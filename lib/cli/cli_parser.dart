import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:modshelf/dev/mod_host.dart';
import 'package:modshelf/tools/adapters/servers.dart';
import 'package:modshelf/tools/core/core.dart';

import '../tools/core/manifest.dart';
import '../tools/engine/package.dart';

Future<void> runCli(List<String> args) async {
  main(args);
}

Future<Patch> package(Directory source,
    {bool asPatch = true,
    ServerAgent? server,
    ContentSnapshot? oldContentOverride}) async {
  File manFile = File("${source.path}/${DirNames.fileManifest}");
  Manifest manifest = Manifest.fromJsonString(await manFile.readAsString());
  ContentSnapshot oldContent = oldContentOverride ?? ContentSnapshot({}, "0");
  String oldVersion = "0";
  if (oldContentOverride == null &&
      asPatch &&
      server != null &&
      await server.hasModpack(manifest.packId)) {
    oldVersion = await server.getLatestVersion(manifest.packId);
    oldContent = await server.getContent(manifest.packId, oldVersion);
  }
  ContentSnapshot newContent =
      await ContentSnapshot.fromDirectory(source, manifest.version);
  return Patch.difference(oldContent, newContent);
}

Future<Archive> asArchive(Patch patch, Directory fileSource,
    ServerAgent buildTarget, NamespacedKey modpackId) async {
  ContentSnapshot ct = patch.asContentSnapshot();
  Archive arch = Archive();
  for (PatchEntry entry in ct.asFiltered(onlyLatest: true).content) {
    File sourceFile = File("${fileSource.path}${entry.relativePath}");
    print(sourceFile.path);
    if (!await sourceFile.exists()) {
      continue;
    }
    arch.addFile(ArchiveFile(
        entry.relativePath.replaceAll(".modshelf", "modshelf"),
        entry.size,
        await sourceFile.readAsBytes()));
  }
  List<int> contentBytes = const Utf8Encoder().convert(ct
      .toContentString(buildTarget.modpackIdToUri(modpackId, asApi: false).path)
      .replaceAll(".modshelf", "modshelf"));

  arch.add(ArchiveFile(
      "/${buildTarget.mappings.content}", contentBytes.length, contentBytes));
  return arch;
}

class InstalledModData {
  final ModData? data;
  final String path;
  final String sha1;

  String get filename => path.split("/").last;

  InstalledModData(
      {required this.data, required this.path, required this.sha1});

  Map<String, dynamic> toJsonMap() {
    final map = {
      "hash": sha1,
    };

    if (data != null) {
      map["name"] = data!.name;
      map["project-id"] = data!.projectId;
      map["version-id"] = data!.versionId;
      map["version"] = data!.version;
      map["host"] = data!.webSource.toString();
    }

    return map;
  }
}

void main(List<String> args) async {
  ModrinthModHost mh = ModrinthModHost();

  Directory installDir = Directory(
      "/home/sawors/.var/app/org.prismlauncher.PrismLauncher/data/PrismLauncher/instances/Tiboise II.V/.minecraft");
  Directory sourceDir = Directory("${installDir.path}/mods/enabled");

  List<InstalledModData> found = [];
  Map<String, List<dynamic>> latestProjectMatch = {};
  File mdInstall =
      File("${installDir.path}/${DirNames.installLocalDir}/modlist.json");

  Map<String, dynamic> savedData = {"found": {}, "not-found": {}};
  if (mdInstall.existsSync()) {
    try {
      savedData = jsonDecode(await mdInstall.readAsString());
    } catch (e) {
      //ignore
    }
  }
  final fileList = sourceDir.listSync(recursive: true);

  print("loading old data");

  for (FileSystemEntity f in fileList) {
    if (!f.path.endsWith(".jar") || !await FileSystemEntity.isFile(f.path)) {
      continue;
    }
    File file = File(f.path);
    final data = await file.readAsBytes();
    final digest = sha1.convert(data);
    final fileName = file.path.split("/").last;

    Map<String, dynamic>? oldData = savedData["found"][fileName];
    ModData? modData;
    if (oldData != null && oldData["hash"] == digest.toString()) {
      modData = ModData(
          projectId: oldData["project-id"],
          versionId: oldData["version-id"],
          name: oldData["name"],
          version: oldData["version"],
          source: Uri.parse(oldData["host"]),
          webSource: Uri.parse(oldData["host"]),
          host: mh);
    }
    found.add(InstalledModData(
        data: modData, path: file.path, sha1: digest.toString()));
  }

  List<InstalledModData> fetchList = [];
  List<InstalledModData> result = [];

  for (InstalledModData ir in found) {
    if (ir.data == null) {
      fetchList.add(ir);
    } else {
      result.add(ir);
    }
  }

  int total = fetchList.length;
  await Future.wait(fetchList.indexed.map((e) {
    print("(${e.$1 + 1}/$total) doing ${e.$2.filename}");
    return mh.modDataFromFile(e.$2.sha1).then((v) {
      result.add(InstalledModData(data: v, path: e.$2.path, sha1: e.$2.sha1));
    });
  }));

  print("done 1");

  await Future.wait(result.indexed.map((e) {
    final pid = e.$2.data?.projectId;
    print("(${e.$1 + 1}/${result.length}) doing VRS ${e.$2.filename}");
    if (pid != null) {
      return mh
          .getModVersions(pid, loader: "fabric", version: "1.20.1")
          .then((v) => latestProjectMatch[pid] = v);
    }
    return Future.value([]);
  }));

  print(result.map((e) => e.data?.name).toList());

  const encoder = JsonEncoder.withIndent("  ");

  for (InstalledModData ir in result) {
    if (ir.data != null) {
      savedData["found"][ir.filename] = ir.toJsonMap();
    } else {
      savedData["not-found"][ir.filename] = ir.toJsonMap();
    }
  }

  String jsonOutput = encoder.convert(savedData);
  await mdInstall.create(recursive: true);
  await mdInstall.writeAsString(jsonOutput);

  String output = "";

  int nameWidth = result.map<int>((e) => e.filename.length).max;

  for (InstalledModData imd in result) {
    ModData? md = imd.data;
    if (md == null) {
      output += "Not Found  | ${imd.filename}\n";
      continue;
    }
    final vrs = latestProjectMatch[md.projectId] ?? [];
    if (vrs.isEmpty) {
      output += "Not Found  | (VRS) ${imd.filename}\n";
      continue;
    }
    vrs.sort((v1, v2) {
      String vn1 = v1["version_number"];
      String vn2 = v2["version_number"];

      return compareNatural(vn2, vn1);
    });
    final latest = vrs.first["version_number"];
    String verUrl = "";
    bool upgradable = md.version != latest;
    String printed = "${imd.filename.padRight(nameWidth)} : ${md.version}";
    if (upgradable) {
      verUrl = mh
          .webSourceForVersion(vrs.first["project_id"], vrs.first["id"])
          .toString();
      printed = "UPGRADABLE | $printed => $latest [$verUrl]";
    } else {
      printed = "           | $printed";
    }
    output += "$printed\n";
  }
  print(output);
  await File(
          "${installDir.path}/${DirNames.installLocalDir}/upgrades_report.txt")
      .writeAsString(output);
}
