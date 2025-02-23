import 'dart:io';

import 'package:flutter/material.dart';
import 'package:modshelf/tools/engine/install.dart';
import 'package:modshelf/ui/main_page/modpack_page/modpack_install_screen/modpack_install_screen.dart';

import '../../../../tools/adapters/launchers.dart';
import '../../../../tools/core/manifest.dart';
import 'download_visual_manager.dart';
import 'install_config_grid.dart';

enum InstallMode {
  launcher,
  standalone;
}

class InstallModeSelection extends StatefulWidget {
  final InstallScreenData downloadData;

  const InstallModeSelection({super.key, required this.downloadData});

  @override
  _InstallModeSelectionState createState() => _InstallModeSelectionState();
}

enum ConfigField {
  installMode,
  launcherType,
  createProfile,
  installDir,
  importOldConfigs,
  oldConfigDir,
}

class ConfigValidationResult {
  final ConfigField field;
  final dynamic value;
  final bool isValid;
  final String errorMessage;

  ConfigValidationResult(
      this.field, this.value, this.isValid, this.errorMessage);
}

class TemporaryInstallConfig {
  List<LauncherAdapter> availableLaunchers = [];

  InstallMode installMode;
  LauncherType? launcherType;
  bool createProfile;
  String installDirPath;
  bool importOldConfig;
  List<String> oldConfigImportList;
  String oldConfigDir;

  TemporaryInstallConfig(
      this.installMode,
      this.launcherType,
      this.createProfile,
      this.installDirPath,
      this.importOldConfig,
      this.oldConfigImportList,
      this.oldConfigDir);

  @override
  String toString() {
    String result = "\nConfig :\n";
    for (ConfigField c in ConfigField.values) {
      result += "  ${c.name}: ${getFromConfigField(c)}\n";
    }
    result += "  Import List: ${oldConfigImportList.toString()}\n";
    return result;
  }

  Future<ConfigValidationResult> isFieldValid(ConfigField field) async {
    // using value here for a more stable behaviour since the only argument is
    // the config field and not the expected value;
    dynamic value = getFromConfigField(field);
    switch (field) {
      case ConfigField.installMode:
      case ConfigField.createProfile:
      case ConfigField.importOldConfigs:
        break;
      case ConfigField.launcherType:
        installMode == InstallMode.standalone ||
            (value != null &&
                availableLaunchers.any((t) => value == t.launcherType));
      case ConfigField.installDir:
        if (value.toString().isEmpty || value == "/") {
          return ConfigValidationResult(
              field, value, false, "Install directory cannot be empty.");
        }
        Directory target = Directory(value);
        bool exists = await target.exists();
        bool isEmpty = exists && await target.list().isEmpty;
        bool res = !exists || isEmpty;
        String errorMessage = "";
        if (exists && !isEmpty) {
          errorMessage = "Install directory already exists and is not empty.";
        }
        return ConfigValidationResult(field, value, res, errorMessage);
      case ConfigField.oldConfigDir:
        Directory target = Directory(value);
        bool exists = await target.exists();
        bool isEmpty = exists && await target.list().isEmpty;
        bool res = !importOldConfig || (exists && !isEmpty);
        String commonErrorMsg = "Source directory for config import";
        String errorMessage = !exists
            ? "$commonErrorMsg does not exist."
            : isEmpty
                ? "$commonErrorMsg is empty."
                : "working ??????? $exists $isEmpty";
        return ConfigValidationResult(
            field, value, res, res ? "" : errorMessage);
    }

    return ConfigValidationResult(field, value, true, "");
  }

  Future<bool> isValid() async {
    return !(await areFieldsValid()).any((v) => !v.isValid);
  }

  Future<List<ConfigValidationResult>> areFieldsValid() async {
    List<ConfigValidationResult> res = [];
    for (ConfigField f in ConfigField.values) {
      res.add(await isFieldValid(f));
    }
    return res;
  }

