import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../models/meal.dart';
import '../../models/meal_item.dart';
import '../../providers/providers.dart';
import '../../services/favorites_service.dart';
import '../../widgets/portion_control.dart';
import '../add_meal/editable_item_tile.dart';
import '../dashboard/dashboard_controller.dart';

class MealDetailScreen extends ConsumerStatefulWidget {
  final Meal meal;

  const MealDetailScreen({super.key, required this.meal});

  @override
  ConsumerState<MealDetailScreen> createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends ConsumerState<MealDetailScreen> {
  late final TextEditingController _nameController;
  late List<MealItem> _items;
  late List<MealItem> _baseItems;
  bool _saving = false;
  bool _repeating = false;
  bool _isFavorite = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.meal.mealName);
    _items = [...widget.meal.items];
    _baseItems = [...widget.meal.items];
    _loadFavoriteStatus();
  }

  Future<void> _loadFavoriteStatus() async {
    final isFav = await ref.read(favoritesServiceProvider).isFavorite(widget.meal.mealName);
    if (mounted) setState(() => _isFavorite = isFav);
  }

  Future<void> _toggleFavorite() async {
    final favorites = await ref.read(favoritesServiceProvider).toggle(FavoriteMeal(
          name: _nameController.text.trim().isEmpty
              ? widget.meal.mealName
              : _nameController.text.trim(),
          imageUrl: widget.meal.imageUrl,
          items: _items,
        ));
    final isFav = favorites.any((f) =>
        f.name == (_nameController.text.trim().isEmpty
            ? widget.meal.mealName
            : _nameController.text.trim()));
    setState(() => _isFavorite = isFav);
    ref.read(dashboardControllerProvider.notifier).refreshFavorites();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isFav ? 'Adicionada às favoritas ⭐' : 'Removida das favoritas'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  int get _total => _items.fold(0, (sum, item) => sum + item.calories);

  double get _totalProtein => _items.fold(0, (sum, item) => sum + (item.protein ?? 0));
  double get _totalCarbs => _items.fold(0, (sum, item) => sum + (item.carbs ?? 0));
  double get _totalFat => _items.fold(0, (sum, item) => sum + (item.fat ?? 0));

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final userId = ref.read(supabaseProvider).auth.currentUser!.id;
      await ref.read(mealRepositoryProvider).updateMeal(
            mealId: widget.meal.id,
            userId: userId,
            mealName: _nameController.text.trim().isEmpty
                ? 'Refeição'
                : _nameController.text.trim(),
            items: _items,
          );
      ref.invalidate(dashboardControllerProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'Não foi possível guardar. Tenta novamente.';
      });
    }
  }

  Future<void> _repeat() async {
    setState(() {
      _repeating = true;
      _error = null;
    });
    try {
      final userId = ref.read(supabaseProvider).auth.currentUser!.id;
      await ref.read(mealRepositoryProvider).insertMeal(
            userId: userId,
            imageUrl: widget.meal.imageUrl,
            mealName: _nameController.text.trim().isEmpty
                ? widget.meal.mealName
                : _nameController.text.trim(),
            items: _items,
            consumedAt: DateTime.now(),
          );
      ref.invalidate(dashboardControllerProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Refeição repetida hoje!')),
        );
      }
    } catch (e) {
      setState(() {
        _repeating = false;
        _error = 'Não foi possível repetir. Tenta novamente.';
      });
    }
  }

  Future<void> _delete() async {
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
    if (ok != true) return;
    final userId = ref.read(supabaseProvider).auth.currentUser!.id;
    await ref.read(mealRepositoryProvider).deleteMeal(widget.meal.id, userId);
    ref.invalidate(dashboardControllerProvider);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes da refeição'),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.star : Icons.star_border,
              color: _isFavorite ? macroCarbsColor : null,
            ),
            tooltip: _isFavorite ? 'Remover das favoritas' : 'Adicionar às favoritas',
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
            children: [
              if (widget.meal.imageUrl != null) ...[
                Hero(
                  tag: 'meal-image-${widget.meal.id}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      widget.meal.imageUrl!,
                      height: 180,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        height: 180,
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.image_outlined, size: 48),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                DateFormat('EEEE, d MMM · HH:mm').format(widget.meal.consumedAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome da refeição',
                  prefixIcon: Icon(Icons.label_outline),
                ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < _items.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EditableItemTile(
                        item: _items[i],
                        onChanged: (name, calories) => setState(() {
                          _items[i] = _items[i].copyWith(
                            name: name,
                            calories: calories,
                            confirmed: true,
                          );
                          _baseItems[i] = _items[i];
                        }),
                        onRemove: () => setState(() {
                          _items.removeAt(i);
                          _baseItems.removeAt(i);
                        }),
                      ),
                      if (i < _baseItems.length)
                        PortionControl(
                          item: _items[i],
                          base: _baseItems[i],
                          onPortionChanged: (mult) => setState(() {
                            _items[i] = _baseItems[i].scaledBy(mult);
                          }),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '$_total kcal',
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _MacroRow(
                        protein: _totalProtein,
                        carbs: _totalCarbs,
                        fat: _totalFat,
                      ),
                    ],
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: (_saving || _repeating) ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(_saving ? 'A guardar...' : 'Guardar'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: (_saving || _repeating) ? null : _repeat,
                  tooltip: 'Repetir hoje',
                  icon: _repeating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.copy_outlined),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: (_saving || _repeating) ? null : _delete,
                  tooltip: 'Apagar',
                  style: IconButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  final double protein;
  final double carbs;
  final double fat;

  const _MacroRow({required this.protein, required this.carbs, required this.fat});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        Text(
          'Proteína ${protein.toStringAsFixed(0)}g',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: macroProteinColor,
          ),
        ),
        Text(
          'Hidratos ${carbs.toStringAsFixed(0)}g',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: macroCarbsColor,
          ),
        ),
        Text(
          'Gordura ${fat.toStringAsFixed(0)}g',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: macroFatColor,
          ),
        ),
      ],
    );
  }
}