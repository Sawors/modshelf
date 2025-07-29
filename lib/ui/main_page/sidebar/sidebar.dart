import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:modshelf/main.dart';
import 'package:modshelf/self_updater/self_update_checker.dart';
import 'package:modshelf/tools/adapters/local_files.dart';
import 'package:modshelf/tools/adapters/servers.dart';
import 'package:modshelf/ui/main_page/main_page.dart';
import 'package:modshelf/ui/main_page/pages/settings_page/settings_page.dart';
import 'package:modshelf/ui/main_page/sidebar/download_page_button.dart';
import 'package:modshelf/ui/main_page/sidebar/page_navigation_button.dart';
import 'package:modshelf/ui/main_page/sidebar/sidebar_thumbnail.dart';
import 'package:modshelf/ui/main_page/sidebar/upgrade_modshelf_popup.dart';
import 'package:modshelf/ui/main_page/sidebar/upgrade_pack_popup.dart';
import 'package:modshelf/ui/ui_utils.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../theme/theme_constants.dart';
import '../../../tools/core/core.dart';
import '../pages/modpack_page/modpack_page.dart';

class Sidebar extends StatelessWidget {
  static const NamespacedKey downloadPageKey =
      NamespacedKey("downloads", "main");

  final List<ModpackData>? modpackList;
  final NamespacedKey selectedSubpage;
  static const Duration tooltipWait = Duration(seconds: 1);
  static const double listItemExtent = 90;

  const Sidebar(
      {super.key, required this.modpackList, required this.selectedSubpage});

