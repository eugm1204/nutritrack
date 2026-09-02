import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import '../services/meal_repository.dart';
import '../services/profile_repository.dart';
import '../services/vision_service.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

final visionServiceProvider = Provider<VisionService>(
  (ref) => VisionService(ref.watch(supabaseProvider)),
);

final mealRepositoryProvider = Provider<MealRepository>(
  (ref) => MealRepository(ref.watch(supabaseProvider)),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(supabaseProvider)),
);

final profileProvider = FutureProvider<Profile>((ref) async {
  final client = ref.watch(supabaseProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) throw Exception('Não autenticado');
  return ref.watch(profileRepositoryProvider).getOrCreate(userId);
});