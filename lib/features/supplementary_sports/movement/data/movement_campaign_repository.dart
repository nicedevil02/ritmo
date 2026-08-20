// lib/features/supplementary_sports/movement/data/movement_campaign_repository.dart

import 'dart:convert';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/schema/tables/supplementary_sports_tables.dart';
import 'package:ritmo/core/domain/engines/ritmo_execution_kernel.dart';
import 'package:ritmo/core/utils/ritmo_id_factory.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_campaign.dart';
import 'package:sqflite/sqflite.dart';

class MovementCampaignRepository {
  MovementCampaignRepository._();
  static final instance = MovementCampaignRepository._();

  bool _tablesEnsured = false;

  Future<Database> get _db async {
    final db = await DatabaseHelper.instance.database;
    if (!_tablesEnsured) {
      await SupplementarySportsTables.ensureLiveMovementSessionTables(db);
      _tablesEnsured = true;
    }
    return db;
  }

  Future<MovementCampaign> createCampaign({
    required String goalCode,
    required String titleFa,
    required DateTime startDate,
    required int weeks,
  }) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final startDateStr = '${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';

    final campaignId = RitmoIdFactory.routine(); // or custom factory ID
    final routineIds = <String>[];

    // Create template routines based on goalCode
    if (goalCode == 'DAMAVAND_6W') {
      // 1. Friday Hiking (weekday 7)
      final hikeId = RitmoIdFactory.routine();
      routineIds.add(hikeId);
      await RitmoExecutionKernel.instance.execute(CreateRoutineCommand(
        routineData: {
          'id': hikeId,
          'title': 'دماوند - کوهنوردی جمعه',
          'category': 'fitness',
          'routineType': 'ROUTINE',
          'targetDurationMinutes': 180,
          'movementKind': 'HIKING',
          'movementTargetMetric': 'ELEVATION',
          'movementTargetValue': 600.0, // starts at 600m
          'isArchived': 0,
          'createdAt': now,
          'updatedAt': now,
        },
        scheduleData: {
          'id': RitmoIdFactory.schedule(hikeId),
          'routineId': hikeId,
          'scheduleType': 'SPECIFIC_DAYS',
          'daysOfWeek': '7', // Friday
          'timeOfDay': '06:00',
          'recurrenceRule': jsonEncode({
            'reminderTimes': ['06:00'],
            'startDate': startDateStr,
            'weekdays': [7]
          }),
          'createdAt': now,
          'updatedAt': now,
        },
      ));

      // 2. Leg Strength 1 (Monday, weekday 3)
      final str1Id = RitmoIdFactory.routine();
      routineIds.add(str1Id);
      await RitmoExecutionKernel.instance.execute(CreateRoutineCommand(
        routineData: {
          'id': str1Id,
          'title': 'دماوند - قدرت پا دوشنبه',
          'category': 'fitness',
          'routineType': 'ROUTINE',
          'targetDurationMinutes': 45,
          'movementKind': 'STRENGTH_HOME',
          'movementTargetMetric': 'DURATION',
          'movementTargetValue': 45.0,
          'isArchived': 0,
          'createdAt': now,
          'updatedAt': now,
        },
        scheduleData: {
          'id': RitmoIdFactory.schedule(str1Id),
          'routineId': str1Id,
          'scheduleType': 'SPECIFIC_DAYS',
          'daysOfWeek': '3', // Monday
          'timeOfDay': '08:00',
          'recurrenceRule': jsonEncode({
            'reminderTimes': ['08:00'],
            'startDate': startDateStr,
            'weekdays': [3]
          }),
          'createdAt': now,
          'updatedAt': now,
        },
      ));

      // 3. Leg Strength 2 (Wednesday, weekday 5)
      final str2Id = RitmoIdFactory.routine();
      routineIds.add(str2Id);
      await RitmoExecutionKernel.instance.execute(CreateRoutineCommand(
        routineData: {
          'id': str2Id,
          'title': 'دماوند - قدرت پا چهارشنبه',
          'category': 'fitness',
          'routineType': 'ROUTINE',
          'targetDurationMinutes': 45,
          'movementKind': 'STRENGTH_HOME',
          'movementTargetMetric': 'DURATION',
          'movementTargetValue': 45.0,
          'isArchived': 0,
          'createdAt': now,
          'updatedAt': now,
        },
        scheduleData: {
          'id': RitmoIdFactory.schedule(str2Id),
          'routineId': str2Id,
          'scheduleType': 'SPECIFIC_DAYS',
          'daysOfWeek': '5', // Wednesday
          'timeOfDay': '08:00',
          'recurrenceRule': jsonEncode({
            'reminderTimes': ['08:00'],
            'startDate': startDateStr,
            'weekdays': [5]
          }),
          'createdAt': now,
          'updatedAt': now,
        },
      ));

      // 4. Stair Climbing (Saturday, weekday 1)
      final stairId = RitmoIdFactory.routine();
      routineIds.add(stairId);
      await RitmoExecutionKernel.instance.execute(CreateRoutineCommand(
        routineData: {
          'id': stairId,
          'title': 'دماوند - پله‌نوردی شنبه',
          'category': 'fitness',
          'routineType': 'ROUTINE',
          'targetDurationMinutes': 30,
          'movementKind': 'STAIR_CLIMBING',
          'movementTargetMetric': 'DURATION',
          'movementTargetValue': 30.0,
          'isArchived': 0,
          'createdAt': now,
          'updatedAt': now,
        },
        scheduleData: {
          'id': RitmoIdFactory.schedule(stairId),
          'routineId': stairId,
          'scheduleType': 'SPECIFIC_DAYS',
          'daysOfWeek': '1', // Saturday
          'timeOfDay': '07:00',
          'recurrenceRule': jsonEncode({
            'reminderTimes': ['07:00'],
            'startDate': startDateStr,
            'weekdays': [1]
          }),
          'createdAt': now,
          'updatedAt': now,
        },
      ));
    }

