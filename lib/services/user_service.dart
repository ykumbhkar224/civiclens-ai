import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/user_model.dart';

class UserService {
  final _client = SupabaseConfig.client;

  Future<UserModel?> fetchProfile(String userId) async {
    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (data == null) return null;
      return UserModel.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<UserModel> upsertProfile({
    required String userId,
    required String fullName,
    required String city,
    String? avatarUrl,
  }) async {
    final data = await _client
        .from('profiles')
        .upsert({
          'id': userId,
          'full_name': fullName,
          'city': city,
          if (avatarUrl != null) 'avatar_url': avatarUrl,
        })
        .select()
        .single();
    return UserModel.fromJson(data);
  }

  Future<void> incrementCivicScore(String userId, int points) async {
    await _client.rpc('increment_civic_score', params: {
      'user_id': userId,
      'points': points,
    });
  }

  RealtimeChannel subscribeToProfile(
    String userId,
    void Function(UserModel) onUpdate,
  ) {
    return _client
        .channel('profile_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (payload) {
            onUpdate(UserModel.fromJson(payload.newRecord));
          },
        )
        .subscribe();
  }
}
