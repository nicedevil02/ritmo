# Ritmo Aurora Theme Migration Audit Report

Generated At: 2026-08-24T20:26:41.771347

## Audit Metrics Summary

| Metric | Key | Scope | Current Count | Baseline | Status |
|---|---|---|---|---|---|
| Hardcoded Colors | `hardcodedColors` | `lib/features/` | 1253 | 1235 | REGRESSION (+1253 > 1235) |
| Material Colors (non-transparent) | `materialColors` | `lib/features/` | 2083 | 2080 | REGRESSION (+2083 > 2080) |
| Old Opacity withOpacity() | `oldOpacity` | `lib/` | 0 | 0 | OK |
| Duplicate Local Font Family | `duplicateFont` | `lib/features/` | 127 | 124 | REGRESSION (+127 > 124) |
| Scattered BackdropFilter | `scatteredBlur` | `lib/features/` | 32 | 30 | REGRESSION (+32 > 30) |
| Manual BoxShadow | `manualShadow` | `lib/features/` | 201 | 199 | REGRESSION (+201 > 199) |
| Raw Scaffold | `rawScaffold` | `lib/features/` | 106 | 106 | OK |
| Page-level CircularProgressIndicator | `circularProgress` | `lib/features/` | 135 | 135 | OK |
| Local Directionality Override | `localDirectionality` | `lib/features/` | 324 | 323 | REGRESSION (+324 > 323) |
| Hardcoded Millisecond Duration | `hardcodedDuration` | `lib/features/` | 196 | 195 | REGRESSION (+196 > 195) |
| Core Hardcoded Colors | `coreHardcodedColors` | `lib/core/` | 415 | 415 | OK |
| Core Material Colors (non-transparent) | `coreMaterialColors` | `lib/core/` | 75 | 75 | OK |
| Core Local Font Family | `coreDuplicateFont` | `lib/core/` | 153 | 153 | OK |
| Core Scattered BackdropFilter | `coreScatteredBlur` | `lib/core/` | 6 | 6 | OK |
| Core Manual BoxShadow | `coreManualShadow` | `lib/core/` | 9 | 9 | OK |
| Raw Font Size | `rawFontSize` | `lib/features/` | 3649 | 3637 | REGRESSION (+3649 > 3637) |
| Raw Geometry Literals | `rawGeometryLiteral` | `lib/features/` | 4529 | 4504 | REGRESSION (+4529 > 4504) |

## Top Offenders by Metric

### Hardcoded Colors (`hardcodedColors`)
Total: 1253 occurrences

| File | Occurrences |
|---|---|
| `lib/features/supplementary_sports/presentation/ss_workout_session_screen.dart` | 157 |
| `lib/features/supplementary_sports/presentation/ss_home_dashboard_screen.dart` | 91 |
| `lib/features/profile/presentation/cycle_harmony_screen.dart` | 75 |
| `lib/features/worship/presentation/widgets/prayer_arc_hero.dart` | 64 |
| `lib/features/worship/presentation/theme/worship_sky_palette.dart` | 57 |

### Material Colors (non-transparent) (`materialColors`)
Total: 2083 occurrences

| File | Occurrences |
|---|---|
| `lib/features/supplementary_sports/presentation/ss_workout_session_screen.dart` | 113 |
| `lib/features/profile/presentation/cycle_harmony_screen.dart` | 78 |
| `lib/features/supplementary_sports/presentation/ss_home_dashboard_screen.dart` | 71 |
| `lib/features/supplementary_sports/movement/presentation/session/movement_session_screen.dart` | 41 |
| `lib/features/supplementary_sports/presentation/widgets/ss_ai_coach_sheet.dart` | 34 |

### Old Opacity withOpacity() (`oldOpacity`)
Total: 0 occurrences

*No violations found.*

### Duplicate Local Font Family (`duplicateFont`)
Total: 127 occurrences

| File | Occurrences |
|---|---|
| `lib/features/supplementary_sports/presentation/ss_exercise_library_screen.dart` | 20 |
| `lib/features/supplementary_sports/movement/presentation/movement_log_sheet.dart` | 18 |
| `lib/features/supplementary_sports/movement/presentation/widgets/movement_session_recovery.dart` | 11 |
| `lib/features/supplementary_sports/movement/presentation/widgets/movement_week_timeline.dart` | 10 |
| `lib/features/supplementary_sports/presentation/ss_movement_tab_screen.dart` | 10 |

### Scattered BackdropFilter (`scatteredBlur`)
Total: 32 occurrences

| File | Occurrences |
|---|---|
| `lib/features/today/presentation/systems_hub_screen.dart` | 4 |
| `lib/features/settings/presentation/groups/identity_group_screen.dart` | 3 |
| `lib/features/cycle/presentation/widgets/add_edit_period_sheet.dart` | 2 |
| `lib/features/cycle/presentation/widgets/cycle_animated_background.dart` | 2 |
| `lib/features/today/presentation/widgets/dashboard/module_summary_grid.dart` | 2 |

### Manual BoxShadow (`manualShadow`)
Total: 201 occurrences

| File | Occurrences |
|---|---|
| `lib/features/supplementary_sports/presentation/ss_home_dashboard_screen.dart` | 9 |
| `lib/features/notes/presentation/screens/notebook_screen.dart` | 8 |
| `lib/features/profile/presentation/cycle_harmony_screen.dart` | 8 |
| `lib/features/today/presentation/widgets/dashboard/today_path_progress_banner.dart` | 8 |
| `lib/features/worship/presentation/widgets/quran_dhikr_section.dart` | 7 |

### Raw Scaffold (`rawScaffold`)
Total: 106 occurrences

