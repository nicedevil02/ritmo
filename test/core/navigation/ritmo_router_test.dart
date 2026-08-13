import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/navigation/ritmo_router.dart';

void main() {
  group('RitmoRouter.resolve', () {
    test('tab routes map to full-mode tab indices', () {
      expect(RitmoRouter.resolve('/')?.kind, RitmoRouteKind.tab);
      expect(RitmoRouter.resolve('/today')?.tabIndex, 2);
      expect(RitmoRouter.resolve('/systems')?.tabIndex, 0);
      expect(RitmoRouter.resolve('/insights')?.tabIndex, 1);
      expect(RitmoRouter.resolve('/routines')?.tabIndex, 3);
      expect(RitmoRouter.resolve('/calendar')?.tabIndex, 4);
    });

    test('sleep routes open the wellbeing sleep section', () {
      expect(RitmoRouter.resolve('/sleep')?.kind, RitmoRouteKind.screen);
      expect(RitmoRouter.resolve('/sleep/journey')?.kind, RitmoRouteKind.screen);
    });

    test('screen routes', () {
      expect(RitmoRouter.resolve('/goals')?.kind, RitmoRouteKind.screen);
      expect(RitmoRouter.resolve('/health')?.kind, RitmoRouteKind.screen);
      expect(RitmoRouter.resolve('/worship')?.kind, RitmoRouteKind.screen);
      expect(RitmoRouter.resolve('/sports')?.kind, RitmoRouteKind.screen);
    });

    test('cycle keywords resolve, including Persian', () {
      expect(RitmoRouter.resolve('/cycle')?.kind, RitmoRouteKind.screen);
      expect(RitmoRouter.resolve('/period-tracker')?.kind, RitmoRouteKind.screen);
      expect(RitmoRouter.resolve('چرخه')?.kind, RitmoRouteKind.screen);
      expect(RitmoRouter.resolve('پریود')?.kind, RitmoRouteKind.screen);
    });

    test('konkur/study resolves to a module entry', () {
      expect(RitmoRouter.resolve('/konkur')?.kind, RitmoRouteKind.moduleEntry);
      expect(RitmoRouter.resolve('/study')?.kind, RitmoRouteKind.moduleEntry);
    });

    test('unknown or empty routes return null', () {
      expect(RitmoRouter.resolve('/nope'), isNull);
      expect(RitmoRouter.resolve(''), isNull);
      expect(RitmoRouter.resolve('   '), isNull);
    });

    test('matching is case-insensitive', () {
      expect(RitmoRouter.resolve('/SLEEP')?.kind, RitmoRouteKind.screen);
      expect(RitmoRouter.resolve('/Today')?.tabIndex, 2);
    });
  });

  group('RitmoRouter pending route (cold start)', () {
    test('queued route is consumed exactly once', () {
      RitmoRouter.queuePendingRoute('/sleep');
      expect(RitmoRouter.consumePendingRoute(), '/sleep');
      expect(RitmoRouter.consumePendingRoute(), isNull);
    });
  });
}
