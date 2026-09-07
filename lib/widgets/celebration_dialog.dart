import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';

class CelebrationDialog extends StatefulWidget {
  final int consumedCalories;
  final int goalCalories;

  const CelebrationDialog({
    super.key,
    required this.consumedCalories,
    required this.goalCalories,
  });

  @override
  State<CelebrationDialog> createState() => _CelebrationDialogState();
}

class _CelebrationDialogState extends State<CelebrationDialog> {
  final _confettiController = ConfettiController(duration: const Duration(seconds: 3));

  @override
  void initState() {
    super.initState();
    _confettiController.play();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                numberOfParticles: 40,
                gravity: 0.25,
                colors: [appGreen, appOrange, theme.colorScheme.onSurfaceVariant],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🎉', style: TextStyle(fontSize: 44)),
                const SizedBox(height: 14),
                Text(
                  'Meta dentro do alvo',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.consumedCalories} de ${widget.goalCalories} kcal — bom trabalho.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Continuar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}