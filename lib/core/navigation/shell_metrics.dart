import 'package:ritmo/core/app_mode/app_mode_service.dart';

abstract final class RitmoShellMetrics {
  static const double navBarHeight = 58.0;
  static const double navBarBottomGap = 16.0;

  static int calendarTabIndexFor(AppMode mode) => mode == AppMode.simple ? 1 : 4;
}
