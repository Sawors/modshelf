import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:modshelf/main.dart';
import 'package:modshelf/tools/adapters/local_files.dart';
import 'package:modshelf/tools/adapters/servers.dart';
import 'package:modshelf/ui/main_page/main_page.dart';
import 'package:modshelf/ui/main_page/sidebar_thumbnail.dart';
import 'package:modshelf/ui/ui_utils.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/theme_constants.dart';
import '../../tools/cache.dart';
import '../../tools/core/core.dart';
import 'modpack_page/modpack_page.dart';

class Sidebar extends StatelessWidget {
  final List<ModpackData>? modpackList;
  final int selectedIndex;
  static const Duration tooltipWait = Duration(seconds: 1);

  const Sidebar(
      {super.key, required this.modpackList, required this.selectedIndex});

  Widget getSidebarContent(
      BuildContext context, List<ModpackData>? modpackList) {
    if (modpackList == null) {
      return const Center(
        child: SizedBox.square(
          dimension: 50,
          child: CircularProgressIndicator(),
        ),
      );
    }

    ThemeData theme = Theme.of(context);

    return ListView.separated(
      controller: ScrollController(
          keepScrollOffset: false,
          // 86 is arbitrary and represents the height of a list element.
          // NOT DYNAMIC !!!! COULD LEAD TO STRANGE BEHAVIOUR IN THE FUTURE !!
          initialScrollOffset: max(0, selectedIndex - 4) * 88.0),
      padding: const EdgeInsets.all(0),
      itemCount: modpackList.length,
      itemBuilder: (BuildContext context, int index) {
        ModpackData md = modpackList[index];
        return Tooltip(
          waitDuration: tooltipWait,
          message: md.installDir?.path ?? "Unknown Install Location",
          child: Padding(
            padding: const EdgeInsets.all(2.0),
            child: ContextMenuRegion(
              contextMenu: getContextMenu(context, md, index),
              child: MaterialButton(
                animationDuration: const Duration(milliseconds: 300),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                color: index == selectedIndex
                    ? theme.colorScheme.surfaceContainerLow
                    : theme.canvasColor,
                shape: RoundedRectangleBorder(
                    side: index == selectedIndex
                        ? BorderSide(color: theme.colorScheme.primary, width: 2)
                        : BorderSide.none,
                    borderRadius:
                        BorderRadius.circular(rectangleRoundingRadius / 2)),
                onPressed: () {
                  int finalIndex = selectedIndex == index ? -1 : index;
                  PageState.setValue(ModpackListPage.indexKey, finalIndex);
                  CacheManager.setCachedValue(
                      ModpackListPage.indexCacheKey, finalIndex.toString());
                  // if (context.mounted) {
                  //   ModpackPageStatusContainer.of(context)
                  //       .onIndexUpdate(index);
                  // }
                  //setState(() {});
                },
                splashColor: Colors.transparent,
                elevation: 0,
                hoverElevation: 2,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  child: SidebarThumbnail(
                    md.manifest,
                    serverAgent: ModshelfServerAgent(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      addRepaintBoundaries: false,
      separatorBuilder: (BuildContext context, int index) => const SizedBox(
        height: 4,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: const Size.fromWidth(350),
      child: DecoratedBox(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(rectangleRoundingRadius),
              border: Border.all(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  width: 2)),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Center(
                  child: Text(
                    "ModPacks",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Container(
                  color: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.color
                      ?.withAlpha(25),
                  height: 1,
                ),
              ),
              Expanded(child: getSidebarContent(context, modpackList)),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: getAddButton(context, tooltipWait),
              )
            ],
          )
          //     }),
          //
          ),
    );
  }
}

class DeleteModpackConfirmDialog extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? display;
  final Function()? onCancel;
  final Function() onConfirm;

  const DeleteModpackConfirmDialog(
      {super.key,
      required this.title,
      required this.subtitle,
      this.onCancel,
      this.display,
      required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: display ??
                  const SizedBox.square(
                    dimension: 0,
                  ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                subtitle,
                style: theme.textTheme.titleMedium,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                MaterialButton(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                        side: BorderSide(
                            color: theme.colorScheme.primary, width: 2)),
                    onPressed: onCancel ??
                        () {
                          Navigator.of(context, rootNavigator: true).pop();
                        },
                    child: const Text("Cancel")),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 20)),
                MaterialButton(
                    onPressed: onConfirm,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                        side: const BorderSide(color: Colors.red, width: 3)),
                    child: Text(
                      "Confirm",
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.redAccent, fontWeight: FontWeight.bold),
                    ))
              ],
            )
          ],
        ),
      ),
    );
  }
}

