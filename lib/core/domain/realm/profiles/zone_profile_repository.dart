import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/realm/profiles/zone_profile.dart';
import 'package:sqflite/sqflite.dart';

/// Authoritative repository for zone schedule profiles (F-13).
class ZoneProfileRepository {
  ZoneProfileRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _dbHelper;

  /// Loads all zone profiles.
  Future<List<ZoneProfile>> loadProfiles({
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _dbHelper.database;
    final rows = await db.query(
      'zone_profiles',
      orderBy: 'createdAt ASC',
    );
    return rows.map(ZoneProfile.fromMap).toList();
  }

  /// Gets the currently active profile (or null if default global).
  Future<ZoneProfile?> getActiveProfile({
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _dbHelper.database;
    final rows = await db.query(
      'zone_profiles',
      where: 'isActive = 1',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ZoneProfile.fromMap(rows.first);
  }

  /// Creates a new profile.
  Future<ZoneProfile> createProfile(
    String name, {
    bool isActive = false,
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _dbHelper.database;
    final id = 'profile_${DateTime.now().millisecondsSinceEpoch}';
    final profile = ZoneProfile(
      id: id,
      name: name,
      isActive: isActive,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    if (isActive) {
      await db.update('zone_profiles', {'isActive': 0});
    }

    await db.insert('zone_profiles', profile.toMap());
    return profile;
  }

  /// Activates a single profile and deactivates all others.
  Future<void> setActiveProfile(
    String profileId, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _dbHelper.database;
    if (db is Database) {
      await db.transaction((txn) async {
        await txn.update('zone_profiles', {'isActive': 0});
        await txn.update(
          'zone_profiles',
          {'isActive': 1},
          where: 'id = ?',
          whereArgs: [profileId],
        );
      });
    } else {
      await db.update('zone_profiles', {'isActive': 0});
      await db.update(
        'zone_profiles',
        {'isActive': 1},
        where: 'id = ?',
        whereArgs: [profileId],
      );
    }
  }

  /// Deletes a profile.
  Future<void> deleteProfile(
    String profileId, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _dbHelper.database;
    await db.delete(
      'zone_profiles',
      where: 'id = ?',
      whereArgs: [profileId],
    );
  }
}
