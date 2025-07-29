import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:modshelf/self_updater/self_update_checker.dart';
import 'package:modshelf/tools/engine/install.dart';
import 'package:modshelf/tools/engine/package.dart';
import 'package:modshelf/ui/main_page/sidebar/upgrade_pack_popup.dart';

import '../../../main.dart';
import '../../../theme/theme_constants.dart';
import '../../../tools/adapters/servers.dart';
import '../../../tools/cache.dart';
import '../../../tools/engine/upgrade.dart';
import '../../../tools/task_supervisor.dart';
import '../main_page.dart';

class UpgradeModshelfPopup extends StatelessWidget {
  const UpgradeModshelfPopup({super.key});

  static const String pageKey = "popup:force-restart";

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final BoxDecoration decoration = BoxDecoration(
        border: Border.all(color: theme.colorScheme.primary, width: 3),
        borderRadius: BorderRadius.circular(200));
    final monoStyle =
        GoogleFonts.robotoMono(textStyle: theme.textTheme.bodySmall);
    final oldV = SelfUpgradeChecker.selfInstallData;
    final newV = SelfUpgradeChecker.newVersion;
    final installDir = oldV?.installDir;
    final ModshelfServerAgent agent = ModshelfServerAgent();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Upgrade Modshelf",
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
                        oldV?.manifest.version ?? "",
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "➞",
                        style: theme.textTheme.displaySmall,
                      ),
                      Text(
                        newV ?? "",
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
              child: installDir == null || oldV == null || newV == null
                  ? Text(
                      "Modshelf is not tracked !\nSelf-updating will not work.",
                      style: theme.textTheme.displaySmall,
                    )
                  : FutureBuilder(
                      future: ModshelfServerAgent().requestPatchContent(
                          oldV.manifest.packId,
                          oldV.modpackConfig,
                          oldV.manifest.version,
                          newV),
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
                                      color: theme
                                          .colorScheme.surfaceContainerHigh,
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
                              child: FutureBuilder(
                                  future: getUpgradeContent(installDir),
                                  builder: (context, snapshot) {
                                    final data = snapshot.data;
                                    if (data == null) {
                                      return const CircularProgressIndicator();
                                    }
                                    return MaterialButton(
                                        autofocus: true,
                                        onPressed: () {
                                          final task = DownloadTask(
                                              agent,
                                              ContentSnapshot(
                                                  data
                                                      .onlyChanged()
                                                      .where((p) =>
                                                          p.type !=
                                                          PatchDifferenceType
                                                              .removed)
                                                      .map((p) =>
                                                          p.getSignificant())
                                                      .toSet(),
                                                  data.version),
                                              SelfUpgradeChecker.modshelfPackId,
                                              description:
                                                  "Downloading the new version of Modshelf.",
                                              title: "Modshelf Self-Update");
                                          TaskSupervisor.supervisor
                                              .start(task)
                                              .last
                                              .then((v) {
                                            print(v.data);
                                            if (v.data == null) {
                                              return null;
                                            }
                                            final tgFile = File(v.data!);
                                            // Allowing sync reading since these are usually small files
                                            // and it simplifies the code.
                                            return (
                                              tgFile,
                                              sha256.convert(
                                                  tgFile.readAsBytesSync())
                                            );
                                          }).then((v) {
                                            if (v != null) {
                                              CacheManager.instance
                                                  .setCachedEntry(
                                                      SelfUpgradeChecker
                                                          .upgradeFileCacheId,
                                                      CacheEntry.immortal(
                                                          v.$1.path));
                                              CacheManager.instance.setCachedEntry(
                                                  SelfUpgradeChecker
                                                      .upgradeManifestJsonCacheId,
                                                  CacheEntry.immortal(oldV
                                                      .manifest
                                                      .toJsonString()));
                                              CacheManager.instance.setCachedEntry(
                                                  SelfUpgradeChecker
                                                      .upgradePatchJsonCacheId,
                                                  CacheEntry.immortal(
                                                      jsonEncode(data
                                                          .toJsonObject())));
                                              CacheManager.instance
                                                  .setCachedEntry(
                                                      SelfUpgradeChecker
                                                          .upgradeFileHashCacheId,
                                                      CacheEntry.immortal(
                                                          v.$2.toString()));
                                            }
                                            PageState.setValue(
                                                MainPage.indexKey, pageKey);
                                          });
                                          Navigator.of(context,
                                                  rootNavigator: true)
                                              .pop();
                                        },
                                        color:
                                            theme.colorScheme.surfaceContainer,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(100)),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 5),
                                          child: Text(
                                            "Install →",
                                            style: theme.textTheme.titleLarge,
                                          ),
                                        ));
                                  }),
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
