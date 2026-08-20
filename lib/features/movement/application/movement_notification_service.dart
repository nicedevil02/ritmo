import 'package:flutter/material.dart';
import 'package:ritmo/core/notifications/notification_channel.dart';
import 'package:ritmo/core/notifications/notification_gateway.dart';
import 'package:ritmo/core/notifications/notification_request.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';
import 'package:ritmo/features/movement/presentation/movement_routes.dart';

/// سرویس مدیریت اعلان‌ها و یادآوری‌های ماژول حرکت (MovementNotificationService)
/// اتصال کامل به NotificationGateway و قواعد لغو، زمان‌بندی مجدد، حریم خصوصی و فال‌بک دیپ‌لینک
class MovementNotificationService {
  MovementNotificationService({
    Future<bool> Function(NotificationRequest req)? scheduleFn,
    Future<bool> Function(String id)? cancelFn,
  }) : _scheduleFn = scheduleFn ?? NotificationGateway.schedule,
       _cancelFn = cancelFn ?? NotificationGateway.cancel;

  final Future<bool> Function(NotificationRequest req) _scheduleFn;
  final Future<bool> Function(String id) _cancelFn;

  static const String sourceSystem = 'movement';

  /// ۱. یادآوری پیش از جلسه ورزشی
  Future<bool> scheduleSessionReminder({
    required MovementOccurrence occurrence,
    MovementActivityKind? kind,
    int minutesBefore = 15,
    bool isPrivate = false,
  }) async {
    if (occurrence.startTime == null || occurrence.startTime!.isEmpty)
      return false;

    final parts = occurrence.startTime!.split(':');
    if (parts.length != 2) return false;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return false;

    final dateParts = occurrence.dateIso.split('-');
    if (dateParts.length != 3) return false;

    final y = int.tryParse(dateParts[0]);
    final m = int.tryParse(dateParts[1]);
    final d = int.tryParse(dateParts[2]);
    if (y == null || m == null || d == null) return false;

    final sessionTime = DateTime(y, m, d, hour, minute);
    final reminderTime = sessionTime.subtract(Duration(minutes: minutesBefore));

    final activityTitle =
        kind?.nameFa ?? MovementStrings.notificationSessionPreReminder;
    final startTime = occurrence.startTime;
    final bodyText = startTime != null
        ? 'ساعت ${toPersianDigits(startTime)}'
        : '';

    final request = NotificationRequest(
      id: 'mov_rem_${occurrence.id}',
      channel: NotificationChannelId.routine,
      scheduledAt: reminderTime,
      title: activityTitle,
      body: bodyText,
      privacy: isPrivate
          ? NotificationPrivacy.redacted
          : NotificationPrivacy.none,
      redactedTitle: MovementStrings.notificationNeutralTitle,
      redactedBody: MovementStrings.notificationNeutralBody,
      sourceSystem: sourceSystem,
      entityId: occurrence.id,
      payload: {
        'type': 'session_reminder',
        'occurrenceId': occurrence.id,
        'dateIso': occurrence.dateIso,
        'route': MovementRoutes.center,
      },
    );

    return _scheduleFn(request);
  }

  /// ۲. یادآوری خلاصهٔ روزانهٔ جلسات صبح
  Future<bool> scheduleMorningSummary({
    required String dateIso,
    required List<MovementOccurrence> dailyOccurrences,
    String morningTime = '08:00',
    bool isPrivate = false,
  }) async {
    if (dailyOccurrences.isEmpty) return false;

    final parts = morningTime.split(':');
    if (parts.length != 2) return false;

    final hour = int.tryParse(parts[0]) ?? 8;
    final minute = int.tryParse(parts[1]) ?? 0;

    final dateParts = dateIso.split('-');
    if (dateParts.length != 3) return false;

    final y = int.tryParse(dateParts[0]) ?? 2026;
    final m = int.tryParse(dateParts[1]) ?? 1;
    final d = int.tryParse(dateParts[2]) ?? 1;

    final scheduledAt = DateTime(y, m, d, hour, minute);

    final request = NotificationRequest(
      id: 'mov_morning_$dateIso',
      channel: NotificationChannelId.planning,
      scheduledAt: scheduledAt,
      title: MovementStrings.notificationMorningTitle,
      body:
          'امروز ${toPersianDigits(dailyOccurrences.length)} جلسهٔ ورزشی در برنامه دارید.',
      privacy: isPrivate
          ? NotificationPrivacy.redacted
          : NotificationPrivacy.none,
      redactedTitle: MovementStrings.notificationNeutralTitle,
      redactedBody: MovementStrings.notificationNeutralBody,
      sourceSystem: sourceSystem,
      entityId: dateIso,
      payload: {
        'type': 'morning_summary',
        'dateIso': dateIso,
        'route': MovementRoutes.center,
      },
    );

    return _scheduleFn(request);
  }

