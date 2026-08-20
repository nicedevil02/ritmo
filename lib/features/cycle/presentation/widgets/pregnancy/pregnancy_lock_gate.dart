import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/cycle/logic/cycle_lock_service.dart';

/// PRG-40: PregnancyLockGate
/// Independent lock gate for the pregnancy section (`preg_lock_enabled`).
/// Enforces PIN/Biometric verification when pregnancy lock is activated.
class PregnancyLockGate extends StatefulWidget {
  const PregnancyLockGate({super.key, required this.child, this.settings});

  final Widget child;
  final Map<String, String>? settings;

  @override
  State<PregnancyLockGate> createState() => _PregnancyLockGateState();
}

class _PregnancyLockGateState extends State<PregnancyLockGate>
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
  void didUpdateWidget(PregnancyLockGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.settings != oldWidget.settings) {
      _loadLockStateAndAuth();
    }
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
    final lockEnabled = widget.settings?['preg_lock_enabled'] == 'true';
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
      final lockEnabled = widget.settings?['preg_lock_enabled'] == 'true';
      if (!lockEnabled) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isLocked = false;
          });
        }
        return;
      }

      final hasPin = await _lockService.hasAnyActivePin();
      final lockoutSecs = await _lockService.remainingLockoutSeconds();

      if (mounted) {
        setState(() {
          _hasPin = hasPin;
          _isLoading = false;
          _isLocked = true;
          _lockoutSeconds = lockoutSecs;
        });
      }

      if (lockoutSecs > 0) {
        _startLockoutCountdown();
      }
    } catch (e, st) {
      RitmoLogger.error(
        '[PregnancyLockGate] error checking lock state: $e',
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
      final didAuth = await _lockService.authenticateBiometric(
        localizedReason: 'تأیید هویت جهت ورود به بخش بارداری',
      );
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
        '[PregnancyLockGate] Biometric auth error: $e',
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
                  'تعداد دفعات اشتباه بیش از حد مجاز بود. لطفاً ${PersianDigits.toFa(remaining.toString())} ثانیه صبر کنید.';
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

    final lockEnabled = widget.settings?['preg_lock_enabled'] == 'true';
    if (!lockEnabled || !_isLocked) {
      return widget.child;
    }

    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    var titleText = 'بخش بارداری قفل است';
    var subtitleText = 'برای مشاهده اطلاعات بارداری، رمز عبور را وارد کنید.';

    if (!_hasPin) {
      if (_firstEnteredPin == null) {
        titleText = 'تعیین رمز عبور جدید';
        subtitleText =
            'یک رمز عبور ۴ رقمی جهت محافظت از اطلاعات بارداری تعیین کنید.';
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
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              RitmoRadius.pill,
                            ),
                            border: Border.all(
                              color: colors.primary.withValues(alpha: 0.2),
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
                                'حریم خصوصی بارداری',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: colors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colors.primary.withValues(alpha: 0.2),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              CupertinoIcons.lock_fill,
                              color: colors.primary,
                              size: 32,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          titleText,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
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
                        const SizedBox(height: 16),
                        if (_pinErrorMessage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              _pinErrorMessage,
                              style: TextStyle(
                                color: colors.error,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        // 4 PIN Dots
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(4, (index) {
                            final filled = index < _enteredPin.length;
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: filled
                                    ? colors.primary
                                    : Colors.transparent,
                                border: Border.all(
                                  color: filled
                                      ? colors.primary
                                      : colors.textSecondary.withValues(
                                          alpha: 0.4,
                                        ),
                                  width: 2,
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 28),
                        // Number Pad Grid
                        _buildNumberPad(context),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberPad(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget buildKey(String text, {VoidCallback? onTap, Widget? customChild}) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(40),
          child: Container(
            width: 70,
            height: 70,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03),
            ),
            child:
                customChild ??
                Text(
                  PersianDigits.toFa(text),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            buildKey('1', onTap: () => _onPinKeyTapped('1')),
            buildKey('2', onTap: () => _onPinKeyTapped('2')),
            buildKey('3', onTap: () => _onPinKeyTapped('3')),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            buildKey('4', onTap: () => _onPinKeyTapped('4')),
            buildKey('5', onTap: () => _onPinKeyTapped('5')),
            buildKey('6', onTap: () => _onPinKeyTapped('6')),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            buildKey('7', onTap: () => _onPinKeyTapped('7')),
            buildKey('8', onTap: () => _onPinKeyTapped('8')),
            buildKey('9', onTap: () => _onPinKeyTapped('9')),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (_hasPin && !kIsWeb)
              buildKey(
                '',
                onTap: _authenticateBiometrics,
                customChild: Icon(
                  Icons.fingerprint,
                  color: colors.primary,
                  size: 28,
                ),
              )
            else
              const SizedBox(width: 70, height: 70),
            buildKey('0', onTap: () => _onPinKeyTapped('0')),
            buildKey(
              '',
              onTap: _onBackspaceTapped,
              customChild: Icon(
                CupertinoIcons.delete_left,
                color: colors.textSecondary,
                size: 24,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
