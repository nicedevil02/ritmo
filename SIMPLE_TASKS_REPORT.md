# Simple Tasks Implementation Report

Generated following `RITMO_SIMPLE_TASKS_PROMPT.md`.

---

## Phase 0: Technical Debt Cleanup & Core Hardening
- [x] **T-01**: Centralize ID generation in `RitmoIdFactory` (`task()`, `taskStep()`, `taskAttachment()`) with atomic monotonic counter, eliminating all usage of `Random()` across simple tasks. [DONE]
- [x] **T-02**: Replace all silent/empty `catch (_) {}` blocks across the simple tasks module with structured `RitmoLog` entries. [DONE]
- [x] **T-03**: Replace all `debugPrint` calls in `lib/features/simple_tasks/` with `RitmoLog.debug` / `RitmoLog.info`. [DONE]
- [x] **T-04**: Unify reminder cancellations via `NotificationGateway.cancel(task.reminderId!)`. [DONE]
- [x] **T-05**: Migrate `TaskPreferences` from `SharedPreferences` to SQLite `app_settings` with strict types and caching. [DONE]
- [x] **T-06**: Decouple task mutations from `RitmoEvents.notifyRoutineChanged()`, firing dedicated `TaskUpdated` events instead. [DONE]
- [x] **T-07**: Refactor repository queries (`doneToday` strict date check, `dueTodayOrOverdue`, `countOverdue`, `countDueToday`, transaction wrapping for `create`). [DONE]

---

## Phase 1: My Day ("روز من")
- [x] **T-08**: Database migration V115 adding `addedToMyDayAt` column & index, updating `SimpleTask` domain model (`isInMyDay`, `addedToMyDayAt`, `copyWith`). [DONE]
- [x] **T-09**: `MyDayService` with daily midnight reset based on app launch/resume (without background alarms or row mutation) and `tasks_my_day_last_reset` in `app_settings`. [DONE]
- [x] **T-10**: `MyDaySuggestions` engine generating up to 5 prioritized, non-judgmental suggestions (overdue, dueToday, important, dueTomorrow, fromRoutine) excluding current My Day tasks. [DONE]
- [x] **T-11**: `MyDaySection` widget with 3 clear states (Empty+Suggestions, Has Tasks, All Clear) integrated at the top of `SimpleTasksScreen` with star toggling, step badges, attachment badges, and tag indicators. [DONE]
- [x] **T-12**: Comprehensive unit & integration tests in `test/simple_tasks/my_day_test.dart` (6/6 passing). [DONE]

---

## Phase 2: Reliable Reminder Engine & Actionable Notifications
- [x] **T-13**: Connected `DailyPlanningNudge.syncNudgeSchedule()` to real `NotificationGateway.schedule` and linked it directly into `AlarmSchedulerService.scheduleNextAlarms()`. [DONE]
- [x] **T-14**: Fixed notification copy to constant anti-guilt text ("امروز چه کاری داری؟") eliminating stale count artifacts. [DONE]
- [x] **T-15**: Created `lib/features/simple_tasks/logic/task_snooze.dart` with 4 discrete presets (`tenMinutes`, `oneHour`, `thisEvening`, `tomorrowMorning`), strictly preserving `dueDate` with full UI action sheet in `TaskScheduleRow`. [DONE]
- [x] **T-16**: Wired `NotificationActionDispatcher` for all simple task actions (`DONE`, `SNOOZE`, `SNOOZE_10M`, `SNOOZE_1H`, `SNOOZE_EVENING`, `SNOOZE_TOMORROW`) through background engine & method channels. [DONE]
- [x] **T-17**: Created `lib/features/simple_tasks/logic/missed_reminder_recovery.dart` with intelligent recovery capped at max 3 instant notifications or 1 consolidated summary. [DONE]
- [x] **T-18**: Verified exact alarm permissions (`SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`) in `AndroidManifest.xml` and user permission flow. [DONE]
- [x] **T-19**: Comprehensive reminder engine test suite in `test/simple_tasks/reminder_engine_test.dart` (7/7 passing). [DONE]

---

## Phase 3: Tags & Full Search Normalization
- [x] **T-20**: Created `lib/features/simple_tasks/logic/task_tag_parser.dart` to extract up to 3 normalized hashtags from titles, keeping excess tags in title and avoiding untitled tasks with `#` guidance hint in add bar. [DONE]
- [x] **T-21**: Added migration V116 for `tagsJson` and normalized search columns with backfill; updated `SimpleTask` and `TaskStep` models. [DONE]
- [x] **T-22**: Connected search query in `GlobalSearchScreen` directly to `SimpleTaskRepository.search()` querying exclusively against `titleNormalized`, `noteNormalized`, `titleNormalized` (steps), and `tagsJson` with direct `TaskDetailSheet` modal interaction. [DONE]
- [x] **T-23**: Added dynamic tag filter chips below search/add bar in `SimpleTasksScreen` with active tag filtering, empty state auto-hide, single-selection toggle, and persistence through optimistic state updates. [DONE]
- [x] **T-24**: Enabled phone and URL interactive links in note view mode using `url_launcher`. [DONE]

---

