import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';

import 'package:go_router/go_router.dart';

import '../../config/app_routes.dart';
import '../../models/issue_model.dart';
import '../../providers/constituency_provider.dart';
import '../../providers/issue_provider.dart';
import '../../services/issue_service.dart';
import '../../widgets/political_hierarchy_card.dart';

class IssueDetailScreen extends ConsumerStatefulWidget {
  final String issueId;
  const IssueDetailScreen({super.key, required this.issueId});

  @override
  ConsumerState<IssueDetailScreen> createState() => _IssueDetailScreenState();
}

class _IssueDetailScreenState extends ConsumerState<IssueDetailScreen> {
  final _commentCtrl = TextEditingController();
  final _commentFocus = FocusNode();
  int _imageIndex = 0;
  bool _isLiked = false;
  bool _isVerified = false;
  int _likeCount = 0;
  int _verifyCount = 0;
  bool _voteLoading = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  void _initFromDetail(IssueDetail detail) {
    _isLiked = detail.isLikedByMe;
    _isVerified = detail.isVerifiedByMe;
    _likeCount = detail.issue.likeCount;
    _verifyCount = detail.issue.verificationCount;
  }

  Future<void> _toggleLike(String issueId) async {
    if (_voteLoading) return;
    setState(() => _voteLoading = true);
    try {
      final isLiked = await ref.read(issueServiceProvider).toggleLike(issueId);
      setState(() {
        _isLiked = isLiked;
        _likeCount = (_likeCount + (isLiked ? 1 : -1)).clamp(0, 999999);
        _voteLoading = false;
      });
    } catch (_) {
      setState(() => _voteLoading = false);
    }
  }

  Future<void> _toggleVerify(String issueId) async {
    if (_voteLoading) return;
    setState(() => _voteLoading = true);
    try {
      final isVerified = await ref.read(issueServiceProvider).toggleVerify(issueId);
      setState(() {
        _isVerified = isVerified;
        _verifyCount = (_verifyCount + (isVerified ? 1 : -1)).clamp(0, 999999);
        _voteLoading = false;
      });
    } catch (_) {
      setState(() => _voteLoading = false);
    }
  }

