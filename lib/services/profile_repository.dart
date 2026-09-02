import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';

class ProfileRepository {
  final SupabaseClient _client;

  ProfileRepository(this._client);

  Future<Profile> getOrCreate(String userId) async {
    final row = await _client.from('profiles').select().eq('id', userId).maybeSingle();

    if (row == null) {
      final inserted = await _client.from('profiles').insert({'id': userId}).select().single();
      return Profile.fromJson(inserted);
    }
    return Profile.fromJson(row);
  }

  Future<Profile> update(String userId, Profile profile) async {
    final row = await _client
        .from('profiles')
        .update(profile.toJson())
        .eq('id', userId)
        .select()
        .single();
    return Profile.fromJson(row);
  }
}