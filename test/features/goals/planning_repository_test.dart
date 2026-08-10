import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/goals/logic/planning_repository.dart';
import 'package:ritmo/features/goals/models/planning_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (d, v) async {
        await d.execute('PRAGMA foreign_keys = ON;');
        await d.execute('''
          CREATE TABLE IF NOT EXISTS planning_cycles (
            id TEXT PRIMARY KEY,
            horizon TEXT NOT NULL,
            startDayKey TEXT NOT NULL,
            endDayKey TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'DRAFT',
            title TEXT,
            theme TEXT,
            capacityMinutes INTEGER NOT NULL DEFAULT 0,
            reserveMinutes INTEGER NOT NULL DEFAULT 0,
            version INTEGER NOT NULL DEFAULT 1,
            supersedesCycleId TEXT,
            createdAt INTEGER NOT NULL,
            activatedAt INTEGER,
            closedAt INTEGER
          );
        ''');
        await d.execute('''
          CREATE TABLE IF NOT EXISTS planning_commitments (
            id TEXT PRIMARY KEY,
            cycleId TEXT NOT NULL REFERENCES planning_cycles(id) ON DELETE CASCADE,
            title TEXT NOT NULL,
            sourceType TEXT NOT NULL DEFAULT 'MANUAL',
            sourceId TEXT,
            goalId TEXT,
            importance TEXT NOT NULL DEFAULT 'SHOULD',
            flexibility TEXT NOT NULL DEFAULT 'FLEXIBLE',
            effortMinutes INTEGER NOT NULL DEFAULT 30,
            workKind TEXT NOT NULL DEFAULT 'LIGHT',
            earliestDayKey TEXT,
            latestDayKey TEXT,
            preferredDayPartsJson TEXT,
            status TEXT NOT NULL DEFAULT 'PROPOSED',
            isUserLocked INTEGER NOT NULL DEFAULT 0,
            origin TEXT NOT NULL DEFAULT 'USER',
            planningReason TEXT,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          );
        ''');
        await d.execute('''
          CREATE TABLE IF NOT EXISTS planning_allocations (
            id TEXT PRIMARY KEY,
            commitmentId TEXT NOT NULL REFERENCES planning_commitments(id) ON DELETE CASCADE,
            dayKey TEXT NOT NULL,
            plannedMinutes INTEGER NOT NULL,
            timeWindowStart TEXT,
            timeWindowEnd TEXT,
            exactTime TEXT,
            status TEXT NOT NULL DEFAULT 'PLANNED',
            materializedEntityType TEXT,
            materializedEntityId TEXT,
            idempotencyKey TEXT NOT NULL UNIQUE,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          );
        ''');
      },
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('D-08 Test 1: draft -> activate -> second activate updates version and supersedesId', () async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final repo = PlanningRepository.instance;

    final cycle1 = PlanningCycle(
      id: 'c1',
      horizon: PlanningHorizon.week,
      startDayKey: '2026-08-08',
      endDayKey: '2026-08-14',
      status: CycleStatus.draft,
      createdAt: nowMs,
    );

    await db.insert('planning_cycles', cycle1.toMap());

    final act1 = await repo.activate(cycle1, nowMs: nowMs);
    expect(act1.status, equals(CycleStatus.active));
    expect(act1.version, equals(1));

    final cycle2 = PlanningCycle(
      id: 'c2',
      horizon: PlanningHorizon.week,
      startDayKey: '2026-08-08',
      endDayKey: '2026-08-14',
      status: CycleStatus.draft,
      createdAt: nowMs + 100,
    );

    final act2 = await repo.activate(cycle2, nowMs: nowMs + 100);
    expect(act2.status, equals(CycleStatus.active));
    expect(act2.version, equals(2));
    expect(act2.supersedesCycleId, equals('c1'));

    final oldCycleRes = await db.query('planning_cycles', where: 'id = ?', whereArgs: ['c1']);
    expect(oldCycleRes.first['status'], equals('CLOSED'));
  });

  test('D-08 Test 2: insertAllocation idempotency check', () async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final repo = PlanningRepository.instance;

    await db.insert('planning_cycles', {
      'id': 'c1', 'horizon': 'WEEK', 'startDayKey': '2026-08-08', 'endDayKey': '2026-08-14', 'createdAt': nowMs,
    });
    await db.insert('planning_commitments', {
      'id': 'cm1', 'cycleId': 'c1', 'title': 'Test', 'createdAt': nowMs, 'updatedAt': nowMs,
    });

    final alloc = PlanningAllocation(
      id: 'a1',
      commitmentId: 'cm1',
      dayKey: '2026-08-09',
      plannedMinutes: 30,
      idempotencyKey: 'idemp_key_1',
      createdAt: nowMs,
      updatedAt: nowMs,
    );

    await repo.insertAllocation(alloc);
    await repo.insertAllocation(alloc); // Repeat insert

    final rows = await db.query('planning_allocations');
    expect(rows.length, equals(1));
  });

  test('D-08 Test 3: moveAllocation updates old status to MOVED and inserts new allocation', () async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final repo = PlanningRepository.instance;

    await db.insert('planning_cycles', {
      'id': 'c1', 'horizon': 'WEEK', 'startDayKey': '2026-08-08', 'endDayKey': '2026-08-14', 'createdAt': nowMs,
    });
    await db.insert('planning_commitments', {
      'id': 'cm1', 'cycleId': 'c1', 'title': 'Test', 'createdAt': nowMs, 'updatedAt': nowMs,
    });
    await db.insert('planning_allocations', {
      'id': 'a1', 'commitmentId': 'cm1', 'dayKey': '2026-08-09', 'plannedMinutes': 30,
      'status': 'PLANNED', 'idempotencyKey': 'idemp_1', 'createdAt': nowMs, 'updatedAt': nowMs,
    });

    await repo.moveAllocation('a1', '2026-08-10', nowMs: nowMs + 50);

    final oldAlloc = await db.query('planning_allocations', where: 'id = ?', whereArgs: ['a1']);
    expect(oldAlloc.first['status'], equals('MOVED'));

    final newAlloc = await db.query('planning_allocations', where: 'status = ?', whereArgs: ['PLANNED']);
    expect(newAlloc.length, equals(1));
    expect(newAlloc.first['dayKey'], equals('2026-08-10'));
  });

  test('D-08 Test 4: dropCommitment sets status to DROPPED without physical delete', () async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final repo = PlanningRepository.instance;

    await db.insert('planning_cycles', {
      'id': 'c1', 'horizon': 'WEEK', 'startDayKey': '2026-08-08', 'endDayKey': '2026-08-14', 'createdAt': nowMs,
    });
    await db.insert('planning_commitments', {
      'id': 'cm1', 'cycleId': 'c1', 'title': 'Test', 'status': 'PROPOSED', 'createdAt': nowMs, 'updatedAt': nowMs,
    });

    await repo.dropCommitment('cm1', reason: 'Not enough time', nowMs: nowMs + 10);

    final res = await db.query('planning_commitments', where: 'id = ?', whereArgs: ['cm1']);
    expect(res.isNotEmpty, isTrue);
    expect(res.first['status'], equals('DROPPED'));
    expect(res.first['planningReason'], equals('Not enough time'));
  });

  test('D-08 Test 5: delete DRAFT cycle cascades delete to commitments and allocations', () async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final repo = PlanningRepository.instance;

    await db.insert('planning_cycles', {
      'id': 'c1', 'horizon': 'WEEK', 'startDayKey': '2026-08-08', 'endDayKey': '2026-08-14', 'status': 'DRAFT', 'createdAt': nowMs,
    });
    await db.insert('planning_commitments', {
      'id': 'cm1', 'cycleId': 'c1', 'title': 'Test', 'createdAt': nowMs, 'updatedAt': nowMs,
    });
    await db.insert('planning_allocations', {
      'id': 'a1', 'commitmentId': 'cm1', 'dayKey': '2026-08-09', 'plannedMinutes': 30,
      'status': 'PLANNED', 'idempotencyKey': 'idemp_1', 'createdAt': nowMs, 'updatedAt': nowMs,
    });

    await repo.deleteDraftCycle('c1');

    final cycles = await db.query('planning_cycles');
    expect(cycles.isEmpty, isTrue);

    final commitments = await db.query('planning_commitments');
    expect(commitments.isEmpty, isTrue);

    final allocations = await db.query('planning_allocations');
    expect(allocations.isEmpty, isTrue);
  });
}
