import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ui_scale.dart';

@immutable
class RitmoMetrics extends ThemeExtension<RitmoMetrics> {
  const RitmoMetrics({
    required this.density,
    required this.densityFactor,
    required this.spaceXs,
    required this.spaceSm,
    required this.spaceMd,
    required this.spaceLg,
    required this.spaceXl,
    required this.spaceXxl,
    required this.spaceXxxl,
    required this.radiusField,
    required this.radiusCard,
    required this.radiusHero,
    required this.radiusSheet,
    required this.iconSm,
    required this.iconMd,
    required this.iconLg,
    required this.iconXl,
    required this.touchTarget,
    required this.rowHeight,
    required this.navBarHeight,
    required this.hourSlotHeight,
  });

  final RitmoDensityLevel density;
  final double densityFactor;
  final double spaceXs;
  final double spaceSm;
  final double spaceMd;
  final double spaceLg;
  final double spaceXl;
  final double spaceXxl;
  final double spaceXxxl;
  final double radiusField;
  final double radiusCard;
  final double radiusHero;
  final double radiusSheet;
  final double iconSm;
  final double iconMd;
  final double iconLg;
  final double iconXl;
  final double touchTarget;
  final double rowHeight;
  final double navBarHeight;
  final double hourSlotHeight;

  factory RitmoMetrics.of(RitmoDensityLevel level) {
    switch (level) {
      case RitmoDensityLevel.compact:
        return const RitmoMetrics(
          density: RitmoDensityLevel.compact,
          densityFactor: 0.92,
          spaceXs: 4.0,
          spaceSm: 8.0,
          spaceMd: 12.0,
          spaceLg: 14.0,
          spaceXl: 22.0,
          spaceXxl: 30.0,
          spaceXxxl: 44.0,
          radiusField: 14.0,
          radiusCard: 16.0,
          radiusHero: 20.0,
          radiusSheet: 27.0,
          iconSm: 16.0,
          iconMd: 18.0,
          iconLg: 22.0,
          iconXl: 30.0,
          touchTarget: 48.0,
          rowHeight: 52.0,
          navBarHeight: 60.0,
          hourSlotHeight: 52.0,
        );
      case RitmoDensityLevel.comfortable:
        return const RitmoMetrics(
          density: RitmoDensityLevel.comfortable,
          densityFactor: 1.00,
          spaceXs: 4.0,
          spaceSm: 8.0,
          spaceMd: 12.0,
          spaceLg: 16.0,
          spaceXl: 24.0,
          spaceXxl: 32.0,
          spaceXxxl: 48.0,
          radiusField: 14.0,
          radiusCard: 16.0,
          radiusHero: 20.0,
          radiusSheet: 28.0,
          iconSm: 16.0,
          iconMd: 20.0,
          iconLg: 24.0,
          iconXl: 32.0,
          touchTarget: 48.0,
          rowHeight: 56.0,
          navBarHeight: 64.0,
          hourSlotHeight: 56.0,
        );
      case RitmoDensityLevel.spacious:
        return const RitmoMetrics(
          density: RitmoDensityLevel.spacious,
          densityFactor: 1.12,
          spaceXs: 4.0,
          spaceSm: 10.0,
          spaceMd: 14.0,
          spaceLg: 18.0,
          spaceXl: 28.0,
          spaceXxl: 36.0,
          spaceXxxl: 54.0,
          radiusField: 15.0,
          radiusCard: 17.0,
          radiusHero: 21.0,
          radiusSheet: 30.0,
          iconSm: 18.0,
          iconMd: 22.0,
          iconLg: 28.0,
          iconXl: 36.0,
          touchTarget: 54.0,
          rowHeight: 62.0,
          navBarHeight: 70.0,
          hourSlotHeight: 62.0,
        );
      case RitmoDensityLevel.xl:
        return const RitmoMetrics(
          density: RitmoDensityLevel.xl,
          densityFactor: 1.24,
          spaceXs: 6.0,
          spaceSm: 10.0,
          spaceMd: 16.0,
          spaceLg: 20.0,
          spaceXl: 30.0,
          spaceXxl: 40.0,
          spaceXxxl: 60.0,
          radiusField: 15.0,
          radiusCard: 18.0,
          radiusHero: 22.0,
          radiusSheet: 31.0,
          iconSm: 20.0,
          iconMd: 24.0,
          iconLg: 30.0,
          iconXl: 40.0,
          touchTarget: 60.0,
          rowHeight: 68.0,
          navBarHeight: 76.0,
          hourSlotHeight: 68.0,
        );
    }
  }

