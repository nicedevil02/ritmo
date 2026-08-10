import 'package:flutter/foundation.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:sqflite/sqflite.dart';

class GestationalAge {
  const GestationalAge(this.weeks, this.days);
  final int weeks;
  final int days;

  factory GestationalAge.fromDays(int totalDays) {
    final d = totalDays < 0 ? 0 : totalDays;
    return GestationalAge(d ~/ 7, d % 7);
  }

  /// ACOG standard: Trimester 1 = 0+0 to 13+6, Trimester 2 = 14+0 to 27+6, Trimester 3 = 28+0 onwards
  int get trimester => weeks < 14 ? 1 : (weeks < 28 ? 2 : 3);

  String get label => toPersianDigits('هفته $weeks و $days روز');
}

class PregnancyRepository {
  PregnancyRepository._internal();
  static final PregnancyRepository instance = PregnancyRepository._internal();

  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<Map<String, dynamic>?> getActiveTracker() async {
    final db = await _db;
    final trackers = await db.query(
      'pregnancy_tracker',
      where: 'isActive = 1',
      orderBy: 'createdAt DESC',
      limit: 1,
    );
    if (trackers.isEmpty) return null;
    return trackers.first;
  }

  Future<void> deactivateTracker(String trackerId) async {
    final db = await _db;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'pregnancy_tracker',
      {'isActive': 0, 'updatedAt': nowMs},
      where: 'id = ?',
      whereArgs: [trackerId],
    );
  }

  Future<String> startTracker({
    required DateTime lmp,
    DateTime? eddOverride,
    int cycleLen = 28,
  }) async {
    final db = await _db;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final trackerId = 'preg_${lmp.millisecondsSinceEpoch}';
    final lmpStr = lmp.toIso8601String().substring(0, 10);

    // Correct EDD based on user's cycle length (PREG-16)
    final cycleCorrection = (cycleLen - 28).clamp(-14, 14);
    final calculatedEdd = eddOverride ?? lmp.add(Duration(days: 280 + cycleCorrection));
    final eddStr = calculatedEdd.toIso8601String().substring(0, 10);

    await db.transaction((txn) async {
      // Deactivate any existing active tracker (PREG-07)
      final trackerTableInfo = await txn.rawQuery("PRAGMA table_info('pregnancy_tracker')");
      final trackerCols = trackerTableInfo.map((c) => c['name'] as String).toSet();

      final updateMap = <String, dynamic>{
        'isActive': 0,
        'updatedAt': nowMs,
      };
      if (trackerCols.contains('endedAt')) {
        updateMap['endedAt'] = nowMs;
      }

      await txn.update(
        'pregnancy_tracker',
        updateMap,
        where: 'isActive = 1',
      );

      // Create new active tracker
      final ga = GestationalAge.fromDays(DateTime.now().difference(lmp).inDays);
      final trackerRow = <String, dynamic>{
        'id': trackerId,
        'lmpDate': lmpStr,
        'isActive': 1,
        'createdAt': nowMs,
        'updatedAt': nowMs,
      };

      if (trackerCols.contains('estimatedDueDate')) {
        trackerRow['estimatedDueDate'] = eddStr;
      }
      if (trackerCols.contains('expectedDueDate')) {
        trackerRow['expectedDueDate'] = eddStr;
      }
      if (trackerCols.contains('currentWeek')) {
        trackerRow['currentWeek'] = ga.weeks;
      }
      if (trackerCols.contains('currentTrimester')) {
        trackerRow['currentTrimester'] = ga.trimester;
      }
      if (trackerCols.contains('notes')) {
        trackerRow['notes'] = null;
      }

      await txn.insert(
        'pregnancy_tracker',
        trackerRow,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Create 7 standard country checkups in the SAME transaction (PREG-07)
      final checkupTemplates = [
        {'code': 'PREG_CHK_1', 'title': 'مراقبت اول: هفته ۶ تا ۱۰', 'weeksMin': 6, 'weeksMax': 10, 'order': 1},
        {'code': 'PREG_CHK_2', 'title': 'مراقبت دوم: هفته ۱۶ تا ۲۰', 'weeksMin': 16, 'weeksMax': 20, 'order': 2},
        {'code': 'PREG_CHK_3', 'title': 'مراقبت سوم: هفته ۲۴ تا ۳۰', 'weeksMin': 24, 'weeksMax': 30, 'order': 3},
        {'code': 'PREG_CHK_4', 'title': 'مراقبت چهارم: هفته ۳۱ تا ۳۴', 'weeksMin': 31, 'weeksMax': 34, 'order': 4},
        {'code': 'PREG_CHK_5', 'title': 'مراقبت پنجم: هفته ۳۵ تا ۳۷', 'weeksMin': 35, 'weeksMax': 37, 'order': 5},
        {'code': 'PREG_CHK_6', 'title': 'مراقبت ششم: هفته ۳۸', 'weeksMin': 38, 'weeksMax': 38, 'order': 6},
        {'code': 'PREG_CHK_7', 'title': 'مراقبت هفتم: هفته ۳۹ تا ۴۰', 'weeksMin': 39, 'weeksMax': 40, 'order': 7},
      ];

      final checkupTableInfo = await txn.rawQuery("PRAGMA table_info('pregnancy_checkups')");
      final chkCols = checkupTableInfo.map((c) => c['name'] as String).toSet();

      for (final chk in checkupTemplates) {
        final scheduled = lmp.add(Duration(days: (chk['weeksMin'] as int) * 7));
        final chkRow = <String, dynamic>{
          'id': 'chk_${trackerId}_${chk["code"]}',
          'pregnancyId': trackerId,
          'title': chk['title'],
          'scheduledDate': scheduled.millisecondsSinceEpoch,
          'createdAt': nowMs,
        };

        if (chkCols.contains('checkupCode')) chkRow['checkupCode'] = chk['code'];
        if (chkCols.contains('type')) chkRow['type'] = 'ROUTINE';
        if (chkCols.contains('isDone')) chkRow['isDone'] = 0;
        if (chkCols.contains('isCompleted')) chkRow['isCompleted'] = 0;
        if (chkCols.contains('notes')) chkRow['notes'] = 'محدوده: هفته ${chk["weeksMin"]} تا ${chk["weeksMax"]}';
        if (chkCols.contains('updatedAt')) chkRow['updatedAt'] = nowMs;

        await txn.insert(
          'pregnancy_checkups',
          chkRow,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // Sync settings keys (PREG-02)
      await txn.insert(
        'app_settings',
        {'key': 'cycle_pregnancy_mode', 'value': 'true', 'updatedAt': nowMs},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'app_settings',
        {'key': 'cycle_is_pregnant', 'value': 'true', 'updatedAt': nowMs},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'app_settings',
        {'key': 'cycle_pregnancy_start_date', 'value': lmpStr, 'updatedAt': nowMs},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'app_settings',
        {'key': 'cycle_pregnancy_due_date', 'value': eddStr, 'updatedAt': nowMs},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });

    return trackerId;
  }

  Future<void> endTracker(String trackerId, String reason) async {
    final db = await _db;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      final trackerTableInfo = await txn.rawQuery("PRAGMA table_info('pregnancy_tracker')");
      final trackerCols = trackerTableInfo.map((c) => c['name'] as String).toSet();

      final updateMap = <String, dynamic>{
        'isActive': 0,
        'updatedAt': nowMs,
      };
      if (trackerCols.contains('endedAt')) {
        updateMap['endedAt'] = nowMs;
      }

      await txn.update(
        'pregnancy_tracker',
        updateMap,
        where: 'id = ?',
        whereArgs: [trackerId],
      );

      await txn.insert(
        'app_settings',
        {'key': 'cycle_pregnancy_mode', 'value': 'false', 'updatedAt': nowMs},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'app_settings',
        {'key': 'cycle_is_pregnant', 'value': 'false', 'updatedAt': nowMs},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<int> gestationalDays(String lmpDate) async {
    final lmp = DateTime.tryParse(lmpDate);
    if (lmp == null) return 0;
    final diff = DateTime.now().difference(lmp).inDays;
    return diff < 0 ? 0 : diff;
  }
}
