import 'package:flutter/material.dart';
import 'package:modshelf/tools/adapters/modloaders.dart';

import '../../../theme/theme_constants.dart';
import '../../../tools/adapters/games.dart';
import '../../../tools/core/core.dart';
import '../../../tools/core/manifest.dart';

class SidebarThumbnail extends StatefulWidget {
  final Manifest manifest;
  final ModpackData? modpackData;
  final String? latestVersion;

  const SidebarThumbnail(this.manifest,
      {super.key, this.latestVersion, this.modpackData});

  @override
  State<SidebarThumbnail> createState() => _SidebarThumbnailState();
}

class _SidebarThumbnailState extends State<SidebarThumbnail> {
  @override
  Widget build(BuildContext context) {
    TextStyle? titleStyle = Theme.of(context)
        .textTheme
        .titleLarge
        ?.copyWith(fontWeight: FontWeight.bold);
    TextStyle? linkStyle = Theme.of(context).textTheme.bodyMedium;
    Manifest manifest = widget.manifest;
    var displayData = manifest.displayData;
    GameAdapter? game = GameAdapter.fromId(manifest.game);
    String textLine = game != null ? game.displayName : manifest.game;
    if (manifest.game == noGameNamespace) {
      textLine = "General installation";
    } else {
      // Just putting this in an "else" to avoid checking it if there are no game
      // registered.
      if (manifest.gameVersion.isNotEmpty) {
        textLine += "  (${manifest.gameVersion})";
      }
      if (ModLoader.fromString(manifest.modLoader) != ModLoader.native) {
        textLine += "  ·  ${manifest.modLoader}";
      }
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            SizedBox.square(
              dimension: 60,
              child: AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(rectangleRoundingRadius),
                    child: Image.network(
                      displayData.thumbnail?.toString() ?? defaultThumbnail,
                      fit: BoxFit.contain,
                    ),
                  )),
            ),
            const SizedBox(
              width: 8,
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          displayData.title,
                          style: titleStyle,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            manifest.version.toString(),
                            style: linkStyle,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          textLine,
                          style: linkStyle?.copyWith(
                              color: linkStyle.color?.withValues(alpha: 0.5)),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
