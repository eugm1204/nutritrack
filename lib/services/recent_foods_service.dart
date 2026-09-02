import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/meal_item.dart';

class RecentFoodsService {
  static const _key = 'recent_foods';

  Future<List<MealItem>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return [];
      return list
          .whereType<Map>()
          .map((e) => MealItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(MealItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await load();
    final filtered = current
        .where((e) => e.name.toLowerCase() != item.name.toLowerCase())
        .toList();
    final updated = [item, ...filtered].take(10).toList();
    await prefs.setString(
      _key,
      jsonEncode(updated.map((e) => e.toJson()).toList()),
    );
  }
}