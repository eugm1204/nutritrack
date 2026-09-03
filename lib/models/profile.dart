class Profile {
  final String id;
  final int dailyGoalCalories;
  final double? weightKg;
  final String objective;
  final String? name;
  final DateTime? birthDate;
  final String? sex;
  final double? heightCm;
  final String? activityLevel;
  final double? targetWeightKg;
  final int? proteinGoalG;
  final int? carbsGoalG;
  final int? fatGoalG;
  final String? avatarUrl;
  final bool onboardingCompleted;

  const Profile({
    required this.id,
    this.dailyGoalCalories = 2200,
    this.weightKg,
    this.objective = 'maintain',
    this.name,
    this.birthDate,
    this.sex,
    this.heightCm,
    this.activityLevel,
    this.targetWeightKg,
    this.proteinGoalG,
    this.carbsGoalG,
    this.fatGoalG,
    this.avatarUrl,
    this.onboardingCompleted = false,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String? ?? '',
      dailyGoalCalories: (json['daily_goal_calories'] as num?)?.toInt() ?? 2200,
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      objective: json['objective'] as String? ?? 'maintain',
      name: json['name'] as String?,
      birthDate: json['birth_date'] != null
          ? DateTime.tryParse(json['birth_date'] as String)
          : null,
      sex: json['sex'] as String?,
      heightCm: (json['height_cm'] as num?)?.toDouble(),
      activityLevel: json['activity_level'] as String?,
      targetWeightKg: (json['target_weight_kg'] as num?)?.toDouble(),
      proteinGoalG: (json['protein_goal_g'] as num?)?.toInt(),
      carbsGoalG: (json['carbs_goal_g'] as num?)?.toInt(),
      fatGoalG: (json['fat_goal_g'] as num?)?.toInt(),
      avatarUrl: json['avatar_url'] as String?,
      onboardingCompleted: json['onboarding_completed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'daily_goal_calories': dailyGoalCalories,
        if (weightKg != null) 'weight_kg': weightKg,
        'objective': objective,
        if (name != null) 'name': name,
        if (birthDate != null)
          'birth_date':
              '${birthDate!.year}-${_two(birthDate!.month)}-${_two(birthDate!.day)}',
        if (sex != null) 'sex': sex,
        if (heightCm != null) 'height_cm': heightCm,
        if (activityLevel != null) 'activity_level': activityLevel,
        if (targetWeightKg != null) 'target_weight_kg': targetWeightKg,
        if (proteinGoalG != null) 'protein_goal_g': proteinGoalG,
        if (carbsGoalG != null) 'carbs_goal_g': carbsGoalG,
        if (fatGoalG != null) 'fat_goal_g': fatGoalG,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        'onboarding_completed': onboardingCompleted,
      };

  Profile copyWith({
    int? dailyGoalCalories,
    double? weightKg,
    String? objective,
    String? name,
    DateTime? birthDate,
    String? sex,
    double? heightCm,
    String? activityLevel,
    double? targetWeightKg,
    int? proteinGoalG,
    int? carbsGoalG,
    int? fatGoalG,
    String? avatarUrl,
    bool? onboardingCompleted,
  }) {
    return Profile(
      id: id,
      dailyGoalCalories: dailyGoalCalories ?? this.dailyGoalCalories,
      weightKg: weightKg ?? this.weightKg,
      objective: objective ?? this.objective,
      name: name ?? this.name,
      birthDate: birthDate ?? this.birthDate,
      sex: sex ?? this.sex,
      heightCm: heightCm ?? this.heightCm,
      activityLevel: activityLevel ?? this.activityLevel,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      proteinGoalG: proteinGoalG ?? this.proteinGoalG,
      carbsGoalG: carbsGoalG ?? this.carbsGoalG,
      fatGoalG: fatGoalG ?? this.fatGoalG,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}

const objectiveLabels = {
  'lose': 'Perder peso',
  'maintain': 'Manter peso',
  'gain': 'Ganhar massa',
};

const objectiveEmojis = {
  'lose': '🔻',
  'maintain': '⚖️',
  'gain': '💪',
};

const sexLabels = {
  'male': 'Masculino',
  'female': 'Feminino',
};

const activityLabels = {
  'sedentary': 'Sedentário (pouco exercício)',
  'light': 'Leve (1–3x por semana)',
  'moderate': 'Moderado (3–5x por semana)',
  'active': 'Ativo (6–7x por semana)',
};

const activityFactors = {
  'sedentary': 1.2,
  'light': 1.375,
  'moderate': 1.55,
  'active': 1.725,
};