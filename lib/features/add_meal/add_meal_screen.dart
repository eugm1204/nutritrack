import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';
import '../../widgets/count_up_text.dart';
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
          SnackBar(content: Text('Erro ao abrir câmara/galeria: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addMealControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Adicionar refeição'),
        automaticallyImplyLeading: state.step != AddMealStep.pick,
      ),
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.restaurant, size: 52, color: appTextSecondary),
          const SizedBox(height: 16),
          const Text(
            'Tira uma foto ao teu prato',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: appTextPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'A IA estima as calorias, macros e porções.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: appTextSecondary),
          ),
          if (error != null) ...[
            const SizedBox(height: 16),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: appRed),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => context.push('/manual-add'),
              child: const Text('Adicionar manualmente'),
            ),
          ],
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: onCamera,
            icon: const Icon(Icons.photo_camera_outlined, size: 20),
            label: const Text('Tirar foto'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onGallery,
            icon: const Icon(Icons.photo_library_outlined, size: 20),
            label: const Text('Escolher da galeria'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.push('/manual-add'),
            child: const Text('Adicionar sem foto'),
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
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(strokeWidth: 3),
          SizedBox(height: 20),
          Text(
            'A analisar a tua foto...',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: appTextPrimary),
          ),
          SizedBox(height: 6),
          Text(
            'Isto pode demorar alguns segundos',
            style: TextStyle(fontSize: 13, color: appTextSecondary),
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
    final controller = ref.read(addMealControllerProvider.notifier);

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.memory(
                state.previewBytes!,
                height: 240,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  height: 240,
                  color: appFill,
                  child: const Icon(Icons.image_outlined, size: 48, color: appTextSecondary),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              onChanged: controller.updateMealName,
              style: const TextStyle(fontSize: 15, color: appTextPrimary),
              decoration: const InputDecoration(
                labelText: 'Nome da refeição',
                prefixIcon: Icon(Icons.label_outline, size: 18),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                CountUpText(
                  target: state.totalCalories,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: appTextPrimary,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'kcal estimadas',
                  style: TextStyle(fontSize: 14, color: appTextSecondary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _MacroSummary(state: state),
            const SizedBox(height: 18),
            const Text(
              'Alimentos',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: appTextPrimary),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < state.items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
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
                      Padding(
                        padding: const EdgeInsets.only(left: 4, top: 6),
                        child: Row(
                          children: [
                            PortionControl(
                              item: state.items[i],
                              base: state.baseItems[i],
                              onPortionChanged: (mult) =>
                                  controller.setPortion(i, mult),
                            ),
                            if ((state.items[i].confidence ?? 1) < 0.6) ...[
                              const SizedBox(width: 10),
                              const Icon(Icons.circle, size: 6, color: appOrange),
                              const SizedBox(width: 4),
                              const Text(
                                'confirma a porção',
                                style: TextStyle(fontSize: 11.5, color: appOrange),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: appTextPrimary),
                ),
                Text(
                  '${state.totalCalories} kcal',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: appTextPrimary,
                  ),
                ),
              ],
            ),
            if (state.error != null) ...[
              const SizedBox(height: 8),
              Text(
                state.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13.5, color: appRed),
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
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check, size: 20),
            label: Text(widget.saving ? 'A guardar...' : 'Guardar refeição'),
          ),
        ),
      ],
    );
  }
}

class _MacroSummary extends StatelessWidget {
  final dynamic state;

  const _MacroSummary({required this.state});

  @override
  Widget build(BuildContext context) {
    double sum(double? Function(dynamic item) extract) => state.items.fold<double>(
        0, (a, item) => a + (extract(item) ?? 0));

    return Row(
      children: [
        _MacroStat(label: 'Proteína', value: sum((item) => item.protein), color: macroProteinColor),
        const SizedBox(width: 12),
        _MacroStat(label: 'Hidratos', value: sum((item) => item.carbs), color: macroCarbsColor),
        const SizedBox(width: 12),
        _MacroStat(label: 'Gordura', value: sum((item) => item.fat), color: macroFatColor),
      ],
    );
  }
}

class _MacroStat extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _MacroStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: appCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: appHairline),
        ),
        child: Column(
          children: [
            Text(
              '${value.toStringAsFixed(0)}g',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: appTextSecondary),
            ),
          ],
        ),
      ),
    );
  }
}