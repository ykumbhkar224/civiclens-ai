import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config/supabase_config.dart';
import '../models/issue_model.dart';
import '../utils/constants.dart';

// Compound detail object returned by getIssueDetail()
class IssueDetail {
  final IssueModel issue;
  final List<CommentModel> comments;
  final List<AuthorityModel> authorities;
  final List<RepresentativeModel> representatives;
  final bool isLikedByMe;
  final bool isVerifiedByMe;

  const IssueDetail({
    required this.issue,
    this.comments = const [],
    this.authorities = const [],
    this.representatives = const [],
    this.isLikedByMe = false,
    this.isVerifiedByMe = false,
  });
}

class IssueFilter {
  final String? city;
  final String? category;
  final String? status;
  final bool nearMe;
  final double? userLat;
  final double? userLng;

  const IssueFilter({
    this.city,
    this.category,
    this.status,
    this.nearMe = false,
    this.userLat,
    this.userLng,
  });

  IssueFilter copyWith({
    String? city,
    String? category,
    String? status,
    bool? nearMe,
    double? userLat,
    double? userLng,
  }) => IssueFilter(
    city: city ?? this.city,
    category: category ?? this.category,
    status: status ?? this.status,
    nearMe: nearMe ?? this.nearMe,
    userLat: userLat ?? this.userLat,
    userLng: userLng ?? this.userLng,
  );
}

class IssueService {
  final _client = SupabaseConfig.client;
  static const _uuid = Uuid();

  // ── Upload helper (XFile → Supabase Storage, cross-platform) ─────────────
  Future<String> _uploadFile(XFile file, String issueId, {bool isVideo = false}) async {
    final bytes = await file.readAsBytes();
    final ext = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : (isVideo ? 'mp4' : 'jpg');
    final folder = isVideo ? 'videos' : 'images';
    final path = 'reports/$issueId/$folder/${_uuid.v4()}.$ext';
    final mime = file.mimeType ?? (isVideo ? 'video/mp4' : 'image/jpeg');
    await _client.storage.from(AppConstants.bucketCivicImages).uploadBinary(
      path, bytes,
      fileOptions: FileOptions(contentType: mime),
    );
    return _client.storage.from(AppConstants.bucketCivicImages).getPublicUrl(path);
  }

  // ── Create issue ──────────────────────────────────────────────────────────
  Future<IssueModel> createIssue(IssueFormData form) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final issueId = _uuid.v4();

    final imageUrls = <String>[];
    for (final p in form.photos) {
      imageUrls.add(await _uploadFile(p, issueId));
    }
    final videoUrls = <String>[];
    for (final v in form.videos) {
      videoUrls.add(await _uploadFile(v, issueId, isVideo: true));
    }

    final payload = {
      'id': issueId,
      'user_id': userId,
      'type': 'issue',
      'title': form.title,
      'description': form.description,
      'category': form.category,
      'severity': form.severity,
      'status': IssueStatus.pending,
      'latitude': form.latitude,
      'longitude': form.longitude,
      'address': form.address,
      'city': form.city,
      'ward': form.ward,
      'pincode': form.pincode,
      'image_urls': imageUrls,
      'video_urls': videoUrls,
      'ai_summary': form.aiSummary,
      'department': form.aiDepartment,
      'is_anonymous': form.isAnonymous,
      'like_count': 0,
      'comment_count': 0,
      'verification_count': 0,
      'upvote_count': 0,
      'created_at': DateTime.now().toIso8601String(),
    };

