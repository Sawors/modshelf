import 'package:flutter/material.dart';
import 'package:modshelf/main.dart';
import 'package:modshelf/theme/theme_constants.dart';
import 'package:modshelf/tools/task_supervisor.dart';
import 'package:modshelf/ui/main_page/pages/basic_page.dart';
import 'package:modshelf/ui/main_page/pages/download_page/task_widget.dart';
import 'package:modshelf/ui/ui_utils.dart';

import '../../../../../../tools/tasks.dart';

class DownloadManagerPage extends StatefulWidget {
  static const String downloadManagerPageIdentifier = "page:download-manager";
  static const String downloadManagerTasksKey = "tasks";

  const DownloadManagerPage({super.key});

  @override
  _DownloadManagerPageState createState() => _DownloadManagerPageState();
}

class _DownloadManagerPageState extends State<DownloadManagerPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final emptyTextStyle = theme.textTheme.titleMedium
        ?.copyWith(color: theme.textTheme.titleMedium?.color?.withAlpha(85));

    return BasicPage(
      title: "Task Manager",
      child: SingleChildScrollView(
        child: ListenableBuilder(
            listenable: PageState.getInstance(
                DownloadManagerPage.downloadManagerPageIdentifier),
            builder: (context, child) {
              List<Task> taskList = TaskSupervisor.supervisor.tasks;
              List<Task> todo = [];
              List<Task> done = [];
              for (var t in taskList) {
                if (t.isDone) {
                  done.add(t);
                } else {
                  todo.add(t);
                }
              }
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child:
                        Text("Active tasks", style: theme.textTheme.titleLarge),
                  ),
                  ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxHeight: 560, minHeight: 0),
                    child: Padding(
                      padding: const EdgeInsets.all(cardMargin / 2),
                      child: todo.isNotEmpty
                          ? DecoratedBox(
                              decoration: BoxDecoration(
                                  border: BoxBorder.all(
                                      color: theme
                                          .colorScheme.surfaceContainerHigh,
                                      width: 2),
                                  borderRadius: BorderRadius.circular(
                                      rectangleRoundingRadius)),
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: todo.length,
                                itemBuilder: (context, index) {
                                  final t = todo[index];
                                  return SizedBox(
                                    height: 100 +
                                        (t is TaskQueue
                                            ? t.tasks.length *
                                                (letterSize(theme.textTheme
                                                        .bodyMedium) ??
                                                    14)
                                            : 0),
                                    child: Padding(
                                      padding: const EdgeInsets.all(2.0),
                                      child: MaterialButton(
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                                rectangleRoundingRadius - 2)),
                                        padding: EdgeInsets.zero,
                                        splashColor: Colors.transparent,
                                        animationDuration:
                                            const Duration(milliseconds: 300),
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        onPressed: () {
                                          if (!t.isStarted) {
                                            TaskSupervisor.supervisor.start(t,
                                                removeWhenDone: false);
                                          }
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 10.0, horizontal: 30),
                                          child: TaskWidget(t),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                separatorBuilder:
                                    (BuildContext context, int index) =>
                                        Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 30),
                                  child: Container(
                                    height: 2,
                                    color: theme.colorScheme.surfaceContainer,
                                  ),
                                ),
                              ),
                            )
                          : Text(
                              "There are no active tasks.",
                              style: emptyTextStyle,
                            ),
                    ),
                  ),
                  const SizedBox(
                    height: 50,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text("Finished tasks",
                        style: theme.textTheme.titleLarge),
                  ),
                  ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxHeight: 560, minHeight: 0),
                    child: Padding(
                      padding: const EdgeInsets.all(cardMargin / 2),
                      child: done.isNotEmpty
                          ? DecoratedBox(
                              decoration: BoxDecoration(
                                  border: BoxBorder.all(
                                      color: theme
                                          .colorScheme.surfaceContainerHigh,
                                      width: 2),
                                  borderRadius: BorderRadius.circular(
                                      rectangleRoundingRadius)),
                              child: ListView.separated(
                                itemCount: done.length,
                                separatorBuilder: (context, index) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 30),
                                  child: Container(
                                    height: 2,
                                    color: theme.colorScheme.surfaceContainer,
                                  ),
                                ),
                                shrinkWrap: true,
                                itemBuilder: (context, index) {
                                  final t = done[index];
                                  return SizedBox(
                                    height: 100 +
                                        (t is TaskQueue
                                            ? t.tasks.length *
                                                (theme.textTheme.bodyMedium
                                                        ?.fontSize ??
                                                    14)
                                            : 0),
                                    child: Padding(
                                      padding: const EdgeInsets.all(2.0),
                                      child: MaterialButton(
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                                rectangleRoundingRadius - 2)),
                                        padding: EdgeInsets.zero,
                                        splashColor: Colors.transparent,
                                        animationDuration:
                                            const Duration(milliseconds: 300),
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        onPressed: () {
                                          TaskSupervisor.supervisor
                                              .remove(t.id);
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 10.0, horizontal: 30),
                                          child: TaskWidget(t),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            )
                          : Text(
                              "There are no finished tasks.",
                              style: emptyTextStyle,
                            ),
                    ),
                  ),
                ],
              );
            }),
      ),
    );
  }
}
