import 'dart:convert';
import 'dart:io';

import 'package:modshelf/tools/adapters/launchers.dart';
import 'package:modshelf/tools/adapters/local_files.dart';
import 'package:modshelf/tools/adapters/modloaders.dart';
import 'package:modshelf/tools/core/core.dart';
import 'package:modshelf/tools/utils.dart';

import '../cache.dart';

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
  List<ModLoader> get modLoaders;

  List<String> get versions;

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
  List<ModLoader> get modLoaders {
    return [ModLoader.neoforge, ModLoader.fabric, ModLoader.forge];
  }

  @override
  List<String> get versions => [
        '1.0',
        '1.1',
        '1.2',
        '1.3',
        '1.4',
        '1.5',
        '1.6',
        '1.7',
        '1.8',
        '1.9',
        '1.10',
        '1.11',
        '1.12',
        '1.13',
        '1.14',
        '1.15',
        '1.16',
        '1.17',
        '1.18',
        '1.19',
        '1.20',
        '1.20.3',
        '1.20.5',
        '1.21',
        '1.21.2',
        '1.21.4',
        '1.21.5',
        '1.21.3',
        '1.21.1',
        '1.20.6',
        '1.20.4',
        '1.20.2',
        '1.20.1',
        '1.19.4',
        '1.19.3',
        '1.19.2',
        '1.19.1',
        '1.18.2',
        '1.18.1',
        '1.17.1',
        '1.16.5',
        '1.16.4',
        '1.16.3',
        '1.16.2',
        '1.16.1',
        '1.15.2',
        '1.15.1',
        '1.14.4',
        '1.14.3',
        '1.14.2',
        '1.14.1',
        '1.13.2',
        '1.13.1',
        '1.12.2',
        '1.12.1',
        '1.11.2',
        '1.11.1',
        '1.10.2',
        '1.10.1',
        '1.9.4',
        '1.9.3',
        '1.9.2',
        '1.9.1',
        '1.8.9',
        '1.8.8',
        '1.8.7',
        '1.8.6',
        '1.8.5',
        '1.8.4',
        '1.8.3',
        '1.8.2',
        '1.8.1',
        '1.7.10',
        '1.7.9',
        '1.7.8',
        '1.7.7',
        '1.7.6',
        '1.7.5',
        '1.7.4',
        '1.7.3',
        '1.7.2',
        '1.6.4',
        '1.6.2',
        '1.6.1',
        '1.5.2',
        '1.5.1',
        '1.4.7',
        '1.4.5',
        '1.4.6',
        '1.4.4',
        '1.4.2',
        '1.3.2',
        '1.3.1',
        '1.2.5',
        '1.2.4',
        '1.2.3',
        '1.2.2',
        '1.2.1'
      ];
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
  List<ModLoader> get modLoaders => [];

  @override
  List<String> get versions => [];
}
