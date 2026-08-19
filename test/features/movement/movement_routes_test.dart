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

    test('Movement routes resolve to valid screen targets in RitmoRouter', () {
      expect(RitmoRouter.resolve(MovementRoutes.center), isNotNull);
      expect(RitmoRouter.resolve(MovementRoutes.picker), isNotNull);
      expect(RitmoRouter.resolve(MovementRoutes.planEditor), isNotNull);
      expect(RitmoRouter.resolve(MovementRoutes.occurrence), isNotNull);
      expect(RitmoRouter.resolve(MovementRoutes.liveSession), isNotNull);
      expect(RitmoRouter.resolve(MovementRoutes.summary), isNotNull);
      expect(RitmoRouter.resolve(MovementRoutes.strengthHub), isNotNull);
      expect(RitmoRouter.resolve(MovementRoutes.strengthOnboarding), isNotNull);
      expect(RitmoRouter.resolve(MovementRoutes.strengthPreview), isNotNull);
      expect(RitmoRouter.resolve(MovementRoutes.progress), isNotNull);
      expect(RitmoRouter.resolve(MovementRoutes.library), isNotNull);
      expect(RitmoRouter.resolve(MovementRoutes.settings), isNotNull);
      expect(RitmoRouter.resolve('/movement'), isNotNull);
    });
  });
}
