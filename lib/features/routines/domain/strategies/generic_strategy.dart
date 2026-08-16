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
    // B-FIX-EVENT-5: eventStartTime, eventEndTime, and eventLocation removed;
    // selectedTime, targetDuration, and description are the canonical sources.
    final eventTime = c.selectedTime;
    final timeStr = c.formatTime(eventTime);
    final durationMinutes = c.targetDuration;
    final String? desc = c.description.isNotEmpty ? c.description : null;

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

    // B-FIX-EVENT-3 — روزِ رویداد باید از `selectedDate` بیاید، نه `eventDate`.
    //
    // `PlannerController.eventDate` با `DateTime.now()` مقداردهی اولیه می‌شود و
    // هیچ‌جای برنامه آن را بازنویسی نمی‌کند. جست‌وجوی سراسری روی مخزن نشان
    // می‌دهد `eventDate` تنها در چهار فایل دیده می‌شود: همین استراتژی،
    // `planner_save_context.dart`، خودِ کنترلر، و یک تست — هیچ فرمی میانشان نیست.
    //
    // در مقابل، فرمِ رویداد همان `GenericStep2Form` است
    // (`universal_planner_sheet.dart` → `setEventSheetOpener`)، و آن فرم
    // `PlannerTimelinePicker` را نشان می‌دهد که تاریخِ انتخابی کاربر را با
    // `controller.setDate(...)` در `selectedDate` می‌نویسد.
    //
    // پس شرطِ پیشین — `(isEvent && c.eventDate != null)` — همیشه برقرار بود و
    // تاریخِ انتخابی کاربر را دور می‌ریخت: هر رویداد روی «روزِ باز شدنِ شیت»
    // ثبت می‌شد. کاربر رویداد را برای پنجشنبه می‌ساخت و رویداد روی امروز
    // می‌نشست — و روی پنجشنبه هرگز دیده نمی‌شد.
    //
    // تا زمانی که یک فرمِ اختصاصیِ رویداد واقعاً `eventDate` را پر کند،
    // `selectedDate` تنها منبعِ معتبرِ روز است.
    final effectiveDate = c.selectedDate;
    RoutineRecurrence recurrence;
    // B-FIX-EVENT-1 — یک «رویداد» ذاتاً یک‌بار مصرف است.
    //
    // `PlannerController.recurrenceType` با مقدار 'EVERY_DAY' شروع می‌شود و
    // مسیر ساخت رویداد هرگز به انتخابگر تکرار نمی‌رسد (تنها
    // `generic_step2_form.dart` می‌تواند آن را 'ONCE' کند). در نتیجه رویداد به
    // شاخهٔ else می‌افتاد و با DailyRecurrence ذخیره می‌شد، یعنی
    // scheduleType='EVERY_DAY' و daysOfWeek='6,7,1,2,3,4,5' — یک روتین روزانهٔ
    // بی‌پایان به جای یک رویداد تک‌نوبتی.
    //
    // EVENT دقیقاً مثل TASK باید یک‌بار مصرف باشد.
    if (c.recurrenceType == 'ONCE' || c.itemType == 'TASK' || isEvent) {
      recurrence = OnceRecurrence(date: effectiveDate);
    } else if ((c.recurrenceType == 'CUSTOM_DAYS' || c.recurrenceType == 'WEEKLY') &&
        c.worshipSelectedDays.isNotEmpty) {
      recurrence = WeekdaysRecurrence(weekdays: c.worshipSelectedDays.toSet());
    } else {
      recurrence = const DailyRecurrence();
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
