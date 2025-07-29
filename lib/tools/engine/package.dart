import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:collection/collection.dart';
import 'package:modshelf/tools/core/core.dart';
import 'package:modshelf/tools/core/modpack_config.dart';
import 'package:modshelf/tools/utils.dart';

import '../../cli/cli_parser.dart';
import '../adapters/servers.dart';
import '../core/manifest.dart';

enum PatchDifferenceType { added, removed, modified, untouched }

class PatchEntry {
  late final String? comment;
  late final Uri? source;
  late final String relativePath;
  String? version;
  late final String crc32;
  late final int size;

  PatchEntry(
      {this.source,
      required this.relativePath,
      this.version,
      required this.crc32,
      required this.size,
      this.comment});

  PatchEntry.voidEntry({String? version})
      : this(relativePath: "", crc32: "", size: 0, version: version);

  bool isVoid() => relativePath.isEmpty && crc32.isEmpty && size == 0;

  static PatchEntry fromString(String str,
      {bool autoVersion = true, String? sourceVersion}) {
    List<String> split = str.split(" ").where((t) => t.isNotEmpty).toList();
    if (split.length != 4) {
      throw ArgumentError(
          "Content string contains wrong values : content should contain 4 parts but ${split.length} were found)");
    }
    String crc32 = split[0];
    String size = split[1];
    String location = Uri.decodeFull(split[2]);
    String relativePath = Uri.decodeFull(split[3]);
    if (!relativePath.startsWith("/")) {
      relativePath = "/$relativePath";
    }
    String? entryVersion;
    try {
      String versionFromPath =
          resourceName(location.replaceAll(relativePath, ""));
      Version.fromString(versionFromPath);
      entryVersion = versionFromPath;
    } catch (e) {
      // ignore
    }
    return PatchEntry(
        relativePath: relativePath,
        crc32: crc32,
        size: int.tryParse(size) ?? 0,
        source: Uri.tryParse(location),
        version: autoVersion ? entryVersion : sourceVersion);
  }

  static Future<PatchEntry> fromFile(File file, Directory root,
      {String? sourceVersion, String? comment}) async {
    String rel = file.absolute.path.replaceFirst(root.absolute.path, "");
    if (!rel.startsWith("/")) {
      rel = "/$rel";
    }
    return PatchEntry(
        relativePath: rel,
        version: sourceVersion,
        comment: comment,
        crc32: await file
            .readAsBytes()
            .then((v) => (Crc32()..add(v)).hash.toRadixString(16)),
        size: await file.length());
  }

  @override
  String toString(
      {String? root, bool rootAppendVersion = true, bool uriEncode = false}) {
    // ${Uri.encodeFull("${root.endsWith('/') ? root.substring(0, root.length - 1) : root}${rootAppendVersion ? '/${v.version}' : ""}${v.relativePath.startsWith('/') ? v.relativePath : '/${v.relativePath}'}")} ${Uri.encodeFull(v.relativePath)}
    final completePath = root != null
        ? "${cleanPath(root)}${rootAppendVersion ? '/$version' : ""}${relativePath.startsWith('/') ? relativePath : '/$relativePath'}"
        : source?.path ?? relativePath;
    return "$crc32 $size /${Uri.encodeFull(cleanPath(completePath))} /${Uri.encodeFull(cleanPath(relativePath))}";
  }

  Object toJsonObject() {
    return {
      "source": source.toString(),
      "path": relativePath,
      "version": version,
      "crc32": crc32,
      "size": size,
      "comment": comment
    };
  }

  PatchEntry.fromJsonObject(Object jsonObject) {
    final map = jsonObject as Map<String, dynamic>;
    source = Uri.tryParse(Uri.decodeFull(map["source"]));
    relativePath = Uri.decodeFull(map["path"]);
    version = map["version"];
    crc32 = map["crc32"];
    size = map["size"];
    comment = map["comment"];
  }
}

class PatchDifference {
  late final PatchEntry oldEntry;
  late final PatchEntry newEntry;
  late final PatchDifferenceType type;

  PatchDifference(
      {required this.oldEntry, required this.newEntry, required this.type});

