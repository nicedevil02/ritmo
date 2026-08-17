# پرامپت اجرایی — بازسازی و رفع باگ‌های «تقویم» در پروژه Ritmo

> این فایل را **کامل و بدون حذف** به‌عنوان اولین پیام به ایجنت برنامه‌نویس بده.
> هیچ توضیح اضافه‌ای لازم نیست. خودِ این فایل نقشه است.

---

## بخش ۰ — نحوهٔ استفاده (برای بهمن، ایجنت این بخش را نادیده بگیرد)

کل محتوای این فایل را کپی کن و به‌عنوان **اولین پیام** در سشن ایجنت برنامه‌نویس (Cursor / Claude Code / Codex / …) بفرست. ریپو باید از قبل clone و `flutter pub get` شده باشد. اگر سشن قطع شد، فقط بنویس: «ادامه بده از `docs/calendar/CALENDAR_FIX_PROGRESS.md`» — ایجنت خودش می‌داند کجا بود.

---

## بخش ۱ — نقش تو و قوانین آهنین

تو یک مهندس ارشد Flutter/Dart هستی که روی ریپو `nicedevil02/ritmo` کار می‌کنی؛ یک اپ برنامه‌ریزی شخصی فارسی با UI راست‌به‌چپ و تقویم شمسی (`shamsi_date`) و پایگاه‌دادهٔ SQLite محلی (`sqflite`).

مأموریت تو: **اجرای دقیق تسک‌های CAL-01 تا CAL-60 در همین فایل، به همین ترتیب.**

### ۱۶ قانون آهنین — نقض هر یک، خرابی کار است

1. **هیچ فایل نقشه/plan/roadmap/طرح ننویس.** این فایل خودش نقشه است. اگر وسوسه شدی «بگذار اول یک نقشه بنویسم» — نکن. برو سر CAL-01.
2. **ترتیب تسک‌ها را عوض نکن.** فازها به هم وابسته‌اند: فاز A زیرساخت مشترکی می‌سازد که فازهای B تا H روی آن بنا می‌شوند.
3. **یک تسک در یک زمان.** چند تسک را با هم قاطی نکن، حتی اگر «مرتبط» به نظر می‌رسند.
4. **چرخهٔ هر تسک، بدون استثنا:** فایل‌ها را بخوان → تغییر بده → `flutter analyze` → `flutter test` → ردیف ledger را DONE کن → commit.
5. **یک commit برای هر تسک** با پیام: `fix(calendar): CAL-## — <عنوان کوتاه فارسی>`
6. **`catch (_) {}` و `catch (_) { return X; }` ممنوع.** همیشه `RitmoLog.error('<Tag>', '<پیام>', e, st)`. اگر خطا واقعاً بی‌اهمیت است، در کامنت بنویس چرا.
7. **`debugPrint` در کد تقویم ممنوع.** فقط `RitmoLog` (در `lib/core/logging/ritmo_logger.dart`).
8. **هیچ رشتهٔ انگلیسی به کاربر نشان نده.** همهٔ پیام‌های UI فارسی. هیچ‌وقت `$e` خام را در `_errorMessage` نگذار؛ آن را log کن.
9. **SQL خام در لایهٔ presentation ممنوع.** خواندن/نوشتن تنظیمات فقط از `SettingsService`، داده فقط از repository مربوطه.
10. **بدون migration، schema را عوض نکن.** جدول‌های `occurrence_overrides` و `day_marks` الگوی «`CREATE TABLE IF NOT EXISTS` تنبل + خودترمیمی» دارند؛ برای افزودن ستون به آن‌ها هم باید migration بنویسی، نه اینکه `CREATE TABLE` را عوض کنی (روی نصب‌های قدیمی اجرا نمی‌شود).
11. **هر تغییر رفتاری، تست می‌خواهد.** تست بدون assert قبول نیست.
12. **کد مرده را پاک کن، کامنت‌نشده رهایش نکن.** هیچ `TODO`، هیچ تابع بی‌استفاده، هیچ ثابت بی‌ارجاع.
13. **اگر تسکی از قبل انجام شده بود:** ردیفش را `SKIPPED` بزن با یک خط دلیل، و **برو تسک بعدی**. توقف نکن و سؤال نپرس.
14. **اگر واقعیت کد با توصیف این فایل فرق داشت:** `BLOCKED` بزن، در ستون یادداشت بنویس دقیقاً چه دیدی، و **برو تسک بعدی**. یک اختلاف کوچک نباید کل زنجیره را متوقف کند.
15. **هرگز فایلی خارج از `lib/features/calendar/`، `lib/core/domain/agenda/`، `lib/core/utils/`، `lib/core/logging/`، `lib/core/settings/` و `test/` را دست نزن** مگر تسک صریحاً گفته باشد.
16. **در پایان هر فاز، `flutter analyze` باید صفر issue بدهد.** با issue باز به فاز بعد نرو.

---

## بخش ۲ — قانون ضد فراموشی (اولین کاری که می‌کنی)

**قبل از CAL-01**، فایل `docs/calendar/CALENDAR_FIX_PROGRESS.md` را بساز با این محتوا: یک جدول که **هر ۶۰ ردیف** CAL-01 تا CAL-60 را دارد، با ستون‌های:

```
| ID | عنوان | فاز | وضعیت | commit | یادداشت |
```

وضعیت اولیهٔ همه: `TODO`. مقادیر مجاز: `TODO` / `DOING` / `DONE` / `SKIPPED` / `BLOCKED`.

این فایل قانون تو است:

- **در شروع هر سشن یا هر پیام جدید، اول همین فایل را بخوان.** هیچ‌وقت از حافظه‌ات تصمیم نگیر که کجا بودی.
- همیشه **اولین ردیف `TODO`** را بردار، بگذارش `DOING`.
- بلافاصله بعد از پاس شدن `flutter analyze` و `flutter test`، ردیف را `DONE` کن و hash کوتاه commit را بنویس.
- **آپدیت ledger در همان commit تسک انجام می‌شود**، نه در commit جدا.
- هرگز چیزی را `DONE` نکن که `flutter analyze` روی آن پاک نیست.
- هرگز ردیف‌ها را حذف یا ادغام نکن.

این فایل را با commit `chore(calendar): CAL-00 — ساخت ledger پیشرفت` ثبت کن.

---

## بخش ۳ — شناخت کد (خواندن اجباری قبل از CAL-01)

این فایل‌ها را کامل بخوان. **هیچ تسکی را قبل از خواندن این‌ها شروع نکن:**

```
lib/features/calendar/presentation/journey_controller.dart          ← قلب مشکلات
lib/features/calendar/presentation/journey_screen.dart
lib/features/calendar/presentation/logic/agenda_bucketing.dart
lib/features/calendar/presentation/logic/timeline_layout_engine.dart
lib/features/calendar/presentation/logic/timeline_snapping.dart
lib/features/calendar/presentation/logic/direct_manipulation_eligibility.dart
lib/features/calendar/presentation/logic/today_calendar_convergence_helper.dart
lib/features/calendar/presentation/logic/split_day_scroll_helper.dart
lib/features/calendar/presentation/logic/morning_brief.dart
lib/features/calendar/presentation/utils/calendar_defaults.dart
lib/features/calendar/presentation/utils/calendar_geometry.dart
lib/features/calendar/presentation/utils/calendar_date_formatter.dart
lib/features/calendar/presentation/utils/calendar_navigation_helper.dart
lib/features/calendar/presentation/models/timeline_view_models.dart
lib/features/calendar/presentation/models/now_pill_view_model.dart
lib/features/calendar/presentation/widgets/journey_agenda_view.dart
lib/features/calendar/presentation/widgets/timeline_grid.dart
lib/features/calendar/presentation/widgets/timeline_split_day_view.dart
lib/features/calendar/presentation/widgets/journey_month_view.dart
lib/features/calendar/presentation/widgets/journey_week_view.dart
lib/features/calendar/presentation/widgets/journey_year_view.dart
lib/features/calendar/presentation/widgets/journey_free_gaps_section.dart
lib/features/calendar/data/day_mark_repository.dart
lib/features/calendar/data/calendar_search_repository.dart
lib/features/calendar/data/occasions_calendar_source.dart
lib/core/domain/agenda/day_agenda_service.dart                      ← منبع حقیقت روز
lib/core/domain/agenda/occurrence_override_repository.dart
lib/core/domain/agenda/agenda_item.dart
lib/core/domain/agenda/day_agenda_snapshot_builder.dart
lib/core/domain/agenda/agenda_action_handler.dart
lib/core/domain/models/duration_bounds.dart
lib/core/domain/commands/command_stack.dart
lib/core/settings/settings_service.dart
lib/core/logging/ritmo_logger.dart
lib/features/courses/logic/course_scheduler.dart                    ← getSaturdayOfWeek
docs/adr/0006-guard-rails-dependency-rules.md
```

### حقایق تأییدشده — دوباره تحقیق نکن

- تقویم پنج مقیاس دارد: `JourneyScale.{agenda, day, week, month, year}`. مقیاس اصلی `agenda` است.
- `JourneyController` هم به `RitmoEventBus().onEvents` گوش می‌دهد و هم به `RitmoEvents.routineChangedNotifier` — **هر دو به `refresh()` وصل‌اند**.
- `DayAgendaService._scheduleUiRefresh()` خودش `RitmoEvents.notifyRoutineChanged()` را صدا می‌زند (debounce ۳۵۰ms، cooldown ۱۵۰۰ms). یعنی حلقهٔ رفرش از دو طرف تغذیه می‌شود.
- `DayAgendaService` **روز خالی را هرگز کش نمی‌کند** (کامنت `C-FIX-4`). این تصمیم درست است؛ عوضش نکن، فقط کنارش negative-cache بگذار (CAL-40).
- جدول `occurrence_overrides` کلید یکتای `(sourceType, sourceId, dateStr)` دارد و `upsert` با `ConflictAlgorithm.replace` کار می‌کند.
- در `_assembleDay`، override با `status == 'SKIPPED'` باعث `completion: skipped` می‌شود؛ `timeOfDay` غیرخالی باعث `itemType: fixed` می‌شود.
- هفتهٔ شمسی: شنبه تا جمعه. `Jalali.weekDay`: ۱=شنبه … ۷=جمعه. روزهای کاری = ۱ تا ۵.
- سه پارسر زمان مستقل و **ناسازگار** در کد هست: `TimelineSnappingHelper.parseTimeToMinutes` (خطا → ۰، بدون اعتبارسنجی بازه)، `TimelineLayoutEngine._tryParseStartMinutes` (خطا → `null`، با اعتبارسنجی)، `DayAgendaService._parseMinutes` (خطا → ۰).
- دو سازندهٔ کلید تاریخ ناسازگار: `JourneyController._formatDateKey` (محلی y/m/d) و `DayAgendaService._dateStr` (`toIso8601String().substring(0,10)` که برای `DateTime` با `isUtc == true` تاریخ را جابه‌جا می‌کند).
- `CalendarDefaults`: `fallbackDurationMinutes = 30`, `snapIntervalMinutes = 15`, `minDurationMinutes = 15`, `maxDurationMinutes = 720`, `untimedPlacementMinutes = 540`.
- `CalendarGeometry`: `pxPerMinute = 1.2`, `pxPerMinuteSplit = 1.6`, `splitBoundaryMinutes = 720`, `maxLanesSplit = 2`.
- `CommandStack.instance` یک singleton سراسری است و `UndoableCommand` رابط آن.

---

# بخش ۴ — تسک‌ها

---

## فاز A — زیرساخت مشترک (CAL-01 … CAL-08)

هدف فاز: حذف «چند منبع حقیقت» برای تاریخ، زمان، لاگ و ثابت‌ها. بدون این فاز، بقیهٔ رفع‌باگ‌ها روی شن ساخته می‌شوند.

---

### CAL-01 — یک سازندهٔ کلید تاریخ برای کل اپ

**باگ:** دو تابع مستقل کلید تاریخ می‌سازند و در حالت مرزی جواب‌های **متفاوت** می‌دهند:

```dart
// JourneyController — محلی، درست
static String _formatDateKey(DateTime dt) =>
    '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}';

// DayAgendaService — روی DateTime با isUtc == true تاریخ را جابه‌جا می‌کند
static String _dateStr(DateTime dt) => dt.toIso8601String().substring(0, 10);
```

در تهران (+۰۳:۳۰)، `DateTime.utc(2026, 8, 16, 21, 30)` با تابع دوم `2026-08-16` می‌دهد و با تابع اول هم `2026-08-16`، اما `DateTime.parse('2026-08-17T01:00:00+03:30')` (که `isUtc == false` است) در تابع دوم `2026-08-16` می‌دهد چون `toIso8601String()` روی زمان محلی offset را حفظ نمی‌کند؟ **خودت با تست ثابت کن**؛ نکتهٔ اصلی این است که دو تابع باید یکی شوند. نتیجهٔ عملی اختلاف: `_rangeSnapshots[selectedKey]` گاهی `null` می‌شود و روز درست‌بارگذاری‌شده «خالی» رندر می‌شود.

**فایل‌ها:** فایل جدید `lib/core/utils/date_key.dart`

**کار دقیق:**

```dart
/// تک‌منبع تبدیل DateTime ↔ کلید تاریخ (yyyy-MM-dd).
/// همیشه بر مبنای تاریخ *محلی* کار می‌کند؛ ورودی UTC اول به محلی تبدیل می‌شود.
abstract final class DateKey {
  static String of(DateTime dt) {
    final local = dt.isUtc ? dt.toLocal() : dt;
    return '${local.year.toString().padLeft(4, '0')}-'
           '${local.month.toString().padLeft(2, '0')}-'
           '${local.day.toString().padLeft(2, '0')}';
  }

  /// نیمه‌شب محلی همان روز. برای هر مقایسه/محاسبهٔ بازه از این استفاده کن.
  static DateTime dayOf(DateTime dt) {
    final local = dt.isUtc ? dt.toLocal() : dt;
    return DateTime(local.year, local.month, local.day);
  }

  static String today() => of(DateTime.now());

  /// null برای ورودی نامعتبر — هرگز به تاریخ امروز fallback نکن.
  static DateTime? parse(String key) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(key.trim());
    if (m == null) return null;
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final d = int.parse(m.group(3)!);
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    final dt = DateTime(y, mo, d);
    if (dt.month != mo || dt.day != d) return null; // ۳۱ اسفند غیرموجود
    return dt;
  }

  /// افزودن روز بدون آسیب DST — روی تاریخ تقویمی کار می‌کند، نه Duration.
  static DateTime addDays(DateTime dt, int days) {
    final d = dayOf(dt);
    return DateTime(d.year, d.month, d.day + days);
  }
}
```

نکتهٔ `addDays` مهم است: در کل کد تقویم از `.add(Duration(days: n))` روی `DateTime` محلی استفاده شده که در گذر DST یک ساعت جابه‌جا می‌شود و `DateTime(y, m, d)` بعدی را عوض می‌کند. `DateTime(y, m, d + n)` امن است.

**معیار پذیرش:** فایل ساخته شده، همهٔ متدها تست دارند، `flutter analyze` پاک.

**تست:** بخشی از CAL-59.

**commit:** `fix(calendar): CAL-01 — تک‌منبع کلید تاریخ (DateKey)`

---

### CAL-02 — جایگزینی همهٔ سازنده‌های کلید تاریخ با `DateKey`

**فایل‌ها:** `day_agenda_service.dart`, `journey_controller.dart`, `agenda_bucketing.dart`, و هر جای دیگری که grep پیدا کرد.

**کار دقیق:**

1. `DayAgendaService._dateStr` را حذف کن؛ همهٔ کاربردها → `DateKey.of(...)`.
2. `JourneyController._formatDateKey` را حذف کن؛ همهٔ کاربردها → `DateKey.of(...)`.
3. در `agendaForRange`، حلقهٔ ساخت `dates` را از `d.add(const Duration(days: 1))` به `DateKey.addDays(d, 1)` عوض کن.
4. در `agenda_bucketing.dart`، همهٔ `DateTime(date.year, date.month, date.day)` → `DateKey.dayOf(date)` و همهٔ `.add(const Duration(days: n))` → `DateKey.addDays(..., n)`.
5. در `agenda_bucketing.dart`، `DateTime.parse(dateStr)` داخل `try/catch` → `DateKey.parse(dateStr)` و اگر `null` بود با `RitmoLog.error` گزارش بده (نه `continue` خاموش).

**معیار پذیرش:**

```bash
rg -n "toIso8601String\(\)\.substring" lib/            # باید خالی باشد
rg -n "_formatDateKey|static String _dateStr" lib/     # باید خالی باشد
rg -n "add\(const Duration\(days:" lib/features/calendar lib/core/domain/agenda   # باید خالی باشد
```

**commit:** `fix(calendar): CAL-02 — یکسان‌سازی کلید تاریخ در سرویس و کنترلر`

---

### CAL-03 — یک پارسر زمان با معناشناسی درست

**باگ:** `TimelineSnappingHelper.parseTimeToMinutes` خطا را به **۰ (نیمه‌شب)** تبدیل می‌کند و بازه را اعتبارسنجی نمی‌کند:

```dart
if (parts.length != 2) return 0;
final h = int.parse(parts[0]);
final m = int.parse(parts[1]);
return (h * 60) + m;        // "99:99" → 6039 دقیقه! هیچ کنترلی نیست
} catch (_) { return 0; }   // "abc" → نیمه‌شب
```

