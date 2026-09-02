import 'package:flutter/material.dart';

class PortionStepper extends StatelessWidget {
  final double multiplier;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final double step;

  const PortionStepper({
    super.key,
    required this.multiplier,
    required this.onChanged,
    this.min = 0.25,
    this.max = 3,
    this.step = 0.25,
  });

  String get _label {
    final value = multiplier * 100;
    final rounded = value.round();
    if (rounded % 100 == 0) return '×${rounded ~/ 100}';
    if (rounded % 50 == 0) return '×${(rounded / 100).toStringAsFixed(1)}';
    return '×${(rounded / 100).toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Button(
          icon: Icons.remove,
          onTap: multiplier > min ? () => onChanged((multiplier - step).clamp(min, max)) : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            _label,
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        _Button(
          icon: Icons.add,
          onTap: multiplier < max ? () => onChanged((multiplier + step).clamp(min, max)) : null,
        ),
      ],
    );
  }
}

class _Button extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _Button({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primary.withValues(alpha: 0.10),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(
            icon,
            size: 18,
            color: onTap == null
                ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3)
                : theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}