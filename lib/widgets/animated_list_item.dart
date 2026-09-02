import 'package:flutter/material.dart';

class AnimatedListItem extends StatelessWidget {
  final int index;
  final Widget child;
  final Duration baseDuration;
  final double slideDistance;

  const AnimatedListItem({
    super.key,
    required this.index,
    required this.child,
    this.baseDuration = const Duration(milliseconds: 300),
    this.slideDistance = 18,
  });

  @override
  Widget build(BuildContext context) {
    final delay = index * 70;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: baseDuration + Duration(milliseconds: delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, slideDistance * (1 - value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}