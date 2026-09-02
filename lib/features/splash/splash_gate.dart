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
    if (_done) return widget.child;

    return AnimatedOpacity(
      opacity: _opacity,
      duration: const Duration(milliseconds: 350),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: primaryGradient),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutBack,
                builder: (context, value, child) => Transform.scale(
                  scale: value,
                  child: Opacity(opacity: value, child: child),
                ),
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text('🍽️', style: TextStyle(fontSize: 52)),
                ),
              ),
              const SizedBox(height: 20),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOut,
                builder: (context, value, child) => Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 8 * (1 - value)),
                    child: child,
                  ),
                ),
                child: const Text(
                  'NutriTrack',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
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