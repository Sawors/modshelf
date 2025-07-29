import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:http/http.dart';
import 'package:io/io.dart';
import 'package:modshelf/tools/adapters/launchers.dart';
import 'package:modshelf/tools/adapters/local_files.dart';
import 'package:modshelf/tools/adapters/servers.dart';
import 'package:modshelf/tools/utils.dart';

import '../core/core.dart';
import '../core/manifest.dart';
import '../tasks.dart';
import 'package.dart';

enum InstallPhase {
  initialization,
  downloadingArchive,
  extractingArchive,
  importingOldConfig,
  launcherLinking,
  linking,
  finalizing,
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

class InstallPackTask extends TaskQueue {
  final Patch? patch;

  InstallPackTask(
      ContentSnapshot content, InstallConfig installConfig, Manifest manifest,
      {required super.description,
      required super.title,
      super.latestProgress,
      this.patch}) {
    this.manifest = manifest;
    final archivePath =
        "${Directory.systemTemp.path}/modshelf-${generateRandomStringAlNum(16)}";
    final Task dl = DownloadTask(
        ModshelfServerAgent(), content, manifest.packId,
        description: "Downloading the pack...",
        title: "Download  ",
        manifest: manifest,
        filePathOverride: archivePath);
    final Task install = UnpackArchiveTask(installConfig, File(archivePath),
        description: "Installing the pack...",
        title: "Installation",
        patch: patch ?? Patch.compiled([content]));
    tasks = [dl, install];
  }

  @override
  Stream<TaskReport<TaskReport>> execute({dynamic pipedData}) async* {
    final initialSize = tasks.length;
    for (var stream in tasks.indexed) {
      current = stream.$1;
      final str = stream.$2.start();
      await for (var report in str) {
        yield TaskReport(
            completed: stream.$1, total: initialSize, data: report);
        if (report.isComplete) {
          break;
        }
      }
    }
    yield TaskReport(
        completed: initialSize, total: initialSize, data: latestProgress);
  }
}

class DownloadTask extends Task {
  final ModshelfServerAgent server;
  final NamespacedKey packId;
  final ContentSnapshot requestContent;
  final String? filePathOverride;

  DownloadTask(this.server, this.requestContent, this.packId,
      {required super.description,
      required super.title,
      super.manifest,
      super.chainedData,
      super.latestProgress,
      this.filePathOverride});

  @override
  Stream<TaskReport<String>> execute({pipedData}) async* {
    final mergedQParameters = {"action": "get"};
    final Request request = Request(
        "post",
        server
            .modpackIdToUri(packId, asApi: true)
            .replace(queryParameters: mergedQParameters));
    request.body = requestContent
        .toContentString(server.modpackIdToUri(packId, asApi: false).path);
    final response = await request.send();
    int completed = 0;
    final String outputFilePath = filePathOverride ??
        "${Directory.systemTemp.path}/modshelf-${generateRandomStringAlNum(16)}";
    final File outputFile = File(outputFilePath);
    final sink = outputFile.openWrite();
    try {
      await for (var chunk in response.stream) {
        completed += chunk.length;
        sink.add(chunk);
        yield TaskReport(
            completed: completed,
            total: response.contentLength ?? 0,
            data: outputFilePath);
      }
    } finally {
      sink.close();
    }
  }
}

class InstallTaskReport extends TaskReport<Directory> {
  final InstallPhase phase;
  String? comment;

  InstallTaskReport(this.phase,
      {this.comment,
      required super.completed,
      required super.total,
      super.data});
}

class UnpackArchiveTask extends Task {
  final InstallConfig installConfig;
  final File archiveFile;
  final bool isUpgrade;
  final Patch? patch;

  UnpackArchiveTask(this.installConfig, this.archiveFile,
      {required super.description,
      required super.title,
      this.isUpgrade = false,
      this.patch});

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

  @override
  Stream<InstallTaskReport> execute({dynamic pipedData}) async* {
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

    if (!isUpgrade && !await extractDir.list().isEmpty) {
      throw const FileSystemException("Target directory is not empty");
    }

    // extracting to destination
    final int extractionSteps = patch?.patch
            .where((p) => p.type != PatchDifferenceType.removed)
            .length ??
        0;
    final int totalSteps = extractionSteps + 2;
    int step = 0;
    final res = ZipDecoder().decodeStream(InputFileStream(archiveFile.path));
    for (var file in res) {
      final filename = file.name;
      final targetPath = "${extractDir.path}/$filename";
      if (file.isFile) {
        step++;
        final data = file.content as List<int>;
        File target = File(targetPath);
        yield InstallTaskReport(InstallPhase.extractingArchive,
            comment: "$targetPath,${data.length}",
            completed: step,
            total: totalSteps);
        await target.create(recursive: true);
        await target.writeAsBytes(data);
      } else {
        Directory(targetPath).createSync(recursive: true);
      }
    }

    // copying base configs
    yield InstallTaskReport(InstallPhase.finalizing,
        completed: step + 1, total: totalSteps);
    if (installConfig.mainProfileSource != null &&
        await installConfig.mainProfileSource!.exists()) {
      for (String path in installConfig.mainProfileImport) {
        final String sourcePath =
            "${installConfig.mainProfileSource!.path}/$path";
        final String targetPath = "${extractDir.path}/$path";
        if (await FileSystemEntity.type(sourcePath) !=
            FileSystemEntityType.notFound) {
          // yield InstallTaskReport(InstallPhase.importingOldConfig,
          //     comment: sourcePath, completed: 1, total: 1);
          copyPath(sourcePath, targetPath);
        }
      }
    }

    // injecting profile
    if (hasLauncher && installConfig.linkToLauncher) {
      LauncherAdapter? adp = installConfig.launcherType?.getAdapter();
      if (adp != null) {
        // yield InstallTaskReport(InstallPhase.launcherLinking,
        //     comment: installConfig.launcherType!.name, completed: 1, total: 1);
        adp.injectProfile(installConfig);
      }
    }

    if (installConfig.keepTrackInProgramStore) {
      // linking
      //yield InstallTaskReport(InstallPhase.linking, completed: 1, total: 1);
      String manifestSourcePath =
          "${extractDir.path}${Platform.pathSeparator}${DirNames.fileManifest}";
      Manifest man = installConfig.manifest;
      await linkManifest(File(manifestSourcePath), loadedManifest: man);
    }

    if (patch != null) {
      try {
        await Future.wait(patch!.patch
            .where((v) => v.type == PatchDifferenceType.removed)
            .map((r) =>
                File("${extractDir.path}${r.getSignificant().relativePath}")
                    .delete(recursive: true)));
      } catch (_) {
        // ignore
      }
    }

    archiveFile.delete();

    // finish
    yield InstallTaskReport(InstallPhase.finish,
        completed: totalSteps, total: totalSteps, data: extractDir);
  }
}

class DownloadTaskReport extends TaskReport<List<int>> {
  final Uri source;

  DownloadTaskReport(
      {required super.completed,
      required super.total,
      required this.source,
      super.data});

  @override
  bool get isComplete => super.isComplete && data != null;
}

class InstallManager {
  late final Uri repository;
  File? archive;
  late final InstallConfig installConfig;

  InstallManager(this.repository, this.installConfig);
}
