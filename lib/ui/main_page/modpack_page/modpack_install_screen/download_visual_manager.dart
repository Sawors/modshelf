import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:modshelf/main.dart';
import 'package:modshelf/tools/adapters/local_files.dart';
import 'package:modshelf/tools/adapters/servers.dart';
import 'package:modshelf/tools/engine/install.dart';
import 'package:modshelf/tools/utils.dart';
import 'package:modshelf/ui/main_page/main_page.dart';

class VisualDownloadManager extends StatefulWidget {
  final ModpackDownloadData downloadData;
  final InstallConfig installConfig;

  const VisualDownloadManager(
      {super.key, required this.downloadData, required this.installConfig});

  @override
  State<VisualDownloadManager> createState() => _VisualDownloadManagerState();
}

class _VisualDownloadManagerState extends State<VisualDownloadManager> {
  late final InstallManager installManager;
  InstallPhase installPhase = InstallPhase.initialization;
  (int, int, List<int>, bool)? downloadState;

  //
  final Duration timerPeriodMs = const Duration(milliseconds: 100);
  final int bpsWindow = 50;
  Queue<int> byteHistory = Queue();
  StreamSubscription? sub;
  Timer? installBytePollTimer;
  int lastByteDl = 0;
  double bytesPerSecond = 0;
  int durationMs = 0;

  //
  TextStyle? monospaceStyle;
  TextStyle? normalStyle;
  TextStyle? biggerStyle;
  TextStyle? titleStyle;
  Color? cardColor;

  //
  StreamSubscription<(InstallPhase, String?)>? subInstall;
  int totalInstallTasks = 0;
  int doneInstallTasks = 0;

