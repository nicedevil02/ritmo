# Database Technical Debt Log

> Last updated: V92 migration cycle (August 2026)

## Purpose

این فایل یافته‌های تکنیکال دِبت دیتابیس را که طی بررسی‌های دوره‌ای شناسایی می‌شوند ثبت می‌کند. هر یافته با شماره نسخه‌ای که آن را رفع کرده برچسب می‌خورد.

---

## A-9: Living Code Coupling in Historical Migrations

**وضعیت:** ⚠️ بازمی‌ماند (هشدار اضافه شد، اما ریشه‌ی مشکل برطرف نشده)

**توضیح:**  
مهاجرت‌های V37، V44 و V45 به جای ثبت DDL ثابت، مستقیماً توابع زنده‌ی schema builder را صدا می‌زنند:

| مهاجرت | تابع زنده‌ی فراخوانده‌شده | خطر |
|---|---|---|
| V37 | `SupplementarySportsTables.create(db)` | اگر جدول جدید اضافه شود schema مهاجرت تغییر می‌کند |
| V44 | `AiTables.ensureSchema(db)` | همان |
| V45 | `DayPlanTables.ensureSchema(db)` | همان |

**راه‌حل صحیح (آینده):**  
این مهاجرت‌ها باید با DDL ثابت و inline بازنویسی شوند (در مهاجرت V100+) تا از coupling خارج شوند.

---

## A-7: Dual Column Names in `daily_reflections`

**وضعیت:** ✅ رفع شد (V91)

**توضیح:**  
جدول `daily_reflections` هم ستون camelCase و هم snake_case داشت:

- `reflectionNote` (legacy) → `reflection_text` (canonical)
- `goodThing` (legacy) → `wins` (canonical)
- `timestamp` (legacy) → `createdAt` (canonical)

**رفع:**  
V91 داده‌ها را از ستون‌های legacy به canonical مهاجرت داد. نویسنده‌های جدید دیگر به ستون‌های legacy نمی‌نویسند.

---

## A-5: Fragile Unique Index on `routine_completions`

**وضعیت:** ✅ رفع شد (V91)

**توضیح:**  
ایندکس unique قدیمی (`idx_uniq_routine_completions_routine_date_result`) فاقد ستون `completionTime` بود و می‌توانست یک completion واقعی را مسدود کند.

**رفع:**  
V91 ایندکس را حذف کرد و ایندکس جدید روی `(routineId, completionDate, completionTime, resultType)` ساخت.

---

## A-6: Nullable NOT NULL Columns in `skip_reasons`

**وضعیت:** ✅ رفع شد (V91)

**توضیح:**  
جدول `skip_reasons` در V70 بدون constraint NOT NULL ساخته شد. V56 آن را درست ساخته بود اما در مهاجرت‌های بعدی بازنویسی شد.

**رفع:**  
V91 جدول را با الگوی temp-table بازسازی کرد و مقادیر NULL را با default پر کرد.

---

## A-3: Orphan Migration Files

**وضعیت:** ✅ رفع شد

**توضیح:**  
دو فایل مهاجرت بدون ثبت در registry وجود داشتند:

- `migration_v70_engine_indexes.dart` → حذف شد (indexes در V91 اضافه شدند)
- `migration_v86_sports_session_log_fk_fix.dart` → حذف شد (بدون داده‌ی در معرض خطر)

---

## B-series: Parallel Table Structures

**وضعیت:** ✅ رفع شد (V92)

چندین ساختار جدول موازی در V92 یکپارچه شدند:

| منبع | مقصد |
|---|---|
| `energy_logs`, `mood_logs`, `bedtime_diagnostics`, `daily_checkins`, `daily_reflections`, `workout_recovery_logs` | `wellbeing_entry` |
| `workout_set_logs`, `ss_workout_set_log` | `ss_session_set_log` |
| `ss_ai_memory` | `ai_memory` (با ستون `scope`) |
| `cycle_logs` | `cycle_periods` + `cycle_day_logs` |
| `fasting_debt` | `worship_debts` |
| `course_active_timers` | `active_timers` |

---

## B-15: Dual-Write & Unified Wellbeing Table Migration
**وضعیت:** 🔄 در حال اجرا (فازهای ۱ تا ۱۱ بهبود حال و تعادل)

**توضیح:**
در فاز بازطراحی ماژول `wellbeing`، تمام ثبت‌های انرژی، حال، خواب و بازتاب از طریق درگاه متمرکز `WellbeingLogGateway` به جداول اختصاصی (`energy_logs`, `mood_logs`, `bedtime_diagnostics`, `daily_reflections`) و همزمان به صورت dual-write به جدول یکپارچهٔ `wellbeing_entry` نوشته می‌شوند. همچنین نتایج قطعی شاخص در جدول `wellbeing_daily` جهت ترسیم نمودارهای روند بلندمدت بدون نیاز به محاسبه مجدد ذخیره می‌گردند. در مهاجرت V100+، جداول اختصاصی legacy حذف و صرفاً `wellbeing_entry` و `wellbeing_daily` استفاده خواهند شد.

