# پرامپت ۰۷۳ — بازطراحی و سخت‌گذاری ماژول «ورزش و حرکت»

> **مخاطب:** ایجنت کدنویس پروژهٔ Ritmo (Flutter + Riverpod + sqflite).
> **شمارهٔ سند:** `prompts/073.md` — گزارش اجباری: `prompts/073_REPORT.md`.
> **دامنه:** فقط ماژول «ورزش و حرکت»، زیرساخت داده/تکمیل/آژندای مرتبط، تست و مستندات همان دامنه.
> **مبنای ممیزی:** شاخهٔ `main` در وضعیت کنونی مخزن `Bahman1Dev/ritmo`؛ آخرین اسناد ممیزی شامل خطای کامپایل `SsProgramCalendar.currentWeek`، دوپاره‌گی plan/prescription، fallback تصادفی جلسه، readiness جعلی، completion غیراتمیک و ناسازگاری agenda هستند.

---

## ⛔ مادهٔ صفر — نقش تو و کارهای ممنوع

**تو در این پروژه طراح نیستی. معمار نیستی. تصمیم‌گیرندهٔ محصول نیستی. تو مجری هستی.**

تمام تصمیم‌های معماری، داده، UX، AI و تست در همین سند گرفته شده است. کدهای حیاتی در همین سند آمده‌اند. وظیفهٔ تو فقط این است که:

1. کدهای این سند را در مسیرهای مشخص‌شده قرار بدهی؛
2. آن‌ها را با امضاها/ایمپورت‌های واقعی کدبیس **به‌صورت مکانیکی** تطبیق بدهی؛
3. تست‌ها را اضافه و اجرا کنی؛
4. خروجی `flutter analyze` و تست‌ها را صادقانه گزارش بدهی؛
5. هیچ‌کدام از ۱۲۰ کار شناسه‌دار را جا نیندازی.

### ممنوعیت‌های مطلق

نقض هرکدام از این موارد = مردودی کل اجرا:

- ⛔ نوشتن هر Implementation Plan، roadmap، TODO.md، سند طراحی یا فازبندی جدید. **همین سند، برنامهٔ اجراست.**
- ⛔ اینکه فقط تحلیل بنویسی یا بگویی «باید انجام شود». باید کد، تست و گزارش واقعی تولید شود.
- ⛔ جاانداختن کارهای شناسه‌دار. اگر کاری انجام نشد، در گزارش با `❌` و دلیل فنی دقیق بنویس؛ جاانداختن بی‌صدا ممنوع.
- ⛔ «خلاقیت» روی منطق تعیین‌شده در این سند. فقط تطبیق مکانیکی با API واقعی مجاز است و باید در گزارش ثبت شود.
- ⛔ استفاده از مسیر فرضی `lib/features/sports/`؛ مسیر واقعی فعلی `lib/features/supplementary_sports/` است.
- ⛔ ساخت پکیج جدید، ماژول مجزا، سیستم دوم تقویم، readiness engine دوم یا منبع حقیقت دوم برای جلسات.
- ⛔ حذف دادهٔ کاربر، بازنویسی مخرب جداول، یا مهاجرت غیرقابل بازگشت بدون snapshot/transaction.
- ⛔ اضافه‌کردن dependency جدید. فقط از پکیج‌های موجود پروژه استفاده کن.
- ⛔ نوشتن query مستقیم در presentation برای منطق جدید؛ منطق باید به repository/domain/service منتقل شود. queryهای قدیمی را در همین موج فقط در مسیرهای تعیین‌شده اصلاح کن.
- ⛔ استفاده از رنگ/شعاع/فونت/فاصلهٔ هاردکد جدید. در کد جدید از Theme/Design Tokenهای موجود استفاده کن. کد قدیمی را فقط در محدودهٔ تسک‌های UX اصلاح کن.
- ⛔ `DateTime.now()` جدید در domain/data/AI. از `RitmoClock` یا زمان تزریق‌شده استفاده کن. `DateTime.now()` قدیمی را در فایل‌هایی که لمس می‌کنی تا حد امکان با سازوکار موجود پروژه جایگزین کن.
- ⛔ `catch (_) {}` خالی جدید. خطاها باید لاگ امن، state قابل بازیابی یا exception معنادار داشته باشند.
- ⛔ بازگشت به fallback تصادفی تمرین/حرکت. هیچ‌وقت حرکت نامرتبط، crossref تصادفی یا شش حرکت دلخواه جایگزین جلسهٔ درخواستی نکن.
- ⛔ ساختن PR آمادهٔ merge بدون گزارش کامل. PR باید Draft باشد.

### مکانیزم ضد فراموشی — اجباری

1. قبل از شروع، فهرست ۱۲۰ شناسهٔ انتهای سند را در TODO tracker داخلی‌ات کپی کن.
2. بعد از هر کار، وضعیتش را به‌روز کن؛ در یک لحظه فقط یک کار `in_progress` باشد.
3. قبل از گزارش نهایی، دستورهای زیر را اجرا کن و خروجی خلاصه‌شده را در گزارش بگذار:

```bash
grep -RIn "SsProgramCalendar.currentWeek\|finalExercises = allExercises\|workoutName\|targetTime\|durationMinutes" lib/features/supplementary_sports lib/core/domain/agenda || true
grep -RIn "module_supplementary_sports_enabled\|sports_detail_mode" lib/features/supplementary_sports lib/core | head -100
grep -RIn "ss_session_prescription\|ss_workout_session_log\|ss_workout_set_log" lib/features/supplementary_sports lib/core/database | head -200
flutter analyze
```

4. گزارش نهایی دقیقاً **۱۲۰ ردیف** دارد؛ به‌ازای هر شناسه: وضعیت، شاهد فایل/تست، دستور اجراشده، نتیجه.

---

## ۱. چی می‌سازیم؟ — نتیجهٔ نهایی محصول

ماژول «ورزش و حرکت» باید یک سیستم واحد و قابل اعتماد شود، نه چند نیم‌پیاده‌سازی موازی. ساختار چهار تب فعلی حفظ می‌شود:

```text
[امروز] [برنامه] [حرکت] [روند]
```

اما معنای هر تب اصلاح می‌شود:

| تب | مسئولیت محصولی | منبع حقیقت |
| --- | --- | --- |
| امروز | آمادگی صادقانه، چک‌این ۵ ثانیه‌ای، نسخهٔ امروز، شروع/ادامه/لغو | `ss_session_prescription` + readiness واحد |
| برنامه | برنامهٔ واقعی تاریخ‌دار، diff واقعی، قفل/دستی/بازسازی | `ss_session_prescription` + template اختیاری |
| جلسهٔ فعال | اجرای تمرین، ثبت هر ست، Undo، درد، یادداشت/RIR، اتمام اتمیک | `ss_workout_session_log` + set logs + prescription |
| حرکت | ثبت سریع فعالیت روزمره/هوازی، بودجهٔ واقعی، Undo حذف | `workout_logs` + `movement_kinds` |
| روند | پایبندی به جلسات برنامه‌ریزی‌شده، برنامه در برابر واقعیت، حجم، RPE/RIR، تعادل | منابع canonical بالا |

### معماری هدف — canonical model

سه مفهوم را برای همیشه جدا کن:

1. **`ss_workout_plan` = template قابل استفادهٔ مجدد**
   - فقط فهرست حرکت‌ها، ترتیب، ست/تکرار هدف، تخمین مدت.
   - تاریخ واقعی، وضعیت انجام، skip/move یا آمادگی در این جدول نیست.

2. **`ss_session_prescription` = نسخهٔ واقعی تاریخ‌دار**
   - هر روز یک رکورد؛ شامل `dateIso`, `cycleWeek`, `slotType`, `targetMinutes`, `intensityTier`, `status`, `isLocked`, `legacyPlanId`, `workoutPlanId`, `workoutLogId`.
   - Agenda و Today فقط همین را برای «چه چیزی امروز باید اتفاق بیفتد؟» می‌خوانند.

3. **`ss_workout_session_log` = اجرای واقعی**
   - شامل زمان شروع/پایان، تعداد انجام‌شده، احساس کلی، یادداشت و `prescriptionId`.
   - setهای انجام‌شده در `ss_workout_set_log` با `rir` و `note` ذخیره می‌شوند.

4. **`workout_logs` = رویداد مرکزی حرکت/مصرف انرژی**
   - برای هر جلسهٔ sports دقیقاً یک event با `sourceModule='ss_prescription'` و `sourceEntityId=<prescriptionId>`.
   - Movement manual logs هم در همین جدول‌اند اما `sourceModule='movement'` و `sourceEntityId=<movementEventId یا id>` دارند.

### قانون مهم دربارهٔ `sports_detail_mode`

`sports_detail_mode` فقط میزان جزئیات UI را تغییر می‌دهد:

- حالت ساده: نسخهٔ روز، مدت، شدت، تمرکز و دکمهٔ شروع/ثبت.
- حالت جزئی‌نما: template حرکتی، set/reps/weight/RIR، تعویض حرکت، یادداشت.

⛔ این mode هرگز تعیین‌کنندهٔ source of truth نیست. نباید با تغییر آن، مسیر داده از prescription به legacy یا برعکس سووییچ شود.

---

# فاز ۰ — شناسایی اجباری (R-01 … R-12)

> بدون تکمیل جدول یافته‌های فاز صفر، نوشتن حتی یک خط کد ممنوع است. یافته‌ها را در گزارش بنویس.

## R-01 — نسخهٔ دیتابیس و آخرین مهاجرت

```bash
grep -n "_dbVersion" lib/core/database/database_helper.dart
ls lib/core/database/migration/migrations/ | sort -V | tail -12
sed -n '1,140p' lib/core/database/migration/migration_runner.dart
```

مهاجرت این پرامپت باید دقیقاً `v90` باشد اگر نسخهٔ فعلی `89` است. اگر نسخه جلوتر رفته بود، `N+1` دقیق و فقط یک مهاجرت.

## R-02 — اسکیمای واقعی جداول sports/movement

```bash
sed -n '1,260p' lib/core/database/schema/tables/supplementary_sports_tables.dart
sed -n '1,220p' lib/core/database/schema/tables/sports_tables.dart
grep -RIn "sourceModule\|metricsJson\|caloriesKcal\|workout_logs" lib/core/database lib/features/supplementary_sports | head -120
```

ستون‌های واقعی `workout_logs`, `ss_session_prescription`, `ss_workout_session_log`, `ss_workout_set_log` را دقیق بنویس.

## R-03 — API زمان و ID

```bash
grep -RIn "class RitmoClock\|abstract class RitmoClock\|static.*now" lib/core/time lib/core/utils | head -80
sed -n '1,220p' lib/core/utils/ritmo_id_factory.dart
```

از این به بعد زمان جدید فقط از API موجود پروژه؛ ID جدید فقط از factory موجود، مگر جایی که این سند صراحتاً deterministic ID می‌خواهد.

## R-04 — امضای تقویم برنامه و mapping روز

```bash
sed -n '1,220p' lib/features/supplementary_sports/domain/ss_program_calendar.dart
grep -RIn "legacySsDayToRitmoDay\|ritmoDayToLegacySsDay" lib/ | head -50
```

تأیید کن `DateTime.weekday` با `1=Monday` و legacy plan با `1=Saturday` است و تنها محل تبدیل، `SsProgramCalendar` است.

## R-05 — وضعیت فعلی scheduler/generator

```bash
sed -n '1,240p' lib/features/supplementary_sports/domain/ss_adaptive_scheduler.dart
sed -n '1,360p' lib/features/supplementary_sports/data/repositories/ss_plan_generator.dart
```

سه خطا/ریسک زیر را صریح گزارش کن:
- فراخوانی تابع ناموجود؛
- تقسیم بر صفر deload؛
- fallback ناامن تمرین‌ها.

## R-06 — prescription repository/model

```bash
sed -n '1,260p' lib/features/supplementary_sports/domain/prescription/session_prescription.dart
sed -n '1,240p' lib/features/supplementary_sports/data/repositories/ss_prescription_repository.dart
sed -n '1,260p' lib/features/supplementary_sports/data/repositories/ss_program_builder.dart
```

## R-07 — completion gateway و movement repository

```bash
sed -n '1,240p' lib/features/supplementary_sports/domain/ss_session_completion_gateway.dart
sed -n '1,360p' lib/features/supplementary_sports/movement/data/movement_repository.dart
sed -n '1,220p' lib/features/supplementary_sports/movement/domain/movement_event.dart
```

## R-08 — session notifier/screen و بازیابی جلسه

```bash
sed -n '1,360p' lib/features/supplementary_sports/presentation/ss_workout_session_notifier.dart
sed -n '1,260p' lib/features/supplementary_sports/presentation/ss_workout_session_screen.dart
grep -RIn "SSWorkoutPlanKey\|SSWorkoutSessionScreen(" lib/features/supplementary_sports | head -80
```

## R-09 — readiness و Today dashboard

```bash
sed -n '1,240p' lib/features/supplementary_sports/domain/ss_readiness_service.dart
grep -n "_energyScore\|_recoveryScore\|_sleepScore\|_stressScore\|_activityScore\|_showBodyStatusDetailsSheet" -A20 -B10 lib/features/supplementary_sports/presentation/ss_home_dashboard_screen.dart
```

## R-10 — agenda source و DayAgendaService

```bash
sed -n '1,220p' lib/core/domain/agenda/sources/sports_agenda_source.dart
grep -RIn "SportsAgendaSource.load\|itemsForDate" lib/core/domain/agenda lib/features | head -80
```

