import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../config/app_routes.dart';
import '../../models/constituency_model.dart';
import '../../models/issue_model.dart';
import '../../providers/constituency_provider.dart';
import '../../providers/issue_provider.dart';
import '../../providers/location_provider.dart';
import '../../services/constituency_service.dart';
import '../../services/location_service.dart';
import '../../utils/category_theme.dart';

class CivicMapScreen extends ConsumerStatefulWidget {
  const CivicMapScreen({super.key});

  @override
  ConsumerState<CivicMapScreen> createState() => _CivicMapScreenState();
}

class _CivicMapScreenState extends ConsumerState<CivicMapScreen> {
  final _mapController = MapController();
  static const _defaultCenter = LatLng(18.5204, 73.8567); // Pune
  static const _defaultZoom = 12.0;

  String? _filterCategory;

  // For "pin to find accountable person"
  LatLng? _pinnedPoint;
  bool _loadingPin = false;
  ConstituencyInfo? _pinnedInfo;
  String? _pinnedAddress;

  Future<void> _onMapTap(TapPosition _, LatLng point) async {
    setState(() {
      _pinnedPoint = point;
      _loadingPin = true;
      _pinnedInfo = null;
      _pinnedAddress = null;
    });

    // Reverse geocode → pincode + city + district
    final geo = await LocationService.reverseGeocode(point.latitude, point.longitude);
    if (!mounted) return;

    final info = await ref.read(constituencyServiceProvider).lookup(
          pincode: geo?.pincode,
          city: geo?.city ?? 'Unknown',
          district: geo?.district,
          ward: geo?.ward,
        );

    if (!mounted) return;
    setState(() {
      _loadingPin = false;
      _pinnedInfo = info;
      _pinnedAddress = geo?.displayAddress ?? '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
    });

    _showAccountabilitySheet(point, info);
  }

