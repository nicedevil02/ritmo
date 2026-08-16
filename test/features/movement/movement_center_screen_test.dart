import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/application/movement_occurrence_service.dart';
import 'package:ritmo/features/movement/application/movement_session_service.dart';
import 'package:ritmo/features/movement/application/strength_program_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';
import 'package:ritmo/features/movement/domain/models/movement_live_session.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';
import 'package:ritmo/features/movement/domain/models/movement_strength_program.dart';
import 'package:ritmo/features/movement/domain/models/movement_week_summary.dart';
import 'package:ritmo/features/movement/presentation/center/movement_center_controller.dart';
import 'package:ritmo/features/movement/presentation/center/movement_center_screen.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/hero_session_card.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/live_session_banner.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/strength_entry_card.dart';
import 'package:ritmo/features/movement/presentation/center/widgets/week_summary_card.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

class FakeOccurrenceService extends MovementOccurrenceService {
  FakeOccurrenceService({
    this.occurrences = const {},
    this.summary = const MovementWeekSummary(),
  });

  Map<String, List<MovementOccurrence>> occurrences;
  MovementWeekSummary summary;

  @override
  Future<Map<String, List<MovementOccurrence>>> getWeekOccurrencesGrouped(
    String startDateIso,
    String endDateIso,
  ) async {
    return occurrences;
  }

  @override
  Future<MovementWeekSummary> getWeekSummary(
    String startDateIso,
    String endDateIso,
    List<String> allSevenDaysIso,
  ) async {
    return summary;
  }
}

class FakeSessionService extends MovementSessionService {
  FakeSessionService({this.session});
  MovementLiveSession? session;

  @override
  Future<MovementLiveSession?> getActiveOrPausedSession() async {
    return session;
  }
}

class FakeStrengthProgramService extends StrengthProgramService {
  FakeStrengthProgramService({this.program});
  MovementStrengthProgram? program;

  @override
  Future<MovementStrengthProgram?> getCurrentProgram() async {
    return program;
  }
}

