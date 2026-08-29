import 'package:flutter/foundation.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/upsert_helper.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/features/goals/models/planning_models.dart';
import 'package:sqflite/sqflite.dart';

class PlanningRepository {
  PlanningRepository._();
  static final PlanningRepository instance = PlanningRepository._();

  Database? _testDb;

  @visibleForTesting
  void setTestDatabase(Database? db) {
    _testDb = db;
  }

  Future<Database> get _db async {
    if (_testDb != null) return _testDb!;
    final raw = DatabaseHelper.rawDatabase;
    if (raw != null) return raw;
    return await DatabaseHelper.instance.database;
  }

  Future<PlanningCycle?> activeCycle(PlanningHorizon horizon, String dayKey) async {
    try {
      final db = await _db;
      final res = await db.query(
        'planning_cycles',
        where: 'horizon = ? AND status = ? AND startDayKey <= ? AND endDayKey >= ?',
        whereArgs: [horizon.name.toUpperCase(), 'ACTIVE', dayKey, dayKey],
        orderBy: 'version DESC',
        limit: 1,
      );
      if (res.isEmpty) return null;
      return PlanningCycle.fromMap(res.first);
    } catch (e, st) {
      RitmoLogger.error('PlanningRepository.activeCycle error: $e', error: e, stack: st);
      rethrow;
    }
  }

  Future<PlanningCycle> createDraft({
    required PlanningHorizon horizon,
    required String startDayKey,
    required String endDayKey,
    String? title,
    String? theme,
    required int nowMs,
  }) async {
    final db = await _db;
    final id = 'cycle_${horizon.name}_$nowMs';
    final draft = PlanningCycle(
      id: id,
      horizon: horizon,
      startDayKey: startDayKey,
      endDayKey: endDayKey,
      status: CycleStatus.draft,
      title: title,
      theme: theme,
      createdAt: nowMs,
    );

    await db.transaction((txn) async {
      await txn.insert('planning_cycles', draft.toMap());
    });

    return draft;
  }

  Future<PlanningCycle> activate(PlanningCycle draft, {required int nowMs}) async {
    final db = await _db;
    late PlanningCycle activated;

    await db.transaction((txn) async {
      final existingActive = await txn.query(
        'planning_cycles',
        where: 'horizon = ? AND status = ? AND startDayKey = ? AND endDayKey = ?',
        whereArgs: [draft.horizon.name.toUpperCase(), 'ACTIVE', draft.startDayKey, draft.endDayKey],
        orderBy: 'version DESC',
      );

      var version = 1;
      String? supersedesId;

      if (existingActive.isNotEmpty) {
        final top = existingActive.first;
        version = ((top['version'] as num?)?.toInt() ?? 1) + 1;
        supersedesId = top['id'] as String;

        await txn.update(
          'planning_cycles',
          {'status': 'CLOSED', 'closedAt': nowMs},
          where: 'horizon = ? AND status = ? AND startDayKey = ? AND endDayKey = ?',
          whereArgs: [draft.horizon.name.toUpperCase(), 'ACTIVE', draft.startDayKey, draft.endDayKey],
        );
      }

      activated = draft.copyWith(
        status: CycleStatus.active,
        version: version,
        supersedesCycleId: supersedesId,
        activatedAt: nowMs,
      );

      await UpsertHelper.upsert(
        txn,
        'planning_cycles',
        activated.toMap(),
        conflictColumns: const ['id'],
      );
    });

    RitmoEventBus().fire(RitmoEvent(
      type: 'planningCycleActivated',
      timestamp: DateTime.fromMillisecondsSinceEpoch(nowMs),
      payload: {'cycleId': activated.id, 'horizon': activated.horizon.name},
    ));

    return activated;
  }

