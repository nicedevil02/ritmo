/// کلیدهای استاندارد و مجاز دلایل تولید اسلات در PlanEngine (S3-T3).
class MvReasonKeys {
  static const String anchor = 'mv_reason_anchor';
  static const String preAnchorTaper = 'mv_reason_pre_anchor_taper';
  static const String postAnchorRecovery = 'mv_reason_post_anchor_recovery';
  static const String complement = 'mv_reason_complement';
  static const String whoGap = 'mv_reason_who_gap';
  static const String strengthQuota = 'mv_reason_strength_quota';
  static const String restGuaranteed = 'mv_reason_rest_guaranteed';
  static const String readinessLow = 'mv_reason_readiness_low';
  static const String loadCap = 'mv_reason_load_cap';
  static const String fallbackMinimum = 'mv_reason_fallback_minimum';
  static const String seasonFit = 'mv_reason_season_fit';
  static const String constraintRelaxed = 'mv_reason_constraint_relaxed';

  static const Set<String> all = {
    anchor,
    preAnchorTaper,
    postAnchorRecovery,
    complement,
    whoGap,
    strengthQuota,
    restGuaranteed,
    readinessLow,
    loadCap,
    fallbackMinimum,
    seasonFit,
    constraintRelaxed,
  };

  /// قالب‌بندی پیام فارسی دلیل اسلات با جایگذاری متغیرها
  static String formatReasonFa(
    String reasonKey, [
    Map<String, String>? params,
  ]) {
    switch (reasonKey) {
      case anchor:
        return 'لنگر ثابت توست';
      case preAnchorTaper:
        final kind = params?['kind'] ?? '';
        return 'فردا $kind داری، امروز سبک';
      case postAnchorRecovery:
        final kind = params?['kind'] ?? '';
        return 'دیروز $kind داشتی، امروز بازیابی';
      case complement:
        final kind = params?['kind'] ?? '';
        final focus = params?['focus'] ?? '';
        return 'پشتیبانی $kind: تقویت $focus';
      case whoGap:
        final remaining = params?['remaining'] ?? '';
        return 'برای رسیدن به هدف هفتگی $remaining دقیقه مانده';
      case strengthQuota:
        final days = params?['days'] ?? '';
        return 'این هفته فقط $days روز قدرتی داشتی';
      case restGuaranteed:
        return 'سه لنگر یا بیشتر داری، این روز کامل استراحت';
      case readinessLow:
        return 'بر اساس چک‌این امروز کم‌شده';
      case loadCap:
        return 'سقف رشد ۱۰٪ رعایت شد';
      case fallbackMinimum:
        return 'حداقل مؤثر برای حفظ روند';
      case seasonFit:
        return 'مناسب فصل جاری';
      case constraintRelaxed:
        return 'برای اینکه برنامه خالی نماند، یک محدودیت شل شد';
      default:
        return 'برنامهٔ هوشمند روز بر اساس اهداف و آمادگی بدنی شما';
    }
  }
}
