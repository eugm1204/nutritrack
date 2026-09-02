import 'package:calorie_tracker/models/meal.dart';
import 'package:calorie_tracker/models/meal_item.dart';
import 'package:calorie_tracker/models/profile.dart';
import 'package:calorie_tracker/models/vision_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MealItem', () {
    test('roundtrip json with macros', () {
      const item = MealItem(
        name: 'Arroz',
        calories: 200,
        protein: 4.2,
        carbs: 43.1,
        fat: 0.5,
        grams: 150,
        portionRef: '1 chávena de arroz',
        confidence: 0.9,
      );
      final decoded = MealItem.fromJson(item.toJson());
      expect(decoded.name, 'Arroz');
      expect(decoded.calories, 200);
      expect(decoded.protein, 4.2);
      expect(decoded.carbs, 43.1);
      expect(decoded.fat, 0.5);
      expect(decoded.grams, 150);
      expect(decoded.portionRef, '1 chávena de arroz');
      expect(decoded.confidence, 0.9);
    });

    test('copyWith preserves fields not provided', () {
      const item = MealItem(name: 'Arroz', calories: 200);
      final updated = item.copyWith(calories: 180);
      expect(updated.name, 'Arroz');
      expect(updated.calories, 180);
      expect(updated.confirmed, isFalse);
    });

    test('macros default to zero', () {
      const item = MealItem(name: 'X', calories: 100);
      expect(item.totalProtein, 0);
      expect(item.totalCarbs, 0);
      expect(item.totalFat, 0);
    });

    test('scaledBy scales all values proportionally', () {
      const item = MealItem(
        name: 'Arroz',
        calories: 200,
        protein: 4,
        carbs: 43,
        fat: 0.5,
        grams: 150,
      );
      final half = item.scaledBy(0.5);
      expect(half.calories, 100);
      expect(half.protein, 2);
      expect(half.carbs, 21.5);
      expect(half.fat, 0.25);
      expect(half.grams, 75);
      expect(half.name, 'Arroz');

      final double2 = item.scaledBy(2);
      expect(double2.calories, 400);
      expect(double2.grams, 300);
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
    test('parses analysis result with macros', () {
      final analysis = VisionAnalysis.fromJson({
        'mealName': 'Almoço',
        'totalCalories': 650,
        'totalProtein': 35.5,
        'items': [
          {
            'name': 'Arroz',
            'calories': 200,
            'protein': 4.0,
            'carbs': 43.0,
            'fat': 0.5,
            'grams': 150,
            'portionRef': '1 chávena de arroz',
            'confidence': 0.92,
          },
        ],
      });

      expect(analysis.mealName, 'Almoço');
      expect(analysis.totalCalories, 650);
      expect(analysis.totalProtein, 35.5);
      expect(analysis.items.single.grams, 150);
      expect(analysis.items.single.protein, 4.0);
      expect(analysis.items.single.portionRef, '1 chávena de arroz');
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
      expect(profile.onboardingCompleted, isFalse);
    });

    test('parses json', () {
      final profile = Profile.fromJson({
        'id': 'u1',
        'daily_goal_calories': 1800,
        'weight_kg': 72.5,
        'objective': 'lose',
        'name': 'João',
        'birth_date': '1990-05-10',
        'sex': 'male',
        'height_cm': 178,
        'activity_level': 'moderate',
        'target_weight_kg': 68,
        'onboarding_completed': true,
      });
      expect(profile.dailyGoalCalories, 1800);
      expect(profile.weightKg, 72.5);
      expect(profile.objective, 'lose');
      expect(profile.name, 'João');
      expect(profile.birthDate, DateTime(1990, 5, 10));
      expect(profile.sex, 'male');
      expect(profile.heightCm, 178);
      expect(profile.activityLevel, 'moderate');
      expect(profile.targetWeightKg, 68);
      expect(profile.onboardingCompleted, isTrue);
    });

    test('serializes birth date as ISO date', () {
      final profile = Profile(id: 'u1', birthDate: DateTime(1990, 5, 10));
      expect(profile.toJson()['birth_date'], '1990-05-10');
      expect(profile.toJson()['onboarding_completed'], isFalse);
    });
  });
}