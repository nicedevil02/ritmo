/// Central registry for all notification integer IDs and ID ranges across Ritmo.
/// Prevents cross-service collisions (e.g. cycle vs backup vs sleep reminders).
abstract final class NotificationIds {
  // 1000-1999: System & Core Services
  static const int masterService = 1001;

  // 2000-2999: Cycle & Reproductive Health
  static const int cyclePill = 2001;
  static const int cyclePeriod = 2002;
  static const int cyclePeriodT2 = 2002;
  static const int cycleOvulation = 2003;
  static const int cyclePeriodT1 = 2004;

  // 3000-3999: Sleep, Recovery & Backups
  static const int sleepWinddown = 3001;
  static const int weeklyBackup = 3002;

  // 7000-7999: Foreground & Status
  static const int persistentStatus = 7777;

  // 8000-8999: Summary & Digests
  static const int summaryGroup = 8888;

  // 9000-9999: Diagnostics & Tests
  static const int testAlarm = 9999;

  /// All registered constant notification IDs to verify uniqueness.
  static const List<int> all = [
    masterService,
    cyclePill,
    cyclePeriod,
    cyclePeriodT1,
    cycleOvulation,
    sleepWinddown,
    weeklyBackup,
    persistentStatus,
    summaryGroup,
    testAlarm,
  ];
}
