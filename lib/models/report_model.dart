import 'package:freezed_annotation/freezed_annotation.dart';

part 'report_model.freezed.dart';
part 'report_model.g.dart';

enum ReportCategory {
  infrastructure,
  environment,
  safety,
  public_service,
  appreciation,
  other,
}

enum ReportSeverity { low, medium, high, critical }

enum ReportStatus { pending, under_review, in_progress, resolved, closed }

@freezed
class ReportModel with _$ReportModel {
  const factory ReportModel({
    required String id,
    required String userId,
    required String title,
    required String description,
    required ReportCategory category,
    required ReportSeverity severity,
    required ReportStatus status,
    required double latitude,
    required double longitude,
    required String address,
    required String city,
    required DateTime createdAt,
    DateTime? updatedAt,
    DateTime? resolvedAt,
    @Default([]) List<String> imageUrls,
    @Default([]) List<String> tags,
    String? department,
    String? aiSummary,
    String? officialResponse,
    @Default(0) int upvoteCount,
    @Default(false) bool isAnonymous,
  }) = _ReportModel;

  factory ReportModel.fromJson(Map<String, dynamic> json) =>
      _$ReportModelFromJson(json);
}

@freezed
class ReportClassification with _$ReportClassification {
  const factory ReportClassification({
    required String category,
    required String severity,
    required String department,
    @Default([]) List<String> tags,
    @Default('') String summary,
  }) = _ReportClassification;

  factory ReportClassification.fromJson(Map<String, dynamic> json) =>
      _$ReportClassificationFromJson(json);
}
