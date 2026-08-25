/// Immutable snapshot of acute and chronic training load (Section 4.3 & S4-T6).
class MvLoadSnapshot {
  final int acuteLoad;
  final double chronicWeeklyLoad;
  final double? ratio; // null when insufficient data
  final String? bandKey; // One of 4 keys from Section 4.3
  final int daysOfHistory;
  final int completedSessions;
  final String? customBandTitleFa;

  const MvLoadSnapshot({
    required this.acuteLoad,
    required this.chronicWeeklyLoad,
    this.ratio,
    this.bandKey,
    this.daysOfHistory = 0,
    this.completedSessions = 0,
    String? bandTitleFa,
  }) : customBandTitleFa = bandTitleFa;

  bool get hasEnoughData => ratio != null && bandKey != null;

  String get bandTitleFa {
    if (customBandTitleFa != null) return customBandTitleFa!;
    switch (bandKey) {
      case 'mv_load_band_low':
        return 'پایین و ناکافی';
      case 'mv_load_band_optimal':
        return 'مطلوب و سازنده';
      case 'mv_load_band_watch':
        return 'احتیاط و بررسی';
      case 'mv_load_band_spike':
        return 'افزایش ناگهانی بار';
      default:
        return 'نامشخص';
    }
  }

  /// سقف رشد بار هفتگی (§۴٫۴): ۱۱۰٪ میانگین هفتگی مزمن
  double get plannedWeeklyLoadCap => 1.10 * chronicWeeklyLoad;

  @override
  String toString() =>
      'MvLoadSnapshot(acute: $acuteLoad, chronicWeekly: $chronicWeeklyLoad, ratio: $ratio, bandKey: $bandKey, days: $daysOfHistory, sessions: $completedSessions)';
}
