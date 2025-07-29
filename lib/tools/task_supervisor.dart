import 'package:collection/collection.dart';
import 'package:modshelf/tools/tasks.dart';

TaskSupervisor? _supervisor;

class TaskSupervisor {
  static TaskSupervisor get supervisor {
    _supervisor ??= TaskSupervisor(tasks: []);
    return _supervisor!;
  }

  Function(Task)? onTaskAdded;
  Function(Task?)? onTaskRemoved;
  Function(Task)? onTaskStarted;
  Function(Task)? onTaskDone;
  final List<Task> tasks;

  TaskSupervisor(
      {required this.tasks,
      this.onTaskAdded,
      this.onTaskRemoved,
      this.onTaskStarted,
      this.onTaskDone});

  static void init(TaskSupervisor supervisor) {
    if (_supervisor != null) {
      throw StateError("supervisor has already been initialized");
    }
    _supervisor = supervisor;
  }

  bool get hasActiveTask => tasks.isNotEmpty;

  void add(Task task) {
    if (supervisor.tasks.none((t) => t.id == task.id)) {
      supervisor.tasks.add(task);
    }
    if (onTaskAdded != null) {
      onTaskAdded!(task);
    }
  }

  Stream<TaskReport> start(Task task,
      {bool removeWhenDone = false,
      Function(TaskReport)? onData,
      Function()? onDone}) {
    add(task);
    final str = task.start(onDone: onDone, onData: onData);
    if (onTaskStarted != null) {
      onTaskStarted!(task);
    }
    str.last.then((_) {
      if (onTaskDone != null) {
        onTaskDone!(task);
      }
      if (removeWhenDone) {
        remove(task.id);
      }
    });
    return str;
  }

  void remove(String taskId) {
    Task? removed;
    supervisor.tasks.removeWhere((t) {
      final check = t.id == taskId;
      if (check) {
        removed = t;
      }
      return check;
    });
    if (onTaskRemoved != null) {
      onTaskRemoved!(removed);
    }
  }
}
