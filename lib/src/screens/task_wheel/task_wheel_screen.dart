import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../database/database.dart';
import '../../models/task.dart';
import '../../providers/task_providers.dart';
import '../tasks/tasks_screen.dart';
import 'task_wheel_painter.dart';
import 'use_task_wheel_screen.dart';
import 'wheel_geometry.dart';

/// Largest the wheel is allowed to grow to, so it stays sensible on wide
/// desktop windows.
const double _maxWheelDiameter = 500;

/// The app's launch screen. Spins over the task list: each wheel section is a
/// task number, landing shows that task's title and description. Needs at least
/// [AppDatabase.minTasks] tasks — below that the wheel is locked.
class TaskWheelScreen extends HookConsumerWidget {
  const TaskWheelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final tasks = ref.watch(taskListProvider);
    // Lifted here so the bottom band (sibling of the wheel) can render the
    // landed task while the spin state stays inside [_ActiveWheelBody].
    final landed = useState<Task?>(null);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.inversePrimary,
        title: const Text('Take Five'),
      ),
      // A drawer makes the Scaffold show the hamburger menu automatically.
      drawer: const _AppDrawer(),
      body: tasks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Could not load tasks: $error')),
        data: (list) {
          final locked = list.length < AppDatabase.minTasks;
          final wheelTasks = [for (final t in list) if (t.onWheel) t];

          return Column(
            children: [
              const Expanded(flex: 1, child: Center(child: _Heading())),
              // The wheel is sized to its content — a square capped at
              // [_maxWheelDiameter] — instead of being wrapped in a flex, so it
              // never has empty space around it. The flex-1 bands above and
              // below center it and balance the heading and result text.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: _maxWheelDiameter),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: locked
                        ? _LockedWheelFace(accent: scheme.primary)
                        : _ActiveWheelBody(tasks: wheelTasks, landed: landed),
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Center(
                  child: locked
                      ? const _LockedMessage()
                      : _ResultBanner(task: landed.value),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The "Take five minutes to..." title above the wheel.
class _Heading extends StatelessWidget {
  const _Heading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        'Take five minutes to...',
        textAlign: TextAlign.center,
        style: Theme.of(context)
            .textTheme
            .headlineSmall
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// The interactive wheel face. [tasks] are the (5–15) tasks currently on the
/// wheel, ordered by position; [landed] is updated with the task the wheel
/// stops on.
class _ActiveWheelBody extends HookConsumerWidget {
  const _ActiveWheelBody({required this.tasks, required this.landed});

  final List<Task> tasks;
  final ValueNotifier<Task?> landed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final labels = [for (final t in tasks) '${t.position}'];

    final wheel = useTaskWheelScreen(
      labels: labels,
      onLanded: (index) {
        if (index < 0 || index >= tasks.length) return;
        final task = tasks[index];
        landed.value = task;
        // No-op server-side when 15 or fewer tasks exist.
        ref.read(taskRepositoryProvider).landOn(task.position);
      },
    );

    return GestureDetector(
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
    );
  }
}

/// A dimmed, non-interactive wheel shown when there are too few tasks to spin.
class _LockedWheelFace extends StatelessWidget {
  const _LockedWheelFace({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.25,
      child: IgnorePointer(
        child: CustomPaint(
          painter: TaskWheelPainter(
            labels: const ['1', '2', '3', '4', '5'],
            colors: wheelColors(5),
            rotation: 0,
            textColor: Colors.white,
            accentColor: accent,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// Prompt shown below the locked wheel.
class _LockedMessage extends StatelessWidget {
  const _LockedMessage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Text(
        'Please add tasks to your task list to get started.',
        textAlign: TextAlign.center,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
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

/// Shows the landed task's title (and description, if any), or a prompt before
/// the first spin.
class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.task});

  /// The landed task, or null if the wheel has not been spun yet.
  final Task? task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final landed = task;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            landed == null
                ? 'Tap the wheel to spin'
                : 'Lands on: ${landed.title}',
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          if (landed?.description != null) ...[
            const SizedBox(height: 4),
            Text(
              landed!.description!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: (theme.textTheme.bodyMedium?.fontSize ?? 14) + 4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
