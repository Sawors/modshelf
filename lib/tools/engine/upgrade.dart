import 'dart:convert';

import 'package:modshelf/tools/engine/package.dart';

import '../../dev/mod_host.dart';

PatchDifference? getUpgradeContent() {}

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
