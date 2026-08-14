import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/app_mode/app_mode_service.dart';
import 'package:ritmo/core/navigation/shell_metrics.dart';

void main() {
  group('P0-6: Calendar Deep Link Tab Index Tests', () {
    test('calendarTabIndexFor returns 1 for AppMode.simple and 4 for AppMode.full', () {
      expect(RitmoShellMetrics.calendarTabIndexFor(AppMode.simple), equals(1));
      expect(RitmoShellMetrics.calendarTabIndexFor(AppMode.full), equals(4));
    });
  });
}
