import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
            ],
          );
        },
      ),
    );
  }
}