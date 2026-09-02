import 'package:cross_file/cross_file.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/meal.dart';
import '../models/meal_item.dart';

class MealRepository {
  final SupabaseClient _client;
  static const _bucket = 'meal-photos';
  static const _uuid = Uuid();

  MealRepository(this._client);

  Future<String> uploadMealPhoto(XFile file, String userId) async {
    final bytes = await file.readAsBytes();
    final ext = p.extension(file.name).isEmpty ? '.jpg' : p.extension(file.name);
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4()}$ext';

    await _client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: file.mimeType ?? 'image/jpeg',
            upsert: false,
          ),
        );

    return _client.storage.from(_bucket).getPublicUrl(path);
  }

  Future<Meal> insertMeal({
    required String userId,
    required String? imageUrl,
    required String mealName,
    required List<MealItem> items,
    required DateTime consumedAt,
  }) async {
    final total = items.fold<int>(0, (sum, item) => sum + item.calories);

    final row = await _client
        .from('meals')
        .insert({
          'user_id': userId,
          'image_url': imageUrl,
          'meal_name': mealName,
          'total_calories': total,
          'items': items.map((e) => e.toJson()).toList(),
          'consumed_at': consumedAt.toUtc().toIso8601String(),
        })
        .select()
        .single();

    return Meal.fromJson(row);
  }

  Future<List<Meal>> fetchMealsForDate(DateTime date, String userId) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    final rows = await _client
        .from('meals')
        .select()
        .eq('user_id', userId)
        .gte('consumed_at', start.toUtc().toIso8601String())
        .lt('consumed_at', end.toUtc().toIso8601String())
        .order('consumed_at', ascending: true);

    return rows.map(Meal.fromJson).toList();
  }

  Future<Map<DateTime, int>> fetchTotalsForRange(
    DateTime from,
    DateTime to,
    String userId,
  ) async {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day).add(const Duration(days: 1));

    final rows = await _client
        .from('meals')
        .select('total_calories, consumed_at')
        .eq('user_id', userId)
        .gte('consumed_at', start.toUtc().toIso8601String())
        .lt('consumed_at', end.toUtc().toIso8601String());

    final totals = <DateTime, int>{};
    for (final row in rows) {
      final day = DateTime.tryParse(row['consumed_at'] as String? ?? '')?.toLocal();
      if (day == null) continue;
      final key = DateTime(day.year, day.month, day.day);
      totals[key] = (totals[key] ?? 0) + ((row['total_calories'] as num?)?.toInt() ?? 0);
    }
    return totals;
  }

  Future<void> deleteMeal(String mealId, String userId) async {
    await _client
        .from('meals')
        .delete()
        .eq('id', mealId)
        .eq('user_id', userId);
  }
}