import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:modshelf/tools/adapters/games.dart';
import 'package:modshelf/tools/adapters/modloaders.dart';
import 'package:modshelf/tools/core/core.dart';
import 'package:modshelf/tools/engine/package.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../tools/adapters/servers.dart';
import '../../../../../tools/core/manifest.dart';
import '../../../../../tools/utils.dart';
import '../../../../ui_utils.dart';
import 'install_mode_selection.dart';

class InstallScreenData {
  final ModpackDownloadData modpackData;
  final GameAdapter? game;

  InstallScreenData({required this.modpackData, required this.game});
}

class ModpackInstallScreen extends StatelessWidget {
  final InstallScreenData installScreenData;
  final ContentSnapshot contentSnapshot;
  static final NamespacedKey pageState =
      NamespacedKey("modpack-install-screen", "global");

  const ModpackInstallScreen(this.installScreenData, this.contentSnapshot,
      {super.key});

  Color getColorForModloader(ModLoader modloader,
      {Color defaultColor = Colors.deepPurpleAccent}) {
    switch (modloader) {
      case ModLoader.forge:
        return Colors.blueGrey;
      case ModLoader.fabric:
        return Colors.lightGreenAccent;
      case ModLoader.neoforge:
        return Colors.orangeAccent;
      case ModLoader.native:
        return Colors.purpleAccent;
    }
  }

