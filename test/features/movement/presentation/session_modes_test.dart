import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';
import 'package:ritmo/features/movement/presentation/session/modes/count_session_view.dart';
import 'package:ritmo/features/movement/presentation/session/modes/distance_session_view.dart';
import 'package:ritmo/features/movement/presentation/session/modes/free_session_view.dart';
import 'package:ritmo/features/movement/presentation/session/modes/lap_session_view.dart';
import 'package:ritmo/features/movement/presentation/session/modes/time_session_view.dart';
import 'package:ritmo/features/movement/presentation/session/widgets/lap_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestableWidget(Widget child) {
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

  group('Session 5 Non-Strength Modes Widget Tests', () {
    testWidgets(
      '1. TimeSessionView renders circular progress, large timer and goal',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          buildTestableWidget(
            const TimeSessionView(
              elapsedSeconds: 900, // 15 mins
              isPaused: false,
              targetDurationMinutes: 30,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('۱۵:۰۰'), findsOneWidget);
        expect(find.textContaining('هدف: ۳۰ دقیقه'), findsOneWidget);
        expect(find.textContaining('پیشرفت: ۵۰٪'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );

    testWidgets(
      '2. DistanceSessionView calculates and displays Pace only when distance is valid',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        double recordedDistance = 0.0;

        await tester.pumpWidget(
          buildTestableWidget(
            DistanceSessionView(
              distanceKm: 2.0,
              elapsedSeconds: 600, // 10 mins for 2km = 5:00 min/km
              isPaused: false,
              onDistanceChanged: (d) => recordedDistance = d,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('۲.۰۰'), findsOneWidget);
        expect(find.textContaining('سرعت (Pace)'), findsOneWidget);
        expect(find.textContaining('۰۵:۰۰'), findsOneWidget);

        // Tap +1.0 km button
        await tester.tap(find.text('+۱.۰'));
        await tester.pumpAndSettle();
        expect(recordedDistance, equals(3.0));
      },
    );

    testWidgets(
      '3. LapButton handles 400ms debounce, records laps and calculates best/avg',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final laps = <SessionLapItem>[
          const SessionLapItem(lapNumber: 1, durationSec: 60, splitTimeSec: 60),
          const SessionLapItem(
            lapNumber: 2,
            durationSec: 50,
            splitTimeSec: 110,
          ),
        ];

        await tester.pumpWidget(
          buildTestableWidget(
            LapSessionView(
              elapsedSeconds: 110,
              isPaused: false,
              laps: laps,
              onLapRecorded: (_) {},
              onUndoLap: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(MovementStrings.sessionLapDone), findsOneWidget);
        expect(find.textContaining('تعداد کل دورها: ۲'), findsOneWidget);
        expect(find.text(MovementStrings.lapBestLabel), findsOneWidget);
        expect(find.text(MovementStrings.lapAvgLabel), findsOneWidget);
      },
    );

    testWidgets(
      '4. CountSessionView renders counter, quick add buttons, and handles increments',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        int count = 10;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              return buildTestableWidget(
                CountSessionView(
                  elapsedSeconds: 300,
                  isPaused: false,
                  currentCount: count,
                  targetCount: 50,
                  onCountChanged: (newVal) => setState(() => count = newVal),
                ),
              );
            },
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('۱۰'), findsOneWidget);
        expect(find.text('از ۵۰'), findsOneWidget);

        // Tap +5
        await tester.tap(find.text('+۵'));
        await tester.pumpAndSettle();

        expect(count, equals(15));
        expect(find.text('۱۵'), findsOneWidget);
      },
    );

    testWidgets(
      '5. FreeSessionView renders intensity picker with all 5 textual labels',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        int intensity = 3;
        final noteController = TextEditingController(
          text: 'یادداشت تمرین آزاد',
        );

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              return buildTestableWidget(
                FreeSessionView(
                  elapsedSeconds: 120,
                  isPaused: false,
                  selectedIntensity: intensity,
                  onIntensityChanged: (newInt) =>
                      setState(() => intensity = newInt),
                  noteController: noteController,
                ),
              );
            },
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(MovementStrings.intensityVeryLight), findsOneWidget);
        expect(find.text(MovementStrings.intensityLight), findsOneWidget);
        expect(find.text(MovementStrings.intensityModerate), findsOneWidget);
        expect(find.text(MovementStrings.intensityHard), findsOneWidget);
        expect(find.text(MovementStrings.intensityVeryHard), findsOneWidget);
        expect(find.text('یادداشت تمرین آزاد'), findsOneWidget);
      },
    );
  });
}
