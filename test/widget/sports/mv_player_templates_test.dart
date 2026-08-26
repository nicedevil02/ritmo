import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/features/supplementary_sports/presentation/player/templates/templates.dart';
import 'package:ritmo/l10n/app_localizations.dart';

Widget createTestApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('fa'),
    home: Scaffold(body: child),
  );
}

void main() {
  group('S4-T3 Five Player Templates Widget Tests', () {
    const dummySession = MvSession(
      id: 'sess_test',
      kindCode: 'BODYWEIGHT',
      startedAt: 1700000000,
      createdAt: 1700000000,
      updatedAt: 1700000000,
    );

    testWidgets(
      'MvTimedTemplate renders stopwatch, phase selector, effort slider, and triggers onFinish',
      (tester) async {
        int? reportedSec;
        int? reportedRpe;

        await tester.pumpWidget(
          createTestApp(
            MvTimedTemplate(
              session: dummySession,
              onFinish: (sec, rpe) {
                reportedSec = sec;
                reportedRpe = rpe;
              },
            ),
          ),
        );
        await tester.pump();

        // Check stopwatch and phases exist
        expect(find.text('تمرین اصلی'), findsWidgets);
        expect(find.text('گرم کردن'), findsOneWidget);
        expect(find.text('سرد کردن'), findsOneWidget);
        expect(find.byType(Slider), findsOneWidget);
        expect(find.text('پایان جلسه'), findsOneWidget);

        // Tap finish
        await tester.tap(find.text('پایان جلسه'));
        await tester.pump();

        expect(reportedSec, isNotNull);
        expect(reportedRpe, isNotNull);
      },
    );

    testWidgets(
      'MvDistanceTemplate renders distance km, stopwatch, adjusts distance, and triggers onFinish',
      (tester) async {
        double? reportedDist;
        int? reportedRpe;

        await tester.pumpWidget(
          createTestApp(
            MvDistanceTemplate(
              session: dummySession,
              onFinish: (sec, dist, rpe) {
                reportedDist = dist;
                reportedRpe = rpe;
              },
            ),
          ),
        );
        await tester.pump();

        expect(find.text('کیلومتر'), findsOneWidget);
        expect(find.text('تنظیم مسافت'), findsOneWidget);
        expect(find.byIcon(Icons.add), findsOneWidget);

        // Increase distance
        await tester.tap(find.byIcon(Icons.add));
        await tester.pump();

        // Finish
        await tester.tap(find.text('پایان جلسه'));
        await tester.pump();

        expect(reportedDist, equals(3500.0)); // 3.0 + 0.5 = 3.5 km = 3500m
        expect(reportedRpe, equals(7));
      },
    );

    testWidgets(
      'MvRouteTemplate renders distance, elevation gain, pack weight, route selector, and triggers onFinish',
      (tester) async {
        double? reportedElev;
        double? reportedPack;

        await tester.pumpWidget(
          createTestApp(
            MvRouteTemplate(
              session: dummySession,
              onFinish:
                  ({
                    required elapsedSeconds,
                    required distanceM,
                    required elevationGainM,
                    required packWeightKg,
                    required rpe1To10,
                    routeId,
                  }) {
                    reportedElev = elevationGainM;
                    reportedPack = packWeightKg;
                  },
            ),
          ),
        );
        await tester.pump();

        expect(find.text('مسافت'), findsOneWidget);
        expect(find.text('ارتفاع صعود'), findsOneWidget);
        expect(find.text('وزن کوله'), findsOneWidget);
        expect(find.text('مسیر'), findsOneWidget);

        // Finish
        await tester.tap(find.text('پایان جلسه'));
        await tester.pump();

        expect(reportedElev, equals(400.0));
        expect(reportedPack, equals(4.0));
      },
    );

    testWidgets(
      'MvLapsTemplate renders lap count, +1 lap button, increments laps, and triggers onFinish',
      (tester) async {
        int? reportedLaps;

        await tester.pumpWidget(
          createTestApp(
            MvLapsTemplate(
              session: dummySession,
              onFinish: (sec, laps, rpe) {
                reportedLaps = laps;
              },
            ),
          ),
        );
        await tester.pump();

        expect(find.text('+۱ دور ثبت شد'), findsOneWidget);
        expect(find.text('دور ثبت‌شده'), findsOneWidget);

        // Tap lap button 3 times
        await tester.tap(find.text('+۱ دور ثبت شد'));
        await tester.pump();
        await tester.tap(find.text('+۱ دور ثبت شد'));
        await tester.pump();
        await tester.tap(find.text('+۱ دور ثبت شد'));
        await tester.pump();

        // Finish
        await tester.tap(find.text('پایان جلسه'));
        await tester.pump();

        expect(reportedLaps, equals(3));
      },
    );

    testWidgets(
      'MvMatchTemplate renders halves indicator, score counters, note field, and triggers onFinish',
      (tester) async {
        String? reportedNote;

        await tester.pumpWidget(
          createTestApp(
            MvMatchTemplate(
              session: dummySession,
              onFinish: (sec, rpe, note) {
                reportedNote = note;
              },
            ),
          ),
        );
        await tester.pump();

        expect(find.text('نیمه اول / ست اول'), findsOneWidget);
        expect(find.text('ما'), findsOneWidget);
        expect(find.text('حریف'), findsOneWidget);
        expect(find.text('شروع نیمه دوم'), findsOneWidget);

        // Switch to second half
        await tester.tap(find.text('شروع نیمه دوم'));
        await tester.pump();
        expect(find.text('نیمه دوم / ست دوم'), findsOneWidget);

        // Enter note
        await tester.enterText(find.byType(TextField), 'پیروزی ۴ بر ۲');
        await tester.pump();

        // Finish
        await tester.tap(find.text('پایان مسابقه'));
        await tester.pump();

        expect(reportedNote, equals('پیروزی ۴ بر ۲'));
      },
    );
  });
}
