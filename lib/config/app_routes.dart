import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/auth/login_screen.dart';
import '../screens/auth/phone_otp_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/home/discovery_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/report/issue_detail_screen.dart';
import '../screens/report/report_issue_screen.dart';
import '../screens/report/share_card_screen.dart';
import '../screens/appreciation/appreciation_screen.dart';
import '../screens/map/civic_map_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/ai_analysis/ai_analysis_screen.dart';
import '../models/issue_model.dart';

part 'app_routes.g.dart';

class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const submitReport = '/report/submit';
  static const shareCard = '/report/share';
  static const reportDetail = '/report/:id';
  static const appreciation = '/appreciation';
  static const civicMap = '/map';
  static const profile = '/profile';
  static const notifications = '/notifications';
  static const aiAnalysis = '/ai-analysis';
  static const phoneOtp = '/phone-otp';
  static const issueDetail = '/issue/:id';

  static String issueDetailPath(String id) => '/issue/$id';
}

// ChangeNotifier that fires whenever Supabase auth state changes.
// Used as GoRouter's refreshListenable so the router re-evaluates
// its redirect without recreating the GoRouter instance.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier() {
    _subscription = Supabase.instance.client.auth.onAuthStateChange
        .listen((_) => notifyListeners());
  }

  late final dynamic _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final authNotifier = _AuthChangeNotifier();
  ref.onDispose(authNotifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final isAuthenticated =
          Supabase.instance.client.auth.currentSession != null;

      final loc = state.matchedLocation;
      final isAuthRoute = loc == AppRoutes.login ||
          loc == AppRoutes.register ||
          loc == AppRoutes.splash ||
          loc == AppRoutes.phoneOtp;

      // Only profile, appreciation, and notifications require login
      final isProtectedRoute = loc == AppRoutes.profile ||
          loc == AppRoutes.appreciation ||
          loc == AppRoutes.notifications;

      if (!isAuthenticated && isProtectedRoute) return AppRoutes.login;
      if (isAuthenticated && isAuthRoute) return AppRoutes.home;
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
      GoRoute(
        path: AppRoutes.phoneOtp,
        builder: (context, state) => const PhoneOtpScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => HomeScreen(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const DiscoveryScreen(),
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
        builder: (context, state) => const ReportIssueScreen(),
      ),
      GoRoute(
        path: AppRoutes.shareCard,
        builder: (context, state) {
          final issue = state.extra as IssueModel;
          return ShareCardScreen(issue: issue);
        },
      ),
      GoRoute(
        path: AppRoutes.issueDetail,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return IssueDetailScreen(issueId: id);
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
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
}