    final campaign = MovementCampaign(
      id: campaignId,
      titleFa: titleFa,
      goalCode: goalCode,
      startDate: startDateStr,
      weeks: weeks,
      status: MovementCampaignStatus.active,
      routineIds: routineIds,
      progressJson: jsonEncode({'currentWeek': 1, 'weeklyLoad': []}),
    );

    await db.insert('movement_campaigns', campaign.toMap());
    return campaign;
  }

  Future<MovementCampaign?> getActiveCampaign() async {
    final db = await _db;
    final rows = await db.query(
      'movement_campaigns',
      where: 'status = ?',
      whereArgs: [MovementCampaignStatus.active.code],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MovementCampaign.fromMap(rows.first);
  }

  Future<MovementCampaign?> getCampaignById(String id) async {
    final db = await _db;
    final rows = await db.query(
      'movement_campaigns',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MovementCampaign.fromMap(rows.first);
  }

  Future<void> cancelCampaign(String id) async {
    final db = await _db;
    final campaign = await getCampaignById(id);
    if (campaign == null) return;

    await db.update(
      'movement_campaigns',
      {
        'status': MovementCampaignStatus.cancelled.code,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    // Archive all routines
    for (final rId in campaign.routineIds) {
      await db.update(
        'routines',
        {
          'isArchived': 1,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [rId],
      );
    }
  }

  Future<void> checkAndUpdateCampaignWeek(String campaignId) async {
    final campaign = await getCampaignById(campaignId);
    if (campaign == null || campaign.status != MovementCampaignStatus.active) return;

    final start = DateTime.parse(campaign.startDate);
    final daysDiff = DateTime.now().difference(start).inDays;
    final currentWeek = (daysDiff / 7).floor() + 1;

    final progress = jsonDecode(campaign.progressJson ?? '{}') as Map<String, dynamic>;
    final lastWeek = progress['currentWeek'] as int? ?? 1;

    if (currentWeek > lastWeek && currentWeek <= campaign.weeks) {
      final db = await _db;

      for (final rId in campaign.routineIds) {
        final rRows = await db.query('routines', where: 'id = ?', whereArgs: [rId], limit: 1);
        if (rRows.isNotEmpty) {
          final r = rRows.first;
          final double currentTargetValue = (r['movementTargetValue'] as num? ?? 0).toDouble();
          
          // Apply maximum 10% progression using static helper multiplier
          final suggested = currentTargetValue * 1.10;

          await db.update(
            'routines',
            {
              'movementTargetValue': suggested,
              'updatedAt': DateTime.now().millisecondsSinceEpoch,
            },
            where: 'id = ?',
            whereArgs: [rId],
          );
        }
      }

      progress['currentWeek'] = currentWeek;
      await db.update(
        'movement_campaigns',
        {
          'progressJson': jsonEncode(progress),
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [campaignId],
      );
    }
  }
}
