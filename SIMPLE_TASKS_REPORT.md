# Simple Tasks Implementation Report

Generated following `RITMO_SIMPLE_TASKS_PROMPT.md`.

## Phase 0: Technical Debt Cleanup & Core Hardening
- [x] **T-01**: Centralize ID generation in `RitmoIdFactory` (`task()`, `taskStep()`, `taskAttachment()`) and eliminate `Random()`. [DONE]
- [x] **T-02**: Replace all empty `catch (_) {}` with structured `RitmoLog` entries. [DONE]
- [x] **T-03**: Replace all `debugPrint` calls in `simple_tasks` with `RitmoLog`. [DONE]
- [x] **T-04**: Unify reminder cancellations via `NotificationGateway.cancel`. [DONE]
- [x] **T-05**: Migrate `TaskPreferences` from `SharedPreferences` to SQLite `app_settings`. [DONE]
- [x] **T-06**: Decouple task mutations from `RitmoEvents.notifyRoutineChanged()`. [DONE]
- [x] **T-07**: Refactor repository queries (`doneToday` strict date check, `dueTodayOrOverdue`, `countOverdue`, `countDueToday`, transaction wrapping for `create`). [DONE]

## Phase 1: My Day ("روز من")
- [x] **T-08**: Database migration V115 adding `addedToMyDayAt` column & index, updating `SimpleTask` model (`isInMyDay`, `addedToMyDayAt`, `copyWith`). [DONE]
- [x] **T-09**: `MyDayService` with daily midnight reset based on app launch/resume (without alarms or row mutation) and `tasks_my_day_last_reset` in `app_settings`. [DONE]
- [x] **T-10**: `MyDaySuggestions` engine generating up to 5 prioritized, non-judgmental suggestions (overdue, dueToday, important, dueTomorrow, fromRoutine) excluding current My Day tasks. [DONE]
- [x] **T-11**: `MyDaySection` widget with 3 clear states (Empty+Suggestions, Has Tasks, All Clear) integrated at the top of `SimpleTasksScreen`. [DONE]
- [x] **T-12**: Comprehensive unit & integration tests in `test/simple_tasks/my_day_test.dart`. [DONE]

## Phase 2: Reliable Reminder Engine & Actionable Notifications
- [x] **T-13**: Connected `DailyPlanningNudge.syncNudgeSchedule()` to real `NotificationGateway.schedule` and linked it directly into `AlarmSchedulerService.scheduleNextAlarms()`. [DONE]
- [x] **T-14**: Fixed notification copy to constant anti-guilt text ("امروز چه کاری داری؟") eliminating stale count artifacts. [DONE]
- [x] **T-15**: Created `lib/features/simple_tasks/logic/task_snooze.dart` with 4 discrete presets (`tenMinutes`, `oneHour`, `thisEvening`, `tomorrowMorning`), strictly preserving `dueDate`. [DONE]
- [x] **T-16**: Wired `NotificationActionDispatcher` for simple task actions (`DONE` and `SNOOZE`/`SNOOZE_1H`) through existing background engine & method channels. [DONE]
- [x] **T-17**: Created `lib/features/simple_tasks/logic/missed_reminder_recovery.dart` with intelligent recovery capped at max 3 instant notifications or 1 consolidated summary. [DONE]
- [x] **T-18**: Verified exact alarm permissions (`SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`) in `AndroidManifest.xml` and user permission flow. [DONE]
- [x] **T-19**: Comprehensive reminder engine test suite in `test/simple_tasks/reminder_engine_test.dart` verifying all scheduling, snoozing, and recovery rules. [DONE]

## Phase 3: Tags & Full Search Normalization
- [x] **T-20**: Created `lib/features/simple_tasks/logic/task_tag_parser.dart` to extract up to 3 normalized hashtags from titles, keeping excess tags in title and avoiding untitled tasks. [DONE]
- [x] **T-21**: Added migration V116 for `tagsJson` and normalized search columns with backfill; updated `SimpleTask` and `TaskStep` models. [DONE]
- [x] **T-22**: Fixed search query bug in `SimpleTaskRepository.search()` by querying exclusively against `titleNormalized`, `noteNormalized`, `titleNormalized` (steps), and `tagsJson`. [DONE]
- [x] **T-23**: Added dynamic tag filter chips below search/add bar in `SimpleTasksScreen` with active tag filtering, empty state auto-hide, and single-selection toggle. [DONE]
- [x] **T-24**: Enabled phone and URL interactive links in note view mode using `url_launcher`. [DONE]

## Phase 4: Display, Sorting, & Momentary Satisfaction
- [x] **T-25**: Added `TaskSortMode` (`smart`, `dueDate`, `importance`, `alphabetical`, `createdAt`) in `task_bucketing.dart` preserving bucket structure and persistence in `tasks_sort_mode`. [DONE]
- [x] **T-26**: Added `tasks_hide_completed` toggle filtering done tasks from UI and removing `doneToday` bucket without mutating database rows. [DONE]
- [x] **T-27**: Modularized `task_detail_sheet.dart` into `task_schedule_row.dart`, `task_note_field.dart`, `task_meta_row.dart`, and `task_attachments_section.dart` (241 lines, <= 250 max limit). [DONE]
- [x] **T-28**: Verified completion sound and haptics trigger exclusively on marking a task complete (no sound/haptic when unchecking). [DONE]
- [x] **T-29**: Comprehensive unit test suite in `test/simple_tasks/task_sorting_test.dart` validating smart sort regression, Persian alphabetical sorting, cross-bucket immutability, and hide completed behavior. [DONE]

## Phase 5: Quick Entry from OS
- [x] **T-30**: Configured Android App Shortcuts (`shortcuts.xml`) for «کار جدید» (opens and focuses task add) and «روز من» (opens My Day). [DONE]
- [x] **T-31**: Verified and wired Quick Settings Tile (`RitmoTaskTileService`) with label `@string/shortcut_new_task`. [DONE]
- [x] **T-32**: Connected and verified Share Target channel (`com.ritmo.app/share_target`) with cold-start buffer and `ShareTargetHandler.init()` in `main.dart`. [DONE]
- [x] **T-33**: Enabled `PROCESS_TEXT` intent-filter with label «افزودن به ریتمو», mapping long text (> 200 chars) to short title and full note. [DONE]
- [x] **T-34**: Unit test suite in `test/simple_tasks/quick_entry_test.dart` verifying simple text, Persian date/time parsing, > 200 character overflow, and whitespace ignoring. [DONE]

## Verification Status:
- `grep -rn "catch (_)" lib/features/simple_tasks/`: Clean (0 occurrences)
- `grep -rn "debugPrint" lib/features/simple_tasks/`: Clean (0 occurrences)
- `grep -rn "SharedPreferences" lib/features/simple_tasks/`: Clean (0 occurrences)
- `grep -rn "Random()" lib/features/simple_tasks/`: Clean (0 occurrences)
- `wc -l lib/features/simple_tasks/presentation/widgets/task_detail_sheet.dart`: 241 lines (<= 250)
- All files in `lib/features/simple_tasks`: <= 500 lines
- `flutter analyze lib/features/simple_tasks lib/main.dart`: 0 errors / 0 warnings
- `flutter test test/features/simple_tasks test/prompt_063 test/simple_tasks`: All 51 tests passing
