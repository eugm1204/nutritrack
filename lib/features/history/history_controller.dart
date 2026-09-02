import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/meal.dart';
import '../../providers/providers.dart';

class HistoryState {
  final int goalCalories;
  final Map<DateTime, List<Meal>> mealsByDay;

  const HistoryState({
    required this.goalCalories,
    required this.mealsByDay,
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

    return HistoryState(goalCalories: profile.dailyGoalCalories, mealsByDay: byDay);
  }

  Future<void> deleteMeal(String mealId) async {
    final userId = ref.read(supabaseProvider).auth.currentUser!.id;
    await ref.read(mealRepositoryProvider).deleteMeal(mealId, userId);
    ref.invalidateSelf();
  }
}

final historyControllerProvider =
    AsyncNotifierProvider<HistoryController, HistoryState>(HistoryController.new);