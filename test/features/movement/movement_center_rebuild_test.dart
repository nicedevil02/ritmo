import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/application/movement_occurrence_service.dart';
import 'package:ritmo/features/movement/application/movement_session_service.dart';
import 'package:ritmo/features/movement/application/strength_program_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_live_session.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';
import 'package:ritmo/features/movement/domain/models/movement_strength_program.dart';
import 'package:ritmo/features/movement/domain/models/movement_week_summary.dart';
import 'package:ritmo/features/movement/presentation/center/movement_center_controller.dart';
import 'package:ritmo/features/movement/presentation/center/movement_center_screen.dart';

class RebuildTrackerOccurrenceService extends MovementOccurrenceService {
  int fetchCount = 0;

  @override
  Future<Map<String, List<MovementOccurrence>>> getWeekOccurrencesGrouped(
    String startDateIso,
    String endDateIso,
  ) async {
    fetchCount++;
    return {};
  }

  @override
  Future<MovementWeekSummary> getWeekSummary(
    String startDateIso,
    String endDateIso,
    List<String> allSevenDaysIso,
  ) async {
    return const MovementWeekSummary();
  }
}

class FakeSessionService extends MovementSessionService {
  @override
  Future<MovementLiveSession?> getActiveOrPausedSession() async => null;
}

class FakeStrengthProgramService extends StrengthProgramService {
  @override
  Future<MovementStrengthProgram?> getCurrentProgram() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Day Switching & Nav State Preservation Tests (Requirements 2 & 3)', () {
    testWidgets(
      'Day selection changes instantly from cached data without re-fetching week occurrences',
      (tester) async {
        final tracker = RebuildTrackerOccurrenceService();
        final controller = MovementCenterController(
          occurrenceService: tracker,
          sessionService: FakeSessionService(),
          strengthProgramService: FakeStrengthProgramService(),
        );

        await controller.loadData();

        await tester.pumpWidget(
          MaterialApp(
            theme: RitmoTheme.build(
              palette: RitmoPalette.jadeNoir,
              brightness: Brightness.dark,
            ),
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: MovementCenterScreen(controller: controller),
            ),
          ),
        );

        await tester.pumpAndSettle();
        final initialFetchCount = tracker.fetchCount;
        expect(initialFetchCount, equals(1));

        // Select 3rd day in cached week (synchronous memory update)
        controller.selectDay(controller.weekDays[2].date);
        await tester.pump();

        // Database fetch count must remain 1 (switched from cache in < 100ms)
        expect(tracker.fetchCount, equals(initialFetchCount));
      },
    );

    testWidgets(
      'Preserves selected day after navigating to child route and popping back',
      (tester) async {
        final controller = MovementCenterController(
          occurrenceService: RebuildTrackerOccurrenceService(),
          sessionService: FakeSessionService(),
          strengthProgramService: FakeStrengthProgramService(),
        );

        await controller.loadData();
        final navKey = GlobalKey<NavigatorState>();

        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navKey,
            theme: RitmoTheme.build(
              palette: RitmoPalette.jadeNoir,
              brightness: Brightness.dark,
            ),
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: MovementCenterScreen(controller: controller),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Select 4th day
        controller.selectDay(controller.weekDays[3].date);
        await tester.pumpAndSettle();

        final selectedDateBeforeNav = controller.selectedDate;

        // 2. Push child route
        unawaited(
          navKey.currentState!.push(
            MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('صفحه فرزند')),
                body: ElevatedButton(
                  onPressed: () => navKey.currentState!.pop(),
                  child: const Text('بازگشت'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('صفحه فرزند'), findsOneWidget);

        // 3. Pop back
        await tester.tap(find.text('بازگشت'));
        await tester.pumpAndSettle();

        // 4. Selected date is preserved!
        expect(controller.selectedDate, equals(selectedDateBeforeNav));
      },
    );
  });
}
