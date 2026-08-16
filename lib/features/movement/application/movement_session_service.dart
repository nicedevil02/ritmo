import 'dart:async';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/schema/tables/movement_tables.dart';
import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';
import 'package:ritmo/features/movement/domain/models/movement_live_session.dart';
import 'package:sqflite/sqflite.dart';

/// سرویس مدیریت جلسات زندهٔ حرکتی در لایهٔ Application
class MovementSessionService {
  MovementSessionService({this.db});

  final Database? db;

  Future<Database> get _database async =>
      db ?? await DatabaseHelper.instance.database;

  Future<MovementLiveSession?> getActiveOrPausedSession() async {
    final dbExec = await _database;
    final rows = await dbExec.query(
      MovementTables.tableLiveSessions,
      where: 'status = ? OR status = ?',
      whereArgs: [
        MovementLiveSessionStatus.active.name,
        MovementLiveSessionStatus.paused.name,
      ],
      orderBy: 'createdAt DESC',
      limit: 1,
    );

    if (rows.isEmpty) return null;

    final row = rows.first;
    final kindId = row['activityKindId'] as String;

    final kindRows = await dbExec.query(
      MovementTables.tableActivityKinds,
      where: 'id = ?',
      whereArgs: [kindId],
      limit: 1,
    );
    final kind = kindRows.isNotEmpty
        ? MovementActivityKind.fromMap(kindRows.first)
        : null;

    return MovementLiveSession.fromMap(row, activityKind: kind);
  }

  Future<void> saveSession(MovementLiveSession session) async {
    final dbExec = await _database;
    await dbExec.insert(
      MovementTables.tableLiveSessions,
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> completeSession(String sessionId) async {
    final dbExec = await _database;
    await dbExec.update(
      MovementTables.tableLiveSessions,
      {
        'status': MovementLiveSessionStatus.completed.name,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> abandonSession(String sessionId) async {
    final dbExec = await _database;
    await dbExec.update(
      MovementTables.tableLiveSessions,
      {
        'status': MovementLiveSessionStatus.abandoned.name,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }
}
