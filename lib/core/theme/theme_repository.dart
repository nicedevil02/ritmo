// ریپازیتوری تنظیمات تم — یکپارچه با SettingsService و مدیریت state دینامیک

import 'package:flutter/material.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_palette.dart';
import 'package:ritmo/core/theme/theme_preferences.dart';

class ThemeRepository {
  final ValueNotifier<ThemePreferences> preferencesNotifier =
      ValueNotifier<ThemePreferences>(ThemePreferences.defaults);

  final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  Future<void> init() async {
    try {
      final modeStr = SettingsService.instance.get<String>('theme_mode');
      final paletteStr = SettingsService.instance.get<String>('theme_palette');
      final reduceTrans = SettingsService.instance.get<bool>('theme_reduce_transparency');
      final trueBlk = SettingsService.instance.get<bool>('theme_true_black');

      final mode = _parseThemeMode(modeStr);
      final paletteId = RitmoPalette.parseId(paletteStr);

      final prefs = ThemePreferences(
        mode: mode,
        paletteId: paletteId,
        reduceTransparency: reduceTrans,
        trueBlack: trueBlk,
      );

      preferencesNotifier.value = prefs;
      themeModeNotifier.value = mode;
    } catch (e, st) {
      RitmoLog.error('Settings', 'خطا در مقداردهی اولیه ThemeRepository', e, st);
    }
  }

  ThemeMode _parseThemeMode(String val) {
    if (val == 'light') return ThemeMode.light;
    if (val == 'system') return ThemeMode.system;
    if (val == 'dark') return ThemeMode.dark;
    RitmoLog.warning('Theme', 'حالت تم ناشناخته "$val". بازگشت به system.');
    return ThemeMode.system;
  }

  String _serializeThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  Future<bool> updateThemeMode(ThemeMode mode) async {
    final current = preferencesNotifier.value;
    final updated = current.copyWith(mode: mode);
    preferencesNotifier.value = updated;
    themeModeNotifier.value = mode;
    return SettingsService.instance.set('theme_mode', _serializeThemeMode(mode));
  }

  Future<bool> updatePalette(RitmoPaletteId paletteId) async {
    final current = preferencesNotifier.value;
    final updated = current.copyWith(paletteId: paletteId);
    preferencesNotifier.value = updated;
    return SettingsService.instance.set('theme_palette', RitmoPalette.serializeId(paletteId));
  }

  Future<bool> updateReduceTransparency(bool reduceTransparency) async {
    final current = preferencesNotifier.value;
    final updated = current.copyWith(reduceTransparency: reduceTransparency);
    preferencesNotifier.value = updated;
    return SettingsService.instance.set('theme_reduce_transparency', reduceTransparency);
  }

  Future<bool> updateTrueBlack(bool trueBlack) async {
    final current = preferencesNotifier.value;
    final updated = current.copyWith(trueBlack: trueBlack);
    preferencesNotifier.value = updated;
    return SettingsService.instance.set('theme_true_black', trueBlack);
  }

  Future<bool> resetAppearance() async {
    const defaults = ThemePreferences.defaults;
    preferencesNotifier.value = defaults;
    themeModeNotifier.value = defaults.mode;

    return SettingsService.instance.setMany({
      'theme_mode': _serializeThemeMode(defaults.mode),
      'theme_palette': RitmoPalette.serializeId(defaults.paletteId),
      'theme_reduce_transparency': false,
      'theme_true_black': false,
    });
  }
}
