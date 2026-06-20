import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

part 'auth_provider.g.dart';

@riverpod
Stream<AuthState> authState(Ref ref) {
  return SupabaseConfig.client.auth.onAuthStateChange;
}

@riverpod
User? currentUser(Ref ref) {
  return SupabaseConfig.client.auth.currentUser;
}

@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  AsyncValue<User?> build() {
    return AsyncValue.data(SupabaseConfig.client.auth.currentUser);
  }

  // ── Email ──────────────────────────────────────────────────────────────────
  Future<void> signInWithEmail(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final res = await SupabaseConfig.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return res.user;
    });
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    required String city,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final res = await SupabaseConfig.client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName, 'city': city},
      );
      return res.user;
    });
  }

  // ── Phone OTP ──────────────────────────────────────────────────────────────
  Future<void> sendPhoneOtp(String phone) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await SupabaseConfig.client.auth.signInWithOtp(phone: phone);
      return null; // OTP sent — no session yet
    });
  }

  Future<void> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final res = await SupabaseConfig.client.auth.verifyOTP(
        phone: phone,
        token: token,
        type: OtpType.sms,
      );
      return res.user;
    });
  }

  // ── Google OAuth ───────────────────────────────────────────────────────────
  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final redirectTo = kIsWeb
          ? '${Uri.base.scheme}://${Uri.base.host}'
              '${Uri.base.port != 80 && Uri.base.port != 443 ? ':${Uri.base.port}' : ''}/'
          : 'io.supabase.civiclens://login-callback/';

      await SupabaseConfig.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectTo,
        authScreenLaunchMode: LaunchMode.platformDefault,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // ── Anonymous ──────────────────────────────────────────────────────────────
  Future<void> signInAnonymously() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final res = await SupabaseConfig.client.auth.signInAnonymously();
      return res.user;
    });
  }

  // ── Sign out ───────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await SupabaseConfig.client.auth.signOut();
    state = const AsyncValue.data(null);
  }

  Future<void> resetPassword(String email) async {
    await SupabaseConfig.client.auth.resetPasswordForEmail(email);
  }
}
