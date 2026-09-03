import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/custom_food.dart';

class CustomFoodsRepository {
  final SupabaseClient _client;

  CustomFoodsRepository(this._client);

  Future<List<CustomFood>> fetch(String userId) async {
    final rows = await _client
        .from('custom_foods')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return rows.map(CustomFood.fromJson).toList();
  }

  Future<CustomFood> add(String userId, CustomFood food) async {
    final row = await _client
        .from('custom_foods')
        .insert({
          'user_id': userId,
          'name': food.name,
          if (food.brand != null) 'brand': food.brand,
          'kcal_per_100g': food.kcalPer100g,
          if (food.protein != null) 'protein': food.protein,
          if (food.carbs != null) 'carbs': food.carbs,
          if (food.fat != null) 'fat': food.fat,
          'reference_grams': food.referenceGrams,
        })
        .select()
        .single();

    return CustomFood.fromJson(row);
  }

  Future<void> delete(String foodId, String userId) async {
    await _client
        .from('custom_foods')
        .delete()
        .eq('id', foodId)
        .eq('user_id', userId);
  }
}