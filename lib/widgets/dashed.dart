import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

/// Contour en tirets. Flutter n'a pas de `BorderStyle.dashed` : on le peint.
/// Sert aux puces de filtre éteintes, à la barre des personnes, aux colonnes
/// vides et aux avatars d'intervenant.
class DashedBorder extends StatelessWidget {
  const DashedBorder({
    super.key,
    required this.child,
    this.radius,
    this.circle = false,
    this.color = T.lineStrong,
    this.width = T.borderWidth,
    this.dash = 4,
    this.gap = 3,
  });

  final Widget child;
  final double? radius;
  final bool circle;
  final Color color;
  final double width;
  final double dash;
  final double gap;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DashedPainter(
      radius: radius ?? 0,
      circle: circle,
      color: color,
      strokeWidth: width,
      dash: dash,
      gap: gap,
    ),
    child: child,
  );
}

class _DashedPainter extends CustomPainter {
  const _DashedPainter({
    required this.radius,
    required this.circle,
    required this.color,
    required this.strokeWidth,
    required this.dash,
    required this.gap,
  });

  final double radius;
  final bool circle;
  final Color color;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      math.max(0, size.width - strokeWidth),
      math.max(0, size.height - strokeWidth),
    );
    if (rect.isEmpty) return;

    final path = circle
        ? (Path()..addOval(rect))
        : (Path()
            ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius))));

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    for (final metric in path.computeMetrics()) {
      var start = 0.0;
      while (start < metric.length) {
        canvas.drawPath(
          metric.extractPath(start, math.min(start + dash, metric.length)),
          paint,
        );
        start += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPainter old) =>
      old.radius != radius ||
      old.circle != circle ||
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.dash != dash ||
      old.gap != gap;
}

/// Le filet pointillé qui sépare le pied des panneaux.
class DashedDivider extends StatelessWidget {
  const DashedDivider({super.key, this.color = T.line});

  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DashedLinePainter(color),
    size: const Size(double.infinity, T.borderWidth),
  );
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = T.borderWidth;
    for (var x = 0.0; x < size.width; x += 7) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(math.min(x + 4, size.width), size.height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) => old.color != color;
}
