// lib/features/supplementary_sports/movement/data/movement_reminder_service.dart

import 'package:flutter/material.dart';
import 'package:ritmo/core/notifications/notification_channel.dart';
import 'package:ritmo/core/notifications/notification_gateway.dart';
import 'package:ritmo/core/notifications/notification_request.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/unified_planner_repository.dart';

/// سرویس مدیریت نوتیفیکیشن‌های یادآوری حرکت و تمرین در طول هفته از طریق NotificationGateway.
class MovementReminderService {
  MovementReminderService._();

  static const String sourceSystem = 'movement';

  /// لغو تمام نوتیفیکیشن‌های یادآوری حرکت قبلی.
  static Future<void> cancelAll() async {
    try {
      await NotificationGateway.cancelForEntity(sourceSystem, 'movement_week');
    } catch (e) {
      debugPrint('[ss] MovementReminderService cancelAll error: $e');
    }
  }

  /// باززمان‌بندی هوشمند تمام یادآوری‌های ۷ روز آینده بر اساس آخرین وضعیت تختهٔ هفته
  /// (با اعمال خودکار همهٔ استثناهای این هفته: SKIP, MOVE, RETIME, LIGHT).
  static Future<void> rescheduleWeekReminders() async {
    try {
      await cancelAll();

      final plan = await UnifiedPlannerRepository.instance.loadWeek();
      final now = DateTime.now();

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
            reminderTime = sessionDateTime.subtract(
              Duration(minutes: item.reminderMinutes),
            );
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

            final reminderId =
                'movement_${item.id}_${reminderTime.millisecondsSinceEpoch}';

            await NotificationGateway.schedule(
              NotificationRequest(
                id: reminderId,
                channel: NotificationChannelId.routine,
                scheduledAt: reminderTime,
                title: 'ریتم حرکت ${item.emoji}',
                body: bodyText,
                sourceSystem: sourceSystem,
                entityId: 'movement_week',
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[ss] MovementReminderService reschedule error: $e');
    }
  }
}
