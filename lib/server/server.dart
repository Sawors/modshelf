import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:modshelf/tools/core/core.dart';
import 'package:modshelf/tools/core/modpack_config.dart';
import 'package:modshelf/tools/engine/package.dart';
import 'package:modshelf/tools/utils.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

final Map<String, dynamic> cache = {};
const int cacheLifetimeMinutes = 60 * 24 * 2;
const String localBasePath = "/home/light-services/webserver/modshelf";

void main(List<String> args) async {
  var handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler((req) => entryPoint(req));

  Map<String, String?> progArgs = Map.fromEntries(args.map((v) {
    final split = v.split("=");
    return MapEntry(split[0], split.elementAtOrNull(1));
  }));

  var server = await shelf_io.serve(
      handler, '127.0.0.1', int.tryParse(progArgs["--port"] ?? "") ?? 4141);

  Timer.periodic(const Duration(minutes: cacheLifetimeMinutes), (t) {
    cache.clear();
  });

  // Enable content compression
  server.autoCompress = true;

  stdout.writeln('Serving at https://${server.address.host}:${server.port}');
}

dynamic getFromCache(String entryKey, dynamic Function() ifNotFound,
    {cacheIfNotFound = true}) {
  final val = cache[entryKey] ??
      () {
        final vt = ifNotFound();
        if (cacheIfNotFound) {
          cache[entryKey] = vt;
        }
        return vt;
      }();
  return val;
}

class PackMeta {
  final String packId;
  final String game;
  String? version;

  PackMeta({required this.packId, required this.game, this.version});

  PackMeta.fromUri(Uri uri)
      : this(
            packId: uri.pathSegments[3],
            game: uri.pathSegments[2],
            version: uri.pathSegments.elementAtOrNull(4));

  Uri toUri({bool includeVersion = true, bool isApi = false}) => Uri.parse(
      "https://sawors.net/modshelf${isApi ? "/api" : ""}/$game/$packId${version != null && includeVersion ? "/$version" : ""}");

  String get cacheKey => "$game:$packId.$version";

  String get contentCacheKey => "$cacheKey/content";

  String get entriesCacheKey => "$cacheKey/entries";

  PackMeta withVersion(String packVersion) {
    return PackMeta(packId: packId, game: game, version: packVersion);
  }

  Map<String, String> get packagingHeaders => {
        "X-Archive-Files": "zip",
        "Content-Disposition": "attachment; filename=$packId-$version.zip"
      };
}

Future<Response> entryPoint(Request request) async {
  // this function is only run if we go through the API in the Uri.
  // Example :
  // https://sawors.net/modshelf/api/<game>/<pack>/     -> this path leads here
  // https://sawors.net/modshelf/<game>/<pack>/         -> this path does not lead here, nginx takes the request in charge
  // path always look like "modshelf", "api", [game], [pack-id], {[version], [content...]}
  final Uri reqUri = request.requestedUri;
  final Map<String, String> params = request.url.queryParameters;
  final List<String> path = reqUri.pathSegments;
  final newLoc =
      Uri.parse(reqUri.toString().replaceFirst("modshelf/api", "modshelf"));
  final Map<String, Object> headers = Map.from(request.headers);
  final Response defaultResponse =
      Response.found(newLoc, headers: request.headers);

  final PackMeta meta;
  try {
    meta = PackMeta.fromUri(reqUri);
    if (params["v"] != null) {
      meta.version =
          Version.tryFromString(params["v"])?.toString(shortened: false);
    }
  } on RangeError {
    return defaultResponse;
  }

  if (meta.version == null) {
    final String action = params["a"] ?? "";

    return await handleAction(action, meta, request) ?? defaultResponse;
  }

  final String game = meta.game;
  final String packId = meta.packId;
  final String version = meta.version ?? "";
  final String contentPath = path.length >= 5 ? path.sublist(5).join("/") : "";

  if (contentPath.isNotEmpty) {
    final String contentCacheKey = meta.contentCacheKey;
    final ContentSnapshot content = getFromCache(contentCacheKey, () {
      File contentFile = File("$localBasePath/$game/$packId/$version/content"
          .replaceAll("/..", "")
          .replaceAll("/.", ""));
      ContentSnapshot ct =
          ContentSnapshot.fromContentString(contentFile.readAsStringSync());
      return ct;
    });

    print(content.content.map((v) => v.toString()).join("\n") + "\n");

    if (contentPath == "content" && (params.isEmpty || params["c"] != "raw")) {
      headers.addAll(meta.packagingHeaders);
      return Response.ok(
          content.toContentString(
              meta.toUri(includeVersion: false, isApi: false).path),
          headers: headers);
    }
    final PatchEntry? searchedEntry = content.content.firstWhereOrNull(
        (v) => cleanPath(v.relativePath) == cleanPath(contentPath));
    print(contentPath);
    if (searchedEntry != null) {
      print(searchedEntry.relativePath);
      print(searchedEntry.toString());
      print("${reqUri.scheme}://${reqUri.host}${searchedEntry.source?.path}");
      return Response.found(
          "${reqUri.scheme}://${reqUri.host}${searchedEntry.source?.path}",
          headers: headers);
    }
  }

  return Response.found(newLoc, headers: headers);
}

bool? stringParseBool(String? toParse,
    {bool? defaultValue,
    List<String>? trueOverride,
    List<String>? falseOverride}) {
  if (toParse == null || toParse == "null") {
    return defaultValue;
  }
  const List<String> trueLike = ["true", "1", "yes"];
  const List<String> falseLike = ["false", "0", "no"];
  return (trueOverride ?? trueLike).contains(toParse.toLowerCase())
      ? true
      : (falseOverride ?? falseLike).contains(toParse.toLowerCase())
          ? false
          : defaultValue;
}

