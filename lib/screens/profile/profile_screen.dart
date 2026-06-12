import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/report_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final myReportsAsync = ref.watch(myReportsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Not signed in'),
              FilledButton(
                onPressed: () => context.go(AppRoutes.login),
                child: const Text('Sign In'),
              ),
            ],
          ),
        ),
      );
    }

    final name = user.userMetadata?['full_name'] as String? ?? user.email ?? 'User';
    final city = user.userMetadata?['city'] as String? ?? 'Unknown city';
    final initials = name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {/* TODO: settings */},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Avatar + name
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_city_outlined, size: 16, color: colorScheme.outline),
                    const SizedBox(width: 4),
                    Text(city, style: TextStyle(color: colorScheme.outline)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  user.email ?? '',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Stats row
          myReportsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const SizedBox.shrink(),
            data: (reports) {
              final resolved = reports.where((r) => r.status.name == 'resolved').length;
              return Row(
                children: [
                  _StatCard(
                    value: reports.length.toString(),
                    label: 'Reports',
                    icon: Icons.report_problem_outlined,
                    color: colorScheme.errorContainer,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    value: resolved.toString(),
                    label: 'Resolved',
                    icon: Icons.check_circle_outline,
                    color: colorScheme.secondaryContainer,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    value: '0',
                    label: 'Badges',
                    icon: Icons.military_tech_outlined,
                    color: colorScheme.tertiaryContainer,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          const Divider(),

          // My Reports section
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Text(
                  'My Reports',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton(onPressed: () {}, child: const Text('See all')),
              ],
            ),
          ),
          myReportsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (reports) {
              if (reports.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text('No reports yet'),
                  ),
                );
              }
              return Column(
                children: reports.take(5).map((r) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    child: Icon(Icons.report_outlined, color: colorScheme.primary, size: 20),
                  ),
                  title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(r.status.name.replaceAll('_', ' ')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(
                    AppRoutes.reportDetail.replaceFirst(':id', r.id),
                  ),
                )).toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout),
            title: const Text('Sign Out'),
            textColor: colorScheme.error,
            iconColor: colorScheme.error,
            onTap: () async {
              await ref.read(authNotifierProvider.notifier).signOut();
              if (context.mounted) context.go(AppRoutes.login);
            },
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        color: color,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            children: [
              Icon(icon, size: 28),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(label, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}
