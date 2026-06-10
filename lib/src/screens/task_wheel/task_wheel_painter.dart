import 'dart:math';

import 'package:flutter/material.dart';

import 'wheel_geometry.dart';

/// Paints the task wheel: [labels.length] colored wedges rotated by [rotation]
/// radians, a center hub, and a fixed pointer at the top (12 o'clock,
/// [wheelPointerAngle]). Scales label text down as the section count grows and
/// truncates with an ellipsis so thin wedges never overflow.
class TaskWheelPainter extends CustomPainter {
  TaskWheelPainter({
    required this.labels,
    required this.colors,
    required this.rotation,
    required this.textColor,
    required this.accentColor,
  });

  final List<String> labels;
  final List<Color> colors;
  final double rotation;
  final Color textColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final n = labels.length;
    final radius = size.shortestSide / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweep = sectionSweep(n);

    final fill = Paint()..style = PaintingStyle.fill;
    final divider = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = textColor;

    // Wedges.
    for (var i = 0; i < n; i++) {
      final start = i * sweep + rotation;
      fill.color = colors[i];
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(rect, start, sweep, false)
        ..close();
      canvas
        ..drawPath(path, fill)
        ..drawPath(path, divider);
    }

    // Labels. Font shrinks with section count; width is capped to the wedge's
    // chord at the label radius so long titles ellipsize instead of overflowing.
    final labelRadius = radius * 0.62;
    final maxWidth = 2 * labelRadius * sin(sweep / 2);
    final fontSize = (radius * 0.16 * (5 / n)).clamp(9.0, 20.0);
    for (var i = 0; i < n; i++) {
      final mid = i * sweep + sweep / 2 + rotation;
      final painter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            color: textColor,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: maxWidth);

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(mid);
      canvas.translate(labelRadius, 0);
      // Keep text upright on the wheel's left half instead of upside-down.
      final normalized = mid % (2 * pi);
      if (normalized > pi / 2 && normalized < 3 * pi / 2) {
        canvas.rotate(pi);
      }
      painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
      canvas.restore();
    }

    // Center hub.
    canvas.drawCircle(center, radius * 0.08, Paint()..color = accentColor);

    // Fixed pointer at the top, tip aimed into the wheel.
    final pointer = Path()
      ..moveTo(center.dx - 14, center.dy - radius)
      ..lineTo(center.dx + 14, center.dy - radius)
      ..lineTo(center.dx, center.dy - radius + 24)
      ..close();
    canvas.drawPath(pointer, Paint()..color = accentColor);
  }

  @override
  bool shouldRepaint(covariant TaskWheelPainter old) =>
      old.rotation != rotation ||
      old.labels != labels ||
      old.colors != colors ||
      old.textColor != textColor ||
      old.accentColor != accentColor;
}
