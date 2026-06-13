import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:take_five/src/screens/task_wheel/use_task_wheel_screen.dart';

void main() {
  Future<void> pumpHook(
    WidgetTester tester,
    void Function() body,
  ) {
    return tester.pumpWidget(
      HookBuilder(builder: (_) {
        body();
        return const SizedBox.shrink();
      }),
    );
  }

  testWidgets('test_model_reflects_supplied_labels', (tester) async {
    late TaskWheelModel model;
    await pumpHook(
      tester,
      () => model = useTaskWheelScreen(labels: const ['1', '2', '3', '4', '5']),
    );

    expect(model.labels, ['1', '2', '3', '4', '5']);
    expect(model.colors, hasLength(5));
    expect(model.isSpinning, isFalse);
  });

  testWidgets('test_too_few_sections_asserts', (tester) async {
    await pumpHook(
      tester,
      () => useTaskWheelScreen(labels: const ['only']),
    );
    expect(tester.takeException(), isAssertionError);
  });

  testWidgets('test_too_many_sections_asserts', (tester) async {
    final labels = [for (var i = 0; i < 16; i++) '$i'];
    await pumpHook(tester, () => useTaskWheelScreen(labels: labels));
    expect(tester.takeException(), isAssertionError);
  });
}
