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
      expect(MovementRoutes.strengthOnboarding, equals('movement.strength.onboarding'));
      expect(MovementRoutes.strengthPreview, equals('movement.strength.preview'));
      expect(MovementRoutes.progress, equals('movement.progress'));
      expect(MovementRoutes.library, equals('movement.library'));
      expect(MovementRoutes.settings, equals('movement.settings'));
    });

    test('In standard build without MOVEMENT_GREENFIELD_INTERNAL flag, movement routes resolve to null', () {
      // In default environment without --dart-define=MOVEMENT_GREENFIELD_INTERNAL=true,
      // the router must safely return null without throwing or registering unreleased screens.
      expect(RitmoRouter.resolve(MovementRoutes.center), isNull);
      expect(RitmoRouter.resolve(MovementRoutes.picker), isNull);
      expect(RitmoRouter.resolve(MovementRoutes.planEditor), isNull);
      expect(RitmoRouter.resolve(MovementRoutes.occurrence), isNull);
      expect(RitmoRouter.resolve(MovementRoutes.liveSession), isNull);
      expect(RitmoRouter.resolve(MovementRoutes.summary), isNull);
      expect(RitmoRouter.resolve(MovementRoutes.strengthHub), isNull);
      expect(RitmoRouter.resolve(MovementRoutes.strengthOnboarding), isNull);
      expect(RitmoRouter.resolve(MovementRoutes.strengthPreview), isNull);
      expect(RitmoRouter.resolve(MovementRoutes.progress), isNull);
      expect(RitmoRouter.resolve(MovementRoutes.library), isNull);
      expect(RitmoRouter.resolve(MovementRoutes.settings), isNull);
    });
  });
}
