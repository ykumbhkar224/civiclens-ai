import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

@freezed
class UserModel with _$UserModel {
  const factory UserModel({
    required String id,
    required String email,
    required String fullName,
    required String city,
    String? avatarUrl,
    @Default(0) int reportsSubmitted,
    @Default(0) int reportsResolved,
    @Default(0) int appreciationsGiven,
    @Default(0) int civicScore,
    @Default('citizen') String role,
    DateTime? createdAt,
    @Default([]) List<String> badges,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);
}
