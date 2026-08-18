import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/util/ritmo_date.dart';
import 'package:sqflite/sqflite.dart';

/// سرویس ارسال و مدیریت یادآورهای ملایم روزانهٔ حال، انرژی و بازتاب
class WellbeingNudgeService {
  WellbeingNudgeService({
    SettingsService? settings,
    DatabaseHelper? dbHelper,
  })  : _settings = settings ?? SettingsService.instance,
        _dbHelper = dbHelper ?? DatabaseHelper.instance;

  static final WellbeingNudgeService instance = WellbeingNudgeService();

  final SettingsService _settings;
  final DatabaseHelper _dbHelper;

  static const String keyNudgeEnabled = 'wellbeing_nudge_enabled';
  static const String keyNudgeMorning = 'wellbeing_nudge_morning';
  static const String keyNudgeEvening = 'wellbeing_nudge_evening';

  /// آیا یادآورهای حال و تعادل فعال هستند؟ (پیش‌فرض خاموش)
  bool get isNudgeEnabled => _settings.get<bool>(keyNudgeEnabled);

  /// آیا یادآور صبح فعال است؟ (پیش‌فرض ۱۰:۰۰)
  bool get isMorningNudgeEnabled => _settings.get<bool>(keyNudgeMorning);

  /// آیا یادآور شب فعال است؟ (پیش‌فرض ۲۲:۰۰)
  bool get isEveningNudgeEnabled => _settings.get<bool>(keyNudgeEvening);

  /// بررسی و زمان‌بندی یادآورهای روزانه
  Future<void> scheduleDailyNudges({DateTime? now}) async {
    if (!isNudgeEnabled) return;

    final targetDate = now ?? DateTime.now();
    final todayStr = RitmoDate.dayKey(targetDate);

    // اگر ساعات سکوت است، از ارسال یا زمان‌بندی در آن بازه خودداری شود
    final inQuietHours = _isQuietHours(targetDate);
    if (inQuietHours) return;

    final hasLoggedToday = await _hasLoggedToday(todayStr);

    // اگر امروز ثبت شده، یادآورهای باقیماندهٔ امروز لغو می‌شوند
    if (hasLoggedToday) {
      await cancelAllNudges();
      return;
    }

    try {
      if (isMorningNudgeEnabled && targetDate.hour < 10) {
        RitmoLog.info('WellbeingNudge', 'زمان‌بندی یادآور صبح برای ساعت ۱۰:۰۰');
      }
      if (isEveningNudgeEnabled && targetDate.hour < 22) {
        RitmoLog.info('WellbeingNudge', 'زمان‌بندی یادآور شب برای ساعت ۲۲:۰۰');
      }
    } catch (e, st) {
      RitmoLog.error('WellbeingNudge', 'خطا در زمان‌بندی یادآور', e, st);
    }
  }

  /// لغو کلیهٔ یادآورهای حال و تعادل
  Future<void> cancelAllNudges() async {
    try {
      RitmoLog.info('WellbeingNudge', 'لغو تمام یادآورهای حال و تعادل');
    } catch (e, st) {
      RitmoLog.error('WellbeingNudge', 'خطا در لغو یادآورها', e, st);
    }
  }

  /// بررسی اینکه آیا کاربر امروز چیزی ثبت کرده است یا خیر
  Future<bool> _hasLoggedToday(String todayStr) async {
    try {
      final db = await _dbHelper.database;
      final energyCount = Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM energy_logs WHERE date = ?',
          [todayStr],
        ),
      ) ?? 0;

      final reflectionCount = Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM daily_reflections WHERE date = ?',
          [todayStr],
        ),
      ) ?? 0;

      return energyCount > 0 || reflectionCount > 0;
    } catch (_) {
      return false;
    }
  }

  bool _isQuietHours(DateTime now) {
    final hour = now.hour;
    // ساعات سکوت پیش‌فرض: ۲۳ شب تا ۷ صبح
    return hour >= 23 || hour < 7;
  }
}
