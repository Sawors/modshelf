import 'dart:convert';
import 'dart:core';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart';
import 'package:modshelf/tools/cache.dart';
import 'package:modshelf/tools/core/core.dart';

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
  static const String fileMatchNamespace = "modrinth-file-matches";
  static const String projectMatchNamespace = "modrinth-project-matches";
  static const String versionMatchNamespace = "modrinth-version-matches";

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

  ModData? modDataFromJsonMap(Map<String, dynamic> data) {
    try {
      final md = ModData(
          projectId: data["project_id"],
          versionId: data["id"],
          name: data["name"],
          version: data["version_number"],
          source: apiSourceForProject(data["project_id"]),
          webSource: webSourceForProject(data["project_id"]),
          host: this);
      md.jsonData.addAll(data);
      return md;
    } catch (e) {
      return null;
    }
  }

  ModData? modDataFromJson(String json) {
    final data = jsonDecode(json);
    return modDataFromJsonMap(data);
  }

  Future<ProjectData?> getProjectData(String projectId,
      {bool useCache = true}) async {
    String? jsonBody;
    final projectKey = NamespacedKey(projectMatchNamespace, projectId);
    if (useCache) {
      jsonBody = CacheManager.instance.getCachedValue(projectKey);
    }
    if (jsonBody == null || jsonBody.isEmpty) {
      Uri source = Uri.parse("${apiSource.toString()}project/$projectId");
      Response req = await get(source, headers: headers);
      jsonBody = req.body;
      if (useCache) {
        CacheManager.instance.setCachedEntry(projectKey,
            CacheEntry(jsonBody, lifetime: const Duration(hours: 2)));
      }
    }

    if (jsonBody.isEmpty) {
      return null;
    }

    try {
      dynamic data = jsonDecode(jsonBody);
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

  NamespacedKey projectVersionCacheKey(String versionId) {
    return NamespacedKey(versionMatchNamespace, versionId);
  }

  Future<Map<File, ModData?>> modDataFromFile2(List<File> files,
      {bool useCache = true}) async {
    Map<File, ModData?> result =
        Map.fromEntries(files.map((f) => MapEntry(f, null)));
    Map<String, File> hashes = Map.fromEntries(await Future.wait(files.map(
        (f) => f
            .readAsBytes()
            .then((r) => MapEntry(sha1.convert(r).toString(), f)))));
    if (useCache) {
      Set<String> cachedHashes = {};
      for (var entry in hashes.entries) {
        final hash = entry.key;
        final cacheKey = NamespacedKey(fileMatchNamespace, hash);
        final versionMatch = CacheManager.instance.getCachedEntry(cacheKey);
        if (versionMatch == null ||
            versionMatch.value == null ||
            versionMatch.isExpired) {
          continue;
        }
        print("  cache hit $hash => ${versionMatch.value}");
        final jsonSource = CacheManager.instance.getCachedEntry(
            NamespacedKey(versionMatchNamespace, versionMatch.value));
        if (jsonSource == null ||
            jsonSource.value == null ||
            jsonSource.isExpired) {
          continue;
        }
        try {
          final md = modDataFromJson(jsonSource.value);
          if (md != null) {
            result[entry.value] = md;
            cachedHashes.add(hash);
          }
        } catch (_) {
          // ignored
        }
      }
      hashes.removeWhere((h, f) => cachedHashes.contains(h));
    }
    final reqBody = {"hashes": hashes.keys.toList(), "algorithm": "sha1"};
    final resp = await post(Uri.parse("${apiSource.toString()}version_files"),
        body: jsonEncode(reqBody),
        headers: {...headers, "Content-Type": "application/json"});
    if (resp.statusCode != 200) {
      throw const FormatException(
          "Request is not correctly formatted, report this to the Modshelf developer.");
    }
    final jsonResp = jsonDecode(resp.body) as Map<String, dynamic>;
    for (var entry in jsonResp.entries) {
      final fileMatch = hashes[entry.key];
      if (fileMatch == null) {
        continue;
      }
      final md = modDataFromJsonMap(entry.value);
      result[fileMatch] = md;
    }
    if (useCache) {
      for (var hashMatch in hashes.entries) {
        final cacheKey = NamespacedKey(fileMatchNamespace, hashMatch.key);
        final res = result[hashMatch.value];
        CacheManager.instance
            .setCachedEntry(cacheKey, CacheEntry.immortal(res?.versionId));
        if (res != null) {
          CacheManager.instance.setCachedEntry(
              projectVersionCacheKey(res.versionId),
              CacheEntry.immortal(res.jsonData));
        }
      }
    }
    return result;
  }

  Future<Map<String, dynamic>> getMultipleProjects(List<String> projectIds,
      {bool useCache = true}) async {
    final Map<String, dynamic> result = {};
    List<String> filteredIds = projectIds;
    if (useCache) {
      List<String> cacheRetrieved = [];
      for (String v in projectIds) {
        final cacheKey = NamespacedKey(projectMatchNamespace, v);
        final cacheEntry = CacheManager.instance.getCachedEntry(cacheKey);
        if (cacheEntry != null &&
            !cacheEntry.isExpired &&
            cacheEntry.value != null) {
          result[v] = cacheEntry.value;
          cacheRetrieved.add(v);
        }
      }
      filteredIds.removeWhere((i) => cacheRetrieved.contains(i));
    }
    final resp = await get(
        Uri.parse("${apiSource.toString()}projects")
            .replace(queryParameters: {"ids": jsonEncode(filteredIds)}),
        headers: headers);
    final body = jsonDecode(resp.body) as List<dynamic>;
    if (resp.statusCode != 200) {
      throw const FormatException(
          "Request is not correctly formatted, report this to the Modshelf developer.");
    }
    result.addEntries(body.map((v) => MapEntry(v["id"], v)));
    if (useCache) {
      for (var entry in body) {
        if (entry == null) {
          continue;
        }
        final id = entry["id"];
        final cacheKey = NamespacedKey(projectMatchNamespace, id);
        CacheManager.instance
            .setCachedEntry(cacheKey, CacheEntry.immortal(entry));
      }
    }
    return result;
  }

  Future<ModData?> modDataFromFile(String sha1, {bool useCache = true}) async {
    String? jsonSource;
    final cacheKey = NamespacedKey(fileMatchNamespace, sha1);
    try {
      jsonSource = CacheManager.instance.getCachedValue(cacheKey);
      if (jsonSource == null || jsonSource.isEmpty) {
        Response req = await get(
            Uri.parse("${apiSource.toString()}version_file/$sha1"),
            headers: headers);
        jsonSource = req.body;
      }
      final md = modDataFromJson(jsonSource);
      if (useCache) {
        CacheManager.instance
            .setCachedEntry(cacheKey, CacheEntry.immortal(jsonSource));
        if (md != null) {
          CacheManager.instance.setCachedEntry(
              projectVersionCacheKey(md.versionId),
              CacheEntry.immortal(jsonSource));
        }
      }
      return md;
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

  Stream<Response> batchRequests(Iterable<Uri> requests,
      {verbose = false}) async* {
    final Client client = Client();
    try {
      final res1 = await client.get(apiSource);
      final int requestLimit =
          int.tryParse(res1.headers["x-ratelimit-remaining"] ?? "") ?? 2;
      final int batchSize = requestLimit - 1;
      final slices = requests
          .map((u) => client.get(u, headers: headers))
          .slices(batchSize);
      if (verbose) {
        stdout.writeln(
            "Using a batch size of $batchSize resulting in ${slices.length} slices");
      }
      final int total = requests.length;
      final int totalStrLength = total.toString().length;
      int done = 0;
      for (var slice in slices) {
        Response? last;
        await for (var res in Stream.fromFutures(slice)) {
          done++;
          last = res;
          if (verbose) {
            stdout.writeln(
                "(${done.toString().padLeft(totalStrLength, "0")}/$total) ${res.request?.url.toString()}");
          }
          yield res;
        }
        final int delay =
            int.tryParse(last?.headers["x-ratelimit-reset"] ?? "") ?? 60;
        final waitTime = Duration(milliseconds: (delay * 1000) + 50);
        if (verbose) {
          stdout.writeln(
              "Waiting ${waitTime.inSeconds}s to avoid being rate-limited.");
        }
        await Future.delayed(waitTime);
      }
    } finally {
      client.close();
    }
  }
}
