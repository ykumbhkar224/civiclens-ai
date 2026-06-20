import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_routes.dart';
import '../../utils/cl_theme.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.child});
  final Widget child;

  int _locationIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc.startsWith(AppRoutes.home)) return 0;
    if (loc.startsWith(AppRoutes.civicMap)) return 1;
    if (loc.startsWith(AppRoutes.appreciation)) return 3;
    if (loc.startsWith(AppRoutes.profile)) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idx = _locationIndex(context);

    return Scaffold(
      body: child,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _GreenFab(
        onTap: () => context.push(AppRoutes.submitReport),
      ),
      bottomNavigationBar: _NavBar(
        currentIndex: idx,
        onTap: (i) => switch (i) {
          0 => context.go(AppRoutes.home),
          1 => context.go(AppRoutes.civicMap),
          3 => context.go(AppRoutes.appreciation),
          4 => context.go(AppRoutes.profile),
          _ => null,
        },
      ),
    );
  }
}

// ── FAB ───────────────────────────────────────────────────────────────────────
class _GreenFab extends StatelessWidget {
  const _GreenFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: CL.green,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: CL.green.withValues(alpha: 0.40),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
      ),
    );
  }
}

// ── Bottom bar ────────────────────────────────────────────────────────────────
class _NavBar extends StatelessWidget {
  const _NavBar({required this.currentIndex, required this.onTap});
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 7,
      elevation: 8,
      shadowColor: Colors.black12,
      color: Colors.white,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _Tab(icon: Icons.home_outlined, activeIcon: Icons.home_rounded,
                label: 'Home', active: currentIndex == 0, onTap: () => onTap(0)),
            _Tab(icon: Icons.map_outlined, activeIcon: Icons.map_rounded,
                label: 'Map', active: currentIndex == 1, onTap: () => onTap(1)),
            const SizedBox(width: 56), // FAB gap
            _Tab(icon: Icons.access_time_outlined, activeIcon: Icons.access_time_filled_rounded,
                label: 'Activity', active: currentIndex == 3, onTap: () => onTap(3)),
            _Tab(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded,
                label: 'Profile', active: currentIndex == 4, onTap: () => onTap(4)),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(active ? activeIcon : icon,
                color: active ? CL.green : CL.text3, size: 24),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                  fontSize: 10,
                  color: active ? CL.green : CL.text3,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                )),
          ],
        ),
      ),
    );
  }
}
