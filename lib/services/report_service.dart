import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config/supabase_config.dart';
import '../models/report_model.dart';

class ReportService {
  final _client = SupabaseConfig.client;
  static const _uuid = Uuid();

  Future<List<ReportModel>> fetchReports({
    String? city,
    ReportCategory? category,
    ReportStatus? status,
    int limit = 20,
    int offset = 0,
  }) async {
    // Build filter string for PostgREST
    var builder = _client.from('reports').select();
    if (city != null) builder = builder.eq('city', city);
    if (category != null) builder = builder.eq('category', category.name);
    if (status != null) builder = builder.eq('status', status.name);

    final data = await builder
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return (data as List<dynamic>)
        .map((e) => ReportModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ReportModel> fetchReportById(String id) async {
    final data = await _client.from('reports').select().eq('id', id).single();
    return ReportModel.fromJson(data);
  }

  Future<List<ReportModel>> fetchNearbyReports({
    required double latitude,
    required double longitude,
    double radiusKm = 5,
  }) async {
    // Uses PostGIS ST_DWithin via RPC
    final data = await _client.rpc('reports_within_radius', params: {
      'lat': latitude,
      'lng': longitude,
      'radius_km': radiusKm,
    }) as List<dynamic>;
    return data.map((e) => ReportModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ReportModel> submitReport({
    required String title,
    required String description,
    required ReportCategory category,
    required ReportSeverity severity,
    required double latitude,
    required double longitude,
    required String address,
    required String city,
    List<File>? images,
    List<String> tags = const [],
    String? department,
    String? aiSummary,
    bool isAnonymous = false,
  }) async {
    final userId = _client.auth.currentUser!.id;
    final reportId = _uuid.v4();

    final imageUrls = <String>[];
    if (images != null) {
      for (final image in images) {
        final ext = image.path.split('.').last;
        final path = 'reports/$reportId/${_uuid.v4()}.$ext';
        await _client.storage.from('civic-images').upload(path, image);
        final url = _client.storage.from('civic-images').getPublicUrl(path);
        imageUrls.add(url);
      }
    }

    final payload = {
      'id': reportId,
      'user_id': userId,
      'title': title,
      'description': description,
      'category': category.name,
      'severity': severity.name,
      'status': ReportStatus.pending.name,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'city': city,
      'image_urls': imageUrls,
      'tags': tags,
      'department': department,
      'ai_summary': aiSummary,
      'is_anonymous': isAnonymous,
      'upvote_count': 0,
      'created_at': DateTime.now().toIso8601String(),
    };

    final data = await _client.from('reports').insert(payload).select().single();
    return ReportModel.fromJson(data);
  }

  Future<void> upvoteReport(String reportId) async {
    await _client.rpc('increment_report_upvote', params: {'report_id': reportId});
  }

  Future<List<ReportModel>> fetchMyReports() async {
    final userId = _client.auth.currentUser!.id;
    final data = await _client
        .from('reports')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false) as List<dynamic>;
    return data.map((e) => ReportModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  RealtimeChannel subscribeToReportUpdates(
    String reportId,
    void Function(ReportModel) onUpdate,
  ) {
    return _client
        .channel('report_$reportId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'reports',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: reportId,
          ),
          callback: (payload) {
            onUpdate(ReportModel.fromJson(payload.newRecord));
          },
        )
        .subscribe();
  }
}
