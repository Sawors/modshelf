import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:modshelf/tools/adapters/modloaders.dart';
import 'package:modshelf/tools/engine/install.dart';
import 'package:modshelf/tools/utils.dart';

import '../core/core.dart';
import '../core/manifest.dart';
import 'games.dart';

abstract class LauncherAdapter {
  void injectProfile(InstallConfig source);

  Directory getLauncherRoot();

  Directory getProfilesDir();

  bool isPresent();

  String get displayName;

  LauncherType? get launcherType;

  GameAdapter get game;

  bool get hasProfile;

  Directory installDirForLauncher(Directory base) {
    return base;
  }
}

// Future<List<LauncherAdapter>> getAvailableLaunchers() async {
//   List<LauncherAdapter> launchers = [];
//   for (LauncherType type in LauncherType.values) {
//     LauncherAdapter? adapter = type.getAdapter();
//     if (adapter != null && await adapter.isPresent()) {
//       launchers.add(adapter);
//     }
//   }
//   return Future.value(launchers);
// }

enum LauncherType {
  mojang,
  prism,
  other;

  LauncherAdapter? getAdapter() {
    switch (this) {
      case LauncherType.mojang:
        return MojangLauncherAdapter();
      case LauncherType.prism:
        return PrismLauncherAdapter();
      case LauncherType.other:
        return null;
    }
  }
}

class MojangLauncherAdapter extends LauncherAdapter {
  Future<Map<String, String>> buildJsonProfile(InstallConfig source) async {
    // if not (
    //         os.path.isdir(mc_path)
    //         and os.path.isdir(version_dir)
    //     ):
    //         raise OSError("Launcher files could not be found")
    //     version_dir = f"{mc_path}/{dreams.DirNames.Minecraft.VERSIONS_DIR}"
    //     target_modloader = manifest_data["modloader"]
    //     target_version = manifest_data["game-version"]
    //     fitting_versions = list(filter(lambda x: target_modloader.lower() in x and target_version.lower() in x, os.listdir(version_dir)))
    //     if len(fitting_versions) < 1:
    //         raise FileNotFoundError("Version could not be found")
    //     best_version = sorted(fitting_versions, reverse=True)[0]
    //
    //     now = datetime.now()
    //     millis = now.strftime("%f")[0:3]
    //     now_str = now.strftime(f"%Y-%m-%dT%H:%M:%S.{millis}z")
    Uri imageUri =
        source.manifest.displayData.thumbnail ?? Uri.parse(defaultThumbnail);

    http.Response r = await http.get(imageUri);
    List<int> iconBytes = r.bodyBytes;

    final DateTime now = DateTime.now();
    final DateFormat formatter =
        DateFormat('yyyy-mm-ddTHH:mm:ss.${now.millisecond}');
    final String nowStr = "${formatter.format(now)}z";
    return {
      "created": nowStr,
      "gameDir": source.installLocation.path,
      "icon": base64Encode(iconBytes),
      "javaArgs":
          "-Xmx6G -XX:+UnlockExperimentalVMOptions -XX:+UseG1GC -XX:G1NewSizePercent=20 -XX:G1ReservePercent=20 -XX:MaxGCPauseMillis=50 -XX:G1HeapRegionSize=32M",
      "lastUsed": nowStr,
      "lastVersionId": "", // TODO : correct this
      "name": source.manifest.displayData.title,
      "type": "custom"
    };
  }

  @override
  void injectProfile(InstallConfig source) {
    // TODO: implement injectProfile
  }

  @override
  Directory getLauncherRoot() {
    // TODO: implement getLauncherRoot
    throw UnimplementedError();
  }

  @override
  Directory getProfilesDir() {
    // TODO: implement getProfilesDir
    throw UnimplementedError();
  }

  @override
  bool isPresent() {
    return false;
  }

  @override
  String get displayName => "Mojang (official)";

  @override
  LauncherType? get launcherType => LauncherType.mojang;

  @override
  GameAdapter get game => MinecraftAdapter();