  static PatchDifferenceType difference(
      PatchEntry? oldEntry, PatchEntry? newEntry) {
    if (oldEntry == newEntry) {
      return PatchDifferenceType.untouched;
    }

    final oldVoid = oldEntry == null || oldEntry.isVoid();
    final newVoid = newEntry == null || newEntry.isVoid();

    if (oldVoid && !newVoid) {
      return PatchDifferenceType.added;
    } else if (!oldVoid && newVoid) {
      return PatchDifferenceType.removed;
    } else if (!oldVoid && !newVoid && oldEntry.crc32 != newEntry.crc32) {
      return PatchDifferenceType.modified;
    }

    return PatchDifferenceType.untouched;
  }

  PatchDifference.fromEntries(PatchEntry? oldEntry, PatchEntry? newEntry) {
    this.oldEntry = oldEntry ?? PatchEntry.voidEntry();
    this.newEntry = newEntry ?? PatchEntry.voidEntry();
    type = difference(oldEntry, newEntry);
  }

  @override
  String toString() {
    return "${type.toString()} : (${oldEntry.size}, ${oldEntry.crc32}, ${oldEntry.version})${oldEntry.relativePath} -> (${newEntry.size}, ${newEntry.crc32}, ${newEntry.version})${newEntry.relativePath}";
  }

  PatchEntry getSignificant() {
    switch (type) {
      case PatchDifferenceType.added:
        return newEntry;
      case PatchDifferenceType.removed:
        return oldEntry;
      case PatchDifferenceType.modified:
        return newEntry;
      case PatchDifferenceType.untouched:
        return oldEntry;
    }
  }

  Object toJsonObject() {
    return {
      "old": oldEntry.toJsonObject(),
      "new": newEntry.toJsonObject(),
      "type": type.name
    };
  }

  PatchDifference.fromJsonObject(Object jsonObject) {
    final map = jsonObject as Map<String, dynamic>;
    oldEntry = PatchEntry.fromJsonObject(map["old"]);
    newEntry = PatchEntry.fromJsonObject(map["new"]);
    type = PatchDifferenceType.values.firstWhere((v) => v.name == map["type"],
        orElse: () => PatchDifferenceType.untouched);
  }
}

class Patch {
  late String version;
  late final String firstVersion;
  late final Set<PatchDifference> patch;

  Patch(
      {required this.patch, required this.version, required this.firstVersion});

  Patch.compiled(List<ContentSnapshot> history) {
    List<ContentSnapshot> sorted =
        history.sortedBy((k) => Version.fromString(k.version));
    version = sorted.last.version;
    firstVersion = sorted.first.version;
    // key: Relative path
    Map<String, PatchEntry> lastState = {};
    Map<String, PatchDifference> diff = {};
    for ((int, ContentSnapshot) entry in sorted.indexed) {
      final content = entry.$2;
      for (PatchEntry newEntry in content.content) {
        String path = newEntry.relativePath;
        PatchEntry? oldEntry = lastState[path] ?? PatchEntry.voidEntry();
        PatchDifference d = PatchDifference.fromEntries(oldEntry, newEntry);
        diff[path] = d;
        lastState[path] = newEntry;
      }
    }
    patch = diff.values.toSet();
  }

  Patch.fromJsonObject(Object jsonObject,
      {String? versionOverride, String? firstVersionOverride}) {
    patch = (jsonObject as List<dynamic>)
        .map((e) => PatchDifference.fromJsonObject(e))
        .toSet();
    if (versionOverride != null && firstVersionOverride != null) {
      version = versionOverride;
      firstVersion = firstVersionOverride;
      return;
    }
    final sorted = patch
        .sortedBy((k) => Version.fromString(k.getSignificant().version ?? "0"));
    version = versionOverride ?? sorted.last.getSignificant().version ?? "1";
    firstVersion =
        firstVersionOverride ?? sorted.first.getSignificant().version ?? "0";
  }

  Iterable<PatchDifference> get removed =>
      patch.where((v) => v.type == PatchDifferenceType.removed);

  Iterable<PatchDifference> get added =>
      patch.where((v) => v.type == PatchDifferenceType.added);

  Iterable<PatchDifference> get modified =>
      patch.where((v) => v.type == PatchDifferenceType.modified);

  Iterable<PatchDifference> get untouched =>
      patch.where((v) => v.type == PatchDifferenceType.untouched);

