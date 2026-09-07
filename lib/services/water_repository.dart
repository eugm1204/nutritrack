import 'package:supabase_flutter/supabase_flutter.dart';

class WaterRepository {
  final SupabaseClient _client;

  WaterRepository(this._client);

  Future<int> fetchCups(String userId, DateTime date) async {
    final row = await _client
        .from('water_logs')
        .select('cups')
        .eq('user_id', userId)
        .eq('log_date', _dateKey(date))
        .maybeSingle();
    return (row?['cups'] as num?)?.toInt() ?? 0;
  }

  Future<void> setCups(String userId, DateTime date, int cups) async {
    await _client.from('water_logs').upsert({
      'user_id': userId,
      'log_date': _dateKey(date),
      'cups': cups,
    }, onConflict: 'user_id,log_date');
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${_two(d.month)}-${_two(d.day)}';

  static String _two(int n) => n.toString().padLeft(2, '0');
}