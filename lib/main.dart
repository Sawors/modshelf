import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:modshelf/theme/theme_constants.dart';
import 'package:modshelf/tools/adapters/games.dart';
import 'package:modshelf/tools/adapters/local_files.dart';
import 'package:modshelf/tools/cache.dart';
import 'package:modshelf/tools/core/core.dart';
import 'package:modshelf/ui/main_page/main_page.dart';

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
    print("loading manifests...");
  }
  final List<ModpackData> manifests = await loadStoredManifests();
  PageState.setValue(ModpackListPage.manifestsKey, manifests);

  if (kDebugMode) {
    print("loading cache...");
  }
  await CacheManager.loadCache().then((v) => CacheManager.cacheState.addAll(v));
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
      CacheManager.saveCache();
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
