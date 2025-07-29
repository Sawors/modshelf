import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:modshelf/dev/mod_host.dart';

import '../tools/cache.dart';
import '../tools/core/core.dart';

Future<void> checkForUpdates(List<File> files) async {
  final modHost = ModrinthModHost();
  List<String> shaList = [];
  stdout.writeln("Listing mods...");
  for (File f in files) {
    if (!(await FileSystemEntity.isFile(f.path) && f.path.endsWith(".jar"))) {
      continue;
    }
    final sha = sha1.convert(await f.readAsBytes()).toString();
    stdout.writeln("Hashing ${f.uri.pathSegments.last}...");
    shaList.add(sha);
  }
  final List<Uri> requestQueue = [];
  final Map<String, ModData> localData = {};
  for (var sha1 in shaList) {
    final cacheKey = NamespacedKey(ModrinthModHost.fileMatchNamespace, sha1);
    final jsonSource = CacheManager.instance.getCachedValue(cacheKey);
    final reqUri =
        Uri.parse("${modHost.apiSource.toString()}version_file/$sha1");
    if (jsonSource == null || jsonSource.isEmpty) {
      requestQueue.add(reqUri);
    } else {
      final md = modHost.modDataFromJson(jsonSource);
      if (md == null) {
        requestQueue.add(reqUri);
      } else {
        localData[md.projectId] = md;
      }
    }
  }
  final fetchResult = await modHost.batchRequests(requestQueue).map((r) {
    final body = r.body;
    if (body.isEmpty) {
      return null;
    }
    final md = modHost.modDataFromJson(body);
    return md;
  }).toList();
  localData
      .addEntries(fetchResult.nonNulls.map((d) => MapEntry(d.projectId, d)));

  final baseInstall =
      await ModpackData.fromInstallation(files.first.parent, recursePath: true);
  stdout.writeln("Checking for updates...");
  String outputStr = "";
  await for (var response in modHost.batchRequests(localData.values.map((d) {
    final List<dynamic> loaders = (d.jsonData["loaders"] as List<dynamic>)
            .contains(baseInstall.manifest.modLoader)
        ? ["\"${baseInstall.manifest.modLoader}\""]
        : d.jsonData["loaders"];
    final txt =
        "${modHost.apiSource.toString()}project/${d.projectId}/version?game_versions=[\"${baseInstall.manifest.gameVersion}\"]&loaders=$loaders";

    return Uri.parse(txt);
  }))) {
    final data = jsonDecode(response.body);
    if (data is List<dynamic>) {
      final sorted = data.sortedByCompare(
          (v) => DateTime.parse(v["date_published"]),
          (d1, d2) => d1.compareTo(d2));
      if (sorted.isEmpty) {
        continue;
      }
      final latest = sorted.last;
      final localRef = localData[latest["project_id"]];
      final url =
          "${modHost.webSource.toString()}mod/${latest["project_id"]}/version/${latest["id"]}";
      if (latest["id"] != localRef?.versionId) {
        outputStr += "$url\n";
        stdout.writeln(
            "[update] ${latest["files"][0]["filename"]?.toString().replaceAll(".jar", "")} : ${localRef?.version} -> ${latest["version_number"]} ($url)");
      }
    }
  }
  stdout.writeln(outputStr);
}

Future<void> updateModrinthCache(ModpackData install) async {
  if (!install.isInstalled) {
    throw StateError("modpack is not installed");
  }
  final modsDir = Directory("${install.installDir?.path}/${DirNames.mods}");
  stdout.writeln("Listing files...");
  final files = await modsDir
      .list(recursive: false)
      .where((f) =>
          FileSystemEntity.isFileSync(f.path) &&
          !f.uri.pathSegments.last.startsWith("."))
      .map((f) => f as File)
      .toList();
  stdout.writeln("Done !");
  stdout.writeln("Getting mod data from files...");
  final mds = await ModrinthModHost().modDataFromFile2(files, useCache: true);
  stdout.writeln("Done !");
  stdout.writeln("Fetching projects...");
  await ModrinthModHost().getMultipleProjects(
      mds.values.nonNulls.map((md) => md.projectId).toList());
  stdout.writeln("Done !");
  await CacheManager.instance.saveCache();
  CacheManager.instance.saveCache();
}
