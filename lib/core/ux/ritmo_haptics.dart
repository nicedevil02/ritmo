import 'package:flutter/services.dart';

class RitmoHaptics {
  // Light: tap اصلی، انتخاب
  static void tap() {
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
  }
  
  // Medium: تأیید، complete، start timer
  static void confirm() {
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }
  
  // Heavy: حذف، خطا، snooze
  static void warning() {
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }
  
  // Success: ثبت موفق، بکاپ موفق
  static void success() {
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }
  
  // Subtle: scroll snap، slider tick
  static void subtle() {
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
  }

  static void selection() => tap();

  static void sheetOpen() {
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  static void sheetClose() {
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
  }

  static void error() {
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }
}
