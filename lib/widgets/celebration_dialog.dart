import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

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
                numberOfParticles: 60,
                gravity: 0.25,
                colors: const [
                  Color(0xFF2E7D32),
                  Color(0xFF66BB6A),
                  Color(0xFFF9A825),
                  Color(0xFFE8590C),
                  Color(0xFF7C4DFF),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 12),
                Text(
                  'Meta dentro do alvo!',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${widget.consumedCalories} de ${widget.goalCalories} kcal — excelente trabalho! 💪',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Continuar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}