import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
  String _objective = 'maintain';
  bool _saving = false;
  String? _error;
  bool _populated = false;

  @override
  void initState() {
    super.initState();
    _goalController = TextEditingController();
    _weightController = TextEditingController();
  }

  @override
  void dispose() {
    _goalController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _populate(Profile profile) {
    if (_populated) return;
    _populated = true;
    _goalController.text = '${profile.dailyGoalCalories}';
    _weightController.text = profile.weightKg?.toString() ?? '';
    _objective = profile.objective;
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
              Text('Perfil', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(
                controller: _goalController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Meta diária de calorias (kcal)',
                  prefixIcon: Icon(Icons.local_fire_department_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Peso (kg) — opcional',
                  prefixIcon: Icon(Icons.monitor_weight_outlined),
                ),
              ),
              const SizedBox(height: 16),
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