## R-11 — AI coach، persona، command bus

```bash
sed -n '1,320p' lib/features/supplementary_sports/presentation/widgets/ss_ai_coach_sheet.dart
sed -n '1,260p' lib/core/domain/personas/persona_registry.dart
grep -RIn "class RitmoCommandBus\|class PlanPreview\|RitmoCommand" lib/core/domain lib/features/assistant | head -120
```

مرز privacy را بنویس: persona ورزش به `DataDomain.cycle` دسترسی ندارد مگر consent صریح و معماری مجاز وجود داشته باشد.

## R-12 — تست‌های موجود و قالب اجرای آن‌ها

```bash
find test/supplementary_sports -maxdepth 2 -type f -print | sort
find test -maxdepth 2 -type f | grep -Ei "agenda|movement|migration|sports" | sort
sed -n '1,220p' test/supplementary_sports/plan_generator_v2_test.dart
sed -n '1,260p' test/supplementary_sports/workout_session_state_test.dart
```

🛑 **دروازهٔ ۰:** اگر اسکیمای `workout_logs` یا API `RitmoCommandBus` مشخص نشد، توقف و سؤال کن؛ حدس نزن.

---

# فاز A — یکپارچه‌سازی معماری و حذف split-brain (A-01 … A-10)

## A-01 — تعریف مجدد مسئولیت plan/template

در تمام کدهایی که لمس می‌کنی، نام‌گذاری و کامنت‌ها را اصلاح کن تا `ss_workout_plan` فقط «template» باشد. هر جا planId به‌جای تاریخ/نسخه استفاده شده، باید یکی از این دو رخ دهد:

- اگر واقعاً template لازم است: `workoutPlanId` یا `legacyPlanId`;
- اگر جلسهٔ تاریخ‌دار لازم است: `prescriptionId`.

⛔ استفاده از `prescription.id` به‌عنوان `planId` ممنوع.

## A-02 — prescription به‌عنوان منبع برنامهٔ روز

Today، Agenda، Program، Progress و completion باید برای «جلسهٔ امروز» ابتدا `ss_session_prescription` را بخوانند. Legacy plan فقط برای حرکت‌های داخل جلسه/حالت detail استفاده می‌شود.

## A-03 — `sports_detail_mode` فقط UI

هر خوانش `sports_detail_mode` که باعث انتخاب منبع دادهٔ متفاوت می‌شود حذف/اصلاح شود. Mode فقط این‌ها را کنترل کند:

- نمایش کارت ساده یا set/reps؛
- نمایش/عدم نمایش swap و RIR؛
- متن‌های راهنما.

## A-04 — alias کلید ماژول

کلید canonical فعال‌سازی `module_sports_enabled` است. خوانش legacy `module_supplementary_sports_enabled` فقط داخل `ModuleGate` یا یک migration-compat helper مجاز است. هر direct read/write پراکنده را پیدا و به canonical key منتقل کن.

## A-05 — ارتباط prescription ↔ template

در `ss_session_prescription` ستون `workoutPlanId` اضافه شود. `legacyPlanId` فقط برای داده‌های قدیمی و fallback موقت است. در دادهٔ جدید `workoutPlanId` مقداردهی شود. اگر هر دو موجود ب����دند، `workoutPlanId` برنده است.

## A-06 — ارتباط prescription ↔ execution

در `ss_workout_session_log` ستون `prescriptionId` اضافه شود. هر session detail که از یک prescription شروع شده باید به همان لینک شود. completion با همان `prescriptionId` انجام می‌شود، نه با حدس تاریخ.

## A-07 — یک event مرکزی برای هر جلسه

برای هر prescription فقط یک `workout_logs` وجود دارد. deterministic key:

```text
sourceModule = ss_prescription
sourceEntityId = <prescription.id>
```

⛔ ساخت ID تصادفی جدید در retry ممنوع.

## A-08 — عدم ساخت data path جداگانه برای Movement

Movement manual logها همان `workout_logs` را با `sourceModule='movement'` استفاده می‌کنند. جدول/ذخیره‌سازی موازی جدید نساز. `movement_kinds` فقط taxonomy است، نه log.

## A-09 — event/invalidation پس از commit

پس از تغییر sports session/prescription/movement log، پس از commit موفق باید رویداد موجود پروژه (`RitmoEventBus` یا معادل فعلی) صدا زده شود تا dashboard/progress/budget invalidate شوند. event قبل از commit ممنوع.

## A-10 — سیاست privacy در AI

Sports AI فقط داده‌های sports/movement/sleep/recovery مجاز را با سازوکار privacy فعلی می‌خواند. دسترسی مستقیم به `/cycle` یا داده‌های حساس دیگر ممنوع، مگر command/bus privacy-aware موجود آن را صریحاً اجازه دهد. در صورت نیاز به چرخه، از readiness/consent abstraction استفاده کن.

---

# فاز D — دیتابیس، مهاجرت، repository و یکپارچگی داده (D-01 … D-14)

## D-01 — مهاجرت واحد v90

فایل جدید:

```text
lib/core/database/migration/migrations/migration_v90_sports_integrity.dart
```

کد پایه را عیناً قرار بده و فقط در صورت اختلاف امضای واقعی، تطبیق مکانیکی انجام بده:

```dart
import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:sqflite/sqflite.dart';

class MigrationV90SportsIntegrity extends Migration {
  @override
  int get version => 90;

  @override
  Future<void> up(Database db) async {
    await db.transaction((txn) async {
      await _safeAddColumn(txn, 'ss_session_prescription', 'workoutPlanId', 'TEXT');
      await _safeAddColumn(txn, 'ss_session_prescription', 'actualRpe', 'INTEGER');
      await _safeAddColumn(txn, 'ss_workout_session_log', 'prescriptionId', 'TEXT');
      await _safeAddColumn(txn, 'ss_workout_set_log', 'rir', 'INTEGER');
      await _safeAddColumn(txn, 'ss_workout_set_log', 'note', 'TEXT');

      await _safeAddColumn(txn, 'workout_logs', 'kind', 'TEXT');
      await _safeAddColumn(txn, 'workout_logs', 'sourceModule', "TEXT NOT NULL DEFAULT 'MOVEMENT'");
      await _safeAddColumn(txn, 'workout_logs', 'sourceEntityId', 'TEXT');
      await _safeAddColumn(txn, 'workout_logs', 'endedAt', 'INTEGER');
      await _safeAddColumn(txn, 'workout_logs', 'metMinutes', 'REAL NOT NULL DEFAULT 0');
      await _safeAddColumn(txn, 'workout_logs', 'caloriesKcal', 'REAL NOT NULL DEFAULT 0');
      await _safeAddColumn(txn, 'workout_logs', 'distanceMeters', 'REAL');
      await _safeAddColumn(txn, 'workout_logs', 'elevationMeters', 'REAL');
      await _safeAddColumn(txn, 'workout_logs', 'laps', 'INTEGER');
      await _safeAddColumn(txn, 'workout_logs', 'steps', 'INTEGER');
      await _safeAddColumn(txn, 'workout_logs', 'avgHeartRate', 'INTEGER');
      await _safeAddColumn(txn, 'workout_logs', 'venue', 'TEXT');
      await _safeAddColumn(txn, 'workout_logs', 'companions', 'TEXT');
      await _safeAddColumn(txn, 'workout_logs', 'metricsJson', 'TEXT');

      await txn.execute('''
        CREATE TABLE IF NOT EXISTS ss_daily_checkin (
          dateIso TEXT PRIMARY KEY,
          energy INTEGER,
          soreness INTEGER,
          fatigue INTEGER,
          painLevel INTEGER,
          availableMinutes INTEGER,
          note TEXT,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL
        );
      ''');

      await txn.execute('''
        UPDATE ss_session_prescription
        SET workoutPlanId = legacyPlanId
        WHERE (workoutPlanId IS NULL OR workoutPlanId = '')
          AND legacyPlanId IS NOT NULL
          AND legacyPlanId != '';
      ''');

      await txn.execute('''
        UPDATE workout_logs
        SET kind = type
        WHERE (kind IS NULL OR kind = '') AND type IS NOT NULL;
      ''');

      await txn.execute('''
        UPDATE workout_logs
        SET sourceEntityId = id
        WHERE sourceEntityId IS NULL OR sourceEntityId = '';
      ''');

      await txn.execute('''
        CREATE INDEX IF NOT EXISTS idx_ss_prescription_plan
        ON ss_session_prescription(workoutPlanId, dateIso);
      ''');
      await txn.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_ss_session_log_prescription
        ON ss_workout_session_log(prescriptionId)
        WHERE prescriptionId IS NOT NULL;
      ''');
      await txn.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_workout_logs_source_entity
        ON workout_logs(sourceModule, sourceEntityId)
        WHERE sourceEntityId IS NOT NULL;
      ''');
      await txn.execute('''
        CREATE INDEX IF NOT EXISTS idx_ss_set_log_exercise_time
        ON ss_workout_set_log(exercise_id, id);
      ''');
    });
  }

  Future<void> _safeAddColumn(
    DatabaseExecutor db,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any(
      (c) => c['name']?.toString().toLowerCase() == column.toLowerCase(),
    );
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition;');
    }
  }

  @override
  Future<void> down(Database db) async {
    // SQLite does not reliably support DROP COLUMN on all supported versions.
    // Destructive rollback is intentionally disabled to preserve user data.
  }
}
```

اگر هر ستون از قبل وجود دارد، `_safeAddColumn` باید آن را skip کند. اگر ایجاد unique index به‌علت دادهٔ duplicate موجود شکست خورد، قبل از ساخت index باید dedupe امن داخل همان migration انجام شود: به‌ازای `(sourceModule, sourceEntityId)` قدیمی‌ترین `loggedAt` نگه داشته و ردیف‌های تکراری حذف شوند.

## D-02 — ثبت migration و افزایش نسخه

- `MigrationV90SportsIntegrity()` را در `migration_runner.dart` با import و عضویت در `_migrations` ثبت کن.
- `_dbVersion` را دقیقاً یک واحد افزایش بده: اگر `89` بود به `90`.
- ⛔ هیچ migration اضافهٔ دیگری در این پرامپت نساز.

## D-03 — create-schema parity

`supplementary_sports_tables.dart` و `sports_tables.dart` باید برای دیتابیس تازه همان ستون‌های v90 را داشته باشند؛ یعنی fresh install بدون migration هم schema نهایی را بگیرد. تست migration/fresh-schema باید این parity را اثبات کند.

## D-04 — توسعهٔ مدل `SessionPrescription`

در `session_prescription.dart` دو فیلد اضافه کن:

```dart
final String? workoutPlanId;
final int? actualRpe;
```

و در constructor، `copyWith`, `toMap`, `fromMap` به‌صورت سازگار با دادهٔ قدیمی مدیریت شوند. الگوی دقیق:

```dart
SessionPrescription copyWith({
  // ...
  String? workoutPlanId,
  int? actualRpe,
  // ...
}) {
  return SessionPrescription(
    // ...
    workoutPlanId: workoutPlanId ?? this.workoutPlanId,
    actualRpe: actualRpe ?? this.actualRpe,
    // ...
  );
}

Map<String, dynamic> toMap() {
  return {
    // ...
    'workoutPlanId': workoutPlanId,
    'actualRpe': actualRpe,
    // ...
  };
}

factory SessionPrescription.fromMap(Map<String, dynamic> map) {
  return SessionPrescription(
    // ...
    workoutPlanId: map['workoutPlanId'] as String? ?? map['legacyPlanId'] as String?,
    actualRpe: map['actualRpe'] as int?,
    // ...
  );
}
```

⛔ `targetRpe` دیگر محل ذخیرهٔ RPE واقعی نیست؛ target هدف است، actual واقعیت.

## D-05 — repository خواندن prescription بر اساس template

در `SsPrescriptionRepository` متدهای زیر را اضافه کن:

```dart
Future<SessionPrescription?> getPrescriptionByPlanId(String planId) async {
  final db = await _database;
  final rows = await db.query(
    'ss_session_prescription',
    where: '(workoutPlanId = ? OR legacyPlanId = ?)',
    whereArgs: [planId, planId],
    orderBy: 'dateIso DESC',
    limit: 1,
  );
  if (rows.isEmpty) return null;
  return SessionPrescription.fromMap(rows.first);
}

Future<SessionPrescription?> getPrescriptionBySessionId(String sessionId) async {
  final db = await _database;
  final rows = await db.rawQuery('''
    SELECT p.*
    FROM ss_session_prescription p
    JOIN ss_workout_session_log s ON s.prescriptionId = p.id
    WHERE s.id = ?
    LIMIT 1
  ''', [sessionId]);
  if (rows.isEmpty) return null;
  return SessionPrescription.fromMap(rows.first);
}
```

اگر امضای `_database` private مانع است، در همان کلاس و با سبک موجود پروژه پیاده کن.

## D-06 — transaction-aware save prescription

برای استفادهٔ اتمیک در gateway، یک متد executor-based اضافه کن:

```dart
Future<void> savePrescriptionIn(
  DatabaseExecutor executor,
  SessionPrescription prescription,
) async {
  await executor.insert(
    'ss_session_prescription',
    prescription.toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}
```

متدهای قبلی را حذف نکن؛ callerهای فعلی نباید بشکنند.

## D-07 — MovementEvent با sourceEntityId

در `movement_event.dart` فیلد زیر را اضافه کن:

```dart
final String? sourceEntityId;
```