  Widget _getInfoRowChip(BuildContext context, String title,
      {Widget? icon, String? subtitle, Color? titleColor, Widget? iconAppend}) {
    TextTheme theme = Theme.of(context).textTheme;
    double internalPadding = 4;
    double iconHeight = (theme.bodyLarge?.fontSize ?? 14);

    List<Widget> children = [
      Padding(
        padding: EdgeInsets.symmetric(horizontal: internalPadding),
        child: Text(
          title,
          style: theme.bodyLarge
              ?.copyWith(fontWeight: FontWeight.bold, color: titleColor),
        ),
      )
    ];

    if (icon != null) {
      children.insert(
          0,
          Padding(
            padding: EdgeInsets.symmetric(horizontal: internalPadding),
            child: SizedBox(height: iconHeight, child: icon),
          ));
    }

    if (subtitle != null) {
      children.add(Padding(
        padding: EdgeInsets.symmetric(horizontal: internalPadding),
        child: Text(
          subtitle,
          style: theme.bodyLarge
              ?.copyWith(color: theme.bodyLarge?.color?.withValues(alpha: 0.5)),
        ),
      ));
    }

    if (iconAppend != null) {
      children.add(iconAppend);
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: children,
        ),
      ),
    );
  }

  Widget buildModpackQuickInfoRow(
      BuildContext context, InstallScreenData data) {
    String modLoader = data.modpackData.manifest.modLoader;
    ThemeData theme = Theme.of(context);
    InputDecorationTheme inputDecorationTheme = theme.inputDecorationTheme;
    TextStyle? mainStyle = theme.textTheme.bodyLarge;
    inputDecorationTheme = inputDecorationTheme.copyWith(
      isDense: true,
      constraints: BoxConstraints.tight(const Size.fromHeight(35)),
      suffixStyle:
          mainStyle?.copyWith(color: mainStyle.color?.withValues(alpha: 0.66)),
      contentPadding: const EdgeInsets.only(left: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    );
    List<Widget> details = [
      _getInfoDisplay(context, "Game", title(data.modpackData.manifest.game)),
      _getInfoDisplay(context, "Version", data.modpackData.manifest.version),
      _getInfoDisplay(
          context, "Game Version", data.modpackData.manifest.gameVersion),
      _getInfoDisplay(context, "Install Size",
          bytesToDisplay(data.modpackData.archiveSize)),
    ];
    if (modLoader.toLowerCase() != ModLoader.native.name) {
      details.insert(
        details.length,
        _getInfoDisplay(
          context,
          "Mod Loader",
          "${title(modLoader)} ${data.modpackData.manifest.modLoaderVersion}",
        ),
      );
    }
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 4,
      crossAxisSpacing: 80,
      childAspectRatio: 8,
      children: details
          .map((e) => Align(
                alignment: Alignment.bottomLeft,
                child: e,
              ))
          .toList(),
    );
  }

  Widget _getInfoDisplay(BuildContext context, String? title, String? details,
      {Widget? label, Widget? value}) {
    TextTheme theme = Theme.of(context).textTheme;
    TextStyle? mainStyle = theme.bodyLarge;
    if (label == null && title == null) {
      throw ArgumentError("One of 'label' or 'title' must be non-null!");
    }
    if (value == null && details == null) {
      throw ArgumentError("One of 'value' or 'details' must be non-null!");
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        label ??
            Text(
              title ?? "TITLE CANNOT BE NULL",
              style: mainStyle?.copyWith(fontWeight: FontWeight.bold),
            ),
        value ??
            Text(
              details ?? "DETAILS CANNOT BE NULL",
              style: mainStyle?.copyWith(
                  color: mainStyle.color?.withValues(alpha: 0.66)),
            )
      ],
    );
  }

  Widget buildAdvancedInfoPanel(BuildContext context, InstallScreenData data) {
    String modloader = data.modpackData.manifest.modLoader;
    ModLoader knownModloader =
        ModLoader.fromString(data.modpackData.manifest.modLoader);
    String mlVersion = data.modpackData.manifest.modLoaderVersion;
    List<Widget> details = [
      Tooltip(
        message: "Game Version",
        child: _getInfoRowChip(context,
            title(data.game?.displayName ?? data.modpackData.manifest.game),
            subtitle: data.modpackData.manifest.gameVersion),
      ),
    ];
    if (knownModloader != ModLoader.native) {
      details.insert(
        0,
        Tooltip(
          message: "Mod Loader",
          child: _getInfoRowChip(context, title(modloader),
              subtitle:
                  mlVersion.isNotEmpty && knownModloader != ModLoader.native
                      ? mlVersion
                      : null,
              icon: FittedBox(
                child: SvgPicture.asset(
                  knownModloader.svgIconAsset,
                  colorFilter: ColorFilter.mode(
                      colorForThemeBrightness(Theme.of(context),
                          getColorForModloader(knownModloader)),
                      BlendMode.srcIn),
                ),
              )),
        ),
      );
    }
    return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: details);
  }

  Widget buildModpackPresentation(BuildContext context, Manifest manifest) {
    TextStyle? modpackTitleStyle = Theme.of(context)
        .textTheme
        .displaySmall
        ?.copyWith(fontWeight: FontWeight.bold);

    Widget thumbnail = SizedBox.square(
      dimension: 130,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child:
              Image.network(manifest.displayData.thumbnail?.toString() ?? ""),
        ),
      ),
    );

    final description = manifest.displayData.description ??
        "A ${manifest.gameVersion} ${title(manifest.modLoader)} modpack.";

    Uri? authorLink = manifest.authorLink;
    Widget authorNameText = Text(
      manifest.author ?? "Unknown Author",
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.color
              ?.withValues(alpha: 0.66)),
    );
    Widget authorName = Padding(
      padding: const EdgeInsets.only(top: 15.0),
      child: authorLink != null
          ? Tooltip(
              message: manifest.authorLink.toString(),
              child: InkWell(
                  onTap: () {
                    Uri? authorLink = manifest.authorLink;
                    if (authorLink != null) {
                      launchUrl(authorLink);
                    }
                  },
                  child: authorNameText),
            )
          : authorNameText,
    );

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                thumbnail,
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10.0, horizontal: 35),
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Text(
                            manifest.displayData.title,
                            style: modpackTitleStyle,
                          ),
                        ),
                        Text(
                          description,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        authorName
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget child = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        buildModpackPresentation(
            context, installScreenData.modpackData.manifest),
        // const Divider(
        //   indent: 20,
        //   endIndent: 20,
        // ),
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: SizedBox(
              height: 110,
              //constraints: BoxConstraints(maxHeight: 150),
              child: buildModpackQuickInfoRow(context, installScreenData)),
        ),
        const Divider(
          indent: 15,
          endIndent: 15,
        ),
        Padding(
          padding: const EdgeInsets.all(10.0),
          child: Text(
            "Install Mode",
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        InstallModeSelection(
          downloadData: installScreenData,
          downloadContent: contentSnapshot,
        )
      ],
    );

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
              padding: const EdgeInsets.only(
                  left: 20.0, right: 20.0, bottom: 20.0, top: 10.0),
              child: child)
        ],
      ),
    );
  }
}
