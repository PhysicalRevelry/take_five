import 'dart:math';

import 'package:flutter/painting.dart';

// Re-export the shared section limits so existing geometry consumers keep
// importing [wheelMinSections] / [wheelMaxSections] from here.
export '../../wheel_limits.dart' show wheelMinSections, wheelMaxSections;

/// Pure geometry + selection math for the hand-rolled task wheel. Kept free of
/// widgets and animation so it can be unit/property-tested directly. The widget
/// layer ([useTaskWheelScreen], [TaskWheelPainter]) consumes these.
///
/// Angle convention matches Flutter's canvas: 0 rad points along +x (3 o'clock)
/// and angles increase clockwise. Wedge `index` occupies
/// `[index * sweep, (index + 1) * sweep)` in the wheel's own (unrotated) frame.

/// Screen-space angle the fixed pointer sits at: straight up (12 o'clock).
const double wheelPointerAngle = -pi / 2;

/// Angular width of one wedge, in radians.
double sectionSweep(int n) => 2 * pi / n;

/// Center angle of wedge [index] in the wheel's unrotated frame.
double sectionCenterAngle(int index, int n) =>
    index * sectionSweep(n) + sectionSweep(n) / 2;

/// Picks a uniformly random wedge in `[0, n)`.
int randomIndex(int n, Random random) => random.nextInt(n);

/// The wheel rotation (radians) that lands [index] under the pointer.
///
/// The result is strictly ahead of [current] by at least [minTurns] full turns
/// (so the wheel always visibly spins forward) and, reduced mod 2π, aligns
/// [index]'s wedge center to [wheelPointerAngle].
double targetRotation({
  required int index,
  required int n,
  required double current,
  int minTurns = 5,
}) {
  final center = sectionCenterAngle(index, n);
  // Rotation R must satisfy: center + R ≡ pointer (mod 2π).
  final base = wheelPointerAngle - center;
  final floor = current + minTurns * 2 * pi;
  // Smallest value ≥ floor that is congruent to `base` mod 2π. Dart's `%`
  // returns a non-negative remainder for a positive divisor, so this lands in
  // [floor, floor + 2π).
  final delta = (base - floor) % (2 * pi);
  return floor + delta;
}

/// `n` visually distinct colors via an even hue sweep, so even 15 sections stay
/// distinguishable.
List<Color> wheelColors(int n) => [
      for (var i = 0; i < n; i++)
        HSVColor.fromAHSV(1, (i * 360 / n) % 360, 0.55, 0.9).toColor(),
    ];
