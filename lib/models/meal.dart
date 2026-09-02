import 'meal_item.dart';

class Meal {
  final String id;
  final String userId;
  final String? imageUrl;
  final String mealName;
  final int totalCalories;
  final DateTime consumedAt;
  final List<MealItem> items;

  const Meal({
    required this.id,
    required this.userId,
    this.imageUrl,
    this.mealName = 'Refeição',
    required this.totalCalories,
    required this.consumedAt,
    required this.items,
  });

  factory Meal.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((e) => MealItem.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <MealItem>[];

    return Meal(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      mealName: json['meal_name'] as String? ?? 'Refeição',
      totalCalories: (json['total_calories'] as num?)?.toInt() ?? 0,
      consumedAt: DateTime.tryParse(json['consumed_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      items: items,
    );
  }

  int get itemCount => items.length;
}