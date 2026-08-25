// lib/features/sports/movement/data/movement_repository.dart

import 'package:ritmo/core/analytics/movement_load_calculator.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/utils/ritmo_id_factory.dart';
import 'package:ritmo/core/utils/text_similarity.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_event.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_kind.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/seed/movement_kinds_seed.dart';
import 'package:sqflite/sqflite.dart';

class PRCheckResult {
  const PRCheckResult({
    required this.isNewPr,
    this.prType,
    this.value,
    this.previousValue,
  });

  final bool isNewPr;
  final String? prType;
  final double? value;
  final double? previousValue;
}

class MovementRepository {
  MovementRepository._();
  static final instance = MovementRepository._();

  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<List<MovementKind>> getKinds({
    MovementFamily? family,
    bool enabledOnly = true,
  }) async {
    final db = await _db;
    final whereClause = StringBuffer(enabledOnly ? 'isEnabled = 1' : '1=1');
    final whereArgs = <dynamic>[];
    if (family != null) {
      whereClause.write(' AND family = ?');
      whereArgs.add(family.code);
    }

    Future<List<Map<String, Object?>>> runQuery() => db.query(
      'movement_kinds',
      where: whereClause.toString(),
      whereArgs: whereArgs,
      orderBy: 'usageCount DESC, sortOrder ASC, titleFa ASC',
    );

    var rows = await runQuery();
    if (rows.isEmpty) {
      // هرگز بهخاطر خالی بودن نتیجهٔ یک فیلتر seed نکن.
      // فقط وقتی bootstrap میکنیم که کل جدول واقعاً خالی باشد.
      final total =
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM movement_kinds'),
          ) ??
          0;
      if (total == 0) {
        await MovementKindsSeed.seed(db);
        rows = await runQuery();
      }
    }
    return rows.map(MovementKind.fromMap).toList();
  }

  /// Search kinds by Persian query, matching titleFa, code, or aliasesFa.
  Future<List<MovementKind>> searchKinds(String query) async {
    final q = TextSimilarity.normalize(query).trim().toLowerCase();
    if (q.isEmpty) return getKinds();

    final db = await _db;
    final all = await db.query('movement_kinds', where: 'isEnabled = 1');
    final kinds = all.map((r) => MovementKind.fromMap(r)).toList();

    return kinds.where((k) {
      final titleNorm = TextSimilarity.normalize(k.titleFa).toLowerCase();
      final aliasesNorm = TextSimilarity.normalize(
        k.aliasesFa ?? '',
      ).toLowerCase();
      final codeNorm = k.code.toLowerCase();

      return titleNorm.contains(q) ||
          aliasesNorm.contains(q) ||
          codeNorm.contains(q);
    }).toList();
  }

  /// Fetch recently or most used kinds for quick pickers.
  Future<List<MovementKind>> recentKinds({int limit = 6}) async {
    final db = await _db;
    final rows = await db.query(
      'movement_kinds',
      where: 'isEnabled = 1 AND usageCount > 0',
      orderBy: 'lastUsedAt DESC, usageCount DESC',
      limit: limit,
    );

    if (rows.length < limit) {
      final fallbackRows = await db.query(
        'movement_kinds',
        where: 'isEnabled = 1',
        orderBy: 'usageCount DESC, sortOrder ASC',
        limit: limit,
      );
      final combined = <String, Map<String, dynamic>>{};
      for (final r in [...rows, ...fallbackRows]) {
        combined[r['code'] as String] = r;
      }
      return combined.values
          .take(limit)
          .map((r) => MovementKind.fromMap(r))
          .toList();
    }

    return rows.map((r) => MovementKind.fromMap(r)).toList();
  }

  /// Get single kind by code.
  Future<MovementKind?> getKind(String code) async {
    final db = await _db;
    return getKindIn(db, code);
  }

  /// Transaction-safe variant of [getKind].
  /// Any code path that may run inside a transaction MUST call this
  /// with the transaction's own executor.
  Future<MovementKind?> getKindIn(
    DatabaseExecutor executor,
    String code,
  ) async {
    final rows = await executor.query(
      'movement_kinds',
      where: 'code = ?',
      whereArgs: [code],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MovementKind.fromMap(rows.first);
  }

  /// Create user custom movement kind.
  Future<MovementKind> createCustomKind(MovementKind kind) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;

    final customMap = Map<String, dynamic>.from(kind.toMap())
      ..['isCustom'] = 1
      ..['isEnabled'] = 1
      ..['createdAt'] = now
      ..['updatedAt'] = now;

    await db.insert(
      'movement_kinds',
      customMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return MovementKind.fromMap(customMap);
  }

  /// Transaction-aware upsert for MovementEvent. Idempotent and does not fire EventBus.
  Future<Map<String, dynamic>> upsertEventInTransaction(
    DatabaseExecutor txn,
    MovementEvent event,
  ) async {
    final sourceEntityId = event.sourceEntityId ?? event.id;
    final existing = await txn.query(
      'workout_logs',
      where: '(id = ?) OR (sourceModule = ? AND sourceEntityId = ?)',
      whereArgs: [event.id, event.sourceModule, sourceEntityId],
      limit: 1,
    );

    final kind = await getKindIn(txn, event.kindCode);
    final met = MovementLoadCalculator.metFor(
      baseMet: kind?.baseMet ?? 4.0,
      metLow: kind?.metLow ?? 3.0,
      metHigh: kind?.metHigh ?? 6.0,
      intensity: event.intensity,
    );
    final weightKg = await MovementLoadCalculator.getUserWeightKg(txn);
    final metMins = MovementLoadCalculator.metMinutes(
      met: met,
      durationMinutes: event.durationMinutes,
    );
    final kcal = MovementLoadCalculator.calories(
      met: met,
      weightKg: weightKg,
      durationMinutes: event.durationMinutes,
    );

    final fullEvent = event.copyWith(
      sourceEntityId: sourceEntityId,
      metMinutes: metMins,
      caloriesKcal: kcal,
    );

    if (existing.isNotEmpty) {
      final existingId = existing.first['id'].toString();
      await txn.update(
        'workout_logs',
        fullEvent.copyWith(id: existingId).toMap(),
        where: 'id = ?',
        whereArgs: [existingId],
      );
      await _recalculatePrsForKind(txn, fullEvent.kindCode);
      return {'id': existingId, 'isPr': false, 'wasDuplicate': true};
    }

    await txn.insert('workout_logs', fullEvent.toMap());
    await txn.rawUpdate(
      '''
      UPDATE movement_kinds
      SET usageCount = usageCount + 1, lastUsedAt = ?
      WHERE code = ?
    ''',
      [fullEvent.loggedAt, fullEvent.kindCode],
    );

    final prResult = await _checkAndRecordPrs(txn, fullEvent, kind);
    return {'id': fullEvent.id, 'isPr': prResult.isNewPr, 'prResult': prResult};
  }

  /// Main method to log a MovementEvent. Handles MET/calories calculations,
  /// kind usage counter, PR checks, and event bus notification inside a transaction.
  Future<Map<String, dynamic>> logEvent(MovementEvent event) async {
    final db = await _db;
    Map<String, dynamic> result = {};

    await db.transaction((txn) async {
      result = await upsertEventInTransaction(txn, event);
    });

    // Fire event bus after commit
    RitmoEventBus().fire(
      RitmoEvent(
        type: RitmoEventType.workoutLogChanged.code,
        timestamp: DateTime.now(),
        payload: {
          'source': event.sourceModule,
          'id': result['id'] ?? event.id,
          'kind': event.kindCode,
          'loggedAt': event.loggedAt,
          'isPr': result['isPr'] ?? false,
        },
      ),
    );

    return result;
  }

  /// Update existing movement event.
  Future<void> updateEvent(MovementEvent event) async {
    final db = await _db;
    final kind = await getKind(event.kindCode);

    final met = MovementLoadCalculator.metFor(
      baseMet: kind?.baseMet ?? 4.0,
      metLow: kind?.metLow ?? 3.0,
      metHigh: kind?.metHigh ?? 6.0,
      intensity: event.intensity,
    );

    final weightKg = await MovementLoadCalculator.getUserWeightKg(db);
    final metMins = MovementLoadCalculator.metMinutes(
      met: met,
      durationMinutes: event.durationMinutes,
    );
    final kcal = MovementLoadCalculator.calories(
      met: met,
      weightKg: weightKg,
      durationMinutes: event.durationMinutes,
    );

    final updated = event.copyWith(metMinutes: metMins, caloriesKcal: kcal);

    await db.transaction((txn) async {
      await txn.update(
        'workout_logs',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [event.id],
      );
      await _recalculatePrsForKind(txn, event.kindCode);
    });

    RitmoEventBus().fire(
      RitmoEvent(
        type: RitmoEventType.workoutLogChanged.code,
        timestamp: DateTime.now(),
        payload: {
          'source': event.sourceModule,
          'id': event.id,
          'kind': event.kindCode,
        },
      ),
    );
  }

  /// Delete a movement event.
  /// Logs owned by other modules (e.g. strength sessions written by the
  /// completion gateway with sourceModule != 'MOVEMENT') are protected and
  /// must be deleted from their owning module.
  Future<void> deleteEvent(String id) async {
    final db = await _db;
    String? kindCode;

    await db.transaction((txn) async {
      final rows = await txn.query(
        'workout_logs',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return;

      final row = rows.first;
      final sourceModule = row['sourceModule'] as String? ?? 'MOVEMENT';
      if (sourceModule != 'MOVEMENT' && sourceModule != 'MOVEMENT_SESSION') {
        throw StateError(
          'DELETE_BLOCKED: workout_logs row $id belongs to sourceModule=$sourceModule; '
          'delete or revert it from that module.',
        );
      }

      kindCode = row['kind']?.toString() ?? row['type']?.toString();

      await txn.delete(
        'workout_exercise_logs',
        where: 'workoutLogId = ?',
        whereArgs: [id],
      );
      await txn.delete('workout_logs', where: 'id = ?', whereArgs: [id]);

      if (sourceModule == 'MOVEMENT_SESSION') {
        final sessionId = row['sourceEntityId'] as String?;
        if (sessionId != null && sessionId.isNotEmpty) {
          await txn.delete(
            'movement_sessions',
            where: 'id = ?',
            whereArgs: [sessionId],
          );
          await txn.delete(
            'movement_session_events',
            where: 'sessionId = ?',
            whereArgs: [sessionId],
          );
        }
      }

      if (kindCode != null && kindCode!.isNotEmpty) {
        // شمارندهٔ استفاده را هماهنگ نگه دار (هرگز منفی نشود).
        await txn.rawUpdate(
          'UPDATE movement_kinds SET usageCount = MAX(usageCount - 1, 0) WHERE code = ?',
          [kindCode],
        );
        await _recalculatePrsForKind(txn, kindCode!);
      }
    });

    RitmoEventBus().fire(
      RitmoEvent(
        type: RitmoEventType.workoutLogChanged.code,
        timestamp: DateTime.now(),
        payload: {'source': 'movement', 'id': id, 'action': 'deleted'},
      ),
    );
  }

  Future<void> _recalculatePrsForKind(
    DatabaseExecutor txn,
    String kindCode,
  ) async {
    final logs = await txn.query(
      'workout_logs',
      where: '(kind = ? OR type = ?)',
      whereArgs: [kindCode, kindCode],
    );

    final prTypes = [
      'MAX_DISTANCE',
      'MAX_DURATION',
      'MAX_ELEVATION',
      'MAX_LAPS',
    ];
    for (final prType in prTypes) {
      double? maxVal;
      String? topLogId;
      int? topLoggedAt;

      for (final log in logs) {
        double? val;
        if (prType == 'MAX_DISTANCE') {
          final dist = log['distanceMeters'] as num?;
          if (dist != null && dist > 0) val = dist / 1000.0;
        } else if (prType == 'MAX_DURATION') {
          final dur = log['durationMinutes'] as num?;
          if (dur != null && dur > 0) val = dur.toDouble();
        } else if (prType == 'MAX_ELEVATION') {
          final elev = log['elevationMeters'] as num?;
          if (elev != null && elev > 0) val = elev.toDouble();
        } else if (prType == 'MAX_LAPS') {
          final laps = log['laps'] as num?;
          if (laps != null && laps > 0) val = laps.toDouble();
        }

        if (val != null) {
          if (maxVal == null || val > maxVal) {
            maxVal = val;
            topLogId = log['id']?.toString();
            topLoggedAt = log['loggedAt'] as int?;
          }
        }
      }

      if (maxVal != null && topLogId != null) {
        final existing = await txn.query(
          'movement_pr',
          where: 'kind = ? AND prType = ?',
          whereArgs: [kindCode, prType],
        );
        if (existing.isEmpty) {
          await txn.insert('movement_pr', {
            'id': RitmoIdFactory.movementPr(),
            'kind': kindCode,
            'prType': prType,
            'value': maxVal,
            'logId': topLogId,
            'achievedAt': topLoggedAt ?? DateTime.now().millisecondsSinceEpoch,
          });
        } else {
          await txn.update(
            'movement_pr',
            {
              'value': maxVal,
              'logId': topLogId,
              'achievedAt':
                  topLoggedAt ?? DateTime.now().millisecondsSinceEpoch,
            },
            where: 'kind = ? AND prType = ?',
            whereArgs: [kindCode, prType],
          );
        }
      } else {
        await txn.delete(
          'movement_pr',
          where: 'kind = ? AND prType = ?',
          whereArgs: [kindCode, prType],
        );
      }
    }
  }

  /// Fetch events in the half-open range [startMs, endMsExclusive).
  /// Prefer this over eventsBetween for any period math.
  Future<List<MovementEvent>> eventsInRangeMs(
    int startMs,
    int endMsExclusive,
  ) async {
    final db = await _db;
    final rows = await db.query(
      'workout_logs',
      where: 'loggedAt >= ? AND loggedAt < ?',
      whereArgs: [startMs, endMsExclusive],
      orderBy: 'loggedAt DESC',
    );
    return rows.map((r) => MovementEvent.fromMap(r)).toList();
  }

  /// Fetch events logged between two dates (inclusive).
  Future<List<MovementEvent>> eventsBetween(DateTime from, DateTime to) async {
    final db = await _db;
    final startMs = DateTime(
      from.year,
      from.month,
      from.day,
    ).millisecondsSinceEpoch;
    final endMs = DateTime(
      to.year,
      to.month,
      to.day,
      23,
      59,
      59,
      999,
    ).millisecondsSinceEpoch;

    final rows = await db.query(
      'workout_logs',
      where: 'loggedAt >= ? AND loggedAt <= ?',
      whereArgs: [startMs, endMs],
      orderBy: 'loggedAt DESC',
    );

    return rows.map((r) => MovementEvent.fromMap(r)).toList();
  }

  /// Fetch events of a specific kind.
  Future<List<MovementEvent>> eventsOfKind(
    String kindCode, {
    int limit = 30,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'workout_logs',
      where: 'kind = ? OR type = ?',
      whereArgs: [kindCode, kindCode],
      orderBy: 'loggedAt DESC',
      limit: limit,
    );

    return rows.map((r) => MovementEvent.fromMap(r)).toList();
  }

  /// Check for new Personal Records (PR) and insert/update movement_pr table.
  Future<PRCheckResult> _checkAndRecordPrs(
    DatabaseExecutor txn,
    MovementEvent event,
    MovementKind? kind,
  ) async {
    if (kind == null) return const PRCheckResult(isNewPr: false);

    bool isPr = false;
    String? topPrType;
    double? prValue;
    double? prevValue;

    Future<void> evaluatePr(String prType, double newValue) async {
      if (newValue <= 0) return;

      final existing = await txn.query(
        'movement_pr',
        where: 'kind = ? AND prType = ?',
        whereArgs: [event.kindCode, prType],
        limit: 1,
      );

      if (existing.isEmpty) {
        isPr = true;
        topPrType = prType;
        prValue = newValue;
        prevValue = 0.0;

        await txn.insert('movement_pr', {
          'id': RitmoIdFactory.movementPr(),
          'kind': event.kindCode,
          'prType': prType,
          'value': newValue,
          'logId': event.id,
          'achievedAt': event.loggedAt,
        });
      } else {
        final currentMax = (existing.first['value'] as num).toDouble();
        if (newValue > currentMax) {
          isPr = true;
          topPrType = prType;
          prValue = newValue;
          prevValue = currentMax;

          await txn.update(
            'movement_pr',
            {
              'value': newValue,
              'logId': event.id,
              'achievedAt': event.loggedAt,
            },
            where: 'kind = ? AND prType = ?',
            whereArgs: [event.kindCode, prType],
          );
        }
      }
    }

    if (event.distanceMeters != null && event.distanceMeters! > 0) {
      await evaluatePr('MAX_DISTANCE', event.distanceMeters! / 1000.0);
    }
    if (event.durationMinutes > 0) {
      await evaluatePr('MAX_DURATION', event.durationMinutes.toDouble());
    }
    if (event.elevationMeters != null && event.elevationMeters! > 0) {
      await evaluatePr('MAX_ELEVATION', event.elevationMeters!);
    }
    if (event.laps != null && event.laps! > 0) {
      await evaluatePr('MAX_LAPS', event.laps!.toDouble());
    }

    return PRCheckResult(
      isNewPr: isPr,
      prType: topPrType,
      value: prValue,
      previousValue: prevValue,
    );
  }
}
