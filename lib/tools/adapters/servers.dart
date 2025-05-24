import 'dart:convert';

import 'package:http/http.dart';
import 'package:modshelf/tools/core/pack_config.dart';

import '../cache.dart';
import '../core/core.dart';
import '../core/manifest.dart';
import '../engine/package.dart';

class ModpackDownloadData {
  final Manifest manifest;
  final PackConfig config;
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

  Future<Manifest> fetchConfig(NamespacedKey modpackId, String version,
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
    if (useCache) {
      String? manStr = CacheManager.getCachedValue(
          Manifest.cacheKeyFromString(modpackId, version));
      if (manStr != null) {
        return Manifest.fromJsonString(manStr);
      }
    }

    String latestPath =
        "$host/${mappings.api}/${modpackId.toPath()}/$version/${DirNames.fileManifest}";
    Response rp = await get(Uri.parse(latestPath));
    String result = rp.body;
    Manifest manifest = Manifest.fromJsonString(result);
    if (useCache) {
      CacheManager.setCachedValue(
          Manifest.cacheKeyFromString(modpackId, version),
          manifest.asJsonString());
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
    Manifest manifest = await fetchManifest(modpackId, version);
    Uri archivePath = Uri.parse(
        "$host/${mappings.api}/${modpackId.toPath()}/$version/${mappings.content}");
    Uri contentPath =
        Uri.parse("$host/${modpackId.toPath()}/$version/${mappings.content}");
    Response rep = await get(contentPath);
    ContentSnapshot entries = ContentSnapshot.fromContentString(rep.body);
    int totalSize = entries.content.fold(0, (v1, v2) => v1 + v2.size);
    return ModpackDownloadData(manifest, archivePath, totalSize, PackConfig(),
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
    Uri archivePath =
        Uri.parse("$host/${modpackId.toPath()}/$version/${mappings.content}");
    Response resp = await get(archivePath);
    return ContentSnapshot.fromContentString(resp.body);
  }

  @override
  Uri get host => Uri.parse("https://sawors.net/modshelf");

  @override
  Future<Manifest> fetchConfig(NamespacedKey modpackId, String version,
      {bool useCache = true}) {
    // TODO: implement fetchConfig
    throw UnimplementedError();
  }
}
