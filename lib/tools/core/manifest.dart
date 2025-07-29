import 'dart:convert';

import 'core.dart';

class Manifest {
  static const String unknownValuePlaceholder = "unknown";

  late final String name;
  late final String game;
  late final String version;
  late final String gameVersion;
  late final String modLoader;
  late final String modLoaderVersion;
  final List<String> tags = [];
  late final ManifestDisplay displayData;
  late final String? author;
  late final Uri? authorLink;

  Manifest(this.displayData,
      {required this.name,
      required this.version,
      required this.gameVersion,
      required this.modLoader,
      required this.modLoaderVersion,
      required this.game,
      this.author,
      this.authorLink});

  NamespacedKey get packId => NamespacedKey(game, name);

  Manifest.fromJsonString(String json) {
    var result = jsonDecode(json) as Map<String, dynamic>;
    name = result["name"].toString();
    version = result["version"].toString();
    game = result["game"].toString();
    gameVersion = result["game-version"].toString();
    modLoader = result["modloader"].toString().toLowerCase();
    modLoaderVersion = result["modloader-version"].toString();
    String title = name;
    Uri? thumbnail;
    String? description;
    if (result.containsKey("display")) {
      Map<String, dynamic> displaySubcat = result["display"];
      title = displaySubcat["title"] ?? name;
      thumbnail = Uri.tryParse(displaySubcat["thumbnail"]);
      description = displaySubcat["description"];
    }

    if (result.containsKey("links")) {
      Map<String, dynamic> linksSubcat = result["links"];
      if (linksSubcat.containsKey("author")) {
        dynamic authorCat = linksSubcat["author"];
        if (authorCat is String) {
          author = authorCat;
          authorLink = null;
        } else if (authorCat is Map<String, dynamic>) {
          author = authorCat["name"];
          authorLink = Uri.tryParse(authorCat["link"]);
        }
      }
    } else {
      author = null;
      authorLink = null;
    }
    displayData = ManifestDisplay(title, thumbnail, description);
    if (result.containsKey("tags") && result["tags"] is List<dynamic>) {
      tags.addAll((result["tags"] as List<dynamic>).map((e) => e.toString()));
    }
  }

  @override
  String toString() {
    final Map<String, String> displayMap = {
      "title": displayData.title,
    };
    if (displayData.description != null) {
      displayMap["description"] = displayData.description!;
    }
    if (displayData.thumbnail != null) {
      displayMap["thumbnail"] = displayData.thumbnail.toString();
    }

    final Map<String, String> authorMap = {};
    if (author != null) {
      authorMap["name"] = author!;
    }
    if (authorLink != null) {
      authorMap["link"] = authorLink.toString();
    }

    final Map<String, dynamic> jsonMap = {
      "name": name,
      "version": version,
      "game": game,
      "game-version": gameVersion,
      "modloader": modLoader,
      "modloader-version": modLoaderVersion,
      "tags": tags,
      "display": displayMap,
    };
    if (authorMap.isNotEmpty) {
      jsonMap["author"] = authorMap;
    }
    return const JsonEncoder().convert(jsonMap);
  }

  String toJsonString() {
    return toString();
  }

  static NamespacedKey cacheKeyFromString(
      NamespacedKey packId, String version) {
    return NamespacedKey("manifest-db", "${packId.toString()}.$version");
  }
}

class ManifestException implements Exception {
  ManifestException(String message);
}
