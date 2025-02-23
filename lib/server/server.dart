import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
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

  print('Serving at http://${server.address.host}:${server.port}');
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

class ContentEntry {
  late final String rc32;
  late final String size;
  late final String path;
  late final String relativeFileName;

  ContentEntry(this.rc32, this.size, this.path, this.relativeFileName);

  ContentEntry.fromString(String line) {
    List<String> split = line.split(" ");
    split = split.where((v) => v.isNotEmpty).toList();
    rc32 = split.elementAtOrNull(0) ?? "";
    size = split.elementAtOrNull(1) ?? "0";
    path = split.elementAtOrNull(2) ?? "/";
    relativeFileName = split.elementAtOrNull(3) ?? "/";
  }

  @override
  String toString() {
    return "$rc32 $size $path $relativeFileName";
  }
}

Response entryPoint(Request request) {
  // path always look like "modshelf", "api", [game], [pack-id], {[version], [content...]}
  final Uri reqUri = request.requestedUri;
  final Map<String, String> params = request.url.queryParameters;
  final List<String> path = reqUri.pathSegments;

  String? game = path.elementAtOrNull(2);
  String? packId = path.elementAtOrNull(3);
  String? versionPath = path.elementAtOrNull(4) ?? params["v"];
  String? contentPath = path.length >= 5 ? path.sublist(5).join("/") : null;

  Map<String, String> headers = Map.from(request.headers);

  final newLoc =
      Uri.parse(reqUri.toString().replaceFirst("modshelf/api", "modshelf"));

  if (contentPath != null && contentPath.isNotEmpty) {
    final String modpackKey = "$game:$packId.$versionPath";
    final String contentCacheKey = "$modpackKey/content";
    final String entriesCacheKey = "$modpackKey/entries";
    final List<String> content = getFromCache(contentCacheKey, () {
      File contentFile = File(
          "$localBasePath/$game/$packId/$versionPath/content"
              .replaceAll("/..", "")
              .replaceAll("/.", ""));
      List<String> ct = contentFile.readAsLinesSync();
      cache[contentCacheKey] = ct;
      return ct;
    });

    if (contentPath == "content" && (params.isEmpty || params["c"] != "raw")) {
      headers["X-Archive-Files"] = "zip";
      headers["Content-Disposition"] =
          "attachment; filename=$packId-$versionPath.zip";
      return Response.ok(content.join("\r\n"), headers: headers);
    }
    final List<ContentEntry> entries = getFromCache(entriesCacheKey, () {
      List<ContentEntry> ct =
          content.map((c) => ContentEntry.fromString(c)).toList();
      cache[entriesCacheKey] = ct;
      return ct;
    });
    final ContentEntry? searchedEntry =
        entries.firstWhereOrNull((v) => v.relativeFileName == contentPath);
    if (searchedEntry != null) {
      return Response.found(
          "${reqUri.scheme}://${reqUri.host}${searchedEntry.path}",
          headers: headers);
    }
  }

  return Response.found(newLoc, headers: headers);
}
