import 'package:flutter/foundation.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/util/ritmo_date.dart';
import 'package:ritmo/features/sleep/data/sleep_program_repository.dart';
import 'package:sqflite/sqflite.dart';

/// ابزار دیباگ برای تولید سریع داده‌های تستی مسیر خواب (T7).
///
/// در حالت دیباگ، ۷ شب لاگ واقعی در `bedtime_diagnostics` می‌کارد تا
/// برنامهٔ خواب بلافاصله از فاز `listening` به فاز `active`/`anchoring` منتقل شود
/// و کارت «پلهٔ امشب» قابل مشاهده و آزمایش باشد.
class SleepProgramDebugHelper {
  const SleepProgramDebugHelper._();

  /// ایجاد ۷ شب لاگ با ساعت خواب حدود ۲۳:۳۰ و بیداری ۰۷:۰۰
  static Future<void> seedSevenNights({DatabaseExecutor? dbExecutor}) async {
    if (!kDebugMode) return;

    final db = dbExecutor ?? await DatabaseHelper.instance.database;
    final now = DateTime.now();

    for (var i = 7; i >= 1; i--) {
      final dateDt = now.subtract(Duration(days: i));
      final dateKey = RitmoDate.dayKey(dateDt);

      // ساعت خواب: ۲۳:۳۰ شب قبل
      final bedtime = DateTime(dateDt.year, dateDt.month, dateDt.day - 1, 23, 30);
      // ساعت بیداری: ۰۷:۰۰ صبح روز
      final wakeTime = DateTime(dateDt.year, dateDt.month, dateDt.day, 7, 0);
      final durationMin = wakeTime.difference(bedtime).inMinutes;

      await db.insert(
        'bedtime_diagnostics',
        {
          'date': dateKey,
          'reason': 'ثبت خودکار دیباگ',
          'note': 'تولیدشده توسط SleepProgramDebugHelper',
          'createdAt': dateDt.millisecondsSinceEpoch,
          'bedtimeAt': bedtime.millisecondsSinceEpoch,
          'wakeAt': wakeTime.millisecondsSinceEpoch,
          'durationMinutes': durationMin,
          'quality': 4,
          'awakenings': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // بازخوانی وضعیت برای به‌روزرسانی فاز
    final repo = SleepProgramRepository(db);
    await repo.refreshAndLoadState(now: now);
  }
}
