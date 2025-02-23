import 'dart:convert';
import 'dart:io';

import 'package:modshelf/main.dart';
import 'package:modshelf/tools/adapters/launchers.dart';
import 'package:modshelf/tools/adapters/local_files.dart';
import 'package:modshelf/tools/adapters/modloaders.dart';
import 'package:modshelf/tools/core/core.dart';
import 'package:modshelf/tools/utils.dart';

final NamespacedKey steamLibKey = NamespacedKey("game-libraries", "steam");

// class OptionFile {
//   late Map<String, String> keys;
//
//   OptionFile(this.keys);
//
//   OptionFile.fromLines(List<String> lines) {
//     Map<String, String> mapping = {};
//     for (String line in lines) {
//       List<String> split = line.split(":");
//       if (split.length < 2) {
//         continue;
//       }
//       String key = split[0];
//       String value = split.sublist(1).join();
//       mapping[key] = value;
//     }
//     keys = mapping;
//   }
//
//   static Future<OptionFile> fromFile(File f) async {
//     return OptionFile.fromLines(await f.readAsLines());
//   }
//
//   static OptionFile merged(OptionFile base, OptionFile override) {
//     Map<String, String> merged = base.keys;
//     merged.addAll(override.keys);
//     return OptionFile(merged);
//   }
//
//   String asWritableOutput() {
//     return keys.entries.fold(
//         "",
//         (prev, entry) =>
//             prev += "${entry.key}:${entry.value}${Platform.lineTerminator}");
//   }
// }

abstract class GameAdapter {
  static final Map<String, GameAdapter> loaded = {};

  static void loadAdapters() {
    List<GameAdapter> adp = [
      MinecraftAdapter(),
      MarvelRivalsAdapter(),
    ];
    for (GameAdapter ap in adp) {
      loaded[ap.gameId] = ap;
    }
  }

  Directory? get gameDir;

  String get displayName =>
      title(gameId, splitPattern: "-", replacePattern: " ");

  String get completeDisplayName => displayName;

  Directory? get gameDefaultModDir;

  Directory get modshelfGameConfigDir =>
      Directory("${getConfigDir()}${sep}games$sep$gameId");

  String get gameId;

  List<LauncherAdapter> getLaunchers({bool onlyAvailable = true});

  // TODO : REWORK THIS TO WORK BETTER
  List<ModLoader> getModLoaders();

  static GameAdapter? fromId(String id) {
    return loaded[id];
  }

  NamespacedKey get cacheEntryKey => NamespacedKey("games", gameId);
}

class MinecraftAdapter extends GameAdapter {
  @override
  String get gameId => "minecraft";

  @override
  Directory? get gameDir => null;

  @override
  Directory? get gameDefaultModDir => null;

  @override
  List<LauncherAdapter> getLaunchers({bool onlyAvailable = true}) {
    List<LauncherAdapter> launchers = [
      PrismLauncherAdapter(),
      MojangLauncherAdapter()
    ];

    if (!onlyAvailable) {
      return launchers;
    }

    List<LauncherAdapter> output = [];

    for (LauncherAdapter adp in launchers) {
      if (adp.isPresent()) {
        output.add(adp);
      }
    }

    return output;
  }

  @override
  List<ModLoader> getModLoaders() {
    return [ModLoader.neoforge, ModLoader.fabric, ModLoader.forge];
  }
}

abstract class SteamGameAdapter extends GameAdapter {
  List<String> get steamLibraries {
    List<String> output = [];
    if (Platform.isWindows) {
      throw UnimplementedError(
          "Steam library binding is not implemented for Windows");
    }
    if (Platform.isLinux || Platform.isMacOS) {
      String? cachedRoot = CacheManager.getCachedValue(steamLibKey);
      if (cachedRoot != null) {
        JsonDecoder decoder = const JsonDecoder();
        try {
          output = (decoder.convert(cachedRoot) as List<dynamic>)
              .map((b) => b.toString())
              .toList();
        } catch (e) {
          // ignore
        }
      } else {
        final String? homeDir = Platform.environment['HOME'];
        output = [
          "$homeDir/.steam/steam/steamapps/common",
          "$homeDir/.var/app/com.valvesoftware.Steam/.steam/steam/steamapps/common",
          "$homeDir/Games/SteamLibrary/steamapps/common",
        ];
      }
    }
    List<String> filtered =
        output.where((d) => FileSystemEntity.isDirectorySync(d)).toList();
    CacheManager.setCachedValue(
        steamLibKey, const JsonEncoder().convert(filtered));

    return filtered;
  }
}

class MarvelRivalsAdapter extends SteamGameAdapter {
  @override
  Directory? get gameDir {
    final sp = Platform.pathSeparator;
    if (Platform.isWindows) {
      throw UnimplementedError(
          "Windows game binding is not implemented for $displayName");
    }
    if (Platform.isLinux || Platform.isMacOS) {
      String? cachedLocation = CacheManager.getCachedValue(cacheEntryKey);
      if (cachedLocation != null) {
        Directory target = Directory(cachedLocation);
        if (target.existsSync()) {
          return target;
        }
      }
      final tryOrder = steamLibraries;
      const String relativeGameLocation = "MarvelRivals";

      for (String root in tryOrder) {
        Directory test = Directory("$root$sp$relativeGameLocation");
        if (test.existsSync()) {
          CacheManager.setCachedValue(cacheEntryKey, test.path);
          return test;
        }
      }
    }

    return null;
  }

  @override
  Directory? get gameDefaultModDir => gameDir != null
      ? Directory(asPath(
          [gameDir!.path, "MarvelGame", "Marvel", "Content", "Paks", "_mods"]))
      : null;

  @override
  String get gameId => "marvel-rivals";

  @override
  List<LauncherAdapter> getLaunchers({bool onlyAvailable = true}) {
    return [];
  }

  @override
  List<ModLoader> getModLoaders() {
    return [];
  }
}
