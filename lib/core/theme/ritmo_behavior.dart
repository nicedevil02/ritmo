// توکن‌های رفتاری دسترسی‌پذیری و تم
// کنترلی بر شفافیت و جلوه‌های شیشه‌ای

import 'package:flutter/material.dart';

@immutable
class RitmoBehavior extends ThemeExtension<RitmoBehavior> {
  const RitmoBehavior({
    required this.reduceTransparency,
    this.glassBlurSigma = 20.0,
    this.glassOpacityPercent = 35,
  });

  final bool reduceTransparency;
  final double glassBlurSigma;
  final int glassOpacityPercent;

  @override
  RitmoBehavior copyWith({
    bool? reduceTransparency,
    double? glassBlurSigma,
    int? glassOpacityPercent,
  }) {
    return RitmoBehavior(
      reduceTransparency: reduceTransparency ?? this.reduceTransparency,
      glassBlurSigma: glassBlurSigma ?? this.glassBlurSigma,
      glassOpacityPercent: glassOpacityPercent ?? this.glassOpacityPercent,
    );
  }

  @override
  RitmoBehavior lerp(ThemeExtension<RitmoBehavior>? other, double t) {
    if (other is! RitmoBehavior) return this;
    return t < 0.5 ? this : other;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RitmoBehavior &&
          runtimeType == other.runtimeType &&
          reduceTransparency == other.reduceTransparency &&
          glassBlurSigma == other.glassBlurSigma &&
          glassOpacityPercent == other.glassOpacityPercent;

  @override
  int get hashCode => Object.hash(
        reduceTransparency,
        glassBlurSigma,
        glassOpacityPercent,
      );
}