constructor، `fromMap`, `toMap`, `copyWith` را کامل به‌روز کن. برای سازگاری:

```dart
sourceEntityId: map['sourceEntityId'] as String? ?? map['id'] as String?,
```

و در `toMap`:

```dart
'sourceEntityId': sourceEntityId ?? id,
```

## D-08 — خواندن canonical kind در Movement tab

در `SSMovementTabScreen._openLogSheet` ساخت `MovementKind` ساختگی با `fromMap({'code': kindCode,...})` ممنوع است. اگر kindCode داری، ابتدا:

```dart
final kind = await MovementRepository.instance.getKind(kindCode);
```

اگر kind پیدا نشد، sheet را با مقدار null و پیام فارسی باز کن؛ taxonomy جعلی نساز.

## D-09 — idempotency سطح repository برای Movement

`MovementRepository.logEvent` باید قبل از افزایش `usageCount` بررسی کند event با همان `(sourceModule, sourceEntityId)` وجود دارد یا نه. اگر وجود دارد، باید update idempotent انجام شود و usageCount/PR دوباره افزایش نیابد. جزئیات در فاز S و کد gateway آمده است.

## D-10 — تاریخ شمسی واقعی در برنامه

هر نمایش تاریخ در Program/Today/Progress که اکنون با index یا تاریخ میلادی خام است، باید از `shamsi_date`/ابزار موجود پروژه برای عنوان فارسی استفاده کند. تاریخ ذخیره‌سازی همچنان ISO میلادی (`YYYY-MM-DD`) است؛ تبدیل فقط در presentation/domain formatting.

## D-11 — قفل و ویرایش دستی

هر rebuild/apply برنامه باید:

- `isLocked=1` را حفظ کند؛
- `source='MANUAL'` را بازنویسی نکند؛
- prescriptionهای DONE/PARTIAL را حذف نکند.

اگر builder فعلی این قانون را نقض می‌کند، اصلاحش کن و تست بده.

## D-12 — diff واقعی برنامه

`SsProgramDiffSheet` نباید با صفرهای ثابت صدا زده شود. Diff باید بر اساس prescriptionهای قدیم/جدید محاسبه شود و برای removed علامت منفی درست نشان دهد. حداقل فیلدهای مقایسه:

```text
dateIso, slotType, focusCodes, targetMinutes, intensityTier, workoutPlanId, isLocked, status
```

## D-13 — پاک‌سازی schema در presentation

`CREATE TABLE IF NOT EXISTS ss_weight_log` داخل `SSProgressScreen` باید حذف شود. اگر جدول لازم است، به schema/migration منتقل شود؛ presentation نباید schema بسازد.

## D-14 — transaction برای reset/regenerate/version restore

تمام عملیات چندمرحله‌ای برنامه باید transactional شود:

- snapshot؛
- delete crossrefها؛
- delete planها؛
- generate/insert planها؛
- insert crossrefها؛
- commit.

هیچ failureای نباید plan خالی/نیمه‌کاره بگذارد.

---

# فاز D/موتور — Scheduler، Generator و Agenda (ادامهٔ D و شروع S)

## D-15 — بازنویسی کامل `SSAdaptiveScheduler`

فایل:

```text
lib/features/supplementary_sports/domain/ss_adaptive_scheduler.dart
```

کلاس را با این پیاده‌سازی جایگزین کن. فقط importهای واقعی پروژه را در صورت نیاز تطبیق بده؛ منطق تغییر نکند:

```dart
import 'package:ritmo/core/utils/ritmo_id_factory.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/ss_plan_generator.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/ss_profile_repository.dart';
import 'package:ritmo/features/supplementary_sports/domain/ss_program_calendar.dart';
import 'package:sqflite/sqflite.dart';

/// Handles weekly adaptive plan regeneration based on recent progression signals
/// and completion of the current dated prescription cycle.
class SSAdaptiveScheduler {
  static const int _progressionWindowDays = 42;

  /// Ensures upcoming week's plan is generated adaptively.
  static Future<void> ensureUpcomingWeekReady(Database db, DateTime today) async {
    final profile = await SSProfileRepository.instance.getProfile();
    if (profile == null) return;

    final programStart = DateTime.tryParse(profile.programStartDate ?? '') ??
        DateTime(today.year, today.month, today.day);
    final nextWeekDate = today.add(const Duration(days: 7));
    final nextWk = SsProgramCalendar.cycleWeekFor(
      nextWeekDate,
      programStart: programStart,
    );

    final check = await db.query(
      'ss_workout_plan',
      where: 'id LIKE ?',
      whereArgs: ['plan_w${nextWk}_%'],
      limit: 1,
    );
    if (check.isNotEmpty) return;

    final signals = await _collectProgressionSignals(db, today);
    final currentWk = SsProgramCalendar.cycleWeekFor(today, programStart: programStart);
    final completionRate = await _calculateWeekCompletionRate(db, currentWk);

    var effectiveProfile = profile;
    if (completionRate < 0.5 && profile.daysPerWeek > 2) {
      effectiveProfile = profile.copyWith(daysPerWeek: profile.daysPerWeek - 1);
    }

    final isDeloadWeek = SsProgramCalendar.isDeloadWeek(
      nextWk,
      deloadEveryNWeeks: profile.deloadEveryNWeeks,
    );

    await db.transaction((txn) async {
      await SSPlanGenerator.generateWeeklyAndMonthlyPlan(
        txn,
        effectiveProfile,
        week: nextWk,
        progressionSignals: signals,
        isDeload: isDeloadWeek,
      );

      await txn.insert('ss_decision_log', {
        'id': RitmoIdFactory.ssDecision(),
        'userId': 'default',
        'decisionType': isDeloadWeek ? 'DELOAD_WEEK_APPLIED' : 'WEEK_REGENERATED',
        'rejectionReason': 'cycleWeek=$nextWk; completion=${(completionRate * 100).toStringAsFixed(0)}%; deload=$isDeloadWeek',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  static Future<Map<String, ProgressionSignal>> _collectProgressionSignals(
    Database db,
    DateTime now,
  ) async {
    final since = now
        .subtract(const Duration(days: _progressionWindowDays))
        .millisecondsSinceEpoch;
    final rows = await db.rawQuery('''
      SELECT exerciseId, feeling, loggedAt
      FROM ss_exercise_feeling_log
      WHERE loggedAt >= ?
      ORDER BY exerciseId ASC, loggedAt DESC
    ''', [since]);

    final byExercise = <String, List<String>>{};
    for (final row in rows) {
      final exerciseId = row['exerciseId']?.toString();
      final feeling = row['feeling']?.toString().toUpperCase();
      if (exerciseId == null || feeling == null) continue;
      byExercise.putIfAbsent(exerciseId, () => []).add(feeling);
    }

    final signals = <String, ProgressionSignal>{};
    byExercise.forEach((exerciseId, feelings) {
      final latest = feelings.take(3).toList(growable: false);
      if (latest.length < 2) {
        signals[exerciseId] = ProgressionSignal.maintain;
        return;
      }

      final latestTwo = latest.take(2).toList(growable: false);
      final hardCount = latestTwo.where((f) => f == 'HARD' || f == 'TOO_HARD').length;
      final easyCount = latestTwo.where((f) => f == 'EASY').length;

      if (hardCount >= 1) {
        signals[exerciseId] = ProgressionSignal.decrease;
      } else if (easyCount == 2) {
        signals[exerciseId] = ProgressionSignal.increase;
      } else {
        signals[exerciseId] = ProgressionSignal.maintain;
      }
    });
    return signals;
  }

  static Future<double> _calculateWeekCompletionRate(Database db, int week) async {
    final rows = await db.query(
      'ss_session_prescription',
      columns: ['status'],
      where: 'cycleWeek = ? AND slotType != ?',
      whereArgs: [week, 'REST'],
    );

    if (rows.isEmpty) return 1.0;

    var earned = 0.0;
    for (final row in rows) {
      final status = row['status']?.toString().toUpperCase();
      if (status == 'DONE') earned += 1.0;
      if (status == 'PARTIAL') earned += 0.5;
    }
    return (earned / rows.length).clamp(0.0, 1.0);
  }
}
```

### شرط‌های اجباری D-15

- `SsProgramCalendar.currentWeek` هرگز صدا زده نشود.
- `deloadEveryNWeeks=0` هیچ خطایی ندارد و هرگز deload نیست.
- completion دیگر از `ss_plan_schedule` یا تاریخچهٔ کلی خوانده نشود.
- decision log باید نتیجهٔ واقعی را بنویسد؛ اگر generator نتواند deload کند، log با `DELOAD_WEEK_APPLIED` ممنوع است.

## D-16 — اعمال واقعی deload در `SSPlanGenerator`

امضای `generateSingleDayPlan` را سازگار گسترش بده:

```dart
static Future<void> generateSingleDayPlan(
  DatabaseExecutor db,
  SsUserProfile profile, {
  required int week,
  required int dayOfWeek,
  Map<String, ProgressionSignal>? progressionSignals,
  bool isDeload = false,
}) async {
```

در `generateWeeklyAndMonthlyPlan` حتماً پاس بده:

```dart
await generateSingleDayPlan(
  db,
  profile,
  week: week,
  dayOfWeek: day,
  progressionSignals: progressionSignals,
  isDeload: isDeload,
);
```

در بخش volume/intensity این منطق را اعمال کن:

```dart
if (isDeload) {
  baseSets = max(1, baseSets - 1);
  baseReps = max(3, baseReps - 2);
  if (baseWeight != null) {
    baseWeight = max(1, (baseWeight! * 0.8).roundToDouble());
  }
}
```

اگر `isDeload=true` بود، progression signals نباید افزایش ایجاد کنند؛ فقط maintain/decrease مجاز است.

## D-17 — حذف fallback ناامن generator

این الگو را دقیقاً حذف کن:

```dart
if (finalExercises.isEmpty) {
  finalExercises = allExercises;
}
```

به‌جایش، بعد از fallback امن bodyweight/warmup/stretching/yoga:

```dart
if (finalExercises.isEmpty) {
  throw StateError(
    'SS_NO_SAFE_EXERCISES: No exercise satisfies equipment, skill, '
    'neighbor-friendly, and physical-limitation constraints.',
  );
}
```

این throw باید قبل از هر delete رخ دهد. در `generateWeeklyAndMonthlyPlan` هم اگر روزی throw کرد، transaction بیرونی rollback شود و plan قبلی حفظ شود.

## D-18 — حذف وزن‌های تخمینی ۵/۱۲/۲۰ کیلو

این منطق را حذف کن:

```dart
baseWeight = beginner ? 5.0 : intermediate ? 12.0 : 20.0;
```

به‌جایش:

```dart
double? baseWeight;
// Unknown load remains null until actual user history/input exists.
```

اگر history معتبر برای exercise داری، همان را به‌عنوان پیش‌فرض بگذار؛ وگرنه `targetWeight=null` ذخیره کن تا UI مقدار واقعی را از کاربر بگیرد.

## D-19 — progression محافظه‌کارانه و تک‌بُعدی

قانون اجباری:

- افزایش در یک هفته فقط یکی از این‌ها: **تکرار +۲** یا **یک ست** یا **وزن بر اساس history**؛ نه چند مورد هم‌زمان.
- کاهش می‌تواند محافظه‌کارانه‌تر باشد، ولی هرگز کمتر از ۱ ست و ۳ تکرار نرود.
- week 4 یا deload همیشه حجم/شدت را کم می‌کند و بر signals غلبه دارد.

نمونهٔ منطق مجاز:

```dart
if (!isDeload && signal == ProgressionSignal.increase) {
  if (exerciseReps < 15) {
    exerciseReps += 2;
  } else {
    exerciseSets += 1;
  }
}
```

⛔ افزایش هم‌زمان ست و وزن ممنوع.

## D-20 — بازنویسی کامل `SportsAgendaSource`

فایل:

```text
lib/core/domain/agenda/sources/sports_agenda_source.dart
```

با این پیاده‌سازی جایگزین کن؛ import/امضاها را فقط مکانیکی تطبیق بده:

```dart
import 'dart:convert';

import 'package:flutter/foundation.dart' hide Category;
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/features/supplementary_sports/domain/ss_program_calendar.dart';
import 'package:sqflite/sqflite.dart';

/// AgendaSource for the unified Sports & Movement domain.
class SportsAgendaSource {
  SportsAgendaSource({
    required this.prescriptionsByDate,
    required this.legacyPlansByDay,
    required this.sportsEnabled,
  });

  final Map<String, Map<String, dynamic>> prescriptionsByDate;
  final Map<int, List<Map<String, dynamic>>> legacyPlansByDay;
  final bool sportsEnabled;

  static Future<SportsAgendaSource> load(
    Database db,
    Map<String, String> settingsMap,
  ) async {
    final sportsEnabled = ModuleGate.instance.isEnabledFrom(settingsMap, 'module_sports_enabled');

    if (!sportsEnabled) {
      return SportsAgendaSource(
        prescriptionsByDate: const {},
        legacyPlansByDay: const {},
        sportsEnabled: false,
      );
    }

    final prescriptionsByDate = <String, Map<String, dynamic>>{};
    final legacyPlansByDay = <int, List<Map<String, dynamic>>>{};

    try {
      final rows = await db.query('ss_session_prescription');
      for (final row in rows) {
        final dateIso = row['dateIso']?.toString();
        if (dateIso != null && dateIso.isNotEmpty) {
          prescriptionsByDate[dateIso] = Map<String, dynamic>.from(row);
        }
      }
    } catch (e, st) {
      debugPrint('[SportsAgendaSource] prescription load error: $e\n$st');
    }

    try {
      final plans = await db.query('ss_workout_plan');
      for (final plan in plans) {
        final day = plan['dayOfWeek'] as int?;
        if (day != null) {
          legacyPlansByDay.putIfAbsent(day, () => []).add(Map<String, dynamic>.from(plan));
        }
      }
    } catch (e, st) {
      debugPrint('[SportsAgendaSource] legacy plan load error: $e\n$st');
    }

    return SportsAgendaSource(
      prescriptionsByDate: prescriptionsByDate,
      legacyPlansByDay: legacyPlansByDay,
      sportsEnabled: sportsEnabled,
    );
  }

  List<AgendaItem> itemsForDate(DateTime date, String dateStr) {
    if (!sportsEnabled) return const [];

    final prescription = prescriptionsByDate[dateStr];
    if (prescription != null) {
      return _itemsForPrescription(prescription, dateStr);
    }

    final legacyDay = SsProgramCalendar.ritmoDayToLegacySsDay(
      SsProgramCalendar.ritmoDayOf(date),
    );
    final plans = legacyPlansByDay[legacyDay] ?? const [];
    return plans.map((plan) => _legacyPlanItem(plan, dateStr)).toList(growable: false);
  }

  List<AgendaItem> _itemsForPrescription(
    Map<String, dynamic> prescription,
    String dateStr,
  ) {
    final slotType = prescription['slotType']?.toString().toUpperCase() ?? 'REST';
    if (slotType == 'REST') return const [];

    final id = prescription['id']?.toString() ?? 'ss_prescription_$dateStr';
    final title = prescription['headlineFa']?.toString().trim().isNotEmpty == true
        ? prescription['headlineFa'].toString()
        : 'تمرین ورزشی';
    final duration = prescription['targetMinutes'] as int? ?? 45;
    final status = prescription['status']?.toString().toUpperCase() ?? 'PLANNED';

    return [
      AgendaItem(
        id: 'sport_${id}_$dateStr',
        sourceId: id,
        domain: AgendaDomain.sport,
        itemType: AgendaItemType.flexible,
        title: title,
        subtitle: prescription['coachNoteFa'] as String?,
        dateStr: dateStr,
        durationMinutes: duration,
        category: Category.fitness,
        deepLink: AgendaDeepLink(domain: AgendaDomain.sport, targetId: id),
        completion: _completionFor(status),
        meta: {'prescription': prescription},
      ),
    ];
  }

  AgendaItem _legacyPlanItem(Map<String, dynamic> plan, String dateStr) {
    final planId = plan['id']?.toString() ?? 'unknown_plan';
    final title = _legacyTitle(plan);
    final duration = plan['estimatedMinutes'] as int? ?? 45;

    return AgendaItem(
      id: 'sport_${planId}_$dateStr',
      sourceId: planId,
      domain: AgendaDomain.sport,
      itemType: AgendaItemType.flexible,
      title: title,
      dateStr: dateStr,
      durationMinutes: duration,
      category: Category.fitness,
      deepLink: AgendaDeepLink(domain: AgendaDomain.sport, targetId: planId),
      completion: AgendaCompletion.pending,
      meta: {'legacyWorkoutPlan': plan},
    );
  }

  String _legacyTitle(Map<String, dynamic> plan) {
    final raw = plan['muscleGroups']?.toString();
    if (raw == null || raw.isEmpty) return 'تمرین ورزشی';
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List && decoded.isNotEmpty) {
        return 'تمرین ${decoded.join(' و ')}';
      }
    } catch (_) {
      // Fall through to raw text below.
    }
    return raw.trim().isEmpty ? 'تمرین ورزشی' : raw;
  }

  AgendaCompletion _completionFor(String status) {
    return switch (status) {
      'DONE' => AgendaCompletion.done,
      'PARTIAL' => AgendaCompletion.partial,
      'SKIPPED' => AgendaCompletion.skipped,
      'MOVED' => AgendaCompletion.none,
      _ => AgendaCompletion.pending,
    };
  }
}
```

### شرط‌های اجباری D-20

- `DateTime.weekday` مستقیم با legacy day مقایسه نشود.
- ستون‌های ناموجود `workoutName/title/timeOfDay/targetTime/durationMinutes` خوانده نشوند.
- prescription بر legacy غلبه دارد و duplicate نسازد.
- REST در agenda آیتم actionable نسازد.
- catch خالی ممنوع؛ در این کد فقط fallback parse JSON مجاز است.

## D-21 — هماهنگی Program Overview با تاریخ واقعی

`SSPlanOverviewScreen` باید به‌جای ساخت grid از `plan_w<week>_<day>` و index، از `dateIso` و `cycleWeek` استفاده کند. mapping روز فقط با `SsProgramCalendar`. عنوان روز باید نام فارسی + تاریخ شمسی واقعی باشد.

## D-22 — legacy week preferences

`ss_active_week` در SharedPreferences نباید منبع حقیقت باشد. فقط به‌عنوان UI cache مجاز است. week واقعی از `programStartDate` و تاریخ امروز با `SsProgramCalendar.cycleWeekFor` محاسبه شود.

---

# فاز S — جلسهٔ فعال، تکمیل اتمیک و پایداری داده (S-01 … S-14)

## S-01 — Resolve امن `planId` از prescription

در `SSWorkoutNotifier._initOrRestoreSession` هرگز `state.planId` را بدون بررسی به `ss_workout_exercise_crossref.planId` نفرست. متد زیر را اضافه کن:

```dart
Future<String?> _resolveWorkoutPlanId(Database db) async {
  final requested = state.planId;

  final planRows = await db.query(
    'ss_workout_plan',
    where: 'id = ?',
    whereArgs: [requested],
    limit: 1,
  );
  if (planRows.isNotEmpty) return requested;

  final prescriptionRows = await db.query(
    'ss_session_prescription',
    where: 'id = ? OR workoutPlanId = ? OR legacyPlanId = ?',
    whereArgs: [requested, requested, requested],
    orderBy: 'dateIso DESC',
    limit: 1,
  );
  if (prescriptionRows.isEmpty) return null;

  final prescription = prescriptionRows.first;
  final resolved = prescription['workoutPlanId']?.toString().trim().isNotEmpty == true
      ? prescription['workoutPlanId'].toString()
      : prescription['legacyPlanId']?.toString();

  if (resolved == null || resolved.isEmpty) return null;
  return resolved;
}
```

نتیجه را در state نگه دار. اگر null بود، error state بساز و هیچ جلسه‌ای شروع نکن.

## S-02 — حذف fallbackهای تصادفی جلسه

این دو بلاک را کامل حذف کن:

```dart
// Fallback 1: Query any crossRefs in database
// ... LIMIT 6
```

و:

```dart
// Fallback 2: Query directly from ss_exercise
// ... limit: 6
```

اگر crossref برای plan resolved پیدا نشد:

```dart
state = state.copyWith(
  isLoading: false,
  loadError: 'برنامهٔ این جلسه پیدا نشد. لطفاً از تب «برنامه» دوباره بساز یا یک تمرین دیگر انتخاب کن.',
  exercises: const [],
);
return;
```

⛔ شروع تمرین با شش حرکت دلخواه، یک باگ امنیتی/محصولی بحرانی است و هرگز نباید رخ دهد.

## S-03 — افزودن `loadError` و `prescriptionId` به state

در `SSWorkoutState` فیلدهای زیر را اضافه کن:

```dart
final String? prescriptionId;
final String? loadError;
final int? elapsedAnchorMs;
```

`copyWith` باید برای `loadError` امکان clear داشته باشد. الگوی پیشنهادی:

```dart
SSWorkoutState copyWith({
  // ...
  String? prescriptionId,
  String? loadError,
  bool clearLoadError = false,
  int? elapsedAnchorMs,
}) {
  return SSWorkoutState(
    // ...
    prescriptionId: prescriptionId ?? this.prescriptionId,
    loadError: clearLoadError ? null : (loadError ?? this.loadError),
    elapsedAnchorMs: elapsedAnchorMs ?? this.elapsedAnchorMs,
  );
}
```

`SSWorkoutPlanKey` و `SSWorkoutSessionScreen` را سازگار گسترش بده؛ `prescriptionId` optional باشد تا callerهای قدیمی نشکنند:

```dart
const SSWorkoutPlanKey({
  required this.planId,
  required this.dayName,
  this.prescriptionId,
});
```

## S-04 — فقط ست‌های انجام‌شده ذخیره شوند

در `finishAndLogWorkout` قبل از insert:

```dart
final completedSetRows = entry.setRows
    .where((setRow) => setRow.status == SetStatus.done)
    .toList(growable: false);

for (var i = 0; i < completedSetRows.length; i++) {
  final setRow = completedSetRows[i];
  final setId = 'set_${state.sessionId}_${entry.exercise.id}_${setRow.setNumber}';
  await txn.insert(
    'ss_workout_set_log',
    {
      'id': setId,
      'session_id': state.sessionId,
      'exercise_id': entry.exercise.id,
      'set_index': setRow.setNumber,
      'weight': setRow.weight,
      'reps': setRow.reps,
      'rir': setRow.rir,
      'note': entry.optionalNote,
      'feeling': entry.feeling != null ? _feelingStr(entry.feeling!) : null,
    },
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}
```

⛔ هیچ ست pending/current نباید به‌عنوان انجام‌شده persist شود.

## S-05 — ذخیرهٔ session با prescriptionId

هنگام insert/update `ss_workout_session_log`:

```dart
await txn.insert(
  'ss_workout_session_log',
  {
    'id': state.sessionId,
    'planId': resolvedPlanId,
    'prescriptionId': state.prescriptionId,
    'startedAt': state.startedAt,
    'finishedAt': finishedAt,
    'durationSeconds': durationSec,
    'completedExercisesCount': completedCount,
    'totalExercisesCount': state.exercises.length,
    'overallFeeling': overallFeeling != null ? _feelingStr(overallFeeling) : null,
    'note': _sessionNoteFromExercises(),
  },
  conflictAlgorithm: ConflictAlgorithm.replace,
);
```

متد `_sessionNoteFromExercises` یادداشت‌های non-empty را با نام حرکت ترکیب کند:

```dart
String? _sessionNoteFromExercises() {
  final notes = state.exercises
      .where((e) => (e.optionalNote ?? '').trim().isNotEmpty)
      .map((e) => '${e.exercise.name}: ${e.optionalNote!.trim()}')
      .toList(growable: false);
  if (notes.isEmpty) return null;
  return notes.join('\n');
}
```

## S-06 — Completion اتمیک در همان transaction

`finishAndLogWorkout` باید پس از insert session/set/feeling، در همان `db.transaction` تابع transaction-aware gateway را صدا بزند. اگر هر بخش fail شود، همه rollback شود.

امضای هدف:

```dart
await SsSessionCompletionGateway.completeDetailedSessionInTransaction(
  txn,
  prescriptionId: state.prescriptionId,
  sessionId: state.sessionId,
  actualMinutes: max(1, (durationSec / 60).round()),
  actualRpe: _estimatedRpeFromSets(),
  location: null,
  customNote: _sessionNoteFromExercises(),
);
```

`_estimatedRpeFromSets` فقط اگر RIR واقعی دارد:

```dart
int? _estimatedRpeFromSets() {
  final rirs = <int>[];
  for (final entry in state.exercises) {
    for (final set in entry.setRows) {
      if (set.status == SetStatus.done) rirs.add(set.rir);
    }
  }
  if (rirs.isEmpty) return null;
  final avgRir = rirs.reduce((a, b) => a + b) / rirs.length;
  return (10 - avgRir).round().clamp(1, 10);
}
```

اگر RPE محاسبه‌پذیر نیست، null بماند و در gateway با قاعدهٔ اعتبارسنجی سازگار شود.

## S-07 — بازنویسی `SsSessionCompletionGateway`

فایل:

```text
lib/features/supplementary_sports/domain/ss_session_completion_gateway.dart
```

پیاده‌سازی هدف:

