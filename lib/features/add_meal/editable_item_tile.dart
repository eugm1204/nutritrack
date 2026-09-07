import 'package:flutter/material.dart';

import '../../core/theme.dart';
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: appCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: appHairline),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: _nameController,
              onChanged: (_) => _emit(),
              style: const TextStyle(fontSize: 14.5, color: appTextPrimary),
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Alimento',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: TextField(
              controller: _caloriesController,
              keyboardType: TextInputType.number,
              onChanged: (_) => _emit(),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14.5, color: appTextPrimary),
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'kcal',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
            ),
          ),
          IconButton(
            onPressed: widget.onRemove,
            icon: const Icon(Icons.close, size: 18, color: appTextSecondary),
          ),
        ],
      ),
    );
  }
}