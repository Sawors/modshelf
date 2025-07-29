import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:modshelf/tools/adapters/games.dart';
import 'package:modshelf/tools/adapters/launchers.dart';
import 'package:modshelf/ui/main_page/pages/modpack_page/modpack_install_screen/modpack_install_screen.dart';

import 'file_picker_field.dart';
import 'install_mode_selection.dart';

class InstallConfigGrid extends StatefulWidget {
  final TemporaryInstallConfig configMap;
  final InstallMode installMode;
  final List<LauncherAdapter> availableLaunchers;
  final InstallScreenData installData;
  final Null Function() onConfigUpdate;

  const InstallConfigGrid(
      {super.key,
      required this.configMap,
      required this.installMode,
      required this.availableLaunchers,
      required this.installData,
      required this.onConfigUpdate});

  @override
  _InstallConfigGridState createState() => _InstallConfigGridState();
}

Future<Directory?> getDefaultInstallDir(bool isStandalone, String modpackName,
    {bool checkExist = true,
    bool checkEmpty = true,
    LauncherAdapter? launcher,
    GameAdapter? game}) async {
  if (game == null && launcher == null) {
    return null;
  }
  Directory? targetPath;
  if (launcher != null) {
    targetPath = Directory("${launcher.getProfilesDir().path}/$modpackName");
  }
  if (targetPath == null && game != null && game.gameDefaultModDir != null) {
    targetPath = Directory("${game.gameDefaultModDir!.path}/$modpackName");
  }
  if (targetPath == null) {
    return null;
  }

  if (await targetPath.exists()) {
    if (checkExist) {
      throw PathExistsException(
          targetPath.path, const OSError("Directory already exists"));
    }
    if (checkEmpty && !await targetPath.list().isEmpty) {
      throw PathAccessException(
          targetPath.path, const OSError("Directory is not empty"));
    }
  }
  return targetPath;
}

Future<Directory?> getAutoInstallDir(bool isStandalone, String modpackName,
    {LauncherAdapter? launcher, GameAdapter? game}) async {
  Directory? defaultDir;
  String baseDir = "";
  try {
    defaultDir = await getDefaultInstallDir(isStandalone, modpackName,
        launcher: launcher, game: game, checkExist: false);
    if (defaultDir != null) {
      return defaultDir;
    }
  } on PathAccessException {
    // ignore
  } on PathExistsException {
    // ignore too
  }

  Directory? bsd = await getDefaultInstallDir(
      isStandalone,
      launcher: launcher,
      modpackName,
      game: game,
      checkEmpty: false,
      checkExist: false);
  if (bsd == null || bsd.path.isEmpty) {
    return null;
  }
  baseDir = bsd.path;

  if (defaultDir != null && defaultDir.path.isNotEmpty) {
    return defaultDir;
  }

  for (int i = 1; i <= 100 || defaultDir != null; i++) {
    String checkPath = "$baseDir($i)";
    Directory checkDir = Directory(checkPath);
    if (!(await checkDir.exists()) || await checkDir.list().isEmpty) {
      return checkDir;
    }
  }
  return null;
}

