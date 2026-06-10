import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:take_five/src/screens/task_wheel/task_wheel_painter.dart';
import 'package:take_five/src/screens/task_wheel/task_wheel_screen.dart';
import 'package:take_five/src/screens/task_wheel/use_task_wheel_screen.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: TaskWheelScreen()));
    await tester.pump();
  }

  testWidgets('shows the spin prompt before any spin', (tester) async {
    await pumpScreen(tester);
    expect(find.text('Tap the wheel to spin'), findsOneWidget);
    expect(find.textContaining('Landed on:'), findsNothing);
  });

  testWidgets('tapping spins and the banner shows a landed result',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byType(TaskWheelScreen));
    // Run the spin animation to completion so the status listener fires.
    await tester.pumpAndSettle();

    expect(find.textContaining('Landed on:'), findsOneWidget);
    expect(find.text('Tap the wheel to spin'), findsNothing);
  });

  testWidgets('a tap during a spin is ignored', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byType(TaskWheelScreen));
    await tester.pump(const Duration(milliseconds: 200)); // mid-spin
    await tester.tap(find.byType(TaskWheelScreen)); // should be a no-op
    await tester.pumpAndSettle();

    // Exactly one spin resolved (one banner, screen settled cleanly).
    expect(find.textContaining('Landed on:'), findsOneWidget);
  });

  // Renders across the supported section range without paint/layout exceptions.
  for (final n in [2, 5, 15]) {
    testWidgets('renders $n sections without overflow', (tester) async {
      final labels = [for (var i = 1; i <= n; i++) 'Task number $i'];
      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              final wheel = useTaskWheelScreen(labels: labels);
              return CustomPaint(
                size: const Size(400, 400),
                painter: TaskWheelPainter(
                  labels: wheel.labels,
                  colors: wheel.colors,
                  rotation: wheel.rotation.value,
                  textColor: Colors.white,
                  accentColor: Colors.deepPurple,
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
