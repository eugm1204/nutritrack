import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';

import 'pressable_card.dart';

class MealCard extends StatelessWidget {
  final dynamic meal;
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
    return PressableCard(
      onTap: onTap,
      onLongPress: () => _confirmDelete(context),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          _MealThumbnail(meal: meal, showHero: showHero),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal.mealName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: appTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${meal.itemCount} ${meal.itemCount == 1 ? 'item' : 'itens'} · '
                  '${DateFormat('HH:mm', 'pt_PT').format(meal.consumedAt)}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: appTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${meal.totalCalories}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: appTextPrimary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const Text(
                'kcal',
                style: TextStyle(fontSize: 11, color: appTextSecondary),
              ),
            ],
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
  final dynamic meal;
  final bool showHero;

  const _MealThumbnail({required this.meal, required this.showHero});

  @override
  Widget build(BuildContext context) {
    final size = 64.0;
    final image = SizedBox(
      width: size,
      height: size,
      child: meal.imageUrl != null
          ? Image.network(
              meal.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _placeholder(),
            )
          : _placeholder(),
    );
    final clip = ClipRRect(borderRadius: BorderRadius.circular(12), child: image);
    return showHero
        ? Hero(tag: 'meal-image-${meal.id}', child: clip)
        : clip;
  }

  Widget _placeholder() {
    return Container(
      color: appFill,
      alignment: Alignment.center,
      child: const Icon(Icons.restaurant, size: 22, color: appTextSecondary),
    );
  }
}