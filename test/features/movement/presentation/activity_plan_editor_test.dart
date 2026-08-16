import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/application/movement_occurrence_service.dart';
import 'package:ritmo/features/movement/application/movement_planning_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';
import 'package:ritmo/features/movement/domain/models/movement_plan_schedule.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';
import 'package:ritmo/features/movement/presentation/planner/activity_plan_editor_controller.dart';
import 'package:ritmo/features/movement/presentation/planner/activity_plan_editor_screen.dart';
import 'package:ritmo/features/movement/presentation/planner/widgets/conflict_panel.dart';
import 'package:ritmo/features/movement/presentation/planner/widgets/goal_field_group.dart';
import 'package:ritmo/features/movement/presentation/planner/widgets/plan_preview_card.dart';
import 'package:ritmo/features/movement/presentation/planner/widgets/weekday_chips.dart';

class FakePlannerOccurrenceService extends MovementOccurrenceService {
  @override
  Future<MovementActivityKind?> getActivityKind(String id) async {
    return MovementActivityKind(
      id: id,
      nameFa: 'دویدن',
      family: 'running',
      icon: 'directions_run',
      primaryMetric: 'duration',
      createdAt: DateTime.now(),
    );
  }
}

class FakePlannerPlanningService extends MovementPlanningService {
  FakePlannerPlanningService({this.conflictsToReturn = const []});

  List<MovementOccurrence> conflictsToReturn;
  bool createPlanCalled = false;

  @override
  Future<List<MovementOccurrence>> checkConflicts({
    required String dateIso,
    required String timeOfDay,
    String? excludeOccurrenceId,
  }) async {
    return conflictsToReturn;
  }

  @override
  Future<String> createPlan({
    required String activityKindId,
    String sessionType = 'repeating',
    Map<String, dynamic>? goal,
    String reminderType = 'none',
    int? reminderOffsetMin,
    required List<MovementPlanSchedule> schedules,
    int horizonWeeks = 4,
  }) async {
    createPlanCalled = true;
    return 'tmpl_new_created';
  }
}

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
        child: child,
      ),
    );
  }

  group('ActivityPlanEditorScreen 8-Step Planner Tests', () {
    testWidgets('Renders all 8-step building blocks without overflow', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final occService = FakePlannerOccurrenceService();
      final planService = FakePlannerPlanningService();
      final controller = ActivityPlanEditorController(
        occurrenceService: occService,
        planningService: planService,
        initialActivityKindId: 'kind_running',
      );
      await controller.init();

      await tester.pumpWidget(
        buildTestableWidget(
          ActivityPlanEditorScreen(
            controller: controller,
            activityKindId: 'kind_running',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify all key planner components exist on the single scrollable page
      expect(find.byType(GoalFieldGroup, skipOffstage: false), findsOneWidget);
      expect(find.byType(WeekdayChips, skipOffstage: false), findsOneWidget);
      expect(find.byType(ConflictPanel, skipOffstage: false), findsOneWidget);
      expect(find.byType(PlanPreviewCard, skipOffstage: false), findsOneWidget);
    });

    testWidgets('Conflict panel displays suggestions when conflicts are detected', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final occService = FakePlannerOccurrenceService();
      final planService = FakePlannerPlanningService(
        conflictsToReturn: [
          MovementOccurrence(
            id: 'occ_conf_1',
            activityKindId: 'kind_cycling',
            dateIso: '2026-08-16',
            startTime: '07:00',
            status: MovementOccurrenceStatus.planned,
            origin: MovementOrigin.template,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
      );
      final controller = ActivityPlanEditorController(
        occurrenceService: occService,
        planningService: planService,
        initialActivityKindId: 'kind_running',
      );
      await controller.init();

      await tester.pumpWidget(
        buildTestableWidget(
          ActivityPlanEditorScreen(
            controller: controller,
            activityKindId: 'kind_running',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Conflict title and suggestions must be visible
      expect(find.text(MovementStrings.conflictDetectedTitle, skipOffstage: false), findsOneWidget);
      expect(find.text(MovementStrings.conflictSuggestOtherTime, skipOffstage: false), findsOneWidget);
      expect(find.text(MovementStrings.conflictSuggestShorten, skipOffstage: false), findsOneWidget);
      expect(find.text(MovementStrings.conflictSuggestMoveToFreeDay, skipOffstage: false), findsOneWidget);
    });

    testWidgets('Save button triggers createPlan when valid schedules are selected', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final occService = FakePlannerOccurrenceService();
      final planService = FakePlannerPlanningService();
      final controller = ActivityPlanEditorController(
        occurrenceService: occService,
        planningService: planService,
        initialActivityKindId: 'kind_running',
      );
      await controller.init();

      await tester.pumpWidget(
        buildTestableWidget(
          ActivityPlanEditorScreen(
            controller: controller,
            activityKindId: 'kind_running',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to save button and tap
      await tester.ensureVisible(find.text(MovementStrings.plannerSaveButton));
      await tester.tap(find.text(MovementStrings.plannerSaveButton));
      await tester.pumpAndSettle();

      expect(planService.createPlanCalled, isTrue);
    });
  });
}
