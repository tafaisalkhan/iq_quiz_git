import 'package:flutter/material.dart';

class AnimatedCard extends StatelessWidget {
  final Widget child;
  final Duration delay;
  final double slideOffset;

  const AnimatedCard({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.slideOffset = 48.0,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      // We can use a Future.delayed internally or pass delay to start the tween
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0.0, (1.0 - value) * slideOffset),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
