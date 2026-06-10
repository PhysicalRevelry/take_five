import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:take_five/src/screens/task_wheel/wheel_geometry.dart';

/// Reduces an angle to `[0, 2π)`.
double norm(double a) => a % (2 * pi);

void main() {
  final counts = [for (var n = wheelMinSections; n <= wheelMaxSections; n++) n];

  group('sectionSweep', () {
    test('test_sectionSweep_equals_full_circle_over_n', () {
      for (final n in counts) {
        expect(sectionSweep(n), closeTo(2 * pi / n, 1e-12));
      }
    });

    test('test_sweeps_tile_the_circle', () {
      for (final n in counts) {
        expect(sectionSweep(n) * n, closeTo(2 * pi, 1e-9));
      }
    });
  });

  group('randomIndex', () {
    test('test_randomIndex_always_in_range', () {
      final random = Random(7);
      for (final n in counts) {
        for (var i = 0; i < 200; i++) {
          expect(randomIndex(n, random), inInclusiveRange(0, n - 1));
        }
      }
    });
  });

  group('targetRotation', () {
    test('test_target_is_forward_by_at_least_minTurns', () {
      const minTurns = 5;
      for (final n in counts) {
        for (var index = 0; index < n; index++) {
          final r = targetRotation(
            index: index,
            n: n,
            current: 1.234,
            minTurns: minTurns,
          );
          expect(
            r - 1.234,
            greaterThanOrEqualTo(minTurns * 2 * pi - 1e-9),
            reason: 'n=$n index=$index must advance ≥ $minTurns turns',
          );
        }
      }
    });

    test('test_target_aligns_chosen_wedge_under_pointer', () {
      for (final n in counts) {
        for (var index = 0; index < n; index++) {
          final r = targetRotation(index: index, n: n, current: 0);
          // center + R ≡ pointer  ⇒  pointer - R ≡ center  (mod 2π)
          expect(
            norm(wheelPointerAngle - r),
            closeTo(norm(sectionCenterAngle(index, n)), 1e-9),
            reason: 'n=$n index=$index not aligned under pointer',
          );
        }
      }
    });

    test('test_target_is_forward_and_aligned_for_random_inputs', () {
      // Property/fuzz: never throws; always forward + pointer-aligned.
      final random = Random(99);
      for (var i = 0; i < 2000; i++) {
        final n = wheelMinSections + random.nextInt(wheelMaxSections - 1);
        final index = random.nextInt(n);
        final current = random.nextDouble() * 100;
        final r = targetRotation(index: index, n: n, current: current);
        expect(r, greaterThan(current));
        expect(
          norm(wheelPointerAngle - r),
          closeTo(norm(sectionCenterAngle(index, n)), 1e-9),
        );
      }
    });
  });

  group('wheelColors', () {
    test('test_returns_n_distinct_colors', () {
      for (final n in counts) {
        final colors = wheelColors(n);
        expect(colors, hasLength(n));
        expect(colors.toSet(), hasLength(n), reason: 'colors must be distinct');
      }
    });
  });
}
