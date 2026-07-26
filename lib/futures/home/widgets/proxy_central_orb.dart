import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tg_proxy/core/components/app_theme.dart';

class ProxyCentralOrb extends StatelessWidget {
  const ProxyCentralOrb({
    required this.pulseController,
    required this.orbitController,
    required this.isConnected,
    required this.isConnecting,
    required this.onPressed,
    super.key,
  });

  final Animation<double> pulseController;
  final Animation<double> orbitController;
  final bool isConnected;
  final bool isConnecting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return RepaintBoundary(
      child: SizedBox.square(
        dimension: 272,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _OrbPainter(
                  pulse: pulseController,
                  orbit: orbitController,
                  color: colors.primary,
                  active: isConnected || isConnecting,
                ),
              ),
            ),
            Semantics(
              button: true,
              enabled: !isConnecting,
              label: isConnected ? 'Stop proxy' : 'Start proxy',
              child: Material(
                color: colors.primary,
                shape: const CircleBorder(),
                elevation: isConnected ? 12 : 7,
                shadowColor: colors.primary.withValues(alpha: 0.55),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: isConnecting ? null : onPressed,
                  child: SizedBox.square(
                    dimension: 104,
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: isConnecting
                            ? const SizedBox.square(
                                key: ValueKey('loading'),
                                dimension: 30,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                            : Icon(
                                isConnected
                                    ? Icons.stop_rounded
                                    : Icons.power_settings_new_rounded,
                                key: ValueKey(isConnected),
                                size: 43,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter({
    required this.pulse,
    required this.orbit,
    required this.color,
    required this.active,
  }) : super(repaint: Listenable.merge([pulse, orbit]));

  final Animation<double> pulse;
  final Animation<double> orbit;
  final Color color;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final shortestSide = size.shortestSide;
    final pulseValue = active ? pulse.value : 0.2;

    for (var index = 0; index < 3; index++) {
      final radius = shortestSide * (0.24 + index * 0.105) + pulseValue * 3;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = index == 0 ? 1.6 : 1
          ..color = color.withValues(alpha: active ? 0.2 - index * 0.04 : 0.08),
      );
    }

    final orbitRadius = shortestSide * 0.43;
    for (var index = 0; index < 4; index++) {
      final angle = orbit.value * math.pi * 2 + index * math.pi / 2;
      final point =
          center + Offset(math.cos(angle), math.sin(angle)) * orbitRadius;
      canvas.drawCircle(
        point,
        index == 0 ? 4 : 2.5,
        Paint()..color = color.withValues(alpha: active ? 0.75 : 0.25),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OrbPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.active != active;
}
