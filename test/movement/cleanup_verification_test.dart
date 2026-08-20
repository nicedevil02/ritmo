import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/movement/presentation/movement_routes.dart';

void main() {
  group('Movement Cleanup and Architecture Verification (Phase 8 / P-21, P-22, P-23)', () {
    test('1. MovementRoutes strictly contains exactly 6 registered routes', () {
      expect(MovementRoutes.center, equals('/movement'));
      expect(MovementRoutes.picker, equals('/movement/picker'));
      expect(MovementRoutes.planEditor, equals('/movement/plan'));
      expect(MovementRoutes.liveSession, equals('/movement/live'));
      expect(MovementRoutes.summary, equals('/movement/summary'));
      expect(MovementRoutes.settings, equals('/movement/settings'));
    });
  });
}