  Future<void> _addComment(String issueId) async {
    final content = _commentCtrl.text.trim();
    if (content.isEmpty) return;
    _commentCtrl.clear();
    _commentFocus.unfocus();
    await ref.read(addCommentNotifierProvider.notifier).add(issueId, content);
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(issueDetailProvider(widget.issueId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return detailAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text('$e')),
      ),
      data: (detail) {
        // Init vote state from server (once)
        if (_likeCount == 0 && !_isLiked) _initFromDetail(detail);
        final issue = detail.issue;
        final hasImages = issue.imageUrls.isNotEmpty;

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // Collapsing header
              SliverAppBar(
                expandedHeight: hasImages ? 260 : 120,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: hasImages
                      ? Stack(
                          children: [
                            PageView.builder(
                              itemCount: issue.imageUrls.length,
                              onPageChanged: (i) => setState(() => _imageIndex = i),
                              itemBuilder: (_, i) => CachedNetworkImage(
                                imageUrl: issue.imageUrls[i],
                                fit: BoxFit.cover,
                                width: double.infinity,
                                placeholder: (_, __) => Container(
                                  color: const Color(0xFF1E293B),
                                  child: const Center(
                                      child: CircularProgressIndicator()),
                                ),
                                errorWidget: (_, __, ___) =>
                                    _GradientBanner(category: issue.category),
                              ),
                            ),
                            // Image counter dots
                            if (issue.imageUrls.length > 1)
                              Positioned(
                                bottom: 12,
                                left: 0,
                                right: 0,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(
                                    issue.imageUrls.length,
                                    (i) => AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      width: i == _imageIndex ? 20 : 7,
                                      height: 7,
                                      margin: const EdgeInsets.symmetric(horizontal: 3),
                                      decoration: BoxDecoration(
                                        color: i == _imageIndex
                                            ? Colors.white
                                            : Colors.white38,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        )
                      : _GradientBanner(category: issue.category),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.ios_share_rounded),
                    tooltip: 'Share',
                    onPressed: () =>
                        context.push(AppRoutes.shareCard, extra: issue),
                  ),
                ],
              ),

              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badges
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _Badge(
                            label: '${IssueCat.emoji(issue.category)} ${IssueCat.label(issue.category)}',
                            color: const Color(0xFF2563EB),
                          ),
                          _Badge(
                            label: IssueSev.label(issue.severity),
                            color: _sevColor(issue.severity),
                          ),
                          _Badge(
                            label: IssueStatus.label(issue.status),
                            color: _statusColor(issue.status),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Title
                      Text(
                        issue.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Author + time
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.2),
                            child: Text(
                              issue.isAnonymous
                                  ? '?'
                                  : (issue.userName?.isNotEmpty == true
                                      ? issue.userName![0].toUpperCase()
                                      : 'U'),
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            issue.isAnonymous ? 'Anonymous' : (issue.userName ?? 'Citizen'),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '· ${timeago.format(issue.createdAt)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Action buttons
                      Row(
                        children: [
                          _VoteButton(
                            icon: _isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                            label: '$_likeCount Like${_likeCount != 1 ? 's' : ''}',
                            active: _isLiked,
                            color: const Color(0xFF2563EB),
                            onTap: () => _toggleLike(issue.id),
                          ),
                          const SizedBox(width: 10),
                          _VoteButton(
                            icon: _isVerified
                                ? Icons.verified
                                : Icons.verified_outlined,
                            label: '$_verifyCount Verified',
                            active: _isVerified,
                            color: const Color(0xFF059669),
                            onTap: () => _toggleVerify(issue.id),
                          ),
                          const SizedBox(width: 10),
                          _VoteButton(
                            icon: Icons.chat_bubble_outline_rounded,
                            label: '${detail.comments.length}',
                            active: false,
                            color: Colors.grey,
                            onTap: () => _commentFocus.requestFocus(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 16),
                      // Description
                      const Text('Description',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(
                        issue.description,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Location
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 16, color: Color(0xFF2563EB)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              issue.address.isNotEmpty
                                  ? '${issue.address}, ${issue.city}'
                                  : issue.city,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (issue.ward != null && issue.ward!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.map_outlined,
                                size: 16, color: Color(0xFF7C3AED)),
                            const SizedBox(width: 6),
                            Text(
                              'Ward: ${issue.ward}',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ],

                      // AI summary
                      if (issue.aiSummary != null &&
                          issue.aiSummary!.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 16),
                        _AiCard(summary: issue.aiSummary!),
                      ],

                      // Civic hierarchy card
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 16),
                      const Text('Civic Representation',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      Consumer(builder: (context, ref, _) {
                        final args = (
                          city: issue.city,
                          district: null,
                          ward: issue.ward,
                          pincode: issue.pincode,
                          category: issue.category,
                        );
                        final infoAsync = ref.watch(constituencyLookupProvider(args));
                        return infoAsync.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (info) => info.hasData
                              ? PoliticalHierarchyCard(info: info)
                              : Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Text(
                                    'No representative data found for ${issue.city}.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? Colors.white38 : Colors.black38,
                                    ),
                                  ),
                                ),
                        );
                      }),

                      // Comments
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 16),
                      Text(
                        'Comments (${detail.comments.length})',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      if (detail.comments.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'No comments yet. Be the first!',
                              style: TextStyle(
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ),
                        )
                      else
                        ...detail.comments
                            .map((c) => _CommentTile(comment: c, isDark: isDark)),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentCtrl,
                      focusNode: _commentFocus,
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.05),
                      ),
                      onSubmitted: (_) => _addComment(issue.id),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Consumer(builder: (_, ref, __) {
                    final isSending =
                        ref.watch(addCommentNotifierProvider).isLoading;
                    return IconButton(
                      onPressed: isSending ? null : () => _addComment(issue.id),
                      icon: isSending
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: const CircleBorder(),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _sevColor(String s) => switch (s) {
    IssueSev.critical => const Color(0xFFDC2626),
    IssueSev.high     => const Color(0xFFEA580C),
    IssueSev.medium   => const Color(0xFFD97706),
    _                 => const Color(0xFF16A34A),
  };

  Color _statusColor(String s) => switch (s) {
    IssueStatus.resolved    => const Color(0xFF16A34A),
    IssueStatus.inProgress  => const Color(0xFF2563EB),
    IssueStatus.underReview => const Color(0xFF7C3AED),
    _                       => const Color(0xFFD97706),
  };
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _GradientBanner extends StatelessWidget {
  final String category;
  const _GradientBanner({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(IssueCat.emoji(category),
            style: const TextStyle(fontSize: 56)),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _VoteButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _VoteButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? color : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: active ? color : Colors.grey),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? color : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiCard extends StatelessWidget {
  final String summary;
  const _AiCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🤖', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI Analysis',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                const SizedBox(height: 4),
                Text(summary,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _CommentTile extends StatelessWidget {
  final CommentModel comment;
  final bool isDark;
  const _CommentTile({required this.comment, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.15),
            child: Text(
              comment.userName?.isNotEmpty == true
                  ? comment.userName![0].toUpperCase()
                  : 'U',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF7C3AED)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.userName ?? 'Citizen',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      timeago.format(comment.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.content,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.black54,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