یعنی یک `timeOfDay` خراب، آیتم را بی‌صدا به ۰۰:۰۰ می‌برد و در بالای فهرست روز می‌نشاند — و `DayAgendaService._parseMinutes` هم همین کار را می‌کند. فقط `TimelineLayoutEngine._tryParseStartMinutes` درست عمل می‌کند (`null` برمی‌گرداند و `h<24 && m<60` را چک می‌کند).

**فایل‌ها:** فایل جدید `lib/core/utils/time_of_day_minutes.dart`

**کار دقیق:**

```dart
import 'package:ritmo/core/utils/persian_digits.dart';

/// تک‌منبع تبدیل 'HH:mm' ↔ دقیقهٔ روز (۰..۱۴۳۹).
abstract final class TimeOfDayMinutes {
  /// null برای ورودی نامعتبر. هرگز به ۰ سقوط نکن.
  static int? tryParse(String? raw) {
    if (raw == null) return null;
    // ارقام فارسی/عربی را هم بپذیر: کاربر و مدل هوش مصنوعی هر دو می‌فرستند.
    final value = toEnglishDigits(raw.trim());
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value);
    if (m == null) return null;
    final h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    if (h < 0 || h > 23 || min < 0 || min > 59) return null;
    return h * 60 + min;
  }

  static String format(int minutesOfDay) {
    final c = minutesOfDay.clamp(0, 1439);
    return '${(c ~/ 60).toString().padLeft(2, '0')}:'
           '${(c % 60).toString().padLeft(2, '0')}';
  }

  static bool isValid(String? raw) => tryParse(raw) != null;
}
```

اگر تابع `toEnglishDigits` با این نام در `persian_digits.dart` نبود، نام واقعی را پیدا کن و همان را استفاده کن؛ اگر وجود نداشت، اضافه‌اش کن.

**معیار پذیرش:** فایل ساخته شده و تست دارد.

**commit:** `fix(calendar): CAL-03 — تک‌منبع پارس زمان (TimeOfDayMinutes)`

---

### CAL-04 — حذف سه پارسر زمان تکراری

**فایل‌ها:** `timeline_snapping.dart`, `timeline_layout_engine.dart`, `day_agenda_service.dart`

**کار دقیق:**

1. `TimelineSnappingHelper.parseTimeToMinutes` و `minutesToTimeString` را **حذف** کن. همهٔ فراخوان‌ها → `TimeOfDayMinutes.tryParse` / `TimeOfDayMinutes.format`.
2. `TimelineLayoutEngine._tryParseStartMinutes` را حذف کن → `TimeOfDayMinutes.tryParse`.
3. `DayAgendaService._parseMinutes` را حذف کن. در `_sortItems`، جایی که ۰ برمی‌گشت، حالا `null` می‌آید؛ آیتم با زمان نامعتبر باید **مثل آیتم بدون زمان** رفتار کند، نه مثل نیمه‌شب:

```dart
void _sortItems(List<AgendaItem> items) {
  items.sort((a, b) {
    final aM = a.isTimed ? TimeOfDayMinutes.tryParse(a.timeOfDay) : null;
    final bM = b.isTimed ? TimeOfDayMinutes.tryParse(b.timeOfDay) : null;
    if (aM != null && bM != null) {
      final cmp = aM.compareTo(bM);
      return cmp != 0 ? cmp : a.id.compareTo(b.id);
    }
    if (aM != null) return -1;
    if (bM != null) return 1;
    final pCmp = b.priority.compareTo(a.priority);
    return pCmp != 0 ? pCmp : a.id.compareTo(b.id);
  });
}
```

4. هر جا `tryParse` مقدار `null` داد و آیتم `isTimed` بود، یک بار `RitmoLog.error` با `item.id` و مقدار خام بزن — این تنها راه دیدن دادهٔ خراب است.

**معیار پذیرش:**

```bash
rg -n "parseTimeToMinutes|_tryParseStartMinutes|_parseMinutes|minutesToTimeString" lib/   # خالی
```

**تست:** بخشی از CAL-59.

**commit:** `fix(calendar): CAL-04 — حذف پارسرهای زمان تکراری`

---

### CAL-05 — یک منبع برای ثابت‌های مدت و زمان پیش‌فرض

**باگ:** `CalendarDefaults.maxDurationMinutes = 720` تعریف شده اما **هیچ‌جا استفاده نمی‌شود**؛ کد عملاً `DurationBounds.maxMinutes` را به کار می‌برد. یعنی دو سقف مدت رقیب. همچنین اعداد جادویی پراکنده‌اند:

```dart
// journey_controller.dart — completeItem
durationMinutes: item.durationMinutes ?? 30,          // ← عدد جادویی
// journey_controller.dart — startItemResize
_previewDurationMinutes = item.durationMinutes ?? 30; // ← عدد جادویی
// journey_controller.dart — commitItemDrag
final oldTimeOfDay = item.timeOfDay ?? '08:00';        // ← زمان جادویی
// journey_controller.dart — commitItemResize (این یکی درست است)
item.durationMinutes ?? CalendarDefaults.fallbackDurationMinutes
```

**فایل‌ها:** `calendar_defaults.dart`, `journey_controller.dart`, `timeline_snapping.dart`

**کار دقیق:**

1. در `CalendarDefaults`: `maxDurationMinutes` را **حذف** کن و به جایش در همان فایل بنویس:
   ```dart
   /// سقف مدت، تک‌منبع در DurationBounds است. اینجا تکرارش نکن.
   ```
   اگر جایی به `CalendarDefaults.maxDurationMinutes` ارجاع بود → `DurationBounds.maxMinutes`.
2. اضافه کن: `static const String fallbackTimeOfDay = '08:00';`
3. هر `?? 30` در تقویم → `?? CalendarDefaults.fallbackDurationMinutes`.
4. هر `?? '08:00'` → `?? CalendarDefaults.fallbackTimeOfDay`.
5. بررسی کن `CalendarDefaults.untimedPlacementMinutes` جایی استفاده می‌شود یا نه (`rg -n untimedPlacementMinutes lib/`). اگر بی‌ارجاع بود، حذفش کن.

**معیار پذیرش:**

```bash
rg -n "\?\? 30\b|\?\? '08:00'" lib/features/calendar    # خالی
rg -n "CalendarDefaults.maxDurationMinutes" lib/          # خالی
```

**commit:** `fix(calendar): CAL-05 — یک‌کاسه‌کردن ثابت‌های مدت و زمان پیش‌فرض`

---

### CAL-06 — `RitmoLog` به‌جای `debugPrint`

**باگ:** `JourneyController` یازده جا `debugPrint` دارد و `DayAgendaService` هم یک `debugPrint` تشخیصی طولانی، در حالی که بقیهٔ کد از `RitmoLog.error` استفاده می‌کند. نتیجه: خطاهای تقویم به pipeline لاگ و redaction نمی‌رسند و در release دیده نمی‌شوند.

**فایل‌ها:** `journey_controller.dart`, `day_agenda_service.dart`, هر فایل تقویم که `debugPrint` دارد.

**کار دقیق:**

- هر `debugPrint('X error: $e\n$stackTrace')` → `RitmoLog.error('JourneyController', 'X failed', e, stackTrace)`.
- خط تشخیصی `[DayAgendaService] range ...` را نگه دار (ارزش عیب‌یابی دارد) اما به `RitmoLog.debug` (یا معادل موجود) منتقلش کن.
- خط `[JourneyController] loadAgendaRange: ${sw.elapsedMilliseconds}ms` را نگه دار و به `RitmoLog.debug` ببر؛ در CAL-42 به بودجهٔ کارایی وصل می‌شود.
- `import 'package:flutter/foundation.dart';` را فقط اگر بعد از تغییرات بی‌استفاده شد حذف کن (`ChangeNotifier` از `foundation` می‌آید — احتمالاً لازم می‌ماند).

**معیار پذیرش:**

```bash
rg -n "debugPrint" lib/features/calendar lib/core/domain/agenda   # خالی
```

**commit:** `fix(calendar): CAL-06 — انتقال لاگ تقویم به RitmoLog`

---

### CAL-07 — پیام‌های خطای فارسی و بدون افشای استثنا

**باگ:** هشت پیام خطای **انگلیسی** به کاربر فارسی‌زبان نشان داده می‌شود و هر هشت‌تا استثنای خام را داخل رشتهٔ UI می‌ریزند:

```dart
_errorMessage = 'Failed to load schedule: $e';
_errorMessage = 'Failed to complete task: $e';
_errorMessage = 'Failed to postpone task: $e';
_errorMessage = 'Failed to skip task: $e';
_errorMessage = 'Failed to move task: $e';
_errorMessage = 'Failed to resize task: $e';
_errorMessage = 'Failed to schedule task: $e';
_errorMessage = 'Failed to unschedule task: $e';
// و در همان کلاس، این یکی فارسی است:
_errorMessage = 'خطا در بارگذاری برنامه‌ها: $e';
```

**فایل‌ها:** `journey_controller.dart`

**کار دقیق:** یک کلاس پیام در بالای فایل (یا `calendar_defaults.dart`) بساز و همه را جایگزین کن. **`$e` هرگز داخل پیام نیاید** — فقط `RitmoLog.error`:

```dart
abstract final class CalendarMessagesFa {
  static const load        = 'بارگذاری برنامه‌ها ناموفق بود. اتصال یا داده‌ها را بررسی کنید.';
  static const complete    = 'ثبت انجام‌شدن این مورد ناموفق بود.';
  static const postpone    = 'به‌تعویق‌انداختن این مورد ناموفق بود.';
  static const skip        = 'رد کردن این مورد ناموفق بود.';
  static const move        = 'جابه‌جایی این مورد ناموفق بود.';
  static const resize      = 'تغییر مدت این مورد ناموفق بود.';
  static const schedule    = 'زمان‌بندی این مورد ناموفق بود.';
  static const unschedule  = 'لغو زمان‌بندی این مورد ناموفق بود.';
  static const notSupported = 'این عملیات برای این نوع مورد پشتیبانی نمی‌شود.';
  static const overlap      = 'این بازه با یک مورد دیگر تداخل دارد.';
  static const invalidTime  = 'زمان انتخاب‌شده معتبر نیست.';
}
```

**معیار پذیرش:**

```bash
rg -n "_errorMessage = '(?i)failed" lib/            # خالی
rg -n "_errorMessage = .*\\\$e" lib/features/calendar  # خالی
```

**commit:** `fix(calendar): CAL-07 — پیام‌های خطای فارسی بدون افشای استثنا`

---

### CAL-08 — نرمال‌سازی `_selectedDate` به نیمه‌شب

**باگ:** `DateTime _selectedDate = DateTime.now();` ساعت و دقیقه و ثانیه را با خودش حمل می‌کند، اما رفتار بقیهٔ کد ناسازگار است:

- `navigatePeriod` در شاخهٔ `month`/`year` از مسیر `Jalali.fromDateTime(...).toDateTime()` می‌گذرد که **نیمه‌شب** برمی‌گرداند → ساعت بی‌صدا پاک می‌شود.
- در شاخهٔ `agenda`/`day`/`week` ساعت حفظ می‌شود.
- `_calculateDateRangeForScale` ورودی را با `DateTime(date.year, date.month, date.day)` نرمال می‌کند، اما `loadAgendaRange` **نمی‌کند** و `anchor.subtract(Duration(days: daysBack))` را با ساعت می‌سازد.

نتیجه: معنای `_selectedDate` بین مقیاس‌ها فرق می‌کند و هر مقایسهٔ `isAtSameMomentAs` شکننده است.

**فایل‌ها:** `journey_controller.dart`

**کار دقیق:**

1. مقدار اولیه: `DateTime _selectedDate = DateKey.dayOf(DateTime.now());`
2. در `selectDate`: `_selectedDate = DateKey.dayOf(date);`
3. در `navigatePeriod`، همهٔ شاخه‌ها: `_selectedDate = DateKey.dayOf(<محاسبه>)` و `add(Duration(days: n))` → `DateKey.addDays(_selectedDate, n)`.
4. در `loadAgendaRange`: `final anchor = DateKey.dayOf(anchorDate ?? _selectedDate);` و مرزها با `DateKey.addDays(anchor, -daysBack)` / `DateKey.addDays(anchor, daysForward)`.
5. یک کامنت بگذار: `/// همیشه نیمه‌شب محلی. هیچ‌وقت ساعت را در _selectedDate نگه نداریم.`

**معیار پذیرش:** `flutter analyze` پاک؛ تست CAL-56 ثابت می‌کند که بعد از `navigatePeriod` در هر پنج مقیاس، `_selectedDate.hour == 0 && minute == 0 && second == 0`.

**commit:** `fix(calendar): CAL-08 — نرمال‌سازی تاریخ انتخابی به نیمه‌شب`

---

## فاز B — درستی داده و بازگردانی (CAL-09 … CAL-16)

هدف فاز: هیچ عملیات تقویم نباید دادهٔ کاربر را بی‌صدا از بین ببرد. الان سه مسیر از‌دست‌رفتن داده وجود دارد.

---

### CAL-09 — `upsert` ادغامی: توقف نابودی ستون‌های همسایه

**باگ (بحرانی، از‌دست‌رفتن داده):** `SqliteOccurrenceOverrideRepository.upsert` از `ConflictAlgorithm.replace` استفاده می‌کند و `toMap()` **همهٔ** ستون‌ها را می‌نویسد، از جمله `null`ها:

```dart
await db.insert('occurrence_overrides', override.toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace);
```

سه فاجعهٔ مشخص:

1. کاربر یک روتین را **resize** می‌کند → ردیف `(status: 'RESIZED', durationMinutes: 45, timeOfDay: null)`.
2. بعد همان را **drag** می‌کند → `_MoveItemCommand` یک `OccurrenceOverride` با فقط `timeOfDay` می‌سازد → `replace` ردیف را بازنویسی می‌کند → **`durationMinutes` به `null` برمی‌گردد**. مدت سفارشی کاربر بی‌صدا نابود شد.
3. اگر ردیف قبلی `status: 'SKIPPED'` بود (کاربر آن روز را رد کرده بود)، `drag` آن را به `'MOVED'` عوض می‌کند → **رد‌شدگی ناپدید می‌شود** و آیتم در `_assembleDay` دوباره فعال می‌شود، چون آنجا `ovr.status == 'SKIPPED'` است که `completion: skipped` را می‌سازد.
4. `createdAt` هم با «الان» بازنویسی می‌شود → تاریخ ایجاد واقعی از دست می‌رود.

**فایل‌ها:** `lib/core/domain/agenda/occurrence_override_repository.dart`

**کار دقیق:**

1. به رابطه اضافه کن:
   ```dart
   Future<OccurrenceOverride?> readOne(String sourceType, String sourceId, String dateStr);
   ```
2. `upsert` را به **read-modify-write داخل یک transaction** تبدیل کن با معناشناسی «فقط فیلدهای غیرnull را بنویس»:

```dart
@override
Future<void> upsert(OccurrenceOverride override) async {
  final db = await DatabaseHelper.instance.database;
  Future<void> run() => db.transaction((txn) async {
    final existing = await txn.query(
      'occurrence_overrides',
      where: 'sourceType = ? AND sourceId = ? AND dateStr = ?',
      whereArgs: [override.sourceType, override.sourceId, override.dateStr],
      limit: 1,
    );
    if (existing.isEmpty) {
      await txn.insert('occurrence_overrides', override.toMap());
      return;
    }
    final old = OccurrenceOverride.fromMap(existing.first);
    // ادغام: فیلد null در ورودی یعنی «دست نزن»، نه «پاک کن».
    final merged = old.copyWith(
      timeOfDay: override.timeOfDay,
      durationMinutes: override.durationMinutes,
      status: override.status,
      note: override.note,
      updatedAt: override.updatedAt,
      // createdAt عمداً پاس نمی‌شود: copyWith مقدار قدیمی را نگه می‌دارد.
    );
    await txn.update(
      'occurrence_overrides',
      merged.toMap(),
      where: 'sourceType = ? AND sourceId = ? AND dateStr = ?',
      whereArgs: [override.sourceType, override.sourceId, override.dateStr],
    );
  });
  try {
    await run();
  } catch (e, st) {
    if (e is DatabaseException && e.toString().contains('no such table')) {
      await ensureTable(db);
      await run();
    } else {
      RitmoLog.error('OccurrenceOverrideRepo', 'upsert failed', e, st);
      rethrow;
    }
  }
}
```

3. **مهم:** `copyWith` فعلی معناشناسی «null یعنی دست نزن» دارد که همین‌جا لازم است — دست نزن.
4. برای پاک کردن *صریح* یک فیلد، متد جدا اضافه کن (نه از طریق `upsert`):
   ```dart
   Future<void> clearFields(String sourceType, String sourceId, String dateStr,
       {bool timeOfDay = false, bool durationMinutes = false, bool status = false});
   ```

**معیار پذیرش:** تست CAL-57 این سناریو را پاس کند: resize → drag → مقدار `durationMinutes` حفظ شده؛ skip → drag → `status` هنوز `'SKIPPED'` است؛ `createdAt` عوض نشده.

**commit:** `fix(calendar): CAL-09 — upsert ادغامی برای override و توقف نابودی ستون‌ها`

---

### CAL-10 — snapshot خواندن override برای بازگردانی درست

