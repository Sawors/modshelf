import 'dart:convert';
import 'dart:io';

import 'adapters/local_files.dart';
import 'core/core.dart';

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
  static final Map<NamespacedKey, CacheEntry> cacheState = {};
  static bool _cacheUpdate = false;

  static Future<Directory> get managedCacheDirectory => LocalFiles()
      .cacheDir
      .then((v) => Directory("${v.path}${Platform.pathSeparator}managed"));

  static Future<Map<NamespacedKey, CacheEntry>> loadCache() async {
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

  static saveCache() async {
    if (!_cacheUpdate) {
      return;
    }
    Directory cacheDir = await managedCacheDirectory;
    // file, key, value
    Map<String, Map<String, Map<String, String>>> flattenedMap = {};

    for (MapEntry<NamespacedKey, CacheEntry> entry in cacheState.entries) {
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
    if (cacheState[key] != entry) {
      _cacheUpdate = true;
      cacheState[key] = entry;
    }
  }

  static setCachedEntry(NamespacedKey key, CacheEntry entry) {
    if (cacheState[key] != entry) {
      _cacheUpdate = true;
      cacheState[key] = entry;
    }
  }

  static CacheEntry? getCachedEntry(NamespacedKey key) {
    return cacheState[key];
  }

  static String? getCachedValue(NamespacedKey key) {
    return cacheState[key]?.value;
  }
}
