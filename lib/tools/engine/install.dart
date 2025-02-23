import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:dio/dio.dart';
import 'package:io/io.dart';
import 'package:modshelf/tools/adapters/launchers.dart';
import 'package:modshelf/tools/adapters/local_files.dart';
import 'package:modshelf/tools/utils.dart';

import '../core/core.dart';
import '../core/manifest.dart';

enum InstallPhase {
  initialization,
  downloadingArchive,
  extractingArchive,
  importingOldConfig,
  launcherLinking,
  linking,
  postInstall,
  finish;
}

class InstallConfig {
  final Directory installLocation;
  final Directory? mainProfileSource;

  // only relative path ⬇ ️
  final List<String> mainProfileImport;

  final bool linkToLauncher;

  final LauncherType? launcherType;

  final Manifest manifest;

  final bool keepArchive;
  final bool keepTrackInProgramStore;

  InstallConfig(
      {required this.installLocation,
      required this.manifest,
      required this.mainProfileSource,
      required this.mainProfileImport,
      required this.linkToLauncher,
      required this.launcherType,
      this.keepArchive = false,
      this.keepTrackInProgramStore = true});
}

class InstallManager {
  late final Uri repository;
  File? archive;
  late final InstallConfig installConfig;

  InstallManager(this.repository, this.installConfig);

  static Future<String?> linkManifest(File manifest,
      {String? installName, Manifest? loadedManifest}) async {
    Directory store = LocalFiles().manifestStoreDir;
    Manifest man = loadedManifest ??
        Manifest.fromJsonString(await manifest.readAsString());
    String manifestSaveName = installName ?? man.name;
    String manifestTargetPath =
        asPath([store.path, man.game, man.modLoader, manifestSaveName]);
    Link manifestTarget = Link(manifestTargetPath);
    // 255 is an arbitrary loop limit
    for (int i = 1; i <= 255; i++) {
      if (!await manifestTarget.exists()) {
        break;
      }
      final longName = "${manifestTargetPath}_$i";
      manifestTarget = Link(longName);
    }

    if (!await manifest.exists()) {
      throw FileSystemException("Manifest file not found", manifest.path);
    }

    return (await Link(manifestTarget.path)
            .create(manifest.path, recursive: true))
        .path;
  }

  // actual bytes, total bytes, target file, download done
  Stream<(int, int, List<int>, bool)> downloadArchive(
      {int periodMs = 200}) async* {
    //yield* downloadFileTemp(repository, periodMs: periodMs);
    // final tempDir = Directory.systemTemp;
    //   final targetFile = File(
    //       "${tempDir.path}${Platform.pathSeparator}modshelf_${generateRandomStringAlNum(16)}.zip");
    //   var status = (0, 0, targetFile, false);
    //   Dio()
    //       .downloadUri(source, targetFile.path,
    //           onReceiveProgress: (currentBytes, totalBytes) =>
    //               status = (currentBytes, totalBytes, targetFile, false))
    //       .whenComplete(() => status = (status.$1, status.$2, status.$3, true));
    //   yield* Stream.periodic(Duration(milliseconds: periodMs), (_) {
    //     return status;
    //   });
    var status = (0, 0, List<int>.empty(growable: false), false);
    Dio().getUri(repository, options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: (actual, total) {
      status = (actual, total, [], false);
    }).then((v) {
      dynamic data = v.data;
      status = (status.$1, status.$2, data as List<int>, true);
    });

    // 726,350,799
    yield* Stream.periodic(Duration(milliseconds: periodMs), (_) {
      return status;
    });
  }

  Stream<(InstallPhase, String)> installModpack(List<int> archiveContent,
      {int fakeDelayMs = 0, bool yieldPostInstall = false}) async* {
    bool hasLauncher = installConfig.launcherType != null;
    Directory extractDir = installConfig.installLocation;
    Directory? adapted = installConfig.launcherType
        ?.getAdapter()
        ?.installDirForLauncher(extractDir);
    if (adapted != null && adapted.path.isNotEmpty) {
      extractDir = adapted;
    }
    if (!await extractDir.exists()) {
      await extractDir.create(recursive: true);
    }

    if (!await extractDir.list().isEmpty) {
      throw const FileSystemException("Target directory is not empty");
    }

    // extracting to destination

    final bytes = archiveContent;
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final file in archive) {
      final filename = file.name;
      final targetPath = "${extractDir.path}/$filename";
      if (file.isFile) {
        final data = file.content as List<int>;
        yield (InstallPhase.extractingArchive, "$targetPath,${data.length}");
        File target = File(targetPath);
        await target.create(recursive: true);
        await target.writeAsBytes(data);
      } else {
        await Directory(targetPath).create(recursive: true);
      }
    }

    await Future.delayed(Duration(milliseconds: fakeDelayMs));
    // copying base configs
    if (installConfig.mainProfileSource != null &&
        await installConfig.mainProfileSource!.exists()) {
      for (String path in installConfig.mainProfileImport) {
        final String sourcePath =
            "${installConfig.mainProfileSource!.path}/$path";
        final String targetPath = "${extractDir.path}/$path";
        if (await FileSystemEntity.type(sourcePath) !=
            FileSystemEntityType.notFound) {
          yield (InstallPhase.importingOldConfig, sourcePath);
          copyPath(sourcePath, targetPath);
        }
      }
    }

    await Future.delayed(Duration(milliseconds: fakeDelayMs));
    // injecting profile
    if (hasLauncher && installConfig.linkToLauncher) {
      LauncherAdapter? adp = installConfig.launcherType?.getAdapter();
      if (adp != null) {
        yield (InstallPhase.launcherLinking, installConfig.launcherType!.name);
        adp.injectProfile(installConfig);
      }
    }

    if (installConfig.keepTrackInProgramStore) {
      await Future.delayed(Duration(milliseconds: fakeDelayMs));
      // linking
      yield (InstallPhase.linking, "");
      String manifestSourcePath =
          "${extractDir.path}${Platform.pathSeparator}${DirNames.fileManifest}";
      Manifest man = installConfig.manifest;
      linkManifest(File(manifestSourcePath), loadedManifest: man);
    }

    await Future.delayed(Duration(milliseconds: fakeDelayMs));
    // finish
    yield (
      yieldPostInstall ? InstallPhase.postInstall : InstallPhase.finish,
      "✔"
    );
  }
}
