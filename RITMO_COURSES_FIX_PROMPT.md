# پرامپت اجرایی — رفع باگ‌ها و بازطراحی UX ماژول «دوره‌های آموزشی» (Courses) در پروژه Ritmo



- **دامنهٔ کار:** ماژول `courses` و تمام نقاط اتصال آن (Agenda، Registry، Goals، Notifications، Engine Bus، Schema/Migrations)


---

## ۰. قواعد اجرای اجباری — قبل از هر کاری این بخش را کامل بخوان

1. **این سند خودِ نقشهٔ پیاده‌سازی است.** برای خودت رودمپ، طرح، پلن، «Implementation Plan»، «Analysis Document»، «Phase Plan» یا هر فایل برنامه‌ریزی دیگری **نساز و ننویس**. مستقیم از `K-01` شروع کن و کد بزن.
2. **بند ۲ فایل `.agents/AGENTS.md` مخزن** (الزام چرخهٔ سه‌مرحله‌ای Draft → Evaluate → Rewrite برای نوشتن رودمپ) **برای این تسک صریحاً لغو است.** بند ۱ (تحلیل عمیق، ممنوعیت تنبلی، ممنوعیت راه‌حل سطحی) و بند ۳ (اجرای `flutter analyze` با صفر error و صفر warning) کاملاً پابرجا و لازم‌الاجراست.
3. فازها را **به ترتیب ۰ → ۹** اجرا کن. بدون عبور از «گیت پذیرش» هر فاز، وارد فاز بعد نشو.
4. هر یافته یک شناسه دارد (`K-01` … `K-107`). در پیام هر کامیت شناسه‌های پوشش‌داده‌شده را بنویس.
5. هر جا نوشته شده **«تصمیم قطعی»**، آن یک دستور است، نه پیشنهاد. حق انتخاب گزینهٔ دیگر نداری و لازم نیست از کاربر بپرسی.
6. **هیچ تغییر رفتار محصولی خارج از این سند اعمال نکن.** ریفکتور فرصت‌طلبانه، تغییر نام دلبخواه، و بازنویسی ماژول‌های دیگر ممنوع است.
7. فایل جدید فقط همان‌هایی که این سند اسمشان را می‌برد. **تنها فایل markdown مجاز برای ساخت، گزارش نهایی فاز ۹ است.**
8. اگر تستی به‌خاطر اصلاح یک باگ می‌شکند و آن تست انتظار **غلط** را کدگذاری کرده بود، تست را اصلاح کن (موارد `K-106` و `K-107`). هرگز باگ را برای سبز نگه‌داشتن تست باقی نگذار و هرگز تست را `skip` نکن.
9. قالب کامیت: `fix(courses): phase N — <خلاصهٔ کوتاه> [K-xx, K-yy]`
10. **PR نساز، push نکن، branch جدید نساز** مگر کاربر جداگانه بخواهد.
11. اگر واقعیت کد با توصیف این سند تفاوت داشت: کد را مبنا بگیر، **هدفِ اصلاح** را حفظ کن، و انحراف را در گزارش فاز ۹ ثبت کن.
12. در تمام کدی که لمس می‌کنی: `catch (_) {}` خالی ممنوع، `debugPrint` برای خطای واقعی ممنوع (از `RitmoLogger`/`RitmoLog` استفاده کن)، `print` ممنوع.
13. هیچ رشتهٔ فارسی جدیدی در `lib/features/courses/logic/**`، `lib/features/courses/models/**`، `lib/core/analytics/courses_engine.dart` یا `lib/core/domain/agenda/sources/course_agenda_source.dart` اضافه نکن. این لایه‌ها فقط `enum` و کد خطا برمی‌گردانند.

---

## فایل‌های تحت مالکیت این تسک

```
lib/features/courses/models/course_models.dart
lib/features/courses/logic/courses_repository.dart
lib/features/courses/logic/course_scheduler.dart
lib/features/courses/logic/course_validation.dart
lib/features/courses/logic/course_timer_service.dart
lib/features/courses/logic/course_energy_engine.dart
lib/features/courses/logic/course_adaptive_engine.dart
lib/features/courses/logic/course_catchup_engine.dart
lib/features/courses/logic/sm2_review_engine.dart
lib/features/courses/logic/courses_ai_helper.dart
lib/features/courses/presentation/courses_screen.dart
lib/features/courses/presentation/course_detail_screen.dart
lib/features/courses/presentation/widgets/*.dart   (۱۵ فایل)
lib/core/analytics/courses_engine.dart
lib/core/domain/agenda/sources/course_agenda_source.dart
lib/features/registry/logic/sources/course_registry_source.dart
lib/core/database/schema/tables/course_tables.dart
lib/core/database/migration/migrations/  (فقط مایگریشن‌های جدیدی که این سند می‌خواهد)
lib/l10n/app_fa.arb , lib/l10n/app_en.arb
test/courses/** , test/courses_engine_test.dart , test/course_scheduler_test.dart
```

فایل‌های جدیدی که **باید** ساخته شوند (و فقط همین‌ها):

```
lib/features/courses/logic/course_date_contract.dart
lib/features/courses/logic/course_metrics.dart
lib/features/courses/logic/course_session_completion_service.dart
lib/features/courses/logic/course_reminder_planner.dart
lib/features/courses/logic/course_review_planner.dart
lib/features/courses/logic/courses_controller.dart
lib/features/courses/presentation/widgets/course_insights_section.dart
lib/features/courses/presentation/widgets/session_actions_sheet.dart
lib/features/courses/presentation/widgets/course_appearance_picker.dart
```

---

## فاز ۰ — ریل‌گذاری و قراردادهای پایه

هدف: قبل از دست‌زدن به منطق، پایه‌های مشترکِ خراب را یکسان کن تا اصلاحات بعدی روی زمین سفت انجام شود.

### K-01 🔵 خط پایه
قبل از هر تغییر، این سه دستور را اجرا کن و خروجی خام را نگه دار:
```
flutter analyze
flutter test
dart format --set-exit-if-changed lib test
```
فهرست تست‌های در حال شکست و خطاهای analyze را ثبت کن. این خط پایه است؛ در فاز ۹ باید همه سبز باشد. **هیچ باگی را بر اساس «از قبل خراب بود» رها نکن.**

### K-02 🔴 قرارداد تاریخ — شش پیاده‌سازی موازی و ناسازگار
**واقعیت فعلی:** تبدیل `DateTime` به کلید روز، در شش جای مختلف و با شش کد متفاوت انجام می‌شود:
- `CourseScheduler._formatDate`
- `CoursesRepository._formatDate`
- `CoursesEngine._formatDate`
- `RitmoDate(dt).value` (در `courses_screen`، `jalali_weekly_heatmap`، `recovery_mode_sheet`)
- فرمت‌کنندهٔ inline در `CourseCatchupEngine.generateCatchupPlan`
- فرمت‌کنندهٔ inline در `course_detail_screen._rescheduleSessionDate`
- `DateTime.now().toIso8601String().split('T').first` در `CourseRegistrySource.fetch`

علاوه بر آن، جابه‌جایی روز با `Duration(days: 1)` روی `DateTime` **محلی** انجام می‌شود (`CourseScheduler.distributeSessions`, `getSaturdayOfWeek`, `CoursesEngine` محاسبهٔ استریک، `RecoveryModeSheet` با `Duration(days: 14)`) که در مرز تغییر ساعت رسمی یک روز را تکرار یا حذف می‌کند.

**تصمیم قطعی:** فایل جدید `lib/features/courses/logic/course_date_contract.dart` بساز با این API و **فقط** همین API در کل ماژول استفاده شود:
```dart
class CourseDate {
  static String toDayKey(DateTime dt);            // 'YYYY-MM-DD' از اجزای محلی
  static DateTime? parseDayKey(String? key);      // null-safe، بدون throw
  static DateTime addDays(DateTime dt, int days); // DST-safe: از DateTime.utc عبور می‌کند
  static int daysBetween(DateTime a, DateTime b); // اختلاف روزِ تقویمی، نه ساعت
  static DateTime startOfFarsiWeek(DateTime dt);  // شنبه
  static bool isSameDay(DateTime a, DateTime b);
  static String toJalaliDisplay(DateTime dt);     // '۱۴۰۵/۰۶/۱۴'
  static String dayKeyToJalaliDisplay(String key);
}
```
قواعد: `daysBetween` باید هر دو طرف را به `DateTime.utc(y, m, d)` نرمال کند. `addDays` هم. تمام هفت پیاده‌سازی بالا حذف و به این کلاس منتقل شوند. `RitmoDate` را حذف نکن (ماژول‌های دیگر از آن استفاده می‌کنند) اما داخل `courses` دیگر از آن استفاده نکن.

**تأیید:** `grep -rn "_formatDate\|toIso8601String()\.split\|Duration(days:" lib/features/courses lib/core/analytics/courses_engine.dart lib/features/registry/logic/sources/course_registry_source.dart` نباید هیچ فرمت‌کنندهٔ تاریخ یا جمع روزِ خام برگرداند.

### K-03 🔴 تاریخ میلادی در رابط کاربری فارسی
**واقعیت فعلی:** `course_detail_screen` تاریخ برنامه‌ریزی جلسه را این‌گونه نشان می‌دهد:
```dart
'برنامه‌ریزی: ${toPersianDigits(session.plannedDate)} 📅'
```
`plannedDate` یک رشتهٔ **میلادی** `YYYY-MM-DD` است؛ نتیجه چیزی مثل `۲۰۲۶-۰۹-۰۵` می‌شود — تاریخ میلادی با ارقام فارسی، داخل اپلیکیشنی که کل تقویمش شمسی است. همان صفحه پس از تغییر تاریخ، پیام `'زمان جلسه به ${toPersianDigits(formatted)} تغییر یافت.'` را هم با همان فرمت میلادی نشان می‌دهد. در مقابل، `JalaliWeeklyHeatmap` و `RecoveryModeSheet` درست عمل می‌کنند و شمسی نشان می‌دهند.

**تصمیم قطعی:** هر تاریخی که به کاربر نشان داده می‌شود باید از `CourseDate.dayKeyToJalaliDisplay` عبور کند. ذخیره‌سازی در دیتابیس **بدون تغییر** میلادی `YYYY-MM-DD` می‌ماند (تغییر فرمت ذخیره ممنوع است — کل ایندکس‌ها و مقایسه‌های رشته‌ای به آن وابسته‌اند). یک تست بساز که مطمئن شود هیچ ویجتی مستقیماً `session.plannedDate` یا `course.targetEndDate` را داخل `Text` نمی‌گذارد.

### K-04 🟠 چهار پیاده‌سازی ارقام فارسی + یک helper مرده
**واقعیت فعلی:** `course_formatters.toPersianDigits` برای هر فراخوانی ۱۰ بار `replaceAll` روی رشته اجرا می‌کند و در هر فریم صدها بار صدا زده می‌شود. همزمان `RitmoNumber.toEn` برای مسیر معکوس وجود دارد و پیاده‌سازی‌های مشابه در ماژول‌های دیگر (مثلاً `cycle_lock_gate._toPersianDigits`) تکرار شده. تابع `formatDuration` در همان فایل `course_formatters.dart` نوشته شده و **هیچ‌جا استفاده نمی‌شود**، در حالی که `CoursesWeeklyHero` دقیقه‌ها را خام نشان می‌دهد («۴۵۰ دقیقه» به‌جای «۷ ساعت و ۳۰ دقیقه»).

**تصمیم قطعی:** یک پیادهٔ واحد در `lib/core/util/ritmo_number.dart` (کنار `toEn`) به نام `RitmoNumber.toFa(Object? input)` با پیمایش تک‌گذر روی code unit‌ها بساز. `course_formatters.toPersianDigits` را به یک `@Deprecated` wrapper نازک روی آن تبدیل کن و همهٔ فراخوانی‌ها را به نسخهٔ جدید ببر. `formatDuration` را به همان فایل core منتقل کن و **همه‌جا** برای نمایش دقیقه استفاده کن (به‌ویژه `CoursesWeeklyHero` و `CompletedCoursesSection`).

### K-05 🟠 لاگ خطای بی‌صدا
**واقعیت فعلی:** تمام مسیرهای بحرانی خطا را می‌خورند و فقط `debugPrint` می‌کنند: `CoursesScreen._loadAllData`, `CourseDetailScreen._loadCourseData`, `CourseTimerService.initOnAppStart`, `CoursesAiHelper` (دو جا), `CourseAgendaSource.load`, `AiSyllabusSheet._saveCourseAndSessions`, `CreateCourseSheet._loadActiveGoals` و `_saveCourse`, و `SafeCourseColor.resolvedColor` که `catch (_) {}` کاملاً خالی دارد.

**تصمیم قطعی:** همه به `RitmoLog.error('COURSES', ..., error: e, stackTrace: st)` تبدیل شوند. هیچ‌جا محتوای یادداشت کاربر (`note`, `keyTakeaway`, `openQuestion`) در لاگ نرود. `test/logger_redaction_test.dart` باید سبز بماند.

### گیت پذیرش فاز ۰
- `course_date_contract.dart` ساخته شده و تنها منبع تاریخ در ماژول است.
- هیچ تاریخ میلادی در UI دیده نمی‌شود.
- `RitmoNumber.toFa` و `formatDuration` تنها مسیر نمایش عدد و مدت‌زمان هستند.
- `flutter analyze` صفر خطا. تست‌های موجود همان وضعیت خط پایه یا بهتر.

---

## فاز ۱ — باگ‌های کرش و خطاهای قطعیِ زمان اجرا

این فاز شامل مواردی است که یا استثنا پرتاب می‌کنند، یا یک قابلیت را **کاملاً** از کار انداخته‌اند.

### K-06 🔴 `CourseRegistrySource.fetch` با SQL نامعتبر کرش می‌کند
**واقعیت فعلی:** در `lib/features/registry/logic/sources/course_registry_source.dart`:
```dart
final doneRes = await db.rawQuery(
  "SELECT COUNT(*) as cnt FROM course_sessions WHERE courseId = ? AND isCompleted = 1",
  [id],
);
```
ستون `isCompleted` **در جدول `course_sessions` وجود ندارد**. نام واقعی ستون `completionStatus TEXT` با مقادیر `'PENDING' | 'COMPLETED' | 'SKIPPED'` است (`isCompleted` فقط یک getter در Dart است). این کوئری در زمان اجرا `SQLiteException: no such column: isCompleted` می‌دهد و **کل صفحهٔ Registry برای دامنهٔ دوره‌ها را می‌شکند**.

در همان فایل دو خطای مشابه هست:
- `final instructor = r['instructor'] as String?;` — ستونی به نام `instructor` وجود ندارد؛ نام واقعی `provider` است. نتیجه: همیشه `null` و subtitle همیشه بدون نام مدرس.
- `count({bool includeArchived = false})` پارامتر را کاملاً نادیده می‌گیرد و `SELECT COUNT(*) FROM courses` می‌زند، پس دوره‌های آرشیوی و تکمیل‌شده هم شمرده می‌شوند در حالی که `fetch` هم فیلتر ندارد.

همچنین `fetch` برای هر ردیف یک کوئری جدا می‌زند (N+1).

**تصمیم قطعی:** یک کوئری تجمیعی جایگزین کن:
```sql
SELECT c.id, c.title, c.provider, c.preferredTime, c.sessionDurationMinutes,
       c.totalSessions, c.status, c.isArchived,
       SUM(CASE WHEN cs.completionStatus = 'COMPLETED' THEN 1 ELSE 0 END) AS doneCount
FROM courses c
LEFT JOIN course_sessions cs ON cs.courseId = c.id
WHERE (:includeArchived = 1 OR c.isArchived = 0)
GROUP BY c.id
ORDER BY c.createdAt DESC
LIMIT ? OFFSET ?
```
`count()` هم باید همان شرط `includeArchived` را اعمال کند. `RegistryStatus` را از `c.status` بخوان، نه از مقایسهٔ `doneCount >= totalSessions`. تست: یک fixture واقعی `sqflite_common_ffi` با یک دوره و سه جلسه بساز و مطمئن شو `fetch` استثنا نمی‌دهد و `doneCount` درست است.

### K-07 🔴 کرش هنگام ویرایش دوره‌ای که هدف متصلش آرشیو شده
**واقعیت فعلی:** `CreateCourseSheet` لیست اهداف را با این کوئری می‌گیرد:
```dart
db.query('goals', columns: ['id','title'], where: "status = 'ACTIVE' AND isPrivate = 0")
```
و `DropdownButton<String?>` را با `value: _linkedGoalId` می‌سازد که از `course.linkedGoalId` می‌آید. اگر هدف متصل بعداً به `COMPLETED`/`ARCHIVED` رفته باشد یا `isPrivate = 1` شده باشد، در `items` وجود ندارد و `DropdownButton` assert می‌کند: «There should be exactly one item with [DropdownButton]'s value». نتیجه: **باز کردن شیت ویرایش آن دوره کرش می‌کند** و کاربر هیچ راهی برای ویرایش یا قطع اتصال ندارد.

همچنین آیتم «بدون اتصال به هدف» بدون `value:` نوشته شده (پارامتر `value` حذف شده) که اتفاقی کار می‌کند اما قرارداد را مبهم می‌گذارد.

**تصمیم قطعی:** در `_loadActiveGoals`، اگر `_linkedGoalId != null` و در لیست نبود، هدف را جداگانه با `getLinkedGoalTitle` بخوان و به‌عنوان یک آیتم غیرفعال با برچسب `«<عنوان> (غیرفعال)»` به `items` اضافه کن. آیتم خالی را صریحاً `value: null` بده. تا زمانی که `_activeGoals` بارگذاری نشده، `value` را `null` بگذار و dropdown را `disabled` کن. تست ویجت برای این سناریو بنویس.

### K-08 🔴 ورودی با ارقام فارسی توسط اعتبارسنجی فرم رد می‌شود
**واقعیت فعلی:** در `CreateCourseSheet`، `_saveCourse` ورودی را با `RitmoNumber.toEn(...)` نرمال می‌کند، اما `validator` فیلدهای «تعداد کل جلسات» و «مدت هر جلسه» مستقیماً روی متن خام کار می‌کند:
```dart
validator: (value) {
  if (value == null || int.tryParse(value) == null || (int.tryParse(value) ?? 0) <= 0) {
    return 'عدد بزرگتر از ۰ وارد کنید';
  }
  return null;
},
```
`int.tryParse('۱۲')` مقدار `null` برمی‌گرداند. پس کاربر فارسی‌زبانی که با کیبورد فارسی عدد وارد می‌کند، پیام «عدد بزرگتر از ۰ وارد کنید» می‌گیرد و **نمی‌تواند دوره بسازد** — در حالی که اگر از validator عبور می‌کرد، `_saveCourse` عدد را درست می‌خواند.

**تصمیم قطعی:** validator‌ها هم باید از `RitmoNumber.toEn` عبور کنند. علاوه بر آن `inputFormatters` اضافه کن که هنگام تایپ، ارقام فارسی/عربی را به لاتین تبدیل کند تا مقدار ذخیره‌شده در controller همیشه ماشین‌خوان باشد. تست: یک تست ویجت که `۱۲` تایپ می‌کند و انتظار دارد اعتبارسنجی پاس شود و `totalSessions == 12` ذخیره شود.

### K-09 🔴 قانون تطابق انرژی هرگز فعال نمی‌شود (ستون اشتباه)
**واقعیت فعلی:** `CoursesRepository.getCurrentEnergyLevel()`:
```dart
final logs = await db.query('energy_logs', orderBy: 'loggedAt DESC', limit: 1);
if (logs.isNotEmpty) {
  final lvl = logs.first['level'] as String?;   // <-- ستون 'level'
  ...
}
```
جدول `energy_logs` ستونی به نام `level` ندارد؛ ستون واقعیِ سطح انرژی `energyLevel` است. پس `lvl` همیشه `null` می‌شود، تابع به `default_energy_level` می‌افتد و در نهایت **همیشه `'MEDIUM'`** برمی‌گرداند. نتیجه: `CourseEnergyEngine`، هشدارهای انرژی در `TodaySessionsSection`، و کل قانون‌های `skip` / `offerLight` / `highEnergyOnly` که در `CreateCourseSheet` به کاربر وعده داده می‌شوند، **هیچ‌وقت اجرا نمی‌شوند**. این یعنی یک قابلیت کامل، مرده است.

مشکل دوم: هیچ فیلتر زمانی وجود ندارد. آخرین ثبت انرژی حتی اگر سه ماه پیش باشد، «انرژی فعلی» محسوب می‌شود.

**تصمیم قطعی:**
1. اول شمای واقعی `energy_logs` را با خواندن `lib/core/database/schema/tables/` تأیید کن و نام درست ستون را استفاده کن. اگر نگاشت با `if (lvl == null)` مبهم بود، از یک alias در SQL استفاده کن نه از حدس.
2. فقط ثبت‌های **امروز** معتبر باشند: `WHERE loggedAt >= <startOfTodayMs>`.
3. تابع باید یک `enum CourseEnergyLevel { low, medium, high, unknown }` برگرداند، نه `String`. `unknown` رفتار «هیچ فیلتری اعمال نکن» دارد و در UI هیچ هشداری نشان نمی‌دهد (در حال حاضر `unknown` به‌غلط `MEDIUM` تلقی می‌شود و قانون `highEnergyOnly` جلسه را پنهان می‌کند).
4. `CourseEnergyEngine.filterAndRankForEnergy` امضایش را به `enum` تغییر دهد و مقایسهٔ رشته‌ای `toUpperCase()` حذف شود.
5. مقادیر `energyRule` (`'NONE'`, `'skip'`, `'offerLight'`, `'highEnergyOnly'`) هم به `enum CourseEnergyRule` تبدیل شوند با نگاشت DB (کد فعلی مخلوطی از SCREAMING_CASE و camelCase است و **هیچ CHECK constraint‌ای ندارد**، پس یک غلط تایپی قانون را بی‌صدا خاموش می‌کند).

### K-10 🔴 بازگشت بی‌صدا از داخل تراکنش، به‌عنوان «موفقیت» گزارش می‌شود
**واقعیت فعلی:** الگوی زیر در `completeSession`, `uncompleteSession`, `skipSession`, `updateCourseStatus`, `updateCourse` تکرار شده:
```dart
await db.transaction((txn) async {
  final sessionMaps = await txn.query('course_sessions', where: 'id = ?', whereArgs: [sessionId]);
  if (sessionMaps.isEmpty) return;   // <-- فقط از closure برمی‌گردد
  ...
});
await syncCourseAlarms();
_fireEvent('COMPLETE', courseId: courseId, sessionId: sessionId);  // courseId = null
```
`return` داخل closure تراکنش، تراکنش را **با موفقیت commit می‌کند**. سپس کد بیرونی `syncCourseAlarms()` را اجرا می‌کند و رویداد `CoursesChanged`/`CourseSessionCompleted` را با `courseId: null` منتشر می‌کند. یعنی «تکمیل یک جلسهٔ حذف‌شده» به‌عنوان تکمیل موفق به کل سیستم اعلام می‌شود. در `updateCourse` هم `if (existingCourse == null) return;` بی‌هیچ خطایی از تابع برمی‌گردد و UI پیام «تغییرات ذخیره شد» نشان می‌دهد.

