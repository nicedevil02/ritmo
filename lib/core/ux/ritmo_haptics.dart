import 'package:flutter/services.dart';
import 'package:ritmo/core/settings/settings_service.dart';

class RitmoHaptics {
  static bool get _isEnabled =>
      !SettingsService.instance.isInitialized ||
      SettingsService.instance.get<bool>('haptic_feedback_enabled');

  // Light: tap اصلی، انتخاب
  static void tap() {
    if (!_isEnabled) return;
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
  }
  
  // Medium: تأیید، complete، start timer
  static void confirm() {
    if (!_isEnabled) return;
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }
  
  // Heavy: حذف، خطا، snooze
  static void warning() {
    if (!_isEnabled) return;
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }
  
  // Success: ثبت موفق، بکاپ موفق
  static void success() {
    if (!_isEnabled) return;
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }
  
  // Subtle: scroll snap، slider tick
  static void subtle() {
    if (!_isEnabled) return;
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
  }

  static void selection() => tap();

  static void sheetOpen() {
    if (!_isEnabled) return;
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  static void sheetClose() {
    if (!_isEnabled) return;
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
  }

  static void error() {
    if (!_isEnabled) return;
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }
}
