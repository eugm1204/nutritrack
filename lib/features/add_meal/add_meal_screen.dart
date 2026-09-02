import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../widgets/portion_control.dart';
import 'add_meal_controller.dart';
import 'editable_item_tile.dart';

class AddMealScreen extends ConsumerStatefulWidget {
  const AddMealScreen({super.key});

  @override
  ConsumerState<AddMealScreen> createState() => _AddMealScreenState();
}

class _AddMealScreenState extends ConsumerState<AddMealScreen> {
  final _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (file == null) return;
      ref.read(addMealControllerProvider.notifier).analyzeImage(file);
    } catch (e) {
      debugPrint('[pickImage] Erro: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao abrir cÃ¢mara/galeria: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addMealControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Adicionar refeiÃ§Ã£o')),
      body: switch (state.step) {
        AddMealStep.pick => _PickView(
            onCamera: () => _pickImage(ImageSource.camera),
            onGallery: () => _pickImage(ImageSource.gallery),
            error: state.error,
          ),
        AddMealStep.analyzing => const _AnalyzingView(),
        AddMealStep.confirm || AddMealStep.saving => _ConfirmView(
            saving: state.step == AddMealStep.saving,
          ),
      },
    );
  }
}

class _PickView extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final String? error;

  const _PickView({required this.onCamera, required this.onGallery, this.error});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'Tira uma foto ao teu prato\ne deixa a IA estimar as calorias.',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (error != null) ...[
            const SizedBox(height: 16),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => context.push('/manual-add'),
              icon: const Icon(Icons.edit_note),
              label: const Text('Adicionar manualmente'),
            ),
          ],
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: onCamera,
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Tirar foto'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onGallery,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Escolher da galeria'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => context.push('/manual-add'),
            icon: const Icon(Icons.edit_note),
            label: const Text('Adicionar sem foto (banco de alimentos)'),
          ),
        ],
      ),
    );
  }
}

class _AnalyzingView extends StatelessWidget {
  const _AnalyzingView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(
            'A analisar a foto com IA...',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Isto pode demorar alguns segundos',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmView extends ConsumerStatefulWidget {
  final bool saving;

  const _ConfirmView({required this.saving});

  @override
  ConsumerState<_ConfirmView> createState() => _ConfirmViewState();
}

class _ConfirmViewState extends ConsumerState<_ConfirmView> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: ref.read(addMealControllerProvider).mealName,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addMealControllerProvider);
    final theme = Theme.of(context);
    final controller = ref.read(addMealControllerProvider.notifier);

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(
                state.previewBytes!,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  height: 220,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.image_outlined, size: 48),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              onChanged: controller.updateMealName,
              decoration: const InputDecoration(
                labelText: 'Nome da refeiÃ§Ã£o',
                prefixIcon: Icon(Icons.label_outline),
              ),
            ),
            const SizedBox(height: 16),
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
                    if (i < state.baseItems.length)
                      PortionControl(
                        item: state.items[i],
                        base: state.baseItems[i],
                        onPortionChanged: (mult) =>
                            controller.setPortion(i, mult),
                      ),
                    if (state.items[i].protein != null ||
                        state.items[i].carbs != null ||
                        state.items[i].fat != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 16, top: 2),
                        child: Row(
                          children: [
                            Text(
                              'P ${(state.items[i].protein ?? 0).toStringAsFixed(0)}g · '
                              'H ${(state.items[i].carbs ?? 0).toStringAsFixed(0)}g · '
                              'G ${(state.items[i].fat ?? 0).toStringAsFixed(0)}g',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if ((state.items[i].confidence ?? 1) < 0.6) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.warning_amber_rounded,
                                  size: 14, color: theme.colorScheme.tertiary),
                              const SizedBox(width: 2),
                              Text(
                                'confirma',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.tertiary,
                                ),
                              ),
                            ],
                          ],
                        ),
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
            onPressed: widget.saving
                ? null
                : () async {
                    final ok = await controller.saveMeal();
                    if (ok && context.mounted) {
                      controller.reset();
                      Navigator.of(context).pop();
                    }
                  },
            icon: widget.saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(widget.saving ? 'A guardar...' : 'Guardar refeiÃ§Ã£o'),
          ),
        ),
      ],
    );
  }
}
