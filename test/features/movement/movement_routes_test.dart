import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/navigation/ritmo_router.dart';
import 'package:ritmo/features/movement/presentation/movement_routes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MovementRoutes & RitmoRouter Greenfield Define Tests (Point 1)', () {
    test('All 12 movement route constants are defined accurately', () {
      expect(MovementRoutes.center, equals('movement.center'));
      expect(MovementRoutes.picker, equals('movement.picker'));
      expect(MovementRoutes.planEditor, equals('movement.plan_editor'));
      expect(MovementRoutes.occurrence, equals('movement.occurrence'));
      expect(MovementRoutes.liveSession, equals('movement.session'));
      expect(MovementRoutes.summary, equals('movement.summary'));
      expect(MovementRoutes.strengthHub, equals('movement.strength'));
      expect(
        MovementRoutes.strengthOnboarding,
        equals('movement.strength.onboarding'),
      );
      expect(
        MovementRoutes.strengthPreview,
        equals('movement.strength.preview'),
      );
      expect(MovementRoutes.progress, equals('movement.progress'));
      expect(MovementRoutes.library, equals('movement.library'));
      expect(MovementRoutes.settings, equals('movement.settings'));
    });

    test('Movement routes generate valid Routes via RitmoRouter.onGenerateRoute', () {
      final routes = [
        MovementRoutes.center,
        MovementRoutes.picker,
        MovementRoutes.planEditor,
        MovementRoutes.occurrence,
        MovementRoutes.liveSession,
        MovementRoutes.summary,
        MovementRoutes.strengthHub,
        MovementRoutes.strengthOnboarding,
        MovementRoutes.strengthPreview,
        MovementRoutes.progress,
        MovementRoutes.library,
        MovementRoutes.settings,
        '/movement',
        '/movement/picker',
        '/movement/plan',
        '/movement/live',
        '/movement/summary',
        '/movement/settings',
      ];

      for (final r in routes) {
        final route = RitmoRouter.onGenerateRoute(RouteSettings(name: r));
        expect(route, isNotNull, reason: 'Route $r should generate a valid MaterialPageRoute');
      }
    });
  });
}