  Patch.difference(ContentSnapshot oldContent, ContentSnapshot newContent,
      {String? versionOverride}) {
    Map<String, PatchEntry> oldIndex = {
      for (var v in oldContent.content) v.relativePath: v
    };
    version = versionOverride ?? newContent.version;
    firstVersion = versionOverride ?? oldContent.version;
    Map<String, PatchEntry> newIndex = {};
    patch = {};
    for (var v in newContent.content) {
      // added, modified, untouched
      PatchEntry? oldValue = oldIndex[v.relativePath];
      newIndex[v.relativePath] = v;
      patch.add(PatchDifference(
          oldEntry: oldValue ?? PatchEntry.voidEntry(),
          newEntry: v,
          type: PatchDifference.difference(oldValue, v)));
    }

    patch.addAll(oldIndex.entries
        .where((v) => !newIndex.containsKey(v.key))
        .map((v) => PatchDifference(
            oldEntry: v.value,
            newEntry: PatchEntry.voidEntry(),
            type: PatchDifferenceType.removed)));
    // I don't know from where but we have lots of void entry
    patch.removeWhere((v) =>
        v.oldEntry.relativePath.isEmpty && v.newEntry.relativePath.isEmpty);
  }

  bool isChanged(PatchDifference diff) {
    switch (diff.type) {
      case PatchDifferenceType.added:
        return diff.oldEntry.isVoid() && !diff.newEntry.isVoid();
      case PatchDifferenceType.removed:
        return !diff.oldEntry.isVoid() && diff.newEntry.isVoid();
      case PatchDifferenceType.modified:
        return true;
      case PatchDifferenceType.untouched:
        return false;
    }
  }

  Set<PatchDifference> onlyChanged({bool considerFirstVersionAsAdded = false}) {
    return patch
        .where((v) => considerFirstVersionAsAdded || isChanged(v))
        .toSet();
  }

  ContentSnapshot asContentSnapshot() {
    return ContentSnapshot(
        patch
            .where((v) =>
                v.type != PatchDifferenceType.removed && !v.newEntry.isVoid())
            .map((v) => v.newEntry)
            .toSet(),
        version);
  }

  Object toJsonObject() {
    return patch.map((e) => e.toJsonObject()).toList();
  }
}

class ContentSnapshot {
  final Set<PatchEntry> content;
  final String version;

  ContentSnapshot(this.content, this.version);

  int get byteSize => content.fold(0, (v1, pe) => v1 + pe.size);

  static bool isExcluded(
      String filePath, String rootDir, List<String> excludeFilters) {
    final relPath =
        cleanPath(filePath.replaceFirst("${cleanPath(rootDir)}/", ""));
    return excludeFilters.any((filter) =>
        filter == relPath || RegExp(cleanPath(filter)).hasMatch(relPath));
  }

  static Future<ContentSnapshot> fromDirectory(Directory dir, String version,
      {List<String>? excludeFilters, List<String>? includeFilters}) async {
    final List<String> relativeInclude =
        includeFilters?.map((p) => cleanPath(p)).toList() ?? [""];
    final List<String> relativeExclude = excludeFilters ?? [];
    List<Future<PatchEntry>> res = [];
    final dirpath = cleanPath(dir.path);
    for (String rel in relativeInclude) {
      final path = "/$dirpath/${cleanPath(rel)}";
      if (await FileSystemEntity.isFile(path) &&
          !isExcluded(cleanPath(rel), "", relativeExclude)) {
        res.add(PatchEntry.fromFile(File(path), dir, sourceVersion: version));
      } else if (await FileSystemEntity.isDirectory(path)) {
        await Directory(path)
            .list(recursive: true, followLinks: false)
            .forEach((f) async {
          if (await FileSystemEntity.isFile(f.path) &&
              !isExcluded(f.path, dirpath, relativeExclude)) {
            res.add(
                PatchEntry.fromFile(File(f.path), dir, sourceVersion: version));
          }
        });
      }
    }
    final Set<PatchEntry> paths = (await Future.wait(res)).toSet();
    // if (config == null) {
    //   filePatch =
    // } else {
    //   for (String path in config.bundleInclude) {
    //     String absolutePath = "${dir.path}/${cleanPath(path)}";
    //     if (config.bundleExclude.any((v) => path.startsWith(cleanPath(v)))) {
    //       continue;
    //     }
    //     if (await FileSystemEntity.isFile(absolutePath)) {
    //       filePatch.add(await PatchEntry.fromFile(File(absolutePath), dir,
    //           sourceVersion: version));
    //     } else if (await FileSystemEntity.isDirectory(absolutePath)) {
    //       await Directory(absolutePath)
    //           .list(recursive: true)
    //           .forEach((f) async {
    //         final relPath = cleanPath(f.path.replaceFirst(dir.path, ""));
    //         if (FileSystemEntity.isFileSync(f.path)) {
    //           if (config.bundleExclude
    //               .any((v) => relPath.startsWith(cleanPath(v)))) {
    //             return;
    //           }
    //           filePatch.add(await PatchEntry.fromFile(File(f.path), dir,
    //               sourceVersion: version));
    //         }
    //       });
    //     }
    //   }
    // }
    return ContentSnapshot(paths, version);
  }

