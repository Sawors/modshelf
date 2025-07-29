import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../../../../../../theme/theme_constants.dart';
import '../../../../../../tools/tasks.dart';

class TaskProgressMonitor extends StatefulWidget {
  final Iterable<Task> monitored;
  final int frequencyMs = 1000 ~/ 30;
  final Widget Function(BuildContext context, double? progress) builder;

  const TaskProgressMonitor(this.monitored, {required this.builder, super.key});

  @override
  _TaskProgressMonitorState createState() => _TaskProgressMonitorState();
}

class _TaskProgressMonitorState extends State<TaskProgressMonitor> {
  double? progress;

  late final Future<void> periodTick;
  late final StreamSubscription sub;
  late final Stream stream;

  @override
  void initState() {
    super.initState();
    stream = Stream.periodic(
        const Duration(milliseconds: animationPeriodMs), (index) {});
    sub = stream.listen((d) {
      if (!mounted || widget.monitored.every((t) => t.isDone)) {
        sub.cancel();
      }
      final iter =
          widget.monitored.where((v) => v.latestProgress != null).map((t) {
        return t.latestProgress?.progress ?? 0;
      });
      final nextValue = iter.isNotEmpty ? iter.average : 0.0;
      if (progress == nextValue) {
        return;
      }
      progress = nextValue;
      if (progress != null && progress! >= 0 && progress! <= 1) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    sub.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, progress);
  }
}
