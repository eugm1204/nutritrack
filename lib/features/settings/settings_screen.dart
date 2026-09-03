import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../models/profile.dart';
import '../../providers/providers.dart';
import '../dashboard/dashboard_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _goalController;
  late final TextEditingController _weightController;
  late final TextEditingController _nameController;
  late final TextEditingController _heightController;
  late final TextEditingController _targetWeightController;
  late final TextEditingController _proteinGoalController;
  late final TextEditingController _carbsGoalController;
  late final TextEditingController _fatGoalController;
  DateTime? _birthDate;
  String? _sex;
  String _objective = 'maintain';
  String? _activityLevel;
  String? _avatarUrl;
  bool _saving = false;
  bool _uploadingAvatar = false;
  String? _error;
  bool _populated = false;

  @override
  void initState() {
    super.initState();
    _goalController = TextEditingController();
    _weightController = TextEditingController();
    _nameController = TextEditingController();
    _heightController = TextEditingController();
    _targetWeightController = TextEditingController();
    _proteinGoalController = TextEditingController();
    _carbsGoalController = TextEditingController();
    _fatGoalController = TextEditingController();
  }

  @override
  void dispose() {
    _goalController.dispose();
    _weightController.dispose();
    _nameController.dispose();
    _heightController.dispose();
    _targetWeightController.dispose();
    _proteinGoalController.dispose();
    _carbsGoalController.dispose();
    _fatGoalController.dispose();
    super.dispose();
  }

  void _populate(Profile profile) {
    if (_populated) return;
    _populated = true;
    _goalController.text = '${profile.dailyGoalCalories}';
    _weightController.text = profile.weightKg?.toString() ?? '';
    _nameController.text = profile.name ?? '';
    _heightController.text = profile.heightCm?.toString() ?? '';
    _targetWeightController.text = profile.targetWeightKg?.toString() ?? '';
    _proteinGoalController.text = profile.proteinGoalG?.toString() ?? '';
    _carbsGoalController.text = profile.carbsGoalG?.toString() ?? '';
    _fatGoalController.text = profile.fatGoalG?.toString() ?? '';
    _birthDate = profile.birthDate;
    _sex = profile.sex;
    _objective = profile.objective;
    _activityLevel = profile.activityLevel;
    _avatarUrl = profile.avatarUrl;
  }

  Future<void> _changeAvatar() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (file == null) return;

    setState(() {
      _uploadingAvatar = true;
      _error = null;
    });
    try {
      final userId = ref.read(supabaseProvider).auth.currentUser!.id;
      final current = ref.read(profileProvider).value ??
          const Profile(id: '');
      final url = await ref.read(profileRepositoryProvider).uploadAvatar(file, userId);
      await ref.read(profileRepositoryProvider).update(
            userId,
            current.copyWith(avatarUrl: url, onboardingCompleted: true),
          );
      ref.invalidate(profileProvider);
      ref.invalidate(dashboardControllerProvider);
      if (!mounted) return;
      setState(() => _avatarUrl = url);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de perfil atualizada! 📸')),
      );
    } catch (e) {
      debugPrint('[avatar] Erro: $e');
      if (mounted) {
        setState(() => _error = 'Não foi possível atualizar a foto.');
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  void _suggestMacros() {
    final goal = int.tryParse(_goalController.text.trim());
    if (goal == null || goal <= 0) return;
    setState(() {
      _proteinGoalController.text = '${(goal * 0.25 / 4).round()}';
      _carbsGoalController.text = '${(goal * 0.45 / 4).round()}';
      _fatGoalController.text = '${(goal * 0.30 / 9).round()}';
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final userId = ref.read(supabaseProvider).auth.currentUser!.id;
      final goal = int.tryParse(_goalController.text.trim());
      final weight = double.tryParse(_weightController.text.trim());

      if (goal == null || goal <= 0) {
        setState(() {
          _error = 'Indica uma meta de calorias válida.';
          _saving = false;
        });
        return;
      }

      await ref.read(profileRepositoryProvider).update(
            userId,
            Profile(
              id: userId,
              dailyGoalCalories: goal,
              weightKg: weight,
              objective: _objective,
              name: _nameController.text.trim().isEmpty
                  ? null
                  : _nameController.text.trim(),
              birthDate: _birthDate,
              sex: _sex,
              heightCm: double.tryParse(_heightController.text.trim()),
              activityLevel: _activityLevel,
              targetWeightKg:
                  double.tryParse(_targetWeightController.text.trim()),
              proteinGoalG: int.tryParse(_proteinGoalController.text.trim()),
              carbsGoalG: int.tryParse(_carbsGoalController.text.trim()),
              fatGoalG: int.tryParse(_fatGoalController.text.trim()),
              onboardingCompleted: true,
            ),
          );
      ref.invalidate(profileProvider);
      ref.invalidate(dashboardControllerProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      debugPrint('[settings/save] Erro: $e');
      setState(() {
        _error = 'Não foi possível guardar. Tenta novamente.';
        _saving = false;
      });
    }
  }

  Future<void> _exportCsv() async {
    try {
      final userId = ref.read(supabaseProvider).auth.currentUser!.id;
      final meals = await ref.read(mealRepositoryProvider).fetchAllMeals(userId);

      final buffer = StringBuffer();
      buffer.writeln('data,refeicao,alimento,calorias,proteina,hidratos,gordura');
      for (final meal in meals) {
        final date = DateFormat('yyyy-MM-dd HH:mm').format(meal.consumedAt);
        for (final item in meal.items) {
          buffer.writeln(
            '"$date","${meal.mealName}","${item.name}",${item.calories},'
            '${item.protein ?? ''},${item.carbs ?? ''},${item.fat ?? ''}',
          );
        }
        if (meal.items.isEmpty) {
          buffer.writeln('"$date","${meal.mealName}","",${meal.totalCalories},,,');
        }
      }

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Exportar dados (CSV)'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${meals.length} refeições · '
                    '${buffer.toString().split('\n').length - 1} linhas'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: buffer.toString()),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('CSV copiado para a área de transferência')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copiar CSV'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('[exportCsv] Erro: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível exportar os dados.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Definições')),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (data) {
          _populate(data);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.surfaceContainerHighest,
                        border: Border.all(
                          color: theme.colorScheme.primary,
                          width: 3,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      alignment: Alignment.center,
                      child: _avatarUrl != null
                          ? Image.network(
                              _avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const Icon(Icons.person, size: 44),
                            )
                          : const Icon(Icons.person, size: 44),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _uploadingAvatar ? null : _changeAvatar,
                      icon: _uploadingAvatar
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.photo_camera_outlined),
                      label: Text(_uploadingAvatar
                          ? 'A enviar...'
                          : _avatarUrl != null
                              ? 'Alterar foto'
                              : 'Adicionar foto'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('Perfil', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cake_outlined),
                title: Text(
                  _birthDate == null
                      ? 'Data de nascimento'
                      : DateFormat('d MMM yyyy').format(_birthDate!),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _birthDate ?? DateTime(2000),
                    firstDate: DateTime(1920),
                    lastDate: DateTime.now(),
                    helpText: 'Data de nascimento',
                    cancelText: 'Cancelar',
                    confirmText: 'OK',
                  );
                  if (picked != null) setState(() => _birthDate = picked);
                },
              ),
              const SizedBox(height: 4),
              SegmentedButton<String?>(
                segments: const [
                  ButtonSegment(value: 'male', label: Text('Homem')),
                  ButtonSegment(value: 'female', label: Text('Mulher')),
                  ButtonSegment(value: null, label: Text('Prefiro não dizer')),
                ],
                selected: {_sex},
                onSelectionChanged: (selection) =>
                    setState(() => _sex = selection.first),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _heightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Altura (cm)',
                        prefixIcon: Icon(Icons.height),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Peso (kg)',
                        prefixIcon: Icon(Icons.monitor_weight_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _targetWeightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Peso alvo (kg) — opcional',
                  prefixIcon: Icon(Icons.flag_outlined),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _objective,
                decoration: const InputDecoration(
                  labelText: 'Objetivo',
                  prefixIcon: Icon(Icons.flag_outlined),
                ),
                items: [
                  for (final entry in objectiveLabels.entries)
                    DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                ],
                onChanged: (value) => setState(() => _objective = value ?? 'maintain'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _activityLevel,
                decoration: const InputDecoration(
                  labelText: 'Atividade física',
                  prefixIcon: Icon(Icons.directions_run),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Não definido'),
                  ),
                  for (final entry in activityLabels.entries)
                    DropdownMenuItem<String?>(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: (value) => setState(() => _activityLevel = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _goalController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Meta diária de calorias (kcal)',
                  prefixIcon: Icon(Icons.local_fire_department_outlined),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Metas de macros (g)',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  TextButton.icon(
                    onPressed: _suggestMacros,
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('Sugerir'),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _proteinGoalController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Proteína',
                        prefixIcon: Icon(
                          Icons.circle,
                          size: 12,
                          color: macroProteinColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _carbsGoalController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Hidratos',
                        prefixIcon: Icon(
                          Icons.circle,
                          size: 12,
                          color: macroCarbsColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _fatGoalController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Gordura',
                        prefixIcon: Icon(
                          Icons.circle,
                          size: 12,
                          color: macroFatColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Deixa vazio para não definires. "Sugerir" calcula a partir da meta de calorias (25/45/30%).',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'A guardar...' : 'Guardar'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _exportCsv,
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('Exportar dados (CSV)'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              ),
            ],
          );
        },
      ),
    );
  }
}