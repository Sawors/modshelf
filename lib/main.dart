import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:modshelf/self_updater/self_update_checker.dart';
import 'package:modshelf/theme/theme_constants.dart';
import 'package:modshelf/tools/adapters/games.dart';
import 'package:modshelf/tools/adapters/local_files.dart';
import 'package:modshelf/tools/cache.dart';
import 'package:modshelf/tools/core/core.dart';
import 'package:modshelf/tools/core/manifest.dart';
import 'package:modshelf/tools/engine/install.dart';
import 'package:modshelf/tools/engine/package.dart';
import 'package:modshelf/tools/task_supervisor.dart';
import 'package:modshelf/ui/main_page/main_page.dart';
import 'package:modshelf/ui/main_page/pages/download_page/download_manager_page.dart';

final Map<String, PageState> pageStateInstances = {};

class PageState extends ChangeNotifier {
  final String key;
  final Map<String, dynamic> _pageState = {};

  PageState(this.key);

  static PageState getInstance(String key) {
    PageState? global = pageStateInstances[key];
    if (global == null) {
      pageStateInstances[key] = PageState(key);
    }
    // bad design
    return pageStateInstances[key]!;
  }

  dynamic getStateValue(String key) {
    return _pageState[key];
  }

  setStateValue(String key, dynamic value) {
    _pageState[key] = value;
    notifyListeners();
  }

  static setValue(NamespacedKey valueKey, dynamic value) {
    getInstance(valueKey.namespace).setStateValue(valueKey.key, value);
  }

  static dynamic getValue(NamespacedKey valueKey) {
    return getInstance(valueKey.namespace).getStateValue(valueKey.key);
  }
}

Future<bool> startupInitLoad() async {
  if (kDebugMode) {
    print("Loading cache...");
  }
  await CacheManager.initialize(
      cacheDir: await CacheManager.managedCacheDirectory);
  await CacheManager.instance.loadCache();

  if (kDebugMode) {
    print("Checking for upgrades...");
  }
  try {
    await SelfUpgradeChecker.checkForUpgrade();
    final File? upgradeFile = await SelfUpgradeChecker.getCachedUpgradeFile();
    final Directory? installDir =
        SelfUpgradeChecker.selfInstallData?.installDir;
    if (upgradeFile != null && installDir != null) {
      stdout.writeln("Installing upgrade");
      //final String tempFilePath = args[0];
      //   final String delay = args[1];
      //   final String executablePath = args[2];
      //   final String installDirPath = args[3];
      //   final String jsonPatch = args[4];
      //   final String jsonManifest = args[5];
      final config = InstallConfig(
          installLocation: installDir,
          manifest: Manifest.fromJsonString(CacheManager.instance
                  .getCachedEntry(SelfUpgradeChecker.upgradeManifestJsonCacheId)
                  ?.value ??
              "{}"),
          mainProfileSource: null,
          mainProfileImport: [],
          linkToLauncher: false,
          keepArchive: false,
          keepTrackInProgramStore: false,
          launcherType: null);
      final patch = Patch.fromJsonObject(jsonDecode(CacheManager.instance
              .getCachedEntry(SelfUpgradeChecker.upgradePatchJsonCacheId)
              ?.value ??
          "{}"));
      await UnpackArchiveTask(
        config,
        upgradeFile,
        description: "Installing the upgrade in a detached process",
        title: "Modshelf upgrade",
        isUpgrade: true,
        patch: patch,
      ).start().last;
      CacheManager.instance.removeNamespace(SelfUpgradeChecker.cacheNamespace);
      await CacheManager.instance.saveCache();
      // await Process.start(
      //     "${File(Platform.resolvedExecutable).parent.path}/utils/modshelf-updater",
      //     [
      //       upgradeFile.path,
      //       "1",
      //       Platform.resolvedExecutable,
      //       installDir.path,
      //       CacheManager.getCachedEntry(
      //                   SelfUpgradeChecker.upgradePatchJsonCacheId)
      //               ?.value ??
      //           "{}",
      //       CacheManager.getCachedEntry(
      //                   SelfUpgradeChecker.upgradeManifestJsonCacheId)
      //               ?.value ??
      //           "{}",
      //     ],
      //     mode: ProcessStartMode.detachedWithStdio);
      //exit(0);
    }
    final upgradable = await SelfUpgradeChecker.checkForUpgrade();
    stdout.writeln("Upgrade status: ${upgradable ?? "up to date"}");
    if (SelfUpgradeChecker.updateAvailable) {
      stdout.writeln(
          "A new update is available ! (${SelfUpgradeChecker.selfInstallData?.manifest.version} -> $upgradable)");
    }
  } catch (e) {
    if (e is StateError) {
      stdout.writeln("    ${e.message}");
    }
  }

  if (kDebugMode) {
    print("Loading manifests...");
  }
  final List<ModpackData> manifests = await loadStoredManifests();
  PageState.setValue(MainPage.manifestsKey, manifests);

  if (kDebugMode) {
    print("Loading games...");
  }
  GameAdapter.loadAdapters();
  if (kDebugMode) {
    print("Loading tasks...");
  }
  taskUpdate(t) =>
      PageState.getInstance(DownloadManagerPage.downloadManagerPageIdentifier)
          .setStateValue(DownloadManagerPage.downloadManagerTasksKey,
              TaskSupervisor.supervisor.tasks);
  TaskSupervisor.init(TaskSupervisor(
    tasks: [],
    onTaskAdded: taskUpdate,
    onTaskRemoved: taskUpdate,
    onTaskDone: taskUpdate,
    onTaskStarted: taskUpdate,
  ));
  if (kDebugMode) {
    print("Startup loading done !");
  }
  return true;
}

void main(List<String> args) async {
  await startupInitLoad();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    Timer.periodic(const Duration(seconds: 2), (t) {
      if (!context.mounted) {
        t.cancel();
      }
      CacheManager.instance.saveCache();
    });

    ThemeData baseTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurpleAccent, brightness: Brightness.dark),
      useMaterial3: true,
    );

    Decoration tooltipDecoration = BoxDecoration(
        color: baseTheme.colorScheme.surfaceContainerLow,
        border: Border.all(
            color: baseTheme.colorScheme.surfaceContainerHighest, width: 2),
        borderRadius: BorderRadius.circular(10));
    baseTheme = baseTheme.copyWith(
        scaffoldBackgroundColor: baseTheme.colorScheme.surfaceContainerLowest,
        tooltipTheme: baseTheme.tooltipTheme.copyWith(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            textStyle: baseTheme.textTheme.bodyMedium,
            decoration: tooltipDecoration),
        cardTheme: baseTheme.cardTheme.copyWith(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(rectangleRoundingRadius))));

    return MaterialApp(
      title: 'Modshelf',
      theme: baseTheme,
      home: const Scaffold(body: MainPage()),
    );
  }
}
