import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'wheel_geometry.dart';

/// How long a single spin animation runs.
const Duration _spinDuration = Duration(milliseconds: 3500);

/// View state the wheel renders from. [rotation] is the live `Animation<double>`
/// (radians) the painter repaints against.
class TaskWheelModel {
  const TaskWheelModel({
    required this.labels,
    required this.colors,
    required this.rotation,
    required this.isSpinning,
    required this.spin,
  });

  final List<String> labels;
  final List<Color> colors;
  final Animation<double> rotation;

  /// True while a spin animation is running; taps are ignored meanwhile.
  final bool isSpinning;

  /// Tap handler: starts a spin toward a random section.
  final VoidCallback spin;
}

/// Hook owning the wheel's spin animation. The caller supplies the section
/// [labels] (the task numbers) and an [onLanded] callback invoked with the
/// landed section index when the spin completes — keeping task lookup and the
/// resulting side effects (showing the title, rotating the wheel) in the widget
/// layer. `useAnimationController` disposes the controller on unmount.
TaskWheelModel useTaskWheelScreen({
  required List<String> labels,
  void Function(int landedIndex)? onLanded,
}) {
  assert(
    labels.length >= wheelMinSections && labels.length <= wheelMaxSections,
    'Wheel supports $wheelMinSections–$wheelMaxSections sections, '
    'got ${labels.length}.',
  );

  final controller = useAnimationController(duration: _spinDuration);
  final random = useMemoized(Random.new);
  final colors =
      useMemoized(() => wheelColors(labels.length), [labels.length]);

  final isSpinning = useState<bool>(false);
  final restRotation = useRef<double>(0);
  final pendingIndex = useRef<int?>(null);
  final rotation = useState<Animation<double>>(
    const AlwaysStoppedAnimation<double>(0),
  );

  // Keep the latest callback so the status listener (bound once) always calls
  // the current closure rather than a stale capture.
  final onLandedRef = useRef(onLanded);
  onLandedRef.value = onLanded;

  useEffect(() {
    void onStatus(AnimationStatus status) {
      if (status != AnimationStatus.completed) return;
      restRotation.value = rotation.value.value;
      isSpinning.value = false;
      final index = pendingIndex.value;
      if (index != null) onLandedRef.value?.call(index);
    }

    controller.addStatusListener(onStatus);
    return () => controller.removeStatusListener(onStatus);
  }, [controller]);

  void spin() {
    if (isSpinning.value) return;
    final index = randomIndex(labels.length, random);
    final target = targetRotation(
      index: index,
      n: labels.length,
      current: restRotation.value,
    );
    pendingIndex.value = index;
    rotation.value = Tween<double>(begin: restRotation.value, end: target)
        .animate(CurvedAnimation(parent: controller, curve: Curves.easeOutCubic));
    isSpinning.value = true;
    controller.forward(from: 0);
  }

  return TaskWheelModel(
    labels: labels,
    colors: colors,
    rotation: rotation.value,
    isSpinning: isSpinning.value,
    spin: spin,
  );
}
