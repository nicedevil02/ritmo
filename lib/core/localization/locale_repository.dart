import 'package:flutter/material.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/settings/settings_service.dart';

class LocaleRepository {
  final ValueNotifier<Locale> localeNotifier =
      ValueNotifier<Locale>(const Locale('fa', 'IR'));

  Future<void> init() async {
    try {
      final localeVal = SettingsService.instance.get<String>('locale');
      if (localeVal.startsWith('fa')) {
        localeNotifier.value = const Locale('fa', 'IR');
      } else if (localeVal.startsWith('en')) {
        localeNotifier.value = const Locale('en', 'US');
      } else {
        localeNotifier.value = Locale(localeVal);
      }
    } catch (e, st) {
      RitmoLog.error('Settings', 'خطا در مقداردهی اولیه مخزن زبان', e, st);
    }
  }

  Future<void> updateLocale(Locale locale) async {
    try {
      localeNotifier.value = locale;
      await SettingsService.instance.set('locale', locale.languageCode);
    } catch (e, st) {
      RitmoLog.error('Settings', 'خطا در به‌روزرسانی زبان', e, st);
    }
  }
}
