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

  final Map<String, dynamic> jsonData = {};

  ModData({
    required this.projectId,
    required this.name,
    required this.versionId,
    required this.version,
    required this.source,
    required this.webSource,
    required this.host,
  });

  Future<List<dynamic>> get getVersionIdList => host.getModVersions(projectId);

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

class ProjectData {
  final ModHost host;

  final Map<String, dynamic> jsonData;

  String get projectId => jsonData["slug"];

  String get name => jsonData["title"];

  Uri get source => host.apiSourceForProject(projectId);

  Uri get webSource => host.webSourceForProject(projectId);

  List<String> get versions => jsonData["versions"];

  ProjectData({required this.jsonData, required this.host});
}

abstract class ModHost {
  Uri get apiSource;

  Uri get webSource;

  Uri apiSourceForProject(String projectId);

  Uri webSourceForProject(String projectId);

  Uri apiSourceForVersion(String projectId, String version);

  Uri webSourceForVersion(String projectId, String version);

  Future<Map<String, dynamic>?> _getModProjectData(String modId);

  Future<List<dynamic>> getModVersions(String modId);

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
  Future<List<Map<String, dynamic>>> getModVersions(String modId) async {
    // TODO: implement getModVersions
    throw UnimplementedError();
  }

  @override
  Uri apiSourceForProject(String projectId) {
    // TODO: implement apiSourceForProject
    throw UnimplementedError();
  }

  @override
  Uri apiSourceForVersion(String projectId, String version) {
    // TODO: implement apiSourceForVersion
    throw UnimplementedError();
  }

  @override
  Uri webSourceForProject(String projectId) {
    // TODO: implement webSourceForProject
    throw UnimplementedError();
  }

  @override
  Uri webSourceForVersion(String projectId, String version) {
    // TODO: implement webSourceForVersion
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
  Future<ProjectData?> getProjectData(String projectId) async {
    Uri source = Uri.parse("${apiSource.toString()}project/$projectId");
    Response req = await get(source, headers: headers);
    String body = req.body;

    if (body.isEmpty) {
      return null;
    }

    try {
      dynamic data = jsonDecode(body);
      return ProjectData(host: this, jsonData: data);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<dynamic>> getModVersions(String modId,
      {String? loader, String? version}) async {
    List<String> params = [];
    if (version != null) {
      params.add("game_versions=[\"$version\"]");
    }
    if (loader != null) {
      params.add("loaders=[\"$loader\"]");
    }
    Uri target = Uri.parse(
        "${apiSource.toString()}project/$modId/version${params.isNotEmpty ? '?${params.join('&')}' : ''}");
    Response req = await get(target, headers: headers);
    String body = req.body;
    try {
      dynamic data = jsonDecode(body);
      if (data is List<dynamic>) {
        return data;
      }
    } catch (e) {
      // ignore and return default
    }
    return [];
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
          source: apiSourceForProject(data["project_id"]),
          webSource: webSourceForProject(data["project_id"]),
          host: this);
    } catch (e) {
      return null;
    }
  }

  @override
  Uri apiSourceForProject(String projectId) {
    return Uri.parse("$_projectScheme$projectId");
  }

  @override
  Uri apiSourceForVersion(String projectId, String version) {
    // TODO: implement apiSourceForVersion
    throw UnimplementedError();
  }

  @override
  Uri webSourceForProject(String projectId) {
    return Uri.parse("${webSource.toString()}project/$projectId");
  }

  @override
  Uri webSourceForVersion(String projectId, String version) {
    return Uri.parse(
        "${webSource.toString()}project/$projectId/version/$version");
  }
}
