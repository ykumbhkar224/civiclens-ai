import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/user_model.dart';
import '../services/user_service.dart';
import 'auth_provider.dart';

part 'user_provider.g.dart';

@riverpod
UserService userService(Ref ref) => UserService();

@riverpod
Future<UserModel?> userProfile(Ref ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ref.watch(userServiceProvider).fetchProfile(user.id);
}

@riverpod
class UserProfileNotifier extends _$UserProfileNotifier {
  @override
  AsyncValue<UserModel?> build() {
    // Seed initial value from cache
    final future = ref.watch(userProfileProvider.future);
    future.then((v) {
      if (state is AsyncLoading) state = AsyncValue.data(v);
    });
    return const AsyncValue.loading();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(userServiceProvider).fetchProfile(
            ref.read(currentUserProvider)!.id,
          ),
    );
  }

  Future<void> upsert({
    required String fullName,
    required String city,
    String? avatarUrl,
  }) async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(userServiceProvider).upsertProfile(
            userId: userId,
            fullName: fullName,
            city: city,
            avatarUrl: avatarUrl,
          ),
    );
  }
}
