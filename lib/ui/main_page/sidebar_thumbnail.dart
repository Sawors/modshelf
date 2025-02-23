import 'package:flutter/material.dart';
import 'package:modshelf/tools/adapters/modloaders.dart';

import '../../theme/theme_constants.dart';
import '../../tools/adapters/games.dart';
import '../../tools/adapters/servers.dart';
import '../../tools/core/core.dart';
import '../../tools/core/manifest.dart';

class SidebarThumbnail extends StatefulWidget {
  final Manifest modpackData;
  final ServerAgent? serverAgent;

  const SidebarThumbnail(this.modpackData, {super.key, this.serverAgent});

  @override
  State<SidebarThumbnail> createState() => _SidebarThumbnailState();
}

class _SidebarThumbnailState extends State<SidebarThumbnail> {
  Version? latest;

  @override
  Widget build(BuildContext context) {
    TextStyle? titleStyle = Theme.of(context)
        .textTheme
        .titleLarge
        ?.copyWith(fontWeight: FontWeight.bold);
    TextStyle? linkStyle = Theme.of(context).textTheme.bodyMedium;
    Manifest manifest = widget.modpackData;
    var displayData = widget.modpackData.displayData;
    GameAdapter? game = GameAdapter.fromId(widget.modpackData.game);
    String textLine = game != null ? game.displayName : widget.modpackData.game;
    if (manifest.gameVersion.isNotEmpty) {
      textLine += "  (${manifest.gameVersion})";
    }
    if (ModLoader.fromString(manifest.modLoader) != ModLoader.native) {
      textLine += "  ·  ${manifest.modLoader}";
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
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          displayData.thumbnail?.toString() ?? defaultThumbnail,
                          fit: BoxFit.contain,
                        ),
                      ],
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
                        FutureBuilder(
                            future: widget.serverAgent?.getLatestVersion(
                                    widget.modpackData.packId) ??
                                Future.value(null),
                            builder: (context, snapshot) {
                              if (snapshot.data == null) {
                                return Container();
                              }
                              Version oldVersion = Version.fromString(
                                  widget.modpackData.version);
                              Version? latestCheck =
                                  Version.tryFromString(snapshot.data);
                              if (latestCheck != null) {
                                latest = latestCheck;
                              }
                              if (latest == null || oldVersion == latest) {
                                return Container();
                              }
                              String message =
                                  "Your version is above the latest published version.";
                              IconData icon = Icons.question_mark_rounded;
                              Color color = Colors.blue;

                              if (latest!.release > oldVersion.release) {
                                message = "New release available !";
                                icon = Icons.error_rounded;
                                color = Colors.red;
                              }
                              if (latest!.major > oldVersion.major) {
                                message = "New update available !";
                                icon = Icons.error_outline_rounded;
                                color = Colors.orangeAccent;
                              }
                              if (latest!.minor > oldVersion.minor) {
                                message = "New patch available !";
                                icon = Icons.circle_outlined;
                                color = Colors.green;
                              }
                              return Tooltip(
                                message: message,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: 3.0, right: 4),
                                  child: Icon(
                                    icon,
                                    color: color,
                                    size: (titleStyle?.fontSize ?? 16),
                                  ),
                                ),
                              );
                            }),
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
            )
          ],
        ),
      ],
    );
  }
}
