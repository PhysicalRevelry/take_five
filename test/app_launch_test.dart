import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:take_five/main.dart';
import 'package:take_five/src/database/database.dart';
import 'package:take_five/src/providers/task_providers.dart';
import 'package:take_five/src/screens/task_wheel/task_wheel_screen.dart';
import 'package:take_five/src/screens/tasks/tasks_screen.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  testWidgets('app launches into the task wheel, not the task list',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MyApp(),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TaskWheelScreen), findsOneWidget);
    expect(find.byType(TasksScreen), findsNothing);
    // Empty list → wheel is locked with the add-tasks prompt.
    expect(
      find.text('Please add tasks to your task list to get started.'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
