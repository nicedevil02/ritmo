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
      await txn.update(
        'pregnancy_tracker',
        {'isActive': 0, 'updatedAt': nowMs},
        where: 'isActive = 1',
      );

      // Create new active tracker
      await txn.insert(
        'pregnancy_tracker',
        {
          'id': trackerId,
          'lmpDate': lmpStr,
          'expectedDueDate': eddStr,
          'isActive': 1,
          'createdAt': nowMs,
          'updatedAt': nowMs,
        },
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

      for (final chk in checkupTemplates) {
        final scheduled = lmp.add(Duration(days: (chk['weeksMin'] as int) * 7));
        await txn.insert(
          'pregnancy_checkups',
          {
            'id': 'chk_${trackerId}_${chk["code"]}',
            'pregnancyId': trackerId,
            'checkupCode': chk['code'],
            'title': chk['title'],
            'scheduledDate': scheduled.millisecondsSinceEpoch,
            'isDone': 0,
            'notes': 'محدوده: هفته ${chk["weeksMin"]} تا ${chk["weeksMax"]}',
            'createdAt': nowMs,
            'updatedAt': nowMs,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // Sync settings keys (PREG-02)
      await txn.insert(
        'app_settings',
        {'key': 'cycle_pregnancy_mode', 'value': 'true'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'app_settings',
        {'key': 'cycle_is_pregnant', 'value': 'true'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'app_settings',
        {'key': 'cycle_pregnancy_start_date', 'value': lmpStr},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'app_settings',
        {'key': 'cycle_pregnancy_due_date', 'value': eddStr},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });



    return trackerId;
  }

  Future<void> endTracker(String trackerId, String reason) async {
    final db = await _db;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      await txn.update(
        'pregnancy_tracker',
        {'isActive': 0, 'endedAt': nowMs, 'updatedAt': nowMs},
        where: 'id = ?',
        whereArgs: [trackerId],
      );

      await txn.insert(
        'app_settings',
        {'key': 'cycle_pregnancy_mode', 'value': 'false'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'app_settings',
        {'key': 'cycle_is_pregnant', 'value': 'false'},
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
