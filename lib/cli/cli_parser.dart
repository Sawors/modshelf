import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:modshelf/dev/mod_host.dart';
import 'package:modshelf/tools/core/core.dart';
import 'package:modshelf/tools/utils.dart';

import '../tools/engine/package.dart';

abstract class CliAction {
  String get name;

  String get helpMessage;

  Future<int> execute(List<String> args);
}

Future<void> runCli(List<String> args) async {
  await main(args);
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

void updateModlist(Directory installDir, {bool refetch = false}) async {
  ModrinthModHost mh = ModrinthModHost();

  Directory sourceDir =
      Directory("${installDir.path}/modshelf/dev/mods/enabled");

  List<InstalledModData> found = [];
  File mdInstall =
      File("${installDir.path}/${DirNames.installLocalDir}/modlist.json");

  print("loading old data");

  Map<String, dynamic> savedData = {"found": {}, "not-found": {}};
  if (mdInstall.existsSync()) {
    try {
      savedData = jsonDecode(await mdInstall.readAsString());
    } catch (e) {
      //ignore
    }
  }
  final fileList = sourceDir.listSync(recursive: true);

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
    if (!refetch && oldData != null && oldData["hash"] == digest.toString()) {
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
    if (refetch || ir.data == null) {
      fetchList.add(ir);
    } else {
      result.add(ir);
    }
  }

  int total = fetchList.length;

  const batchSize = 16;
  final batches = fetchList.slices(batchSize);

  for (var sliceIndexed in batches.indexed) {
    final slice = sliceIndexed.$2;
    final index = sliceIndexed.$1;

    await Future.wait(slice.indexed.map((e) async {
      final verData = await mh.modDataFromFile(e.$2.sha1);
      if (verData != null) {
        final projId = verData.projectId;
        final project = await mh.getProjectData(projId);
        if (project != null) {
          result.add(InstalledModData(
              data: ModData(
                  projectId: verData.projectId,
                  name: project.name,
                  versionId: verData.versionId,
                  version: verData.version,
                  source: verData.source,
                  webSource: verData.webSource,
                  host: verData.host),
              path: e.$2.path,
              sha1: e.$2.sha1));
        }
      }
    }));
  }

  await Future.wait(fetchList.indexed.map((e) {
    print("(${e.$1 + 1}/$total) doing ${e.$2.filename}");
    return mh.modDataFromFile(e.$2.sha1).then((v) {
      result.add(InstalledModData(data: v, path: e.$2.path, sha1: e.$2.sha1));
    });
  }));
}

Future<void> main(List<String> args) async {
  final String action = args.elementAtOrNull(0) ?? "";
  print(args);

  switch (action.toLowerCase()) {
    case "package":
      {
        final result = CliPackage().execute(args.sublist(1));
      }
    case "install":
      {}
    case _:
      print("Please select an action :\n - package\n - install");
  }
  return;
  ////
  //// CREATE A SNAPSHOT OF THE WHOLE INSTALL AND SAVE IT
  ////
  // print("creating content snapshot...");
  // Directory installDir = Directory(
  //     "/home/sawors/.var/app/org.prismlauncher.PrismLauncher/data/PrismLauncher/instances/Tiboise II.V/.minecraft");
  //
  // ModpackData installed = await ModpackData.fromInstallation(installDir);
  //
  // Patch content = await package(installDir,
  //     server: ModshelfServerAgent(),
  //     oldContentOverride: ContentSnapshot({}, "0"));
  //
  // File outputFile = File(
  //     "${installDir.path}/${DirNames.releases}/${installed.manifest.version}/content");
  // if (!await outputFile.parent.exists()) {
  //   outputFile.parent.create(recursive: true);
  // }
  // outputFile
  //     .writeAsStringSync(content.asContentSnapshot().toContentString("LOCAL"));
  //// SNAPSHOT SAVED

  // // CREATE A SNAPSHOT OF THE WHOLE INSTALL AND SAVE IT
  // //
  // print("creating content snapshot...");
  // Directory releaseDir = Directory("${installDir.path}/${DirNames.releases}");
  // final latest = releaseDir
  //     .listSync()
  //     .sorted((v1, v2) => compareNatural(
  //         v1.path.split(Platform.pathSeparator).last,
  //         v2.path.split(Platform.pathSeparator).last))
  //     .last;
  // File lastContentFile = File("${latest.path}/content");
  //
  // ContentSnapshot oldContent;
  // if (lastContentFile.existsSync()) {
  //   oldContent =
  //       ContentSnapshot.fromContentString(lastContentFile.readAsStringSync());
  // } else {
  //   oldContent = ContentSnapshot({}, "0");
  // }
  //
  // Patch content = await package(installDir,
  //     server: ModshelfServerAgent(), oldContentOverride: oldContent);
  // final diff = content.onlyChanged();
  // print("diff length: ${diff.length}");
  // for (PatchDifference pd in diff) {
  //   print(
  //       "${pd.type.name} : ${pd.oldEntry.relativePath} -> ${pd.newEntry.relativePath}");
  // }
  //
  // // SNAPSHOT SAVED

  //
  // UPDATE THE UPDATE REPORT LIST
  //

  Directory installDir = Directory(
      "/home/sawors/.var/app/org.prismlauncher.PrismLauncher/data/PrismLauncher/instances/Tiboise II.V/.minecraft");
  const bool readOnly = true;

  ModrinthModHost mh = ModrinthModHost();

  Directory sourceDir =
      Directory("${installDir.path}/modshelf/dev/mods/enabled");

  List<InstalledModData> found = [];
  Map<String, List<dynamic>> latestProjectMatch = {};
  File mdInstall =
      File("${installDir.path}/${DirNames.installLocalDir}/modlist.json");

  File forgeMigTable =
      File("${installDir.path}/${DirNames.installLocalDir}/migration.csv");
  Table<String> migration = Table();
  migration.setRow(0, ["mod-id", "fabric-latest", "forge-latest", "forge-url"]);

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

  List<String> loaders = ["forge"];
  List<String> versions = ["1.20.1"];

  List<Future<dynamic>> workqueue = [];

  List<String> nulls = [];

  for (var f in result) {
    final pid = f.data?.projectId;
    if (pid == null) {
      continue;
    }
    for (var loader in loaders) {
      for (var version in versions) {
        workqueue.add(
            mh.getModVersions(pid, loader: loader, version: version).then((v) {
          final latest = v
              .sorted((v1, v2) => compareAsciiLowerCaseNatural(
                  v1["version_number"], v2["version_number"]))
              .lastOrNull;
          final String url = v.isNotEmpty
              ? "https://modrinth.com/project/$pid/version/${latest["id"]}"
              : "https://modrinth.com/project/$pid";
          print(
              "$pid:${latest != null ? latest['id'] : '--------'} | ${latest != null ? latest['version_number'] : "----"} -> $url");
          migration.addRow([pid, "?", latest?["id"], url]);
          if (latest == null) {
            nulls.add("$pid : 0 -> $url");
          }
        }));
      }
    }
  }

  final slices = workqueue.slices(250);

  for (var sl in slices.indexed) {
    print("SLICE ${sl.$1 + 1}/${slices.length} // ${workqueue.length}");
    await Future.wait(sl.$2);
    print("sleeping");
    sleep(const Duration(seconds: 60));
  }

  print(
      "================================== NULLS ===========================\n${nulls.join("\n")}");

  await forgeMigTable.writeAsString(migration.toCsv());

  print("DONEEEE");

  return;

  await Future.wait(result.indexed.map((e) {
    final pid = e.$2.data?.projectId;
    print("(${e.$1 + 1}/${result.length}) doing VRS ${e.$2.filename}");
    if (pid != null) {
      return mh
          .getModVersions(pid, loader: "fabric", version: "1.20.1")
          .then((v) {
        latestProjectMatch[pid] = v;
      });
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

  final Map<File, Uri> upgradeFiles = {};

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
    // final latest
    final latest = vrs.first;
    final latestVersion = latest["version_number"];
    String verUrl = "";
    bool upgradable = md.version != latestVersion;
    String printed = "${imd.filename.padRight(nameWidth)} : ${md.version}";
    if (upgradable) {
      final List<dynamic> files = latest["files"];
      String? url = files.firstWhereOrNull((f) => f["primary"])?["url"];
      if (url != null) {
        upgradeFiles[File(imd.path)] = Uri.parse(url);
      }
      verUrl =
          mh.webSourceForVersion(latest["project_id"], latest["id"]).toString();
      printed = "UPGRADABLE | $printed => $latestVersion [$verUrl]";
    } else {
      printed = "           | $printed";
    }
    output += "$printed\n";
  }
  print(output);
  await File(
          "${installDir.path}/${DirNames.installLocalDir}/upgrades_report.txt")
      .writeAsString(output);
  if (!readOnly) {
    print(upgradeFiles);
    Directory outputDir = Directory("/tmp/modshelf_upgrades");
    Directory backlogDir =
        Directory("${installDir.path}/${DirNames.devDir}/upgrades/old");
    await outputDir.create(recursive: true);

    final dio = Dio();
    print("downloading upgrades...");
    await Future.wait(upgradeFiles.entries.map((e) => dio
            .downloadUri(
                e.value, "${outputDir.path}/${e.value.pathSegments.last}")
            .then((v) async {
          String fileName = e.value.pathSegments.last;
          File oldMod = e.key;
          File newModDl = File("${outputDir.path}/$fileName");
          String newModPath = "${e.key.parent.path}/$fileName";
          await oldMod
              .copy("${backlogDir.path}/$fileName")
              .then((v) => oldMod.delete());
          newModDl.copy(newModPath);
        })));
    if (await outputDir.exists()) {
      await outputDir.delete(recursive: true);
    }
  }
  print("done");

  //FILE UPDATED
}
