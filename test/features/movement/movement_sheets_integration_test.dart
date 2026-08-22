import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/application/movement_readiness_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';
import 'package:ritmo/features/movement/domain/models/movement_tier.dart';
import 'package:ritmo/features/movement/domain/models/movement_week_stats.dart';
import 'package:ritmo/features/movement/presentation/center/states/movement_has_session_view.dart';
import 'package:ritmo/features/movement/presentation/center/states/movement_rest_day_view.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/day_slot.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/hero_session_card.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/recovery_day_card.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/week_rail.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.now();

  final dummyKind = MovementActivityKind(
    id: 'kind_running',
    nameFa: 'دویدن',
    family: 'cardio',
    icon: 'directions_run',
    primaryMetric: 'duration',
    createdAt: now,
  );

  final dummyOcc = MovementOccurrence(
    id: 'occ_123',
    dateIso: '2026-08-22',
    activityKindId: 'kind_running',
    status: MovementOccurrenceStatus.planned,
    goalType: 'duration',
    goalValue: 30.0,
    goalUnit: 'دقیقه',
    activityKind: dummyKind,
    origin: MovementOrigin.template,
    createdAt: now,
    updatedAt: now,
  );

  const dummyWeekStats = MovementWeekStats.empty();

  final dummyRailDays = <MovementDayData>[
    MovementDayData(
      date: DateTime(2026, 8, 22),
      dayName: 'شنبه',
      dayNumber: 1,
      monthName: 'شهریور',
      state: MovementDaySlotState.selected,
      sessionCount: 1,
      completedCount: 0,
    ),
  ];

  group('Movement Smart Sheets & Hero Session Card Integration Tests', () {
    testWidgets('MovementHasSessionView wires onPlanB and onMoveSession to HeroSessionCard', (tester) async {
      bool planBCalled = false;
      bool moveCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.build(
            palette: RitmoPalette.jadeNoir,
            brightness: Brightness.light,
          ),
          home: Scaffold(
            body: MovementHasSessionView(
              occurrence: dummyOcc,
              weekStats: dummyWeekStats,
              readiness: const ReadinessReady(
                tier: ReadinessTier.light,
                score: 80,
                suggestionFa: 'آمادگی خوب است',
                isEstimated: false,
              ),
              tier: MovementTier.two,
              railDays: dummyRailDays,
              onStartSession: () {},
              onQuickLog: () {},
              onSelectDay: (_) {},
              onPlanB: () => planBCalled = true,
              onMoveSession: () => moveCalled = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HeroSessionCard), findsOneWidget);
      expect(find.text(MovementStrings.heroActionShortVersion), findsOneWidget);
      expect(find.text(MovementStrings.heroActionMove), findsOneWidget);

      await tester.tap(find.text(MovementStrings.heroActionShortVersion));
      await tester.pump();
      expect(planBCalled, isTrue);

      await tester.tap(find.text(MovementStrings.heroActionMove));
      await tester.pump();
      expect(moveCalled, isTrue);
    });

    testWidgets('MovementRestDayView displays RecoveryDayCard', (tester) async {
      bool lightMovementTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.build(
            palette: RitmoPalette.jadeNoir,
            brightness: Brightness.light,
          ),
          home: Scaffold(
            body: MovementRestDayView(
              railDays: dummyRailDays,
              onConfirmRestDay: () {},
              onOpenPicker: () => lightMovementTriggered = true,
              onSelectDay: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RecoveryDayCard), findsOneWidget);
      expect(find.text('امروز استراحت کردن خودش تمرینه.'), findsOneWidget);

      await tester.tap(find.text(MovementStrings.recoveryDayAddLight));
      await tester.pump();
      expect(lightMovementTriggered, isTrue);
    });
  });
}
