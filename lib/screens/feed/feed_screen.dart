import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_routes.dart';
import '../../models/issue_model.dart';
import '../../providers/issue_provider.dart';
import '../../services/issue_service.dart';
import '../../widgets/issue_card.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final _scrollController = ScrollController();
  String? _activeStatus;
  String? _activeCategory;

  static const _statusFilters = [
    ('All', null),
    ('Open', IssueStatus.pending),
    ('In Progress', IssueStatus.inProgress),
    ('Resolved', IssueStatus.resolved),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(feedNotifierProvider.notifier).loadMore();
    }
  }

  void _applyFilter() {
    ref.read(feedNotifierProvider.notifier).applyFilter(
      IssueFilter(status: _activeStatus, category: _activeCategory),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(feedNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: () => ref.read(feedNotifierProvider.notifier).refresh(),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // App bar
          SliverAppBar(
            floating: true,
            snap: true,
            title: const Text(
              'Community Feed',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                onPressed: _showFilterSheet,
              ),
            ],
          ),

          // Status filter chips
          SliverToBoxAdapter(
            child: Container(
              height: 48,
              margin: const EdgeInsets.only(top: 4),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _statusFilters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final (label, value) = _statusFilters[i];
                  final selected = _activeStatus == value;
                  return FilterChip(
                    label: Text(label),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _activeStatus = value);
                      _applyFilter();
                    },
                    selectedColor: Theme.of(context).colorScheme.primary,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : null,
                      fontWeight: FontWeight.w600,
                    ),
                    showCheckmark: false,
                  );
                },
              ),
            ),
          ),

          // Category chips row
          if (_activeCategory != null || IssueCat.all.isNotEmpty)
            SliverToBoxAdapter(
              child: Container(
                height: 44,
                margin: const EdgeInsets.only(bottom: 4),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: IssueCat.all.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      final selected = _activeCategory == null;
                      return FilterChip(
                        label: const Text('All Categories'),
                        selected: selected,
                        onSelected: (_) {
                          setState(() => _activeCategory = null);
                          _applyFilter();
                        },
                        selectedColor: Theme.of(context).colorScheme.secondary,
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : null,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        showCheckmark: false,
                      );
                    }
                    final cat = IssueCat.all[i - 1];
                    final selected = _activeCategory == cat;
                    return FilterChip(
                      label: Text('${IssueCat.emoji(cat)} ${IssueCat.label(cat)}'),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _activeCategory = cat);
                        _applyFilter();
                      },
                      selectedColor: Theme.of(context).colorScheme.secondary,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : null,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      showCheckmark: false,
                    );
                  },
                ),
              ),
            ),

          // Loading initial
          if (feed.isLoadingMore && feed.issues.isEmpty)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),

          // Error state
          if (feed.error != null && feed.issues.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text(feed.error!, style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () => ref.read(feedNotifierProvider.notifier).refresh(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),

          // Empty state
          if (!feed.isLoadingMore && feed.issues.isEmpty && feed.error == null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🏙', style: TextStyle(fontSize: 56)),
                    const SizedBox(height: 12),
                    Text(
                      'No issues found',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Be the first to report an issue\nin your area',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Issue list
          if (feed.issues.isNotEmpty)
            SliverList.builder(
              itemCount: feed.issues.length,
              itemBuilder: (_, i) {
                final issue = feed.issues[i];
                return IssueCard(
                  issue: issue,
                  onTap: () => context.push(AppRoutes.issueDetailPath(issue.id)),
                  onLike: () async {
                    try {
                      final isLiked = await ref
                          .read(issueServiceProvider)
                          .toggleLike(issue.id);
                      ref
                          .read(feedNotifierProvider.notifier)
                          .applyLikeToggle(issue.id, isLiked);
                    } catch (_) {}
                  },
                );
              },
            ),

          // Load more indicator
          if (feed.isLoadingMore && feed.issues.isNotEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),

          // End of list
          if (!feed.hasMore && feed.issues.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'You\'ve seen all ${feed.issues.length} issues',
                    style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _FilterSheet(
        activeCategory: _activeCategory,
        activeStatus: _activeStatus,
        onApply: (cat, status) {
          setState(() {
            _activeCategory = cat;
            _activeStatus = status;
          });
          _applyFilter();
        },
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final String? activeCategory;
  final String? activeStatus;
  final void Function(String? category, String? status) onApply;

  const _FilterSheet({
    required this.activeCategory,
    required this.activeStatus,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String? _cat;
  late String? _status;

  @override
  void initState() {
    super.initState();
    _cat = widget.activeCategory;
    _status = widget.activeStatus;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filter Issues',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          const Text('Status', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _chip('All', null, _status, (v) => setState(() => _status = v)),
              _chip('Open', IssueStatus.pending, _status, (v) => setState(() => _status = v)),
              _chip('In Progress', IssueStatus.inProgress, _status, (v) => setState(() => _status = v)),
              _chip('Resolved', IssueStatus.resolved, _status, (v) => setState(() => _status = v)),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Category', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _chip('All', null, _cat, (v) => setState(() => _cat = v)),
              ...IssueCat.all.map((c) => _chip(
                '${IssueCat.emoji(c)} ${IssueCat.label(c)}', c, _cat,
                (v) => setState(() => _cat = v),
              )),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onApply(_cat, _status);
              },
              child: const Text('Apply Filters'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String? value, String? current, void Function(String?) onTap) {
    final selected = current == value;
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => onTap(value),
      selectedColor: Theme.of(context).colorScheme.primary,
      labelStyle: TextStyle(color: selected ? Colors.white : null, fontWeight: FontWeight.w600),
      showCheckmark: false,
    );
  }
}
