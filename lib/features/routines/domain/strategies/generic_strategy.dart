import 'package:flutter/material.dart' show BuildContext;
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/domain/engines/ritmo_execution_kernel.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/domain/models/duration_bounds.dart';
import 'package:ritmo/features/routines/domain/routine_recurrence.dart';
import 'package:ritmo/features/routines/domain/strategies/planner_category_strategy.dart';
import 'package:ritmo/features/routines/domain/strategies/planner_save_context.dart';

/// Handles: personal (non-reflect), free, work, konkur, and fitness ROUTINE type.
/// Also used as the fallback for any unknown category.
class GenericStrategy implements PlannerCategoryStrategy {
  const GenericStrategy();

  @override
  Category get category => Category.personal;

  @override
  bool matches(Category category, {String? itemType}) {
    // Matches any category that no other strategy claims
    // (personal without REFLECT, free, work, konkur)
    return true;
  }

  @override
  bool isModuleEnabled(Object controller) => true;

  @override
  Future<void> save(Object ctx, BuildContext context) async {
    final c = ctx as PlannerSaveContext;
    final now = DateTime.now().millisecondsSinceEpoch;
    final routineId = c.isEditing
        ? c.routineToEdit!['id'] as String
        : 'routine_$now';

    final isEvent = c.itemType == 'EVENT';
    final eventTime = (isEvent && c.eventStartTime != null) ? c.eventStartTime! : c.selectedTime;
    final timeStr = c.formatTime(eventTime);

    int durationMinutes = c.targetDuration;
    if (isEvent && c.eventStartTime != null && c.eventEndTime != null) {
      final startMin = c.eventStartTime!.hour * 60 + c.eventStartTime!.minute;
      final endMin = c.eventEndTime!.hour * 60 + c.eventEndTime!.minute;
      final diff = endMin - startMin;
      durationMinutes = diff > 0 ? diff : 60;
    }

    String? desc = c.description.isNotEmpty ? c.description : null;
    if (isEvent && c.eventLocation.trim().isNotEmpty) {
      final locText = 'مکان: ${c.eventLocation.trim()}';
      desc = desc != null ? '$desc\n$locText' : locText;
    }

    final routineData = {
      'id': routineId,
      'title': c.title,
      'description': desc,
      'category': c.selectedCategory.name,
      'customCategoryId': null,
      'zoneId': c.selectedZoneId,
      'routineType': isEvent
          ? RoutineType.timeBased.name
          : (c.itemType == 'TASK' ? RoutineType.timeBased.name : c.routineType.name),
      'notificationLevel': NotificationLevel.normal.name,
      'isEssential': 0,
      'isEssentialLocked': 0,
      'energyRule': c.energyRule,
      'priority': c.priority,
      'targetDurationMinutes': DurationBounds.sanitize(durationMinutes),
      'lightDurationMinutes': 0,
      'minimalDurationMinutes': 0,
      'isArchived': 0,
      'isPrivate': 0,
      'displayOrder': 1,
      'createdAt': c.isEditing ? c.routineToEdit!['createdAt'] ?? now : now,
      'updatedAt': now,
      'dependsOnRoutineId': c.dependsOnRoutineId,
      'dependencyType': c.dependencyType.name,
      'dependencyOffsetMinutes': c.dependencyOffsetMinutes,
      'minIntervalHours': c.minIntervalHours,
      'maxDosesPerDay': c.routineType == RoutineType.countBased ? c.countTarget : c.maxDosesPerDay,
      'progressionMode': c.routineType == RoutineType.progressive ? 'DURATION_RAMP' : 'NONE',
      'progressionStart': c.progressionStart,
      'progressionStep': c.progressionStep,
      'progressionTarget': c.progressionTarget,
      'progressionEveryN': c.progressionEveryN,
      'progressionCurrent': c.isEditing ? (c.routineToEdit!['progressionCurrent'] ?? c.progressionStart) : c.progressionStart,
      'progressionDoneSinceAdvance': c.isEditing ? (c.routineToEdit!['progressionDoneSinceAdvance'] ?? 0) : 0,
      'itemType': c.itemType,
      'reminderOffsetMinutes': c.reminderOffsetMinutes,
    };

    final effectiveDate = (isEvent && c.eventDate != null) ? c.eventDate! : c.selectedDate;
    RoutineRecurrence recurrence = const DailyRecurrence();
    if (isEvent) {
      recurrence = OnceRecurrence(date: effectiveDate);
    } else if (c.itemType == 'TASK') {
      recurrence = OnceRecurrence(date: effectiveDate);
    } else if (c.recurrenceType == 'CUSTOM_DAYS' && c.worshipSelectedDays.isNotEmpty) {
      recurrence = WeekdaysRecurrence(weekdays: c.worshipSelectedDays.toSet());
    }

    final (schedType, daysOfWeek) = deriveScheduleParams(recurrence);
    final recurrenceJson = encodeRecurrenceRule(
      recurrence: recurrence,
      startDate: effectiveDate,
      reminderTimes: [timeStr],
    );

    final scheduleData = {
      'id': 'sched_$routineId',
      'routineId': routineId,
      'scheduleType': schedType,
      'timeOfDay': timeStr,
      'daysOfWeek': daysOfWeek,
      'recurrenceRule': recurrenceJson,
      'createdAt': c.isEditing ? c.routineToEdit!['createdAt'] ?? now : now,
      'updatedAt': now,
    };

    if (c.isEditing) {
      await RitmoExecutionKernel.instance.execute(
        EditRoutineCommand(
          routineId: routineId,
          routineData: routineData,
          scheduleData: scheduleData,
          applyToAll: true,
        ),
      );
    } else {
      await RitmoExecutionKernel.instance.execute(
        CreateRoutineCommand(
          routineData: routineData,
          scheduleData: scheduleData,
        ),
      );
    }
    DayAgendaService.instance.invalidateAll();
    RitmoEvents.notifyRoutineChanged();
    RitmoEventBus().fire(RitmoEvent(
      type: 'RoutineChanged',
      timestamp: DateTime.now(),
      payload: const {},
    ));
  }
}