  @override
  RitmoMetrics copyWith({
    RitmoDensityLevel? density,
    double? densityFactor,
    double? spaceXs,
    double? spaceSm,
    double? spaceMd,
    double? spaceLg,
    double? spaceXl,
    double? spaceXxl,
    double? spaceXxxl,
    double? radiusField,
    double? radiusCard,
    double? radiusHero,
    double? radiusSheet,
    double? iconSm,
    double? iconMd,
    double? iconLg,
    double? iconXl,
    double? touchTarget,
    double? rowHeight,
    double? navBarHeight,
    double? hourSlotHeight,
  }) {
    return RitmoMetrics(
      density: density ?? this.density,
      densityFactor: densityFactor ?? this.densityFactor,
      spaceXs: spaceXs ?? this.spaceXs,
      spaceSm: spaceSm ?? this.spaceSm,
      spaceMd: spaceMd ?? this.spaceMd,
      spaceLg: spaceLg ?? this.spaceLg,
      spaceXl: spaceXl ?? this.spaceXl,
      spaceXxl: spaceXxl ?? this.spaceXxl,
      spaceXxxl: spaceXxxl ?? this.spaceXxxl,
      radiusField: radiusField ?? this.radiusField,
      radiusCard: radiusCard ?? this.radiusCard,
      radiusHero: radiusHero ?? this.radiusHero,
      radiusSheet: radiusSheet ?? this.radiusSheet,
      iconSm: iconSm ?? this.iconSm,
      iconMd: iconMd ?? this.iconMd,
      iconLg: iconLg ?? this.iconLg,
      iconXl: iconXl ?? this.iconXl,
      touchTarget: touchTarget ?? this.touchTarget,
      rowHeight: rowHeight ?? this.rowHeight,
      navBarHeight: navBarHeight ?? this.navBarHeight,
      hourSlotHeight: hourSlotHeight ?? this.hourSlotHeight,
    );
  }

  @override
  RitmoMetrics lerp(ThemeExtension<RitmoMetrics>? other, double t) {
    if (other is! RitmoMetrics) return this;
    return RitmoMetrics(
      density: t < 0.5 ? density : other.density,
      densityFactor:
          ui.lerpDouble(densityFactor, other.densityFactor, t) ?? densityFactor,
      spaceXs: ui.lerpDouble(spaceXs, other.spaceXs, t) ?? spaceXs,
      spaceSm: ui.lerpDouble(spaceSm, other.spaceSm, t) ?? spaceSm,
      spaceMd: ui.lerpDouble(spaceMd, other.spaceMd, t) ?? spaceMd,
      spaceLg: ui.lerpDouble(spaceLg, other.spaceLg, t) ?? spaceLg,
      spaceXl: ui.lerpDouble(spaceXl, other.spaceXl, t) ?? spaceXl,
      spaceXxl: ui.lerpDouble(spaceXxl, other.spaceXxl, t) ?? spaceXxl,
      spaceXxxl: ui.lerpDouble(spaceXxxl, other.spaceXxxl, t) ?? spaceXxxl,
      radiusField:
          ui.lerpDouble(radiusField, other.radiusField, t) ?? radiusField,
      radiusCard: ui.lerpDouble(radiusCard, other.radiusCard, t) ?? radiusCard,
      radiusHero: ui.lerpDouble(radiusHero, other.radiusHero, t) ?? radiusHero,
      radiusSheet:
          ui.lerpDouble(radiusSheet, other.radiusSheet, t) ?? radiusSheet,
      iconSm: ui.lerpDouble(iconSm, other.iconSm, t) ?? iconSm,
      iconMd: ui.lerpDouble(iconMd, other.iconMd, t) ?? iconMd,
      iconLg: ui.lerpDouble(iconLg, other.iconLg, t) ?? iconLg,
      iconXl: ui.lerpDouble(iconXl, other.iconXl, t) ?? iconXl,
      touchTarget:
          ui.lerpDouble(touchTarget, other.touchTarget, t) ?? touchTarget,
      rowHeight: ui.lerpDouble(rowHeight, other.rowHeight, t) ?? rowHeight,
      navBarHeight:
          ui.lerpDouble(navBarHeight, other.navBarHeight, t) ?? navBarHeight,
      hourSlotHeight:
          ui.lerpDouble(hourSlotHeight, other.hourSlotHeight, t) ??
          hourSlotHeight,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RitmoMetrics &&
          runtimeType == other.runtimeType &&
          density == other.density &&
          densityFactor == other.densityFactor &&
          spaceXs == other.spaceXs &&
          spaceSm == other.spaceSm &&
          spaceMd == other.spaceMd &&
          spaceLg == other.spaceLg &&
          spaceXl == other.spaceXl &&
          spaceXxl == other.spaceXxl &&
          spaceXxxl == other.spaceXxxl &&
          radiusField == other.radiusField &&
          radiusCard == other.radiusCard &&
          radiusHero == other.radiusHero &&
          radiusSheet == other.radiusSheet &&
          iconSm == other.iconSm &&
          iconMd == other.iconMd &&
          iconLg == other.iconLg &&
          iconXl == other.iconXl &&
          touchTarget == other.touchTarget &&
          rowHeight == other.rowHeight &&
          navBarHeight == other.navBarHeight &&
          hourSlotHeight == other.hourSlotHeight;

  @override
  int get hashCode => Object.hashAll([
    density,
    densityFactor,
    spaceXs,
    spaceSm,
    spaceMd,
    spaceLg,
    spaceXl,
    spaceXxl,
    spaceXxxl,
    radiusField,
    radiusCard,
    radiusHero,
    radiusSheet,
    iconSm,
    iconMd,
    iconLg,
    iconXl,
    touchTarget,
    rowHeight,
    navBarHeight,
    hourSlotHeight,
  ]);
}

extension RitmoMetricsX on BuildContext {
  RitmoMetrics get metrics =>
      Theme.of(this).extension<RitmoMetrics>() ??
      RitmoMetrics.of(RitmoUiScale.defaultDensity);
}
