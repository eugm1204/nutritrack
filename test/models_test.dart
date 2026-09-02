import 'package:calorie_tracker/models/meal.dart';
import 'package:calorie_tracker/models/meal_item.dart';
import 'package:calorie_tracker/models/profile.dart';
import 'package:calorie_tracker/models/vision_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MealItem', () {
    test('roundtrip json', () {
      const item = MealItem(name: 'Arroz', calories: 200, grams: 150, confidence: 0.9);
      final decoded = MealItem.fromJson(item.toJson());
      expect(decoded.name, 'Arroz');
      expect(decoded.calories, 200);
      expect(decoded.grams, 150);
      expect(decoded.confidence, 0.9);
    });

    test('copyWith preserves fields not provided', () {
      const item = MealItem(name: 'Arroz', calories: 200);
      final updated = item.copyWith(calories: 180);
      expect(updated.name, 'Arroz');
      expect(updated.calories, 180);
      expect(updated.confirmed, isFalse);
    });
  });

  group('Meal', () {
    test('parses json with items array', () {
      final meal = Meal.fromJson({
        'id': 'abc',
        'user_id': 'u1',
        'image_url': 'https://example.com/f.jpg',
        'meal_name': 'Almoço',
        'total_calories': 650,
        'consumed_at': '2026-09-02T12:00:00Z',
        'items': [
          {'name': 'Arroz', 'calories': 200},
          {'name': 'Frango', 'calories': 350},
          {'name': 'Salada', 'calories': 100},
        ],
      });

      expect(meal.id, 'abc');
      expect(meal.totalCalories, 650);
      expect(meal.itemCount, 3);
      expect(meal.items.first.name, 'Arroz');
    });

    test('tolerates empty or null items', () {
      final meal = Meal.fromJson({'id': 'x', 'user_id': 'u', 'total_calories': 0});
      expect(meal.items, isEmpty);
      expect(meal.mealName, 'Refeição');
    });
  });

  group('VisionAnalysis', () {
    test('parses analysis result', () {
      final analysis = VisionAnalysis.fromJson({
        'mealName': 'Almoço',
        'totalCalories': 650,
        'items': [
          {'name': 'Arroz', 'calories': 200, 'grams': 150, 'confidence': 0.92},
        ],
      });

      expect(analysis.mealName, 'Almoço');
      expect(analysis.totalCalories, 650);
      expect(analysis.items.single.grams, 150);
    });

    test('falls back to summing items when totalCalories missing', () {
      final analysis = VisionAnalysis.fromJson({
        'items': [
          {'name': 'A', 'calories': 100},
          {'name': 'B', 'calories': 200},
        ],
      });

      expect(analysis.totalCalories, 300);
    });

    test('tolerates invalid types', () {
      final analysis = VisionAnalysis.fromJson({'items': 'nope'});
      expect(analysis.items, isEmpty);
      expect(analysis.totalCalories, 0);
    });
  });

  group('Profile', () {
    test('defaults to 2200 kcal goal', () {
      const profile = Profile(id: 'u1');
      expect(profile.dailyGoalCalories, 2200);
      expect(profile.objective, 'maintain');
    });

    test('parses json', () {
      final profile = Profile.fromJson({
        'id': 'u1',
        'daily_goal_calories': 1800,
        'weight_kg': 72.5,
        'objective': 'lose',
      });
      expect(profile.dailyGoalCalories, 1800);
      expect(profile.weightKg, 72.5);
      expect(profile.objective, 'lose');
    });
  });
}