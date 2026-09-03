import 'package:supabase_flutter/supabase_flutter.dart';

class ErrorReporter {
  final SupabaseClient _client;

  ErrorReporter(this._client);

  Future<void> report({
    required String action,
    required String message,
    String? stack,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      await _client.from('error_logs').insert({
        'user_id': ?userId,
        'action': action,
        'message': message.length > 2000 ? message.substring(0, 2000) : message,
        if (stack != null && stack.isNotEmpty)
          'stack': stack.length > 4000 ? stack.substring(0, 4000) : stack,
      });
    } catch (_) {
      // nunca bloquear a app por causa da telemetria
    }
  }
}