**فایل‌ها:** `occurrence_override_repository.dart`

**کار دقیق:** اضافه کن:

```dart
/// همهٔ overrideهای این منبع از [dateStr] به بعد — برای snapshot قبل از removeAllFuture.
Future<List<OccurrenceOverride>> readAllFuture(
    String sourceType, String sourceId, String dateStr);

/// درج دسته‌ای بدون ادغام — فقط برای بازگردانی snapshot. داخل یک transaction.
Future<void> restoreAll(List<OccurrenceOverride> overrides);
```

`restoreAll` باید ردیف‌ها را عیناً برگرداند (`ConflictAlgorithm.replace` اینجا **درست** است، چون snapshot کامل است).

**معیار پذیرش:** هر دو متد در پیاده‌سازی SQLite و در fake تست موجودند.

**commit:** `fix(calendar): CAL-10 — افزودن readOne/readAllFuture/restoreAll به مخزن override`

---

### CAL-11 — بازگردانی مبتنی بر snapshot در `_MoveItemCommand` و `_ResizeItemCommand`

**باگ (بحرانی، از‌دست‌رفتن داده):** `undo()` در حالت `thisDayOnly` **کل ردیف را حذف می‌کند**:

```dart
@override
Future<void> undo() async {
  if (scope == CalendarEditScope.thisDayOnly) {
    await _overrideRepo.remove(item.domain.name, item.sourceId, item.dateStr);
  }
  ...
}
```

اگر قبل از این move، override دیگری وجود داشت (resize قبلی، یا `status: 'SKIPPED'`، یا `note` کاربر)، undo **همه‌اش** را پاک می‌کند. undo باید فقط اثر *همین* دستور را برگرداند، نه تاریخ را پاک کند.

**فایل‌ها:** `journey_controller.dart`

**کار دقیق:**

1. به هر دو دستور یک فیلد اضافه کن: `OccurrenceOverride? _beforeSnapshot;`
2. در ابتدای `execute()`، **قبل از** هر نوشتن:
   ```dart
   _beforeSnapshot = await _overrideRepo.readOne(
       item.domain.name, item.sourceId, item.dateStr);
   ```
3. در `undo()` برای `thisDayOnly`:
   ```dart
   final before = _beforeSnapshot;
   if (before == null) {
     await _overrideRepo.remove(item.domain.name, item.sourceId, item.dateStr);
   } else {
     await _overrideRepo.restoreAll([before]);
   }
   ```
4. اگر `execute()` دو بار صدا زده شد (redo)، `_beforeSnapshot` را بازنویسی **نکن** — با یک `if (_beforeSnapshot == null)` یا یک flag جدا محافظت کن، وگرنه redo، snapshot را با حالت بعد از execute عوض می‌کند.

**معیار پذیرش:** تست CAL-57: resize → move → undo → مدت resize‌شده برگشته و `timeOfDay` به حالت قبل از move است.

**commit:** `fix(calendar): CAL-11 — بازگردانی مبتنی بر snapshot برای جابه‌جایی و تغییر مدت`

---

### CAL-12 — `allFutureDays`: snapshot و transaction برای `removeAllFuture`

**باگ (بحرانی، از‌دست‌رفتن داده):** در حالت «همهٔ روزهای آینده»:

```dart
await _overrideRepo.removeAllFuture(item.domain.name, item.sourceId, item.dateStr);
await actionHandler.updateAgendaItemTimeAndDuration(item: item, newTimeOfDay: newTimeOfDay);
```

این دستور **همهٔ** overrideهای آن منبع از امروز به بی‌نهایت را حذف می‌کند — بی هیچ سقفی. اما `undo()` فقط زمان قدیمی را روی schedule پایه برمی‌گرداند و **هیچ‌یک از آن ردیف‌های حذف‌شده را باز نمی‌گرداند**. دقیقاً یعنی: کاربر ده روز آیندهٔ خودش را دستی تنظیم کرده، یک بار «همهٔ روزهای آینده» را جابه‌جا می‌کند، پشیمان می‌شود و undo می‌زند — ده تنظیم دستی برنمی‌گردد.

همچنین دو عمل (delete + update) در **دو transaction جدا** هستند؛ کرش بین آن‌ها وضعیت نیمه‌کاره می‌سازد.

**فایل‌ها:** `journey_controller.dart`, `occurrence_override_repository.dart`

**کار دقیق:**

1. فیلد اضافه کن: `List<OccurrenceOverride> _futureSnapshot = const [];`
2. در `execute()` برای `allFutureDays`، قبل از حذف:
   ```dart
   _futureSnapshot = await _overrideRepo.readAllFuture(
       item.domain.name, item.sourceId, item.dateStr);
   ```
3. در `undo()` برای `allFutureDays`، بعد از برگرداندن زمان پایه:
   ```dart
   if (_futureSnapshot.isNotEmpty) {
     await _overrideRepo.restoreAll(_futureSnapshot);
   }
   ```
4. `removeAllFuture` را با یک سقف امن محدود کن: پارامتر اختیاری `String? untilDateStr` اضافه کن و از `journey_controller` یک سال جلوتر را پاس بده. حذف نامحدود تا ابد در یک اپ با دادهٔ محلی، خطرناک است.

**معیار پذیرش:** تست CAL-57: سه override آینده بساز → move با `allFutureDays` → undo → هر سه برگشته‌اند با مقادیر یکسان.

**commit:** `fix(calendar): CAL-12 — snapshot و بازگردانی overrideهای آینده`

---

### CAL-13 — حذف کلید برهنهٔ `sourceId` در نگاشت override

**باگ (بحرانی، آلودگی بین‌دامنه‌ای):** در `DayAgendaService._assembleDay`:

```dart
for (final ovr in dayOverrides) {
  overrideMap['${ovr.sourceType.toLowerCase()}:${ovr.sourceId}'] = ovr;
  overrideMap[ovr.sourceId] = ovr;              // ← کلید برهنه
}
...
final ovr = overrideMap['${item.domain.name.toLowerCase()}:${item.sourceId}']
    ?? overrideMap[item.sourceId];              // ← fallback خطرناک
```

دو خرابی:

1. `sourceId`ها شناسهٔ رکورد در جدول‌های **مختلف**اند (task، routine، course، …). پس `sourceId == '42'` در چند دامنه هم‌زمان وجود دارد. یک override که کاربر برای `task:42` ساخته، از طریق fallback روی `routine:42` هم اعمال می‌شود → **جابه‌جا کردن یک تسک، یک روتین بی‌ربط را در همان روز جابه‌جا می‌کند.**
2. اگر دو override با `sourceId` یکسان از دو دامنه در یک روز باشند، `overrideMap[ovr.sourceId] = ovr` دومی اولی را **بازنویسی** می‌کند → کدام برنده شود به ترتیب ردیف‌های SQLite بستگی دارد؛ یعنی رفتار نامعین.

**فایل‌ها:** `day_agenda_service.dart`

**کار دقیق:**

1. خط `overrideMap[ovr.sourceId] = ovr;` را **حذف** کن.
2. `?? overrideMap[item.sourceId]` را **حذف** کن. فقط کلید کامل `domain:sourceId`.
3. اگر نگرانی «ردیف‌های قدیمی با `sourceType` خالی/غلط» هست: یک migration بنویس که ردیف‌هایی با `sourceType` تهی یا نامعتبر را **حذف** کند (نه اینکه حدس بزند مال کدام دامنه‌اند)، و در ledger یادداشت کن چند ردیف پاک شد. حدس زدن دامنه، همان باگ را به migration منتقل می‌کند.
4. کلیدسازی را به یک تابع تک‌منبع ببر تا نوشتن و خواندن هرگز واگرا نشوند:
   ```dart
   static String overrideKey(String sourceType, String sourceId) =>
       '${sourceType.toLowerCase()}:$sourceId';
   ```
   و در هر دو طرف از همان استفاده کن.

**معیار پذیرش:**

```bash
rg -n "overrideMap\[ovr.sourceId\]|overrideMap\[item.sourceId\]" lib/   # خالی
```
تست CAL-57: یک `task:42` و یک `routine:42` در یک روز؛ override روی task؛ روتین **بی‌تغییر** بماند.

**commit:** `fix(calendar): CAL-13 — حذف کلید برهنهٔ sourceId و توقف آلودگی بین‌دامنه‌ای`

---

### CAL-14 — پایهٔ مشترک دستورات تقویم: بی‌اعتبارسازی کش اجباری

**باگ:** `_MoveItemCommand` و `_ResizeItemCommand` قبل از `onRefresh()` این را صدا می‌زنند:

```dart
DayAgendaService.instance.invalidateDate(item.dateStr);
```

اما `_ScheduleItemCommand` و `_UnscheduleItemCommand` **نمی‌زنند**. چون کش `DayAgendaService` فقط روزهای **غیرخالی** را نگه می‌دارد و روزی که آیتم زمان‌بندی می‌شود دقیقاً غیرخالی است، ردیف کش‌شده باقی می‌ماند و `refresh()` همان دادهٔ قدیمی را برمی‌گرداند → **پس از کشیدن یک آیتم بی‌زمان روی تایم‌لاین، ساعت قدیمی نمایش داده می‌شود** تا زمانی که یک رویداد بی‌ربط کش را پاک کند.

این باگ از جنس «فراموش‌کردنی» است؛ راه‌حل باید ساختاری باشد، نه اضافه‌کردن یک خط.

**فایل‌ها:** `journey_controller.dart`

**کار دقیق:** یک کلاس پایهٔ abstract بساز و هر چهار دستور از آن ارث ببرند:

```dart
abstract class _CalendarCommand implements UndoableCommand {
  _CalendarCommand({required this.item, required this.onRefresh});

  final AgendaItem item;
  final Future<void> Function() onRefresh;

  /// منطق خالص دستور. زیرکلاس‌ها فقط این را پیاده می‌کنند.
  Future<void> applyForward();
  Future<void> applyBackward();

  /// این دو final‌اند تا هیچ زیرکلاسی نتواند بی‌اعتبارسازی کش را فراموش کند.
  @override
  Future<void> execute() async {
    await applyForward();
    DayAgendaService.instance.invalidateDate(item.dateStr);
    await onRefresh();
  }

  @override
  Future<void> undo() async {
    await applyBackward();
    DayAgendaService.instance.invalidateDate(item.dateStr);
    await onRefresh();
  }
}
```

هر چهار دستور را بازنویسی کن تا `applyForward`/`applyBackward` را پیاده کنند و `execute`/`undo` را **override نکنند**. دستوری که چند روز را دست می‌زند (`allFutureDays`) باید `invalidateAll()` صدا بزند — برای آن یک `bool get affectsMultipleDays => false;` روی پایه بگذار و در `execute`/`undo` بر اساسش تصمیم بگیر.

**معیار پذیرش:**

```bash
rg -n "class _.*ItemCommand implements UndoableCommand" lib/   # خالی؛ همه از _CalendarCommand ارث می‌برند
rg -c "invalidateDate" lib/features/calendar/presentation/journey_controller.dart   # حداکثر ۲ (فقط در پایه)
```

**commit:** `fix(calendar): CAL-14 — پایهٔ مشترک دستورات و بی‌اعتبارسازی اجباری کش`

---

### CAL-15 — `skipItem` برای دامنه‌های غیرروتین معنای غلطی دارد

**باگ:**

```dart
Future<void> skipItem(AgendaItem item) async {
  if (item.domain == AgendaDomain.routine) {
    await _kernel.execute(SkipOccurrenceCommand(...));
  } else {
    await _actionHandler.toggleAgendaItem(item: item, isDone: false);  // ← غلط
  }
```

`isDone: false` یعنی «انجام‌نشده علامت بزن»، یعنی **لغو انجام‌شدن** — نه «رد کن». برای آیتمی که از قبل انجام‌نشده است (که حالت غالب هنگام زدن «رد کردن» است) این یک **no-op کامل** است: آیتم در فهرست می‌ماند، کاربر فکر می‌کند دکمه خراب است، و هیچ خطایی هم نمایش داده نمی‌شود.

زیرساخت درست از قبل موجود است: `_assembleDay` وقتی `ovr.status == 'SKIPPED'` باشد `completion: skipped` می‌دهد.

**فایل‌ها:** `journey_controller.dart`

**کار دقیق:**

1. یک `_SkipItemCommand extends _CalendarCommand` بساز:
   - `applyForward`: snapshot بگیر، بعد `upsert(OccurrenceOverride(..., status: 'SKIPPED'))`.
   - `applyBackward`: snapshot را با `restoreAll` برگردان یا اگر snapshot نبود `remove` کن.
2. `skipItem` برای دامنهٔ `routine` همان `SkipOccurrenceCommand` هستهٔ اجرا را نگه دارد (تاریخچهٔ occurrence آنجا معنا دارد) اما برای بقیهٔ دامنه‌ها از `_SkipItemCommand` استفاده کند.
3. هر دو مسیر باید `CommandStack.instance.push(command)` بزنند تا «بازگردانی» کار کند — الان مسیر skip **هیچ‌وقت push نمی‌شود**، پس رد کردن غیرقابل بازگشت است.

**معیار پذیرش:** تست CAL-56: `skipItem` روی یک `task` یک override با `status: 'SKIPPED'` می‌سازد و `CommandStack` یک دستور بازگشت‌پذیر دارد.

**commit:** `fix(calendar): CAL-15 — رد کردن واقعی برای دامنه‌های غیرروتین`

---

### CAL-16 — `postponeItem` برای بیشتر دامنه‌ها بی‌صدا هیچ کاری نمی‌کند

**باگ (سه‌لایه):**

```dart
Future<void> postponeItem(AgendaItem item, {int days = 1}) async {
  ...
  if (item.domain == AgendaDomain.task) {
    final task = await SimpleTaskRepository.instance.getById(item.sourceId);
    if (task != null) {
      final currentDate = DateTime.tryParse(task.dueDate ?? item.dateStr) ?? DateTime.now();
      final nextDate = currentDate.add(Duration(days: days));
      ...
    }
  }
  await refresh();   // ← برای همهٔ دامنه‌های دیگر: هیچ اتفاقی نیفتاد، ولی رفرش شد
}
```

1. **no-op خاموش:** برای `routine`, `worship`, `prayer`, `course`, `goalStep`, `konkur`, `sport`, `medicine`, `appointment`, `commitment`, `cycle`, `event` هیچ کاری نمی‌کند. نه خطا، نه پیام. کاربر «به فردا بیانداز» می‌زند، انیمیشن رفرش می‌بیند، و آیتم سر جایش است.
2. **ریاضی تاریخ غلط:** اگر تسک ده روز عقب‌افتاده باشد، `currentDate` همان تاریخ گذشته است و `+1 روز` آن را به **نُه روز پیش** می‌برد؛ یعنی همچنان معوقه. معنای درست: `max(امروز, dueDate) + days`.
3. **غیرقابل بازگشت:** `CommandStack.instance.push` صدا زده نمی‌شود، در حالی که move/resize/schedule می‌زنند. ناسازگاری رفتار undo در همان صفحه.
4. `if (task != null)` — اگر تسک پیدا نشد، سکوت.

**فایل‌ها:** `journey_controller.dart`

**کار دقیق:**

1. یک `_PostponeItemCommand extends _CalendarCommand` بساز که دو استراتژی دارد:
   - **دامنهٔ `task`:** `dueDate` را عوض کن. تاریخ مبدأ:
     ```dart
     final today = DateKey.dayOf(DateTime.now());
     final due = DateKey.parse(task.dueDate ?? item.dateStr) ?? today;
     final base = due.isBefore(today) ? today : due;
     final next = DateKey.addDays(base, days);
     ```
     `applyBackward` مقدار `dueDate` قبلی را برمی‌گرداند (snapshot بگیر).
   - **دامنه‌های تکرارشونده:** روی روز مبدأ یک override با `status: 'SKIPPED'` بگذار و روی روز مقصد یک override با `timeOfDay` و `durationMinutes` همان آیتم بساز. `applyBackward` هر دو را با snapshot برمی‌گرداند. **هر دو نوشتن در یک transaction.**
2. برای دامنه‌هایی که واقعاً قابل تعویق نیستند (مثل `prayer` که زمانش نجومی است، و `cycle`): یک `Set<AgendaDomain> _nonPostponableDomains` بساز و صریحاً:
   ```dart
   if (_nonPostponableDomains.contains(item.domain)) {
     _errorMessage = CalendarMessagesFa.notSupported;
     notifyListeners();
     return;
   }
   ```
3. همیشه `CommandStack.instance.push(command)` بعد از `execute()` موفق.
4. اگر `task == null` بود، `RitmoLog.error` + `_errorMessage = CalendarMessagesFa.postpone`.

**معیار پذیرش:** تست CAL-56 برای هر سه حالت: تسک عادی، تسک معوقه (باید به `امروز + days` برود نه گذشته)، و دامنهٔ غیرمجاز (باید پیام فارسی بدهد و `CommandStack` خالی بماند).

**commit:** `fix(calendar): CAL-16 — تعویق واقعی، بازگشت‌پذیر و با ریاضی تاریخ درست`

---

## فاز C — کنترلر: مسابقه، طوفان رفرش، مقیاس (CAL-17 … CAL-26)

---

### CAL-17 — توکن نسل بارگذاری برای جلوگیری از نوشتن بی‌ترتیب