## Phase 4: Display, Sorting, & Momentary Satisfaction
- [x] **T-25**: Added `TaskSortMode` (`smart`, `dueDate`, `importance`, `alphabetical`, `createdAt`) in `task_bucketing.dart` preserving bucket structure and persistence in `tasks_sort_mode`. [DONE]
- [x] **T-26**: Added `tasks_hide_completed` toggle filtering done tasks from UI and removing `doneToday` bucket without mutating database rows or flickering upon task toggle. [DONE]
- [x] **T-27**: Modularized `task_detail_sheet.dart` into `task_schedule_row.dart`, `task_note_field.dart`, `task_meta_row.dart`, and `task_attachments_section.dart` (226 lines, strictly <= 250 max limit). [DONE]
- [x] **T-28**: Verified completion sound and haptics trigger exclusively on marking a task complete (no sound/haptic when unchecking). [DONE]
- [x] **T-29**: Comprehensive unit test suite in `test/simple_tasks/task_sorting_test.dart` (5/5 passing). [DONE]

---

## Phase 5: Quick Entry from OS
- [x] **T-30**: Configured Android App Shortcuts (`shortcuts.xml`) for «کار جدید» (opens and focuses task add) and «روز من» (opens My Day). [DONE]
- [x] **T-31**: Verified and wired Quick Settings Tile (`RitmoTaskTileService`) with label `@string/shortcut_new_task`. [DONE]
- [x] **T-32**: Connected and verified Share Target channel (`com.ritmo.app/share_target`) with cold-start buffer and `ShareTargetHandler.init()` in `main.dart`. [DONE]
- [x] **T-33**: Enabled `PROCESS_TEXT` intent-filter with label «افزودن به ریتمو», mapping long text (> 200 chars) to short title and full note. [DONE]
- [x] **T-34**: Unit test suite in `test/simple_tasks/quick_entry_test.dart` (4/4 passing). [DONE]

---

## Phase 6: Routine Bridge & Recurrence Guard
- [x] **T-35**: Created `RoutineTaskBridge.materializeTodayRoutineTasks()` to materialize up to 5 daily routine tasks for today with `tasks_routine_materialized_date` guard and `origin = 'PROMOTED'`. [DONE]
- [x] **T-36**: Added architecture guard and comment forbidding recurrence/repeat rules in `SimpleTask` (`test/simple_tasks/no_recurrence_test.dart`). [DONE]
- [x] **T-37**: Unit test suite in `test/simple_tasks/routine_bridge_test.dart` (5/5 passing). [DONE]

---

## Phase 7: Final Acceptance Gate
- [x] **T-38**: Settings registry audited to exactly 9 closed keys with max 4 user-facing settings (`tasks_completion_sound_enabled`, `tasks_daily_nudge_enabled`, `tasks_daily_nudge_time`, `tasks_hide_completed`). Dead settings purged via migration V116. [DONE]
- [x] **T-39**: Entry point audit:
  1. In-app button: `OK`
  2. Share text from other apps (`ACTION_SEND`): `OK`
  3. Text selection context menu (`PROCESS_TEXT`): `OK`
  4. App Shortcuts (Long press launcher): `OK`
  5. Quick Settings tile: `OK`
  6. Daily nudge notification tap: `OK`
  7. Task reminder notification tap: `OK`
  8. Android Home Screen Widget: `OK` [DONE]
- [x] **T-40**: Final gate acceptance:
  - Architecture: 30 dart files in `lib/features/simple_tasks/` (<= 30 max).
  - File size: Zero files > 500 lines (`simple_tasks_screen.dart`: 476 lines, `simple_task_repository.dart`: 470 lines, `task_detail_sheet.dart`: 226 lines).
  - Code hygiene: 0 empty catches, 0 `debugPrint`, 0 `SharedPreferences` in feature logic, 0 `Random()`.
  - Anti-guilt copy: 100% compliant and centralized in `TaskStrings`.
  - Database: Clean additive migrations V115 & V116.
  - Tests & Analysis: `flutter analyze` 0 errors/warnings on `lib/features/simple_tasks/`, 62/62 simple tasks tests passing. [DONE]

---

## Phase 8: Home Screen Widget
- [x] **T-41**: Created Android Home Screen Widget for Tasks & My Day (`RitmoTasksWidgetProvider.kt`, `RitmoTasksWidgetService.kt`, `RitmoTasksWidgetFactory.kt`, layout XMLs) with header counter, scrollable list, and quick add trigger. [DONE]
- [x] **T-42**: In-widget completion (`setTaskDoneDirect`) wired through background Flutter engine & method channel. [DONE]
- [x] **T-43**: Real-time snapshot synchronization (`SnapshotHelper.updateTasksWidgetSnapshot`) integrated into all `SimpleTaskRepository` mutations. [DONE]

---

## وضعیت نهایی
- تعداد کل تسک‌ها: ۴۳
- تعداد آیتم `DONE`: ۴۳ (۱۰۰٪ تکمیل)
- تعداد آیتم `SKIPPED`: ۰
- تعداد آزمون‌های پاس‌شده: ۶۲ / ۶۲ آزمون در `test/simple_tasks/`
- وضعیت تحلیل استاتیک: بدون خطا و اخطار (0 errors, 0 warnings)