**تصمیم قطعی:** یک `enum CourseMutationResult { applied, notFound, noOp }` معرفی کن. همهٔ متدهای جهش‌دهنده این را برگردانند. `syncCourseAlarms` و `_fireEvent` فقط در حالت `applied` اجرا شوند. UI در حالت `notFound` پیام خطای مشخص («این جلسه دیگر وجود ندارد») نشان دهد و لیست را رفرش کند. برای مسیرهای واقعاً استثنایی (مثل `CourseValidationException`) رفتار فعلی throw حفظ شود.

### K-11 🟠 شمارهٔ جلسهٔ تکراری، ویرایش دوره را بی‌صدا از بین می‌برد
**واقعیت فعلی:** جدول `course_sessions` یک ایندکس `UNIQUE(courseId, sessionNumber)` دارد. در `updateCourse` مسیر افزایش تعداد جلسات:
```dart
final startSessionNumber = existingSessions.length + 1;
... sessionNumber: startSessionNumber + i ...
await txn.insert('course_sessions', newSession.toMap(),
    conflictAlgorithm: ConflictAlgorithm.abort);
```
اگر قبلاً جلساتی از میانهٔ لیست حذف شده باشند یا `reorderSessions` شماره‌ها را جابه‌جا کرده باشد، `existingSessions.length + 1` می‌تواند با یک `sessionNumber` موجود برابر شود. `ConflictAlgorithm.abort` **کل تراکنش را rollback می‌کند**؛ کاربر فقط یک توست عمومی «خطایی در ذخیره دوره رخ داد» می‌بیند و همهٔ ویرایش‌هایش از دست می‌رود.

همچنین شناسه‌ها با `'sess_${now.millisecondsSinceEpoch}_${course.id.hashCode}_$i'` ساخته می‌شوند و شناسهٔ خودِ دوره با `'course_${now.millisecondsSinceEpoch}_${title.hashCode}'`. `String.hashCode` در Dart **تضمین پایداری بین نسخه‌های VM ندارد** و برای تولید شناسهٔ دائمیِ رکورد نامناسب است.

**تصمیم قطعی:**
1. شمارهٔ شروع را از دیتابیس و داخل تراکنش بخوان: `SELECT COALESCE(MAX(sessionNumber), 0) + 1 FROM course_sessions WHERE courseId = ?`.
2. تولید شناسه را به یک helper مرکزی منتقل کن که از `uuid` v4 استفاده می‌کند (بستهٔ `uuid` را اگر در `pubspec.yaml` نیست اضافه کن؛ اگر هست همان را به کار بگیر). قالب: `'sess_<uuid>'` و `'course_<uuid>'`.
3. `conflictAlgorithm: ConflictAlgorithm.abort` باقی بماند (fail-fast درست است) اما خطا باید به `CourseValidationException('SESSION_NUMBER_CONFLICT', ...)` تبدیل و با پیام معنادار به کاربر نشان داده شود.

### K-12 🟠 `reorderSessions` با ایندکس UNIQUE ناسازگار است (و در ضمن مرده است)
**واقعیت فعلی:** `reorderSessions` داخل یک تراکنش، ردیف‌به‌ردیف `sessionNumber` را به‌روزرسانی می‌کند. با وجود `UNIQUE(courseId, sessionNumber)`، هر جابه‌جایی که یک شمارهٔ در حال استفاده را هدف بگیرد (مثلاً تعویض ۱ و ۲) در **همان دستور** UNIQUE را نقض می‌کند و throw می‌کند. این باگ تا امروز بروز نکرده چون **هیچ‌کس `reorderSessions` را صدا نمی‌زند** — منطق دقیق حفظ عنوان‌های سفارشی که در آن نوشته شده، کد مرده است، و در عوض `course_detail_screen` هیچ امکان جابه‌جایی جلسه ندارد.

**تصمیم قطعی:** بازنویسی دومرحله‌ای:
```
1) UPDATE course_sessions SET sessionNumber = -sessionNumber WHERE courseId = ?
2) برای هر id به ترتیب جدید: UPDATE ... SET sessionNumber = ?, displayOrder = ? WHERE id = ?
```
منطق حفظ عنوان سفارشی («فقط عنوان‌هایی را بازنویسی کن که دقیقاً الگوی `<unitLabel> <number>` را دارند») **دقیقاً همان‌طور که هست** حفظ شود. سپس در فاز ۷ این متد به UI وصل می‌شود (`K-83`). تست: یک reorder کامل معکوس (۱→۵، ۵→۱) روی دیتابیس واقعی که باید بدون خطا اجرا شود.

### K-13 🟠 `ensureSchema` وعده‌ای می‌دهد که انجام نمی‌دهد
**واقعیت فعلی:** `CourseTables.ensureSchema` با کامنت «Self-healing schema validation to ensure course/study session tables exist» نوشته شده، اما بدنهٔ آن **فقط** `study_active_session` را می‌سازد. جداول `courses`، `course_sessions` و `course_active_timers` هیچ مسیر self-heal ندارند، در حالی که `courses` بدون `IF NOT EXISTS` ساخته می‌شود.

مشکل دوم: `study_active_session` متعلق به ماژول Konkur/Study است اما داخل `course_tables.dart` ساخته می‌شود.

**تصمیم قطعی:** `ensureSchema` را کامل کن تا برای هر سه جدول courses از `CREATE TABLE IF NOT EXISTS` + ایندکس‌های `IF NOT EXISTS` استفاده کند. تعریف `study_active_session` را به فایل جداگانهٔ `study_tables.dart` منتقل کن و از رجیستری شمای اصلی صدا بزن (اگر فایل مشابهی هست، به آن اضافه کن). **مایگریشن جدیدی برای این مورد لازم نیست** — فقط self-heal و مالکیت درست.

### گیت پذیرش فاز ۱
- `CourseRegistrySource.fetch` روی fixture واقعی sqflite بدون استثنا اجرا می‌شود و `doneCount` درست است.
- ویرایش دوره‌ای با هدف آرشیوشده کرش نمی‌کند (تست ویجت سبز).
- تایپ `۱۲` در فرم ساخت دوره پذیرفته می‌شود (تست ویجت سبز).
- `getCurrentEnergyLevel` یک `enum` برمی‌گرداند و روی fixture با ردیف `energy_logs` امروز، مقدار درست می‌دهد.
- `grep -rn "isCompleted = 1\|r\['instructor'\]" lib` هیچ نتیجه‌ای ندارد.
- reorder معکوس کامل روی ۵ جلسه بدون خطا انجام می‌شود.
- `flutter analyze` صفر خطا و صفر warning.

---

## فاز ۲ — تایمر مطالعه و مسیر ثبت جلسه (بیشترین تراکم باگ در کل ماژول)

این فاز قلب تجربهٔ کاربر است: مقدار `actualDurationMinutes` که اینجا تولید می‌شود، ورودی هر متریک دیگری است (دقیقهٔ هفتگی، هیت‌مپ، دقت تخمین، ماندگاری). هر خطایی در اینجا کل تحلیل‌ها را مسموم می‌کند.

### K-14 🔴 تایمر رهاشده منجر به ثبت جعلی ۸ ساعت مطالعه می‌شود
**واقعیت فعلی:** در `ActiveCourseTimer.calculateCurrentElapsedSeconds`:
```dart
final runningSeconds = (now.millisecondsSinceEpoch - startedAt) ~/ 1000;
final total = elapsedSecondsBeforePause + (runningSeconds > 0 ? runningSeconds : 0);
return total > 28800 ? 28800 : total;   // سقف ۸ ساعت
```
اگر کاربر تایمر را شروع کند و اپ را ببندد و سه روز بعد برگردد، `initOnAppStart` محاسبه می‌کند که تایمر بیش از ۸ ساعت را گذرانده، آن را به `elapsedSecondsBeforePause: 28800` پین می‌کند و pause می‌کند. سپس `FocusModeScreen._finishTimer` یا `FloatingTimerBar` این را `(elapsedSec / 60).ceil().clamp(1, 480)` می‌کند و **`actualDurationMinutes: 480` در دیتابیس می‌نویسد**. کاربر هیچ هشداری نمی‌بیند و از آن لحظه به بعد: `weeklyStudyMinutes` در اعداد نجومی، `estimationAccuracy` حدود ۱۰، و هیت‌مپ با یک ستون غیرواقعی که مقیاس بقیه را له می‌کند.

**تصمیم قطعی:** مفهوم **تایمر بایات (stale)** معرفی کن:
1. در `initOnAppStart`، اگر تایمر در حالت RUNNING بوده و `now - updatedAt > 2 ساعت`، تایمر را به `state = 'STALE'` تغییر بده و مقدار elapsed را **روی آخرین `updatedAt` معتبر** قطع کن، نه روی `now`.
2. مقدار `state` در جدول `course_active_timers` باید `'RUNNING' | 'PAUSED' | 'STALE'` باشد. مایگریشن لازم نیست (ستون TEXT بدون CHECK است).
3. در اولین مواجهه با تایمر `STALE`، یک دیالوگ نشان بده: «یک جلسهٔ نیمه‌تمام با حدود X دقیقه پیدا شد» با سه گزینه: «ثبت با همین مدت» / «ویرایش مدت» / «دور ریختن این تایمر». این دیالوگ را در `FloatingTimerBar` میزبانی کن (تنها جایی که همیشه دیده می‌شود).
4. سقف ۸ ساعت باقی بماند اما **دیگر هرگز به‌عنوان مقدار واقعی ذخیره نشود**؛ سقف فقط برای نمایش است.
5. `clamp(1, 480)` را از دو ویجت حذف کن؛ تبدیل ثانیه به دقیقه باید **در یک جا** در `CourseTimerService` انجام شود.

### K-15 🔴 اتمام تایمر و بستن شیت بازخورد ، مطالعه را کاملاً نابود می‌کند
**واقعیت فعلی:** در `FocusModeScreen._finishTimer`:
```dart
final elapsedMin = (elapsedSec / 60).ceil().clamp(1, 480);
await CourseTimerService.instance.stopTimer();   // <-- ردیف تایمر از DB حذف می‌شود
Navigator.pop(context);
SessionDebriefSheet.show(context, session: ..., actualDurationMinutes: elapsedMin);
```
اگر کاربر شیت بازخورد را با swipe ببندد (که هیچ دکمهٔ «انصراف» هم ندارد)، تایمر حذف شده، جلسه PENDING مانده، و **۹۰ دقیقه مطالعهٔ واقعی برای همیشه گم شده است**. دقیقاً همین باگ در دکمهٔ اتمام `FloatingTimerBar` هم تکرار شده.

**تصمیم قطعی:** ترتیب را معکوس کن. یک سرویس جدید `lib/features/courses/logic/course_session_completion_service.dart` بساز:
```dart
class CourseSessionCompletionService {
  static Future<void> finishWithDebrief(BuildContext context, {
    required Course course,
    required CourseSession session,
  });
}
```
منطق:
1. `elapsedMinutes` را از `CourseTimerService` بخوان اما **تایمر را حذف نکن**؛ فقط `pauseTimer()` کن.
2. `SessionDebriefSheet` را نشان بده و منتظر نتیجه بمان (`Future<bool>` برگرداند: `true` = ذخیره شد).
3. فقط اگر ذخیره شد → `stopTimer()`.
4. اگر کاربر شیت را بست → تایمر در حالت PAUSED زنده می‌ماند، `FloatingTimerBar` نمایش داده می‌شود، و یک توست می‌گوید «جلسه ثبت نشد؛ تایمر متوقف شده و می‌توانی ادامه بدهی».
5. `SessionDebriefSheet` باید یک دکمهٔ صریح «فعلاً نه» داشته باشد که همین مسیر را طی کند.

### K-16 🔴 شروع تایمر جدید، تایمر در حال اجرا را بی‌هشدار نابود می‌کند
**واقعیت فعلی:** `CourseTimerService.startTimer` بی‌قیدوشرط `await db.delete('course_active_timers')` (بدون `where`!) می‌زند و تایمر جدید می‌سازد. `StudyTimerSheet` یک دیالوگ تعارض دارد (`_promptActiveTimerConflict`) — اما `WhatToReadNowCard` مستقیماً این را صدا می‌زند:
```dart
await CourseTimerService.instance.startTimer(course.id, session.id);
```
پس اگر کاربر ۴۰ دقیقه روی جلسهٔ A کار کرده باشد و روی کارت «الان چی بخونم؟» برای جلسهٔ B بزند، هر ۴۰ دقیقه بی‌هیچ پیامی پاک می‌شود.

**تصمیم قطعی:**
1. `startTimer` را به `startTimer({required String courseId, required String sessionId, bool force = false})` تغییر بده. اگر تایمری برای سشن دیگر فعال باشد و `force == false`، یک `CourseTimerConflictException` با شناسهٔ سشن و ثانیهٔ سپری‌شده پرتاب کن.
2. دیالوگ تعارض را از `StudyTimerSheet` به یک تابع مشترک در `CourseSessionCompletionService` منتقل کن تا هر دو مسیر (و هر مسیر آینده) از آن استفاده کنند. متن دیالوگ باید **مدت سپری‌شدهٔ تایمر قبلی و عنوان جلسهٔ قبلی** را نشان دهد و گزینهٔ سوم داشته باشد: «اول جلسهٔ قبلی را ثبت کن».
3. `db.delete` بدون `where` را در هر دو متد `startTimer` و `stopTimer` به `where: 'courseSessionId = ?'` تبدیل کن.

### K-17 🟠 `pauseTimer` به مقداری که UI می‌دهد اعتماد می‌کند
**واقعیت فعلی:** `pauseTimer(int currentElapsedSeconds)` مقدار را از فراخوانی‌کننده می‌گیرد. سه فراخوانی‌کننده وجود دارد که یکیشان (`StudyTimerSheet._togglePlayPause`) مقدار یک‌ثانیه بایات می‌دهد. اگر فردا یک فراخوانی‌کنندهٔ جدید صفر بدهد، کل زمان بی‌صدا صفر می‌شود.

**تصمیم قطعی:** امضا به `Future<void> pauseTimer()` تغییر کند و خودِ سرویس `_activeTimer!.calculateCurrentElapsedSeconds(DateTime.now())` را محاسبه کند. همهٔ فراخوانی‌کننده‌ها به‌روز شوند.

### K-18 🟠 تک تایمر دائمی در پس‌زمینه و بارگذاری DB هر ثانیه
**واقعیت فعلی:**
- `CourseTimerService._startTicker` یک `Timer.periodic(1s)` می‌سازد که تا زمان توقف تایمر می‌ماند — حتی وقتی اپ در پس‌زمینه است. سرویس یک singleton است و هرگز dispose نمی‌شود.
- `FloatingTimerBar._onTimerUpdated` **در هر tick** `_loadTimerData()` (یک تابع async) را صدا می‌زند و سپس `setState(() {})` را هم. یعنی دو بار rebuild در هر ثانیه و یک فراخوانی async بی‌مدیریت.

**تصمیم قطعی:**
1. `CourseTimerService` باید `WidgetsBindingObserver` را پیاده کند (یا یک متد `onAppLifecycleChanged` داشته باشد که از `main.dart` صدا زده می‌شود). در `paused`/`inactive`/`hidden` تکر را متوقف کن و `updatedAt` را در DB به‌روز کن (لازمهٔ تشخیص stale در `K-14`). در `resumed` تکر را دوباره راه بینداز.
2. `FloatingTimerBar` باید دو مسیر را جدا کند: (الف) تیک زمانی که فقط متن تایمر را با یک `ValueListenableBuilder`/`AnimatedBuilder` بازسازی کند؛ (ب) تغییر هویت جلسه که فقط وقتی `sessionId` عوض شده دیتابیس را بخواند. فراخوانی async داخل کال‌بک notifier ممنوع است.
3. در `FloatingTimerBar._loadTimerData`، جای `sessions.firstWhere(..., orElse: () => sessions.first)` را با `firstWhereOrNull` عوض کن؛ رفتار فعلی در صورت نبودن سشن موردنظر، **جلسهٔ اشتباهی را به کاربر نشان می‌دهد** و تایمر را به آن نسبت می‌دهد. اگر null بود، تایمر را متوقف کن (همان کاری که برای `sessions.isEmpty` می‌کند).

### K-19 🔴 چهار مسیر متفاوت برای تکمیل جلسه با کیفیت دادهٔ متفاوت
**واقعیت فعلی:** چهار راه مختلف برای تکمیل یک جلسه وجود دارد و هر کدام مجموعهٔ متفاوتی از فیلدها را پر می‌کند:

| مسیر | duration | note | understandingScore | needsReview | keyTakeaway | openQuestion |
|---|---|---|---|---|---|---|
| `TodaySessionsSection._completeDirectly` | پیش‌فرض دوره (جعلی) | — | — | — | — | — |
| `StudyTimerSheet._finishSession` | واقعی | ✓ | — | — | — | — |
| `FocusModeScreen` → `SessionDebriefSheet` | واقعی | ✓ | ✓ | ✓ | ✓ | ✓ |
| `FloatingTimerBar` → `SessionDebriefSheet` | واقعی | ✓ | ✓ | ✓ | ✓ | ✓ |

نتیجه: `masteryByCourse`، `needsReview` و کل بخش «برداشت‌های من» به این بستگی دارد که کاربر تصادفاً کدام دکمه را زده. دو مسیر از چهار مسیر، هیچ دادهٔ کیفی تولید نمی‌کنند.

**تصمیم قطعی:** تمام تکمیل‌ها از `CourseSessionCompletionService` عبور کنند و همیشه `SessionDebriefSheet` نمایش داده شود، اما با دو حالت:
- `DebriefMode.full` — پس از تایمر (همان فرم کامل فعلی).
- `DebriefMode.quick` — برای «تکمیل مستقیم»: فقط ردیف امتیاز درک (۵ دکمه) + فیلد مدت قابل ویرایش با پیش‌فرض مدت دوره. هیچ جلسه‌ای بدون دست‌کم امتیاز درک ثبت نشود.

`StudyTimerSheet` دیالوگ داخلی خودش را حذف کند و از همین سرویس استفاده کند.

### K-20 🔴 «تکمیل مستقیم» دادهٔ ساختگی را مثل دادهٔ اندازه‌گیری‌شده ذخیره می‌کند
**واقعیت فعلی:** `TodaySessionsSection._completeDirectly` مقدار `course.sessionDurationMinutes` را به‌عنوان `actualDurationMinutes` می‌نویسد. این عدد دقیقاً برابر `estimatedDurationMinutes` است، پس `estimationAccuracy` برای آن جلسات **دقیقاً ۱.۰** می‌شود و متریک «دقت تخمین مدت» را به سمت ۱ می‌کشد. در دیتابیس هیچ راهی برای تمیز دادن مدت واقعی و مدت حدسی وجود ندارد.

مشکل دوم در همان تابع: در حالت `offerLight` (انرژی پایین)، UI به کاربر وعده می‌دهد «نسخهٔ سبک به مدت X دقیقه» (`customDuration`) اما `_completeDirectly` مقدار **کامل** `course.sessionDurationMinutes` را می‌نویسد — متناقض با همان کارتی که دکمه در آن قرار دارد.

**تصمیم قطعی:**
1. یک ستون جدید با مایگریشن اضافه کن: `durationSource TEXT NOT NULL DEFAULT 'UNKNOWN' CHECK(durationSource IN ('TIMER','MANUAL','DEFAULT','UNKNOWN'))` روی `course_sessions`. فایل مایگریشن را دقیقاً مطابق الگوی موجود (`migration_v97_course_session_question_resolved.dart` را به‌عنوان الگو بخوان، از `safeAddColumn` استفاده کن) بساز و در `migrations_registry.dart` با شمارهٔ نسخهٔ بعدی موجود ثبت کن.
2. `'TIMER'` فقط از مسیر تایمر؛ `'MANUAL'` وقتی کاربر در debrief مدت را با دست وارد کند؛ `'DEFAULT'` وقتی از پیش‌فرض دوره استفاده شده.
3. `CoursesEngine.estimationAccuracy` **فقط** روی `durationSource = 'TIMER'` محاسبه شود.
4. `weeklyStudyMinutes` همه را بشمارد اما فیلد `estimatedMinutesIncluded` دقیق شود و در UI نمایش داده شود (`K-21`).
5. `_completeDirectly` در حالت `offerLight` همان `customDuration` را بنویسد، نه مدت کامل.

### K-21 🟠 دقیقهٔ تخمینی به‌عنوان دقیقهٔ واقعی نمایش داده می‌شود
**واقعیت فعلی:** `CoursesEngine` فیلد `estimatedMinutesIncluded` را درست محاسبه می‌کند، اما `CoursesScreen` آن را به `CoursesWeeklyHero` پاس نمی‌دهد و `CoursesWeeklyHero` هم هیچ پارامتری برای آن ندارد. کاربر عدد «۴۵۰ دقیقه» را به‌عنوان زمان اندازه‌گیری‌شده می‌بیند در حالی که ممکن است ۱۰۰٪ حدسی باشد.

**تصمیم قطعی:** `estimatedMinutesIncluded` را پاس بده و در کارت، مقدار با پیشوند `≈` و یک آیکون info با tooltip «برخی جلسات بدون تایمر ثبت شده‌اند و مدت آن‌ها تخمینی است» نمایش داده شود. مقدار با `formatDuration` نشان داده شود (`K-04`).

### K-22 🟠 هیت‌مپ بر اساس تاریخ **برنامه‌ریزی** باکت می‌شود، نه تاریخ انجام
**واقعیت فعلی:** `JalaliWeeklyHeatmap`:
```dart
if (s.isCompleted && s.plannedDate == dtStr) {
  dayMinutes[i] += s.actualDurationMinutes ?? 30;
}
```
جلسه‌ای که برای هفتهٔ گذشته برنامه‌ریزی شده و امروز انجام شده، **در هیت‌مپ امروز دیده نمی‌شود**؛ و جلسه‌ای که برای فردا برنامه‌ریزی شده و امروز جلوتر انجام شده، روی فردا می‌نشیند. کل تفسیر «الگوی مطالعه این هفته» غلط است.

دو مشکل دیگر در همان ویجت:
- `?? 30` یک مقدار پیش‌فرض **سوم** برای مدت است (۴۵ در `AiSyllabusSheet` و `CoursesEngine`، `course.sessionDurationMinutes` در جای دیگر).
- `maxMin = dayMinutes.fold<int>(1, ...)` — اگر کل هفته فقط ۵ دقیقه مطالعه باشد، `intensity = 5/5 = 1.0` و هیت‌مپ با رنگ کامل پر می‌شود — یعنی شدت رنگ هیچ معنای مطلقی ندارد.