class _InstallConfigGridState extends State<InstallConfigGrid> {
  Widget getOptionSelector(
      BuildContext context, String title, Widget selector) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        selector
      ],
    );
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    widget.onConfigUpdate();
  }

  Widget getOptionCheckbox(
      BuildContext context, String title, ConfigField configEntry,
      {bool defaultState = false, Function(bool)? onTick}) {
    bool checkBoxValue = bool.tryParse(
            widget.configMap.getFromConfigField(configEntry).toString()) ??
        false;
    return getOptionSelector(
        context,
        title,
        Checkbox(
            value: checkBoxValue,
            visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
            splashRadius: 0,
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  try {
                    if (onTick != null) {
                      onTick(value);
                    } else {
                      widget.configMap.setConfigField(configEntry, value);
                    }
                  } on TypeError {
                    if (kDebugMode) {
                      print("Field $configEntry cannot be set to a boolean");
                    }
                  }
                });
              }
            }));
  }

  List<Widget> getInstallGrid(BuildContext context, InstallMode installMode) {
    List<Widget> gridContent = [];
    switch (installMode) {
      case InstallMode.launcher:
        gridContent = [
          getOptionCheckbox(
              context, "Create Profile", ConfigField.createProfile),
        ];
        break;
      case InstallMode.standalone:
    }

    List<LauncherAdapter> launchers =
        widget.installData.game?.getLaunchers(onlyAvailable: false) ?? [];
    if (launchers.isNotEmpty && launchers.first.hasProfile) {
      gridContent.add(
        getOptionCheckbox(
            context, "Import Configurations", ConfigField.importOldConfigs),
      );
    }

    if (widget.configMap.importOldConfig) {
      List<(String, String)> importList = [
        ("Import Options", "options.txt"),
        ("Import Resource Packs", "resourcepacks/"),
        ("Import Shader Packs", "shaderpacks/"),
      ];
      for (var entry in importList) {
        gridContent.add(
          getOptionSelector(
              context,
              entry.$1,
              Checkbox(
                  value:
                      widget.configMap.oldConfigImportList.contains(entry.$2),
                  visualDensity:
                      const VisualDensity(horizontal: -4, vertical: -4),
                  splashRadius: 0,
                  onChanged: (value) {
                    if (value != null) {
                      if (value) {
                        widget.configMap.oldConfigImportList.add(entry.$2);
                      } else {
                        widget.configMap.oldConfigImportList.remove(entry.$2);
                      }
                      setState(() {});
                    }
                  })),
        );
      }

      gridContent.add(getOptionSelector(
          context,
          "Source",
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 10),
              child: FilePickerField(
                onTextSubmitted: (v) {
                  widget.configMap.oldConfigDir = v;
                  setState(() {});
                },
                defaultContent: widget.configMap.oldConfigDir,
              ),
            ),
          )));
    }
    return gridContent;
  }

  double longFieldWidth = 351;

  @override
  Widget build(BuildContext context) {
    LauncherAdapter? adapter = widget.configMap.launcherType?.getAdapter();

    Future<Directory?> defineDefaultInstallDir = getAutoInstallDir(
        widget.configMap.installMode == InstallMode.standalone,
        launcher: adapter,
        game: widget.installData.game,
        widget.installData.modpackData.manifest.name);

    InputDecorationTheme inputDecorationTheme =
        Theme.of(context).inputDecorationTheme;
    inputDecorationTheme = inputDecorationTheme.copyWith(
      isDense: true,
      constraints: BoxConstraints.tight(const Size.fromHeight(35)),
      suffixStyle: Theme.of(context).textTheme.titleMedium,
      contentPadding: const EdgeInsets.only(left: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    );
    List<DropdownMenuEntry<LauncherType?>> launchers = widget.availableLaunchers
        .map((e) =>
            DropdownMenuEntry(value: e.launcherType, label: e.displayName))
        .toList();
    List<Widget> gridContent = getInstallGrid(context, widget.installMode);

    double height = 150;
    if (widget.configMap.importOldConfig) {
      height += 100;
    }

    return SizedBox(
      height: height,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: getOptionSelector(
                context,
                "Install Directory",
                SizedBox(
                    width: longFieldWidth,
                    child: FutureBuilder(
                        future: defineDefaultInstallDir,
                        builder: (context, snapshot) {
                          String data = snapshot.data?.path ?? "";
                          if (widget.configMap.installDirPath.isNotEmpty ||
                              snapshot.connectionState ==
                                  ConnectionState.done) {
                            if (widget.configMap.installDirPath.isEmpty) {
                              widget.configMap.installDirPath = data;
                              // Future.delayed(
                              //     const Duration(milliseconds: 100), () {
                              //   print("delayed");
                              //   if (mounted) {
                              //     setState(() {});
                              //   }
                              // });
                            }
                            return FilePickerField(
                              onTextSubmitted: (t) {
                                widget.configMap.installDirPath = t;
                                setState(() {});
                              },
                              defaultContent: widget.configMap.installDirPath,
                            );
                          }
                          return DecoratedBox(
                            decoration: BoxDecoration(
                                border: Border.all(
                                    color: Theme.of(context).hintColor),
                                borderRadius: BorderRadius.circular(10)),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 13),
                                child: SizedBox.square(
                                  dimension: 10,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: Theme.of(context)
                                        .primaryTextTheme
                                        .bodyMedium
                                        ?.color,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }))),
          ),
          widget.installMode == InstallMode.launcher
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: getOptionSelector(
                      context,
                      "Launcher",
                      DropdownMenu<LauncherType?>(
                        dropdownMenuEntries: launchers,
                        width: longFieldWidth,
                        initialSelection: widget.configMap.launcherType,
                        enableSearch: true,
                        inputDecorationTheme: inputDecorationTheme,
                        textStyle: Theme.of(context).textTheme.titleMedium,
                        onSelected: (v) {
                          widget.configMap.launcherType = v;
                          if (widget.configMap.launcherType != v) {
                            widget.configMap.installDirPath = "";
                          }
                          setState(() {});
                        },
                      )),
                )
              : Container(),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 8,
              mainAxisSpacing: 20,
              crossAxisSpacing: 80,
              children: gridContent,
            ),
          ),
        ],
      ),
    );
  }
}
