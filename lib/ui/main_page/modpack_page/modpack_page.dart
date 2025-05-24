import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:modshelf/main.dart';
import 'package:modshelf/tools/adapters/servers.dart';
import 'package:modshelf/tools/engine/install.dart';
import 'package:modshelf/ui/main_page/sidebar_thumbnail.dart';

import '../../../theme/theme_constants.dart';
import '../../../tools/adapters/local_files.dart';
import '../../../tools/cache.dart';
import '../../../tools/core/core.dart';
import '../../../tools/core/manifest.dart';
import '../../ui_utils.dart';
import '../main_page.dart';
import '../sidebar.dart';
import 'modpack_install_screen/modpack_install_screen.dart';
import 'modpack_page_content.dart';

class ModpackPage extends StatelessWidget {
  final ModpackData? modpackData;

  const ModpackPage({super.key, required this.modpackData});

  Widget getPageContent(BuildContext context) {
    ThemeData flutterTheme = Theme.of(context);
    double cardRadius = 10;
    double cardMargin = 20;

    if (modpackData == null) {
      const double borderRadius = 20.0;
      return Center(
        child: Card(
          elevation: 4,
          color: flutterTheme.canvasColor,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(rectangleRoundingRadius)),
          child: DecoratedBox(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(rectangleRoundingRadius),
                border: Border.all(
                    color: flutterTheme.colorScheme.primary, width: 3)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Add a Modpack",
                    style: flutterTheme.textTheme.displaySmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Card(
                      shape: const CircleBorder(),
                      color: flutterTheme.colorScheme.surfaceContainer,
                      child: SizedBox.square(
                          dimension: 50,
                          child: getAddButton(
                              context, const Duration(seconds: 1))),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      );
    }
    ModpackData notNullData = modpackData!;
    ModpackTheme theme = notNullData.theme;
    Uri? bckgUri = theme.backgroundImage;
    Uri? bnnrUri = theme.bannerImage;
    Widget? background;
    Widget? banner;
    double blur = 6;
    ImageFilter blurFilter = ImageFilter.blur(sigmaX: blur, sigmaY: blur);
    if (bckgUri != null) {
      Image? imgBckg = buildImageFromUri(bckgUri);
      background = ImageFiltered(
        imageFilter: blurFilter,
        child: imgBckg,
      );
    }
    if (bnnrUri != null) {
      Image? imgBnnr = buildImageFromUri(bnnrUri);
      banner = ImageFiltered(
        imageFilter: blurFilter,
        child: imgBnnr,
      );
    }

    List<Widget> stack = [const Center(child: Text("Play me"))];

    if (background != null) {
      stack.insert(0, background);
    }

    TextStyle? titleStyle = flutterTheme.textTheme.displayLarge
        ?.copyWith(fontWeight: FontWeight.bold);

    Color? elevatedCardColor = flutterTheme.colorScheme.surfaceContainerLow;

    return Padding(
      padding: EdgeInsets.only(left: cardMargin * 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(rectangleRoundingRadius),
              child: Container(
                height: 200,
                color: elevatedCardColor,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    banner ?? Container(),
                    Center(
                      child: Text(
                        notNullData.manifest.displayData.title,
                        style: titleStyle,
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ModpackPageContent(
              notNullData,
              elevatedCardColor: elevatedCardColor,
              cardMargin: cardMargin,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1920),
        child: getPageContent(context));
  }
}

enum ModpackUriInputType {
  modshelf,
  modshelfIdClash,
  file,
  manifestImport,
  web,
  unknown,
  invalid;
}

class AddModpackUrlDialog extends StatefulWidget {
  const AddModpackUrlDialog({super.key});

  @override
  State<AddModpackUrlDialog> createState() => _AddModpackUrlDialogState();
}

class _AddModpackUrlDialogState extends State<AddModpackUrlDialog> {
  void showInstallScreen(BuildContext context, Uri modpackUri) {
    Navigator.of(context, rootNavigator: true).pop();
    showDialog(
        context: context,
        builder: (cont) {
          return Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: SingleChildScrollView(
                      child: ModpackInstallScreen(modpackUri))));
        });
  }

  List<NamespacedKey> remoteModpackList = [];
  ServerAgent serverAgent = ModshelfServerAgent();

  Future<(ModpackUriInputType, String)?> isInputValid(String input) async {
    String sanitized = input.trim();
    if (input != controller.text) {
      return null;
    }
    lastSubmittedContent = input;
    Uri? inputUri = Uri.tryParse(sanitized);
    if (inputUri != null) {
      File checkFile = File(inputUri.path);
      if (["http", "https"].contains(inputUri.scheme)) {
        return (ModpackUriInputType.web, inputUri.toString());
      } else if ((inputUri.hasScheme && inputUri.isScheme("file")) ||
          inputUri.pathSegments.length > 1 && await checkFile.exists()) {
        return (
          inputUri.path.endsWith(DirNames.fileManifest)
              ? ModpackUriInputType.manifestImport
              : ModpackUriInputType.file,
          checkFile.path
        );
      } else if (inputUri.pathSegments.length > 1 &&
          await FileSystemEntity.isDirectory(inputUri.path)) {
        File manifestFile = File("${inputUri.path}/${DirNames.fileManifest}");
        if (await manifestFile.exists()) {
          return (ModpackUriInputType.manifestImport, manifestFile.path);
        }
      }
    }
    NamespacedKey? namespacedKey = NamespacedKey.fromStringOrNull(sanitized);
    if (namespacedKey != null) {
      List<NamespacedKey> validId =
          await serverAgent.getModpacks(namespacedKey.namespace);
      return validId.contains(namespacedKey)
          ? (ModpackUriInputType.modshelf, namespacedKey.toString())
          : (ModpackUriInputType.invalid, namespacedKey.toString());
    }

    if (remoteModpackList.isEmpty) {
      remoteModpackList = await serverAgent.getAllModpacks();
    }
    List<NamespacedKey> validId =
        remoteModpackList.where((v) => v.key == sanitized).toList();
    return validId.length > 1
        ? (ModpackUriInputType.modshelfIdClash, validId.join(","))
        : validId.length == 1
            ? (ModpackUriInputType.modshelf, validId.first.toString())
            : (ModpackUriInputType.invalid, sanitized);
  }

  late final Timer timer;
  String lastContent = "";
  String lastSubmittedContent = "";
  String lastEvaluatedContent = "";
  ModpackUriInputType? lastState;
  Future<(ModpackUriInputType, String)?> inputType = Future.value(null);
  String errorMessageStr = "";
  final TextEditingController controller = TextEditingController();

  Uri? getModpackUriFromInput(String content, ServerAgent server) {
    return lastState == ModpackUriInputType.modshelf
        ? server.modpackIdToUri(NamespacedKey.fromString(lastEvaluatedContent))
        : Uri.tryParse(content);
  }

  @override
  void initState() {
    super.initState();
    controller.value = const TextEditingValue(text: "");
    timer = Timer.periodic(const Duration(milliseconds: 200), (t) {
      if (!context.mounted) {
        timer.cancel();
        inputType.ignore();
        return;
      }
      String text = controller.text;
      if (text.isEmpty || text == lastSubmittedContent) {
        return;
      }
      inputType.ignore();
      inputType = isInputValid(text).then((v) {
        lastState = v?.$1;
        String? textOutput = v?.$2;
        if (textOutput != null) {
          lastEvaluatedContent = textOutput;
        }
        setState(() {});
        return v;
      });
    });
  }

  @override
  void dispose() {
    timer.cancel();
    inputType.ignore();
    super.dispose();
  }

  bool isInputValidAsBool() {
    const List<ModpackUriInputType> validTypes = [
      ModpackUriInputType.manifestImport,
      ModpackUriInputType.modshelf
    ];

    return validTypes.contains(lastState);
  }

  @override
  Widget build(BuildContext context) {
    TextStyle? errorMessageStyle =
        Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.red);

    double spacingWidth = 60;

    TextStyle? hint = Theme.of(context).textTheme.bodyLarge;
    hint = hint?.copyWith(color: hint.color?.withValues(alpha: 0.5));

    Color inputIconColor = Colors.transparent;

    Widget bottomAppend = SizedBox(
      height: (errorMessageStyle?.fontSize ?? 14) + 15,
    );

    File manFile = File(lastEvaluatedContent);

    bool inputValid = isInputValidAsBool();

    // async worth it or not ?

    Widget? prefixIcon;
    // VALIDATION
    switch (lastState) {
      case ModpackUriInputType.manifestImport:
        prefixIcon = const Tooltip(
          message: "Modpack found",
          child: Icon(
            Icons.check_rounded,
            color: Colors.green,
          ),
        );
        try {
          String content = manFile.readAsStringSync();
          Manifest man = Manifest.fromJsonString(content);
          bottomAppend = Padding(
            padding: EdgeInsets.symmetric(
                vertical: 10, horizontal: spacingWidth - 5),
            child: Card(
                color: Theme.of(context).colorScheme.surfaceContainer,
                child: SidebarThumbnail(man)),
          );
        } catch (e) {
          if (e is FileSystemException ||
              e is ManifestException ||
              e is JsonUnsupportedObjectError) {
            setState(() {
              lastState = ModpackUriInputType.invalid;
              errorMessageStr = "Manifest file could not be read";
            });
          }
        }
      case ModpackUriInputType.modshelf:
        prefixIcon = const Tooltip(
          message: "Modpack found",
          child: Icon(
            Icons.check_rounded,
            color: Colors.green,
          ),
        );
        ServerAgent serverAgent = ModshelfServerAgent();
        NamespacedKey packKey = NamespacedKey.fromString(lastEvaluatedContent);
        Future<Manifest> future =
            serverAgent.getLatestVersion(packKey).then((v) {
          String? cached = CacheManager.getCachedValue(
              Manifest.cacheKeyFromString(packKey, v));
          if (cached != null) {
            return Future.value(Manifest.fromJsonString(cached));
          }
          return serverAgent
              .fetchManifest(NamespacedKey.fromString(lastEvaluatedContent), v)
              .then((v) {
            CacheManager.setCachedValue(
                Manifest.cacheKeyFromString(packKey, v.version),
                v.asJsonString());
            return v;
          });
        });
        bottomAppend = FutureBuilder(
            future: future,
            builder: (context, snapshot) {
              Widget child = Container();
              if (snapshot.hasData && snapshot.data != null) {
                Manifest data = snapshot.data!;
                child = SidebarThumbnail(data);
              }
              return Padding(
                padding: EdgeInsets.symmetric(
                    vertical: 10, horizontal: spacingWidth - 5),
                child: Center(
                    child: Card(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: child,
                        ))),
              );
            });
      case ModpackUriInputType.unknown:
      case ModpackUriInputType.web:
        prefixIcon = const Tooltip(
          message: "Unknown source",
          child: Icon(
            Icons.question_mark_rounded,
            color: Colors.blue,
          ),
        );
        bottomAppend = Container();
      case ModpackUriInputType.modshelfIdClash:
        prefixIcon = const Tooltip(
          message: "Modpack ID matches multiple modpacks",
          child: Icon(
            Icons.error_rounded,
            color: Colors.orange,
          ),
        );
      case null:
        prefixIcon = Tooltip(
          message: "Enter a value",
          child: Icon(
            Icons.circle_outlined,
            color: Theme.of(context).hintColor,
          ),
        );
      case ModpackUriInputType.invalid:
        prefixIcon = const Tooltip(
          message: "Modpack not found",
          child: Icon(
            Icons.error_rounded,
            color: Colors.red,
          ),
        );
      case ModpackUriInputType.file:
        prefixIcon = const Tooltip(
          message: "File installation is not yet implemented",
          child: Icon(
            Icons.error_rounded,
            color: Colors.blue,
          ),
        );
      // throw UnimplementedError(
      //     "File installation is not yet implemented");
    }

    if (lastState == ModpackUriInputType.modshelf) {
    } else if (lastState == ModpackUriInputType.manifestImport) {
    } else if (errorMessageStr.isNotEmpty) {
      bottomAppend = Text(
        errorMessageStr,
        style: errorMessageStyle,
      );
    }

    InputDecoration inpd = InputDecoration(
        filled: true,
        fillColor: Theme.of(context).canvasColor,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(rectangleRoundingRadius / 2)),
        hintText: "Modpack id or url...",
        hintStyle: hint,
        isDense: true,
        isCollapsed: false,
        prefixIcon: prefixIcon,
        prefixIconColor: inputIconColor,
        contentPadding: const EdgeInsets.all(10));

    TextField textField = TextField(
      controller: controller,
      decoration: inpd,
      contentInsertionConfiguration: ContentInsertionConfiguration(
          onContentInserted: (c) =>
              controller.value = TextEditingValue(text: c.uri)),
      autofocus: true,
      textAlign: TextAlign.left,
      onChanged: (input) {
        //   lastContent = input;
        //   setState(() {
        //     if (input.isNotEmpty) {
        //       if (timer != null && timer!.isActive) {
        //         return;
        //       }
        //       timer = Timer.periodic(const Duration(seconds: 1), (t) {
        //         if (snapshot.connectionState == ConnectionState.done &&
        //             lastContent != lastSubmittedContent) {
        //           setState(() {
        //             inputType = isInputValid(lastContent);
        //           });
        //         }
        //       });
        //       inputType = isInputValid(input);
        //     }
        //   });
      },
      onSubmitted: (content) {
        switch (lastState) {
          case ModpackUriInputType.modshelf:
            Uri? uri = getModpackUriFromInput(content, serverAgent);
            if (uri == null) {
              return;
            }
            showInstallScreen(context, uri);
          case ModpackUriInputType.manifestImport:
            InstallManager.linkManifest(File(lastEvaluatedContent)).then((v) {
              loadStoredManifests().then((v) {
                PageState.setValue(ModpackListPage.manifestsKey, v);
              });
            });
            Navigator.of(context, rootNavigator: true).pop();
          case ModpackUriInputType.file:
            errorMessageStr = "File import is not yet supported";
          case _:
            errorMessageStr = "Modpack URL/ID is not correct";
            setState(() {});
        }
      },
    );

    IconButton nextButton = IconButton(
        tooltip: inputValid ? "Install modpack" : "Invalid input",
        onPressed: inputValid
            ? () {
                (textField.onSubmitted ?? () {})(lastSubmittedContent);
              }
            : null,
        icon: const Icon(Icons.chevron_right_rounded));

    IconButton browseFileButton = IconButton(
        tooltip: "Import archive or manifest.json",
        onPressed: () {
          FilePicker.platform.pickFiles(
              dialogTitle: "Select a file to import",
              allowMultiple: false,
              type: FileType.custom,
              allowedExtensions: [
                "json",
                "zip",
                "tar",
                "gzip",
                "xz"
              ]).then((v) {
            String? text = v?.paths.firstOrNull;
            if (text != null) {
              controller.value = TextEditingValue(text: text);
              (textField.onChanged ?? () {})(text);
            }
          });
        },
        color: Theme.of(context).hintColor,
        icon: const Icon(Icons.folder_outlined));
    const double titleAndBottomHeight = 50;
    return Card(
      color: Theme.of(context).canvasColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: titleAndBottomHeight,
            child: Center(
              child: Text(
                "Add Modpack",
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: spacingWidth,
                child: Center(
                  child: browseFileButton,
                ),
              ),
              Expanded(child: textField),
              SizedBox(
                  width: spacingWidth,
                  child: Center(
                    child: nextButton,
                  )),
            ],
          ),
          Center(
            child: ConstrainedBox(
                constraints:
                    const BoxConstraints(minHeight: 50, maxHeight: 100),
                child: bottomAppend),
          )
        ],
      ),
    );
  }
}
