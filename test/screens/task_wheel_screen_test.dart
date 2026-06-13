import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:take_five/src/database/database.dart';
import 'package:take_five/src/providers/task_providers.dart';
import 'package:take_five/src/screens/task_wheel/task_wheel_screen.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  /// Escapes the fake-async zone so Drift query streams can deliver, then pumps.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    // Portrait surface, matching real devices: the wheel is a width-derived
    // square, which would overflow the default 800x600 (wide) test window.
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: TaskWheelScreen()),
      ),
    );
    await settle(tester);
  }

  Future<void> disposeScreen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('locks the wheel with a prompt below the minimum',
      (tester) async {
    await db.addTask(title: 'Only one');
    await pumpScreen(tester);

    expect(
      find.text('Please add tasks to your task list to get started.'),
      findsOneWidget,
    );
    expect(find.text('Tap the wheel to spin'), findsNothing);
    await disposeScreen(tester);
  });

  testWidgets('unlocks with the spin prompt once the minimum is met',
      (tester) async {
    for (var i = 1; i <= 5; i++) {
      await db.addTask(title: 'Task $i');
    }
    await pumpScreen(tester);

    // Section numbers are painted on a CustomPaint canvas (not Text widgets),
    // so the unlocked state is asserted via the prompt + absence of the lock.
    expect(find.text('Tap the wheel to spin'), findsOneWidget);
    expect(
      find.text('Please add tasks to your task list to get started.'),
      findsNothing,
    );
    await disposeScreen(tester);
  });

  testWidgets('spinning lands on a task and shows its title', (tester) async {
    for (var i = 1; i <= 5; i++) {
      await db.addTask(title: 'Task $i');
    }
    await pumpScreen(tester);

    await tester.tap(find.byType(TaskWheelScreen));
    await tester.pumpAndSettle();

    expect(find.textContaining('Lands on: Task '), findsOneWidget);
    expect(find.text('Tap the wheel to spin'), findsNothing);
    await disposeScreen(tester);
  });

  /// Parses the number `X` out of the rendered `Lands on: Task X` banner.
  String landedNumber(WidgetTester tester) {
    final text =
        tester.widget<Text>(find.textContaining('Lands on: Task ')).data!;
    return text.split('Task ').last.trim();
  }

  testWidgets('landed title and description belong to the same task (<=15)',
      (tester) async {
    for (var i = 1; i <= 5; i++) {
      await db.addTask(title: 'Task $i', description: 'Desc $i');
    }
    await pumpScreen(tester);

    await tester.tap(find.byType(TaskWheelScreen));
    await tester.pumpAndSettle();

    final n = landedNumber(tester);
    // The description shown must be the landed task's own, and no other.
    expect(find.text('Desc $n'), findsOneWidget);
    for (var i = 1; i <= 5; i++) {
      if ('$i' != n) expect(find.text('Desc $i'), findsNothing);
    }
    await disposeScreen(tester);
  });

  testWidgets('landed title and description belong to the same task (>15)',
      (tester) async {
    for (var i = 1; i <= 20; i++) {
      await db.addTask(title: 'Task $i', description: 'Desc $i');
    }
    await pumpScreen(tester);

    await tester.tap(find.byType(TaskWheelScreen));
    await tester.pumpAndSettle();

    final n = landedNumber(tester);
    expect(find.text('Desc $n'), findsOneWidget);
    await disposeScreen(tester);
  });

  testWidgets('with more than 15 tasks the wheel keeps 15 and rotates on land',
      (tester) async {
    for (var i = 1; i <= 20; i++) {
      await db.addTask(title: 'Task $i');
    }
    await pumpScreen(tester);

    // Starts on the lowest 15 positions. Drift stream reads must run via
    // runAsync to escape the fake-async zone (a bare `.first` would hang).
    final before = (await tester.runAsync(() => db.watchWheelTasks().first))!
        .map((t) => t.position)
        .toSet();
    expect(before, {for (var p = 1; p <= 15; p++) p});

    await tester.tap(find.byType(TaskWheelScreen));
    await tester.pumpAndSettle();
    await settle(tester); // let the landOn write + stream re-emit settle

    expect(find.textContaining('Lands on: Task '), findsOneWidget);
    // Still exactly 15, but the set changed (one rotated off, 16 came on).
    final after = (await tester.runAsync(() => db.watchWheelTasks().first))!
        .map((t) => t.position)
        .toSet();
    expect(after, hasLength(15));
    expect(after, isNot(before));
    expect(after.contains(16), isTrue);
    await disposeScreen(tester);
  });
}
