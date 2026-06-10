import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../models/task.dart';
import 'database_exceptions.dart';

part 'database.g.dart';

/// A single user-entered task: an ordering number, a short title, and an
/// optional description.
@DataClassName('TaskRow')
@TableIndex(name: 'idx_tasks_position', columns: {#position})
class Tasks extends Table {
  /// Stable identity used for edit/delete; independent of display ordering.
  IntColumn get id => integer().autoIncrement()();

  /// 1-based display order. Assigned on insert; kept contiguous on delete.
  IntColumn get position => integer()();

  /// Short, required label (1–100 characters).
  TextColumn get title => text().withLength(min: 1, max: 100)();

  /// Optional free-form detail.
  TextColumn get description => text().nullable()();
}

/// The app's local SQLite database. Self-contained on the device — no network.
@DriftDatabase(tables: [Tasks])
class AppDatabase extends _$AppDatabase {
  /// Opens the on-device database file (created on first launch).
  AppDatabase() : super(driftDatabase(name: 'take_five'));

  /// Opens against a caller-supplied executor — used by tests with an
  /// in-memory or temp-file database for isolation.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          // v2: the `items` table and its position index were renamed to
          // `tasks`. SQLite can rename the table in place; the index has no
          // RENAME, so drop the old one and recreate it under the new name.
          if (from < 2) {
            await customStatement('ALTER TABLE items RENAME TO tasks');
            await customStatement('DROP INDEX IF EXISTS idx_items_position');
            await m.createIndex(idxTasksPosition);
          }
        },
      );

  /// The maximum number of tasks the list may hold.
  static const int maxTasks = 50;

  /// The inclusive maximum length of a task title (in Unicode code points),
  /// mirroring the schema's `withLength(max: 100)` CHECK constraint.
  static const int maxTitleLength = 100;

  /// The inclusive maximum length of a task description (in code points).
  /// Descriptions are free-form, but bounded to reject pathological input.
  static const int maxDescriptionLength = 1000;

  /// Emits the full list ordered by [Tasks.position] (ascending) and re-emits
  /// whenever the underlying data changes. Drift rows are mapped to [Task]
  /// so the generated row type stays internal to this layer.
  Stream<List<Task>> watchTasks() {
    return (select(tasks)..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .watch()
        .map((rows) => rows.map(_toModel).toList());
  }

  /// The current number of stored tasks.
  Future<int> taskCount() async {
    final count = tasks.id.count();
    final query = selectOnly(tasks)..addColumns([count]);
    return query.map((row) => row.read(count)!).getSingle();
  }

  /// Appends a new task at the next position and returns its generated id.
  ///
  /// Throws [InvalidTaskException] for an empty or over-length title, and
  /// [TaskLimitExceededException] when the list already holds [maxTasks].
  /// The count check and insert run in one transaction so concurrent adds
  /// cannot both slip past the cap.
  Future<int> addTask({required String title, String? description}) {
    final cleanTitle = _validateTitle(title);
    final cleanDescription = _normalizeDescription(description);

    return transaction(() async {
      // Count and insert share one transaction. Drift serializes all access
      // through a single connection and this app is the only writer, so the
      // cap cannot be raced past between the check and the insert.
      if (await taskCount() >= maxTasks) {
        throw const TaskLimitExceededException(maxTasks);
      }
      final maxColumn = tasks.position.max();
      final currentMax = await (selectOnly(tasks)..addColumns([maxColumn]))
          .map((row) => row.read(maxColumn))
          .getSingleOrNull();

      return into(tasks).insert(
        TasksCompanion.insert(
          position: (currentMax ?? 0) + 1,
          title: cleanTitle,
          description: Value(cleanDescription),
        ),
      );
    });
  }

  /// Updates the title and description of the task with [id], leaving its
  /// position unchanged.
  ///
  /// Throws [InvalidTaskException] for an invalid title and
  /// [TaskNotFoundException] if no task has the given [id].
  Future<void> editTask({
    required int id,
    required String title,
    String? description,
  }) async {
    final cleanTitle = _validateTitle(title);
    final cleanDescription = _normalizeDescription(description);

    final updated = await (update(tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        title: Value(cleanTitle),
        description: Value(cleanDescription),
      ),
    );
    if (updated == 0) {
      throw TaskNotFoundException(id);
    }
  }

  /// Deletes the task with [id] (a no-op if it does not exist) and re-sequences
  /// the remaining tasks so their positions stay contiguous (1..N) in their
  /// original relative order. Runs in a transaction so the list is never left
  /// with gaps.
  Future<void> deleteTask(int id) {
    return transaction(() async {
      await (delete(tasks)..where((t) => t.id.equals(id))).go();
      await _resequence();
    });
  }

  /// Rewrites positions to a contiguous 1..N sequence, preserving the current
  /// ascending order. Only rows whose position actually changes are written.
  ///
  /// Updates row-by-row, which is fine for the capped list size ([maxTasks]);
  /// it would warrant a single batched statement only at a much larger scale.
  Future<void> _resequence() async {
    final remaining = await (select(tasks)
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .get();
    for (var i = 0; i < remaining.length; i++) {
      final desired = i + 1;
      if (remaining[i].position != desired) {
        await (update(tasks)..where((t) => t.id.equals(remaining[i].id)))
            .write(TasksCompanion(position: Value(desired)));
      }
    }
  }

  /// Maps a Drift row to the app-facing [Task] domain model.
  Task _toModel(TaskRow row) => Task(
        id: row.id,
        position: row.position,
        title: row.title,
        description: row.description,
      );

  /// Trims and validates a title, returning the cleaned value. Length is
  /// measured in code points (`runes`) to match the schema's SQLite
  /// `LENGTH()` CHECK exactly, so Dart and the database never disagree.
  String _validateTitle(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw const InvalidTaskException('Title must not be empty.');
    }
    if (trimmed.runes.length > maxTitleLength) {
      throw const InvalidTaskException(
        'Title must be $maxTitleLength characters or fewer.',
      );
    }
    return trimmed;
  }

  /// Trims a description, collapsing empty/whitespace-only input to null and
  /// rejecting input longer than [maxDescriptionLength] code points.
  String? _normalizeDescription(String? description) {
    final trimmed = description?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    if (trimmed.runes.length > maxDescriptionLength) {
      throw const InvalidTaskException(
        'Description must be $maxDescriptionLength characters or fewer.',
      );
    }
    return trimmed;
  }
}
