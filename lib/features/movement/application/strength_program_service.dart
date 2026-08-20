import 'dart:async';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/schema/tables/movement_tables.dart';
import 'package:ritmo/features/movement/domain/models/movement_change_scope.dart';
import 'package:ritmo/features/movement/domain/models/movement_set_log.dart';
import 'package:ritmo/features/movement/domain/models/movement_strength_program.dart';
import 'package:sqflite/sqflite.dart';

/// سرویس مدیریت برنامه‌های تمرین قدرتی (Tier 3 — زیر ۱۵۰ خط)
class StrengthProgramService {
  StrengthProgramService({this.db});

  final Database? db;

  Future<Database> get _database async =>
      db ?? await DatabaseHelper.instance.database;

  /// دریافت برنامهٔ جاری
  Future<MovementStrengthProgram?> getCurrentProgram() async {
    final dbExec = await _database;
    final rows = await dbExec.query(
      MovementTables.tableStrengthPrograms,
      where: 'status != ?',
      whereArgs: [MovementStrengthProgramStatus.none.name],
      orderBy: 'updatedAt DESC',
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return MovementStrengthProgram.fromMap(rows.first);
  }

  /// ثبت لاگ ست تمرینی در دیتابیس
  Future<void> recordSetLog(MovementSetLog log) async {
    final dbExec = await _database;
    await dbExec.insert(
      MovementTables.tableSetLogs,
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// دریافت لاگ‌های ست‌های جلسهٔ قبل برای نمایش راهنما/پیشنهاد وزنه
  Future<List<MovementSetLog>> getPreviousSessionSetLogs(
    String exerciseNameFa,
  ) async {
    final dbExec = await _database;
    final rows = await dbExec.rawQuery('''
      SELECT s.* FROM ${MovementTables.tableSetLogs} s
      INNER JOIN ${MovementTables.tableStrengthExercises} e ON s.exerciseId = e.id
      WHERE e.nameFa = ?
      ORDER BY s.at DESC
      LIMIT 10
    ''', [exerciseNameFa]);

    return rows.map((r) => MovementSetLog.fromMap(r)).toList();
  }

  /// تعویض حرکت در برنامه یا فقط برای جلسهٔ جاری
  Future<void> swapExercise({
    required String exerciseId,
    required String newExerciseNameFa,
    required String newMuscleGroup,
    MovementChangeScope scope = MovementChangeScope.onlyThis,
    String? dayId,
    String? programId,
  }) async {
    final dbExec = await _database;
    await dbExec.update(
      MovementTables.tableStrengthExercises,
      {
        'nameFa': newExerciseNameFa,
        'muscleGroup': newMuscleGroup,
      },
      where: 'id = ?',
      whereArgs: [exerciseId],
    );
  }
}
