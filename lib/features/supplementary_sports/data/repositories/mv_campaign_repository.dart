import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:sqflite/sqflite.dart';

/// Single Source of Truth Repository for Goal-Oriented Campaigns (`movement_campaigns` / S5-T1).
class MvCampaignRepository {
  final DatabaseExecutor? _customDb;

  MvCampaignRepository([this._customDb]);

  Future<DatabaseExecutor> get _db async {
    final custom = _customDb;
    if (custom != null) return custom;
    return DatabaseHelper.instance.database;
  }

  /// Retrieves the currently active campaign, if any.
  Future<MvCampaign?> getActive() async {
    final db = await _db;
    final rows = await db.query(
      'movement_campaigns',
      where: 'status = ?',
      whereArgs: ['ACTIVE'],
      orderBy: 'createdAt DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MvCampaign.fromMap(rows.first);
  }

  /// Retrieves a specific campaign by ID.
  Future<MvCampaign?> getById(String id) async {
    final db = await _db;
    final rows = await db.query(
      'movement_campaigns',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MvCampaign.fromMap(rows.first);
  }

  /// Retrieves all campaigns ordered by creation date descending.
  Future<List<MvCampaign>> getAllCampaigns() async {
    final db = await _db;
    final rows = await db.query(
      'movement_campaigns',
      orderBy: 'createdAt DESC',
    );
    return rows.map((r) => MvCampaign.fromMap(r)).toList();
  }

  /// Inserts or updates a goal campaign.
  Future<MvCampaign> upsert(MvCampaign c) async {
    final db = await _db;
    await db.insert(
      'movement_campaigns',
      c.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return c;
  }

  /// Marks a campaign as completed. Supports both String and int identifiers.
  Future<void> complete(dynamic id) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'movement_campaigns',
      {'status': 'COMPLETED', 'updatedAt': now},
      where: 'id = ?',
      whereArgs: [id.toString()],
    );
  }

  /// Archives a campaign.
  Future<void> archive(dynamic id) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'movement_campaigns',
      {'status': 'ARCHIVED', 'updatedAt': now},
      where: 'id = ?',
      whereArgs: [id.toString()],
    );
  }
}
