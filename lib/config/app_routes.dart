import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/report/report_detail_screen.dart';
import '../screens/report/submit_report_screen.dart';
import '../screens/appreciation/appreciation_screen.dart';
import '../screens/map/civic_map_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/ai_analysis/ai_analysis_screen.dart';

part 'app_routes.g.dart';

// Route name constants
class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const submitReport = '/report/submit';
  static const reportDetail = '/report/:id';
  static const appreciation = '/appreciation';
  static const civicMap = '/map';
  static const profile = '/profile';
  static const notifications = '/notifications';
  static const aiAnalysis = '/ai-analysis';
}

@riverpod
GoRouter appRouter(Ref ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final isAuthenticated = authState.valueOrNull != null;
      final isAuthRoute =
          state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register ||
          state.matchedLocation == AppRoutes.splash;

      if (!isAuthenticated && !isAuthRoute) return AppRoutes.login;
      if (isAuthenticated && state.matchedLocation == AppRoutes.login) {
        return AppRoutes.home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => HomeScreen(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const HomeTab(),
          ),
          GoRoute(
            path: AppRoutes.civicMap,
            builder: (context, state) => const CivicMapScreen(),
          ),
          GoRoute(
            path: AppRoutes.appreciation,
            builder: (context, state) => const AppreciationScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.submitReport,
        builder: (context, state) => const SubmitReportScreen(),
      ),
      GoRoute(
        path: AppRoutes.reportDetail,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ReportDetailScreen(reportId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.aiAnalysis,
        builder: (context, state) => const AiAnalysisScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.error}'),
      ),
    ),
  );
}
