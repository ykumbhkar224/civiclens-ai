import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../config/app_routes.dart';
import '../../models/constituency_model.dart';
import '../../models/issue_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/constituency_service.dart';
import '../../services/location_service.dart';
import '../../utils/cl_theme.dart';
import '../../widgets/political_hierarchy_card.dart';
import 'issue_confirmation_screen.dart';

class ReportIssueScreen extends ConsumerStatefulWidget {
  const ReportIssueScreen({super.key});

  @override
  ConsumerState<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends ConsumerState<ReportIssueScreen>
    with SingleTickerProviderStateMixin {
  final _pageController = PageController();
  int _step = 0; // 0=category, 1=media, 2=details

  // Step 1 — category & severity
  String _category = IssueCat.infrastructure;
  String _severity = IssueSev.medium;

  // Step 2 — media
  final List<XFile> _photos = [];
  final List<XFile> _videos = [];
  final _picker = ImagePicker();

  // Step 3 — details
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _wardCtrl = TextEditingController();
  bool _isAnonymous = false;
  LatLng? _location;
  String _address = '';
  String _city = '';
  String _pincode = '';
  bool _locationLoading = false;
  bool _geocodingLoading = false;
  ConstituencyInfo? _constituencyInfo;
  bool _constituencyLoading = false;

  static const _fallbackCenter = LatLng(19.0760, 72.8777);

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _wardCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchLocation() async {
    setState(() {
      _locationLoading = true;
      _geocodingLoading = false;
      _constituencyInfo = null; // clear stale data when location changes
    });
    try {
      final loc = await ref.read(currentLocationProvider.future);
      if (loc != null && mounted) {
        setState(() {
          _location = loc;
          _address = '${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)}';
          _locationLoading = false;
          _geocodingLoading = true;
        });
        // Reverse geocode in background
        final geo = await LocationService.reverseGeocode(loc.latitude, loc.longitude);
        if (geo != null && mounted) {
          setState(() {
            _address = geo.displayAddress;
            _city = geo.city;
            _pincode = geo.pincode;
            if (_wardCtrl.text.isEmpty && geo.ward.isNotEmpty) {
              _wardCtrl.text = geo.ward;
            }
            _geocodingLoading = false;
          });
          _lookupConstituency(geo.city, geo.ward, geo.pincode);
        } else if (mounted) {
          setState(() => _geocodingLoading = false);
        }
      } else if (mounted) {
        setState(() => _locationLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() { _locationLoading = false; _geocodingLoading = false; });
    }
  }

  void _goTo(int step) {
    setState(() => _step = step);
    _pageController.animateToPage(step,
        duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    // If navigating to details and GPS already failed, prompt map picker
    if (step == 2 && _location == null && !_locationLoading) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted && _location == null) _openMapPicker();
      });
    }
  }

  bool _canProceedStep0() => true; // category always selected
  bool _canProceedStep1() => true; // photos optional
  bool _canProceedStep2() {
    return _titleCtrl.text.trim().length >= 5 &&
        _descCtrl.text.trim().length >= 10 &&
        _location != null;
  }

  void _next() {
    if (_step == 0 && _canProceedStep0()) _goTo(1);
    else if (_step == 1 && _canProceedStep1()) _goTo(2);
    else if (_step == 2 && _canProceedStep2()) _goToConfirmation();
    else if (_step == 2) {
      if (_location == null) {
        // Auto-open map picker so user can immediately set location
        _showSnack('Please pick a location on the map first.');
        _openMapPicker();
      } else {
        _showSnack('Please add a title (min. 5 chars) and description (min. 10 chars).');
      }
    }
  }

  void _back() {
    if (_step == 0) Navigator.of(context).pop();
    else _goTo(_step - 1);
  }

  void _goToConfirmation() {
    final isLoggedIn = ref.read(authStateProvider).valueOrNull != null;
    if (!isLoggedIn) {
      _showAuthChoiceDialog();
      return;
    }
    _pushConfirmation(anonymous: false);
  }

  void _pushConfirmation({required bool anonymous}) {
    final city = _city.isNotEmpty
        ? _city
        : (ref.read(userProfileProvider).valueOrNull?.city ?? 'Unknown');
    final form = IssueFormData(
      category: _category,
      severity: _severity,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      latitude: _location!.latitude,
      longitude: _location!.longitude,
      address: _address,
      city: city,
      ward: _wardCtrl.text.trim().isEmpty ? null : _wardCtrl.text.trim(),
      pincode: _pincode.isNotEmpty ? _pincode : null,
      photos: List.from(_photos),
      videos: List.from(_videos),
      isAnonymous: anonymous,
    );
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => IssueConfirmationScreen(form: form)),
    );
  }

  Future<void> _showAuthChoiceDialog() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AuthChoiceSheet(
        onLogin: () {
          Navigator.pop(context);
          context.push(AppRoutes.login);
        },
        onRegister: () {
          Navigator.pop(context);
          context.push(AppRoutes.register);
        },
        onGuest: () {
          Navigator.pop(context);
          setState(() => _isAnonymous = true);
          _pushConfirmation(anonymous: true);
        },
      ),
    );
  }

  Future<void> _pickPhotos() async {
    final files = await _picker.pickMultiImage(imageQuality: 80, limit: 5);
    if (files.isNotEmpty) setState(() => _photos.addAll(files));
  }

  Future<void> _takePhoto() async {
    final file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (file != null) setState(() => _photos.add(file));
  }

  Future<void> _takeVideo() async {
    final file = await _picker.pickVideo(source: ImageSource.camera);
    if (file != null) setState(() => _videos.add(file));
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _MapPickerPage(
          initialLocation: _location ?? _fallbackCenter,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _location = result;
        _address = '${result.latitude.toStringAsFixed(5)}, ${result.longitude.toStringAsFixed(5)}';
        _geocodingLoading = true;
        _constituencyInfo = null; // clear stale constituency when location changes
      });
      // Reverse geocode the picked point
      final geo = await LocationService.reverseGeocode(result.latitude, result.longitude);
      if (geo != null && mounted) {
        setState(() {
          _address = geo.displayAddress;
          _city = geo.city;
          _pincode = geo.pincode;
          // Always update ward when user picks a new map location
          if (geo.ward.isNotEmpty) {
            _wardCtrl.text = geo.ward;
          }
          _geocodingLoading = false;
        });
        _lookupConstituency(geo.city, geo.ward, geo.pincode);
      } else if (mounted) {
        setState(() => _geocodingLoading = false);
      }
    }
  }

  Future<void> _lookupConstituency(String city, String ward, String pincode) async {
    if (city.isEmpty) return;
    setState(() { _constituencyLoading = true; _constituencyInfo = null; });
    try {
      final info = await ref.read(constituencyServiceProvider).lookup(
        pincode: pincode.isNotEmpty ? pincode : null,
        city: city,
        ward: ward.isNotEmpty ? ward : null,
        issueCategory: _category,
      );
      if (mounted) setState(() { _constituencyInfo = info; _constituencyLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _constituencyLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    onPressed: _back,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Report Issue',
                          style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Step ${_step + 1} of 3: '
                          '${['Provide incident details', 'Attach photos', 'Set location & review'][_step]}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Help icon
                  Icon(Icons.help_outline_rounded,
                      size: 22,
                      color: isDark ? Colors.white38 : Colors.black26),
                ],
              ),
            ),
            // Step indicator — green segments
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                children: List.generate(3, (i) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: i <= _step
                            ? CL.green
                            : (isDark ? Colors.white12 : Colors.black12),
                      ),
                    ),
                  );
                }),
              ),
            ),
            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _Step0CategoryPage(
                    selectedCategory: _category,
                    selectedSeverity: _severity,
                    onCategoryChanged: (c) => setState(() => _category = c),
                    onSeverityChanged: (s) => setState(() => _severity = s),
                  ),
                  _Step1MediaPage(
                    photos: _photos,
                    videos: _videos,
                    onPickPhotos: _pickPhotos,
                    onTakePhoto: _takePhoto,
                    onTakeVideo: _takeVideo,
                    onRemovePhoto: (i) => setState(() => _photos.removeAt(i)),
                    onRemoveVideo: (i) => setState(() => _videos.removeAt(i)),
                  ),
                  _Step2DetailsPage(
                    titleCtrl: _titleCtrl,
                    descCtrl: _descCtrl,
                    wardCtrl: _wardCtrl,
                    isAnonymous: _isAnonymous,
                    location: _location,
                    address: _address,
                    city: _city,
                    locationLoading: _locationLoading,
                    geocodingLoading: _geocodingLoading,
                    constituencyInfo: _constituencyInfo,
                    constituencyLoading: _constituencyLoading,
                    onAnonymousChanged: (v) => setState(() => _isAnonymous = v),
                    onRefreshLocation: _fetchLocation,
                    onPickOnMap: _openMapPicker,
                  ),
                ],
              ),
            ),
            // Bottom navigation
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (_step > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _back,
                        child: const Text('Back'),
                      ),
                    ),
                  if (_step > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _NextButton(
                      step: _step,
                      onPressed: _next,
                    ),
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

// ── Step 0: Category + Severity ───────────────────────────────────────────────
class _Step0CategoryPage extends StatelessWidget {
  final String selectedCategory;
  final String selectedSeverity;
  final void Function(String) onCategoryChanged;
  final void Function(String) onSeverityChanged;

  const _Step0CategoryPage({
    required this.selectedCategory,
    required this.selectedSeverity,
    required this.onCategoryChanged,
    required this.onSeverityChanged,
  });

  static IconData _catIcon(String cat) => switch (cat) {
        IssueCat.roads         => Icons.directions_car_rounded,
        IssueCat.water         => Icons.water_drop_rounded,
        IssueCat.environment   => Icons.delete_rounded,
        IssueCat.electricity   => Icons.wb_twilight_rounded,
        IssueCat.infrastructure=> Icons.waves_rounded,
        IssueCat.safety        => Icons.shield_rounded,
        IssueCat.transport     => Icons.directions_bus_rounded,
        IssueCat.healthcare    => Icons.local_hospital_rounded,
        IssueCat.publicService => Icons.account_balance_rounded,
        _                      => Icons.more_horiz_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Show 3 severity levels matching the Stitch design
    final severities = [IssueSev.low, IssueSev.medium, IssueSev.high];
    final sevColors = [
      const Color(0xFF16A34A),
      const Color(0xFFD97706),
      const Color(0xFFDC2626),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Category label ────────────────────────────────────────────────
          const Text(
            'SELECT CATEGORY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: CL.text3,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 14),

          // ── 2-column icon grid ────────────────────────────────────────────
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.6,
            ),
            itemCount: IssueCat.all.length,
            itemBuilder: (_, i) {
              final cat = IssueCat.all[i];
              final selected = cat == selectedCategory;
              return GestureDetector(
                onTap: () => onCategoryChanged(cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: selected
                        ? CL.greenBg
                        : (isDark
                            ? const Color(0xFF1E293B)
                            : Colors.white),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? CL.green
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : CL.divider),
                      width: selected ? 1.5 : 1,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: CL.green.withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      // Icon in green rounded square
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: selected
                              ? CL.green
                              : CL.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _catIcon(cat),
                          size: 18,
                          color:
                              selected ? Colors.white : CL.green,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          IssueCat.label(cat),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? CL.green
                                : (isDark
                                    ? Colors.white70
                                    : CL.text1),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // ── Severity label ────────────────────────────────────────────────
          const Text(
            'SEVERITY LEVEL',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: CL.text3,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),

          // ── 3 horizontal pill chips ───────────────────────────────────────
          Row(
            children: List.generate(severities.length, (i) {
              final sev = severities[i];
              final color = sevColors[i];
              final selected = sev == selectedSeverity;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onSeverityChanged(sev),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: EdgeInsets.only(right: i < 2 ? 10 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? color.withValues(alpha: 0.1)
                          : (isDark
                              ? const Color(0xFF1E293B)
                              : Colors.white),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: selected
                            ? color
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : CL.divider),
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          IssueSev.label(sev),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? color
                                : (isDark
                                    ? Colors.white70
                                    : CL.text2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ── Step 1: Media ─────────────────────────────────────────────────────────────
class _Step1MediaPage extends StatelessWidget {
  final List<XFile> photos;
  final List<XFile> videos;
  final VoidCallback onPickPhotos;
  final VoidCallback onTakePhoto;
  final VoidCallback onTakeVideo;
  final void Function(int) onRemovePhoto;
  final void Function(int) onRemoveVideo;

  const _Step1MediaPage({
    required this.photos,
    required this.videos,
    required this.onPickPhotos,
    required this.onTakePhoto,
    required this.onTakeVideo,
    required this.onRemovePhoto,
    required this.onRemoveVideo,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final all = photos.length + videos.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Photos help authorities understand the issue better. (Optional)',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          const SizedBox(height: 20),
          // Photo grid
          if (all > 0)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: all + (all < 5 ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == all) {
                  return _AddMediaBox(
                    isDark: isDark,
                    onTap: onPickPhotos,
                  );
                }
                final isPhoto = i < photos.length;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: isPhoto
                          ? (kIsWeb
                              ? Image.network(photos[i].path, fit: BoxFit.cover)
                              : Image.network(photos[i].path, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.image_outlined)))
                          : Container(
                              color: Colors.black87,
                              child: const Center(
                                child: Icon(Icons.videocam_rounded,
                                    color: Colors.white, size: 32),
                              ),
                            ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => isPhoto
                            ? onRemovePhoto(i)
                            : onRemoveVideo(i - photos.length),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                );
              },
            )
          else
            Column(
              children: [
                _AddMediaBox(isDark: isDark, onTap: onPickPhotos, large: true),
                const SizedBox(height: 16),
              ],
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _MediaButton(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  onTap: onTakePhoto,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MediaButton(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  onTap: onPickPhotos,
                ),
              ),
              if (!kIsWeb) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _MediaButton(
                    icon: Icons.videocam_rounded,
                    label: 'Video',
                    onTap: onTakeVideo,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              '${photos.length} photo${photos.length != 1 ? 's' : ''}'
              '${videos.isNotEmpty ? ', ${videos.length} video${videos.length != 1 ? 's' : ''}' : ''}'
              ' selected (max 5)',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddMediaBox extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;
  final bool large;
  const _AddMediaBox({required this.isDark, required this.onTap, this.large = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: large ? 160 : null,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
            style: BorderStyle.solid,
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_rounded, size: 32, color: Colors.grey),
            SizedBox(height: 4),
            Text('Add Media', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _MediaButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MediaButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}

// ── Step 2: Details ───────────────────────────────────────────────────────────
class _Step2DetailsPage extends StatelessWidget {
  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;
  final TextEditingController wardCtrl;
  final bool isAnonymous;
  final LatLng? location;
  final String address;
  final String city;
  final bool locationLoading;
  final bool geocodingLoading;
  final ConstituencyInfo? constituencyInfo;
  final bool constituencyLoading;
  final void Function(bool) onAnonymousChanged;
  final VoidCallback onRefreshLocation;
  final VoidCallback onPickOnMap;

  const _Step2DetailsPage({
    required this.titleCtrl,
    required this.descCtrl,
    required this.wardCtrl,
    required this.isAnonymous,
    required this.location,
    required this.address,
    required this.city,
    required this.locationLoading,
    required this.geocodingLoading,
    required this.onAnonymousChanged,
    required this.onRefreshLocation,
    required this.onPickOnMap,
    this.constituencyInfo,
    this.constituencyLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Issue Title *',
              hintText: 'e.g. Large pothole on MG Road',
              prefixIcon: Icon(Icons.title_rounded),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: descCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Description *',
              hintText: 'Describe the issue in detail...',
              prefixIcon: Icon(Icons.description_outlined),
              alignLabelWithHint: true,
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: wardCtrl,
            decoration: const InputDecoration(
              labelText: 'Ward / Area (optional)',
              hintText: 'e.g. Ward 42, Andheri West',
              prefixIcon: Icon(Icons.map_outlined),
            ),
          ),
          const SizedBox(height: 16),
          // Location card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.location_on_rounded, size: 18, color: Color(0xFF2563EB)),
                    SizedBox(width: 6),
                    Text('Location *', style: TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 8),
                if (locationLoading)
                  const Row(children: [
                    SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('Detecting GPS...', style: TextStyle(fontSize: 13)),
                  ])
                else if (geocodingLoading && location != null)
                  Row(children: [
                    const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Getting address...',
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black45),
                      ),
                    ),
                  ])
                else if (location != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        address,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (city.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.location_city_outlined,
                                size: 13, color: Color(0xFF7C3AED)),
                            const SizedBox(width: 4),
                            Text(
                              city,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF7C3AED)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  )
                else
                  const Text(
                    'Location not detected',
                    style: TextStyle(fontSize: 13, color: Colors.red),
                  ),
                const SizedBox(height: 10),
                if (location == null) ...[
                  // Prominent CTA when no location set
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: onPickOnMap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.map_rounded, size: 16),
                        label: const Text('Pick Location on Map',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onRefreshLocation,
                      icon: const Icon(Icons.gps_fixed, size: 14),
                      label: const Text('Use GPS Instead',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onRefreshLocation,
                          icon: const Icon(Icons.gps_fixed, size: 14),
                          label:
                              const Text('GPS', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onPickOnMap,
                          icon: const Icon(Icons.map_rounded, size: 14),
                          label: const Text('Change',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Civic representation lookup
          if (constituencyLoading)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: const Row(
                  children: [
                    SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 10),
                    Text('Looking up civic representation...',
                        style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            )
          else if (constituencyInfo != null && constituencyInfo!.hasData)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: PoliticalHierarchyCard(info: constituencyInfo!),
            ),
          // Anonymous toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_off_outlined, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Report Anonymously',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        'Your name won\'t be shown publicly',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(value: isAnonymous, onChanged: onAnonymousChanged),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Next button ────────────────────────────────────────────────────────────────
class _NextButton extends StatelessWidget {
  final int step;
  final VoidCallback onPressed;
  const _NextButton({required this.step, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final labels = [
      'Next: Location  →',
      'Next: Details  →',
      'Submit Report',
    ];
    final icon = step == 2
        ? Icons.check_circle_outline_rounded
        : Icons.arrow_forward_rounded;

    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CL.green,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: CL.green.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          icon: Icon(icon, size: 18),
          label: Text(
            labels[step],
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
      ),
    );
  }
}

// ── Map picker full-screen page ────────────────────────────────────────────────
class _MapPickerPage extends StatefulWidget {
  final LatLng initialLocation;
  const _MapPickerPage({required this.initialLocation});

  @override
  State<_MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<_MapPickerPage> {
  late LatLng _picked;
  late MapController _mapCtrl;
  final _searchCtrl = TextEditingController();
  List<_PlaceSuggestion> _suggestions = [];
  bool _searching = false;
  Timer? _debounce;
  bool _showSuggestions = false;

  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
    headers: {'User-Agent': 'CivicLensApp/1.0'},
  ));

  @override
  void initState() {
    super.initState();
    _picked = widget.initialLocation;
    _mapCtrl = MapController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 3) {
      setState(() { _suggestions = []; _showSuggestions = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(q.trim()));
  }

  Future<void> _search(String q) async {
    setState(() => _searching = true);
    try {
      final resp = await _dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': q,
          'format': 'json',
          'limit': '5',
          'addressdetails': '1',
          'countrycodes': 'in',
        },
      );
      final results = (resp.data as List).cast<Map<String, dynamic>>();
      setState(() {
        _suggestions = results.map((r) => _PlaceSuggestion(
          displayName: r['display_name'] as String,
          lat: double.parse(r['lat'] as String),
          lng: double.parse(r['lon'] as String),
        )).toList();
        _showSuggestions = _suggestions.isNotEmpty;
        _searching = false;
      });
    } catch (_) {
      setState(() => _searching = false);
    }
  }

  void _selectSuggestion(_PlaceSuggestion s) {
    final pt = LatLng(s.lat, s.lng);
    setState(() {
      _picked = pt;
      _searchCtrl.text = s.shortName;
      _suggestions = [];
      _showSuggestions = false;
    });
    _mapCtrl.move(pt, 16);
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: CL.text1, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Pick Location',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: CL.text1),
        ),
      ),
      // ── Confirm button fixed at the bottom ────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [CL.green, Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: CL.green.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, _picked),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.check_circle_rounded, size: 20),
                label: const Text(
                  'Confirm This Location',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // ── Full-screen map ────────────────────────────────────────────
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: _picked,
              initialZoom: 15,
              maxZoom: 19,
              minZoom: 4,
              onTap: (_, pt) {
                setState(() {
                  _picked = pt;
                  _suggestions = [];
                  _showSuggestions = false;
                });
                FocusScope.of(context).unfocus();
              },
            ),
            children: [
              // Carto Voyager — Google Maps-like street style, fast CDN
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.civiclens.app',
                maxZoom: 19,
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _picked,
                    width: 44,
                    height: 52,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: CL.issueRed,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: CL.issueRed.withValues(alpha: 0.45),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.place_rounded, color: Colors.white, size: 18),
                        ),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ── Search bar + suggestions floating over map ─────────────────
          Positioned(
            top: 10,
            left: 12,
            right: 12,
            child: Column(
              children: [
                // Search field
                Material(
                  elevation: 4,
                  shadowColor: Colors.black26,
                  borderRadius: BorderRadius.circular(14),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search address or landmark…',
                      hintStyle: const TextStyle(color: CL.text3, fontSize: 14),
                      prefixIcon: _searching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: CL.green),
                              ),
                            )
                          : const Icon(Icons.search_rounded,
                              color: CL.text3, size: 20),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  size: 18, color: CL.text3),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() {
                                  _suggestions = [];
                                  _showSuggestions = false;
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                    ),
                  ),
                ),
                // Suggestions list
                if (_showSuggestions)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: _suggestions
                            .map(
                              (s) => InkWell(
                                onTap: () => _selectSuggestion(s),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 11),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.place_rounded,
                                          size: 16, color: CL.green),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          s.displayName,
                                          style: const TextStyle(
                                              fontSize: 13, color: CL.text1),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── "Tap to move pin" hint chip ────────────────────────────────
          if (!_showSuggestions)
            Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Tap anywhere to move the pin',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlaceSuggestion {
  final String displayName;
  final double lat;
  final double lng;
  const _PlaceSuggestion({required this.displayName, required this.lat, required this.lng});
  String get shortName => displayName.split(',').take(2).join(',');
}

// ── Auth choice sheet ──────────────────────────────────────────────────────────
class _AuthChoiceSheet extends StatelessWidget {
  final VoidCallback onLogin;
  final VoidCallback onRegister;
  final VoidCallback onGuest;
  const _AuthChoiceSheet({required this.onLogin, required this.onRegister, required this.onGuest});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(color: CL.divider, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          // Icon
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [CL.green, CL.updateBlue]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.how_to_vote_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 16),
          const Text(
            'How do you want to post?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: CL.text1),
          ),
          const SizedBox(height: 6),
          const Text(
            'Login gets you updates on your issue. You can also post anonymously.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: CL.text3, height: 1.5),
          ),
          const SizedBox(height: 24),
          // Login button
          SizedBox(
            width: double.infinity, height: 50,
            child: FilledButton.icon(
              onPressed: onLogin,
              style: FilledButton.styleFrom(
                backgroundColor: CL.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text('Login', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 10),
          // Register button
          SizedBox(
            width: double.infinity, height: 50,
            child: OutlinedButton.icon(
              onPressed: onRegister,
              style: OutlinedButton.styleFrom(
                foregroundColor: CL.updateBlue,
                side: const BorderSide(color: CL.updateBlue),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: const Text('Create Account', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 10),
          // Guest button
          SizedBox(
            width: double.infinity, height: 50,
            child: TextButton.icon(
              onPressed: onGuest,
              style: TextButton.styleFrom(
                foregroundColor: CL.text2,
                backgroundColor: const Color(0xFFF1F5F9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.person_outline_rounded, size: 18),
              label: const Text('Post as Guest', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
