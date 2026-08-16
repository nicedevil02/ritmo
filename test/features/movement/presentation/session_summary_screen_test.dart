import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/application/movement_log_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';
import 'package:ritmo/features/movement/domain/models/movement_workout_log.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';
import 'package:ritmo/features/movement/presentation/summary/session_summary_screen.dart';
import 'package:ritmo/features/movement/presentation/summary/widgets/summary_feeling_picker.dart';
import 'package:ritmo/features/movement/presentation/summary/widgets/summary_metric_block.dart';
import 'package:ritmo/features/movement/presentation/summary/widgets/summary_pr_block.dart';

class FakeSummaryLogService extends MovementLogService {
  MovementWorkoutLog? savedLog;

  @override
  Future<void> saveWorkoutLog(MovementWorkoutLog log) async {
    savedLog = log;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleKind = MovementActivityKind(
    id: 'kind_running',
    nameFa: 'دویدن',
    family: 'running',
    icon: 'directions_run',
    primaryMetric: 'distance',
    createdAt: DateTime.now(),
  );

  final sampleLog = MovementWorkoutLog(
    id: 'log_summary_test',
    activityKindId: 'kind_running',
    dateIso: '2026-08-16',
    durationSec: 1800, // 30 mins
    metricJson: '{"distanceKm": 5.2, "calories": 320, "caloriesEstimated": true}',
    source: 'live',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      theme: RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
      ),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: child,
      ),
    );
  }

  group('SessionSummaryScreen Widget Tests (Gate 3)', () {
    testWidgets('1. Renders all 7 zones with actual metrics and estimation badge', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeLogService = FakeSummaryLogService();

      await tester.pumpWidget(
        buildTestableWidget(
          SessionSummaryScreen(
            workoutLog: sampleLog,
            activityKind: sampleKind,
            logService: fakeLogService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Zone 1: Confirmation sentence
      expect(find.text(MovementStrings.summarySubtitleCompleted), findsOneWidget);

      // Zone 2: SummaryMetricBlock
      expect(find.byType(SummaryMetricBlock), findsOneWidget);
      expect(find.textContaining('۳۰'), findsWidgets); // 30 mins
      expect(find.textContaining('۵.۲۰'), findsOneWidget); // 5.20 km
      expect(find.text(MovementStrings.summaryEstimated), findsOneWidget);

      // Zone 5: SummaryFeelingPicker
      expect(find.byType(SummaryFeelingPicker), findsOneWidget);
      expect(find.text('عالی'), findsOneWidget);

      // Zone 6: Weekly impact
      expect(find.textContaining('دقیقه به دقایق تمرین این هفته اضافه شد'), findsOneWidget);

      // Zone 7: Two CTAs
      expect(find.text(MovementStrings.summaryDone), findsOneWidget);
      expect(find.text(MovementStrings.summaryLogAnother), findsOneWidget);
    });

    testWidgets('2. Partial session shows neutral tone subtitle without exaggeration', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildTestableWidget(
          SessionSummaryScreen(
            workoutLog: sampleLog,
            activityKind: sampleKind,
            isPartial: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(MovementStrings.summarySubtitlePartial), findsOneWidget);
      expect(find.text(MovementStrings.summarySubtitleCompleted), findsNothing);
    });

    testWidgets('3. Renders SummaryPrBlock when PR is achieved', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildTestableWidget(
          SessionSummaryScreen(
            workoutLog: sampleLog,
            activityKind: sampleKind,
            isPr: true,
            prTitle: 'بیشترین مسافت ۵ کیلومتر',
            prValue: '۲۴:۳۰ دقیقه',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SummaryPrBlock), findsOneWidget);
      expect(find.text(MovementStrings.summaryPrCelebration), findsOneWidget);
      expect(find.textContaining('بیشترین مسافت ۵ کیلومتر'), findsOneWidget);
    });

    testWidgets('4. QuickStart session renders proposal to add to weekly plan', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildTestableWidget(
          SessionSummaryScreen(
            workoutLog: sampleLog,
            activityKind: sampleKind,
            isQuickStart: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(MovementStrings.summaryAddToPlanPrompt), findsOneWidget);
      expect(find.text(MovementStrings.summaryAddToPlanButton), findsOneWidget);
    });

    testWidgets('5. Selecting feeling and tapping Done saves updated log', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeLogService = FakeSummaryLogService();
      bool doneCalled = false;

      await tester.pumpWidget(
        buildTestableWidget(
          SessionSummaryScreen(
            workoutLog: sampleLog,
            activityKind: sampleKind,
            logService: fakeLogService,
            onDone: () => doneCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on feeling chip 'عالی'
      await tester.tap(find.text('عالی'));
      await tester.pumpAndSettle();

      // Tap Done button
      await tester.tap(find.text(MovementStrings.summaryDone));
      await tester.pumpAndSettle();

      expect(doneCalled, isTrue);
      expect(fakeLogService.savedLog?.feeling, equals('عالی'));
    });
  });
}