  dynamic getFromConfigField(ConfigField field) {
    switch (field) {
      case ConfigField.installMode:
        return installMode;
      case ConfigField.launcherType:
        return launcherType;
      case ConfigField.createProfile:
        return createProfile;
      case ConfigField.installDir:
        return installDirPath;
      case ConfigField.importOldConfigs:
        return importOldConfig;
      case ConfigField.oldConfigDir:
        return oldConfigDir;
    }
  }

  setConfigField(ConfigField field, dynamic value) {
    switch (field) {
      case ConfigField.installMode:
        if (value.runtimeType == installMode.runtimeType) {
          installMode = value;
        } else {
          throw TypeError();
        }
      case ConfigField.launcherType:
        if (value.runtimeType == launcherType.runtimeType) {
          launcherType = value;
        } else {
          throw TypeError();
        }
      case ConfigField.createProfile:
        if (value.runtimeType == createProfile.runtimeType) {
          createProfile = value;
        } else {
          throw TypeError();
        }
      case ConfigField.installDir:
        if (value.runtimeType == installDirPath.runtimeType) {
          installDirPath = value;
        } else {
          throw TypeError();
        }
      case ConfigField.importOldConfigs:
        if (value.runtimeType == importOldConfig.runtimeType) {
          importOldConfig = value;
        } else {
          throw TypeError();
        }
      case ConfigField.oldConfigDir:
        if (value.runtimeType == oldConfigDir.runtimeType) {
          oldConfigDir = value;
        } else {
          throw TypeError();
        }
    }
  }

  // a isValid check should be done before this !!. No security check will be done here.
  InstallConfig toInstallConfig(Manifest manifest) {
    return InstallConfig(
        installLocation: Directory(installDirPath),
        manifest: manifest,
        mainProfileSource: Directory(oldConfigDir),
        mainProfileImport: oldConfigImportList,
        linkToLauncher: createProfile,
        launcherType: launcherType,
        keepArchive: true);
  }
}

class _InstallModeSelectionState extends State<InstallModeSelection> {
  InstallMode installMode = InstallMode.launcher;

  // doing this to keep InstallConfig final and to allow for more parsing abilities
  TemporaryInstallConfig installConfigMap = TemporaryInstallConfig(
      InstallMode.launcher, null, true, "", false, [], "");

