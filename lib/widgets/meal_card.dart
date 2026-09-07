import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme.dart';
import 'pressable_card.dart';

class MealCard extends StatelessWidget {
  final dynamic meal;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final void Function(DateTime date)? onDuplicate;
  final bool showHero;

  const MealCard({
    super.key,
    required this.meal,
    required this.onTap,
    required this.onDelete,
    this.onDuplicate,
    this.showHero = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PressableCard(
      onTap: onTap,
      onLongPress: onDuplicate != null
          ? () => _showActions(context)
          : () => _confirmDelete(context),
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
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${meal.itemCount} ${meal.itemCount == 1 ? 'item' : 'itens'} · '
                  '${DateFormat('HH:mm', 'pt_PT').format(meal.consumedAt)}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: theme.colorScheme.onSurfaceVariant,
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
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: theme.colorScheme.onSurface,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                'kcal',
                style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showActions(BuildContext context) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(meal.mealName),
        children: [
          ListTile(
            leading: const Icon(Icons.copy_outlined),
            title: const Text('Duplicar para outro dia'),
            onTap: () => Navigator.pop(context, 'duplicate'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: appRed),
            title: Text(
              'Apagar',
              style: TextStyle(color: appRed),
            ),
            onTap: () => Navigator.pop(context, 'delete'),
          ),
        ],
      ),
    );
    if (action == 'delete' && context.mounted) {
      await _confirmDelete(context);
    } else if (action == 'duplicate' && context.mounted) {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: now.subtract(const Duration(days: 365)),
        lastDate: now,
        helpText: 'Duplicar para',
        cancelText: 'Cancelar',
        confirmText: 'Duplicar',
      );
      if (picked != null) {
        onDuplicate!(picked);
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Apagar refeição'),
        content: Text('Tens a certeza que queres apagar esta refeição?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Apagar'),
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
              errorBuilder: (_, _, _) => _placeholder(context),
            )
          : _placeholder(context),
    );
    final clip = ClipRRect(borderRadius: BorderRadius.circular(12), child: image);
    return showHero
        ? Hero(tag: 'meal-image-${meal.id}', child: clip)
        : clip;
  }

Widget _placeholder(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(Icons.restaurant, size: 22, color: theme.colorScheme.onSurfaceVariant),
    );
  }
}