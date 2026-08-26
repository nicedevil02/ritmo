import 'package:sqflite/sqflite.dart';

/// Centralized atomic upsert helper eliminating destructive `ConflictAlgorithm.replace`
/// (which executes DELETE + INSERT, cascades foreign keys, and resets unspecified columns to defaults - P-B).
class UpsertHelper {
  UpsertHelper._();

  /// Performs an atomic SQLite UPSERT (`INSERT INTO ... ON CONFLICT(conflictColumns) DO UPDATE SET ...`).
  /// Unspecified existing columns remain intact.
  static Future<int> upsert(
    DatabaseExecutor db,
    String table,
    Map<String, dynamic> values, {
    List<String> conflictColumns = const ['id'],
  }) async {
    if (values.isEmpty) return 0;

    final columns = values.keys.toList();
    final placeholders = List.filled(columns.length, '?').join(', ');
    final conflictTarget = conflictColumns.join(', ');

    final updateColumns = columns.where((c) => !conflictColumns.contains(c)).toList();

    if (updateColumns.isEmpty) {
      final sql = '''
        INSERT INTO $table (${columns.join(', ')})
        VALUES ($placeholders)
        ON CONFLICT($conflictTarget) DO NOTHING
      ''';
      return await db.rawInsert(sql, values.values.toList());
    }

    final updateClause = updateColumns.map((c) => '$c = excluded.$c').join(', ');
    final sql = '''
      INSERT INTO $table (${columns.join(', ')})
      VALUES ($placeholders)
      ON CONFLICT($conflictTarget) DO UPDATE SET $updateClause
    ''';

    return await db.rawInsert(sql, values.values.toList());
  }
}
