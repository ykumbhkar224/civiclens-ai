import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../models/issue_model.dart';
import '../utils/cl_theme.dart';

class IssueCard extends ConsumerWidget {
  const IssueCard({
    super.key,
    required this.issue,
    required this.onTap,
    this.onLike,
    this.onShare,
  });

  final IssueModel issue;
  final VoidCallback onTap;
  final VoidCallback? onLike;
  final VoidCallback? onShare;

  static IconData _categoryIcon(String cat) => switch (cat) {
        IssueCat.roads         => Icons.directions_car_rounded,
        IssueCat.water         => Icons.water_drop_rounded,
        IssueCat.electricity   => Icons.bolt_rounded,
        IssueCat.environment   => Icons.park_rounded,
        IssueCat.safety        => Icons.shield_rounded,
        IssueCat.infrastructure=> Icons.construction_rounded,
        IssueCat.transport     => Icons.directions_bus_rounded,
        IssueCat.healthcare    => Icons.local_hospital_rounded,
        IssueCat.publicService => Icons.account_balance_rounded,
        _                      => Icons.report_problem_rounded,
      };

  static Color _categoryColor(String cat) => switch (cat) {
        IssueCat.roads         => const Color(0xFFF59E0B),
        IssueCat.water         => const Color(0xFF2563EB),
        IssueCat.electricity   => const Color(0xFFF59E0B),
        IssueCat.environment   => CL.green,
        IssueCat.safety        => const Color(0xFFEF4444),
        IssueCat.infrastructure=> const Color(0xFF7C3AED),
        IssueCat.transport     => const Color(0xFF0891B2),
        IssueCat.healthcare    => const Color(0xFFEF4444),
        IssueCat.publicService => const Color(0xFF7C3AED),
        _                      => CL.text2,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ago = timeago.format(issue.createdAt, locale: 'en_short');
    final hasImage = issue.imageUrls.isNotEmpty;
    final statusColor = CL.statusColor(issue.status);
    final statusLabel = CL.statusLabel(issue.status).toUpperCase();
    final catColor = _categoryColor(issue.category);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Left image / placeholder ─────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: hasImage
                  ? CachedNetworkImage(
                      imageUrl: issue.imageUrls.first,
                      width: 88,
                      height: 110,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _ImagePlaceholder(
                          color: catColor, icon: _categoryIcon(issue.category)),
                      errorWidget: (_, __, ___) => _ImagePlaceholder(
                          color: catColor, icon: _categoryIcon(issue.category)),
                    )
                  : _ImagePlaceholder(
                      color: catColor, icon: _categoryIcon(issue.category)),
            ),

            // ── Right content ─────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row + status badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            issue.title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: CL.text1,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 7),

                    // Location
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            size: 12, color: CL.text3),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            issue.ward != null && issue.ward!.isNotEmpty
                                ? 'Ward ${issue.ward}, ${issue.city}'
                                : issue.city,
                            style: const TextStyle(
                                fontSize: 11, color: CL.text3),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 9),

                    // Votes + comments + time
                    Row(
                      children: [
                        GestureDetector(
                          onTap: onLike,
                          child: Row(
                            children: [
                              Icon(
                                issue.isLikedByMe
                                    ? Icons.thumb_up_rounded
                                    : Icons.thumb_up_outlined,
                                size: 13,
                                color: issue.isLikedByMe
                                    ? CL.green
                                    : CL.text2,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${issue.likeCount}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: issue.isLikedByMe
                                        ? CL.green
                                        : CL.text2,
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.chat_bubble_outline_rounded,
                            size: 13, color: CL.text2),
                        const SizedBox(width: 3),
                        Text('${issue.commentCount}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: CL.text2,
                                fontWeight: FontWeight.w500)),
                        const Spacer(),
                        Text(
                          ago,
                          style: const TextStyle(
                              fontSize: 11, color: CL.text3),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final Color color;
  final IconData icon;
  const _ImagePlaceholder({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 110,
      color: color.withValues(alpha: 0.08),
      child: Center(
        child: Icon(icon, color: color.withValues(alpha: 0.6), size: 30),
      ),
    );
  }
}
