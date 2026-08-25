# دفتر پورت و حذف کدهای موروثی ورزش تکمیلی (Port & Deletion Ledger)

این سند وضعیت تک‌تک فایل‌های موروثی (`ss_*` و `movement/**`) را قبل از هرگونه عملیات پاکسازی مشخص می‌کند. هیچ فایلی بدون داشتن وضعیت `PORTED` یا `INTENTIONALLY_DROPPED` در این جدول حذف نمی‌شود.

| مسیر فایل موروثی | اندازه | وضعیت | مقصد پورت / جایگزین زنده | دلیل حذف |
| :--- | :--- | :--- | :--- | :--- |
| `presentation/ss_home_dashboard_screen.dart` | 135KB | PORTED | `presentation/screens/mv_today_tab.dart` + `mv_hub_screen.dart` | هاب یکپارچه ۳ تب با کنترلر تمیز |
| `presentation/ss_workout_session_screen.dart` | 117KB | PORTED | `presentation/player/mv_session_player_screen.dart` | بازطراحی در ۵ قالب تخصصی پلیر |
| `presentation/ss_onboarding_flow.dart` | 66KB | PORTED | `presentation/screens/mv_onboarding_screen.dart` | جریان آنبوردینگ با سوال لنگر و تعهدات |
| `presentation/ss_premium_muscle_category_screen.dart` | 21KB | PORTED | `presentation/screens/mv_library_screen.dart` | تب ورزش‌ها و حرکات کتابخانه |
| `presentation/ss_progress_screen.dart` | 38KB | PORTED | `presentation/screens/mv_progress_tab.dart` | ۵ کارت تب پیشرفت با دو ارز سلامت |
| `presentation/ss_plan_overview_screen.dart` | 28KB | PORTED | `presentation/screens/mv_week_tab.dart` | ریل ۷ روزه هفته و کارت‌های لنگر |
| `presentation/ss_plan_day_detail_screen.dart` | 19KB | PORTED | `presentation/screens/mv_day_detail_screen.dart` | جزییات اسلات روز و تمرکز عضلانی |
| `presentation/ss_exercise_library_screen.dart` | 24KB | PORTED | `presentation/screens/mv_library_screen.dart` | کتابخانه یکپارچه با فیلتر آپارتمان |
| `presentation/ss_settings_screen.dart` | 15KB | PORTED | `presentation/screens/mv_settings_screen.dart` | تنظیمات متمرکز سیستم حرکت |
| `presentation/ss_program_settings_screen.dart` | 18KB | PORTED | `presentation/screens/mv_settings_screen.dart` | ادغام در تنظیمات متمرکز |
| `presentation/ss_movement_tab_screen.dart` | 32KB | PORTED | `presentation/screens/mv_hub_screen.dart` | تب‌های هاب اصلی حرکت |
| `presentation/ss_session_summary_screen.dart` | 22KB | PORTED | `presentation/player/mv_session_summary_screen.dart` | خلاصه تمرین با انتخاب ۳ دکمه و RPE |
| `presentation/ss_intro_screen.dart` | 12KB | PORTED | `presentation/screens/mv_onboarding_screen.dart` | صفحه معرفی آنبوردینگ |
| `presentation/ss_workout_session_notifier.dart` | 34KB | PORTED | `data/repositories/mv_session_repository.dart` | کنترلر و مخزن نشست‌های ورزشی |
| `presentation/ss_custom_exercise_sheet.dart` | 14KB | PORTED | `presentation/sheets/mv_custom_kind_sheet.dart` | شیت ساخت ورزش سفارشی دلخواه |
| `presentation/new_movement_section.dart` | 16KB | PORTED | `presentation/screens/mv_today_tab.dart` | ویجت بخش ورزش تب امروز |
| `presentation/widgets/ss_ai_coach_sheet.dart` | 10KB | PORTED | `presentation/sheets/mv_ai_coach_sheet.dart` | شیت بازطراحی‌شده مربی هوشمند |
| `presentation/widgets/ss_cant_today_sheet.dart` | 12KB | PORTED | `presentation/sheets/mv_cant_today_sheet.dart` | شیت امروز نمی‌توانم با اکشن لنگر |
| `presentation/widgets/ss_daily_checkin_widget.dart` | 8KB | PORTED | `presentation/sheets/mv_quick_checkin_sheet.dart` | ثبت سریع آمادگی روزانه |
| `presentation/widgets/ss_log_session_sheet.dart` | 14KB | PORTED | `presentation/sheets/mv_quick_log_sheet.dart` | ثبت سریع با چیپ‌های اخیر |
| `presentation/widgets/ss_program_diff_sheet.dart` | 9KB | PORTED | `presentation/sheets/mv_day_plan_sheet.dart` | مقایسه و تغییر برنامه روز |
| `presentation/widgets/ss_recovery_card.dart` | 6KB | PORTED | `presentation/components/mv_hero_card.dart` | کارت‌های وضعیت ریکاوری |
| `movement/presentation/movement_plan_sheet.dart` | 42KB | PORTED | `presentation/sheets/mv_day_plan_sheet.dart` | برنامه روز با ۷ فیلد و تعهدات |
| `movement/presentation/movement_log_sheet.dart` | 37.9KB | PORTED | `presentation/sheets/mv_quick_log_sheet.dart` | ثبت سریع با ۴ چیپ اخیر |
| `movement/presentation/movement_custom_kind_sheet.dart` | 15.8KB | PORTED | `presentation/sheets/mv_custom_kind_sheet.dart` | شیت ورزش سفارشی |
| `movement/presentation/movement_analytics_screen.dart` | 9.5KB | PORTED | `presentation/screens/mv_progress_tab.dart` | تب پیشرفت و آنالیز |
| `movement/presentation/planner/unified_week_planner_screen.dart` | 35.5KB | PORTED | `presentation/screens/mv_week_tab.dart` | تب برنامه هفته |
| `movement/presentation/planner/week_smart_fill_sheet.dart` | 14.1KB | PORTED | `domain/engines/plan_engine.dart` | موتور خودکار مرحله ۴ FILL |
| `movement/presentation/planner/movement_slot_actions_sheet.dart` | 11KB | PORTED | `presentation/sheets/mv_day_plan_sheet.dart` | اکشن‌های اسلات روز |
| `movement/presentation/session/movement_session_screen.dart` | 30.7KB | PORTED | `presentation/player/mv_session_player_screen.dart` | پلیر ۵ قالبه تمرین |
| `movement/presentation/session/session_shell.dart` | 19.8KB | PORTED | `presentation/player/mv_session_player_screen.dart` | ساختار فریم پلیر |
| `movement/presentation/session/session_template.dart` | 8KB | PORTED | `presentation/player/templates/` | ۵ قالب تخصصی پلیر |
| `movement/presentation/session/session_widgets.dart` | 12KB | PORTED | `presentation/components/` | کامپوننت‌های مشترک پلیر |
| `movement/presentation/session/open_session.dart` | 10KB | PORTED | `presentation/player/templates/mv_timed_template.dart` | پلیر زمان‌محور و تایمر آزاد |
| `movement/presentation/session/session_template_router.dart` | 8KB | PORTED | `application/mv_start_session_use_case.dart` | انتخاب قطعی قالب با resolveSessionMode |
| `movement/presentation/session/session_surface.dart` | 14KB | PORTED | `presentation/player/mv_session_player_screen.dart` | لایه سطح پلیر |
| `movement/presentation/session/movement_session_notifier.dart` | 16KB | PORTED | `data/repositories/mv_session_repository.dart` | کنترلر وضعیت اجرای تمرین |
| `movement/domain/movement_suggester.dart` | 17.4KB | PORTED | `domain/engines/plan_engine.dart` | موتور هوشمند برنامه‌ریزی ۶ مرحله‌ای |
| `movement/domain/movement_budget.dart` | 8KB | PORTED | `domain/engines/budget_engine.dart` | موتور بودجه با معادل متوسط WHO |
| `movement/domain/movement_kind.dart` | 9KB | PORTED | `domain/models/mv_movement_kind.dart` | مدل ایمیوتبل ورزش با ۴۹ نوع |
| `movement/domain/week_slot_resolver.dart` | 14KB | PORTED | `domain/engines/plan_engine.dart` | مراحل ۱ تا ۶ PlanEngine |
| `movement/domain/week_plan_item.dart` | 6KB | PORTED | `domain/models/mv_plan_result.dart` | مدل اسلات روز و نتایج برنامه |
| `movement/domain/movement_campaign.dart` | 8KB | PORTED | `domain/models/mv_campaign.dart` | مدل کمپین و دوره‌های هدف‌دار |
| `movement/domain/endurance_progression.dart` | 12KB | PORTED | `domain/engines/campaign_engine.dart` | موتور دوره‌بندی معکوس ۳ مرحله‌ای |
| `movement/domain/movement_plan_writer.dart` | 10KB | PORTED | `application/mv_save_commitment_use_case.dart` | ثبت و ذخیره برنامه و تعهدات |
| `movement/domain/movement_event.dart` | 5KB | PORTED | `domain/models/mv_session.dart` | رویدادها و متادیتاهای جلسه |
| `movement/domain/session_mode.dart` | 4KB | PORTED | `domain/models/mv_session_mode.dart` | مدل انوم حالت‌های پلیر |
| `movement/domain/movement_slot_override.dart` | 6KB | PORTED | `domain/models/mv_slot_override.dart` | بازنویسی و لغو موقت اسلات‌ها |
| `movement/domain/movement_reminder_defaults.dart` | 4KB | PORTED | `domain/engines/reminder_engine.dart` | یادآورهای تعهدات لنگر |
| `movement/domain/movement_session.dart` | 12KB | PORTED | `domain/models/mv_session.dart` | مدل جامع جلسه با ۷ فیلد متریک |
| `movement/data/unified_planner_repository.dart` | 22KB | PORTED | `data/repositories/mv_prescription_repository.dart` | مخزن برنامه‌های هفتگی |
| `movement/data/movement_reminder_service.dart` | 14KB | PORTED | `domain/engines/reminder_engine.dart` | سرویس اعلان‌ها |
| `movement/data/seed/movement_kinds_seed.dart` | 38KB | KEEP_AS_REFERENCE | `movement/data/seed/movement_kinds_seed.dart` | **منبع حقیقت ۴۹ ورزش (ممنوع‌الحذف)** |
| `data/repositories/ss_plan_generator.dart` | 24KB | PORTED | `domain/engines/plan_engine.dart` | تولید خودکار برنامه |
| `data/repositories/ss_program_builder.dart` | 28KB | PORTED | `domain/engines/plan_engine.dart` | ساختاردهی برنامه تمرینی |
| `data/repositories/ss_prescription_repository.dart` | 18KB | PORTED | `data/repositories/mv_prescription_repository.dart` | مخزن تجویز اسلات‌ها |
| `data/repositories/ss_session_repository_impl.dart` | 26KB | PORTED | `data/repositories/mv_session_repository.dart` | پیاده‌سازی مخزن جلسات |
| `data/repositories/ss_compensation_service.dart` | 12KB | PORTED | `domain/engines/substitution_engine.dart` | جبران کسری و جایگزینی |
| `domain/ss_readiness_service.dart` | 10KB | PORTED | `domain/engines/readiness_engine.dart` | سرویس سنجش آمادگی |
| `domain/ss_adaptive_scheduler.dart` | 16KB | PORTED | `domain/engines/adaptation_engine.dart` | زمان‌بندی انطباقی |
| `domain/ss_agenda_source.dart` | 8KB | PORTED | `application/mv_hub_controller.dart` | تامین داده‌های تقویم روز |
| `domain/ss_week_resolver.dart` | 14KB | PORTED | `domain/engines/plan_engine.dart` | حل تعارضات هفته |
| `domain/ss_program_calendar.dart` | 10KB | PORTED | `domain/models/mv_calendar.dart` | تقویم برنامه‌ریزی |
| `domain/ss_session_completion_gateway.dart` | 14KB | PORTED | `application/mv_finish_session_use_case.dart` | درگاه تکمیل جلسه و ذخیره PR |
| `data/seed/ss_exercise_animation_map.dart` | 28KB | KEEP_AS_REFERENCE | `data/seed/ss_exercise_animation_map.dart` | **پشتوانه ۳۲۱ انیمیشن (ممنوع‌الحذف)** |
| `data/seed/ss_exercise_farsi_names.dart` | 43KB | KEEP_AS_REFERENCE | `data/seed/ss_exercise_farsi_names.dart` | **پشتوانه ۸۰۴ نام فارسی (ممنوع‌الحذف)** |
