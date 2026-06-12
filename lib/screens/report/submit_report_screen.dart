import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../models/report_model.dart';
import '../../providers/location_provider.dart';
import '../../providers/report_provider.dart';
import '../../providers/user_provider.dart';

class SubmitReportScreen extends ConsumerStatefulWidget {
  const SubmitReportScreen({super.key});

  @override
  ConsumerState<SubmitReportScreen> createState() => _SubmitReportScreenState();
}

class _SubmitReportScreenState extends ConsumerState<SubmitReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _addressController = TextEditingController();

  ReportCategory _category = ReportCategory.infrastructure;
  ReportSeverity _severity = ReportSeverity.medium;
  bool _isAnonymous = false;
  bool _isClassifying = false;
  ReportClassification? _aiClassification;
  List<XFile> _images = [];
  LatLng? _selectedLocation;

  static const _fallbackCenter = LatLng(19.0760, 72.8777); // Mumbai

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    try {
      final location = await ref.read(currentLocationProvider.future);
      if (location != null && mounted) {
        setState(() => _selectedLocation = location);
      }
    } catch (_) {}
  }

  Future<void> _openMapPicker() async {
    final initial = _selectedLocation ?? _fallbackCenter;
    final picked = await showModalBottomSheet<LatLng>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MapPickerSheet(initialLocation: initial),
    );
    if (picked != null && mounted) {
      setState(() => _selectedLocation = picked);
    }
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(imageQuality: 80, limit: 4);
    if (files.isNotEmpty) setState(() => _images = files);
  }

  Future<void> _classifyWithAI() async {
    if (_descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a description first')),
      );
      return;
    }
    setState(() => _isClassifying = true);
    try {
      final gemini = ref.read(geminiServiceProvider);
      final result = await gemini.classifyReport(
        description: _descController.text.trim(),
      );
      if (mounted) {
        setState(() {
          _aiClassification = result;
          _isClassifying = false;
          try {
            _category = ReportCategory.values.firstWhere(
              (c) => c.name == result.category,
              orElse: () => _category,
            );
            _severity = ReportSeverity.values.firstWhere(
              (s) => s.name == result.severity,
              orElse: () => _severity,
            );
          } catch (_) {}
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI classification applied'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isClassifying = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please set a location first'),
          action: SnackBarAction(label: 'Pick', onPressed: _openMapPicker),
        ),
      );
      return;
    }

    final files = _images.map((x) => File(x.path)).toList();
    final result = await ref.read(submitReportNotifierProvider.notifier).submit(
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      category: _category,
      severity: _severity,
      latitude: _selectedLocation!.latitude,
      longitude: _selectedLocation!.longitude,
      address: _addressController.text.trim(),
      city: ref.read(userProfileProvider).valueOrNull?.city ?? 'Unknown',
      images: files.isEmpty ? null : files,
      tags: _aiClassification?.tags ?? [],
      department: _aiClassification?.department,
      aiSummary: _aiClassification?.summary,
      isAnonymous: _isAnonymous,
    );

    if (result != null && mounted) {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final submitState = ref.watch(submitReportNotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;

    ref.listen(submitReportNotifierProvider, (_, next) {
      if (next is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error.toString()),
            backgroundColor: colorScheme.error,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report an Issue'),
        actions: [
          TextButton.icon(
            onPressed: _isClassifying ? null : _classifyWithAI,
            icon: _isClassifying
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: const Text('AI Classify'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // AI classification banner
            if (_aiClassification != null)
              Card(
                color: colorScheme.secondaryContainer,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome, color: colorScheme.secondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'AI: ${_aiClassification!.summary}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Brief title of the issue',
                prefixIcon: Icon(Icons.title),
              ),
              maxLength: 100,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Title is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Describe the issue in detail',
                prefixIcon: Icon(Icons.description_outlined),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              maxLength: 1000,
              validator: (v) => v == null || v.trim().length < 20
                  ? 'Add at least 20 characters'
                  : null,
            ),
            const SizedBox(height: 16),

            // Category selector
            DropdownButtonFormField<ReportCategory>(
              value: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: ReportCategory.values.map((c) {
                return DropdownMenuItem(
                  value: c,
                  child: Text(c.name.replaceAll('_', ' ').toUpperCase()),
                );
              }).toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 16),

            // Severity selector
            DropdownButtonFormField<ReportSeverity>(
              value: _severity,
              decoration: const InputDecoration(
                labelText: 'Severity',
                prefixIcon: Icon(Icons.warning_amber_outlined),
              ),
              items: ReportSeverity.values.map((s) {
                return DropdownMenuItem(
                  value: s,
                  child: Text(s.name.toUpperCase()),
                );
              }).toList(),
              onChanged: (v) => setState(() => _severity = v!),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address / Location Description',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Address is required' : null,
            ),
            const SizedBox(height: 12),

            // ── Location picker card ──────────────────────────────────────
            _LocationPickerCard(
              location: _selectedLocation,
              onPickOnMap: _openMapPicker,
              onRefreshGps: _loadCurrentLocation,
            ),
            const SizedBox(height: 16),

            // Image picker
            OutlinedButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(
                _images.isEmpty
                    ? 'Add Photos (optional)'
                    : '${_images.length} photo(s) selected',
              ),
            ),
            if (_images.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: kIsWeb
                        ? Image.network(
                            _images[i].path,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          )
                        : Image.file(
                            File(_images[i].path),
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            SwitchListTile(
              value: _isAnonymous,
              onChanged: (v) => setState(() => _isAnonymous = v),
              title: const Text('Submit anonymously'),
              subtitle: const Text('Your name will not be shown publicly'),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: submitState.isLoading ? null : _submit,
              icon: submitState.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: const Text('Submit Report'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── Location picker card ─────────────────────────────────────────────────────
class _LocationPickerCard extends StatelessWidget {
  final LatLng? location;
  final VoidCallback onPickOnMap;
  final VoidCallback onRefreshGps;

  const _LocationPickerCard({
    required this.location,
    required this.onPickOnMap,
    required this.onRefreshGps,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasLocation = location != null;

    return Card(
      color: hasLocation ? cs.secondaryContainer : cs.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              hasLocation ? Icons.location_on : Icons.location_off_outlined,
              color: hasLocation ? cs.secondary : cs.error,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasLocation ? 'Location set' : 'No location set',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (hasLocation)
                    Text(
                      '${location!.latitude.toStringAsFixed(5)}, '
                      '${location!.longitude.toStringAsFixed(5)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else
                    Text(
                      'Tap "Pick on Map" to set location',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: cs.error),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Use GPS',
              icon: const Icon(Icons.my_location_outlined),
              onPressed: onRefreshGps,
            ),
            FilledButton.tonal(
              onPressed: onPickOnMap,
              child: const Text('Pick on Map'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Map picker bottom sheet ──────────────────────────────────────────────────
class _MapPickerSheet extends StatefulWidget {
  final LatLng initialLocation;
  const _MapPickerSheet({required this.initialLocation});

  @override
  State<_MapPickerSheet> createState() => _MapPickerSheetState();
}

class _MapPickerSheetState extends State<_MapPickerSheet> {
  late LatLng _pinLocation;
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _pinLocation = widget.initialLocation;
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          // Handle bar
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Tap on map to set location',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(_pinLocation),
                  child: const Text('Confirm'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _pinLocation,
                    initialZoom: 15,
                    onTap: (_, latlng) {
                      setState(() => _pinLocation = latlng);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.civiclens.app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _pinLocation,
                          width: 48,
                          height: 56,
                          alignment: Alignment.topCenter,
                          child: Icon(
                            Icons.location_pin,
                            color: cs.error,
                            size: 48,
                            shadows: const [
                              Shadow(blurRadius: 6, color: Colors.black26),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Coordinates overlay
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(blurRadius: 6, color: Colors.black26),
                        ],
                      ),
                      child: Text(
                        '${_pinLocation.latitude.toStringAsFixed(5)}, '
                        '${_pinLocation.longitude.toStringAsFixed(5)}',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
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