**باگ (مسابقه):** `loadForActiveScale` و `loadAgendaRange` هر دو `async`اند و در پایان `_rangeSnapshots = newSnapshots;` می‌نویسند. هیچ محافظی نیست. سناریوی واقعی: کاربر سریع سه بار swipe می‌کند → سه `agendaForRange` هم‌زمان در جریان است → هر کدام **دیرتر** تمام شود برنده است. چون این فراخوان‌ها I/O دارند و زمان‌شان یکسان نیست، **دادهٔ قدیمی می‌تواند روی دادهٔ جدید بنویسد** و کاربر هفتهٔ اشتباه را ببیند.

`_isExecutingAction` فقط عملیات نوشتن را قفل می‌کند، بارگذاری‌ها را نه.

**فایل‌ها:** `journey_controller.dart`

**کار دقیق:**

1. فیلد اضافه کن: `int _loadGeneration = 0;`
2. در ابتدای هر دو متد بارگذاری:
   ```dart
   final gen = ++_loadGeneration;
   ```
3. **بعد از هر `await`** این محافظ را بگذار (نه فقط یک بار در آخر):
   ```dart
   if (_isDisposed || gen != _loadGeneration) return;
   ```
4. در `finally`، `_isLoading = false` را فقط وقتی بگذار که `gen == _loadGeneration` باشد؛ وگرنه یک بارگذاری منسوخ، اسپینر بارگذاری زندهٔ فعلی را خاموش می‌کند.

**معیار پذیرش:** تست CAL-56: دو `loadAgendaRange` را با تأخیر مصنوعی معکوس اجرا کن؛ نتیجهٔ نهایی باید مال فراخوان **آخر** باشد.

**commit:** `fix(calendar): CAL-17 — توکن نسل بارگذاری و رفع مسابقهٔ بارگذاری`

---

### CAL-18 — حذف شاخهٔ مردهٔ `agenda` و یک تعریف واحد برای پنجرهٔ اجندا

**باگ (دو منبع حقیقت + کد مرده):** دو تعریف متناقض از بازهٔ اجندا در یک فایل وجود دارد:

```dart
// loadForActiveScale — مسیر واقعی
if (_activeScale == JourneyScale.agenda) {
  await loadAgendaRange(anchorDate: _selectedDate);   // پنجره: -14 .. +45
  return;
}

// _calculateDateRangeForScale — هرگز اجرا نمی‌شود
case JourneyScale.agenda:
  return (start: dateOnly, end: dateOnly.add(const Duration(days: 59)));   // پنجره: 0 .. +59
```

شاخهٔ دوم **کد مرده** است. خطرناک‌تر: اگر روزی کسی short-circuit را بردارد، پنجره از «امروز» شروع می‌شود و سطل «معوقه» در `bucketRange` **برای همیشه خالی می‌ماند** — چون هیچ روز گذشته‌ای بارگذاری نمی‌شود. یک باگ خاموش که منتظر است.

**فایل‌ها:** `journey_controller.dart`

**کار دقیق:**

1. ثابت‌ها را در بالای کلاس بگذار:
   ```dart
   static const int agendaWindowDaysBack = 14;
   static const int agendaWindowDaysForward = 45;
   ```
2. شاخهٔ `case JourneyScale.agenda:` را از `_calculateDateRangeForScale` **حذف** کن و به‌جایش:
   ```dart
   case JourneyScale.agenda:
     // مقیاس اجندا بازهٔ خودش را دارد (loadAgendaRange) و هرگز به اینجا نمی‌رسد.
     throw StateError('agenda scale must use loadAgendaRange');
   ```
3. `loadAgendaRange` پیش‌فرض‌هایش را از همان ثابت‌ها بگیرد.
4. کامنت بگذار: `/// معوقه فقط تا agendaWindowDaysBack روز عقب دیده می‌شود. CAL-38 سقف را برمی‌دارد.`

**معیار پذیرش:** `rg -n "days: 59" lib/` خالی. تست CAL-56 ثابت کند فراخوانی `_calculateDateRangeForScale` با `agenda` پرتاب می‌کند.

**commit:** `fix(calendar): CAL-18 — حذف تعریف مردهٔ بازهٔ اجندا`

---

### CAL-19 — پنجرهٔ بارگذاری صریح و عبور `isBackgroundRefresh`

**باگ:** `refresh()` → `loadForActiveScale(isBackgroundRefresh: true)` → در مقیاس اجندا به `loadAgendaRange(...)` می‌رسد که **پارامتر `isBackgroundRefresh` ندارد**؛ پس پرچم بی‌صدا دور انداخته می‌شود و منطق `_isLoading` دوباره از صفر اجرا می‌شود. علاوه بر این `loadAgendaRange` هر بار پنجره را از نو حول `_selectedDate` می‌سازد و هیچ‌کس نمی‌داند «الان چه بازه‌ای در حافظه است».

**فایل‌ها:** `journey_controller.dart`

**کار دقیق:**

1. فیلدهای صریح اضافه کن و در getter عمومی بگذار:
   ```dart
   DateTime? _windowStart;
   DateTime? _windowEnd;
   DateTime? get windowStart => _windowStart;
   DateTime? get windowEnd => _windowEnd;
   ```
2. امضا: `Future<void> loadAgendaRange({DateTime? anchorDate, int daysBack = agendaWindowDaysBack, int daysForward = agendaWindowDaysForward, bool isBackgroundRefresh = false})`
3. شرط لودینگ در هر دو متد **یکسان** شود:
   ```dart
   if (!isBackgroundRefresh && _snapshot == null) _isLoading = true;
   ```
4. بعد از موفقیت: `_windowStart = start; _windowEnd = end;`
5. `refresh()` پرچم را پاس بدهد (خودش الان درست است، فقط مسیر اجندا باید محترمش بدارد).

**معیار پذیرش:** تست CAL-56: `refresh()` روی اجندا با `_snapshot != null` هرگز `isLoading` را `true` نکند.

**commit:** `fix(calendar): CAL-19 — پنجرهٔ صریح و احترام به رفرش پس‌زمینه`

---

### CAL-20 — تعویض مقیاس، دادهٔ مقیاس قبلی را نشان می‌دهد

**باگ:** در `loadForActiveScale`:

```dart
if (!isBackgroundRefresh && _snapshot == null) {
  _isLoading = true;
}
```

هنگام تعویض اجندا → ماه، `_snapshot != null` است، پس `_isLoading` **false می‌ماند** و `_rangeSnapshots` هنوز پنجرهٔ ۶۰ روزهٔ اجندا را دارد. تا وقتی `await agendaForRange` برگردد، نمای ماه با دادهٔ بازهٔ اشتباه رندر می‌شود: نقطه‌ها و شمارش روزها غلط‌اند. `_rangeSnapshots` هیچ‌جا پاک نمی‌شود.

**فایل‌ها:** `journey_controller.dart`

**کار دقیق:** در `setScale`، قبل از `loadForActiveScale()`:

```dart
void setScale(JourneyScale scale) {
  if (_isDisposed || _activeScale == scale) return;
  _activeScale = scale;
  // دادهٔ مقیاس قبلی برای مقیاس جدید معنا ندارد؛ نگه‌داشتنش نمای غلط می‌سازد.
  _rangeSnapshots = const {};
  _snapshot = null;
  _windowStart = null;
  _windowEnd = null;
  _isLoading = true;
  notifyListeners();
  loadForActiveScale();
}
```

همین کار را در `selectDate` **فقط وقتی** `scaleToSet != null && scaleToSet != _activeScale` انجام بده (تعویض تاریخ در همان مقیاس نباید فلش خالی بسازد).

**معیار پذیرش:** تست CAL-56: پس از `setScale(month)` و قبل از تمام‌شدن بارگذاری، `rangeSnapshots.isEmpty && isLoading == true`.

**commit:** `fix(calendar): CAL-20 — پاک‌سازی داده هنگام تعویض مقیاس`

---

### CAL-21 — یک fallback واحد برای `_snapshot` تهی

**باگ:** دو مسیر بارگذاری رفتار متفاوت دارند:

```dart
// loadForActiveScale — بدون fallback
_snapshot = _rangeSnapshots[selectedKey];

// loadAgendaRange — با fallback
_snapshot = _rangeSnapshots[selectedKey] ??
    _snapshotBuilder.buildSnapshot(DayAgenda(dateStr: selectedKey, items: const []));
```

پس در مقیاس day/week/month/year اگر کلید در نقشه نباشد (مثلاً بعد از باگ کلید تاریخ، یا `appStartDate` فیلترکردن روزهای قبل از نصب) `_snapshot == null` می‌شود و UI حالت «خطا/تهی» نامعلوم نشان می‌دهد نه «روز خالی».

**فایل‌ها:** `journey_controller.dart`

**کار دقیق:** یک متد خصوصی واحد بساز و هر دو مسیر از آن استفاده کنند:

```dart
DayAgendaSnapshot _snapshotForSelectedDate() {
  final key = DateKey.of(_selectedDate);
  return _rangeSnapshots[key] ??
      _snapshotBuilder.buildSnapshot(DayAgenda(dateStr: key, items: const []));
}
```

نوع `_snapshot` را می‌توانی non-nullable نکنی (UI به null وابسته است)، اما هر دو مسیر باید همین متد را صدا بزنند.

**معیار پذیرش:** `rg -n "_rangeSnapshots\[selectedKey\]" lib/` خالی.

**commit:** `fix(calendar): CAL-21 — fallback یکسان برای روز انتخابی`

---

### CAL-22 — `loadDefaultScale`: SQL خام در لایهٔ نمایش + مسابقه

**باگ (سه‌لایه):**

```dart
final db = await DatabaseHelper.instance.database;
final rows = await db.query('app_settings', where: 'key = ?', whereArgs: ['calendar_default_scale'], limit: 1);
...
_activeScale = scale;
notifyListeners();          // ← داده بارگذاری نمی‌شود!
...
} catch (e) {
  debugPrint('[JourneyController] loadDefaultScale error: $e');
}
```

1. **نقض معماری:** یک `ChangeNotifier` در `presentation` مستقیم SQL می‌زند و `SettingsService` را دور می‌زند.
2. **مسابقه:** فقط `_activeScale` را عوض می‌کند و `notifyListeners()` می‌زند اما **بارگذاری نمی‌کند**. اگر این متد بعد از اولین `loadForActiveScale()` تمام شود، مقیاس به مثلاً `month` می‌رود در حالی که `_rangeSnapshots` پنجرهٔ اجندا را دارد — و هیچ بارگذاری‌ای هم شروع نمی‌شود. کاربر یک نمای ماه با دادهٔ غلط می‌بیند تا دستی چیزی را لمس کند.
3. **بلع خطا** با `debugPrint`.

**فایل‌ها:** `journey_controller.dart`, و بررسی `journey_screen.dart` برای ترتیب فراخوانی در `initState`.

**کار دقیق:**

1. خواندن را به `SettingsService` ببر (اگر متد getter وجود ندارد، اضافه کن: `Future<String?> getString(String key)`).
2. `catch` را به `RitmoLog.error('JourneyController', 'loadDefaultScale failed', e, st)` عوض کن.
3. بعد از اعمال مقیاس، **بارگذاری کن**:
   ```dart
   if (scale != _activeScale) {
     _activeScale = scale;
     await loadForActiveScale();
   }
   ```
4. در `journey_screen.dart`: `loadDefaultScale()` باید **قبل از** اولین بارگذاری `await` شود، یا اگر معماری اجازه نمی‌دهد، `loadForActiveScale()` اولیه فقط پس از آن صدا زده شود. حتماً کامنت K22 موجود در فایل را بخوان و رعایت کن: اگر فراخوان `selectDate(scaleToSet: ...)` مقیاس را صریح داده (مثلاً از نوتیفیکیشن یا `initialItemId`)، این متد **نباید** آن را override کند. برای همین یک فلگ اضافه کن:
   ```dart
   bool _scaleExplicitlySet = false;   // در selectDate با scaleToSet != null مقدار true می‌گیرد
   ```
   و در `loadDefaultScale` اول `if (_scaleExplicitlySet) return;`.

**معیار پذیرش:** `rg -n "app_settings" lib/features/` خالی. تست CAL-56: با `_scaleExplicitlySet == true`، `loadDefaultScale` مقیاس را عوض نکند.

**commit:** `fix(calendar): CAL-22 — خواندن مقیاس پیش‌فرض از SettingsService و رفع مسابقه`

---

### CAL-23 — `setScale` مقیاس را ذخیره نمی‌کند

**باگ:** کلید `calendar_default_scale` خوانده می‌شود اما `setScale` هرگز آن را نمی‌نویسد. یعنی «مقیاس پیش‌فرض» فقط از شیت تنظیمات عوض می‌شود و اپ هیچ‌وقت آخرین مقیاس استفاده‌شده را به یاد نمی‌آورد — رفتاری که هر کاربر تقویم انتظارش را دارد.

**فایل‌ها:** `journey_controller.dart`, و شیت مربوطه (`calendar_management_sheet.dart`) برای نبستن دو مسیر نوشتن.

**کار دقیق:**

1. یک متد کمکی: `static String _scaleToString(JourneyScale s) => s.name;` (نام enum دقیقاً همان رشته‌های `_scaleFromString` است — بررسی کن).
2. در `setScale`، بعد از اعمال، **بدون await کردن UI**:
   ```dart
   SettingsService.instance
       .setString('calendar_default_scale', scale.name)
       .catchError((e, st) => RitmoLog.error('JourneyController', 'persist scale failed', e, st));
   ```
3. اگر شیت تنظیمات هم همین کلید را می‌نویسد، مطمئن شو هر دو از یک متد `SettingsService` استفاده می‌کنند و هیچ‌کدام SQL خام نمی‌زنند.
4. `_scaleFromString` را نگه دار اما `default:` آن را با `RitmoLog.error` همراه کن — یک مقدار نامعتبر در دیتابیس باید دیده شود، نه بی‌صدا به `agenda` سقوط کند.

**معیار پذیرش:** تست CAL-56 با یک `SettingsService` جعلی ثابت کند `setScale(week)` مقدار `'week'` را می‌نویسد.

**commit:** `fix(calendar): CAL-23 — ذخیرهٔ مقیاس انتخابی`

---

### CAL-24 — طوفان رفرش: دو منبع رویداد و صفر debounce

**باگ (کارایی جدی):** کنترلر **هم‌زمان** به دو منبع گوش می‌دهد:

```dart
_subscription = _eventBus.onEvents.listen(_handleEvent);
RitmoEvents.routineChangedNotifier.addListener(_onRoutineChangedNotification);
```

و `DayAgendaService._scheduleUiRefresh()` خودش برای رویدادهای `_uiRefreshEvents` تابع `RitmoEvents.notifyRoutineChanged()` را صدا می‌زند. پس یک `TaskToggled` این زنجیره را می‌سازد:

1. رویداد روی bus → `_handleEvent` → `refresh()` → **یک `agendaForRange` روی ۶۰ روز**
2. سرویس با debounce ۳۵۰ms → `notifyRoutineChanged()` → `routineChangedNotifier` → `_onRoutineChangedNotification` → `refresh()` → **دومین `agendaForRange` روی ۶۰ روز**

یعنی هر تیک زدن یک تسک، دو بازسازی کامل ۶۰ روزه. کنترلر **هیچ debounce ندارد**. علاوه بر این، `_handleEvent` یک زنجیرهٔ ۲۴ تایی `if (event.type == '...' || ...)` با رشته‌های خام است — خطای تایپی در آن بی‌صدا رویداد را می‌خورد و هیچ تستی نمی‌گیردش.

نکتهٔ مهم: `DayAgendaService` عمداً `'RoutineChanged'` را از `_uiRefreshEvents` بیرون گذاشته (کامنت طولانی فارسی درباره حلقهٔ خودتغذیه و OOM). اما `JourneyController._handleEvent` **`'RoutineChanged'` را دارد** و به آن `refresh()` می‌دهد. آن حلقه را نمی‌بندد چون کنترلر رویداد جدید تولید نمی‌کند، ولی نشان می‌دهد دو لیست رویداد مستقل و ناهمگام‌اند.

**فایل‌ها:** `journey_controller.dart`

**کار دقیق:**

1. زنجیرهٔ `if` را با یک ثابت جایگزین کن و کنار آن کامنت بگذار که باید با `DayAgendaService._cacheInvalidatingEvents` همگام بماند:
   ```dart
   static const Set<String> _refreshTriggeringEvents = { ... };   // همان ۲۴ رشته
   ```
2. **یک منبع رویداد.** `routineChangedNotifier` را نگه دار (چون سرویس از آن برای فن‌اوت استفاده می‌کند) و از `_handleEvent` **فقط** رویدادهایی را بپذیر که سرویس در `_uiRefreshEvents` **ندارد** — بقیه از طریق notifier می‌آیند. اگر تفکیک شکننده بود، سادهٔ امن این است: `_handleEvent` را حذف کن و **تنها** به `routineChangedNotifier` گوش بده، و مطمئن شو هر رویدادی که تقویم لازم دارد در `DayAgendaService._uiRefreshEvents` هست. هر تصمیمی گرفتی، در کامنت دلیلش را بنویس.
3. **debounce + coalescing** در کنترلر:
   ```dart
   Timer? _refreshDebounce;
   static const _refreshDebounceDuration = Duration(milliseconds: 250);

   void _requestRefresh({String? dateStr}) {
     if (_isDisposed) return;
     if (dateStr != null) _pendingInvalidDates.add(dateStr);
     _refreshDebounce?.cancel();
     _refreshDebounce = Timer(_refreshDebounceDuration, () {
       if (_isDisposed) return;
       refresh();
     });
   }
   ```
