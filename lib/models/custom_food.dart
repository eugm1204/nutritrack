class CustomFood {
  final String? id;
  final String name;
  final String? brand;
  final int kcalPer100g;
  final double? protein;
  final double? carbs;
  final double? fat;
  final double referenceGrams;

  const CustomFood({
    this.id,
    required this.name,
    this.brand,
    required this.kcalPer100g,
    this.protein,
    this.carbs,
    this.fat,
    this.referenceGrams = 100,
  });

  factory CustomFood.fromJson(Map<String, dynamic> json) {
    return CustomFood(
      id: json['id'] as String?,
      name: json['name'] as String? ?? 'Alimento',
      brand: json['brand'] as String?,
      kcalPer100g: (json['kcal_per_100g'] as num?)?.toInt() ?? 0,
      protein: (json['protein'] as num?)?.toDouble(),
      carbs: (json['carbs'] as num?)?.toDouble(),
      fat: (json['fat'] as num?)?.toDouble(),
      referenceGrams: (json['reference_grams'] as num?)?.toDouble() ?? 100,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'name': name,
        if (brand != null) 'brand': brand,
        'kcal_per_100g': kcalPer100g,
        if (protein != null) 'protein': protein,
        if (carbs != null) 'carbs': carbs,
        if (fat != null) 'fat': fat,
        'reference_grams': referenceGrams,
      };
}