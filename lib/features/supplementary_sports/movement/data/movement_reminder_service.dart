// lib/features/supplementary_sports/movement/data/movement_reminder_service.dart

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/unified_planner_repository.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// سرویس مدیریت نوتیفیکیشن‌های یادآوری حرکت و تمرین در طول هفته.
class MovementReminderService {
  MovementReminderService._();

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const String channelId = 'movement_reminders';
  static const String channelName = 'یادآوری‌های حرکت و تمرین';
  static const String channelDescription =
      'اعلان‌های یادآوری قبل از شروع جلسات ورزشی و تمرین';

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;

    try {
      tz.initializeTimeZones();

      const initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const initializationSettingsDarwin = DarwinInitializationSettings();

      const initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );

      await _notificationsPlugin.initialize(settings: initializationSettings);
      _initialized = true;
    } catch (e) {
      debugPrint('[ss] MovementReminderService init error: $e');
    }
  }

  /// لغو تمام نوتیفیکیشن‌های یادآوری حرکت قبلی.
  static Future<void> cancelAll() async {
    try {
      await _ensureInitialized();
      for (int i = 10000; i < 10100; i++) {
        await _notificationsPlugin.cancel(id: i);
      }
    } catch (e) {
      debugPrint('[ss] MovementReminderService cancelAll error: $e');
    }
  }

  /// باززمان‌بندی هوشمند تمام یادآوری‌های ۷ روز آینده بر اساس آخرین وضعیت تختهٔ هفته
  /// (با اعمال خودکار همهٔ استثناهای این هفته: SKIP, MOVE, RETIME, LIGHT).
  static Future<void> rescheduleWeekReminders() async {
    try {
      await _ensureInitialized();
      await cancelAll();

      final plan = await UnifiedPlannerRepository.instance.loadWeek();
      final now = DateTime.now();

      int notifIdCounter = 10000;

      for (int dayIndex = 0; dayIndex < 7; dayIndex++) {
        final items = plan.byDay[dayIndex];
        for (final item in items) {
          if (item.isCompleted) continue;
          if (item.reminderMinutes == 0) continue;
          if (item.dateIso == null || item.timeLabel == null) continue;

          final itemDate = DateTime.tryParse(item.dateIso!);
          if (itemDate == null) continue;

          final timeParts = item.timeLabel!.split(':');
          if (timeParts.length != 2) continue;
          final hour = int.tryParse(timeParts[0]) ?? 18;
          final minute = int.tryParse(timeParts[1]) ?? 30;

          final sessionDateTime = DateTime(
            itemDate.year,
            itemDate.month,
            itemDate.day,
            hour,
            minute,
          );

          DateTime reminderTime;
          if (item.reminderMinutes == -1) {
            // شب قبل ساعت ۲۱:۰۰
            reminderTime = DateTime(
              itemDate.year,
              itemDate.month,
              itemDate.day,
              21,
              0,
            ).subtract(const Duration(days: 1));
          } else {
            reminderTime = sessionDateTime
                .subtract(Duration(minutes: item.reminderMinutes));
          }

          if (reminderTime.isAfter(now)) {
            final String bodyText;
            if (item.isLight) {
              bodyText = 'نسخه سبک ${item.title} امروز 🌿';
            } else if (item.reminderMinutes == -1) {
              bodyText = 'فردا صبح برنامهٔ ${item.title} داری 🌅 — آماده باش!';
            } else {
              bodyText =
                  '${toPersianDigits(item.reminderMinutes.toString())} دقیقه دیگه ${item.title} ${item.emoji}';
            }

            await _scheduleSingleNotification(
              id: notifIdCounter++,
              title: 'ریتم حرکت ${item.emoji}',
              body: bodyText,
              scheduledDate: reminderTime,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[ss] MovementReminderService reschedule error: $e');
    }
  }

  static Future<void> _scheduleSingleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      color: Color(0xFF10B981),
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final tzDateTime = tz.TZDateTime.from(scheduledDate, tz.local);

    try {
      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzDateTime,
        notificationDetails: platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {
      try {
        await _notificationsPlugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: tzDateTime,
          notificationDetails: platformDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (e) {
        debugPrint('[ss] MovementReminderService single schedule fallback error: $e');
      }
    }
  }
}
