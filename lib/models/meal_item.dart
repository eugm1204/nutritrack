class MealItem {
  final String name;
  final int calories;
  final double? protein;
  final double? carbs;
  final double? fat;
  final double? grams;
  final double? confidence;
  final bool confirmed;

  const MealItem({
    required this.name,
    required this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.grams,
    this.confidence,
    this.confirmed = false,
  });

  factory MealItem.fromJson(Map<String, dynamic> json) {
    return MealItem(
      name: json['name'] as String? ?? 'Desconhecido',
      calories: (json['calories'] as num?)?.toInt() ?? 0,
      protein: (json['protein'] as num?)?.toDouble(),
      carbs: (json['carbs'] as num?)?.toDouble(),
      fat: (json['fat'] as num?)?.toDouble(),
      grams: (json['grams'] as num?)?.toDouble(),
      confidence: (json['confidence'] as num?)?.toDouble(),
      confirmed: json['confirmed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'calories': calories,
        if (protein != null) 'protein': protein,
        if (carbs != null) 'carbs': carbs,
        if (fat != null) 'fat': fat,
        if (grams != null) 'grams': grams,
        if (confidence != null) 'confidence': confidence,
        'confirmed': confirmed,
      };

  MealItem copyWith({
    String? name,
    int? calories,
    double? protein,
    double? carbs,
    double? fat,
    double? grams,
    double? confidence,
    bool? confirmed,
  }) {
    return MealItem(
      name: name ?? this.name,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      grams: grams ?? this.grams,
      confidence: confidence ?? this.confidence,
      confirmed: confirmed ?? this.confirmed,
    );
  }

  double get totalProtein => protein ?? 0;
  double get totalCarbs => carbs ?? 0;
  double get totalFat => fat ?? 0;
}