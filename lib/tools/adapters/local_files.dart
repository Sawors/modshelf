import 'dart:io';

import 'package:modshelf/tools/core/core.dart';
import 'package:modshelf/tools/engine/package.dart';

final String sep = Platform.pathSeparator;

Directory installationDirFromManifestFile(File manifestFile) {
  int climb = DirNames.fileManifest.split("/").length - 1;
  Directory target = manifestFile.parent;
  for (int i = 0; i < climb; i++) {
    target = target.parent;
  }
  return target;
}

Directory getConfigDir() {
  String configIdentifier = "modshelf";
  if (Platform.isWindows) {
    return Directory(
        "${File(Platform.resolvedExecutable).parent.path}${sep}config");
  } else if (Platform.isLinux) {
    Map<String, String> env = Platform.environment;
    String xdgConfig = env["XDG_CONFIG_HOME"] ?? "${env['HOME']}$sep.config";
    return Directory("$xdgConfig$sep$configIdentifier");
  }

  throw UnimplementedError("OS not supported");
}

Future<List<ModpackData>> loadStoredManifests(
    {bool deleteBroken = true}) async {
  Directory store = LocalFiles().manifestStoreDir;
  List<ModpackData> manifests = [];
  List<File> manifestsFiles = await store
      .list(recursive: true, followLinks: false)
      .where((f) {
        FileSystemEntityType type = FileSystemEntity.typeSync(f.path);
        bool brokenLink = type == FileSystemEntityType.link &&
            File(Link(f.path).targetSync()).existsSync();

        if (brokenLink || type == FileSystemEntityType.notFound) {
          f.delete();
          return false;
        }

        final path = f.resolveSymbolicLinksSync();
        return FileSystemEntity.isFileSync(path) && path.endsWith(".json");
      })
      .map((f) => File(f.resolveSymbolicLinksSync()))
      .toList();
  for (File f in manifestsFiles) {
    try {
      manifests.add(await ModpackData.fromInstallation(
          installationDirFromManifestFile(f)));
    } catch (e) {
      print(e.toString());
    }
  }
  return manifests;
}

Future<ContentSnapshot> snapshotFromInstall(Directory install) async {
  final ModpackData localData = await ModpackData.fromInstallation(install);
  final List<PatchEntry> res = [];
  await Future.wait(install
      .listSync(recursive: true, followLinks: false)
      .map((f) => FileSystemEntity.isFile(f.path).then((isFile) {
            if (isFile) {
              return PatchEntry.fromFile(f as File, install,
                      sourceVersion: localData.manifest.version)
                  .then((p) => res.add(p));
            }
            return Future.value();
          })));
  return ContentSnapshot(res.toSet(), localData.manifest.version);
}

class LocalFiles {
  Future<Directory> get cacheDir async {
    if (Platform.isWindows) {
      throw UnimplementedError(
          "Implement cache for ${Platform.operatingSystem}");
    } else if (Platform.isLinux) {
      return Directory(
          "${Platform.environment['HOME']}/.cache/com.example.modshelf");
    } else if (Platform.isMacOS) {
      throw UnimplementedError(
          "Implement cache for ${Platform.operatingSystem}");
    }

    throw const OSError("Modshelf is not available for this platform.");
  }

  Directory get storeDir => Directory("${getConfigDir().path}${sep}store");

  Directory get manifestStoreDir =>
      Directory("${storeDir.path}${sep}manifests");
}
