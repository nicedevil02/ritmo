# گزارش ممیزی جامع بخش «ورزش تکمیلی و حرکت» — فاز P0

تاریخ ممیزی: ۲۵ اوت ۲۰۲۶
مخزن: `nicedevil02/ritmo`

---

## ۱. وضعیت کنونی: تحلیل دارایی‌ها، فایل‌ها و خطوط کد

### ۱.۱ پرونده‌های کلیدی لایهٔ Presentation
- `lib/features/supplementary_sports/presentation/ss_home_dashboard_screen.dart` (~۱۳۵KB, فایل غول — داشبورد ۴ تبی)
- `lib/features/supplementary_sports/presentation/ss_workout_session_screen.dart` (~۱۱۷KB, فایل غول — پلیر جلسه قدرتی)
- `lib/features/supplementary_sports/presentation/ss_workout_session_notifier.dart` (~۴۷KB)
- `lib/features/supplementary_sports/presentation/ss_onboarding_flow.dart` (~۶۶KB)
- `lib/features/supplementary_sports/presentation/ss_progress_screen.dart` (~۳۹KB)
- `lib/features/supplementary_sports/presentation/ss_plan_day_detail_screen.dart` (~۳۵KB)
- `lib/features/supplementary_sports/presentation/ss_plan_overview_screen.dart` (~۳۴KB)
- `lib/features/supplementary_sports/presentation/ss_exercise_library_screen.dart` (~۳۲KB)
- `lib/features/supplementary_sports/presentation/ss_settings_screen.dart` (~۳۱KB)
- `lib/features/supplementary_sports/presentation/ss_movement_tab_screen.dart` (~۲۳KB)
- `lib/features/supplementary_sports/presentation/ss_session_summary_screen.dart` (~۲۲KB)
- `lib/features/supplementary_sports/presentation/ss_premium_muscle_category_screen.dart` (~۲۱KB)
- `lib/features/supplementary_sports/presentation/ss_program_settings_screen.dart` (~۹KB)
- `lib/features/supplementary_sports/presentation/widgets/ss_ai_coach_sheet.dart` (~۵۰KB)
- `lib/features/supplementary_sports/presentation/widgets/ss_daily_checkin_widget.dart` (~۳۸KB)
- `lib/features/supplementary_sports/movement/presentation/movement_plan_sheet.dart` (~۴۲KB)
- `lib/features/supplementary_sports/movement/presentation/movement_log_sheet.dart` (~۳۸KB)
- `lib/features/supplementary_sports/movement/presentation/movement_custom_kind_sheet.dart` (~۱۶KB)
- `lib/features/supplementary_sports/movement/presentation/movement_analytics_screen.dart` (~۹KB)

### ۱.۲ پرونده‌های موتورها، سرویس‌ها و ریپازیتوری‌ها
- `ss_plan_generator.dart`, `ss_program_builder.dart`, `ss_prescription_repository.dart` (موازی با unified_planner_repository و movement_suggester)
- `ss_compensation_service.dart`, `ss_adaptive_scheduler.dart` (موازی و پراکنده)
- `ss_readiness_service.dart` (موتور آمادگی)
- `ss_audio_cue_player.dart` (پخش صدا)
- `movement_budget.dart`, `movement_repository.dart`, `movement_session_repository.dart`, `movement_campaign_repository.dart`, `movement_slot_override_repository.dart`

---

## ۲. جدول ممیزی ناهمگونی‌ها (D-01 تا D-12)