4. **رفرش نقطه‌ای:** رویدادها `payload['date']` یا `payload['dateStr']` دارند (در `DayAgendaService._subscribeToEvents` دیده می‌شود). اگر رویداد تاریخ دارد و آن تاریخ **داخل پنجرهٔ فعلی نیست**، رفرش نکن:
   ```dart
   final d = (event.payload['date'] ?? event.payload['dateStr']) as String?;
   if (d != null && _windowStart != null && _windowEnd != null) {
     final parsed = DateKey.parse(d);
     if (parsed != null && (parsed.isBefore(_windowStart!) || parsed.isAfter(_windowEnd!))) {
       return;   // خارج از دید کاربر؛ بازسازی ۶۰ روزه لازم نیست
     }
   }
   ```
5. `_refreshDebounce?.cancel()` در `dispose()`.

**معیار پذیرش:**

```bash
rg -n "event.type == '" lib/features/calendar   # خالی
```
تست CAL-56: ده رویداد پشت‌هم در ۱۰۰ms → **دقیقاً یک** فراخوانی `agendaForRange` روی سرویس جعلی.

**commit:** `fix(calendar): CAL-24 — debounce و coalescing رفرش تقویم`

---

### CAL-25 — نشتی حافظه از طریق `CommandStack` سراسری

**باگ:** هر چهار دستور با `onRefresh: refresh` ساخته می‌شوند:

```dart
final command = _MoveItemCommand(actionHandler: _actionHandler, item: item, ..., onRefresh: refresh, ...);
await command.execute();
CommandStack.instance.push(command);
```

`refresh` یک متد bound است، پس closure یک ارجاع قوی به **کل `JourneyController`** نگه می‌دارد — و از طریق آن به `_rangeSnapshots` (تا ۶۰ روز آیتم). `CommandStack.instance` singleton سراسری است و `dispose()` کنترلر هیچ‌وقت آن را پاک نمی‌کند. یعنی هر بار کاربر صفحهٔ تقویم را باز و بسته کند و یک drag انجام داده باشد، **یک کنترلر مرده با کل snapshotهایش در حافظه می‌ماند**. `refresh()` خودش با `if (_isDisposed) return;` امن است، اما حافظه آزاد نمی‌شود.

**فایل‌ها:** `journey_controller.dart`, `lib/core/domain/commands/command_stack.dart`

**کار دقیق:** ارجاع به کنترلر را از دستورها **قطع** کن. دستورها نباید UI را بشناسند:

1. `onRefresh` را از `_CalendarCommand` **حذف** کن.
2. `_CalendarCommand.execute()` بعد از `invalidateDate` یک رویداد بفرستد:
   ```dart
   RitmoEvents.notifyRoutineChanged();   // یا رویداد اختصاصی 'CalendarItemChanged' با payload date
   ```
   کنترلر از قبل (پس از CAL-24) به همین رویداد گوش می‌دهد و با debounce رفرش می‌کند. حالا دستور، خودکفا و قابل تست است.
3. اگر `CommandStack` متد پاک‌سازی ندارد، اضافه کن (`void clear()`), اما **در `dispose()` کنترلر آن را صدا نزن** — پشتهٔ undo باید بین صفحه‌ها زنده بماند. با حذف closure، نشتی از بین رفته و پاک‌سازی لازم نیست. اگر `CommandStack` سقف اندازه ندارد، سقف بگذار (مثلاً ۵۰ دستور، قدیمی‌ترین حذف شود).
4. `undoLastAction()` در کنترلر بعد از `CommandStack.instance.undoLast()` همان‌طور `refresh()` کند (این فراخوانی مستقیم است و مشکلی ندارد).

**معیار پذیرش:** `rg -n "onRefresh" lib/features/calendar` خالی. تست CAL-56 با یک دستور جعلی ثابت کند `execute()` بدون هیچ ارجاعی به کنترلر کار می‌کند.

**commit:** `fix(calendar): CAL-25 — قطع ارجاع کنترلر از پشتهٔ دستورات`

---

### CAL-26 — درگ و ریسایز هیچ اعتبارسنجی و تشخیص تداخلی ندارند

**باگ:** `commitItemDrag(item, newTimeOfDay)` رشتهٔ ورودی را **همان‌طور که آمده** می‌نویسد:

```dart
final oldTimeOfDay = item.timeOfDay ?? '08:00';
final command = _MoveItemCommand(..., newTimeOfDay: newTimeOfDay, ...);
```

هیچ‌کدام از این‌ها انجام نمی‌شود:
- اعتبارسنجی فرمت `newTimeOfDay` (اگر ویجت رشتهٔ خراب بدهد، مستقیم در دیتابیس می‌نشیند)
- snap به `CalendarDefaults.snapIntervalMinutes` (تابع `TimelineSnappingHelper.snapStartMinutes` وجود دارد و **کنترلر هیچ‌وقت صدایش نمی‌زند**)
- کنترل `start + duration <= 1440` (آیتم می‌تواند از نیمه‌شب عبور کند و در layout حذف/بریده شود)
- **تشخیص تداخل با آیتم‌های زمان‌دار دیگر همان روز** — کاربر می‌تواند دو کار را روی هم بیندازد بدون هیچ هشداری
- کنترل `DurationBounds` در `commitItemResize`

کنترلر تنها مسیر نوشتن است؛ اعتبارسنجی باید همین‌جا باشد نه در ویجت.

**فایل‌ها:** `journey_controller.dart`

**کار دقیق:**

1. یک متد خصوصی بساز:
   ```dart
   /// null یعنی معتبر؛ در غیر این صورت پیام فارسی برمی‌گرداند.
   String? _validatePlacement({
     required AgendaItem item,
     required int startMinutes,
     required int durationMinutes,
     required bool allowOverlap,
   }) {
     if (startMinutes < 0 || startMinutes > 1439) return CalendarMessagesFa.invalidTime;
     if (durationMinutes < CalendarDefaults.minDurationMinutes) return CalendarMessagesFa.invalidTime;
     if (startMinutes + durationMinutes > 1440) return CalendarMessagesFa.invalidTime;
     if (!allowOverlap) {
       final others = (_snapshot?.items ?? const <AgendaItem>[])
           .where((o) => o.id != item.id && o.isTimed);
       for (final o in others) {
         final s = TimeOfDayMinutes.tryParse(o.timeOfDay);
         if (s == null) continue;
         final d = DurationBounds.sanitize(o.durationMinutes);
         if (startMinutes < s + d && startMinutes + durationMinutes > s) {
           return CalendarMessagesFa.overlap;
         }
       }
     }
     return null;
   }
   ```
2. در `commitItemDrag`:
   ```dart
   final raw = TimeOfDayMinutes.tryParse(newTimeOfDay);
   if (raw == null) { _errorMessage = CalendarMessagesFa.invalidTime; notifyListeners(); return; }
   final dur = item.durationMinutes ?? CalendarDefaults.fallbackDurationMinutes;
   final snapped = TimelineSnappingHelper.snapStartMinutes(raw, durationMinutes: dur);
   final err = _validatePlacement(item: item, startMinutes: snapped, durationMinutes: dur, allowOverlap: true);
   if (err != null) { _errorMessage = err; notifyListeners(); return; }
   final finalTime = TimeOfDayMinutes.format(snapped);
   ```
   و `finalTime` را به دستور بده، نه `newTimeOfDay` خام.
3. در `commitItemResize` همان الگو با `TimelineSnappingHelper.snapDurationMinutes(newDurationMinutes, startMinutes: <start>)` و `allowOverlap: true`.
4. **تداخل را فعلاً مسدود نکن، هشدار بده.** یک فیلد جدید اضافه کن: `String? _warningMessage;` + getter. اگر `_validatePlacement` با `allowOverlap: false` تداخل داد، عمل را انجام بده اما `_warningMessage = CalendarMessagesFa.overlap` بگذار تا UI یک نوار زرد نشان دهد. مسدود کردن یک الگوی موجود کاربر، رگرسیون است.
5. `_warningMessage` را در شروع هر عمل و در `clearFocusAndHighlight()` پاک کن.

**معیار پذیرش:** تست CAL-56 برای: زمان نامعتبر (رد شود)، زمان ۲۳:۵۰ با مدت ۳۰ دقیقه (رد شود چون از نیمه‌شب می‌گذرد)، زمان ۰۹:۰۷ (به ۰۹:۰۰ یا ۰۹:۱۵ snap شود)، تداخل (انجام شود ولی `warningMessage` ست شود).

**commit:** `fix(calendar): CAL-26 — اعتبارسنجی، snap و هشدار تداخل در مسیر نوشتن`

---

## فاز D — موتور چیدمان و اسنپ (CAL-27 … CAL-32)

---

### CAL-27 — محاسبهٔ `totalLanes` غلط است: هم‌پوشانی تراگذر نیست

**باگ (چیدمان بصری):** در `TimelineLayoutEngine.calculateLayout`، تعداد ستون‌ها برای **هر آیتم جداگانه** و فقط از هم‌پوشانی‌های *مستقیم* خودش محاسبه می‌شود:

```dart
final overlappingEntries = rawEntries.where((other) =>
    entry.visibleStart < other.visibleEnd && entry.visibleEnd > other.visibleStart).toList();
final maxLaneInGroup = overlappingEntries.fold<int>(
    entry.laneIndex, (maxIdx, other) => max(maxIdx, other.laneIndex));
var totalLanes = maxLaneInGroup + 1;
```

اما هم‌پوشانی یک رابطهٔ **تراگذر (transitive) نیست**. مثال مشخص:

- A: ۰۹:۰۰–۱۲:۰۰ → lane 0
- B: ۰۹:۳۰–۱۰:۰۰ → lane 1
- E: ۰۹:۳۰–۱۰:۰۰ → lane 2
- C: ۱۰:۳۰–۱۱:۰۰ → lane 1 (با B تداخل ندارد)

برای A: هم‌پوشان‌ها = {A,B,E,C} → maxLane=2 → `totalLanes=3` → عرض ۱/۳
برای C: هم‌پوشان‌ها = {C,A} → maxLane=1 → `totalLanes=2` → عرض ۱/۲ و `left = 1/2`

پس دو کارت در **یک خوشهٔ بصری** با عرض‌های ۱/۳ و ۱/۲ رندر می‌شوند: ستون‌ها روی هم نمی‌افتند اما هم‌تراز هم نیستند و بین کارت‌ها شکاف بی‌دلیل می‌افتد. این همان باگ کلاسیک «ستون‌های تقویم تراز نیست» است.

**فایل‌ها:** `timeline_layout_engine.dart`

**کار دقیق:** الگوریتم استاندارد دو مرحله‌ای را پیاده کن:

1. **مؤلفه‌های همبند (connected components)** روی گراف هم‌پوشانی بساز. چون ورودی بر اساس `visibleStart` مرتب است، یک روش خطی کافی است:
   ```dart
   final clusters = <List<_RawEntry>>[];
   var current = <_RawEntry>[];
   var clusterEnd = -1;
   for (final e in rawEntries) {           // مرتب‌شده بر visibleStart
     if (current.isEmpty || e.visibleStart < clusterEnd) {
       current.add(e);
       clusterEnd = max(clusterEnd, e.visibleEnd);
     } else {
       clusters.add(current);
       current = [e];
       clusterEnd = e.visibleEnd;
     }
   }
   if (current.isNotEmpty) clusters.add(current);
   ```
2. برای هر خوشه، lane assignment را **داخل همان خوشه** انجام بده و `totalLanes` خوشه را `maxLane + 1` بگیر.
3. **همهٔ اعضای یک خوشه همان `totalLanes` را می‌گیرند.** این نکتهٔ اصلی رفع باگ است.
4. کامنت بگذار: `/// هم‌پوشانی تراگذر نیست؛ عرض ستون باید از مؤلفهٔ همبند بیاید نه از هم‌پوشانی مستقیم.`

**معیار پذیرش:** تست CAL-54 با همان چهار آیتم بالا: هر چهار `TimelineLayoutItem` مقدار `totalLanes` یکسان داشته باشند، و مجموع `widthFraction` هیچ دو آیتم هم‌پوشانی همپوشانی هندسی نداشته باشد.

**commit:** `fix(calendar): CAL-27 — محاسبهٔ عرض ستون بر اساس مؤلفهٔ همبند`

---

### CAL-28 — کارت overflow آیتم‌های *دیده‌شده* را هم می‌شمارد

**باگ (شمارش غلط + رندر دوباره):** منطق capping اینجاست:

```dart
final processedOverflowEntries = <_RawEntry>{};
for (final entry in rawEntries) {
  if (processedOverflowEntries.contains(entry)) continue;
  ...
  if (primaryEntries.contains(entry)) {
    result.add(...);            // به‌عنوان کارت اصلی رندر شد
  } else {
    if (!overflowEntries.every((e) => processedOverflowEntries.contains(e))) {
      for (final overflowEntry in overflowEntries) processedOverflowEntries.add(overflowEntry);
      ...
      overflowCount: overflowEntries.length,
      overflowItems: overflowItemsList,
```

`overlappingEntries` و در نتیجه `primaryEntries`/`overflowEntries` برای **هر `entry` از نو** و با مجموعهٔ متفاوتی محاسبه می‌شوند. پس یک آیتم می‌تواند در ارزیابی خودش «primary» باشد و به `result` اضافه شود، و بعد در ارزیابی یک همسایه داخل `overflowEntries` قرار بگیرد و در `overflowCount` و `overflowItems` شمرده شود. نتیجهٔ کاربری: چیپ **«+۲ مورد دیگر»** آیتم‌هایی را می‌شمارد که همان لحظه روی صفحه دیده می‌شوند. `processedOverflowEntries` فقط بعد از وقوع پر می‌شود، پس جلوی این را نمی‌گیرد.

**فایل‌ها:** `timeline_layout_engine.dart`

**کار دقیق:** بعد از CAL-27 این باگ ساختاراً از بین می‌رود، چون تصمیم primary/overflow **یک بار برای هر خوشه** گرفته می‌شود نه یک بار برای هر آیتم:

1. حلقهٔ اصلی را از «برای هر entry» به **«برای هر cluster»** تبدیل کن.
2. داخل هر خوشه، یک بار مرتب‌سازی اولویت، یک بار تقسیم primary/overflow، یک بار ساخت کارت overflow.
3. `processedOverflowEntries` را **حذف** کن — دیگر لازم نیست و وجودش نشانهٔ همین باگ بود.
4. یک `assert` بگذار که هیچ `item.id` دو بار در `result` (به‌عنوان کارت یا داخل `overflowItems`) نیاید:
   ```dart
   assert(() {
     final seen = <String>{};
     for (final r in result) {
       if (!seen.add(r.item.id)) return false;
       for (final o in r.overflowItems) { if (!seen.add(o.id)) return false; }
     }
     return true;
   }(), 'یک آیتم دو بار در چیدمان ظاهر شده است');
   ```

**معیار پذیرش:** تست CAL-54: با `maxLanes: 2` و چهار آیتم هم‌پوشان، مجموع (کارت‌های اصلی + overflowItems) دقیقاً برابر تعداد ورودی و **بدون تکرار** باشد.

**commit:** `fix(calendar): CAL-28 — رفع دوباره‌شماری آیتم‌ها در کارت overflow`

---

### CAL-29 — خطای یک‌واحدی در `primaryCount` نمای دوستونی

**باگ:** `CalendarGeometry.maxLanesSplit = 2` و در موتور:

```dart
final primaryCount = maxLanes! - 1;      // = 1
final primaryEntries = overlappingEntries.take(primaryCount).toList();
final overflowEntries = overlappingEntries.skip(primaryCount).toList();
```

پس در نمای split، اگر **دو** آیتم هم‌پوشان باشند، یکی کارت می‌شود و دیگری به چیپ overflow می‌رود — در حالی که ظرفیت دو ستون موجود است و اسم ثابت هم `maxLanesSplit = 2` است. یعنی نمای دوستونی عملاً **تک‌ستونی** کار می‌کند و کاربر برای دیدن آیتم دوم باید چیپ را باز کند. حالت دو-آیتمی رایج‌ترین حالت هم‌پوشانی است.

**فایل‌ها:** `timeline_layout_engine.dart`

**کار دقیق:** جای یک ستون را فقط وقتی برای چیپ رزرو کن که واقعاً چیزی برای سرریز باشد:

```dart
final clusterSize = clusterEntries.length;
final needsOverflowChip = clusterSize > maxLanes!;
final primaryCount = needsOverflowChip ? maxLanes! - 1 : maxLanes!;
final totalLanes = needsOverflowChip ? maxLanes! : min(clusterSize, maxLanes!);
```

حالت‌هایی که باید درست شوند:
- ۲ آیتم، `maxLanes = 2` → دو کارت، بدون چیپ، `totalLanes = 2`
- ۳ آیتم، `maxLanes = 2` → یک کارت + یک چیپ با `overflowCount = 2`، `totalLanes = 2`
- ۱ آیتم → `totalLanes = 1` و عرض کامل (الان `maxLaneInGroup + 1 = 1` که درست است، حفظش کن)

**معیار پذیرش:** تست CAL-54 برای هر سه حالت بالا با اعداد صریح.

