import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:modshelf/theme/theme_constants.dart';
import 'package:modshelf/tools/utils.dart';
import 'package:modshelf/ui/main_page/pages/download_page/task_progress_monitor.dart';
import 'package:modshelf/ui/ui_utils.dart';

import '../../../../../../tools/tasks.dart';

class TaskWidget extends StatefulWidget {
  final Task task;

  const TaskWidget(this.task, {super.key});

  @override
  _TaskWidgetState createState() => _TaskWidgetState();
}

class _TaskWidgetState extends State<TaskWidget> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void deactivate() {
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final theme = Theme.of(context);
    final monospaceStyle =
        GoogleFonts.robotoMono(textStyle: theme.textTheme.bodyMedium);
    final monospaceStyleBigger =
        GoogleFonts.robotoMono(textStyle: theme.textTheme.bodyLarge);
    String? thumbnailUrl = task.manifest?.displayData.thumbnail?.toString();
    Widget thumbnail = thumbnailUrl != null
        ? Image.network(thumbnailUrl)
        : Stack(
            children: [
              Container(
                color: Colors.primaries.elementAt(
                    Random(task.id.hashCode).nextInt(Colors.primaries.length)),
              ),
              Center(
                  child: Text(task.title[0],
                      style: theme.textTheme.displaySmall
                          ?.copyWith(fontWeight: FontWeight.bold))),
            ],
          );

    final isQueue = task is TaskQueue;
    final bool isDone = task.isDone;

    return Row(
      spacing: 5,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox.square(
          dimension: 60,
          child: Align(
            alignment: Alignment.topCenter,
            child: AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(rectangleRoundingRadius - 10),
                  child: thumbnail),
            ),
          ),
        ),
        const SizedBox(
          width: 5,
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                spacing: 10,
                children: [
                  Text(
                    title(task.title),
                    style: theme.textTheme.titleLarge,
                  ),
                  isQueue
                      ? TaskProgressMonitor([task],
                          builder: (context, progress) => Text(
                              style: monospaceStyleBigger,
                              "(${task.latestProgress?.completed}/${task.latestProgress?.total})"))
                      : Container(),
                  Padding(
                    // to align it with the title (silly)
                    padding: const EdgeInsets.only(bottom: 1),
                    child: Text(
                      isQueue && !isDone
                          ? task
                              .tasks[min(task.latestProgress?.completed ?? 0,
                                  task.tasks.length - 1)]
                              .description
                          : task.description,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.disabledColor),
                    ),
                  ),
                  isDone
                      ? Expanded(
                          child: Text(
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: theme.disabledColor),
                            task.endTime != null
                                ? "Completed : ${prettyTimePrint(task.endTime!.toLocal())}"
                                : "",
                            textAlign: TextAlign.right,
                          ),
                        )
                      : Container()
                ],
              ),
              isDone
                  ? Container()
                  : isQueue
                      ? Container()
                      : SizedBox(
                          width: double.infinity,
                          child: Center(
                              child: TaskProgressMonitor(
                            [task],
                            builder: (context, progress) => Row(
                              children: [
                                Expanded(
                                  child: LinearProgressIndicator(
                                    borderRadius:
                                        BorderRadiusGeometry.circular(100),
                                    value: progress,
                                  ),
                                ),
                                SizedBox(
                                    width: 40,
                                    child: Text(
                                      "${((progress ?? 0) * 100).toInt()}%",
                                      textAlign: TextAlign.end,
                                      style: monospaceStyle,
                                    )),
                              ],
                            ),
                          ))),
              isQueue
                  ? ListView.builder(
                      itemExtent: letterSize(theme.textTheme.bodyLarge) ?? 14,
                      shrinkWrap: true,
                      itemCount: task.tasks.length,
                      itemBuilder: (context, index) {
                        final currentTask = task.tasks[index];
                        return Row(
                          spacing: 10,
                          children: [
                            Text(
                              title(currentTask.title),
                              style: theme.textTheme.bodyLarge,
                            ),
                            currentTask.isDone
                                ? Text(
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(color: theme.disabledColor),
                                    task.endTime != null
                                        ? "Completed : ${prettyTimePrint(currentTask.endTime!.toLocal())}"
                                        : "",
                                  )
                                : Expanded(
                                    child: TaskProgressMonitor(
                                    [currentTask],
                                    builder: (context, progress) => Row(
                                      children: [
                                        Expanded(
                                          child: LinearProgressIndicator(
                                            borderRadius:
                                                BorderRadiusGeometry.circular(
                                                    100),
                                            value: progress,
                                          ),
                                        ),
                                        SizedBox(
                                            width: 40,
                                            child: Text(
                                              "${((progress ?? 0) * 100).toInt()}%",
                                              textAlign: TextAlign.end,
                                              style: monospaceStyle,
                                            )),
                                      ],
                                    ),
                                  )),
                          ],
                        );
                      })
                  : Container()
            ],
          ),
        ),
      ],
    );
  }
}
