// ریپازیتوری تنظیمات تم — یکپارچه با SettingsService و مدیریت state دینامیک

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_palette.dart';
import 'package:ritmo/core/theme/theme_preferences.dart';
import 'package:ritmo/core/theme/ui_scale.dart';

class ThemeRepository {
  final ValueNotifier<ThemePreferences> preferencesNotifier =
      ValueNotifier<ThemePreferences>(ThemePreferences.defaults);

  final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(
    ThemeMode.system,
  );

  StreamSubscription<String>? _settingsSubscription;

  Future<void> init() async {
    _syncFromSettings();
    await _settingsSubscription?.cancel();
    _settingsSubscription = SettingsService.instance.changes.listen((key) {
      if (key == 'theme_mode' ||
          key == 'theme_palette' ||
          key == 'theme_reduce_transparency' ||
          key == 'glass_blur_intensity' ||
          key == 'glass_opacity_percent' ||
          key == 'theme_true_black' ||
          key == 'ui_text_scale' ||
          key == 'ui_text_follow_os' ||
          key == 'ui_density') {
        _syncFromSettings();
      }
    });
  }

  void _syncFromSettings() {
    try {
      final modeStr = SettingsService.instance.get<String>('theme_mode');
      final paletteStr = SettingsService.instance.get<String>('theme_palette');
      final reduceTrans = SettingsService.instance.get<bool>(
        'theme_reduce_transparency',
      );
      final glassBlurInt = SettingsService.instance.get<int>(
        'glass_blur_intensity',
      );
      final glassOpacity = SettingsService.instance.get<int>(
        'glass_opacity_percent',
      );
      final trueBlk = SettingsService.instance.get<bool>('theme_true_black');
      final textScalePercent = SettingsService.instance.get<int>(
        'ui_text_scale',
      );
      final followOs = SettingsService.instance.get<bool>('ui_text_follow_os');
      final densityStr = SettingsService.instance.get<String>('ui_density');

      final mode = _parseThemeMode(modeStr);
      final paletteId = RitmoPalette.parseId(paletteStr);
      final density = RitmoUiScale.parseDensity(densityStr);

      final prefs = ThemePreferences(
        mode: mode,
        paletteId: paletteId,
        reduceTransparency: reduceTrans,
        trueBlack: trueBlk,
        glassBlurSigma: glassBlurInt.toDouble(),
        glassOpacityPercent: glassOpacity,
        textScalePercent: textScalePercent,
        followOsTextScale: followOs,
        density: density,
      );

      preferencesNotifier.value = prefs;
      themeModeNotifier.value = mode;
    } catch (e, st) {
      RitmoLog.error(
        'Settings',
        'خطا در مقداردهی اولیه ThemeRepository',
        e,
        st,
      );
    }
  }

  void dispose() {
    unawaited(_settingsSubscription?.cancel());
    _settingsSubscription = null;
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
    return SettingsService.instance.set(
      'theme_mode',
      _serializeThemeMode(mode),
    );
  }

  Future<bool> updatePalette(RitmoPaletteId paletteId) async {
    final current = preferencesNotifier.value;
    final updated = current.copyWith(paletteId: paletteId);
    preferencesNotifier.value = updated;
    return SettingsService.instance.set(
      'theme_palette',
      RitmoPalette.serializeId(paletteId),
    );
  }

  Future<bool> updateReduceTransparency(bool reduceTransparency) async {
    final current = preferencesNotifier.value;
    final updated = current.copyWith(reduceTransparency: reduceTransparency);
    preferencesNotifier.value = updated;
    return SettingsService.instance.set(
      'theme_reduce_transparency',
      reduceTransparency,
    );
  }

  Future<bool> updateGlassBlurSigma(double sigma) async {
    final current = preferencesNotifier.value;
    final updated = current.copyWith(glassBlurSigma: sigma);
    preferencesNotifier.value = updated;
    return SettingsService.instance.set('glass_blur_intensity', sigma.round());
  }

  Future<bool> updateGlassOpacityPercent(int percent) async {
    final current = preferencesNotifier.value;
    final updated = current.copyWith(glassOpacityPercent: percent);
    preferencesNotifier.value = updated;
    return SettingsService.instance.set('glass_opacity_percent', percent);
  }

  Future<bool> updateTrueBlack(bool trueBlack) async {
    final current = preferencesNotifier.value;
    final updated = current.copyWith(trueBlack: trueBlack);
    preferencesNotifier.value = updated;
    return SettingsService.instance.set('theme_true_black', trueBlack);
  }

  Future<bool> updateTextScalePercent(int percent) async {
    final current = preferencesNotifier.value;
    final updated = current.copyWith(textScalePercent: percent);
    preferencesNotifier.value = updated;
    return SettingsService.instance.set('ui_text_scale', percent);
  }

  Future<bool> updateFollowOsTextScale(bool followOs) async {
    final current = preferencesNotifier.value;
    final updated = current.copyWith(followOsTextScale: followOs);
    preferencesNotifier.value = updated;
    return SettingsService.instance.set('ui_text_follow_os', followOs);
  }

  Future<bool> updateDensity(RitmoDensityLevel density) async {
    final current = preferencesNotifier.value;
    final updated = current.copyWith(density: density);
    preferencesNotifier.value = updated;
    return SettingsService.instance.set(
      'ui_density',
      RitmoUiScale.serializeDensity(density),
    );
  }

  Future<bool> resetAppearance() async {
    const defaults = ThemePreferences.defaults;
    preferencesNotifier.value = defaults;
    themeModeNotifier.value = defaults.mode;

    return SettingsService.instance.setMany({
      'theme_mode': _serializeThemeMode(defaults.mode),
      'theme_palette': RitmoPalette.serializeId(defaults.paletteId),
      'theme_reduce_transparency': false,
      'glass_blur_intensity': 20,
      'glass_opacity_percent': 35,
      'theme_true_black': false,
      'ui_text_scale': defaults.textScalePercent,
      'ui_text_follow_os': defaults.followOsTextScale,
      'ui_density': RitmoUiScale.serializeDensity(defaults.density),
    });
  }
}
