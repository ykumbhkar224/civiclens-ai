import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/appreciation_model.dart';
import '../services/appreciation_service.dart';

part 'appreciation_provider.g.dart';

@riverpod
AppreciationService appreciationService(Ref ref) => AppreciationService();

@riverpod
Future<List<PublicOfficialModel>> officials(
  Ref ref, {
  String? city,
  String? department,
}) async {
  return ref
      .watch(appreciationServiceProvider)
      .fetchOfficials(city: city, department: department);
}

@riverpod
Future<List<AppreciationModel>> officialAppreciations(
  Ref ref,
  String officialId,
) async {
  return ref
      .watch(appreciationServiceProvider)
      .fetchAppreciationsForOfficial(officialId);
}

@riverpod
Future<List<AppreciationModel>> recentAppreciations(
  Ref ref, {
  String? city,
}) async {
  return ref
      .watch(appreciationServiceProvider)
      .fetchRecentAppreciations(city: city);
}

@riverpod
class SubmitAppreciationNotifier extends _$SubmitAppreciationNotifier {
  @override
  AsyncValue<AppreciationModel?> build() => const AsyncValue.data(null);

  Future<void> submit({
    required String toOfficialId,
    required String officialName,
    required String officialRole,
    required String message,
    String? achievement,
    String? department,
    bool isPublic = true,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(appreciationServiceProvider).submitAppreciation(
        toOfficialId: toOfficialId,
        officialName: officialName,
        officialRole: officialRole,
        message: message,
        achievement: achievement,
        department: department,
        isPublic: isPublic,
      ),
    );
  }

  void reset() => state = const AsyncValue.data(null);
}
