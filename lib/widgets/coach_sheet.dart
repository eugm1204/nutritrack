import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/history/history_controller.dart';
import '../providers/providers.dart';
import '../services/ai_coach_service.dart';

class CoachSheet extends ConsumerStatefulWidget {
  final HistoryState historyState;

  const CoachSheet({super.key, required this.historyState});

  @override
  ConsumerState<CoachSheet> createState() => _CoachSheetState();
}

class _CoachSheetState extends ConsumerState<CoachSheet> {
  bool _loading = true;
  String? _error;
  CoachResponse? _response;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final state = widget.historyState;
      final user = ref.read(supabaseProvider).auth.currentUser;
      if (user == null) throw Exception('Sessão expirada');

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final days = <(DateTime, int)>[];
      double proteinSum = 0, carbsSum = 0, fatSum = 0;
      var counted = 0;
      for (var i = 0; i < 7; i++) {
        final day = today.subtract(Duration(days: i));
        final meals = state.mealsByDay[day] ?? const [];
        final total = meals.fold<int>(0, (s, m) => s + m.totalCalories);
        days.insert(0, (day, total));
        if (total > 0) {
          counted++;
          for (final meal in meals) {
            for (final item in meal.items) {
              proteinSum += item.protein ?? 0;
              carbsSum += item.carbs ?? 0;
              fatSum += item.fat ?? 0;
            }
          }
        }
      }

      var streak = 0;
      var dayCursor = today;
      while (true) {
        final meals = state.mealsByDay[dayCursor];
        if (meals == null || meals.isEmpty) {
          if (streak == 0) {
            dayCursor = dayCursor.subtract(const Duration(days: 1));
            continue;
          }
          break;
        }
        streak++;
        dayCursor = dayCursor.subtract(const Duration(days: 1));
      }

      String weightTrend = 'sem dados';
      try {
        final entries = await ref.read(weightRepositoryProvider).fetchEntries(user.id);
        if (entries.length >= 2) {
          final latest = entries.last.weightKg;
          final previous = entries[entries.length - 2].weightKg;
          weightTrend = latest < previous
              ? 'a descer'
              : latest > previous
                  ? 'a subir'
                  : 'estável';
        }
      } catch (_) {
        // sem dados de peso
      }

      final profile = await ref.read(profileRepositoryProvider).getOrCreate(user.id);

      final response = await ref.read(aiCoachServiceProvider).weeklyCoach(
            days: days,
            goalCalories: state.goalCalories,
            daysLogged: counted,
            streakDays: streak,
            avgProtein: counted > 0 ? proteinSum / counted : 0,
            avgCarbs: counted > 0 ? carbsSum / counted : 0,
            avgFat: counted > 0 ? fatSum / counted : 0,
            objective: profile.objective,
            weightTrend: weightTrend,
          );

      if (!mounted) return;
      setState(() {
        _response = response;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[coach] Erro: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Não foi possível gerar o resumo. Tenta novamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'O teu coach semanal 🧠',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              'Análise dos últimos 7 dias',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!, textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              FilledButton.tonal(
                                onPressed: _load,
                                child: const Text('Tentar de novo'),
                              ),
                            ],
                          ),
                        )
                      : ListView(
                          controller: scrollController,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('🤖', style: TextStyle(fontSize: 28)),
                                  const SizedBox(height: 8),
                                  Text(
                                    _response!.summary,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Dicas da semana 💡',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            for (final tip in _response!.tips)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('✅', style: TextStyle(fontSize: 16)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        tip,
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}