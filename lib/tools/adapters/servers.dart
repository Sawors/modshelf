import 'dart:convert';

import 'package:http/http.dart';
import 'package:modshelf/server/server.dart';
import 'package:modshelf/tools/core/modpack_config.dart';

import '../cache.dart';
import '../core/core.dart';
import '../core/manifest.dart';
import '../engine/package.dart';

class ModpackDownloadData {
  final Manifest manifest;
  final ModpackConfig config;
  final Uri archive;
  final int archiveSize;
  final List<String> versions;

  ModpackDownloadData(this.manifest, this.archive, this.archiveSize,
      this.config, this.versions);
}

class ServerLocation {
  // BE CAREFUL TO NOT END PATHS WITH "/" !!!!!!!!!
  String get content => "content";

  String get api => "api";
}

abstract class ServerAgent {
  ServerLocation get mappings => ServerLocation();

  Uri get host;

  String get serverId;

  Future<Manifest> fetchManifest(NamespacedKey modpackId, String version,
      {bool useCache = true});

  Future<ModpackConfig> fetchConfig(NamespacedKey modpackId, String version,
      {bool useCache = true});

  Future<List<String>> getGames();

  Future<bool> hasModpack(NamespacedKey modpackId);

  Future<List<NamespacedKey>> getModpacks(String game);

  Future<List<NamespacedKey>> getAllModpacks() async {
    List<String> games = await getGames();
    List<NamespacedKey> modpacks = [];
    for (String game in games) {
      modpacks.addAll(await getModpacks(game));
    }
    return modpacks;
  }

  Future<List<String>> fetchVersions(NamespacedKey modpackId);

  Future<String> getLatestVersion(NamespacedKey modpackId);

  Future<ModpackDownloadData> getDownloadData(
      NamespacedKey modpackId, String version);

  Future<ContentSnapshot> getContent(NamespacedKey modpackId, String version);

  Uri modpackIdToUri(NamespacedKey modpackId, {bool asApi = false}) {
    return Uri.parse(
        "${asApi ? "$host/${mappings.api}" : host}/${modpackId.toPath()}");
  }

  NamespacedKey modpackUriToId(Uri modpackBaseUri) {
    List<String> split = modpackBaseUri
        .toString()
        .replaceFirst("$host/${mappings.api}", "")
        .replaceFirst(host.toString(), "")
        .split("/")
        .where((v) => v.isNotEmpty)
        .toList();
    return NamespacedKey(split[0], split[1]);
  }

  Future<String?> hasUpgrade(Manifest manifest);
}

// class DynamicServerAgent extends ServerAgent {
//   DynamicServerAgent(String json) {
//
//   }
// }

class ModshelfServerAgent extends ServerAgent {
  @override
  Future<Manifest> fetchManifest(NamespacedKey modpackId, String version,
      {bool useCache = true}) async {
    final vString = Version.fromString(version).toString(shortened: false);
    if (useCache) {
      String? manStr = CacheManager.instance
          .getCachedValue(Manifest.cacheKeyFromString(modpackId, vString));
      if (manStr != null) {
        return Manifest.fromJsonString(manStr);
      }
    }

    String latestPath =
        "$host/${mappings.api}/${modpackId.toPath()}/$vString/${DirNames.fileManifest}";
    Response rp = await get(Uri.parse(latestPath));
    String result = rp.body;
    Manifest manifest = Manifest.fromJsonString(result);
    if (useCache) {
      CacheManager.instance.setCachedValue(
          Manifest.cacheKeyFromString(modpackId, vString),
          manifest.toJsonString());
    }
    return manifest;
  }

  @override
  Future<List<String>> fetchVersions(NamespacedKey modpackId) async {
    Response rp =
        await get(Uri.parse("$host/${mappings.api}/${modpackId.toPath()}"));
    final content = rp.body;
    final List<dynamic> jsonObject = jsonDecode(content);
    final List<String> versions = [];
    for (var obj in jsonObject) {
      if (obj is Map<String, dynamic>) {
        final name = obj["name"].toString();
        final type = obj["type"].toString();
        if (type == "directory") {
          try {
            versions.add(name);
          } on FormatException {
            // ignoring, just not appending it
          }
        }
      }
    }
    return versions;
  }

  @override
  Future<List<String>> getGames() async {
    Response rp = await get(Uri.parse("$host/${mappings.api}"));
    final content = rp.body;
    final List<dynamic> jsonObject = jsonDecode(content);
    final List<String> modpacks = [];
    for (var obj in jsonObject) {
      if (obj is Map<String, dynamic>) {
        final name = obj["name"].toString();
        final type = obj["type"].toString();
        if (type == "directory") {
          modpacks.add(name);
        }
      }
    }
    return modpacks;
  }

