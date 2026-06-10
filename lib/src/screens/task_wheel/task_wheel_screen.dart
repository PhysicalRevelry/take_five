import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../tasks/tasks_screen.dart';
import 'task_wheel_painter.dart';
import 'use_task_wheel_screen.dart';

/// The app's launch screen: a hand-rolled Wheel-of-Fortune style wheel. Tapping
/// the wheel spins it to a random section; the landed value is shown in the
/// banner below. All spin logic lives in [useTaskWheelScreen]; this build method
/// only renders the resulting state.
class TaskWheelScreen extends HookWidget {
  const TaskWheelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wheel = useTaskWheelScreen();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.inversePrimary,
        title: const Text('Take Five'),
      ),
      // A drawer makes the Scaffold show the hamburger menu in the AppBar's
      // leading slot automatically.
      drawer: const _AppDrawer(),
      body: Column(
        children: [
          Expanded(
            flex: 1,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Take five minutes to...',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: GestureDetector(
                    // Tap-to-spin. Ignored mid-spin so a spin can't re-trigger.
                    onTap: wheel.isSpinning ? null : wheel.spin,
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedBuilder(
                      animation: wheel.rotation,
                      builder: (context, _) => CustomPaint(
                        painter: TaskWheelPainter(
                          labels: wheel.labels,
                          colors: wheel.colors,
                          rotation: wheel.rotation.value,
                          textColor: Colors.white,
                          accentColor: scheme.primary,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          _ResultBanner(label: wheel.selectedLabel),
        ],
      ),
    );
  }
}

/// Navigation drawer. Holds a single entry for now — opening the task list
/// editor ([TasksScreen]).
class _AppDrawer extends StatelessWidget {
  const _AppDrawer();

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            ListTile(
              leading: const Icon(Icons.checklist),
              title: const Text('Edit task list'),
              onTap: () {
                Navigator.pop(context); // close the drawer first
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const TasksScreen(title: 'Edit task list'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the landed section below the wheel, or a prompt before the first spin.
class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.label});

  /// The landed section label, or null if the wheel has not been spun yet.
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        label == null ? 'Tap the wheel to spin' : 'Landed on: $label',
        style: Theme.of(context).textTheme.titleLarge,
        textAlign: TextAlign.center,
      ),
    );
  }
}
