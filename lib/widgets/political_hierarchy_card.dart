import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/constituency_model.dart';
import '../models/issue_model.dart';
import '../utils/cl_theme.dart';

/// Full Accountability card — matches Figma design.
/// Shows two sections:
///   1. Operational Responsibility (departments / authorities)
///   2. Elected Representatives (Corporator · MLA · MP)
class PoliticalHierarchyCard extends StatelessWidget {
  final ConstituencyInfo info;
  const PoliticalHierarchyCard({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    final hasDepts = info.departments.isNotEmpty;
    final hasReps =
        info.councillor != null || info.mla != null || info.mp != null;

    if (!hasDepts && !hasReps) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CL.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF16A34A), Color(0xFF2563EB)]),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.account_balance_rounded,
                      color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Accountability',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: CL.text1),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: CL.divider),

          // ── Operational Responsibility ───────────────────────────────
          if (hasDepts) ...[
            const _SectionHeader(label: 'Operational Responsibility'),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
              child: Column(
                children: info.departments
                    .map((d) => _DeptRow(dept: d))
                    .toList(),
              ),
            ),
          ],

          // ── Elected Representatives ──────────────────────────────────
          if (hasReps) ...[
            if (hasDepts) const Divider(height: 1, color: CL.divider),
            const _SectionHeader(label: 'Elected Representatives'),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              child: Column(
                children: [
                  if (info.councillor != null)
                    _RepRow(
                      rep: info.councillor!,
                      role: 'Corporator',
                      subtitle:
                          '${info.ward ?? info.city} · ${_bodyName(info.councillor!)}',
                      color: const Color(0xFF059669),
                    ),
                  if (info.mla != null)
                    _RepRow(
                      rep: info.mla!,
                      role: 'MLA',
                      subtitle: info.assemblyConstituency != null
                          ? '${info.assemblyConstituency} Constituency'
                          : 'State Assembly',
                      color: CL.purple,
                    ),
                  if (info.mp != null)
                    _RepRow(
                      rep: info.mp!,
                      role: 'MP',
                      subtitle: info.parliamentConstituency != null
                          ? '${info.parliamentConstituency} Lok Sabha'
                          : 'Lok Sabha',
                      color: CL.updateBlue,
                    ),
                ],
              ),
            ),
          ],

          // ── Footer note ──────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 14, color: Color(0xFFD97706)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'This issue falls under the jurisdiction of the above authorities and representatives.',
                    style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFFD97706),
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _bodyName(RepresentativeModel rep) {
    if (rep.party != null && rep.party!.isNotEmpty) return rep.party!;
    return 'Municipal Corp.';
  }
}

// ── Section header ────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: CL.text2,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ── Department row ────────────────────────────────────────────────────────────
class _DeptRow extends StatelessWidget {
  final AuthorityModel dept;
  const _DeptRow({required this.dept});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.account_balance_outlined,
                size: 18, color: CL.updateBlue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dept.name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: CL.text1),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(dept.department,
                    style: const TextStyle(fontSize: 11, color: CL.text3),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (dept.contactPhone != null)
            _ActionCircle(
              icon: Icons.call_outlined,
              color: const Color(0xFF059669),
              bg: const Color(0xFFDCFCE7),
              onTap: () => launchUrl(Uri.parse('tel:${dept.contactPhone}')),
            ),
          if (dept.contactEmail != null)
            _ActionCircle(
              icon: Icons.chat_bubble_outline_rounded,
              color: CL.updateBlue,
              bg: const Color(0xFFDBEAFE),
              onTap: () => launchUrl(Uri.parse('mailto:${dept.contactEmail}')),
            ),
        ],
      ),
    );
  }
}

// ── Representative row ────────────────────────────────────────────────────────
class _RepRow extends StatelessWidget {
  final RepresentativeModel rep;
  final String role;
  final String subtitle;
  final Color color;

  const _RepRow({
    required this.rep,
    required this.role,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          // Avatar
          Stack(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: color.withValues(alpha: 0.15),
                backgroundImage: rep.photoUrl != null
                    ? NetworkImage(rep.photoUrl!)
                    : null,
                child: rep.photoUrl == null
                    ? Text(
                        rep.name[0].toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: color,
                          fontSize: 16,
                        ),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    role,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 7,
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          // Name + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rep.name,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: CL.text1),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: CL.text3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Call + Chat buttons
          _ActionCircle(
            icon: Icons.call_outlined,
            color: const Color(0xFF059669),
            bg: const Color(0xFFDCFCE7),
            onTap: rep.contactPhone != null
                ? () => launchUrl(Uri.parse('tel:${rep.contactPhone}'))
                : null,
          ),
          _ActionCircle(
            icon: Icons.chat_bubble_outline_rounded,
            color: CL.updateBlue,
            bg: const Color(0xFFDBEAFE),
            onTap: rep.contactEmail != null
                ? () => launchUrl(Uri.parse('mailto:${rep.contactEmail}'))
                : null,
          ),
        ],
      ),
    );
  }
}

// ── Action circle button ──────────────────────────────────────────────────────
class _ActionCircle extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bg;
  final VoidCallback? onTap;

  const _ActionCircle({
    required this.icon,
    required this.color,
    required this.bg,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.only(left: 6),
        decoration: BoxDecoration(
          color: onTap != null ? bg : const Color(0xFFF3F4F6),
          shape: BoxShape.circle,
        ),
        child: Icon(icon,
            size: 15,
            color: onTap != null ? color : CL.text3),
      ),
    );
  }
}
