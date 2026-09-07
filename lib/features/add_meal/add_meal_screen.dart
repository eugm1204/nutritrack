import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

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
        title: Text('Adicionar refeição'),
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.restaurant, size: 52, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            'Tira uma foto ao teu prato',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'A IA estima as calorias, macros e porções.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurfaceVariant),
          ),
          if (error != null) ...[
            const SizedBox(height: 16),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: appRed),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => context.push('/manual-add'),
              child: Text('Adicionar manualmente'),
            ),
          ],
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: onCamera,
            icon: Icon(Icons.photo_camera_outlined, size: 20),
            label: Text('Tirar foto'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onGallery,
            icon: Icon(Icons.photo_library_outlined, size: 20),
            label: Text('Escolher da galeria'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.push('/manual-add'),
            child: Text('Adicionar sem foto'),
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
          CircularProgressIndicator(strokeWidth: 3),
          SizedBox(height: 20),
          Text(
            'A analisar a tua foto...',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
          ),
          SizedBox(height: 6),
          Text(
            'Isto pode demorar alguns segundos',
            style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
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
    final theme = Theme.of(context);
    final state = ref.watch(addMealControllerProvider);
    final controller = ref.read(addMealControllerProvider.notifier);

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  Image.memory(
                    state.previewBytes!,
                    height: 240,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      height: 240,
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(Icons.image_outlined, size: 48, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: _PhotoOverlayChip(state: state),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _nameController,
              onChanged: controller.updateMealName,
              style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurface),
              decoration: const InputDecoration(
                labelText: 'Nome da refeição',
                prefixIcon: Icon(Icons.label_outline, size: 18),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hoje · ${DateFormat('HH:mm', 'pt_PT').format(DateTime.now())}',
              style: TextStyle(fontSize: 12.5, color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                CountUpText(
                  target: state.totalCalories,
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'kcal estimadas',
                  style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _MacroSummary(state: state),
            const SizedBox(height: 18),
            Text(
              'Alimentos',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
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
                              Icon(Icons.circle, size: 6, color: appOrange),
                              const SizedBox(width: 4),
                              Text(
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
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Resumo',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Detetados ${state.items.length} '
                        '${state.items.length == 1 ? 'item' : 'itens'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Divider(color: theme.colorScheme.outlineVariant, height: 1),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '${state.totalCalories} kcal',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Estimativa por IA — podes corrigir qualquer valor.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
            ),
            if (state.error != null) ...[
              const SizedBox(height: 8),
              Text(
                state.error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: appRed),
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
                : Icon(Icons.check, size: 20),
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
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
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
              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
class _PhotoOverlayChip extends StatelessWidget {
  final dynamic state;

  const _PhotoOverlayChip({required this.state});

  @override
Widget build(BuildContext context) {
    double sum(double? Function(dynamic item) extract) => state.items.fold<double>(
        0, (a, item) => a + (extract(item) ?? 0));
    final protein = sum((item) => item.protein);
    final carbs = sum((item) => item.carbs);
    final fat = sum((item) => item.fat);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            ' kcal',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 10),
          _macro(protein, macroProteinColor),
          const SizedBox(width: 6),
          _macro(carbs, macroCarbsColor),
          const SizedBox(width: 6),
          _macro(fat, macroFatColor),
        ],
      ),
    );
  }

  Widget _macro(double value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(
          'g',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
