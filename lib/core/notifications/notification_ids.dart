/// Central registry for all notification integer IDs and ID ranges across Ritmo.
/// Prevents cross-service collisions (e.g. cycle vs backup vs sleep reminders).
abstract final class NotificationIds {
  // 1000-1999: System & Core Services
  static const int masterService = 1001;

  // 2000-2999: Cycle & Reproductive Health (Single source of truth)
  static const int cyclePill = 2001;
  static const int cyclePeriod = 2002;
  static const int cyclePeriodT2 = 2002;
  static const int cycleOvulation = 2003;
  static const int cyclePeriodT1 = 2004;

  static const int cycleLeadReminderBase = 2010; // 2010..2029 (lead days × lookahead cycles)
  static const int cycleStartConfirmBase = 2030; // 2030..2039
  static const int cycleEndConfirmBase = 2040; // 2040..2049
  static const int cycleProlongedBase = 2050; // 2050..2059

  static int leadReminder(int cycleIndex, int leadDays) =>
      cycleLeadReminderBase + (cycleIndex * 5) + (leadDays % 5);

  static int startConfirm(int cycleIndex) => cycleStartConfirmBase + cycleIndex;
  static int endConfirm() => cycleEndConfirmBase;
  static int prolongedBleeding() => cycleProlongedBase;

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
    cycleLeadReminderBase,
    cycleStartConfirmBase,
    cycleEndConfirmBase,
    cycleProlongedBase,
    sleepWinddown,
    weeklyBackup,
    persistentStatus,
    summaryGroup,
    testAlarm,
  ];
}