  void _showAccountabilitySheet(LatLng point, ConstituencyInfo info) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AccountabilitySheet(
        address: _pinnedAddress ?? '',
        info: info,
        point: point,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationAsync = ref.watch(currentLocationProvider);
    final center = locationAsync.valueOrNull ?? _defaultCenter;
    final pos = (lat: center.latitude, lng: center.longitude);
    final issuesAsync = ref.watch(nearbyIssuesProvider(pos));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Civic Map', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          // Category filter
          PopupMenuButton<String?>(
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _filterCategory != null
                    ? CategoryTheme.accent(_filterCategory!).withValues(alpha: 0.15)
                    : (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.07)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.filter_list_rounded, size: 16,
                      color: _filterCategory != null
                          ? CategoryTheme.accent(_filterCategory!)
                          : null),
                  const SizedBox(width: 4),
                  Text(_filterCategory != null
                      ? IssueCat.label(_filterCategory!)
                      : 'All',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            onSelected: (cat) => setState(() => _filterCategory = cat),
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('All Issues')),
              for (final cat in IssueCat.all)
                PopupMenuItem(
                  value: cat,
                  child: Text('${IssueCat.emoji(cat)} ${IssueCat.label(cat)}'),
                ),
            ],
          ),
          const SizedBox(width: 4),
          // My location button
          IconButton(
            icon: const Icon(Icons.my_location_rounded),
            onPressed: () {
              if (locationAsync.valueOrNull != null) {
                _mapController.move(locationAsync.valueOrNull!, 15);
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: _defaultZoom,
              maxZoom: 19,
              minZoom: 7,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.civiclens.app',
                maxZoom: 19,
                tileDisplay: const TileDisplay.fadeIn(),
              ),

              // Issue markers
              issuesAsync.when(
                loading: () => const MarkerLayer(markers: []),
                error: (_, __) => const MarkerLayer(markers: []),
                data: (issues) {
                  final filtered = _filterCategory == null
                      ? issues
                      : issues.where((i) => i.category == _filterCategory).toList();
                  return MarkerLayer(
                    markers: filtered.map((issue) {
                      return Marker(
                        point: LatLng(issue.latitude, issue.longitude),
                        width: 44,
                        height: 44,
                        child: GestureDetector(
                          onTap: () =>
                              context.push(AppRoutes.issueDetailPath(issue.id)),
                          child: _IssueMarker(issue: issue),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

              // Current location blue dot
              if (locationAsync.valueOrNull != null)
                MarkerLayer(markers: [
                  Marker(
                    point: locationAsync.valueOrNull!,
                    width: 22,
                    height: 22,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                ]),

              // Pinned point (tap-to-find marker)
              if (_pinnedPoint != null)
                MarkerLayer(markers: [
                  Marker(
                    point: _pinnedPoint!,
                    width: 44,
                    height: 54,
                    child: _PinMarker(loading: _loadingPin),
                  ),
                ]),
            ],
          ),

          // Issue count chip (top overlay)
          issuesAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (issues) {
              final count = _filterCategory == null
                  ? issues.length
                  : issues.where((i) => i.category == _filterCategory).length;
              return Positioned(
                top: 10,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B).withValues(alpha: 0.95)
                          : Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      '$count ${count == 1 ? 'issue' : 'issues'} nearby  •  tap map to find officials',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Zoom controls
          Positioned(
            right: 12,
            bottom: 80,
            child: Column(
              children: [
                _MapBtn(
                  icon: Icons.add,
                  onTap: () => _mapController.move(
                    _mapController.camera.center,
                    _mapController.camera.zoom + 1,
                  ),
                ),
                const SizedBox(height: 8),
                _MapBtn(
                  icon: Icons.remove,
                  onTap: () => _mapController.move(
                    _mapController.camera.center,
                    _mapController.camera.zoom - 1,
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

// ── Issue map marker ──────────────────────────────────────────────────────────

class _IssueMarker extends StatelessWidget {
  final IssueModel issue;
  const _IssueMarker({required this.issue});

  Color get _borderColor => switch (issue.severity) {
        IssueSev.critical => const Color(0xFFDC2626),
        IssueSev.high => const Color(0xFFEA580C),
        IssueSev.medium => const Color(0xFFD97706),
        _ => const Color(0xFF16A34A),
      };

  @override
  Widget build(BuildContext context) {
    final gradient = CategoryTheme.gradient(issue.category);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: gradient,
        shape: BoxShape.circle,
        border: Border.all(color: _borderColor, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: (gradient.colors.last).withValues(alpha: 0.45),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          IssueCat.emoji(issue.category),
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}

// ── Pin drop marker (tap-to-find) ─────────────────────────────────────────────

class _PinMarker extends StatelessWidget {
  final bool loading;
  const _PinMarker({required this.loading});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF7C3AED),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.45),
                blurRadius: 12,
              ),
            ],
          ),
          child: loading
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.location_pin, color: Colors.white, size: 22),
        ),
        Container(
          width: 3,
          height: 10,
          decoration: const BoxDecoration(color: Color(0xFF7C3AED)),
        ),
      ],
    );
  }
}

// ── Zoom button ───────────────────────────────────────────────────────────────

class _MapBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MapBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
            ),
          ],
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }
}

// ── Accountability bottom sheet ───────────────────────────────────────────────

class _AccountabilitySheet extends StatelessWidget {
  final String address;
  final ConstituencyInfo info;
  final LatLng point;

  const _AccountabilitySheet({
    required this.address,
    required this.info,
    required this.point,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.location_pin, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Officials Accountable Here',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        address,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),

          if (!info.hasData)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 40,
                      color: isDark ? Colors.white38 : Colors.black26),
                  const SizedBox(height: 10),
                  Text(
                    'No representative data found for this area yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black45,
                        fontSize: 13),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Column(
                children: [
                  if (info.city.isNotEmpty)
                    _InfoRow(
                      icon: '📍',
                      label: 'Area',
                      value: [
                        info.city,
                        if (info.assemblyConstituency != null)
                          info.assemblyConstituency!,
                      ].join(', '),
                      isDark: isDark,
                    ),
                  if (info.mla != null)
                    _OfficialTile(
                      emoji: '🏛',
                      role: 'MLA (State Assembly)',
                      name: info.mla!.name,
                      party: info.mla!.party,
                      constituency: info.assemblyConstituency,
                      color: const Color(0xFF7C3AED),
                      isDark: isDark,
                    ),
                  if (info.mp != null)
                    _OfficialTile(
                      emoji: '🇮🇳',
                      role: 'MP (Parliament)',
                      name: info.mp!.name,
                      party: info.mp!.party,
                      constituency: info.parliamentConstituency,
                      color: const Color(0xFF2563EB),
                      isDark: isDark,
                    ),
                  if (info.councillor != null)
                    _OfficialTile(
                      emoji: '🏘',
                      role: 'Councillor',
                      name: info.councillor!.name,
                      party: info.councillor!.party,
                      constituency: info.ward,
                      color: const Color(0xFF059669),
                      isDark: isDark,
                    ),
                  if (info.departments.isNotEmpty) ...[
                    const Divider(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '🏢 Responsible Departments',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: info.departments.map((d) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: const Color(0xFFD97706)
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            d.department,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFD97706),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String icon, label, value;
  final bool isDark;
  const _InfoRow(
      {required this.icon,
      required this.label,
      required this.value,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text('$label: ',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.black45)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _OfficialTile extends StatelessWidget {
  final String emoji, role, name;
  final String? party, constituency;
  final Color color;
  final bool isDark;

  const _OfficialTile({
    required this.emoji,
    required this.role,
    required this.name,
    this.party,
    this.constituency,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(role,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color)),
                Text(name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800)),
                if (party != null && party!.isNotEmpty)
                  Text(
                    [party!, if (constituency != null) constituency!].join(' · '),
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
