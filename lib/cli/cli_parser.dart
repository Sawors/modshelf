import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
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

void main(List<String> args) async {
  ModrinthModHost mh = ModrinthModHost();
  ModData? data =
      await mh.modDataFromFile("2873346ec8ca2874ef2dcc167c5b2c5fdbf98f04");
  if (data == null) {
    return;
  }
  print(data.versionId);
  print(data.version);
  print(data.source);
  print(data.webSource);
  print(data.host);
  print(data.name);
  print(data.projectId);
}
