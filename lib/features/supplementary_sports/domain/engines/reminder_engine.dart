import '../models/models.dart';

/// Reminder notification schedule details.
class MvScheduledReminder {
  final String dateIso;
  final String time; // HH:mm
  final String messageFa;
  final bool isSilent;
  final bool shouldSchedule;

  const MvScheduledReminder({
    required this.dateIso,
    required this.time,
    required this.messageFa,
    this.isSilent = false,
    this.shouldSchedule = true,
  });
}

/// 7.11 ReminderEngine: Schedules non-intrusive workout reminders respecting calendar constraints.
class ReminderEngine {
  const ReminderEngine();

  /// Calculates reminder scheduling parameters for a slot.
  MvDecision<MvScheduledReminder> evaluateReminder({
    required MvSlot slot,
    bool isBlockedTime = false,
    bool isSilentZone = false,
    String defaultTime = '18:00',
  }) {
    if (slot.isRest || slot.isCompleted || slot.isSkipped || isBlockedTime) {
      return MvDecision<MvScheduledReminder>(
        value: MvScheduledReminder(
          dateIso: slot.dateIso,
          time: defaultTime,
          messageFa: '',
          shouldSchedule: false,
        ),
        reasonFa: 'یادآور برای روز استراحت یا منطقهٔ زمان مسدود فعال نمی‌شود.',
        sources: const ['calendar_gates'],
        confidence: 1.0,
        hasEnoughData: true,
      );
    }

    final scheduledTime = slot.plannedTime ?? defaultTime;
    final headline = slot.headlineFa;
    final messageFa =
        'وقت ${headline.replaceAll("سبک: ", "")} رسیده است. هر زمان آماده بودی شروع کن.';

    final reminder = MvScheduledReminder(
      dateIso: slot.dateIso,
      time: scheduledTime,
      messageFa: messageFa,
      isSilent: isSilentZone,
      shouldSchedule: true,
    );

    return MvDecision<MvScheduledReminder>(
      value: reminder,
      reasonFa: 'یادآور برای ساعت $scheduledTime تنظیم شد.',
      sources: const ['slot_time'],
      confidence: 1.0,
      hasEnoughData: true,
    );
  }
}