  /// ۳. یادآوری جلسهٔ نیمه‌تمام پس از یک بازهٔ زمانی
  Future<bool> schedulePartialSessionReminder({
    required String occurrenceId,
    int delayMinutes = 120,
    bool isPrivate = false,
  }) async {
    final scheduledAt = DateTime.now().add(Duration(minutes: delayMinutes));

    final request = NotificationRequest(
      id: 'mov_partial_$occurrenceId',
      channel: NotificationChannelId.routine,
      scheduledAt: scheduledAt,
      title: MovementStrings.notificationPartialTitle,
      body: MovementStrings.notificationPartialBody,
      privacy: isPrivate
          ? NotificationPrivacy.redacted
          : NotificationPrivacy.none,
      redactedTitle: MovementStrings.notificationNeutralTitle,
      redactedBody: MovementStrings.notificationNeutralBody,
      sourceSystem: sourceSystem,
      entityId: occurrenceId,
      payload: {
        'type': 'partial_session_reminder',
        'occurrenceId': occurrenceId,
        'route': MovementRoutes.liveSession,
      },
    );

    return _scheduleFn(request);
  }

  /// لغو یادآورهای یک رخداد (هنگام تکمیل، لغو، یا رد جلسه)
  Future<void> cancelOccurrenceReminders(String occurrenceId) async {
    await _cancelFn('mov_rem_$occurrenceId');
    await _cancelFn('mov_partial_$occurrenceId');
  }

  /// زمان‌بندی مجدد یادآور جلسه هنگام جابه‌جایی
  Future<bool> rescheduleOccurrenceReminder({
    required MovementOccurrence movedOccurrence,
    MovementActivityKind? kind,
    int minutesBefore = 15,
  }) async {
    await cancelOccurrenceReminders(movedOccurrence.id);
    if (movedOccurrence.status == MovementOccurrenceStatus.planned &&
        movedOccurrence.startTime != null &&
        movedOccurrence.startTime!.isNotEmpty) {
      return scheduleSessionReminder(
        occurrence: movedOccurrence,
        kind: kind,
        minutesBefore: minutesBefore,
      );
    }
    return true;
  }

  /// توقف یادآورهای برنامهٔ قدرتی هنگام مکث یا آرشیو
  Future<void> cancelStrengthProgramReminders(
    List<String> occurrenceIds,
  ) async {
    for (final id in occurrenceIds) {
      await cancelOccurrenceReminders(id);
    }
  }

  /// پاکسازی تمام یادآورهای ماژول حرکت (هنگام حذف کامل داده‌ها)
  Future<void> cancelAllMovementReminders({
    List<String>? allOccurrenceIds,
  }) async {
    if (allOccurrenceIds != null) {
      for (final id in allOccurrenceIds) {
        await cancelOccurrenceReminders(id);
      }
    }
  }

  /// مسیریابی امن اعلان با Fallback مطمئن به مرکز حرکت (بدون بن‌بست یا خطای خالی)
  static void navigateFromPayload(
    BuildContext context,
    Map<String, dynamic>? payload,
  ) {
    if (payload == null) {
      Navigator.of(context).pushNamed(MovementRoutes.center);
      return;
    }

    final route = payload['route'] as String? ?? MovementRoutes.center;
    final occurrenceId = payload['occurrenceId'] as String?;
    final dateIso = payload['dateIso'] as String?;

    if (route == MovementRoutes.center &&
        occurrenceId != null &&
        occurrenceId.isNotEmpty) {
      Navigator.of(context).pushNamed(
        MovementRoutes.center,
        arguments: {'occurrenceId': occurrenceId, 'dateIso': dateIso},
      );
      return;
    }

    if (route == MovementRoutes.liveSession &&
        occurrenceId != null &&
        occurrenceId.isNotEmpty) {
      Navigator.of(context).pushNamed(
        MovementRoutes.liveSession,
        arguments: {'occurrenceId': occurrenceId},
      );
      return;
    }

    if (route == MovementRoutes.center) {
      Navigator.of(
        context,
      ).pushNamed(MovementRoutes.center, arguments: {'initialDate': dateIso});
      return;
    }

    // پیش‌فرض ایمن
    Navigator.of(context).pushNamed(MovementRoutes.center);
  }
}
