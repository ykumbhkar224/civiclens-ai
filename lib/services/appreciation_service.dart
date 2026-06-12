import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config/supabase_config.dart';
import '../models/appreciation_model.dart';

class AppreciationService {
  final _client = SupabaseConfig.client;
  static const _uuid = Uuid();

  Future<List<PublicOfficialModel>> fetchOfficials({String? city, String? department}) async {
    var query = _client
        .from('public_officials')
        .select()
        .order('appreciation_count', ascending: false);

    if (city != null) query = query.eq('city', city) as dynamic;
    if (department != null) query = query.eq('department', department) as dynamic;

    final data = await query as List<dynamic>;
    return data.map((e) => PublicOfficialModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<AppreciationModel>> fetchAppreciationsForOfficial(
    String officialId, {
    int limit = 20,
  }) async {
    final data = await _client
        .from('appreciations')
        .select()
        .eq('to_official_id', officialId)
        .eq('is_public', true)
        .order('created_at', ascending: false)
        .limit(limit) as List<dynamic>;
    return data.map((e) => AppreciationModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AppreciationModel> submitAppreciation({
    required String toOfficialId,
    required String officialName,
    required String officialRole,
    required String message,
    String? achievement,
    String? department,
    bool isPublic = true,
  }) async {
    final userId = _client.auth.currentUser!.id;
    final id = _uuid.v4();

    final payload = {
      'id': id,
      'from_user_id': userId,
      'to_official_id': toOfficialId,
      'official_name': officialName,
      'official_role': officialRole,
      'message': message,
      'achievement': achievement,
      'department': department,
      'is_public': isPublic,
      'like_count': 0,
      'created_at': DateTime.now().toIso8601String(),
    };

    final data = await _client
        .from('appreciations')
        .insert(payload)
        .select()
        .single();
    return AppreciationModel.fromJson(data);
  }

  Future<void> likeAppreciation(String appreciationId) async {
    await _client.rpc('increment_appreciation_like', params: {
      'appreciation_id': appreciationId,
    });
  }

  Future<List<AppreciationModel>> fetchRecentAppreciations({
    String? city,
    int limit = 20,
  }) async {
    var query = _client
        .from('appreciations')
        .select()
        .eq('is_public', true)
        .order('created_at', ascending: false)
        .limit(limit);

    if (city != null) {
      // Join via officials table
      query = query.eq('public_officials.city', city) as dynamic;
    }

    final data = await query as List<dynamic>;
    return data.map((e) => AppreciationModel.fromJson(e as Map<String, dynamic>)).toList();
  }
}
