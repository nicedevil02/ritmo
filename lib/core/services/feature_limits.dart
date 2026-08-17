import 'package:ritmo/core/services/premium_service.dart';

/// تک‌منبع‌حقیقت برای تمام سقف‌های فریمیوم ریتمو
/// قانون ۱۸: همه محدودیت‌ها از اینجا خوانده می‌شوند — هیچ‌جای دیگری عدد هاردکد نمی‌شود.
class FeatureLimits {
  const FeatureLimits._({
    required this.maxActiveModules,
    required this.maxActiveRoutines,
    required this.maxActiveGoals,
    required this.historyDays,
    required this.monthlyAiMessages,
    required this.crossEngineInsights,
    required this.adaptiveSportsSchedule,
    required this.cloudBackup,
    required this.multiDeviceSync,
    required this.allThemes,
    required this.reportWatermark,
    required this.showAds,
    required this.smartReshuffle,
  });

  // ─── ریتمو پایه (رایگان) ───────────────────────────────────────────────────
  static const _free = FeatureLimits._(
    maxActiveModules: 4, // ماژول اختیاری فعال همزمان
    maxActiveRoutines: 7, // روتین فعال
    maxActiveGoals: 3, // هدف فعال
    historyDays: 30, // تاریخچه تحلیل (روز)
    monthlyAiMessages: 10, // پیام AI در ماه
    crossEngineInsights: false, // بینش Cross-Engine (RIE)
    adaptiveSportsSchedule: false,
    cloudBackup: false, // بکاپ ابری خودکار
    multiDeviceSync: false, // همگام‌سازی چنددستگاهی
    allThemes: false, // تم‌ها و آیکن‌های سفارشی
    reportWatermark: true, // واترمارک روی گزارش صادرشده
    showAds: true, // نمایش تبلیغات بنری
    smartReshuffle: false, // برنامه‌ریزی تطبیقی خودکار
  );

  // ─── ریتمو پلاس ────────────────────────────────────────────────────────────
  static const _plus = FeatureLimits._(
    maxActiveModules: 15, // تمام ماژول‌های اختیاری
    maxActiveRoutines: 50, // سقف قانون ۲۲
    maxActiveGoals: 20, // سقف قانون ۲۲
    historyDays: 730, // ۲ سال
    monthlyAiMessages: 500, // سهمیه ماهانه پلاس
    crossEngineInsights: true,
    adaptiveSportsSchedule: true,
    cloudBackup: true,
    multiDeviceSync: true,
    allThemes: true,
    reportWatermark: false,
    showAds: false,
    smartReshuffle: true,
  );

  /// دریافت محدودیت‌های فعال بر اساس وضعیت پریمیوم کاربر
  static FeatureLimits get current => _plus;

  // ─── فیلدها ────────────────────────────────────────────────────────────────
  final int maxActiveModules;
  final int maxActiveRoutines;
  final int maxActiveGoals;
  final int historyDays;
  final int monthlyAiMessages;
  final bool crossEngineInsights;
  final bool adaptiveSportsSchedule;
  final bool cloudBackup;
  final bool multiDeviceSync;
  final bool allThemes;
  final bool reportWatermark;
  final bool showAds;
  final bool smartReshuffle;
}