  static ContentSnapshot fromContentString(String contentString,
      {String? versionOverride}) {
    List<String> lines = contentString.split("\r\n");
    Set<PatchEntry> content = {};
    String version = "0";
    for ((int, String) s in lines.indexed) {
      PatchEntry entry =
          PatchEntry.fromString(s.$2, autoVersion: versionOverride == null);
      Version? entryVersion = Version.tryFromString(entry.version);
      if (entryVersion != null &&
          entryVersion.compareTo(Version.fromString(version)) > 0) {
        version = entryVersion.toString();
      }
      content.add(entry);
    }
    return ContentSnapshot(content, versionOverride ?? version);
  }

  String toContentString(String root,
      {bool rootAppendVersion = true,
      bool safeGeneration = true,
      bool includePatchDiffAsComment = true}) {
    List<PatchEntry> sorted = safeGeneration ? [] : content.toList();

    // "safeGeneration" only means sorting the files.
    // It is important to ensure that 2 content file describing the same content
    // are actually equals between them
    // (THERE MIGHT BE EDGE CASES AND COMPARING FILES IS NEVER RECOMMENDED !!).
    // Ok honestly is is mainly for esthetical reasons :).
    if (safeGeneration) {
      Map<String, List<PatchEntry>> versions = {};
      for (PatchEntry p in content) {
        String version = p.version ?? "0";
        List<PatchEntry> entry = versions[version] ?? [];
        entry.add(p);
        versions[version] = entry;
      }
      sorted = versions.entries
          .map((entry) => (
                Version.tryFromString(entry.key) ?? Version.fromString("0"),
                entry.value.sorted((v1, v2) => v1.crc32.compareTo(v2.crc32))
              ))
          .sorted((e1, e2) => e1.$1.compareTo(e2.$1))
          .fold(List<PatchEntry>.empty(growable: true),
              (List<PatchEntry> previous, e) => previous..addAll(e.$2))
          .toList(growable: false);
    }

    return sorted
        .map((v) => v.toString(
            root: root, rootAppendVersion: rootAppendVersion, uriEncode: false))
        .join("\r\n");
  }

  ContentSnapshot asFiltered(
      {bool onlyLatest = false, bool Function(PatchEntry)? filter}) {
    return ContentSnapshot(
        content
            .where(onlyLatest
                ? (p) =>
                    Version.tryFromString(p.version) ==
                    Version.tryFromString(version)
                : filter ?? (p) => true)
            .toSet(),
        version);
  }
}

Future<Patch> package(Directory source,
    {bool asPatch = true,
    ServerAgent? server,
    ContentSnapshot? oldContentOverride,
    String? profile}) async {
  ModpackData modpack = await ModpackData.fromInstallation(source);
  Manifest manifest = modpack.manifest;
  ModpackConfig config = modpack.modpackConfig.asProfile(profile);
  ContentSnapshot oldContent = oldContentOverride ?? ContentSnapshot({}, "0");
  String oldVersion = "0";
  if (oldContentOverride == null &&
      asPatch &&
      server != null &&
      await server.hasModpack(manifest.packId)) {
    oldVersion = await server.getLatestVersion(manifest.packId);
    oldContent = await server.getContent(manifest.packId, oldVersion);
  }
  ContentSnapshot newContent = await ContentSnapshot.fromDirectory(
      source, manifest.version,
      includeFilters: config.bundleInclude,
      excludeFilters: config.bundleExclude);
  final patch = Patch.difference(oldContent, newContent);
  patch.version = newContent.version;
  return patch;
}

