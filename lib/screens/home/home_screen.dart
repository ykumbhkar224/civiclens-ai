import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../config/app_routes.dart';
import '../../models/report_model.dart';
import '../../providers/report_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/extensions.dart';

class HomeScreen extends ConsumerWidget {
  final Widget child;
  const HomeScreen({super.key, required this.child});

  int _locationIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc.startsWith(AppRoutes.home)) return 0;
    if (loc.startsWith(AppRoutes.civicMap)) return 1;
    if (loc.startsWith(AppRoutes.appreciation)) return 2;
    if (loc.startsWith(AppRoutes.profile)) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = _locationIndex(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: child,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.submitReport),
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Report Issue'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go(AppRoutes.home);
            case 1:
              context.go(AppRoutes.civicMap);
            case 2:
              context.go(AppRoutes.appreciation);
            case 3:
              context.go(AppRoutes.profile);
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.star_outline),
            selectedIcon: Icon(Icons.star),
            label: 'Appreciate',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final city = profileAsync.valueOrNull?.city ?? 'Mumbai';
    final reportsAsync = ref.watch(cityReportsProvider(city: city));

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.location_city_rounded, color: colorScheme.primary, size: 22),
            const SizedBox(width: 8),
            const Text('CivicLens AI'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push(AppRoutes.notifications),
          ),
          IconButton(
            icon: const Icon(Icons.psychology_outlined),
            onPressed: () => context.push(AppRoutes.aiAnalysis),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(userProfileProvider);
          ref.invalidate(cityReportsProvider(city: city));
        },
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Civic Score Card
                  profileAsync.when(
                    loading: () => const _ScoreCardSkeleton(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (profile) => _CivicScoreCard(
                      score: profile?.civicScore ?? 0,
                      name: profile?.fullName ?? 'Citizen',
                      city: profile?.city ?? city,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Stats Row
                  profileAsync.when(
                    loading: () => const _StatsRowSkeleton(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (profile) => _StatsRow(
                      reports: profile?.reportsSubmitted ?? 0,
                      resolved: profile?.reportsResolved ?? 0,
                      appreciations: profile?.appreciationsGiven ?? 0,
                    ),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Text(
                        'Recent Issues in $city',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => context.go(AppRoutes.civicMap),
                        child: const Text('View Map'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ]),
              ),
            ),

            // Reports feed
            reportsAsync.when(
              loading: () => const SliverToBoxAdapter(
                child: Center(child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                )),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Center(child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('Error loading reports: $e'),
                )),
              ),
              data: (reports) {
                if (reports.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Column(
                          children: [
                            Icon(Icons.inbox_outlined, size: 64, color: colorScheme.outline),
                            const SizedBox(height: 12),
                            Text('No reports in $city yet', style: TextStyle(color: colorScheme.outline)),
                            const SizedBox(height: 12),
                            FilledButton.tonal(
                              onPressed: () => context.push(AppRoutes.submitReport),
                              child: const Text('Be the first to report'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.builder(
                    itemCount: reports.length,
                    itemBuilder: (ctx, i) => _ReportTile(report: reports[i]),
                  ),
                );
              },
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
    );
  }
}

// ─── Civic Score Card ────────────────────────────────────────────────────────
class _CivicScoreCard extends StatelessWidget {
  final int score;
  final String name;
  final String city;

  const _CivicScoreCard({required this.score, required this.name, required this.city});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: cs.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.emoji_events_rounded, color: cs.onPrimary, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, ${name.split(' ').first}!',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Row(
                    children: [
                      Text(
                        '$score',
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('Civic Points', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: cs.outline),
                      const SizedBox(width: 2),
                      Text(city, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.outline)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stats Row ───────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final int reports;
  final int resolved;
  final int appreciations;

  const _StatsRow({required this.reports, required this.resolved, required this.appreciations});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        _StatCard(icon: Icons.report_problem_outlined, label: 'Reports', value: '$reports', color: cs.errorContainer),
        const SizedBox(width: 12),
        _StatCard(icon: Icons.check_circle_outline, label: 'Resolved', value: '$resolved', color: cs.secondaryContainer),
        const SizedBox(width: 12),
        _StatCard(icon: Icons.star_outline, label: 'Appreciated', value: '$appreciations', color: cs.tertiaryContainer),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        color: color,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, size: 24),
              const SizedBox(height: 4),
              Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              Text(label, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Report Tile ─────────────────────────────────────────────────────────────
class _ReportTile extends StatelessWidget {
  final ReportModel report;
  const _ReportTile({required this.report});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(AppRoutes.reportDetail.replaceFirst(':id', report.id)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: report.severity.color(cs).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(report.category.icon, color: report.severity.color(cs), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            report.title,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: report.status.color(cs).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            report.status.displayName,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: report.status.color(cs),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report.address,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.outline),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.thumb_up_outlined, size: 13, color: cs.outline),
                        const SizedBox(width: 3),
                        Text('${report.upvoteCount}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.outline)),
                        const SizedBox(width: 10),
                        Icon(Icons.schedule_outlined, size: 13, color: cs.outline),
                        const SizedBox(width: 3),
                        Text(timeago.format(report.createdAt), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.outline)),
                        if (report.imageUrls.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Icon(Icons.photo_outlined, size: 13, color: cs.outline),
                          const SizedBox(width: 3),
                          Text('${report.imageUrls.length}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.outline)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Skeletons ───────────────────────────────────────────────────────────────
class _ScoreCardSkeleton extends StatelessWidget {
  const _ScoreCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(width: 56, height: 56, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.2), shape: BoxShape.circle)),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 120, height: 14, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(7))),
                const SizedBox(height: 8),
                Container(width: 80, height: 32, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(7))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsRowSkeleton extends StatelessWidget {
  const _StatsRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (_) => Expanded(
        child: Card(
          child: Container(
            height: 80,
            decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
          ),
        ),
      )),
    );
  }
}