```dart
import 'dart:convert';

import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/ss_prescription_repository.dart';
import 'package:ritmo/features/supplementary_sports/domain/prescription/session_prescription.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/movement_repository.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_event.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_kind.dart';
import 'package:sqflite/sqflite.dart';

class SsSessionCompletionGateway {
  static const String sourceModule = 'ss_prescription';

  /// Completes a prescription session atomically and idempotently.
  static Future<String?> completeSession({
    required String dateIso,
    int? actualMinutes,
    int? actualRpe,
    String? location,
    String? customNote,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final repo = SsPrescriptionRepository.instance;
    final prescription = await repo.getPrescriptionForDate(dateIso);
    if (prescription == null) return null;

    _validateCompletion(prescription, actualMinutes, actualRpe);

    String? completedLogId;
    await db.transaction((txn) async {
      completedLogId = await completeDetailedSessionInTransaction(
        txn,
        prescriptionId: prescription.id,
        actualMinutes: actualMinutes,
        actualRpe: actualRpe,
        location: location,
        customNote: customNote,
      );
    });

    if (completedLogId != null) {
      RitmoEventBus().fire(RitmoEvent(
        type: RitmoEventType.workoutLogChanged.code,
        timestamp: DateTime.now(),
        payload: {
          'source': sourceModule,
          'id': completedLogId,
          'prescriptionId': prescription.id,
        },
      ));
    }
    return completedLogId;
  }

  /// Transaction-aware variant. Never fires events here; caller fires after commit.
  static Future<String?> completeDetailedSessionInTransaction(
    DatabaseExecutor txn, {
    required String? prescriptionId,
    String? sessionId,
    int? actualMinutes,
    int? actualRpe,
    String? location,
    String? customNote,
  }) async {
    if (prescriptionId == null || prescriptionId.isEmpty) return null;

    final rows = await txn.query(
      'ss_session_prescription',
      where: 'id = ?',
      whereArgs: [prescriptionId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('SS_PRESCRIPTION_NOT_FOUND: $prescriptionId');
    }

    final prescription = SessionPrescription.fromMap(rows.first);
    _validateCompletion(prescription, actualMinutes, actualRpe);

    if (prescription.status == PrescriptionStatus.done &&
        prescription.workoutLogId != null &&
        prescription.workoutLogId!.isNotEmpty) {
      return prescription.workoutLogId;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final logId = prescription.workoutLogId?.trim().isNotEmpty == true
        ? prescription.workoutLogId!
        : 'wlog_ss_${prescription.id}';

    final intensity = _intensityFromRpe(actualRpe);
    final event = MovementEvent(
      id: logId,
      kindCode: _kindForSlot(prescription.slotType),
      durationMinutes: actualMinutes ?? prescription.targetMinutes,
      intensity: intensity,
      loggedAt: nowMs,
      location: location,
      sourceModule: sourceModule,
      sourceEntityId: prescription.id,
      note: customNote ?? prescription.headlineFa,
      metricsJson: jsonEncode({
        'prescriptionId': prescription.id,
        'sessionId': sessionId,
        'slotType': prescription.slotType.code,
        'targetRpe': prescription.targetRpe,
        'actualRpe': actualRpe,
        'cycleWeek': prescription.cycleWeek,
      }),
    );

    await MovementRepository.instance.upsertEventInTransaction(txn, event);

    final updated = prescription.copyWith(
      status: PrescriptionStatus.done,
      workoutLogId: logId,
      actualRpe: actualRpe,
      updatedAt: nowMs,
    );
    await txn.insert(
      'ss_session_prescription',
      updated.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return logId;
  }

  static void _validateCompletion(
    SessionPrescription prescription,
    int? actualMinutes,
    int? actualRpe,
  ) {
    if (prescription.slotType == SlotType.rest) {
      throw ArgumentError('Cannot complete a REST prescription as a workout.');
    }
    if (actualMinutes != null && (actualMinutes <= 0 || actualMinutes > 240)) {
      throw ArgumentError('actualMinutes must be between 1 and 240.');
    }
    if (actualRpe != null && (actualRpe < 1 || actualRpe > 10)) {
      throw ArgumentError('actualRpe must be between 1 and 10.');
    }
  }

  static MovementIntensity _intensityFromRpe(int? actualRpe) {
    if (actualRpe == null) return MovementIntensity.medium;
    if (actualRpe <= 5) return MovementIntensity.low;
    if (actualRpe >= 8) return MovementIntensity.high;
    return MovementIntensity.medium;
  }

  static String _kindForSlot(SlotType slotType) {
    return switch (slotType) {
      SlotType.strength => 'SS_SESSION',
      SlotType.cardio => 'CARDIO_GENERIC',
      SlotType.mobility => 'YOGA',
      SlotType.activeRest => 'WALKING',
      SlotType.rest => 'OTHER',
    };
  }
}
```

### شرط‌های اجباری S-07

- `targetRpe` هرگز با actual بازنویسی نشود.
- `location` در event ذخیره شود.
- retry باید همان `workoutLogId` را برگرداند.
- event bus فقط بعد از commit.
- REST workout completion نشود.

## S-08 — متد transaction-aware در `MovementRepository`

در `movement_repository.dart` متد عمومی زیر را اضافه کن. این متد transaction جدید نمی‌سازد و event fire نمی‌کند:

```dart
Future<Map<String, dynamic>> upsertEventInTransaction(
  DatabaseExecutor txn,
  MovementEvent event,
) async {
  final sourceEntityId = event.sourceEntityId ?? event.id;
  final existing = await txn.query(
    'workout_logs',
    where: '(id = ?) OR (sourceModule = ? AND sourceEntityId = ?)',
    whereArgs: [event.id, event.sourceModule, sourceEntityId],
    limit: 1,
  );

  final kind = await getKind(event.kindCode);
  final met = MovementLoadCalculator.metFor(
    baseMet: kind?.baseMet ?? 4.0,
    metLow: kind?.metLow ?? 3.0,
    metHigh: kind?.metHigh ?? 6.0,
    intensity: event.intensity,
  );
  final weightKg = await MovementLoadCalculator.getUserWeightKg(txn);
  final metMins = MovementLoadCalculator.metMinutes(
    met: met,
    durationMinutes: event.durationMinutes,
  );
  final kcal = MovementLoadCalculator.calories(
    met: met,
    weightKg: weightKg,
    durationMinutes: event.durationMinutes,
  );

  final fullEvent = event.copyWith(
    sourceEntityId: sourceEntityId,
    metMinutes: metMins,
    caloriesKcal: kcal,
  );

  if (existing.isNotEmpty) {
    final existingId = existing.first['id'].toString();
    await txn.update(
      'workout_logs',
      fullEvent.copyWith(id: existingId).toMap(),
      where: 'id = ?',
      whereArgs: [existingId],
    );
    return {'id': existingId, 'isPr': false, 'wasDuplicate': true};
  }

  await txn.insert('workout_logs', fullEvent.toMap());
  await txn.rawUpdate('''
    UPDATE movement_kinds
    SET usageCount = usageCount + 1, lastUsedAt = ?
    WHERE code = ?
  ''', [fullEvent.loggedAt, fullEvent.kindCode]);

  final prResult = await _checkAndRecordPrs(txn, fullEvent, kind);
  return {'id': fullEvent.id, 'isPr': prResult.isNewPr, 'prResult': prResult};
}
```

`logEvent` فعلی را طوری refactor کن که محاسبات مشترک تکرار نشود؛ اما تغییر API عمومی قدیمی مجاز نیست. retry نباید `usageCount` را دوباره افزایش دهد.

## S-09 — idempotency/debounce تکمیل ست

در notifier فیلد اضافه کن:

```dart
bool _isCompletingSet = false;
```

و ابتدای `_completeCurrentSet`:

```dart
void _completeCurrentSet() {
  if (_isCompletingSet) return;
  _isCompletingSet = true;
  try {
    // existing set completion logic
  } finally {
    _isCompletingSet = false;
  }
}
```

اگر منطق async شد، از lock ساده با `Completer` استفاده کن. دابل‌تاپ نباید دو ست را done کند.

## S-10 — Undo آخرین ست

در UI و notifier intent جدید بساز:

```dart
class UndoLastSet extends SSWorkoutIntent {
  const UndoLastSet();
}
```

رفتار:

- آخرین set با `SetStatus.done` در همان exercise به `current` برگردد؛
- اگر current set بعدی وجود دارد، به `pending` برگردد؛
- اگر exercise به‌اشتباه done شده، status آن به `current` برگردد؛
- تغییرات بلافاصله در SharedPreferences ذخیره شوند؛
- Undo فقط تا قبل از finish مجاز است.

## S-11 — دکمهٔ پایدار «درد/ناراحتی»

در صفحهٔ session یک اکشن پایدار اضافه کن:

```text
درد دارم ⚠️
```

رفتار:

1. تایمر pause شود؛
2. bottom sheet با سه انتخاب باز شود: `کاهش وزن/شدت`, `تعویض حرکت`, `پایان امن تمرین`;
3. انتخاب هر گزینه در `ss_decision_log` با `decisionType='PAIN_ACTION'` ثبت شود؛
4. اگر `پایان امن` انتخاب شد، جلسه partial ذخیره و prescription `PARTIAL` شود؛
5. اگر تعویض شد، همان swap امن با candidateهای فیلترشده انجام شود.

## S-12 — resurfacing یادداشت قبلی حرکت

هنگام load هر exercise، آخرین `note` non-empty از `ss_workout_set_log` برای همان `exercise_id` خوانده و در UI به‌صورت کارت کوچک نمایش داده شود:

```sql
SELECT note
FROM ss_workout_set_log
WHERE exercise_id = ? AND note IS NOT NULL AND note != ''
ORDER BY id DESC
LIMIT 1
```

یادداشت فعلی در همان فیلد به کاربر نشان داده شود تا ویرایش/تکمیل کند.

## S-13 — بازیابی صحیح زمان سپری‌شده

ذخیرهٔ `elapsedSeconds` به‌تنهایی کافی نیست. state باید anchor داشته باشد:

```dart
void _syncElapsedOnResume() {
  if (state.isTimerPaused) return;
  final anchor = state.elapsedAnchorMs;
  if (anchor == null || anchor <= 0) return;
  final now = DateTime.now().millisecondsSinceEpoch;
  final delta = ((now - anchor) / 1000).floor();
  if (delta <= 0) return;
  state = state.copyWith(
    elapsedSeconds: state.elapsedSeconds + delta,
    elapsedAnchorMs: now,
  );
}
```

در pause:

```dart
state = state.copyWith(isTimerPaused: true, elapsedAnchorMs: null);
```

در resume:

```dart
state = state.copyWith(
  isTimerPaused: false,
  elapsedAnchorMs: DateTime.now().millisecondsSinceEpoch,
);
```

⛔ timer نباید بعد از background هم reset شود، هم double-count کند.

## S-14 — خطای قابل بازیابی در UI جلسه

اگر `state.loadError != null`، UI باید صفحهٔ خطای فارسی بدهد با:

- توضیح مشکل؛
- دکمهٔ «بازگشت به برنامه»؛
- دکمهٔ «تلاش دوباره» که init را دوباره صدا می‌زند؛
- هیچ تایمر/جلسه‌ای شروع نشود.

این state باید از `isLoading=false` و `exercises=[]` متمایز باشد تا empty state با خطا قاطی نشود.

---

# فاز H — آمادگی صادقانه و تجربهٔ «امروز» (H-01 … H-08)

## H-01 — یک readiness engine واحد

`SSReadinessService` تنها منبع readiness sports است. محاسبات پراکنده در `SSHomeDashboardTabContent`، RecoveryCard، AI context یا جاهای دیگر حذف/به این service متصل شوند. هر مصرف‌کننده باید `SSReadinessVerdict` بگیرد، نه اینکه خودش score جعلی بسازد.

## H-02 — حذف پیش‌فرض‌های جعلی داشبورد

در `ss_home_dashboard_screen.dart` این مقداردهی‌ها ممنوع‌اند:

```dart
_energyScore = 82;
_recoveryScore = 74;
_sleepScore = 82;
_stressScore = 32;
_activityScore = 88;
```

اگر داده نباشد، UI باید به‌جای عدد نشان بدهد:

```text
دادهٔ کافی نیست
```

⛔ نباید با دادهٔ ساختگی به کاربر بگویی «وزنه را سنگین‌تر کن»، «گل��کوژن پر است»، «التهاب کم است» یا «کورتیزول متعادل است».

## H-03 — جدول چک‌این روزانه در همان مهاجرت v90

در `MigrationV90SportsIntegrity.up` این جدول را هم اضافه کن:

```sql
CREATE TABLE IF NOT EXISTS ss_daily_checkin (
  dateIso TEXT PRIMARY KEY,
  energy INTEGER,
  soreness INTEGER,
  fatigue INTEGER,
  painLevel INTEGER,
  availableMinutes INTEGER,
  note TEXT,
  createdAt INTEGER NOT NULL,
  updatedAt INTEGER NOT NULL
);
```

و create-schema parity را در `SupplementarySportsTables.create/ensure...` انجام بده. این جدول برای چک‌این ۵ ثانیه‌ای است و با `workout_recovery_logs` قدیمی سازگار می‌ماند.

## H-04 — بازنویسی `SSReadinessService`

فایل:

```text
lib/features/supplementary_sports/domain/ss_readiness_service.dart
```

اصلاحات اجباری:

1. مقدار اولیه `soreness` و `fatigue` باید `0` باشد، نه `1`.
2. اگر recovery/check-in نباشد، `hasRecoveryData=false`.
3. sleep فقط اگر مربوط به دیشب/امروز صبح باشد معتبر است؛ آخرین رکورد تاریخ‌دار بیش از ۳۶ ساعت باید stale محسوب شود.
4. خروجی `hasData=false` وقتی نه sleep معتبر هست نه check-in.
5. score=0 فقط برای دادهٔ ناکافی؛ نه برای tier full.
6. تصمیم‌ها محافظه‌کارانه و بدون ادعای زیستی نامعول باشند.

الگوی دقیق منطق:

