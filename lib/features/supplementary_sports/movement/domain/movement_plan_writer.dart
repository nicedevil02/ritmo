// lib/features/supplementary_sports/movement/domain/movement_plan_writer.dart

import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/domain/engines/ritmo_execution_kernel.dart';
import 'package:ritmo/core/utils/ritmo_id_factory.dart';
import 'package:ritmo/features/routines/domain/routine_recurrence.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/movement_reminder_service.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_kind.dart';

/// Helper مشترک برای ساخت و ویرایش روتین‌های حرکتی با ساعت اختصاصی به ازای هر روز.
class MovementPlanWriter {
  MovementPlanWriter._();

  static Future<String> savePlan({
    String? routineId,
    required MovementKind kind,
    String? muscleFocus,
    required Map<int, TimeOfDay> dayTimesDartWeekday, // Dart weekday 1..7 -> TimeOfDay
    required int targetDurationMinutes,
    required double targetValue,
    required int reminderMinutes,
    bool isEditing = false,
    Map<String, dynamic>? existingRoutineData,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rId = (isEditing && routineId != null) ? routineId : RitmoIdFactory.routine();

    final routineData = <String, dynamic>{
      'id': rId,
      'title': kind.titleFa,
      'description': (isEditing && existingRoutineData != null)
          ? existingRoutineData['description']
          : null,
      'category': 'fitness',
      'customCategoryId': null,
      'zoneId': (isEditing && existingRoutineData != null)
          ? existingRoutineData['zoneId']
          : null,
      'routineType': 'ROUTINE',
      'notificationLevel': 'NORMAL',
      'isEssential': 0,
      'isEssentialLocked': 0,
      'energyRule': 'NONE',
      'priority': 1.0,
      'targetDurationMinutes': targetDurationMinutes,
      'lightDurationMinutes': 0,
      'minimalDurationMinutes': 0,
      'isArchived': 0,
      'isPrivate': 0,
      'displayOrder': 1,
      'createdAt': (isEditing && existingRoutineData != null)
          ? (existingRoutineData['createdAt'] ?? now)
          : now,
      'updatedAt': now,
      'dependsOnRoutineId': null,
      'itemType': 'ROUTINE',
      'reminderOffsetMinutes': reminderMinutes,
      'movementKind': kind.code,
      'movementTargetMetric': kind.primaryMetric.name.toUpperCase(),
      'movementTargetValue': targetValue,
      'movementIsMeetup': kind.isSocial ? 1 : 0,
      'movementMuscleFocus': muscleFocus,
    };

    final schedules = <Map<String, dynamic>>[];
    for (final entry in dayTimesDartWeekday.entries) {
      final dartWeekday = entry.key;
      final time = entry.value;
      final timeStr =
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      final recurrence = WeekdaysRecurrence(weekdays: {dartWeekday});
      final (schedType, daysOfWeek) = deriveScheduleParams(recurrence);
      final recurrenceJson = encodeRecurrenceRule(
        recurrence: recurrence,
        startDate: DateTime.now(),
        reminderTimes: [timeStr],
      );

      schedules.add({
        'id': RitmoIdFactory.schedule(rId),
        'routineId': rId,
        'scheduleType': schedType,
        'timeOfDay': timeStr,
        'daysOfWeek': daysOfWeek,
        'recurrenceRule': recurrenceJson,
        'createdAt': isEditing ? (existingRoutineData?['createdAt'] ?? now) : now,
        'updatedAt': now,
      });
    }

    if (isEditing) {
      await RitmoExecutionKernel.instance.execute(
        EditRoutineCommand(
          routineId: rId,
          routineData: routineData,
          schedules: schedules,
          applyToAll: true,
        ),
      );
    } else {
      await RitmoExecutionKernel.instance.execute(
        CreateRoutineCommand(
          routineData: routineData,
          schedules: schedules,
        ),
      );
      RitmoEventBus().fire(RitmoEvent(
        type: 'movement_plan_created',
        timestamp: DateTime.now(),
        payload: {
          'kindCode': kind.code,
          'muscleFocus': muscleFocus,
        },
      ));
    }

    // باززمان‌بندی نوتیفیکیشن‌ها پس از تغییر برنامه
    await MovementReminderService.rescheduleWeekReminders();

    return rId;
  }
}
