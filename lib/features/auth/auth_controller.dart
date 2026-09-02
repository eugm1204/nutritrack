import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/providers.dart';

class AuthState {
  final User? user;
  final bool loading;
  final String? error;
  final bool signupPendingEmail;

  const AuthState({
    this.user,
    this.loading = false,
    this.error,
    this.signupPendingEmail = false,
  });

  AuthState copyWith({
    User? user,
    bool? loading,
    String? error,
    bool? signupPendingEmail,
    bool clearError = false,
  }) {
    return AuthState(
      user: user ?? this.user,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      signupPendingEmail: signupPendingEmail ?? this.signupPendingEmail,
    );
  }
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    return AuthState(user: ref.watch(supabaseProvider).auth.currentUser);
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final session = await ref
          .read(supabaseProvider)
          .auth
          .signInWithPassword(email: email.trim(), password: password);
      state = AuthState(user: session.user);
      return true;
    } catch (e) {
      _log(e, 'login');
      state = state.copyWith(loading: false, error: _message(e));
      return false;
    }
  }

  Future<bool> signUp(String email, String password) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final response = await ref.read(supabaseProvider).auth.signUp(
            email: email.trim(),
            password: password,
          );

      if (response.session != null) {
        state = AuthState(user: response.user);
        return true;
      }

      state = state.copyWith(
        loading: false,
        signupPendingEmail: true,
        error: 'Conta criada! Verifica o teu email para confirmar e depois entra.',
      );
      return false;
    } catch (e) {
      _log(e, 'signup');
      state = state.copyWith(loading: false, error: _message(e));
      return false;
    }
  }

  Future<void> signOut() async {
    await ref.read(supabaseProvider).auth.signOut();
    state = AuthState();
  }

  void _log(Object e, String action) {
    debugPrint('[$action] Erro de autenticação: $e');
    if (e is AuthException) {
      debugPrint('[$action] Mensagem AuthException: ${e.message}');
      if (e is AuthApiException) {
        debugPrint('[$action] Status API: ${e.statusCode}');
      }
    }
  }

  String _message(Object e) {
    if (e is AuthException) {
      final msg = e.message;
      if (msg.contains('Invalid login credentials')) {
        return 'Email ou senha incorretos.';
      }
      if (msg.contains('Email not confirmed')) {
        return 'Confirma o teu email antes de entrar.';
      }
      if (msg.contains('already registered') || msg.contains('already been registered')) {
        return 'Este email já está registado. Tenta entrar.';
      }
      if (msg.contains('Password should be')) {
        return 'A senha deve ter pelo menos 6 caracteres.';
      }
      if (msg.contains('rate limit') || msg.contains('rate_limit')) {
        return 'Demasiadas tentativas. Espera alguns minutos e tenta de novo.';
      }
      if (msg.contains('Signups not allowed') ||
          msg.contains('signup') && msg.toLowerCase().contains('disabled')) {
        return 'O registo está desativado no momento.';
      }
      if (msg.contains('Invalid email') || msg.contains('invalid email')) {
        return 'Indica um email válido.';
      }
      if (msg.contains('Network') || msg.contains('connect')) {
        return 'Sem ligação à internet. Verifica a tua rede.';
      }
      return msg;
    }

    if (e is SocketException || e is http.ClientException) {
      return 'Sem ligação à internet. Verifica a tua rede.';
    }
    if (e is TimeoutException) {
      return 'A ligação demorou demasiado. Tenta de novo.';
    }

    debugPrint('Erro de auth não tratado: $e');
    return 'Ocorreu um erro. Tenta novamente.';
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);