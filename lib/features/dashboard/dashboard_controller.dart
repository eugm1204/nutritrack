import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/meal.dart';
import '../../providers/providers.dart';
import '../../services/favorites_service.dart';

class DashboardState {
  final DateTime date;
  final List<Meal> meals;
  final int goalCalories;
  final Map<DateTime, int> weekTotals;
  final bool onboardingCompleted;
  final String? name;
  final double? targetWeightKg;
  final double? latestWeightKg;
  final int? proteinGoalG;
  final int? carbsGoalG;
  final int? fatGoalG;
  final int streakDays;
  final int waterCups;
  final List<FavoriteMeal> favorites;

  const DashboardState({
    required this.date,
    required this.meals,
    required this.goalCalories,
    required this.weekTotals,
    required this.onboardingCompleted,
    this.name,
    this.targetWeightKg,
    this.latestWeightKg,
    this.proteinGoalG,
    this.carbsGoalG,
    this.fatGoalG,
    this.streakDays = 0,
    this.waterCups = 0,
    this.favorites = const [],
  });

  bool get hasMacroGoals =>
      proteinGoalG != null || carbsGoalG != null || fatGoalG != null;

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
  static const _waterKey = 'water_';

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

    final streak = await _computeStreak(userId);
    final water = await _loadWater(today);
    final favorites = await ref.read(favoritesServiceProvider).load();

    return DashboardState(
      date: date,
      meals: meals,
      goalCalories: profile.dailyGoalCalories,
      weekTotals: weekTotals,
      onboardingCompleted: profile.onboardingCompleted,
      name: profile.name,
      targetWeightKg: profile.targetWeightKg,
      latestWeightKg: latestWeight,
      proteinGoalG: profile.proteinGoalG,
      carbsGoalG: profile.carbsGoalG,
      fatGoalG: profile.fatGoalG,
      streakDays: streak,
      waterCups: water,
      favorites: favorites,
    );
  }

  Future<int> _computeStreak(String userId) async {
    final today = DateTime.now();
    final from = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 59));
    final meals = await ref
        .watch(mealRepositoryProvider)
        .fetchMealsForRange(from, today, userId);

    final days = <DateTime>{};
    for (final meal in meals) {
      days.add(DateTime(
        meal.consumedAt.year,
        meal.consumedAt.month,
        meal.consumedAt.day,
      ));
    }

    var streak = 0;
    var day = today;
    if (!days.contains(day)) {
      day = day.subtract(const Duration(days: 1));
    }
    while (days.contains(day)) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  Future<int> _loadWater(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_waterKey${date.year}-${date.month}-${date.day}';
    return prefs.getInt(key) ?? 0;
  }

  Future<void> _saveWater(int cups) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setInt(
      '$_waterKey${now.year}-${now.month}-${now.day}',
      cups,
    );
  }

  Future<void> addWater() async {
    final current = state.value;
    if (current == null) return;
    await _saveWater(current.waterCups + 1);
    state = state.copyWithValue(waterCups: current.waterCups + 1);
  }

  Future<void> removeWater() async {
    final current = state.value;
    if (current == null || current.waterCups <= 0) return;
    await _saveWater(current.waterCups - 1);
    state = state.copyWithValue(waterCups: current.waterCups - 1);
  }

  Future<void> refreshFavorites() async {
    final current = state.value;
    if (current == null) return;
    final favorites = await ref.read(favoritesServiceProvider).load();
    state = state.copyWithValue(favorites: favorites);
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

extension on AsyncValue<DashboardState> {
  AsyncValue<DashboardState> copyWithValue({
    int? waterCups,
    List<FavoriteMeal>? favorites,
  }) {
    final value = this.value;
    if (value == null) return this;
    return AsyncData(DashboardState(
      date: value.date,
      meals: value.meals,
      goalCalories: value.goalCalories,
      weekTotals: value.weekTotals,
      onboardingCompleted: value.onboardingCompleted,
      name: value.name,
      targetWeightKg: value.targetWeightKg,
      latestWeightKg: value.latestWeightKg,
      proteinGoalG: value.proteinGoalG,
      carbsGoalG: value.carbsGoalG,
      fatGoalG: value.fatGoalG,
      streakDays: value.streakDays,
      waterCups: waterCups ?? value.waterCups,
      favorites: favorites ?? value.favorites,
    ));
  }
}

final dashboardControllerProvider =
    AsyncNotifierProvider<DashboardController, DashboardState>(DashboardController.new);