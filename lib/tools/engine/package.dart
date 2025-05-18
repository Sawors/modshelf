import 'dart:io';

import 'package:archive/archive.dart';
import 'package:collection/collection.dart';
import 'package:modshelf/tools/core/core.dart';
import 'package:modshelf/tools/core/modpack_config.dart';
import 'package:modshelf/tools/utils.dart';

enum PatchDifferenceType { added, removed, modified, untouched }

class PatchEntry {
  final String? comment;
  final Uri? source;
  final String relativePath;
  String? version;
  final String crc32;
  final int size;

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
      {String? root, bool rootAppendVersion = true, bool uriEncode = true}) {
    // ${Uri.encodeFull("${root.endsWith('/') ? root.substring(0, root.length - 1) : root}${rootAppendVersion ? '/${v.version}' : ""}${v.relativePath.startsWith('/') ? v.relativePath : '/${v.relativePath}'}")} ${Uri.encodeFull(v.relativePath)}
    final encodedPath = root != null
        ? Uri.encodeFull(
            "${root.endsWith('/') ? root.substring(0, root.length - 1) : root}${rootAppendVersion ? '/$version' : ""}${relativePath.startsWith('/') ? relativePath : '/$relativePath'}")
        : source?.path ?? relativePath;
    final encodedRelative = Uri.encodeFull(relativePath);
    return "$crc32 $size $encodedPath $encodedRelative";
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
}

// class PatchHistory {
//   List<ContentSnapshot> history = [];
//
//   List<String> get versions => history.map((p) => p.version).toList();
//
//   PatchHistory.compiled(List<ContentSnapshot> history) {
//     // relative path to PatchDifference
//     Map<String, List<PatchEntry>> diff = {};
//     for (ContentSnapshot content in history) {
//       for (PatchEntry newEntry in content.content) {
//         List<PatchEntry> base = diff[newEntry.fileRelativePath] ?? [];
//         base.add(newEntry);
//         diff[newEntry.fileRelativePath] = base;
//       }
//     }
//   }
// }

class Patch {
  late final String version;
  late final String firstVersion;
  late final Set<PatchDifference> patch;

  Patch.compiled(List<ContentSnapshot> history) {
    List<ContentSnapshot> sorted = history
        .sortedBy((k) => Version.fromString(k.version))
        .toList(growable: false);
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
        if (path == "/config/dehydration.json5") {
          print(
              "${entry.$1} ${d.type.name} => check: ${oldEntry.version} / ${oldEntry.relativePath} | ${newEntry.version} / ${newEntry.relativePath}");
        }
        // if ((diff[path] != null && d.type == PatchDifferenceType.untouched)) {
        //   continue;
        // }
        diff[path] = d;
        lastState[path] = newEntry;
      }
    }
    patch = diff.values.toSet();
  }

  Patch.difference(ContentSnapshot oldContent, ContentSnapshot newContent) {
    Map<String, PatchEntry> oldIndex = {
      for (var v in oldContent.content) v.relativePath: v
    };
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
}

class ContentSnapshot {
  final Set<PatchEntry> content;
  final String version;

  ContentSnapshot(this.content, this.version);

  static Future<ContentSnapshot> fromDirectory(Directory dir, String version,
      {List<String>? fileRelativePathExclude, ModpackConfig? config}) async {
    List<PatchEntry> filePatch = [];
    if (config == null) {
      filePatch = await dir
          .list(recursive: true)
          .where((e) =>
              (fileRelativePathExclude == null ||
                  fileRelativePathExclude.contains(e.path)) &&
              FileSystemEntity.isFileSync(e.path))
          .asyncMap((e) async {
        return PatchEntry.fromFile(File(e.path), Directory(dir.path),
            sourceVersion: version);
      }).toList();
    } else {
      for (String path in config.bundleInclude) {
        if (config.bundleExclude.any((v) => path.startsWith(v))) {
          continue;
        }
        String absolutePath = "${dir.path}/$path";
        if (await FileSystemEntity.isFile(absolutePath)) {
          filePatch.add(await PatchEntry.fromFile(File(absolutePath), dir,
              sourceVersion: version));
        } else if (await FileSystemEntity.isDirectory(absolutePath)) {
          await Directory(absolutePath)
              .list(recursive: true)
              .forEach((f) async {
            if (FileSystemEntity.isFileSync(f.path)) {
              if (config.bundleExclude.any((v) => path.startsWith(v))) {
                return;
              }
              filePatch.add(await PatchEntry.fromFile(File(f.path), dir,
                  sourceVersion: version));
            }
          });
        }
      }
    }

    return ContentSnapshot(filePatch.toSet(), version);
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
      {bool rootAppendVersion = true, bool safeGeneration = true}) {
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
            root: root, rootAppendVersion: rootAppendVersion, uriEncode: true))
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