  Widget getSidebarContent(
      BuildContext context, List<ModpackData>? modpackList) {
    final int selectedIndex = selectedSubpage.namespace == "index"
        ? int.tryParse(selectedSubpage.key) ?? -1
        : -1;
    if (modpackList == null) {
      return const Center(
        child: SizedBox.square(
          dimension: 50,
          child: CircularProgressIndicator(),
        ),
      );
    }

    return ListView.builder(
      itemExtent: listItemExtent,
      controller: ScrollController(
          keepScrollOffset: false,
          initialScrollOffset: max(0, selectedIndex - 4) * listItemExtent),
      padding: const EdgeInsets.all(0),
      shrinkWrap: true,
      itemCount: modpackList.length,
      itemBuilder: (BuildContext context, int index) {
        ModpackData md = modpackList[index];
        return Tooltip(
          waitDuration: tooltipWait,
          message: md.installDir?.path ?? "Unknown Install Location",
          child: Padding(
            padding: const EdgeInsets.all(2.0),
            child: FutureBuilder(
                future: ModshelfServerAgent().hasUpgrade(md.manifest),
                builder: (context, asyncSnapshot) {
                  return ContextMenuRegion(
                      contextMenu: getContextMenu(context, md, index,
                          latest: asyncSnapshot.data),
                      child: PageNavigationButton(
                        trackedPage: NamespacedKey("index", index.toString()),
                        shape: (context, selected) => RoundedRectangleBorder(
                            side: index == selectedIndex
                                ? BorderSide(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    width: 2)
                                : BorderSide.none,
                            borderRadius: BorderRadius.circular(
                                rectangleRoundingRadius / 2)),
                        child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: SidebarThumbnail(
                                    md.manifest,
                                    modpackData: md,
                                  ),
                                ),
                                getUpgradeButton(
                                    context, asyncSnapshot.data, md)
                              ],
                            )),
                      )
                      // MaterialButton(
                      //   animationDuration: const Duration(milliseconds: 300),
                      //   materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      //   color: index == selectedIndex
                      //       ? theme.colorScheme.surfaceContainerLow
                      //       : theme.canvasColor,
                      //   shape: RoundedRectangleBorder(
                      //       side: index == selectedIndex
                      //           ? BorderSide(
                      //               color: theme.colorScheme.primary, width: 2)
                      //           : BorderSide.none,
                      //       borderRadius: BorderRadius.circular(
                      //           rectangleRoundingRadius / 2)),
                      //   onPressed: () {
                      //     int finalIndex = selectedIndex == index ? -1 : index;
                      //     final NamespacedKey target = selectedIndex >= 0
                      //         ? NamespacedKey("index", finalIndex.toString())
                      //         : MainPage.mainPageKey;
                      //     MainPage.goToPage(target);
                      //   },
                      //   splashColor: Colors.transparent,
                      //   elevation: 0,
                      //   hoverElevation: 2,
                      //   child: Padding(
                      //       padding: const EdgeInsets.symmetric(
                      //           vertical: 10, horizontal: 4),
                      //       child: Row(
                      //         children: [
                      //           Expanded(
                      //             child: SidebarThumbnail(
                      //               md.manifest,
                      //               modpackData: md,
                      //             ),
                      //           ),
                      //           getUpgradeButton(context, asyncSnapshot.data, md)
                      //         ],
                      //       )),
                      // ),
                      );
                }),
          ),
        );
      },
      addRepaintBoundaries: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    const Widget taskManagerButton = DownloadPageButton();
    final theme = Theme.of(context);
    return SizedBox.fromSize(
      size: const Size.fromWidth(350),
      child: DecoratedBox(
          decoration: BoxDecoration(
              color: theme.canvasColor,
              borderRadius: BorderRadius.circular(rectangleRoundingRadius),
              border: Border.all(
                  color: theme.colorScheme.surfaceContainerLow, width: 2)),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Center(
                  child: Text(
                    "Installations",
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ),
              Container(
                color: theme.colorScheme.surfaceContainer,
                height: 2,
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Flexible(child: getSidebarContent(context, modpackList)),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: getAddButton(context, tooltipWait),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  spacing: 8,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Expanded(
                      child: PageNavigationButton(
                        trackedPage: SettingsPage.settingsPageKey,
                        minHeight: 45,
                        child: Icon(Icons.settings),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: SelfUpgradeChecker.updateAvailable
                    ? Column(
                        spacing: 8,
                        children: [
                          Tooltip(
                              waitDuration: const Duration(seconds: 1),
                              message:
                                  "Update available : ${SelfUpgradeChecker.selfInstallData?.manifest.version} → ${SelfUpgradeChecker.newVersion}",
                              child: MaterialButton(
                                onPressed: () {
                                  showDialog(
                                      context: context,
                                      builder: (context) => const Center(
                                            child: UpgradeModshelfPopup(),
                                          ));
                                },
                                splashColor: Colors.transparent,
                                animationDuration:
                                    const Duration(milliseconds: 300),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                //color: theme.canvasColor,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        rectangleRoundingRadius - 6)),
                                minWidth: double.infinity,
                                height: 45,
                                child: Text(
                                  "System update available !",
                                  style: theme.textTheme.titleMedium?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold),
                                ),
                              )),
                          taskManagerButton,
                        ],
                      )
                    : taskManagerButton,
              )
            ],
          )
          //     }),
          //
          ),
    );
  }

  Widget getUpgradeButton(
      BuildContext context, String? latestVersion, ModpackData sourceData) {
    final latest = Version.tryFromString(latestVersion);
    final oldVersion = Version.fromString(sourceData.manifest.version);
    final bool hasUpgrade = latest != null;
    if (!hasUpgrade) {
      return Container();
    }
    String message = "Your version is above the latest published version.";
    final IconData icon = latest.release > oldVersion.release
        ? Icons.question_mark_rounded
        : Icons.file_download_outlined;
    Color color = Colors.blue;

    if (latest.release > oldVersion.release) {
      message = "New release available\n$oldVersion  →  $latest";
      color = Colors.red;
    }
    if (latest.major > oldVersion.major) {
      message = "New update available\n$oldVersion  →  $latest";
      color = Colors.orangeAccent;
    }
    if (latest.minor > oldVersion.minor) {
      message = "New patch available\n$oldVersion  →  $latest";
      color = Colors.green;
    }
    return Tooltip(
      message: message,
      textAlign: TextAlign.center,
      child: MaterialButton(
        onPressed: () {
          showDialog(
              context: context,
              builder: (context) => Center(
                    child: UpgradePackPopup(
                        oldVersion: sourceData,
                        newVersion: latest.toString(),
                        asFullCheckUpgrade: false),
                  ));
        },
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(rectangleRoundingRadius / 2)),
        minWidth: 0,
        padding:
            const EdgeInsetsGeometry.symmetric(horizontal: 10, vertical: 10),
        elevation: 5,
        child: Icon(
          icon,
          color: color,
        ),
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
    BuildContext context, ModpackData modpackData, int index,
    {String? latest}) {
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
                        PageState.getValue(MainPage.manifestsKey) ?? [];
                    PageState.setValue(
                        MainPage.manifestsKey, mans..removeAt(index));
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
                        PageState.getValue(MainPage.manifestsKey) ?? [];
                    PageState.setValue(
                        MainPage.manifestsKey, mans..removeAt(index));
                    modpackData.installDir?.delete(recursive: true);
                    Navigator.of(context, rootNavigator: true).pop();
                  },
                ),
              );
            });
      },
    ),
  ];

  if (latest != null) {
    entries.insertAll(2, [
      MenuItem(
        label: 'Upgrade',
        icon: Icons.file_download_outlined,
        onSelected: () {
          showDialog(
              context: context,
              builder: (context) => Center(
                    child: UpgradePackPopup(
                        oldVersion: modpackData,
                        newVersion: latest,
                        asFullCheckUpgrade: false),
                  ));
        },
      ),
      MenuItem(
        label: 'Upgrade and check',
        icon: Icons.move_up,
        onSelected: () {
          showDialog(
              context: context,
              builder: (context) => Center(
                    child: UpgradePackPopup(
                        oldVersion: modpackData,
                        newVersion: latest,
                        asFullCheckUpgrade: true),
                  ));
        },
      ),
    ]);
  }

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
    message: "Add a pack",
    child: IconButton(
      onPressed: () {
        // TaskSupervisor.supervisor.start(DownloadTask(
        //     Uri.parse(
        //         "https://sawors.net/modshelf/api/minecraft/tiboise-2/1.9/content"),
        //     description: "Downloading the modpack",
        //     title: "Tiboise 2",
        //     pollingPeriodMs: animationPeriodMs + 10));
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
