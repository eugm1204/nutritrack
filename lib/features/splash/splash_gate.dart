import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme.dart';

class SplashGate extends StatefulWidget {
  final Widget child;

  const SplashGate({super.key, required this.child});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _done = false;
  double _opacity = 1;

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1300), () {
      if (mounted) setState(() => _opacity = 0);
    });
    Timer(const Duration(milliseconds: 1650), () {
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_done) return widget.child;

    return AnimatedOpacity(
      opacity: _opacity,
      duration: const Duration(milliseconds: 350),
      child: Scaffold(
        backgroundColor: appBackground,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.85, end: 1),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOut,
                builder: (context, value, child) => Transform.scale(
                  scale: value,
                  child: Opacity(
                    opacity: value < 1 ? 0.7 : 1,
                    child: child,
                  ),
                ),
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: appGreen,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.restaurant,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOut,
                builder: (context, value, child) => Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 6 * (1 - value)),
                    child: child,
                  ),
                ),
                child: Text(
                  'NutriTrack',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}