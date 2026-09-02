import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/meal_item.dart';

class FavoriteMeal {
  final String name;
  final String? imageUrl;
  final List<MealItem> items;

  const FavoriteMeal({
    required this.name,
    this.imageUrl,
    required this.items,
  });

  factory FavoriteMeal.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((e) => MealItem.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <MealItem>[];
    return FavoriteMeal(
      name: json['name'] as String? ?? 'Refeição',
      imageUrl: json['imageUrl'] as String?,
      items: items,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (imageUrl != null) 'imageUrl': imageUrl,
        'items': items.map((e) => e.toJson()).toList(),
      };
}

class FavoritesService {
  static const _key = 'favorite_meals';
  static const _maxFavorites = 10;

  Future<List<FavoriteMeal>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return [];
      return list
          .whereType<Map>()
          .map((e) => FavoriteMeal.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _save(List<FavoriteMeal> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(favorites.map((e) => e.toJson()).toList()),
    );
  }

  Future<bool> isFavorite(String name) async {
    final favorites = await load();
    return favorites.any((f) => f.name == name);
  }

  Future<List<FavoriteMeal>> toggle(FavoriteMeal meal) async {
    final favorites = await load();
    final exists = favorites.any((f) => f.name == meal.name);
    final updated = exists
        ? favorites.where((f) => f.name != meal.name).toList()
        : [meal, ...favorites].take(_maxFavorites).toList();
    await _save(updated);
    return updated;
  }
}