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

  Future<void> signInWithEmail(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final response = await SupabaseConfig.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response.user;
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
      final response = await SupabaseConfig.client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName, 'city': city},
      );
      return response.user;
    });
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await SupabaseConfig.client.auth.signInWithOAuth(OAuthProvider.google);
      return SupabaseConfig.client.auth.currentUser;
    });
  }

  Future<void> signOut() async {
    await SupabaseConfig.client.auth.signOut();
    state = const AsyncValue.data(null);
  }

  Future<void> resetPassword(String email) async {
    await SupabaseConfig.client.auth.resetPasswordForEmail(email);
  }
}