```dart
if (!hasSleep && !hasCheckin) {
  return SSReadinessVerdict(
    tier: SSReadinessTier.full,
    reasonFa: 'اطلاعات کافی نیست؛ چک‌این ۵ ثانیه‌ای امروز را انجام بده.',
    emoji: '📊',
    score: 0,
    sleepMinutes: null,
    recoveryLoad: 0,
    hasData: false,
  );
}

if (painLevel >= 3) {
  return _verdict(
    SSReadinessTier.rest,
    'درد امروز جدی گزارش شده؛ تمرین اصلی لغو و ریکاوری/مشاوره پیشنهاد می‌شود.',
    '🩹',
    20,
  );
}

if (sleepMinutes != null && sleepMinutes < 300) {
  return _verdict(
    SSReadinessTier.minimal,
    'خواب دیشب کم بوده؛ نسخهٔ حداقلی برای حفظ زنجیره کافی است.',
    '⚡',
    40,
  );
}

if ((soreness + fatigue) >= 5 || availableMinutes <= 15) {
  return _verdict(
    SSReadinessTier.light,
    'بدن خسته است یا زمان کمی داری؛ نسخهٔ سبک پیشنهاد می‌شود.',
    '🔋',
    60,
  );
}

if ((soreness + fatigue) >= 2 || availableMinutes <= 30) {
  return _verdict(
    SSReadinessTier.light,
    'شرایط متوسط است؛ نسخهٔ سبک تا متوسط امن‌تر است.',
    '🟡',
    75,
  );
}

return _verdict(
  SSReadinessTier.full,
  'داده‌های امروز وضعیت مناسبی نشان می‌دهند؛ نسخهٔ برنامه‌ریزی‌شده را انجام بده.',
  '🔥',
  90,
);
```

⛔ اگر `hasData=false` است، recommendation باید «ثبت داده/چک‌این» باشد، نه تمرین کامل.

## H-05 — چک‌این ۵ ثانیه‌ای در Today

در تب «امروز» یک کارت compact اضافه کن با چهار ورودی سریع:

```text
انرژی: ۱ تا ۵
کوفاتگی: ۰ تا ۳
خستگی: ۰ تا ۳
درد: ۰ تا ۵
زمان موجود: ۱۰ / ۲۰ / ۳۰ / ۴۵+ دقیقه
```

ذخیره در `ss_daily_checkin`، سپس invalidate readiness و Today. UI نباید بیش از ۵ ثانیه طول بکشد؛ هیچ فرم بلند/الزامی نساز.

## H-06 — خروجی آمادگی باید actionable باشد

بر اساس verdict، چهار اکشن واقعی بساز:

| Tier | اکشن اصلی | اکشن دوم |
| --- | --- | --- |
| full | شروع نسخهٔ کامل | مشاهدهٔ جزئیات |
| light | تبدیل امروز به نسخهٔ سبک | شروع نسخهٔ سبک |
| minimal | تبدیل به ۱۰/۱۵ دقیقه | شروع حداقلی |
| rest | تبدیل به استراحت/ریکاوری | انتقال به فردا |

این اکشن‌ها باید `ss_session_prescription.status/intensityTier/targetMinutes/slotType` را واقعاً تغییر دهند؛ فقط بستن sheet کافی نیست.

## H-07 — «امروز نمی‌شود» واقعی

`ss_cant_today_sheet.dart` و sheet قدیمی Today باید واقعاً یکی از این transitionها را انجام دهند:

- `MOVED` + `movedToDateIso=<tomorrow>`;
- `SKIPPED` + دلیل کاربر؛
- تبدیل به `LIGHT/MINIMAL` با `targetMinutes` کمتر.

پس از تغییر، Agenda/Today/Program invalidate شوند. فقط `Navigator.pop` ممنوع.

## H-08 — حذف دو مسیر readiness

هر readiness/RecoveryCard جداگانه باید از `SSReadinessService.evaluateToday()` استفاده کند. اگر RecoveryCard فقط نمایش است، آن را نگه دار؛ اگر محاسبه می‌کند، محاسبه را حذف کن.

---

# فاز M — Movement: ثبت سریع، بودجه، پیشنهاد و PR (M-01 … M-10)

## M-01 — Quick log دو ضربه‌ای

در تب «حرکت» چهار اکشن سریع بالای صفحه بساز:

```text
پیاده‌روی ۲۰′ 🚶 | دویدن ۲۰′ 🏃 | دوچرخه ۳۰′ 🚴 | یوگا ۱۵′ 🧘
```

ضربه اول = انتخاب، ضربه دوم = تأیید و ثبت. مقادیر پیش‌فرض intensity=`medium` و kind canonical از `movement_kinds` خوانده شود.

## M-02 — canonical MovementKind در همهٔ مسیرها

هیچ جایی `MovementKind.fromMap` ساختگی با `titleFa=kindCode` ساخته نشود. اگر kindCode وجود دارد:

```dart
final kind = await MovementRepository.instance.getKind(kindCode);
if (kind == null) {
  // Show recoverable Persian error; do not fabricate taxonomy.
}
```

## M-03 — درصد بودجه با target واقعی

هر محاسبه‌ای شبیه زیر را پیدا و اصلاح کن:

```dart
_calculatedMetMinutes / 500.0
```

به:

```dart
snapshot.weeklyMetMinutesTarget > 0
    ? achieved / snapshot.weeklyMetMinutesTarget
    : 0.0
```

target کاربر از `movement_budget` یا تنظیمات موجود خوانده شود؛ هاردکد ۵۰۰ فقط fallback اولیه است.

## M-04 — برچسب فارسی در timeline

در `SSMovementTabScreen` و analytics، به‌جای `e.kindCode`:

```dart
final kind = await MovementRepository.instance.getKind(e.kindCode);
final title = kind?.titleFa ?? 'فعالیت حرکتی';
```

برای performance، map از code→kind کش شود تا در هر row query تکراری نزنی.

## M-05 — حذف با تأیید و Undo

Swipe-delete فعلی نباید مستقیم حذف کند. رفتار:

1. `Dismissible` فقط آیتم را به‌صورت optimistic پنهان کند یا تأیید اولیه بگیرد؛
2. SnackBar با «حذف شد» و اکشن «واگرد» نشان بده؛
3. اگر Undo زده شد، event همان با همان id بازیابی شود؛
4. اگر Undo نشد، delete واقعی اجرا شود.

برای Undo نیاز به snapshot کامل event قبل از حذف داری. اگر restore دقیق PR را سخت می‌کند، Undo باید قبل از delete فیزیکی با تأخیر ۴ ثانیه انجام شود.

## M-06 — محاسبهٔ مجدد PR پس از edit/delete

در `MovementRepository.updateEvent` و `deleteEvent` بعد از تغییر:

```text
movement_pr برای همان kind/prType از روی workout_logs معتبر بازمحاسبه شود.
```

حداقل قاعده:
- اگر PR فعلی به event حذف/کاهش‌شده لینک بود، max جدید از بقیه eventها محاسبه شود؛
- اگر هیچ eventی نماند، رکورد PR حذف شود؛
- PR جدید بعد از update بزرگ‌تر شود، جایگزین شود.

## M-07 — `logEvent` واقعاً idempotent

در `logEvent` فعلی از همان منطق `upsertEventInTransaction` استفاده کن. `ConflictAlgorithm.replace` به‌تنهایی کافی نیست چون `usageCount` و PR side effect دارند. retry با همان id/sourceEntityId باید:

- یک ردیف بسازد/به‌روز کند؛
- usageCount فقط یک بار؛
- PR فقط یک بار/بر اساس max واقعی.

## M-08 — اصلاح `MovementSuggester`

فایل:

```text
lib/features/supplementary_sports/movement/domain/movement_suggester.dart
```

قواعد:

1. confidence ثابت ۰٫۹ ممنوع. مقدار واقعی از تعداد داده، تطابق محدودیت، فصل، بودجه و recency محاسبه شود؛ بازه ۰٫۲ تا ۰٫۹.
2. ادعای ثابت «شنا ۱۲۰ MET-min» حذف شود. باید با calculator واقعی:

```dart
final met = MovementLoadCalculator.metFor(...);
final metMinutes = MovementLoadCalculator.metMinutes(
  met: met,
  durationMinutes: suggestedMinutes,
);
```

3. متن دلیل باید عدد واقعی را نشان دهد:

```dart
'شنا با شدت ملایم حدود ${metMinutes.round()} MET-min از کسری هفته را جبران می‌کند.'
```

4. اگر budgetGap <= 0، پیشنهاد باید حفظ ریتم/تنوع باشد، نه جبران کسری.
5. اگر داده کافی نیست، confidence پایین و متن محتاطانه.

## M-09 — گزینه‌های پیشرفته در sheet ثبت حرکت

`movement_log_sheet.dart` باید به‌صورت پیش‌فرض فقط این‌ها را نشان دهد:

```text
نوع حرکت، مدت، شدت، یادداشت کوتاه
```

فیلدهای پیشرفته (`distance`, `elevation`, `laps`, `heartRate`, `venue`, `companions`) داخل `<details>`/ExpansionTile یا معادل Flutter موجود باشند. Quick log نباید کاربر را با فرم بلند خسته کند.

## M-10 — نمایش بدهی/بودجهٔ انسانی

در WeeklyBudgetCard علاوه بر درصد، متن فارسی بساز:

- اگر عقب است: «برای رسیدن به هدف هفته، حدود X دقیقه فعالیت متوسط مانده است.»
- اگر جلو است: «از هدف هفته جلوتر هستی؛ امروز می‌تواند سبک باشد.»
- اگر داده نیست: «هدف هفتگی را تنظیم کن.»

محاسبهٔ X باید از MET واقعی حرکت پیشنهادی و budgetGap باشد، نه تقسیم سادهٔ خام.

---

# فاز P — روند، تحلیل و گزارش واقعی (P-01 … P-08)

## P-01 — Progress باید هر دو مسیر completion را ببیند

در `SSProgressScreen` فقط خواندن این مورد کافی نیست:

```sql
SELECT ... FROM workout_logs WHERE sourceModule='ss_prescription'
```

باید علاوه بر آن، sessionهای detail قدیمی/جاری را هم بگیرد:

```sql
SELECT id, startedAt, finishedAt, durationSeconds, completedExercisesCount,
       totalExercisesCount, overallFeeling, prescriptionId
FROM ss_workout_session_log
WHERE finishedAt IS NOT NULL
```

و آن‌ها را با eventهای مرکزی merge کند. قانون dedupe:

- اگر `prescriptionId` مشترک است، رکورد canonical همان prescription است؛
- اگر event مرکزی و session detail هر دو هستند، فقط یک نمونه در شمارش بیاید؛
- duration واقعی session بر تخمین prescription غلبه دارد.

## P-02 — adherence بر اساس جلسات برنامه‌ریزی‌شده

Streak روزهای تقویمی معیار ورزش نیست. متریک اصلی:

```text
Adherence = جلسات DONE + 0.5*PARTIAL / جلسات غیر REST برنامه‌ریزی‌شده
```

برای هفته/ماه جاری. روزهای REST نباید streak را بشکنند یا کاذب پر کنند.

## P-03 — Streak بر اساس scheduled sessions

Current streak یعنی چند جلسهٔ برنامه‌ریزی‌شدهٔ متوالی انجام شده، نه چند روز پشت سرهم. اگر کاربر دوشنبه و پنجشنبه تمرین دارد، انجام هر دو یعنی streak=2؛ روزهای بینشان break نیستند.

## P-04 — Planned vs Actual

برای هر هفته گزارش کن:

```text
plannedMinutes = SUM(targetMinutes) برای غیر REST
actualMinutes = SUM(duration واقعی/event)
adherencePercent = actual / planned
```

در UI چارت دو سری «برنامه» و «واقعیت» نشان بده. اگر داده نبود، صفر جعلی نساز؛ empty state بنویس.

## P-05 — شمارش full/light/minimal

از `intensityTier` و `status` در prescriptionها گزارش بگیر:

```text
نسخهٔ کامل انجام‌شده
نسخهٔ سبک انجام‌شده
نسخهٔ حداقلی انجام‌شده
جلسات جابه‌جاشده
جلسات ردشده
```

این بهتر از streak خام است و رفتار واقعی کاربر را نشان می‌دهد.

## P-06 — حجم هفتگی، RPE و RIR

در detail mode از `ss_workout_set_log` محاسبه کن:

```text
weeklyVolume = SUM(weight * reps)
setsDone = COUNT(*)
averageRir = AVG(rir)
averageActualRpe = AVG(actualRpe) از metricsJson یا ستون actualRpe
```

اگر weight null است، آن set را در volume weight-based حساب نکن و جدا گزارش کن: «تمرین بدون وزن».

## P-07 — حذف consecutiveEasyWeeks جعلی

این مقدار را حذف کن:

```dart
consecutiveEasyWeeks: (total / 2).round()
```

به‌جایش برای هر exercise آخرین feelingهای ۶ هفته را بگیر و با منطق scheduler سازگار باش. اگر نمی‌توانی مقدار دقیق محاسبه کنی، مقدار `null` و متن «دادهٔ کافی نیست» بده.

## P-08 — روند درد/ریکاوری

اگر `ss_daily_checkin.painLevel` یا `workout_recovery_logs` موجود است، نمودار هفتگی pain/soreness را در روند نشان بده. اگر داده نیست، بنویس:

```text
برای تحلیل ریکاوری، چک‌این روزانه را انجام بده.
```

⛔ هیچ نمودار ساختگی با دادهٔ ثابت نساز.

---

# فاز X — تجربهٔ کاربری چهار تب (X-01 … X-08)

## X-01 — Today: کارت امروز

کارت اصلی Today باید این اجزا را داشته باشد:

1. وضعیت readiness صادقانه یا «دادهٔ کافی نیست»؛
2. عنوان نسخهٔ امروز + slotType + intensity + مدت؛
3. CTA اصلی وابسته به وضعیت:
   - `شروع تمرین`
   - `ادامهٔ جلسهٔ نیمه‌تمام`
   - `ثبت انجام خارج از اپ`
   - `چک‌این ۵ ثانیه‌ای`
4. اکشن‌های ثانویه: `سبک‌تر`, `حداقلی`, `امروز نمی‌شود`, `جزئیات`.

