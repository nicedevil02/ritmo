import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/security/app_lock_service.dart';
import 'package:ritmo/core/security/pin_hasher.dart';
import 'package:ritmo/core/settings/settings_registry.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.child});
  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  final AppLockService _lockService = AppLockService.instance;
  bool _isLoading = true;
  bool _isLocked = false;
  String _enteredPin = '';
  String _pinErrorMessage = '';
  
  // Rate limiting / Cooldown
  int _failedAttempts = 0;
  DateTime? _lockoutEndTime;
  Timer? _cooldownTimer;

  // Cached lock configurations
  bool _lockEnabled = false;
  String? _lockPassword;
  bool _useDeviceLock = false;
  bool _biometricEnabled = false;
  int _lockTimeoutSecs = 300;
  
  DateTime? _pausedAt;
  bool _isAuthenticating = false;

  bool get _isCooldownActive =>
      _lockoutEndTime != null && DateTime.now().isBefore(_lockoutEndTime!);

  int get _cooldownRemainingSeconds {
    if (!_isCooldownActive) return 0;
    final diff = _lockoutEndTime!.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff + 1 : 1;
  }

  int get _expectedPinLength {
    final pass = _lockPassword ?? '';
    if (pass.isNotEmpty && pass.length <= 6 && !pass.startsWith('v2:')) {
      return pass.length;
    }
    return 4;
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!_isCooldownActive) {
        timer.cancel();
        setState(() {
          _failedAttempts = 0;
          _lockoutEndTime = null;
          _pinErrorMessage = '';
        });
      } else {
        setState(() {});
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettingsAndAuth();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _handlePause();
    } else if (state == AppLifecycleState.resumed) {
      _handleResume();
    }
  }

  Future<void> _handlePause() async {
    try {
      _lockEnabled = await _lockService.isLockEnabled();
      _lockPassword = await _lockService.getLockPassword();
      _useDeviceLock = await _lockService.useDeviceLock();
      
      final hasPassword = _lockPassword != null && _lockPassword!.isNotEmpty;

      if (_lockEnabled && (hasPassword || _useDeviceLock)) {
        _pausedAt = DateTime.now();
      }
    } catch (e, st) {
      RitmoLog.error('Settings', 'خطا در مدیریت توقف برنامه (قفل)', e, st);
    }
  }

  Future<void> _handleResume() async {
    try {
      _lockEnabled = await _lockService.isLockEnabled();
      _lockPassword = await _lockService.getLockPassword();
      _useDeviceLock = await _lockService.useDeviceLock();
      _biometricEnabled = await _lockService.isBiometricEnabled();
      _lockTimeoutSecs = await _lockService.getLockTimeoutSeconds();
      
      final hasPassword = _lockPassword != null && _lockPassword!.isNotEmpty;

      if (_lockEnabled && (hasPassword || _useDeviceLock) && _pausedAt != null) {
        if (_lockTimeoutSecs != AppLockTimeout.never) {
          final elapsedSecs = DateTime.now().difference(_pausedAt!).inSeconds;
          if (_lockTimeoutSecs == AppLockTimeout.immediate || elapsedSecs >= _lockTimeoutSecs) {
            if (mounted) {
              setState(() {
                _isLocked = true;
                _enteredPin = '';
                _pinErrorMessage = '';
              });
            }
          }
        }
      }
      _pausedAt = null;

      if (_isLocked && _lockEnabled && (_biometricEnabled || _useDeviceLock) && !_isCooldownActive) {
        unawaited(_authenticateDeviceLock());
      }
    } catch (e, st) {
      RitmoLog.error('Settings', 'خطا در مدیریت ازسرگیری برنامه (قفل)', e, st);
    }
  }

  Future<void> _loadSettingsAndAuth() async {
    try {
      _lockEnabled = await _lockService.isLockEnabled();
      _lockPassword = await _lockService.getLockPassword();
      _useDeviceLock = await _lockService.useDeviceLock();
      _biometricEnabled = await _lockService.isBiometricEnabled();
      _lockTimeoutSecs = await _lockService.getLockTimeoutSeconds();

      final hasPassword = _lockPassword != null && _lockPassword!.isNotEmpty;
      final shouldLock = _lockEnabled && (hasPassword || _useDeviceLock);

      if (mounted) {
        setState(() {
          _isLocked = shouldLock;
          _isLoading = false;
        });
      }

      if (shouldLock && (_biometricEnabled || _useDeviceLock) && !kIsWeb) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _isLocked && !_isCooldownActive) {
            unawaited(_authenticateDeviceLock());
          }
        });
      }
    } catch (e, st) {
      RitmoLog.error('Settings', 'خطا در بارگذاری تنظیمات گیت قفل برنامه', e, st);
      if (mounted) {
        setState(() {
          _isLocked = true;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _authenticateDeviceLock() async {
    if (kIsWeb || _isAuthenticating) return;
    
    setState(() {
      _isAuthenticating = true;
      _pinErrorMessage = '';
    });

    try {
      final success = await _lockService.authenticateWithDevice(
        reason: 'لطفاً برای ورود به برنامه احراز هویت کنید.',
        biometricOnly: _biometricEnabled && !_useDeviceLock, 
      );

      if (success) {
        await HapticFeedback.mediumImpact();
        if (mounted) {
          setState(() {
            _isLocked = false;
            _enteredPin = '';
            _pinErrorMessage = '';
            _failedAttempts = 0;
            _lockoutEndTime = null;
          });
          _cooldownTimer?.cancel();
        }
      } else {
        await HapticFeedback.heavyImpact();
        if (mounted) {
          setState(() {
            _pinErrorMessage = 'احراز هویت انجام نشد. لطفاً مجدداً تلاش کنید.';
          });
        }
      }
    } catch (e, st) {
      RitmoLog.error('Settings', 'خطا در احراز هویت بیومتریک گیت ورود', e, st);
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  void _onPinKeyTapped(String key) {
    if (_isCooldownActive) return;
    final correctPin = _lockPassword ?? '';
    if (correctPin.isEmpty) return;
    final expectedLength = _expectedPinLength;
    if (_enteredPin.length >= expectedLength) return;
    
    HapticFeedback.lightImpact();
    setState(() {
      _pinErrorMessage = '';
      _enteredPin += key;
    });

    if (_enteredPin.length == expectedLength) {
      Future.delayed(const Duration(milliseconds: 200), () async {
        final result = PinHasher.verifyAndUpgrade(_enteredPin, correctPin);
        if (result.isValid) {
          if (result.upgradedHash != null) {
            await _lockService.setLockPassword(result.upgradedHash!);
            _lockPassword = result.upgradedHash!;
          }
          await HapticFeedback.mediumImpact();
          if (mounted) {
            setState(() {
              _isLocked = false;
              _enteredPin = '';
              _pinErrorMessage = '';
              _failedAttempts = 0;
              _lockoutEndTime = null;
            });
            _cooldownTimer?.cancel();
          }
        } else {
          await HapticFeedback.heavyImpact();
          if (mounted) {
            setState(() {
              _enteredPin = '';
              _failedAttempts++;
              if (_failedAttempts >= 5) {
                _lockoutEndTime = DateTime.now().add(const Duration(seconds: 30));
                _startCooldownTimer();
                _pinErrorMessage = 'تعداد تلاش‌های ناموفق بیش از حد مجاز است. لطفاً ۳۰ ثانیه صبر کنید.';
              } else {
                _pinErrorMessage = 'رمز عبور نادرست است. دوباره تلاش کنید.';
              }
            });
          }
        }
      });
    }
  }

  void _onBackspaceTapped() {
    if (_isCooldownActive || _enteredPin.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _pinErrorMessage = '';
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
  }

  Future<void> _handleForgotPassword() async {
    final isSupported = await _lockService.isDeviceSupported();
    final canCheck = await _lockService.canCheckBiometrics();
    final useDeviceLock = await _lockService.useDeviceLock();

    if (!isSupported && !canCheck && !useDeviceLock) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'بازیابی رمز عبور',
            style: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: const Text(
            'این دستگاه از قفل بیومتریک یا قفل سیستم‌عامل پشتیبانی نمی‌کند. در صورت فراموشی رمز عبور، برای حفظ امنیت داده‌ها، بازیابی فقط از طریق پاک‌سازی داده‌های برنامه یا نصب مجدد امکان‌پذیر است.',
            style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 13, height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('متوجه شدم', style: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    try {
      final success = await _lockService.authenticateWithDevice(
        reason: 'لطفاً برای بازنشانی و حذف رمز عبور برنامه، هویت خود را تایید کنید.',
        biometricOnly: false,
      );

      if (success) {
        await _lockService.setLockPassword('');
        await _lockService.setLockEnabled(false);
        if (mounted) {
          setState(() {
            _isLocked = false;
            _enteredPin = '';
            _pinErrorMessage = '';
            _lockPassword = '';
            _lockEnabled = false;
            _failedAttempts = 0;
            _lockoutEndTime = null;
          });
          _cooldownTimer?.cancel();
        }
      } else {
        if (mounted) {
          setState(() {
            _pinErrorMessage = 'احراز هویت دستگاه برای بازنشانی تایید نشد.';
          });
        }
      }
    } catch (e, st) {
      RitmoLog.error('Settings', 'خطا در بازیابی رمز با قفل دستگاه', e, st);
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
      return const Material(
        color: Color(0xff08090C),
        child: Center(child: CircularProgressIndicator(color: Color(0xff5B8AF5))),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = context.colors;

    final hasRitmoPin = _lockPassword != null && _lockPassword!.isNotEmpty;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Stack(
        children: [
          IgnorePointer(
            ignoring: _isLocked,
            child: widget.child,
          ),
          if (_isLocked)
            Positioned.fill(
              child: Scaffold(
                backgroundColor: isDark ? const Color(0xff08090C) : const Color(0xffF2F5FA),
                body: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isDark
                          ? [const Color(0xff0F1322), const Color(0xff08090C)]
                          : [const Color(0xffF2F6FF), const Color(0xffE2EAFC)],
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(flex: 2),
                        // App Lock Header
                        Icon(
                          _useDeviceLock ? CupertinoIcons.device_phone_portrait : CupertinoIcons.lock_shield_fill, 
                          color: const Color(0xff5B8AF5), 
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'قفل امنیت ریتمو',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: colors.textPrimary,
                            fontFamily: 'Vazirmatn',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            _useDeviceLock && !hasRitmoPin
                                ? 'این برنامه با قفل امنیت گوشی شما محافظت می‌شود. لطفاً برای ورود دکمه زیر را فشار دهید.'
                                : 'لطفاً برای ورود به برنامه، رمز عبور ${_toPersianDigits(_expectedPinLength.toString())} رقمی خود را وارد کنید.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.textSecondary,
                              height: 1.6,
                              fontFamily: 'Vazirmatn',
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Exclusive UI Case 1: Device Lock Only (No Ritmo PIN)
                        if (_useDeviceLock && !hasRitmoPin) ...[
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            icon: const Icon(CupertinoIcons.shield_fill, size: 20),
                            label: const Text(
                              'تایید هویت با قفل گوشی',
                              style: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff5B8AF5),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              elevation: 2,
                            ),
                            onPressed: _authenticateDeviceLock,
                          ),
                          const SizedBox(height: 16),
                          if (_pinErrorMessage.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Text(
                                _pinErrorMessage,
                                style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          const Spacer(flex: 3),
                        ]
                        // Exclusive UI Case 2: Ritmo PIN (Keypad & Dot Indicators)
                        else ...[
                          // Dot Indicators
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(_expectedPinLength, (index) {
                              final isFilled = _enteredPin.length > index;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                margin: const EdgeInsets.symmetric(horizontal: 8),
                                height: 16,
                                width: 16,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isFilled ? const Color(0xff5B8AF5) : Colors.transparent,
                                  border: Border.all(
                                    color: isFilled ? const Color(0xff5B8AF5) : colors.textSecondary.withValues(alpha: 0.4),
                                    width: 2.5,
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 20),

                          if (_isCooldownActive)
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 24),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(CupertinoIcons.hourglass, color: Colors.redAccent, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'لطفاً صبر کنید: ${_toPersianDigits(_cooldownRemainingSeconds.toString())} ثانیه',
                                    style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            )
                          else if (_pinErrorMessage.isNotEmpty)
                            Text(
                              _pinErrorMessage,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold),
                            ),

                          const Spacer(),

                          // Keypad
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: ['1', '2', '3'].map(_buildKeypadButton).toList(),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: ['4', '5', '6'].map(_buildKeypadButton).toList(),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: ['7', '8', '9'].map(_buildKeypadButton).toList(),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    // Fingerprint / Biometric Fallback Button
                                    if ((_biometricEnabled || _useDeviceLock) && !kIsWeb) InkWell(
                                            onTap: _isCooldownActive ? null : _authenticateDeviceLock,
                                            borderRadius: BorderRadius.circular(30),
                                            child: Container(
                                              height: 60,
                                              width: 60,
                                              decoration: BoxDecoration(
                                                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(Icons.fingerprint, color: Color(0xff5B8AF5), size: 30),
                                            ),
                                          ) else const SizedBox(width: 60, height: 60),
                                    _buildKeypadButton('0'),
                                    // Backspace
                                    InkWell(
                                      onTap: _onBackspaceTapped,
                                      borderRadius: BorderRadius.circular(30),
                                      child: Container(
                                        height: 60,
                                        width: 60,
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(CupertinoIcons.delete_left, color: colors.textPrimary, size: 22),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Forgot PIN Button
                          TextButton(
                            onPressed: _handleForgotPassword,
                            child: const Text(
                              'فراموشی رمز عبور',
                              style: TextStyle(
                                fontFamily: 'Vazirmatn',
                                color: Color(0xff5B8AF5),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildKeypadButton(String key) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => _onPinKeyTapped(key),
      borderRadius: BorderRadius.circular(30),
      child: Container(
        height: 60,
        width: 60,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            _toPersianDigits(key),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
              fontFamily: 'Vazirmatn',
            ),
          ),
        ),
      ),
    );
  }
}
