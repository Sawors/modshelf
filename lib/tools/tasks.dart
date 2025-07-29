import 'dart:async';

import 'package:modshelf/tools/utils.dart';

import 'core/manifest.dart';

class TaskReport<T> {
  int completed;
  final int total;
  T? data;

  TaskReport({required this.completed, required this.total, this.data});

  bool get isComplete => total > 0 && completed >= total;

  double get progress => total != 0 ? completed / total : 0;
}

abstract class Task<T> {
  final String description;
  final String title;
  Manifest? manifest;
  late final String id;
  DateTime? startTime;
  DateTime? endTime;
  StreamSubscription<TaskReport>? subscription;
  Stream<TaskReport>? stream;
  TaskReport? latestProgress;
  dynamic chainedData;

  Task(
      {required this.description,
      required this.title,
      this.manifest,
      this.latestProgress,
      this.chainedData}) {
    id = generateRandomString(8);
  }

  Stream<TaskReport> execute({dynamic pipedData});

  bool get isStarted => stream != null;

  Stream<TaskReport> start(
      {Function(TaskReport<dynamic>)? onData,
      Function()? onDone,
      dynamic pipedData}) {
    if (subscription != null) {
      throw StateError("this task has already been started!");
    }
    stream = execute(pipedData: pipedData).asBroadcastStream(onCancel: (v) {
      if (isDone) {
        v.cancel();
      }
    });
    subscription = stream!.listen((d) {
      if (onData != null) {
        onData(d);
      }
      latestProgress = d;
      if (isDone) {
        close();
        if (onDone != null) {
          onDone();
        }
      }
    });
    startTime = DateTime.now();
    return stream!;
  }

  bool get isDone => latestProgress?.isComplete ?? false;

  void close() {
    endTime = DateTime.now();
    subscription?.cancel();
  }
}

class StreamTask<T> extends Task<T> {
  final Stream<TaskReport> taskStream;

  StreamTask(this.taskStream,
      {required super.description,
      required super.title,
      super.manifest,
      super.latestProgress,
      super.chainedData});

  @override
  Stream<TaskReport> execute({dynamic pipedData}) {
    return taskStream;
  }
}

class TaskQueue extends Task {
  late List<Task> tasks;
  int current = 0;

  TaskQueue(
      {required super.description,
      required super.title,
      super.manifest,
      super.latestProgress,
      List<Task>? tasks,
      super.chainedData}) {
    this.tasks = tasks ?? [];
    latestProgress ??= TaskReport(completed: 0, total: tasks?.length ?? 0);
  }

  @override
  Stream<TaskReport<TaskReport>> execute({dynamic pipedData}) async* {
    final initialSize = tasks.length;
    dynamic latestData;
    for (var stream in tasks.indexed) {
      current = stream.$1;
      final str = stream.$2.start(pipedData: latestData);
      await for (var report in str) {
        yield TaskReport(
            completed: stream.$1, total: initialSize, data: report);
        if (report.isComplete) {
          latestData = report.data;
          break;
        }
      }
    }
    yield TaskReport(completed: initialSize, total: initialSize);
  }
}
