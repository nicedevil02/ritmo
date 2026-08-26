import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/schema/schema_manager.dart';
import 'package:ritmo/features/goals/logic/execution_factor.dart';
import 'package:ritmo/features/goals/logic/goals_controller.dart';
import 'package:ritmo/features/goals/logic/planning_repository.dart';
import 'package:ritmo/features/goals/logic/planning_review_repository.dart';
import 'package:ritmo/features/goals/models/planning_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});

    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await SchemaManager.createAll(db);
        },
      ),
    );

    await DatabaseHelper.ensureCriticalSchema(db);
    DatabaseHelper.instance.overrideDatabaseForTesting(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Goals Fixes Audit (RITF-085 .. RITF-088)', () {
    test('RITF-086 & RITF-087: GoalsController persists UI preferences in app_settings', () async {
      final controller = GoalsController();

      await controller.toggleViewMode(false);
      await controller.setTabIndex(2);
      await controller.toggleNodeExpanded('goal_root_1');

      final viewModeRow = await db.query('app_settings', where: "key = 'goals_view_mode'");
      expect(viewModeRow.isNotEmpty, isTrue);
      expect(viewModeRow.first['value'], 'false');

      final tabIndexRow = await db.query('app_settings', where: "key = 'goals_last_tab'");
      expect(tabIndexRow.isNotEmpty, isTrue);
      expect(tabIndexRow.first['value'], '2');

      final expandedRow = await db.query('app_settings', where: "key = 'goals_expanded_ids'");
      expect(expandedRow.isNotEmpty, isTrue);
      expect(expandedRow.first['value']!.toString().contains('goal_root_1'), isTrue);
    });

    test('RITF-087: ExecutionFactor handles empty database and computes baseline gracefully', () async {
      final factor = await ExecutionFactor.computeForPastDays(daysHistory: 21, txn: db);
      expect(factor.value, 1.0);
      expect(factor.sampleDays, 0);
      expect(factor.isReliable, isFalse);
    });

    test('RITF-088: PlanningRepository & PlanningReviewRepository use UpsertHelper', () async {
      final repo = PlanningRepository.instance;
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      final draft = await repo.createDraft(
        horizon: PlanningHorizon.week,
        startDayKey: '2026-08-23',
        endDayKey: '2026-08-29',
        nowMs: nowMs,
      );
      expect(draft.status, CycleStatus.draft);

      final activated = await repo.activate(draft, nowMs: nowMs);
      expect(activated.status, CycleStatus.active);

      final fetched = await repo.activeCycle(PlanningHorizon.week, '2026-08-25');
      expect(fetched, isNotNull);
      expect(fetched!.id, draft.id);

      // Test PlanningAllocation
      final allocation = PlanningAllocation(
        id: 'alloc_1',
        commitmentId: 'commit_1',
        dayKey: '2026-08-27',
        plannedMinutes: 30,
        idempotencyKey: 'idem_1',
        createdAt: nowMs,
        updatedAt: nowMs,
      );
      await repo.insertAllocation(allocation);
      final allocations = await repo.allocationsForDay('2026-08-27');
      expect(allocations.isNotEmpty, isTrue);
      expect(allocations.first.id, 'alloc_1');

      // Test PlanningReviewRepository
      final reviewRepo = PlanningReviewRepository.instance;
      final reviewItem = PlanningReviewItem(
        id: 'review_1',
        cycleId: draft.id,
        reviewType: 'END_CYCLE',
        plannedMinutes: 120,
        completedMinutes: 120,
        movedMinutes: 0,
        droppedMinutes: 0,
        unplannedCompletedMinutes: 0,
        calibrationScore: 1.0,
        createdAt: nowMs,
      );
      await reviewRepo.saveReview(reviewItem);
      final reviews = await reviewRepo.reviewsOf(draft.id);
      expect(reviews.isNotEmpty, isTrue);
      expect(reviews.first.id, 'review_1');
    });
  });
}