ContextMenu getContextMenu(
    BuildContext context, ModpackData modpackData, int index) {
  final theme = Theme.of(context);

  Widget linkHint = Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Text(
      modpackData.installDir?.path ?? "",
      style: theme.textTheme.bodyMedium
          ?.copyWith(color: theme.disabledColor, fontStyle: FontStyle.italic),
    ),
  );

  final entries = <ContextMenuEntry>[
    MenuHeader(text: modpackData.manifest.displayData.title),
    MenuItem(
      label: 'Open in explorer',
      icon: Icons.open_in_browser_rounded,
      onSelected: () {
        Uri? target = modpackData.installDir?.uri;
        if (target != null) {
          launchUrl(target);
        }
      },
    ),
    const MenuDivider(),
    MenuItem(
      label: 'Remove from Modshelf',
      icon: Icons.delete_outline_rounded,
      onSelected: () {
        showDialog(
            context: context,
            builder: (subContext) {
              return Center(
                child: DeleteModpackConfirmDialog(
                  title:
                      "Are you sure you want to remove this modpack from Modshelf ?",
                  subtitle:
                      "This action does NOT delete the modpack from your disk !",
                  display: linkHint,
                  onConfirm: () {
                    List<ModpackData> mans =
                        PageState.getValue(ModpackListPage.manifestsKey) ?? [];
                    PageState.setValue(
                        ModpackListPage.manifestsKey, mans..removeAt(index));
                    Directory? dir = modpackData.installDir;
                    if (dir != null) {
                      LocalFiles()
                          .manifestStoreDir
                          .list(followLinks: false, recursive: true)
                          .firstWhere((t) {
                        if (!FileSystemEntity.isLinkSync(t.path)) {
                          return false;
                        }
                        Link link = Link(t.path);
                        bool isValid = link.targetSync().startsWith(dir.path);
                        return isValid;
                      }, orElse: () => File("")).then((l) {
                        if (l.path.isNotEmpty &&
                            FileSystemEntity.isLinkSync(l.path)) {
                          l.delete(recursive: false);
                        }
                      });
                    }
                    Navigator.of(context, rootNavigator: true).pop();
                  },
                ),
              );
            });
      },
    ),
    StyledMenuItem(
      label: Text(
        'Delete',
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: Colors.red, fontWeight: FontWeight.bold),
      ),
      value: "Delete",
      icon: Icons.delete_forever_rounded,
      onSelected: () {
        showDialog(
            context: context,
            builder: (subContext) {
              return Center(
                child: DeleteModpackConfirmDialog(
                  title: "Are you sure you want to delete this modpack ?",
                  subtitle: "This action cannot be undone",
                  display: linkHint,
                  onConfirm: () {
                    List<ModpackData> mans =
                        PageState.getValue(ModpackListPage.manifestsKey) ?? [];
                    PageState.setValue(
                        ModpackListPage.manifestsKey, mans..removeAt(index));
                    modpackData.installDir?.delete(recursive: true);
                    Navigator.of(context, rootNavigator: true).pop();
                  },
                ),
              );
            });
      },
    ),
  ];

// initialize a context menu
  final menu = ContextMenu(
    entries: entries,
    padding: const EdgeInsets.all(8.0),
  );

  return menu;
}

Widget getAddButton(BuildContext context, Duration tooltipWait) {
  return Tooltip(
    waitDuration: tooltipWait,
    message: "Install Modpack",
    child: IconButton(
      onPressed: () {
        showDialog(
            context: context,
            builder: (cont) {
              return Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: const AddModpackUrlDialog()),
              );
            });
      },
      icon: const Icon(Icons.add),
      style: IconButton.styleFrom(
        shape: const CircleBorder(),
      ),
    ),
  );
}
