# Ritmo Aurora Theme Migration Audit Report

Generated At: 2026-08-14T22:57:40.949667

## Audit Metrics Summary

| Metric | Key | Scope | Current Count | Baseline | Status |
|---|---|---|---|---|---|
| Hardcoded Colors | `hardcodedColors` | `lib/features/` | 1516 | 1516 | OK |
| Material Colors (non-transparent) | `materialColors` | `lib/features/` | 2210 | 2210 | OK |
| Old Opacity withOpacity() | `oldOpacity` | `lib/` | 0 | 0 | OK |
| Duplicate Local Font Family | `duplicateFont` | `lib/features/` | 13 | 13 | OK |
| Scattered BackdropFilter | `scatteredBlur` | `lib/features/` | 29 | 29 | OK |
| Manual BoxShadow | `manualShadow` | `lib/features/` | 174 | 174 | OK |
| Raw Scaffold | `rawScaffold` | `lib/features/` | 102 | 102 | OK |
| Page-level CircularProgressIndicator | `circularProgress` | `lib/features/` | 114 | 114 | OK |
| Local Directionality Override | `localDirectionality` | `lib/features/` | 297 | 297 | OK |
| Hardcoded Millisecond Duration | `hardcodedDuration` | `lib/features/` | 160 | 160 | OK |

## Top Offenders by Metric

### Hardcoded Colors (`hardcodedColors`)
Total: 1516 occurrences

| File | Occurrences |
|---|---|
| `lib/features/supplementary_sports/presentation/ss_workout_session_screen.dart` | 157 |
| `lib/features/cycle/presentation/cycle_screen.dart` | 99 |
| `lib/features/supplementary_sports/presentation/ss_home_dashboard_screen.dart` | 91 |
| `lib/features/profile/presentation/cycle_harmony_screen.dart` | 75 |
| `lib/features/worship/presentation/widgets/prayer_arc_hero.dart` | 64 |

### Material Colors (non-transparent) (`materialColors`)
Total: 2210 occurrences

| File | Occurrences |
|---|---|
| `lib/features/cycle/presentation/cycle_screen.dart` | 166 |
| `lib/features/supplementary_sports/presentation/ss_workout_session_screen.dart` | 113 |
| `lib/features/profile/presentation/cycle_harmony_screen.dart` | 78 |
| `lib/features/supplementary_sports/presentation/ss_home_dashboard_screen.dart` | 71 |
| `lib/features/cycle/presentation/widgets/cycle_pregnancy_mode.dart` | 51 |

### Old Opacity withOpacity() (`oldOpacity`)
Total: 0 occurrences

*No violations found.*

### Duplicate Local Font Family (`duplicateFont`)
Total: 13 occurrences

| File | Occurrences |
|---|---|
| `lib/features/profile/presentation/crash_reports_screen.dart` | 2 |
| `lib/features/today/presentation/insights_screen.dart` | 2 |
| `lib/features/calendar/presentation/widgets/journey_agenda_view.dart` | 1 |
| `lib/features/courses/presentation/widgets/floating_timer_bar.dart` | 1 |
| `lib/features/courses/presentation/widgets/focus_mode_screen.dart` | 1 |

### Scattered BackdropFilter (`scatteredBlur`)
Total: 29 occurrences

| File | Occurrences |
|---|---|
| `lib/features/cycle/presentation/cycle_screen.dart` | 5 |
| `lib/features/settings/presentation/groups/identity_group_screen.dart` | 4 |
| `lib/features/today/presentation/systems_hub_screen.dart` | 2 |
| `lib/features/today/presentation/widgets/dashboard/module_summary_grid.dart` | 2 |
| `lib/features/assistant/presentation/widgets/ai_day_planner_preview_sheet.dart` | 1 |

### Manual BoxShadow (`manualShadow`)
Total: 174 occurrences

| File | Occurrences |
|---|---|
| `lib/features/supplementary_sports/presentation/ss_home_dashboard_screen.dart` | 9 |
| `lib/features/notes/presentation/screens/notebook_screen.dart` | 8 |
| `lib/features/profile/presentation/cycle_harmony_screen.dart` | 8 |
| `lib/features/settings/presentation/groups/identity_group_screen.dart` | 6 |
| `lib/features/worship/presentation/widgets/mustahab_section.dart` | 6 |

### Raw Scaffold (`rawScaffold`)
Total: 102 occurrences

| File | Occurrences |
|---|---|
| `lib/features/supplementary_sports/presentation/ss_workout_session_screen.dart` | 9 |
| `lib/features/supplementary_sports/presentation/ss_home_dashboard_screen.dart` | 4 |
| `lib/features/supplementary_sports/presentation/ss_plan_day_detail_screen.dart` | 4 |
| `lib/features/cycle/presentation/onboarding/cycle_onboarding_shell.dart` | 3 |
| `lib/features/konkur/presentation/konkur_screen.dart` | 3 |

### Page-level CircularProgressIndicator (`circularProgress`)
Total: 114 occurrences

| File | Occurrences |
|---|---|
| `lib/features/goals/presentation/widgets/create_goal_sheet.dart` | 3 |
| `lib/features/profile/presentation/backup_screen.dart` | 3 |
| `lib/features/supplementary_sports/presentation/ss_workout_session_screen.dart` | 3 |
| `lib/features/chat/presentation/ai_chat_screen.dart` | 2 |
| `lib/features/goals/presentation/widgets/goals_card_list_section.dart` | 2 |

### Local Directionality Override (`localDirectionality`)
Total: 297 occurrences

| File | Occurrences |
|---|---|
| `lib/features/supplementary_sports/presentation/ss_workout_session_screen.dart` | 12 |
| `lib/features/cycle/presentation/cycle_screen.dart` | 10 |
| `lib/features/today/presentation/insights_screen.dart` | 7 |
| `lib/features/health/presentation/widgets/medications_section.dart` | 6 |
| `lib/features/profile/presentation/cycle_harmony_screen.dart` | 6 |

### Hardcoded Millisecond Duration (`hardcodedDuration`)
Total: 160 occurrences

| File | Occurrences |
|---|---|
| `lib/features/routines/presentation/widgets/planner_timeline_picker.dart` | 8 |
| `lib/features/supplementary_sports/presentation/ss_onboarding_flow.dart` | 7 |
| `lib/features/worship/presentation/widgets/quran_dhikr_section.dart` | 6 |
| `lib/features/worship/presentation/widgets/worship_reminder_settings_sheet.dart` | 6 |
| `lib/features/health/presentation/health_screen.dart` | 5 |
