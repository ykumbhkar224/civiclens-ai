import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_routes.dart';
import '../../providers/auth_provider.dart';

class PhoneOtpScreen extends ConsumerStatefulWidget {
  const PhoneOtpScreen({super.key});

  @override
  ConsumerState<PhoneOtpScreen> createState() => _PhoneOtpScreenState();
}

class _PhoneOtpScreenState extends ConsumerState<PhoneOtpScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(6, (_) => FocusNode());
  final _phoneFocus = FocusNode();

  bool _otpSent = false;
  String _phone = '';
  int _resendSeconds = 0;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    for (final c in _otpControllers) c.dispose();
    for (final f in _otpFocusNodes) f.dispose();
    _phoneFocus.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      _showSnack('Enter a valid phone number', isError: true);
      return;
    }
    // Ensure E.164 format
    final formatted = phone.startsWith('+') ? phone : '+91$phone';
    await ref.read(authNotifierProvider.notifier).sendPhoneOtp(formatted);

    final s = ref.read(authNotifierProvider);
    if (s is AsyncError) {
      _showSnack(s.error.toString(), isError: true);
      return;
    }

    setState(() {
      _phone = formatted;
      _otpSent = true;
      _resendSeconds = 30;
    });
    _startResendTimer();
    _animCtrl.reset();
    _animCtrl.forward();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _otpFocusNodes[0].requestFocus();
    });
    _showSnack('OTP sent to $formatted');
  }

  Future<void> _verifyOtp() async {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length < 6) {
      _showSnack('Enter the 6-digit OTP', isError: true);
      return;
    }
    await ref.read(authNotifierProvider.notifier).verifyPhoneOtp(
          phone: _phone,
          token: otp,
        );
    final s = ref.read(authNotifierProvider);
    if (s is AsyncError && mounted) {
      _showSnack(s.error.toString(), isError: true);
    }
  }

  void _startResendTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendSeconds = (_resendSeconds - 1).clamp(0, 30));
      return _resendSeconds > 0;
    });
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _onOtpDigit(int index, String val) {
    if (val.length == 6) {
      // Paste — distribute across boxes
      for (int i = 0; i < 6 && i < val.length; i++) {
        _otpControllers[i].text = val[i];
      }
      _otpFocusNodes[5].requestFocus();
      return;
    }
    if (val.isNotEmpty && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    }
    if (val.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    // Navigate home on successful login
    ref.listen(authNotifierProvider, (_, next) {
      if (next is AsyncData && next.value != null && mounted) {
        context.go(AppRoutes.home);
      }
      if (next is AsyncError && mounted) {
        _showSnack(next.error.toString(), isError: true);
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [const Color(0xFF0F172A), const Color(0xFF1E1B4B)]
                    : [const Color(0xFFEFF6FF), const Color(0xFFF5F3FF)],
              ),
            ),
          ),
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button
                  IconButton(
                    onPressed: () {
                      if (_otpSent) {
                        setState(() {
                          _otpSent = false;
                          for (final c in _otpControllers) c.clear();
                        });
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 24),

                  FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Icon(
                              _otpSent ? Icons.lock_open_rounded : Icons.phone_android_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _otpSent ? 'Verify OTP' : 'Phone Login',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _otpSent
                                ? 'Enter the 6-digit code sent to\n$_phone'
                                : 'Enter your mobile number to receive an OTP',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isDark ? Colors.white54 : Colors.black45,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 36),

                          if (!_otpSent) ...[
                            // Phone input
                            Container(
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.07),
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
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 14),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.white.withValues(alpha: 0.06)
                                              : Colors.black.withValues(alpha: 0.04),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isDark
                                                ? Colors.white.withValues(alpha: 0.1)
                                                : Colors.black.withValues(alpha: 0.08),
                                          ),
                                        ),
                                        child: const Row(
                                          children: [
                                            Text('🇮🇳', style: TextStyle(fontSize: 18)),
                                            SizedBox(width: 6),
                                            Text('+91',
                                                style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 15)),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: TextField(
                                          controller: _phoneController,
                                          focusNode: _phoneFocus,
                                          keyboardType: TextInputType.phone,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.digitsOnly,
                                            LengthLimitingTextInputFormatter(10),
                                          ],
                                          style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 2),
                                          decoration: InputDecoration(
                                            hintText: '9876543210',
                                            hintStyle: TextStyle(
                                              color: isDark ? Colors.white24 : Colors.black26,
                                              fontWeight: FontWeight.w400,
                                              letterSpacing: 0,
                                              fontSize: 16,
                                            ),
                                            border: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                          onSubmitted: (_) => _sendOtp(),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _GradientButton(
                                    label: 'Send OTP',
                                    icon: Icons.send_rounded,
                                    isLoading: authState.isLoading,
                                    onPressed: authState.isLoading ? null : _sendOtp,
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            // OTP boxes
                            Container(
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.07),
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
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: List.generate(6, (i) {
                                      return _OtpBox(
                                        controller: _otpControllers[i],
                                        focusNode: _otpFocusNodes[i],
                                        onChanged: (v) => _onOtpDigit(i, v),
                                        isDark: isDark,
                                        cs: cs,
                                      );
                                    }),
                                  ),
                                  const SizedBox(height: 20),
                                  _GradientButton(
                                    label: 'Verify & Sign In',
                                    icon: Icons.verified_rounded,
                                    isLoading: authState.isLoading,
                                    onPressed: authState.isLoading ? null : _verifyOtp,
                                  ),
                                  const SizedBox(height: 12),
                                  // Resend
                                  TextButton(
                                    onPressed: _resendSeconds == 0 ? _sendOtp : null,
                                    child: Text(
                                      _resendSeconds > 0
                                          ? 'Resend OTP in ${_resendSeconds}s'
                                          : 'Resend OTP',
                                      style: TextStyle(
                                        color: _resendSeconds > 0
                                            ? (isDark ? Colors.white38 : Colors.black38)
                                            : cs.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── OTP digit box ────────────────────────────────────────────────────────────
class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final void Function(String) onChanged;
  final bool isDark;
  final ColorScheme cs;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.isDark,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 54,
      child: AnimatedBuilder(
        animation: focusNode,
        builder: (_, child) {
          final focused = focusNode.hasFocus;
          return Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: focused ? 0.12 : 0.06)
                  : Colors.black.withValues(alpha: focused ? 0.06 : 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: focused
                    ? cs.primary
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.1)),
                width: focused ? 2 : 1,
              ),
            ),
            child: child,
          );
        },
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6), // allow paste of full OTP
          ],
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            counterText: '',
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ─── Gradient button ──────────────────────────────────────────────────────────
class _GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;
  final IconData icon;

  const _GradientButton({
    required this.onPressed,
    required this.isLoading,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: onPressed == null
              ? const LinearGradient(colors: [Colors.grey, Colors.grey])
              : const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: onPressed == null
              ? []
              : [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        )),
                    const SizedBox(width: 8),
                    Icon(icon, size: 18),
                  ],
                ),
        ),
      ),
    );
  }
}
