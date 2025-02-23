import 'dart:convert';
import 'dart:core';

import 'package:http/http.dart';

class ModData {
  final String name;
  final String version;
  final String versionId;
  final String projectId;
  final Uri? source;
  final Uri? webSource;
  final ModHost host;

  ModData({
    required this.projectId,
    required this.name,
    required this.versionId,
    required this.version,
    required this.source,
    required this.webSource,
    required this.host,
  });

  Future<List<String>> get getVersionIdList => host.getModVersions(projectId);

  String toJson() {
    return const JsonEncoder().convert({
      "versionId": versionId,
      "version": version,
      "source": source.toString(),
      "webSource": webSource.toString(),
      "host": host.apiSource.toString(),
      "name": name,
      "projectId": projectId,
    });
  }
}

abstract class ModHost {
  Uri get apiSource;

  Uri get webSource;

  Future<Map<String, dynamic>?> _getModProjectData(String modId);

  Future<List<String>> getModVersions(String modId);

  Future<ModData> getModData(String modId, String version);
}

class CurseforgeModHost extends ModHost {
  @override
  Uri get apiSource => Uri.parse("https://api.curseforge.com/v1/");

  @override
  Uri get webSource => Uri.parse("https://www.curseforge.com/");

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
  Uri get webSource => Uri.parse("https://modrinth.com/");

  String get _projectScheme => "${apiSource.toString()}project/";

  @override
  Future<Map<String, dynamic>?> _getModProjectData(String modId) async {
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

  Future<ModData?> modDataFromFile(String sha1) async {
    Response req = await get(
        Uri.parse("${apiSource.toString()}version_file/$sha1"),
        headers: headers);
    String body = req.body;
    try {
      dynamic data = jsonDecode(body);
      return ModData(
          projectId: data["project_id"],
          versionId: data["id"],
          name: data["name"],
          version: data["version_number"],
          source: Uri.parse("$_projectScheme${data["project_id"]}"),
          webSource:
              Uri.parse("${webSource.toString()}project/${data["project_id"]}"),
          host: this);
    } catch (e) {
      return null;
    }
  }
}
