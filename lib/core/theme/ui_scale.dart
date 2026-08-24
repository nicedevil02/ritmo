import 'package:ritmo/core/theme/tokens/ritmo_breakpoints.dart';

enum RitmoDensityLevel { compact, comfortable, spacious, xl }

abstract final class RitmoUiScale {
  static const List<double> textSteps = [0.85, 0.925, 1.0, 1.10, 1.25, 1.40];
  static const List<int> textPercents = [85, 93, 100, 110, 125, 140];
  static const int defaultTextPercent = 100;
  static const int minTextPercent = 85;
  static const int maxTextPercent = 140;
  static const RitmoDensityLevel defaultDensity = RitmoDensityLevel.comfortable;

  /// درصد را به شاخص گسسته (۰ تا ۵) تبدیل می‌کند.
  static int stepIndexFromPercent(int percent) {
    final factor = factorFromPercent(percent);
    for (var i = 0; i < textSteps.length; i++) {
      if ((textSteps[i] - factor).abs() < 0.001) return i;
    }
    return 2; // پیش‌فرض ۱۰۰٪ (شاخص ۲)
  }

  /// شاخص گسسته (۰ تا ۵) را به درصد متناظر تبدیل می‌کند.
  static int percentFromStepIndex(int index) {
    final clamped = index.clamp(0, textSteps.length - 1);
    return textPercents[clamped];
  }

  /// درصد ذخیره‌شده در تنظیمات را به ضریب تبدیل و روی نزدیک‌ترین پله snap می‌کند.
  static double factorFromPercent(int percent) {
    if (percent <= 85) return textSteps[0];
    if (percent >= 140) return textSteps[5];
    final target = percent / 100.0;
    var closest = textSteps[0];
    var minDiff = (closest - target).abs();
    for (final step in textSteps) {
      final diff = (step - target).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = step;
      }
    }
    return closest;
  }

  static int percentFromFactor(double factor) {
    return (factor * 100).round();
  }

  static double effectiveTextScale({
    required double osScale,
    required int appPercent,
    required bool followOs,
  }) {
    final appFactor = factorFromPercent(appPercent);
    final rawScale = followOs ? (appFactor * osScale) : appFactor;
    return rawScale.clamp(
      RitmoBreakpoints.supportedMinTextScale,
      RitmoBreakpoints.supportedMaxTextScale,
    );
  }

  static double densityFactor(RitmoDensityLevel level) {
    switch (level) {
      case RitmoDensityLevel.compact:
        return 0.92;
      case RitmoDensityLevel.comfortable:
        return 1.00;
      case RitmoDensityLevel.spacious:
        return 1.12;
      case RitmoDensityLevel.xl:
        return 1.24;
    }
  }

  /// برچسب فارسی پله برای UI: «خیلی کوچک»، «کوچک»، «معمولی»، «بزرگ»، «خیلی بزرگ»، «بیشینه».
  static String textLabelFor(int percent) {
    final factor = factorFromPercent(percent);
    if (factor <= 0.86) return 'خیلی کوچک';
    if (factor <= 0.93) return 'کوچک';
    if (factor <= 1.01) return 'معمولی (پیش‌فرض)';
    if (factor <= 1.11) return 'بزرگ';
    if (factor <= 1.26) return 'خیلی بزرگ';
    return 'بیشینه';
  }

  /// برچسب فارسی چگالی: «فشرده»، «معمولی»، «راحت»، «بزرگ».
  static String densityLabelFor(RitmoDensityLevel level) {
    switch (level) {
      case RitmoDensityLevel.compact:
        return 'فشرده';
      case RitmoDensityLevel.comfortable:
        return 'معمولی';
      case RitmoDensityLevel.spacious:
        return 'راحت';
      case RitmoDensityLevel.xl:
        return 'بزرگ';
    }
  }

  /// در برابر ورودی خراب/ناشناس مقاوم باشد و مقدار پیش‌فرض را برگرداند.
  static RitmoDensityLevel parseDensity(String? raw) {
    if (raw == null || raw.isEmpty) return defaultDensity;
    for (final level in RitmoDensityLevel.values) {
      if (level.name == raw) return level;
    }
    return defaultDensity;
  }

  static String serializeDensity(RitmoDensityLevel value) {
    return value.name;
  }
}
