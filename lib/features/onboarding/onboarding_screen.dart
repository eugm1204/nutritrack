import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../models/profile.dart';
import '../../providers/providers.dart';
import '../dashboard/dashboard_controller.dart';

enum OnboardingStep { name, birth, objective, body, goal }

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  OnboardingStep _step = OnboardingStep.name;

  final _nameController = TextEditingController();
  DateTime? _birthDate;
  String? _sex;
  String _objective = 'maintain';
  double? _targetWeight;

  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  String? _activityLevel;

  final _goalController = TextEditingController();
  int? _suggestedGoal;

  bool _saving = false;
  String? _error;

  static const _steps = [
    OnboardingStep.name,
    OnboardingStep.birth,
    OnboardingStep.objective,
    OnboardingStep.body,
    OnboardingStep.goal,
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  int get _stepIndex => _steps.indexOf(_step);

  bool get _canContinue {
    switch (_step) {
      case OnboardingStep.name:
        return _nameController.text.trim().isNotEmpty;
      case OnboardingStep.birth:
        return _birthDate != null && _sex != null;
      case OnboardingStep.goal:
        return (_goalController.text.isEmpty ||
                (int.tryParse(_goalController.text) ?? 0) > 0) &&
            !_saving;
      default:
        return true;
    }
  }

  void _next() {
    HapticFeedback.selectionClick();
    if (_stepIndex < _steps.length - 1) {
      setState(() => _step = _steps[_stepIndex + 1]);
      if (_step == OnboardingStep.goal) _computeSuggestion();
    } else {
      _finish();
    }
  }

  void _skip() => _next();

  void _computeSuggestion() {
    final weight = double.tryParse(_weightController.text.trim());
    final height = double.tryParse(_heightController.text.trim());
    final age = _birthDate == null
        ? null
        : DateTime.now().year - _birthDate!.year -
            (DateTime.now().isBefore(
                    DateTime(_birthDate!.year, DateTime.now().month, DateTime.now().day))
                ? 1
                : 0);

    final sexOffset = _sex == 'male' ? 5 : (_sex == 'female' ? -161 : -78);
    final factor = activityFactors[_activityLevel] ?? 1.375;

    if (weight != null && weight > 0 && height != null && height > 0 && age != null) {
      final bmr = 10 * weight + 6.25 * height - 5 * age + sexOffset;
      final adjustment = _objective == 'lose' ? -400 : (_objective == 'gain' ? 300 : 0);
      final goal = (bmr * factor + adjustment).round().clamp(1200, 4000);
      _suggestedGoal = goal;
      _goalController.text = '$goal';
    } else {
      _suggestedGoal = null;
      _goalController.text = '';
    }
  }

  Future<void> _finish() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final client = ref.read(supabaseProvider);
      final user = client.auth.currentUser;
      if (user == null) throw Exception('Sessão expirada');

      final weight = double.tryParse(_weightController.text.trim());
      final goal = int.tryParse(_goalController.text.trim());

      final profile = Profile(
        id: user.id,
        name: _nameController.text.trim(),
        birthDate: _birthDate,
        sex: _sex,
        objective: _objective,
        heightCm: double.tryParse(_heightController.text.trim()),
        activityLevel: _activityLevel,
        targetWeightKg: _targetWeight,
        weightKg: weight,
        dailyGoalCalories: goal ?? 2200,
        onboardingCompleted: true,
      );

      await ref.read(profileRepositoryProvider).update(user.id, profile);

      if (weight != null && weight > 0) {
        await ref.read(weightRepositoryProvider).addEntry(
              userId: user.id,
              weightKg: weight,
              recordedAt: DateTime.now(),
            );
      }

      ref.invalidate(profileProvider);
      ref.invalidate(dashboardControllerProvider);
    } catch (e) {
      debugPrint('[onboarding] Erro: $e');
      setState(() {
        _saving = false;
        _error = 'Não foi possível guardar. Tenta novamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (_stepIndex > 0)
                        IconButton(
                          onPressed: () => setState(
                              () => _step = _steps[_stepIndex - 1]),
                          icon: const Icon(Icons.arrow_back),
                        )
                      else
                        const SizedBox(width: 48),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: (_stepIndex + 1) / _steps.length,
                            minHeight: 8,
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${_stepIndex + 1}/${_steps.length}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      _title(),
                      key: ValueKey(_step),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      _subtitle(),
                      key: ValueKey('sub-${_step.name}'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: ListView(
                  key: ValueKey('body-${_step.name}'),
                  padding: const EdgeInsets.all(20),
                  children: _stepBody(),
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: _canContinue ? _next : null,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_stepIndex == _steps.length - 1 ? 'Começar! 🚀' : 'Continuar'),
                  ),
                  if (_skippable) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _saving ? null : _skip,
                      child: const Text('Adicionar mais tarde'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _title() {
    switch (_step) {
      case OnboardingStep.name:
        return 'Como te chamas? 👋';
      case OnboardingStep.birth:
        return 'Um pouco sobre ti 🎂';
      case OnboardingStep.objective:
        return 'Qual é o teu objetivo? 🎯';
      case OnboardingStep.body:
        return 'O teu corpo ⚖️';
      case OnboardingStep.goal:
        return 'A tua meta diária 🔥';
    }
  }

  String _subtitle() {
    switch (_step) {
      case OnboardingStep.name:
        return 'Vou usar o teu nome nas saudações.';
      case OnboardingStep.birth:
        return 'Necessário para calcular as tuas necessidades calóricas.';
      case OnboardingStep.objective:
        return 'Escolhe um — podes mudar depois nas definições.';
      case OnboardingStep.body:
        return 'Sem pressão — podes adicionar tudo mais tarde.';
      case OnboardingStep.goal:
        return 'Calculada para ti, mas ajustável.';
    }
  }

  bool get _skippable {
    switch (_step) {
      case OnboardingStep.name:
      case OnboardingStep.birth:
      case OnboardingStep.goal:
        return false;
      default:
        return true;
    }
  }

  List<Widget> _stepBody() {
    final theme = Theme.of(context);
    switch (_step) {
      case OnboardingStep.name:
        return [
          TextField(
            controller: _nameController,
            onChanged: (_) => setState(() {}),
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'O teu nome',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
        ];
      case OnboardingStep.birth:
        return [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.cake_outlined),
            title: Text(
              _birthDate == null
                  ? 'Data de nascimento'
                  : DateFormat('d MMM yyyy').format(_birthDate!),
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime(2000),
                firstDate: DateTime(1920),
                lastDate: DateTime.now(),
                helpText: 'Data de nascimento',
                cancelText: 'Cancelar',
                confirmText: 'OK',
              );
              if (picked != null) setState(() => _birthDate = picked);
            },
          ),
          const SizedBox(height: 8),
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
        ];
      case OnboardingStep.objective:
        return [
          for (final entry in objectiveLabels.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ObjectiveCard(
                emoji: objectiveEmojis[entry.key]!,
                label: entry.value,
                selected: _objective == entry.key,
                onTap: () => setState(() => _objective = entry.key),
              ),
            ),
          if (_objective != 'maintain') ...[
            const SizedBox(height: 4),
            TextField(
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) => setState(
                  () => _targetWeight = double.tryParse(value.trim())),
              decoration: const InputDecoration(
                labelText: 'Peso alvo (kg)',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
            ),
          ],
        ];
      case OnboardingStep.body:
        return [
          TextField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Peso atual (kg)',
              prefixIcon: Icon(Icons.monitor_weight_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _heightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Altura (cm)',
              prefixIcon: Icon(Icons.height),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Atividade física',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          RadioGroup<String>(
            groupValue: _activityLevel,
            onChanged: (value) => setState(() => _activityLevel = value),
            child: Column(
              children: [
                for (final entry in activityLabels.entries)
                  RadioListTile<String>(
                    value: entry.key,
                    title: Text(entry.value),
                    dense: true,
                  ),
              ],
            ),
          ),
        ];
      case OnboardingStep.goal:
        return [
          if (_suggestedGoal != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: primaryGradientFor(theme.brightness),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    'Sugestão para ti',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_suggestedGoal kcal/dia',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Completa os dados anteriores (peso, altura e atividade) '
                'para receberes uma sugestão personalizada. 🧮',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _goalController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Meta diária de calorias (kcal)',
              prefixIcon: Icon(Icons.local_fire_department_outlined),
            ),
          ),
        ];
    }
  }
}

class _ObjectiveCard extends StatelessWidget {
  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ObjectiveCard({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primary.withValues(alpha: 0.12)
          : theme.colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}