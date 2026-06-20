import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/constituency_model.dart';
import '../models/issue_model.dart';
import '../utils/category_theme.dart';

/// Fixed-size card (360 wide) suitable for widget-to-image capture.
/// Wrap in RepaintBoundary before capturing.
class IssueShareCard extends StatelessWidget {
  final IssueModel issue;
  final ConstituencyInfo? constituencyInfo;

  const IssueShareCard({
    super.key,
    required this.issue,
    this.constituencyInfo,
  });

  Color _sevColor(String s) => switch (s) {
        IssueSev.critical => const Color(0xFFDC2626),
        IssueSev.high => const Color(0xFFEA580C),
        IssueSev.medium => const Color(0xFFD97706),
        _ => const Color(0xFF16A34A),
      };

  @override
  Widget build(BuildContext context) {
    final info = constituencyInfo;

    return Container(
      width: 360,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 48,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Banner ──────────────────────────────────────────────────────
          issue.imageUrls.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: issue.imageUrls.first,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _GradientBanner(issue: issue),
                  placeholder: (_, __) => _GradientBanner(issue: issue),
                )
              : _GradientBanner(issue: issue),

          // ── Content ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badges
                Wrap(
                  spacing: 6,
                  children: [
                    _Badge(
                      label:
                          '${IssueCat.emoji(issue.category)} ${IssueCat.label(issue.category)}',
                      color: CategoryTheme.accent(issue.category),
                    ),
                    _Badge(
                      label: IssueSev.label(issue.severity),
                      color: _sevColor(issue.severity),
                    ),
                    _Badge(
                      label: IssueStatus.label(issue.status),
                      color: issue.status == IssueStatus.resolved
                          ? const Color(0xFF059669)
                          : const Color(0xFFD97706),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Title
                Text(
                  issue.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Location
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded,
                        size: 13, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        issue.address.isNotEmpty ? issue.address : issue.city,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF64748B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      DateFormat('d MMM y').format(issue.createdAt),
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),

                // ── Accountability section ──────────────────────────────
                if (info != null && info.hasData) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [
                                  Color(0xFF2563EB),
                                  Color(0xFF7C3AED)
                                ]),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.bolt_rounded,
                                  size: 12, color: Colors.white),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'ACCOUNTABLE OFFICIALS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF374151),
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (info.mla != null)
                          _OfficialRow(
                            icon: '🏛',
                            role: 'MLA',
                            name: info.mla!.name,
                            sub: info.assemblyConstituency,
                            color: const Color(0xFF7C3AED),
                          ),
                        if (info.mp != null)
                          _OfficialRow(
                            icon: '🇮🇳',
                            role: 'MP',
                            name: info.mp!.name,
                            sub: info.parliamentConstituency,
                            color: const Color(0xFF2563EB),
                          ),
                        if (info.councillor != null)
                          _OfficialRow(
                            icon: '🏘',
                            role: 'Councillor',
                            name: info.councillor!.name,
                            sub: issue.ward,
                            color: const Color(0xFF059669),
                          ),
                        if (info.departments.isNotEmpty)
                          _OfficialRow(
                            icon: '🏢',
                            role: 'Dept',
                            name: info.departments.first.department,
                            color: const Color(0xFFD97706),
                          ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // ── CivicLens branding footer ───────────────────────────
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1D4ED8), Color(0xFF6D28D9)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_city_rounded,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      const Text(
                        'CivicLens AI',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '#HoldThemAccountable',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _GradientBanner extends StatelessWidget {
  final IssueModel issue;
  const _GradientBanner({required this.issue});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: CategoryTheme.gradient(issue.category),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                IssueCat.emoji(issue.category),
                style: const TextStyle(fontSize: 52),
              ),
              const SizedBox(height: 4),
              Text(
                IssueCat.label(issue.category).toUpperCase(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OfficialRow extends StatelessWidget {
  final String icon;
  final String role;
  final String name;
  final String? sub;
  final Color color;

  const _OfficialRow({
    required this.icon,
    required this.role,
    required this.name,
    this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Center(
              child: Text(icon, style: const TextStyle(fontSize: 13)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$role: ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      TextSpan(
                        text: name,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ],
                  ),
                ),
                if (sub != null && sub!.isNotEmpty)
                  Text(
                    sub!,
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFF6B7280)),
                  ),
              ],
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
