import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:take_five/src/database/database.dart';
import 'package:take_five/src/database/database_exceptions.dart';
import 'package:take_five/src/models/task.dart';

void main() {
  // These tests intentionally open many short-lived databases (the property
  // test) and reopen a file-backed one (the persistence test). Each uses its
  // own executor and is closed before the next, so the multiple-instance race
  // warning does not apply here.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<List<int>> positions() async {
    final items = await db.watchTasks().first;
    return items.map((i) => i.position).toList();
  }

  group('addTask (Phase 2)', () {
    test('first item gets position 1', () async {
      await db.addTask(title: 'first');
      final items = await db.watchTasks().first;
      expect(items.single.position, 1);
    });

    test('positions increment as max + 1', () async {
      await db.addTask(title: 'a');
      await db.addTask(title: 'b');
      await db.addTask(title: 'c');
      expect(await positions(), [1, 2, 3]);
    });

    test('the 50th item succeeds and the 51st throws', () async {
      for (var i = 0; i < AppDatabase.maxTasks; i++) {
        await db.addTask(title: 'item $i');
      }
      expect(await db.taskCount(), AppDatabase.maxTasks);
      expect(
        () => db.addTask(title: 'one too many'),
        throwsA(isA<TaskLimitExceededException>()),
      );
      expect(await db.taskCount(), AppDatabase.maxTasks);
    });

    test('empty or whitespace title throws and persists nothing', () async {
      expect(
        () => db.addTask(title: '   '),
        throwsA(isA<InvalidTaskException>()),
      );
      expect(await db.taskCount(), 0);
    });

    test('over-length title throws and persists nothing', () async {
      final tooLong = 'x' * (AppDatabase.maxTitleLength + 1);
      expect(
        () => db.addTask(title: tooLong),
        throwsA(isA<InvalidTaskException>()),
      );
      expect(await db.taskCount(), 0);
    });

    test('title at the max length is accepted and trimmed', () async {
      final maxTitle = 'y' * AppDatabase.maxTitleLength;
      await db.addTask(title: '  $maxTitle  ');
      final item = (await db.watchTasks().first).single;
      expect(item.title, maxTitle);
    });

    test('omitted description stores null; provided round-trips', () async {
      await db.addTask(title: 'no detail');
      await db.addTask(title: 'with detail', description: 'hello');
      final items = await db.watchTasks().first;
      expect(items[0].description, isNull);
      expect(items[1].description, 'hello');
    });

    test('whitespace-only description is normalized to null', () async {
      await db.addTask(title: 'blank detail', description: '   ');
      final item = (await db.watchTasks().first).single;
      expect(item.description, isNull);
    });

    test('description with surrounding whitespace is trimmed but kept',
        () async {
      await db.addTask(title: 'a', description: '  real content  ');
      final item = (await db.watchTasks().first).single;
      expect(item.description, 'real content');
    });

    test('over-length description throws and persists nothing', () async {
      final tooLong = 'd' * (AppDatabase.maxDescriptionLength + 1);
      expect(
        () => db.addTask(title: 'a', description: tooLong),
        throwsA(isA<InvalidTaskException>()),
      );
      expect(await db.taskCount(), 0);
    });
  });

  group('editTask (Phase 2)', () {
    test('updates title and description, leaving position unchanged', () async {
      await db.addTask(title: 'a');
      final id = await db.addTask(title: 'b', description: 'old');
      await db.addTask(title: 'c');

      await db.editTask(id: id, title: 'b-edited', description: 'new');

      final edited =
          (await db.watchTasks().first).firstWhere((i) => i.id == id);
      expect(edited.title, 'b-edited');
      expect(edited.description, 'new');
      expect(edited.position, 2);
    });

    test('can clear a description by passing null', () async {
      final id = await db.addTask(title: 'a', description: 'detail');
      await db.editTask(id: id, title: 'a');
      final item = (await db.watchTasks().first).single;
      expect(item.description, isNull);
    });

    test('whitespace-only description normalizes to null on edit', () async {
      final id = await db.addTask(title: 'a', description: 'detail');
      await db.editTask(id: id, title: 'a', description: '   ');
      final item = (await db.watchTasks().first).single;
      expect(item.description, isNull);
    });

    test('editing one item does not shift other items\' positions', () async {
      final id1 = await db.addTask(title: 'a');
      final id2 = await db.addTask(title: 'b');
      final id3 = await db.addTask(title: 'c');

      await db.editTask(id: id2, title: 'b-edited');

      final items = await db.watchTasks().first;
      expect(items.map((i) => i.position), [1, 2, 3]);
      expect(items.map((i) => i.id), [id1, id2, id3]);
    });

    test('invalid title throws and does not modify the row', () async {
      final id = await db.addTask(title: 'original');
      expect(
        () => db.editTask(id: id, title: ''),
        throwsA(isA<InvalidTaskException>()),
      );
      final item = (await db.watchTasks().first).single;
      expect(item.title, 'original');
    });

    test('editing a missing id throws TaskNotFoundException', () async {
      expect(
        () => db.editTask(id: 999, title: 'ghost'),
        throwsA(isA<TaskNotFoundException>()),
      );
    });
  });

  group('deleteTask (Phase 2)', () {
    test('removes the row and re-sequences to contiguous 1..N', () async {
      final ids = <int>[];
      for (var i = 0; i < 5; i++) {
        ids.add(await db.addTask(title: 'item $i'));
      }
      // Delete the middle item (position 3).
      await db.deleteTask(ids[2]);

      final items = await db.watchTasks().first;
      expect(items.map((i) => i.position), [1, 2, 3, 4]);
      // Relative order preserved: items 0,1,3,4 remain in order.
      expect(items.map((i) => i.title), ['item 0', 'item 1', 'item 3', 'item 4']);
    });

    test('deleting a missing id is a no-op', () async {
      await db.addTask(title: 'a');
      await db.deleteTask(999);
      expect(await db.taskCount(), 1);
      expect(await positions(), [1]);
    });

    test('deleting frees capacity so a new item can be added at 50', () async {
      for (var i = 0; i < AppDatabase.maxTasks; i++) {
        await db.addTask(title: 'item $i');
      }
      final items = await db.watchTasks().first;
      await db.deleteTask(items.first.id);
      // Now at 49 — adding should succeed and land at position 50.
      await db.addTask(title: 'replacement');
      expect(await db.taskCount(), AppDatabase.maxTasks);
      expect((await positions()).last, AppDatabase.maxTasks);
    });
  });

  group('positions stay contiguous under random deletes (property)', () {
    test('invariant holds across many random delete sequences', () async {
      final rng = Random(1234); // fixed seed → deterministic
      for (var trial = 0; trial < 25; trial++) {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final count = rng.nextInt(AppDatabase.maxTasks) + 1; // 1..50
        for (var i = 0; i < count; i++) {
          await db.addTask(title: 'i$i');
        }
        final deletions = rng.nextInt(count); // delete up to count-1
        for (var d = 0; d < deletions; d++) {
          final current = await db.watchTasks().first;
          final victim = current[rng.nextInt(current.length)];
          await db.deleteTask(victim.id);

          final after = await db.watchTasks().first;
          final expected =
              List<int>.generate(after.length, (idx) => idx + 1);
          expect(
            after.map((i) => i.position).toList(),
            expected,
            reason: 'positions must be contiguous 1..N after each delete',
          );
        }
        await db.close();
      }
    });
  });

  group('watchTasks reactivity (Phase 2)', () {
    test('re-emits after add, edit, and delete', () async {
      final emissions = <List<Task>>[];
      final sub = db.watchTasks().listen(emissions.add);
      addTearDown(sub.cancel);

      // Initial emission: empty.
      await pumpEventQueue();
      expect(emissions.last, isEmpty);

      final id = await db.addTask(title: 'a');
      await pumpEventQueue();
      expect(emissions.last.single.title, 'a');

      await db.editTask(id: id, title: 'a-edited');
      await pumpEventQueue();
      expect(emissions.last.single.title, 'a-edited');

      await db.deleteTask(id);
      await pumpEventQueue();
      expect(emissions.last, isEmpty);

      // Initial + add + edit + delete = at least 4 distinct emissions.
      expect(emissions.length, greaterThanOrEqualTo(4));
    });

    test('emits items sorted by position ascending', () async {
      await db.addTask(title: 'first');
      await db.addTask(title: 'second');
      await db.addTask(title: 'third');
      final items = await db.watchTasks().first;
      expect(items.map((i) => i.position), [1, 2, 3]);
      expect(items.map((i) => i.title), ['first', 'second', 'third']);
    });
  });

  group('persistence across reopen (Phase 2)', () {
    test('data survives closing and reopening a file-backed database',
        () async {
      final dir = await Directory.systemTemp.createTemp('take_five_test');
      final file = File('${dir.path}/take_five.sqlite');
      try {
        final first = AppDatabase.forTesting(NativeDatabase(file));
        await first.addTask(title: 'persisted', description: 'kept');
        await first.close();

        final second = AppDatabase.forTesting(NativeDatabase(file));
        final items = await second.watchTasks().first;
        expect(items.single.title, 'persisted');
        expect(items.single.description, 'kept');
        await second.close();
      } finally {
        await dir.delete(recursive: true);
      }
    });
  });
}
