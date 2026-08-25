import 'package:flutter/widgets.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
// lib/features/calendar/presentation/utils/calendar_geometry.dart

/// Geometry and dimension parameters for the Ritmo Timeline and Journey calendar views.
///
/// These values govern layout math, time-to-pixel scaling, and column boundaries.
/// Design tokens (radii, typography, spacing, colors, motion) are handled directly
/// via [RitmoTheme], [RitmoSpacing], [RitmoRadius], [RitmoMotion], and [RitmoColors].
abstract final class CalendarGeometry {
  // ─── Single Column Timeline Geometry ───
  /// Vertical pixels allocated per minute in single-day timeline view.
  static const double pxPerMinute = 1.2;

  /// Returns dynamic pixels per minute based on the theme's hour slot height token.
  static double effectivePxPerMinute(BuildContext context) =>
      context.metrics.hourSlotHeight / 60.0;

  /// Width of the hour axis gutter in single-day view.
  static const double hourAxisWidth = 34.0;

  /// Returns dynamic hour axis width based on text scale.
  static double effectiveHourAxisWidth(BuildContext context) =>
      34.0 * (context.textScale > 1.0 ? context.textScale : 1.0);

  /// Width of the accent color bar indicator on the side of timeline cards.
  static const double accentBarWidth = 3.0;

  /// Thickness of the real-time "Now" indicator line.
  static const double nowLineThickness = 2.0;

  // ─── Split-Day (Two Column) Timeline Geometry ───
  /// Split point dividing the day into morning/afternoon columns (12:00 = 720 minutes).
  static const int splitBoundaryMinutes = 720;

  /// Vertical pixels per minute in split two-column view (more compact).
  static const double pxPerMinuteSplit = 1.6;

  /// Returns dynamic pixels per minute for split view based on hour slot height token.
  static double effectivePxPerMinuteSplit(BuildContext context) =>
      (context.metrics.hourSlotHeight * (1.6 / 1.2)) / 60.0;

  /// Width of the hour axis in split two-column view.
  static const double hourAxisWidthSplit = 28.0;

  /// Returns dynamic split hour axis width based on text scale.
  static double effectiveHourAxisWidthSplit(BuildContext context) =>
      28.0 * (context.textScale > 1.0 ? context.textScale : 1.0);

  /// Horizontal gap between the morning and afternoon columns.
  static const double columnGap = 4.0;

  /// Maximum parallel lanes per column in split mode.
  static const int maxLanesSplit = 2;

  /// Minimum screen width required to render split two-column mode.
  static const double splitMinScreenWidth = 340.0;

  /// Height of the morning/afternoon column header widget.
  static const double columnHeaderHeight = 32.0;

  /// Returns dynamic column header height based on density and text scale.
  static double effectiveColumnHeaderHeight(BuildContext context) =>
      32.0 *
      context.metrics.densityFactor *
      (context.textScale > 1.0 ? context.textScale : 1.0);

  // ─── Agenda & Registry View Dimensions ───
  /// Fixed row height for agenda list items (prevents scroll jitter).
  static const double agendaRowHeight = 52.0;

  /// Returns dynamic agenda row height using density tokens.
  static double effectiveAgendaRowHeight(BuildContext context) =>
      context.metrics.rowHeight;

  /// Height of the agenda section/bucket headers ("امروز", "فردا", ...).
  static const double agendaBucketHeaderHeight = 36.0;

  /// Returns dynamic agenda bucket header height.
  static double effectiveAgendaBucketHeaderHeight(BuildContext context) =>
      36.0 * context.metrics.densityFactor;

  /// Height of individual plan cards in the registry list.
  static const double registryCardHeight = 92.0;

  /// Returns dynamic registry card height based on density and text scale.
  static double effectiveRegistryCardHeight(BuildContext context) =>
      92.0 *
      context.metrics.densityFactor *
      (context.textScale > 1.0 ? context.textScale : 1.0);

  /// Standard filter/module chip height.
  static const double chipHeight = 36.0;

  /// Returns dynamic chip height adhering to Law 38 (Minimum 48dp Touch Target Floor).
  static double effectiveChipHeight(BuildContext context) =>
      context.metrics.touchTarget;

  // ─── Surface & Background Opacities ───
  /// Opacity for domain tinted background surfaces.
  static const double alphaDomainFill = 0.10;

  /// Opacity for active / highlighted domain surfaces.
  static const double alphaDomainActive = 0.16;

  /// Opacity for the current time slot highlight.
  static const double alphaCurrentTime = 0.12;

  /// Dimming opacity for completed/past items.
  static const double alphaPastDim = 0.04;

  /// Border opacity for timeline item cards.
  static const double alphaCardBorder = 0.08;
}