**تصمیم قطعی:**
1. باکت‌بندی را بر اساس `CourseDate.toDayKey(DateTime.fromMillisecondsSinceEpoch(session.completedAt!))` انجام بده. جلسات `completedAt == null` را کنار بگذار (دیگر fallback به `updatedAt` نکن).
2. مدت را فقط از `actualDurationMinutes` بخوان؛ اگر null بود، جلسه را در شمارش جلسات بیاور ولی در دقیقه‌ها نه (و در tooltip ذکر کن).
3. مقیاس رنگ را مطلق کن: آستانه‌های ثابت بر اساس میانگین مدت جلسهٔ دوره‌های فعال (`۰`, `< ۱ جلسه`, `۱ جلسه`, `≥ ۲ جلسه`) با حداقل شدت ۰.۲ و حداکثر ۱.۰. یک راهنمای رنگ (legend) کوتاه زیر هیت‌مپ اضافه کن.
4. هر ستون باید `Semantics(label:)` و `Tooltip` داشته باشد: «شنبه ۱۴/۰۶/۱۴ — ۲ جلسه ، ۹۰ دقیقه».
5. پیش‌فرض‌های مدت (`30`, `45`) به یک ثابت واحد `CourseDefaults.sessionDurationMinutes = 45` در `course_models.dart` منتقل شوند.

### K-23 🟡 ستون `targetDurationMinutes` مرده است
**واقعیت فعلی:** جدول `course_active_timers` ستون `targetDurationMinutes INTEGER` دارد ولی `ActiveCourseTimer.toMap()` آن را نمی‌نویسد و `fromMap` نمی‌خواند. نتیجه: پس از ریستارت، هیچ کس نمی‌داند هدف زمانی این جلسه چقدر بوده؛ `FocusModeScreen` هدف را از `widget.session/course` بازمی‌سازد که در مسیر بازگشت از `FloatingTimerBar` کار می‌کند اما اگر دوره در فاصله ویرایش شده باشد، هدف عوض می‌شود.

**تصمیم قطعی:** ستون را حذف نکن؛ آن را در `startTimer` پر کن (`session.estimatedDurationMinutes ?? course.sessionDurationMinutes`)، در `toMap`/`fromMap` بیاور، و `FocusModeScreen` هدف را از تایمر بخواند نه از ویجت. این لازمهٔ حالت شمارش معکوس در `K-77` هم هست.

### K-24 🟠 شروع تایمر قبل از ورود به صفحهٔ تمرکز
**واقعیت فعلی:** `WhatToReadNowCard` اول `startTimer` می‌زند، بعد `Navigator.push` می‌کند، و بعد `onStartSession?.call()` که `_loadAllData()` است. اگر push شکست بخورد یا کاربر فوری back بزند، تایمر در حال اجراست و تنها نشانهٔ آن، نوار شناوری است که **فقط در صفحهٔ دوره‌ها** رندر می‌شود. علاوه بر آن، فراخوانی `_loadAllData()` در حین push باعث یک محاسبهٔ کامل موتور در میانهٔ انیمیشن مسیر می‌شود.

**تصمیم قطعی:** ترتیب را به این شکل دربیاور: `Navigator.push` → `FocusModeScreen.initState` خودش تایمر را شروع کند (با مدیریت تعارض `K-16`) → رفرش فقط پس از `await Navigator.push(...)` انجام شود. همچنین `FloatingTimerBar` باید در سطح ریشهٔ اپ (کنار نوار پایین/shell اصلی) میزبانی شود تا در همهٔ صفحات دیده شود؛ اگر تغییر shell خارج از دامنهٔ مجاز بود، دست‌کم آن را به `CourseDetailScreen` هم اضافه کن و این محدودیت را در گزارش فاز ۹ ثبت کن.

### K-25 🟠 تایمر بدون wakelock و بدون پشتیبانی نوتیفیکیشن
**واقعیت فعلی:** `FocusModeScreen` یک مود تمرکز عمیق است اما صفحه پس از تایم‌اوت سیستم خواب می‌رود، و هیچ نوتیفیکیشن دائمی/foreground وجود ندارد که نشان دهد تایمر در حال اجراست. دکمهٔ back بدون هیچ تأییدی صفحه را می‌بندد و تایمر بی‌صدا در پس‌زمینه می‌ماند.

**تصمیم قطعی:**
1. در `FocusModeScreen`، `WakelockPlus.enable()` در `initState` و `disable()` در `dispose` (اگر بستهٔ `wakelock_plus` در `pubspec.yaml` نیست، اضافه کن). اگر دسترسی به وابستگی جدید ممکن نبود، از همان مسیری که ماژول‌های دیگر (مثلاً ورزش/نماز) استفاده می‌کنند پیروی کن و این مورد را در گزارش بنویس.
2. دکمهٔ بستن باید `PopScope` داشته باشد و اگر تایمر در حال اجراست، بپرسد: «تایمر را در پس‌زمینه نگه دارم یا جلسه را ثبت کنم؟»
3. یک نوتیفیکیشن دائمی (ongoing) از طریق `NotificationGateway` با عنوان جلسه و زمان سپری‌شده نمایش بده که با `stopTimer` پاک می‌شود. از `NotificationChannelId` موجود مناسب استفاده کن؛ کانال جدید نساز.

### K-26 🟡 `fontFamily: 'Courier'` برای ارقام فارسی
**واقعیت فعلی:** در `FocusModeScreen` و `FloatingTimerBar`، متن تایمر با `fontFamily: 'Courier'` رندر می‌شود در حالی که محتوای متن ارقام فارسی (`۰۲:۳۴`) است. `Courier` یک فونت bundle‌شده نیست؛ رفتار fallback بین iOS/Android متفاوت است و ممکن است ارقام فارسی را اصلاً رندر نکند (tofu).

**تصمیم قطعی:** `fontFamily` را حذف کن و از `Theme.of(context).textTheme` با `fontFeatures: [FontFeature.tabularFigures()]` استفاده کن تا عرض ارقام ثابت بماند و تایمر نلرزد.

### K-27 🟡 `StudyTimerSheet` در تم روشن ناخوانا است
**واقعیت فعلی:** در `StudyTimerSheet`، عنوان جلسه با `color: Colors.white`، متن دیالوگ با `color: Colors.white`، و `TextField` با `style: TextStyle(color: Colors.white)` و `hintStyle: Colors.white.withValues(alpha: 0.4)` نوشته شده. در تم روشن، متن سفید روی glass card روشن = **نامرئی**. همین مشکل در `course_detail_screen` (دیالوگ حذف)، `ai_syllabus_sheet` (کل شیت)، و `create_course_sheet` (دیالوگ تغییر ریتم با `backgroundColor: Color(0xff1C1F2E)`) وجود دارد.

**تصمیم قطعی:** این مورد در فاز ۸ (`K-88`) به‌صورت سیستمی حل می‌شود، اما برای مسیر تایمر مهم است که **در همین فاز** حداقل `StudyTimerSheet`، `FocusModeScreen` و `SessionDebriefSheet` به `context.colors` منتقل شوند تا تست‌های این فاز در هر دو تم قابل اجرا باشند.

### گیت پذیرش فاز ۲
- بستن شیت بازخورد بدون ذخیره، مدت مطالعه را از بین نمی‌برد (تست ویجت).
- تایمری که ۳ روز رها مانده، به `STALE` می‌رود و هرگز `actualDurationMinutes = 480` نمی‌نویسد (تست واحد با `DateTime` تزریق‌شده).
- شروع تایمر جدید در حال وجود تایمر فعال، استثنا می‌دهد مگر `force: true`.
- همهٔ چهار مسیر تکمیل، دست‌کم `understandingScore` ثبت می‌کنند.
- `durationSource` در دیتابیس وجود دارد و درست پر می‌شود (تست مایگریشن + تست مخزن).
- هیت‌مپ روی `completedAt` باکت می‌کند (تست واحد: جلسهٔ برنامهٔ هفتهٔ گذشته که امروز تکمیل شده، روی امروز دیده می‌شود).
- `grep -rn "clamp(1, 480)\|Colors.white" lib/features/courses/presentation/widgets/study_timer_sheet.dart lib/features/courses/presentation/widgets/focus_mode_screen.dart` خالی است.

---

## فاز ۳ — یکپارچگی داده، مخزن و یادآورها

### K-28 🔴 دوره‌ای که همهٔ جلساتش رد شده، «تکمیل‌شده 🏆» اعلام می‌شود
**واقعیت فعلی:** در `completeSession` و `skipSession`:
```dart
final remainingPending = await txn.query('course_sessions',
    where: 'courseId = ? AND completionStatus = ?', whereArgs: [courseId, 'PENDING']);
if (remainingPending.isEmpty) {
  // دوره COMPLETED می‌شود و completedAt ست می‌شود
}
```
پرچم `allSkipped` محاسبه می‌شود و فقط در payload رویداد قرار می‌گیرد — ولی **وضعیت دیتابیس همان `COMPLETED` است**. پس دوره‌ای که کاربر همهٔ ۳۰ جلسه‌اش را رد کرده، در «تالار افتخارات» با نشان تکمیل و جشن نمایش داده می‌شود. این یک دروغ مستقیم به کاربر است و اعتماد به کل ماژول را از بین می‌برد.

**تصمیم قطعی:**
1. یک وضعیت جدید `'CLOSED'` به CHECK ستون `courses.status` اضافه کن (مایگریشن لازم است: SQLite اجازهٔ تغییر CHECK نمی‌دهد، پس الگوی موجود مخزن برای بازسازی جدول را پیدا کن؛ اگر الگویی وجود ندارد، **CHECK را دست نزن** و جایش از راه‌حل ۲ استفاده کن).
2. **راه‌حل جایگزین (ترجیحی اگر مایگریشن CHECK پرهزینه باشد):** وضعیت همان `COMPLETED` بماند، اما مفهوم «کیفیت پایان» در لایهٔ دامنه محاسبه شود: `CourseCompletionQuality { fullyCompleted, partiallySkipped, allSkipped }` بر اساس نسبت `COMPLETED` به `SKIPPED`.
3. `CompletedCoursesSection` باید سه نشان متفاوت نشان دهد: «تکمیل‌شده 🏆» / «تکمیل با X جلسهٔ ردشده» / «بسته‌شده بدون انجام» با رنگ‌های متفاوت.
4. در حالت `allSkipped` هیچ انیمیشن/جشنی نشان داده نشود.

### K-29 🔴 پیشرفت هدف متصل، مستقیم بازنویسی می‌شود و منابع دیگر را نابود می‌کند
**واقعیت فعلی:** در `completeSession` و `uncompleteSession`:
```dart
final ratio = totalSess > 0 ? (doneSess / totalSess) : 0.0;
await txn.update('goals', {'progressCache': ratio, 'updatedAt': nowMs},
    where: 'id = ?', whereArgs: [course.linkedGoalId]);
```
سه مشکل جدی:
1. مقدار `progressCache` مستقیم بازنویسی می‌شود. اگر یک هدف چند منبع پیشرفت داشته باشد (چند دوره، عادت، تسک)، **آخرین دوره‌ای که جلسه‌ای در آن تکمیل می‌شود، پیشرفت بقیه را پاک می‌کند**.
2. `GoalProgressCalculator` در مخزن وجود دارد (در `test/goals_test.dart` ایمپورت شده) و **دور زده شده**.
3. مقیاس مقدار (`0..1` یا `0..100`) هیچ‌جا تأیید نشده. علاوه بر این، `deleteCourse` هیچ پاکسازی‌ای انجام نمی‌ده؛ پس حذف دوره، یک مقدار پیشرفت مرده روی هدف جا می‌گذارد.

**تصمیم قطعی:**
1. `lib/features/goals/**` را بخوان و API محاسبهٔ رسمی پیشرفت را پیدا کن. مخزن دوره‌ها باید **فقط** به آن اطلاع دهد که «دادهٔ دوره تغییر کرد» و محاسبهٔ نهایی در لایهٔ goals انجام شود. اگر این API جریان معکوس ندارد، رویداد `RitmoEvent('CoursesChanged')` را مبنا بگیر و در لایهٔ goals مشتری بساز.
2. تا زمانی که مسیر رسمی وجود ندارد، حداقل این دو را اصلاح کن: (الف) مقدار فقط زمانی نوشته شود که هدف فقط همین یک دوره به آن متصل است (`SELECT COUNT(*) FROM courses WHERE linkedGoalId = ?`)؛ (ب) `deleteCourse` هم همان محاسبه را دوباره انجام دهد یا مقدار را صفر کند.
3. در `uncompleteSession` هم همین قرارداد دوطرفه رعایت شود (در حال حاضر کامنت می‌گوید دوطرفه است اما منطق یکسان نیست).

### K-30 🔴 شناسهٔ یادآور تکراری → یادآورهای بی‌صدا حذف‌شده
**واقعیت فعلی:** در `_rebuildRemindersForCourse`:
```dart
final nowMs = DateTime.now().millisecondsSinceEpoch;   // یک بار قبل از حلقه
for (final session in sessions) {
  final reminderId = 'rem_${nowMs}_${session.id.hashCode}';
  await txn.insert('pending_reminders', {...}, conflictAlgorithm: ConflictAlgorithm.replace);
}
```
چون `nowMs` ثابت است، یکتایی فقط به `session.id.hashCode` وابسته است و با `ConflictAlgorithm.replace` هر برخورد، یک یادآور را **بی‌صدا حذف** می‌کند. علاوه بر این، شناسه در هر rebuild عوض می‌شود، پس همان یادآور منطقی هر بار شناسهٔ جدیدی می‌گیرد و لغو کردن آلارم قدیمی غیرقابل‌اعتماد می‌شود.

**تصمیم قطعی:** شناسه باید **معین (deterministic)** باشد: `'rem_course_${session.id}'`. با این کار `ConflictAlgorithm.replace` درست عمل می‌کند (همان یادآور به‌روز می‌شود) و لغو آلارم قابل اعتماد می‌شود. همین قاعده برای `NotificationRequest.id` و `entityId` و `alarmId`.

**تأیید:** `grep -rn "\.hashCode" lib/features/courses` باید خالی باشد.

### K-31 🔴 هر تکمیل جلسه، تمام آلارم‌های تمام دوره‌ها را بازنویسی می‌کند
**واقعیت فعلی:** `syncCourseAlarms()` در پایان همهٔ این متدها صدا زده می‌شود: `createCourse`, `createCourseWithSessions`, `updateCourse`, `completeSession`, `uncompleteSession`, `skipSession`, `skipSessions`, `rescheduleSession`, `updateCourseStatus`, `deleteCourse`. خودِ `syncCourseAlarms` هم تمام یادآورهای آینده‌ی همهٔ دوره‌های فعال را دوباره زمان‌بندی می‌کند. پس تکمیل یک جلسه در یک دوره می‌تواند منجر به صدها فراخوانی پلتفرمی شود — فریز قابل دیدن UI.

دو مشکل مرتبط:
- **هیچ سقفی وجود ندارد.** یک دورهٔ ۵۰۰ جلسه‌ای با یادآور فعال، تا ۵۰۰ آلارم پلتفرمی می‌سازد (محدودیت واقعی اندروید/iOS را رد می‌کند).
- `uncompleteSession` مقدار بازگشتی `_rebuildRemindersForCourse` (لیست آلارم‌هایی که باید لغو شوند) را **دور می‌ریزد** — برخلاف بقیهٔ متدها که `alarmsToCancel` را جمع می‌کنند. پس آلارم‌های یتیم باقی می‌مانند و کاربر برای یادآوری که دیگر وجود ندارد نوتیفیکیشن می‌گیرد.

**تصمیم قطعی:** منطق یادآور را به یک فایل جداگانه `lib/features/courses/logic/course_reminder_planner.dart` منتقل کن با این قواعد:
1. **پنجرهٔ زمانی غلتان:** فقط یادآورهای ۱۴ روز آینده و حداکثر ۲۰ مورد برای هر دوره زمان‌بندی شوند.
2. **همگام‌سازی تفاضلی (diff):** وضع مطلوب را محاسبه کن، با وضع ثبت‌شده در `pending_reminders` مقایسه کن، و فقط تفاوت‌ها را زمان‌بندی/لغو کن. هیچ‌وقت تمام آلارم‌ها را بازنویسی نکن.
3. `syncCourseAlarms` فقط با `courseId` مشخص کار کند، نه برای همهٔ دوره‌ها. یک متد جداگانه `syncAllCourseAlarms()` فقط برای مسیر راه‌اندازی اپ و تغییر مجوز نوتیفیکیشن بماند.
4. `uncompleteSession` مقدار بازگشتی را حتماً مصرف کند.
5. متن نوتیفیکیشن به‌جای `'کلاس: $courseTitle'` خالی، عنوان دوره و body با عنوان/شمارهٔ جلسه داشته باشد و از `l10n` بیاید (فاز ۸).

### K-32 🟠 کاهش تعداد جلسات ممکن است تعداد اشتباهی جلسه حذف کند
**واقعیت فعلی:** در `updateCourse`، `existingSessions` **قبل از** شروع تراکنش خوانده می‌شود، و `countToRemove` از `existingCourse.totalSessions - updatedCourse.totalSessions` محاسبه می‌شود — نه از تعداد واقعی ردیف‌ها. مرحلهٔ دوم همان تابع، خودش اعتراف می‌کند که این دو مقدار می‌توانند واگرا شوند و `totalSessions` را با `COUNT(*)` بازنویسی می‌کند — یعنی **مقداری که کاربر وارد کرده، بی‌هیچ اطلاعی بازنویسی می‌شود**.

**تصمیم قطعی:**
1. خواندن `existingSessions` به **داخل تراکنش** منتقل شود.
2. `countToRemove` از تعداد واقعی ردیف‌ها محاسبه شود.
3. اگر در نهایت `COUNT(*)` با مقدار درخواستی کاربر یکی نبود (مثلاً چون جلسات تکمیل‌شده قابل حذف نیستند)، **باید قبل از ذخیره** با یک دیالوگ به کاربر گفته شود: «۵ جلسه قبلاً تکمیل یا رد شده‌اند و قابل حذف نیستند؛ تعداد کل حداقل ۵ خواهد بود.» (موجودیت خطای `CANNOT_SHRINK_BELOW_LOCKED` در `CourseValidator` را برای این کار به کار بگیر — این کد خطا در حال حاضر هیچ‌جا پرتاب نمی‌شود).

### K-33 🔴 تغییر `targetEndDate` هیچ تأثیری ندارد
**واقعیت فعلی:** `needsReschedule` (هم در مخزن و هم نسخهٔ تکراری‌اش در `CreateCourseSheet`) فقط `preferredDays`, `weeklyTargetSessions` و `totalSessions` را مقایسه می‌کند و `targetEndDate` را نادیده می‌گیرد. پس پلن «تمدید» در `RecoveryModeSheet` که فقط `targetEndDate` را می‌نویسد، **هیچ تغییری در برنامه ایجاد نمی‌کند** و کاربر می‌بیند که دکمه را زده و هیچ اتفاقی نیفتاده.

**تصمیم قطعی:**
1. `targetEndDate` را به شرط‌های `needsReschedule` اضافه کن.
2. `CourseScheduler.distributeSessions` یک پارامتر اختیاری `DateTime? targetEndDate` بگیرد. اگر داده شد، هدف هفتگی موردنیاز را از تعداد جلسات باقی‌مانده تقسیم بر تعداد هفته‌های باقی‌مانده محاسبه کن و اگر از تعداد روزهای ترجیحی بیشتر بود، خطای `TARGET_END_UNREACHABLE` بده تا UI بتواند بگوید چند روز در هفته لازم است.
3. پلن «تمدید» باید واقعاً جلسات باقی‌مانده را توزیع مجدد کند (`K-63`).

### K-34 🟠 توزیع مجدد، سیگنال عقب‌ماندگی را پاک می‌کند
**واقعیت فعلی:** مرحلهٔ ۳ `updateCourse` تمام جلسات PENDINGِ `!isUserScheduled` را **از امروز** دوباره توزیع می‌کند. یعنی کاربری که ۱۵ جلسه عقب افتاده، اگر فقط عنوان دوره را ویرایش کند و در کنارش یکی از فیلدهای زمان‌بندی را لمس کند، **عقب‌ماندگی‌اش صفر می‌شود** و موتور تطبیقی (`overdueCount >= 6`) هرگز تریگر نمی‌شود. تاریخچهٔ واقعی برنامه هم پاک می‌شود (`scheduleAdherence` بی‌معنا می‌شود).

**تصمیم قطعی:**
1. جلسات PENDING با `plannedDate < today` دیگر در توزیع مجدد به آینده منتقل نشوند **مگر کاربر صریحاً درخواست کند**. در دیالوگ تأیید بازتوزیع، یک چک‌باکس اضافه کن: «جلسات عقب‌افتاده هم به آینده منتقل شوند» (پیش‌فرض: خاموش).
2. دیالوگ تأیید بازتوزیع باید **دقیقاً بگوید چند جلسه جابه‌جا می‌شود و تاریخ پایان جدید چه می‌شود** (امروز فقط متن کلی دارد).
3. منطق `needsReschedule` فقط در مخزن باشد؛ نسخهٔ تکراری در `CreateCourseSheet` حذف و از همان متد مخزن استفاده شود (کامنت خود کد هم می‌گوید «باید با مخزن هماهنگ بماند» — این پذیرفتنی نیست).

### K-35 🟠 فقدان تکه‌بندی در `IN (...)` — سقف ۹۹۹ پارامتر SQLite
**واقعیت فعلی:** `getSessionsForCourses(List<String> courseIds)` یک `IN (${placeholders})` می‌سازد بدون هیچ تکه‌بندی. `CoursesScreen._loadAllData` این را با شناسهٔ همهٔ دوره‌ها صدا می‌زند. با بیش از ۹۹۹ دوره، کوئری خطا می‌دهد (سناریوی دور اما کد باید مقاوم باشد).

**تصمیم قطعی:** یک helper خصوصی `_chunked<T>(List<T>, int size)` در مخزن بساز با سایز `500` و نتایج را ادغام کن. روی هر جایی که `IN (...)` هست اعمال کن.

### K-36 🟠 کوئری بازهٔ تاریخی، جلسات دوره‌های غیرفعال را هم می‌آورد
**واقعیت فعلی:** `getSessionsForDateRange` فقط روی `plannedDate` فیلتر می‌کند و هیچ join/فیلتری روی وضعیت دوره ندارد. `CourseAgendaSource.load` هم همین کار را می‌کند و سپس در Dart فیلتر می‌کند. یعنی دوره‌های PAUSED / COMPLETED / آرشیوی هم از دیتابیس کشیده می‌شوند.

**تصمیم قطعی:** امضا را به `getSessionsForDateRange({required String startDate, required String endDate, List<String>? courseIds, bool activeCoursesOnly = false})` تغییر بده و فیلتر را در SQL اعمال کن (`INNER JOIN courses`). یک ایندکس جدید هم لازم است (`K-37`).

