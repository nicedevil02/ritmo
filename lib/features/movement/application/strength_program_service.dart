import 'dart:async';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/schema/tables/movement_tables.dart';
import 'package:ritmo/features/movement/domain/models/movement_strength_program.dart';
import 'package:sqflite/sqflite.dart';

/// سرویس مدیریت برنامه‌های قدرتی در لایهٔ Application
class StrengthProgramService {
  StrengthProgramService({this.db});

  final Database? db;

  Future<Database> get _database async =>
      db ?? await DatabaseHelper.instance.database;

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

  Future<void> saveProgram(MovementStrengthProgram program) async {
    final dbExec = await _database;
    await dbExec.insert(
      MovementTables.tableStrengthPrograms,
      program.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
