import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:sqflite/sqflite.dart';

/// Single Source of Truth Repository for Daily Prescriptions and Slots (`ss_session_prescription`).
class MvPrescriptionRepository {
  final DatabaseExecutor? _customDb;

  MvPrescriptionRepository([this._customDb]);

  Future<DatabaseExecutor> get _db async {
    final custom = _customDb;
    if (custom != null) return custom;
    return DatabaseHelper.instance.database;
  }

  /// Retrieves the prescription for a specific date (`YYYY-MM-DD`).
  Future<MvSlot?> getPrescriptionForDate(String dateIso) async {
    final db = await _db;
    final rows = await db.query(
      'ss_session_prescription',
      where: 'dateIso = ?',
      whereArgs: [dateIso],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MvSlot.fromMap(rows.first);
  }

  /// Retrieves all prescriptions for a given list of date strings (e.g. 7 days of a week).
  Future<List<MvSlot>> getPrescriptionsForDates(List<String> dateIsos) async {
    if (dateIsos.isEmpty) return [];
    final db = await _db;
    final placeholders = List.filled(dateIsos.length, '?').join(',');
    final rows = await db.query(
      'ss_session_prescription',
      where: 'dateIso IN ($placeholders)',
      whereArgs: dateIsos,
      orderBy: 'dateIso ASC',
    );
    return rows.map((r) => MvSlot.fromMap(r)).toList();
  }

  /// Retrieves 7 daily slots for the week starting at [weekStartIso].
  Future<List<MvSlot>> getWeekSlots(String weekStartIso) async {
    final startDt = MvCalendar.parseDateIso(weekStartIso);
    final weekDays = MvCalendar.getWeekDays(startDt);
    final dateIsos = weekDays.map((d) => MvCalendar.formatDateIso(d)).toList();
    return getPrescriptionsForDates(dateIsos);
  }

  /// Saves or updates a single prescription slot.
  Future<void> savePrescription(MvSlot slot) async {
    final db = await _db;
    await db.insert(
      'ss_session_prescription',
      slot.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Batch saves multiple prescription slots.
  Future<void> savePrescriptions(List<MvSlot> slots) async {
    if (slots.isEmpty) return;
    final db = await _db;
    if (db is Database) {
      final batch = db.batch();
      for (final slot in slots) {
        batch.insert(
          'ss_session_prescription',
          slot.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } else {
      for (final slot in slots) {
        await savePrescription(slot);
      }
    }
  }

  /// Updates slot status and execution results.
  Future<void> updateSlotStatus(
    String slotId,
    MvSlotStatus status, {
    int? actualRpe,
    String? workoutLogId,
  }) async {
    final db = await _db;
    final updates = <String, dynamic>{
      'status': status.code,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    if (actualRpe != null) updates['actualRpe'] = actualRpe;
    if (workoutLogId != null) updates['workoutLogId'] = workoutLogId;

    await db.update(
      'ss_session_prescription',
      updates,
      where: 'id = ?',
      whereArgs: [slotId],
    );
  }

  /// Moves a slot to a different target date.
  Future<void> moveSlot(String slotId, String newDateIso) async {
    final db = await _db;
    await db.update(
      'ss_session_prescription',
      {
        'status': MvSlotStatus.moved.code,
        'movedToDateIso': newDateIso,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [slotId],
    );
  }
}
