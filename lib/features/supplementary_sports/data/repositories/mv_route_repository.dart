import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:sqflite/sqflite.dart';

/// Single Source of Truth Repository for Recurring Trails & Routes (`mv_routes` / S4-T7).
class MvRouteRepository {
  final DatabaseExecutor? _customDb;

  MvRouteRepository([this._customDb]);

  Future<DatabaseExecutor> get _db async {
    final custom = _customDb;
    if (custom != null) return custom;
    return DatabaseHelper.instance.database;
  }

  /// Retrieves all routes matching a given sport/movement kind code.
  Future<List<MvRoute>> getRoutesForKind(String kindCode) async {
    final db = await _db;
    final rows = await db.query(
      'mv_routes',
      where: 'kindCode = ?',
      whereArgs: [kindCode],
      orderBy: 'timesCompleted DESC, id DESC',
    );
    return rows.map((r) => MvRoute.fromMap(r)).toList();
  }

  /// Retrieves all saved routes across all movement kinds.
  Future<List<MvRoute>> getAllRoutes() async {
    final db = await _db;
    final rows = await db.query(
      'mv_routes',
      orderBy: 'kindCode ASC, timesCompleted DESC',
    );
    return rows.map((r) => MvRoute.fromMap(r)).toList();
  }

  /// Retrieves a specific route by its integer primary key ID.
  Future<MvRoute?> getRouteById(int id) async {
    final db = await _db;
    final rows = await db.query(
      'mv_routes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MvRoute.fromMap(rows.first);
  }

  /// Inserts a new recurring route and returns its generated integer ID.
  Future<int> insertRoute(MvRoute route) async {
    final db = await _db;
    return await db.insert(
      'mv_routes',
      route.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Updates an existing route.
  Future<void> updateRoute(MvRoute route) async {
    if (route.id == null) return;
    final db = await _db;
    await db.update(
      'mv_routes',
      route.toMap(),
      where: 'id = ?',
      whereArgs: [route.id],
    );
  }

  /// Records a completed session on a route, updating completion count, PR duration, and timestamp.
  Future<void> recordRouteCompletion({
    required int routeId,
    required int durationMin,
    required DateTime completedAt,
  }) async {
    final route = await getRouteById(routeId);
    if (route == null) return;

    final newTimes = route.timesCompleted + 1;
    final newBest =
        (route.bestDurationMin == null || durationMin < route.bestDurationMin!)
        ? durationMin
        : route.bestDurationMin;

    final updated = route.copyWith(
      timesCompleted: newTimes,
      bestDurationMin: newBest,
      lastDoneAt: completedAt.toIso8601String(),
    );

    await updateRoute(updated);
  }

  /// Deletes a route by ID.
  Future<void> deleteRoute(int id) async {
    final db = await _db;
    await db.delete('mv_routes', where: 'id = ?', whereArgs: [id]);
  }
}
