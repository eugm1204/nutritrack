import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../models/meal.dart';
import 'pressable_card.dart';

String mealTypeEmoji(DateTime time) {
  final h = time.hour;
  if (h < 11) return '☕';
  if (h < 16) return '🍽️';
  if (h < 22) return '🌙';
  return '🌌';
}

Color mealTypeColor(DateTime time) {
  final h = time.hour;
  if (h < 11) return morningColor;
  if (h < 16) return lunchColor;
  if (h < 22) return dinnerColor;
  return nightColor;
}

class MealCard extends StatelessWidget {
  final Meal meal;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool showHero;

  const MealCard({
    super.key,
    required this.meal,
    required this.onTap,
    required this.onDelete,
    this.showHero = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeColor = mealTypeColor(meal.consumedAt);

    return PressableCard(
      onTap: onTap,
      onLongPress: () => _confirmDelete(context),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          _MealThumbnail(meal: meal, color: typeColor, showHero: showHero),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal.mealName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  '${mealTypeEmoji(meal.consumedAt)} '
                  '${meal.itemCount} item(s) · ${DateFormat('HH:mm').format(meal.consumedAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${meal.totalCalories}',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.primary,
            ),
          ),
          Text(
            ' kcal',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar refeição'),
        content: const Text('Tens a certeza que queres apagar esta refeição?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (ok == true) onDelete();
  }
}

class _MealThumbnail extends StatelessWidget {
  final Meal meal;
  final Color color;
  final bool showHero;

  const _MealThumbnail({required this.meal, required this.color, required this.showHero});

  @override
  Widget build(BuildContext context) {
    final size = 58.0;
    final thumb = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: meal.imageUrl != null
          ? Image.network(
              meal.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _fallback(),
            )
          : _fallback(),
    );
    final clip = ClipRRect(borderRadius: BorderRadius.circular(14), child: thumb);
    return showHero
        ? Hero(tag: 'meal-image-${meal.id}', child: clip)
        : clip;
  }

  Widget _fallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.85), color.withValues(alpha: 0.55)],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        mealTypeEmoji(meal.consumedAt),
        style: const TextStyle(fontSize: 26),
      ),
    );
  }
}