import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'wheel_geometry.dart';

/// Default hard-coded sections until the wheel is wired to the task list.
const List<String> _defaultLabels = ['1', '2', '3', '4', '5'];

/// How long a single spin animation runs.
const Duration _spinDuration = Duration(milliseconds: 3500);

/// View state the task wheel screen renders from. [rotation] is the live
/// `Animation<double>` (radians) the painter repaints against.
class TaskWheelModel {
  const TaskWheelModel({
    required this.labels,
    required this.colors,
    required this.rotation,
    required this.selectedIndex,
    required this.selectedLabel,
    required this.isSpinning,
    required this.spin,
  });

  final List<String> labels;
  final List<Color> colors;
  final Animation<double> rotation;

  /// The wedge the wheel last landed on, or null before the first spin.
  final int? selectedIndex;

  /// Label of [selectedIndex], or null before the first spin.
  final String? selectedLabel;

  /// True while a spin animation is running; taps are ignored meanwhile.
  final bool isSpinning;

  /// Tap handler: starts a spin toward a random wedge.
  final VoidCallback spin;
}

/// Hook owning the wheel's spin animation and selection state. Mirrors the
/// logic-in-a-hook split used by the tasks screen ([useTasksScreen]).
///
/// [labels] defaults to the hard-coded `1`–`5`; callers may pass 2–15 labels
/// (e.g. real task titles later). The `flutter_hooks` `useAnimationController`
/// disposes the controller automatically on unmount.
TaskWheelModel useTaskWheelScreen({List<String>? labels}) {
  final sections = labels ?? _defaultLabels;
  assert(
    sections.length >= wheelMinSections &&
        sections.length <= wheelMaxSections,
    'Wheel supports $wheelMinSections–$wheelMaxSections sections, '
    'got ${sections.length}.',
  );

  final controller = useAnimationController(duration: _spinDuration);
  final random = useMemoized(Random.new);
  final colors =
      useMemoized(() => wheelColors(sections.length), [sections.length]);

  final selectedIndex = useState<int?>(null);
  final isSpinning = useState<bool>(false);
  // Refs (not state): mutated from callbacks/listeners without forcing rebuilds.
  final restRotation = useRef<double>(0);
  final pendingIndex = useRef<int?>(null);
  final rotation = useState<Animation<double>>(
    const AlwaysStoppedAnimation<double>(0),
  );

  useEffect(() {
    void onStatus(AnimationStatus status) {
      if (status != AnimationStatus.completed) return;
      restRotation.value = rotation.value.value;
      selectedIndex.value = pendingIndex.value;
      isSpinning.value = false;
    }

    controller.addStatusListener(onStatus);
    return () => controller.removeStatusListener(onStatus);
  }, [controller]);

  void spin() {
    if (isSpinning.value) return;
    final index = randomIndex(sections.length, random);
    final target = targetRotation(
      index: index,
      n: sections.length,
      current: restRotation.value,
    );
    pendingIndex.value = index;
    rotation.value = Tween<double>(begin: restRotation.value, end: target)
        .animate(CurvedAnimation(parent: controller, curve: Curves.easeOutCubic));
    isSpinning.value = true;
    controller.forward(from: 0);
  }

  final selected = selectedIndex.value;
  return TaskWheelModel(
    labels: sections,
    colors: colors,
    rotation: rotation.value,
    selectedIndex: selected,
    selectedLabel: selected == null ? null : sections[selected],
    isSpinning: isSpinning.value,
    spin: spin,
  );
}
