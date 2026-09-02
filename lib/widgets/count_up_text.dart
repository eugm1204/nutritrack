import 'package:flutter/material.dart';

class CountUpText extends StatelessWidget {
  final int target;
  final TextStyle? style;
  final Duration duration;

  const CountUpText({
    super.key,
    required this.target,
    this.style,
    this.duration = const Duration(milliseconds: 900),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: target),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => Text('$value', style: style),
    );
  }
}