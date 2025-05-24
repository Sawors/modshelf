import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:modshelf/tools/engine/package.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

final Map<String, dynamic> cache = {};
const int cacheLifetimeMinutes = 60 * 24;
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

  print('Serving at https://${server.address.host}:${server.port}');
}

dynamic getFromCache(String entryKey, dynamic Function() ifNotFound) {
  final val = cache[entryKey] ??
      () {
        final vt = ifNotFound();
        cache[entryKey] = vt;
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

Response entryPoint(Request request) {
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
      meta.version = params["v"];
    }
  } on IndexError {
    return defaultResponse;
  }

  if (meta.version == null) {
    final String action = params["a"] ?? "";
    return handleAction(action, meta, request) ?? defaultResponse;
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
      cache[contentCacheKey] = ct;
      return ct;
    });

    if (contentPath == "content" && (params.isEmpty || params["c"] != "raw")) {
      headers.addAll(meta.packagingHeaders);
      return Response.ok(
          content.toContentString(
              meta.toUri(includeVersion: false, isApi: false).path),
          headers: headers);
    }
    final PatchEntry? searchedEntry =
        content.content.firstWhereOrNull((v) => v.relativePath == contentPath);
    if (searchedEntry != null) {
      return Response.found(
          "${reqUri.scheme}://${reqUri.host}${searchedEntry.relativePath}",
          headers: headers);
    }
  }

  return Response.found(newLoc, headers: headers);
}

Response? handleAction(
    String action, PackMeta packMeta, Request sourceRequest) {
  final params = sourceRequest.requestedUri.queryParameters;
  final Map<String, Object> headers = Map.from(sourceRequest.headers);
  switch (action) {
    case "patch":
      final String fromV = params["f"] ?? "";
      final String toV = params["t"] ?? "";
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
        cache[metaFrom.contentCacheKey] = ct;
        return ct;
      });
      final ContentSnapshot contentTo =
          getFromCache(metaTo.contentCacheKey, () {
        File contentFile = File(
            "$localBasePath/${metaTo.game}/${metaTo.packId}/${metaTo.version}/content"
                .replaceAll("/..", "")
                .replaceAll("/.", ""));
        final ct =
            ContentSnapshot.fromContentString(contentFile.readAsStringSync());
        cache[metaTo.contentCacheKey] = ct;
        return ct;
      });
      final Patch patch = Patch.difference(contentFrom, contentTo,
          versionOverride: "$fromV-$toV");
      headers.addAll(packMeta.withVersion(patch.version).packagingHeaders);
      final String res = ContentSnapshot(
              patch
                  .onlyChanged()
                  .map((v) => v.getSignificant())
                  .where((v) => v.version != fromV)
                  .toSet(),
              patch.version)
          .toContentString(packMeta
              .withVersion(patch.version)
              .toUri(includeVersion: false, isApi: false)
              .path);
      return Response.ok(res, headers: headers);
  }
  return null;
}