  Widget buttonLabel(bool selected, String label, {bool enabled = true}) {
    ThemeData theme = Theme.of(context);
    //Color enabledCardColor = theme.colorScheme.surfaceContainerHigh;
    Color enabledCardBorderColor =
        theme.colorScheme.primary.withValues(alpha: 0.9);
    TextStyle? selectedStyle = Theme.of(context).textTheme.bodyLarge;
    //selectedStyle = selectedStyle?.copyWith(fontWeight: FontWeight.bold);
    TextStyle? defaultStyle = Theme.of(context).textTheme.bodyLarge;
    TextStyle? disabledStyle =
        defaultStyle?.copyWith(color: theme.disabledColor);
    EdgeInsets cardPadding =
        const EdgeInsets.symmetric(vertical: 5.0, horizontal: 15);

    BorderRadiusGeometry borderRadius =
        const BorderRadius.all(Radius.circular(100));

    return Tooltip(
      message:
          enabled ? "" : "Disabled because no compatible launcher was found.",
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
        elevation: enabled ? null : 0,
        color: enabled ? null : theme.colorScheme.surfaceContainer,
        child: Container(
          decoration: BoxDecoration(
              border: Border.all(
                  color: selected ? enabledCardBorderColor : Colors.transparent,
                  width: 3),
              borderRadius: borderRadius),
          padding: cardPadding,
          child: Text(
            label,
            style: enabled
                ? selected
                    ? selectedStyle
                    : defaultStyle
                : disabledStyle,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    ButtonStyle? style = SegmentedButton.styleFrom(
        selectedForegroundColor: theme.colorScheme.primary,
        selectedBackgroundColor: Colors.transparent,
        overlayColor: Colors.transparent,
        side: BorderSide.none,
        visualDensity: VisualDensity.compact,
        elevation: 0,
        alignment: Alignment.center);

    installConfigMap.installMode = installMode;
    List<LauncherAdapter> availableLaunchers =
        widget.downloadData.game?.getLaunchers() ?? [];
    if (installConfigMap.availableLaunchers.isEmpty) {
      installConfigMap.availableLaunchers = availableLaunchers;
    }
    bool isStandaloneOnly = installConfigMap.availableLaunchers.isEmpty;
    if (isStandaloneOnly) {
      installMode = InstallMode.standalone;
    }

    if (installMode == InstallMode.launcher &&
        installConfigMap.launcherType == null) {
      installConfigMap.launcherType =
          installConfigMap.availableLaunchers[0].launcherType;
    }

    double installButtonHeight = 40;

    return Column(
      children: [
        SegmentedButton<InstallMode>(
          style: style,
          showSelectedIcon: false,
          segments: <ButtonSegment<InstallMode>>[
            ButtonSegment<InstallMode>(
                value: InstallMode.launcher,
                label: buttonLabel(
                    installMode == InstallMode.launcher, "Launcher Install",
                    enabled: !isStandaloneOnly),
                enabled: !isStandaloneOnly),
            ButtonSegment<InstallMode>(
              value: InstallMode.standalone,
              label: buttonLabel(
                  installMode == InstallMode.standalone, "Standalone Install"),
            ),
          ],
          selected: <InstallMode>{installMode},
          onSelectionChanged: (Set<InstallMode> newSelection) {
            setState(() {
              // By default there is only a single segment that can be
              // selected at one time, so its value is always the first
              // item in the selected set.
              installMode = newSelection.first;
            });
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          child: InstallConfigGrid(
            installMode: installMode,
            configMap: installConfigMap,
            availableLaunchers: installConfigMap.availableLaunchers,
            installData: widget.downloadData,
            onConfigUpdate: () {
              setState(() {});
            },
          ),
        ),
        SizedBox(
          height: installButtonHeight,
          child: FutureBuilder(
            future: installConfigMap.areFieldsValid(),
            builder: (BuildContext context,
                AsyncSnapshot<List<ConfigValidationResult>> snapshot) {
              List<ConfigValidationResult> snapshotData = snapshot.data ?? [];
              bool isValid = snapshotData.isNotEmpty &&
                  !snapshotData.any((d) => !d.isValid);
              if (true) {
                if (isValid) {
                  bool isFutureDone =
                      snapshot.connectionState == ConnectionState.done;
                  return Tooltip(
                    message:
                        isFutureDone ? "" : "Input verification in process...",
                    child: MaterialButton(
                        autofocus: true,
                        onPressed: isFutureDone
                            ? () {
                                Navigator.of(context, rootNavigator: true)
                                    .pop();
                                showDialog(
                                    context: context,
                                    builder: (cont) {
                                      return Center(
                                          child: VisualDownloadManager(
                                        downloadData:
                                            widget.downloadData.modpackData,
                                        installConfig: installConfigMap
                                            .toInstallConfig(widget.downloadData
                                                .modpackData.manifest),
                                      ));
                                    });
                              }
                            : () {},
                        color: theme.colorScheme.surfaceContainer,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          child: Text(
                            "Install →",
                            style: theme.textTheme.titleLarge,
                          ),
                        )),
                  );
                } else {
                  TextStyle? errorStyle = theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.error);
                  List<Text> messages = snapshotData
                      .where((c) => !c.isValid && c.errorMessage.isNotEmpty)
                      .map((c) => Text(
                            c.errorMessage,
                            style: errorStyle,
                          ))
                      .toList();
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: messages,
                    ),
                  );
                }
              }
            },
          ),
        )
      ],
    );
  }
}