اگر prescription امروز DONE است، خلاصهٔ واقعی جلسه را نشان بده؛ اگر فقط یک session unrelated امروز است، prescription را done جعلی نکن.

## X-02 — Today: حذف پیام‌های ساختگی

هر جمله‌ای شبیه این‌ها که از دادهٔ واقعی نیامده حذف شود:

```text
بدن شما پرانرژی‌تره
بهترین زمان برای افزایش شدت
ذخایر گلیکوژن
التهاب مفصلی
سیستم عصبی سمپاتیک
کورتیزول
```

متن جایگزین امن:

```text
بر اساس آخرین داده‌های ثبت‌شده، این نسخه برای امروز مناسب است. اگر حالت بدتری داری، نسخهٔ سبک را انتخاب کن.
```

## X-03 — Program: تاریخ، diff و قفل

در تب «برنامه»:

- تاریخ شمسی واقعی هر روز نمایش داده شود؛
- وضعیت `PLANNED/DONE/PARTIAL/SKIPPED/MOVED` با رنگ/آیکن واضح؛
- قفل‌ها قابل تشخیص و حفظ‌شده در rebuild؛
- diff قبل از اعمال تغییرات با تعداد و نام واقعی جلسات؛
- scope انتخاب شود: `فقط این ج��سه`, `این هفته`, `کل برنامه`.

## X-04 — Program: بازسازی امن

دکمهٔ بازسازی باید:

1. snapshot بگیرد؛
2. diff/preview نشان دهد؛
3. تأیید بگیرد؛
4. transaction اجرا کند؛
5. در صورت خطا rollback کند؛
6. undo/restore از history کار کند.

## X-05 — Session: اجرای تمرین

صفحهٔ session باید شامل این بهبودها شود:

- هر set بلافاصله با حالت بصری مشخص (`pending/current/done`) ذخیره شود؛
- Undo آخرین ست؛
- note و RIR برای هر حرکت واقعاً ذخیره شود؛
- یادداشت قبلی حرکت نمایش داده شود؛
- دکمهٔ درد پایدار؛
- resume پس از background درست؛
- empty/error state مجزا.

## X-06 — Movement: سادگی و سرعت

تب حرکت باید:

- quick log دو ضربه‌ای؛
- بودجهٔ واقعی با متن انسانی؛
- timeline فارسی؛
- حذف با Undo؛
- فرم پیشرفته collapse؛
- CTA پیشنهاد هوشمند که kind واقعی را باز کند.

## X-07 — Progress: معنای آماری

تب روند باید از «سرگرمی عددی» به «تصمیم‌سازی» برسد:

- adherence هفته/ماه؛
- planned vs actual؛
- full/light/minimal؛
- volume/RPE/RIR؛
- تعادل عضلانی؛
- PR معتبر؛
- درد/ریکاوری؛
- CTA بعدی مثل «هفتهٔ بعد سبک‌تر شود».

## X-08 — تنظیمات برنامه

`SSProgramSettingsScreen` و rebuild باید:

- `respectLocks=true` پیش‌فرض؛
- تغییرات manual حفظ شود؛
- نتیجهٔ diff قبل از apply نشان داده شود؛
- اگر settings چیزی را تغییر نداده، rebuild خالی اجرا نشود؛
- خطاهای کاربر با SnackBar/Dialog فارسی قابل فهم گزارش شود.

---

# فاز I — هوش مصنوعی ورزش و دستیار تخصصی (I-01 … I-08)

## I-01 — حذف write مستقیم AI

`SSAiCoachSheet` نباید مستقیماً با `AIGateway + ChatActionParser + AssistantActionRegistry` دیتابیس را تغییر دهد. مسیر مجاز:

```text
User message
  → Sports Persona
  → structured RitmoCommand
  → RitmoCommandBus.preview
  → PlanPreview قابل فهم فارسی
  → تأیید کاربر
  → execute در transaction
  → audit log + Undo
```

هر مسیر مستقیم دیگر برای write ممنوع است.

## I-02 — فرمان‌های sports موجود باید واقعی شوند

در persona registry فعلی این فرمان‌ها وجود دارند و باید به command bus واقعی وصل شوند، نه فقط openPage:

```text
sports.setTrainingDays
sports.setSessionMinutes
sports.setFocus
sports.setRestDay
sports.lockDay
sports.swapExercise
sports.adjustIntensity
sports.logSession
sports.generateProgram
sports.setQuietMode
```

برای هر فرمان:

- validator دقیق؛
- preview؛
- effect روی prescription/template؛
- audit؛
- Undo در صورت امکان.

## I-03 — Context هوش مصنوعی فقط canonical

Context AI باید شامل این‌ها باشد:

```text
today prescription
next 7 days prescriptions
active template summary
last 3 completed sessions
latest set/RPE/RIR summaries
check-in امروز
movement budget snapshot
physicalLimitations و equipment
```

⛔ AI نباید برای «برنامهٔ امروز» فقط legacy plan/crossref را بخواند و prescription را نادیده بگیرد.

## I-04 — Candidateهای swap معتبر

قبل از اینکه AI پیشنهاد تعویض حرکت بدهد، باید ID candidateها از `SSPlanGenerator.getSwapCandidates` یا repository معادل گرفته شود. پاسخ AI فقط می‌تواند یکی از همان IDها را انتخاب کند. اگر ID نامعتبر بود، command reject شود.

## I-05 — Preview فارسی و دقیق

هر preview باید برای کاربر قابل فهم باشد:

```text
«سه‌شنبه ۲۱ آبان: تمرین قدرتی ۴۵ دقیقه → نسخهٔ سبک ۲۵ دقیقه»
«حرکت اسکوات با پلانک جایگزین می‌شود؛ فقط جلسهٔ امروز تغییر می‌کند»
```

بدون preview و تأیید، هیچ writeای اجرا نشود.

## I-06 — Undo و audit برای همهٔ writeها

هر command موفق باید در audit log فعلی پروژه ذخیره شود:

```text
command type, target id, old value, new value, actor=AI/USER, timestamp
```

اگر undo قابل پیاده‌سازی است، snapshot قبل از apply ذخیره شود.

## I-07 — Privacy boundary

Sports assistant اجازه ندارد مسیر مستقیم به `/cycle` یا دیتای حساس دیگر برود. اگر readiness به اطلاعات چرخه نیاز دارد، فقط از سرویس داخلی consent-aware و حداقل‌گرا استفاده کند. هیچ متن چرخه/پزشکی خام در prompt AI ارسال نشود.

## I-08 — رفتار دستیار ورزشی

Sports persona باید بتواند در دامنهٔ خودش این کارها را کند:

- توضیح برنامهٔ امروز/هفته؛
- سبک/سنگین‌تر کردن برنامه با preview؛
- قفل/بازکردن روز؛
- جابه‌جایی جلسه؛
- ثبت جلسهٔ خارج از اپ؛
- پیشنهاد حرکت جایگزین امن؛
- تحلیل پیشرفت با دادهٔ واقعی؛
- ارجاع به پزشک در درد/علائم هشدار، بدون تشخیص پزشکی.

اگر درخواست خارج از sports بود، handoff به دستیار عمومی.

---

# فاز T — تست‌های الزامی (T-01 … T-12)

> هیچ تستی را صرفاً با `skip` یا `expect(true, true)` نمی‌پذیریم. هر تست باید رفتار واقعی را اثبات کند.

## T-01 — تست migration v90

فایل پیشنهادی:

```text
test/database/migration_v90_sports_integrity_test.dart
```

اثبات‌ها:

- از schema قدیمی ۸۹ به ۹۰ بدون خطا ارتقا می‌یابد؛
- ستون‌های جدید وجود دارند؛
- داده‌های قدیمی حفظ می‌شوند؛
- unique indexها duplicate را کنترل می‌کنند؛
- fresh install با schema نهایی parity دارد.

## T-02 — تست scheduler compile/week wrap

فایل:

```text
test/supplementary_sports/ss_adaptive_scheduler_test.dart
```

اثبات‌ها:

- `ensureUpcomingWeekReady` کامپایل و اجرا می‌شود؛
- week 4 → week 1 wrap می‌شود؛
- `deloadEveryNWeeks=0` خطا ندارد؛
- وقتی plan هفتهٔ بعد موجود است، idempotent است.

## T-03 — تست completion rate هفته‌محور

با داده‌های چند `cycleWeek` متفاوت اثبات کن فقط هفتهٔ درخواستی حساب می‌شود و:

```text
DONE=1
PARTIAL=0.5
SKIPPED/MOVED/PLANNED=0
REST excluded
empty=1.0
```

## T-04 — تست progression signals جدید

- آخرین دو feeling EASY → increase؛
- یکی از دو آخر HARD/TOO_HARD → decrease؛
- دادهٔ قدیمی‌تر از ۶ هفته بی‌اثر؛
- یک رکورد تنها → maintain.

## T-05 — تست generator safety/deload

در `plan_generator_v2_test.dart` یا فایل جدید:

- حرکت مغایر equipment/limitation/skill هرگز با fallback برنمی‌گردد؛
- وقتی هیچ حرکت امن نیست، plan قبلی حذف نمی‌شود؛
- `isDeload=true` باعث کاهش sets/reps می‌شود؛
- هیچ وزن ۵/۱۲/۲۰ کیلویی خودکار ساخته نمی‌شود؛
- افزایش هم‌زمان sets+weight اتفاق نمی‌افتد.

## T-06 — تست agenda mapping/prescription priority

فایل:

```text
test/agenda_sports_source_test.dart
```

اثبات‌ها:

- دوشنبه `DateTime.monday` به legacy day 3 نگاشت می‌شود؛
- شنبه به 1؛
- prescription برای همان تاریخ بر legacy غلبه می‌کند؛
- duplicate ساخته نمی‌شود؛
- REST آیتم actionable نمی‌سازد؛
- ستون‌های ناموجود استفاده نمی‌شوند.

## T-07 — تست resolve جلسه و عدم fallback تصادفی

- planId معتبر → همان plan؛
- prescriptionId → workoutPlanId/legacyPlanId درست؛
- plan/prescription گمشده → `loadError`؛
- هیچ crossref/exercise نامرتبط لود نمی‌شود.

## T-08 — تست finish session

- فقط setهای done ذخیره می‌شوند؛
- `rir` و `note` ذخیره می‌شوند؛
- session `prescriptionId` دارد؛
- prescription در همان transaction DONE می‌شود؛
- workout log مرکزی یکی است.

## T-09 — تست idempotency completion gateway

- دوبار صدا زدن `completeSession` یک workout log بسازد؛
- `movement_kinds.usageCount` فقط یک بار زیاد شود؛
- targetRpe حفظ و actualRpe جدا ذخیره شود؛
- location و metricsJson ذخیره شوند؛
- خطای movement insert باعث rollback prescription شود.

## T-10 — تست restore/regenerate plan

- snapshot `{plans,crossrefs}` درست decode می‌شود؛
- restore هر دو را در یک transaction برمی‌گرداند؛
- خطای regeneration وسط کار plan قبلی را حفظ می‌کند؛
- ترتیب delete/insert با FK امن است.

## T-11 — تست readiness

- بدون sleep/check-in → `hasData=false` و پیام ثبت داده؛
- sleep قدیمی‌تر از ۳۶ ساعت معتبر نیست؛
- painLevel بالا → rest؛
- sleep بسیار کم → minimal؛
- soreness/fatigue بالا → light؛
- هیچ توصیهٔ افزایش شدت در نبود داده وجود ندارد.

## T-12 — تست Movement و Progress

- `logEvent` retry → usageCount یکبار؛
- update/delete PR را بازمحاسبه می‌کند؛
- درصد budget با target واقعی محاسبه می‌شود؛
- Progress جلسات detail و مرکزی را dedupe می‌کند؛
- streak scheduled-based است؛
- `consecutiveEasyWeeks` جعلی وجود ندارد.

---

# فاز Q — کیفیت، امنیت، تحویل و گزارش (Q-01 … Q-08)

## Q-01 — Format

برای همهٔ فایل‌های Dart لمس‌شده:

```bash
dart format <files>
```

## Q-02 — Analyze

```bash
flutter analyze
```

⛔ هیچ analyzer error جدیدی مجاز نیست. اگر error موجود قدیمی بود، در گزارش با baseline ثبت کن و مطمئن شو تغییرات تو آن را بدتر نکرده‌اند.

## Q-03 — تست‌های focused

حداقل:

```bash
flutter test test/supplementary_sports
flutter test test/database
flutter test test/agenda_sports_source_test.dart
```

اگر نام فایل دقیق متفاوت شد، معادل واقعی را اجرا و گزارش کن.

## Q-04 — تست کامل

اگر زمان/محیط اجازه می‌دهد:

```bash
flutter test
```

اگر fail قدیمی داشت، نام تست، علت و ارتباط/عدم ارتباط با تغییرات را دقیق بنویس. خطای مرتبط با این پرامپت قابل قبول نیست.

## Q-05 — عدم افزودن dependency

```bash
git diff -- pubspec.yaml pubspec.lock
```

نباید تغییری داشته باشد مگر با مجوز صریح کاربر. این پرامپت چنین مجوزی نمی‌دهد.

## Q-06 — بازبینی privacy و UX

کنترل دستی:

- هیچ دادهٔ cycle در sports AI بدون consent نیامده؛
- readiness بدون داده، توصیهٔ افزایش شدت نمی‌دهد؛
- متن‌های فارسی روان و بدون ادعای پزشکی هستند؛
- حالت‌های empty/error/loading مجزا هستند.

