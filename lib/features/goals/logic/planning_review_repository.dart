import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/upsert_helper.dart';
import 'package:ritmo/features/goals/models/planning_models.dart';
import 'package:sqflite/sqflite.dart';

class PlanningReviewItem {
  const PlanningReviewItem({
    required this.id,
    required this.cycleId,
    required this.reviewType,
    required this.plannedMinutes,
    required this.completedMinutes,
    required this.movedMinutes,
    required this.droppedMinutes,
    required this.unplannedCompletedMinutes,
    this.calibrationScore,
    this.answersJson,
    required this.createdAt,
  });

  final String id;
  final String cycleId;
  final String reviewType; // MID_CYCLE or END_CYCLE
  final int plannedMinutes;
  final int completedMinutes;
  final int movedMinutes;
  final int droppedMinutes;
  final int unplannedCompletedMinutes;
  final double? calibrationScore;
  final String? answersJson;
  final int createdAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'cycleId': cycleId,
        'reviewType': reviewType,
        'plannedMinutes': plannedMinutes,
        'completedMinutes': completedMinutes,
        'movedMinutes': movedMinutes,
        'droppedMinutes': droppedMinutes,
        'unplannedCompletedMinutes': unplannedCompletedMinutes,
        'calibrationScore': calibrationScore,
        'answersJson': answersJson,
        'createdAt': createdAt,
      };

  factory PlanningReviewItem.fromMap(Map<String, Object?> m) => PlanningReviewItem(
        id: m['id'] as String,
        cycleId: m['cycleId'] as String,
        reviewType: m['reviewType'] as String,
        plannedMinutes: (m['plannedMinutes'] as num?)?.toInt() ?? 0,
        completedMinutes: (m['completedMinutes'] as num?)?.toInt() ?? 0,
        movedMinutes: (m['movedMinutes'] as num?)?.toInt() ?? 0,
        droppedMinutes: (m['droppedMinutes'] as num?)?.toInt() ?? 0,
        unplannedCompletedMinutes: (m['unplannedCompletedMinutes'] as num?)?.toInt() ?? 0,
        calibrationScore: (m['calibrationScore'] as num?)?.toDouble(),
        answersJson: m['answersJson'] as String?,
        createdAt: (m['createdAt'] as num).toInt(),
      );
}

class PlanningReviewRepository {
  PlanningReviewRepository._();
  static final PlanningReviewRepository instance = PlanningReviewRepository._();

  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<void> saveReview(PlanningReviewItem review) async {
    final db = await _db;
    await db.transaction((txn) async {
      await UpsertHelper.upsert(
        txn,
        'planning_reviews',
        review.toMap(),
        conflictColumns: const ['id'],
      );
    });
  }

  Future<List<PlanningReviewItem>> reviewsOf(String cycleId) async {
    final db = await _db;
    final res = await db.query(
      'planning_reviews',
      where: 'cycleId = ?',
      whereArgs: [cycleId],
      orderBy: 'createdAt DESC',
    );
    return res.map(PlanningReviewItem.fromMap).toList();
  }

  Future<PlanningReviewItem?> latestFor(PlanningHorizon horizon) async {
    final db = await _db;
    final res = await db.rawQuery('''
      SELECT r.* FROM planning_reviews r
      INNER JOIN planning_cycles c ON r.cycleId = c.id
      WHERE c.horizon = ?
      ORDER BY r.createdAt DESC
      LIMIT 1
    ''', [horizon.name.toUpperCase()]);

    if (res.isEmpty) return null;
    return PlanningReviewItem.fromMap(res.first);
  }
}