  @override
  bool get hasProfile => true;
}

class PrismLauncherAdapter extends LauncherAdapter {
  static const mmcPackFabricB64 =
      "ewogICJjb21wb25lbnRzIjogWwogICAgewogICAgICAiY2FjaGVkTmFtZSI6ICJNaW5lY3JhZnQiLAogICAgICAiY2FjaGVkVmVyc2lvbiI6ICIkTUNfVkVSU0lPTiIsCiAgICAgICJpbXBvcnRhbnQiOiB0cnVlLAogICAgICAidWlkIjogIm5ldC5taW5lY3JhZnQiLAogICAgICAidmVyc2lvbiI6ICIkTUNfVkVSU0lPTiIKICAgIH0sCiAgICB7CiAgICAgICJjYWNoZWROYW1lIjogIkZhYnJpYyBMb2FkZXIiLAogICAgICAiY2FjaGVkUmVxdWlyZXMiOiBbCiAgICAgICAgewogICAgICAgICAgInVpZCI6ICJuZXQuZmFicmljbWMuaW50ZXJtZWRpYXJ5IgogICAgICAgIH0KICAgICAgXSwKICAgICAgImNhY2hlZFZlcnNpb24iOiAiJE1PRExPQURFUl9WRVJTSU9OIiwKICAgICAgInVpZCI6ICJuZXQuZmFicmljbWMuZmFicmljLWxvYWRlciIsCiAgICAgICJ2ZXJzaW9uIjogIiRNT0RMT0FERVJfVkVSU0lPTiIKICAgIH0KICBdLAogICJmb3JtYXRWZXJzaW9uIjogMQp9Cg==";
  static const mmcPackForgeB64 =
      "ewogICJjb21wb25lbnRzIjogWwogICAgewogICAgICAiY2FjaGVkTmFtZSI6ICJNaW5lY3JhZnQiLAogICAgICAiY2FjaGVkVmVyc2lvbiI6ICIkTUNfVkVSU0lPTiIsCiAgICAgICJpbXBvcnRhbnQiOiB0cnVlLAogICAgICAidWlkIjogIm5ldC5taW5lY3JhZnQiLAogICAgICAidmVyc2lvbiI6ICIkTUNfVkVSU0lPTiIKICAgIH0sCiAgICB7CiAgICAgICJ1aWQiOiAibmV0Lm1pbmVjcmFmdGZvcmdlIiwKICAgICAgInZlcnNpb24iOiAiJE1PRExPQURFUl9WRVJTSU9OIgogICAgfQogIF0sCiAgImZvcm1hdFZlcnNpb24iOiAxCn0K";
  static const mmcPackNeoforgeB64 =
      "ewogICJjb21wb25lbnRzIjogWwogICAgewogICAgICAiY2FjaGVkTmFtZSI6ICJNaW5lY3JhZnQiLAogICAgICAiY2FjaGVkVmVyc2lvbiI6ICIkTUNfVkVSU0lPTiIsCiAgICAgICJpbXBvcnRhbnQiOiB0cnVlLAogICAgICAidWlkIjogIm5ldC5taW5lY3JhZnQiLAogICAgICAidmVyc2lvbiI6ICIkTUNfVkVSU0lPTiIKICAgIH0sCiAgICB7CiAgICAgICJ1aWQiOiAibmV0Lm5lb2ZvcmdlZCIsCiAgICAgICJ2ZXJzaW9uIjogIiRNT0RMT0FERVJfVkVSU0lPTiIKICAgIH0KICBdLAogICJmb3JtYXRWZXJzaW9uIjogMQp9Cg==";
  static const instanceCfgB64 =
      "W0dlbmVyYWxdCkNvbmZpZ1ZlcnNpb249MS4yCkluc3RhbmNlVHlwZT1PbmVTaXgKaWNvbktleT0kSUNPTl9LRVkKbmFtZT0kSU5TVEFOQ0VfTkFNRQo=";

  static const Map<String, String> lwjglVersionMatch = {};

