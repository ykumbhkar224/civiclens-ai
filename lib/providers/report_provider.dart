import 'dart:io';
import 'package:latlong2/latlong.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/report_model.dart';
import '../services/gemini_service.dart';
import '../services/report_service.dart';

part 'report_provider.g.dart';

@riverpod
ReportService reportService(Ref ref) => ReportService();

@riverpod
GeminiService geminiService(Ref ref) => GeminiService();

@riverpod
Future<List<ReportModel>> cityReports(
  Ref ref, {
  required String city,
  ReportCategory? category,
  ReportStatus? status,
}) async {
  return ref.watch(reportServiceProvider).fetchReports(
    city: city,
    category: category,
    status: status,
  );
}

@riverpod
Future<ReportModel> reportDetail(Ref ref, String id) async {
  return ref.watch(reportServiceProvider).fetchReportById(id);
}

@riverpod
Future<List<ReportModel>> nearbyReports(Ref ref, LatLng location) async {
  return ref.watch(reportServiceProvider).fetchNearbyReports(
    latitude: location.latitude,
    longitude: location.longitude,
  );
}

@riverpod
Future<List<ReportModel>> myReports(Ref ref) async {
  return ref.watch(reportServiceProvider).fetchMyReports();
}

@riverpod
class SubmitReportNotifier extends _$SubmitReportNotifier {
  @override
  AsyncValue<ReportModel?> build() => const AsyncValue.data(null);

  Future<ReportModel?> submit({
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
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return ref.read(reportServiceProvider).submitReport(
        title: title,
        description: description,
        category: category,
        severity: severity,
        latitude: latitude,
        longitude: longitude,
        address: address,
        city: city,
        images: images,
        tags: tags,
        department: department,
        aiSummary: aiSummary,
        isAnonymous: isAnonymous,
      );
    });
    return state.valueOrNull;
  }

  void reset() => state = const AsyncValue.data(null);
}