### K-37 🟡 ایندکس گمشده برای پرتکرارترین کوئری ماژول
**واقعیت فعلی:** ایندکس‌های موجود: `idx_course_sessions_planned(plannedDate, completionStatus)`, `idx_course_sessions_course_status(courseId, completionStatus)`, `idx_course_sessions_completedAt(completedAt)`. اما پرتکرارترین کوئری کل ماژول `WHERE courseId = ? ORDER BY displayOrder, sessionNumber` است (صفحهٔ جزئیات، مسیر توزیع مجدد، مسیر یادآور) و هیچ ایندکسی آن را پوشش نمی‌دهد.

**تصمیم قطعی:** دو ایندکس با مایگریشن اضافه کن:
```sql
CREATE INDEX IF NOT EXISTS idx_course_sessions_course_order ON course_sessions(courseId, displayOrder, sessionNumber);
CREATE INDEX IF NOT EXISTS idx_course_sessions_course_planned ON course_sessions(courseId, plannedDate);
```
و در `CourseTables.create` هم بیاور تا دیتابیس‌های جدید هم داشته باشند. در `test/migration_test.dart` الگوی موجود تست مایگریشن را دنبال کن و این‌ها را هم تست کن.

### K-38 🟠 محدودیت‌های عددی: چهار منبع حقیقت متفاوت
**واقعیت فعلی:**

| مقدار | `CourseValidator` | DB CHECK | UI (`CreateCourseSheet`) | موتورها | AI helper |
|---|---|---|---|---|---|
| `weeklyTargetSessions` | ۱..۲۱ | ۱..۲۱ | ۱..**۱۴** | `clamp(1, 14)` | ۱..۲۱ |
| `sessionDurationMinutes` | ۱..۶۰۰ | ۱..۶۰۰ | `clamp(5, 480)` | — | ۵..۳۰۰ |
| `totalSessions` | ۱..۵۰۰ | `> 0` (بی‌سقف) | — | — | ۱..۱۰۰ |

نتیجهٔ عملی: کاربر می‌تواند مدت `600` دقیقه تایپ کند، پیام خطایی نبیند، و مقدار `480` ذخیره شود. و کاربری که هدف هفتگی را در UI تا ۱۴ می‌برد، هرگز نمی‌داند موتور تطبیقی می‌تواند آن را تا ۱۴ ببرد ولی DB تا ۲۱ مجاز می‌داند.

**تصمیم قطعی:** یک منبع حقیقت واحد در `course_models.dart`:
```dart
abstract final class CourseLimits {
  static const int minTotalSessions = 1;
  static const int maxTotalSessions = 500;
  static const int minSessionDurationMinutes = 5;
  static const int maxSessionDurationMinutes = 600;
  static const int minWeeklyTarget = 1;
  static const int maxWeeklyTarget = 21;
  static const int maxScheduleHorizonDays = 730;
  static const int maxTimerSeconds = 28800;
}
```
همهٔ موارد بالا (validator، UI، موتورها، AI helper) فقط از این ثابت‌ها استفاده کنند. حداقل مدت را روی `5` ثابت کن (مقدار ۱ دقیقه بی‌معنا است). اگر دادهٔ قدیمی خارج از محدوده وجود دارد، در خواندن clamp نکن — فقط در نوشتن. **تغییر CHECK دیتابیس لازم نیست.**

### K-39 🔴 `fromMap` با cast بدون محافظت → کرش در خواندن ردیف قدیمی
**واقعیت فعلی:** `Course.fromMap` و `CourseSession.fromMap` از cast مستقیم استفاده می‌کنند:
```dart
totalSessions: map['totalSessions'] as int,
createdAt: map['createdAt'] as int,
sessionNumber: map['sessionNumber'] as int,
```
هر ردیفی که از مایگریشن ناقص یا واردات snapshot مقدار NULL یا `double` داشته باشد، کل صفحه را با `TypeError` می‌شکند — و چون `CoursesScreen` خطا را می‌خورد (`K-70`)، کاربر می‌بیند که **همهٔ دوره‌هایش ناپدید شده‌اند**.

مشکل دوم: `preferredDays` از CSV خوانده می‌شود ولی برخلاف `CourseScheduler.normalizePreferredDays`، محدوده و تکرار کنترل نمی‌شود؛ یک مقدار خراب `'9,9,-1'` درست در حافطه می‌نشیند.

**تصمیم قطعی:**
1. دو helper خصوصی در همان فایل: `int _int(Object? v, {int fallback = 0})` و `String _str(Object? v, {String fallback = ''})` که `num` و `String` و `null` را امن می‌خوانند. همهٔ cast‌های مستقیم جایگزین شوند.
2. `id` و `courseId` و `title` اگر خالی بودند، **خطای صریح** بده (این‌ها فاقد fallback معنادارند) و ردیف را در لاگ با شناسه (بدون محتوای کاربر) ثبت کن.
3. `preferredDays` از همان منطق نرمال‌سازی عبور کند (فیلتر ۰..۶ + حذف تکرار + مرتب‌سازی)، **اما بدون جایگزینی پیش‌فرض** (رجوع به `K-47`).
4. `CoursesDataDoctor.diagnose(db)` بساز (یک تابع ساده در مخزن) که ردیف‌های نامعتبر را برمی‌شمارد: `plannedDate` با فرمت نامعتبر، `sessionNumber` تکراری، `courseId` یتیم، `energyRule` نامعتبر، `completionStatus = 'COMPLETED'` با `completedAt = NULL`. خروجی فقط در لاگ و در یک تست.

### K-40 🟡 `CourseTypeExtension.name` نام درون‌ساخت enum را پوشانده است
**واقعیت فعلی:** `extension CourseTypeExtension on CourseType { String get name => ... }` مقدار `'VIDEO'` برمی‌گرداند، در حالی که Dart خودش `CourseType.video.name == 'video'` دارد. هر توسعه‌دهنده‌ای که `.name` بنویسد، مقدار غیرمنتطره می‌گیرد — و بدتر، اگر extension ایمپورت نشود، مقدار متفاوتی می‌گیرد. این یک بمب ساعتی برای ذخیره‌سازی است.

**تصمیم قطعی:** به `String get dbValue` تغییر نام بده (همان قالبی که `CourseActivityKind` درست انجام داده) و همهٔ فراخوانی‌ها را به‌روز کن. یک تست round-trip برای هر چهار مقدار `CourseType` بنویس (در `test/courses/course_models_test.dart` که الان هم وجود دارد).

### K-41 🟠 `copyWith` نمی‌تواند فیلدها را خالی کند — و UI به اشتباه تلاش می‌کند
**واقعیت فعلی:** `Course.copyWith` الگوی زیر را فقط برای برخی فیلدها دارد:
```dart
preferredTime: preferredTimeSet ? preferredTime : (preferredTime ?? this.preferredTime),
```
فیلدهای `emoji`, `colorHex`, `unitLabel`, `provider`, `zoneId`, `linkedGoalId`, `targetEndDate` **هیچ پرچم `...Set` ندارند**، پس `copyWith(provider: null)` به معنای «دست نزن» تفسیر می‌شود. و `CreateCourseSheet._saveCourse` دقیقاً این کار را می‌کند:
```dart
provider: _providerController.text.trim().isEmpty ? null : ...,
unitLabel: _unitLabelController.text.trim().isEmpty ? null : ...,
```
کاربری که فیلد «مدرس/پلتفرم» را پاک می‌کند و ذخیره می‌زند، **مقدار قبلی را دوباره می‌بیند** بی‌هیچ توضیحی.

**تصمیم قطعی:** الگوی `sentinel` را برای همهٔ فیلدهای nullable اعمال کن:
```dart
const Object _unset = Object();
// در امضا: Object? provider = _unset
// در بدنه: provider: provider == _unset ? this.provider : provider as String?
```
پرچم‌های `...Set` موجود حذف شوند. همین کار برای `CourseSession.copyWith` (که مشکل مشابه برای `plannedDate`, `note`, `keyTakeaway`, `skipReason` دارد). تست: برای هر فیلد nullable یک تست «خالی کردن» و یک تست «دست نزدن».

### K-42 🟡 `activityType` یک رشتهٔ آزاد با صفر مصرف‌کننده
**واقعیت فعلی:** `courses.activityType TEXT NOT NULL` بدون پیش‌فرض SQL و بدون CHECK؛ مدل مقدار `'STUDY'` را پیش‌فرض می‌گذارد؛ **هیچ کدی در کل مخزن این فیلد را نمی‌خواند**. یک ستون مرده و یک بدهی فنی.

**تصمیم قطعی:** ستون را حذف نکن (مایگریشن پرهزینه است). اما: (الف) در `course_models.dart` یک کامنت واضح `// Reserved. Always 'STUDY'.` بگذار؛ (ب) مقدار را به یک ثابت `CourseDefaults.activityType` منتقل کن؛ (ج) در `docs/DB_TECH_DEBT.md` یک ردیف اضافه کن. **این تنها استثنای مجاز برای نوشتن در یک فایل markdown موجود است.**

### گیت پذیرش فاز ۳
- دوره‌ای با همهٔ جلسات ردشده، نشان «تکمیل 🏆» نمی‌گیرد (تست ویجت).
- دو دورهٔ متصل به یک هدف، پیشرفت همدیگر را پاک نمی‌کنند (تست مخزن).
- تکمیل یک جلسه در حضور ۵ دورهٔ فعال، فقط آلارم‌های همان دوره را لمس می‌کند (تست با fake gateway که فراخوانی‌ها را می‌شمارد).
- هیچ دوره‌ای بیش از ۲۰ آلارم ثبت‌شده ندارد.
- `grep -rn "\.hashCode" lib/features/courses` خالی.
- `CourseLimits` تنها منبع محدودیت‌هاست؛ `grep -rn "clamp(1, 14)\|clamp(5, 480)\|1, 500\|1, 600" lib/features/courses` خالی.
- خواندن ردیف دوره با `totalSessions = NULL` کرش نمی‌کند (تست واحد).

---

## فاز ۴ — زمان‌بندی و موتور تحلیل

### K-43 🔴 هدف هفتگی کاربر بی‌صدا به تعداد روزهای ترجیحی تقلیل می‌شود
**واقعیت فعلی:** در `CourseScheduler.distributeSessions`:
```dart
final normalizedDays = normalizePreferredDays(preferredDays);
final effectiveWeeklyTarget = normalizedDays.isNotEmpty
    ? (weeklyTarget > normalizedDays.length ? normalizedDays.length : weeklyTarget)
    : weeklyTarget;
```
الگوریتم در هر روز ترجیحی حداکثر **یک** جلسه می‌گذارد. پس اگر کاربر روزهای شنبه/دوشنبه/چهارشنبه (۳ روز) را انتخاب کند اما هدف هفتگی را `5` بگذارد:
- در دیتابیس `weeklyTargetSessions = 5` ذخیره می‌شود؛
- ولی زمان‌بندی واقعی ۳ جلسه در هفته می‌شود؛
- و `CoursesWeeklyHero` در مخرج عدد `5` را نشان می‌دهد؛
- پس **نوار پیشرفت هفتگی منطقاً هرگز به ۱۰۰٪ نمی‌رسد** و کاربر هر هفته حس شکست می‌کند. هیچ پیامی در هیچ جای UI این تقلیل را اعلام نمی‌کند.

علاوه بر آن، شاخهٔ `else` (یعنی `normalizedDays.isEmpty`) **مرده است**، چون `normalizePreferredDays` در حالت خالی مقدار `[6, 1, 3]` برمی‌گرداند و هرگز لیست خالی نمی‌دهد.

**تصمیم قطعی:** اجازهٔ **چند جلسه در یک روز** را پیاده کن:
1. `distributeSessions` دیگر هدف را تقلیل ندهد. جلسات هر هفته را روی روزهای ترجیحی **round-robin** توزیع کن؛ اگر `weeklyTarget > days.length`، روزهای اول دو جلسه می‌گیرند.
2. سقف منطقی `CourseLimits.maxSessionsPerDay = 3` بگذار. اگر هدف هفتگی از `days.length * 3` بیشتر بود، `CourseValidationException('WEEKLY_TARGET_EXCEEDS_DAYS')` بده.
3. در `CreateCourseSheet` یک متن کمکی پویا زیر استپر هدف هفتگی: «۳ روز انتخاب شده → با هدف ۵، دو روز دو جلسه‌ای می‌شوند» — یا در حالت غیرممکن، خطای inline قبل از دکمهٔ ذخیره.

### K-44 🔴 مخرج و صورت نوار پیشرفت هفتگی از دو جمعیت متفاوت می‌آیند
**واقعیت فعلی:** در `CoursesEngine.calculate`:
- `weeklyTargetSessions` = جمع `weeklyTargetSessions` فقط دوره‌های **ACTIVE**.
- `weeklyDoneSessions` = شمارش جلسات تکمیل‌شدهٔ این هفته در **همهٔ دوره‌ها** (شامل COMPLETED و PAUSED).

پس وقتی کاربر آخرین جلسهٔ یک دوره را تمام می‌کند، دوره COMPLETED می‌شود → هدفش از **مخرج** حذف می‌شود ولی تکمیلش در **صورت** می‌ماند. نتیجه: نسبت می‌تواند از ۱۰۰٪ رد شود و با یک جهش ناگهانی عوض شود (مثلاً از `4/6` به `5/3`). تست موجود `test/courses_engine_test.dart` دقیقاً این را به‌عنوان رفتار مطلوب کدگذاری کرده (`expect(output.weeklyDoneSessions, equals(3))` با کامنت «despite course being COMPLETED») — این تست **اشتباه است و باید اصلاح شود** (`K-107`).

**تصمیم قطعی:**
1. یک جمعیت واحد تعریف کن: دوره‌هایی که **در این هفته فعال بوده‌اند** = `status == 'ACTIVE'` یا (`status == 'COMPLETED'` و `completedAt >= startOfWeek`). هم صورت و هم مخرج از همین مجموعه بیایند.
2. دوره‌های PAUSED در هیچ‌کدام نیایند (مگر در همان هفته جلسه‌ای تکمیل شده که در این صورت باید هدفش هم بشمارد).
3. نسبت در UI با `.clamp(0.0, 1.0)` محافظت شود و اگر صورت > مخرج بود، متن «فراتر از هدف» نشان داده شود، نه عدد بی‌معنا.

### K-45 🔴 `CoursesEngine.invalidate()` خالی است و اثر‌انگشت دوره را پوشش نمی‌دهد
**واقعیت فعلی:**
```dart
@override
void invalidate() {}
```
و اثر‌انگشت:
```dart
'$dayStamp|${courses.length}|${sessions.length}|$completedCount|$skippedCount|$maxUpdated|$currentEnergyLevel'
```
`maxUpdated` فقط از `sessions` می‌آید. پس تغییر `weeklyTargetSessions`، `preferredDays`، `status`، `title` یا `targetEndDate` یک دوره **اثر‌انگشت را تغییر نمی‌دهد** و تا ۵ دقیقه خروجی کش‌شدهٔ قدیمی برمی‌گردد. همزمان، `invalidate()` خالی بودنش معنیش این است که هر فراخوانی روی `RitmoEngineBus` بی‌اثر است.

**مشکل موازی و مهم‌تر:** `CoursesScreen._loadAllData` در **هر فراخوانی** یک موتور تازه می‌سازد:
```dart
final engine = CoursesEngine();
final output = await engine.calculate(input);
```
پس کل ماشین‌آلات کش (`ttl`، `fingerprint`، `canRun`) **هرگز استفاده نمی‌شود**. یعنی در عین حال که کش خراب است، بی‌استفاده هم هست.

**تصمیم قطعی:**
1. `invalidate()` را واقعاً پیاده کن (پاک‌کردن خروجی کش‌شده و اثر‌انگشت).
2. اثر‌انگشت باید `max(courses.updatedAt)` را هم شامل شود.
3. دسترسی به موتور باید از مسیر رسمی `RitmoEngineBus` باشد (الگوی موتورهای دیگر را بخوان و دقیقاً تقلید کن). هرگز `CoursesEngine()` در لایهٔ ویجت ساخته نشود.
4. پس از هر جهش مخزن، `invalidate()` فراخوانی شود (از طریق مشتری `RitmoEventBus` برای `CoursesChanged`).

### K-46 🟠 `canRun` برای کاربر جدید false است
**واقعیت فعلی:** `bool canRun(CoursesEngineInput input) => input.courses.isNotEmpty;` — پس برای کاربر بدون دوره، موتور هیچ خروجی نمی‌دهد. مصرف‌کننده‌های بالادستی (داشبورد/Journey) باید با `null` کنار بیایند — و چون `CoursesScreen` مستقیم `calculate` را صدا می‌زند و `canRun` را نمی‌پرسد، دو مسیر رفتار متفاوتی دارند.

**تصمیم قطعی:** موتور باید با لیست خالی هم کار کند و خروجی صفرِ معتبر بدهد (همهٔ مقادیر صفر، لیست‌ها خالی). `canRun` فقط وقتی false بدهد که ماژول دوره‌ها خاموش است (`ModuleGate`).

### K-47 🟠 جایگزینی پیش‌فرض روزها، حالت «روزی انتخاب نشده» را پنهان می‌کند
**واقعیت فعلی:** `normalizePreferredDays([])` مقدار `[6, 1, 3]` می‌دهد. پس کاربری که همهٔ روزها را از حالت انتخاب درمی‌آورد، بدون هیچ پیامی برنامهٔ شنبه/دوشنبه/چهارشنبه تحویل می‌گیرد. `CreateCourseSheet` هیچ اعتبارسنجی‌ای روی این ندارد.

**تصمیم قطعی:** `normalizePreferredDays` دیگر جایگزینی نکند و لیست خالی را همان طور برگرداند. `distributeSessions` در مواجهه با لیست خالی، `CourseValidationException('NO_PREFERRED_DAYS')` بدهد. `CourseValidator.validateCourse` هم این را چک کند. `CreateCourseSheet` دکمهٔ ذخیره را غیرفعال کند و زیر ردیف روزها خطای inline نشان دهد. پیش‌فرض `[6, 1, 3]` فقط به‌عنوان **مقدار اولیهٔ فرم ساخت دوره** باقی بماند، نه در لایهٔ منطق.

### K-48 🟠 `blockedDates` یک پارامتر مرده با مقایسهٔ نادرست کلید
**واقعیت فعلی:** `distributeSessions` پارامتر `Set<DateTime>? blockedDates` دارد که **هیچ فراخوانی‌کننده‌ای آن را پاس نمی‌دهد**. علاوه بر آن، مقایسه روی `DateTime` خام انجام می‌شود؛ هر اختلاف در جزء زمان، مقایسه را بی‌اثر می‌کند.

**تصمیم قطعی:** پارامتر را به `Set<String> blockedDayKeys` تغییر بده (کلید `CourseDate.toDayKey`) و واقعاً از آن استفاده کن: در `createCourse`/`updateCourse` روزهایی که کاربر جلسهٔ `isUserScheduled` دارد را پاس بده تا دو جلسه روی هم نیفتند. اگر تصمیم گرفتی هنوز کاربردی ندارد، **پارامتر را حذف کن** — اما رها نگذار.

### K-49 🟠 `SCHEDULE_INCOMPLETE` در دو جای مختلف به دو روش مدیریت می‌شود
**واقعیت فعلی:** `distributeSessions` پس از `maxDaysLimit = 730` روز `CourseValidationException('SCHEDULE_INCOMPLETE')` می‌دهد. اما:
- در `createCourse` این در **داخل تراکنش** پرتاب می‌شود (rollback + توست).
- در `estimatedEndDate` با `catch (_) { return null; }` خورده می‌شود و UI «مشخص نیست» نشان می‌دهد بی‌هیچ دلیلی.
- در `CourseCatchupEngine.generateCatchupPlan` بدون محافظت فراخوانی می‌شود.

عملاً یک دورهٔ ۵۰۰ جلسه‌ای با یک روز در هفته (که مطابق validator مجاز است) **قابل ساخت نیست** و کاربر فقط یک توست مبهم می‌گیرد.

**تصمیم قطعی:**
1. اعتبارسنجی را **پیش‌از‌ذخیره** انجام بده: در `CourseValidator` یک قاعدهٔ جدید اضافه کن که بررسی کند `totalSessions / (weeklyTarget)` در افق `maxScheduleHorizonDays` جا می‌شود یا نه، و خطای inline با پیشنهاد عدد («با ۱ جلسه در هفته، ۵۰۰ جلسه حدود ۱۰ سال طول می‌کشد؛ حداقل ۵ جلسه در هفته لازم است») بده.
2. `estimatedEndDate` دیگر خطا را نخورد؛ یک `sealed`/`Result` برگرداند یا خطا را پرتاب کند تا UI بتواند دلیل را نشان دهد.
3. `distributeSessions` را خارج از تراکنش دیتابیس فراخوانی کن (محاسبهٔ خالص است و دلیلی ندارد داخل تراکنش باشد) تا خطا باعث rollback نشود و پیام دقیق قابل ارائه باشد.

### K-50 🟠 `daysBehind` جلسه می‌شمارد ولی روز نامیده می‌شود
**واقعیت فعلی:** `CourseScheduler.daysBehind(...)` تعداد جلسات PENDING با `plannedDate < today` را برمی‌گرداند. در `CoursesEngineOutput` فیلد `behindSchedule` با کامنت «courseId -> days behind» توصیف شده، ولی `ActiveCoursesSection` درست می‌نویسد `'$behindCount جلسه عقب'`. در `CatchupPlan` همان مقدار `overdueSessionsCount` نام دارد. سه نام برای یک مفهوم.

**تصمیم قطعی:** نام واحد `overdueSessionsCount` در همهٔ لایه‌ها. `CoursesEngineOutput.behindSchedule` به `overdueSessionsByCourse` تغییر نام دهد. `ActiveCoursesSection` دیگر خودش محاسبه نکند و این مقدار را از موتور بگیرد (در حال حاضر `DateTime.now()` را داخل `itemBuilder` صدا می‌زند — غیرقابل تست و به‌علاوه در نیمه‌شب به‌روز نمی‌شود).

### K-51 🟠 `scheduleAdherence` در دورهٔ تازه، ۱۰۰٪ می‌دهد و رد کردن جلسه را تنبیه می‌کند
**واقعیت فعلی:** مخرج = جلساتی که `plannedDate <= today` دارند (شامل SKIPPED)؛ و اگر مخرج صفر بود، مقدار `1.0` برمی‌گردد. دو خروجی غلط:
1. دوره‌ای که هنوز شروع نشده، «۱۰۰٪ منطبق بر برنامه» است.
2. رد کردن جلسه یک اقدام مجاز و مدیریت‌شده است (حتی `skipReason` دارد) اما به‌طور دائمی انطباق را پایین می‌آورد.

**تصمیم قطعی:** مقدار باید `double?` باشد و در نبود داده، `null` بدهد (UI «هنوز دادهٔ کافی نیست» نشان دهد). جلسات SKIPPED از مخرج حذف شوند و در عوض یک متریک جداگانهٔ `skipRate` اضافه شود. حداقل نمونه: `5` جلسه.

