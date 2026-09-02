import 'package:calorie_tracker/services/ai_coach_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MealSuggestion', () {
    test('parses suggestion json', () {
      final suggestion = MealSuggestion.fromJson({
        'name': 'Frango grelhado com arroz',
        'description': 'Refeição leve e proteica',
        'calories': 450,
        'protein': 40.5,
        'carbs': 50,
        'fat': 12,
      });
      expect(suggestion.name, 'Frango grelhado com arroz');
      expect(suggestion.calories, 450);
      expect(suggestion.protein, 40.5);
      expect(suggestion.carbs, 50);
      expect(suggestion.fat, 12);
    });

    test('tolerates missing fields', () {
      final suggestion = MealSuggestion.fromJson({'calories': 100});
      expect(suggestion.name, 'Sugestão');
      expect(suggestion.calories, 100);
      expect(suggestion.protein, isNull);
    });
  });

  group('CoachResponse', () {
    test('parses coach json', () {
      final coach = CoachResponse.fromJson({
        'summary': 'Boa semana! Registaste 5 de 7 dias.',
        'tips': ['Bebe mais água', 'Adiciona proteína ao jantar'],
      });
      expect(coach.summary, contains('Boa semana'));
      expect(coach.tips.length, 2);
      expect(coach.tips.first, 'Bebe mais água');
    });

    test('tolerates missing tips', () {
      final coach = CoachResponse.fromJson({'summary': 'ok'});
      expect(coach.tips, isEmpty);
      expect(coach.summary, 'ok');
    });
  });
}