import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/security/app_lock_service.dart';
import 'package:ritmo/core/services/secure_key_store.dart';
import 'package:ritmo/core/settings/settings_registry.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/cycle_privacy_guard.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/widgets/ritmo_module_app_bar.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_page_scaffold.dart';
import 'package:ritmo/features/cycle/logic/cycle_lock_service.dart';
import 'package:ritmo/features/settings/presentation/widgets/settings_section.dart';
import 'package:ritmo/features/settings/presentation/widgets/settings_tile.dart';

class SecurityGroupScreen extends StatefulWidget {
  final String? highlightKey;

  const SecurityGroupScreen({
    super.key,
    this.highlightKey,
  });

  @override
  State<SecurityGroupScreen> createState() => _SecurityGroupScreenState();
}

class _SecurityGroupScreenState extends State<SecurityGroupScreen> {
  bool _appLockEnabled = false;
  bool _biometricEnabled = false;
  bool _canUseBiometrics = false;
  int _timeoutSeconds = 300;
  bool _hasAppPassword = false;

  bool _cycleBiometricEnabled = false;
  bool _hasCyclePassword = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    _appLockEnabled = SettingsService.instance.get<bool>('app_lock_enabled');
    _biometricEnabled = SettingsService.instance.get<bool>('app_biometric_enabled');
    _timeoutSeconds = SettingsService.instance.get<int>('app_lock_timeout_seconds');

    final appPass = await SecureKeyStore.getKey('app_lock_password');
    _hasAppPassword = appPass != null && appPass.isNotEmpty;

    _cycleBiometricEnabled = SettingsService.instance.get<bool>('cycle_biometric_enabled');
    final cyclePass = await SecureKeyStore.getKey('cycle_lock_password');
    _hasCyclePassword = cyclePass != null && cyclePass.isNotEmpty;

    try {
      final auth = LocalAuthentication();
      final canCheck = await auth.canCheckBiometrics;
      final isSupported = await auth.isDeviceSupported();
      _canUseBiometrics = canCheck && isSupported;
    } catch (e, st) {
      RitmoLog.error('Settings', 'خطا در بررسی پشتیبانی بیومتریک', e, st);
      _canUseBiometrics = false;
    }

