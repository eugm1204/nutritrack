class Profile {
  final String id;
  final int dailyGoalCalories;
  final double? weightKg;
  final String objective;

  const Profile({
    required this.id,
    this.dailyGoalCalories = 2200,
    this.weightKg,
    this.objective = 'maintain',
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String? ?? '',
      dailyGoalCalories: (json['daily_goal_calories'] as num?)?.toInt() ?? 2200,
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      objective: json['objective'] as String? ?? 'maintain',
    );
  }

  Map<String, dynamic> toJson() => {
        'daily_goal_calories': dailyGoalCalories,
        if (weightKg != null) 'weight_kg': weightKg,
        'objective': objective,
      };
}

const objectiveLabels = {
  'lose': 'Perder peso',
  'maintain': 'Manter peso',
  'gain': 'Ganhar massa',
};