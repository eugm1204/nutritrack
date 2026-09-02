class MealItem {
  final String name;
  final int calories;
  final double? grams;
  final double? confidence;
  final bool confirmed;

  const MealItem({
    required this.name,
    required this.calories,
    this.grams,
    this.confidence,
    this.confirmed = false,
  });

  factory MealItem.fromJson(Map<String, dynamic> json) {
    return MealItem(
      name: json['name'] as String? ?? 'Desconhecido',
      calories: (json['calories'] as num?)?.toInt() ?? 0,
      grams: (json['grams'] as num?)?.toDouble(),
      confidence: (json['confidence'] as num?)?.toDouble(),
      confirmed: json['confirmed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'calories': calories,
        if (grams != null) 'grams': grams,
        if (confidence != null) 'confidence': confidence,
        'confirmed': confirmed,
      };

  MealItem copyWith({
    String? name,
    int? calories,
    double? grams,
    bool? confirmed,
  }) {
    return MealItem(
      name: name ?? this.name,
      calories: calories ?? this.calories,
      grams: grams ?? this.grams,
      confidence: confidence,
      confirmed: confirmed ?? this.confirmed,
    );
  }
}