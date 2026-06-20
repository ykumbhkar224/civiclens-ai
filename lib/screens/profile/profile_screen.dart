import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/report_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/cl_theme.dart';

// Badge icon data
const _badgeIcons = [
  (Icons.shield_rounded, Color(0xFFFFD700), 'Civic Hero'),
  (Icons.campaign_rounded, Color(0xFF3B82F6), 'Reporter'),
  (Icons.verified_rounded, Color(0xFF16A34A), 'Verifier'),
  (Icons.change_circle_rounded, Color(0xFFF59E0B), 'Change Maker'),
];

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return Scaffold(
        backgroundColor: CL.bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_off_outlined,
                  size: 64, color: CL.text3),
              const SizedBox(height: 16),
              const Text('Not signed in',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: CL.text1)),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: CL.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 14),
                ),
                onPressed: () => context.go(AppRoutes.login),
                child: const Text('Sign In',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      );
    }

    final profileAsync = ref.watch(userProfileProvider);
    final myReportsAsync = ref.watch(myReportsProvider);

    final profile = profileAsync.valueOrNull;
    final name = profile?.fullName ??
        user.userMetadata?['full_name'] as String? ??
        user.email ??
        'Citizen';
    final city = profile?.city ??
        user.userMetadata?['city'] as String? ??
        'India';
    final civicScore = profile?.civicScore ?? 0;
    final badges = profile?.badges ?? [];
    final reportsTotal = profile?.reportsSubmitted ?? 0;
    final reportsResolved = profile?.reportsResolved ?? 0;
    final appreciations = profile?.appreciationsGiven ?? 0;

    final rank = civicScore > 500
        ? 'Civic Hero'
        : civicScore > 200
            ? 'Active Citizen'
            : civicScore > 50
                ? 'Contributor'
                : 'Newcomer';

    final initials = name
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    return Scaffold(
      backgroundColor: CL.bg,
      body: RefreshIndicator(
        color: CL.green,
        onRefresh: () async {
          ref.invalidate(userProfileProvider);
          ref.invalidate(myReportsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // ── Purple header ─────────────────────────────────────────────
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF5B21B6), Color(0xFF7C3AED)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      // Top bar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Row(
                          children: [
                            const Text(
                              'Profile',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Spacer(),
                            _HeaderIconBtn(
                              icon: Icons.settings_outlined,
                              onTap: () {},
                            ),
                            const SizedBox(width: 8),
                            _HeaderIconBtn(
                              icon: Icons.edit_outlined,
                              onTap: () {},
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Avatar + name
                      Column(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 44,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.2),
                                child: Text(
                                  initials,
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 2,
                                right: 2,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: CL.green,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check,
                                      color: Colors.white, size: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.verified_rounded,
                                  color: Colors.white70, size: 18),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.location_on_outlined,
                                  color: Colors.white60, size: 14),
                              const SizedBox(width: 3),
                              Text(city,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),

                      // ── Civic Points + Rank ──────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: _PurpleStatTile(
                                label: 'Civic Points',
                                value: _formatNumber(civicScore),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _PurpleStatTile(
                                label: 'Rank',
                                value: rank,
                                icon: Icons.emoji_events_rounded,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── My Badges ─────────────────────────────────────────────────
              _Section(
                child: Column(
                  children: [
                    _SectionHeader(
                      title: 'My Badges',
                      trailing: TextButton(
                        onPressed: () {},
                        child: const Text('View All',
                            style: TextStyle(color: CL.purple)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        for (int i = 0; i < _badgeIcons.length; i++)
                          _BadgeTile(
                            icon: _badgeIcons[i].$1,
                            color: _badgeIcons[i].$2,
                            label: _badgeIcons[i].$3,
                            earned: i < badges.length,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Stats row ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _StatCard(
                      value: '$reportsTotal',
                      label: 'Reports',
                      color: CL.issueRedBg,
                      iconColor: CL.issueRed,
                      icon: Icons.report_problem_rounded,
                    ),
                    const SizedBox(width: 10),
                    _StatCard(
                      value: '$reportsResolved',
                      label: 'Resolved',
                      color: CL.greenBg,
                      iconColor: CL.green,
                      icon: Icons.check_circle_rounded,
                    ),
                    const SizedBox(width: 10),
                    _StatCard(
                      value: '$appreciations',
                      label: 'Appreciated',
                      color: CL.purpleBg,
                      iconColor: CL.purple,
                      icon: Icons.thumb_up_rounded,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Menu items ────────────────────────────────────────────────
              _Section(
                child: Column(
                  children: [
                    _MenuItem(
                      icon: Icons.assignment_outlined,
                      label: 'My Reports',
                      onTap: () {},
                    ),
                    _MenuDivider(),
                    _MenuItem(
                      icon: Icons.star_outline_rounded,
                      label: 'My Appreciations',
                      onTap: () {},
                    ),
                    _MenuDivider(),
                    _MenuItem(
                      icon: Icons.people_outline_rounded,
                      label: 'Following',
                      onTap: () {},
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Recent Reports ────────────────────────────────────────────
              _Section(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                      title: 'Recent Reports',
                      trailing: TextButton(
                        onPressed: () {},
                        child: const Text('See all',
                            style: TextStyle(color: CL.green)),
                      ),
                    ),
                    myReportsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                            child: CircularProgressIndicator(color: CL.green)),
                      ),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (reports) {
                        if (reports.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.add_location_alt_outlined,
                                      size: 40,
                                      color: Colors.grey.shade300),
                                  const SizedBox(height: 8),
                                  const Text('No reports yet',
                                      style: TextStyle(color: CL.text2)),
                                ],
                              ),
                            ),
                          );
                        }
                        return Column(
                          children: reports.take(5).map((r) {
                            final statusColor =
                                CL.statusColor(r.status.name);
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 0, vertical: 2),
                              leading: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: CL.greenBg,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.report_outlined,
                                    color: CL.green, size: 22),
                              ),
                              title: Text(
                                r.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: CL.text1),
                              ),
                              subtitle: Row(
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    CL.statusLabel(r.status.name),
                                    style: TextStyle(
                                        color: statusColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                              trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                  color: CL.text3),
                              onTap: () => context.push(
                                AppRoutes.reportDetail
                                    .replaceFirst(':id', r.id),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Sign out ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: () async {
                    await ref
                        .read(authNotifierProvider.notifier)
                        .signOut();
                    if (context.mounted) context.go(AppRoutes.login);
                  },
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: CL.issueRed.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded,
                            color: CL.issueRed.withValues(alpha: 0.8),
                            size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Sign Out',
                          style: TextStyle(
                            color: CL.issueRed.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatNumber(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _HeaderIconBtn extends StatelessWidget {
  const _HeaderIconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _PurpleStatTile extends StatelessWidget {
  const _PurpleStatTile({
    required this.label,
    required this.value,
    this.icon,
  });
  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 4),
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: const Color(0xFFFFD700), size: 18),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: CL.text1)),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.earned,
  });
  final IconData icon;
  final Color color;
  final String label;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: earned
                ? color.withValues(alpha: 0.15)
                : Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(icon,
              color: earned ? color : Colors.grey.shade400, size: 28),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: earned ? CL.text1 : CL.text3,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
    required this.iconColor,
    required this.icon,
  });
  final String value;
  final String label;
  final Color color;
  final Color iconColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: iconColor)),
            Text(label,
                style:
                    const TextStyle(fontSize: 11, color: CL.text2)),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: CL.bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: CL.text2, size: 20),
            ),
            const SizedBox(width: 14),
            Text(label,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: CL.text1)),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded,
                color: CL.text3, size: 22),
          ],
        ),
      ),
    );
  }
}

class _MenuDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, color: CL.divider);
  }
}