**commit:** `fix(calendar): CAL-29 — رفع خطای یک‌واحدی ظرفیت ستون در نمای دوستونی`

---

### CAL-30 — `snapDurationMinutes` می‌تواند از نیمه‌شب عبور کند

**باگ:** در `TimelineSnappingHelper`:

```dart
final untilEndOfDay = 1440 - startMinutes;
final maxAllowed = untilEndOfDay.clamp(minDurationMinutes, DurationBounds.maxMinutes);
return snapped.clamp(minDurationMinutes, maxAllowed);
```

با `startMinutes = 1430` مقدار `untilEndOfDay = 10` است، اما `clamp(15, max)` آن را **به ۱۵ بالا می‌برد**. یعنی خروجی ۱۵ دقیقه است و `1430 + 15 = 1445 > 1440` — دقیقاً همان محدودیتی که خط قصد داشت اعمال کند، توسط کرانِ پایینِ `clamp` نقض می‌شود. آیتم از نیمه‌شب می‌گذرد و در `calculateLayout` بریده یا حذف می‌شود.

**فایل‌ها:** `timeline_snapping.dart`

**کار دقیق:** به‌جای بالا بردن سقف، وضعیت غیرممکن را صریح اعلام کن:

```dart
/// null یعنی در این نقطهٔ شروع، حتی حداقل مدت هم جا نمی‌شود.
static int? snapDurationMinutes(
  int rawDurationMinutes, {
  int startMinutes = 0,
  int intervalMinutes = defaultSnapIntervalMinutes,
}) {
  final interval = intervalMinutes > 0 ? intervalMinutes : CalendarDefaults.snapIntervalMinutes;
  final untilEndOfDay = 1440 - startMinutes;
  if (untilEndOfDay < minDurationMinutes) return null;
  final hardMax = min(untilEndOfDay, DurationBounds.maxMinutes);
  final snapped = (rawDurationMinutes / interval).round() * interval;
  return snapped.clamp(minDurationMinutes, hardMax);
}
```

همهٔ فراخوان‌ها را برای `null` آماده کن: در `commitItemResize` اگر `null` بود `_errorMessage = CalendarMessagesFa.invalidTime` و بازگشت.

همین بازبینی را روی `snapStartMinutes` انجام بده: آنجا `maxAllowed = (1440 - durationMinutes).clamp(0, 1440)` درست است، اما اگر `durationMinutes > 1440` باشد `maxAllowed = 0` می‌شود و آیتم به نیمه‌شب می‌پرد. یک `assert` یا `sanitize` روی `durationMinutes` بگذار.

**معیار پذیرش:** تست CAL-55: `snapDurationMinutes(30, startMinutes: 1430)` باید `null` بدهد؛ `snapDurationMinutes(600, startMinutes: 1380)` باید ۶۰ بدهد (نه بیشتر).

**commit:** `fix(calendar): CAL-30 — جلوگیری از عبور مدت از نیمه‌شب در اسنپ`

---

### CAL-31 — `isTruncated` و `renderDurationMinutes` معنای مبهم دارند

**باگ:**

```dart
final renderDurM = (visibleEnd - visibleStart)
    .clamp(DurationBounds.minMinutes, DurationBounds.maxRenderMinutes);
final isTruncated = renderDurM < (visibleEnd - visibleStart);
```

وقتی `visibleEnd - visibleStart` کمتر از `minMinutes` باشد، `clamp` آن را **بالا** می‌برد و `isTruncated = false` می‌شود — درست. وقتی از `maxRenderMinutes` بیشتر باشد `isTruncated = true` — درست. اما `renderDurationMinutes` هم‌زمان دو کار می‌کند: «مدت قابل رندر» و «حداقل ارتفاع». در ادامه هم `height` دوباره با `max(rawHeight, minItemHeight)` و بعد `clamp(minItemHeight, maxHeight)` محاسبه می‌شود — یعنی سه لایه clamp روی هم که هیچ‌کدام مستند نیستند و `maxHeight` می‌تواند از `minItemHeight` کمتر شود (وقتی `top` نزدیک انتهای تایم‌لاین است) و آن‌وقت `clamp(minItemHeight, maxHeight)` با کرانِ پایینِ بزرگ‌تر از کرانِ بالا **پرتاب می‌کند**.

**فایل‌ها:** `timeline_layout_engine.dart`

**کار دقیق:**

1. مسئولیت‌ها را جدا کن: `renderDurationMinutes` فقط «مدت قابل مشاهده در بازه» باشد (بدون clamp حداقلی)، و حداقل ارتفاع فقط در محاسبهٔ `height` اعمال شود.
2. `height` را ایمن کن:
   ```dart
   final maxHeight = (totalTimelineHeight - top).clamp(0.0, totalTimelineHeight);
   final height = maxHeight <= minItemHeight
       ? maxHeight                      // نزدیک انتهای تایم‌لاین؛ کوچک‌تر از حداقل قابل قبول است
       : max(rawHeight, minItemHeight).clamp(minItemHeight, maxHeight);
   ```
3. `isTruncated` را دقیق تعریف کن با کامنت: `/// true یعنی مدت واقعی از سقف رندر بیشتر بوده و کارت کوتاه‌تر کشیده شده.`

**معیار پذیرش:** تست CAL-54: آیتمی با شروع ۲۳:۵۵ و مدت ۵ دقیقه پرتاب نکند و `height > 0` بدهد.

**commit:** `fix(calendar): CAL-31 — تفکیک مدت رندر از حداقل ارتفاع و ایمن‌سازی clamp`

---

### CAL-32 — ترتیب چیدمان نامعین است

**باگ:** مرتب‌سازی اولیه:

```dart
rawEntries.sort((a, b) {
  final cmp = a.visibleStart.compareTo(b.visibleStart);
  if (cmp != 0) return cmp;
  return b.durationMinutes.compareTo(a.durationMinutes);
});
```

دو آیتم با شروع و مدت یکسان **ترتیب نامعین** می‌گیرند (`List.sort` در Dart پایدار نیست). چون `laneIndex` از همین ترتیب می‌آید، دو آیتم هم‌زمان با هر بار rebuild می‌توانند جای ستون‌شان عوض شود → **کارت‌ها بین فریم‌ها می‌پرند**. همین مشکل در مرتب‌سازی اولویت capping هم هست (آنجا tie-break آخر `visibleStart` است که برای آیتم‌های هم‌زمان مساوی می‌ماند).

**فایل‌ها:** `timeline_layout_engine.dart`

**کار دقیق:** هر دو مرتب‌سازی را با `item.id` قطعی کن:

```dart
rawEntries.sort((a, b) {
  final cmp = a.visibleStart.compareTo(b.visibleStart);
  if (cmp != 0) return cmp;
  final durCmp = b.durationMinutes.compareTo(a.durationMinutes);
  if (durCmp != 0) return durCmp;
  return a.item.id.compareTo(b.item.id);   // tie-break قطعی
});
```

و در مرتب‌سازی capping، بعد از `visibleStart` هم `a.item.id.compareTo(b.item.id)` اضافه کن.

**معیار پذیرش:** تست CAL-54: همان ورودی را ۲۰ بار چیدمان کن؛ فهرست `(item.id, laneIndex)` باید در هر ۲۰ بار **یکسان** باشد.

**commit:** `fix(calendar): CAL-32 — قطعی‌سازی ترتیب چیدمان تایم‌لاین`

---

## فاز E — سطل‌بندی اجندا و برچسب‌های فارسی (CAL-33 … CAL-38)

---

### CAL-33 — برچسب بی‌معنی «۳ روز از ۱»

**باگ:** در `calculateDaysInBucket` برای سطل `thisWeek`:

```dart
final thisWeekStart = tomorrow.add(const Duration(days: 1));
if (thisWeekStart.isAfter(thisFri)) return 1;      // ← سطل خالی است ولی ۱ برمی‌گرداند
return thisFri.difference(thisWeekStart).inDays + 1;
```

وقتی امروز **پنج‌شنبه** یا **جمعه** باشد، `thisWeekStart` از `thisFri` می‌گذرد و تابع `1` می‌دهد. بعد در `calculateRecurrenceLabel(dates, 1)` مقدار `m = 1` می‌شود، شرط `n >= m && m >= 3` رد می‌شود، و اگر برچسب روز هفته هم نگیرد به آخرین خط می‌رسد:

```dart
return '${toPersianDigits(n)} روز از ${toPersianDigits(m)}';   // → «۳ روز از ۱»
```

یعنی کاربر در آخر هفته برچسب «۳ روز از ۱» می‌بیند. باگ عددی قابل مشاهده.

**فایل‌ها:** `agenda_bucketing.dart`

**کار دقیق:**

1. `calculateDaysInBucket` برای سطل خالی `0` برگرداند (و در کامنت بنویس یعنی «این سطل در تقویم امروز وجود ندارد»).
2. در `calculateRecurrenceLabel` مقدار `m` را ایمن کن و هرگز کسری بی‌معنی نساز:
   ```dart
   final m = daysInBucket > 0 ? daysInBucket : n;
   if (n > m) {
     // نمی‌تواند بیشتر از تعداد روزهای سطل باشد؛ داده‌ها ناسازگارند.
     RitmoLog.error('AgendaBucketing', 'n=$n > m=$m in recurrence label', StateError('bucket span'));
     return 'تکرارشونده';
   }
   if (n == m) return 'هر روز';        // شرط m >= 3 را بردار؛ «هر روز» برای ۲ روز هم درست است
   ```
3. UI باید سطلی با `daysInBucket == 0` را **رندر نکند** — در `journey_agenda_view.dart` بررسی کن و اگر سطل خالی هدر می‌گیرد، شرط بگذار.

**معیار پذیرش:** تست CAL-53 با `now` روی پنج‌شنبه و جمعه: هیچ برچسبی شامل «از ۱» نباشد و `calculateDaysInBucket(thisWeek)` صفر بدهد.

**commit:** `fix(calendar): CAL-33 — رفع برچسب تکرار بی‌معنی در آخر هفته`

---

### CAL-34 — برچسب تکرار از نمونه حدس زده می‌شود، نه از قاعدهٔ واقعی

**باگ (ریشه‌ای):** `calculateRecurrenceLabel` سعی می‌کند قاعدهٔ تکرار را از **تعداد نمونه‌های بارگذاری‌شده** مهندسی معکوس کند:

```dart
final isAllWorkdays = jalaliDates.every((j) => j.weekDay >= 1 && j.weekDay <= 5);
if (isAllWorkdays && n >= 3 && (m == 7 || n == 5)) return 'روزهای کاری';
```

دو خرابی:

1. آیتمی که فقط **شنبه، یک‌شنبه، دوشنبه** تکرار می‌شود (۳ از ۷) برچسب **«روزهای کاری»** می‌گیرد، در حالی که سه‌شنبه و چهارشنبه ندارد. شرط `m == 7 || n == 5` جادویی و بی‌مبناست.
2. برای سطل‌های `nextWeek` (که `m` سخت‌کد ۷ است) و `later` (که `m` از بازهٔ آیتم‌های بارگذاری‌شده می‌آید) مخرج کسر **غلط** است، چون بخشی از بازه ممکن است بیرون پنجرهٔ ۶۰ روزه باشد.

قاعدهٔ واقعی در دیتابیس هست (`routine_schedules`)؛ حدس زدنش از نمونه، غلط است.

**فایل‌ها:** `agenda_bucketing.dart`, `agenda_item.dart`, و منبع اجندای روتین (`lib/core/domain/agenda/sources/routine_agenda_source.dart`)

**کار دقیق:**

1. یک فیلد اختیاری به `AgendaItem` اضافه کن (اگر ندارد): `final String? recurrenceLabelFa;`
2. در `RoutineAgendaSource` (و هر منبع تکرارشونده‌ای که قاعده دارد) این برچسب را **از قاعدهٔ واقعی** بساز و روی آیتم بگذار. اگر منبع قاعده ندارد، `null` بگذار.
3. در `collapseRecurringSeries`:
   ```dart
   final label = rep.recurrenceLabelFa ?? calculateRecurrenceLabel(dates, daysInBucket);
   ```
   یعنی حدس فقط **fallback** باشد.
4. شرط «روزهای کاری» را سخت‌گیر کن — فقط اگر **همهٔ پنج روز کاری** حاضر باشند:
   ```dart
   final weekdaySet = jalaliDates.map((j) => j.weekDay).toSet();
   if (weekdaySet.length == 5 && weekdaySet.every((w) => w >= 1 && w <= 5)) {
     return 'روزهای کاری';
   }
   ```
5. اگر تغییر `AgendaItem` دامنهٔ کار را زیاد می‌کند، `BLOCKED` بزن، فقط بند ۴ را انجام بده و در یادداشت بنویس که بند ۱–۳ به تسک جدا نیاز دارد.

**معیار پذیرش:** تست CAL-53: آیتم شنبه/یک‌شنبه/دوشنبه **نباید** «روزهای کاری» بگیرد؛ آیتم پنج روز کاری باید بگیرد.

**commit:** `fix(calendar): CAL-34 — برچسب تکرار از قاعدهٔ واقعی و سخت‌گیری روزهای کاری`

---

### CAL-35 — تک‌آیتم‌ها بی‌توجه به زمان بالای سری‌ها می‌نشینند

**باگ:** انتهای `collapseRecurringSeries`:

```dart
// Returns a list where [AgendaSingle] items appear FIRST (top) followed by [AgendaSeries].
return [...singles, ...seriesList];
```

نتیجه: یک کار تک‌بار در **۲۳:۰۰** بالای یک روتین روزانه در **۰۶:۰۰** نمایش داده می‌شود. این با ترتیب زمانی `DayAgendaService._sortItems` (که همه‌جای اپ رعایت می‌شود) در تضاد است و کاربر ترتیب روز خودش را نمی‌فهمد. کامنت می‌گوید عمدی است، اما تضاد با بقیهٔ اپ یعنی تصمیم اشتباه است.

**فایل‌ها:** `agenda_bucketing.dart`

**کار دقیق:** ادغام و مرتب‌سازی واحد. یک کلید مرتب‌سازی روی `AgendaEntry` بگذار:

```dart
sealed class AgendaEntry {
  AgendaItem get anchor;                      // برای single خودش، برای series نماینده
  String get sortDate => anchor.dateStr;
  int? get sortMinutes => TimeOfDayMinutes.tryParse(anchor.timeOfDay);
}

final all = <AgendaEntry>[...singles, ...seriesList];
all.sort((a, b) {
  final d = a.sortDate.compareTo(b.sortDate);
  if (d != 0) return d;
  final am = a.sortMinutes, bm = b.sortMinutes;
  if (am != null && bm != null) {
    final t = am.compareTo(bm);
    if (t != 0) return t;
  } else if (am != null) return -1;
  else if (bm != null) return 1;
  final p = b.anchor.priority.compareTo(a.anchor.priority);
  if (p != 0) return p;
  return a.anchor.id.compareTo(b.anchor.id);      // قطعی
});
return all;
```

کامنت قدیمی «singles FIRST» را حذف کن و به‌جایش بنویس چرا ترتیب زمانی است.

**معیار پذیرش:** تست CAL-53: آیتم تک ۲۳:۰۰ باید **پایین‌تر** از سری ۰۶:۰۰ باشد.

**commit:** `fix(calendar): CAL-35 — ترتیب زمانی واحد برای تک‌آیتم‌ها و سری‌ها`

---

### CAL-36 — ارقام و نام روزهای فارسی ناهمگون

**باگ:** در همان فایل، دو آرایهٔ دستی نام روز و دو سیستم رقم هم‌زمان استفاده می‌شوند:

```dart
// calculateRecurrenceLabel — ارقام فارسی
return '${toPersianDigits(n)} روز از ${toPersianDigits(m)}';

// daySubGroupLabel — ارقام لاتین!
return '$wdLabel ${j.day} ${j.formatter.mN}';
```

پس در یک صفحه هم‌زمان «۵ روز از ۷» و «شنبه 3 مرداد» دیده می‌شود. علاوه بر آن دو آرایهٔ نام روز (`weekdayPlurals` و `weekdays`) به‌صورت دستی تکرار شده‌اند در حالی که `shamsi_date` خودش `j.formatter.wN` دارد.

**فایل‌ها:** `agenda_bucketing.dart`, و یک فایل مشترک برای نام‌ها.

**کار دقیق:**

1. `${j.day}` → `${toPersianDigits(j.day.toString())}`. کل فایل را برای ارقام لاتین در رشته‌های فارسی بگرد.
2. یک تک‌منبع نام روز بساز (مثلاً در `lib/core/utils/shamsi_week.dart` که در CAL-41 هم لازم می‌شود):
   ```dart
   abstract final class ShamsiWeek {
     static const weekdayNames = ['شنبه','یک‌شنبه','دوشنبه','سه‌شنبه','چهارشنبه','پنج‌شنبه','جمعه'];
     static const weekdayPlurals = ['شنبه‌ها','یک‌شنبه‌ها','دوشنبه‌ها','سه‌شنبه‌ها','چهارشنبه‌ها','پنج‌شنبه‌ها','جمعه‌ها'];
     static String nameOf(int jalaliWeekDay) => weekdayNames[(jalaliWeekDay - 1).clamp(0, 6)];
     static String pluralOf(int jalaliWeekDay) => weekdayPlurals[(jalaliWeekDay - 1).clamp(0, 6)];
   }
   ```
