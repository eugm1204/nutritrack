import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/add_item_sheet.dart';
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
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => AddItemSheet(
        onAdd: (item) =>
            ref.read(manualAddControllerProvider.notifier).addItem(item),
      ),
    );
  }
}
