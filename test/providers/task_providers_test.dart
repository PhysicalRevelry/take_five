import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:take_five/src/database/database.dart';
import 'package:take_five/src/database/database_exceptions.dart';
import 'package:take_five/src/models/task.dart';
import 'package:take_five/src/providers/task_providers.dart';

void main() {
  // Each test opens its own isolated in-memory database; the multiple-instance
  // race warning does not apply here.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  /// Builds a container whose [appDatabaseProvider] is backed by a fresh
  /// in-memory database, returning both for assertions and cleanup.
  (ProviderContainer, AppDatabase) makeContainer() {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    return (container, db);
  }

  group('appDatabaseProvider (Phase 3)', () {
    test('returns the same shared instance across reads', () {
      final (container, db) = makeContainer();
      addTearDown(container.dispose);

      expect(container.read(appDatabaseProvider), same(db));
      expect(container.read(appDatabaseProvider), same(db));
    });

    test('disposes the database when the scope is disposed', () async {
      // Mirrors the production wiring (ref.onDispose(db.close)) and spies on the
      // disposal callback to prove it fires when the container is torn down.
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      var disposed = false;
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWith((ref) {
            ref.onDispose(() {
              disposed = true;
              db.close();
            });
            return db;
          }),
        ],
      );
      container.read(appDatabaseProvider);
      expect(disposed, isFalse);

      container.dispose();
      expect(disposed, isTrue);
    });
  });

  group('taskListProvider (Phase 3)', () {
    test('emits current rows and re-emits after a mutation', () async {
      final (container, db) = makeContainer();
      addTearDown(container.dispose);

      final emissions = <List<Task>>[];
      final sub = container.listen(
        taskListProvider,
        (_, next) {
          final value = next.value;
          if (value != null) emissions.add(value);
        },
        fireImmediately: true,
      );
      addTearDown(sub.close);

      // Initial emission: empty.
      await pumpEventQueue();
      expect(emissions.last, isEmpty);

      await db.addTask(title: 'first');
      await pumpEventQueue();
      expect(emissions.last.single.title, 'first');
    });

    test('maps every field through to the domain model', () async {
      final (container, db) = makeContainer();
      addTearDown(container.dispose);

      final emissions = <List<Task>>[];
      final sub = container.listen(
        taskListProvider,
        (_, next) {
          final value = next.value;
          if (value != null) emissions.add(value);
        },
        fireImmediately: true,
      );
      addTearDown(sub.close);

      final id = await db.addTask(title: 'a title', description: 'a detail');
      await pumpEventQueue();

      final item = emissions.last.single;
      expect(item.id, id);
      expect(item.position, 1);
      expect(item.title, 'a title');
      expect(item.description, 'a detail');
    });
  });

  group('taskRepositoryProvider (Phase 3)', () {
    test('returns the same shared instance across reads', () {
      final (container, _) = makeContainer();
      addTearDown(container.dispose);
      expect(
        container.read(taskRepositoryProvider),
        same(container.read(taskRepositoryProvider)),
      );
    });

    test('routes add/edit/delete to the database', () async {
      final (container, db) = makeContainer();
      addTearDown(container.dispose);
      final repo = container.read(taskRepositoryProvider);

      final id = await repo.add(title: 'a', description: 'detail');
      expect((await db.watchTasks().first).single.title, 'a');

      await repo.edit(id: id, title: 'a-edited');
      expect((await db.watchTasks().first).single.title, 'a-edited');

      await repo.delete(id);
      expect(await db.taskCount(), 0);
    });

    test('surfaces the item-limit exception unchanged', () async {
      final (container, db) = makeContainer();
      addTearDown(container.dispose);
      final repo = container.read(taskRepositoryProvider);

      for (var i = 0; i < AppDatabase.maxTasks; i++) {
        await repo.add(title: 'item $i');
      }
      expect(
        () => repo.add(title: 'too many'),
        throwsA(isA<TaskLimitExceededException>()),
      );
    });

    test('surfaces validation errors from add unchanged', () async {
      final (container, _) = makeContainer();
      addTearDown(container.dispose);
      final repo = container.read(taskRepositoryProvider);

      expect(
        () => repo.add(title: '   '),
        throwsA(isA<InvalidTaskException>()),
      );
    });

    test('surfaces TaskNotFoundException from edit unchanged', () async {
      final (container, _) = makeContainer();
      addTearDown(container.dispose);
      final repo = container.read(taskRepositoryProvider);

      expect(
        () => repo.edit(id: 999, title: 'ghost'),
        throwsA(isA<TaskNotFoundException>()),
      );
    });

    test('surfaces validation errors from edit unchanged', () async {
      final (container, _) = makeContainer();
      addTearDown(container.dispose);
      final repo = container.read(taskRepositoryProvider);
      final id = await repo.add(title: 'original');

      expect(
        () => repo.edit(id: id, title: ''),
        throwsA(isA<InvalidTaskException>()),
      );
    });
  });
}
