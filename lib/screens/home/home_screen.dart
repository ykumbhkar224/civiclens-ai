import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_routes.dart';

class HomeScreen extends ConsumerWidget {
  final Widget child;
  const HomeScreen({super.key, required this.child});

  int _locationIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith(AppRoutes.home)) return 0;
    if (location.startsWith(AppRoutes.civicMap)) return 1;
    if (location.startsWith(AppRoutes.appreciation)) return 2;
    if (location.startsWith(AppRoutes.profile)) return 3;
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

// Placeholder for the home tab content
class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CivicLens AI'),
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
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Civic Score Card
                Card(
                  color: colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Icon(
                          Icons.emoji_events_rounded,
                          size: 48,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your Civic Score',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text(
                              '0',
                              style: Theme.of(
                                context,
                              ).textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Quick Stats Row
                Row(
                  children: [
                    _StatCard(
                      icon: Icons.report_problem_outlined,
                      label: 'Reports',
                      value: '0',
                      color: colorScheme.errorContainer,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      icon: Icons.check_circle_outline,
                      label: 'Resolved',
                      value: '0',
                      color: colorScheme.secondaryContainer,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      icon: Icons.star_outline,
                      label: 'Given',
                      value: '0',
                      color: colorScheme.tertiaryContainer,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Recent Reports',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                // Placeholder for recent reports list
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 64,
                          color: colorScheme.outline,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No reports yet',
                          style: TextStyle(color: colorScheme.outline),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.tonal(
                          onPressed: () =>
                              context.push(AppRoutes.submitReport),
                          child: const Text('Submit First Report'),
                        ),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
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
