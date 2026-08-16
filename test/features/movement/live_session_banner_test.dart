import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';
import 'package:ritmo/features/movement/domain/models/movement_live_session.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/live_session_banner.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: RitmoTheme.build(
      palette: RitmoPalette.jadeNoir,
      brightness: Brightness.dark,
    ),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LiveSessionBanner Widget Tests (Requirement 4)', () {
    final testKind = MovementActivityKind(
      id: 'kind_running',
      nameFa: 'دویدن استقامتی',
      family: 'running',
      icon: 'directions_run',
      primaryMetric: 'distance',
      createdAt: DateTime.now(),
    );

    testWidgets('Renders active session banner with running elapsed time and resume CTA', (tester) async {
      bool resumed = false;

      final session = MovementLiveSession(
        id: 'sess_1',
        activityKindId: 'kind_running',
        activityKind: testKind,
        mode: 'standard',
        status: MovementLiveSessionStatus.active,
        startedAt: DateTime.now().subtract(const Duration(minutes: 12, seconds: 34)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        _wrap(
          LiveSessionBanner(
            session: session,
            onResume: () {
              resumed = true;
            },
            onFinishAndSave: () {},
            onDiscard: () {},
          ),
        ),
      );

      expect(find.text('دویدن استقامتی'), findsOneWidget);
      expect(find.textContaining('در حال ضبط'), findsOneWidget);
      expect(find.text(MovementStrings.bannerResumeSession), findsOneWidget);

      await tester.tap(find.text(MovementStrings.bannerResumeSession));
      await tester.pumpAndSettle();
      expect(resumed, isTrue);
    });

    testWidgets('Paused session shows paused status and popup menu actions', (tester) async {
      bool finishCalled = false;
      bool discardCalled = false;

      final session = MovementLiveSession(
        id: 'sess_2',
        activityKindId: 'kind_running',
        activityKind: testKind,
        mode: 'standard',
        status: MovementLiveSessionStatus.paused,
        startedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        _wrap(
          LiveSessionBanner(
            session: session,
            onResume: () {},
            onFinishAndSave: () {
              finishCalled = true;
            },
            onDiscard: () {
              discardCalled = true;
            },
          ),
        ),
      );

      expect(find.textContaining('مکث شده'), findsOneWidget);

      // Open popup menu
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      expect(find.text(MovementStrings.bannerFinishAndSave), findsOneWidget);
      expect(find.text(MovementStrings.bannerDiscardSession), findsOneWidget);

      // Tap finish
      await tester.tap(find.text(MovementStrings.bannerFinishAndSave));
      await tester.pumpAndSettle();
      expect(finishCalled, isTrue);

      // Re-open and tap discard
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(MovementStrings.bannerDiscardSession));
      await tester.pumpAndSettle();
      expect(discardCalled, isTrue);
    });
  });
}