### K-52 🟠 `masteryByCourse` سه مقیاس ناسازگار را در یک عدد جمع می‌کند
**واقعیت فعلی:** منطق به ترتیب: (۱) اگر `course.masteryScore > 0` همان؛ (۲) وگرنه میانگین `understandingScore` ضربدر ۲۰؛ (۳) وگرنه `completionRate * 100`.
- شاخهٔ (۱) **مرده است** — `masteryScore` را هیچ کدی نمی‌نویسد.
- شاخهٔ (۳) **پیشرفت را مانند تسلط برچسب می‌زند** — کاربری که ۸۰٪ جلسات را گذرانده ولی هیچ چیز نفهمیده، «تسلط ۸۰» می‌گیرد.

**تصمیم قطعی:** یک فایل جدید `lib/features/courses/logic/course_metrics.dart` بساز که همهٔ متریک‌ها را با **تعریف مکتوب و نوع بازگشتی نال‌پذیر** محاسبه کند:
```dart
class CourseMetric<T> { final T? value; final int sampleSize; final String reasonCode; }
```
- `mastery` **فقط** از میانگین `understandingScore` محاسبه شود و اگر کمتر از ۳ نمونه بود، `null` باشد. `completionRate` هرگز به‌عنوان تسلط ارائه نشود.
- `masteryScore` در جدول `courses` در هر تکمیل جلسه با همین مقدار به‌روز شود تا دیگر مرده نباشد (یا در `K-64` تصمیم حذف گرفته شود — هر دو قابل قبول، اما **انتخاب را در گزارش بنویس**).

### K-53 🟠 سه فرمول مختلف برای پیشرفت یک دوره
**واقعیت فعلی:**
- `CoursesEngine.completionRate`: مخرج = جلسات `activityKind != review` (یا `totalSessions` اگر خالی)
- `ActiveCoursesSection`: `completedCount / course.totalSessions`
- `CourseDetailScreen`: `completedCount / _course.totalSessions`
- `CourseRegistrySource`: `doneCount >= totalSessions`
- `SegmentedVisualJourneyTrack`: بر اساس طول لیست جلسات

پنج منبع حقیقت. و در همهٔ آن‌ها جلسات SKIPPED در مخرج می‌مانند ولی هرگز در صورت نمی‌آیند؛ پس دوره‌ای که با ردِ چند جلسه تمام شده و وضعیتش COMPLETED است، پیشرفتش مثلاً ۸۵٪ نشان داده می‌شود — متناقض با نشان «تکمیل‌شده».

**تصمیم قطعی:** در `course_metrics.dart` دو مفهوم جدا تعریف کن و همهٔ مصرف‌کننده‌ها را به آن‌ها وصل کن:
- `settledRate = (completed + skipped) / total` — «چند درصد مسیر طی شده» (مبنای نوار پیشرفت و وضعیت تکمیل)
- `completionRate = completed / total` — «چند درصد واقعاً انجام شد» (مبنای متریک‌های کیفی)

نوار پیشرفت دوره باید **دورنگ** باشد: بخش انجام‌شده + بخش ردشده (رنگ خاموش)، تا کاربر حقیقت را ببیند.

### K-54 🟠 `requiredWeeklyPace` یک روز خطا دارد و در حالت تاریخ گذشته حذف می‌شود
**واقعیت فعلی:** `targetDt.difference(input.today).inDays` — `input.today` جزء زمان دارد و `targetDt` نیمه‌شب است، پس `inDays` یک روز کمتر می‌شود. و اگر `daysLeft <= 0`، کلید در مپ قرار **نمی‌گیرد** — پس UI نمی‌تواند «مهلت تمام شده» را از «تاریخ هدف تعیین نشده» تمیز دهد.

**تصمیم قطعی:** از `CourseDate.daysBetween` استفاده کن. و نوع بازگشتی را صریح کن: `CoursePace { onTrack, behind(requiredPerWeek), deadlinePassed, noTarget }`.

### K-55 🟠 استریک مطالعه می‌تواند باز باشد در حالی که امروز هیچ مطالعه‌ای نبوده
**واقعیت فعلی:** `studyStreakDays` اجازه می‌دهد استریک از دیروز شروع شود (رفتار درستی است) اما UI فقط عدد را با 🔥 نشان می‌دهد. کاربر «۷ روز استریک» می‌بیند و فکر می‌کند امروز را هم ثبت کرده. علاوه بر آن fallback به `updatedAt` در نبود `completedAt`، با هر ویرایش بعدی یک جلسه را به روز دیگری جابه‌جا می‌کند.

**تصمیم قطعی:**
1. fallback به `updatedAt` حذف شود. جلسات COMPLETED با `completedAt == null` در `CoursesDataDoctor` گزارش شوند و یک مایگریشن داده `UPDATE course_sessions SET completedAt = updatedAt WHERE completionStatus = 'COMPLETED' AND completedAt IS NULL` انجام شود.
2. خروجی موتور باید `StudyStreak { days, includesToday }` باشد و UI در حالت `!includesToday` برچسب «تا دیروز» و رنگ خاموش‌تر نشان دهد.

### K-56 🔴 خروجی‌های موتور که محاسبه می‌شوند و هرگز دیده نمی‌شوند
**واقعیت فعلی:** `CoursesEngineOutput` چهارده فیلد دارد و `CoursesScreen` فقط پنج تا را مصرف می‌کند. این‌ها در هر بارگذاری محاسبه می‌شوند و هرگز دیده نمی‌شوند: `completionRate`، `scheduleAdherence`، `estimationAccuracy`، `requiredWeeklyPace`، `masteryByCourse`، `estimatedEnd`، `behindSchedule`، `estimatedMinutesIncluded`.

**این بزرگ‌ترین فرصت UX این ماژول است:** اپ الان می‌داند کاربر چقدر بر برنامه منطبق است، تخمین مدتش چقدر دقیق است، چه سرعتی برای رسیدن به تاریخ هدف لازم است، و چه تاریخی تمام می‌شود — و هیچ‌کدام را نمی‌گوید.

**تصمیم قطعی:** در فاز ۷ یک ویجت جدید `course_insights_section.dart` ساخته می‌شود که همهٔ این‌ها را نمایش می‌دهد (`K-76`). در این فاز فقط مطمئن شو هر متریک یک نوع بازگشتی قابل ارائه دارد (`CourseMetric<T>` با `sampleSize` و `reasonCode`) تا UI بتواند حالت‌های «دادهٔ کافی نیست» را صادقانه نشان دهد. متریکی که قرار نیست نمایش داده شود، **نباید محاسبه شود**.

### K-57 🟡 `CourseAgendaSource` کل موتور را دور می‌زند و دوباره محاسبه می‌کند
**واقعیت فعلی:** `CourseAgendaSource` مستقیماً به مخزن می‌زند، خودش مدت را با `?? 30` حدس می‌زند (در حالی که موتور `?? 45` می‌زند)، و عنوان فارسی `'جلسه ${s.sessionNumber}'` را **داخل `lib/core/`** هاردکد کرده. پارامتر `priority: 1.5` یک عدد جادویی بی‌توضیح است. و `meta: {'session': s.toMap()}` **کل ردیف جلسه را شامل یادداشت، برداشت و پرسش باز کاربر** داخل payload مشترک اجندا می‌ریزد — مسئلهٔ حجم و محرمانگی.

**تصمیم قطعی:**
1. `meta` فقط کلیدهای لازم را حمل کند: `sessionId`, `courseId`, `sessionNumber`, `activityKind`, `estimatedDurationMinutes`. هیچ محتوای کاربری در `meta` قرار نگیرد.
2. مدت از `CourseDefaults.sessionDurationMinutes` بیاید، نه `30`.
3. عنوان فال‌بک باید از `l10n` بیاید (فاز ۸). تا آن زمان، یک تابع تزریق‌پذیر بگیر و رشتهٔ هاردکد را از `lib/core/` خارج کن.
4. `priority: 1.5` به یک ثابت نام‌دار با کامنت توضیحی تبدیل شود.
5. کوئری را با `courseId IN (...)` فیلتر کن (`K-36`).

### گیت پذیرش فاز ۴
- کاربر با ۳ روز ترجیحی و هدف ۵، واقعاً ۵ جلسه در هفته می‌گیرد (تست واحد زمان‌بند).
- نوار پیشرفت هفتگی هرگز بیش از ۱۰۰٪ نمی‌شود و در تکمیل دوره جهش نمی‌کند (تست واحد موتور، شامل اصلاح `test/courses_engine_test.dart`).
- `invalidate()` واقعاً کش را پاک می‌کند؛ تغییر `weeklyTargetSessions` بلافاصله در خروجی دیده می‌شود (تست واحد).
- `grep -rn "CoursesEngine()" lib/features` خالی است.
- دورهٔ تازه، «۱۰۰٪ منطبق بر برنامه» نشان نمی‌دهد.
- `?? 30` و `?? 45` دیگر در کد نیستند؛ `grep -rn "?? 30\|?? 45" lib/features/courses lib/core/analytics/courses_engine.dart lib/core/domain/agenda/sources/course_agenda_source.dart` خالی.

---

## فاز ۵ — قابلیت‌های مرده و وعده‌های دروغین به کاربر

این فاز جدی‌ترین بخش پرونده است. ماژول دوره‌ها مقدار زیادی کد کامل، درست و تست‌نشده دارد که **هیچ فراخوانی‌کننده‌ای ندارد**، و بدتر از آن، UI وجود آن قابلیت‌ها را به کاربر **وعده می‌دهد**.

قاعدهٔ عمومی این فاز: **هر قابلیت مرده باید یا وصل شود یا حذف شود. رها گذاشتن ممنوع است.** برای هر مورد تصمیم قطعی مشخص شده.

### K-58 🔴 وعدهٔ «مرور فضادار» دروغ است
**واقعیت فعلی:** `SessionDebriefSheet` دقیقاً این متن را به کاربر نشان می‌دهد:
> «در یادآوری‌های مرور دوره‌ای پیشنهادی قرار می‌گیرد»

و پرچم `needsReview = 1` را می‌نویسد. اما:
- `SM2ReviewEngine.calculateNextReview` کامل پیاده شده (فرمول SM-2 با `easinessFactor`، سقف `1.3`، فواصل `1, 6, prev*ef`) و **هیچ‌جا فراخوانی نمی‌شود**.
- `needsReview` در دیتابیس نوشته می‌شود و **هیچ‌جا خوانده نمی‌شود**.
- `CourseActivityKind.review` در CHECK دیتابیس وجود دارد و **هیچ جلسه‌ای با این نوع ساخته نمی‌شود**.
- `sourceSessionId` (برای وصل جلسهٔ مرور به جلسهٔ اصل) همیشه NULL است.
- `courses.reviewEnabled` هیچ سوییچی در UI ندارد.

پس کاربر برای ۶ ماه جلسات را «نیاز به مرور» علامت می‌زند و هیچ کاری اتفاق نمی‌افتد.

**تصمیم قطعی: وصل کن، حذف نکن.** این قابلیت ارزشمندترین وجه تمایز ماژول است.
1. مایگریشن: سه ستون به `course_sessions` اضافه کن تا حالت SM-2 قابل ذخیره باشد:
```
sm2Repetitions INTEGER NOT NULL DEFAULT 0
sm2EasinessFactor REAL NOT NULL DEFAULT 2.5
sm2IntervalDays INTEGER NOT NULL DEFAULT 0
```
2. فایل جدید `lib/features/courses/logic/course_review_planner.dart`:
```dart
class CourseReviewPlanner {
  /// پس از ثبت یک جلسه با needsReview = true، یک جلسهٔ REVIEW
  /// با sourceSessionId و plannedDate حاصل از SM2ReviewEngine می‌سازد.
  Future<CourseSession?> scheduleReviewFor(CourseSession source, {required Course course});
}
```
قواعد:
- کیفیت ورودی SM-2 = `understandingScore` (۱..۵) نگاشت‌شده به مقیاس ۰..۵ SM-2. نگاشت را در یک تابع مستند بنویس (۱→1، ۲→2، ۳→3، ۴→4، ۵→5).
- جلسهٔ مرور `activityKind = 'REVIEW'`، `estimatedDurationMinutes = (course.sessionDurationMinutes / 3).ceil()`، `sessionTitle = 'مرور: <عنوان جلسهٔ مبدأ>'` (از `l10n`).
- `sessionNumber` جدید از `MAX(sessionNumber) + 1` (رجوع به `K-11`) ولی `displayOrder` برابر `source.displayOrder` تا در لیست درست کنار جلسهٔ مبدأ بنشیند.
- جلسات REVIEW **نباید** در `totalSessions` شمرده شوند و نباید در `settledRate`/`completionRate` بیایند (موتور الان `review` را درست کنار می‌گذارد — این را حفظ کن).
- تکمیل جلسهٔ مرور، SM-2 را دوباره روی **جلسهٔ مبدأ** اجرا کند و دور مرور بعدی را بسازد تا وقتی `understandingScore >= 4` و `repetitions >= 3`.
3. `courses.reviewEnabled` را در `CreateCourseSheet` به‌عنوان یک `SwitchListTile` با توضیح کوتاه ارائه کن. اگر خاموش بود، `SessionDebriefSheet` متن وعده را **نشان ندهد**.
4. در `SessionDebriefSheet` پس از ذخیره، اگر جلسهٔ مروری ساخته شد، تاریخ واقعی آن را به شمسی نشان بده: «مرور این جلسه برای ۱۴۰۵/۰۶/۲۱ ثبت شد».
5. تست: زنجیرهٔ کامل مرور برای کیفیت‌های `2, 4, 5` (فواصل `1, 6, ~15`) روی دیتابیس واقعی.

### K-59 🔴 مود بازیابی (`RecoveryModeSheet`) از هیچ جایی باز نمی‌شود
**واقعیت فعلی:** `RecoveryModeSheet.show(...)` یک متد استاتیک کامل با سه پلن و UI دقیق است که **هیچ فراخوانی‌کننده‌ای در کل مخزن ندارد**. کاربری که ۱۵ جلسه عقب افتاده، فقط برچسب «۱۵ جلسه عقب، جبران می‌کنی 💪» می‌بیند و هیچ راهی برای اقدام ندارد. این بدترین حالت ممکن است: اپ مشکل را تشخیص می‌دهد، به کاربر می‌گوید، راه‌حل را هم ساخته و راه‌حل را در دسترس قرار نمی‌دهد.

مشکلات داخلی خود شیت:
- `_applyPlan` مقادیر را بر اساس متغیرهای محاسبه‌شدهٔ هر سه پلن می‌فرستد، بدون اینکه `_selectedPlanIndex` را در همهٔ مسیرها محترم بدارد.
- پلن ۲ (تمدید) فقط `targetEndDate` می‌نویسد که `needsReschedule` نادیده می‌گیرد (`K-33`) → **عملاً بی‌اثر**.
- پلن ۳ (غربال) برچسبش «جلسات فرعی و تمرینی» است ولی در عمل **هر جلسهٔ غیر `learn`** را رد می‌کند — شامل `EXAM` و `PROJECT` که قطعاً فرعی نیستند.
- `weeksToCatchUp` وقتی `extraPerWeek == 0` باشد، برابر `overdueCount` می‌شود — مثلاً «۱۵ هفته» بدون هیچ مبنای منطقی.

**تصمیم قطعی: وصل کن.**
1. نقاط ورود: (الف) برچسب «X جلسه عقب» در `ActiveCoursesSection` قابل لمس شود و شیت را باز کند؛ (ب) در `CourseDetailScreen` وقتی `overdueSessionsCount >= 3`، یک `RitmoCallout` با دکمهٔ «بازطراحی برنامه».
2. پلن‌ها را از `CourseCatchupEngine` بگیر، نه محاسبهٔ inline (`K-60`).
3. هر سه پلن باید واقعاً کار کنند. پلن تمدید باید `targetEndDate` را بنویسد **و** بازتوزیع را تریگر کند.
4. پلن غربال فقط `PRACTICE` را رد کند (`EXAM` و `PROJECT` مصون). متن برچسب دقیقاً بگوید چند جلسه و از چه نوعی رد خواهد شد.
5. `_applyPlan` فقط مقادیر پلن انتخابی را اعمال کند. قبل از اعمال، یک پیش‌نمایش نشان بده: تاریخ پایان قبل و بعد، و تعداد جلسات جابه‌جاشده.
6. `weeksToCatchUp` در حالت `extraPerWeek == 0` باید `null` بدهد و UI بگوید «با این تنظیمات جبران ممکن نیست».

### K-60 🔴 `CourseCatchupEngine` محاسبهٔ سنگین می‌کند که مصرف‌کننده‌اش دور می‌ریزد
**واقعیت فعلی:**
- `generateCatchupPlan` یک لیست کامل `rescheduledSessions` (همهٔ جلسات با `copyWith(plannedDate:)`) می‌سازد.
- `applyCatchupPlan` این لیست را **کاملاً نادیده می‌گیرد** و فقط `updateCourse` با هدف هفتگی جدید را صدا می‌زند.
- `plan.suggestedSkipsCount` (`overdueCount - 10`) محاسبه می‌شود و هیچ‌جا نمایش داده یا اعمال نمی‌شود.
- `messageFa` می‌گوید «ظرف حدود X هفته جبران می‌شود» در حالی که محاسبهٔ پشت آن مربوط به پلنی است که اعمال نمی‌شود.
- و خود موتور **هیچ فراخوانی‌کننده‌ای در UI ندارد** — `RecoveryModeSheet` منطق رقیب خودش را inline دوباره نوشته.

**تصمیم قطعی: موتور را تنها منبع منطق جبران کن.**
1. `applyCatchupPlan` باید `rescheduledSessions` را واقعاً ذخیره کند (با `rescheduleSession` یا یک متد دسته‌ای جدید `rescheduleSessions(Map<String,String>)` در یک تراکنش) — یا اگر قرار است فقط هدف هفتگی عوض شود، **لیست را از خروجی موتور حذف کن**. محاسبهٔ بدون مصرف ممنوع است.
2. `suggestedSkipsCount` را در پلن غربال واقعاً به کار بگیر یا حذف کن.
3. `messageFa` را از موتور خارج کن (فاز ۸): موتور باید `CatchupReasonCode` بدهد، نه متن فارسی.
4. `maxAdditionalWeeklyTarget = 2` به `CourseLimits` منتقل شود.

### K-61 🔴 موتور تطبیقی کاملاً بی‌ورودی و بی‌خروجی است
**واقعیت فعلی:** `CourseAdaptiveEngine.evaluateAndAdjustCourse` یک منطق کامل دو-هفته‌ای با دورهٔ خنک‌شدن ۱۴ روزه دارد، **هیچ فراخوانی‌کننده‌ای ندارد**، و `isAdaptive` هیچ سوییچی در UI ندارد. پس `adaptiveLastAppliedAt` همیشه NULL است.

مشکلات داخلی:
- `updatedAt: today.millisecondsSinceEpoch` — مقدار `updatedAt` را از تاریخ **تزریق‌شده** می‌گیرد. در تست با تاریخ جعلی، این مقدار در دیتابیس خراب می‌شود و اثر‌انگشت موتور (`K-45`) را به عقب می‌برد.
- `evaluateAndAdjustCourse` مستقیماً `updateCourse` را صدا می‌زند، که خودش بازتوزیع + بازسازی یادآور + همگام‌سازی آلارم را تریگر می‌کند — به‌عنوان عوارض جانبی یک متدی که نامش `evaluate` است. هیچ حالت dry-run وجود ندارد.
- شرط افزایش، `prevWeekDone >= weeklyTargetSessions * 1.5` برای **هر دو** هفته است؛ با سقف تقلیل‌یافتهٔ `K-43` عملاً دست‌نیافتنی است. آستانه‌های `1.5`، `0.5`، `6` همه اعداد جادویی بدون نام هستند.
- `reasonFa` رشتهٔ فارسی در لایهٔ منطق.

**تصمیم قطعی: وصل کن، اما محافطه‌شده.**
1. متد را به دو قسمت بشکن: `evaluate(...)` که خالص است و فقط یک `AdaptiveAdjustmentResult` می‌دهد؛ و `apply(...)` که ذخیره می‌کند. تست‌پذیری و قابلیت پیش‌نمایش لازمهٔ بند ۳ است.
2. `updatedAt` حتماً `DateTime.now()` باشد، نه `today` تزریقی.
3. **موتور هرگز بدون اطلاع کاربر تغییر اعمال نکند.** مدل مورد تأیید: در ورود به صفحهٔ دوره‌ها، `evaluate` برای دوره‌های `isAdaptive` اجرا شود و اگر پیشنهادی وجود داشت، یک کارت پیشنهاد در بالای لیست نشان داده شود: «دو هفته پیاپی فراتر از هدف بودی — هدف هفتگی را به ۴ برسانیم؟» با دو دکمهٔ «بله» / «فعلاً نه». رد کردن، `adaptiveLastAppliedAt` را تنطیم کند تا دورهٔ خنک‌شدن رعایت شود.
4. `isAdaptive` را به `CreateCourseSheet` به‌عنوان `SwitchListTile` با توضیح اضافه کن.
5. آستانه‌ها به ثابت‌های نام‌دار در `CourseLimits` منتقل شوند: `adaptiveOverdueThreshold = 6`, `adaptiveUpscaleRatio = 1.5`, `adaptiveDownscaleRatio = 0.5`, `adaptiveCooldownDays = 14`.
6. `reasonFa` → `AdaptiveReasonCode` (فاز ۸).

### K-62 🟠 `reorderSessions` موجود است و لیست جلسات قابل جابه‌جایی نیست
**تصمیم قطعی: وصل کن.** پس از اصلاح تراکنش دومرحله‌ای (`K-12`)، لیست جلسات در `CourseDetailScreen` باید `ReorderableListView` شود — اما **فقط در حالت ویرایش** (یک دکمهٔ «مرتب‌سازی» در هدر بخش جلسات) تا درگ تصادفی در هنگام اسکرول رخ ندهد. جلسات تکمیل‌شده قابل جابه‌جایی نباشند. پس از جابه‌جایی، باید پرسیده شود «تاریخ‌های برنامه هم جابه‌جا شوند؟»

### K-63 🟠 `getCourseSettings` مرده است
**واقعیت فعلی:** `CoursesRepository.getCourseSettings()` تمام کلیدهای `module_courses_%` را می‌خواند و **هیچ‌جا فراخوانی نمی‌شود**.

**تصمیم قطعی: حذف کن.** هیچ تنظیم ماژولی فعلاً تعریف نشده و این متد یک قرارداد خالی است. اگر در فاز ۷ به تنظیمی نیاز پیدا شد (مثلاً پیش‌فرض مرتب‌سازی لیست)، متد تازه با کلیدهای مشخص و تایپ‌دار بنویس.