  @override
  Future<List<NamespacedKey>> getModpacks(String game) async {
    Response rp =
        await get(Uri.parse("$host/${mappings.api}/${game.toLowerCase()}"));
    final content = rp.body;
    final List<dynamic> jsonObject = jsonDecode(content);
    final List<NamespacedKey> modpacks = [];
    for (var obj in jsonObject) {
      if (obj is Map<String, dynamic>) {
        final name = obj["name"].toString();
        final type = obj["type"].toString();
        if (type == "directory") {
          modpacks.add(NamespacedKey(game.toLowerCase(), name));
        }
      }
    }
    return modpacks;
  }

  @override
  Future<String> getLatestVersion(NamespacedKey modpackId) async {
    List<String> versions = await fetchVersions(modpackId);
    versions.sort((v1, v2) {
      Version? v1v = Version.tryFromString(v1) ?? Version.zero();
      Version? v2v = Version.tryFromString(v2) ?? Version.zero();
      return v1v.compareTo(v2v);
    });
    return versions.last;
  }

  @override
  Future<ModpackDownloadData> getDownloadData(
      NamespacedKey modpackId, String version) async {
    final vString = Version.fromString(version).toString(shortened: false);
    Manifest manifest = await fetchManifest(modpackId, vString);
    Uri archivePath = Uri.parse(
        "$host/${mappings.api}/${modpackId.toPath()}/$vString/${mappings.content}");
    Uri contentPath =
        Uri.parse("$host/${modpackId.toPath()}/$vString/${mappings.content}");
    Response rep = await get(contentPath);
    ContentSnapshot entries = ContentSnapshot.fromContentString(rep.body);
    int totalSize = entries.content.fold(0, (v1, v2) => v1 + v2.size);
    final configResponse = await fetchConfig(modpackId, version);
    return ModpackDownloadData(manifest, archivePath, totalSize, configResponse,
        await fetchVersions(modpackId));
  }

  @override
  String get serverId => "modshelf-official";

  @override
  Future<bool> hasModpack(NamespacedKey modpackId) async {
    Uri packPath = Uri.parse("$host/${mappings.api}/${modpackId.toPath()}");
    Response resp = await get(packPath);
    return resp.statusCode < 400;
  }

  @override
  Future<ContentSnapshot> getContent(
      NamespacedKey modpackId, String version) async {
    Uri archivePath = Uri.parse(
        "$host/${modpackId.toPath()}/${Version.fromString(version).toString(shortened: false)}/${mappings.content}");
    Response resp = await get(archivePath);
    return ContentSnapshot.fromContentString(resp.body);
  }

  @override
  Uri get host => Uri.parse("https://sawors.net/modshelf");

  @override
  Future<ModpackConfig> fetchConfig(NamespacedKey modpackId, String version,
      {bool useCache = false}) async {
    if (useCache) {
      String? confStr = CacheManager.instance.getCachedValue(
          ModpackConfig.cacheKeyFromString(modpackId,
              Version.fromString(version).toString(shortened: false)));
      if (confStr != null) {
        return ModpackConfig.fromJsonString(confStr);
      }
    }

    String latestPath =
        "$host/${mappings.api}/${modpackId.toPath()}/${Version.fromString(version).toString(shortened: false)}/${DirNames.fileConfig}";
    Response rp = await get(Uri.parse(latestPath));
    String result = rp.body;
    ModpackConfig config = ModpackConfig.fromJsonString(result);
    if (useCache) {
      CacheManager.instance.setCachedValue(
          ModpackConfig.cacheKeyFromString(modpackId,
              Version.fromString(version).toString(shortened: false)),
          config.toJsonString());
    }
    return config;
  }

  Uri generatePatchUri(
      NamespacedKey packId, String fromVersion, String toVersion,
      {bool onlyContent = true}) {
    return Uri.parse(
        "$host/api/${packId.namespace}/${packId.key}?a=${onlyContent ? "patch-content" : "patch"}&f=${Version.fromString(fromVersion).toString(shortened: false)}&t=${Version.fromString(toVersion).toString(shortened: false)}");
  }

  @override
  Future<String?> hasUpgrade(Manifest manifest) {
    return getLatestVersion(manifest.packId).then((latest) {
      Version oldVersion = Version.fromString(manifest.version);
      Version? latestCheck = Version.tryFromString(latest);
      if (latestCheck != null && latestCheck.compareTo(oldVersion) > 0) {
        return latest;
      }
      return null;
    });
  }

  Future<Patch> requestPatchContent(NamespacedKey packId,
      ModpackConfig? localConfig, String fromVersion, String toVersion) {
    final req = PatchRequest(
        fromVersion: fromVersion, toVersion: toVersion, config: localConfig);
    final uri = modpackIdToUri(packId, asApi: true)
        .replace(queryParameters: {"action": "patch-content"});
    return post(uri, body: req.toJson()).then((v) {
      final jsonResult = (jsonDecode(v.body) as List<dynamic>);
      return Patch.fromJsonObject(jsonResult,
          versionOverride: toVersion, firstVersionOverride: fromVersion);
    });
  }
}
