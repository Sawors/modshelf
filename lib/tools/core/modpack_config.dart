import 'dart:convert';

import 'package:modshelf/tools/utils.dart';

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

  List<String> _stringListify(List<dynamic> source) {
    return source.map((v) => v.toString()).toList();
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
      required this.upgradeIgnoreDeletion});

  ModpackConfig.fromJsonString(String json) {
    late final result = jsonDecode(json) as Map<String, dynamic>;
    repository = Uri.tryParse(result["repository"]);
    type = result["type"] ?? "unknown";
    forceLocal =
        bool.tryParse(result["force-local-config"].toString()) ?? false;
    Map<String, dynamic> bundleSubmap = result["bundle"];
    bundleInclude = _stringListify(bundleSubmap["include"])
            .map((v) => cleanPath(v))
            .toList() ??
        [];
    bundleExclude = _stringListify(bundleSubmap["exclude"])
            .map((v) => cleanPath(v))
            .toList() ??
        [];
    Map<String, dynamic> upgradeSubmap = result["upgrade"];
    upgradeIgnored = _stringListify(upgradeSubmap["ignored"])
            .map((v) => cleanPath(v))
            .toList() ??
        [];
    upgradeIgnoreDeletion = _stringListify(upgradeSubmap["ignore-deletion"])
            .map((v) => cleanPath(v))
            .toList() ??
        [];
    upgradeIgnoreAddition = _stringListify(upgradeSubmap["ignore-addition"])
            .map((v) => cleanPath(v))
            .toList() ??
        [];
    upgradeIgnoreModification =
        _stringListify(upgradeSubmap["ignore-modification"])
                .map((v) => cleanPath(v))
                .toList() ??
            [];
  }
}
