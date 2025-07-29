import 'dart:convert';
import 'dart:io';

import 'package:modshelf/tools/adapters/servers.dart';
import 'package:modshelf/tools/core/core.dart';
import 'package:modshelf/tools/core/modpack_config.dart';
import 'package:modshelf/tools/engine/package.dart';

import '../../dev/mod_host.dart';
import '../tasks.dart';
import '../utils.dart';
import 'install.dart';

class ModVersionReport {
  final String modId;
  final String versionId;
  final List<String> loaders;
  final List<String> gameVersion;
  final ModHost modHost;

  ModVersionReport(
      {required this.modId,
      required this.versionId,
      required this.loaders,
      required this.gameVersion,
      required this.modHost});

  Map<String, dynamic> toJsonEncodable() {
    return {
      "mod-id": modId,
      "version-id": versionId,
      "loaders": loaders,
      "game-versions": gameVersion,
      "modhost": modHost.apiSource.toString()
    };
  }

  @override
  String toString() {
    return jsonEncode(toJsonEncodable());
  }

  static ModVersionReport fromJsonMap(Map<String, dynamic> jsonMap) {
    return ModVersionReport(
        modId: jsonMap["mod-id"],
        versionId: jsonMap["version-id"],
        loaders: (jsonMap["loaders"] as List<dynamic>)
            .map((v) => v.toString())
            .toList(),
        gameVersion: (jsonMap["game-versions"] as List<dynamic>)
            .map((v) => v.toString())
            .toList(),
        modHost: ModrinthModHost());
  }

  static ModVersionReport fromString(String str) {
    final res = jsonDecode(str);
    return fromJsonMap(res);
  }
}

class CompleteUpgradePipelineTask extends TaskQueue {
  List<int> archiveData = [];
  final ModpackData modpackData;
  final Patch upgradeTarget;
  final String installTitle = "Upgrade   ";
  final String installDescription = "Upgrading the pack...";
  final String downloadTitle = "Download";
  final String downloadDescription = "Downloading the pack...";

  CompleteUpgradePipelineTask(
      this.modpackData, Directory installDirectory, this.upgradeTarget,
      {required super.description,
      required super.title,
      super.manifest,
      super.latestProgress}) {
    // preventing the usage of home-made API, THIS IS A PROBLEM!
    final archivePath =
        "${Directory.systemTemp.path}/modshelf-${generateRandomStringAlNum(16)}";
    final Task dl = DownloadTask(
        ModshelfServerAgent(),
        ContentSnapshot(
            upgradeTarget
                .onlyChanged()
                .where((p) => p.type != PatchDifferenceType.removed)
                .map((p) => p.getSignificant())
                .toSet(),
            upgradeTarget.version),
        modpackData.manifest.packId,
        description: description,
        title: this.title,
        manifest: modpackData.manifest,
        filePathOverride: archivePath);

    final InstallConfig installConfig = InstallConfig(
        installLocation: modpackData.installDir!,
        manifest: modpackData.manifest,
        mainProfileSource: null,
        mainProfileImport: [],
        linkToLauncher: false,
        keepArchive: false,
        keepTrackInProgramStore: false,
        launcherType: null);
    final UnpackArchiveTask install = UnpackArchiveTask(
        installConfig, File(archivePath),
        description: installDescription,
        title: installTitle,
        isUpgrade: true,
        patch: upgradeTarget);
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
          if (report is DownloadTaskReport) {
            archiveData = report.data ?? [];
          }
          break;
        }
      }
    }
    yield TaskReport(completed: initialSize, total: initialSize);
  }
}

Future<Patch> getUpgradeContent(Directory dir, {String? targetVersion}) async {
  final ModpackData localData = await ModpackData.fromInstallation(dir);
  final ServerAgent agent = ModshelfServerAgent();
  final ModpackConfig usedConfig = localData.modpackConfig.forceLocal
      ? localData.modpackConfig
      : await agent.fetchConfig(localData.manifest.packId,
          await agent.getLatestVersion(localData.manifest.packId));
  final ContentSnapshot content = await ContentSnapshot.fromDirectory(
      dir, localData.manifest.version,
      includeFilters: usedConfig.bundleInclude,
      excludeFilters: [
        ...usedConfig.bundleExclude,
        ...usedConfig.upgradeIgnored
      ]);
  final newContent = await agent.getContent(localData.manifest.packId,
      targetVersion ?? await agent.getLatestVersion(localData.manifest.packId));

  final Patch patch = Patch.difference(content, newContent);
  return Patch(
      patch:
          patch.patch.where((pt) => usedConfig.patchShouldInclude(pt)).toSet(),
      version: patch.version,
      firstVersion: patch.firstVersion);
}
