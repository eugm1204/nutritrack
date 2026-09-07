import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/meal.dart';
import '../../providers/providers.dart';

class WeeklyInsights {
  final int avgKcalPerDay;
  final int daysLogged;
  final int currentWeekKcal;
  final int? previousWeekKcal;
  final int? bestDayKcal;
  final int? worstDayKcal;
  final DateTime? bestDay;
  final DateTime? worstDay;

  const WeeklyInsights({
    required this.avgKcalPerDay,
    required this.daysLogged,
    required this.currentWeekKcal,
    this.previousWeekKcal,
    this.bestDayKcal,
    this.worstDayKcal,
    this.bestDay,
    this.worstDay,
  });

  int? get changePercent {
    final prev = previousWeekKcal;
    if (prev == null || prev <= 0) return null;
    return ((currentWeekKcal - prev) * 100 / prev).round();
  }

  bool get hasData => daysLogged > 0;
}

class HistoryState {
  final int goalCalories;
  final Map<DateTime, List<Meal>> mealsByDay;
  final WeeklyInsights insights;
  final double avgProtein;
  final double avgCarbs;
  final double avgFat;
  final int? proteinGoalG;
  final int? carbsGoalG;
  final int? fatGoalG;

  const HistoryState({
    required this.goalCalories,
    required this.mealsByDay,
    required this.insights,
    this.avgProtein = 0,
    this.avgCarbs = 0,
    this.avgFat = 0,
    this.proteinGoalG,
    this.carbsGoalG,
    this.fatGoalG,
  });
}

class HistoryController extends AsyncNotifier<HistoryState> {
  @override
  Future<HistoryState> build() async {
    final client = ref.watch(supabaseProvider);
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw Exception('Não autenticado');

    final profile = await ref.watch(profileRepositoryProvider).getOrCreate(userId);
    final today = DateTime.now();
    final from = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 13));

    final meals =
        await ref.watch(mealRepositoryProvider).fetchMealsForRange(from, today, userId);

    final byDay = <DateTime, List<Meal>>{};
    for (final meal in meals) {
      final key = DateTime(
        meal.consumedAt.year,
        meal.consumedAt.month,
        meal.consumedAt.day,
      );
      byDay.putIfAbsent(key, () => []).add(meal);
    }

    double proteinSum = 0, carbsSum = 0, fatSum = 0;
    var counted = 0;
    for (var i = 0; i < 7; i++) {
      final day = today.subtract(Duration(days: i));
      final meals = byDay[day] ?? const [];
      if (meals.isNotEmpty) counted++;
      for (final meal in meals) {
        for (final item in meal.items) {
          proteinSum += item.protein ?? 0;
          carbsSum += item.carbs ?? 0;
          fatSum += item.fat ?? 0;
        }
      }
    }

    return HistoryState(
      goalCalories: profile.dailyGoalCalories,
      mealsByDay: byDay,
      insights: _computeInsights(byDay, profile.dailyGoalCalories),
      avgProtein: counted > 0 ? proteinSum / counted : 0,
      avgCarbs: counted > 0 ? carbsSum / counted : 0,
      avgFat: counted > 0 ? fatSum / counted : 0,
      proteinGoalG: profile.proteinGoalG,
      carbsGoalG: profile.carbsGoalG,
      fatGoalG: profile.fatGoalG,
    );
  }

  WeeklyInsights _computeInsights(
    Map<DateTime, List<Meal>> byDay,
    int goalCalories,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    int totalFor(DateTime day) => (byDay[day] ?? const [])
        .fold(0, (sum, meal) => sum + meal.totalCalories);

    int currentWeek = 0;
    int previousWeek = 0;
    int daysLogged = 0;
    DateTime? bestDay;
    DateTime? worstDay;
    int bestDeviation = 1 << 30;
    int worstDeviation = -1;

    for (var i = 0; i < 7; i++) {
      final day = today.subtract(Duration(days: i));
      final total = totalFor(day);
      currentWeek += total;
      if (total > 0) {
        daysLogged++;
        final deviation = (total - goalCalories).abs();
        if (deviation < bestDeviation) {
          bestDeviation = deviation;
          bestDay = day;
        }
        if (deviation > worstDeviation) {
          worstDeviation = deviation;
          worstDay = day;
        }
      }
    }

    for (var i = 7; i < 14; i++) {
      previousWeek += totalFor(today.subtract(Duration(days: i)));
    }

    return WeeklyInsights(
      avgKcalPerDay: daysLogged > 0 ? (currentWeek / daysLogged).round() : 0,
      daysLogged: daysLogged,
      currentWeekKcal: currentWeek,
      previousWeekKcal: previousWeek,
      bestDayKcal: bestDay != null ? totalFor(bestDay) : null,
      worstDayKcal: worstDay != null ? totalFor(worstDay) : null,
      bestDay: bestDay,
      worstDay: worstDay,
    );
  }

  Future<void> deleteMeal(String mealId) async {
    final userId = ref.read(supabaseProvider).auth.currentUser!.id;
    await ref.read(mealRepositoryProvider).deleteMeal(mealId, userId);
    ref.invalidateSelf();
  }
}

final historyControllerProvider =
    AsyncNotifierProvider<HistoryController, HistoryState>(HistoryController.new);