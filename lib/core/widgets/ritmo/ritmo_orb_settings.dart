// =============================================================================
//  Ritmo Orb Settings — سه سوئیچِ حباب
//
//  کلیدها در SettingsRegistry ثبت شده و از طریق SettingsService ذخیره و همگام
//  می‌شوند (همراه با مهاجرت خودکار از SharedPreferences).
//  در عین حال ValueNotifierها جهت دسترسی فوری و سنکرون بدون await در فریم‌های
//  نقاشی حفظ شده‌اند و با تغییراتِ سرویس همگام می‌مانند.
// =============================================================================

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class RitmoOrbSettingsSnapshot {
  const RitmoOrbSettingsSnapshot({
    required this.enabled,
    required this.dockWhenTyping,
    required this.eyes,
  });

  /// حبابِ دستیار روشن است یا کاربر خاموشش کرده.
  final bool enabled;

  /// وقتی کیبرد باز است، حباب دورِ کادرِ تایپ پهن شود.
  final bool dockWhenTyping;

  /// چشم‌ها ظاهر شوند و پلک بزنند.
  final bool eyes;

  @override
  bool operator ==(Object other) =>
      other is RitmoOrbSettingsSnapshot &&
      other.enabled == enabled &&
      other.dockWhenTyping == dockWhenTyping &&
      other.eyes == eyes;

  @override
  int get hashCode => Object.hash(enabled, dockWhenTyping, eyes);
}

class RitmoOrbSettings {
  RitmoOrbSettings._() {
    _ensureSubscribed();
  }

  static final RitmoOrbSettings instance = RitmoOrbSettings._();

  static const String keyEnabled = 'orb_enabled';
  static const String keyDockWhenTyping = 'orb_dock_when_typing';
  static const String keyEyes = 'orb_eyes_enabled';

  final ValueNotifier<bool> enabled = ValueNotifier<bool>(true);
  final ValueNotifier<bool> dockWhenTyping = ValueNotifier<bool>(true);
  final ValueNotifier<bool> eyes = ValueNotifier<bool>(true);

  StreamSubscription<String>? _settingsSubscription;

  void _ensureSubscribed() {
    _settingsSubscription ??= SettingsService.instance.changes.listen((key) {
      if (key == keyEnabled) {
        final val = SettingsService.instance.get<bool>(keyEnabled);
        if (enabled.value != val) enabled.value = val;
      } else if (key == keyDockWhenTyping) {
        final val = SettingsService.instance.get<bool>(keyDockWhenTyping);
        if (dockWhenTyping.value != val) dockWhenTyping.value = val;
      } else if (key == keyEyes) {
        final val = SettingsService.instance.get<bool>(keyEyes);
        if (eyes.value != val) eyes.value = val;
      }
    });
  }

  /// یک شنوندهٔ ترکیبی برای ویجت‌هایی که به هر سه سوئیچ وابسته‌اند.
  late final Listenable listenable = Listenable.merge(
    <Listenable>[enabled, dockWhenTyping, eyes],
  );

  Future<void>? _loading;
  bool _loaded = false;

  bool get isLoaded => _loaded;

  RitmoOrbSettingsSnapshot get snapshot => RitmoOrbSettingsSnapshot(
        enabled: enabled.value,
        dockWhenTyping: dockWhenTyping.value,
        eyes: eyes.value,
      );

  /// خواندنِ یک‌بارهٔ تنظیمات. چند بار صدا زدنش بی‌خطر است.
  Future<void> load() {
    if (_loaded) return Future<void>.value();
    return _loading ??= _read();
  }

  Future<void> _read() async {
    _ensureSubscribed();
    try {
      if (SettingsService.instance.isInitialized) {
        enabled.value = SettingsService.instance.get<bool>(keyEnabled);
        dockWhenTyping.value =
            SettingsService.instance.get<bool>(keyDockWhenTyping);
        eyes.value = SettingsService.instance.get<bool>(keyEyes);
      } else {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        if (prefs.containsKey(keyEnabled)) {
          enabled.value = prefs.getBool(keyEnabled) ?? true;
        }
        if (prefs.containsKey(keyDockWhenTyping)) {
          dockWhenTyping.value = prefs.getBool(keyDockWhenTyping) ?? true;
        }
        if (prefs.containsKey(keyEyes)) {
          eyes.value = prefs.getBool(keyEyes) ?? true;
        }
      }
    } catch (e) {
      // اگر حافظهٔ محلی در دسترس نبود (مثلاً در تست)، پیش‌فرض‌ها سرِ جایشان‌اند.
      debugPrint('RitmoOrbSettings: خواندنِ تنظیماتِ حباب ناموفق بود ($e)');
    }
    _loaded = true;
    _loading = null;
  }

  Future<void> setEnabled(bool value) => _write(keyEnabled, value, enabled);

  Future<void> setDockWhenTyping(bool value) =>
      _write(keyDockWhenTyping, value, dockWhenTyping);

  Future<void> setEyes(bool value) => _write(keyEyes, value, eyes);

  Future<void> _write(
    String key,
    bool value,
    ValueNotifier<bool> target,
  ) async {
    // اول UI، بعد دیسک: کاربر نباید منتظرِ نوشتنِ حافظه بماند.
    target.value = value;
    try {
      if (SettingsService.instance.isInitialized) {
        await SettingsService.instance.set(key, value);
      } else {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool(key, value);
      }
    } catch (e) {
      debugPrint('RitmoOrbSettings: ذخیرهٔ $key ناموفق بود ($e)');
    }
  }

  @visibleForTesting
  void debugSet({bool? on, bool? dock, bool? withEyes}) {
    if (on != null) enabled.value = on;
    if (dock != null) dockWhenTyping.value = dock;
    if (withEyes != null) eyes.value = withEyes;
  }

  @visibleForTesting
  void debugReset() {
    _loaded = false;
    _loading = null;
    enabled.value = true;
    dockWhenTyping.value = true;
    eyes.value = true;
  }
}

/// بازسازی وقتی هر یک از سه سوئیچ عوض شود.
class RitmoOrbSettingsBuilder extends StatelessWidget {
  const RitmoOrbSettingsBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, RitmoOrbSettingsSnapshot settings)
      builder;

  @override
  Widget build(BuildContext context) {
    final RitmoOrbSettings settings = RitmoOrbSettings.instance;
    return ListenableBuilder(
      listenable: settings.listenable,
      builder: (context, _) => builder(context, settings.snapshot),
    );
  }
}
