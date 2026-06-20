import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_routes.dart';
import '../../models/issue_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/issue_provider.dart';
import '../../utils/category_theme.dart';
import '../../widgets/gradient_button.dart';

class IssueConfirmationScreen extends ConsumerStatefulWidget {
  final IssueFormData form;
  const IssueConfirmationScreen({super.key, required this.form});

  @override
  ConsumerState<IssueConfirmationScreen> createState() =>
      _IssueConfirmationScreenState();
}

class _IssueConfirmationScreenState
    extends ConsumerState<IssueConfirmationScreen> {
  bool _pendingSubmit = false;

  void _submitWithAuthGate() {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      setState(() => _pendingSubmit = true);
      _showInlineLoginSheet();
      return;
    }
    ref.read(createIssueNotifierProvider.notifier).submit(widget.form);
  }

  void _showInlineLoginSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: _InlineLoginSheet(
          onLoggedIn: () {
            if (mounted) {
              ref
                  .read(createIssueNotifierProvider.notifier)
                  .submit(widget.form);
            }
          },
        ),
      ),
    );
  }

  Color _sevColor(String s) => switch (s) {
        IssueSev.critical => const Color(0xFFDC2626),
        IssueSev.high => const Color(0xFFEA580C),
        IssueSev.medium => const Color(0xFFD97706),
        _ => const Color(0xFF16A34A),
      };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final submitState = ref.watch(createIssueNotifierProvider);
    final isLoading = submitState.isLoading;

    ref.listen(createIssueNotifierProvider, (_, next) {
      if (next is AsyncData && next.value != null) {
        final issue = next.value!;
        setState(() => _pendingSubmit = false);
        ref.read(createIssueNotifierProvider.notifier).reset();
        context.pushReplacement(AppRoutes.shareCard, extra: issue);
      } else if (next is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${next.error}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    });

    // When user logs in while _pendingSubmit, auto-submit
    ref.listen(authNotifierProvider, (_, next) {
      if (_pendingSubmit && next is AsyncData && next.value != null) {
        setState(() => _pendingSubmit = false);
        ref
            .read(createIssueNotifierProvider.notifier)
            .submit(widget.form);
      }
    });

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Review & Submit',
            style: TextStyle(fontWeight: FontWeight.w800)),
        leading: BackButton(
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview card
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: isDark ? 0.25 : 0.07),
                    blurRadius: 24,
                    offset: const Offset(0, 6),
                  ),
                ],
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.form.photos.isNotEmpty)
                    SizedBox(
                      height: 200,
                      width: double.infinity,
                      child: kIsWeb
                          ? Image.network(
                              widget.form.photos.first.path,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _banner(widget.form),
                            )
                          : Image.network(
                              widget.form.photos.first.path,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _banner(widget.form),
                            ),
                    )
                  else
                    _banner(widget.form),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          children: [
                            _Badge(
                              label:
                                  '${IssueCat.emoji(widget.form.category)} ${IssueCat.label(widget.form.category)}',
                              color: const Color(0xFF2563EB),
                            ),
                            _Badge(
                              label: IssueSev.label(widget.form.severity),
                              color: _sevColor(widget.form.severity),
                            ),
                            if (widget.form.isAnonymous)
                              _Badge(
                                  label: '👤 Anonymous',
                                  color: Colors.grey),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          widget.form.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.form.description,
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                isDark ? Colors.white70 : Colors.black54,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded,
                                size: 16, color: Color(0xFF2563EB)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                widget.form.address,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.white60
                                      : Colors.black45,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (widget.form.ward != null &&
                            widget.form.ward!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.map_outlined,
                                  size: 16, color: Color(0xFF7C3AED)),
                              const SizedBox(width: 6),
                              Text(
                                widget.form.ward!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.white60
                                      : Colors.black45,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (widget.form.photos.isNotEmpty ||
                            widget.form.videos.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            children: [
                              if (widget.form.photos.isNotEmpty)
                                _Badge(
                                  label:
                                      '📷 ${widget.form.photos.length} photo${widget.form.photos.length > 1 ? 's' : ''}',
                                  color: const Color(0xFF059669),
                                ),
                              if (widget.form.videos.isNotEmpty)
                                _Badge(
                                  label:
                                      '🎥 ${widget.form.videos.length} video${widget.form.videos.length > 1 ? 's' : ''}',
                                  color: const Color(0xFF059669),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            if (widget.form.aiSummary != null &&
                widget.form.aiSummary!.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🤖', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AI Analysis',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.form.aiSummary!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          if (widget.form.aiDepartment != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Dept: ${widget.form.aiDepartment}',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Declaration
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 16, color: Color(0xFF2563EB)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'By submitting, you confirm this issue is genuine and in a public area.',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFF2563EB)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            GradientButton(
              label: isLoading
                  ? 'Submitting...'
                  : (_pendingSubmit
                      ? 'Waiting for login...'
                      : 'Submit Issue'),
              icon: Icons.send_rounded,
              isLoading: isLoading || _pendingSubmit,
              onPressed: (isLoading || _pendingSubmit)
                  ? null
                  : _submitWithAuthGate,
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: (isLoading || _pendingSubmit)
                    ? null
                    : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit Issue'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  static Widget _banner(IssueFormData form) => Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: CategoryTheme.gradient(form.category),
        ),
        child: Center(
          child: Text(IssueCat.emoji(form.category),
              style: const TextStyle(fontSize: 64)),
        ),
      );
}

// ── Inline login bottom sheet ─────────────────────────────────────────────────

class _InlineLoginSheet extends ConsumerStatefulWidget {
  final VoidCallback onLoggedIn;
  const _InlineLoginSheet({required this.onLoggedIn});

  @override
  ConsumerState<_InlineLoginSheet> createState() => _InlineLoginSheetState();
}

class _InlineLoginSheetState extends ConsumerState<_InlineLoginSheet> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    ref.listen(authNotifierProvider, (_, next) {
      if (next is AsyncData && next.value != null) {
        Navigator.of(context).pop(); // close sheet
        widget.onLoggedIn();
      } else if (next is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error.toString()),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    });

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '🔐 Sign in to Post Issue',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your report is ready. Sign in to submit it.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 24),
            // Email field
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Email address',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon:
                    const Icon(Icons.email_outlined, color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Password field
            TextField(
              controller: _passCtrl,
              obscureText: _obscure,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Password',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon:
                    const Icon(Icons.lock_outline, color: Colors.white38),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Colors.white38,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _signIn(),
            ),
            const SizedBox(height: 16),
            // Sign in button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: isLoading ? null : _signIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Sign In & Submit',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Google login
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isLoading
                    ? null
                    : () => ref
                        .read(authNotifierProvider.notifier)
                        .signInWithGoogle(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.g_mobiledata, size: 24),
                label: const Text('Continue with Google',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white38)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signIn() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter email and password')),
      );
      return;
    }
    await ref
        .read(authNotifierProvider.notifier)
        .signInWithEmail(email, pass);
  }
}

// ── Shared helper widgets ─────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