### K-64 🟠 فیلدهای دیتابیس که هیچ UI‌ای آن‌ها را تنطیم نمی‌کند
**واقعیت فعلی:** این ستون‌ها وجود دارند، در مدل هستند، در `toMap`/`fromMap` هستند، و **هیچ UI‌ای مقدارشان را تنطیم نمی‌کند**:

| ستون | جدول | تصمیم قطعی |
|---|---|---|
| `emoji` | courses | **وصل** — انتخابگر در `course_appearance_picker.dart` (`K-79`) |
| `colorHex` | courses | **وصل** — همان انتخابگر |
| `zoneId` | courses | **وصل** — دراپ‌داون منطقه در `CreateCourseSheet` (الگوی ماژول‌های دیگر را تقلید کن) |
| `targetEndDate` | courses | **وصل** — انتخاب‌گر تاریخ شمسی با `RitmoDatePicker.showJalali` |
| `isAdaptive` | courses | **وصل** — `K-61` |
| `reviewEnabled` | courses | **وصل** — `K-58` |
| `masteryScore` | courses | **وصل** — `K-52` |
| `difficulty` | course_sessions | **وصل** — انتخاب در `SessionActionsSheet` و ورودی رتبه‌بندی `CourseEnergyEngine` |
| `activityKind` | course_sessions | **وصل** — قابل تغییر در `SessionActionsSheet`؛ پیش‌فرض `LEARN` |
| `sectionTitle` | course_sessions | **وصل** — از `AiSyllabusSheet` پر می‌شود و باید به‌عنوان سرفصل گروه‌بندی در لیست جلسات دیده شود |
| `learningObjective` | course_sessions | **وصل** — در `SessionActionsSheet` و در `FocusModeScreen` به‌عنوان «هدف این جلسه» |
| `plannedStartTime` | course_sessions | **وصل** — لازمهٔ موقعیت درست در تایم‌لاین اجندا؛ پیش‌فرض از `course.preferredTime` |
| `sourceSessionId` | course_sessions | **وصل** — `K-58` |
| `activityType` | courses | **مستندسازی به‌عنوان رزرو** — `K-42` |
| `targetDurationMinutes` | course_active_timers | **وصل** — `K-23` |

قاعده: هر ستونی که بعد از این فاز هنوز بدون مصرف‌کننده ماند، باید در گزارش فاز ۹ با دلیل مستند شود.

### K-65 🔴 دکمهٔ «سرفصل AI» هیچ فراخوانی AI انجام نمی‌دهد
**واقعیت فعلی:**
- `CoursesAiHelper.getCourseSuggestion` یک پرامپت کامل با `AIGateway`، `PersonaRegistry`، `AssistantMemoryBinding` و `AIResponseProcessor` دارد — و **هیچ‌جا فراخوانی نمی‌شود**.
- `CoursesScreen._openAiSyllabusSheetWithData(...)` نوشته شده و **هیچ فراخوانی‌کننده‌ای ندارد**.
- `AiSyllabusSheet` فقط متن چسبانده‌شده را محلی parse می‌کند. پس عنوان «ورود سرفصل AI» مطلقاً گمراه‌کننده است.

**تصمیم قطعی: وصل کن.**
1. در `AiSyllabusSheet` یک حالت دوم اضافه کن: یک `TextField` کوتاه برای توصیف دوره (مثلاً «زبان انگلیسی سطح B2 در ۳ ماه») + دکمهٔ «ساخت با هوش مصنوعی» که `getCourseSuggestion` را صدا می‌زند و نتیجه را در همان لیست پیش‌نمایش قابل ویرایش می‌ریزد.
2. حالت فعلی (چسباندن متن) باقی بماند ولی عنوانش به «ورود دستی سرفصل» تغییر کند. دو حالت با `SegmentedButton` تفکیک شوند.
3. `_openAiSyllabusSheetWithData` را وصل کن یا حذف کن — تصمیم: **وصل کن** به مسیر جدید بالا.
4. `CoursesAiHelper` در خطا باید **نوع خطا** برگرداند (`noNetwork`, `invalidResponse`, `notPremium`, `disabled`)، نه `null` خالی. UI باید پیام متفاوتی برای هر کدام نشان دهد.
5. مقادیر بازگشتی AI باید با `CourseLimits` و `CourseValidator` اعتبارسنجی شوند **قبل از** نمایش پیش‌نمایش.

### K-66 🔴 JSON معتبر ولی غیرآرایه‌ای، باعث خطای دروغین می‌شود
**واقعیت فعلی:** در `AiSyllabusSheet._parseSyllabusText`:
```dart
try {
  final decoded = jsonDecode(text);
  if (decoded is List) { ...ساخت drafts... }
} catch (_) {
  ...parse خط‌به‌خط (fallback)...
}
```
اگر کاربر متنی مانند `{"sessions": [ ... ]}` بچسباند (رایج‌ترین قالب خروجی مدل‌های زبانی)، `jsonDecode` موفق می‌شود، `decoded is List` غلط است، `catch` اجرا **نمی‌شود**، `drafts` خالی می‌ماند و پیام «امکان استخراج سرفصل وجود نداشت» نشان داده می‌شود — در حالی که fallback خط‌به‌خط حتماً جواب می‌داد.

**تصمیم قطعی:** منطق parse را به سه مرحلهٔ زنجیره‌ای بازنویسی کن و به یک تابع خالص قابل تست منتقل کن:
1. `jsonDecode` → اگر `List` بود، مستقیم.
2. اگر `Map` بود، اولین مقدار `List` داخلش را پیدا کن (کلیدهای متداول: `sessions`, `items`, `syllabus`, `outline`, `chapters`).
3. اگر هیچ‌کدام نشد (یا خطا) → parse خط‌به‌خط.

موارد دیگر در همین شیت که باید در این فاز اصلاح شوند:
- **`onReorderItem`** در `ReorderableListView` — این پارامتر را با API واقعی Flutter در `pubspec.lock` تطبیق بده. اگر پارامتر درست `onReorder` است، اصلاح کن و **حتماً تصحیح off-by-one را اضافه کن** (`if (newIndex > oldIndex) newIndex -= 1;`) که در کد فعلی نیست — بدون آن، درگ به پایین یک خانه اشتباه می‌نشیند.
- `difficulty` از JSON باید `clamp(1, 5)` شود؛ مقدار `9` باعد CHECK دیتابیس را نقض می‌کند و کل تراکنش ساخت دوره abort می‌شود (با توست عمومی).
- پس از حذف/جابه‌جایی، `sessionNumber` درافت‌ها بازشماری نمی‌شود (نمایش از `index + 1` است ولی مقدار ذخیره‌شده قدیمی است). بازشماری را در همان setState انجام بده.
- مقادیر هاردکد هنگام ذخیره (`sessionDurationMinutes: 45`, `courseType: CourseType.video`, `preferredDays: [6,1,3]`) باید قابل انتخاب شوند؛ حداقل مسیر زیر را پیاده کن: پس از تأیید پیش‌نمایش، `CreateCourseSheet` با `initialValues` پرشده باز شود تا کاربر روزها، مدت، نوع و یادآور را تعیین کند. **مسیر فعلی که مستقیم دوره می‌سازد، حذف شود.**
- عنوان پیش‌فرض `'دوره جدید با سرفصل AI'` در controller باید به `hintText` تبدیل شود، نه مقدار واقعی — در حال حاضر کاربران دوره‌هایی با همین عنوان تحویلی می‌سازند.
- `unitLabel` در پرامپت AI به مجموعهٔ فارسی `['جلسه','فصل','تمرین','واحد']` محدود شده — این مجموعه باید از `CourseType.defaultUnitLabel` بیاید، نه لیست جداگانه.

### K-67 🟠 کارت «الان چی بخونم؟» با لیست جلسات امروز تضاد دارد
**واقعیت فعلی:** `WhatToReadNowCard._pickRecommendedSession` منطق خودش را دارد (اول عقب‌افتاده، بعد امروز، بعد اولین PENDING) و `CoursesEngine.todaySessions` منطق دیگری. پس کارت بالای صفحه ممکن است جلسه‌ای را پیشنهاد دهد که در لیست «جلسات برنامهٔ امروز شما» وجود ندارد — دو پیشنهاد متناقض در یک صفحه. علاوه بر آن، این محاسبهٔ O(courses × sessions) همراه مرتب‌سازی `CourseEnergyEngine` **در متد `build()` اجرا می‌شود**.

**تصمیم قطعی:** منطق انتخاب به `course_metrics.dart` یا موتور منتقل شود و خروجی موتور یک فیلد جدید داشته باشد: `recommendedSession` همراه `recommendationReason` (`overdue`, `plannedToday`, `energyMatch`, `nextInLine`). ویجت فقط رندر کند. در UI دلیل انتخاب را به کاربر بگو (`K-78`).

### گیت پذیرش فاز ۵
- جلسه‌ای که با `needsReview` ثبت می‌شود، یک جلسهٔ `REVIEW` واقعی با تاریخ SM-2 در دیتابیس می‌سازد (تست مخزن).
- `RecoveryModeSheet` از حداقل دو نقطه در UI باز می‌شود (تست ویجت).
- پلن تمدید، تاریخ جلسات را واقعاً تغییر می‌دهد (تست مخزن).
- پلن غربال، جلسات `EXAM` و `PROJECT` را حفظ می‌کند.
- `AiSyllabusSheet` ورودی `{"sessions":[...]}` را درست parse می‌کند (تست واحد روی تابع خالص parse با ۴ قالب ورودی متفاوت).
- `grep -rn "onReorderItem" lib` خالی است.
- هر کلاس موتور در `lib/features/courses/logic/` حداقل یک فراخوانی‌کنندهٔ واقعی دارد (تست گارد: هر فایل logic باید دست‌کم یک بار خارج از تست‌ها import شود).

---

## فاز ۶ — یکپارچگی بین‌ماژولی

### K-68 🔴 `CoursesScreen` به `RitmoEventBus` گوش نمی‌دهد
**واقعیت فعلی:** مخزن در هر جهش `RitmoEventBus().fire(RitmoEvent('CoursesChanged', ...))` می‌زند، اما هیچ مشتری‌ای در ماژول دوره‌ها وجود ندارد. پس:
- تکمیل جلسه از مسیر اجندا/داشبورد، صفحهٔ دوره‌ها را تازه نمی‌کند.
- حذف یک هدف (`goals`) که `linkedGoalId` را NULL می‌کند، در کارت دوره منعکس نمی‌شود.
- خاموش/روشن شدن ماژول از مسیر تنظیمات در صفحهٔ باز دیده نمی‌شود.

**تصمیم قطعی:** `CoursesController` (فاز ۷، `K-77`) در سازنده به `RitmoEventBus` مشترک شود و روی `CoursesChanged`، `CourseSessionCompleted`، `GoalsChanged` و رویدادهای تغییر ماژول، بارگذاری مجدد (debounced با ۲۵۰ms) انجام دهد. در `dispose` اشتراک لغو شود. الگوی ماژولی که الان درست این کار را می‌کند پیدا کن و دقیقاً همان را تقلید کن.

### K-69 🔴 انتشار رویداد با پراکندگی نال‌پذیر در map
**واقعیت فعلی:** در `_fireEvent`:
```dart
payload: { 'reason': reason, if (courseId != null) 'courseId': courseId }
```
این الگو درست است، اما در برخی مسیرها `courseId` در واقع `null` تحویل داده می‌شود (مورد `K-10`: خروج زودرس از تراکنش)، پس مشترک بالادستی نمی‌داند چه دوره‌ای عوض شده و مجبور است همه را بارگذاری کند.

**تصمیم قطعی:** payload را تایپ‌دار کن: یک کلاس کوچک `CoursesChangedPayload { reason, courseId, sessionIds }` بساز و `courseId` را در همهٔ مسیرها اجباری کن (مگر `reason == 'SKIP_BATCH'` که چنددوره‌ای است). مشترک باید بتواند فقط یک دوره را تازه کند.

همچنین محدودیت SDK در `pubspec.yaml` را بررسی کن و مطمئن شو همهٔ الگوهای collection-if و پراکندگی نال‌پذیر که در ماژول استفاده شده، با همان محدودیت سازگارند (`flutter analyze` باید ۰ خروجی بدهد).

### K-70 🔴 حذف دوره، آلارم‌ها و یادآورهای معلق را پاک نمی‌کند
**واقعیت فعلی:** `deleteCourse` ردیف دوره را حذف می‌کند؛ `course_sessions` با `ON DELETE CASCADE` حذف می‌شوند و `course_active_timers` هم به تبع آن. اما:
- ردیف‌های `pending_reminders` با `courseSessionId` مربوطه **با کلید خارجی پوشش داده نشده‌اند** (جدول مشترک است) → رکوردهای معلق.
- آلارم‌های سیستمی (`AlarmPlatform`) لغو نمی‌شوند → **کاربر برای دوره‌ای که حذف کرده نوتیفیکیشن دریافت می‌کند.** این یک باگ درجه‌یک از نقطه‌نظر اعتماد کاربر است.
- `goals.progressCache` با مقدار قدیمی باقی می‌ماند (`K-29`).

**تصمیم قطعی:** `deleteCourse` باید در یک تراکنش:
1. شناسهٔ جلسات را پیش از حذف بخواند.
2. `pending_reminders` مربوطه را حذف کند (با تکه‌تکه کردن `IN`، `K-35`).
3. `linkedGoalId` را قبل از حذف نگه دارد تا پس از تراکنش، `GoalProgressCalculator` دوباره محاسبه شود.
4. پس از تراکنش، آلارم‌ها را با `sl<AlarmPlatform>().cancelAlarm(id)` برای همهٔ یادآورهای حذف‌شده لغو کند.
5. همین مسیر باید برای `archiveCourse` (وقتی پیاده شد) و برای تغییر وضعیت به `PAUSED` و `COMPLETED` هم طی شود — دورهٔ متوقف نباید یادآور بفرستد.

### K-71 🟠 خاموش کردن ماژول دوره‌ها یادآورها را خاموش نمی‌کند
**واقعیت فعلی:** `ModuleGate.instance.isEnabled('module_courses_enabled')` فقط در لایهٔ نمایش چک می‌شود. هیچ مسیری برای لغو آلارم‌های دوره در زمان خاموش شدن ماژول وجود ندارد، و تایمر فعال هم متوقف نمی‌شود. تست `test/unit/module_deactivation_sync_test.dart` وجود دارد — بخوانش و ببین ماژول‌های دیگر چه قراردادی دارند و دوره‌ها را به همان قرارداد ملحق کن.

**تصمیم قطعی:** در خاموش شدن ماژول: همهٔ آلارم‌های دوره لغو، تایمر فعال (اگر وجود داشت) متوقف و ذخیره شود، و `CourseAgendaSource` دیگر موردی تولید نکند. در روشن شدن مجدد، `syncAllCourseAlarms()` فراخوانی شود (`K-31`).

### K-72 🟠 `CourseRegistrySource` و شمارش دوبارهٔ همه‌چیز
**واقعیت فعلی (علاوه بر ستون‌های ناموجود در `K-06`):** این فایل مفهوم «تکمیل‌شده» را مستقلاً بازتعریف می‌کند (`doneCount >= totalSessions`) در حالی که مخزن وضعیت `COMPLETED` را در دیتابیس دارد. دو منبع حقیقت که در وجود جلسات ردشده واگرا می‌شوند.

**تصمیم قطعی:** منبع حقیقت `courses.status` است. `CourseRegistrySource` باید همین را بخواند و در کوئری این ستون‌های واقعی را به کار ببرد: `status`، `isArchived`، `provider`. پس از اصلاح، یک تست واقعی روی دیتابیس in-memory بنویس که اگر ستونی ناموجود باشد، تست فوراً قرمز شود (این دقیقاً دلیلی است که `K-06` تا امروز کشف نشده بود).

### K-73 🟡 `snapshot_sync_service` بدون محافطت در مسیر داغ فراخوانی می‌شود
**واقعیت فعلی:** `SnapshotSyncService.syncAll()` در مسیرهای جهش مخزن بدون debounce و بدون `await`-مدیریت‌شده صدا می‌شود. در حالت تکمیل دسته‌ای جلسات (پلن غربال، `SKIP_BATCH`) به تعداد جلسات فراخوانی می‌شود.

**تصمیم قطعی:** در عملیات دسته‌ای، همگام‌سازی فقط **یک بار در پایان** انجام شود. اگر سرویس خودش debounce دارد، مستند کن و دست نزن؛ وگرنه در مخزن یک پرچم `suppressSync` برای مسیرهای دسته‌ای اضافه کن.

### گیت پذیرش فاز ۶
- تکمیل جلسه از مسیر اجندا، صفحهٔ دوره‌ها را خودبه‌خود تازه می‌کند (تست ویجت با رویداد جعلی).
- حذف دوره، هیچ ردیفی در `pending_reminders` باقی نمی‌گذارد و `cancelAlarm` برای هر یادآور صدا می‌شود (تست مخزن با fake alarm platform و شمارش فراخوانی‌ها).
- `CourseAgendaSource` در ماژول خاموش، موردی تولید نمی‌کند.
- `grep -rn "'جلسه \${" lib/core` خالی است.
- `flutter analyze` بدون خروجی.

---

## فاز ۷ — رابط کاربری و تجربهٔ کاربری

این فاز شامل همهٔ پیشنهادهای بهبود UI/UX است. این‌ها **پیشنهاد نیستند، الزام هستند.** ترتیب اجرا دقیقاً همین ترتیب است، چون `K-77` (کنترلر) زیرساخت بقیه است — اما اول `K-74` و `K-75` را انجام بده تا ساختار صفحه آمادهٔ کنترلر شود.

### K-74 🔴 کل صفحه یک `SingleChildScrollView` با سه لیست `shrinkWrap` توی‌درتوی است
**واقعیت فعلی:** `CoursesScreen` کل محتوا را در یک `SingleChildScrollView` می‌گذارد و `ActiveCoursesSection`، `TodaySessionsSection` و `CompletedCoursesSection` هر سه `ListView.builder` با `shrinkWrap: true` و `physics: NeverScrollableScrollPhysics()` هستند. پیامدها:
- **مجازی‌سازی کاملاً از بین می‌رود.** همهٔ کارت‌های هر سه بخش در هر فریم ساخته می‌شوند. کاربری با ۳۰ دوره و ۲۰۰ جلسهٔ امروز، افت فریم محسوس دارد.
- `WhatToReadNowCard` محاسبهٔ O(n²) خود را در `build()` انجام می‌دهد که در هر اسکرول تکرار می‌شود.

**تصمیم قطعی:** بازنویسی با `CustomScrollView` و اسلایورها:
```dart
CustomScrollView(
  slivers: [
    SliverToBoxAdapter(child: CoursesWeeklyHero(...)),
    SliverToBoxAdapter(child: WhatToReadNowCard(...)),
    SliverToBoxAdapter(child: CourseInsightsSection(...)),   // K-76
    SliverToBoxAdapter(child: _SectionHeader('دوره‌های فعال')),
    SliverList.builder(...),                                  // دوره‌های فعال
    SliverToBoxAdapter(child: _SectionHeader('جلسات امروز')),
    SliverList.builder(...),                                  // جلسات امروز
    SliverToBoxAdapter(child: _CompletedToggle(...)),
    SliverList.builder(...),                                  // تکمیل‌شده (فقط در حالت باز)
    const SliverToBoxAdapter(child: SizedBox(height: 96)),   // فضای FAB
  ],
)
```
هر سه ویجت بخش، باید به دو قسمت بشکنند: یک ویجت هدر و یک ویجت کارت تکی (`CourseCard`، `TodaySessionTile`، `CompletedCourseCard`). منطق گروه‌بندی/مرتب‌سازی به کنترلر منتقل شود. هیچ `shrinkWrap: true` در ماژول باقی نماند.

همین کار در `CourseDetailScreen` باید انجام شود: لیست جلسات (که تا ۵۰۰ ردیف می‌تواند داشته باشد) باید مجازی باشد.

### K-75 🔴 بارگذاری دوباره در هر تعامل، و خطای دیتابیس شبیه «دوره‌ای ندارید» دیده می‌شود
**واقعیت فعلی:**
1. شش ویجت فرزند کال‌بک `onChanged` دارند که `_loadAllData()` را صدا می‌زند، و برخی مسیرها علاوه بر آن `.then((_) => _loadAllData())` هم دارند → **دو بارگذاری کامل برای یک تپ**. هر بارگذاری = چندین کوئری + محاسبهٔ کامل موتور.
2. `catch` بارگذاری فقط `_isLoading = false` می‌کند و لیست‌ها خالی می‌مانند → کاربر پیام «هنوز هیچ دوره‌ای ایجاد نکرده‌اید» می‌بیند. **کاربری که ۳۰ دوره دارد و کوئری خطا داده، فکر می‌کند همهٔ داده‌هایش پاک شده.** این بدترین حالت خطای ممکن است. و درست اینجاست که `K-06` (کوئری روی ستون ناموجود) ماه‌ها پنهان مانده.

**تصمیم قطعی:** یک ماشین حالت صریح بساز:
```dart
sealed class CoursesViewState {}
class CoursesLoading extends CoursesViewState {}
class CoursesReady extends CoursesViewState { ... }
class CoursesEmpty extends CoursesViewState {}
class CoursesError extends CoursesViewState { final String code; final Object error; }
```
- `CoursesError` باید یک حالت خطای واقعی با متن و دکمهٔ «تلاش مجدد» رندر کند و خطا را با `RitmoLog.error('COURSES', ...)` لاگ کند.
- `_loadAllData` در یک زمان فقط یک بار اجرا شود (گارد `_inFlight` + debounce ۲۵۰ms) و همهٔ `.then((_) => _loadAllData())` حذف شوند.
- همهٔ `setState` با `if (!mounted) return;` محافظت شوند (موارد فعلی را بررسی و تکمیل کن).

### K-76 🔴 بخش جدید «بصیرت‌ها» — نمایش متریک‌هایی که محاسبه می‌شوند و دیده نمی‌شوند
**فایل جدید:** `lib/features/courses/presentation/widgets/course_insights_section.dart`

این مهم‌ترین فرصت محصولی ماژول است: موتور همهٔ این داده‌ها را محاسبه می‌کند و هیچ کدام به کاربر نشان داده نمی‌شود (`K-56`).

محتوای الزامی — یک گرید ۲×۲ از کارت‌های کوچک در یک تاگل جمع‌شدنی (پیش‌فرض: باز):

| کارت | مقدار | در نبود داده |
|---|---|---|
| «انطباق بر برنامه» | `scheduleAdherence` به درصد | «حداقل ۵ جلسه لازم است» |
| «دقت تخمین زمان» | `estimationAccuracy` + جهت (کمتر/بیشتر از تخمین) | «با تایمر مطالعه کن تا محاسبه شود» |
| «سرعت لازم تا تاریخ هدف» | `requiredWeeklyPace` (حالت‌های `CoursePace`) | «تاریخ هدفی تعیین نکرده‌ای» + دکمهٔ تعیین |
| «تاریخ پایان تخمینی» | `estimatedEnd` به شمسی | دلیل دقیق (نه «مشخص نیست» خالی) |

