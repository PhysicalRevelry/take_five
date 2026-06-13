import '../database/database.dart';

/// Thin write-side facade over [AppDatabase] for task mutations. Validation,
/// the task cap, and re-sequencing all live in the database layer; this exists
/// to give the UI a small, intention-revealing API and a single seam to mock.
class TaskRepository {
  const TaskRepository(this._db);

  final AppDatabase _db;

  /// Appends a new task; see [AppDatabase.addTask] for thrown errors.
  Future<int> add({required String title, String? description}) =>
      _db.addTask(title: title, description: description);

  /// Updates an existing task; see [AppDatabase.editTask] for thrown errors.
  Future<void> edit({
    required int id,
    required String title,
    String? description,
  }) =>
      _db.editTask(id: id, title: title, description: description);

  /// Deletes a task and re-sequences the remainder.
  Future<void> delete(int id) => _db.deleteTask(id);

  /// Records a wheel landing on the task at [position], rotating the wheel.
  Future<void> landOn(int position) => _db.landOnTask(position);
}
