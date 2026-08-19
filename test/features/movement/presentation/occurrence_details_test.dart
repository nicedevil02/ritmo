import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/application/movement_occurrence_service.dart';
import 'package:ritmo/features/movement/application/movement_planning_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';
import 'package:ritmo/features/movement/domain/models/movement_change_scope.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';
import 'package:ritmo/features/movement/domain/models/movement_workout_log.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';
import 'package:ritmo/features/movement/presentation/occurrence/occurrence_details_screen.dart';
import 'package:ritmo/features/movement/presentation/occurrence/widgets/occurrence_actions.dart';
import 'package:ritmo/features/movement/presentation/occurrence/widgets/occurrence_header.dart';

class FakeDetailsOccurrenceService extends MovementOccurrenceService {
  FakeDetailsOccurrenceService(this.occurrence, this.logs);

  MovementOccurrence? occurrence;
  List<MovementWorkoutLog> logs;

  @override
  Future<MovementOccurrence?> getOccurrenceById(String occurrenceId) async {
    return occurrence;
  }

  @override
  Future<List<MovementWorkoutLog>> getOccurrenceLogs(
    String occurrenceId,
  ) async {
    return logs;
  }
}

class FakeDetailsPlanningService extends MovementPlanningService {
  bool deleteCalled = false;

  @override
  Future<void> deleteWithScope({
    required String occurrenceId,
    required String focalDateIso,
    String? templateId,
    MovementChangeScope scope = MovementChangeScope.onlyThis,
  }) async {
    deleteCalled = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testOccurrence = MovementOccurrence(
    id: 'occ_test_detail',
    activityKindId: 'kind_running',
    activityKind: MovementActivityKind(
      id: 'kind_running',
      nameFa: 'دویدن',
      family: 'running',
      icon: 'directions_run',
      primaryMetric: 'duration',
      createdAt: DateTime.now(),
    ),
    dateIso: '2026-08-16',
    startTime: '07:30',
    status: MovementOccurrenceStatus.planned,
    goalType: 'duration',
    goalValue: 35.0,
    goalUnit: 'دقیقه',
    origin: MovementOrigin.template,
    templateId: 'tmpl_1',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      theme: RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
      ),
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    );
  }

  group('ActivityOccurrenceDetailsScreen Tests', () {
    testWidgets(
      'Renders occurrence header, goal, origin, logs and action buttons',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final occService = FakeDetailsOccurrenceService(testOccurrence, []);
        final planService = FakeDetailsPlanningService();

        await tester.pumpWidget(
          buildTestableWidget(
            ActivityOccurrenceDetailsScreen(
              occurrenceId: 'occ_test_detail',
              occurrenceService: occService,
              planningService: planService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Header and displayName
        expect(find.byType(OccurrenceHeader), findsOneWidget);
        expect(find.text('دویدن'), findsWidgets);

        // Goal card
        expect(find.text(MovementStrings.occurrenceGoal), findsOneWidget);
        expect(find.text('هدف تعیین‌شده'), findsOneWidget);

        // Origin
        expect(find.text(MovementStrings.occurrenceOrigin), findsOneWidget);
        expect(
          find.text(MovementStrings.occurrenceOriginTemplate),
          findsOneWidget,
        );

        // Actions widget
        expect(find.byType(OccurrenceActions), findsOneWidget);
        expect(find.text(MovementStrings.menuStart), findsOneWidget);
        expect(find.text(MovementStrings.menuManualLog), findsOneWidget);
        expect(find.text(MovementStrings.menuMove), findsOneWidget);
        expect(find.text(MovementStrings.menuShortVersion), findsOneWidget);
        expect(find.text(MovementStrings.menuSkip), findsOneWidget);
        expect(find.text(MovementStrings.menuEditPlan), findsOneWidget);
        expect(find.text(MovementStrings.menuDelete), findsOneWidget);
      },
    );

    testWidgets(
      'Delete button prompts confirmation dialog and deletes occurrence',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final occService = FakeDetailsOccurrenceService(testOccurrence, []);
        final planService = FakeDetailsPlanningService();

        await tester.pumpWidget(
          buildTestableWidget(
            ActivityOccurrenceDetailsScreen(
              occurrenceId: 'occ_test_detail',
              occurrenceService: occService,
              planningService: planService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Scroll to delete button and tap
        await tester.ensureVisible(find.text(MovementStrings.menuDelete));
        await tester.tap(find.text(MovementStrings.menuDelete));
        await tester.pumpAndSettle();

        // Confirm dialog appears
        expect(
          find.text(MovementStrings.occurrenceDeleteConfirmTitle),
          findsOneWidget,
        );
        expect(
          find.text(MovementStrings.occurrenceDeleteConfirmDesc),
          findsOneWidget,
        );

        // Tap confirm delete
        await tester.tap(
          find.widgetWithText(ElevatedButton, MovementStrings.commonDelete),
        );
        await tester.pumpAndSettle();

        expect(planService.deleteCalled, isTrue);
      },
    );
  });
}