3. هر دو آرایهٔ درون‌خطی را حذف کن و از `ShamsiWeek` استفاده کن. `calendar_date_formatter.dart` را هم بررسی کن — اگر آرایهٔ سومی دارد، آن هم حذف شود.

**معیار پذیرش:**

```bash
rg -n "'شنبه'" lib/ | rg -v shamsi_week    # خالی
```
تست CAL-53: خروجی `daySubGroupLabel` هیچ رقم لاتینی نداشته باشد (`RegExp(r'[0-9]')` نگیرد).

**commit:** `fix(calendar): CAL-36 — یکدست‌سازی ارقام فارسی و نام روزهای هفته`

---

### CAL-37 — `catch (_)` های خاموش در سطل‌بندی

**باگ:** پنج جای `agenda_bucketing.dart` خطا را بی‌صدا می‌خورد:

```dart
try { date = DateTime.parse(dateStr); } catch (_) { continue; }   // آیتم‌های آن روز بی‌صدا حذف می‌شوند
...
try { dates.add(DateTime.parse(inst.dateStr)); } catch (_) {}
try { dates.add(DateTime.parse(item.dateStr)); } catch (_) {}
...
try { ... } catch (_) { return dateStr; }
```

اولی از همه بدتر است: یک کلید تاریخ خراب باعث می‌شود **همهٔ آیتم‌های آن روز از اجندا ناپدید شوند** بدون هیچ لاگ، هیچ بنر degraded و هیچ نشانه‌ای. با توجه به باگ کلید تاریخ (CAL-01)، دقیقاً همان حالتی که باید دیده می‌شد، پنهان می‌ماند.

**فایل‌ها:** `agenda_bucketing.dart`

**کار دقیق:** هر پنج مورد → `DateKey.parse` + لاگ:

```dart
final date = DateKey.parse(dateStr);
if (date == null) {
  RitmoLog.error('AgendaBucketing', 'کلید تاریخ نامعتبر در سطل‌بندی: $dateStr',
      StateError('invalid date key'));
  continue;
}
```

برای `daySubGroupLabel`، fallback به `dateStr` بماند (رفتار UI درست است) اما لاگ اضافه شود.

**معیار پذیرش:**

```bash
rg -n "catch \(_\)" lib/features/calendar lib/core/domain/agenda   # خالی
```

**commit:** `fix(calendar): CAL-37 — حذف catch های خاموش در سطل‌بندی اجندا`

---

### CAL-38 — «معوقه» فقط ۱۴ روز عقب را می‌بیند

**باگ:** سطل `overdue` فقط از snapshotهای **داخل پنجرهٔ بارگذاری‌شده** پر می‌شود، و پنجره `daysBack = 14` است. یعنی کاری که ۲۰ روز عقب افتاده **به‌کل از اجندا ناپدید می‌شود** — نه در معوقه، نه هیچ‌جا. کاربر هیچ راهی برای فهمیدنش ندارد و هیچ نشانه‌ای هم در UI نیست که «فقط ۱۴ روز عقب نشان داده می‌شود».

**فایل‌ها:** `journey_controller.dart`, `agenda_bucketing.dart`, `journey_agenda_view.dart`

**کار دقیق:**

1. یک پرس‌وجوی مستقل و ارزان برای معوقه‌های قدیمی اضافه کن — **آیتم را بازسازی نکن، فقط بشمار**. سبک‌ترین راه: یک متد روی `DayAgendaService` مثل
   ```dart
   Future<int> countOverdueBefore(DateTime cutoff);
   ```
   که با یک پرس‌وجوی جمعی روی جدول‌های واقعی (نه بازسازی اجندا) تعداد کارهای انجام‌نشدهٔ قبل از `cutoff` را می‌دهد. اگر پیاده‌سازی دقیقش دامنه را زیاد می‌کند، `BLOCKED` بزن و فقط بند ۲ را انجام بده.
2. در هدر سطل «معوقه»، اگر `countOverdueBefore(windowStart) > 0`:
   نمایش یک ردیف با متن `«{n} مورد قدیمی‌تر از {daysBack} روز»` و دکمهٔ «نمایش همه» که پنجره را با `daysBack: 365` دوباره بار می‌کند (`loadAgendaRange(daysBack: 365)`).
3. یک ثابت اضافه کن: `static const int agendaExpandedDaysBack = 365;`

**معیار پذیرش:** تست CAL-53/CAL-56 برای بند ۲ و ۳. اگر بند ۱ BLOCKED شد، در ledger صریح بنویس.

**commit:** `fix(calendar): CAL-38 — نمایش معوقه‌های خارج از پنجره`

---

## فاز F — کارایی (CAL-39 … CAL-42)

---

### CAL-39 — بارگذاری پنجرهٔ ۶۰ روزه در یک ضرب روی UI isolate

**باگ:** `loadAgendaRange(daysBack: 14, daysForward: 45)` = **۶۰ روز × همهٔ منابع** در یک فراخوانی. `DayAgendaService.agendaForRange` برای هر روز `_assembleDay` می‌زند که خودش ۹+ منبع را جمع می‌کند و `prayerTimesFor(date)` را (که محاسبهٔ نجومی است) صدا می‌زند. کامنت خودش هدف «< 250ms» را ادعا می‌کند، `Stopwatch` هم می‌گذارد و نتیجه را `debugPrint` می‌کند — اما **هیچ اعمالی و هیچ تستی نیست**. با باگ طوفان رفرش (CAL-24) این کار دو بار به‌ازای هر رویداد تکرار می‌شود.

**فایل‌ها:** `journey_controller.dart`

**کار دقیق:** بارگذاری دو مرحله‌ای — اول چیزی که کاربر می‌بیند، بعد بقیه:

```dart
static const int agendaFastWindowDays = 3;

Future<void> loadAgendaRange({...}) async {
  final gen = ++_loadGeneration;
  // مرحلهٔ ۱: پنجرهٔ کوچک، سریع، برای رندر فوری
  await _loadWindow(gen,
      start: DateKey.addDays(anchor, -agendaFastWindowDays),
      end: DateKey.addDays(anchor, agendaFastWindowDays),
      isBackgroundRefresh: isBackgroundRefresh);
  if (_isDisposed || gen != _loadGeneration) return;
  // مرحلهٔ ۲: بقیهٔ پنجره در پس‌زمینه، بدون اسپینر
  await _loadWindow(gen,
      start: DateKey.addDays(anchor, -daysBack),
      end: DateKey.addDays(anchor, daysForward),
      isBackgroundRefresh: true);
}
```

`_loadWindow` نتایج را با `_rangeSnapshots` **ادغام** کند (`Map.from(_rangeSnapshots)..addAll(new)`) نه اینکه جایگزین کند، و بعد از هر مرحله `notifyListeners()` بزند. توکن `gen` در هر دو مرحله چک شود.

**معیار پذیرش:** تست CAL-56: بعد از مرحلهٔ اول، `isLoading == false` و `snapshot != null`؛ سرویس جعلی باید **دو** فراخوانی بازه ببیند، اولی ۷ روز.

**commit:** `fix(calendar): CAL-39 — بارگذاری دو مرحله‌ای پنجرهٔ اجندا`

---

### CAL-40 — روزهای خالی در هر رفرش از نو ساخته می‌شوند

**باگ:** در `DayAgendaService.agendaForRange`:

```dart
// C-FIX-4: NEVER cache an empty day.
if (cacheEligible && agenda.items.isNotEmpty) {
  _cache[ds] = agenda;
}
```

این تصمیم **درست** است (کامنت طولانی دلیلش را توضیح می‌دهد: یک بارگذاری زودهنگام، روز خالی را برای کل سشن قفل می‌کرد). اما هزینه‌اش این است که در یک پنجرهٔ ۶۰ روزه که بیشترش خالی است، **هر روز خالی در هر رفرش از صفر ساخته می‌شود** — با محاسبهٔ اوقات شرعی. این غالب‌ترین هزینهٔ اجندا است.

راه‌حل: «هرگز خالی را چسبناک نکن» را حفظ کن، اما خالی را تا **اولین تغییر داده** به یاد بیاور.

**فایل‌ها:** `day_agenda_service.dart`

**کار دقیق:**

1. یک شمارندهٔ نسخهٔ داده اضافه کن:
   ```dart
   int _dataRevision = 0;
   void invalidateAll() { _cache.clear(); _emptyDays.clear(); _dataRevision++; }
   void invalidateDate(String dateStr) { _cache.remove(dateStr); _emptyDays.remove(dateStr); _dataRevision++; }
   ```
2. کش منفی با مهر نسخه:
   ```dart
   final Map<String, int> _emptyDays = {};   // dateStr → revision
   ```
3. در حلقه:
   ```dart
   if (cacheEligible && _emptyDays[ds] == _dataRevision) {
     result[ds] = DayAgenda.empty(ds);
     servedFromCache++;
     continue;
   }
   ...
   if (cacheEligible) {
     if (agenda.items.isNotEmpty) { _cache[ds] = agenda; }
     else { _emptyDays[ds] = _dataRevision; }
   }
   ```
4. کامنت بگذار که چرا این با C-FIX-4 در تضاد نیست: **هر تغییر داده‌ای `_dataRevision` را جلو می‌برد، پس خالی‌بودن هرگز از یک mutation عبور نمی‌کند.**
5. سقف اندازه برای `_emptyDays` بگذار (مثلاً ۴۰۰ کلید) تا در پیمایش طولانی رشد نکند.

**معیار پذیرش:** تست: دو `agendaForRange` پشت‌هم روی بازهٔ خالی → دومی هیچ `_assembleDay` نزند؛ بعد از `invalidateAll()` → دوباره بزند.

**commit:** `fix(calendar): CAL-40 — کش منفی نسخه‌دار برای روزهای خالی`

---

### CAL-41 — تقویم به فیچر «دوره‌ها» وابسته است

**باگ (نقض ADR):** هم کنترلر و هم سطل‌بندی برای مرز هفتهٔ شمسی به فیچر courses وابسته‌اند:

```dart
import 'package:ritmo/features/courses/logic/course_scheduler.dart';
...
final sat = CourseScheduler.getSaturdayOfWeek(dateOnly);
```

یک وابستگی feature → feature که `docs/adr/0006-guard-rails-dependency-rules.md` منعش می‌کند. علاوه بر آن، محاسبهٔ مرز هفته در تقویم از courses می‌آید ولی محاسبهٔ ماه/سال از `Jalali` — دو مبنای متفاوت در یک فایل.

**فایل‌ها:** `lib/core/utils/shamsi_week.dart` (از CAL-36), `journey_controller.dart`, `agenda_bucketing.dart`, `course_scheduler.dart`

**کار دقیق:**

1. `getSaturdayOfWeek` را به `ShamsiWeek` منتقل کن:
   ```dart
   static DateTime saturdayOf(DateTime date) {
     final d = DateKey.dayOf(date);
     final j = Jalali.fromDateTime(d);
     return DateKey.addDays(d, -(j.weekDay - 1));   // weekDay: 1=شنبه
   }
   static DateTime fridayOf(DateTime date) => DateKey.addDays(saturdayOf(date), 6);
   ```
2. `CourseScheduler.getSaturdayOfWeek` را نگه دار اما بدنه‌اش را به `ShamsiWeek.saturdayOf` واگذار کن (`@Deprecated` بزن) تا فیچر courses نشکند.
3. import های `course_scheduler` را از `journey_controller.dart` و `agenda_bucketing.dart` **حذف** کن.
4. `import 'package:ritmo/features/calendar/presentation/logic/direct_manipulation_eligibility.dart';` را در `journey_controller.dart` بررسی کن — به‌نظر بی‌استفاده است. اگر واقعاً استفاده نمی‌شود حذفش کن؛ اگر `TimelineSnappingHelper` یا چیز دیگری از طریق آن re-export می‌شود، import صریح بگذار و در کامنت بنویس.

**معیار پذیرش:**

```bash
rg -n "features/courses" lib/features/calendar lib/core/domain/agenda   # خالی
```
تست معماری CAL-58 این را قفل کند.

**commit:** `fix(calendar): CAL-41 — انتقال محاسبهٔ هفتهٔ شمسی به core و قطع وابستگی به courses`

---

### CAL-42 — بودجهٔ کارایی، اندازه‌گیری‌شده و اعمال‌شده

**باگ:** `Stopwatch` هست، هدف «< 250ms» در کامنت هست، اما هیچ اعمال و هیچ تستی نیست. پس رگرسیون کارایی بی‌صدا وارد می‌شود.

**فایل‌ها:** `journey_controller.dart`, `test/calendar/agenda_performance_test.dart`

**کار دقیق:**

1. ثابت بودجه: `static const Duration agendaLoadBudget = Duration(milliseconds: 250);`
2. بعد از `sw.stop()`:
   ```dart
   if (sw.elapsed > agendaLoadBudget) {
     RitmoLog.error('JourneyController',
         'بارگذاری اجندا از بودجه گذشت: ${sw.elapsedMilliseconds}ms (بودجه ${agendaLoadBudget.inMilliseconds}ms)',
         StateError('agenda load budget exceeded'));
   }
   assert(sw.elapsed <= agendaLoadBudget * 4,
       'بارگذاری اجندا بیش از حد کند است: ${sw.elapsedMilliseconds}ms');
   ```
3. یک تست کارایی با دیتابیس in-memory بنویس که ۶۰ روز با ~۱۰ آیتم در روز seed کند و بودجه را assert کند. اگر زیرساخت seed در تست‌های موجود نیست، از الگوی `test/flutter_test_config.dart` و تست‌های موجود پیروی کن؛ اگر عملاً امکان‌پذیر نبود `BLOCKED` بزن و فقط بندهای ۱ و ۲ را انجام بده.

**commit:** `fix(calendar): CAL-42 — اعمال و اندازه‌گیری بودجهٔ بارگذاری اجندا`

---

## فاز G — پیشنهادهای خلاقانه (CAL-43 … CAL-52)

این‌ها ویژگی جدیدند. هر کدام را **کامل** پیاده کن (منطق + UI + تست)، یا اگر واقعاً بیش از یک تسک است `BLOCKED` بزن با توضیح دقیق. نصفه رها نکن.

---

### CAL-43 — «جا کردن هوشمند»: تشخیص تداخل + پیشنهاد شکاف خالی

زیرساخت از قبل هست: `journey_free_gaps_section.dart` شکاف‌های خالی روز را می‌داند و CAL-26 تشخیص تداخل را اضافه کرد.

**کار دقیق:**

1. یک تابع خالص در `lib/features/calendar/presentation/logic/gap_finder.dart`:
   ```dart
   /// شکاف‌های آزاد روز، مرتب‌شده بر اساس نزدیکی به [preferredStart].
   List<({int startMinutes, int durationMinutes})> findFreeGaps(
     List<AgendaItem> dayItems, {
     required int minDurationMinutes,
     int dayStartMinutes = 6 * 60,
     int dayEndMinutes = 23 * 60,
   });
   ```
   منطق: بازه‌های اشغال را از آیتم‌های `isTimed` بساز، ادغام کن، مکمل بگیر، شکاف‌های کوچک‌تر از حداقل را بریز بیرون.
2. وقتی `_validatePlacement` تداخل داد، در `_warningMessage` بمان اما یک فیلد جدید هم پر کن:
   ```dart
   ({int startMinutes, int durationMinutes})? suggestedSlot;
   ```
   نزدیک‌ترین شکاف به زمان درخواستی کاربر.
3. در UI، نوار هشدار تداخل یک دکمه داشته باشد: **«انتقال به {ساعت}»** که `commitItemDrag` را با زمان پیشنهادی صدا می‌زند.
4. تست: سه سناریو — بدون شکاف، شکاف قبل، شکاف بعد.

**commit:** `feat(calendar): CAL-43 — تشخیص تداخل و پیشنهاد شکاف خالی`

---

### CAL-44 — نوار «بازگردانی» با redo

**کار دقیق:**

1. اگر `CommandStack` فقط `undoLast()` دارد، `redoLast()` و `canUndo`/`canRedo` و `lastDescription` اضافه کن. `push` جدید باید پشتهٔ redo را پاک کند.
2. بعد از هر عمل موفق تقویم، یک `SnackBar` فارسی با متن `command.description` (که از قبل روی هر دستور هست: «جابه‌جایی رویداد»، «تغییر مدت زمان رویداد»، …) و دکمهٔ «بازگردانی» با مدت ۶ ثانیه نشان بده.
3. یک دکمهٔ «بازگردانی/دوباره» در نوار ابزار تقویم که به `canUndo`/`canRedo` واکنش نشان دهد.
4. تست: undo → redo → حالت اولیه برگردد.

**commit:** `feat(calendar): CAL-44 — نوار بازگردانی و redo`

---

### CAL-45 — رها کردن آیتم بی‌زمان روی نوار شکاف‌های خالی

آیتم‌های بی‌زمان در `timeline_untimed_section.dart` هستند و شکاف‌ها در `journey_free_gaps_section.dart`. الان راه سریعی برای زمان‌بندی نیست.

**کار دقیق:** `Draggable` روی کارت‌های بی‌زمان و `DragTarget` روی هر چیپ شکاف. با رها شدن، `scheduleItem(item, gap.startMinutes, min(gap.durationMinutes, پیشنهاد))` صدا زده شود. بازخورد لمسی با `RitmoHapticsPolicy.success()` (از قبل در `scheduleItem` هست). تست ویجت برای drop.

