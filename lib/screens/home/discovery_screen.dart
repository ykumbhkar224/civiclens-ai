import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/constituency_provider.dart';
import '../../providers/issue_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/issue_service.dart';
import '../../services/location_service.dart';
import '../../utils/cl_theme.dart';
import '../../widgets/issue_card.dart';

// Feed filter tabs matching Figma
enum _FeedTab { all, issues, appreciations, updates }

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final _scrollController = ScrollController();
  _FeedTab _tab = _FeedTab.all;
  String? _selectedCity;
  bool _locationLoading = false;

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

  Future<void> _useGPS() async {
    setState(() => _locationLoading = true);
    try {
      final pos = await LocationService.getCurrentLocation();
      if (pos == null) return;
      final geo =
          await LocationService.reverseGeocode(pos.latitude, pos.longitude);
      if (!mounted) return;
      if (geo == null) return;
      setState(() => _selectedCity = geo.city);
      ref.read(feedNotifierProvider.notifier).applyFilter(
            IssueFilter(city: geo.city),
          );
    } finally {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  void _applyTab(_FeedTab tab) {
    setState(() => _tab = tab);
    String? typeFilter;
    if (tab == _FeedTab.issues) typeFilter = 'issue';
    if (tab == _FeedTab.appreciations) typeFilter = 'appreciation';
    ref.read(feedNotifierProvider.notifier).applyFilter(
          IssueFilter(city: _selectedCity, category: typeFilter),
        );
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(feedNotifierProvider);
    final user = ref.watch(currentUserProvider);
    final isLoggedIn = user != null;

    return RefreshIndicator(
      color: CL.green,
      onRefresh: () => ref.read(feedNotifierProvider.notifier).refresh(),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // ── Sticky App Bar ────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            floating: false,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            toolbarHeight: 64,
            title: Row(
              children: [
                // CivicLens colourful icon
                _AppLogo(),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'CivicLens',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: CL.text1,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: CL.green,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            'AI',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      'See it. Report it. Change it.',
                      style: TextStyle(fontSize: 11, color: CL.text3),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              // Location chip
              GestureDetector(
                onTap: _locationLoading ? null : _useGPS,
                child: Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: CL.bg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_locationLoading)
                        const SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: CL.green),
                        )
                      else
                        const Icon(Icons.location_on_rounded,
                            size: 14, color: CL.green),
                      const SizedBox(width: 4),
                      Text(
                        _selectedCity ?? 'Near Me',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: CL.text1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Notification bell
              IconButton(
                icon: Stack(
                  children: [
                    const Icon(Icons.notifications_outlined,
                        color: CL.text1, size: 24),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: CL.issueRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
                onPressed: () => context.push(AppRoutes.notifications),
              ),
              const SizedBox(width: 4),
            ],
            // ── Filter tabs ─────────────────────────────────────────────────
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(52),
              child: Container(
                height: 52,
                color: Colors.white,
                child: Column(
                  children: [
                    Container(height: 1, color: CL.divider),
                    Expanded(
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        children: [
                          _FilterTab(
                            label: 'All',
                            active: _tab == _FeedTab.all,
                            onTap: () => _applyTab(_FeedTab.all),
                          ),
                          _FilterTab(
                            label: 'Issues',
                            active: _tab == _FeedTab.issues,
                            color: CL.issueRed,
                            onTap: () => _applyTab(_FeedTab.issues),
                          ),
                          _FilterTab(
                            label: 'Appreciations',
                            active: _tab == _FeedTab.appreciations,
                            color: CL.purple,
                            onTap: () => _applyTab(_FeedTab.appreciations),
                          ),
                          _FilterTab(
                            label: 'Updates',
                            active: _tab == _FeedTab.updates,
                            color: CL.updateBlue,
                            onTap: () => _applyTab(_FeedTab.updates),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Login CTA (if not logged in) ──────────────────────────────────
          if (!isLoggedIn)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [CL.green, CL.greenLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Sign in to report issues & track accountability',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => context.push(AppRoutes.login),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Sign In',
                          style: TextStyle(
                            color: CL.green,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Your Representatives strip ────────────────────────────────────
          SliverToBoxAdapter(
            child: _RepresentativesStrip(
              city: _selectedCity ??
                  ref.watch(userProfileProvider).valueOrNull?.city,
            ),
          ),

          // ── Section header ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Row(
                children: [
                  const Text(
                    'Recent Issues',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: CL.text1,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => context.push(AppRoutes.civicMap),
                    child: const Text(
                      'View Map',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: CL.green,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Loading / empty ───────────────────────────────────────────────
          if (feed.isLoadingMore && feed.issues.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: CL.green),
              ),
            ),

          if (!feed.isLoadingMore && feed.issues.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_city_outlined,
                        size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text(
                      _selectedCity != null
                          ? 'No issues found near $_selectedCity'
                          : 'No issues yet in your area',
                      style: const TextStyle(
                          color: CL.text2, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                        'Be the first to report a civic issue!',
                        style: TextStyle(color: CL.text3, fontSize: 13)),
                  ],
                ),
              ),
            ),

          // ── Feed ─────────────────────────────────────────────────────────
          if (feed.issues.isNotEmpty)
            SliverList.builder(
              itemCount: feed.issues.length,
              itemBuilder: (_, i) {
                final issue = feed.issues[i];
                return IssueCard(
                  issue: issue,
                  onTap: () =>
                      context.push(AppRoutes.issueDetailPath(issue.id)),
                  onLike: () async {
                    try {
                      final liked = await ref
                          .read(issueServiceProvider)
                          .toggleLike(issue.id);
                      ref
                          .read(feedNotifierProvider.notifier)
                          .applyLikeToggle(issue.id, liked);
                    } catch (_) {}
                  },
                  onShare: () =>
                      context.push(AppRoutes.shareCard, extra: issue),
                );
              },
            ),

          // ── Loading more ──────────────────────────────────────────────────
          if (feed.isLoadingMore && feed.issues.isNotEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                    child: CircularProgressIndicator(color: CL.green)),
              ),
            ),

          if (!feed.hasMore && feed.issues.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    '${feed.issues.length} reports loaded',
                    style: const TextStyle(color: CL.text3, fontSize: 13),
                  ),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 90)),
        ],
      ),
    );
  }
}

// ─── App logo ────────────────────────────────────────────────────────────────
class _AppLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: CL.green,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.grid_view_rounded, color: Colors.white, size: 20),
    );
  }
}

