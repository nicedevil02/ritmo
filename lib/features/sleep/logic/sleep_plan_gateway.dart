import 'package:ritmo/core/analytics/sleep_program_engine.dart';
import 'package:ritmo/core/analytics/wellbeing_insight_arbiter.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/features/sleep/data/sleep_program_repository.dart';
import 'package:ritmo/features/sleep/logic/sleep_plan_insights.dart';

/// پل میان لایهٔ دادهٔ برنامهٔ خواب و روایت‌های «حال و تعادل».
///
/// صفحه‌ها نه مخزن را می‌شناسند نه موتور را؛ فقط همین دو تابع را صدا می‌زنند.
class SleepPlanGateway {
  const SleepPlanGateway._();

  /// وضعیت امشب (تسویهٔ شب‌های گذشته + فریز پله) یا null.
  static Future<SleepProgramState?> loadState({DateTime? now}) async {
    try {
      final repo = await SleepProgramRepository.fromHelper();
      return await repo.refreshAndLoadState(now: now);
    } catch (e, st) {
      RitmoLog.error('SleepPlanGateway', 'loadState failed', e, st);
      return null;
    }
  }

  /// اسنپ‌شات داور را با روایت‌های برنامهٔ خواب ترکیب می‌کند.
  ///
  /// اگر [state] از پیش داشته باشی (مثلاً برای کارت‌های دیگر هم لازمش داری)
  /// دوباره از دیتابیس خوانده نمی‌شود.
  static Future<WellbeingInsightSnapshot> mergeInto(
    WellbeingInsightSnapshot snapshot, {
    required DateTime now,
    int sleepLogCount = 0,
    SleepProgramState? state,
  }) async {
    final resolved = state ?? await loadState(now: now);
    if (resolved == null) return snapshot;
    return SleepPlanInsights.merge(
      snapshot: snapshot,
      state: resolved,
      now: now,
      sleepLogCount: sleepLogCount,
    );
  }
}
