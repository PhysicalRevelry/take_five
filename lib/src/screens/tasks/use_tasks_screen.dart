import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../database/database.dart';
import '../../models/task.dart';
import '../../providers/task_providers.dart';

/// Mutation callbacks and derived state the tasks screen renders from. Holds the
/// screen's business logic so the widget itself stays presentation-only.
class TasksScreenModel {
  const TasksScreenModel({
    required this.tasks,
    required this.canAdd,
    required this.atCapacity,
    required this.belowMinimum,
    required this.maxTasks,
    required this.minTasks,
    required this.maxTitleLength,
    required this.maxDescriptionLength,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  /// The reactive list of tasks (loading / data / error).
  final AsyncValue<List<Task>> tasks;

  /// Whether another task may be added. False while data is still loading and
  /// once [maxTasks] is reached.
  final bool canAdd;

  /// Whether the list is full (loaded and holding [maxTasks]). Drives the cap
  /// banner — distinct from [canAdd] so the banner does not flash during load.
  final bool atCapacity;

  /// Whether the list has at least one task but fewer than [minTasks] — drives
  /// the "add at least five" nudge. False while empty or once the minimum is met.
  final bool belowMinimum;

  /// The maximum number of tasks allowed.
  final int maxTasks;

  /// The recommended minimum number of tasks.
  final int minTasks;

  /// The maximum title length, for client-side form validation.
  final int maxTitleLength;

  /// The maximum description length, for client-side form validation.
  final int maxDescriptionLength;

  /// Adds a task. May throw the same errors as the database layer.
  final Future<void> Function({required String title, String? description}) onAdd;

  /// Edits an existing task by id.
  final Future<void> Function({required int id, required String title, String? description}) onEdit;

  /// Deletes a task by id.
  final Future<void> Function(int id) onDelete;
}

/// Custom hook wiring the task providers into a [TasksScreenModel].
TasksScreenModel useTasksScreen(WidgetRef ref) {
  final tasks = ref.watch(taskListProvider);
  final repo = ref.watch(taskRepositoryProvider);
  final hasData = tasks.hasValue;
  final count = tasks.value?.length ?? 0;

  return TasksScreenModel(
    tasks: tasks,
    canAdd: hasData && count < AppDatabase.maxTasks,
    atCapacity: hasData && count >= AppDatabase.maxTasks,
    belowMinimum: hasData && count > 0 && count < AppDatabase.minTasks,
    maxTasks: AppDatabase.maxTasks,
    minTasks: AppDatabase.minTasks,
    maxTitleLength: AppDatabase.maxTitleLength,
    maxDescriptionLength: AppDatabase.maxDescriptionLength,
    onAdd: repo.add,
    onEdit: repo.edit,
    onDelete: repo.delete,
  );
}