    final data = await _client.from('reports').insert(payload).select().single();
    return IssueModel.fromJson(data as Map<String, dynamic>);
  }

  // ── Paginated feed ────────────────────────────────────────────────────────
  Future<List<IssueModel>> getFeed({
    int page = 0,
    int pageSize = AppConstants.pageSize,
    IssueFilter? filter,
  }) async {
    final offset = page * pageSize;
    var query = _client.from('reports').select().eq('type', 'issue');

    if (filter?.city != null && filter!.city!.isNotEmpty) {
      query = query.eq('city', filter.city!);
    }
    if (filter?.category != null && filter!.category!.isNotEmpty) {
      query = query.eq('category', filter.category!);
    }
    if (filter?.status != null && filter!.status!.isNotEmpty) {
      query = query.eq('status', filter.status!);
    }

    final data = await query
        .order('created_at', ascending: false)
        .range(offset, offset + pageSize - 1) as List;

    return data.map((e) => IssueModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── Full issue detail + comments + votes ──────────────────────────────────
  Future<IssueDetail> getIssueDetail(String issueId) async {
    final issueData = await _client.from('reports').select().eq('id', issueId).single();
    final issue = IssueModel.fromJson(issueData as Map<String, dynamic>);

    final commentsData = await _client
        .from('issue_comments')
        .select()
        .eq('issue_id', issueId)
        .order('created_at', ascending: true) as List;
    final comments = commentsData
        .map((e) => CommentModel.fromJson(e as Map<String, dynamic>))
        .toList();

    bool isLikedByMe = false;
    bool isVerifiedByMe = false;
    final userId = _client.auth.currentUser?.id;
    if (userId != null) {
      final votes = await _client
          .from('issue_votes')
          .select('vote_type')
          .eq('issue_id', issueId)
          .eq('user_id', userId) as List;
      for (final v in votes) {
        if (v['vote_type'] == 'like') isLikedByMe = true;
        if (v['vote_type'] == 'verify') isVerifiedByMe = true;
      }
    }

    final authorities = await getAuthorities(issue.city, category: issue.category);
    final representatives = await getRepresentatives(issue.city, ward: issue.ward);

    return IssueDetail(
      issue: issue,
      comments: comments,
      authorities: authorities,
      representatives: representatives,
      isLikedByMe: isLikedByMe,
      isVerifiedByMe: isVerifiedByMe,
    );
  }

  // ── Toggle like (returns new isLiked state) ───────────────────────────────
  Future<bool> toggleLike(String issueId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');
    final existing = await _client
        .from('issue_votes')
        .select('id')
        .eq('issue_id', issueId)
        .eq('user_id', userId)
        .eq('vote_type', 'like')
        .maybeSingle();
    if (existing != null) {
      await _client
          .from('issue_votes')
          .delete()
          .eq('issue_id', issueId)
          .eq('user_id', userId)
          .eq('vote_type', 'like');
      return false;
    } else {
      await _client.from('issue_votes').insert(
          {'issue_id': issueId, 'user_id': userId, 'vote_type': 'like'});
      return true;
    }
  }

  // ── Toggle verify ─────────────────────────────────────────────────────────
  Future<bool> toggleVerify(String issueId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');
    final existing = await _client
        .from('issue_votes')
        .select('id')
        .eq('issue_id', issueId)
        .eq('user_id', userId)
        .eq('vote_type', 'verify')
        .maybeSingle();
    if (existing != null) {
      await _client
          .from('issue_votes')
          .delete()
          .eq('issue_id', issueId)
          .eq('user_id', userId)
          .eq('vote_type', 'verify');
      return false;
    } else {
      await _client.from('issue_votes').insert(
          {'issue_id': issueId, 'user_id': userId, 'vote_type': 'verify'});
      return true;
    }
  }

  // ── Add comment ───────────────────────────────────────────────────────────
  Future<CommentModel> addComment(String issueId, String content) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');
    final data = await _client.from('issue_comments').insert({
      'issue_id': issueId,
      'user_id': userId,
      'content': content.trim(),
    }).select().single();
    return CommentModel.fromJson(data as Map<String, dynamic>);
  }

  // ── Authorities for a city / category ────────────────────────────────────
  Future<List<AuthorityModel>> getAuthorities(String city, {String? category}) async {
    try {
      final data = await _client
          .from('authorities')
          .select()
          .eq('city', city)
          .order('name') as List;
      var list = data.map((e) => AuthorityModel.fromJson(e as Map<String, dynamic>)).toList();
      if (category != null) {
        list = list.where((a) => a.categories.isEmpty || a.categories.contains(category)).toList();
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  // ── Representatives for a city ────────────────────────────────────────────
  Future<List<RepresentativeModel>> getRepresentatives(String city, {String? ward}) async {
    try {
      final data = await _client
          .from('representatives')
          .select()
          .eq('city', city)
          .order('name') as List;
      return data.map((e) => RepresentativeModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Nearby issues by bounding box (for map) ──────────────────────────────
  Future<List<IssueModel>> getNearbyIssues(
    double lat,
    double lng, {
    double radiusKm = 15,
  }) async {
    // 1 degree ≈ 111 km
    final delta = radiusKm / 111.0;
    final data = await _client
        .from('reports')
        .select()
        .eq('type', 'issue')
        .gte('latitude', lat - delta)
        .lte('latitude', lat + delta)
        .gte('longitude', lng - delta)
        .lte('longitude', lng + delta)
        .order('created_at', ascending: false)
        .limit(200) as List;
    return data
        .map((e) => IssueModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── My issues ─────────────────────────────────────────────────────────────
  Future<List<IssueModel>> getMyIssues() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    final data = await _client
        .from('reports')
        .select()
        .eq('user_id', userId)
        .eq('type', 'issue')
        .order('created_at', ascending: false) as List;
    return data.map((e) => IssueModel.fromJson(e as Map<String, dynamic>)).toList();
  }
}
