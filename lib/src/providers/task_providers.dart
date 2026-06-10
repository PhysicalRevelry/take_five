import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/database.dart';
import '../models/task.dart';
import '../repositories/task_repository.dart';

part 'task_providers.g.dart';

/// The single, app-lifetime [AppDatabase] instance. Kept alive so the SQLite
/// connection is opened once and shared, and closed when the scope is disposed.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}

/// Reactive view of the stored tasks, ordered by position. Re-emits on every
/// mutation, so any consuming widget rebuilds automatically.
@riverpod
Stream<List<Task>> taskList(Ref ref) {
  return ref.watch(appDatabaseProvider).watchTasks();
}

/// Write-side entry point for adding, editing, and deleting tasks. Kept alive
/// like [appDatabaseProvider] — it is a stateless facade over the shared
/// database, so there is nothing to dispose and no value in recreating it.
@Riverpod(keepAlive: true)
TaskRepository taskRepository(Ref ref) {
  return TaskRepository(ref.watch(appDatabaseProvider));
}
