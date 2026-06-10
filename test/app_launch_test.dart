import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:take_five/main.dart';
import 'package:take_five/src/screens/task_wheel/task_wheel_screen.dart';
import 'package:take_five/src/screens/tasks/tasks_screen.dart';

void main() {
  testWidgets('app launches into the task wheel, not the task list',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pump();

    expect(find.byType(TaskWheelScreen), findsOneWidget);
    expect(find.byType(TasksScreen), findsNothing);
    expect(find.text('Tap the wheel to spin'), findsOneWidget);
  });
}
