import 'dart:io';
import 'package:flutter/material.dart';
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
      } else if (mounted) {
        // Fallback: show a snackbar so the user knows to allow location
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location unavailable. Allow location access in your browser, then retry.',
            ),
            duration: Duration(seconds: 5),
            action: SnackBarAction(label: 'Retry', onPressed: () => _loadCurrentLocation()),
          ),
        );
      }
    } catch (_) {}
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
          // Auto-fill AI suggestions
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
        const SnackBar(content: Text('Location is required')),
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
            const SizedBox(height: 8),
            if (_selectedLocation != null)
              Chip(
                avatar: const Icon(Icons.my_location, size: 16),
                label: Text(
                  'GPS: ${_selectedLocation!.latitude.toStringAsFixed(4)}, '
                  '${_selectedLocation!.longitude.toStringAsFixed(4)}',
                ),
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
                    child: Image.file(
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
