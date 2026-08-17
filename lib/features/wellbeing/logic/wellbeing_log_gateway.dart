import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/util/ritmo_date.dart';
import 'package:ritmo/core/utils/ritmo_id_factory.dart';
import 'package:ritmo/features/energy/models/energy_mood_models.dart';
import 'package:sqflite/sqflite.dart';

class WellbeingLogGateway {
  WellbeingLogGateway._();
  static final WellbeingLogGateway instance = WellbeingLogGateway._();

  /// Logs energy level, creates entry in energy_logs and dual-writes to wellbeing_entry (B15)
  Future<String?> logEnergy({
    required EnergyLevel level,
    String source = 'wellbeing_screen',
    DateTime? now,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final effectiveNow = now ?? DateTime.now();
      final nowMs = effectiveNow.millisecondsSinceEpoch;
      final id = RitmoIdFactory.uuid();
      final dateStr = RitmoDate.dayKey(effectiveNow);

      final row = <String, Object?>{
        'id': id,
        'level': level.index,
        'energyLevel': level.name,
        'source': source,
        'loggedAt': nowMs,
        'createdAt': nowMs,
      };

      await db.insert('energy_logs', row, conflictAlgorithm: ConflictAlgorithm.replace);

      // Dual-write to wellbeing_entry (B15)
      // TODO(DB_TECH_DEBT): Dual-write until legacy tables are deprecated. Reference: docs/DB_TECH_DEBT.md
      try {
        await db.insert(
          'wellbeing_entry',
          {
            'id': id,
            'date': dateStr,
            'dimension': 'ENERGY',
            'value': level == EnergyLevel.high ? 3.0 : (level == EnergyLevel.low ? 1.0 : 2.0),
            'source': source,
            'createdAt': nowMs,
            'updatedAt': nowMs,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (_) {}

      RitmoEventBus().publish(RitmoEvent(
        type: RitmoEventType.energyLogged.code,
        data: {'id': id, 'level': level.name, 'loggedAt': nowMs},
      ));

      return id;
    } catch (e, st) {
      RitmoLog.error('WellbeingLogGateway', 'logEnergy failed', e, st);
      return null;
    }
  }

  /// Logs mood entry, editing recent log within 10 minutes if available (B10)
  Future<String?> logMood({
    required int score, // 1..5
    String? note,
    String source = 'QUICK_BAR',
    DateTime? now,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final effectiveNow = now ?? DateTime.now();
      final nowMs = effectiveNow.millisecondsSinceEpoch;
      final dateStr = RitmoDate.dayKey(effectiveNow);

      // Check if a mood was logged within last 10 minutes from quick bar (B10)
      final tenMinutesAgo = nowMs - (10 * 60 * 1000);
      final recentLogs = await db.query(
        'mood_logs',
        where: 'source = ? AND loggedAt >= ?',
        whereArgs: [source, tenMinutesAgo],
        orderBy: 'loggedAt DESC',
        limit: 1,
      );

      String id;
      if (recentLogs.isNotEmpty && source == 'QUICK_BAR') {
        id = recentLogs.first['id'] as String;
        await db.update(
          'mood_logs',
          {
            'mood': score >= 4 ? 'HAPPY' : (score <= 2 ? 'SAD' : 'NEUTRAL'),
            'valence': score,
            'note': ?note,
            'loggedAt': nowMs,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      } else {
        id = RitmoIdFactory.uuid();
        final row = <String, Object?>{
          'id': id,
          'mood': score >= 4 ? 'HAPPY' : (score <= 2 ? 'SAD' : 'NEUTRAL'),
          'valence': score,
          'note': note,
          'source': source,
          'loggedAt': nowMs,
        };
        await db.insert('mood_logs', row, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Dual-write to wellbeing_entry (B15)
      // TODO(DB_TECH_DEBT): Dual-write until legacy tables are deprecated. Reference: docs/DB_TECH_DEBT.md
      try {
        await db.insert(
          'wellbeing_entry',
          {
            'id': id,
            'date': dateStr,
            'dimension': 'MOOD',
            'value': score.toDouble(),
            'note': note,
            'source': source,
            'createdAt': nowMs,
            'updatedAt': nowMs,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (_) {}

      RitmoEventBus().publish(RitmoEvent(
        type: RitmoEventType.moodLogged.code,
        data: {'id': id, 'score': score, 'loggedAt': nowMs},
      ));

      return id;
    } catch (e, st) {
      RitmoLog.error('WellbeingLogGateway', 'logMood failed', e, st);
      return null;
    }
  }

  /// Deletes mood log by id
  Future<bool> deleteMood(String id) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('mood_logs', where: 'id = ?', whereArgs: [id]);
      try {
        await db.delete('wellbeing_entry', where: 'id = ?', whereArgs: [id]);
      } catch (_) {}
      RitmoEventBus().publish(RitmoEvent(
        type: RitmoEventType.moodLogged.code,
        data: {'id': id, 'deleted': true},
      ));
      return true;
    } catch (e, st) {
      RitmoLog.error('WellbeingLogGateway', 'deleteMood failed', e, st);
      return false;
    }
  }

  /// Saves reflection for a given day (defaults to today)
  Future<String?> saveReflection({
    required String goodThing,
    int? moodScore,
    String? note,
    bool appendIfExists = true,
    DateTime? now,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final effectiveNow = now ?? DateTime.now();
      final nowMs = effectiveNow.millisecondsSinceEpoch;
      final dateStr = RitmoDate.dayKey(effectiveNow);

      final existing = await db.query('daily_reflections', where: 'date = ?', whereArgs: [dateStr], limit: 1);

      String id;
      String finalText = goodThing;
      if (existing.isNotEmpty) {
        id = existing.first['id']?.toString() ?? 'refl_$nowMs';
        final oldText = existing.first['goodThing']?.toString() ?? existing.first['wins']?.toString() ?? '';
        if (appendIfExists && oldText.isNotEmpty && !oldText.contains(goodThing)) {
          finalText = '$oldText\n$goodThing';
        }
        await db.update(
          'daily_reflections',
          {
            'goodThing': finalText,
            'wins': finalText,
            'mood_score': ?moodScore,
            'reflection_text': ?note,
            'updatedAt': nowMs,
          },
          where: 'date = ?',
          whereArgs: [dateStr],
        );
      } else {
        id = 'refl_$nowMs';
        await db.insert('daily_reflections', {
          'id': id,
          'date': dateStr,
          'goodThing': finalText,
          'wins': finalText,
          'mood_score': ?moodScore,
          'reflection_text': ?note,
          'createdAt': nowMs,
          'updatedAt': nowMs,
        });
      }

      // Dual-write to wellbeing_entry (B15)
      // TODO(DB_TECH_DEBT): Dual-write until legacy tables are deprecated. Reference: docs/DB_TECH_DEBT.md
      try {
        await db.insert(
          'wellbeing_entry',
          {
            'id': id,
            'date': dateStr,
            'dimension': 'REFLECTION',
            'value': (moodScore ?? 3).toDouble(),
            'note': finalText,
            'source': 'wellbeing_screen',
            'createdAt': nowMs,
            'updatedAt': nowMs,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (_) {}

      RitmoEventBus().publish(RitmoEvent(
        type: RitmoEventType.reflectionSaved.code,
        data: {'id': id, 'date': dateStr, 'loggedAt': nowMs},
      ));

      return id;
    } catch (e, st) {
      RitmoLog.error('WellbeingLogGateway', 'saveReflection failed', e, st);
      return null;
    }
  }

  /// Deletes a reflection entry and returns the deleted row for undo
  Future<Map<String, dynamic>?> deleteReflection(String dateOrId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final existing = await db.query(
        'daily_reflections',
        where: 'id = ? OR date = ?',
        whereArgs: [dateOrId, dateOrId],
        limit: 1,
      );
      if (existing.isEmpty) return null;

      final row = Map<String, dynamic>.from(existing.first);
      await db.delete('daily_reflections', where: 'id = ? OR date = ?', whereArgs: [dateOrId, dateOrId]);
      try {
        await db.delete('wellbeing_entry', where: 'id = ? OR date = ?', whereArgs: [dateOrId, dateOrId]);
      } catch (_) {}

      RitmoEventBus().publish(RitmoEvent(
        type: RitmoEventType.reflectionSaved.code,
        data: {'id': row['id'], 'deleted': true},
      ));

      return row;
    } catch (e, st) {
      RitmoLog.error('WellbeingLogGateway', 'deleteReflection failed', e, st);
      return null;
    }
  }

  /// Restores a deleted reflection (Undo)
  Future<bool> restoreReflection(Map<String, dynamic> row) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert('daily_reflections', row, conflictAlgorithm: ConflictAlgorithm.replace);
      try {
        await db.insert('wellbeing_entry', {
          'id': row['id'],
          'date': row['date'],
          'dimension': 'REFLECTION',
          'value': (row['mood_score'] ?? 3).toDouble(),
          'note': row['goodThing'] ?? row['wins'] ?? row['reflection_text'],
          'source': 'wellbeing_undo',
          'createdAt': row['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } catch (_) {}

      RitmoEventBus().publish(RitmoEvent(
        type: RitmoEventType.reflectionSaved.code,
        data: {'id': row['id'], 'restored': true},
      ));
      return true;
    } catch (e, st) {
      RitmoLog.error('WellbeingLogGateway', 'restoreReflection failed', e, st);
      return false;
    }
  }
}
