import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:sqflite/sqflite.dart';

/// Single Source of Truth Repository for Exercises (`ss_exercise`, `ss_exercise_similarity`).
class MvExerciseRepository {
  final DatabaseExecutor? _customDb;

  MvExerciseRepository([this._customDb]);

  Future<DatabaseExecutor> get _db async {
    final custom = _customDb;
    if (custom != null) return custom;
    return DatabaseHelper.instance.database;
  }

  /// Retrieves all 268+ available exercises.
  Future<List<MvExercise>> getAllExercises() async {
    final db = await _db;
    final rows = await db.query('ss_exercise', orderBy: 'name ASC');
    return rows.map((r) => MvExercise.fromMap(r)).toList();
  }

  /// Retrieves an exercise by ID.
  Future<MvExercise?> getExerciseById(String id) async {
    final db = await _db;
    final rows = await db.query(
      'ss_exercise',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MvExercise.fromMap(rows.first);
  }

  /// Retrieves similar exercises ordered by similarity score using `ss_exercise_similarity`.
  Future<List<MvExercise>> getSimilarExercises(
    String exerciseId, {
    int limit = 3,
  }) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT e.* FROM ss_exercise e
      INNER JOIN ss_exercise_similarity s ON s.similarExerciseId = e.id
      WHERE s.exerciseId = ?
      ORDER BY s.similarityScore DESC
      LIMIT ?
    ''',
      [exerciseId, limit],
    );
    return rows.map((r) => MvExercise.fromMap(r)).toList();
  }

  /// Retrieves all custom exercises created by user.
  Future<List<MvExercise>> getCustomExercises() async {
    final db = await _db;
    final rows = await db.query(
      'ss_exercise',
      where: 'isCustom = 1',
      orderBy: 'name ASC',
    );
    return rows.map((r) => MvExercise.fromMap(r)).toList();
  }

  /// Saves or updates a custom exercise.
  Future<void> saveCustomExercise(MvExercise exercise) async {
    final db = await _db;
    final customExercise = exercise.toMap();
    customExercise['isCustom'] = 1;
    await db.insert(
      'ss_exercise',
      customExercise,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Deletes a custom exercise.
  Future<void> deleteCustomExercise(String id) async {
    final db = await _db;
    await db.delete(
      'ss_exercise',
      where: 'id = ? AND isCustom = 1',
      whereArgs: [id],
    );
  }
}
