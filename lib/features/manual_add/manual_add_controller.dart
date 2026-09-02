import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/meal_item.dart';
import '../../providers/providers.dart';
import '../dashboard/dashboard_controller.dart';

class ManualAddState {
  final String mealName;
  final List<MealItem> items;
  final List<MealItem> baseItems;
  final bool saving;
  final String? error;

  const ManualAddState({
    this.mealName = 'Refeição',
    this.items = const [],
    this.baseItems = const [],
    this.saving = false,
    this.error,
  });

  int get totalCalories => items.fold(0, (sum, item) => sum + item.calories);

  ManualAddState copyWith({
    String? mealName,
    List<MealItem>? items,
    List<MealItem>? baseItems,
    bool? saving,
    String? error,
    bool clearError = false,
  }) {
    return ManualAddState(
      mealName: mealName ?? this.mealName,
      items: items ?? this.items,
      baseItems: baseItems ?? this.baseItems,
      saving: saving ?? this.saving,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ManualAddController extends Notifier<ManualAddState> {
  @override
  ManualAddState build() => const ManualAddState();

  void updateMealName(String name) {
    state = state.copyWith(mealName: name);
  }

  void addItem(MealItem item) {
    state = state.copyWith(
      items: [...state.items, item],
      baseItems: [...state.baseItems, item],
      clearError: true,
    );
    ref.read(recentFoodsServiceProvider).save(item);
  }

  void updateItem(int index, String? name, int? calories) {
    final items = [...state.items];
    final updated = items[index].copyWith(name: name, calories: calories);
    items[index] = updated;

    final baseItems = [...state.baseItems];
    baseItems[index] = updated;

    state = state.copyWith(items: items, baseItems: baseItems);
  }

  void setPortion(int index, double multiplier) {
    final items = [...state.items];
    items[index] = state.baseItems[index].scaledBy(multiplier);
    state = state.copyWith(items: items);
  }

  void removeItem(int index) {
    final items = [...state.items]..removeAt(index);
    final baseItems = [...state.baseItems]..removeAt(index);
    state = state.copyWith(items: items, baseItems: baseItems);
  }

  Future<bool> save() async {
    if (state.items.isEmpty) {
      state = state.copyWith(error: 'Adiciona pelo menos um alimento.');
      return false;
    }
    state = state.copyWith(saving: true, clearError: true);
    try {
      final user = ref.read(supabaseProvider).auth.currentUser;
      if (user == null) {
        state = state.copyWith(saving: false, error: 'Sessão expirada. Volta a entrar.');
        return false;
      }
      await ref.read(mealRepositoryProvider).insertMeal(
            userId: user.id,
            imageUrl: null,
            mealName: state.mealName.isEmpty ? 'Refeição' : state.mealName,
            items: state.items,
            consumedAt: DateTime.now(),
          );
      ref.invalidate(dashboardControllerProvider);
      return true;
    } catch (e) {
      debugPrint('[manualAdd/save] Erro: $e');
      state = state.copyWith(
        saving: false,
        error: 'Não foi possível guardar. Tenta novamente.',
      );
      return false;
    }
  }
}

final manualAddControllerProvider =
    NotifierProvider<ManualAddController, ManualAddState>(ManualAddController.new);