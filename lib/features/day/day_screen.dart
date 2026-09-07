import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../models/meal.dart';
import '../../providers/providers.dart';
import '../../widgets/meal_card.dart';
import '../dashboard/dashboard_controller.dart';
import '../history/history_controller.dart';

class DayScreen extends ConsumerStatefulWidget {
  final DateTime date;

  const DayScreen({super.key, required this.date});

  @override
  ConsumerState<DayScreen> createState() => _DayScreenState();
}

class _DayScreenState extends ConsumerState<DayScreen> {
  bool _loading = true;
  String? _error;
  List<Meal> _meals = [];
  int _waterCups = 0;
  int _goalCalories = 2200;
  int _waterGoal = 8;
  int? _proteinGoal;
  int? _carbsGoal;
  int? _fatGoal;

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
      final user = ref.read(supabaseProvider).auth.currentUser;
      if (user == null) throw Exception('Sessão expirada');
      final profile = await ref.read(profileRepositoryProvider).getOrCreate(user.id);
      final meals = await ref
          .read(mealRepositoryProvider)
          .fetchMealsForDate(widget.date, user.id);
      final water =
          await ref.read(waterRepositoryProvider).fetchCups(user.id, widget.date);

      if (!mounted) return;
      setState(() {
        _meals = meals;
        _waterCups = water;
        _goalCalories = profile.dailyGoalCalories;
        _waterGoal = profile.waterGoalCups;
        _proteinGoal = profile.proteinGoalG;
        _carbsGoal = profile.carbsGoalG;
        _fatGoal = profile.fatGoalG;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[day] Erro: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Não foi possível carregar o dia.';
      });
    }
  }

  Future<void> _changeWater(int delta) async {
    final next = (_waterCups + delta).clamp(0, 30);
    if (next == _waterCups) return;
    setState(() => _waterCups = next);
    final user = ref.read(supabaseProvider).auth.currentUser;
    if (user == null) return;
    await ref
        .read(waterRepositoryProvider)
        .setCups(user.id, widget.date, next);
  }

  Future<void> _deleteMeal(Meal meal) async {
    final user = ref.read(supabaseProvider).auth.currentUser;
    if (user == null) return;
    await ref.read(mealRepositoryProvider).deleteMeal(meal.id, user.id);
    await _load();
  }

  Future<void> _duplicateMeal(Meal meal, DateTime date) async {
    try {
      final user = ref.read(supabaseProvider).auth.currentUser;
      if (user == null) return;
      final consumedAt = DateTime(
        date.year,
        date.month,
        date.day,
        meal.consumedAt.hour,
        meal.consumedAt.minute,
      );
      await ref.read(mealRepositoryProvider).insertMeal(
            userId: user.id,
            imageUrl: meal.imageUrl,
            mealName: meal.mealName,
            items: meal.items,
            consumedAt: consumedAt,
            notes: meal.notes,
          );
      ref.invalidate(dashboardControllerProvider);
      ref.invalidate(historyControllerProvider);
      await _load();
    } catch (e) {
      debugPrint('[day/duplicate] Erro: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível duplicar a refeição.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isToday = now.year == widget.date.year &&
        now.month == widget.date.month &&
        now.day == widget.date.day;

    final consumed = _meals.fold<int>(0, (sum, meal) => sum + meal.totalCalories);
    final progress = _goalCalories <= 0 ? 0.0 : (consumed / _goalCalories).clamp(0.0, 1.0);

    double sumMacro(double? Function(dynamic item) extract) => _meals.fold<double>(
        0, (acc, meal) => acc + meal.items.fold<double>(0, (a, item) => a + (extract(item) ?? 0)));

    final protein = sumMacro((item) => item.protein);
    final carbs = sumMacro((item) => item.carbs);
    final fat = sumMacro((item) => item.fat);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isToday ? 'Hoje' : DateFormat('EEEE, d MMM', 'pt_PT').format(widget.date),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.colorScheme.outlineVariant),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '$consumed',
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onSurface,
                                    letterSpacing: -0.8,
                                    fontFeatures: [FontFeature.tabularFigures()],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 5),
                                  child: Text(
                                    'de $_goalCalories kcal',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 6,
                                color: consumed > _goalCalories ? appOrange : appGreen,
                                backgroundColor:
                                    theme.colorScheme.surfaceContainerHighest,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _dayMacroRow('Proteína', protein, _proteinGoal, macroProteinColor),
                            const SizedBox(height: 6),
                            _dayMacroRow('Hidratos', carbs, _carbsGoal, macroCarbsColor),
                            const SizedBox(height: 6),
                            _dayMacroRow('Gordura', fat, _fatGoal, macroFatColor),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.colorScheme.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            Text('💧', style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Água · $_waterCups/$_waterGoal copos',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _waterCups > 0 ? () => _changeWater(-1) : null,
                              icon: Icon(
                                Icons.remove_circle_outline,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            IconButton(
                              onPressed: () => _changeWater(1),
                              icon: const Icon(Icons.add_circle_outline, color: appWaterBlue),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('Refeições', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (_meals.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: theme.colorScheme.outlineVariant),
                          ),
                          child: Text(
                            'Sem refeições registadas neste dia.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      else
                        for (final meal in _meals)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: MealCard(
                              meal: meal,
                              onTap: () => context.push('/meal', extra: meal),
                              onDelete: () => _deleteMeal(meal),
                              onDuplicate: (date) => _duplicateMeal(meal, date),
                            ),
                          ),
                    ],
                  ),
                ),
    );
  }

  Widget _dayMacroRow(String label, double value, int? goal, Color color) {
    final theme = Theme.of(context);
    final progress = goal == null || goal <= 0 ? 0.0 : (value / goal).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              color: color,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 70,
          child: Text(
            goal != null
                ? '${value.toStringAsFixed(0)}/${goal}g'
                : '${value.toStringAsFixed(0)}g',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}