Future<Archive> asArchive(Patch patch, Directory fileSource,
    ServerAgent buildTarget, NamespacedKey modpackId,
    {bool rebase = false}) async {
  ContentSnapshot ct;
  if (rebase) {
    ct = patch.asContentSnapshot();
  } else {
    ct = ContentSnapshot(
        patch
            .onlyChanged(considerFirstVersionAsAdded: true)
            .map((v) => v.getSignificant())
            .where((v) => !v.isVoid())
            .toSet(),
        patch.version);
  }
  Archive arch = Archive();
  for (PatchEntry entry in ct.asFiltered(onlyLatest: true).content) {
    File sourceFile = File("${fileSource.path}${entry.relativePath}");
    if (!await sourceFile.exists()) {
      continue;
    }
    arch.addFile(ArchiveFile("/${patch.version}/${entry.relativePath}",
        entry.size, await sourceFile.readAsBytes()));
  }
  List<int> contentBytes = const Utf8Encoder().convert(ct.toContentString(
      buildTarget.modpackIdToUri(modpackId, asApi: false).path));

  arch.add(ArchiveFile("/${patch.version}/${buildTarget.mappings.content}",
      contentBytes.length, contentBytes));
  return arch;
}

class CliPackage extends CliAction {
  @override
  Future<int> execute(List<String> args) async {
    // package
    //    [-c, --content]                          Output only the content.
    //    [-p=<profile>, --profile=<profile>]      Specify a config profile to use.
    //    [--rebase]                               Create an archive containing all the files.
    //    -d=<source_dir>,--dir=<source_dir>
    Directory? installDir;
    String? profile;
    final bool rebase = args.contains("--rebase");
    final bool outputArchive =
        !(args.contains("-c") || args.contains("--content"));
    for (String s in args) {
      if (s.startsWith("-d=") || s.startsWith("--dir=")) {
        installDir = Directory(s.split("=").sublist(1).join("="));
      } else if (s.startsWith("-p=") || s.startsWith("--profile=")) {
        profile = s.split("=").sublist(1).join("=");
      }
      if (installDir == null && !s.startsWith("-") && s == args.last) {
        installDir = Directory(s);
      }
    }

    ModpackData installed;
    if (installDir == null || !installDir.existsSync()) {
      try {
        final rez = await ModpackData.fromInstallation(Directory.current,
            recursePath: true);
        installed = rez;
      } on FileSystemException {
        stderr.writeln(
            "No directory has been provided and the current directory is not part of a pack.");
        return -1;
      }
    } else {
      installed =
          await ModpackData.fromInstallation(installDir, recursePath: true);
    }
    print("creating content snapshot...");

    final ServerAgent agent = ModshelfServerAgent();
    if (!installed.isInstalled) {
      stderr.writeln("The modpack is not installed (strange error message).");
      return -1;
    }

    Patch content =
        await package(installed.installDir!, server: agent, profile: profile);

    File outputFile = File(
        "${installed.installDir!.path}/${DirNames.releases}/${installed.manifest.version}-content.txt");
    if (!await outputFile.parent.exists()) {
      outputFile.parent.create(recursive: true);
    }

    final archiveOutputFile = File(
        "${outputFile.parent.path}/${rebase ? "" : "patch-"}${installed.manifest.version}${profile != null ? "-$profile" : ""}.zip");
    if (outputArchive) {
      print("Saving modpack to archive...");
      Manifest man = Manifest.fromJsonString(
          await File("${installed.installDir!.path}/${DirNames.fileManifest}")
              .readAsString());
      final arch = await asArchive(
          content, installed.installDir!, agent, man.packId,
          rebase: rebase);
      await archiveOutputFile.writeAsBytes(ZipEncoder().encode(arch));
      print("Archive done !");
    } else {
      await outputFile.create();
      outputFile.writeAsStringSync(content
          .asContentSnapshot()
          .toContentString(installed.installDir!.path));
    }
    print("Modpack packaged at ${archiveOutputFile.path} !");
    // SNAPSHOT SAVED
    return 0;
  }

  @override
  String get name => "package";

  @override
  String get helpMessage => throw UnimplementedError();
}
