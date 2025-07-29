import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:modshelf/tools/adapters/servers.dart';
import 'package:modshelf/tools/cache.dart';
import 'package:modshelf/tools/core/core.dart';
import 'package:modshelf/tools/core/manifest.dart';
import 'package:modshelf/tools/engine/install.dart';
import 'package:modshelf/tools/tasks.dart';

import '../tools/engine/package.dart';

Future<void> main(List<String> args) async {
  if (args.length < 6) {
    stdout.writeln("Not enough arguments to start the process, aborting.");
    return;
  }
  final String tempFilePath = args[0];
  final String delay = args[1];
  final String executablePath = args[2];
  final String installDirPath = args[3];
  final String jsonPatch = args[4];
  final String jsonManifest = args[5];
  final List<String> otherArgs = args.length > 6 ? args.sublist(6) : [];

  final InstallConfig installConfig = InstallConfig(
      installLocation: Directory(installDirPath),
      manifest: Manifest.fromJsonString(jsonManifest),
      mainProfileSource: null,
      mainProfileImport: [],
      linkToLauncher: false,
      keepArchive: false,
      keepTrackInProgramStore: false,
      launcherType: null);
  await SelfUpgradeChecker.install(tempFilePath, executablePath, installConfig,
          Patch.fromJsonObject(jsonDecode(jsonPatch)))
      .last;
  await Future.delayed(Duration(seconds: int.tryParse(delay) ?? 2));
  Process.start(executablePath, otherArgs, mode: ProcessStartMode.detached);
}

abstract class SelfUpgradeChecker {
  static ModpackData? selfInstallData;
  static String? newVersion;
  static bool updateAvailable = false;
  static const String cacheNamespace = "modshelf-auto-upgrade";
  static const NamespacedKey upgradeFileCacheId =
      NamespacedKey(cacheNamespace, "filepath");
  static const NamespacedKey upgradePatchJsonCacheId =
      NamespacedKey(cacheNamespace, "patch-json");
  static const NamespacedKey upgradeManifestJsonCacheId =
      NamespacedKey(cacheNamespace, "manifest-json");
  static const NamespacedKey upgradeFileHashCacheId =
      NamespacedKey(cacheNamespace, "filehash");
  static const NamespacedKey modshelfPackId =
      NamespacedKey("general", "modshelf");

  static Future<File?> getCachedUpgradeFile() async {
    final filePath = CacheManager.instance.getCachedValue(upgradeFileCacheId);
    final fileHash =
        CacheManager.instance.getCachedValue(upgradeFileHashCacheId);
    if (filePath != null && fileHash != null && await File(filePath).exists()) {
      final File archFile = File(filePath);
      final currentHash =
          sha256.convert(await archFile.readAsBytes()).toString();
      if (fileHash == currentHash) {
        return archFile;
      }
    }
    return null;
  }

  static Future<String?> checkForUpgrade() async {
    final installation = File(Platform.resolvedExecutable);
    ModpackData data;
    try {
      data = await ModpackData.fromInstallation(installation.parent);
      selfInstallData = data;
    } on FileSystemException {
      throw StateError(
          "Modshelf is not installed in a tracked directory !\nCannot check for updates.");
    }
    await ModshelfServerAgent().hasUpgrade(data.manifest).then((check) {
      updateAvailable = check != null;
      if (updateAvailable) {
        newVersion = check;
      } else {
        newVersion = null;
      }
    });
    return newVersion;
  }

  static Stream<TaskReport<dynamic>> install(String upgradeFilePath,
      String executable, InstallConfig config, Patch patch) {
    return UnpackArchiveTask(config, File(upgradeFilePath),
            description: "Installing the upgrade in a detached process",
            title: "Modshelf upgrade",
            isUpgrade: true)
        .start();
  }
}
