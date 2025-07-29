import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:modshelf/theme/theme_constants.dart';
import 'package:modshelf/tools/adapters/servers.dart';
import 'package:modshelf/tools/engine/package.dart';
import 'package:modshelf/tools/engine/upgrade.dart';

import '../../../main.dart';
import '../../../tools/adapters/local_files.dart';
import '../../../tools/core/core.dart';
import '../../../tools/task_supervisor.dart';
import '../main_page.dart';

class UpgradePackPopup extends StatefulWidget {
  final ModpackData oldVersion;
  final String newVersion;
  final bool asFullCheckUpgrade;

  const UpgradePackPopup(
      {super.key,
      required this.oldVersion,
      required this.newVersion,
      this.asFullCheckUpgrade = false});

  @override
  State<UpgradePackPopup> createState() => _UpgradePackPopupState();
}

Widget buildPatchEntryDisplay(PatchEntry entry,
    {displayFullPath = false, double indentSize = 20}) {
  final pathFragments = entry.relativePath.split("/");
  int indent = pathFragments.length - 1;
  final List<Widget> columnContent = [
    Row(
      children: [
        Padding(
          padding: EdgeInsets.only(left: indent * indentSize),
          child: Text(
            displayFullPath ? entry.relativePath : pathFragments.last,
            maxLines: 3,
            overflow: TextOverflow.fade,
          ),
        ),
      ],
    ),
  ];
  if (entry.comment != null) {
    columnContent.add(Padding(
      padding: EdgeInsets.only(left: (indent + 1) * indentSize),
      child: Text(entry.comment!),
    ));
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: columnContent,
  );
}

class _UpgradePackPopupState extends State<UpgradePackPopup> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final BoxDecoration decoration = BoxDecoration(
        border: Border.all(color: theme.colorScheme.primary, width: 3),
        borderRadius: BorderRadius.circular(200));
    final getPatchContentTask = widget.asFullCheckUpgrade
        ? getUpgradeContent(widget.oldVersion.installDir!)
        : ModshelfServerAgent().requestPatchContent(
            widget.oldVersion.manifest.packId,
            widget.oldVersion.modpackConfig,
            widget.oldVersion.manifest.version,
            widget.newVersion);
    final monoStyle =
        GoogleFonts.robotoMono(textStyle: theme.textTheme.bodySmall);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Upgrade ${widget.oldVersion.manifest.displayData.title}",
              style: theme.textTheme.displaySmall,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: DecoratedBox(
                decoration: decoration,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 0, horizontal: 15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    mainAxisSize: MainAxisSize.min,
                    spacing: 10,
                    children: [
                      Text(
                        widget.oldVersion.manifest.version,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "➞",
                        style: theme.textTheme.displaySmall,
                      ),
                      Text(
                        widget.newVersion,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: FutureBuilder(
                  future: getPatchContentTask,
                  builder: (context, snapshot) {
                    final data = snapshot.data;
                    if (data == null) {
                      return Column(
                        children: [
                          Text(
                            "Building the patch...",
                            style: theme.textTheme.titleLarge,
                          ),
                          const Padding(
                            padding: EdgeInsets.all(100.0),
                            child: CircularProgressIndicator(),
                          )
                        ],
                      );
                    }
                    final added = data.added;
                    final modified = data.modified;
                    final removed = data.removed;
                    return Column(
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                              border: Border.all(
                                  color: theme.colorScheme.surfaceContainerHigh,
                                  width: 2),
                              borderRadius: BorderRadius.circular(
                                  rectangleRoundingRadius)),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                  maxWidth: 800, maxHeight: 400),
                              child: SingleChildScrollView(
                                child: Column(
                                  children: [
                                    ...added.map((v) => Row(
                                          children: [
                                            Text(
                                              "+",
                                              style: monoStyle,
                                            ),
                                            buildPatchEntryDisplay(
                                                v.getSignificant()),
                                          ],
                                        )),
                                    ...modified.map((v) => Row(
                                          children: [
                                            Text(
                                              "~",
                                              style: monoStyle,
                                            ),
                                            buildPatchEntryDisplay(
                                                v.getSignificant()),
                                          ],
                                        )),
                                    ...removed.map((v) => Row(
                                          children: [
                                            Text(
                                              "-",
                                              style: monoStyle,
                                            ),
                                            buildPatchEntryDisplay(
                                                v.getSignificant()),
                                          ],
                                        )),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 40.0),
                          child: MaterialButton(
                              autofocus: true,
                              onPressed: () {
                                if (widget.oldVersion.installDir == null) {
                                  throw const FileSystemException(
                                      "Directory for upgrade is null");
                                }
                                final task = CompleteUpgradePipelineTask(
                                    widget.oldVersion,
                                    widget.oldVersion.installDir!,
                                    data,
                                    description:
                                        "Upgrading ${widget.oldVersion.manifest.displayData.title} to ${widget.newVersion}",
                                    title: widget
                                        .oldVersion.manifest.displayData.title,
                                    manifest: widget.oldVersion.manifest);
                                TaskSupervisor.supervisor.start(task).last.then(
                                    (v) => loadStoredManifests().then((v) {
                                          PageState.setValue(
                                              MainPage.manifestsKey, v);
                                        }));
                                Navigator.of(context, rootNavigator: true)
                                    .pop();
                              },
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
                        ),
                      ],
                    );
                  }),
            ),
          ],
        ),
      ),
    );
  }
}