  startSequence() {
    installPhase = InstallPhase.downloadingArchive;
    sub = installManager
        .downloadArchive(periodMs: timerPeriodMs.inMilliseconds)
        .listen((data) {
      downloadState = data;

      if (!mounted) {
        return;
      }

      setState(() {
        durationMs += timerPeriodMs.inMilliseconds;
        if (downloadState != null) {
          byteHistory.add(downloadState!.$1 - lastByteDl);
          lastByteDl = downloadState!.$1;
          if (byteHistory.length > bpsWindow) {
            byteHistory.removeFirst();
          }
        }
        bytesPerSecond = byteHistory.fold(0, (b1, b2) => b1 + b2) /
            ((bpsWindow * timerPeriodMs.inMilliseconds) / 1000);
      });

      if (data.$4) {
        sub?.cancel();
        // Download done
        subInstall = installManager
            .installModpack(downloadState!.$3, fakeDelayMs: 100)
            .listen((d) {
          if (installPhase != d.$1) {
            installPhase = d.$1;
            setState(() {});
            doneInstallTasks++;
          }

          if (installPhase == InstallPhase.finish) {
            subInstall?.cancel();
          }
        });
        return;
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    sub?.cancel();
    subInstall?.cancel();
    installBytePollTimer?.cancel();
  }

  @override
  void initState() {
    super.initState();
    const valuesPhase = InstallPhase.values;
    totalInstallTasks = (valuesPhase.length - 2) -
        valuesPhase.indexOf(InstallPhase.extractingArchive);
    installManager =
        InstallManager(widget.downloadData.archive, widget.installConfig);
    byteHistory = Queue.of(List.generate(bpsWindow, (_) => 0));
    startSequence();
  }

  Widget getStateChild(BuildContext context) {
    double standardWidth = 500;
    switch (installPhase) {
      case InstallPhase.initialization:
      case InstallPhase.downloadingArchive:
        Widget indicator = const SizedBox.square(
          dimension: 50,
          child: CircularProgressIndicator(),
        );
        int bCurrent = downloadState?.$1 ?? 0;
        int bTotal = downloadState?.$2 ?? 1;
        if (downloadState != null && bTotal > 0) {
          double progress = bCurrent / bTotal;
          int remainingBytes = bTotal - bCurrent;
          int estimatedTimeS = (remainingBytes / bytesPerSecond).ceil();
          indicator = Column(
            children: [
              Text(
                "Download Progress",
                style: titleStyle,
              ),
              Expanded(
                  child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      "${(progress * 100).toInt()} %",
                      style: biggerStyle,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 5, bottom: 20),
                      child: LinearProgressIndicator(
                        value: progress,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "${bytesToDisplay(bCurrent, displayUnit: false)} / ${bytesToDisplay(bTotal)} (${bytesToDisplay(bytesPerSecond * 8.388608000000088, dataTypeLetter: 'bps', segmentSize: 1000)})",
                          style: monospaceStyle,
                        ),
                        Text(
                          "ETA: ${toDurationDisplay(Duration(seconds: estimatedTimeS), minimize: true, showUnit: true, separator: ' ', padding: ' ')}",
                          style: monospaceStyle,
                        ),
                      ],
                    ),
                  ],
                ),
              ))
            ],
          );
        }
        return SizedBox(
          width: standardWidth,
          height: 160,
          child: Center(
              child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: indicator,
          )),
        );
      case InstallPhase.extractingArchive:
      case InstallPhase.importingOldConfig:
      case InstallPhase.launcherLinking:
      case InstallPhase.linking:
      case InstallPhase.postInstall:
        double progress = doneInstallTasks / totalInstallTasks;
        Widget indicator = Column(
          children: [
            Text(
              "Installation Progress",
              style: titleStyle,
            ),
            Expanded(
                child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "${(progress * 100).toInt()} %",
                    style: biggerStyle,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 5, bottom: 20),
                    child: LinearProgressIndicator(
                      //value: progress,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "$doneInstallTasks / $totalInstallTasks tasks",
                        style: monospaceStyle,
                      ),
                      Text(
                        title(variableNameToText(installPhase.name)),
                        style: monospaceStyle,
                      ),
                    ],
                  ),
                ],
              ),
            ))
          ],
        );

        return SizedBox(
          width: standardWidth,
          height: 160,
          child: Center(
              child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: indicator,
          )),
        );

      case InstallPhase.finish:
        List<String> faces = [
          "(＾▽＾)",
          "(＾ω＾)",
          "(*•‿•*)",
          "(  ͡^  ͜ʖ  ͡^ )",
          "ヘ(* 。* ヘ)",
          "´･ᴗ･`",
          "ヽ(͡◕ ͜ʖ ͡◕)ﾉ",
          "( ͡♥ ͜ʖ ͡♥)",
          "(✿╹◡╹)"
        ];

        String randomFace = faces[Random().nextInt(faces.length)];
        Widget indicator = Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Installation Done !",
              style: titleStyle,
            ),
            // Icon(
            //   Icons.check_circle_outline_rounded,
            //   color: Theme.of(context).colorScheme.primary,
            // ),
            Expanded(
              child: Center(
                child: Tooltip(
                  message: "Close",
                  waitDuration: const Duration(milliseconds: 500),
                  child: MaterialButton(
                      onPressed: () {
                        loadStoredManifests().then((v) {
                          PageState.setValue(ModpackListPage.manifestsKey, v);
                        });
                        Navigator.of(context, rootNavigator: true).pop();
                      },
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("Close",
                                style: biggerStyle?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                )),
                            Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Text(
                                randomFace,
                                style: monospaceStyle?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer),
                              ),
                            ),
                          ],
                        ),
                      )),
                ),
              ),
            ),
          ],
        );
        return SizedBox(
          width: standardWidth,
          height: 160,
          child: Center(
              child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: indicator,
          )),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    normalStyle ??= Theme.of(context).textTheme.bodyMedium;
    biggerStyle ??= Theme.of(context).textTheme.bodyLarge;
    monospaceStyle ??= GoogleFonts.robotoMono(textStyle: normalStyle);
    titleStyle ??= Theme.of(context).textTheme.titleLarge;
    cardColor ??= Theme.of(context).canvasColor;

    return Card(
      color: cardColor,
      child: getStateChild(context),
    );
  }
}
