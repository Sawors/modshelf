import 'package:flutter/material.dart';
import 'package:modshelf/theme/theme_constants.dart';
import 'package:modshelf/tools/core/core.dart';
import 'package:modshelf/ui/main_page/modpack_page/page_content/details_page.dart';
import 'package:modshelf/ui/main_page/modpack_page/page_content/history_page.dart';
import 'package:modshelf/ui/main_page/modpack_page/page_content/modlist_page.dart';
import 'package:modshelf/ui/main_page/modpack_page/page_content/patchnote_page.dart';
import 'package:modshelf/ui/main_page/modpack_page/page_content/readme_page.dart';

enum ModpackPageContentType { patchnote, readme, history, details, modList }

class ModpackPageContent extends StatefulWidget {
  final Color? elevatedCardColor;
  final double cardMargin;
  final ModpackData data;

  const ModpackPageContent(this.data,
      {Key? key, this.elevatedCardColor, this.cardMargin = 10})
      : super(key: key);

  @override
  _ModpackPageContentState createState() => _ModpackPageContentState();
}

class _ModpackPageContentState extends State<ModpackPageContent> {
  ModpackPageContentType pageType = ModpackPageContentType.readme;

  ButtonSegment<ModpackPageContentType> getMenuButton(
      ModpackPageContentType value, String name) {
    bool selected = pageType == value;
    final TextStyle? buttonTextStyle = Theme.of(context)
        .textTheme
        .titleLarge
        ?.copyWith(
            fontWeight: FontWeight.bold,
            color: selected
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : null);
    return ButtonSegment<ModpackPageContentType>(
      value: value,
      label: SizedBox(
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
              color: selected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              borderRadius: BorderRadius.circular(rectangleRoundingRadius)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: Text(
                name,
                style: buttonTextStyle,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget pageContent = Center(child: Text(pageType.name));

    final ThemeData theme = Theme.of(context);
    final ButtonStyle buttonStyle = SegmentedButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: 0),
        //selectedForegroundColor: theme.colorScheme.primary,
        selectedBackgroundColor: theme.colorScheme.surfaceContainerLow,
        backgroundColor: theme.colorScheme.surfaceContainerLow,
        overlayColor: Colors.transparent,
        side: const BorderSide(width: 0, color: Colors.transparent),
        visualDensity: VisualDensity.comfortable,
        shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.red, width: 2),
            borderRadius: BorderRadius.circular(rectangleRoundingRadius)),
        elevation: 2,
        alignment: Alignment.center);

    switch (pageType) {
      case ModpackPageContentType.patchnote:
        pageContent = PatchnotePage();
        break;
      case ModpackPageContentType.readme:
        pageContent = ReadmePage();
        break;
      case ModpackPageContentType.history:
        pageContent = HistoryPage();
        break;
      case ModpackPageContentType.details:
        pageContent = DetailsPage();
        break;
      case ModpackPageContentType.modList:
        pageContent = ModlistPage();
        break;
    }

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: widget.cardMargin / 1.61),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton(
              style: buttonStyle,
              showSelectedIcon: false,
              segments: <ButtonSegment<ModpackPageContentType>>[
                getMenuButton(ModpackPageContentType.readme, "Home"),
                getMenuButton(ModpackPageContentType.patchnote, "Patchnote"),
                getMenuButton(ModpackPageContentType.modList, "Mod List"),
                getMenuButton(ModpackPageContentType.history, "History"),
                getMenuButton(ModpackPageContentType.details, "Details"),
              ],
              selected: <ModpackPageContentType>{pageType},
              onSelectionChanged: (Set<ModpackPageContentType> newSelection) {
                setState(() {
                  // By default there is only a single segment that can be
                  // selected at one time, so its value is always the first
                  // item in the selected set.
                  pageType = newSelection.first;
                });
              },
            ),
          ),
        ),
        Expanded(
          child: Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(rectangleRoundingRadius)),
              color: widget.elevatedCardColor,
              margin: EdgeInsets.zero,
              // margin: EdgeInsets.only(
              //     top: widget.cardMargin / 1.61803399,
              //     left: widget.cardMargin * 2),
              child: pageContent),
        ),
      ],
    );
  }
}
