import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/cycle/logic/cycle_lock_service.dart';

class CycleLockGate extends StatefulWidget {
  const CycleLockGate({super.key, required this.child});
  final Widget child;

  @override
  State<CycleLockGate> createState() => _CycleLockGateState();
}

class _CycleLockGateState extends State<CycleLockGate>
    with WidgetsBindingObserver {
  final CycleLockService _lockService = CycleLockService.instance;
  bool _isLoading = true;
  bool _isLocked = true;
  bool _hasPin = false;
  String _enteredPin = '';
  String _pinErrorMessage = '';
  String? _firstEnteredPin;
  int _lockoutSeconds = 0;
  Timer? _lockoutTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLockStateAndAuth();
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _reLockOnBackground();
    }
  }

  Future<void> _reLockOnBackground() async {
    final lockEnabled = await _lockService.isLockEnabled();
    if (lockEnabled && mounted) {
      setState(() {
        _isLocked = true;
        _enteredPin = '';
        _firstEnteredPin = null;
        _pinErrorMessage = '';
      });
    }
  }

  Future<void> _loadLockStateAndAuth() async {
    try {
      final lockEnabled = await _lockService.isLockEnabled();
      final hasPin = await _lockService.hasAnyActivePin();
      final lockoutSecs = await _lockService.remainingLockoutSeconds();

      if (mounted) {
        setState(() {
          _hasPin = hasPin;
          _isLoading = false;
          _isLocked = lockEnabled;
          _lockoutSeconds = lockoutSecs;
        });
      }

      if (lockoutSecs > 0) {
        _startLockoutCountdown();
      }

      if (!lockEnabled) return;

      // If PIN is configured and not locked out, offer biometric prompt
      if (hasPin && lockoutSecs == 0 && !kIsWeb) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _isLocked) {
            _authenticateBiometrics();
          }
        });
      }
    } catch (e, st) {
      RitmoLogger.error(
        '[CycleLockGate] error checking lock state: $e',
        error: e,
        stack: st,
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _startLockoutCountdown() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_lockoutSeconds <= 1) {
        timer.cancel();
        setState(() {
          _lockoutSeconds = 0;
          _pinErrorMessage = '';
        });
      } else {
        setState(() {
          _lockoutSeconds--;
        });
      }
    });
  }

  Future<void> _authenticateBiometrics() async {
    if (kIsWeb || _lockoutSeconds > 0) return;
    try {
      final didAuth = await _lockService.authenticateBiometric();
      if (didAuth && mounted) {
        await HapticFeedback.mediumImpact();
        setState(() {
          _isLocked = false;
          _enteredPin = '';
          _pinErrorMessage = '';
        });
      }
    } catch (e, st) {
      RitmoLogger.error(
        '[CycleLockGate] Biometric auth error: $e',
        error: e,
        stack: st,
      );
    }
  }

  void _onPinKeyTapped(String key) {
    if (_lockoutSeconds > 0 || _enteredPin.length >= 4) return;
    HapticFeedback.lightImpact();
    setState(() {
      _pinErrorMessage = '';
      _enteredPin += key;
    });

    if (_enteredPin.length == 4) {
      _processCompletePin();
    }
  }

  Future<void> _processCompletePin() async {
    if (!_hasPin) {
      // First time PIN setup flow
      if (_firstEnteredPin == null) {
        setState(() {
          _firstEnteredPin = _enteredPin;
          _enteredPin = '';
          _pinErrorMessage = '';
        });
      } else {
        if (_enteredPin == _firstEnteredPin) {
          await _lockService.setPin(_enteredPin);
          await HapticFeedback.mediumImpact();
          if (mounted) {
            setState(() {
              _hasPin = true;
              _isLocked = false;
              _enteredPin = '';
              _firstEnteredPin = null;
            });
          }
        } else {
          await HapticFeedback.heavyImpact();
          if (mounted) {
            setState(() {
              _enteredPin = '';
              _firstEnteredPin = null;
              _pinErrorMessage =
                  'رمز عبور با تاییدیه مطابقت ندارد. دوباره تلاش کنید.';
            });
          }
        }
      }
    } else {
      // Verification flow
      final isValid = await _lockService.verifyPin(_enteredPin);
      if (isValid) {
        await HapticFeedback.mediumImpact();
        if (mounted) {
          setState(() {
            _isLocked = false;
            _enteredPin = '';
            _pinErrorMessage = '';
          });
        }
      } else {
        await HapticFeedback.heavyImpact();
        final remaining = await _lockService.remainingLockoutSeconds();
        if (mounted) {
          setState(() {
            _enteredPin = '';
            _lockoutSeconds = remaining;
            if (remaining > 0) {
              _pinErrorMessage =
                  'تعداد تلاش‌های ناموفق بیش از حد مجاز است. لطفاً کمی صبر کنید.';
              _startLockoutCountdown();
            } else {
              _pinErrorMessage = 'رمز عبور نادرست است. دوباره تلاش کنید.';
            }
          });
        }
      }
    }
  }

  void _onBackspaceTapped() {
    if (_lockoutSeconds > 0 || _enteredPin.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _pinErrorMessage = '';
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
  }

  Future<void> _optOutLock() async {
    await _lockService.setLockEnabled(false);
    if (mounted) {
      setState(() {
        _isLocked = false;
        _enteredPin = '';
        _firstEnteredPin = null;
      });
    }
  }

  String _toPersianDigits(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    var result = input;
    for (var i = 0; i < english.length; i++) {
      result = result.replaceAll(english[i], persian[i]);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Material(
        color: context.colors.background,
        child: Center(
          child: CircularProgressIndicator(color: context.colors.primary),
        ),
      );
    }

    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    var titleText = 'این بخش خصوصی است';
    var subtitleText = 'برای مشاهده اطلاعات، رمز عبور را وارد کنید.';

    if (!_hasPin) {
      if (_firstEnteredPin == null) {
        titleText = 'تعیین رمز عبور جدید';
        subtitleText =
            'یک رمز عبور ۴ رقمی جهت محافظت از اطلاعات این بخش تعیین کنید.';
      } else {
        titleText = 'تایید رمز عبور جدید';
        subtitleText =
            'لطفاً رمز عبور ۴ رقمی جدید خود را مجدداً وارد کنید تا تایید شود.';
      }
    }

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // C-09: Do NOT build or leak child in tree/semantics when locked
          if (!_isLocked) widget.child else const SizedBox.shrink(),

          if (_isLocked)
            ExcludeSemantics(
              excluding: false,
              child: Stack(
                children: [
                  // Fullscreen Immersive Glass Blur Backdrop
                  Positioned.fill(
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? colors.background.withValues(alpha: 0.88)
                                : colors.background.withValues(alpha: 0.94),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Modern 2026 Passcode Gateway
                  SafeArea(
                    child: Center(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 16,
                        ),
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 380),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Top Header Bar
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    IconButton(
                                      icon: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.08,
                                                )
                                              : Colors.black.withValues(
                                                  alpha: 0.05,
                                                ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          CupertinoIcons.xmark,
                                          color: colors.textSecondary,
                                          size: 16,
                                        ),
                                      ),
                                      onPressed: () =>
                                          Navigator.maybePop(context),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.primary.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          RitmoRadius.pill,
                                        ),
                                        border: Border.all(
                                          color: colors.primary.withValues(
                                            alpha: 0.2,
                                          ),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            CupertinoIcons.lock_shield_fill,
                                            color: colors.primary,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'حریم خصوصی چرخه',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: colors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(
                                      width: 40,
                                    ), // Balanced spacing
                                  ],
                                ),
                                const SizedBox(height: 24),

                                // Illuminated Dual-Ring Security Shield Badge
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: colors.primary.withValues(
                                      alpha: 0.08,
                                    ),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: colors.primary.withValues(
                                        alpha: 0.2,
                                      ),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 58,
                                      height: 58,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            colors.primary.withValues(
                                              alpha: 0.2,
                                            ),
                                            colors.primary.withValues(
                                              alpha: 0.08,
                                            ),
                                          ],
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        CupertinoIcons.shield_fill,
                                        color: colors.primary,
                                        size: 28,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Title & Subtitle
                                Text(
                                  titleText,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: colors.textPrimary,
                                    fontFamily: 'Vazirmatn',
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  child: Text(
                                    subtitleText,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: colors.textSecondary,
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Lockout Notice / Error Message
                                if (_lockoutSeconds > 0) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.warning.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: colors.warning.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      'قفل به دلیل تلاش‌های ناموفق: ${_toPersianDigits(_lockoutSeconds.toString())} ثانیه باقیمانده',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colors.warning,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ] else if (_pinErrorMessage.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.error.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: colors.error.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      _pinErrorMessage,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colors.error,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 20),

                                // PIN Indicator Glowing Capsules with Shake Animation
                                Semantics(
                                  liveRegion: true,
                                  label:
                                      '${_toPersianDigits(_enteredPin.length.toString())} رقم وارد شده',
                                  child:
                                      Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: List.generate(4, (index) {
                                              final isActive =
                                                  _enteredPin.length > index;
                                              final isErr =
                                                  _pinErrorMessage.isNotEmpty;

                                              return AnimatedContainer(
                                                duration: const Duration(
                                                  milliseconds: 200,
                                                ),
                                                curve: Curves.easeOutCubic,
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 9,
                                                    ),
                                                height: 15,
                                                width: isActive ? 18 : 15,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  gradient: isActive
                                                      ? LinearGradient(
                                                          colors: isErr
                                                              ? [
                                                                  colors.error,
                                                                  colors.error
                                                                      .withValues(
                                                                        alpha:
                                                                            0.8,
                                                                      ),
                                                                ]
                                                              : [
                                                                  colors
                                                                      .primary,
                                                                  colors.primary
                                                                      .withValues(
                                                                        alpha:
                                                                            0.85,
                                                                      ),
                                                                ],
                                                        )
                                                      : null,
                                                  color: isActive
                                                      ? null
                                                      : (isDark
                                                            ? Colors.white
                                                                  .withValues(
                                                                    alpha: 0.12,
                                                                  )
                                                            : Colors.black
                                                                  .withValues(
                                                                    alpha: 0.08,
                                                                  )),
                                                  border: Border.all(
                                                    color: isActive
                                                        ? (isErr
                                                              ? colors.error
                                                              : colors.primary)
                                                        : colors.borderSubtle,
                                                    width: 1.2,
                                                  ),
                                                  boxShadow: isActive
                                                      ? [
                                                          BoxShadow(
                                                            color:
                                                                (isErr
                                                                        ? colors
                                                                              .error
                                                                        : colors
                                                                              .primary)
                                                                    .withValues(
                                                                      alpha:
                                                                          0.4,
                                                                    ),
                                                            blurRadius: 8,
                                                            spreadRadius: 1,
                                                          ),
                                                        ]
                                                      : null,
                                                ),
                                              );
                                            }),
                                          )
                                          .animate(
                                            target: _pinErrorMessage.isNotEmpty
                                                ? 1.0
                                                : 0.0,
                                          )
                                          .shake(
                                            hz: 4,
                                            curve: Curves.easeInOut,
                                          ),
                                ),
                                const SizedBox(height: 32),

                                // Responsive Ergonomic Keypad
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 290,
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: ['1', '2', '3']
                                            .map(
                                              (k) => _buildKeyBtn(
                                                k,
                                                colors,
                                                isDark,
                                              ),
                                            )
                                            .toList(),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: ['4', '5', '6']
                                            .map(
                                              (k) => _buildKeyBtn(
                                                k,
                                                colors,
                                                isDark,
                                              ),
                                            )
                                            .toList(),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: ['7', '8', '9']
                                            .map(
                                              (k) => _buildKeyBtn(
                                                k,
                                                colors,
                                                isDark,
                                              ),
                                            )
                                            .toList(),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          // Biometric Quick Action Button (or placeholder)
                                          if (_hasPin &&
                                              _lockoutSeconds == 0 &&
                                              !kIsWeb)
                                            Semantics(
                                              label:
                                                  'ورود با اثر انگشت یا چهره',
                                              button: true,
                                              child: InkResponse(
                                                onTap: _authenticateBiometrics,
                                                radius: 36,
                                                child: Container(
                                                  height: 68,
                                                  width: 68,
                                                  decoration: BoxDecoration(
                                                    color: colors.primary
                                                        .withValues(alpha: 0.1),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: colors.primary
                                                          .withValues(
                                                            alpha: 0.25,
                                                          ),
                                                      width: 1.2,
                                                    ),
                                                  ),
                                                  child: Center(
                                                    child: Icon(
                                                      Icons.fingerprint,
                                                      color: colors.primary,
                                                      size: 28,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            )
                                          else
                                            const SizedBox(
                                              width: 68,
                                              height: 68,
                                            ),

                                          // Digit 0
                                          _buildKeyBtn('0', colors, isDark),

                                          // Backspace Button
                                          Semantics(
                                            label: 'پاک کردن رقم قبلی',
                                            button: true,
                                            child: InkResponse(
                                              onTap: _lockoutSeconds > 0
                                                  ? null
                                                  : _onBackspaceTapped,
                                              radius: 36,
                                              child: Container(
                                                height: 68,
                                                width: 68,
                                                decoration: BoxDecoration(
                                                  color: isDark
                                                      ? Colors.white.withValues(
                                                          alpha: 0.05,
                                                        )
                                                      : Colors.black.withValues(
                                                          alpha: 0.04,
                                                        ),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: isDark
                                                        ? colors.borderSubtle
                                                              .withValues(
                                                                alpha: 0.4,
                                                              )
                                                        : colors.borderSubtle,
                                                    width: 1.0,
                                                  ),
                                                ),
                                                child: Center(
                                                  child: Icon(
                                                    CupertinoIcons.delete_left,
                                                    color: colors.textPrimary,
                                                    size: 22,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Opt-out option for initial setup
                                if (!_hasPin) ...[
                                  const SizedBox(height: 24),
                                  TextButton(
                                    onPressed: _optOutLock,
                                    child: Text(
                                      'فعلاً قفل نمی‌خواهم',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
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

  Widget _buildKeyBtn(String key, RitmoColors colors, bool isDark) {
    final disabled = _lockoutSeconds > 0;
    return Semantics(
      label: 'رقم ${_toPersianDigits(key)}',
      button: true,
      enabled: !disabled,
      child: InkResponse(
        onTap: disabled ? null : () => _onPinKeyTapped(key),
        radius: 36,
        child: Container(
          height: 68,
          width: 68,
          decoration: BoxDecoration(
            color: isDark ? colors.surfaceElevated : colors.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark
                  ? colors.borderSubtle.withValues(alpha: 0.5)
                  : colors.borderSubtle,
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              _toPersianDigits(key),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'Vazirmatn',
                color: disabled ? colors.textTertiary : colors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
