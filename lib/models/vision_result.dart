class VisionItem {
  final String name;
  final int calories;
  final double? protein;
  final double? carbs;
  final double? fat;
  final double? grams;
  final double? confidence;

  const VisionItem({
    required this.name,
    required this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.grams,
    this.confidence,
  });

  factory VisionItem.fromJson(Map<String, dynamic> json) {
    return VisionItem(
      name: json['name'] as String? ?? 'Desconhecido',
      calories: (json['calories'] as num?)?.toInt() ?? 0,
      protein: (json['protein'] as num?)?.toDouble(),
      carbs: (json['carbs'] as num?)?.toDouble(),
      fat: (json['fat'] as num?)?.toDouble(),
      grams: (json['grams'] as num?)?.toDouble(),
      confidence: (json['confidence'] as num?)?.toDouble(),
    );
  }
}

class VisionAnalysis {
  final String mealName;
  final List<VisionItem> items;
  final int totalCalories;
  final double? totalProtein;

  const VisionAnalysis({
    this.mealName = 'Refeição',
    required this.items,
    required this.totalCalories,
    this.totalProtein,
  });

  factory VisionAnalysis.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((e) => VisionItem.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <VisionItem>[];

    return VisionAnalysis(
      mealName: json['mealName'] as String? ?? 'Refeição',
      items: items,
      totalCalories: (json['totalCalories'] as num?)?.toInt() ??
          items.fold(0, (sum, item) => sum + item.calories),
      totalProtein: (json['totalProtein'] as num?)?.toDouble(),
    );
  }
}