class PatchRequest {
  final String fromVersion;
  final String toVersion;
  final ModpackConfig? config;

  PatchRequest(
      {required this.fromVersion,
      required this.toVersion,
      required this.config});

  factory PatchRequest.fromJson(String json) {
    final jsonMap = jsonDecode(json);
    return PatchRequest(
        fromVersion: jsonMap["fromVersion"],
        toVersion: jsonMap["toVersion"],
        config: ModpackConfig.fromJsonString(jsonMap["config"]));
  }

  Map<String, dynamic> asMap() {
    return {
      "fromVersion": fromVersion,
      "toVersion": toVersion,
      "config": config?.toJsonString()
    };
  }

  String toJson() {
    return jsonEncode(asMap());
  }
}

Future<Response?> actionPatch(
    PackMeta packMeta, Request sourceRequest, bool asContentString) async {
  final params = sourceRequest.requestedUri.queryParameters;
  final Map<String, Object> headers = Map.from(sourceRequest.headers);
  PatchRequest request;
  final body = await sourceRequest.readAsString();
  try {
    request = PatchRequest.fromJson(body);
  } catch (e) {
    request = PatchRequest(
        fromVersion: params["f"] ?? "",
        toVersion: params["t"] ?? "",
        config: ModpackConfig(
            repository: null,
            type: "empty",
            forceLocal: false,
            bundleInclude: [],
            bundleExclude: [],
            upgradeIgnored: [],
            upgradeIgnoreAddition: [],
            upgradeIgnoreModification: [],
            upgradeIgnoreDeletion: [],
            profiles: {}));
  }
  final String fromV =
      Version.fromString(request.fromVersion).toString(shortened: false);
  final String toV =
      Version.fromString(request.toVersion).toString(shortened: false);
  if (fromV.isEmpty || toV.isEmpty) {
    return null;
  }
  final PackMeta metaFrom = packMeta.withVersion(fromV);
  final PackMeta metaTo = packMeta.withVersion(toV);
  final ContentSnapshot contentFrom =
      getFromCache(metaFrom.contentCacheKey, () {
    File contentFile = File(
        "$localBasePath/${metaFrom.game}/${metaFrom.packId}/${metaFrom.version}/content"
            .replaceAll("/..", "")
            .replaceAll("/.", ""));
    final ct =
        ContentSnapshot.fromContentString(contentFile.readAsStringSync());
    return ct;
  });
  final ContentSnapshot contentTo = getFromCache(metaTo.contentCacheKey, () {
    File contentFile = File(
        "$localBasePath/${metaTo.game}/${metaTo.packId}/${metaTo.version}/content"
            .replaceAll("/..", "")
            .replaceAll("/.", ""));
    final ct =
        ContentSnapshot.fromContentString(contentFile.readAsStringSync());
    return ct;
  });

  final String versionStr = "$fromV-$toV";
  final Patch patch = getFromCache(
      "patch:$versionStr",
      () => Patch.difference(contentFrom, contentTo,
          versionOverride: versionStr));
  final ModpackConfig config;
  final reqConfig = request.config;
  if (reqConfig != null && reqConfig.forceLocal && reqConfig.type != "empty") {
    config = reqConfig;
  } else {
    config = getFromCache("config:$toV", () {
      final configPath = contentTo.content
          .firstWhereOrNull((v) =>
              cleanPath(v.relativePath) == cleanPath(DirNames.fileConfig))
          ?.source;
      if (configPath != null) {
        final configFile = File(
            "$localBasePath/${configPath.pathSegments.sublist(1).join("/")}"
                .replaceAll("/..", "")
                .replaceAll("/.", ""));
        if (configFile.existsSync()) {
          try {
            return ModpackConfig.fromJsonString(configFile.readAsStringSync());
          } catch (_) {
            return request.config;
          }
        }
      }
      return request.config;
    });
  }
  if (asContentString) {
    final res =
        jsonEncode(patch.onlyChanged().map((e) => e.toJsonObject()).toList());
    return Response.ok(res, headers: headers);
  }
  final String res = ContentSnapshot(
          patch
              .onlyChanged()
              .where((v) => config.patchShouldInclude(v))
              .map((v) => v.getSignificant())
              .toSet(),
          patch.version)
      .toContentString(packMeta
          .withVersion(patch.version)
          .toUri(includeVersion: false, isApi: false)
          .path);
  headers.addAll(packMeta.withVersion(patch.version).packagingHeaders);
  return Response.ok(res, headers: headers);
}

Future<Response?> actionGetContent(
    PackMeta packMeta, Request sourceRequest) async {
  final body = await sourceRequest.readAsString();
  final headers = Map.of(sourceRequest.headers);
  final ContentSnapshot ct;
  try {
    ct = ContentSnapshot.fromContentString(body);
  } catch (e) {
    return Response.badRequest(body: e.toString());
  }
  headers.addAll(packMeta.withVersion(ct.version).packagingHeaders);
  // security feature : nothing goes out of the specified domain
  return Response.ok(
      ct.toContentString("modshelf/${packMeta.game}/${packMeta.packId}"),
      headers: headers);
}

Future<Response?> handleAction(
    String action, PackMeta packMeta, Request sourceRequest) async {
  switch (action) {
    case "patch":
    case "patch-content":
      return actionPatch(packMeta, sourceRequest, action == "patch-content");
    case "get":
      return actionGetContent(packMeta, sourceRequest);
  }
  return null;
}