Widget _wrapScreen(MovementCenterController controller) {
  return MaterialApp(
    theme: RitmoTheme.build(
      palette: RitmoPalette.jadeNoir,
      brightness: Brightness.dark,
    ),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: MovementCenterScreen(
        controller: controller,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testKind = MovementActivityKind(
    id: 'kind_running',
    nameFa: 'دویدن استقامتی',
    family: 'running',
    icon: 'directions_run',
    primaryMetric: 'distance',
    createdAt: DateTime.now(),
  );

  final today = DateTime.now();
  final todayIso =
      '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

  group('MovementCenterScreen 8 Entry States (Requirement 1)', () {
    testWidgets('State 1: Brand New User shows emptyPlan hero, inactive strength card, and 0 summary', (tester) async {
      final controller = MovementCenterController(
        occurrenceService: FakeOccurrenceService(occurrences: {}),
        sessionService: FakeSessionService(session: null),
        strengthProgramService: FakeStrengthProgramService(program: null),
        initialDate: today,
      );

      await controller.loadData();
      await tester.pumpWidget(_wrapScreen(controller));
      await tester.pumpAndSettle();

      expect(controller.entryState, equals(MovementCenterEntryState.brandNewUser));
      expect(find.byType(HeroSessionCard, skipOffstage: false), findsOneWidget);
      expect(find.byType(StrengthEntryCard, skipOffstage: false), findsOneWidget);
      expect(find.byType(WeekSummaryCard, skipOffstage: false), findsOneWidget);
    });

    testWidgets('State 2: Has Plan Today Session shows ready hero with start CTA', (tester) async {
      final occ = MovementOccurrence(
        id: 'occ_today_1',
        activityKindId: 'kind_running',
        activityKind: testKind,
        dateIso: todayIso,
        startTime: '18:00',
        status: MovementOccurrenceStatus.planned,
        goalType: 'duration',
        goalValue: 30,
        goalUnit: 'دقیقه',
        origin: MovementOrigin.template,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final controller = MovementCenterController(
        occurrenceService: FakeOccurrenceService(occurrences: {
          todayIso: [occ],
        }),
        sessionService: FakeSessionService(session: null),
        strengthProgramService: FakeStrengthProgramService(program: null),
        initialDate: today,
      );

      await controller.loadData();
      await tester.pumpWidget(_wrapScreen(controller));
      await tester.pumpAndSettle();

      expect(controller.entryState, equals(MovementCenterEntryState.hasPlanTodaySession));
      expect(find.byType(HeroSessionCard, skipOffstage: false), findsOneWidget);
      expect(find.text(MovementStrings.heroStart, skipOffstage: false), findsOneWidget);
    });

    testWidgets('State 3: Today Session Completed shows allDone hero with summary', (tester) async {
      final occ = MovementOccurrence(
        id: 'occ_today_done',
        activityKindId: 'kind_running',
        activityKind: testKind,
        dateIso: todayIso,
        startTime: '10:00',
        status: MovementOccurrenceStatus.completed,
        goalType: 'duration',
        goalValue: 30,
        goalUnit: 'دقیقه',
        origin: MovementOrigin.template,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final controller = MovementCenterController(
        occurrenceService: FakeOccurrenceService(occurrences: {
          todayIso: [occ],
        }),
        sessionService: FakeSessionService(session: null),
        strengthProgramService: FakeStrengthProgramService(program: null),
        initialDate: today,
      );

      await controller.loadData();
      await tester.pumpWidget(_wrapScreen(controller));
      await tester.pumpAndSettle();

      expect(controller.entryState, equals(MovementCenterEntryState.todaySessionCompleted));
      expect(find.byType(HeroSessionCard, skipOffstage: false), findsOneWidget);
      expect(find.text(MovementStrings.heroAllDone, skipOffstage: false), findsOneWidget);
    });

    testWidgets('State 4: Past Planned Time shows late hero with doNow CTA', (tester) async {
      final occ = MovementOccurrence(
        id: 'occ_late',
        activityKindId: 'kind_running',
        activityKind: testKind,
        dateIso: todayIso,
        startTime: '08:00',
        status: MovementOccurrenceStatus.late,
        goalType: 'duration',
        goalValue: 30,
        goalUnit: 'دقیقه',
        origin: MovementOrigin.template,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final controller = MovementCenterController(
        occurrenceService: FakeOccurrenceService(occurrences: {
          todayIso: [occ],
        }),
        sessionService: FakeSessionService(session: null),
        strengthProgramService: FakeStrengthProgramService(program: null),
        initialDate: today,
      );

      await controller.loadData();
      await tester.pumpWidget(_wrapScreen(controller));
      await tester.pumpAndSettle();

      expect(controller.entryState, equals(MovementCenterEntryState.pastPlannedTime));
      expect(find.byType(HeroSessionCard, skipOffstage: false), findsOneWidget);
      expect(find.text(MovementStrings.heroActionDoNow, skipOffstage: false), findsOneWidget);
    });

    testWidgets('State 5: Multi Sessions Today shows multiToday hero with progress indicator', (tester) async {
      final occ1 = MovementOccurrence(
        id: 'occ_multi_1',
        activityKindId: 'kind_running',
        activityKind: testKind,
        dateIso: todayIso,
        startTime: '08:00',
        status: MovementOccurrenceStatus.completed,
        origin: MovementOrigin.template,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final occ2 = MovementOccurrence(
        id: 'occ_multi_2',
        activityKindId: 'kind_running',
        activityKind: testKind,
        dateIso: todayIso,
        startTime: '18:00',
        status: MovementOccurrenceStatus.planned,
        origin: MovementOrigin.template,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final controller = MovementCenterController(
        occurrenceService: FakeOccurrenceService(occurrences: {
          todayIso: [occ1, occ2],
        }),
        sessionService: FakeSessionService(session: null),
        strengthProgramService: FakeStrengthProgramService(program: null),
        initialDate: today,
      );

      await controller.loadData();
      await tester.pumpWidget(_wrapScreen(controller));
      await tester.pumpAndSettle();

      expect(controller.entryState, equals(MovementCenterEntryState.multiSessionsToday));
      expect(find.byType(HeroSessionCard, skipOffstage: false), findsOneWidget);
      expect(find.text(MovementStrings.heroSessionProgress(1, 2), skipOffstage: false), findsOneWidget);
    });

    testWidgets('State 6: Recovery Day shows restDay hero with light movement action', (tester) async {
      final otherDay = today.subtract(const Duration(days: 1));
      final otherIso =
          '${otherDay.year.toString().padLeft(4, '0')}-${otherDay.month.toString().padLeft(2, '0')}-${otherDay.day.toString().padLeft(2, '0')}';

      final occ = MovementOccurrence(
        id: 'occ_other',
        activityKindId: 'kind_running',
        activityKind: testKind,
        dateIso: otherIso,
        status: MovementOccurrenceStatus.completed,
        origin: MovementOrigin.template,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final controller = MovementCenterController(
        occurrenceService: FakeOccurrenceService(occurrences: {
          otherIso: [occ],
        }),
        sessionService: FakeSessionService(session: null),
        strengthProgramService: FakeStrengthProgramService(program: null),
        initialDate: today,
      );

      await controller.loadData();
      await tester.pumpWidget(_wrapScreen(controller));
      await tester.pumpAndSettle();

      expect(controller.entryState, equals(MovementCenterEntryState.recoveryDay));
      expect(find.byType(HeroSessionCard, skipOffstage: false), findsOneWidget);
      expect(find.text(MovementStrings.heroRestDay, skipOffstage: false), findsOneWidget);
      expect(find.text(MovementStrings.heroActionLightMovement, skipOffstage: false), findsWidgets);
    });

    testWidgets('State 7: In-progress Live Session shows LiveSessionBanner above hero', (tester) async {
      final session = MovementLiveSession(
        id: 'sess_live',
        activityKindId: 'kind_running',
        activityKind: testKind,
        mode: 'standard',
        status: MovementLiveSessionStatus.active,
        startedAt: DateTime.now().subtract(const Duration(minutes: 15)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final controller = MovementCenterController(
        occurrenceService: FakeOccurrenceService(occurrences: {}),
        sessionService: FakeSessionService(session: session),
        strengthProgramService: FakeStrengthProgramService(program: null),
        initialDate: today,
      );

      await controller.loadData();
      await tester.pumpWidget(_wrapScreen(controller));
      await tester.pumpAndSettle();

      expect(controller.entryState, equals(MovementCenterEntryState.inProgressLiveSession));
      expect(find.byType(LiveSessionBanner, skipOffstage: false), findsOneWidget);
      expect(find.text(MovementStrings.bannerResumeSession, skipOffstage: false), findsOneWidget);
    });

    testWidgets('State 8: First launch after cutover shows callout banner and dismisses it', (tester) async {
      final controller = MovementCenterController(
        occurrenceService: FakeOccurrenceService(occurrences: {}),
        sessionService: FakeSessionService(session: null),
        strengthProgramService: FakeStrengthProgramService(program: null),
        initialDate: today,
        isFirstLaunchAfterCutover: true,
      );

      await controller.loadData();
      await tester.pumpWidget(_wrapScreen(controller));
      await tester.pumpAndSettle();

      expect(controller.entryState, equals(MovementCenterEntryState.firstLaunchAfterCutover));
      expect(find.text(MovementStrings.cutoverCalloutDesc, skipOffstage: false), findsOneWidget);

      // Dismiss cutover callout
      controller.dismissCutoverCallout();
      await tester.pumpAndSettle();

      expect(controller.isFirstLaunchAfterCutover, isFalse);
      expect(find.text(MovementStrings.cutoverCalloutDesc, skipOffstage: false), findsNothing);
    });
  });
}
