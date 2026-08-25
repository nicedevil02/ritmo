// lib/features/profile/presentation/widgets/otp_verification_sheet.dart

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/backend/auth_service.dart';
import 'package:ritmo/core/backend/models/auth_result.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

class OtpVerificationSheet extends StatefulWidget {
  final String identifier;
  final bool isEmail;
  final String? emailUserId;
  final VoidCallback onSuccess;

  const OtpVerificationSheet({
    super.key,
    required this.identifier,
    this.isEmail = false,
    this.emailUserId,
    required this.onSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required String identifier,
    bool isEmail = false,
    String? emailUserId,
    required VoidCallback onSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: OtpVerificationSheet(
          identifier: identifier,
          isEmail: isEmail,
          emailUserId: emailUserId,
          onSuccess: onSuccess,
        ),
      ),
    );
  }

  @override
  State<OtpVerificationSheet> createState() => _OtpVerificationSheetState();
}

class _OtpVerificationSheetState extends State<OtpVerificationSheet> {
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Timer? _timer;
  int _secondsRemaining = 120;
  bool _isLoading = false;
  bool _isResending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _secondsRemaining = 120;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        t.cancel();
      }
    });
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final mStr = minutes.toString().padLeft(2, '0');
    final sStr = seconds.toString().padLeft(2, '0');
    return '$mStr:$sStr';
  }

  String _normalizeDigits(String input) {
    const persianDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    String res = input;
    for (int i = 0; i < 10; i++) {
      res = res.replaceAll(persianDigits[i], '$i');
      res = res.replaceAll(arabicDigits[i], '$i');
    }
    return res;
  }

  Future<void> _verifyCode() async {
    final rawDigits = _normalizeDigits(_otpController.text);
    if (rawDigits.length != 6) {
      setState(() => _errorMessage = 'لطفاً کد ۶ رقمی را به طور کامل وارد کنید.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (widget.emailUserId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'شناسه تأیید ایمیل معتبر نیست. لطفاً مجدداً تلاش کنید.';
      });
      return;
    }

    final res = await AuthService.instance.verifyEmailOtp(widget.emailUserId!, rawDigits);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res.isSuccess) {
      Navigator.of(context).pop();
      widget.onSuccess();
    } else {
      setState(() {
        _errorMessage = res.errorMessage ?? AuthErrorCode.wrongOtp.persianMessage;
      });
    }
  }

  Future<void> _resendCode() async {
    if (_secondsRemaining > 0 || _isResending) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    final res = await AuthService.instance.requestEmailOtp(widget.identifier);

    if (!mounted) return;
    setState(() => _isResending = false);

    if (res.isSuccess) {
      _startCountdown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('کد جدید با موفقیت ارسال شد.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() {
        _errorMessage = res.errorMessage ?? AuthErrorCode.smsDeliveryFailed.persianMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final isDark = context.isDark;
    final isGlass = context.isGlassEnabled;
    final blur = context.glassBlurSigma.clamp(0.0, 50.0);
    const sheetRadius = BorderRadius.vertical(top: Radius.circular(32));
    final maskedId = AuthService.maskIdentifier(widget.identifier);
    final rawDigits = _normalizeDigits(_otpController.text);

    final content = Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: colors.divider,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.isEmail ? 'تأیید نشانی ایمیل' : 'تأیید شماره همراه',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
                height: 1.5,
              ),
              children: [
                TextSpan(text: widget.isEmail ? 'کد ۶ رقمی ارسال‌شده به ایمیل ' : 'کد ۶ رقمی ارسال‌شده به شماره '),
                TextSpan(
                  text: maskedId,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
                const TextSpan(text: ' را وارد کنید:'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Visual 6-Digit PIN Boxes
          GestureDetector(
            onTap: () => _focusNode.requestFocus(),
            child: Stack(
              children: [
                // Hidden TextField for input catching
                Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: _otpController,
                    focusNode: _focusNode,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (val) {
                      setState(() {
                        _errorMessage = null;
                      });
                      if (_normalizeDigits(val).length == 6) {
                        _verifyCode();
                      }
                    },
                  ),
                ),
                // Render 6 PIN Boxes
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (index) {
                    final isFilled = index < rawDigits.length;
                    final isFocused = index == rawDigits.length;
                    final char = isFilled ? rawDigits[index] : '';

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 46,
                      height: 54,
                      decoration: BoxDecoration(
                        color: isFilled
                            ? colors.primary.withValues(alpha: isDark ? 0.2 : 0.1)
                            : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isFocused
                              ? colors.primary
                              : (isFilled
                                  ? colors.primary.withValues(alpha: 0.6)
                                  : (isDark ? Colors.white.withValues(alpha: 0.12) : colors.divider)),
                          width: isFocused ? 2 : 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        char,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            Text(
              _errorMessage!,
              style: TextStyle(
                color: colors.error,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 24),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_secondsRemaining > 0)
                Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 18, color: colors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      'ارسال مجدد تا ${_formatTime(_secondsRemaining)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )
              else
                TextButton.icon(
                  onPressed: _isResending ? null : _resendCode,
                  icon: _isResending
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
                        )
                      : Icon(Icons.refresh_rounded, size: 18, color: colors.primary),
                  label: Text(
                    'ارسال مجدد کد',
                    style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold),
                  ),
                ),

              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: (_isLoading || rawDigits.length != 6) ? null : _verifyCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: colors.onPrimary),
                        )
                      : const Text('تأیید و ورود', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final sheetBody = Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        type: MaterialType.transparency,
        child: content,
      ),
    );

    if (!isGlass) {
      return Container(
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: sheetRadius,
          border: Border.all(
            color: isDark ? colors.border : colors.divider,
            width: 1.0,
          ),
        ),
        child: sheetBody,
      );
    }

    return ClipRRect(
      borderRadius: sheetRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.glassTint,
            borderRadius: sheetRadius,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.70),
              width: 1.0,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: sheetRadius,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: isDark ? 0.08 : 0.20),
                  Colors.white.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.45],
              ),
            ),
            child: sheetBody,
          ),
        ),
      ),
    );
  }
}
