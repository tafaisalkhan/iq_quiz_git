import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A brief, non-interactive burst around the middle of the quiz screen.
class AnswerSparkles extends StatelessWidget {
  const AnswerSparkles({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        builder: (context, progress, _) => CustomPaint(
          painter: _SparklePainter(progress),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _SparklePainter extends CustomPainter {
  const _SparklePainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .42);
    const colors = [
      Color(0xFFFFD54F),
      Color(0xFF69F0AE),
      Color(0xFF80D8FF),
      Color(0xFFFF80AB),
    ];
    for (var i = 0; i < 30; i++) {
      final angle = i * 2 * math.pi / 30;
      final distance =
          (40 + (i % 5) * 23) * Curves.easeOutCubic.transform(progress);
      final point =
          center +
          Offset(math.cos(angle) * distance, math.sin(angle) * distance);
      final paint = Paint()
        ..color = colors[i % colors.length].withValues(alpha: 1 - progress);
      canvas.drawCircle(point, (i % 3 + 2) * (1 - progress * .5), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