قواعد:
- مقادیر از `CourseMetric<T>` بیایند (`K-52`)؛ اگر `value == null`، متن دلیل را از `reasonCode` بساز — هرگز عدد صفر یا خط تیره نشان نده.
- در حالت دورهٔ تکی (`CourseDetailScreen`) همین ویجت با دادهٔ محدود به همان دوره استفاده شود — دو پیاده‌سازی موازی ننویس.
- هر کارت یک `Tooltip` توضیحی داشته باشد که فرمول را به زبان ساده توضیح می‌دهد («از جلساتی که تاریخشان رسیده، چه نسبتی را انجام داده‌ای»).
- این بخش در حالت `CoursesEmpty` نمایش داده نشود.

### K-77 🔴 کنترلر — خروج منطق از لایهٔ ویجت
**فایل جدید:** `lib/features/courses/logic/courses_controller.dart`

مسئولیت‌ها:
- بارگذاری یکجای داده (دوره‌ها، جلسات، تایمر فعال، خروجی موتور) در یک مسیر، با گارد همزمانی.
- نگه‌داشت `CoursesViewState` و انتشار با `ChangeNotifier` (یا هر الگویی که در بقیهٔ پروژه رایج است — **اول یک ماژول مشابه را بخوان و همان الگو را تقلید کن؛ مدیریت حالت جدید وارد پروژه نکن**).
- اشتراک در `RitmoEventBus` (`K-68`) و لغو در `dispose`.
- فیلتر/جستجو/مرتب‌سازی (`K-85`).
- فراخوانی موتور از مسیر `RitmoEngineBus` (`K-45`)، نه `CoursesEngine()`.

قاعده: پس از این مورد، `CoursesScreen` نباید هیچ فراخوانی مستقیم مخزن یا موتور داشته باشد. گیت: `grep -rn "CoursesRepository\|CoursesEngine" lib/features/courses/presentation` فقط موارد مربوط به تزریق در سازندهٔ کنترلر را نشان دهد.

### K-78 🔴 کارت «الان چی بخونم؟» نمی‌گوید چرا این را پیشنهاد داده
**واقعیت فعلی:** کارت فقط عنوان جلسه و دکمهٔ شروع را نشان می‌دهد. منطق پشتش (عقب‌افتادگی، تطابق انرژی، برنامهٔ امروز) نامرئی است، پس کاربر به پیشنهاد اعتماد نمی‌کند. علاوه بر آن:
- حاشیهٔ کارت `16` است در حالی که پدینگ والد `20` است → **عدم ترازی مرئی با بقیهٔ صفحه**.
- محاسبه در `build()` (`K-67`).
- دکمهٔ شروع مستقیماً `startTimer` می‌زند که تایمر دیگری را نابود می‌کند (`K-16`).

**تصمیم قطعی:**
1. یک ردیف دلیل بالای عنوان اضافه کن که از `recommendationReason` ساخته می‌شود: «۳ روز عقب افتاده» / «برنامهٔ امروزت» / «متناسب با انرژی پایین امروز» / «جلسهٔ بعدی در مسیر».
2. دکمهٔ ثانویهٔ «یکی دیگر» که پیشنهاد بعدی را نشان می‌دهد (لیست مرتب‌شده را از کنترلر بگیر، نه فقط عنصر اول).
3. حاشیه را با بقیهٔ صفحه یکسان کن (حذف `margin` داخلی و تکیه بر پدینگ والد).
4. دکمهٔ شروع از همان مسیر واحد شروع تایمر با مدیریت تعارض عبور کند.

### K-79 🟠 انتخابگر ظاهر دوره — امکان تفکیک بصری دوره‌ها
**فایل جدید:** `lib/features/courses/presentation/widgets/course_appearance_picker.dart`

**واقعیت فعلی:** ستون‌های `emoji` و `colorHex` در دیتابیس وجود دارند، مدل آن‌ها را دارد، `CourseType.defaultEmoji` هم وجود دارد — و هیچ UI‌ای قابل تغییرشان نیست. پس همهٔ دوره‌های هم‌نوع دقیقاً هم‌شکل دیده می‌شوند. کاربری با پنج دورهٔ ویدیویی، پنج کارت با 🎥 و یک رنگ می‌بیند.

**محتوای الزامی:**
- ردیف انتخاب ایموجی: ۱۲ ایموجی رایج یادگیری + پیش‌فرض نوع دوره.
- ردیف انتخاب رنگ از پالت تم (`RitmoColors`) — **نه رنگ هاردکد** (`K-88`). رنگ انتخابی باید در دو حالت روشن/تاریک تضاد مکفی داشته باشد.
- انتخاب‌گر `targetEndDate` با `RitmoDatePicker.showJalali` + دکمهٔ پاک کردن.
- سوییچ‌های `isAdaptive` (`K-61`) و `reviewEnabled` (`K-58`) با توضیح یک‌خطی.
- دراپ‌داون `zoneId` و `provider` (مثلاً «یودمی»، «مکتبخونه») — `provider` هم در دیتابیس هست و هیچ ورودی‌ای ندارد.

این ویجت باید هم در `CreateCourseSheet` (مرحلهٔ دو) و هم در ویرایش دوره استفاده شود — یک پیاده‌سازی، دو مصرف‌کننده.

### K-80 🟠 کارت دوره اطلاعات کلیدی را پنهان می‌کند و عنوان بلند را می‌شکند
**واقعیت فعلی در `ActiveCoursesSection`:**
- عنوان دوره در یک `Row` بدون `Expanded` و بدون `overflow: TextOverflow.ellipsis` → عناوین بلند (که تا ۱۲۰ کاراکتر مجازند) باعث سرریز می‌شوند.
- `DateTime.now()` داخل `itemBuilder` فراخوانی می‌شود (`K-50`).
- **تاریخ جلسهٔ بعدی نمایش داده نمی‌شود** — مهم‌ترین اطلاعی که کاربر در لیست دوره‌ها لازم دارد.
- هیچ راهی برای متوقف/ادامه کردن دوره (`PAUSED`) وجود ندارد در حالی که وضعیتش در دیتابیس وجود دارد و `statusLabel` برایش متن دارد.

**تصمیم قطعی — محتوای نهایی کارت دوره:**
1. ردیف بالا: ایموجی + عنوان (`Expanded` + `maxLines: 2` + `ellipsis`) + منوی سه‌نقطه.
2. ردیف دوم: نوار پیشرفت دورنگ (انجام‌شده / ردشده، `K-53`) + متن `۱۲ از ۴۰ جلسه` با واحد از `unitLabel`.
3. ردیف سوم (جدید): «جلسهٔ بعدی: پنجشنبه ۲۱ خرداد» یا در حالت عقب‌افتادگی، چیپ قابل لمس «۳ جلسه عقب» که `RecoveryModeSheet` را باز می‌کند (`K-59`).
4. ردیف چهارم (جدید): `SegmentedVisualJourneyTrack` فشرده (حداکثر ۲۰ قطعه، بقیه خلاصه) تا کاربر الگوی پیوستگی‌اش را ببیند.
5. منوی سه‌نقطه: «ویرایش»، «متوقف کردن دوره» / «ادامه دادن»، «بازطراحی برنامه»، «بایگانی کردن» (`K-87`)، «حذف».
6. دورهٔ `PAUSED` با رنگ خاموش و برچسب واضح در همان لیست نشان داده شود (نه حذف شود)، تا کاربر فراموشش نکند.

### K-81 🟠 هیچ مسیر سریعی برای ثبت و هیچ راه بازگشتی وجود ندارد
**واقعیت فعلی:** برای رد کردن یا تکمیل سریع یک جلسه باید وارد جزئیات شد یا شیت دیبریف را پر کرد. و هیچ عملی قابل بازگرداندن نیست — رد کردن اشتباهی یک جلسه، فقط با رفتن به جزئیات دوره و پیدا کردن جلسه قابل جبران است (و `uncompleteSession` هم مسیر UI کاملی ندارد).

**تصمیم قطعی:**
1. جلسات امروز با `Dismissible` دوجهته: کشیدن به یک طرف = «تکمیل سریع» (`DebriefMode.quick`، `K-19`)، به طرف دیگر = «رد کردن» با انتخاب دلیل. جهت‌ها حتماً با `TextDirection.rtl` معنادار باشند.
2. پس از هر دو، یک `SnackBar` با دکمهٔ **«بازگرداندن»** (۵ ثانیه) که `uncompleteSession` یا بازگردانی وضعیت به PENDING را فراخوانی می‌کند. در بازگرداندن، یادآور و آلارم هم باید بازگردد (`K-31` را رعایت کن).
3. در تکمیل سریع، `durationSource = 'DEFAULT'` باشد (`K-20`) و در متریک دقت تخمین وارد نشود.

### K-82 🔴 مشکلات قطعی در `TodaySessionsSection`
**واقعیت فعلی:**
1. الگوی `firstWhere` در `try/catch` برای پیدا کردن دورهٔ متناظر — استثنا به‌عنوان جریان کنترلی.
2. قاعدهٔ `highEnergyOnly`: وقتی انرژی پایین است، یک کارت نشان داده می‌شود که «این جلسه به انرژی بالا نیاز دارد» و **هیچ دکمه‌ای ندارد** — نه «باشه، بازهم شروع کن»، نه «به روز دیگر موکول کن»، نه «رد کن». کاربر در بن‌بست است.
3. `_resolvedQuestionIds` در حالت محلی نگه داشته می‌شود و `setSessionQuestionResolved(...)` **بدون `await`** فراخوانی می‌شود → در خطا، تیک در UI می‌ماند و در دیتابیس نیست؛ با یک بار رفرش، تیک ناپدید می‌شود.

**تصمیم قطعی:**
1. `firstWhereOrNull` از `package:collection` در همهٔ موارد. گیت: `grep -rn "firstWhere(" lib/features/courses` فقط مواردی را نشان دهد که وجود عنصر قطعی است.
2. کارت `highEnergyOnly` سه دکمه بگیرد: «بازهم شروع می‌کنم» (تایمر)، «موکول به فردا» (`rescheduleSession`)، «رد کردن با دلیل انرژی پایین» (`skipReason`). قاعدهٔ `offerLight` هم باید دکمهٔ واقعی داشته باشد که `customDuration` را واقعاً بنویسد (`K-20`).
3. `setSessionQuestionResolved` با `await` و با بازگردانی حالت در خطا (optimistic + rollback) پیاده شود؛ منبع حقیقت `questionResolved` دیتابیس باشد، نه `Set` محلی.
4. جلسات امروز باید گروه‌بندی شوند: «عقب‌افتاده» قبل از «امروز»، با هدر مجزا. در حال حاضر همه با هم مخلوطند.

### K-83 🟠 شیت اقدامات جلسه — دسترسی به همهٔ عملیات از یک جا
**فایل جدید:** `lib/features/courses/presentation/widgets/session_actions_sheet.dart`

محتوای الزامی (با لمس طولانی روی هر جلسه در هر دو صفحه باز می‌شود):
- شروع تایمر / تکمیل سریع / تکمیل با دیبریف کامل
- لغو تکمیل (`uncompleteSession` — الان مسیر کاملی ندارد)
- رد کردن با **انتخاب دلیل** (ستون `skipReason` وجود دارد و مایگریشن `migration_v70_course_skip_reason.dart` هم هست — ولی هیچ UI‌ای دلیل را نمی‌پرسد)
- تغییر تاریخ (`rescheduleSession` با تقویم شمسی)
- جابه‌جایی در ترتیب (`K-62`)
- ویرایش `sessionTitle`، `sectionTitle`، `learningObjective`، `difficulty`، `activityKind`، `estimatedDurationMinutes`، `plannedStartTime` (`K-64`)
- مشاهده/ویرایش `note`، `keyTakeaway`، `openQuestion` و تیک `questionResolved`

قاعده: هر اقدامی که مخزن پشتیبانی می‌کند باید در این شیت در دسترس باشد. اقدامات غیرمجاز در وضعیت فعلی جلسه باید `disabled` باشند با توضیح دلیل در `Tooltip` — نه مخفی.

### K-84 🟠 جریان ساخت دوره — کاربر تا لحظهٔ ذخیره نمی‌داند چه چیزی می‌سازد
**واقعیت فعلی:** `CreateCourseSheet` (۳۴ کیلوبایت) پارامترها را می‌گیرد و هیچ پیش‌نمایشی از برنامهٔ حاصل نمی‌دهد. کاربر فقط پس از ذخیره می‌بیند که دوره تا دو سال بعد طول می‌کشد. علاوه بر آن، منطق `needsReschedule` در این فایل **کپی شده** (تکرار منطق مخزن، `K-34`).

**تصمیم قطعی:**
1. یک کارت پیش‌نمایش زنده در انتهای فرم که با هر تغییری به‌روز می‌شود:
   - «۴۰ جلسه، ۳ روز در هفته → پایان حدود ۱۴۰۵/۰۹/۱۲ (۱۳ هفته)»
   - تاریخ سه جلسهٔ اول به شمسی.
   - اگر `targetEndDate` تعیین شده و قابل دسترسی نیست، هشدار با پیشنهاد عدد دقیق (`K-49`).
   - پیش‌نمایش باید از همان `CourseScheduler.distributeSessions` بیاید تا دقیقاً با نتیجهٔ ذخیره یکسان باشد (پیش‌نمایشی که منطق موازی داشته باشد، بدتر از نبودن پیش‌نمایش است).
2. اعتبارسنجی inline زیر هر فیلد به محض تغییر (نه فقط در لحظهٔ ذخیره)، با خروجی `CourseValidator` که تنها منبع قواعد است.
3. منطق تکراری `needsReschedule` از این فایل حذف و به مخزن منتقل شود.
4. دیالوگ تأیید بازتوزیع در ویرایش باید بگوید چند جلسه جابه‌جا می‌شود و تاریخ پایان جدید چه می‌شود (`K-34`).
5. در حالت کوتاه کردن دوره، پیام باید صریح بگوید کدام جلسات حذف می‌شوند و چند جلسهٔ تکمیل‌شده مانع کار است (`K-32`).

### K-85 🟠 بدون جستجو، فیلتر و مرتب‌سازی
**واقعیت فعلی:** لیست دوره‌ها ثابت است و هیچ راهی برای پیدا کردن یک دوره در میان ۳۰ دوره نیست. مرتب‌سازی فعلی فقط ترتیب پیش‌فرض کوئری است. علاوه بر آن، `ActiveCoursesSection` یک حالت خالی داخلی دارد که **هرگز دیده نمی‌شود** چون والد در لیست خالی این ویجت را رندر نمی‌کند — کد مرده.

**تصمیم قطعی:**
1. یک نوار جستجوی ساده (روی `title` و `provider`) که با ارقام فارسی هم کار کند (نرمال‌سازی با `RitmoNumber.toEn` و نرمال‌سازی کاراکترهای عربی/فارسی کو ی).
2. چیپ‌های فیلتر: وضعیت (فعال/متوقف/تکمیل)، نوع دوره، «فقط عقب‌افتاده‌ها».
3. مرتب‌سازی: جلسهٔ بعدی، میزان پیشرفت، عقب‌افتادگی، آخرین فعالیت، الفبا.
4. حالت خالی، **متناسب با زمینه** باشد: «هنوز دوره‌ای نساخته‌ای» با CTA واقعی در مقابل «هیچ دوره‌ای با این فیلتر پیدا نشد» با دکمهٔ پاک کردن فیلتر. از `RitmoEmptyState` استفاده کن.
5. حالت خالی مرده در `ActiveCoursesSection` حذف شود.
6. حالت بارگذاری از `RitmoSkeleton` استفاده کند (در حال حاضر `CircularProgressIndicator` در مرکز صفحه است و جایگاه محتوا را نشان نمی‌دهد).

### K-86 🟠 مشکلات `CourseDetailScreen` و مسیر پیشرفت بصری
**واقعیت فعلی:**
1. دورهٔ با وضعیت `COMPLETED` در برخی مسیرها برچسب «متوقف‌شده» می‌گیرد (منطق برچسب با `statusLabel` هماهنگ نیست).
2. `SegmentedVisualJourneyTrack` قطعات را با عرض ثابت ۳ پیکسل می‌سازد در یک `SingleChildScrollView` افقی بدون هیچ نشانهٔ اسکرول — با ۴۰۰ جلسه، ۳۰۰۰ پیکسل محتوای نامرئی. `onSegmentTap` پارامتری است که `null` پاس می‌شود → قطعات قابل لمس نیستند.
3. محاسبهٔ پیشرفت inline (`K-53`).

**تصمیم قطعی:**
1. همهٔ برچسب‌های وضعیت از `Course.statusLabel` بیایند. گیت: هیچ رشتهٔ `'متوقف‌شده'` یا `'تکمیل‌شده'` در لایهٔ ویجت نباشد.
2. `SegmentedVisualJourneyTrack` در دو حالت: تا ۴۰ جلسه قطعات تکی؛ بیش از آن، خلاصه‌سازی هفتگی/فصلی با حداکثر ۴۰ قطعه. عرض قطعات با `LayoutBuilder` متناسب با عرض موجود محاسبه شود تا همیشه بدون اسکرول جا شود.
3. `onSegmentTap` واقعاً وصل شود و `SessionActionsSheet` را باز کند. هر قطعه `Semantics` و `Tooltip` با عنوان جلسه و وضعیت بگیرد (فاز ۸).
4. رنگ قطعات باید سه حالت را تمیز تفکیک کند (انجام‌شده / ردشده / باقیمانده) و فقط با رنگ تفکیک نشود (الگو/شکل متفاوت برای ردشده).
5. لیست جلسات بر اساس `sectionTitle` گروه‌بندی شود (وقتی مقدار دارد) — این دقیقاً دلیل وجود آن ستون است (`K-64`).

### K-87 🟡 مشکلات بخش دوره‌های تکمیل‌شده و بایگانی که وجود ندارد
**واقعیت فعلی در `CompletedCoursesSection`:**
1. مجموع زمان مطالعه با `actualDurationMinutes ?? 0` جمع می‌شود → جلساتی که با تکمیل مستقیم ثبت شده‌اند صفر می‌شوند → **کم‌شماری شدید فخر کاربر.** کاربری که ۴۰ جلسه را بدون تایمر ثبت کرده، «۰ دقیقه مطالعه» می‌بیند.
2. دورهٔ بایگانی‌شده با `TextDecoration.lineThrough` رندر می‌شود — این قرارداد بصری «لغوشده» است، نه «بایگانی‌شده».
3. `getCompletedAndArchivedCourses` شاخهٔ `isArchived == 1` دارد، ولی **هیچ UI‌ای در کل اپ این ستون را روی `1` نمی‌گذارد** → آن شاخه دسترس‌ناپذیر است.

**تصمیم قطعی:**
1. مجموع زمان مطالعه فقط روی جلسات `durationSource == 'TIMER'` یا `'MANUAL'` جمع شود و کنارش برچسب «از X جلسهٔ دارای زمان ثبت‌شده» بیاید (`K-20`). هرگز ۰ را به‌جای «ثبت نشده» نشان نده.
2. `lineThrough` حذف شود؛ بایگانی با رنگ خاموش + آیکن آرشیو + برچسب متنی نشان داده شود.
3. عملیات «بایگانی کردن» و «خروج از بایگانی» در منوی کارت دوره وصل شود، و در مخزن متدهای `archiveCourse(id)` / `unarchiveCourse(id)` با لغو آلارم (`K-70`) اضافه شوند. دورهٔ بایگانی نباید در اجندا، رجیستری، موتور یا یادآورها ظاهر شود.
4. کارت دورهٔ تکمیل‌شده باید کیفیت تکمیل را نشان دهد (`K-28`): «کامل» / «با X جلسهٔ ردشده» — و دورهٔ کاملاً ردشده هرگز 🏆 نگیرد.

### گیت پذیرش فاز ۷
- `grep -rn "shrinkWrap: true" lib/features/courses` خالی است.
- `grep -rn "CoursesRepository\|CoursesEngine" lib/features/courses/presentation` فقط تزریق کنترلر را نشان می‌دهد.
- `grep -rn "firstWhere(" lib/features/courses` بدون مورد در جریان کنترلی.
- تست ویجت: با خطای تزریق‌شدهٔ مخزن، حالت خطا با دکمهٔ تلاش مجدد رندر می‌شود، نه حالت خالی.
- تست ویجت: یک تپ روی تکمیل جلسه، دقیقاً **یک** بارگذاری تریگر می‌کند (شمارش فراخوانی مخزن جعلی).
- تست ویجت: عنوان ۱۲۰ کاراکتری باعث `RenderFlex overflow` نمی‌شود.
- تست ویجت: دورهٔ ۴۰۰ جلسه‌ای، مسیر پیشرفت را بدون سرریز رندر می‌کند.
- بخش بصیرت‌ها در نبود داده متن دلیل نشان می‌دهد، نه صفر.

---

## فاز ۸ — تم، دسترس‌پذیری و بومی‌سازی

### K-88 🔴 رنگ‌های هاردکد در سراسر ماژول
**واقعیت فعلی:** دست‌کم ۱۶ مقدار `Color(0x...)` و ده‌ها `Colors.white*` در ماژول هاردکد شده‌اند:
```
0xff3B82F6  0xff8B5CF6  0xffEC4899  0xff10A37F  0xff10B981  0xff1D4ED8
0xff1E3A8A  0xffEFF6FF  0xffDBEAFE  0xff12141C  0xff16192E  0xff1C1F2E
0xff5B8AF5  0xff1A1D29  0xff0F172A  0xffF8FAFC
```
به‌علاوه `Colors.white`، `Colors.white10/12/54/60/70` و `Colors.lightBlueAccent` در `study_timer_sheet.dart`، `ai_syllabus_sheet.dart`، `course_detail_screen.dart`، `create_course_sheet.dart`.

پیامد: مقادیر `0xff12141C`، `0xff16192E`، `0xff1A1D29`، `0xff0F172A` رنگ‌های **پس‌زمینهٔ تیره** هستند. در حالت تم روشن، متن سفید روی پس‌زمینهٔ روشن یا متن تیره روی پس‌زمینهٔ تیره می‌نشیند — **بخش‌هایی از ماژول در تم روشن عملاً خوانا نیستند.**

**تصمیم قطعی:**
1. `docs/theme_migration.md` را بخوان و دقیقاً قرارداد موجود را به کار بگیر. همهٔ رنگ‌ها از `context.colors` / `RitmoColors` بیایند.
2. اگر رنگ معناداری لازم داری که در تم نیست (مثلاً رنگ «ردشده»)، آن را به `RitmoColors` اضافه کن (برای هر دو حالت روشن/تیره)، نه در ویجت.
3. پالت رنگ دوره (`colorHex`، `K-79`) مجموعه‌ای از توکن‌های تم باشد، نه هگزهای خام.
4. همهٔ متن‌ها و آیکن‌ها در هر دو حالت تم باید حداقل نسبت تضاد WCAG AA (۴.۵:۱ برای متن معمول، ۳:۱ برای متن بزرگ) را داشته باشند.

