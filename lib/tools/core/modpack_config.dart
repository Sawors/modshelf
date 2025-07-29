import 'dart:convert';

import 'package:modshelf/tools/utils.dart';

import '../engine/package.dart';
import 'core.dart';

class ModpackConfig {
  late final Uri? repository;
  late final String type;
  late final bool forceLocal;
  late final List<String> bundleInclude;
  late final List<String> bundleExclude;
  late final List<String> upgradeIgnored;
  late final List<String> upgradeIgnoreAddition;
  late final List<String> upgradeIgnoreModification;
  late final List<String> upgradeIgnoreDeletion;
  late final Map<String, Map<String, dynamic>> profiles;

  List<String> _stringListify(List<dynamic> source) {
    return source.map((v) => cleanPath(v.toString())).toList();
  }

  ModpackConfig(
      {required this.repository,
      required this.type,
      required this.forceLocal,
      required this.bundleInclude,
      required this.bundleExclude,
      required this.upgradeIgnored,
      required this.upgradeIgnoreAddition,
      required this.upgradeIgnoreModification,
      required this.upgradeIgnoreDeletion,
      required this.profiles});

  ModpackConfig.fromJsonMap(Map<String, dynamic> jsonMap) {
    final result = jsonMap;
    repository = Uri.tryParse(result["repository"]);
    type = result["type"] ?? "unknown";
    forceLocal =
        bool.tryParse(result["force-local-config"].toString()) ?? false;
    Map<String, dynamic> bundleSubmap = result["bundle"] ?? {};
    bundleInclude = _stringListify(bundleSubmap["include"] ?? [])
        .map((v) => cleanPath(v))
        .toList();
    bundleExclude = _stringListify(bundleSubmap["exclude"] ?? [])
        .map((v) => cleanPath(v))
        .toList();
    Map<String, dynamic> upgradeSubmap = result["upgrade"] ?? {};
    upgradeIgnored = _stringListify(upgradeSubmap["ignored"] ?? [])
        .map((v) => cleanPath(v))
        .toList();
    upgradeIgnoreDeletion =
        _stringListify(upgradeSubmap["ignore-deletion"] ?? [])
            .map((v) => cleanPath(v))
            .toList();
    upgradeIgnoreAddition =
        _stringListify(upgradeSubmap["ignore-addition"] ?? [])
            .map((v) => cleanPath(v))
            .toList();
    upgradeIgnoreModification =
        _stringListify(upgradeSubmap["ignore-modification"] ?? [])
            .map((v) => cleanPath(v))
            .toList();
    final profilesJson = result["profiles"];
    profiles = {};
    if (profilesJson is Map<String, dynamic>) {
      for (var entry in profilesJson.entries) {
        if (entry.value is Map<String, dynamic>) {
          profiles[entry.key] = entry.value;
        }
      }
    }
  }

  ModpackConfig.fromJsonString(String json)
      : this.fromJsonMap(jsonDecode(json) as Map<String, dynamic>);

  ModpackConfig asProfile(String? profile) {
    if (profile == null) {
      return this;
    }
    final profileOverride = profiles[profile];
    final reference = toJsonMap();
    reference.addAll(profileOverride ?? {});
    return ModpackConfig.fromJsonMap(reference);
  }

  Map<String, dynamic> toJsonMap() {
    return {
      "repository": repository.toString(),
      "type": type,
      "force-local-config": forceLocal,
      "bundle": {"include": bundleInclude, "exclude": bundleExclude},
      "upgrade": {
        "ignored": upgradeIgnored,
        "ignore-addition": upgradeIgnoreAddition,
        "ignore-deletion": upgradeIgnoreDeletion,
        "ignore-modification": upgradeIgnoreModification,
      },
      "profiles": profiles
    };
  }

  String toJsonString() {
    return jsonEncode(toJsonMap());
  }

  static NamespacedKey cacheKeyFromString(
      NamespacedKey packId, String version) {
    return NamespacedKey("modpack-config-db", "${packId.toString()}.$version");
  }

  bool patchShouldInclude(PatchDifference difference) {
    final path = cleanPath(difference.getSignificant().relativePath);
    if (upgradeIgnored.any((v) => path.startsWith(v))) {
      return false;
    }
    switch (difference.type) {
      case PatchDifferenceType.added:
        return !upgradeIgnoreAddition.any((v) => path.startsWith(cleanPath(v)));
      case PatchDifferenceType.removed:
        return !upgradeIgnoreDeletion.any((v) => path.startsWith(cleanPath(v)));
      case PatchDifferenceType.modified:
        return !upgradeIgnoreModification
            .any((v) => path.startsWith(cleanPath(v)));
      case PatchDifferenceType.untouched:
        return true;
    }
  }
}
