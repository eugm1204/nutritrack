import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

class MealSuggestion {
  final String name;
  final String description;
  final int calories;
  final double? protein;
  final double? carbs;
  final double? fat;

  const MealSuggestion({
    required this.name,
    required this.description,
    required this.calories,
    this.protein,
    this.carbs,
    this.fat,
  });

  factory MealSuggestion.fromJson(Map<String, dynamic> json) {
    return MealSuggestion(
      name: json['name'] as String? ?? 'Sugestão',
      description: json['description'] as String? ?? '',
      calories: (json['calories'] as num?)?.toInt() ?? 0,
      protein: (json['protein'] as num?)?.toDouble(),
      carbs: (json['carbs'] as num?)?.toDouble(),
      fat: (json['fat'] as num?)?.toDouble(),
    );
  }
}

class CoachResponse {
  final String summary;
  final List<String> tips;

  const CoachResponse({required this.summary, required this.tips});

  factory CoachResponse.fromJson(Map<String, dynamic> json) {
    final rawTips = json['tips'];
    final tips = rawTips is List
        ? rawTips.whereType<String>().toList()
        : <String>[];
    return CoachResponse(
      summary: json['summary'] as String? ?? '',
      tips: tips,
    );
  }
}

class AiCoachService {
  final SupabaseClient _client;

  AiCoachService(this._client);

  Future<List<MealSuggestion>> suggestMeals({
    required int remainingKcal,
    required String objective,
    required double protein,
    required double carbs,
    required double fat,
    int? proteinGoal,
    int? carbsGoal,
    int? fatGoal,
  }) async {
    final response = await _client.functions.invoke(
      'suggest-meals',
      body: {
        'kcalRestantes': remainingKcal,
        'objective': objective,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'proteinGoal': proteinGoal,
        'carbsGoal': carbsGoal,
        'fatGoal': fatGoal,
      },
    );

    if (response.status < 200 || response.status >= 300 || response.data == null) {
      throw Exception('Sugestões falharam (HTTP ${response.status})');
    }

    final data = jsonDecode(jsonEncode(response.data));
    final raw = data is Map<String, dynamic> ? data['suggestions'] : null;
    if (raw is! List) throw const FormatException('Formato inesperado');

    return raw
        .whereType<Map>()
        .map((e) => MealSuggestion.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<CoachResponse> weeklyCoach({
    required List<(DateTime, int)> days,
    required int goalCalories,
    required int daysLogged,
    required int streakDays,
    required double avgProtein,
    required double avgCarbs,
    required double avgFat,
    required String objective,
    required String weightTrend,
  }) async {
    final response = await _client.functions.invoke(
      'weekly-coach',
      body: {
        'days': [
          for (final (day, kcal) in days)
            {'date': '${day.day}/${day.month}', 'kcal': kcal},
        ],
        'goalCalories': goalCalories,
        'daysLogged': daysLogged,
        'streakDays': streakDays,
        'avgProtein': avgProtein,
        'avgCarbs': avgCarbs,
        'avgFat': avgFat,
        'objective': objective,
        'weightTrend': weightTrend,
      },
    );

    if (response.status < 200 || response.status >= 300 || response.data == null) {
      throw Exception('Coach falhou (HTTP ${response.status})');
    }

    final data = jsonDecode(jsonEncode(response.data));
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Formato inesperado');
    }

    return CoachResponse.fromJson(data);
  }
}