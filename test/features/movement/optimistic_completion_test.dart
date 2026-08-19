import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/movement/application/movement_occurrence_service.dart';
import 'package:ritmo/features/movement/application/movement_session_service.dart';
import 'package:ritmo/features/movement/application/strength_program_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';
import 'package:ritmo/features/movement/presentation/center/movement_center_controller.dart';

class FailingOccurrenceService extends MovementOccurrenceService {
  FailingOccurrenceService(this.occurrences);

  Map<String, List<MovementOccurrence>> occurrences;

  @override
  Future<Map<String, List<MovementOccurrence>>> getWeekOccurrencesGrouped(
    String startDateIso,
    String endDateIso,
  ) async {
    return occurrences;
  }

  @override
  Future<void> updateOccurrenceStatus(
    String occurrenceId,
    MovementOccurrenceStatus newStatus,
  ) async {
    // Simulate database network / disk failure
    throw Exception('Database update failed');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Optimistic Completion & Rollback Tests (Requirement 7)', () {
    final today = DateTime.now();
    final todayIso =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final testOcc = MovementOccurrence(
      id: 'occ_opt_1',
      activityKindId: 'kind_walking',
      activityKind: MovementActivityKind(
        id: 'kind_walking',
        nameFa: 'پیاده‌روی',
        family: 'walking',
        icon: 'directions_walk',
        primaryMetric: 'duration',
        createdAt: DateTime.now(),
      ),
      dateIso: todayIso,
      status: MovementOccurrenceStatus.planned,
      goalType: 'duration',
      goalValue: 30,
      goalUnit: 'دقیقه',
      origin: MovementOrigin.template,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    test(
      'Optimistic completion applies status immediately and reverts on failure',
      () async {
        final failingService = FailingOccurrenceService({
          todayIso: [testOcc],
        });

        final controller = MovementCenterController(
          occurrenceService: failingService,
          sessionService: MovementSessionService(),
          strengthProgramService: StrengthProgramService(),
          initialDate: today,
        );

        await controller.loadData();
        expect(
          controller.selectedDayOccurrences.first.status,
          equals(MovementOccurrenceStatus.planned),
        );

        // Trigger optimistic complete
        final success = await controller.optimisticCompleteOccurrence(
          'occ_opt_1',
        );

        // Database failed, so success is false and status reverted back to planned!
        expect(success, isFalse);
        expect(
          controller.selectedDayOccurrences.first.status,
          equals(MovementOccurrenceStatus.planned),
        );
      },
    );
  });
}