## Q-07 — گزارش اجباری `073_REPORT.md`

فایل:

```text
prompts/073_REPORT.md
```

باید شامل این بخش‌ها باشد:

1. خلاصهٔ تغییرات؛
2. فهرست فایل‌های تغییرکرده؛
3. migration و schema diff؛
4. دستورهای اجراشده و خروجی؛
5. تست‌های موفق/ناموفق؛
6. ریسک‌های باقی‌مانده؛
7. جدول دقیقاً ۱۲۰ ردیفی برای همهٔ شناسه‌ها.

قالب هر ردیف:

```markdown
| R-01 | ✅ | `lib/...` / `test/...` | `flutter test ...` | PASS |
```

## Q-08 — Pull Request

- شاخهٔ پیشنهادی: `fix/sports-movement-integrity-073`
- PR باید Draft باشد.
- Title:

```text
fix(sports): harden movement planning, session integrity, and progress
```

- بدنهٔ PR باید شامل خلاصهٔ P0/P1، فایل‌ها، migration، تست‌ها، ریسک‌ها و لینک/متن گزارش باشد.
- merge نکن.

---

# فهرست نهایی کارها — ۱۲۰ شناسهٔ الزامی

> این فهرست قرارداد اتمام است. همه باید در گزارش ظاهر شوند. هیچ شناسه‌ای را حذف، ادغام یا rename نکن.

## Recon — فاز ۰

- [ ] **R-01** نسخهٔ DB، migration بعدی و registry دقیق شناسایی و گزارش شود.
- [ ] **R-02** اسکیمای واقعی sports/movement و ستون‌های migration لازم شناسایی شود.
- [ ] **R-03** API واقعی زمان/ID پروژه شناسایی و در کد جدید استفاده شود.
- [ ] **R-04** mapping روز هفته و توابع `SsProgramCalendar` مستند و استفاده شود.
- [ ] **R-05** خطاهای فعلی scheduler/generator با شاهد کد گزارش شود.
- [ ] **R-06** model/repository/builder فعلی prescription شناسایی شود.
- [ ] **R-07** completion gateway و movement repository فعلی شناسایی شود.
- [ ] **R-08** session notifier/screen و همهٔ callerهای `SSWorkoutPlanKey` شناسایی شود.
- [ ] **R-09** readiness و readiness dashboard فعلی شناسایی شود.
- [ ] **R-10** agenda source و مصرف‌کننده‌های آن شناسایی شود.
- [ ] **R-11** AI coach/persona/command bus و مرز privacy شناسایی شود.
- [ ] **R-12** تست‌های موجود و نحوهٔ اجرای آن‌ها شناسایی شود.

## Architecture — فاز A

- [ ] **A-01** نقش `ss_workout_plan` به template محدود و مستند شود.
- [ ] **A-02** prescription منبع حقیقت جلسهٔ تاریخ‌دار شود.
- [ ] **A-03** `sports_detail_mode` فقط UI detail را تغییر دهد.
- [ ] **A-04** کلید ماژول canonical یکپارچه و legacy reads حذف/مرکزی شود.
- [ ] **A-05** `workoutPlanId` به prescription اضافه و از legacy مقداردهی شود.
- [ ] **A-06** `prescriptionId` به session log اضافه و استفاده شود.
- [ ] **A-07** برای هر prescription فقط یک `workout_logs` مرکزی وجود داشته باشد.
- [ ] **A-08** Movement از همان `workout_logs` استفاده کند و مسیر موازی نسازد.
- [ ] **A-09** event/invalidation فقط بعد از commit موفق انجام شود.
- [ ] **A-10** مرز privacy sports AI رعایت شود.

## Data/Domain — فاز D

- [ ] **D-01** migration v90 دقیقاً یک‌بار ساخته و اجرا شود.
- [ ] **D-02** migration در runner ثبت و `_dbVersion` یک واحد افزایش یابد.
- [ ] **D-03** fresh schema با migration parity داشته باشد.
- [ ] **D-04** `SessionPrescription` فیلدهای `workoutPlanId` و `actualRpe` را پشتیبانی کند.
- [ ] **D-05** repository بتواند prescription را از plan/session resolve کند.
- [ ] **D-06** ذخیرهٔ transaction-aware prescription اضافه شود.
- [ ] **D-07** `MovementEvent.sourceEntityId` کامل پشتیبانی شود.
- [ ] **D-08** Movement tab دیگر kind ساختگی نسازد.
- [ ] **D-09** Movement logging در سطح repository idempotent شود.
- [ ] **D-10** تاریخ‌های نمایشی برنامه فارسی/شمسی و تاریخ ذخیره ISO باقی بماند.
- [ ] **D-11** rebuild، قفل‌ها و ویرایش‌های دستی را حفظ کند.
- [ ] **D-12** diff برنامه واقعی و علامت removal درست شود.
- [ ] **D-13** schema creation از presentation حذف شود.
- [ ] **D-14** reset/regenerate/restore تراکنشی و قابل rollback شود.
- [ ] **D-15** `SSAdaptiveScheduler` بازنویسی و خطای `currentWeek` برطرف شود.
- [ ] **D-16** deload واقعاً به generator برسد و حجم/شدت را کم کند.
- [ ] **D-17** fallback ناامن `finalExercises = allExercises` حذف شود.
- [ ] **D-18** وزن‌های جعلی ۵/۱۲/۲۰ کیلو حذف شود.
- [ ] **D-19** progression تک‌بُعدی و محافظه‌کارانه شود.
- [ ] **D-20** `SportsAgendaSource` با prescription-first و weekday mapping درست بازنویسی شود.
- [ ] **D-21** Program Overview از تاریخ/cycle واقعی استفاده کند.
- [ ] **D-22** `ss_active_week` فقط UI cache باشد، نه source of truth.

## Session — فاز S

- [ ] **S-01** `planId` از prescription امن resolve شود.
- [ ] **S-02** fallback تصادفی crossref/exercise حذف شود.
- [ ] **S-03** state/key/screen از `prescriptionId` و `loadError` پشتیبانی کنند.
- [ ] **S-04** فقط setهای done با RIR/note ذخیره شوند.
- [ ] **S-05** session log به prescription لینک شود.
- [ ] **S-06** detailed completion داخل همان transaction مرکزی انجام شود.
- [ ] **S-07** completion gateway اعتبارسنجی، اتمیک و idempotent شود.
- [ ] **S-08** Movement repository متد transaction-aware و idempotent بگیرد.
- [ ] **S-09** double-tap روی تکمیل ست بی‌اثر/امن شود.
- [ ] **S-10** Undo آخرین ست پیاده‌سازی شود.
- [ ] **S-11** اکشن پایدار درد/ناراحتی اضافه شود.
- [ ] **S-12** یادداشت قبلی هر حرکت در جلسه نمایش/ویرایش شود.
- [ ] **S-13** elapsed timer بعد از pause/background/resume دقیق باشد و active session به‌صورت سازگار و قابل بازیابی ذخیره شود؛ اگر ذخیرهٔ چندگانهٔ SharedPreferences باعث race است، آن را به یک snapshot اتمیک/رکورد دیتابیس منتقل کن.
- [ ] **S-14** خطای جلسه قابل فهم و قابل بازیابی در UI باشد.

## Readiness/Today — فاز H

- [ ] **H-01** readiness engine واحد canonical شود.
- [ ] **H-02** scoreهای جعلی 82/74/82/32/88 حذف شود.
- [ ] **H-03** جدول `ss_daily_checkin` در migration/schema اضافه شود.
- [ ] **H-04** readiness بدون پیش‌فرض‌های soreness/fatigue و با sleep fresh کار کند.
- [ ] **H-05** چک‌این ۵ ثانیه‌ای امروز پیاده‌سازی شود.
- [ ] **H-06** خروجی readiness اکشن واقعی full/light/minimal/rest داشته باشد.
- [ ] **H-07** «امروز نمی‌شود» transition واقعی prescription انجام دهد.
- [ ] **H-08** readiness موازی/دوم حذف یا به سرویس canonical متصل شود.

## Movement — فاز M

- [ ] **M-01** quick log دو ضربه‌ای اضافه شود.
- [ ] **M-02** همهٔ kindها canonical و از repository خوانده شوند.
- [ ] **M-03** درصد budget با target واقعی کاربر محاسبه شود.
- [ ] **M-04** timeline فارسی و بدون `kindCode` خام شود.
- [ ] **M-05** حذف event تأیید/Undo داشته باشد.
- [ ] **M-06** PR بعد از edit/delete بازمحاسبه شود.
- [ ] **M-07** `logEvent` در retry side effect را تکرار نکند.
- [ ] **M-08** suggester اعداد MET/confidence واقعی بدهد و ادعای ثابت نداشته باشد.
- [ ] **M-09** فیلدهای پیشرفتهٔ movement collapse شوند.
- [ ] **M-10** متن budget انسانی و مبتنی بر محاسبهٔ واقعی شود.

## Progress — فاز P

- [ ] **P-01** Progress مرکز و detail sessions را merge/dedupe کند.
- [ ] **P-02** adherence بر اساس جلسات برنامه‌ریزی‌شده محاسبه شود.
- [ ] **P-03** streak scheduled-session-based شود.
- [ ] **P-04** planned vs actual هفتگی نمایش داده شود.
- [ ] **P-05** full/light/minimal/moved/skipped گزارش شود.
- [ ] **P-06** حجم هفتگی، RPE و RIR واقعی محاسبه شود.
- [ ] **P-07** consecutiveEasyWeeks جعلی حذف شود.
- [ ] **P-08** روند درد/ریکاوری با دادهٔ واقعی یا empty state نمایش داده شود.

## UX — فاز X

- [ ] **X-01** Today کارت actionable و وضعیت completion صحیح داشته باشد؛ plan completion بر اساس چرخهٔ جاری و هویت prescription/session باشد، نه شمارش all-time.
- [ ] **X-02** متن‌های ساختگی/پزشکی بی‌مبنا حذف شود.
- [ ] **X-03** Program تاریخ شمسی، diff و lock درست نشان بدهد.
- [ ] **X-04** بازسازی برنامه با preview و transaction امن شود.
- [ ] **X-05** Session UX شامل ذخیرهٔ هر ست، Undo، RIR/note، درد، resume و error state شود.
- [ ] **X-06** Movement UX سریع، فارسی و با Undo شود.
- [ ] **X-07** Progress UX به تصمیم‌سازی تبدیل شود، نه صرفاً streak روزانه.
- [ ] **X-08** تنظیمات برنامه locks/manual edits را حفظ و diff واقعی نشان دهد.

## AI — فاز I

- [ ] **I-01** write مستقیم AI حذف و به command bus منتقل شود.
- [ ] **I-02** فرمان‌های sports واقعاً preview/execute/undo داشته باشند.
- [ ] **I-03** context AI از prescription/canonical data استفاده کند.
- [ ] **I-04** swap فقط از candidate IDهای معتبر انتخاب شود.
- [ ] **I-05** preview فارسی و قابل فهم قبل از write الزامی شود.
- [ ] **I-06** audit و undo برای writeهای AI فعال شود.
- [ ] **I-07** privacy boundary چرخه/داده‌های حساس رعایت شود.
- [ ] **I-08** sports persona در دامنهٔ خودش کامل و خارج از آن handoff کند.

## Tests — فاز T

- [ ] **T-01** migration v90 تست شود.
- [ ] **T-02** scheduler و wrap week تست شود.
- [ ] **T-03** completion rate هفته‌محور تست شود.
- [ ] **T-04** progression signals اخیر تست شود.
- [ ] **T-05** generator safety و deload تست شود.
- [ ] **T-06** agenda mapping و prescription priority تست شود.
- [ ] **T-07** resolve جلسه و حذف fallback تصادفی تست شود.
- [ ] **T-08** finish session و ذخیرهٔ set/RIR/note تست شود.
- [ ] **T-09** idempotency/atomicity gateway تست شود.
- [ ] **T-10** restore/regenerate rollback تست شود.
- [ ] **T-11** readiness تست شود.
- [ ] **T-12** Movement/Progress idempotency و analytics تست شود.

## Quality — فاز Q

- [ ] **Q-01** Dart format اجرا شود.
- [ ] **Q-02** `flutter analyze` بدون خطای جدید باشد.
- [ ] **Q-03** تست‌های focused اجرا و گزارش شود.
- [ ] **Q-04** تست کامل اجرا/گزارش شود.
- [ ] **Q-05** dependency جدید اضافه نشده باشد.
- [ ] **Q-06** privacy/UX review دستی انجام شود.
- [ ] **Q-07** `prompts/073_REPORT.md` با ۱۲۰ ردیف کامل ساخته شود.
- [ ] **Q-08** Draft PR با توضیحات کامل باز و merge نشود.

---

# تعریف پایان کار

کار فقط وقتی تمام است که:

1. همهٔ ۱۲۰ شناسه در گزارش وضعیت داشته باشند؛
2. `flutter analyze` و تست‌های focused اجرا شده باشند؛
3. migration v90 روی DB قدیمی و fresh هر دو اثبات شده باشد؛
4. هیچ fallback تصادفی تمرین باقی نمانده باشد؛
5. readiness بدون داده، توصیهٔ افزایش شدت نکند؛
6. completion یک جلسه اتمیک و idempotent باشد؛
7. Agenda/Today/Program/Progress همه از منبع canonical درست بخوانند؛
8. PR به‌صورت Draft با گزارش کامل باز شده باشد.
