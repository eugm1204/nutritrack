import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/weight_entry.dart';

class WeightRepository {
  final SupabaseClient _client;

  WeightRepository(this._client);

  Future<List<WeightEntry>> fetchEntries(String userId) async {
    final rows = await _client
        .from('weight_entries')
        .select()
        .eq('user_id', userId)
        .order('recorded_at', ascending: true);

    return rows.map(WeightEntry.fromJson).toList();
  }

  Future<void> addEntry({
    required String userId,
    required double weightKg,
    required DateTime recordedAt,
  }) async {
    await _client.from('weight_entries').insert({
      'user_id': userId,
      'weight_kg': weightKg,
      'recorded_at': recordedAt.toUtc().toIso8601String(),
    });
  }

  Future<void> deleteEntry(String entryId, String userId) async {
    await _client
        .from('weight_entries')
        .delete()
        .eq('id', entryId)
        .eq('user_id', userId);
  }
}