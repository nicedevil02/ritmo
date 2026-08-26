import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/upsert_helper.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:sqflite/sqflite.dart';

/// Single Source of Truth Repository for User Sports Profile (`ss_user_profile`).
class MvProfileRepository {
  final DatabaseExecutor? _customDb;

  MvProfileRepository([this._customDb]);

  Future<DatabaseExecutor> get _db async {
    final custom = _customDb;
    if (custom != null) return custom;
    return DatabaseHelper.instance.database;
  }

  /// Retrieves the active profile, returning a sensible default if none exists.
  Future<MvUserProfile> getProfile() async {
    final db = await _db;
    final rows = await db.query(
      'ss_user_profile',
      where: "id = 'default'",
      limit: 1,
    );
    if (rows.isEmpty) {
      return MvUserProfile.empty();
    }
    return MvUserProfile.fromMap(rows.first);
  }

  /// Saves or updates the user profile.
  Future<void> saveProfile(MvUserProfile profile) async {
    final db = await _db;
    final cleanProfile = profile.copyWith(
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await UpsertHelper.upsert(
      db,
      'ss_user_profile',
      cleanProfile.toMap(),
      conflictColumns: const ['id'],
    );
  }
}
