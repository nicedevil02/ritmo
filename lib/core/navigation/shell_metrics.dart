import 'package:ritmo/core/app_mode/app_mode_service.dart';

abstract final class RitmoShellMetrics {
  static const double navBarHeight = 58.0;
  static const double navBarBottomGap = 16.0;

  static int calendarTabIndexFor(AppMode mode) => mode == AppMode.simple ? 1 : 4;

  static int tabCountFor(AppMode mode) => mode == AppMode.simple ? 3 : 5;

  static int defaultTabFor(AppMode mode) => mode == AppMode.simple ? 0 : 2;

  static int homeTabIndexFor(AppMode mode) => mode == AppMode.simple ? 0 : 2;

  /// Returns uniform optical bottom margin whether on gesture nav or button-based nav.
  static double effectiveBottomMargin(double deviceBottomPadding) {
    if (deviceBottomPadding > 0) {
      return (deviceBottomPadding + 4.0).clamp(navBarBottomGap, 34.0);
    }
    return navBarBottomGap;
  }
}
