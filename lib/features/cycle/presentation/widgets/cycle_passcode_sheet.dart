import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/features/cycle/logic/cycle_lock_service.dart';

enum CyclePasscodeSheetMode {
  setup,
  verifyBeforeEnable,
  verifyBeforeDisable,
  change,
  chooseSource,
}

class CyclePasscodeSheet extends StatefulWidget {
  const CyclePasscodeSheet({super.key, required this.mode, this.onSuccess});

  final CyclePasscodeSheetMode mode;
  final VoidCallback? onSuccess;

  static Future<bool?> show(
    BuildContext context, {
    required CyclePasscodeSheetMode mode,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CyclePasscodeSheet(mode: mode),
    );
  }

  @override
  State<CyclePasscodeSheet> createState() => _CyclePasscodeSheetState();
}

class _CyclePasscodeSheetState extends State<CyclePasscodeSheet>
    with SingleTickerProviderStateMixin {
  late CyclePasscodeSheetMode _currentMode;
  int _step = 1; // Used for multi-step flows (setup, change)
  String _enteredPin = '';
  String? _firstEnteredPin;
  String _errorMessage = '';
  bool _isLoading = false;
  bool _hasAppLock = false;
  bool _hasDedicatedPin = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.mode;
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(
      begin: 0,
      end: 12,
    ).chain(CurveTween(curve: Curves.elasticIn)).animate(_shakeController);

    _checkInitialState();
  }

  Future<void> _checkInitialState() async {
    final hasApp = await CycleLockService.instance.hasAppLockPassword();
    final hasDedicated = await CycleLockService.instance.hasCyclePin();
    if (mounted) {
      setState(() {
        _hasAppLock = hasApp;
        _hasDedicatedPin = hasDedicated;
      });
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _triggerErrorShake(String message) {
    HapticFeedback.heavyImpact();
    setState(() {
      _errorMessage = message;
      _enteredPin = '';
    });
    _shakeController.forward(from: 0.0);
  }

  void _onKeyTap(String digit) {
    if (_enteredPin.length >= 4 || _isLoading) return;
    HapticFeedback.lightImpact();
    setState(() {
      _errorMessage = '';
      _enteredPin += digit;
    });

    if (_enteredPin.length == 4) {
      _processPin();
    }
  }

  void _onBackspace() {
    if (_enteredPin.isEmpty || _isLoading) return;
    HapticFeedback.lightImpact();
    setState(() {
      _errorMessage = '';
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
  }

  Future<void> _processPin() async {
    setState(() => _isLoading = true);

    try {
      switch (_currentMode) {
        case CyclePasscodeSheetMode.setup:
          if (_step == 1) {
            // Save first PIN and proceed to confirmation
            setState(() {
              _firstEnteredPin = _enteredPin;
              _enteredPin = '';
              _step = 2;
              _isLoading = false;
            });
          } else {
            // Confirm PIN
            if (_enteredPin == _firstEnteredPin) {
              await CycleLockService.instance.setPin(_enteredPin);
              await HapticFeedback.mediumImpact();
              if (mounted) {
                RitmoToast.show(
                  context,
                  'رمز عبور اختصاصی چرخه با موفقیت تنظیم شد 🔒',
                );
                widget.onSuccess?.call();
                Navigator.pop(context, true);
              }
            } else {
              _triggerErrorShake(
                'رمز عبور با تکرار آن مطابقت ندارد. دوباره وارد کنید.',
              );
              setState(() {
                _firstEnteredPin = null;
                _step = 1;
                _isLoading = false;
              });
            }
          }
          break;

        case CyclePasscodeSheetMode.verifyBeforeEnable:
          final isValid = await CycleLockService.instance.verifyPin(
            _enteredPin,
          );
          if (isValid) {
            await CycleLockService.instance.setLockEnabled(true);
            await HapticFeedback.mediumImpact();
            if (mounted) {
              RitmoToast.show(context, 'قفل حریم خصوصی چرخه فعال شد 🔒');
              widget.onSuccess?.call();
              Navigator.pop(context, true);
            }
          } else {
            _triggerErrorShake('رمز عبور وارد شده نادرست است.');
            setState(() => _isLoading = false);
          }
          break;

        case CyclePasscodeSheetMode.verifyBeforeDisable:
          final isValid = await CycleLockService.instance.verifyPin(
            _enteredPin,
          );
          if (isValid) {
            await CycleLockService.instance.setLockEnabled(false);
            await HapticFeedback.mediumImpact();
            if (mounted) {
              RitmoToast.show(context, 'قفل حریم خصوصی چرخه غیرفعال شد 🔓');
              widget.onSuccess?.call();
              Navigator.pop(context, true);
            }
          } else {
            _triggerErrorShake('رمز عبور وارد شده نادرست است.');
            setState(() => _isLoading = false);
          }
          break;

        case CyclePasscodeSheetMode.change:
          if (_hasDedicatedPin && _step == 1) {
            // Step 1: Verify current PIN
            final isValid = await CycleLockService.instance.verifyPin(
              _enteredPin,
            );
            if (isValid) {
              setState(() {
                _step = 2;
                _enteredPin = '';
                _isLoading = false;
              });
            } else {
              _triggerErrorShake('رمز عبور فعلی نادرست است.');
              setState(() => _isLoading = false);
            }
          } else if (_step == 2 || (!_hasDedicatedPin && _step == 1)) {
            // Enter new PIN
            setState(() {
              _firstEnteredPin = _enteredPin;
              _enteredPin = '';
              _step = _hasDedicatedPin ? 3 : 2;
              _isLoading = false;
            });
          } else {
            // Confirm new PIN
            if (_enteredPin == _firstEnteredPin) {
              await CycleLockService.instance.setPin(_enteredPin);
              await HapticFeedback.mediumImpact();
              if (mounted) {
                RitmoToast.show(
                  context,
                  'رمز عبور چرخه با موفقیت تغییر یافت 🔒',
                );
                widget.onSuccess?.call();
                Navigator.pop(context, true);
              }
            } else {
              _triggerErrorShake('رمز عبور جدید با تکرار آن مطابقت ندارد.');
              setState(() {
                _firstEnteredPin = null;
                _step = _hasDedicatedPin ? 2 : 1;
                _isLoading = false;
              });
            }
          }
          break;

        case CyclePasscodeSheetMode.chooseSource:
          // Not used in numeric keypad
          break;
      }
    } catch (e) {
      _triggerErrorShake('خطایی در پردازش رمز رخ داد.');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _authenticateBiometrics() async {
    try {
      final didAuth = await CycleLockService.instance.authenticateBiometric(
        localizedReason: 'تأیید هویت جهت تنظیمات قفل چرخه',
      );
      if (didAuth && mounted) {
        await HapticFeedback.mediumImpact();
        if (!mounted) return;
        if (_currentMode == CyclePasscodeSheetMode.verifyBeforeEnable) {
          await CycleLockService.instance.setLockEnabled(true);
          if (mounted) {
            RitmoToast.show(context, 'قفل چرخه با موفقیت فعال شد 🔒');
            Navigator.pop(context, true);
          }
        } else if (_currentMode == CyclePasscodeSheetMode.verifyBeforeDisable) {
          await CycleLockService.instance.setLockEnabled(false);
          if (mounted) {
            RitmoToast.show(context, 'قفل چرخه غیرفعال شد 🔓');
            Navigator.pop(context, true);
          }
        } else if (_currentMode == CyclePasscodeSheetMode.change) {
          setState(() {
            _step = 2;
            _enteredPin = '';
          });
        }
      }
    } catch (e, st) {
      debugPrint('[CyclePasscodeSheet] Biometric auth error: $e, $st');
    }
  }

  Future<void> _selectAppLockSource() async {
    await CycleLockService.instance.setLockSource(CycleLockSource.appLock);
    await CycleLockService.instance.setLockEnabled(true);
    await HapticFeedback.mediumImpact();
    if (mounted) {
      RitmoToast.show(context, 'قفل چرخه با رمز اصلی برنامه فعال شد 🔒');
      widget.onSuccess?.call();
      Navigator.pop(context, true);
    }
  }

  String _getTitle() {
    switch (_currentMode) {
      case CyclePasscodeSheetMode.chooseSource:
        return 'انتخاب شیوهٔ رمز عبور چرخه';
      case CyclePasscodeSheetMode.setup:
        return _step == 1 ? 'تعیین رمز عبور ۴ رقمی' : 'تکرار رمز عبور جدید';
      case CyclePasscodeSheetMode.verifyBeforeEnable:
        return 'تأیید رمز عبور جهت فعال‌سازی';
      case CyclePasscodeSheetMode.verifyBeforeDisable:
        return 'غیرفعال‌سازی قفل چرخه';
      case CyclePasscodeSheetMode.change:
        if (_hasDedicatedPin && _step == 1) {
          return 'ورود رمز عبور فعلی';
        } else if ((_hasDedicatedPin && _step == 2) ||
            (!_hasDedicatedPin && _step == 1)) {
          return 'تعیین رمز عبور جدید';
        } else {
          return 'تکرار رمز عبور جدید';
        }
    }
  }

  String _getSubtitle() {
    switch (_currentMode) {
      case CyclePasscodeSheetMode.chooseSource:
        return 'می‌توانید از رمز اصلی برنامه استفاده کنید یا یک رمز اختصاصی برای چرخه تعیین نمایید.';
      case CyclePasscodeSheetMode.setup:
        return _step == 1
            ? 'یک رمز ۴ رقمی جهت حفاظت از بخش چرخه وارد کنید.'
            : 'جهت اطمینان، رمز ۴ رقمی را مجدداً وارد نمایید.';
      case CyclePasscodeSheetMode.verifyBeforeEnable:
        return 'برای اطمینان از حفظ بودن رمز، لطفاً رمز عبور فعلی را وارد کنید.';
      case CyclePasscodeSheetMode.verifyBeforeDisable:
        return 'برای خاموش کردن قفل، رمز عبور یا اثر انگشت خود را تأیید نمایید.';
      case CyclePasscodeSheetMode.change:
        if (_hasDedicatedPin && _step == 1) {
          return 'برای تغییر رمز، ابتدا رمز عبور فعلی را وارد کنید.';
        } else if ((_hasDedicatedPin && _step == 2) ||
            (!_hasDedicatedPin && _step == 1)) {
          return 'یک رمز عبور ۴ رقمی جدید وارد کنید.';
        } else {
          return 'رمز عبور جدید را مجدداً وارد نمایید.';
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: RitmoTheme.glassCardLight(
          borderRadius: 28,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.textSecondary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(
                        CupertinoIcons.xmark,
                        size: 20,
                        color: colors.textSecondary,
                      ),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                    Expanded(
                      child: Text(
                        _getTitle(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 40), // Balance close button
                  ],
                ),
                const SizedBox(height: 6),

                // Subtitle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    _getSubtitle(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                if (_currentMode == CyclePasscodeSheetMode.chooseSource)
                  _buildChooseSourceView(colors, isDark)
                else ...[
                  // 4 Dots Indicator
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(
                          _shakeAnimation.value *
                              (_shakeController.isAnimating
                                  ? (1 - _shakeController.value)
                                  : 0),
                          0,
                        ),
                        child: child,
                      );
                    },
                    child: _buildPinDots(colors),
                  ),

                  // Error message
                  if (_errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.medicalRed,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Numeric Keypad
                  _buildKeypad(colors, isDark),

                  // Forgot Password / Reset Link (Zero-Lockout safety net)
                  if (_currentMode ==
                          CyclePasscodeSheetMode.verifyBeforeEnable ||
                      (_currentMode == CyclePasscodeSheetMode.change &&
                          _step == 1)) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _currentMode = CyclePasscodeSheetMode.setup;
                          _step = 1;
                          _enteredPin = '';
                          _firstEnteredPin = null;
                          _errorMessage = '';
                        });
                      },
                      child: Text(
                        'رمز قبلی را به یاد ندارم (تعریف رمز جدید)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChooseSourceView(dynamic colors, bool isDark) {
    return Column(
      children: [
        if (_hasAppLock)
          _buildSourceCard(
            colors: colors,
            isDark: isDark,
            icon: CupertinoIcons.lock_shield_fill,
            iconColor: colors.primary,
            title: 'استفاده از رمز عبور اصلی برنامه',
            subtitle:
                'با همان رمزی که برای ورود به اپلیکیشن تعیین کرده‌اید، قفل چرخه باز می‌شود.',
            onTap: _selectAppLockSource,
          ),
        const SizedBox(height: 12),
        _buildSourceCard(
          colors: colors,
          isDark: isDark,
          icon: Icons.vpn_key_rounded,
          iconColor: colors.accent,
          title: 'تعریف رمز اختصاصی ۴ رقمی برای چرخه',
          subtitle:
              'یک رمز عبور مستقل و جداگانه فقط برای محافظت از بخش چرخه بدن تعیین کنید.',
          onTap: () {
            setState(() {
              _currentMode = CyclePasscodeSheetMode.setup;
              _step = 1;
              _enteredPin = '';
              _firstEnteredPin = null;
            });
          },
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildSourceCard({
    required dynamic colors,
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_left,
              color: colors.textSecondary,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinDots(dynamic colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final isFilled = index < _enteredPin.length;
        final isErr = _errorMessage.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 9),
          height: 15,
          width: isFilled ? 18 : 15,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isFilled
                ? LinearGradient(
                    colors: isErr
                        ? [
                            colors.error as Color,
                            (colors.error as Color).withValues(alpha: 0.8),
                          ]
                        : [
                            colors.primary as Color,
                            (colors.primary as Color).withValues(alpha: 0.85),
                          ],
                  )
                : null,
            color: isFilled
                ? null
                : (colors.borderSubtle as Color).withValues(alpha: 0.3),
            border: Border.all(
              color: isFilled
                  ? (isErr ? colors.error as Color : colors.primary as Color)
                  : colors.borderSubtle as Color,
              width: 1.2,
            ),
            boxShadow: isFilled
                ? [
                    BoxShadow(
                      color:
                          (isErr
                                  ? colors.error as Color
                                  : colors.primary as Color)
                              .withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }

  Widget _buildKeypad(dynamic colors, bool isDark) {
    const persianDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildKeyButton('1', persianDigits[1], colors, isDark),
              _buildKeyButton('2', persianDigits[2], colors, isDark),
              _buildKeyButton('3', persianDigits[3], colors, isDark),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildKeyButton('4', persianDigits[4], colors, isDark),
              _buildKeyButton('5', persianDigits[5], colors, isDark),
              _buildKeyButton('6', persianDigits[6], colors, isDark),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildKeyButton('7', persianDigits[7], colors, isDark),
              _buildKeyButton('8', persianDigits[8], colors, isDark),
              _buildKeyButton('9', persianDigits[9], colors, isDark),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Biometric key
              InkResponse(
                onTap: _authenticateBiometrics,
                radius: 36,
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: (colors.primary as Color).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (colors.primary as Color).withValues(alpha: 0.25),
                      width: 1.2,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.fingerprint,
                      size: 28,
                      color: colors.primary as Color,
                    ),
                  ),
                ),
              ),
              _buildKeyButton('0', persianDigits[0], colors, isDark),
              // Backspace key
              InkResponse(
                onTap: _onBackspace,
                radius: 36,
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.04),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? (colors.borderSubtle as Color).withValues(
                              alpha: 0.4,
                            )
                          : colors.borderSubtle as Color,
                      width: 1.0,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      CupertinoIcons.delete_left,
                      size: 22,
                      color: colors.textPrimary as Color,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeyButton(
    String val,
    String label,
    dynamic colors,
    bool isDark,
  ) {
    return InkResponse(
      onTap: () => _onKeyTap(val),
      radius: 36,
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark
              ? (colors.surfaceElevated as Color)
              : (colors.surface as Color),
          border: Border.all(
            color: isDark
                ? (colors.borderSubtle as Color).withValues(alpha: 0.5)
                : colors.borderSubtle as Color,
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
            label,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'Vazirmatn',
              color: colors.textPrimary as Color,
            ),
          ),
        ),
      ),
    );
  }
}