**گیت:** `grep -rn "Color(0x" lib/features/courses` و `grep -rn "Colors\." lib/features/courses` هر دو خالی (مگر `Colors.transparent`).

### K-89 🟠 اندازهٔ قلم هاردکد و ارتفاع شیت ثابت در مقابل `textScaler`
**واقعیت فعلی:** اندازه‌های `9`، `9.5`، `10`، `10.5`، `11`، `11.5`، `12.5` مستقیماً در ویجت‌ها نوشته شده‌اند، و ارتفاع شیت‌ها با ضرایب ثابت `0.85`، `0.8`، `0.6` از ارتفاع صفحه محاسبه می‌شود. کاربری که اندازهٔ قلم سیستم را ۲افزوده کرده:
- متن‌های ۹ پوانتی در `Row`‌های تنگ سرریز می‌شوند.
- محتوای شیت دیبریف در ارتفاع ثابت جا نمی‌شود و **دکمهٔ ذخیره از دسترس خارج می‌شود** → کاربر نمی‌تواند جلسه را ثبت کند.

**تصمیم قطعی:**
1. همهٔ اندازه‌های قلم از `Theme.of(context).textTheme` بیایند (یا هر قراردادی که `ritmo_theme.dart` دارد). هیچ `fontSize:` عددی در ماژول نماند.
2. شیت‌ها از `RitmoSheetScaffold` با ارتفاع انعطاف‌پذیر (`DraggableScrollableSheet` یا `maxHeight` + `SingleChildScrollView`) استفاده کنند. دکمهٔ اقدام اصلی در یک ناحیهٔ ثابت پایین (خارج از ناحیهٔ اسکرول) قرار بگیرد تا هرگز از دسترس خارج نشود.
3. `fontFamily: 'Courier'` برای ارقام تایمر حذف و با `FontFeature.tabularFigures()` روی قلم اصلی جایگزین شود (`K-26`).
4. تست: دو تست ویجت با `MediaQuery(data: ...copyWith(textScaler: TextScaler.linear(2.0)))` برای صفحهٔ دوره‌ها و شیت دیبریف که سرریز ندارند و دکمهٔ ذخیره قابل دسترس است. الگوی `test/narrow_screen_fallback_test.dart` را تقلید کن.

### K-90 🟠 دسترس‌پذیری عملاً غایب است
**واقعیت فعلی:** هیچ `Semantics`، هیچ `Tooltip` معنادار، و چندین هدف لمس کوچک‌تر از ۴۸×۴۸ در ماژول وجود دارد.

**تصمیم قطعی — حداقل موارد الزامی:**
- `_WeekdayChip` (انتخاب روزها): `Semantics(button: true, selected: ..., label: '<نام روز>')` و هدف لمس حداقل ۴۸×۴۸.
- چیپ‌های امتیاز در `SessionDebriefSheet`: برچسب معنادار («درک ۳ از ۵»)، نه فقط عدد.
- قطعات مسیر پیشرفت: `Semantics` + `Tooltip` با عنوان جلسه و وضعیت (`K-86`).
- کارت‌های پلن در `RecoveryModeSheet`: `Semantics(button: true, selected: ...)`.
- همهٔ `LinearProgressIndicator`‌ها: در `Semantics` با `value` متنی پیچیده شوند («پیشرفت ۶۰ درصد») — در حال حاضر برای صفحه‌خوان کاملاً خاموشند.
- دکمه‌های آیکنی تایمر (پخش/مکس/توقف): `tooltip` داشته باشند.
- تایپوی متنی را اصلاح کن: `'مکس'` → `'مکث'` در `study_timer_sheet.dart`.

### K-91 🟡 پدینگ/حاشیهٔ جهت‌دار و اعلان‌های تکراری `Directionality`
**واقعیت فعلی:** در ماژول از `EdgeInsets.only(right: ..)` و `left:` استفاده شده که در RTL معنای معکوس دارد، و `Directionality(textDirection: TextDirection.rtl)` حدود هشت بار در ویجت‌های مختلف تکرار شده.

**تصمیم قطعی:** `EdgeInsetsDirectional.only(start:, end:)` و `AlignmentDirectional` در همه جا. یک `Directionality` در ریشهٔ اپ (یا از طریق `locale`) و حذف همهٔ اعلان‌های موضعی در ماژول. گیت: `grep -rn "Directionality(" lib/features/courses` خالی؛ `grep -rn "EdgeInsets.only(right:\|EdgeInsets.only(left:" lib/features/courses` خالی.

### K-92 🟠 رشته‌های فارسی در لایهٔ منطق و عدم وجود l10n
**واقعیت فعلی:** ماژول دوره‌ها عملاً صفر رشتهٔ استخراج‌شده دارد. `l10n.yaml`، `lib/l10n/app_fa.arb` و `app_en.arb` در پروژه وجود دارند و `docs/l10n_audit.md` هم هست. علاوه بر ویجت‌ها، رشتهٔ فارسی در لایهٔ منطق هم وجود دارد: `messageFa` (موتور جبران)، `reasonFa` (موتور تطبیقی)، و `'جلسه ${s.sessionNumber}'` در `lib/core/`.

**تصمیم قطعی:**
1. `docs/l10n_audit.md` و `lib/l10n/app_fa.arb` را بخوان و قرارداد نام‌گذاری کلیدها را درست تقلید کن.
2. همهٔ رشته‌های کاربرپسند ماژول دوره‌ها به `app_fa.arb` منتقل شوند (پیشوند کلید: `courses`). مقادیر پویا با placeholder تعریف شوند، نه الحاق رشته.
3. `app_en.arb` با ترجمهٔ واقعی انگلیسی پر شود — نه کپی فارسی.
4. `messageFa` و `reasonFa` از همهٔ کلاس‌های `logic/` حذف و با کد (`enum`) جایگزین شوند؛ نگاشت کد→متن در لایهٔ ویجت انجام شود.
5. ارقام همه با `RitmoNumber.toFa` (فاز ۰) نمایش داده شوند و تاریخ‌ها همه با `CourseDate.toJalaliDisplay`.

### K-93 🟠 تست گارد منبع کد
**تصمیم قطعی:** یک تست گارد بنویس که فایل‌های منبع را می‌خواند و موارد زیر را رد می‌کند. الگو: `test/prompt_036_source_guards_test.dart`.

| قاعده | دامنه |
|---|---|
| رشتهٔ حاوی حروف فارسی | `lib/core/**`، `lib/features/courses/logic/**`، `lib/features/courses/models/**` |
| `Color(0x` یا `Colors.` (جز `transparent`) | `lib/features/courses/**` |
| `debugPrint` | `lib/features/courses/**` |
| `.hashCode` | `lib/features/courses/**` |
| `shrinkWrap: true` | `lib/features/courses/**` |
| `Directionality(` | `lib/features/courses/**` |
| `EdgeInsets.only(right:` / `left:` | `lib/features/courses/**` |
| `fontSize:` عددی | `lib/features/courses/**` |
| `messageFa` / `reasonFa` | کل `lib/` |
| `onReorderItem` | کل `lib/` |
| `isCompleted = 1` | کل `lib/` |

تست باید در خطا شمارهٔ خط و مسیر فایل را چاپ کند تا قابل رفع باشد.

### گیت پذیرش فاز ۸
- تست گارد `K-93` سبز است.
- دو تست `textScaler: 2.0` سبز هستند.
- ماژول در تم روشن خوانا است (بازرسی دستی + گولدن در صورت وجود زیرساخت `test/golden/**`).
- `flutter gen-l10n` (یا مسیر معادل در پروژه) بدون خطا اجرا می‌شود و هر دو `.arb` مجموعهٔ کلید یکسان دارند.

---

## فاز ۹ — تست‌ها و تأیید نهایی

این فاز قابل حذف یا خلاصه شدن نیست. بیشتر باگ‌های این ماژول دقیقاً به این دلیل زنده مانده‌اند که پرمسئولیت‌ترین فایل ماژول (`courses_repository.dart`، ۳۹.۵ کیلوبایت) صفر تست دارد.

### K-94 🔴 فیکسچر دیتابیس واقعی برای مخزن
**واقعیت فعلی:** تست‌های موجود ماژول (`course_scheduler_test`، `course_models_test`، `course_energy_engine_test`، `course_timer_service_test`، `course_bugs_test`، `courses_engine_test`) همه روی توابع خالص یا مدل‌ها هستند. هیچ تستی به دیتابیس نمی‌رسد. دقیقاً به همین دلیل `isCompleted = 1`، `r['instructor']` و `energy_logs['level']` ماه‌ها زنده ماندند.

**تصمیم قطعی:**
1. اول `test/migration_test.dart` را بخوان و ببین پروژه چطور دیتابیس تست می‌سازد. اگر `sqflite_common_ffi` قبلاً در `dev_dependencies` هست، همان را به کار بگیر؛ وگرنه اضافه کن.
2. یک هلپر مشترک بساز: `test/courses/helpers/courses_db_fixture.dart` که دیتابیس in-memory را **با همان مسیر مایگریشن واقعی اپ** می‌سازد (نه با CREATE TABLE دستی در تست — این نکته بحرانی است، وگرنه تست، اشتباه نام ستون را تکرار می‌کند و باز هم مخفی می‌ماند).
3. سازنده‌های داده (`makeCourse`، `makeSession`) با مقادیر پیش‌فرض معقول داشته باش.
4. فیکسچر باید زمان را تزریق‌پذیر کند (هیچ تستی به `DateTime.now()` واقعی وابسته نباشد).

### K-95 🔴 تست‌های الزامی مخزن
حداقل موارد زیر در `test/courses/courses_repository_test.dart`:

| مورد | تأیید می‌کند |
|---|---|
| ساخت دوره با ۴۰ جلسه | تعداد ردیف، ترتیب `sessionNumber`، یگانگی شناسه‌ها (`K-11`) |
| دو بار ساخت دوره در همان میلی‌ثانیه | عدم تعارض کلید (`K-11`) |
| `reorderSessions` | عدم نقض ایندکس UNIQUE (`K-12`) |
| `completeSession` دو بار پشت سر هم | بازگشت `CourseMutationResult.noOp`، عدم انتشار رویداد دوم (`K-10`) |
| `completeSession` روی شناسهٔ ناموجود | `notFound`، عدم تغییر دیتابیس (`K-10`) |
| دورهٔ کاملاً ردشده | `CourseCompletionQuality.allSkipped`، عدم نمایش 🏆 (`K-28`) |
| دورهٔ متصل به هدف | `progressCache` از `GoalProgressCalculator` می‌آید و با حذف دوره تازه می‌شود (`K-29`، `K-70`) |
| کوتاه کردن دوره با جلسات تکمیل‌شده | خطای `CANNOT_SHRINK_BELOW_LOCKED` (`K-32`) |
| `targetEndDate` دسترس‌ناپذیر | خطای `TARGET_END_UNREACHABLE` با عدد پیشنهادی (`K-33`) |
| جلسات عقب‌افتاده در بازتوزیع | جابه‌جا نمی‌شوند مگر صریحاً خواسته شود (`K-34`) |
| ۱۵۰۰ شناسه در `IN` | بدون خطای SQLite (`K-35`) |
| `getSessionsForDateRange` | جلسات دورهٔ متوقف/بایگانی را برنمی‌گرداند (`K-36`) |
| `fromMap` با ردیف مخروب | بدون کرش، لاگ خطا (`K-39`) |
| دورهٔ متصل به هدف بایگانی‌شده | بدون کرش در دراپ‌داون (`K-07`) |
| حذف دوره | `pending_reminders` خالی + `cancelAlarm` برای هر یادآور (`K-70`) |
| دو جهش پشت سر هم | `syncCourseAlarms` فقط تفاوت‌ها را دوباره می‌چیند (`K-31`) |

### K-96 🔴 تست `CourseRegistrySource` روی دیتابیس واقعی
تستی که اگر نام ستونی در کوئری اشتباه باشد، **قرمز می‌شود**. پوشش: دورهٔ فعال، دورهٔ تکمیل‌شده، دورهٔ بایگانی‌شده با `includeArchived` در هر دو حالت، و شمارش که باید با لیست همخوان باشد (`K-06`، `K-72`).

### K-97 🔴 تست موتورهای تا امروز بدون تست
- `test/courses/course_catchup_engine_test.dart`: پلن‌های پیشنهادی، `weeksToCatchUp == null` در حالت `extraPerWeek == 0` (`K-60`)، کدهای دلیل به‌جای رشتهٔ فارسی.
- `test/courses/course_adaptive_engine_test.dart`: `evaluate` خالص است و هیچ نوشتنی در دیتابیس انجام نمی‌دهد؛ دورهٔ درون دورهٔ خنک‌شدن پیشنهاد نمی‌دهد؛ آستانه‌ها از `CourseLimits` خوانده می‌شوند (`K-61`).
- `test/courses/sm2_review_engine_test.dart`: زنجیرهٔ کامل مرور با کیفیت‌های `2`، `4`، `5` و فاصله‌های `1`، `6`، `~15`؛ سقف `ef` در `1.3`؛ قطع زنجیره در `understandingScore >= 4 && repetitions >= 3` (`K-58`).
- `test/courses/courses_ai_helper_test.dart`: سه مرحلهٔ `_parseSyllabusText` (لیست خالص، لیست درون `{"sessions": [...]}`، متن خط‌به‌خط)، محدودسازی `difficulty` در `1..5`، و رفتار در خروجی بی‌ربط AI (`K-65`، `K-66`). همهٔ کلیدهای `sessions|items|syllabus|outline|chapters` پوشش داده شوند.
- `test/courses/course_validation_test.dart`: همهٔ کدهای خطا، ورودی با ارقام فارسی (`K-08`)، و مرزهای `CourseLimits` (`K-38`).
- `test/courses/course_date_contract_test.dart`: `startOfFarsiWeek` در هر هفت روز هفته، `daysBetween` در مرز تغییر ساعت تهران، رفت‌وبرگشت `toDayKey`/`parseDayKey` (`K-02`).
- `test/courses/course_reminder_planner_test.dart`: پنجرهٔ ۱۴ روز/۲۰ مورد، همگام‌سازی تفاوتمحور، و شناسهٔ پایدار `rem_course_<sessionId>` (`K-30`، `K-31`).

### K-98 🔴 تست بازیابی تایمر
در `test/courses/course_timer_service_test.dart` موارد زیر اضافه شود:
- تایمری که ۱۲ ساعت پیش شروع شده و `updatedAt` آن ۴۵ دقیقه پس از شروع است → وضعیت `STALE`، زمان محاسبه‌شده ۴۵ دقیقه، **نه ۴۸۰** (`K-14`).
- شروع تایمر دوم با تایمر فعال → `CourseTimerConflictException`؛ با `force: true` → تایمر قبلی ذخیره می‌شود، نه حذف (`K-16`).
- `pauseTimer` با مقدار دروغین از فراخوان → مقدار محاسبه‌شدهٔ داخلی ملاک است (`K-17`).
- تایمر بیش از ۸ ساعت → سقف `CourseLimits.maxTimerSeconds` اعمال می‌شود.
- بستن شیت دیبریف بدون ذخیره → زمان مطالعه **از دست نمی‌رود** و تایمر در حالت مکث می‌ماند (`K-15`). این تست مهم‌ترین تست رگرسیون ماژول است.

### K-99 🟠 تست‌های ویجت
- `test/courses/create_course_sheet_test.dart`: ورود ارقام فارسی پذیرفته می‌شود (`K-08`)؛ هدف هفتگی بیش از تعداد روزهای انتخابی پیام واضح می‌دهد (`K-43`)؛ روز انتخابی صفر پیام `NO_PREFERRED_DAYS` می‌دهد و دکمهٔ ذخیره غیرفعال می‌شود (`K-47`)؛ پیش‌نمایش برنامه با خروجی ذخیره یکسان است (`K-84`).
- `test/courses/ai_syllabus_sheet_test.dart`: مسیر AI واقعاً AI را فراخوانی می‌کند (با دروازهٔ جعلی)؛ خطاهای تایپ‌دار رندر می‌شوند؛ جابه‌جایی درافت‌ها درست کار می‌کند و شماره‌گذاری دوباره انجام می‌شود (`K-65`، `K-66`).
- `test/courses/recovery_mode_sheet_test.dart`: شیت از دو مسیر قابل باز شدن است؛ پلن انتخابی **همان** پلنی است که اعمال می‌شود (رگرسیون مستقیم `K-59`)؛ هر سه پلن اثر واقعی در دیتابیس دارند.
- `test/courses/session_actions_sheet_test.dart`: هر اقدام، متد مخزن متناسب را صدا می‌زند؛ اقدامات غیرمجاز `disabled` هستند نه مخفی (`K-83`).
- `test/courses/courses_screen_test.dart`: حالت خطا با حالت خالی اشتباه نمی‌شود (`K-75`)؛ یک تپ فقط یک بارگذاری تریگر می‌کند.

### K-100 🔴 دو تست موجود که **رفتار غلط را تثبیت کرده‌اند**
این دو تست باید **عوض شوند**، نه اینکه کد مطابق آن‌ها نگه داشته شود:
1. `test/course_scheduler_test.dart` انتظار دارد وقتی `preferredDays` خالی است، جلسات روی روزهای پیاپی بروند. این رفتار با `K-47` در تضاد است. تست باید به انتظار خطای `NO_PREFERRED_DAYS` تغییر کند.
2. `test/courses_engine_test.dart` صریحاً `output.weeklyDoneSessions == 3` را با توضیح «در عین تکمیل‌شده بودن دوره» تأیید می‌کند — یعنی باگ `K-44` را به‌عنوان رفتار مطلوب قفل کرده. تست باید بر اساس جمعیت واحد (`K-44`) بازنویسی شود.

در هر دو مورد، در پیام کامیت و در گزارش نهایی صریحاً بنویس که تست قبلی رفتار باگ‌دار را تثبیت کرده بود. هیچ تست دیگری را برای سبز شدن بیلد حذف یا `skip` نکن.

### K-101 🔴 تأیید نهایی و گزارش
در پایان، این سه فرمان باید دقیقاً پاک باشند:
```bash
flutter analyze                                # ۰ error، ۰ warning، ۰ info
flutter test                                   # همه سبز
dart format --set-exit-if-changed lib test     # بدون تغییر
```

و جمع‌بندی گیت‌های grep — همه باید خروجی خالی داشته باشند:
```bash
grep -rn "isCompleted = 1" lib
grep -rn "'instructor'" lib
grep -rn "energy_logs" lib | grep "'level'"
grep -rn "\.hashCode" lib/features/courses
grep -rn "Color(0x" lib/features/courses
grep -rn "debugPrint" lib/features/courses
grep -rn "messageFa\|reasonFa" lib
grep -rn "onReorderItem" lib
grep -rn "CoursesEngine()" lib/features
grep -rn "shrinkWrap: true" lib/features/courses
grep -rn "?? 30\|?? 45" lib/features/courses lib/core/analytics/courses_engine.dart
grep -rn "Directionality(" lib/features/courses
grep -rn "catch (_) {}" lib/features/courses
```

**گزارش نهایی — دقیقاً یک فایل:** `docs/reports/COURSES_FIX_REPORT.md` با این ساختار:

```markdown
# گزارش اجرای پرامپت اصلاح ماژول دوره‌ها

## خلاصهٔ وضعیت
- تعداد موارد: X؛ انجام‌شده: Y؛ انجام‌نشده: Z
- flutter analyze: ...   flutter test: ...   dart format: ...

## جدول موارد
| شناسه | وضعیت | فایل‌های تغییریافته | تست‌های مربوطه | یادداشت |
|---|---|---|---|---|
| K-01 | ✅ | ... | ... | ... |

## تصمیمات انحرافی
هر جایی که مجبور شدی از دستور پرامپت منحرف شوی — با دلیل فنی.

## بدهی باقی‌مانده
مواردی که کشف کردی ولی در دامنهٔ این پرامپت نبودند.
```

### گیت پذیرش فاز ۹ (گیت نهایی پروژه)
- هر سه فرمان تأیید پاکند.
- همهٔ ۱۳ گیت grep خروجی خالی دارند.
- همهٔ گیت‌های فازهای ۰ تا ۸ دوباره اجرا و سبز شده‌اند (رگرسیون نداریم).
- `docs/reports/COURSES_FIX_REPORT.md` کامل پر شده و هیچ ردیف جدولی خالی نیست.
- `docs/DB_TECH_DEBT.md` با ستون‌های رزروشده (`activityType`) به‌روز شده.
- هیچ فایلی در `lib/features/courses/logic/` بدون مصرف‌کنندهٔ خارج از تست نیست (تست گارد `K-67`).

---

## ۱۰. قواعد کامیت

- یک کامیت به ازای هر فاز، نه به ازای هر مورد و نه یک کامیت غول در انتها.
- قالب: `fix(courses): phase N — <خلاصه> [K-xx, K-yy, ...]`
- پیام کامیت باید فهرست شناسه‌های پوشش‌داده‌شده و هر انحرافی از پرامپت را داشته باشد.
- پیش از هر کامیت، گیت پذیرش همان فاز باید سبز باشد. کامیت روی بیلد قرمز ممنوع است.

---

## ۱۱. تکرار قاعدهٔ اصلی (مهم‌ترین بخش این فایل)

این فایل **نقشهٔ پیاده‌سازی تمام‌شده** است.

- مادهٔ ۲ فایل `.agents/AGENTS.md` (سه دور اجباری پیش‌نویس → ارزیابی → بازنویسی نقشه) **برای این پرامپت لغو شده است.** مادهٔ ۱ (تحلیل عمیق پیش از تغییر) و مادهٔ ۳ (خروجی صفر در `flutter analyze`) معتبر و الزامی هستند.
- فایل نقشه، فایل برنامه، فایل تحلیل، فایل پیش‌نویس یا فایل ارزیابی **نساز**. تنها مستندات مجاز: `docs/reports/COURSES_FIX_REPORT.md` و به‌روزرسانی `docs/DB_TECH_DEBT.md`.
- ترتیب فازها را عوض نکن و فازی را جا نینداز.
- هیچ موردی را «خارج از دامنه» اعلام نکن. اگر موردی را نمی‌توانی انجام دهی، در جدول گزارش با دلیل فنی دقیق علامت بزن و به فاز بعد برو.
- برای هر مورد، پیش از تغییر، فایل‌های مرتبط را کامل بخوان. هیچ تغییری را حدسی انجام نده.
- تصمیمات این فایل قطعی هستند. اگر راه بهتری دیدی، پیاده کن و در بخش «تصمیمات انحرافی» گزارش کن — ولی اول کار را تمام کن.

معیار پایان کار: هر ۱۰۱ مورد (`K-01` تا `K-101`) در جدول گزارش وضعیت قطعی دارد، هر ۱۰ گیت فاز سبز است، و سه فرمان تأیید نهایی پاکند.
