import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:image_picker/image_picker.dart';

part 'issue_model.freezed.dart';
part 'issue_model.g.dart';

// ── Category / severity / status constants ─────────────────────────────────────
class IssueCat {
  static const infrastructure = 'infrastructure';
  static const safety = 'safety';
  static const environment = 'environment';
  static const water = 'water';
  static const electricity = 'electricity';
  static const roads = 'roads';
  static const transport = 'transport';
  static const healthcare = 'healthcare';
  static const publicService = 'public_service';
  static const other = 'other';

  static const all = [
    infrastructure, safety, environment, water,
    electricity, roads, transport, healthcare, publicService, other,
  ];

  static String label(String c) => switch (c) {
    infrastructure  => 'Infrastructure',
    safety          => 'Safety',
    environment     => 'Environment',
    water           => 'Water',
    electricity     => 'Electricity',
    roads           => 'Roads',
    transport       => 'Transport',
    healthcare      => 'Healthcare',
    publicService   => 'Public Service',
    _               => 'Other',
  };

  static String emoji(String c) => switch (c) {
    infrastructure  => '🏗',
    safety          => '🚨',
    environment     => '🌳',
    water           => '💧',
    electricity     => '⚡',
    roads           => '🛣',
    transport       => '🚌',
    healthcare      => '🏥',
    publicService   => '🏛',
    _               => '📋',
  };
}

class IssueSev {
  static const low = 'low';
  static const medium = 'medium';
  static const high = 'high';
  static const critical = 'critical';

  static String label(String s) => switch (s) {
    low      => 'Low',
    medium   => 'Medium',
    high     => 'High',
    critical => 'Critical',
    _        => s,
  };
}

class IssueStatus {
  static const pending     = 'pending';
  static const underReview = 'under_review';
  static const inProgress  = 'in_progress';
  static const resolved    = 'resolved';
  static const closed      = 'closed';

  static String label(String s) => switch (s) {
    pending     => 'Open',
    underReview => 'Under Review',
    inProgress  => 'In Progress',
    resolved    => 'Resolved',
    closed      => 'Closed',
    _           => s,
  };
}

// ── Issue model (maps to reports table) ───────────────────────────────────────
@freezed
class IssueModel with _$IssueModel {
  const factory IssueModel({
    required String id,
    required String userId,
    @Default('issue')  String type,
    @Default(IssueCat.other) String category,
    @Default(IssueSev.medium) String severity,
    @Default(IssueStatus.pending) String status,
    required String title,
    required String description,
    required double latitude,
    required double longitude,
    required String address,
    required String city,
    String? ward,
    String? pincode,
    @Default([]) List<String> imageUrls,
    @Default([]) List<String> videoUrls,
    @Default(0) int likeCount,
    @Default(0) int commentCount,
    @Default(0) int verificationCount,
    @Default(0) int upvoteCount,
    @Default(false) bool isAnonymous,
    String? department,
    String? aiSummary,
    String? officialResponse,
    required DateTime createdAt,
    DateTime? updatedAt,
    DateTime? resolvedAt,
    // Populated by service; not in DB columns
    String? userName,
    String? userAvatarUrl,
    @Default(false) bool isLikedByMe,
    @Default(false) bool isVerifiedByMe,
  }) = _IssueModel;

  factory IssueModel.fromJson(Map<String, dynamic> json) =>
      _$IssueModelFromJson(json);
}

// ── Comment model ─────────────────────────────────────────────────────────────
@freezed
class CommentModel with _$CommentModel {
  const factory CommentModel({
    required String id,
    required String issueId,
    required String userId,
    required String content,
    required DateTime createdAt,
    DateTime? updatedAt,
    String? userName,
    String? userAvatarUrl,
  }) = _CommentModel;

  factory CommentModel.fromJson(Map<String, dynamic> json) =>
      _$CommentModelFromJson(json);
}

// ── Vote model ────────────────────────────────────────────────────────────────
@freezed
class VoteModel with _$VoteModel {
  const factory VoteModel({
    required String id,
    required String issueId,
    required String userId,
    required String voteType,
    required DateTime createdAt,
  }) = _VoteModel;

  factory VoteModel.fromJson(Map<String, dynamic> json) =>
      _$VoteModelFromJson(json);
}

// ── Authority model ───────────────────────────────────────────────────────────
@freezed
class AuthorityModel with _$AuthorityModel {
  const factory AuthorityModel({
    required String id,
    required String name,
    required String department,
    required String city,
    String? ward,
    String? contactEmail,
    String? contactPhone,
    String? websiteUrl,
    @Default([]) List<String> categories,
    required DateTime createdAt,
  }) = _AuthorityModel;

  factory AuthorityModel.fromJson(Map<String, dynamic> json) =>
      _$AuthorityModelFromJson(json);
}

// ── Representative model ──────────────────────────────────────────────────────
@freezed
class RepresentativeModel with _$RepresentativeModel {
  const factory RepresentativeModel({
    required String id,
    required String name,
    @Default('other') String type,
    String? party,
    required String constituency,
    required String city,
    String? ward,
    String? pincode,
    String? state,
    String? contactEmail,
    String? contactPhone,
    String? photoUrl,
    required String role,
    required DateTime createdAt,
  }) = _RepresentativeModel;

  factory RepresentativeModel.fromJson(Map<String, dynamic> json) =>
      _$RepresentativeModelFromJson(json);
}

// ── Form data passed between report screens ───────────────────────────────────
class IssueFormData {
  final String category;
  final String severity;
  final String title;
  final String description;
  final double latitude;
  final double longitude;
  final String address;
  final String city;
  final String? ward;
  final String? pincode;
  final List<XFile> photos;
  final List<XFile> videos;
  final bool isAnonymous;
  final String? aiSummary;
  final String? aiDepartment;

  const IssueFormData({
    required this.category,
    required this.severity,
    required this.title,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.city,
    this.ward,
    this.pincode,
    this.photos = const [],
    this.videos = const [],
    this.isAnonymous = false,
    this.aiSummary,
    this.aiDepartment,
  });

  IssueFormData copyWith({
    String? category,
    String? severity,
    String? title,
    String? description,
    double? latitude,
    double? longitude,
    String? address,
    String? city,
    String? ward,
    String? pincode,
    List<XFile>? photos,
    List<XFile>? videos,
    bool? isAnonymous,
    String? aiSummary,
    String? aiDepartment,
  }) => IssueFormData(
    category: category ?? this.category,
    severity: severity ?? this.severity,
    title: title ?? this.title,
    description: description ?? this.description,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    address: address ?? this.address,
    city: city ?? this.city,
    ward: ward ?? this.ward,
    pincode: pincode ?? this.pincode,
    photos: photos ?? this.photos,
    videos: videos ?? this.videos,
    isAnonymous: isAnonymous ?? this.isAnonymous,
    aiSummary: aiSummary ?? this.aiSummary,
    aiDepartment: aiDepartment ?? this.aiDepartment,
  );
}