  Future<void> closeCycle(String id, {int? nowMs}) async {
    final db = await _db;
    final ms = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.update(
        'planning_cycles',
        {'status': 'CLOSED', 'closedAt': ms},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> deleteDraftCycle(String id) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.rawDelete('''
        DELETE FROM planning_allocations
        WHERE commitmentId IN (
          SELECT id FROM planning_commitments WHERE cycleId = ?
        )
      ''', [id]);
      await txn.delete(
        'planning_commitments',
        where: 'cycleId = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'planning_cycles',
        where: 'id = ? AND status = ?',
        whereArgs: [id, 'DRAFT'],
      );
    });
  }

  Future<List<PlanningCommitment>> commitmentsOf(String cycleId) async {
    try {
      final db = await _db;
      final res = await db.query(
        'planning_commitments',
        where: 'cycleId = ?',
        whereArgs: [cycleId],
      );
      return res.map(PlanningCommitment.fromMap).toList();
    } catch (e, st) {
      RitmoLogger.error('PlanningRepository.commitmentsOf error: $e', error: e, stack: st);
      rethrow;
    }
  }

  Future<PlanningCommitment?> commitmentById(String id) async {
    try {
      final db = await _db;
      final res = await db.query(
        'planning_commitments',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (res.isEmpty) return null;
      return PlanningCommitment.fromMap(res.first);
    } catch (e, st) {
      RitmoLogger.error('PlanningRepository.commitmentById error: $e', error: e, stack: st);
      return null;
    }
  }

  Future<void> upsertCommitment(PlanningCommitment c) async {
    final db = await _db;
    await db.transaction((txn) async {
      final existing = await txn.query(
        'planning_commitments',
        where: 'id = ?',
        whereArgs: [c.id],
      );
      if (existing.isEmpty) {
        await txn.insert('planning_commitments', c.toMap());
      } else {
        await txn.update(
          'planning_commitments',
          c.toMap(),
          where: 'id = ?',
          whereArgs: [c.id],
        );
      }
    });

    RitmoEventBus().fire(RitmoEvent(
      type: 'commitmentChanged',
      timestamp: DateTime.now(),
      payload: {'commitmentId': c.id},
    ));
  }

  Future<void> setCommitmentStatus(String id, CommitmentStatus s, {int? nowMs}) async {
    final db = await _db;
    final ms = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.update(
        'planning_commitments',
        {'status': s.name.toUpperCase(), 'updatedAt': ms},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> dropCommitment(String id, {String? reason, int? nowMs}) async {
    final db = await _db;
    final ms = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.update(
        'planning_commitments',
        {
          'status': 'DROPPED',
          'planningReason': reason,
          'updatedAt': ms,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<List<PlanningAllocation>> allocationsOf(String cycleId) async {
    try {
      final db = await _db;
      final res = await db.rawQuery('''
        SELECT a.* FROM planning_allocations a
        INNER JOIN planning_commitments c ON a.commitmentId = c.id
        WHERE c.cycleId = ? AND a.status != 'DROPPED' AND a.status != 'MOVED' AND c.status != 'DROPPED'
      ''', [cycleId]);
      return res.map(PlanningAllocation.fromMap).toList();
    } catch (e, st) {
      RitmoLogger.error('PlanningRepository.allocationsOf error: $e', error: e, stack: st);
      rethrow;
    }
  }

  Future<List<PlanningAllocation>> allocationsForDay(String dayKey) async {
    try {
      final db = await _db;
      final res = await db.query(
        'planning_allocations',
        where: "dayKey = ? AND status != 'DROPPED' AND status != 'MOVED'",
        whereArgs: [dayKey],
      );
      return res.map(PlanningAllocation.fromMap).toList();
    } catch (e, st) {
      RitmoLogger.error('PlanningRepository.allocationsForDay error: $e', error: e, stack: st);
      rethrow;
    }
  }

  Future<int> purgeGhostAllocations(String cycleId) async {
    try {
      final db = await _db;
      return await db.transaction((txn) async {
        final count = await txn.rawDelete('''
          DELETE FROM planning_allocations
          WHERE commitmentId IN (
            SELECT id FROM planning_commitments WHERE cycleId = ?
          ) AND (status = 'DROPPED' OR status = 'MOVED')
        ''', [cycleId]);
        return count;
      });
    } catch (e, st) {
      RitmoLogger.error('PlanningRepository.purgeGhostAllocations error: $e', error: e, stack: st);
      return 0;
    }
  }

  Future<void> insertAllocation(PlanningAllocation a) async {
    final db = await _db;
    try {
      await db.transaction((txn) async {
        await UpsertHelper.upsert(
          txn,
          'planning_allocations',
          a.toMap(),
          conflictColumns: const ['id'],
        );
      });
    } catch (e, st) {
      RitmoLogger.error(
        'PlanningRepository: Allocation insert error: $e',
        error: e,
        stack: st,
      );
    }
  }

  Future<void> moveAllocation(String allocationId, String newDayKey, {int? nowMs}) async {
    final db = await _db;
    final ms = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      final existing = await txn.query(
        'planning_allocations',
        where: 'id = ?',
        whereArgs: [allocationId],
      );

      if (existing.isNotEmpty) {
        final old = existing.first;
        await txn.update(
          'planning_allocations',
          {'status': 'MOVED', 'updatedAt': ms},
          where: 'id = ?',
          whereArgs: [allocationId],
        );

        final newAllocId = 'alloc_${ms}_${allocationId.hashCode}';
        await txn.insert('planning_allocations', {
          'id': newAllocId,
          'commitmentId': old['commitmentId'],
          'dayKey': newDayKey,
          'plannedMinutes': old['plannedMinutes'],
          'timeWindowStart': old['timeWindowStart'],
          'timeWindowEnd': old['timeWindowEnd'],
          'exactTime': old['exactTime'],
          'status': 'PLANNED',
          'materializedEntityType': old['materializedEntityType'],
          'materializedEntityId': old['materializedEntityId'],
          'idempotencyKey': '$allocationId|moved|$newDayKey',
          'createdAt': ms,
          'updatedAt': ms,
        });
      }
    });
  }

  Future<void> updateCycleTheme(String cycleId, String themeJson) async {
    final db = await _db;
    await db.update(
      'planning_cycles',
      {'theme': themeJson},
      where: 'id = ?',
      whereArgs: [cycleId],
    );
  }

  Future<void> setDayLight(String dayKey, bool isLight) async {
    final db = await _db;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (isLight) {
      final existing = await db.query(
        'calendar_exceptions',
        where: 'date = ?',
        whereArgs: [dayKey],
      );
      if (existing.isNotEmpty) {
        await db.update(
          'calendar_exceptions',
          {
            'behavior': 'ESSENTIAL_ONLY',
            'reason': 'LIGHT_DAY',
            'updatedAt': nowMs,
          },
          where: 'date = ?',
          whereArgs: [dayKey],
        );
      } else {
        await db.insert(
          'calendar_exceptions',
          {
            'id': 'ce_$dayKey',
            'date': dayKey,
            'behavior': 'ESSENTIAL_ONLY',
            'reason': 'LIGHT_DAY',
            'createdAt': nowMs,
            'updatedAt': nowMs,
          },
        );
      }
    } else {
      await db.delete(
        'calendar_exceptions',
        where: "date = ? AND (reason = 'LIGHT_DAY' OR behavior = 'ESSENTIAL_ONLY')",
        whereArgs: [dayKey],
      );
    }
  }

  Future<Set<String>> getLightDays() async {
    try {
      final db = await _db;
      final rows = await db.query(
        'calendar_exceptions',
        columns: ['date'],
        where: "reason = 'LIGHT_DAY' OR behavior = 'ESSENTIAL_ONLY'",
      );
      return rows
          .map((r) => r['date'] as String?)
          .whereType<String>()
          .toSet();
    } catch (e, st) {
      RitmoLogger.error('PlanningRepository.getLightDays error: $e', error: e, stack: st);
      rethrow;
    }
  }
}
