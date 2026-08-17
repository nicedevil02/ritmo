// C-06, C-07, C-08, C-09, C-43: CycleLockGate
// Privacy gate protecting cycle content with zero background leakage,
// strict biometric verification, SecureKeyStore hashed PIN, lockout display, and accessible Persian keypad.
import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      final hasPin = await _lockService.hasCyclePin();
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
    } catch (_) {
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
    } catch (_) {}
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
                  // Blur background overlay
                  Positioned.fill(
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          color: isDark
                              ? colors.background.withValues(alpha: 0.85)
                              : colors.background.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ),

                  // PIN Entry Card
                  Center(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 32,
                        ),
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: RitmoTheme.glassCardLight(
                            borderRadius: 28,
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              constraints: const BoxConstraints(maxWidth: 340),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Header Row
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          CupertinoIcons.xmark,
                                          color: colors.textSecondary,
                                          size: 20,
                                        ),
                                        onPressed: () =>
                                            Navigator.maybePop(context),
                                      ),
                                      Text(
                                        'حریم خصوصی چرخه',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: colors.textPrimary,
                                        ),
                                      ),
                                      Icon(
                                        CupertinoIcons.lock_fill,
                                        color: colors.primary,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                  Divider(height: 20, color: colors.divider),

                                  // Shield Icon
                                  Container(
                                    height: 48,
                                    width: 48,
                                    decoration: BoxDecoration(
                                      color: colors.primary.withValues(
                                        alpha: 0.12,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      CupertinoIcons.shield_fill,
                                      color: colors.primary,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  // Title & Subtitle
                                  Text(
                                    titleText,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    subtitleText,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colors.textSecondary,
                                      height: 1.4,
                                    ),
                                  ),

                                  // Lockout Notice / Error Message
                                  if (_lockoutSeconds > 0) ...[
                                    const SizedBox(height: 10),
                                    Text(
                                      'قفل به دلیل تلاش‌های مکرر ناموفق: ${_toPersianDigits(_lockoutSeconds.toString())} ثانیه باقیمانده',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: colors.warning,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ] else if (_pinErrorMessage.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Text(
                                      _pinErrorMessage,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: colors.warning,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 16),

                                  // PIN Dots with Accessibility LiveRegion
                                  Semantics(
                                    liveRegion: true,
                                    label:
                                        '${_toPersianDigits(_enteredPin.length.toString())} رقم وارد شده',
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: List.generate(4, (index) {
                                        final isActive =
                                            _enteredPin.length > index;
                                        return Container(
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          height: 12,
                                          width: 12,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isActive
                                                ? colors.primary
                                                : colors.textTertiary
                                                      .withValues(alpha: 0.3),
                                          ),
                                        );
                                      }),
                                    ),
                                  ),

                                  // Biometrics Button (if PIN is set)
                                  if (_hasPin &&
                                      _lockoutSeconds == 0 &&
                                      !kIsWeb) ...[
                                    const SizedBox(height: 14),
                                    TextButton.icon(
                                      onPressed: _authenticateBiometrics,
                                      icon: Icon(
                                        CupertinoIcons.device_phone_portrait,
                                        size: 16,
                                        color: colors.primary,
                                      ),
                                      label: Text(
                                        'ورود با اثر انگشت / چهره',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: colors.primary,
                                        ),
                                      ),
                                    ),
                                  ],

                                  // Opt-out option for new users
                                  if (!_hasPin) ...[
                                    const SizedBox(height: 8),
                                    TextButton(
                                      onPressed: _optOutLock,
                                      child: Text(
                                        'فعلاً قفل نمی‌خواهم',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 16),

                                  // Responsive Keypad
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 260,
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceEvenly,
                                          children: ['1', '2', '3']
                                              .map(
                                                (k) => _buildKeyBtn(k, colors),
                                              )
                                              .toList(),
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceEvenly,
                                          children: ['4', '5', '6']
                                              .map(
                                                (k) => _buildKeyBtn(k, colors),
                                              )
                                              .toList(),
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceEvenly,
                                          children: ['7', '8', '9']
                                              .map(
                                                (k) => _buildKeyBtn(k, colors),
                                              )
                                              .toList(),
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceEvenly,
                                          children: [
                                            const SizedBox(
                                              width: 52,
                                              height: 52,
                                            ),
                                            _buildKeyBtn('0', colors),
                                            Semantics(
                                              label: 'پاک کردن رقم قبلی',
                                              button: true,
                                              child: InkWell(
                                                onTap: _lockoutSeconds > 0
                                                    ? null
                                                    : _onBackspaceTapped,
                                                borderRadius:
                                                    BorderRadius.circular(26),
                                                child: Container(
                                                  height: 52,
                                                  width: 52,
                                                  decoration: BoxDecoration(
                                                    color: colors.textPrimary
                                                        .withValues(
                                                          alpha: 0.04,
                                                        ),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    CupertinoIcons.delete_left,
                                                    color: colors.textPrimary,
                                                    size: 18,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
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

  Widget _buildKeyBtn(String key, RitmoColors colors) {
    final disabled = _lockoutSeconds > 0;
    return Semantics(
      label: 'رقم ${_toPersianDigits(key)}',
      button: true,
      enabled: !disabled,
      child: InkWell(
        onTap: disabled ? null : () => _onPinKeyTapped(key),
        borderRadius: BorderRadius.circular(26),
        child: Container(
          height: 52,
          width: 52,
          decoration: BoxDecoration(
            color: colors.textPrimary.withValues(alpha: disabled ? 0.02 : 0.06),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              _toPersianDigits(key),
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: disabled ? colors.textTertiary : colors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
