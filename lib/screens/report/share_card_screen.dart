import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/app_routes.dart';
import '../../models/constituency_model.dart';
import '../../models/issue_model.dart';
import '../../providers/constituency_provider.dart';
import '../../widgets/issue_share_card.dart';

class ShareCardScreen extends ConsumerWidget {
  final IssueModel issue;

  const ShareCardScreen({super.key, required this.issue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (
      city: issue.city,
      district: null,
      ward: issue.ward,
      pincode: issue.pincode,
      category: issue.category,
    );
    final infoAsync = ref.watch(constituencyLookupProvider(args));

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Issue Card',
          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.go(AppRoutes.home),
        ),
      ),
      body: infoAsync.when(
        loading: () => _ShareCardBody(issue: issue, constituencyInfo: null),
        error: (_, __) => _ShareCardBody(issue: issue, constituencyInfo: null),
        data: (info) => _ShareCardBody(issue: issue, constituencyInfo: info),
      ),
    );
  }
}

class _ShareCardBody extends StatefulWidget {
  final IssueModel issue;
  final ConstituencyInfo? constituencyInfo;

  const _ShareCardBody({required this.issue, this.constituencyInfo});

  @override
  State<_ShareCardBody> createState() => _ShareCardBodyState();
}

class _ShareCardBodyState extends State<_ShareCardBody> {
  final GlobalKey _cardKey = GlobalKey();
  bool _isSharing = false;

  List<String> _buildHashtags() {
    final cityTag = widget.issue.city.replaceAll(' ', '');
    final catTag = IssueCat.label(widget.issue.category).replaceAll(' ', '');
    final tags = [
      '#CivicLens',
      '#$cityTag',
      '#$catTag',
      '#HoldThemAccountable',
      '#CivicAccountability',
      '#SmartCity',
    ];
    final info = widget.constituencyInfo;
    if (info?.mla != null) {
      tags.insert(2, '@${info!.mla!.name.replaceAll(' ', '')}');
    }
    if (info?.mp != null) {
      tags.insert(3, '@${info!.mp!.name.replaceAll(' ', '')}');
    }
    if (info?.councillor != null) {
      tags.insert(4, '@${info!.councillor!.name.replaceAll(' ', '')}');
    }
    return tags;
  }

  Future<void> _share() async {
    setState(() => _isSharing = true);
    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final xfile = XFile.fromData(
        bytes,
        name: 'civiclens_issue_${DateTime.now().millisecondsSinceEpoch}.png',
        mimeType: 'image/png',
      );

      final hashtags = _buildHashtags().join(' ');
      final caption =
          '🚨 ${widget.issue.title}\n\n📍 ${widget.issue.city}\n\n$hashtags\n\nReported via CivicLens AI';

      await Share.shareXFiles(
        [xfile],
        text: caption,
        subject: 'CivicLens Issue Report',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not share: $e'),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hashtags = _buildHashtags();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: 'Issue reported ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(
                  text: '🎉',
                  style: TextStyle(fontSize: 20),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Share this card to hold your representatives accountable.',
            style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 24),

          // Card preview
          Center(
            child: RepaintBoundary(
              key: _cardKey,
              child: IssueShareCard(
                issue: widget.issue,
                constituencyInfo: widget.constituencyInfo,
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Suggested tags section
          const Text(
            'Suggested Tags',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: hashtags.map((tag) => _HashtagChip(tag: tag)).toList(),
          ),
          const SizedBox(height: 28),

          // Instagram share button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE1306C), Color(0xFF833AB4)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE1306C).withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _isSharing ? null : _share,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                icon: _isSharing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.camera_alt_rounded, size: 20),
                label: Text(
                  _isSharing ? 'Preparing image...' : 'Share to Instagram',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // General share button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _isSharing ? null : _share,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.share_rounded, size: 18),
              label: const Text(
                'Share via...',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Done button
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => context.go(AppRoutes.home),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Go to Home',
                style: TextStyle(
                  color: Colors.white38,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HashtagChip extends StatelessWidget {
  final String tag;
  const _HashtagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    final isAt = tag.startsWith('@');
    final color =
        isAt ? const Color(0xFF3B82F6) : const Color(0xFF8B5CF6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        tag,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
