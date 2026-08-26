import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/features/supplementary_sports/presentation/player/mv_session_summary_screen.dart';
import 'package:ritmo/l10n/app_localizations.dart';

Widget createTestApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('fa'),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  group('S4-T5 MvSessionSummaryScreen Unit & Widget Tests', () {
    const hikingKind = MvMovementKind(
      code: 'HIKING',
      titleFa: 'کوهنوردی',
      emoji: '🏔',
      family: MovementFamily.outdoor,
      baseMet: 7.5,
      metLow: 5.0,
      metHigh: 10.0,
      primaryMetric: MovementMetric.distance,
      isOutdoor: true,
      isSocial: false,
      needsVenue: false,
      jointImpact: 2,
      isCustom: false,
      isEnabled: true,
      usageCount: 1,
      sortOrder: 1,
    );

    const futsalKind = MvMovementKind(
      code: 'FUTSAL',
      titleFa: 'فوتسال',
      emoji: '⚽',
      family: MovementFamily.sport,
      baseMet: 8.5,
      metLow: 6.0,
      metHigh: 11.0,
      primaryMetric: MovementMetric.duration,
      isOutdoor: false,
      isSocial: true,
      needsVenue: true,
      jointImpact: 2,
      isCustom: false,
      isEnabled: true,
      usageCount: 1,
      sortOrder: 2,
    );

    testWidgets(
      'HIKING session renders elevation gain, pack weight, and distance',
      (tester) async {
        const hikingSession = MvSession(
          id: 'sess_hike',
          kindCode: 'HIKING',
          sessionMode: MvSessionMode.route,
          status: MvSessionStatus.completed,
          startedAt: 1700000000,
          endedAt: 1700000000 + (120 * 60 * 1000), // 120 min
          distanceM: 8500.0,
          elevationGainM: 650.0,
          packWeightKg: 5.0,
          createdAt: 1700000000,
          updatedAt: 1700000000,
        );

        await tester.pumpWidget(
          createTestApp(
            MvSessionSummaryScreen(
              session: hikingSession,
              kind: hikingKind,
              onFinish:
                  ({
                    required feeling,
                    required rpe1To10,
                    required effortSource,
                    note,
                  }) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('کوهنوردی'), findsOneWidget);
        expect(find.text('ارتفاع صعود'), findsOneWidget);
        expect(find.text('وزن کوله'), findsOneWidget);
        expect(find.text('مسافت'), findsOneWidget);
      },
    );

    testWidgets(
      'FUTSAL session does NOT render elevation gain, but renders match stats',
      (tester) async {
        const futsalSession = MvSession(
          id: 'sess_futsal',
          kindCode: 'FUTSAL',
          sessionMode: MvSessionMode.match,
          status: MvSessionStatus.completed,
          startedAt: 1700000000,
          endedAt: 1700000000 + (90 * 60 * 1000), // 90 min
          rpe1To10: 8,
          createdAt: 1700000000,
          updatedAt: 1700000000,
        );

        await tester.pumpWidget(
          createTestApp(
            MvSessionSummaryScreen(
              session: futsalSession,
              kind: futsalKind,
              onFinish:
                  ({
                    required feeling,
                    required rpe1To10,
                    required effortSource,
                    note,
                  }) async {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('فوتسال'), findsOneWidget);
        // Elevation gain MUST NOT be visible
        expect(find.text('ارتفاع صعود'), findsNothing);
        expect(find.text('وزن کوله'), findsNothing);
        // Match duration and load MUST be visible
        expect(find.text('مدت مسابقه'), findsOneWidget);
        expect(find.text('بار جلسه'), findsOneWidget);
      },
    );

    testWidgets(
      'Effort buttons and fine-tune slider update RPE and trigger onFinish with user source',
      (tester) async {
        int? reportedRpe;
        String? reportedSource;
        String? reportedNote;

        const session = MvSession(
          id: 'sess_test',
          kindCode: 'SWIMMING',
          sessionMode: MvSessionMode.laps,
          startedAt: 1700000000,
          endedAt: 1700000000 + (45 * 60 * 1000),
          laps: 20,
          createdAt: 1700000000,
          updatedAt: 1700000000,
        );

        await tester.pumpWidget(
          createTestApp(
            MvSessionSummaryScreen(
              session: session,
              onFinish:
                  ({
                    required feeling,
                    required rpe1To10,
                    required effortSource,
                    note,
                  }) async {
                    reportedRpe = rpe1To10;
                    reportedSource = effortSource;
                    reportedNote = note;
                  },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap Hard effort button (RPE 8)
        await tester.tap(find.byKey(const Key('mv_effort_hard')));
        await tester.pumpAndSettle();

        // Scroll until TextField is visible and enter free note
        await tester.scrollUntilVisible(
          find.byType(TextField),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField),
          'تمرین کرال سینه عالی بود',
        );
        await tester.pumpAndSettle();

        // Scroll until submit button is visible and tap
        await tester.scrollUntilVisible(
          find.text('ثبت جلسه و ذخیره'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('ثبت جلسه و ذخیره'));
        await tester.pump();

        expect(reportedRpe, equals(8));
        expect(reportedSource, equals('user'));
        expect(reportedNote, equals('تمرین کرال سینه عالی بود'));
      },
    );
  });
}
