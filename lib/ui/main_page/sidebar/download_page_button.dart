import 'package:flutter/material.dart';
import 'package:modshelf/tools/tasks.dart';
import 'package:modshelf/ui/main_page/pages/download_page/task_progress_monitor.dart';
import 'package:modshelf/ui/main_page/sidebar/page_navigation_button.dart';
import 'package:modshelf/ui/main_page/sidebar/sidebar.dart';

import '../../../tools/task_supervisor.dart';

class DownloadPageButton extends StatelessWidget {
  const DownloadPageButton({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Widget> columnElements = [const Icon(Icons.download_rounded)];
    if (TaskSupervisor.supervisor.hasActiveTask &&
        TaskSupervisor.supervisor.tasks.any((t) => t.isStarted && !t.isDone)) {
      columnElements.add(const SizedBox(
        height: 4,
      ));
      final List<Task> flatMap = [];
      for (var task in TaskSupervisor.supervisor.tasks) {
        if (task is TaskQueue) {
          flatMap.addAll(task.tasks);
        } else {
          flatMap.add(task);
        }
      }
      columnElements.add(TaskProgressMonitor(
        flatMap.where((t) => !t.isDone),
        builder: (context, progress) => LinearProgressIndicator(
          borderRadius: BorderRadiusGeometry.circular(100),
          value: progress,
        ),
      ));
    }

    return Tooltip(
        waitDuration: const Duration(seconds: 1),
        message: "Tasks",
        child: PageNavigationButton(
            trackedPage: Sidebar.downloadPageKey,
            minHeight: 60,
            child: Column(
              children: columnElements,
            )));
  }
}
