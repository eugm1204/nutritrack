import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/add_meal/add_meal_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/history/history_screen.dart';
import '../features/home/home_shell.dart';
import '../features/manual_add/manual_add_screen.dart';
import '../features/meal_detail/meal_detail_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/weight/weight_screen.dart';

final authStatusNotifier = ValueNotifier<bool>(false);

CustomTransitionPage<T> _fadeSlide<T>(Widget child) {
  return CustomTransitionPage<T>(
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

final appRouter = GoRouter(
  initialLocation: '/login',
  refreshListenable: authStatusNotifier,
  redirect: (context, state) {
    final loggedIn = authStatusNotifier.value;
    final atAuth = state.matchedLocation == '/login';

    if (!loggedIn && !atAuth) return '/login';
    if (loggedIn && atAuth) return '/';
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) => _fadeSlide(const LoginScreen()),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          HomeShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => _fadeSlide(const DashboardScreen()),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/history',
            pageBuilder: (context, state) => _fadeSlide(const HistoryScreen()),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/weight',
            pageBuilder: (context, state) => _fadeSlide(const WeightScreen()),
          ),
        ]),
      ],
    ),
    GoRoute(
      path: '/capture',
      pageBuilder: (context, state) => _fadeSlide(const AddMealScreen()),
    ),
    GoRoute(
      path: '/manual-add',
      pageBuilder: (context, state) => _fadeSlide(const ManualAddScreen()),
    ),
    GoRoute(
      path: '/meal',
      pageBuilder: (context, state) =>
          _fadeSlide(MealDetailScreen(meal: state.extra! as dynamic)),
    ),
    GoRoute(
      path: '/settings',
      pageBuilder: (context, state) => _fadeSlide(const SettingsScreen()),
    ),
  ],
);