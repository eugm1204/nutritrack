class WeightEntry {
  final String id;
  final double weightKg;
  final DateTime recordedAt;

  const WeightEntry({
    required this.id,
    required this.weightKg,
    required this.recordedAt,
  });

  factory WeightEntry.fromJson(Map<String, dynamic> json) {
    return WeightEntry(
      id: json['id'] as String? ?? '',
      weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 0,
      recordedAt: DateTime.tryParse(json['recorded_at'] as String? ?? '')
              ?.toLocal() ??
          DateTime.now(),
    );
  }
}