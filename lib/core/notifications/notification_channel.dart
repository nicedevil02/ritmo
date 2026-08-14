/// Six canonical native notification channels in Ritmo.
/// Each channel corresponds to an Android Notification Channel with defined sound, priority, and bypass rules.
enum NotificationChannelId {
  /// Vital medical and health reminders (medications, insulin, urgent health checks).
  /// Bypasses Quiet Hours and Do Not Disturb (DND).
  critical(
    nativeId: 'ritmo_critical_v3',
    titleFa: 'دارو و سلامت حیاتی',
    descriptionFa: 'یادآوری‌های پزشکی و سلامت با اولویت بالا و عبور از ساعت سکوت',
    bypassesQuietHours: true,
  ),

  /// Daily routine and habit reminders.
  routine(
    nativeId: 'ritmo_routine_v3',
    titleFa: 'روتین‌ها و عادات روزمره',
    descriptionFa: 'یادآوری کارها و روتین‌های روزمره زمان‌بندی‌شده',
    bypassesQuietHours: false,
  ),

  /// Prayer times, Athan, and religious practices.
  worship(
    nativeId: 'ritmo_worship_v3',
    titleFa: 'اذان و عبادات',
    descriptionFa: 'اوقات شرعی، اذان و یادآوری اعمال دینی با صدای مستقل',
    bypassesQuietHours: false,
  ),

  /// Daily planning, morning brief, evening reflection, wind-down.
  planning(
    nativeId: 'ritmo_planning_v3',
    titleFa: 'برنامه‌ریزی و بازبینی',
    descriptionFa: 'برنامه‌ریزی روزانه، یادآور پیش‌خواب و مرورهای شبانه',
    bypassesQuietHours: false,
  ),

  /// AI Assistant recommendations, pattern insights, digests.
  insight(
    nativeId: 'ritmo_insight_v3',
    titleFa: 'بینش و دستیار هوشمند',
    descriptionFa: 'تحلیل‌های سبک زندگی و توصیه‌های هوشمند دستیار ریتمو',
    bypassesQuietHours: false,
  ),

  /// Highly sensitive reminders (cycle tracking, confidential notes).
  /// Always redacted or hidden by default.
  privateChannel(
    nativeId: 'ritmo_private_v3',
    titleFa: 'اعلان‌های خصوصی',
    descriptionFa: 'یادآوری چرخه سلامت، یادداشت‌های خصوصی و موارد محرمانه',
    bypassesQuietHours: false,
  );

  const NotificationChannelId({
    required this.nativeId,
    required this.titleFa,
    required this.descriptionFa,
    required this.bypassesQuietHours,
  });

  final String nativeId;
  final String titleFa;
  final String descriptionFa;
  final bool bypassesQuietHours;

  /// Temporary compatibility mapper: isEssential derives from channel.
  bool get isEssential => this == critical;

  static NotificationChannelId parse(String raw) {
    for (final c in NotificationChannelId.values) {
      if (c.name == raw || c.nativeId == raw) {
        return c;
      }
    }
    return NotificationChannelId.routine;
  }
}
