import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/meal_item.dart';
import '../../providers/providers.dart';
import '../../services/food_search_service.dart';
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
                    child: EditableItemTile(
                      item: state.items[i],
                      onChanged: (name, calories) =>
                          controller.updateItem(i, name, calories),
                      onRemove: () => controller.removeItem(i),
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
  String? _error;

  final _manualNameController = TextEditingController();
  final _manualCaloriesController = TextEditingController();
  bool _showManual = false;

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
      final results =
          await ref.read(foodSearchServiceProvider).search(query.trim());
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
          grams: product.kcalPer100g != null ? 100 : null,
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
                    subtitle: kcal != null
                        ? Text('${kcal.round()} kcal / 100g')
                        : Text('Sem dados de calorias'),
                    trailing: const Icon(Icons.add_circle_outline),
                    onTap: kcal != null ? () => _addProduct(product) : null,
                  );
                },
              ),
            ),
          ],
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