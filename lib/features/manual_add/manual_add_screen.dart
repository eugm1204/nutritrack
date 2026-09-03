import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/custom_food.dart';
import '../../models/meal_item.dart';
import '../../providers/providers.dart';
import '../../services/food_search_service.dart';
import '../../widgets/portion_control.dart';
import '../add_meal/editable_item_tile.dart';
import 'manual_add_controller.dart';

class ManualAddScreen extends ConsumerStatefulWidget {
  const ManualAddScreen({super.key});

  @override
  ConsumerState<ManualAddScreen> createState() => _ManualAddScreenState();
}

class _ManualAddScreenState extends ConsumerState<ManualAddScreen> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: ref.read(manualAddControllerProvider).mealName,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ok = await ref.read(manualAddControllerProvider.notifier).save();
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(manualAddControllerProvider);
    final theme = Theme.of(context);
    final controller = ref.read(manualAddControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Adicionar sem foto')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              TextField(
                controller: _nameController,
                onChanged: controller.updateMealName,
                decoration: const InputDecoration(
                  labelText: 'Nome da refeição',
                  prefixIcon: Icon(Icons.label_outline),
                ),
              ),
              const SizedBox(height: 16),
              if (state.items.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(Icons.restaurant_menu,
                            size: 42, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(height: 10),
                        Text(
                          'Ainda não tens alimentos nesta refeição.\nToca em "Adicionar alimento" para procurar ou registar.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                for (var i = 0; i < state.items.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        EditableItemTile(
                          item: state.items[i],
                          onChanged: (name, calories) =>
                              controller.updateItem(i, name, calories),
                          onRemove: () => controller.removeItem(i),
                        ),
                        if (i < state.baseItems.length &&
                            (state.baseItems[i].grams != null ||
                                state.baseItems[i].calories > 0))
                          PortionControl(
                            item: state.items[i],
                            base: state.baseItems[i],
                            onPortionChanged: (mult) =>
                                controller.setPortion(i, mult),
                          ),
                      ],
                    ),
                  ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  title: Text(
                    'Total',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  trailing: Text(
                    '${state.totalCalories} kcal',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              if (state.error != null) ...[
                const SizedBox(height: 8),
                Text(
                  state.error!,
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
            child: FilledButton.icon(
              onPressed: state.saving ? null : _save,
              icon: state.saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(state.saving ? 'A guardar...' : 'Guardar refeição'),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddItemSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Adicionar alimento'),
      ),
    );
  }

  void _openAddItemSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _AddItemSheet(),
    );
  }
}

class _AddItemSheet extends ConsumerStatefulWidget {
  const _AddItemSheet();

  @override
  ConsumerState<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends ConsumerState<_AddItemSheet> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  bool _searching = false;
  List<FoodProduct> _results = [];
  List<MealItem> _recents = [];
  List<CustomFood> _customFoods = [];
  String? _error;

  final _manualNameController = TextEditingController();
  final _manualCaloriesController = TextEditingController();
  bool _showManual = false;

  @override
  void initState() {
    super.initState();
    _loadRecents();
    _loadCustomFoods();
  }

  Future<void> _loadRecents() async {
    final recents = await ref.read(recentFoodsServiceProvider).load();
    if (!mounted) return;
    setState(() => _recents = recents);
  }

  Future<void> _loadCustomFoods() async {
    final user = ref.read(supabaseProvider).auth.currentUser;
    if (user == null) return;
    try {
      final foods = await ref.read(customFoodsRepositoryProvider).fetch(user.id);
      if (!mounted) return;
      setState(() => _customFoods = foods);
    } catch (e) {
      debugPrint('[customFoods/load] Erro: $e');
    }
  }

