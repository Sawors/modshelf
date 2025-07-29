import 'dart:convert';
import 'dart:io';

import 'adapters/local_files.dart';
import 'core/core.dart';

final class CacheEntry {
  static const Duration defaultLifetime = Duration(hours: 1);
  static const Duration immortalLifetime = Duration.zero;
  late final dynamic value;
  late final DateTime birth;
  late final Duration lifetime;

  bool get isExpired =>
      lifetime.compareTo(immortalLifetime) != 0 &&
      birth.add(lifetime).isBefore(DateTime.now());

  // set lifetime to 0 to ignore lifetime
  CacheEntry(this.value, {DateTime? birth, Duration? lifetime}) {
    this.birth = birth ?? DateTime.now();
    this.lifetime = lifetime ?? defaultLifetime;
  }

  CacheEntry.immortal(this.value, {DateTime? birth}) {
    this.birth = birth ?? DateTime.now();
    lifetime = immortalLifetime;
  }

  Map<String, dynamic> get asMap => {
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
  static CacheManager? _instance;
  final Map<NamespacedKey, CacheEntry> cacheState = {};
  final Set<String> cacheNamespaceToSave = {};
  final Set<String> unloadedNamespaces = {};
  final bool lazyLoading;
  final Directory cacheDir;

  CacheManager({this.lazyLoading = true, required this.cacheDir});

  static Future<void> initialize(
      {CacheManager? source, required Directory cacheDir}) async {
    _instance ??= source ?? CacheManager(cacheDir: await managedCacheDirectory);
  }

  static CacheManager get instance {
    if (_instance == null) {
      throw StateError("The cache manager has not been initialized");
    }
    return _instance!;
  }

  static Future<Directory> get managedCacheDirectory => LocalFiles()
      .cacheDir
      .then((v) => Directory("${v.path}${Platform.pathSeparator}managed"));

  Future<Map<NamespacedKey, CacheEntry>> loadCacheNamespace(
      String namespace) async {
    final File file = File("${cacheDir.path}/$namespace.json");
    return loadCacheFile(file);
  }

  Future<Map<NamespacedKey, CacheEntry>> loadCacheFile(File file) async {
    final fileName = file.uri.pathSegments.last;
    final String namespace = fileName.endsWith(".json")
        ? fileName.substring(0, fileName.length - 5)
        : fileName;
    if (!await file.exists()) {
      throw FileSystemException(
          "Cache file not found for namespace $namespace");
    }
    const JsonDecoder decoder = JsonDecoder();
    Map<NamespacedKey, CacheEntry> result = {};
    Map<String, dynamic> fileMap =
        decoder.convert(await file.readAsString()) as Map<String, dynamic>;
    for (MapEntry<String, dynamic> entry in fileMap.entries) {
      NamespacedKey key = NamespacedKey(namespace, entry.key);
      if (entry.value is Map<String, dynamic>) {
        try {
          final ent = CacheEntry.fromMap(entry.value);
          if (!ent.isExpired) {
            result[key] = ent;
          } else {
            stdout
                .writeln("[CACHE] : skipping expired entry ${key.toString()}");
          }
        } on ArgumentError {
          // ignore
        }
      }
    }
    unloadedNamespaces.remove(namespace);
    cacheState.addAll(result);
    return result;
  }

  Map<NamespacedKey, CacheEntry> loadCacheNamespaceSync(String namespace) {
    final File file = File("${cacheDir.path}/$namespace.json");
    return loadCacheFileSync(file);
  }

  Map<String, CacheEntry> getNamespace(String namespace) {
    return Map.fromEntries(cacheState.entries
        .where((e) => e.key.namespace == namespace)
        .map((e) => MapEntry(e.key.key, e.value)));
  }

  Map<NamespacedKey, CacheEntry> loadCacheFileSync(File file) {
    final fileName = file.uri.pathSegments.last;
    final String namespace = fileName.endsWith(".json")
        ? fileName.substring(0, fileName.length - 5)
        : fileName;
    if (!file.existsSync()) {
      throw FileSystemException(
          "Cache file not found for namespace $namespace");
    }
    const JsonDecoder decoder = JsonDecoder();
    Map<NamespacedKey, CacheEntry> result = {};
    Map<String, dynamic> fileMap =
        decoder.convert(file.readAsStringSync()) as Map<String, dynamic>;
    for (MapEntry<String, dynamic> entry in fileMap.entries) {
      NamespacedKey key = NamespacedKey(namespace, entry.key);
      if (entry.value is Map<String, dynamic>) {
        try {
          final ent = CacheEntry.fromMap(entry.value);
          if (!ent.isExpired) {
            result[key] = ent;
          } else {
            stdout
                .writeln("[CACHE] : skipping expired entry ${key.toString()}");
          }
        } on ArgumentError {
          // ignore
        }
      }
    }
    unloadedNamespaces.remove(namespace);
    cacheState.addAll(result);
    return result;
  }

  Future<Map<NamespacedKey, CacheEntry>> loadCache() async {
    Directory cacheDir = await managedCacheDirectory;
    Map<NamespacedKey, CacheEntry> result = {};
    if (!await cacheDir.exists()) {
      return result;
    }
    for (FileSystemEntity f in await cacheDir.list().toList()) {
      if (await FileSystemEntity.isFile(f.path)) {
        String fileName = f.uri.pathSegments.last;
        final String filenameNoExtension = fileName.endsWith(".json")
            ? fileName.substring(0, fileName.length - 5)
            : fileName;
        if (!lazyLoading) {
          result.addAll(await loadCacheFile(f as File));
        } else {
          unloadedNamespaces.add(filenameNoExtension);
        }
      }
    }
    cacheState.addAll(result);
    return result;
  }

  Future<void> saveCache() async {
    if (cacheNamespaceToSave.isEmpty) {
      return;
    }
    Directory cacheDir = await managedCacheDirectory;
    // file, key, value
    Map<String, Map<String, Map<String, dynamic>>> flattenedMap = {};

    for (MapEntry<NamespacedKey, CacheEntry> entry in cacheState.entries) {
      if (entry.value.isExpired ||
          !cacheNamespaceToSave.contains(entry.key.namespace)) {
        continue;
      }
      Map<String, Map<String, dynamic>> map =
          flattenedMap[entry.key.namespace] ?? {};
      map[entry.key.key] = entry.value.asMap;
      flattenedMap[entry.key.namespace] = map;
    }

    const JsonEncoder encoder = JsonEncoder();
    for (String namespace in flattenedMap.keys) {
      final entry = flattenedMap[namespace];
      stdout.writeln("[CACHE] : saving namespace '$namespace'");
      File cacheFile =
          File("${cacheDir.path}${Platform.pathSeparator}$namespace.json");
      if (entry == null || entry.isEmpty) {
        await cacheFile.delete();
      } else {
        await cacheFile.create(recursive: true).then((f) {
          try {
            final converted = encoder.convert(entry);
            f.writeAsString(converted);
          } catch (_) {
            stdout.writeln(
                "[CACHE] : Could not save cache file ${f.uri.pathSegments.last}");
          }
        });
      }
    }
    cacheNamespaceToSave.clear();
  }

  setCachedValue(NamespacedKey key, String value) {
    if (lazyLoading) {
      final namespace = key.namespace;
      if (unloadedNamespaces.contains(namespace)) {
        cacheState.addAll(loadCacheNamespaceSync(namespace));
      }
    }
    CacheEntry entry = CacheEntry(value);
    if (cacheState[key] != entry) {
      cacheNamespaceToSave.add(key.namespace);
      cacheState[key] = entry;
    }
  }

  removeKey(NamespacedKey key) {
    if (lazyLoading) {
      final namespace = key.namespace;
      if (unloadedNamespaces.contains(namespace)) {
        cacheState.addAll(loadCacheNamespaceSync(namespace));
      }
    }
    cacheState.remove(key);
    cacheNamespaceToSave.add(key.namespace);
  }

  removeNamespace(String namespace) {
    if (lazyLoading) {
      if (unloadedNamespaces.contains(namespace)) {
        cacheState.addAll(loadCacheNamespaceSync(namespace));
      }
    }
    cacheState.removeWhere((k, _) => k.namespace == namespace);
    cacheNamespaceToSave.add(namespace);
  }

  setCachedEntry(NamespacedKey key, CacheEntry entry) {
    if (lazyLoading) {
      final namespace = key.namespace;
      if (unloadedNamespaces.contains(namespace)) {
        cacheState.addAll(loadCacheNamespaceSync(namespace));
      }
    }
    if (cacheState[key] != entry) {
      cacheState[key] = entry;
      cacheNamespaceToSave.add(key.namespace);
    }
  }

  CacheEntry? getCachedEntry(NamespacedKey key) {
    if (lazyLoading) {
      final namespace = key.namespace;
      if (unloadedNamespaces.contains(namespace)) {
        cacheState.addAll(loadCacheNamespaceSync(namespace));
      }
    }
    return cacheState[key];
  }

  String? getCachedValue(NamespacedKey key) {
    if (lazyLoading) {
      final namespace = key.namespace;
      if (unloadedNamespaces.contains(namespace)) {
        cacheState.addAll(loadCacheNamespaceSync(namespace));
      }
    }
    return cacheState[key]?.value;
  }
}
