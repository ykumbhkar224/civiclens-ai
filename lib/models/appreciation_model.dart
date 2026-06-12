import 'package:freezed_annotation/freezed_annotation.dart';

part 'appreciation_model.freezed.dart';
part 'appreciation_model.g.dart';

@freezed
class AppreciationModel with _$AppreciationModel {
  const factory AppreciationModel({
    required String id,
    required String fromUserId,
    required String toOfficialId,
    required String officialName,
    required String officialRole,
    required String message,
    required DateTime createdAt,
    String? achievement,
    String? department,
    @Default(0) int likeCount,
    @Default(false) bool isPublic,
  }) = _AppreciationModel;

  factory AppreciationModel.fromJson(Map<String, dynamic> json) =>
      _$AppreciationModelFromJson(json);
}

@freezed
class PublicOfficialModel with _$PublicOfficialModel {
  const factory PublicOfficialModel({
    required String id,
    required String name,
    required String role,
    required String department,
    required String city,
    String? avatarUrl,
    @Default(0) int appreciationCount,
    @Default(0) int resolvedIssues,
    @Default(0.0) double performanceScore,
  }) = _PublicOfficialModel;

  factory PublicOfficialModel.fromJson(Map<String, dynamic> json) =>
      _$PublicOfficialModelFromJson(json);
}