  Future<void> _openCreateFoodDialog() async {
    final saved = await showDialog<CustomFood>(
      context: context,
      builder: (context) => const _CreateFoodDialog(),
    );
    if (saved == null) return;
    final user = ref.read(supabaseProvider).auth.currentUser;
    if (user == null) return;
    try {
      await ref.read(customFoodsRepositoryProvider).add(user.id, saved);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${saved.name} criado! 🎉')),
        );
      }
      await _loadCustomFoods();
    } catch (e) {
      debugPrint('[customFoods/add] Erro: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível criar o alimento.')),
        );
      }
    }
  }

  Future<void> _deleteCustomFood(CustomFood food) async {
    final user = ref.read(supabaseProvider).auth.currentUser;
    if (user == null || food.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar alimento'),
        content: Text('Apagar "${food.name}" da tua lista?'),
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
    await ref.read(customFoodsRepositoryProvider).delete(food.id!, user.id);
    await _loadCustomFoods();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _manualNameController.dispose();
    _manualCaloriesController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await ref.read(foodSearchServiceProvider).search(query.trim());
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = 'Não foi possível pesquisar. Tenta novamente.';
      });
    }
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(value));
  }

  void _addProduct(FoodProduct product) {
    ref.read(manualAddControllerProvider.notifier).addItem(MealItem(
          name: product.name,
          calories: product.kcalPer100g?.round() ?? 0,
          grams: product.kcalPer100g != null ? product.referenceGrams : null,
          confirmed: true,
        ));
    Navigator.of(context).pop();
  }

  void _addCustomFood(CustomFood food) {
    ref.read(manualAddControllerProvider.notifier).addItem(MealItem(
          name: food.name,
          calories: food.kcalPer100g,
          protein: food.protein,
          carbs: food.carbs,
          fat: food.fat,
          grams: food.referenceGrams,
          confirmed: true,
        ));
    Navigator.of(context).pop();
  }

  void _addManual() {
    final name = _manualNameController.text.trim();
    final calories = int.tryParse(_manualCaloriesController.text.trim());
    if (name.isEmpty || calories == null || calories <= 0) return;
    ref.read(manualAddControllerProvider.notifier).addItem(
          MealItem(name: name, calories: calories, confirmed: true),
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            onChanged: _onQueryChanged,
            decoration: const InputDecoration(
              labelText: 'Pesquisar alimento',
              prefixIcon: Icon(Icons.search),
              hintText: 'ex: arroz, frango, batata...',
            ),
          ),
          if (_searchController.text.trim().isEmpty && _recents.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Recentes',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _recents.length,
                itemBuilder: (context, index) {
                  final item = _recents[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.history, size: 18),
                    title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      item.grams != null
                          ? '${item.calories} kcal · ${item.grams!.round()} g'
                          : '${item.calories} kcal',
                    ),
                    trailing: const Icon(Icons.add_circle_outline),
                    onTap: () {
                      ref.read(manualAddControllerProvider.notifier).addItem(item);
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
          ],
          if (_customFoods.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Os teus alimentos ⭐',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _customFoods.length,
                itemBuilder: (context, index) {
                  final food = _customFoods[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.star, size: 18, color: macroCarbsColor),
                    title: Text(food.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${food.kcalPer100g} kcal/100g · porção ${food.referenceGrams.round()} g'
                      '${food.brand != null ? ' · ${food.brand}' : ''}',
                    ),
                    trailing: const Icon(Icons.add_circle_outline),
                    onTap: () => _addCustomFood(food),
                    onLongPress: () => _deleteCustomFood(food),
                  );
                },
              ),
            ),
          ],
          if (_searching) ...[
            const SizedBox(height: 12),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Resultados (valores por 100 g)',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final product = _results[index];
                  final kcal = product.kcalPer100g;
                  return ListTile(
                    dense: true,
                    title: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      kcal != null
                          ? '${kcal.round()} kcal/100g · porção ${product.referenceGrams.round()} g'
                          : 'Sem dados de calorias',
                    ),
                    trailing: const Icon(Icons.add_circle_outline),
                    onTap: kcal != null ? () => _addProduct(product) : null,
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _openCreateFoodDialog,
            icon: const Icon(Icons.add_box_outlined),
            label: const Text('Criar o meu alimento'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => setState(() => _showManual = !_showManual),
            icon: const Icon(Icons.edit_note),
            label: Text(_showManual ? 'Ocultar registo manual' : 'Registar manualmente'),
          ),
          if (_showManual) ...[
            TextField(
              controller: _manualNameController,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Nome do alimento',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _manualCaloriesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Calorias (kcal)',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: _addManual,
              child: const Text('Adicionar'),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _CreateFoodDialog extends StatefulWidget {
  const _CreateFoodDialog();

  @override
  State<_CreateFoodDialog> createState() => _CreateFoodDialogState();
}

class _CreateFoodDialogState extends State<_CreateFoodDialog> {
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _kcalController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _gramsController = TextEditingController(text: '100');

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _kcalController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _gramsController.dispose();
    super.dispose();
  }

  CustomFood? _build() {
    final name = _nameController.text.trim();
    final kcal = int.tryParse(_kcalController.text.trim());
    final grams = double.tryParse(_gramsController.text.trim()) ?? 100;
    if (name.isEmpty || kcal == null || kcal <= 0 || grams <= 0) return null;

    return CustomFood(
      name: name,
      brand: _brandController.text.trim().isEmpty
          ? null
          : _brandController.text.trim(),
      kcalPer100g: kcal,
      protein: double.tryParse(_proteinController.text.trim()),
      carbs: double.tryParse(_carbsController.text.trim()),
      fat: double.tryParse(_fatController.text.trim()),
      referenceGrams: grams,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Criar alimento 🍎'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nome *',
                prefixIcon: Icon(Icons.fastfood_outlined),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _brandController,
              decoration: const InputDecoration(
                labelText: 'Marca (opcional)',
                prefixIcon: Icon(Icons.storefront_outlined),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _kcalController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Calorias por 100 g *',
                prefixIcon: Icon(Icons.local_fire_department_outlined),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _proteinController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Proteína',
                      prefixIcon: Icon(Icons.circle, size: 12, color: macroProteinColor),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _carbsController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Hidratos',
                      prefixIcon: Icon(Icons.circle, size: 12, color: macroCarbsColor),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _fatController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Gordura',
                      prefixIcon: Icon(Icons.circle, size: 12, color: macroFatColor),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _gramsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Porção de referência (g)',
                prefixIcon: Icon(Icons.straighten),
                helperText: 'Ex: 1 iogurte = 125 g',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Valores por 100 g. A porção de referência é a quantidade habitual '
              '(ex: 1 iogurte, 1 fatia, 1 copo).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final food = _build();
            if (food == null) return;
            Navigator.pop(context, food);
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}