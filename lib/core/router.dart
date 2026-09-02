import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/add_meal/add_meal_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/manual_add/manual_add_screen.dart';
import '../features/meal_detail/meal_detail_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/weight/weight_screen.dart';

final authStatusNotifier = ValueNotifier<bool>(false);

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
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),
    GoRoute(path: '/capture', builder: (context, state) => const AddMealScreen()),
    GoRoute(path: '/manual-add', builder: (context, state) => const ManualAddScreen()),
    GoRoute(
      path: '/meal',
      builder: (context, state) => MealDetailScreen(meal: state.extra! as dynamic),
    ),
    GoRoute(path: '/weight', builder: (context, state) => const WeightScreen()),
    GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
  ],
);