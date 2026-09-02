import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/providers.dart';

class AuthState {
  final User? user;
  final bool loading;
  final String? error;

  const AuthState({this.user, this.loading = false, this.error});

  AuthState copyWith({User? user, bool? loading, String? error, bool clearError = false}) {
    return AuthState(
      user: user ?? this.user,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
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
      state = state.copyWith(loading: false, error: _message(e));
      return false;
    }
  }

  Future<bool> signUp(String email, String password) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final session = await ref.read(supabaseProvider).auth.signUp(
            email: email.trim(),
            password: password,
          );
      state = AuthState(user: session.user);
      return true;
    } catch (e) {
      state = state.copyWith(loading: false, error: _message(e));
      return false;
    }
  }

  Future<void> signOut() async {
    await ref.read(supabaseProvider).auth.signOut();
    state = AuthState();
  }

  String _message(Object e) {
    final text = e.toString();
    if (text.contains('Invalid login credentials')) {
      return 'Email ou senha incorretos.';
    }
    if (text.contains('Email not confirmed')) {
      return 'Confirme o seu email antes de entrar.';
    }
    if (text.contains('already registered') || text.contains('already been registered')) {
      return 'Este email já está registado.';
    }
    if (text.contains('Password should be')) {
      return 'A senha deve ter pelo menos 6 caracteres.';
    }
    return 'Ocorreu um erro. Tenta novamente.';
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);