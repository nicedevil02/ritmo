import 'package:flutter/foundation.dart';

/// اسنپ‌شات بودجهٔ هفتگی (S3-T4 / §۴٫۲)
@immutable
class MvBudgetSnapshot {
  final int moderateEquivalentMinutes;
  final double rawMetMinutes;
  final int strengthDays;
  final int targetMin; // 150
  final int targetOptimal; // 300
  final int strengthDaysTarget; // 2
  final double? forecastedModerateMinutes;
  final bool hasEnoughDataForForecast;

  const MvBudgetSnapshot({
    required this.moderateEquivalentMinutes,
    required this.rawMetMinutes,
    required this.strengthDays,
    this.targetMin = 150,
    this.targetOptimal = 300,
    this.strengthDaysTarget = 2,
    this.forecastedModerateMinutes,
    this.hasEnoughDataForForecast = false,
  });

  double get percentage => targetMin > 0
      ? (moderateEquivalentMinutes / targetMin).clamp(0.0, 1.5)
      : 0.0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MvBudgetSnapshot &&
          runtimeType == other.runtimeType &&
          moderateEquivalentMinutes == other.moderateEquivalentMinutes &&
          rawMetMinutes == other.rawMetMinutes &&
          strengthDays == other.strengthDays &&
          targetMin == other.targetMin &&
          targetOptimal == other.targetOptimal &&
          strengthDaysTarget == other.strengthDaysTarget &&
          forecastedModerateMinutes == other.forecastedModerateMinutes &&
          hasEnoughDataForForecast == other.hasEnoughDataForForecast;

  @override
  int get hashCode =>
      moderateEquivalentMinutes.hashCode ^
      rawMetMinutes.hashCode ^
      strengthDays.hashCode ^
      targetMin.hashCode ^
      targetOptimal.hashCode ^
      strengthDaysTarget.hashCode ^
      forecastedModerateMinutes.hashCode ^
      hasEnoughDataForForecast.hashCode;
}
