import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:take_five/src/database/database.dart';
import 'package:take_five/src/database/database_exceptions.dart';
import 'package:take_five/src/providers/task_providers.dart';
import 'package:take_five/src/repositories/task_repository.dart';
import 'package:take_five/src/screens/tasks/tasks_screen.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  /// Drift query streams emit on real event-loop tasks, which the fake-async
  /// zone of `testWidgets` does not advance. [settle] escapes to real async via
  /// `runAsync` so the stream can deliver, then pumps frames (including any
  /// dialog/route animations) to render the result.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: TasksScreen(title: 'Items')),
      ),
    );
    await settle(tester);
  }

  /// Unmounts the widget tree so Riverpod disposes the providers, then pumps to
  /// drain the zero-duration timer Drift schedules when its query stream is
  /// cancelled. Without this the test-end `!timersPending` invariant fails.
  Future<void> disposeScreen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    // Advance the fake clock so Drift's zero-duration close timer actually
    // fires (a zero-duration pump() does not elapse time enough to drain it).
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('shows the empty state when there are no items', (tester) async {
    await pumpScreen(tester);
    expect(find.textContaining('No tasks yet'), findsOneWidget);
    await disposeScreen(tester);
  });

  testWidgets('renders items in position order with optional description',
      (tester) async {
    await db.addTask(title: 'Alpha', description: 'first detail');
    await db.addTask(title: 'Beta'); // no description
    await pumpScreen(tester);

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('first detail'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    await disposeScreen(tester);
  });

  testWidgets('adding a valid item inserts it and updates the list reactively',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'New item');
    await tester.tap(find.text('Add'));
    await settle(tester);

    expect(find.text('New item'), findsOneWidget);
    expect(await db.taskCount(), 1);
    await disposeScreen(tester);
  });

  testWidgets(
      'blocks an empty title with an inline message and persists nothing',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Submit without entering a title.
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Title is required.'), findsOneWidget);
    expect(await db.taskCount(), 0);
    // Dialog is still open.
    expect(find.text('Add task'), findsOneWidget);
    await disposeScreen(tester);
  });

  testWidgets('editing an item updates its title', (tester) async {
    await db.addTask(title: 'Before');
    await pumpScreen(tester);

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'After');
    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(find.text('After'), findsOneWidget);
    expect(find.text('Before'), findsNothing);
    await disposeScreen(tester);
  });

  testWidgets('editing an item updates its description', (tester) async {
    await db.addTask(title: 'Item', description: 'old detail');
    await pumpScreen(tester);

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    // Second field is the description.
    await tester.enterText(find.byType(TextFormField).at(1), 'new detail');
    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(find.text('new detail'), findsOneWidget);
    expect(find.text('old detail'), findsNothing);
    await disposeScreen(tester);
  });

  testWidgets('deleting an item removes it and re-sequences positions',
      (tester) async {
    await db.addTask(title: 'One');
    await db.addTask(title: 'Two');
    await pumpScreen(tester);

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await settle(tester);

    expect(find.text('One'), findsNothing);
    expect(find.text('Two'), findsOneWidget);
    // 'Two' was re-sequenced from position 2 to 1 — verified via its badge.
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsNothing);
    await disposeScreen(tester);
  });

  testWidgets('disables adding and shows a banner when the cap is reached',
      (tester) async {
    for (var i = 0; i < AppDatabase.maxTasks; i++) {
      await db.addTask(title: 'item $i');
    }
    await pumpScreen(tester);

    expect(
      find.textContaining('Maximum of ${AppDatabase.maxTasks} tasks'),
      findsOneWidget,
    );

    final fab = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(fab.onPressed, isNull);
    await disposeScreen(tester);
  });

  testWidgets('surfaces a mutation failure as a SnackBar', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          taskRepositoryProvider.overrideWithValue(_ThrowingRepository()),
        ],
        child: const MaterialApp(home: TasksScreen(title: 'Items')),
      ),
    );
    await settle(tester);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Anything');
    await tester.tap(find.text('Add'));
    await settle(tester);

    expect(find.textContaining('List is limited to'), findsOneWidget);
    await disposeScreen(tester);
  });
}

/// A repository whose mutations always fail, used to drive the UI error path.
class _ThrowingRepository implements TaskRepository {
  @override
  Future<int> add({required String title, String? description}) async {
    throw const TaskLimitExceededException(AppDatabase.maxTasks);
  }

  @override
  Future<void> edit({
    required int id,
    required String title,
    String? description,
  }) async {}

  @override
  Future<void> delete(int id) async {}
}
