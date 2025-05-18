import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:modshelf/cli/cli_parser.dart';
import 'package:modshelf/theme/theme_constants.dart';
import 'package:modshelf/tools/adapters/games.dart';
import 'package:modshelf/tools/adapters/local_files.dart';
import 'package:modshelf/tools/core/core.dart';
import 'package:modshelf/ui/main_page/main_page.dart';
import 'package:window_manager/window_manager.dart';

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

final class CacheEntry {
  static const Duration defaultLifetime = Duration(hours: 1);
  late final String value;
  late final DateTime birth;
  late final Duration lifetime;

  DateTime? get limit =>
      lifetime.inMilliseconds > 0 ? birth.add(lifetime) : null;

  // set lifetime to 0 to ignore lifetime
  CacheEntry(this.value, {DateTime? birth, Duration? lifetime}) {
    this.birth = birth ?? DateTime.now();
    this.lifetime = lifetime ?? defaultLifetime;
  }

  Map<String, String> get asMap => {
        "value": value,
        "birth": birth.toUtc().toIso8601String(),
        "lifetime": lifetime.inSeconds.toString()
      };

  CacheEntry.fromMap(Map<String, dynamic> map) {
    if (!map.containsKey("value")) {
      throw ArgumentError("'value' field cannot be empty !");
    }
    value = map["value"];
    birth = map.containsKey("birth")
        ? DateTime.parse(map["birth"])
        : DateTime.now();
    lifetime = Duration(seconds: int.tryParse(map["lifetime"] ?? "0") ?? 0);
  }
}

class CacheManager {
  static final Map<NamespacedKey, CacheEntry> _cacheState = {};
  static bool _cacheUpdate = false;

  static Future<Directory> get managedCacheDirectory => LocalFiles()
      .cacheDir
      .then((v) => Directory("${v.path}${Platform.pathSeparator}managed"));

  static Future<Map<NamespacedKey, CacheEntry>> _loadCache() async {
    Directory cacheDir = await managedCacheDirectory;
    Map<NamespacedKey, CacheEntry> result = {};
    const JsonDecoder decoder = JsonDecoder();
    if (!await cacheDir.exists()) {
      return result;
    }
    for (FileSystemEntity f in await cacheDir.list().toList()) {
      if (await FileSystemEntity.isFile(f.path)) {
        String fileName = f.uri.pathSegments.last;
        Map<String, dynamic> fileMap = decoder
            .convert(await File(f.path).readAsString()) as Map<String, dynamic>;
        for (MapEntry<String, dynamic> entry in fileMap.entries) {
          NamespacedKey key = NamespacedKey(fileName, entry.key);
          if (entry.value is Map<String, dynamic>) {
            try {
              result[key] = CacheEntry.fromMap(entry.value);
            } on ArgumentError {
              // ignore
            }
          }
        }
      }
    }
    return result;
  }

  static _saveCache() async {
    if (!_cacheUpdate) {
      return;
    }
    Directory cacheDir = await managedCacheDirectory;
    // file, key, value
    Map<String, Map<String, Map<String, String>>> flattenedMap = {};

    for (MapEntry<NamespacedKey, CacheEntry> entry in _cacheState.entries) {
      Map<String, Map<String, String>> map =
          flattenedMap[entry.key.namespace] ?? {};
      map[entry.key.key] = entry.value.asMap;
      flattenedMap[entry.key.namespace] = map;
    }

    const JsonEncoder encoder = JsonEncoder();
    for (MapEntry<String, Map<String, Map<String, String>>> entry
        in flattenedMap.entries) {
      File cacheFile =
          File("${cacheDir.path}${Platform.pathSeparator}${entry.key}");
      cacheFile
          .create(recursive: true)
          .then((f) => f.writeAsString(encoder.convert(entry.value)));
    }
    _cacheUpdate = false;
  }

  static setCachedValue(NamespacedKey key, String value) {
    CacheEntry entry = CacheEntry(value);
    if (_cacheState[key] != entry) {
      _cacheUpdate = true;
      _cacheState[key] = entry;
    }
  }

  static setCachedEntry(NamespacedKey key, CacheEntry entry) {
    if (_cacheState[key] != entry) {
      _cacheUpdate = true;
      _cacheState[key] = entry;
    }
  }

  static CacheEntry? getCachedEntry(NamespacedKey key) {
    return _cacheState[key];
  }

  static String? getCachedValue(NamespacedKey key) {
    return _cacheState[key]?.value;
  }
}

Future<bool> startupInitLoad() async {
  if (kDebugMode) {
    print("loading manifests...");
  }
  final List<ModpackData> manifests = await loadStoredManifests();
  PageState.setValue(ModpackListPage.manifestsKey, manifests);

  if (kDebugMode) {
    print("loading cache...");
  }
  await CacheManager._loadCache()
      .then((v) => CacheManager._cacheState.addAll(v));
  if (kDebugMode) {
    print("loading games...");
  }
  GameAdapter.loadAdapters();
  if (kDebugMode) {
    print("preloading done !");
  }
  return true;
}

void main(List<String> args) async {
  if (args.contains("nogui")) {
    WidgetsFlutterBinding.ensureInitialized();
    await windowManager.ensureInitialized();
    await windowManager.hide();
    await runCli(args);
    //SystemNavigator.pop();
  } else {
    await startupInitLoad();
    runApp(const MyApp());
  }
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
      CacheManager._saveCache();
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
      home: const Scaffold(body: ModpackListPage()),
    );
  }
}
