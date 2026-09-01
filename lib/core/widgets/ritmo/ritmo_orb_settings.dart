// =============================================================================
//  Ritmo Orb Settings — سه سوئیچِ حباب
//
//  عمداً از SettingsService مستقل است. دلیلش معماری است، نه تنبلی:
//  آن سرویس هیچ ValueListenable نمی‌دهد (هر صفحه دستی _loadSettings + setState
//  می‌کند) و حباب باید در همان لحظه‌ای که کاربر سوئیچ را می‌زند محو شود —
//  نه بعد از رفت‌وبرگشتِ صفحه.
//
//  کلیدها در SharedPreferences می‌نشینند و هنوز در SettingsRegistry ثبت نشده‌اند.
//  ثبتشان کارِ بعدی است تا در جست‌وجوی تنظیمات، صادرات/واردات و تاریخچهٔ
//  تغییراتِ دستیار هم دیده شوند. تا آن روز، همین رشته‌ها باید بمانند.
// =============================================================================

import 'package:flutter/widgets.dart';
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
  RitmoOrbSettings._();

  static final RitmoOrbSettings instance = RitmoOrbSettings._();

  static const String keyEnabled = 'orb_enabled';
  static const String keyDockWhenTyping = 'orb_dock_when_typing';
  static const String keyEyes = 'orb_eyes_enabled';

  final ValueNotifier<bool> enabled = ValueNotifier<bool>(true);
  final ValueNotifier<bool> dockWhenTyping = ValueNotifier<bool>(true);
  final ValueNotifier<bool> eyes = ValueNotifier<bool>(true);

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
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      enabled.value = prefs.getBool(keyEnabled) ?? true;
      dockWhenTyping.value = prefs.getBool(keyDockWhenTyping) ?? true;
      eyes.value = prefs.getBool(keyEyes) ?? true;
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
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
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
