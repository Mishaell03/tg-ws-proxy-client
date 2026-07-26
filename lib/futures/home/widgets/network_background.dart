import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tg_proxy/core/components/app_theme.dart';

class NetworkBackground extends StatelessWidget {
  const NetworkBackground({
    required this.controller,
    required this.isConnected,
    super.key,
  });

  final Animation<double> controller;
  final bool isConnected;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: _NetworkBackgroundPainter(
        animation: controller,
        backgroundColor: context.colors.bg,
        lineColor: isConnected
            ? context.colors.success
            : context.colors.primary,
        active: isConnected,
      ),
    ),
  );
}

class _NetworkBackgroundPainter extends CustomPainter {
  _NetworkBackgroundPainter({
    required this.animation,
    required this.backgroundColor,
    required this.lineColor,
    required this.active,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Color backgroundColor;
  final Color lineColor;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = backgroundColor);

    final points = <Offset>[
      Offset(size.width * 0.05, size.height * 0.18),
      Offset(size.width * 0.27, size.height * 0.28),
      Offset(size.width * 0.78, size.height * 0.16),
      Offset(size.width * 0.94, size.height * 0.34),
      Offset(size.width * 0.11, size.height * 0.67),
      Offset(size.width * 0.34, size.height * 0.82),
      Offset(size.width * 0.74, size.height * 0.74),
      Offset(size.width * 0.92, size.height * 0.88),
    ];
    const edges = <(int, int)>[
      (0, 1),
      (0, 4),
      (1, 2),
      (1, 5),
      (2, 3),
      (2, 6),
      (3, 6),
      (4, 5),
      (5, 6),
      (6, 7),
    ];
    final linePaint = Paint()
      ..strokeWidth = 1
      ..color = lineColor.withValues(alpha: active ? 0.11 : 0.055);
    for (final edge in edges) {
      canvas.drawLine(points[edge.$1], points[edge.$2], linePaint);
    }

    final phase = animation.value * math.pi * 2;
    for (var index = 0; index < points.length; index++) {
      final wave = (math.sin(phase + index * 0.8) + 1) / 2;
      canvas.drawCircle(
        points[index],
        2 + wave * (active ? 2 : 1),
        Paint()..color = lineColor.withValues(alpha: active ? 0.25 : 0.12),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NetworkBackgroundPainter oldDelegate) =>
      oldDelegate.backgroundColor != backgroundColor ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.active != active;
}
