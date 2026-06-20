import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/issue_model.dart';
import '../services/issue_service.dart';
import '../utils/constants.dart';

part 'issue_provider.g.dart';

@riverpod
IssueService issueService(Ref ref) => IssueService();

// ── Feed state ─────────────────────────────────────────────────────────────────
class FeedState {
  final List<IssueModel> issues;
  final int page;
  final bool hasMore;
  final bool isLoadingMore;
  final bool isRefreshing;
  final IssueFilter filter;
  final String? error;

  const FeedState({
    this.issues = const [],
    this.page = 0,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.filter = const IssueFilter(),
    this.error,
  });

  FeedState copyWith({
    List<IssueModel>? issues,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
    bool? isRefreshing,
    IssueFilter? filter,
    String? error,
    bool clearError = false,
  }) => FeedState(
    issues: issues ?? this.issues,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    filter: filter ?? this.filter,
    error: clearError ? null : (error ?? this.error),
  );
}

// ── Feed notifier (infinite scroll) ───────────────────────────────────────────
@riverpod
class FeedNotifier extends _$FeedNotifier {
  @override
  FeedState build() {
    Future.microtask(() => loadInitial());
    return const FeedState(isLoadingMore: true);
  }

  Future<void> loadInitial({IssueFilter? filter}) async {
    final f = filter ?? state.filter;
    state = FeedState(filter: f, isLoadingMore: true, isRefreshing: state.issues.isNotEmpty);
    try {
      final issues = await ref.read(issueServiceProvider).getFeed(page: 0, filter: f);
      state = FeedState(
        issues: issues,
        page: 0,
        hasMore: issues.length >= AppConstants.pageSize,
        filter: f,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, isRefreshing: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final next = state.page + 1;
      final more = await ref.read(issueServiceProvider).getFeed(
        page: next, filter: state.filter,
      );
      state = state.copyWith(
        issues: [...state.issues, ...more],
        page: next,
        hasMore: more.length >= AppConstants.pageSize,
        isLoadingMore: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  Future<void> refresh() => loadInitial(filter: state.filter);

  void applyFilter(IssueFilter filter) => loadInitial(filter: filter);

  // Optimistic update after like toggle
  void applyLikeToggle(String issueId, bool isLiked) {
    state = state.copyWith(
      issues: state.issues.map((i) => i.id == issueId
          ? i.copyWith(
              isLikedByMe: isLiked,
              likeCount: (i.likeCount + (isLiked ? 1 : -1)).clamp(0, 999999),
            )
          : i).toList(),
    );
  }
}

// ── Issue detail ───────────────────────────────────────────────────────────────
@riverpod
Future<IssueDetail> issueDetail(Ref ref, String issueId) async {
  return ref.read(issueServiceProvider).getIssueDetail(issueId);
}

// ── Create issue ───────────────────────────────────────────────────────────────
@riverpod
class CreateIssueNotifier extends _$CreateIssueNotifier {
  @override
  AsyncValue<IssueModel?> build() => const AsyncValue.data(null);

  Future<IssueModel?> submit(IssueFormData form) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(issueServiceProvider).createIssue(form),
    );
    if (state.hasValue && state.value != null) {
      ref.invalidate(feedNotifierProvider);
      ref.invalidate(myIssuesProvider);
    }
    return state.valueOrNull;
  }

  void reset() => state = const AsyncValue.data(null);
}

// ── Add comment ────────────────────────────────────────────────────────────────
@riverpod
class AddCommentNotifier extends _$AddCommentNotifier {
  @override
  AsyncValue<CommentModel?> build() => const AsyncValue.data(null);

  Future<void> add(String issueId, String content) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(issueServiceProvider).addComment(issueId, content),
    );
    if (state.hasValue) ref.invalidate(issueDetailProvider(issueId));
  }

  void reset() => state = const AsyncValue.data(null);
}

// ── Nearby issues for map (bounding box) ──────────────────────────────────────
@riverpod
Future<List<IssueModel>> nearbyIssues(
  Ref ref,
  ({double lat, double lng}) pos,
) async {
  return ref
      .read(issueServiceProvider)
      .getNearbyIssues(pos.lat, pos.lng, radiusKm: 15);
}

// ── My issues ──────────────────────────────────────────────────────────────────
@riverpod
Future<List<IssueModel>> myIssues(Ref ref) async {
  return ref.read(issueServiceProvider).getMyIssues();
}