| File | Occurrences |
|---|---|
| `lib/features/supplementary_sports/presentation/ss_workout_session_screen.dart` | 9 |
| `lib/features/supplementary_sports/presentation/ss_home_dashboard_screen.dart` | 4 |
| `lib/features/supplementary_sports/presentation/ss_plan_day_detail_screen.dart` | 4 |
| `lib/features/supplementary_sports/presentation/ss_progress_screen.dart` | 3 |
| `lib/features/cycle/presentation/cycle_screen.dart` | 3 |

### Page-level CircularProgressIndicator (`circularProgress`)
Total: 135 occurrences

| File | Occurrences |
|---|---|
| `lib/features/goals/presentation/widgets/create_goal_sheet.dart` | 3 |
| `lib/features/profile/presentation/backup_screen.dart` | 3 |
| `lib/features/supplementary_sports/presentation/ss_workout_session_screen.dart` | 3 |
| `lib/features/worship/presentation/widgets/prayer_city_picker.dart` | 2 |
| `lib/features/chat/presentation/ai_chat_screen.dart` | 2 |

### Local Directionality Override (`localDirectionality`)
Total: 324 occurrences

| File | Occurrences |
|---|---|
| `lib/features/supplementary_sports/presentation/ss_workout_session_screen.dart` | 12 |
| `lib/features/health/presentation/widgets/medications_section.dart` | 8 |
| `lib/features/today/presentation/insights_screen.dart` | 7 |
| `lib/features/profile/presentation/cycle_harmony_screen.dart` | 6 |
| `lib/features/worship/presentation/widgets/quran_dhikr_section.dart` | 6 |

### Hardcoded Millisecond Duration (`hardcodedDuration`)
Total: 196 occurrences

| File | Occurrences |
|---|---|
| `lib/features/worship/presentation/widgets/quran_dhikr_section.dart` | 10 |
| `lib/features/routines/presentation/widgets/planner_timeline_picker.dart` | 8 |
| `lib/features/supplementary_sports/presentation/ss_onboarding_flow.dart` | 7 |
| `lib/features/worship/presentation/widgets/worship_reminder_settings_sheet.dart` | 6 |
| `lib/features/routines/presentation/widgets/planner_advanced_section.dart` | 5 |

### Core Hardcoded Colors (`coreHardcodedColors`)
Total: 415 occurrences

| File | Occurrences |
|---|---|
| `lib/core/theme/palettes/copper_dusk.dart` | 68 |
| `lib/core/theme/palettes/graphite_champagne.dart` | 68 |
| `lib/core/theme/palettes/jade_noir.dart` | 68 |
| `lib/core/theme/palettes/olive_sand.dart` | 68 |
| `lib/core/theme/palettes/rosewood.dart` | 68 |

### Core Material Colors (non-transparent) (`coreMaterialColors`)
Total: 75 occurrences

| File | Occurrences |
|---|---|
| `lib/core/security/app_lock_gate.dart` | 13 |
| `lib/core/widgets/action/ritmo_action_sheet.dart` | 9 |
| `lib/core/utils/ritmo_toast.dart` | 8 |
| `lib/core/observability/ritmo_friendly_error_pane.dart` | 7 |
| `lib/core/theme/ritmo_theme.dart` | 6 |

### Core Local Font Family (`coreDuplicateFont`)
Total: 153 occurrences

| File | Occurrences |
|---|---|
| `lib/core/theme/ritmo_theme.dart` | 43 |
| `lib/core/domain/agenda/agenda_renderer_registry.dart` | 19 |
| `lib/core/identity/identity_gate.dart` | 11 |
| `lib/core/security/app_lock_gate.dart` | 11 |
| `lib/core/domain/agenda/action_router.dart` | 9 |

### Core Scattered BackdropFilter (`coreScatteredBlur`)
Total: 6 occurrences

| File | Occurrences |
|---|---|
| `lib/core/theme/ritmo_theme.dart` | 2 |
| `lib/core/theme/tokens/ritmo_material.dart` | 1 |
| `lib/core/utils/ritmo_date_picker.dart` | 1 |
| `lib/core/utils/ritmo_toast.dart` | 1 |
| `lib/core/widgets/ritmo/ritmo_glass_surface.dart` | 1 |

### Core Manual BoxShadow (`coreManualShadow`)
Total: 9 occurrences

| File | Occurrences |
|---|---|
| `lib/core/theme/ritmo_theme.dart` | 2 |
| `lib/core/ai/web_bridge/chatgpt_mini_preview.dart` | 1 |
| `lib/core/observability/ritmo_friendly_error_pane.dart` | 1 |
| `lib/core/services/ad_service.dart` | 1 |
| `lib/core/utils/ritmo_date_picker.dart` | 1 |

### Raw Font Size (`rawFontSize`)
Total: 3649 occurrences

| File | Occurrences |
|---|---|
| `lib/features/supplementary_sports/presentation/ss_workout_session_screen.dart` | 80 |
| `lib/features/supplementary_sports/presentation/ss_home_dashboard_screen.dart` | 72 |
| `lib/features/today/presentation/insights_screen.dart` | 62 |
| `lib/features/profile/presentation/cycle_harmony_screen.dart` | 53 |
| `lib/features/supplementary_sports/presentation/ss_onboarding_flow.dart` | 49 |

### Raw Geometry Literals (`rawGeometryLiteral`)
Total: 4529 occurrences

| File | Occurrences |
|---|---|
| `lib/features/supplementary_sports/presentation/ss_home_dashboard_screen.dart` | 131 |
| `lib/features/supplementary_sports/presentation/ss_workout_session_screen.dart` | 96 |
| `lib/features/today/presentation/insights_screen.dart` | 93 |
| `lib/features/notes/presentation/screens/notebook_screen.dart` | 74 |
| `lib/features/worship/presentation/widgets/quran_dhikr_section.dart` | 65 |

