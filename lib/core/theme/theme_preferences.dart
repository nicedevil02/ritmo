// مدل تنظیمات ظاهر و تم کاربر
// شامل حالت روشنایی، شناسه پالت و تنظیمات دسترسی‌پذیری

import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_palette.dart';
import 'package:ritmo/core/theme/ui_scale.dart';

@immutable
class ThemePreferences {
  const ThemePreferences({
    required this.mode,
    required this.paletteId,
    required this.reduceTransparency,
    required this.trueBlack,
    this.glassBlurSigma = 20.0,
    this.glassOpacityPercent = 35,
    this.autoDarkAtMaghrib = false, // Hook رزروشده بر اساس اوقات شرعی
    this.textScalePercent = RitmoUiScale.defaultTextPercent,
    this.followOsTextScale = true,
    this.density = RitmoUiScale.defaultDensity,
  });

  final ThemeMode mode;
  final RitmoPaletteId paletteId;
  final bool reduceTransparency;
  final bool trueBlack;
  final double glassBlurSigma;
  final int glassOpacityPercent;
  final bool autoDarkAtMaghrib;
  final int textScalePercent;
  final bool followOsTextScale;
  final RitmoDensityLevel density;

  static const ThemePreferences defaults = ThemePreferences(
    mode: ThemeMode.system,
    paletteId: RitmoPaletteId.jadeNoir,
    reduceTransparency: false,
    trueBlack: false,
    glassBlurSigma: 20.0,
    glassOpacityPercent: 35,
    autoDarkAtMaghrib: false,
    textScalePercent: RitmoUiScale.defaultTextPercent,
    followOsTextScale: true,
    density: RitmoUiScale.defaultDensity,
  );

  ThemePreferences copyWith({
    ThemeMode? mode,
    RitmoPaletteId? paletteId,
    bool? reduceTransparency,
    bool? trueBlack,
    double? glassBlurSigma,
    int? glassOpacityPercent,
    bool? autoDarkAtMaghrib,
    int? textScalePercent,
    bool? followOsTextScale,
    RitmoDensityLevel? density,
  }) {
    return ThemePreferences(
      mode: mode ?? this.mode,
      paletteId: paletteId ?? this.paletteId,
      reduceTransparency: reduceTransparency ?? this.reduceTransparency,
      trueBlack: trueBlack ?? this.trueBlack,
      glassBlurSigma: glassBlurSigma ?? this.glassBlurSigma,
      glassOpacityPercent: glassOpacityPercent ?? this.glassOpacityPercent,
      autoDarkAtMaghrib: autoDarkAtMaghrib ?? this.autoDarkAtMaghrib,
      textScalePercent: textScalePercent ?? this.textScalePercent,
      followOsTextScale: followOsTextScale ?? this.followOsTextScale,
      density: density ?? this.density,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThemePreferences &&
          runtimeType == other.runtimeType &&
          mode == other.mode &&
          paletteId == other.paletteId &&
          reduceTransparency == other.reduceTransparency &&
          trueBlack == other.trueBlack &&
          glassBlurSigma == other.glassBlurSigma &&
          glassOpacityPercent == other.glassOpacityPercent &&
          autoDarkAtMaghrib == other.autoDarkAtMaghrib &&
          textScalePercent == other.textScalePercent &&
          followOsTextScale == other.followOsTextScale &&
          density == other.density;

  @override
  int get hashCode => Object.hash(
    mode,
    paletteId,
    reduceTransparency,
    trueBlack,
    glassBlurSigma,
    glassOpacityPercent,
    autoDarkAtMaghrib,
    textScalePercent,
    followOsTextScale,
    density,
  );
}