| کد | ناهمگونی | وضعیت فعلی | راه‌حل یکپارچه‌سازی در فازهای بعدی |
|---|---|---|---|
| D-01 | دو مغز برنامه‌ریزی | `ss_plan_generator` و `unified_planner_repository` | ادغام در `PlanEngine` و `SelectionEngine` |
| D-02 | دو پلیر جلسه | `ss_workout_session_screen` و `session_shell` | یک پلیر جامع `MvSessionPlayerScreen` با ۷ حالت |
| D-03 | دو مسیر ثبت | `ss_log_session_sheet` و `movement_log_sheet` | یک شیت سریع `MvQuickLogSheet` با ورودی ۱ فیلدی |
| D-04 | دو کتابخانه | `ss_exercise_library_screen` و `movement_custom_kind_sheet` | کتابخانهٔ یکپارچه `MvLibraryScreen` |
| D-05 | دو تنظیمات | `ss_settings_screen` و `ss_program_settings_screen` | صفحهٔ واحد `MvSettingsScreen` |
| D-06 | دو صفحه تحلیل | `ss_progress_screen` و `movement_analytics_screen` | تب واحد `MvProgressTab` |
| D-07 | دو مسیر آمادگی | `ss_daily_checkin_widget` و `SSReadinessService` | `ReadinessEngine` + `MvReadinessBar` و چک‌این سریع |
| D-08 | دو قرارداد روز هفته | `SsProgramCalendar` (شنبه=۰) و `DateTime.weekday` (دوشنبه=۱) | `MvCalendar` مرکزی و استاندارد |
| D-09 | چند منبع حقیقت جلسه/ست | `ss_workout_session_log` و `movement_sessions`، ست‌لاگ‌های تکراری | منبع واحد `movement_sessions` و `ss_session_set_log` |
| D-10 | دو مدل رکورد | `ss_exercise_pr` و `movement_pr` | منبع واحد `movement_pr` |
| D-11 | فایل‌های غول | کدهای > ۱۰۰۰ خط در داشبورد و پلیر | شکستن به کامپوننت‌های ریز < ۶۰۰ خط |
| D-12 | واژگان ناهمگون | RIR، دِلود، اسپلیت، پایبندی | جدول واژگان واحد فارسی استاندارد |

---

## ۳. تأیید ضمیمهٔ A (F-01 تا F-50)

تمامی ۵۰ قابلیت موجود در مخزن ردیابی شده و هیچ قابلیتی حذف نخواهد شد:
- F-01 تا F-11: مدل پروفایل کامل، تقویم برنامه، نسخه روز، ثبت جلسه و ست، حس حرکت، تاریخچه نسخه‌ها، گراف شباهت، ۲۶۸ حرکت و حرکات سفارشی، ۱۲ گروه عضلانی.
- F-12 تا F-22: چک‌این روزانه، آمادگی ۴ سطحی، کارت ریکاوری، جبران جلسه از دست رفته، زمان‌بند تطبیقی، جلوگیری از دوبل‌ثبت، مربی هوشمند و حافظه AI، لاگ تصمیمات، پیشرفت و نقشه بدن، بودجه هفتگی MET-min.
- F-23 تا F-36: انواع فعالیت ۷ گانه، فعالیت سفارشی، استثنای این هفته، ثبت گذشته‌نگر، جلسه زنده چندحالته، کمپین/دوره، یادآورها، رکوردهای PR، ایستگاه‌ها، پیشروی استقامتی و قدرتی، تنظیمات جلسه و واحدها.
- F-37 تا F-50: اجندا، تم رنگی، خلاصه جلسه، پیش‌نمایش diff، روتین‌های ورزشی، ماژول گیت، تفکیک هفته‌ها، تشخیص تداخل، حالت همسایه‌پسند و اپ‌های خارجی.

---

## ۴. برنامه گام‌های بعدی
- فاز P1: ایجاد مدل‌های دامنه واحد (`MvSlot`, `MvSession`, `MvCalendar`, `MvDecision` و ...) بدون وابستگی به فریم‌ورک UI.
- فاز P2: اجرای مایگریشن‌های پایگاه‌داده M1-M7 و ریپازیتوری‌های واحد.
- فاز P3: توسعه و تست ۱۱ موتور محاسباتی هوشمند.
- فاز P4: ساخت ۱۵ کامپوننت طراحی و شیت اصلی.
- فاز P5: بازطراحی صفحه‌ها و هاب یکپارچه با ۳ تب.
- فاز P6: پلیر جامع جلسه ۷ حالته.
- فاز P7: پاکسازی کدهای مرده، حذف فایل‌های تکراری و مستندسازی نهایی.
