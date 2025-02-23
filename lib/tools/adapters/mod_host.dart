import 'dart:core';

class ModData {
  final String name;
  final String version;
  final String modId;
  final List<String> availableVersions;
  final Uri? source;
  final ModHost host;
  final Map<String, dynamic> sourceData;

  ModData(
      {required this.modId,
      required this.name,
      required this.version,
      required this.availableVersions,
      required this.source,
      required this.host,
      required this.sourceData});
}

abstract class ModHost {
  Uri get apiSource;

  Future<Map<String, dynamic>?> _getModProjectData(String modId);

  Future<List<String>> getModVersions(String modId);

  Future<ModData> getModData(String modId, String version);
}

class CurseforgeModHost extends ModHost {
  @override
  // TODO: implement apiSource
  Uri get apiSource => Uri.parse("https://api.curseforge.com/v1");

  @override
  Future<Map<String, dynamic>?> _getModProjectData(String modId) async {
    // TODO: implement _getModProjectData
    throw UnimplementedError();
  }

  @override
  Future<ModData> getModData(String modId, String version) async {
    // TODO: implement getModData
    throw UnimplementedError();
  }

  @override
  Future<List<String>> getModVersions(String modId) async {
    // TODO: implement getModVersions
    throw UnimplementedError();
  }
}

class ModrinthModHost extends ModHost {
  static const Map<String, String> headers = {
    "User-Agent": "sawors/modshelf/1.0.0 (sawors@proton.me)"
  };

  @override
  Uri get apiSource => Uri.parse("https://api.modrinth.com/v2/");

  @override
  Future<Map<String, dynamic>?> _getModProjectData(String modId) async {
    // TODO: implement _getModProjectData
    throw UnimplementedError();
  }

  @override
  Future<ModData> getModData(String modId, String version) async {
    // TODO: implement getModData
    throw UnimplementedError();
  }

  @override
  Future<List<String>> getModVersions(String modId) async {
    // TODO: implement getModVersions
    throw UnimplementedError();
  }
}
