import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import '../services/ai_coach_service.dart';
import '../services/custom_foods_repository.dart';
import '../services/error_reporter.dart';
import '../services/favorites_service.dart';
import '../services/food_search_service.dart';
import '../services/meal_repository.dart';
import '../services/profile_repository.dart';
import '../services/recent_foods_service.dart';
import '../services/vision_service.dart';
import '../services/weight_repository.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

final visionServiceProvider = Provider<VisionService>(
  (ref) => VisionService(ref.watch(supabaseProvider)),
);

final aiCoachServiceProvider = Provider<AiCoachService>(
  (ref) => AiCoachService(ref.watch(supabaseProvider)),
);

final mealRepositoryProvider = Provider<MealRepository>(
  (ref) => MealRepository(ref.watch(supabaseProvider)),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(supabaseProvider)),
);

final weightRepositoryProvider = Provider<WeightRepository>(
  (ref) => WeightRepository(ref.watch(supabaseProvider)),
);

final foodSearchServiceProvider = Provider<FoodSearchService>(
  (ref) => FoodSearchService(),
);

final recentFoodsServiceProvider = Provider<RecentFoodsService>(
  (ref) => RecentFoodsService(),
);

final favoritesServiceProvider = Provider<FavoritesService>(
  (ref) => FavoritesService(),
);

final customFoodsRepositoryProvider = Provider<CustomFoodsRepository>(
  (ref) => CustomFoodsRepository(ref.watch(supabaseProvider)),
);

final errorReporterProvider = Provider<ErrorReporter>(
  (ref) => ErrorReporter(ref.watch(supabaseProvider)),
);

final profileProvider = FutureProvider<Profile>((ref) async {
  final client = ref.watch(supabaseProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) throw Exception('Não autenticado');
  return ref.watch(profileRepositoryProvider).getOrCreate(userId);
});