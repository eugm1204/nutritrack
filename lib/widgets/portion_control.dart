import 'package:flutter/material.dart';

import '../models/meal_item.dart';
import 'portion_stepper.dart';

class PortionControl extends StatelessWidget {
  final MealItem item;
  final MealItem base;
  final void Function(double multiplier) onPortionChanged;

  const PortionControl({
    super.key,
    required this.item,
    required this.base,
    required this.onPortionChanged,
  });

  double get _multiplier {
    if (base.grams != null && base.grams! > 0 && item.grams != null) {
      final m = item.grams! / base.grams!;
      return (m * 100).roundToDouble() / 100;
    }
    if (base.calories > 0 && item.calories > 0) {
      final m = item.calories / base.calories;
      return (m * 100).roundToDouble() / 100;
    }
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grams = item.grams;
    final portionRef = item.portionRef;

    return Padding(
      padding: const EdgeInsets.only(left: 14, top: 2),
      child: Row(
        children: [
          PortionStepper(
            multiplier: _multiplier,
            onChanged: onPortionChanged,
          ),
          const SizedBox(width: 12),
          if (grams != null)
            Text(
              '${grams.round()} g',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
          if (grams != null && portionRef != null) ...[
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward_ios,
                size: 10, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
          ],
          if (portionRef != null)
            Expanded(
              child: Text(
                portionRef,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}