**commit:** `feat(calendar): CAL-45 — زمان‌بندی با رها کردن روی شکاف خالی`

---

### CAL-46 — «قالب روز»

**کار دقیق:** روی نمای روز، منوی «ذخیره به‌عنوان قالب» که چیدمان زمانی آیتم‌های زمان‌دار آن روز را در یک جدول جدید `day_templates(id, name, payloadJson, createdAt)` ذخیره کند (با migration). و «اعمال قالب» که برای روز مقصد یک `CommandPlan` بسازد: مجموعه‌ای از overrideهای `timeOfDay`/`durationMinutes` که **یک‌جا** اعمال و **یک‌جا** بازگردانی شوند. یک تأیید قبل از اعمال. تست: ذخیره → اعمال روی روز دیگر → undo.

**commit:** `feat(calendar): CAL-46 — ذخیره و اعمال قالب روز`

---

### CAL-47 — نقشهٔ حرارتی در نمای سال

`journey_year_view.dart` الان نقطه‌های ساده دارد. به‌جایش شدت رنگ هر روز بر اساس نسبت `تعداد انجام‌شده / تعداد کل` (یا تراکم آیتم‌ها اگر نسبت در دسترس نیست). یک راهنمای رنگ فارسی پایین نما. رنگ‌ها از `RitmoColors` بگیر، هارد‌کد نکن. حتماً حالت دسترسی‌پذیری: فقط رنگ کافی نیست، `Semantics` label با عدد فارسی بگذار.

**commit:** `feat(calendar): CAL-47 — نقشهٔ حرارتی نمای سال`

---

### CAL-48 — درگ چندروزه در نمای هفته و ماه

الان drag فقط داخل یک روز کار می‌کند. `LongPressDraggable` روی آیتم و `DragTarget` روی سلول‌های روز در `journey_week_view.dart` و `journey_month_view.dart`. رها کردن یک `_MoveItemToDateCommand extends _CalendarCommand` بسازد که override روز مبدأ را `SKIPPED` کند و روی روز مقصد override بسازد — همان منطق CAL-16، پس همان دستور را دوباره استفاده کن. **هر دو روز باید `invalidateDate` بگیرند**، پس `affectsMultipleDays` را از CAL-14 به کار بگیر.

**commit:** `feat(calendar): CAL-48 — جابه‌جایی آیتم بین روزها با درگ`

---

### CAL-49 — علامت روز استراحت/سفر با یک ضربه

جدول `day_marks` و منطق `REST`/`TRAVEL` از قبل در `_assembleDay` پیاده است (بخش K43: آیتم‌های غیرضروری به `skipped` می‌روند) اما رابط کاربری سریعی برای آن نیست و `day_mark_repository.dart` استفادهٔ محدودی دارد.

**کار دقیق:** در هدر روز یک دکمهٔ سه‌حالته «عادی / استراحت / سفر». تغییر باید یک `UndoableCommand` باشد و `invalidateDate` بزند. یک بنر فارسی روی آن روز: «روز استراحت — فقط موارد ضروری». تست: علامت‌گذاری → آیتم غیرضروری `skipped` شود، آیتم ضروری دست‌نخورده بماند → undo برگردد.

**commit:** `feat(calendar): CAL-49 — علامت‌گذاری سریع روز استراحت و سفر`

---

### CAL-50 — حالت تمرکز روی بلوک زمانی

ضربه روی یک کارت زمان‌دار → شیت «شروع تمرکز» با تایمر معکوس به اندازهٔ `durationMinutes`. پایان تایمر → پیشنهاد `completeItem`. اگر کاربر قبل از پایان بست، هیچ تغییری ثبت نشود. حالت `partial` را در نظر بگیر: `CompleteOccurrenceCommand` مقدار `OccurrenceResultType.partial` دارد و کنترلر الان **همیشه `full`** می‌فرستد؛ این تسک فرصت درست‌کردن آن است: اگر تایمر نیمه‌کاره تمام شد، `partial` با `durationMinutes` واقعی بفرست.

**commit:** `feat(calendar): CAL-50 — حالت تمرکز و ثبت انجام جزئی`

---

### CAL-51 — ارتقای «الان چی؟»

`now_pill.dart` و `now_pill_view_model.dart` را بخوان. اضافه کن: زمان باقی‌ماندهٔ آیتم جاری با ارقام فارسی، عنوان آیتم بعدی، و دو دکمهٔ «انجام شد» / «شروع تمرکز» (به CAL-50 وصل). حتماً تایمر را در `dispose` لغو کن و از `Timer.periodic` با بازهٔ ۳۰ ثانیه استفاده کن نه هر ثانیه (مصرف باتری). تست ViewModel برای مرزها: قبل از اولین آیتم، بین دو آیتم، بعد از آخرین آیتم، روز خالی.

**commit:** `feat(calendar): CAL-51 — ارتقای نشان «الان چی؟»`

---

### CAL-52 — ورود و خروج ICS

**کار دقیق:** یک `AgendaSource` جدید `IcsAgendaSource` که فایل `.ics` واردشده را به `AgendaItem`های **فقط‌خواندنی** تبدیل کند (دامنهٔ `event`). ثبتش در `AgendaSourceRegistry` با یک module gate جدید (`module_ics_enabled`) که پیش‌فرض خاموش است. و یک خروجی: تبدیل بازهٔ انتخابی به `.ics`. رخدادهای تکرارشونده (`RRULE`) را در نسخهٔ اول پشتیبانی **نکن** و صریحاً در UI بنویس. تست: پارس یک فایل نمونهٔ کوچک، و گرد کردن (round-trip) خروجی.

**commit:** `feat(calendar): CAL-52 — منبع اجندای ICS برای ورود و خروج`

---

## فاز H — تست‌ها (CAL-53 … CAL-60)

قبل از ساختن هر فایل تست، `ls test/calendar/` و `rg -l "bucketRange|TimelineLayoutEngine" test/` بزن. اگر تستی از قبل هست، **تکمیلش کن** و در ledger `SKIPPED` ننویس — بنویس «تکمیل شد».

---

### CAL-53 — `test/calendar/agenda_bucketing_test.dart`

حداقل موارد:
- عدم تکرار: هیچ آیتمی در دو سطل نباشد (روی یک مجموعهٔ ۳۰ روزه)
- عدم گم‌شدن: مجموع آیتم‌های سطل‌ها + آیتم‌های گذشتهٔ انجام‌شده = کل ورودی
- `now` روی هر هفت روز هفته (شنبه تا جمعه) — مرزهای `thisWeek`/`nextWeek`
- امروز پنج‌شنبه و جمعه → هیچ برچسب «از ۱» تولید نشود (CAL-33)
- `calculateRecurrenceLabel`: «هر روز»، «روزهای کاری» (فقط با هر پنج روز کاری)، «شنبه‌ها»، کسری
- ترتیب زمانی ادغام‌شدهٔ singles و series (CAL-35)
- ارقام فارسی در `daySubGroupLabel` (CAL-36)
- کلید تاریخ نامعتبر → آیتم‌ها گم نشوند بی‌صدا

---

### CAL-54 — `test/calendar/timeline_layout_engine_test.dart`

- خوشهٔ تراگذر A/B/E/C: `totalLanes` یکسان برای همه (CAL-27)
- هیچ `item.id` دو بار (کارت + overflowItems) (CAL-28)
- `maxLanes: 2` با ۲ آیتم → دو کارت بدون چیپ؛ با ۳ آیتم → یک کارت + چیپ با `overflowCount = 2` (CAL-29)
- آیتم ۲۳:۵۵ با مدت ۵ دقیقه → پرتاب نکند، `height > 0` (CAL-31)
- قطعیت: ۲۰ بار اجرا، خروجی یکسان (CAL-32)
- زمان نامعتبر (`"99:99"`, `"abc"`, `null`) → آیتم حذف شود، نه به نیمه‌شب برود
- بازهٔ split (`rangeStartMinutes: 720`): آیتم عبوری از مرز `isClippedAtStart` بگیرد

---

### CAL-55 — `test/calendar/timeline_snapping_test.dart`

- `snapStartMinutes`: snap به ۱۵، clamp به `1440 - duration`, مقدار منفی
- `snapDurationMinutes(30, startMinutes: 1430)` → `null` (CAL-30)
- `snapDurationMinutes(600, startMinutes: 1380)` → ۶۰
- `intervalMinutes: 0` → به پیش‌فرض برگردد

---

### CAL-56 — `test/calendar/journey_controller_test.dart`

با `FakeDayAgendaService`, `FakeAgendaActionHandler`, `FakeOccurrenceOverrideRepository`, `FakeSettingsService`:
- نرمال‌سازی نیمه‌شب در هر پنج مقیاس (CAL-08)
- توکن نسل: دو بارگذاری با تأخیر معکوس → برندهٔ آخر (CAL-17)
- `_calculateDateRangeForScale(agenda, …)` پرتاب کند (CAL-18)
- `refresh()` روی اجندا با snapshot موجود `isLoading` را true نکند (CAL-19)
- `setScale` داده را پاک کند و `isLoading` بگذارد (CAL-20)
- ده رویداد در ۱۰۰ms → یک بارگذاری (CAL-24)
- `skipItem` روی task یک override با `SKIPPED` بسازد و به `CommandStack` push شود (CAL-15)
- `postponeItem` روی تسک معوقه → `امروز + days` (CAL-16)
- `postponeItem` روی دامنهٔ غیرمجاز → پیام فارسی، بدون push (CAL-16)
- درگ با زمان نامعتبر / عبور از نیمه‌شب → رد شود؛ با تداخل → انجام شود + `warningMessage` (CAL-26)
- بارگذاری دو مرحله‌ای: دو فراخوانی بازه، اولی ۷ روز (CAL-39)
- `loadDefaultScale` با `_scaleExplicitlySet` مقیاس را عوض نکند (CAL-22)
- `setScale` مقدار را ذخیره کند (CAL-23)
- **`dispose()` بعد از یک عمل**: هیچ استثنایی پرتاب نشود و `notifyListeners` صدا زده نشود

---

### CAL-57 — `test/calendar/occurrence_override_repository_test.dart`

- `upsert` اد‌غامی: resize → move → `durationMinutes` حفظ شود (CAL-09)
- skip → move → `status` هنوز `SKIPPED` (CAL-09)
- `createdAt` بعد از upsert دوم عوض نشود (CAL-09)
- `readOne` / `readAllFuture` / `restoreAll` (CAL-10)
- undo مبتنی بر snapshot: resize → move → undo → حالت بعد از resize (CAL-11)
- `allFutureDays`: سه override آینده → move → undo → هر سه برگردند (CAL-12)
- `task:42` و `routine:42` در یک روز: override روی task، روتین دست‌نخورده (CAL-13)
- `no such table` → `ensureTable` و موفقیت در تلاش دوم

---

### CAL-58 — `test/architecture/calendar_dependency_test.dart`

تست ثابت (بدون اجرای اپ) که فایل‌های `lib/features/calendar/**` و `lib/core/domain/agenda/**` را می‌خواند و assert می‌کند:
- هیچ `import` به `features/courses/` یا هر `features/` دیگری جز `calendar` و `simple_tasks` (CAL-41)
- هیچ `debugPrint` (CAL-06)
- هیچ `catch (_)` (CAL-37)
- هیچ `toIso8601String().substring` (CAL-02)
- هیچ `db.query('app_settings'` در `lib/features/` (CAL-22)
- هیچ رشتهٔ `'Failed ` در مقادیر `_errorMessage` (CAL-07)

این تست ارزشمندترین چیز در کل این فایل است: هر شش باگ را برای همیشه قفل می‌کند.

---

### CAL-59 — `test/core/date_key_test.dart` و `test/core/time_of_day_minutes_test.dart`

- `DateKey.of` روی UTC و local همان تاریخ محلی بدهد (CAL-01)
- `DateKey.parse('2026-13-01')` → `null`؛ `'1404-12-31'` روی سال غیرکبیسه → `null`
- `DateKey.addDays` روی مرز ماه و سال
- `TimeOfDayMinutes.tryParse`: `'09:30'`, `'9:30'`, `'۰۹:۳۰'` (ارقام فارسی), `'24:00'` → null, `'99:99'` → null, `'abc'` → null, `null` → null
- `format(1439)` → `'23:59'`؛ `format(-5)` → `'00:00'`

---

### CAL-60 — تست طلایی RTL و تست رگرسیون سرتاسری

1. تست طلایی نمای اجندا و نمای روز در سه مقیاس متن (`textScaleFactor: 1.0, 1.3, 1.6`) و در `TextDirection.rtl`. باید سرریز متن نداشته باشند.
2. یک تست یکپارچه: روز با سه آیتم بساز → drag یکی → resize یکی → skip یکی → postpone یکی → سه بار undo → assert کن حالت دیتابیس **دقیقاً** برابر حالت اولیه است. این تست همهٔ باگ‌های ازدست‌رفتن داده در فاز B را با هم می‌گیرد.

**commit هر تست:** `test(calendar): CAL-## — <عنوان>`

---

# بخش ۵ — Definition of Done

کار تمام **نیست** مگر همهٔ این‌ها درست باشد:

1. هر ۶۰ ردیف `docs/calendar/CALENDAR_FIX_PROGRESS.md` وضعیت `DONE`، `SKIPPED` یا `BLOCKED` با دلیل نوشته‌شده دارند. هیچ `TODO` و هیچ `DOING` نمانده.
2. `flutter analyze` → **صفر issue**.
3. `flutter test` → همه سبز، هیچ تست `skip` نشده.
4. این هفت دستور همه باید خروجی **خالی** بدهند:

```bash
rg -n "debugPrint" lib/features/calendar lib/core/domain/agenda
rg -n "catch \(_\)" lib/features/calendar lib/core/domain/agenda
rg -n "toIso8601String\(\)\.substring" lib/
rg -n "parseTimeToMinutes|_tryParseStartMinutes|_parseMinutes" lib/
rg -n "features/courses" lib/features/calendar lib/core/domain/agenda
rg -n "_errorMessage = '(?i)failed" lib/
rg -n "overrideMap\[ovr.sourceId\]|overrideMap\[item.sourceId\]" lib/
```

5. `rg -n "TODO|FIXME" lib/features/calendar` هیچ مورد **جدیدی** که خودت اضافه کرده باشی نداشته باشد.
6. **آزمون دستی** (انجامش بده و نتیجه را در ledger بنویس):
   - تقویم را باز کن → اجندا باید زیر یک ثانیه بیاید و سطل «امروز» درست باشد.
   - یک آیتم را resize کن، بعد drag کن، بعد دو بار undo بزن → **هر دو تغییر** باید برگردند و مدت resize گم نشود.
   - یک آیتم را روی آیتم دیگر بیانداز → نوار هشدار تداخل فارسی با دکمهٔ پیشنهاد ساعت ظاهر شود.
   - یک روتین را «رد کن» → از فهرست برود و دکمهٔ بازگردانی کار کند.
   - یک تسک معوقه را «به فردا بیانداز» → واقعاً به **فردا** برود، نه به گذشته.
   - مقیاس را به ماه عوض کن → هیچ فریمی با دادهٔ اجندا رندر نشود.
   - مقیاس را روی «هفته» بگذار، اپ را ببند و باز کن → روی «هفته» بماند.
   - در روز جمعه اجندا را باز کن → هیچ برچسبی مثل «۳ روز از ۱» نبینی.

---

# بخش ۶ — یادآوری ضد لغزش

این‌ها را وقتی وسوسه شدی میان‌بر بزنی بخوان:

- **وسوسه:** «این باگ‌ها به هم مربوط‌اند، همه را در یک commit درست می‌کنم.» → نه. یک تسک، یک commit. وقتی چیزی خراب شود، `git bisect` تنها دوست تو است.
- **وسوسه:** «تست نوشتن برای این یکی خیلی طول می‌کشد.» → تست CAL-58 (تست معماری) ارزان‌ترین و مؤثرترین است. اگر وقت کم داری آن را بنویس، نه اینکه هیچ تستی نباشد.
- **وسوسه:** «`catch (_) {}` را نگه دارم، ضرری ندارد.» → همین الگو باعث شده باگ کلید تاریخ سال‌ها دیده نشود.
- **وسوسه:** «`clamp` را می‌گذارم چون کد را ساده می‌کند.» → دقیقاً همین `clamp` در CAL-30 محدودیت نیمه‌شب را نقض کرده. `clamp` روی مرزی که خودش نامعتبر است، خطا را پنهان می‌کند نه رفع.
- **وسوسه:** «`isDone: false` برای skip کافی است.» → نه. «انجام‌نشده» و «رد‌شده» دو حالت متفاوت‌اند و `_assembleDay` هم همین را می‌گوید.
- **وسوسه:** «`ConflictAlgorithm.replace` سریع‌تر است.» → و ستون‌های همسایه را null می‌کند. برای snapshot درست است، برای upsert جزئی فاجعه.
- **وسوسه:** «اول کل معماری را ریفکتور کنم.» → نه. فاز A حداقل زیرساخت لازم است، نه بازنویسی.
- اگر گیر کردی: `BLOCKED` بزن، یادداشت دقیق بنویس، **برو تسک بعدی**. هیچ‌وقت متوقف نشو و منتظر جواب نمان.

**حالا برو. اول `docs/calendar/CALENDAR_FIX_PROGRESS.md` را بساز، بعد CAL-01.**
