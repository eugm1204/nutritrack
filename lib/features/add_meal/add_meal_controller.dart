import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/meal_item.dart';
import '../../providers/providers.dart';
import '../dashboard/dashboard_controller.dart';

enum AddMealStep { pick, analyzing, confirm, saving }

class AddMealState {
  final AddMealStep step;
  final String? imagePath;
  final Uint8List? previewBytes;
  final String? imageUrl;
  final String mealName;
  final List<MealItem> items;
  final String? error;

  const AddMealState({
    this.step = AddMealStep.pick,
    this.imagePath,
    this.previewBytes,
    this.imageUrl,
    this.mealName = 'Refeição',
    this.items = const [],
    this.error,
  });

  int get totalCalories => items.fold(0, (sum, item) => sum + item.calories);

  AddMealState copyWith({
    AddMealStep? step,
    String? imagePath,
    Uint8List? previewBytes,
    String? imageUrl,
    String? mealName,
    List<MealItem>? items,
    String? error,
    bool clearError = false,
  }) {
    return AddMealState(
      step: step ?? this.step,
      imagePath: imagePath ?? this.imagePath,
      previewBytes: previewBytes ?? this.previewBytes,
      imageUrl: imageUrl ?? this.imageUrl,
      mealName: mealName ?? this.mealName,
      items: items ?? this.items,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AddMealController extends Notifier<AddMealState> {
  @override
  AddMealState build() => const AddMealState();

  Future<void> analyzeImage(XFile file) async {
    state = state.copyWith(
      step: AddMealStep.analyzing,
      imagePath: file.path,
      previewBytes: await file.readAsBytes(),
      clearError: true,
    );

    try {
      final userId = ref.read(supabaseProvider).auth.currentUser!.id;
      final imageUrl = await ref.read(mealRepositoryProvider).uploadMealPhoto(file, userId);
      final analysis = await ref.read(visionServiceProvider).analyzeMeal(imageUrl);

      state = state.copyWith(
        step: AddMealStep.confirm,
        mealName: analysis.mealName,
        imageUrl: imageUrl,
        items: analysis.items
            .map((item) => MealItem(
                  name: item.name,
                  calories: item.calories,
                  grams: item.grams,
                  confidence: item.confidence,
                ))
            .toList(),
      );
    } catch (e) {
      debugPrint('[analyzeImage] Erro: $e');
      state = state.copyWith(
        step: AddMealStep.pick,
        error: 'Não foi possível analisar a imagem. Tenta novamente.',
      );
    }
  }

  void updateMealName(String name) {
    state = state.copyWith(mealName: name);
  }

  void updateItem(int index, String? name, int? calories) {
    final items = [...state.items];
    items[index] = items[index].copyWith(
      name: name,
      calories: calories,
      confirmed: true,
    );
    state = state.copyWith(items: items);
  }

  void removeItem(int index) {
    final items = [...state.items]..removeAt(index);
    state = state.copyWith(items: items);
  }

  Future<bool> saveMeal() async {
    state = state.copyWith(step: AddMealStep.saving, clearError: true);
    try {
      final userId = ref.read(supabaseProvider).auth.currentUser!.id;
      await ref.read(mealRepositoryProvider).insertMeal(
            userId: userId,
            imageUrl: state.imageUrl,
            mealName: state.mealName.isEmpty ? 'Refeição' : state.mealName,
            items: state.items,
            consumedAt: DateTime.now(),
          );
      ref.invalidate(dashboardControllerProvider);
      return true;
    } catch (e) {
      debugPrint('[saveMeal] Erro: $e');
      state = state.copyWith(
        step: AddMealStep.confirm,
        error: 'Não foi possível guardar a refeição. Tenta novamente.',
      );
      return false;
    }
  }

  void reset() {
    state = const AddMealState();
  }
}

final addMealControllerProvider =
    NotifierProvider<AddMealController, AddMealState>(AddMealController.new);