    if (mounted) setState(() {});
  }

  Future<void> _update(String key, Object val) async {
    await SettingsService.instance.set(key, val);
    await _loadState();
  }

  Future<bool> _setPin(String keyName, String title) async {
    final colors = context.colors;
    final pinController = TextEditingController();
    bool saved = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => RitmoCustomDialog(
          title: title,
          icon: Icons.lock_outline_rounded,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'یک رمز عددی ۴ رقمی وارد کنید:',
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                obscureText: true,
                placeholder: '••••',
                style: TextStyle(fontSize: 20, letterSpacing: 6, color: colors.textPrimary),
              ),
            ],
          ),
          actions: [
            RitmoSecondaryButton(
              label: 'انصراف',
              onPressed: () => Navigator.pop(ctx),
            ),
            const SizedBox(width: 10),
            RitmoPrimaryButton(
              label: 'ذخیره رمز',
              onPressed: () async {
                final pin = pinController.text.trim();
                if (pin.length < 4) {
                  RitmoToast.show(context, 'رمز باید حداقل ۴ رقم باشد.', iconColor: colors.medicalRed);
                  return;
                }
                Navigator.pop(ctx);
                if (keyName == 'cycle_lock_password') {
                  await CycleLockService.instance.setPin(pin);
                } else {
                  await AppLockService.instance.setPin(pin);
                }
                saved = true;
                await _loadState();
                if (mounted) {
                  RitmoToast.show(context, 'رمز با موفقیت ذخیره شد.');
                }
              },
            ),
          ],
        ),
      );
    } finally {
      pinController.dispose();
    }
    return saved;
  }

  Future<void> _deletePin(String keyName, String title) async {
    final confirmed = await RitmoDialog.show(
      context,
      title: 'حذف $title',
      content: 'آیا از حذف این رمز عبور اطمینان دارید؟ قفل برنامه غیرفعال خواهد شد.',
      confirmLabel: 'حذف رمز',
      cancelLabel: 'انصراف',
      isDestructive: true,
    );

    if (confirmed == true) {
      if (keyName == 'cycle_lock_password') {
        await CycleLockService.instance.clearPin();
        await SettingsService.instance.set('cycle_biometric_enabled', false);
      } else {
        await AppLockService.instance.setLockPassword(null);
        await SettingsService.instance.set('app_lock_enabled', false);
        await SettingsService.instance.set('app_biometric_enabled', false);
      }
      await _loadState();
      if (mounted) {
        RitmoToast.show(context, 'رمز عبور با موفقیت حذف شد.');
      }
    }
  }

  Future<void> _onAppLockToggled(bool val) async {
    if (val && !_hasAppPassword) {
      final pinSet = await _setPin('app_lock_password', 'تعریف رمز قفل برنامه');
      if (!pinSet) return;
    }
    await _update('app_lock_enabled', val);
  }

  Future<void> _onAppBiometricToggled(bool val) async {
    if (!_canUseBiometrics) {
      RitmoToast.show(context, 'این دستگاه از حسگر اثر انگشت یا چهره پشتیبانی نمی‌کند یا حسگری ثبت نشده است.');
      return;
    }
    if (val) {
      if (!_hasAppPassword) {
        final pinSet = await _setPin('app_lock_password', 'تعریف رمز قفل برنامه');
        if (!pinSet) return;
      }
      try {
        final auth = LocalAuthentication();
        final authenticated = await auth.authenticate(
          localizedReason: 'لطفاً برای فعال‌سازی قفل بیومتریک، هویت خود را تایید کنید',
          biometricOnly: true,
          persistAcrossBackgrounding: true,
        );
        if (!authenticated) {
          if (mounted) {
            RitmoToast.show(context, 'احراز هویت بیومتریک ناموفق بود.');
          }
          return;
        }
      } catch (e, st) {
        RitmoLog.error('Settings', 'خطا در احراز هویت بیومتریک', e, st);
        if (mounted) {
          RitmoToast.show(context, 'خطا در دسترسی به حسگر بیومتریک.');
        }
        return;
      }
    }
    await _update('app_biometric_enabled', val);
  }

  Future<void> _onCycleBiometricToggled(bool val) async {
    if (!_canUseBiometrics) {
      RitmoToast.show(context, 'این دستگاه از حسگر اثر انگشت یا چهره پشتیبانی نمی‌کند یا حسگری ثبت نشده است.');
      return;
    }
    if (val) {
      if (!_hasCyclePassword) {
        final pinSet = await _setPin('cycle_lock_password', 'تعریف رمز بخش چرخهٔ زیستی');
        if (!pinSet) return;
      }
      try {
        final auth = LocalAuthentication();
        final authenticated = await auth.authenticate(
          localizedReason: 'لطفاً برای فعال‌سازی قفل بیومتریک چرخه، هویت خود را تایید کنید',
          biometricOnly: true,
          persistAcrossBackgrounding: true,
        );
        if (!authenticated) {
          if (mounted) {
            RitmoToast.show(context, 'احراز هویت بیومتریک ناموفق بود.');
          }
          return;
        }
      } catch (e, st) {
        RitmoLog.error('Settings', 'خطا در احراز هویت بیومتریک چرخه', e, st);
        if (mounted) {
          RitmoToast.show(context, 'خطا در دسترسی به حسگر بیومتریک.');
        }
        return;
      }
    }
    await _update('cycle_biometric_enabled', val);
  }

  void _showPrivacyPolicy() {
    RitmoDialog.show(
      context,
      title: 'سیاست حریم خصوصی و امنیت',
      content: 'ریتمو یک نرم‌افزار متمرکز بر حریم خصوصی محلی (Local-First) است.\n\n'
          '۱. کلیه اطلاعات شما اعم از روتین‌ها، یادآوری‌ها، داده‌های زیستی و یادداشت‌ها روی دستگاه شما ذخیره می‌شوند.\n'
          '۲. رمزهای عبور و کلیدهای هوش مصنوعی در محیط امن سخت‌افزاری دستگاه (Keychain / KeyStore) نگهداری می‌شوند.\n'
          '۳. هیچ‌گونه داده‌ای بدون رضایت صریح و فعال‌سازی پردازش ابری به خارج از دستگاه ارسال نخواهد شد.',
      confirmLabel: 'متوجه شدم',
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final showAdvanced = SettingsService.instance.get<bool>('show_advanced_settings');
    final isCycleVisible = CyclePrivacyGuard.isVisible({
      'user_gender': SettingsService.instance.get<String>('user_gender'),
      'module_cycle_enabled': ModuleGate.instance.isEnabled('module_cycle_enabled') ? 'true' : 'false',
    });

    final timeoutLabels = <int, String>{
      AppLockTimeout.immediate: 'فوری',
      60: '۱ دقیقه',
      300: '۵ دقیقه',
      900: '۱۵ دقیقه',
      AppLockTimeout.never: 'هرگز',
    };

    return RitmoPageScaffold(
      padding: EdgeInsets.zero,
      appBar: RitmoModuleAppBar.fromContext(
        context: context,
        title: 'امنیت و حریم خصوصی',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 60),
        child: Column(
          children: [
            SettingsSection(
              title: 'قفل کلی اپلیکیشن',
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('فعال‌سازی قفل برنامه', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.textPrimary)),
                          const SizedBox(height: 4),
                          Text('درخواست رمز عبور یا بیومتریک هنگام ورود', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                        ],
                      ),
                      CupertinoSwitch(
                        value: _appLockEnabled,
                        activeTrackColor: colors.primary,
                        onChanged: _onAppLockToggled,
                      ),
                    ],
                  ),
                ),
                SettingsTile(
                  title: _hasAppPassword ? 'تغییر رمز قفل برنامه' : 'تعریف رمز عددی',
                  subtitle: _hasAppPassword ? 'رمز عددی ۴ رقمی فعال است' : 'هنوز رمزی تعریف نشده است',
                  trailing: _hasAppPassword
                      ? CupertinoButton(
                          padding: EdgeInsets.zero,
                          child: Icon(CupertinoIcons.trash, size: 18, color: colors.medicalRed),
                          onPressed: () => _deletePin('app_lock_password', 'رمز قفل برنامه'),
                        )
                      : null,
                  onTap: () => _setPin('app_lock_password', 'رمز قفل برنامه'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ورود با اثر انگشت / تشخیص چهره', style: TextStyle(fontSize: 14, color: _canUseBiometrics ? colors.textPrimary : colors.textSecondary)),
                            if (!_canUseBiometrics) ...[
                              const SizedBox(height: 4),
                              Text('این دستگاه از حسگر اثر انگشت یا چهره پشتیبانی نمی‌کند یا حسگری ثبت نشده است', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      CupertinoSwitch(
                        value: _canUseBiometrics && _biometricEnabled,
                        activeTrackColor: colors.primary,
                        onChanged: _canUseBiometrics ? _onAppBiometricToggled : null,
                      ),
                    ],
                  ),
                ),
                if (showAdvanced)
                  SettingsTile(
                    title: 'مهلت قفل خودکار',
                    subtitle: timeoutLabels[_timeoutSeconds] ?? '${toPersianDigits(_timeoutSeconds)} ثانیه',
                    onTap: () {
                      showModalBottomSheet<void>(
                        context: context,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        builder: (modalCtx) {
                          final modalColors = modalCtx.colors;
                          final isDark = modalCtx.isDark;
                          final isGlass = modalCtx.isGlassEnabled;
                          final blur = modalCtx.glassBlurSigma.clamp(0.0, 50.0);
                          const sheetRadius = BorderRadius.vertical(top: Radius.circular(28));

                          final content = Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Center(
                                  child: Container(
                                    width: 40,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: modalColors.textSecondary.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: modalColors.primary.withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        CupertinoIcons.timer,
                                        color: modalColors.primary,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'انتخاب مهلت قفل خودکار',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: modalColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                ...timeoutLabels.entries.map((e) {
                                  final isCurrent = _timeoutSeconds == e.key;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: isCurrent
                                          ? modalColors.primary.withValues(alpha: isDark ? 0.18 : 0.12)
                                          : (isDark
                                              ? Colors.white.withValues(alpha: 0.04)
                                              : Colors.black.withValues(alpha: 0.03)),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isCurrent
                                            ? modalColors.primary.withValues(alpha: 0.5)
                                            : (isDark
                                                ? Colors.white.withValues(alpha: 0.08)
                                                : Colors.black.withValues(alpha: 0.06)),
                                        width: isCurrent ? 1.5 : 1.0,
                                      ),
                                    ),
                                    child: ListTile(
                                      dense: true,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      title: Text(
                                        e.value,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                          color: isCurrent ? modalColors.primary : modalColors.textPrimary,
                                        ),
                                      ),
                                      trailing: isCurrent
                                          ? Icon(
                                              CupertinoIcons.checkmark_circle_fill,
                                              color: modalColors.primary,
                                              size: 20,
                                            )
                                          : null,
                                      onTap: () {
                                        RitmoHapticsPolicy.selection();
                                        _update('app_lock_timeout_seconds', e.key);
                                        Navigator.pop(modalCtx);
                                      },
                                    ),
                                  );
                                }),
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
                                color: modalColors.surfaceElevated,
                                borderRadius: sheetRadius,
                                border: Border.all(
                                  color: isDark ? modalColors.border : modalColors.divider,
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
                                  color: modalColors.glassTint,
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
                        },
                      );
                    },
                  ),
              ],
            ),
            if (isCycleVisible) ...[
              SettingsSection(
                title: 'قفل اختصاصی بخش چرخهٔ زیستی',
                footer: 'این رمز کاملاً مجزا از رمز ورود به برنامه است و امنیت بخش سلامت بانوان را تامین می‌کند.',
                children: [
                  SettingsTile(
                    title: _hasCyclePassword ? 'تغییر رمز بخش خصوصی' : 'تعریف رمز بخش خصوصی',
                    subtitle: _hasCyclePassword ? 'رمز ۴ رقمی مجزا فعال است' : 'رمز اختصاصی تعریف نشده',
                    trailing: _hasCyclePassword
                        ? CupertinoButton(
                            padding: EdgeInsets.zero,
                            child: Icon(CupertinoIcons.trash, size: 18, color: colors.medicalRed),
                            onPressed: () => _deletePin('cycle_lock_password', 'رمز بخش چرخه'),
                          )
                        : null,
                    onTap: () => _setPin('cycle_lock_password', 'رمز بخش خصوصی چرخه'),
                  ),
                  if (showAdvanced)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('بیومتریک اختصاصی بخش چرخه', style: TextStyle(fontSize: 14, color: _canUseBiometrics ? colors.textPrimary : colors.textSecondary)),
                                if (!_canUseBiometrics) ...[
                                  const SizedBox(height: 4),
                                  Text('این دستگاه از حسگر اثر انگشت یا چهره پشتیبانی نمی‌کند یا حسگری ثبت نشده است', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          CupertinoSwitch(
                            value: _canUseBiometrics && _cycleBiometricEnabled,
                            activeTrackColor: colors.primary,
                            onChanged: _canUseBiometrics ? _onCycleBiometricToggled : null,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            SettingsSection(
              title: 'حریم خصوصی و شفافیت',
              children: [
                SettingsTile(
                  title: 'سیاست حریم خصوصی',
                  subtitle: 'تعهد ریتمو به ذخیره‌سازی محلی و عدم ردیابی',
                  leading: Icon(CupertinoIcons.shield_lefthalf_fill, color: colors.primary),
                  onTap: _showPrivacyPolicy,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