  @override
  void injectProfile(InstallConfig source) {
    Manifest man = source.manifest;
    String? loaderStr = man.modLoader;
    ModLoader loader = ModLoader.fromString(loaderStr ?? "");
    String mmcPack;
    String instanceCfg = String.fromCharCodes(base64Decode(instanceCfgB64));
    switch (loader) {
      case ModLoader.forge:
        mmcPack = String.fromCharCodes(base64Decode(mmcPackForgeB64));
      case ModLoader.fabric:
        mmcPack = String.fromCharCodes(base64Decode(mmcPackFabricB64));
      case ModLoader.neoforge:
        mmcPack = String.fromCharCodes(base64Decode(mmcPackNeoforgeB64));
      case ModLoader.native:
        throw ManifestException("Modloader not found or not known");
    }
    mmcPack = mmcPack
        .replaceAll("\$MC_VERSION", man.gameVersion)
        .replaceAll("\$MODLOADER_VERSION", man.modLoaderVersion);

    Uri thumbnail = man.displayData.thumbnail ?? Uri.parse(defaultThumbnail);
    final String iconKey = "modshelf_${generateRandomStringAlNum(32)}";
    Dio().downloadUri(thumbnail,
        "${getLauncherRoot().path}${Platform.pathSeparator}icons${Platform.pathSeparator}$iconKey");

    instanceCfg = instanceCfg
        .replaceAll("\$INSTANCE_NAME", man.displayData.title)
        .replaceAll("\$ICON_KEY", iconKey);

    File mmcPackFile = File(
        "${source.installLocation.path}${Platform.pathSeparator}mmc-pack.json");
    File instanceCfgFile = File(
        "${source.installLocation.path}${Platform.pathSeparator}instance.cfg");
    mmcPackFile.create().then((f) => f.writeAsString(mmcPack));
    instanceCfgFile.create().then((f) => f.writeAsString(instanceCfg));
  }

  @override
  Directory getLauncherRoot() {
    if (Platform.isLinux || Platform.isMacOS) {
      List<String> pathWaterfall = [
        "${Platform.environment['HOME']}/.local/share/PrismLauncher",
        "${Platform.environment['HOME']}/.var/app/org.prismlauncher.PrismLauncher/data/PrismLauncher"
      ];
      String? dir = cascadeCheckFileSystem(pathWaterfall, isDirectory: true);
      if (dir != null) {
        return Directory(dir);
      }
    } else if (Platform.isWindows) {
      throw UnimplementedError(
          "Windows launcher bindings are not implemented.");
    }
    throw UnimplementedError(
        "Launcher binding is not implemented for your operating system, or the path has not been found.");
  }

  @override
  Directory getProfilesDir() {
    if (Platform.isLinux) {
      return Directory("${getLauncherRoot().path}/instances");
    } else if (Platform.isWindows) {
      throw UnimplementedError("Windows launcher bindings are not implemented");
    }
    throw UnimplementedError(
        "launcher binding is not implemented for your operating system");
  }

  @override
  bool isPresent() {
    try {
      bool hasRoot = getLauncherRoot().existsSync();
      bool hasProfiles = getProfilesDir().existsSync();
      return hasRoot && hasProfiles;
    } on UnimplementedError {
      return false;
    }
  }

  @override
  String get displayName => "Prism";

  @override
  LauncherType? get launcherType => LauncherType.prism;

  @override
  Directory installDirForLauncher(Directory base) {
    return Directory("${base.path}/minecraft");
  }

  @override
  GameAdapter get game => MinecraftAdapter();

  @override
  bool get hasProfile => true;
}

String? cascadeCheckFileSystem(List<String> paths, {bool isDirectory = true}) {
  for (String path in paths) {
    // yeah I might re-think the logic here, brain issue
    if ((isDirectory && FileSystemEntity.isDirectorySync(path)) ||
        (!isDirectory && FileSystemEntity.isFileSync(path))) {
      return path;
    }
  }
  return null;
}
