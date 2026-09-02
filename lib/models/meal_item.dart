class MealItem {
  final String name;
  final int calories;
  final double? protein;
  final double? carbs;
  final double? fat;
  final double? grams;
  final String? portionRef;
  final double? confidence;
  final bool confirmed;

  const MealItem({
    required this.name,
    required this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.grams,
    this.portionRef,
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
      portionRef: json['portionRef'] as String?,
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
        if (portionRef != null) 'portionRef': portionRef,
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
    String? portionRef,
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
      portionRef: portionRef ?? this.portionRef,
      confidence: confidence ?? this.confidence,
      confirmed: confirmed ?? this.confirmed,
    );
  }

  double get totalProtein => protein ?? 0;
  double get totalCarbs => carbs ?? 0;
  double get totalFat => fat ?? 0;

  MealItem scaledBy(double multiplier) {
    return MealItem(
      name: name,
      calories: (calories * multiplier).round(),
      protein: protein != null ? protein! * multiplier : null,
      carbs: carbs != null ? carbs! * multiplier : null,
      fat: fat != null ? fat! * multiplier : null,
      grams: grams != null ? grams! * multiplier : null,
      portionRef: portionRef,
      confidence: confidence,
      confirmed: confirmed,
    );
  }
}