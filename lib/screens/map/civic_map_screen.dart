import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../config/app_routes.dart';
import '../../models/report_model.dart';
import '../../providers/location_provider.dart';
import '../../providers/report_provider.dart';

class CivicMapScreen extends ConsumerStatefulWidget {
  const CivicMapScreen({super.key});

  @override
  ConsumerState<CivicMapScreen> createState() => _CivicMapScreenState();
}

class _CivicMapScreenState extends ConsumerState<CivicMapScreen> {
  final _mapController = MapController();
  ReportCategory? _filterCategory;

  static const _defaultCenter = LatLng(19.0760, 72.8777); // Mumbai
  static const _defaultZoom = 12.0;

  @override
  Widget build(BuildContext context) {
    final locationAsync = ref.watch(currentLocationProvider);
    final center = locationAsync.valueOrNull ?? _defaultCenter;
    final nearbyAsync = ref.watch(nearbyReportsProvider(center));
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Civic Map'),
        actions: [
          PopupMenuButton<ReportCategory?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (cat) => setState(() => _filterCategory = cat),
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('All Issues')),
              ...ReportCategory.values.map(
                (c) => PopupMenuItem(
                  value: c,
                  child: Text(c.name.replaceAll('_', ' ')),
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              if (locationAsync.valueOrNull != null) {
                _mapController.move(locationAsync.valueOrNull!, 15);
              }
            },
          ),
        ],
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: center,
          initialZoom: _defaultZoom,
          maxZoom: 18,
          minZoom: 8,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.civiclens.app',
          ),
          // Current location marker
          if (locationAsync.valueOrNull != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: locationAsync.valueOrNull!,
                  width: 40,
                  height: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          // Report markers
          nearbyAsync.when(
            loading: () => const MarkerLayer(markers: []),
            error: (_, __) => const MarkerLayer(markers: []),
            data: (reports) {
              final filtered = _filterCategory == null
                  ? reports
                  : reports.where((r) => r.category == _filterCategory).toList();
              return MarkerLayer(
                markers: filtered.map((report) {
                  return Marker(
                    point: LatLng(report.latitude, report.longitude),
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () => context.push(
                        AppRoutes.reportDetail.replaceFirst(':id', report.id),
                      ),
                      child: _ReportMarker(report: report),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'zoom_in',
            onPressed: () {
              final zoom = _mapController.camera.zoom;
              _mapController.move(_mapController.camera.center, zoom + 1);
            },
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'zoom_out',
            onPressed: () {
              final zoom = _mapController.camera.zoom;
              _mapController.move(_mapController.camera.center, zoom - 1);
            },
            child: const Icon(Icons.remove),
          ),
        ],
      ),
    );
  }
}

class _ReportMarker extends StatelessWidget {
  final ReportModel report;
  const _ReportMarker({required this.report});

  Color get _color => switch (report.severity) {
    ReportSeverity.low => Colors.green,
    ReportSeverity.medium => Colors.orange,
    ReportSeverity.high => Colors.red,
    ReportSeverity.critical => Colors.purple,
  };

  IconData get _icon => switch (report.category) {
    ReportCategory.infrastructure => Icons.construction,
    ReportCategory.environment => Icons.eco,
    ReportCategory.safety => Icons.shield_outlined,
    ReportCategory.public_service => Icons.account_balance,
    ReportCategory.appreciation => Icons.star,
    ReportCategory.other => Icons.report_problem,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [BoxShadow(color: _color.withOpacity(0.4), blurRadius: 6)],
      ),
      child: Icon(_icon, color: Colors.white, size: 20),
    );
  }
}
