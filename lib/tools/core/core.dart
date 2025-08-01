import 'dart:io';

import 'package:modshelf/tools/engine/package.dart';
import 'package:modshelf/tools/utils.dart';

import 'manifest.dart';
import 'modpack_config.dart';

final String s = Platform.pathSeparator;

const String defaultThumbnail = "https://sawors.net/assets/unknown.png";
const String noGameNamespace = "general";

abstract class DirNames {
  static const String config = "config";
  static const String crash = "crash-reports";
  static const String install = "modshelf";
  static const String logs = "logs";
  static const String mods = "mods";
  static const String resourcePacks = "resourcepacks";
  static const String saves = "saves";
  static const String shaderpacks = "shaderpacks";
  static const String defaults = "$install/defaults";
  static const String installThemeDir = "$install/theme";
  static const String installConfigDir = "$install/config";
  static const String installLocalDir = "$install/install";
  static const String publishDir = "$install/publish";
  static const String devDir = "$install/dev";
  static const String themeFile = "$installThemeDir/theme.json";
  static const String readmeFile = "$install/readme.md";
  static const String version = "$install/version";
  static const String releases = "$devDir/releases";
  static const String reports = "$installLocalDir/reports";
  static const String patchnotes = "$installLocalDir/version";
  static const String server = "$installLocalDir/server";
  static const String fileManifest = "$install/manifest.json";
  static const String fileConfig = "$install/config.json";
  static const String fileConfigPublication = "$publishDir/publish.json";
  static const String fileConfigServer = "$server/serverconfig.json";
  static const String fileVersionChecker = "$config/bcc.json";
}

class Version implements Comparable<Version> {
  late final int release;
  late final int major;
  late final int minor;

  Version(this.release, this.major, this.minor);

  Version.zero() {
    release = 0;
    major = 0;
    minor = 0;
  }

  static Version? tryFromString(String? str) {
    if (str == null) {
      return null;
    }
    try {
      return Version.fromString(str);
    } on FormatException {
      return null;
    }
  }

  Version add(Version other) {
    return Version(
        release + other.release, major + other.major, minor + other.minor);
  }

  Version.fromString(String str) {
    List<String> list = str.split(".");
    switch (list.length) {
      case 1:
        release = int.parse(list[0]);
        major = 0;
        minor = 0;
      case 2:
        release = int.parse(list[0]);
        major = int.parse(list[1]);
        minor = 0;
      case 3:
        release = int.parse(list[0]);
        major = int.parse(list[1]);
        minor = int.parse(list[2]);
      case _:
        throw FormatException(
            "Version is not correctly formatted (value ${list.length} not in range [1..3])");
    }
  }

  @override
  int compareTo(Version other) {
    var rel = release.compareTo(other.release);
    if (rel != 0) {
      return rel;
    }
    var maj = major.compareTo(other.major);
    if (maj != 0) {
      return maj;
    }
    return minor.compareTo(other.minor);
  }

  @override
  String toString({bool shortened = false}) {
    if (shortened) {
      String result = "$release.$major";
      if (minor > 0) {
        result += ".$minor";
      }
      return result;
    }
    return "$release.$major.$minor";
  }

  @override
  bool operator ==(Object other) {
    return hashCode == other.hashCode;
  }

  @override
  int get hashCode => toString().hashCode;
}

class ManifestDisplay {
  final String title;
  final Uri? thumbnail;
  final String? description;

  ManifestDisplay(this.title, this.thumbnail, this.description);
}

class NamespacedKey {
  final String namespace;
  final String key;

  const NamespacedKey(this.namespace, this.key);

  static NamespacedKey? fromStringOrNull(String string) {
    List<String> split = string.split(":");
    if (split.length < 2) {
      return null;
    }
    final namespace = split[0];
    final key = split.sublist(1).join(":");
    if (namespace.isEmpty || key.isEmpty) {
      return null;
    }
    return NamespacedKey(namespace, key);
  }

  static NamespacedKey fromString(String string) {
    List<String> split = string.split(":");
    if (split.length < 2) {
      throw const FormatException(
          "Namespaced key is not correctly formatted ! Missing a namespace or a key");
    }
    final namespace = split[0];
    final key = split.sublist(1).join(":");
    if (namespace.isEmpty || key.isEmpty) {
      throw const FormatException(
          "Namespaced key is not correctly formatted ! Missing a namespace or a key");
    }
    return NamespacedKey(namespace, key);
  }

  @override
  String toString() {
    return "$namespace:$key";
  }

  String toPath() {
    return "$namespace/$key";
  }

  @override
  bool operator ==(Object other) {
    return hashCode == other.hashCode;
  }

  @override
  int get hashCode => toString().hashCode;
}

class ModpackTheme {
  final Uri? backgroundImage;
  final Uri? bannerImage;

  ModpackTheme(this.backgroundImage, this.bannerImage);

  static Future<ModpackTheme> fromFile(File themeJson) async {
    // Map<String, dynamic> content =
    //     const JsonDecoder().convert(await themeJson.readAsString());
    return ModpackTheme(Directory("${themeJson.parent.path}/backgrounds").uri,
        Directory("${themeJson.parent.path}/banners").uri);
  }
}

class ModpackData {
  final Manifest manifest;
  final ModpackConfig modpackConfig;
  final ModpackTheme theme;
  Directory? installDir;

  ModpackData(
      {required this.manifest,
      required this.modpackConfig,
      required this.theme,
      this.installDir});

  static Future<ModpackData> fromInstallation(Directory source,
      {bool recursePath = false}) async {
    Directory root =
        recursePath ? await searchTreeForRoot(source.uri) ?? source : source;
    final File manFile = File("${root.path}$s${DirNames.fileManifest}");
    final File confFile = File("${root.path}$s${DirNames.fileConfig}");
    if (!await manFile.exists()) {
      throw const FileSystemException(
          "This directory tree does not contain a pack");
    }
    final Manifest man = Manifest.fromJsonString(await manFile.readAsString());
    final ModpackConfig modpackConfig =
        ModpackConfig.fromJsonString(await confFile.readAsString());

    final ModpackTheme theme = await ModpackTheme.fromFile(
        File("${root.path}$s${DirNames.themeFile}"));
    return ModpackData(
        manifest: man,
        modpackConfig: modpackConfig,
        theme: theme,
        installDir: root);
  }

  String get themeDirPath => "$installDir$s${DirNames.installThemeDir}";

  String get patchNoteDirPath => "$installDir$s${DirNames.patchnotes}";

  bool get isInstalled => installDir?.existsSync() ?? false;

  Future<ContentSnapshot?> getContentSnapshot() async {
    return isInstalled
        ? ContentSnapshot.fromDirectory(installDir!, manifest.version)
        : null;
  }
}
