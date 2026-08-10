# گزارش اجرای پرامپت ۰۷۲ (افق‌های برنامه‌ریزی: روز / هفته / ماه)

## ۱. خروجی فاز ۰ (یافته‌های کلیدی)
- **R-01**: آخرین نسخهٔ مهاجرت `V87` با کلاس `MigrationV87Planning` ثبت شد.
- **R-02**: الگوی مهاجرت `Migration` با `up`/`down` در `MigrationRunner` ثبت گردید.
- **R-03**: متد `DayPlanApplyExecutor.applyWithTxn` جهت دریافت `txn` در تراکنش اتمیک استخراج شد.
- **R-04**: اسکیما `day_plan_templates` از نام‌های قدیمی `title`/`plan_json` به `name`/`itemsJson` مهاجرت داده شد.
- **R-05 & R-06**: فرامین برنامه‌ریزی با دامنه‌های `routines` و `goals` در `RitmoCommandBus` پیاده‌سازی و ثبت شدند.

---

## ۲. جدول ۸۲ کار پرامپت ۰۷۲

| کد | عنوان | وضعیت | شاهد (مسیر فایل + نام کلاس/تابع) |
|---|---|---|---|
| R-01 | بررسی نسخهٔ دیتابیس | ✅ | `lib/core/database/database_helper.dart` |
| R-02 | الگوی پایهٔ مهاجرت | ✅ | `lib/core/database/migration/migration_runner.dart` |
| R-03 | استخراج applyDayPlan | ✅ | `lib/features/assistant/logic/assistant_action_registry.dart` |
| R-04 | اصلاح اسکیمای templates | ✅ | `lib/core/database/migration/migrations/migration_v87_planning.dart` |
| R-05 | بررسی DataDomain و حساسیت | ✅ | `lib/core/domain/commands/ritmo_command.dart` |
| R-06 | امضای CommandBus و PlanPreview | ✅ | `lib/core/domain/commands/ritmo_command_bus.dart` |
| R-07 | اجندای بازه‌ای DayAgendaService | ✅ | `lib/core/domain/agenda/day_agenda_service.dart` |
| R-08 | زمان و هفتهٔ شمسی | ✅ | `lib/core/time/ritmo_clock.dart` |
| R-09 | تنظیمات پیش‌فرض برنامه‌ریزی | ✅ | `lib/core/database/migration/migrations/migration_v87_planning.dart` |
| R-10 | خروجی موتور انرژی | ✅ | `lib/core/analytics/energy_analytics_engine.dart` |
| A-01 | ذخیرهٔ اتمیک هفته | ✅ | `lib/features/assistant/presentation/widgets/ai_weekly_planner_preview_sheet.dart` (`_saveWeeklyPlan`) |
| A-02 | حالت draftOnly شیت روزانه | ✅ | `lib/features/assistant/presentation/widgets/ai_day_planner_preview_sheet.dart` (`DayPlannerMode.draftOnly`) |
| A-03 | تبدیل جدول day_plan_templates | ✅ | `lib/core/database/migration/migrations/migration_v87_planning.dart` |
| A-04 | فرمان PlanningApplyWeekCommand | ✅ | `lib/core/domain/commands/catalog/planning_commands.dart` |
| A-05 | ثبت فرامین برنامه‌ریزی در Bus | ✅ | `lib/core/domain/commands/commands_registry.dart` (`registerAllRitmoCommands`) |
| A-06 | تبدیل آیتم‌های oneOff به task | ✅ | `lib/features/assistant/logic/assistant_action_registry.dart` |
| A-07 | تست رگرسیون اتمیک بودن هفته | ✅ | `test/core/domain/commands/planning_apply_week_atomic_test.dart` |
| A-08 | اعلام تضمین اتمیک در UI | ✅ | `lib/features/assistant/presentation/widgets/ai_weekly_planner_preview_sheet.dart` |
| D-01 | کلاس MigrationV87Planning | ✅ | `lib/core/database/migration/migrations/migration_v87_planning.dart` |
| D-02 | ثبت ۶ کلید تنظیمات | ✅ | `lib/core/database/migration/migrations/migration_v87_planning.dart` |
| D-03 | مدل‌های planning_models | ✅ | `lib/features/goals/models/planning_models.dart` |
| D-04 | مخزن PlanningRepository | ✅ | `lib/features/goals/logic/planning_repository.dart` |
| D-05 | مخزن PlanningReviewRepository | ✅ | `lib/features/goals/logic/planning_review_repository.dart` |
| D-06 | ماژول PlanningWeek | ✅ | `lib/features/goals/logic/planning_week.dart` |
| D-07 | ابطال کش و رویدادهای EventBus | ✅ | `lib/features/goals/logic/planning_repository.dart` |
| D-08 | تست‌های PlanningRepository | ✅ | `test/features/goals/planning_repository_test.dart` |
| D-09 | تست مهاجرت V87 | ✅ | `test/core/database/migration_v87_planning_test.dart` |
| D-10 | پاک‌سازی ماژول و تست ریست | ✅ | `lib/core/services/module_management_service.dart` & `test/core/services/planning_tables_reset_test.dart` |
| E-01 | مدل‌های بار و ظرفیت روزانه | ✅ | `lib/features/goals/logic/capacity_models.dart` (`DayLoad`, `DayCapacity`) |
| E-02 | محاسبه‌گر WeekCapacityCalculator | ✅ | `lib/features/goals/logic/week_capacity_calculator.dart` |
| E-03 | ضریب اجرای تاریخی ExecutionFactor | ✅ | `lib/features/goals/logic/execution_factor.dart` |
| E-04 | امتیازدهی شفاف CommitmentScorer | ✅ | `lib/features/goals/logic/commitment_scorer.dart` (`ScoreBreakdown`) |
| E-05 | موتور WeekAllocationEngine | ✅ | `lib/features/goals/logic/week_allocation_engine.dart` |
| E-06 | قاعده عدم انتقال خودکار بدهی | ✅ | `lib/features/goals/logic/week_allocation_engine.dart` |
| E-07 | دروازه شخصی‌سازی PersonalizationGate | ✅ | `lib/features/goals/logic/personalization_gate.dart` |
| E-08 | دلایل فارسی تخصیص | ✅ | `lib/features/goals/logic/commitment_scorer.dart` (`toReasonFa`) |
| E-09 | ۱۰ تست موتور تخصیص | ✅ | `test/features/goals/week_allocation_engine_test.dart` |
| E-10 | مستندسازی ثابت‌های ظرفیت | ✅ | `lib/features/goals/logic/week_capacity_calculator.dart` |
| U-01 | سوییچر سه‌حالته افق‌ها | ✅ | `lib/features/goals/presentation/planning_screen.dart` |
| U-02 | کنترلر PlanningController | ✅ | `lib/features/goals/logic/planning_controller.dart` |
| U-03 | کارت فرمان افق امروز | ✅ | `lib/features/goals/presentation/planning_screen.dart` (`_buildTodayView`) |
| U-04 | نمای افق این هفته با ۷ روز و نوار ظرفیت | ✅ | `lib/features/goals/presentation/planning_screen.dart` (`_buildWeekView`) |
| U-05 | شیت برنامه‌ریزی سریع ۹۰ ثانیه‌ای | ✅ | `lib/features/goals/presentation/widgets/week_planner_sheet.dart` |
| U-06 | ویزارد چندمرحله‌ای هفته | ✅ | `lib/features/goals/presentation/widgets/week_planner_sheet.dart` (`_buildWizardView`) |
| U-07 | منوی عملیات تعهد (انتقال، تقسیم، قفل، حذف) | ✅ | `lib/features/goals/presentation/planning_screen.dart` (`_handleContextMenuAction`) |
| U-08 | پیش‌نمایش Plan Diff در شیت | ✅ | `lib/features/goals/presentation/widgets/week_planner_sheet.dart` |
| U-09 | بخش افق این ماه | ✅ | `lib/features/goals/presentation/widgets/month_plan_section.dart` |
| U-10 | ادغام واقعیت‌های قطعی تایم‌لاین | ✅ | `lib/features/goals/presentation/widgets/month_plan_section.dart` |
| U-11 | کارت خلاصه تعهد در داشبورد | ✅ | `lib/features/today/presentation/widgets/dashboard/dashboard_module_summary.dart` |
| U-12 | ریتوال‌های هفتگی و میان‌هفته | ✅ | `lib/features/goals/presentation/planning_screen.dart` |
| U-13 | حالت‌های خالی و خطا | ✅ | `lib/features/goals/presentation/planning_screen.dart` |
| U-14 | تست‌های ویجت صفحه برنامه‌ریزی | ✅ | `test/features/goals/planning_screen_test.dart` |
| I-01 | پارسر خروجی هوش مصنوعی PlanningIntentParser | ✅ | `lib/features/assistant/logic/planning_intent_parser.dart` |
| I-02 | پرامپت سیستمی برنامه‌ریز | ✅ | `lib/core/ai/personas/assistant_charters.dart` (`system_prompt_planning`) |
| I-03 | سناریوهای سه‌گانه ذخیره زمان | ✅ | `lib/features/goals/logic/capacity_models.dart` (`ReserveProfile`) |
| I-04 | سناریوی تریدآف عددی | ✅ | `test/features/assistant/planning_intent_test.dart` |
| I-05 | یادگیری ترجیحات کاربر PlanningPreferenceLearner | ✅ | `lib/features/goals/logic/planning_preference_learner.dart` |
| I-06 | توضیح دلایل تخصیص بدون واژگان علّی | ✅ | `lib/features/goals/logic/commitment_scorer.dart` |
| I-07 | ۱۰ فرمان planning در کاتالوگ | ✅ | `lib/core/domain/commands/catalog/planning_commands.dart` |
| I-08 | پرسونای اهداف و دستیار سراسری | ✅ | `lib/core/domain/personas/persona_registry.dart` |
| I-09 | کانتکست تمیز برنامه‌ریزی بدون داده محرمانه | ✅ | `lib/features/assistant/logic/planning_intent_parser.dart` |
| I-10 | اعتبارسنج و گیت پرسونای برنامه‌ریزی | ✅ | `lib/features/assistant/logic/planning_intent_parser.dart` |
| I-11 | ره‌گیری رویدادها در EventBus | ✅ | `lib/features/goals/logic/planning_repository.dart` |
| I-12 | ۶ تست طلایی هوش مصنوعی | ✅ | `test/features/assistant/planning_intent_test.dart` |
| V-01 | محاسبه‌گر سنجه‌های مرور PlanningReviewCalculator | ✅ | `lib/features/goals/logic/planning_review_calculator.dart` |
| V-02 | شیت مرور هفته WeekReviewSheet | ✅ | `lib/features/goals/presentation/widgets/week_review_sheet.dart` |
| V-03 | مرور روایی ماهانه | ✅ | `lib/features/goals/presentation/widgets/month_plan_section.dart` |
| V-04 | بستن چرخه و ثبت مرور | ✅ | `lib/features/goals/presentation/widgets/week_review_sheet.dart` |
| V-05 | محاسبه کالیبراسیون و ضریب اجرا | ✅ | `lib/features/goals/logic/planning_review_calculator.dart` |
| V-06 | تست‌های مرور و کالیبراسیون | ✅ | `test/features/goals/planning_review_test.dart` |
| V-07 | اصل صداقت روانی در متون مرور | ✅ | `lib/features/goals/presentation/widgets/week_review_sheet.dart` |
| V-08 | یکپارچگی مرور با سیستم یادگیری | ✅ | `lib/features/goals/logic/planning_review_repository.dart` |
| Q-01 | محلی‌سازی و پشتیبانی راست‌به‌چپ (RTL) | ✅ | همهٔ ویجت‌های UI با ارقام فارسی و فونت Vazirmatn |
| Q-02 | تحلیل ایستا و سازگاری کد | ✅ | بدون خطای تایپ |
| Q-03 | مجموعه تست‌های خودکار کامل (بیش از ۲۵ تست) | ✅ | پوشش در ۸ فایل تست مجزا |
| Q-04 | کارایی بالا بدون N+1 | ✅ | کوئری‌های تک‌مرحله‌ای با JOIN |
| Q-05 | دسترسی‌پذیری و عملکرد منوی زمینه | ✅ | `planning_screen.dart` |
| Q-06 | پشتیبان‌گیری از ۴ جدول برنامه‌ریزی | ✅ | `lib/core/services/backup_service.dart` |
| Q-07 | ریست ماژول شامل جداول برنامه‌ریزی | ✅ | `lib/core/services/module_management_service.dart` |
| Q-08 | سند معماری سیستم برنامه‌ریزی | ✅ | `DESIGN_SYSTEM_PLANNING.md` |
| Q-09 | تمیزکاری و حذف کدهای مرده | ✅ | حذف کدهای ساختگی و حلقه‌های غیراستاندارد |
| Q-10 | گزارش نهایی اجرای پرامپت | ✅ | `prompts/072_REPORT.md` |

---

## ۳. تأیید اتمی بودن برنامهٔ هفتگی
- متد `PlanningApplyWeekCommand.run` تمامی روزها را درون یک تراکنش واحد (`ctx.txn.transaction`) اجرا می‌کند و در صورت بروز هرگونه استثنا، کل عملیات برگشت می‌خورد (`Rollback`).
- تست‌های مربوطه در `test/core/domain/commands/planning_apply_week_atomic_test.dart` با موفقیت پاس می‌شوند.

---

## ۴. جمع‌بندی
تمامی ۸۲ بند پرامپت ۰۷۲ بدون استثنا، بدون باقی گذاشتن کدهای ماک یا ساختگی، و با رعایت استانداردهای کامل مهندسی نرم‌افزار و معماری پروژه ریتمو پیاده‌سازی و نهایی شدند.
