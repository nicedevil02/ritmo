# Ritmo Aurora Theme Migration Audit Report

Generated At: 2026-08-25T09:46:53.451930

## Audit Metrics Summary

| Metric | Key | Scope | Current Count | Baseline | Status |
|---|---|---|---|---|---|
| Hardcoded Colors | `hardcodedColors` | `lib/features/` | 1307 | 1307 | OK |
| Material Colors (non-transparent) | `materialColors` | `lib/features/` | 1967 | 1967 | OK |
| Old Opacity withOpacity() | `oldOpacity` | `lib/` | 0 | 0 | OK |
| Duplicate Local Font Family | `duplicateFont` | `lib/features/` | 163 | 163 | OK |
| Scattered BackdropFilter | `scatteredBlur` | `lib/features/` | 32 | 32 | OK |
| Manual BoxShadow | `manualShadow` | `lib/features/` | 208 | 208 | OK |
| Raw Scaffold | `rawScaffold` | `lib/features/` | 102 | 102 | OK |
| Page-level CircularProgressIndicator | `circularProgress` | `lib/features/` | 122 | 122 | OK |
| Local Directionality Override | `localDirectionality` | `lib/features/` | 325 | 325 | OK |
| Hardcoded Millisecond Duration | `hardcodedDuration` | `lib/features/` | 200 | 200 | OK |
| Core Hardcoded Colors | `coreHardcodedColors` | `lib/core/` | 415 | 415 | OK |
| Core Material Colors (non-transparent) | `coreMaterialColors` | `lib/core/` | 75 | 75 | OK |
| Core Local Font Family | `coreDuplicateFont` | `lib/core/` | 146 | 146 | OK |
| Core Scattered BackdropFilter | `coreScatteredBlur` | `lib/core/` | 6 | 6 | OK |
| Core Manual BoxShadow | `coreManualShadow` | `lib/core/` | 9 | 9 | OK |
| Raw Font Size | `rawFontSize` | `lib/features/` | 3491 | 3493 | IMPROVED (3491 < 3493) |
| Raw Geometry Literals | `rawGeometryLiteral` | `lib/features/` | 4379 | 4380 | IMPROVED (4379 < 4380) |

## Top Offenders by Metric

### Hardcoded Colors (`hardcodedColors`)
Total: 1307 occurrences

| File | Occurrences |
|---|---|
| `lib/features/supplementary_sports/presentation/ss_workout_session_screen.dart` | 157 |
| `lib/features/supplementary_sports/presentation/ss_home_dashboard_screen.dart` | 91 |
| `lib/features/profile/presentation/cycle_harmony_screen.dart` | 75 |
| `lib/features/worship/presentation/widgets/prayer_arc_hero.dart` | 64 |
| `lib/features/worship/presentation/theme/worship_sky_palette.dart` | 57 |

### Material Colors (non-transparent) (`materialColors`)
Total: 1967 occurrences

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
Total: 163 occurrences

| File | Occurrences |
|---|---|
| `lib/features/supplementary_sports/presentation/ss_exercise_library_screen.dart` | 20 |
| `lib/features/supplementary_sports/movement/presentation/movement_log_sheet.dart` | 18 |
| `lib/features/wellbeing/presentation/wellbeing_screen.dart` | 14 |
| `lib/features/supplementary_sports/movement/presentation/widgets/movement_session_recovery.dart` | 11 |
| `lib/features/today/presentation/widgets/daily_reflection_sheet.dart` | 10 |

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
Total: 208 occurrences

| File | Occurrences |
|---|---|
| `lib/features/supplementary_sports/presentation/ss_home_dashboard_screen.dart` | 9 |
| `lib/features/notes/presentation/screens/notebook_screen.dart` | 8 |
| `lib/features/profile/presentation/cycle_harmony_screen.dart` | 8 |
| `lib/features/today/presentation/widgets/dashboard/today_path_progress_banner.dart` | 8 |
| `lib/features/worship/presentation/widgets/quran_dhikr_section.dart` | 7 |

### Raw Scaffold (`rawScaffold`)
Total: 102 occurrences

| File | Occurrences |
|---|---|
| `lib/features/supplementary_sports/presentation/ss_workout_session_screen.dart` | 9 |
| `lib/features/supplementary_sports/presentation/ss_home_dashboard_screen.dart` | 4 |
| `lib/features/supplementary_sports/presentation/ss_plan_day_detail_screen.dart` | 4 |
| `lib/features/cycle/presentation/cycle_screen.dart` | 3 |
| `lib/features/cycle/presentation/onboarding/cycle_onboarding_shell.dart` | 3 |

### Page-level CircularProgressIndicator (`circularProgress`)
Total: 122 occurrences

| File | Occurrences |
|---|---|
| `lib/features/goals/presentation/widgets/create_goal_sheet.dart` | 3 |
| `lib/features/profile/presentation/backup_screen.dart` | 3 |
| `lib/features/supplementary_sports/presentation/ss_workout_session_screen.dart` | 3 |
| `lib/features/worship/presentation/widgets/prayer_city_picker.dart` | 2 |
| `lib/features/chat/presentation/ai_chat_screen.dart` | 2 |

### Local Directionality Override (`localDirectionality`)
Total: 325 occurrences

| File | Occurrences |
|---|---|
| `lib/features/supplementary_sports/presentation/ss_workout_session_screen.dart` | 12 |
| `lib/features/health/presentation/widgets/medications_section.dart` | 8 |
| `lib/features/today/presentation/insights_screen.dart` | 7 |
| `lib/features/profile/presentation/cycle_harmony_screen.dart` | 6 |
| `lib/features/worship/presentation/widgets/quran_dhikr_section.dart` | 6 |

### Hardcoded Millisecond Duration (`hardcodedDuration`)
Total: 200 occurrences

| File | Occurrences |
|---|---|
| `lib/features/worship/presentation/widgets/quran_dhikr_section.dart` | 10 |
| `lib/features/routines/presentation/widgets/planner_timeline_picker.dart` | 8 |
| `lib/features/supplementary_sports/presentation/ss_onboarding_flow.dart` | 7 |
| `lib/features/worship/presentation/widgets/worship_reminder_settings_sheet.dart` | 6 |
| `lib/features/health/presentation/health_screen.dart` | 5 |

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
Total: 146 occurrences

| File | Occurrences |
|---|---|
| `lib/core/theme/ritmo_theme.dart` | 43 |
| `lib/core/domain/agenda/agenda_renderer_registry.dart` | 16 |
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
Total: 3491 occurrences

| File | Occurrences |
|---|---|
| `lib/features/supplementary_sports/presentation/ss_workout_session_screen.dart` | 80 |
| `lib/features/supplementary_sports/presentation/ss_home_dashboard_screen.dart` | 72 |
| `lib/features/profile/presentation/cycle_harmony_screen.dart` | 53 |
| `lib/features/supplementary_sports/presentation/ss_onboarding_flow.dart` | 49 |
| `lib/features/notes/presentation/screens/notebook_screen.dart` | 47 |

### Raw Geometry Literals (`rawGeometryLiteral`)
Total: 4379 occurrences

| File | Occurrences |
|---|---|
| `lib/features/supplementary_sports/presentation/ss_home_dashboard_screen.dart` | 131 |
| `lib/features/supplementary_sports/presentation/ss_workout_session_screen.dart` | 96 |
| `lib/features/notes/presentation/screens/notebook_screen.dart` | 76 |
| `lib/features/worship/presentation/widgets/quran_dhikr_section.dart` | 65 |
| `lib/features/health/presentation/widgets/medication_form_sheet.dart` | 63 |

