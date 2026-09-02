import 'package:flutter/material.dart';

import '../../models/meal_item.dart';

class EditableItemTile extends StatefulWidget {
  final MealItem item;
  final void Function(String name, int calories) onChanged;
  final VoidCallback onRemove;

  const EditableItemTile({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<EditableItemTile> createState() => _EditableItemTileState();
}

class _EditableItemTileState extends State<EditableItemTile> {
  late final TextEditingController _nameController;
  late final TextEditingController _caloriesController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    _caloriesController = TextEditingController(text: '${widget.item.calories}');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(
      _nameController.text.trim(),
      int.tryParse(_caloriesController.text) ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _nameController,
                onChanged: (_) => _emit(),
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Alimento',
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 110,
              child: TextField(
                controller: _caloriesController,
                keyboardType: TextInputType.number,
                onChanged: (_) => _emit(),
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'kcal',
                ),
              ),
            ),
            IconButton(
              onPressed: widget.onRemove,
              icon: const Icon(Icons.delete_outline),
              color: theme.colorScheme.error,
            ),
          ],
        ),
      ),
    );
  }
}