// ─── Representatives strip ───────────────────────────────────────────────────
class _RepresentativesStrip extends ConsumerWidget {
  final String? city;
  const _RepresentativesStrip({this.city});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (city == null || city!.isEmpty) return const SizedBox.shrink();

    final args = (
      city: city!,
      district: null,
      ward: null,
      pincode: null,
      category: null,
    );
    final infoAsync = ref.watch(constituencyLookupProvider(args));

    return infoAsync.when(
      loading: () => const SizedBox(
          height: 80,
          child: Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: CL.green))),
      error: (_, __) => const SizedBox.shrink(),
      data: (info) {
        // (role, name, party, color, photoUrl)
        final reps = <(String, String, String?, Color, String?)>[];
        if (info.councillor != null) {
          reps.add(('Corporator', info.councillor!.name,
              info.councillor!.party, const Color(0xFF059669),
              info.councillor!.photoUrl));
        }
        if (info.mla != null) {
          reps.add(('MLA', info.mla!.name, info.mla!.party, CL.purple,
              info.mla!.photoUrl));
        }
        if (info.mp != null) {
          reps.add(('MP', info.mp!.name, info.mp!.party, CL.updateBlue,
              info.mp!.photoUrl));
        }

        if (reps.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Row(
                children: [
                  const Text(
                    'Your Representatives',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: CL.text1,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: CL.greenBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      city!,
                      style: const TextStyle(
                          fontSize: 11,
                          color: CL.green,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 192,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: reps.length,
                itemBuilder: (_, i) {
                  final (role, name, party, color, photoUrl) = reps[i];
                  final rep = role == 'Corporator'
                      ? info.councillor!
                      : role == 'MLA'
                          ? info.mla!
                          : info.mp!;
                  return _RepCard(
                    role: role,
                    name: name,
                    party: party,
                    color: color,
                    photoUrl: photoUrl,
                    onTap: () =>
                        _showPoliticianProfile(context, role, rep, info, color),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showPoliticianProfile(
    BuildContext context,
    String role,
    dynamic rep,
    dynamic info,
    Color color,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PoliticianSheet(
        role: role,
        rep: rep,
        info: info,
        color: color,
      ),
    );
  }
}

class _RepCard extends StatelessWidget {
  final String role;
  final String name;
  final String? party;
  final String? photoUrl;
  final Color color;
  final VoidCallback onTap;

  const _RepCard({
    required this.role,
    required this.name,
    required this.party,
    required this.photoUrl,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 155,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Photo area with role badge overlay ───────────────────────────
            Stack(
              children: [
                // Photo / avatar background
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Container(
                    height: 118,
                    width: double.infinity,
                    color: color.withValues(alpha: 0.08),
                    child: photoUrl != null
                        ? Image.network(
                            photoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _AvatarFallback(name: name, color: color),
                          )
                        : _AvatarFallback(name: name, color: color),
                  ),
                ),
                // Role badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      role.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // ── Name & party ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: CL.text1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (party != null && party!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      party!,
                      style: TextStyle(
                        fontSize: 11,
                        color: color.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Default avatar shown when no photo is available
class _AvatarFallback extends StatelessWidget {
  final String name;
  final Color color;
  const _AvatarFallback({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 66,
        height: 66,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            name[0].toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Politician profile bottom sheet ─────────────────────────────────────────
class _PoliticianSheet extends StatelessWidget {
  final String role;
  final dynamic rep;
  final dynamic info;
  final Color color;

  const _PoliticianSheet({
    required this.role,
    required this.rep,
    required this.info,
    required this.color,
  });

  String get _roleFullLabel => switch (role) {
        'Corporator' => 'Corporator (Local Govt)',
        'MLA' => 'MLA (State Govt)',
        _ => 'MP (Central Govt)',
      };

  String? get _constituency => role == 'MLA'
      ? info.assemblyConstituency as String?
      : role == 'MP'
          ? info.parliamentConstituency as String?
          : info.ward as String?;

  String get _jurisdictionLabel => switch (role) {
        'Corporator' => 'Ward No. ${info.ward ?? _constituency ?? '-'}',
        'MLA' => 'State Legislature',
        _ => 'Lok Sabha',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ──────────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Green header ─────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            color: color,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Role chip + share
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.65),
                            width: 1.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _roleFullLabel,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.share_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Photo + name/party (horizontal)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Square photo with rounded corners
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 80,
                            height: 80,
                            color: Colors.white.withValues(alpha: 0.2),
                            child: rep.photoUrl != null
                                ? Image.network(
                                    rep.photoUrl as String,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _SheetAvatarFallback(
                                            name: rep.name as String),
                                  )
                                : _SheetAvatarFallback(
                                    name: rep.name as String),
                          ),
                        ),
                        // Verified badge
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.verified_rounded,
                                color: color, size: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),

                    // Name + party
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            rep.name as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (rep.party != null &&
                              (rep.party as String).isNotEmpty)
                            Row(
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade400,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.people_rounded,
                                      size: 13, color: Colors.white),
                                ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    rep.party as String,
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.9),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 2,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── White body ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                // Constituency + Jurisdiction cards (side by side)
                Row(
                  children: [
                    Expanded(
                      child: _InfoCard(
                        label: 'CONSTITUENCY',
                        value: _constituency ?? (info.city as String),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InfoCard(
                        label: 'JURISDICTION',
                        value: _jurisdictionLabel,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Contact pills: Call | WhatsApp | Email
                Row(
                  children: [
                    Expanded(
                      child: _PillBtn(
                        icon: Icons.call_rounded,
                        label: 'Call',
                        color: CL.updateBlue,
                        bg: const Color(0xFFEFF6FF),
                        onTap: rep.contactPhone != null
                            ? () => _launch('tel:${rep.contactPhone}')
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _PillBtn(
                        icon: Icons.chat_rounded,
                        label: 'WhatsApp',
                        color: const Color(0xFF25D366),
                        bg: const Color(0xFFDCFCE7),
                        onTap: rep.contactPhone != null
                            ? () => _launch(
                                'https://wa.me/${rep.contactPhone}')
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _PillBtn(
                        icon: Icons.email_rounded,
                        label: 'Email',
                        color: CL.updateBlue,
                        bg: const Color(0xFFEFF6FF),
                        onTap: rep.contactEmail != null
                            ? () => _launch('mailto:${rep.contactEmail}')
                            : null,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Report issue CTA — outlined box
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    context.push(AppRoutes.submitReport);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: color.withValues(alpha: 0.45), width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.report_problem_outlined,
                            color: color, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Report Issue to This Representative',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(
                    height: MediaQuery.of(context).padding.bottom + 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }
}

// Fallback avatar inside the bottom sheet header
class _SheetAvatarFallback extends StatelessWidget {
  final String name;
  const _SheetAvatarFallback({required this.name});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        name[0].toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 30,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// Two-column info card (CONSTITUENCY / JURISDICTION)
class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  const _InfoCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CL.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: CL.text3,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: CL.text1,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// Pill-shaped contact action button
class _PillBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  final VoidCallback? onTap;

  const _PillBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: active ? bg : CL.bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: active ? color.withValues(alpha: 0.3) : CL.divider),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: active ? color : CL.text3),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: active ? color : CL.text3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Filter tab pill ─────────────────────────────────────────────────────────
class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.label,
    required this.active,
    required this.onTap,
    this.color,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? CL.green;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: active ? activeColor : CL.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? activeColor : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : CL.text2,
          ),
        ),
      ),
    );
  }
}
