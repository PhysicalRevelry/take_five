import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:take_five/src/database/database.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> addTasks(int n) async {
    for (var i = 1; i <= n; i++) {
      await db.addTask(title: 'Task $i');
    }
  }

  Future<Set<int>> onWheelPositions() async {
    final rows = await db.watchWheelTasks().first;
    return rows.map((t) => t.position).toSet();
  }

  test('test_on_wheel_positions_map_to_ascending_labels', () async {
    // The wheel's section labels are the on-wheel task positions as ascending
    // strings, capped at 15 — this is the list→wheel mapping the UI renders.
    for (final n in [5, 15, 20]) {
      final local = AppDatabase.forTesting(NativeDatabase.memory());
      for (var i = 1; i <= n; i++) {
        await local.addTask(title: 'Task $i');
      }
      final labels = (await local.watchWheelTasks().first)
          .map((t) => '${t.position}')
          .toList();
      final expected = [for (var p = 1; p <= (n < 15 ? n : 15); p++) '$p'];
      expect(labels, expected, reason: 'n=$n');
      await local.close();
    }
  });

  test('test_add_sets_lowest_15_on_wheel', () async {
    await addTasks(20);
    expect(await onWheelPositions(), {for (var p = 1; p <= 15; p++) p});
  });

  test('test_fewer_than_15_all_on_wheel', () async {
    await addTasks(6);
    expect(await onWheelPositions(), {1, 2, 3, 4, 5, 6});
  });

  test('test_watchWheelTasks_caps_at_15_ordered', () async {
    await addTasks(30);
    final rows = await db.watchWheelTasks().first;
    expect(rows, hasLength(15));
    expect(
      rows.map((t) => t.position).toList(),
      [for (var p = 1; p <= 15; p++) p],
    );
  });

  test('test_landOn_is_noop_at_or_below_15', () async {
    await addTasks(15);
    await db.landOnTask(8);
    expect(await onWheelPositions(), {for (var p = 1; p <= 15; p++) p});
  });

  test('test_landOn_replaces_with_next_above', () async {
    await addTasks(20);
    await db.landOnTask(8);
    expect(await onWheelPositions(), {
      ...{for (var p = 1; p <= 15; p++) p}..remove(8),
      16,
    });
  });

  test('test_landOn_sequence_wraps_back_to_freed_low', () async {
    // The worked example: 20 tasks, land 8 -> 16, 16 -> 17, ... 20 -> back to 8.
    await addTasks(20);
    await db.landOnTask(8); // brings 16
    await db.landOnTask(16); // 17
    await db.landOnTask(17); // 18
    await db.landOnTask(18); // 19
    await db.landOnTask(19); // 20
    expect(await onWheelPositions(), {
      ...[1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15],
      20,
    });
    await db.landOnTask(20); // wraps: first off-wheel scanning up from 21->1 is 8
    expect(await onWheelPositions(), {for (var p = 1; p <= 15; p++) p});
  });

  test('test_edit_preserves_wheel_rotation', () async {
    // A title/description edit changes neither positions nor membership, so the
    // in-progress wheel rotation must survive it (unlike add/delete).
    await addTasks(20);
    await db.landOnTask(8); // wheel now {1-7,9-15,16}
    final first = (await db.watchTasks().first)
        .firstWhere((t) => t.position == 1);
    await db.editTask(id: first.id, title: 'renamed');
    expect(await onWheelPositions(), {
      ...[1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15],
      16,
    });
  });

  test('test_delete_resequences_and_resets_wheel', () async {
    await addTasks(20);
    await db.landOnTask(8);
    final tenth = (await db.watchTasks().first)
        .firstWhere((t) => t.position == 10);
    await db.deleteTask(tenth.id);
    // 19 tasks remain, contiguous; wheel reset to 1..15.
    expect(await db.taskCount(), 19);
    expect(await onWheelPositions(), {for (var p = 1; p <= 15; p++) p});
  });

  test('test_property_wheel_holds_15_distinct_across_random_lands', () async {
    await addTasks(25);
    // Deterministic pseudo-random land sequence (no clock/RNG dependency).
    var seed = 12345;
    int nextLanded(int n) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed % n + 1;
    }

    for (var i = 0; i < 200; i++) {
      final current = (await db.watchWheelTasks().first)
          .map((t) => t.position)
          .toList();
      expect(current.toSet(), hasLength(15));
      // Land on one of the numbers actually on the wheel.
      await db.landOnTask(current[nextLanded(current.length) - 1]);
    }
    expect(await onWheelPositions(), hasLength(15));
  });
}
