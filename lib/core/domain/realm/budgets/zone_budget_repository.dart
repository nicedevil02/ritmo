import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/realm/budgets/zone_budget.dart';
import 'package:sqflite/sqflite.dart';

/// Authoritative repository for realm presence budgets (F-12).
class ZoneBudgetRepository {
  ZoneBudgetRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _dbHelper;

  /// Loads the budget for a specific zone if one exists.
  Future<ZoneBudget?> loadBudget(
    String zoneId, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _dbHelper.database;
    final rows = await db.query(
      'zone_budgets',
      where: 'zoneId = ?',
      whereArgs: [zoneId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ZoneBudget.fromMap(rows.first);
  }

  /// Loads all zone budgets.
  Future<List<ZoneBudget>> loadAllBudgets({
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _dbHelper.database;
    final rows = await db.query('zone_budgets');
    return rows.map(ZoneBudget.fromMap).toList();
  }

  /// Inserts or replaces a budget.
  Future<void> saveBudget(
    ZoneBudget budget, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _dbHelper.database;
    await db.insert(
      'zone_budgets',
      budget.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Deletes a budget by zoneId.
  Future<void> deleteBudget(
    String zoneId, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _dbHelper.database;
    await db.delete(
      'zone_budgets',
      where: 'zoneId = ?',
      whereArgs: [zoneId],
    );
  }
}
