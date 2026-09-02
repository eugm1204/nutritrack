import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/meal.dart';
import '../../providers/providers.dart';

class DashboardState {
  final DateTime date;
  final List<Meal> meals;
  final int goalCalories;
  final Map<DateTime, int> weekTotals;
  final bool onboardingCompleted;
  final String? name;
  final double? targetWeightKg;
  final double? latestWeightKg;

  const DashboardState({
    required this.date,
    required this.meals,
    required this.goalCalories,
    required this.weekTotals,
    required this.onboardingCompleted,
    this.name,
    this.targetWeightKg,
    this.latestWeightKg,
  });

  int get consumedCalories =>
      meals.fold(0, (sum, meal) => sum + meal.totalCalories);

  int get remainingCalories => goalCalories - consumedCalories;

  double get progress => goalCalories <= 0
      ? 0
      : (consumedCalories / goalCalories).clamp(0.0, 1.0);

  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }
}

class DashboardController extends AsyncNotifier<DashboardState> {
  @override
  Future<DashboardState> build() => _load(DateTime.now());

  Future<DashboardState> _load(DateTime date) async {
    final client = ref.watch(supabaseProvider);
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw Exception('Não autenticado');

    final profile = await ref.watch(profileRepositoryProvider).getOrCreate(userId);
    final meals = await ref
        .watch(mealRepositoryProvider)
        .fetchMealsForDate(date, userId);

    final today = DateTime.now();
    final weekStart = today.subtract(const Duration(days: 6));
    final weekTotals = await ref
        .watch(mealRepositoryProvider)
        .fetchTotalsForRange(weekStart, today, userId);

    double? latestWeight;
    try {
      final entries = await ref.watch(weightRepositoryProvider).fetchEntries(userId);
      if (entries.isNotEmpty) latestWeight = entries.last.weightKg;
    } catch (_) {
      // peso indisponível não bloqueia o dashboard
    }

    return DashboardState(
      date: date,
      meals: meals,
      goalCalories: profile.dailyGoalCalories,
      weekTotals: weekTotals,
      onboardingCompleted: profile.onboardingCompleted,
      name: profile.name,
      targetWeightKg: profile.targetWeightKg,
      latestWeightKg: latestWeight,
    );
  }

  Future<void> selectDate(DateTime date) async {
    state = await AsyncValue.guard(() => _load(date));
  }

  Future<void> goToToday() => selectDate(DateTime.now());

  Future<void> deleteMeal(String mealId) async {
    final userId = ref.read(supabaseProvider).auth.currentUser!.id;
    await ref.read(mealRepositoryProvider).deleteMeal(mealId, userId);
    final current = state.value;
    if (current != null) {
      state = await AsyncValue.guard(() => _load(current.date));
    } else {
      ref.invalidateSelf();
    }
  }
}

final dashboardControllerProvider =
    AsyncNotifierProvider<DashboardController, DashboardState>(DashboardController.new);