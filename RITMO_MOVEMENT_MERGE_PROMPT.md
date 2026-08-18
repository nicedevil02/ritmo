# پرامپت اجرایی: بازسازی، رفع باگ و تلفیق ماژول «حرکت مرکزی» و «ورزش تکمیلی» — پروژهٔ ریتمو

> **مخاطب:** ایجنت کدنویس (AI coding agent) روی مخزن `nicedevil02/ritmo`
> **دامنهٔ کار:** `lib/features/movement/**` + `lib/features/supplementary_sports/**` + جدول‌ها و سیم‌کشی‌های مرتبط در `lib/core/**`
> **خروجی مورد انتظار:** کد کارکرد، مهاجرت دیتابیس بدون از دست رفتن داده، تست سبز، `flutter analyze` با صفر خطا و صفر هشدار

---

## ۰. قواعد اجرای اجباری — قبل از نوشتن حتی یک خط کد بخوان

این بخش مهم‌ترین بخش فایل است. تخطی از هر بند = کار مردود.

**۰-۱ — نقشهٔ پیاده‌سازی ننویس.**
این فایل، *خودش* نقشهٔ پیاده‌سازی است. تو حق نداری نقشه، رودمپ، پلن، «تحلیل اولیه»، «طرح پیشنهادی»، یا هر سند برنامه‌ریزی دیگری تولید کنی. هیچ فایل `PLAN.md`، `ROADMAP.md`، `IMPLEMENTATION_PLAN.md`، `ANALYSIS.md` یا مشابه نساز. مستقیم برو سراغ فاز ۰ و کد بزن.

**۰-۲ — بند ۲ فایل `.agents/AGENTS.md` برای این تسک لغو است.**
در `.agents/AGENTS.md` بندی وجود دارد که تو را ملزم می‌کند سه چرخهٔ اجباری «پیش‌نویس ← ارزیابی ← بازنویسی» روی نقشهٔ پیاده‌سازی انجام دهی. **این بند برای این تسک صراحتاً باطل اعلام می‌شود.** آن سه چرخه را انجام نده. آن بند در این تسک قابل استناد نیست.
دو بند دیگر همان فایل **به قوت خود باقی است**:
- بند «تحلیل عمیق پیش از تغییر» — هر فایلی را که لمس می‌کنی، اول کامل بخوان.
- بند «`flutter analyze` باید صفر خطا و صفر هشدار بدهد» — بدون استثنا.

**۰-۳ — ترتیب فازها قفل است.**
فاز `N+1` را شروع نکن مگر آنکه دروازهٔ پذیرش فاز `N` سبز شده باشد. هر فاز یک «دروازهٔ پذیرش» صریح دارد. اجرای موازی فازها ممنوع.

**۰-۴ — هر شناسهٔ `M-xx` باید در گزارش پایانی وضعیت قطعی داشته باشد.**
در انتهای کار جدولی بساز با ستون‌های `شناسه | عنوان | وضعیت | فایل‌های تغییر یافته | تست مربوطه`. وضعیت فقط یکی از این سه: `انجام شد` / `منتفی شد (با دلیل فنی)` / `مسدود شد (با دلیل فنی و مسیر رفع)`. «در دست بررسی» یا «بعداً» وضعیت معتبر نیست.

**۰-۵ — بدون داده‌سازی.**
هیچ عدد، درصد، نرخ، میانگین یا برچسبی را حدس نزن و هاردکد نکن. اگر داده کافی نیست، سیستم باید صادقانه بگوید «داده کافی نیست» — نه اینکه عددی جعلی نشان دهد. این قاعده مستقیماً به `M-74`، `M-76`، `M-62` و `M-55` مربوط است.

**۰-۶ — مهاجرت داده، نه پاک کردن داده.**
هیچ جدولی را بدون مهاجرت داده حذف نکن. هیچ `DROP TABLE` بدون کپی قبلی مجاز نیست. کاربر واقعی روی نسخهٔ فعلی داده دارد.

**۰-۷ — `catch (_) {}` ممنوع.**
هیچ بلوک `catch` خالی، هیچ `catch (_) {}`، و هیچ خطای بلعیده‌شده‌ای در کد نهایی نباشد. هر `catch` باید یا خطا را با `RitmoLog` ثبت کند و حالت قابل‌مشاهده بسازد، یا خطا را بالا بفرستد.

**۰-۸ — `debugPrint` ممنوع.** فقط `RitmoLog`.

**۰-۹ — رشتهٔ فارسی هاردکد در ویجت ممنوع.** همه چیز از `MovementStrings` یا `app_fa.arb`/`app_en.arb`.

**۰-۱۰ — رنگ و اندازهٔ فونت هاردکد ممنوع.** نه `Color(0x...)`، نه `Colors.*`، نه `fontSize: <عدد>`. فقط `context.colors` / `RitmoColors` / `RitmoTextStyles`.

**۰-۱۱ — هر فاز یک کامیت مستقل.** فرمت کامیت در بخش ۱۰ آمده.

**۰-۱۲ — سه فرمان تأیید بعد از هر فاز:**
```bash
flutter analyze                                   # باید 0 error, 0 warning
flutter test                                      # باید کامل سبز
dart format --set-exit-if-changed lib test        # باید بدون تغییر
```
در فاز ۸ اضافه می‌شود: `flutter gen-l10n`.

**۰-۱۳ — دامنهٔ مالکیت فایل.**
تو مالک این مسیرها هستی و اجازهٔ تغییر گسترده داری:
- `lib/features/movement/**`
- `lib/features/supplementary_sports/**`
- `lib/core/database/schema/tables/movement_tables.dart`
- `lib/core/database/schema/tables/supplementary_sports_tables.dart`
- `lib/core/database/schema/tables/sports_tables.dart`
- `lib/core/database/migrations/**` (فقط افزودن مهاجرت جدید + ثبت در رجیستری)
- `lib/l10n/app_fa.arb`, `lib/l10n/app_en.arb`
- `test/**` (فقط افزودن/به‌روزرسانی تست‌های مرتبط)

خارج از این مسیرها فقط تغییر حداقلی و ضروری برای سیم‌کشی (مثلاً ثبت منبع agenda یا حذف یک import مرده) مجاز است و باید در گزارش پایانی صریحاً فهرست شود.

**۰-۱۴ — ممنوعیت مطلق.**
- تغییر ماژول‌های `cycle`، `courses`، `nutrition`، `habits` ممنوع است مگر برای حذف یک import شکسته.
- تغییر `analysis_options.yaml` برای خفه کردن هشدار ممنوع است.
- افزودن `// ignore:` یا `// ignore_for_file:` ممنوع است مگر با توضیح فنی یک‌خطی در همان خط و ثبت در گزارش.
- افزودن پکیج جدید به `pubspec.yaml` ممنوع است مگر آنکه در همین فایل صراحتاً خواسته شده باشد.

---

## ۰-۲. تصمیم‌های قطعی معماری — این‌ها قابل مذاکره نیستند

قبل از فازها، این هفت تصمیم را به‌عنوان حقیقت پایه بپذیر. کل کار روی این‌ها سوار است.

**تصمیم ۱ — «حرکت مرکزی» تنها مالک دامنهٔ ورزش است.**
`lib/features/movement/` ماژول قانونی (canonical) است. `lib/features/supplementary_sports/` در پایان کار به‌عنوان یک فیچرِ مستقل **وجود نخواهد داشت**. هر چیز ارزشمندی از آن به `movement` منتقل می‌شود و باقی حذف می‌گردد.

**تصمیم ۲ — `AgendaDomain.sport` دقیقاً یک منبع دارد.**
در پایان کار فقط و فقط `MovementAgendaSource` آیتم با دامنهٔ `sport` تولید می‌کند. `SsAgendaSource` حذف می‌شود و منطق مفیدش (نسخه‌ها، روتین‌های `fitness`) داخل `MovementAgendaSource` جذب می‌شود.

**تصمیم ۳ — یک قرارداد واحد روز هفته.**
یک فایل `lib/features/movement/domain/movement_date_contract.dart` ساخته می‌شود که تنها مرجع تبدیل روز هفته و تاریخ است. هیچ‌جای دیگر کد حق ندارد `(x.weekday ± n) % 7` بنویسد.

**تصمیم ۴ — تاریخِ تقویمی همیشه محلی است.**
هر `dateIso` (یعنی `YYYY-MM-DD`) نمایندهٔ روز تقویمی **محلی کاربر** است. هیچ‌جا از `DateTime.now().toUtc().toIso8601String().substring(0, 10)` برای ساختن `dateIso` استفاده نمی‌شود. زمان‌مُهرها (`createdAt`، `at`، `loggedAt`) می‌توانند UTC باشند، اما کلید روز هرگز.

**تصمیم ۵ — یک کارخانهٔ شناسه.**
تمام شناسه‌ها از `RitmoIdFactory` (مبتنی بر uuid) می‌آیند. `hashCode`، `millisecondsSinceEpoch`، `microsecondsSinceEpoch` و الحاق رشته‌ای برای ساخت شناسه **ممنوع** است — تنها استثنا شناسه‌های عمداً idempotent (مثل `wlog_ss_<prescriptionId>`) که باید با کامنت صریح توجیه شوند.

**تصمیم ۶ — یک لایهٔ حالت.**
هر کنترلر ارائه‌ای یک `sealed class` حالت دارد: `Loading` / `Ready(data)` / `Empty(reason)` / `Error(code)`. رشتهٔ خام استثنای Dart هرگز به UI نمی‌رسد.

**تصمیم ۷ — یک سیستم طراحی.**
`RitmoTheme` تنها سیستم طراحی است. `supplementary_sports_theme.dart` حذف می‌شود.

---

## فاز ۰ — قراردادهای پایه

هدف: قبل از دست زدن به منطق، زیرساخت مشترکی بساز که فازهای بعد روی آن سوار شوند. در پایان این فاز هیچ رفتاری برای کاربر تغییر نکرده، اما پایه‌ها یکسان شده‌اند.

### M-01 — چهار پیاده‌سازی متفاوت و ناسازگار از «روز هفته»

**واقعیت فعلی:** دست‌کم چهار فرمول مختلف برای تبدیل روز هفتهٔ Dart به روز هفتهٔ ریتمو در کد وجود دارد:

1. در `movement_center_controller.dart` → `_getSaturdayOfWeek`:
```dart
final dayOfWeekOffset = (date.weekday - 6 + 7) % 7;
```
2. در `movement_planning_service.dart` → `getRitmoWeekday`:
```dart
int getRitmoWeekday(DateTime date) => (date.weekday + 1) % 7;
```
3. در `ss_program_calendar.dart` → `ritmoDayToLegacySsDay(date.weekday)` — نگاشت سومی مبتنی بر شنبه.
4. در `ss_agenda_source.dart` → `_isScheduledOn` که مستقیماً `date.weekday` (یعنی ۱=دوشنبه تا ۷=یکشنبه) را با محتوای ستون `routine_schedules.daysOfWeek` مقایسه می‌کند، در حالی که کامنتِ مستندسازی *در همان فایل* می‌گوید «۱=دوشنبه تا ۷=یکشنبه» و رشتهٔ پیش‌فرض `'6,7,1,2,3,4,5'` است. یعنی داخل یک فایل دو قرارداد متضاد کنار هم زندگی می‌کنند.

علاوه بر این، `changeWeek` در کنترلر عبارت `(_selectedDate.weekday - 6 + 7) % 7` را دوباره درجا بازنویسی کرده — نسخهٔ کپی‌شدهٔ چهارم از همان فرمول.

**نتیجهٔ عملی:** یک جلسه که برای «سه‌شنبه» برنامه‌ریزی شده، بسته به اینکه از کدام مسیر خوانده شود، ممکن است روی دو روز مختلف نمایش داده شود. این ریشهٔ بخش بزرگی از باگ‌های «جلسه‌ام گم شد» است.

**تصمیم قطعی:** فایل `lib/features/movement/domain/movement_date_contract.dart` بساز با این محتوا (امضاها الزامی، پیاده‌سازی داخلی با خودت):

```dart
/// تنها مرجع تبدیل تاریخ و روز هفته در دامنهٔ حرکت.
/// قرارداد ریتمو: 0 = شنبه، 1 = یکشنبه، ... ، 6 = جمعه
abstract final class MovementDate {
  /// روز هفتهٔ ریتمو (0=شنبه .. 6=جمعه) از یک DateTime محلی
  static int ritmoWeekday(DateTime local);

  /// شنبهٔ همان هفتهٔ تقویمی (نیمه‌شب محلی)
  static DateTime saturdayOfWeek(DateTime local);

  /// کلید روز تقویمی محلی به شکل YYYY-MM-DD — هرگز UTC
  static String toDateIso(DateTime local);

  /// تبدیل معکوس: کلید روز به DateTime نیمه‌شب محلی
  static DateTime fromDateIso(String dateIso);

  /// نیمه‌شب محلی همان روز
  static DateTime startOfDay(DateTime local);

  /// تعداد روز تقویمی بین دو تاریخ، مصون از تغییر ساعت تابستانی
  static int calendarDaysBetween(DateTime a, DateTime b);

  /// نگاشت روز ریتمو به روز میراثی ss (برای خواندن دادهٔ قدیمی در مهاجرت)
  static int toLegacySsDay(int ritmoWeekday);

  /// نگاشت معکوس، فقط برای مهاجرت
  static int fromLegacySsDay(int legacyDay);
}
```

سپس **تمام** موارد زیر را به این کلاس هدایت کن: `_getSaturdayOfWeek`، `changeWeek`، `goToThisWeek`، `getRitmoWeekday`، `_isScheduledOn`، `ritmoDayToLegacySsDay`، `cycleWeekFor`، و هر جای دیگری که عبارت `weekday` در آن با عدد جمع یا تفریق می‌شود.

**معیار پذیرش:**
- `grep -rn "weekday - 6\|weekday + 1) % 7\|weekday % 7" lib/features/movement lib/features/supplementary_sports` هیچ نتیجه‌ای برنگرداند.
- تست جدولی `test/unit/movement/movement_date_contract_test.dart` که برای هر هفت روز هفته، هم `ritmoWeekday` و هم `saturdayOfWeek` و هم رفت‌وبرگشت `toDateIso`/`fromDateIso` را تأیید کند.

### M-02 — کلید روز تقویمی با UTC ساخته می‌شود و جلسات عصر به فردا می‌افتند

**واقعیت فعلی:** الگوی `DateTime.now().toUtc()` و سپس `.toIso8601String().substring(0, 10)` در سراسر ماژول برای ساختن `dateIso` استفاده می‌شود — از جمله در `MovementSessionService.finishSession` و در `MovementAgendaSource.load`.

منطقهٔ زمانی کاربر `Asia/Tehran` با اختلاف `+03:30` است. یعنی هر رویدادی که بعد از **۲۰:۳۰ به وقت تهران** ثبت شود، در UTC روز بعد است و به‌اشتباه به فردا نسبت داده می‌شود. کاربری که ساعت ۲۱:۰۰ تمرین می‌کند، تمرینش در تقویم فردا ظاهر می‌شود، `adherence` امروزش صفر می‌ماند و «روزهای فعال»ش اشتباه شمرده می‌شود.

**تصمیم قطعی:** هر جایی که خروجی به یک کلید `YYYY-MM-DD` تبدیل می‌شود، از `MovementDate.toDateIso(local)` استفاده کن. زمان‌مُهرهای دقیق (`createdAt`، `updatedAt`، `at`، `startedAt`) می‌توانند UTC بمانند، اما باید به‌صورت ISO-8601 کامل با پسوند منطقه ذخیره شوند تا مقایسه‌شان معنادار باشد.

**معیار پذیرش:**
- `grep -rn "toUtc().toIso8601String().substring" lib/features/movement lib/features/supplementary_sports` خالی باشد.
- تست: جلسه‌ای که در `2026-08-18T21:30:00+03:30` تمام می‌شود باید `dateIso == '2026-08-18'` بگیرد، نه `'2026-08-19'`.
- تست مرز تغییر ساعت: `calendarDaysBetween` روی بازهٔ شامل تغییر ساعت باید عدد صحیح بدهد.

### M-03 — شناسه‌ها از `hashCode` و `millisecondsSinceEpoch` ساخته می‌شوند و تصادم می‌کنند

**واقعیت فعلی:** در `MovementSessionService`:
```dart
final id = 'live_${now.millisecondsSinceEpoch}_${activityKindId.hashCode.abs()}';
...
final logId = 'log_${now.millisecondsSinceEpoch}_${session.activityKindId.hashCode.abs()}';
...
final eventId = 'evt_${now.millisecondsSinceEpoch}_${type.name}';
```
و در `MovementPlanningService.createPlan`:
```dart
final occId = 'occ_${DateTime.now().microsecondsSinceEpoch}_${formatIso(targetDate)}';
final schId = 'sch_${DateTime.now().microsecondsSinceEpoch}_${schedule.weekday}';
```

سه مشکل هم‌زمان:
1. `String.hashCode` در Dart بین اجراهای مختلف برنامه پایدار نیست و تضمینی برای یکتایی ندارد.
2. دو رویداد از یک نوع در یک میلی‌ثانیه شناسهٔ یکسان می‌گیرند. چون `recordEvent` با `ConflictAlgorithm.replace` می‌نویسد، یکی از دو رویداد **بی‌صدا نابود می‌شود**.
3. `pauseSession` و `resumeSession` رویداد را **بدون** `conflictAlgorithm` درج می‌کنند؛ همان تصادم آن‌جا به‌جای بلعیده‌شدن، استثنا پرتاب می‌کند و جلسهٔ زندهٔ کاربر می‌شکند.

**تصمیم قطعی:** تمام تولید شناسه به `RitmoIdFactory` منتقل شود. متدهای لازم را اضافه کن: `movementOccurrence()`، `movementSession()`، `movementEvent()`، `movementLog()`، `movementTemplate()`، `movementSchedule()`، `movementSetLog()`. همه مبتنی بر uuid v4.

**معیار پذیرش:** `grep -rn "hashCode\|millisecondsSinceEpoch\|microsecondsSinceEpoch" lib/features/movement` هیچ موردی در مسیر تولید شناسه نشان ندهد. تست: هزار بار فراخوانی پیاپی `RitmoIdFactory.movementEvent()` در یک حلقهٔ تنگ باید هزار شناسهٔ یکتا بدهد.

### M-04 — `debugPrint` به‌جای لاگر پروژه برای خطاهای واقعی

**واقعیت فعلی:** در `ss_agenda_source.dart` حدود هشت بار و در `ss_week_resolver.dart` با الگوی `debugPrint('[ss] ss_week_resolver.dart: $e')` خطاهای واقعی چاپ می‌شوند. `debugPrint` در بیلد ریلیز عملاً بی‌اثر است، پس این خطاها در دست کاربر واقعی **کاملاً نامرئی** هستند.

**تصمیم قطعی:** همه به `RitmoLog` با سطح مناسب (`warning` / `error`) و برچسب ماژول `movement` منتقل شوند.

**معیار پذیرش:** `grep -rn "debugPrint" lib/features/movement lib/features/supplementary_sports` خالی.

### M-05 — `MovementStrings` وجود دارد اما دور زده می‌شود

**واقعیت فعلی:** فایل `lib/features/movement/presentation/common/movement_strings.dart` با حجم حدود ۳۳ کیلوبایت وجود دارد و رشته‌ها را متمرکز کرده — ولی `movement_center_screen.dart` رشته‌های فارسی را مستقیم می‌نویسد، از جمله:
```dart
'جلسه‌ای برای این روز تنظیم نشده'
'برای ثبت تمرین یا برنامه‌ریزی، دکمهٔ «افزودن فعالیت» پایین را لمس کنید.'
```
یعنی زحمت متمرکزسازی کشیده شده ولی رعایت نمی‌شود.

**تصمیم قطعی:** در فاز ۰ فقط یک گاردِ تست بساز که این تخلف را قابل تشخیص کند (فهرست تخلف‌ها را چاپ کند و در حالت `allowList` فعلی سبز بماند). رفع کامل در فاز ۸ انجام می‌شود؛ در فاز ۸ فهرست مجاز خالی می‌شود.

### M-06 — رشتهٔ خام استثنای Dart مستقیم روی صفحهٔ کاربر می‌نشیند

**واقعیت فعلی:** در `MovementCenterController`:
```dart
catch (e) {
  _errorMessage = e.toString();
}
```
و در صفحه:
```dart
ErrorBlock(message: _controller.errorMessage!)
```
یعنی کاربر فارسی‌زبان چیزی مثل `DatabaseException(no such column: isCompleted) sql 'SELECT ...'` می‌بیند.

**تصمیم قطعی:** `enum MovementErrorCode { database, notFound, conflict, permission, unknown }` بساز. کنترلر استثنا را به کد نگاشت می‌کند، پیام کاربرپسند از `MovementStrings` می‌آید، و متن فنی فقط به `RitmoLog` می‌رود. `ErrorBlock` فقط `MovementErrorCode` می‌گیرد، نه `String`.

**معیار پذیرش:** `ErrorBlock` هیچ پارامتری از نوع `String message` نداشته باشد. تست ویجت: با خطای دیتابیس شبیه‌سازی‌شده، هیچ‌جای درخت ویجت رشتهٔ `Exception` یا `sql` رندر نشود.

### M-07 — گاردِ سراسری علیه `catch (_) {}`

**تصمیم قطعی:** در همین فاز فایل تست `test/unit/movement/movement_source_guards_test.dart` را بساز، با الگوبرداری از `test/prompt_036_source_guards_test.dart` موجود در مخزن. این تست باید در تمام فایل‌های `lib/features/movement/**` (و در فاز ۲ به بعد، بازماندهٔ `supplementary_sports`) این الگوها را ممنوع کند:

| الگو | دلیل | فازی که باید صفر شود |
|---|---|---|
| `catch (_) {}` و `catch (e) {}` خالی | بلعیدن خطا | ۱ |
| `debugPrint(` | لاگ نامرئی در ریلیز | ۰ |
| `.hashCode` در ساخت شناسه | تصادم شناسه | ۰ |
| `millisecondsSinceEpoch` در ساخت شناسه | تصادم شناسه | ۰ |
| `toUtc().toIso8601String().substring` | جابه‌جایی روز | ۰ |
| `Color(0x` | دور زدن تم | ۸ |
| `Colors.` | دور زدن تم | ۸ |
| `fontSize:` با عدد ثابت | دور زدن تایپوگرافی | ۸ |
| `Directionality(` دستی | شکستن RTL سراسری | ۸ |
| `EdgeInsets.only(left:` / `right:` | شکستن RTL | ۸ |
| `firstWhere(` بدون `orElse` | استثنای غیرمنتظره | ۱ |
| رشتهٔ فارسی داخل ویجت | دور زدن l10n | ۸ |

تست باید در هر فاز فهرست مجاز (`allowList`) کوچک‌تر شود و در پایان فاز ۹ **کاملاً خالی** باشد.

### M-08 — لایهٔ ارائه مستقیماً سرویس می‌سازد؛ هیچ تزریق وابستگی وجود ندارد

**واقعیت فعلی:** `MovementCenterScreen` مستقیماً `MovementPlanningService()`، `MovementLogService()`، `MovementOccurrenceService()` و حتی یک `MovementSessionService()` تازه را درجا داخل هندلر «دور انداختن جلسه» می‌سازد. نتیجه: هر نمونه کش مستقل خودش را دارد (به `M-52` نگاه کن)، تست‌پذیری صفر است، و هیچ راهی برای mock کردن نیست.

**تصمیم قطعی:** یک `MovementServiceLocator` سبک (یا استفاده از الگوی DI موجود پروژه اگر هست) بساز که نمونه‌های singleton سرویس‌ها را نگه دارد. صفحه‌ها و شیت‌ها سرویس را از کنترلر یا از locator می‌گیرند، هرگز `new` نمی‌کنند.

**معیار پذیرش:** `grep -rn "Service()" lib/features/movement/presentation` هیچ نتیجه‌ای ندهد.

### 🚦 دروازهٔ پذیرش فاز ۰

- [ ] `movement_date_contract.dart` ساخته شده و تمام محاسبات روز هفته و کلید روز از آن می‌گذرد.
- [ ] `RitmoIdFactory` متدهای حرکت را دارد و هیچ شناسه‌ای از `hashCode`/`epoch` ساخته نمی‌شود.
- [ ] `debugPrint` صفر است.
- [ ] `MovementErrorCode` وجود دارد و `ErrorBlock` رشتهٔ خام نمی‌پذیرد.
- [ ] `movement_source_guards_test.dart` وجود دارد و سبز است.
- [ ] `MovementServiceLocator` وجود دارد و لایهٔ ارائه سرویس نمی‌سازد.
- [ ] سه فرمان تأیید سبز.

---

## فاز ۱ — کلاس فاجعه: خرابی خاموش دیتابیس و از دست رفتن داده

هدف: قبل از هر بازسازی معماری، خون‌ریزی را بند بیاور. موارد این فاز همین الان در دست کاربر واقعی دارند داده خراب می‌کنند.

### M-09 🔥 — دو تعریف متضاد و رقیب از جدول `movement_session_events`

**این بدترین باگ کل ماژول است. اول این را درست کن.**

**واقعیت فعلی:** دو جای مختلف در پروژه، جدولی با **دقیقاً همین نام** و **دو اسکیمای ناسازگار** می‌سازند، هر دو با `CREATE TABLE IF NOT EXISTS`:

در `lib/core/database/schema/tables/movement_tables.dart`:
```sql
CREATE TABLE IF NOT EXISTS movement_session_events (
  id TEXT PRIMARY KEY,
  sessionId TEXT NOT NULL,
  type TEXT NOT NULL,
  payloadJson TEXT,
  at TEXT NOT NULL          -- متنی / ISO-8601
)
```

در `lib/core/database/schema/tables/supplementary_sports_tables.dart` → `ensureLiveMovementSessionTables`:
```sql
CREATE TABLE IF NOT EXISTS movement_session_events (
  id TEXT PRIMARY KEY,
  sessionId TEXT NOT NULL,
  type TEXT NOT NULL,
  at INTEGER NOT NULL,      -- عددی / epoch millis
  dataJson TEXT
)
```

**چرا فاجعه است:** `IF NOT EXISTS` یعنی هر کدام که زودتر اجرا شود برنده می‌شود و دومی **بدون هیچ خطایی رد می‌شود**. پس:
- اگر نسخهٔ SS زودتر بسازد، `MovementSessionService.recordEvent` که `payloadJson` می‌نویسد با خطای `no such column: payloadJson` می‌شکند — یا بدتر، اگر در مسیری با `catch` باشد، رویداد بی‌صدا گم می‌شود.
- اگر نسخهٔ Movement زودتر بسازد، `MovementRepository.upsertEventInTransaction` که `dataJson` و `at` عددی می‌نویسد می‌شکند.
- و از همه بدتر: ستون `at` در یکی `TEXT` و در دیگری `INTEGER` است. چون SQLite تایپ را سخت‌گیرانه اعمال نمی‌کند، ممکن است بدون خطا بنویسد و بعد `ORDER BY at` روی دادهٔ مخلوط، ترتیب رویدادهای جلسه را به‌هم بریزد — یعنی محاسبهٔ مدت مکث (`accumulatedPauseMs`) اشتباه و مدت جلسه بی‌معنا می‌شود.

**تصمیم قطعی:**
1. نسخهٔ قانونی `MovementTables` است، اما با اسکیمای نهایی زیر (اتحاد دو نسخه):
```sql
CREATE TABLE IF NOT EXISTS movement_session_events (
  id          TEXT PRIMARY KEY,
  sessionId   TEXT NOT NULL,
  type        TEXT NOT NULL,
  payloadJson TEXT,
  atUtc       TEXT NOT NULL,          -- همیشه ISO-8601 کامل با پسوند منطقه
  atEpochMs   INTEGER NOT NULL        -- همیشه epoch millis برای مرتب‌سازی قطعی
);
CREATE INDEX IF NOT EXISTS idx_mse_session ON movement_session_events(sessionId, atEpochMs);
```
2. `SupplementarySportsTables.ensureLiveMovementSessionTables` دیگر این جدول را **نمی‌سازد**.
3. در مهاجرت فاز ۲، جدول موجود را با `PRAGMA table_info(movement_session_events)` بازرسی کن، هر دو شکل ممکن را بخوان و به اسکیمای جدید مهاجرت بده (`payloadJson` یا `dataJson` → `payloadJson`؛ `at` متنی یا عددی → هر دو ستون `atUtc` و `atEpochMs`).

**معیار پذیرش (الزامی):** تست `test/unit/movement/schema_collision_guard_test.dart` که تمام فایل‌های `lib/core/database/**` را می‌خواند، هر `CREATE TABLE` را استخراج می‌کند، و تأکید می‌کند **هیچ نام جدولی دو بار تعریف نشده باشد**. این تست باید برای کل پروژه اجرا شود نه فقط حرکت — اگر جاهای دیگری هم تخطی دارند، فهرستشان را در گزارش بنویس و فقط موارد دامنهٔ خودت را رفع کن؛ بقیه را در `allowList` موقت با کامنت `TODO(M-09)` قرار بده.

### M-10 🔥 — تمام ساخت جداول نسخه‌نویسی در `try {} catch (_) {}` بلعیده می‌شود

**واقعیت فعلی:** در `supplementary_sports_tables.dart`، همهٔ بدنهٔ `ensurePrescriptionTables` در یک `try { ... } catch (_) {}` پیچیده شده. داخل این بلوک این جداول ساخته می‌شوند: `ss_session_prescription`، `ss_muscle_group` (با ۱۲ ردیف seed)، `station_bundles`، `ss_plan_schedule`، `ss_exercise_pr`، `ss_session_set_log`، `movement_budget`، `movement_pr`. همین الگو در `ensureLiveMovementSessionTables` هم تکرار شده.

**نتیجهٔ عملی:** اگر ساخت یک جدول یا ایندکس شکست بخورد — مثلاً به دلیل همان تصادم `M-09` یا محدودیت دیسک — اپلیکیشن **با خیال راحت بالا می‌آید** و فقط وقتی کاربر وارد صفحه می‌شود، صفحهٔ خالی یا خطای خام می‌بیند — بدون هیچ لاگی برای تشخیص علت.

**تصمیم قطعی:** هر `catch (_) {}` در مسیر ساخت اسکیما حذف می‌شود. ساخت اسکیما باید در صورت شکست، خطا را بالا بفرستد تا مسیر مهاجرت بتواند تصمیم بگیرد. فقط در مورد عملیات ذاتاً idempotent مثل `safeAddColumn` که ممکن است ستون قبلاً وجود داشته باشد، `catch` مجاز است و آن هم باید فقط خطای «duplicate column» را فیلتر کند و بقیه را بالا بفرستد.

### M-11 — `SportsTables` بدون `IF NOT EXISTS` جدول می‌سازد

**واقعیت فعلی:** در `sports_tables.dart` پنج جدول اول (`workout_logs`، `workout_split_days`، `workout_recovery_logs`، `exercises_library`، `workout_set_logs`) با `CREATE TABLE` ساده و بدون `IF NOT EXISTS` ساخته می‌شوند، در حالی که بقیهٔ پروژه از `IF NOT EXISTS` استفاده می‌کند. این یعنی هر فراخوانی دوم (مثلاً در مسیر تعمیر یا بازیابی) پرتاب می‌کند.

**تصمیم قطعی:** همه به `CREATE TABLE IF NOT EXISTS` تبدیل شوند. معیار: `grep -n "CREATE TABLE " lib/core/database/schema/tables/` هیچ موردی بدون `IF NOT EXISTS` نداشته باشد.

### M-12 — `startSession` هیچ گاردی برای جلسهٔ فعال قبلی ندارد

**واقعیت فعلی:** `MovementSessionService.startSession` مستقیماً یک ردیف جدید در `movement_live_sessions` درج می‌کند بدون اینکه بپرسد آیا جلسه‌ای با وضعیت `active` یا `paused` وجود دارد. همزمان، جدول `movement_live_sessions` هیچ ایندکس یکتایی محافظی ندارد — در حالی که نسخهٔ SS یعنی `movement_sessions` **دقیقاً همین محافظ را دارد**:
```sql
CREATE UNIQUE INDEX idx_movement_sessions_active
  ON movement_sessions(status) WHERE status IN ('ACTIVE','PAUSED')
```
یعنی ماژول قدیمی این را حل کرده بود و ماژول جدید پس‌رفت کرده است.

**نتیجهٔ عملی:** کاربر می‌تواند چند جلسهٔ زندهٔ هم‌زمان داشته باشد. بنر «جلسهٔ در حال اجرا» یکی از آن‌ها را نشان می‌دهد و بقیه برای همیشه در دیتابیس زنده می‌مانند.

**تصمیم قطعی:**
1. ایندکس یکتایی جزئی روی `movement_live_sessions` بساز:
```sql
CREATE UNIQUE INDEX IF NOT EXISTS idx_movement_live_sessions_active
  ON movement_live_sessions(status) WHERE status IN ('active','paused');
```
2. `startSession` قبل از درج، جلسهٔ فعال را پیدا کند و به‌جای ساخت جلسهٔ دوم، `MovementActiveSessionConflict` با اطلاعات جلسهٔ موجود برگرداند.
3. UI باید در این حالت یک دیالوگ سه‌گزینه‌ای نشان دهد: **ادامهٔ جلسهٔ قبلی** / **پایان دادن به جلسهٔ قبلی و شروع جدید** / **انصراف**. این متن‌ها باید به `MovementStrings` اضافه شوند.

**معیار پذیرش:** تست واحد: دو بار پشت سر هم `startSession` را صدا بزن؛ بار دوم باید تعارض برگرداند و جدول دقیقاً یک ردیف فعال داشته باشد.

### M-13 — مسابقهٔ داده در `resumeSession` — محاسبه خارج از تراکنش

**واقعیت فعلی:** `resumeSession` ابتدا تمام رویدادهای جلسه را می‌خواند و `getSessionById` را صدا می‌زند تا `addedPauseMs` را حساب کند، **و بعد** تراکنشی باز می‌کند تا `accumulatedPauseMs` جدید را بنویسد. اگر در فاصله رویدادی ثبت شود (مثلاً از اعلان، یا از دو لمس پشت سر هم)، محاسبه بر اساس دادهٔ کهنه انجام شده و نتیجه روی دادهٔ تازه نوشته می‌شود — الگوی کلاسیک lost update.

**تصمیم قطعی:** کل چرخهٔ خواندن ← محاسبه ← نوشتن باید داخل یک `txn` باشد. تمام کوئری‌ها از `txn` استفاده کنند، نه از handle سطح بالا.

### M-14 — `changeGoal` یک رویداد را از داخل تراکنش با اتصال مستقل می‌نویسد

**واقعیت فعلی:** `changeGoal` درون `dbExec.transaction((txn) async { ... })` متد `recordEvent(...)` را صدا می‌زند — و `recordEvent` خودش `DatabaseHelper.instance.database` را می‌گیرد. یعنی نوشتن رویداد از تراکنش **فرار می‌کند**: اگر تراکنش رول‌بک شود، رویداد می‌ماند؛ و در sqflite این کار بسته به حالت قفل، می‌تواند منجر به deadlock شود.

**تصمیم قطعی:** الگوی مورد انتظار: هر متد داخلی که ممکن است در تراکنش صدا زده شود، باید یک پارامتر `DatabaseExecutor` بگیرد:
```dart
Future<void> recordEvent(
  DatabaseExecutor db, {   // الزامی — دیگر داخل خودش handle نمی‌گیرد
  required String sessionId,
  required MovementSessionEventType type,
  Map<String, Object?>? payload,
});
```
تمام فراخوانی‌ها به‌روز شوند. معیار: `grep -rn "DatabaseHelper.instance.database" lib/features/movement/application` فقط در نقطه‌های ورودی سرویس باشد، نه در توابع کمکی.

### M-15 — `finishSession` مدت جعلی ۱ ثانیه می‌نویسد

**واقعیت فعلی:**
```dart
durationSec: elapsedSec > 0 ? elapsedSec : 1,
```
یعنی اگر به هر دلیلی محاسبه صفر شود (جلسهٔ فوراً تمام‌شده، خطای محاسبهٔ مکث، یا ترتیب خراب رویدادها از `M-09`)، سیستم عدد ۱ ثانیه می‌سازد و آن را به‌عنوان دادهٔ واقعی در تحلیل‌ها خرج می‌کند. این نقض مستقیم قاعدهٔ ۰-۵ است.

**تصمیم قطعی:** ستون `durationSource` به `movement_workout_logs` اضافه شود:
```sql
durationSource TEXT NOT NULL DEFAULT 'UNKNOWN'
  CHECK (durationSource IN ('TIMER','MANUAL','ESTIMATED','UNKNOWN'))
```
- `TIMER` — از جلسهٔ زنده، قابل اعتماد.
- `MANUAL` — کاربر خودش وارد کرده.
- `ESTIMATED` — از هدف جلسه تخمین زده شده (باید در UI با نشانهٔ «تخمینی» دیده شود).
- `UNKNOWN` — دادهٔ میراثی؛ در محاسبات تجمیعی **کنار گذاشته می‌شود**.

`elapsedSec == 0` دیگر به `1` تبدیل نمی‌شود؛ صفر ذخیره می‌شود و `durationSource = 'UNKNOWN'` می‌گیرد، و لایهٔ تحلیل آن را نمی‌شمارد.

### M-16 — `abandonSession` وضعیت واقعی occurrence را پاک می‌کند

**واقعیت فعلی:** `abandonSession` وضعیت occurrence را به‌طور بی‌قید و شرط به `planned` بازمی‌گرداند — حتی اگر occurrence قبلاً `late` بوده، یا در جلسه چند ست ثبت شده باشد.

**تصمیم قطعی:** منطق صریح:
- اگر در جلسه حداقل یک ست یا یک پیشرفت معنادار ثبت شده → `partial` و یک `movement_workout_logs` با `durationSource='TIMER'` ثبت می‌شود.
- وگرنه → وضعیت قبلی occurrence بازگردانده می‌شود (که باید در `movement_live_sessions.targetSnapshotJson` ذخیره شده باشد)، نه مقدار ثابت `planned`.

### M-17 — `ss_user_profile` با `limit: 1` بدون `where` خوانده می‌شود

**واقعیت فعلی:** جدول `ss_user_profile` با `id TEXT PRIMARY KEY DEFAULT 'default'` تعریف شده، ولی مصرف‌کننده‌ها فقط `limit: 1` می‌زنند بدون `where: 'id = ?'`. اگر به هر دلیلی دو ردیف وجود داشته باشد، سیستم بدون ترتیب مشخص یکی را می‌خواند — یعنی `programStartDate`، `deloadEveryNWeeks`، `trainingDays` ممکن است بین دو اجرا تغییر کنند.

**تصمیم قطعی:** در مهاجرت فاز ۲، پروفایل به جدول تنظیمات حرکت منتقل می‌شود (`M-32`). تا آن زمان، هر خواندن باید `where: 'id = ?', whereArgs: ['default']` داشته باشد و مهاجرت باید ردیف‌های اضافی را ادغام یا قرنطینه کند.

### M-18 — `firstWhere` بدون `orElse`

**تصمیم قطعی:** تمام `firstWhere` های بدون `orElse` در دامنه پیدا و اصلاح شوند. جایی که مقدار ممکن است وجود نداشته باشد، از `firstWhereOrNull` (از `package:collection` اگر قبلاً در `pubspec.yaml` هست، وگرنه اکستنشن داخلی) استفاده کن و حالت null را صریحاً مدیریت کن.

### M-19 — سازگاری SDK برای عنصر null-aware

**واقعیت فعلی:** `MovementAnalyticsService.logSessionPartial` از نحو `'reason': ?reason` استفاده می‌کند (null-aware element، معرفی‌شده در Dart 3.9). این نحو فقط وقتی کامپایل می‌شود که `environment.sdk` در `pubspec.yaml` حداقل `^3.9.0` باشد.

**تصمیم قطعی:** `pubspec.yaml` را بخوان. اگر محدودیت SDK پایین‌تر است، **محدودیت را بالا نبر** (قاعدهٔ ۰-۱۴)؛ به‌جای آن نحو را به شکل سازگار بازنویسی کن:
```dart
final payload = <String, Object?>{ ... };
if (reason != null) payload['reason'] = reason;
```
و واقعیت را در گزارش پایانی ذکر کن.

### M-20 — `MovementAnalyticsService` حافظه را بی‌نهایت مصرف می‌کند

**واقعیت فعلی:** کلاس یک لیست `static` به نام `_recordedEventsForTesting` دارد که **هر رویدادی را برای همیشه نگه می‌دارد** — در بیلد ریلیز هم. هیچ سقف، هیچ پاک‌سازی، و هیچ گارد `kDebugMode` وجود ندارد. علاوه بر این، سرویس هیچ مقصد واقعی‌ای ندارد — `_customObserver` با `@visibleForTesting` علامت خورده. یعنی ۱۳ رویداد تحلیلی تعریف شده‌اند که هیچ‌کدام به جایی نمی‌روند.

**تصمیم قطعی:**
1. لیست ایستا فقط در `kDebugMode` پر شود و سقف سخت `200` رویداد با حذف قدیمی‌ترین داشته باشد.
2. یک مقصد واقعی تعریف شود: رویدادها در جدول محلی `movement_analytics_events(id, name, payloadJson, atUtc)` با سقف ۵۰۰ ردیف و حذف خودکار قدیمی‌ها ذخیره شوند تا صفحهٔ تشخیص (`M-99`) بتواند آن‌ها را نشان دهد. هیچ داده‌ای از دستگاه خارج نمی‌شود.

### 🚦 دروازهٔ پذیرش فاز ۱

- [ ] تست `schema_collision_guard_test.dart` سبز است و `movement_session_events` دقیقاً یک تعریف دارد.
- [ ] `grep -rn "catch (_) {}" lib/core/database lib/features/movement lib/features/supplementary_sports` خالی.
- [ ] هیچ `CREATE TABLE` بدون `IF NOT EXISTS` نمانده.
- [ ] ایندکس یکتایی جلسهٔ فعال وجود دارد و تست دوباره‌شروع سبز است.
- [ ] `recordEvent` پارامتر `DatabaseExecutor` می‌گیرد و هیچ تراکنش تودرتویی نمانده.
- [ ] `durationSource` در اسکیما و در مدل وجود دارد؛ مقدار جعلی ۱ حذف شده.
- [ ] لیست ایستای تحلیلی سقف دارد و فقط در دیباگ فعال است.
- [ ] سه فرمان تأیید سبز.

---

## فاز ۲ — تلفیق: انتقال «ورزش تکمیلی» به درون «حرکت مرکزی»

این فاز قلب کار است. هدف: در پایان این فاز در کل پروژه فقط **یک** درخت کد ورزشی، **یک** خانهٔ داده برای هر مفهوم، و **یک** منبع agenda وجود داشته باشد.

### M-21 🔥 — سه درخت کد موازی برای یک دامنه

**واقعیت فعلی:** سه پیاده‌سازی مستقل از مفهوم «حرکت» در پروژه وجود دارد:

| # | مسیر | ماهیت |
|---|---|---|
| ۱ | `lib/features/movement/**` | ماژول تمیز و لایه‌بندی‌شده (`application`/`domain`/`presentation`) — **قانونی** |
| ۲ | `lib/features/supplementary_sports/**` (سطح اول) | ماژول نسخه‌محور SS |
| ۳ | `lib/features/supplementary_sports/movement/**` | **درخت سوم** — یک پیاده‌سازی کاملاً مجزای حرکت داخل SS |

درخت سوم مدل‌های موازی خودش را دارد: `movement_kind.dart`، `movement_session.dart`، `movement_event.dart`، `movement_budget.dart`، `movement_slot_override.dart`، `movement_campaign.dart`، `session_mode.dart`، `week_plan_item.dart`، `week_slot_resolver.dart`، `endurance_progression.dart`، `movement_plan_writer.dart`، `movement_reminder_defaults.dart`، به‌علاوهٔ `movement_suggester.dart` (حدود ۱۷ کیلوبایت)، `movement_repository.dart`، و صفحاتی مثل `movement_log_sheet.dart` (حدود ۳۸ کیلوبایت)، `movement_plan_sheet.dart` (حدود ۴۲ کیلوبایت)، `movement_custom_kind_sheet.dart`، `movement_analytics_screen.dart`، و `unified_week_planner_screen.dart`.

**تصمیم قطعی:** درخت سوم در پایان این فاز **حذف می‌شود**. قبل از حذف، دقیقاً این موارد به `movement` منتقل می‌شوند (نه کپی‌پیست، بلکه بازنویسی متناسب با مدل دامنهٔ مقصد):
- `movement_suggester.dart` → `lib/features/movement/application/movement_suggester_service.dart` — منطق پیشنهاد هوشمند جلسه، منبع دادهٔ `SmartFillSheet` می‌شود.
- `movement_budget.dart` → `lib/features/movement/domain/models/movement_budget.dart` — بودجهٔ هفتگی MET-minute و روزهای فعال.
- `movement_slot_override.dart` + `week_slot_resolver.dart` → `lib/features/movement/domain/` — مفهوم «استثنای همین هفته».
- `endurance_progression.dart` → منطق پیشرفت استقامتی در `movement_progression_service.dart`.
- `unified_week_planner_screen.dart` → منطق برنامه‌ریز هفتگی در `lib/features/movement/presentation/planner/` جذب می‌شود.
- `movement_reminder_defaults.dart` → مقادیر پیش‌فرض یادآور در `MovementNotificationService` (فاز ۵).
- `movement_kind.dart` → هر فیلدی که `MovementActivityKind` ندارد (مشخصاً مقدار MET) به مدل قانونی اضافه می‌شود.

بقیهٔ درخت سوم (مدل‌های تکراری `movement_session`، `movement_event`، `movement_campaign`، `session_mode`، `movement_plan_writer`، `movement_repository`، و صفحات/شیت‌های موازی) حذف می‌شود.

### M-22 🔥 — چهار خانهٔ داده برای یک مفهوم

**واقعیت فعلی:** هر مفهوم کلیدی دامنه در دو تا چهار جدول مختلف زندگی می‌کند:

| مفهوم | خانه‌های موجود |
|---|---|
| لاگ تمرین | `movement_workout_logs` ، `workout_logs` ، `ss_workout_session_log` |
| لاگ ست | `movement_set_logs` ، `workout_set_logs` ، `ss_workout_set_log` ، `ss_session_set_log` |
| جلسهٔ زنده | `movement_live_sessions` ، `movement_sessions` |
| رویداد جلسه | `movement_session_events` ×۲ (هم‌نام، دو اسکیما — `M-09`) |
| رکورد شخصی | `movement_personal_records` ، `movement_pr` ، `ss_exercise_pr` |
| چک‌این آمادگی | `movement_readiness_checkins` ، `ss_daily_checkin` ، `workout_recovery_logs` |
| برنامهٔ جلسه | `movement_occurrences` ، `ss_session_prescription` ، `ss_workout_plan` ، `ss_plan_schedule` ، `routines` (با `category='fitness'`) |
| کتابخانهٔ حرکات | `movement_activity_kinds` ، `ss_exercise` ، `exercises_library` ، `movement_strength_exercises` |

**تصمیم قطعی — جدول مقصد نهایی.** این جدول قانون است؛ از آن تخطی نکن:

| مبدأ | سرنوشت | مقصد قانونی |
|---|---|---|
| `movement_workout_logs` | **می‌ماند (توسعه‌یافته)** | خانهٔ قانونی لاگ تمرین |
| `workout_logs` | مهاجرت → حذف | `movement_workout_logs` |
| `ss_workout_session_log` | مهاجرت → حذف | `movement_workout_logs` |
| `movement_set_logs` | **می‌ماند (توسعه‌یافته)** | خانهٔ قانونی ست |
| `workout_set_logs` ، `ss_workout_set_log` ، `ss_session_set_log` | مهاجرت → حذف | `movement_set_logs` |
| `movement_live_sessions` | **می‌ماند** | جلسهٔ زنده |
| `movement_sessions` (SS) | مهاجرت → حذف | `movement_live_sessions` |
| `movement_personal_records` | **می‌ماند (با UNIQUE جدید)** | رکوردها |
| `movement_pr` ، `ss_exercise_pr` | مهاجرت → حذف | `movement_personal_records` |
| `movement_readiness_checkins` | **می‌ماند (ستون‌های جدید)** | چک‌این |
| `ss_daily_checkin` ، `workout_recovery_logs` | مهاجرت → حذف | `movement_readiness_checkins` |
| `movement_occurrences` | **می‌ماند (ستون‌های نسخه)** | برنامهٔ جلسه |
| `ss_session_prescription` | مهاجرت → حذف | `movement_occurrences` |
| `ss_workout_plan` ، `ss_plan_schedule` ، `ss_workout_exercise_crossref` | مهاجرت → حذف | `movement_plan_templates` + `movement_plan_schedules` + `movement_occurrences` |
| `movement_activity_kinds` | **می‌ماند (ستون MET)** | نوع فعالیت |
| `ss_exercise` (~۵۰ ستون) | بازطراحی → `movement_exercises` | کتابخانهٔ حرکات |
| `exercises_library` | مهاجرت → حذف | `movement_exercises` |
| `ss_muscle_group` | انتقال عیناً → `movement_muscle_groups` | تاکسونومی عضلات |
| `ss_exercise_similarity` | انتقال → `movement_exercise_similarity` | جایگزینی حرکت |
| `movement_budget` | انتقال عیناً (مالکیت به movement) | بودجهٔ هفتگی |
| `movement_slot_overrides` | انتقال عیناً | استثنای هفتگی |
| `ss_user_profile` | مهاجرت → حذف | `movement_preferences` (key/value) |
| `ss_ai_memory` ، `ss_decision_log` | مهاجرت → `movement_decision_log` | تاریخچهٔ تصمیم |
| `ss_exercise_feeling_log` | مهاجرت → حذف | `movement_set_logs.feeling` + `movement_workout_logs.feeling` |
| `ss_plan_version_history` | مهاجرت → `movement_plan_versions` | تاریخچهٔ نسخه |
| `workout_plan_versions` | مهاجرت → `movement_plan_versions` | همان |
| `station_bundles` ، `ss_workout_set` ، `ss_exercise_set_suitability` | انتقال با پیشوند `movement_` | بسته‌های تمرین |
| `workout_split_days` | مهاجرت → حذف | `movement_plan_schedules` |
| `movement_campaigns` | قرنطینه (مصرف‌کننده ندارد) | — |

**قاعدهٔ حذف:** هیچ جدولی در همان مهاجرتی که داده‌اش را کپی می‌کند `DROP` نمی‌شود. به‌جای آن به `_legacy_<name>` تغییر نام می‌دهی و در یک مهاجرت مستقل بعدی (که در همین کار نمی‌نویسی — فقط `TODO` با شمارهٔ نسخهٔ بعدی می‌گذاری) حذف خواهند شد. این به کاربر یک نسخه فرصت می‌دهد تا اگر مهاجرت خراب بود، داده قابل بازیابی باشد.

### M-23 — مهاجرت واقعی دیتابیس

**تصمیم قطعی:** یک مهاجرت جدید بساز — شمارهٔ نسخه را از رجیستری موجود (`lib/core/database/migrations/migrations_registry.dart`) بخوان و عدد بعدی را بردار:

`lib/core/database/migrations/migration_v<N>_movement_unification.dart`

قواعد اجرای مهاجرت:
1. **در یک تراکنش واحد** اجرا شود. اگر هر مرحله شکست بخورد، کل مهاجرت رول‌بک شود و خطا بالا برود.
2. قبل از خواندن هر جدول مبدأ، وجودش را با کوئری روی `sqlite_master` تأیید کن (نه با `try/catch`).
3. قبل از خواندن هر ستون مشکوک (مثل `ss_workout_plan.week` یا `movement_session_events.dataJson`)، با `PRAGMA table_info(...)` وجودش را بررسی کن.
4. برای افزودن ستون فقط از `SchemaManager.safeAddColumn` استفاده کن.
5. در پایان، یک ردیف در `movement_decision_log` بنویس با خلاصهٔ تعداد رکوردهای مهاجرت‌یافته از هر مبدأ.

**نگاشت فیلدها — صریح و اجباری:**

`workout_logs` → `movement_workout_logs`:
```
id                      -> id
sourceEntityId          -> occurrenceId (اگر sourceModule='MOVEMENT')
kind                    -> activityKindId (با نگاشت به شناسهٔ movement_activity_kinds)
date(loggedAt) محلی    -> dateIso
time(loggedAt) محلی    -> startTime
durationMinutes * 60    -> durationSec  (durationSource='MANUAL')
feeling                 -> feeling
note                    -> note
sourceModule            -> source
distanceMeters, elevationMeters, laps, steps,
avgHeartRate, metMinutes, caloriesKcal, metricsJson -> metricJson (ادغام JSON)
loggedAt                -> createdAt
```

`ss_workout_session_log` → `movement_workout_logs`:
```
id                          -> id
prescriptionId              -> occurrenceId (بعد از نگاشت نسخه‌ها در مرحلهٔ قبل)
date(startedAt) محلی      -> dateIso
durationSeconds             -> durationSec (durationSource='TIMER')
overallFeeling              -> feeling
note                        -> note
'ss_prescription'           -> source
completedExercisesCount,
totalExercisesCount         -> metricJson
```

`ss_session_prescription` → `movement_occurrences` (+ ستون‌های جدید):
```
id              -> id
dateIso         -> dateIso
slotType        -> activityKindId  (STRENGTH->kind_strength, CARDIO->kind_running,
                                    MOBILITY->kind_yoga_mobility, ACTIVE_REST->kind_walking,
                                    REST-> ردیف با status='restDay')
targetMinutes   -> goalType='duration', goalValue=targetMinutes, goalUnit='min'
status          -> status  (PLANNED->planned, DONE->completed, PARTIAL->partial,
                            SKIPPED->skipped, MOVED->moved)
movedToDateIso  -> movedToDateIso
'template'      -> origin
cycleWeek       -> cycleWeek         (ستون جدید)
focusCodes      -> focusCodes        (ستون جدید، JSON)
intensityTier   -> intensityTier     (ستون جدید)
targetRpe       -> targetRpe         (ستون جدید)
actualRpe       -> actualRpe         (ستون جدید)
headlineFa      -> headlineFa        (ستون جدید)
coachNoteFa     -> coachNoteFa       (ستون جدید)
isLocked        -> isLocked          (ستون جدید)
```

`ss_daily_checkin` + `workout_recovery_logs` → `movement_readiness_checkins` (+ ستون‌های جدید):
```
dateIso / date  -> dateIso  (کلید؛ در صورت تصادم، ss_daily_checkin ارجح است)
energy          -> energy
soreness        -> soreness
fatigue         -> fatigue        (ستون جدید)
painLevel       -> painLevel      (ستون جدید)
hydration       -> hydration      (ستون جدید)
soreMuscleGroups-> soreMuscleGroups (ستون جدید، JSON)
availableMinutes-> availableMinutes
note            -> note           (ستون جدید)
```
توجه: `movement_readiness_checkins` فعلاً `sleep` دارد ولی `ss_daily_checkin` ندارد. مقدار را `NULL` بگذار — **هرگز مقدار پیش‌فرض ننویس** (قاعدهٔ ۰-۵). سرویس آمادگی در فاز ۴ خودش خواب را از `bedtime_diagnostics` می‌خواند.

`movement_pr` + `ss_exercise_pr` → `movement_personal_records`:
```
kind / exerciseId -> activityKindId یا exerciseId (دقیقاً یکی، دیگری NULL)
prType            -> recordType
value             -> value
achievedAt        -> achievedAt
logId / sessionId -> sourceId
```
و ایندکس یکتایی الزامی پس از مهاجرت:
```sql
CREATE UNIQUE INDEX IF NOT EXISTS idx_movement_pr_unique
  ON movement_personal_records(recordType, COALESCE(activityKindId,''), COALESCE(exerciseId,''));
```

**معیار پذیرش (الزامی):** تست رفت‌وبرگشت مهاجرت در `test/unit/movement/movement_unification_migration_test.dart`:
1. یک دیتابیس حافظه‌ای با `sqflite_common_ffi` بساز که دقیقاً اسکیمای قبل از مهاجرت را دارد.
2. در هر جدول مبدأ حداقل دو ردیف واقعی بریز (یکی کامل، یکی با فیلدهای `NULL`).
3. مهاجرت را اجرا کن.
4. تأکید کن تعداد ردیف‌های مقصد دقیقاً برابر مجموع مبادی منهای تکراری‌های قابل تشخیص باشد.
5. تأکید کن هیچ مقدار غیر‌`NULL` مبدأ در مقصد `NULL` نشده باشد.
6. مهاجرت را دوباره اجرا کن و تأکید کن تعداد ردیف‌ها تغییر نکرده (idempotency).

### M-24 — کتابخانهٔ حرکات: `ss_exercise` با حدود ۵۰ ستون و مفاهیم تکراری

**واقعیت فعلی:** جدول `ss_exercise` مشکلات اسکیمای زیر را دارد:
- مفاهیم دوباره در دو ستون با دو سبک نام‌گذاری: `skillRequired` و `skill_max`؛ `sexynessMale` و `sexyness_m`؛ `sexynessFemale` و `sexyness_f`.
- ده ستون بولی مجزا با پیشوند `cat_*` به‌جای یک جدول اتصال.
- مخلوط camelCase و snake_case در یک جدول.

**تصمیم قطعی:** جدول قانونی جدید:
```sql
CREATE TABLE IF NOT EXISTS movement_exercises (
  id                TEXT PRIMARY KEY,
  code              TEXT NOT NULL UNIQUE,
  nameFa            TEXT NOT NULL,
  nameEn            TEXT,
  primaryMuscleCode TEXT REFERENCES movement_muscle_groups(code),
  equipment         TEXT,
  isCompound        INTEGER NOT NULL DEFAULT 0,
  isMachine         INTEGER NOT NULL DEFAULT 0,
  skillLevelMin     INTEGER,
  skillLevelMax     INTEGER,
  instructionsFa    TEXT,
  animationAsset    TEXT,
  isCustom          INTEGER NOT NULL DEFAULT 0,
  archivedAt        TEXT,
  createdAt         TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS movement_exercise_muscles (
  exerciseId  TEXT NOT NULL REFERENCES movement_exercises(id) ON DELETE CASCADE,
  muscleCode  TEXT NOT NULL REFERENCES movement_muscle_groups(code),
  role        TEXT NOT NULL CHECK (role IN ('PRIMARY','SECONDARY')),
  PRIMARY KEY (exerciseId, muscleCode)
);

CREATE TABLE IF NOT EXISTS movement_exercise_tags (
  exerciseId TEXT NOT NULL REFERENCES movement_exercises(id) ON DELETE CASCADE,
  tag        TEXT NOT NULL,
  PRIMARY KEY (exerciseId, tag)
);
```
ده ستون `cat_*` به ردیف‌های `movement_exercise_tags` مهاجرت می‌کنند. ستون‌های تکراری ادغام می‌شوند (مقدار غیر‌NULL ارجح است؛ اگر هر دو غیر‌NULL و متفاوت بودند، snake_case که جدیدتر است ارجحیت دارد و اختلاف در `movement_decision_log` ثبت می‌شود).

ستون‌های `sexyness*` در مدل جدید **حذف می‌شوند** — هیچ مصرف‌کنندهٔ معناداری ندارند و نام‌گذاری‌شان برای یک اپ سلامت بانوان نامناسب است. اگر در کد مصرف‌کننده‌ای پیدا کردی، فقط آن مورد را به `movement_exercise_tags` با برچسب خنثی نگاشت کن و در گزارش بنویس.

### M-25 — تاکسونومی عضلات منتقل می‌شود (قابلیت ارزشمند SS)

**واقعیت فعلی:** `ss_muscle_group` یک تاکسونومی تمیز با ۱۲ کد و عنوان فارسی و ناحیه و ایموجی و ترتیب دارد — یکی از کمترین قسمت‌های مشکل‌دار SS. در مقابل، `MovementProgressService.getMuscleWorkload` دسته‌بندی خودش را با برچسب‌های ناسازگار `'سایر'` و `'عمومی'` می‌سازد.

**تصمیم قطعی:** جدول عیناً به `movement_muscle_groups(code, titleFa, region, emoji, sortOrder)` منتقل می‌شود با همان ۱۲ ردیف seed:
```
CHEST/سینه/UPPER  • SHOULDER/سرشانه/UPPER  • BICEPS/جلوبازو/UPPER
TRICEPS/پشت‌بازو/UPPER • BACK/زیربغل و پشت/UPPER • CORE/شکم و مرکز/CORE
QUADS_GLUTES/ران و باسن/LOWER • HAMSTRINGS/پشت ران/LOWER • CALVES/ساق پا/LOWER
CARDIO/هوازی/CARDIO • MOBILITY/تحرک و کشش/MOBILITY • FULL_BODY/کل بدن/FULL
```
`getMuscleWorkload` باید فقط از این کدها استفاده کند و برچسب را از `titleFa` بخواند. حرکات بدون کد عضله به `FULL_BODY` نگاشت نمی‌شوند — در خروجی به‌عنوان «بدون داده» گزارش می‌شوند.

### M-26 — فایل‌های seed حجیم در کد Dart

**واقعیت فعلی:** `ss_exercise_farsi_names.dart` حدود ۴۳ کیلوبایت و `ss_exercise_animation_map.dart` حدود ۲۸ کیلوبایت مپ هاردکد Dart هستند. این ۷۱ کیلوبایت در هر بیلد کامپایل می‌شود و در حافظهٔ اپ می‌ماند.

**تصمیم قطعی:** هر دو به فایل JSON در `assets/movement/` تبدیل شوند و فقط یک‌بار در مسیر seed دیتابیس خوانده شوند و به `movement_exercises` بروند. پس از seed اولیه، منبع حقیقت دیتابیس است نه فایل. `pubspec.yaml` فقط برای ثبت مسیر asset تغییر می‌کند (این استثنای مجاز قاعدهٔ ۰-۱۴ است).

### M-27 — `supplementary_sports_theme.dart` یک سیستم طراحی دوم است

**تصمیم قطعی:** فایل حذف می‌شود. هر توکنی که در `RitmoTheme` معادل ندارد و واقعاً لازم است، به `context.modules.sports` اضافه می‌شود — نه در یک فایل تم مستقل.

### M-28 — پلیس‌هولدر توسعه در نسخهٔ محصول

**واقعیت فعلی:** در `new_movement_section.dart`:
```dart
Tab(text: 'تب ۳'),
...
Center(child: Text('محتوای تب ۳'))
```
این عیناً در دست کاربر نهایی قابل مشاهده است. همین فایل `fontSize: 13` را در `labelStyle` و `unselectedLabelStyle` هاردکد کرده.

**تصمیم قطعی:** تب حذف می‌شود. اندازهٔ فونت از `RitmoTextStyles` می‌آید. کل این ویجت در پایان فاز ۷ جایش را به ناوبری یکپارچهٔ حرکت می‌دهد (`M-99`).

### M-29 — ماژول SS جدول `routines` را دستکاری می‌کند

**واقعیت فعلی:** `SupplementarySportsTables.ensureMovementMuscleFocus` این کار را می‌کند:
```dart
safeAddColumn(db, 'routines', 'movementMuscleFocus', 'TEXT');
```
یعنی یک ماژول فرعی به جدول مرکزی ماژول دیگری ستون اضافه می‌کند. علاوه بر این، `SsAgendaSource` ردیف‌های `routines` با `category = 'fitness'` را به‌عنوان جلسهٔ ورزشی می‌خواند و فیلدهای `movementIsMeetup` و `targetDurationMinutes` را مصرف می‌کند — پس `routines` خانهٔ چهارم دادهٔ حرکتی است.

**تصمیم قطعی:**
1. `ensureMovementMuscleFocus` حذف می‌شود. ستون `routines.movementMuscleFocus` در دیتابیس‌های موجود باقی می‌ماند (حذف ستون در SQLite پرهزینه است) ولی دیگر نوشته نمی‌شود؛ مقدارش در مهاجرت به `movement_occurrences.focusCodes` منتقل می‌شود.
2. روتین‌های `category = 'fitness'` **در جای خود می‌مانند** (مالک آن‌ها ماژول روتین است) ولی `MovementAgendaSource` موظف می‌شود آن‌ها را بخواند و با occurrence ها دیداپ کند (`M-77`). در گزارش صریحاً بنویس که این تنها مورد مجاز دومین منبع داده است و دلیلش مالکیت ماژول دیگر است.

### M-30 — فهرست قطعی فایل‌های حذفی

در پایان فاز ۲ این موارد دیگر نباید وجود داشته باشند:

```
lib/features/supplementary_sports/movement/**              (کل درخت سوم)
lib/features/supplementary_sports/supplementary_sports_theme.dart
lib/features/supplementary_sports/domain/ss_agenda_source.dart
lib/features/supplementary_sports/domain/ss_program_calendar.dart      (منطق به movement)
lib/features/supplementary_sports/domain/ss_week_resolver.dart          (منطق به movement)
lib/features/supplementary_sports/domain/ss_readiness_service.dart      (منطق به movement)
lib/features/supplementary_sports/domain/ss_adaptive_scheduler.dart     (منطق به movement)
lib/features/supplementary_sports/domain/ss_session_completion_gateway.dart
lib/features/supplementary_sports/presentation/new_movement_section.dart
lib/core/database/schema/tables/supplementary_sports_tables.dart        (پس از مهاجرت)
```

صفحات بزرگ SS (`ss_home_dashboard_screen.dart`، `ss_workout_session_screen.dart`، `ss_onboarding_flow.dart`، `ss_progress_screen.dart`، `ss_plan_overview_screen.dart`، `ss_plan_day_detail_screen.dart`، `ss_settings_screen.dart`، `ss_exercise_library_screen.dart`، `ss_premium_muscle_category_screen.dart`، `ss_session_summary_screen.dart`، `ss_movement_tab_screen.dart`، `ss_intro_screen.dart`، `ss_program_settings_screen.dart`) **در فاز ۲ حذف نمی‌شوند** — حذفشان در فاز ۷ و پس از اینکه معادل کارکردی‌شان در `movement` ساخته شد، انجام می‌شود. در فاز ۲ فقط لایهٔ داده و دامنه یکپارچه می‌شود و صفحات SS موقتاً روی مخازن جدید سوار می‌شوند.

### M-31 — گیت ماژول باید یکی شود

**واقعیت فعلی:** دو کلید تنظیمات موازی وجود دارد: `module_sports_enabled` و `module_supplementary_sports_enabled`. `SsAgendaSource` هر دو را می‌خواند؛ `MovementAgendaSource` هیچ‌کدام را نمی‌خواند (`M-78`).

**تصمیم قطعی:** کلید قانونی `module_sports_enabled` است. در مهاجرت، اگر `module_supplementary_sports_enabled` مقدار دارد، مقدار نهایی `module_sports_enabled = (sports OR supplementary)` محاسبه می‌شود تا کاربری که فقط یکی را روشن كرده بود ماژولش خاموش نشود. کلید دوم حذف می‌شود.

### 🚦 دروازهٔ پذیرش فاز ۲

- [ ] `lib/features/supplementary_sports/movement/` دیگر وجود ندارد.
- [ ] مهاجرت `migration_v<N>_movement_unification.dart` در رجیستری ثبت شده.
- [ ] تست رفت‌وبرگشت مهاجرت سبز است و idempotency تأیید شده.
- [ ] تست تصادم اسکیما هنوز سبز است.
- [ ] `movement_muscle_groups` با ۱۲ ردیف و `movement_exercises` با دادهٔ مهاجرت‌یافته وجود دارند.
- [ ] `supplementary_sports_theme.dart` حذف شده و هیچ import باقی نمانده.
- [ ] پلیس‌هولدر «تب ۳» حذف شده.
- [ ] یک کلید گیت ماژول بیشتر نداریم.
- [ ] سه فرمان تأیید سبز.

---

## فاز ۳ — درستی موتور جلسه، برنامه و occurrence

هدف: موتوری که جلسات را می‌سازد، جابه‌جا می‌کند و تکمیل می‌کند باید دقیقاً یک رفتار داشته باشد، نه دو رفتار متضاد.

### M-32 🔥 — دو پیاده‌سازی متضاد از `moveOccurrence`

**واقعیت فعلی:** دو متد هم‌نام در دو سرویس وجود دارد و نتیجهٔ دو متفاوت تولید می‌کنند:

- `MovementPlanningService.moveOccurrence` → وضعیت را `'planned'` می‌گذارد.
- `MovementOccurrenceService.moveOccurrence` → وضعیت را `moved.name` می‌گذارد.

صفحه از نسخهٔ `PlanningService` استفاده می‌کند؛ نسخهٔ `OccurrenceService` کد مرده است. نتیجه: جلسه‌ای که جابه‌جا شده هیچ ردپایی از جابه‌جایی ندارد، `movedToDateIso` بی‌معنا می‌ماند، و `MovementDayStatus.moved` در ریل هفته هرگز نمایش داده نمی‌شود.

**تصمیم قطعی — معنای رسمی جابه‌جایی:**
جابه‌جایی دو ردیف تولید می‌کند، نه یکی:
1. occurrence مبدأ: `status = 'moved'`، `movedToDateIso = <تاریخ مقصد>`.
2. occurrence مقصد: ردیف جدید با `status = 'planned'`، `origin = 'oneOff'`، `movedFromOccurrenceId = <شناسهٔ مبدأ>` (ستون جدید).

این کار در یک تراکنش انجام می‌شود. نسخهٔ `MovementOccurrenceService` حذف می‌شود؛ تنها نسخهٔ قانونی در `MovementPlanningService` می‌ماند و مطابق بالا بازنویسی می‌شود.

**معیار پذیرش:** تست: یک occurrence را جابه‌جا کن؛ دو ردیف باید وجود داشته باشد؛ ریل هفته باید روز مبدأ را با نشانهٔ `moved` و روز مقصد را با `planned` نشان دهد.

### M-33 — هیچ قید یکتایی روی occurrence وجود ندارد و برنامه تکثیر می‌شود

**واقعیت فعلی:** `movement_occurrences` هیچ `UNIQUE` و هیچ کلید خارجی ندارد. `createPlan` در یک حلقه شناسه‌ها را از مهر زمانی می‌سازد. یعنی اگر کاربر برنامه را دو بار ذخیره کند، یا اگر فراخوانی دوبار اتفاق بیفتد (که با `M-46` کاملاً ممکن است)، دو مجموعه occurrence کاملاً تکراری ساخته می‌شود و کاربر هر جلسه را دو بار می‌بیند.

**تصمیم قطعی:**
```sql
CREATE UNIQUE INDEX IF NOT EXISTS idx_movement_occurrences_slot
  ON movement_occurrences(templateId, dateIso, COALESCE(startTime,''))
  WHERE templateId IS NOT NULL;
```
و `createPlan` از `ConflictAlgorithm.ignore` برای ردیف‌های قالب‌محور استفاده کند تا تکرار بی‌ضرر باشد.
قبل از ساخت ایندکس، در مهاجرت باید تکراری‌های موجود پاک شوند: از هر گروه تکراری، ردیفی که وضعیت `completed`/`partial` دارد حفظ می‌شود؛ اگر هیچ‌کدام ندارد، قدیمی‌ترین `createdAt`.

### M-34 🔥 — افق برنامه چهار هفته است و هیچ مکانیزم بازتولیدی وجود ندارد

**واقعیت فعلی:** `MovementPlanningService.createPlan` با پیش‌فرض `horizonWeeks = 4` در حلقهٔ `for (int i = 0; i < maxWeeks * 7; i++)` occurrence می‌سازد. در سراسر کد **هیچ جایی** کار دوره‌ای برای تمدید این افق وجود ندارد.

**نتیجهٔ عملی:** کاربری که یک برنامهٔ «هر هفته» می‌سازد، دقیقاً بعد از چهار هفته می‌بیند برنامه‌اش بدون هیچ توضیحی تمام شده. این بدترین نوع باگ است: کاربر خیال می‌کند خودش تقصیر دارد.

**تصمیم قطعی:** کلاس `MovementHorizonService` بساز با قرارداد زیر:
- هدف ثابت: همیشه حداقل **۸ هفتهٔ آینده** occurrence فعال وجود داشته باشد.
- متد `ensureHorizon({ DateTime? from })` که برای هر `movement_plan_templates` فعال (`archivedAt IS NULL`) و هر `movement_plan_schedules` مربوطه، ردیف‌های خالی را پر کند. این متد با وجود ایندکس `M-33` کاملاً idempotent است.
- فراخوانی در سه نقطه: (الف) هنگام باز شدن مرکز حرکت، (ب) هنگام حرکت به هفتهٔ بعد، (ج) پس از ذخیره/ویرایش هر قالب.
- `weeksCount` در `movement_plan_schedules` اگر مقدار دارد، سقف واقعی است و باید رعایت شود؛ اگر `NULL` است یعنی نامحدود و افق مدام جلو می‌رود.
- وقتی برنامه به انتهای `weeksCount` می‌رسد، **حالت پایان صریح** در UI نمایش داده می‌شود: «برنامهٔ شما تمام شد. تمدید یا ساخت برنامهٔ جدید؟» با دو دکمه.

**معیار پذیرش:** تست: برنامهٔ هفتگی بساز، ساعت تست را ۶ ماه جلو ببر، `ensureHorizon` را صدا بزن؛ باید همچنان حداقل ۸ هفته occurrence آینده موجود باشد و هیچ تکراری تولید نشده باشد.

### M-35 — `checkConflicts` فقط تساوی دقیق رشتهٔ ساعت را تشخیص می‌دهد

**واقعیت فعلی:** منطق تشخیص تعارض عملاً این است:
```dart
if (occTime == timeOfDay) { /* تعارض */ }
```
یعنی یک جلسهٔ ۶۰ دقیقه‌ای در `18:00` و جلسه‌ای دیگر در `18:30` از نظر سیستم هیچ تعارضی ندارند. علاوه بر این، فقط occurrence های با `status = 'planned'` بررسی می‌شوند، پس جلسهٔ `inProgress` هم تعارض حساب نمی‌شود.

**تصمیم قطعی:** تشخیص تعارض باید مبتنی بر **همپوشانی بازه** باشد:
```
تعارض افتد اگر: startA < endB  و  startB < endA
مدت هر occurrence:
  - goalType == 'duration' -> goalValue دقیقه
  - در غیر این صورت -> مدت تخمینی از movement_activity_kinds.defaultDurationMin
    (ستون جدید؛ برای هشت نوع seed مقدار واقعی بگذار)
```
وضعیت‌های مورد بررسی: `planned`، `inProgress`، `late`. وضعیت‌های `completed`، `partial`، `skipped`، `moved`، `restDay` تعارض نیستند.
در UI، تعارض باید دقیقاً بگوید کدام جلسه، در چه ساعتی، و چند دقیقه همپوشانی دارد — نه یک پیام عمومی.

### M-36 — `updatePlanWithScope` دامنه‌ها را ناقص اعمال می‌کند

**واقعیت فعلی:**
- برای `thisAndFuture` فقط `status != 'completed'` فیلتر می‌شود — یعنی occurrence های `skipped` و `moved` هم بازنویسی می‌شوند و تصمیم قبلی کاربر از بین می‌رود.
- برای `wholePlan`، `newReminderType` فقط روی قالب ذخیره می‌شود و روی occurrence های موجود اثری ندارد و هیچ یادآوری باززمان‌بندی نمی‌شود.

**تصمیم قطعی — معنای رسمی سه دامنه:**

| دامنه | occurrence های تحت تأثیر | قالب | یادآورها |
|---|---|---|---|
| `onlyThis` | فقط همین یک ردیف | دست نمی‌خورد | فقط همین ردیف لغو/باززمان‌بندی |
| `thisAndFuture` | `dateIso >= امروز` و `status IN ('planned','late','restDay')` | به‌روز می‌شود | همهٔ ردیف‌های متأثر |
| `wholePlan` | همهٔ `status IN ('planned','late','restDay')` در هر تاریخ | به‌روز می‌شود | همهٔ ردیف‌های متأثر |

در هر سه حالت، occurrence های `completed`، `partial`، `skipped`، `moved` **دست نمی‌خورند** — آن‌ها تاریخ‌اند.
قبل از اعمال، UI باید پیش‌نمایش تفاوت بدهد (`DiffList` در ماژول هست و استفاده می‌شود) با تعداد دقیق ردیف‌های متأثر.

### M-37 — حذف برنامه هیچ یادآوری را لغو نمی‌کند

**واقعیت فعلی:** `deleteWithScope` ردیف‌های occurrence را حذف می‌کند و هرگز `MovementNotificationService.cancelOccurrenceReminders` را صدا نمی‌زند. همین موضوع برای مسیرهای تکمیل، رد کردن، و جابه‌جایی هم صادق است — هیچ مسیری در کل ماژول این متد را صدا نمی‌زند.

**تصمیم قطعی:** یک قرارداد واحد: هر تغییر وضعیت occurrence از یک متد مرکزی می‌گذرد:
```dart
Future<void> applyOccurrenceTransition({
  required String occurrenceId,
  required MovementOccurrenceStatus to,
  String? movedToDateIso,
});
```
این متد **همیشه** سه کار را با هم انجام می‌دهد: (۱) به‌روزرسانی ردیف، (۲) مدیریت یادآور (لغو یا باززمان‌بندی)، (۳) انتشار `RitmoEvent` مناسب. هیچ جای دیگری حق ندارد مستقیماً `UPDATE movement_occurrences SET status` بزند.

**معیار پذیرش:** `grep -rn "SET status\|'status':" lib/features/movement` فقط داخل همین متد دیده شود. تست: پس از حذف یا تکمیل یک occurrence، یک fake از `NotificationGateway` باید دقیقاً یک `cancel` با شناسهٔ `mov_rem_<id>` دریافت کرده باشد.

### M-38 — به‌روزرسانی خوشبینانه لیست کش‌شده را درجا جهش می‌دهد

**واقعیت فعلی:** `optimisticCompleteOccurrence` و `optimisticSkipOccurrence` دو مشکل دارند:
1. لیست کش را درجا تغییر می‌دهند (`occurrences[index] = ...`) به‌جای ساختن لیست جدید — یعنی مقایسهٔ مرجع در ویجت‌ها شکست می‌خورد و رندر مجدد تضمین‌شده نیست.
2. فقط در `_weekOccurrencesMap[_formatDateIso(_selectedDate)]` جستجو می‌کنند؛ پس تکمیل یک occurrence از روز دیگر (مثلاً از کارت «دیرکرددار») بی‌صدا `false` برمی‌گرداند و UI به‌روز نمی‌شود.

**تصمیم قطعی:** مدل‌ها و لیست‌های حالت غیرقابل تغییر (immutable) باشند. به‌روزرسانی خوشبینانه باید `Map` و `List` تازه بسازد و در همهٔ روزهای کش‌شدهٔ هفته جستجو کند، نه فقط روز انتخاب‌شده. اگر occurrence در کش نباشد، به‌جای `false` باید بارگذاری دوباره ترگیر شود.

### M-39 — `loadData` نه گارد دارد نه دبونس؛ صفحه چند بار بارگذاری می‌شود

**واقعیت فعلی:**
- `loadData()` هیچ پرچم `_inFlight` ندارد.
- `changeWeek` و `goToThisWeek` بدون `await` آن را صدا می‌زنند.
- صفحه در دست‌کم شش نقطه الگوی `.then((_) => _controller.loadData())` دارد.

نتیجه: هر تعامل ساده دو تا سه بارگذاری کامل را موازی راه می‌اندازد؛ روی دیتابیس واقعی این یعنی پرش محسوس و احتمال دیدن دادهٔ کهنه (بارگذاری کندتر آخر می‌رسد و نتیجهٔ تازه‌تر را پاک می‌کند).

**تصمیم قطعی:**
1. `_inFlight` بولی و شمارندهٔ نسخه (`_loadGeneration`) اضافه کن؛ نتیجهٔ بارگذاری فقط وقتی اعمال شود که نسخه هنوز جاری باشد.
2. دبونس ۲۵۰ میلی‌ثانیه روی درخواست‌های پشت سر هم.
3. الگوی `.then((_) => loadData())` در صفحه حذف شود؛ به‌جای آن هر عملیات در کنترلر خودش بازتازه‌سازی لازم را ترتیب بدهد.

### M-40 🔥 — `_computeEntryStateAndHero` مقایسهٔ همیشه‌درست می‌کند

**واقعیت فعلی:** در این متد:
```dart
final now = _selectedDate;                 // ← اینجا اشتباه است
...
if (_selectedDate.day == now.day && _selectedDate.month == now.month) { ... }
```
این شرط **همیشه درست است**، چون `now` همان `_selectedDate` است. دو پیامد:
1. وقتی کاربر روزی بدون occurrence را انتخاب می‌کند، سیستم برای **هر روزی** وضعیت `recoveryDay` و کارت «روز ریکاوری» را نشان می‌دهد — حتی برای ۳ هفته بعد.
2. مرور هفتهٔ گذشته یا آینده، آن روز را «امروز» تلقی می‌کند و همهٔ منطق `pastPlannedTime` / `late` مخدوش می‌شود.

**تصمیم قطعی:** یک منبع زمان تزریق‌پذیر بساز (`MovementClock` با `DateTime nowLocal()`) تا تست‌پذیر باشد. `_computeEntryStateAndHero` باید صریحاً `MovementDate.toDateIso(clock.nowLocal())` را با `MovementDate.toDateIso(_selectedDate)` مقایسه کند. حالت‌های ورودی باید دقیقاً بر این مبنا تفکیک شوند:

| وضعیت | شرط |
|---|---|
| `brandNewUser` | هیچ قالب و هیچ لاگی در کل دیتابیس نیست |
| `inProgressLiveSession` | جلسهٔ زندهٔ `active`/`paused` وجود دارد (اولویت مطلق) |
| `todaySessionCompleted` | روز انتخابی = امروز و همهٔ occurrence ها `completed`/`partial`/`skipped` |
| `multiSessionsToday` | روز انتخابی بیش از یک occurrence فعال دارد |
| `pastPlannedTime` | روز انتخابی = امروز و ساعت فعلی از `startTime` گذشته |
| `hasPlanTodaySession` | روز انتخابی occurrence فعال دارد |
| `recoveryDay` | روز انتخابی `restDay` دارد **یا** برنامهٔ فعالی هست ولی این روز عمداً استراحت است |
| `noPlanToday` (جدید) | برنامه هست ولی این روز خالی است و روز استراحت مشخص‌شده نیست |

تمایز `recoveryDay` و `noPlanToday` مهم است: اولی پیام تشویقی می‌دهد، دومی دعوت به اقدام.

### M-41 — `getWeekSummary` عددهای ساختگی تولید می‌کند

**واقعیت فعلی:** دو مشکل جداگانه:
1. برای هر occurrence تکمیل‌شده‌ای که `goalType != 'duration'` است، عدد ثابت `activeMinutes += 30` اضافه می‌شود — یعنی عدد «دقایق فعال» در خلاصهٔ هفته تا حد زیادی ساختگی است.
2. `daysWithActivity.add(occ.dateIso)` برای **هر** occurrence فراخوانی می‌شود، بدون توجه به وضعیت. یعنی روزی که فقط برنامه‌ریزی شده ولی انجام نشده، به‌عنوان روز فعال شمرده می‌شود و `recoveryDaysCount` هم به همین دلیل اشتباه می‌شود.

**تصمیم قطعی:** خلاصهٔ هفته فقط از `movement_workout_logs` محاسبه می‌شود (منبع حقیقت کارِ انجام‌شده)، نه از occurrence ها (که قصد هستند):
```
activeMinutes = SUM(durationSec)/60  WHERE durationSource IN ('TIMER','MANUAL')
                                     AND dateIso BETWEEN <شنبه> AND <جمعه>
daysWithActivity = COUNT(DISTINCT dateIso)  با همان فیلتر
plannedCount   = COUNT(occurrences) با status فعال
completedCount = COUNT(occurrences) با status IN ('completed','partial')
recoveryDays   = COUNT(occurrences) با status = 'restDay'
```
ردیف‌های با `durationSource IN ('ESTIMATED','UNKNOWN')` در `activeMinutes` نمی‌آیند ولی تعدادشان در خروجی به‌عنوان `unmeasuredCount` برمی‌گردد تا UI بتواند بگوید «۳ جلسه بدون مدت ثبت‌شده».

### M-42 — ثبت گذشته‌نگر: فردا مجاز است و تطبیق خودکار کور است

**واقعیت فعلی:** گارد تاریخ آینده در `MovementLogService.logRetroWorkout` این است:
```dart
if (parsedDate.isAfter(todayMidnight.add(const Duration(days: 1)))) { /* رد */ }
```
یعنی **فردا کاملاً مجاز است**. برای یک «ثبت گذشته‌نگر» معنا ندارد.
همچنین تطبیق خودکار با occurrence فقط `limit: 1` را برمی‌دارد و هیچ بررسی نزدیکی زمانی ندارد — لاگ ساعت ۷ صبح ممکن است به جلسهٔ ساعت ۲۱ متصل شود.

**تصمیم قطعی:**
1. گارد باید `parsedDate.isAfter(todayMidnight)` باشد — ثبت برای آینده ممنوع.
2. تطبیق خودکار: فقط occurrence های همان `dateIso` با همان `activityKindId` و با فاصلهٔ حداکثر **۱۸۰ دقیقه** از زمان لاگ کاندیدا هستند. اگر بیش از یک کاندیدا باشد، هیچ‌کدام خودکار متصل نمی‌شود و انتخاب به کاربر واگذار می‌شود (با لیست کوتاه در همان فرم).

### M-43 — کش نوع فعالیت هرگز بین نمونه‌ها باطل نمی‌شود

**واقعیت فعلی:** `MovementOccurrenceService._activityCache` یک کش درون‌نمونه‌ای است. چون لایهٔ ارائه نمونه‌های جدید می‌سازد (`M-08`)، ساختن یک نوع فعالیت سفارشی در یک صفحه، کش صفحهٔ دیگر را باطل نمی‌کند. علاوه بر این، `archiveCustomActivityKind` را از کش حذف می‌کند ولی `getAllActivityKinds` فقط موارد غیرآرشیو را دوباره می‌ریزد — پس occurrence های مربوط به یک نوع آرشیوشده `displayName` را به پیش‌فرض `'تمرین حرکتی'` می‌افتند.

**تصمیم قطعی:** کش به سطح ماژول منتقل می‌شود (`MovementActivityKindRegistry` با نمونهٔ تک، در `MovementServiceLocator`) و پس از هر نوشتن باطل می‌شود. کش باید انواع آرشیوشده را هم نگه دارد (برای نمایش دادهٔ تاریخی)، و فقط در لیست انتخاب فیلترشان کند.

### 🚦 دروازهٔ پذیرش فاز ۳

- [ ] فقط یک `moveOccurrence` وجود دارد و دو ردیف تولید می‌کند.
- [ ] ایندکس یکتایی occurrence وجود دارد و تکراری‌های قدیمی پاک شده‌اند.
- [ ] `MovementHorizonService` وجود دارد و تست ۶‌ماهه سبز است.
- [ ] `checkConflicts` مبتنی بر همپوشانی بازه است.
- [ ] `applyOccurrenceTransition` تنها نقطهٔ تغییر وضعیت است و یادآور را مدیریت می‌کند.
- [ ] `_inFlight` + دبونس وجود دارد و `.then((_) => loadData())` حذف شده.
- [ ] `MovementClock` تزریق‌پذیر است و تست ورودی برای هر هشت حالت سبز است.
- [ ] `getWeekSummary` هیچ عدد ثابتی اضافه نمی‌کند.
- [ ] سه فرمان تأیید سبز.

---

## فاز ۴ — آمادگی، انطباق و نسخه‌نویسی

این فاز جایی است که ارزشمندترین قابلیت‌های SS وارد `movement` می‌شوند — ولی فقط پس از اصلاح باگ‌هایشان.

### M-44 🔥 — دو سیستم آمادگی موازی

**واقعیت فعلی:**

| | `MovementReadinessService` | `SSReadinessService` |
|---|---|---|
| منبع داده | فقط `movement_readiness_checkins` | `ss_daily_checkin` + `bedtime_diagnostics` + `vital_signs_logs` + `energy_logs` + `workout_recovery_logs` + چرخه (با رضایت `cycle_consent_sports`) |
| سطوح | مقیاس ساده | چهار سطح `full` / `light` / `minimal` / `rest` + امتیاز ۰..۱۰۰ |
| صداقت | مقادیر هاردکد در نبود داده | پرچم `hasData` دارد (ولی معیوب — `M-46`) |

**تصمیم قطعی:** منطق غنی SS برنده است و به `MovementReadinessService` **جذب** می‌شود (نه کپی، بلکه بازنویسی با رفع باگ‌های زیر). خروجی قانونی:
```dart
class MovementReadinessVerdict {
  final MovementReadinessTier tier;   // full | light | minimal | rest
  final int? score;                   // null وقتی داده نیست
  final MovementReadinessReason reason; // enum، نه رشتهٔ فارسی
  final int sampleSize;               // تعداد منابع داده‌ای که واقعاً جواب دادند
  final int? sleepMinutes;
  final int? recoveryLoad;
  final bool isMenstrualPhase;
}
```
متن فارسی در لایهٔ ارائه از `MovementStrings` ساخته می‌شود، نه در سرویس.

### M-45 🔥 — جعل داده در نبود چک‌این

**واقعیت فعلی:** در مسیر محاسبه، وقتی کاربر چک‌این نکرده باشد، مقادیر زیر جایگزین می‌شوند:
```dart
sleep ?? 3, energy ?? 3, soreness ?? 1, stress ?? 1
```
یعنی سیستم فرض می‌کند کاربر خواب متوسط، انرژی متوسط و بدون کوفتگی است — بدون اینکه هیچ داده‌ای داشته باشد. در یک اپ سلامت، توصیهٔ تمرینی بر پایهٔ دادهٔ جعلی یک مشکل ایمنی است، نه یک نقص UX.

**تصمیم قطعی:** مقادیر پیش‌فرض حذف می‌شوند. اگر هیچ منبعی داده نداد، خروجی باید دقیقاً این باشد:
```dart
MovementReadinessVerdict(
  tier: MovementReadinessTier.unknown,   // مقدار جدید در enum
  score: null,
  reason: MovementReadinessReason.noData,
  sampleSize: 0,
  ...
)
```
و UI به‌جای نمره، دعوت به چک‌این نشان می‌دهد. هر منبع داده که جواب داد، `sampleSize` را یکی زیاد می‌کند؛ اگر `sampleSize < 2` باشد، توصیه باید با برچسب «اطمینان پایین» نمایش داده شود.

### M-46 — تناقض منطقی در حکم آمادگی SS

**واقعیت فعلی:** در `SSReadinessService`، وقتی هیچ داده‌ای نیست، خروجی هم‌زمان این سه را دارد:
- `tier: SSReadinessTier.full` (یعنی «برو تمرین کامل»)
- `score: 0` (یعنی «صفر آمادگی»)
- متن «اطلاعات کافی نیست»

هر مصرف‌کننده‌ای که فقط به `tier` نگاه کند، به کاربری که هیچ داده‌ای ندارد تمرین سنگین تجویز می‌کند. علاوه بر این، `hasData` فقط بر اساس کوئری خواب تعیین می‌شود — پس کاربری که چک‌این کامل ثبت کرده ولی خواب ثبت نکرده، به غلط `hasData = false` می‌گیرد.

**تصمیم قطعی:** با `M-45` حل می‌شود: مقدار `unknown` در enum و `score: null`. علاوه بر آن، `sampleSize` جمع پاسخ همهٔ منابع است — نه یک کوئری. تست اجباری: دیتابیس خالی → `tier == unknown && score == null`.

### M-47 — شاخهٔ قاعدگی روز کم‌انرژی را ارتقا می‌دهد

**واقعیت فعلی:** ترتیب شرط‌ها در `SSReadinessService` این است:
```
painLevel >= 5                                  -> rest    / 30
isMenstrualPhase                                -> light   / 50
energy <= 1 || sleepMinutes < 300               -> minimal / 40
energy == 2 || sleepMinutes < 360 || load >= 6  -> light   / 60
```
چون شاخهٔ قاعدگی **قبل از** شاخهٔ انرژی/خواب است و `return` می‌کند، کاربری که هم‌زمان در دورهٔ قاعدگی است **و** انرژی ۱ دارد **و** ۴ ساعت خوابیده، حکم `light / 50` می‌گیرد — نه `minimal / 40`. یعنی شاخهٔ قاعدگی عملاً وضعیت را **بهتر** نشان می‌دهد.

**تصمیم قطعی:** منطق از زنجیرهٔ `if/return` به مدل امتیازدهی تجمیعی تغییر می‌کند: هر سیگنال یک سقف می‌گذارد و **کمترین سقف برنده است**:
```
درد >= 5                 -> سقف rest
انرژی <= 1 یا خواب < 300  -> سقف minimal
قاعدگی                   -> سقف light
انرژی == 2 یا خواب < 360 یا بار ریکاوری >= 6 -> سقف light
در غیر این صورت           -> سقف full
```
دلیل نهایی (`reason`) همان سیگنالی است که سقف را تعیین کرده. در صورت تساوی، درد بر خواب، خواب بر انرژی، و انرژی بر قاعدگی اولویت دارد.

توجه جدی: دسترسی به دادهٔ چرخه فقط و فقط پس از بررسی `cycle_consent_sports` مجاز است. این گارد در کد فعلی SS هست و باید عیناً حفظ شود. اگر رضایت نیست، `isMenstrualPhase` همیشه `false` است و هیچ کوئری به جداول چرخه زده نمی‌شود.

### M-48 🔥 — `resolveProgramStartDate` به `DateTime.now()` سقوط می‌کند

**واقعیت فعلی:** اگر `ss_user_profile.programStartDate` خالی یا غیرقابل پارس باشد، تابع `DateTime.now()` برمی‌گرداند. چون همین مقدار مبنای محاسبهٔ هفتهٔ جاری است، نتیجه این است که برنامه **هر روز از هفتهٔ ۱ شروع می‌شود** و کاربر هرگز به هفتهٔ ۲ نمی‌رسد.

**تصمیم قطعی:** تابع باید `DateTime?` برگرداند. در نبود تاریخ شروع:
1. اول تلاش کن از قدیمی‌ترین `movement_occurrences.dateIso` مربوط به برنامه بازسازی کنی — و اگر توانستی، همان را دائمی ذخیره کن.
2. اگر نشد، `null` برگردان و لایهٔ بالاتر باید به جای نمایش هفتهٔ جعلی، وضعیت «برنامه هنوز شروع نشده» با دکمهٔ «شروع برنامه از امروز» نشان دهد. تاریخ شروع فقط با اقدام صریح کاربر نوشته می‌شود.

### M-49 🔥 — محاسبهٔ هفتهٔ جاری برنامه را بی‌پایان می‌کند

**واقعیت فعلی:** در `SsWeekResolver`:
```dart
resolveActiveWeek = ((diff ~/ 7) % totalWeeks) + 1;
```
عملگر باقی‌مانده یعنی بعد از هفتهٔ آخر، برنامه به هفتهٔ ۱ برمی‌گردد و **تا ابد تکرار می‌شود**. هیچ حالت «برنامه تمام شد» وجود ندارد. یعنی کاربری که یک برنامهٔ ۸ هفته‌ای را تمام کرده، نه تبریکی می‌گیرد نه پیشنهاد برنامهٔ بعدی — فقط بی‌صدا به هفتهٔ ۱ برمی‌گردد.

**تصمیم قطعی:** تابع به این قرارداد تغییر می‌کند:
```dart
sealed class MovementProgramWeek {}
class ProgramNotStarted extends MovementProgramWeek {}
class ProgramActiveWeek extends MovementProgramWeek { final int week; final int totalWeeks; }
class ProgramFinished extends MovementProgramWeek { final DateTime finishedOn; }
```
وقتی `(diff ~/ 7) + 1 > totalWeeks` شد، خروجی `ProgramFinished` است و UI باید کارت پایان برنامه با خلاصهٔ دستاوردها و دو گزینه (تکرار برنامه / ساخت برنامهٔ جدید) نشان دهد.

### M-50 — استخراج تعداد هفته‌ها با regex روی شناسهٔ متنی

**واقعیت فعلی:** تعداد کل هفته‌های برنامه این‌گونه به دست می‌آید:
```dart
RegExp(r'^plan_w(\d+)_')   // روی شناسهٔ متنی ردیف‌ها
... ?? 4                   // عدد جادویی در نبود تطابق
```
و در `ensureUpcomingWeekReady`:
```dart
where: 'id LIKE ?', whereArgs: ['plan_w${nextWk}_%']
```
یعنی **ساختار داده در رشتهٔ کلید کدگذاری شده.** هر تغییر در فرمت شناسه — که در فاز ۰ اتفاق می‌افتد — این منطق را بی‌صدا می‌شکند.

**تصمیم قطعی:** هفته یک ستون عددی می‌شود و هرگز از شناسه استخراج نمی‌شود:
- `movement_occurrences.cycleWeek INTEGER` (در `M-23` اضافه شد).
- `totalWeeks` از `movement_strength_programs.totalWeeks` یا `movement_plan_schedules.weeksCount` خوانده می‌شود.
- هر کوئری با `LIKE 'plan_w%'` حذف می‌شود و جایش را `WHERE cycleWeek = ?` می‌گیرد.
- عدد جادویی `4` حذف می‌شود؛ در نبود مقدار، تابع `null` برمی‌گرداند.

**معیار پذیرش:** `grep -rn "plan_w" lib/` بدون نتیجه.

### M-51 — نرخ تکمیل هفته در نبود داده `1.0` می‌شود

**واقعیت فعلی:** `_calculateWeekCompletionRate` وقتی هیچ نسخه‌ای برای هفته وجود ندارد، `1.0` برمی‌گرداند — یعنی «۱۰۰٪ موفق». چون همین عدد ورودی زمان‌بند انطباقی است، سیستم برای کاربری که هیچ کاری نکرده، شدت را افزایش می‌دهد.

**تصمیم قطعی:** امضای تابع به `double?` تغییر می‌کند و در نبود داده `null` برمی‌گرداند. زمان‌بند انطباقی وقتی ورودی `null` می‌گیرد، **هیچ تغییری اعمال نمی‌کند** و در `movement_decision_log` دلیل `INSUFFICIENT_DATA` ثبت می‌کند.

### M-52 — `daysPerWeek` کم می‌شود ولی هرگز برنمی‌گردد

**واقعیت فعلی:** در مسیر انطباق، وقتی نرخ تکمیل پایین است `daysPerWeek` کاهش می‌یابد، ولی هیچ مسیری برای افزایش دوباره وجود ندارد. یعنی یک هفتهٔ بد (مثلاً سفر یا بیماری) برنامه را دائمی کوچک می‌کند و برنامه به مرور تحلیل می‌رود.

**تصمیم قطعی:** دو مقدار جدا نگه دار:
- `targetDaysPerWeek` — هدف مورد توافق کاربر؛ فقط کاربر تغییرش می‌دهد.
- `currentDaysPerWeek` — مقدار تطبیقی هفتهٔ جاری.

قاعده: پس از هر هفته با نرخ تکمیل ≥۸۰٪، `currentDaysPerWeek` یک واحد به سمت `targetDaysPerWeek` بازمی‌گردد. کاهش حداکثر تا `max(2, target - 2)` مجاز است. هر دو تغییر در `movement_decision_log` ثبت می‌شوند و در صفحهٔ تشخیص (`M-99`) قابل مشاهده‌اند.

### M-53 — سیگنال‌های پیشرفت بیش‌از‌حد واکنشی هستند

**واقعیت فعلی:** در `_collectProgressionSignals`:
- پنجرهٔ تحلیل `feelings.take(3)` و `latest.take(2)` است — یعنی دو تا سه دادهٔ آخر.
- یک بار `'HARD'` کافی است تا تصمیم `decrease` شود.
- `if (latest.length < 2) return maintain;` — یعنی دو جلسهٔ اول هر برنامه هرگز پیشرفت نمی‌کنند.

نتیجه: یک جلسهٔ بد (کم‌خوابی، استرس کاری) کل مسیر پیشرفت را عقب می‌برد.

**تصمیم قطعی — قاعدهٔ پیشرفت قانونی:**
```
پنجره: حداقل ۴ جلسهٔ ثبت‌شده، حداکثر ۴۲ روز گذشته.
کمتر از ۴ جلسه -> خروجی null (نه maintain) و زمان‌بند دست نمی‌زند.
increase: درصد تکمیل >= 85٪  و  حداکثر یک جلسهٔ HARD  و  میانگین RPE <= 7
decrease: درصد تکمیل < 50٪  یا  >= ۲ جلسهٔ HARD  یا  میانگین RPE >= 8.5
maintain: بقیه
```
هیچ تصمیم پیشرفتی بدون ثبت در `movement_decision_log` (شامل سیگنال‌های ورودی، نه فقط نتیجه) مجاز نیست.

### M-54 — خطاهای خام SS مستقیم به UI می‌رسند

**واقعیت فعلی:** در `SsSessionCompletionGateway`:
```dart
throw StateError('SS_PRESCRIPTION_NOT_FOUND: $prescriptionId');
...
throw ArgumentError(...)   // وقتی actualMinutes > 240
```
این رشته‌های انگلیسی فنی در مسیر خطا به کاربر فارسی‌زبان نشان داده می‌شوند. علاوه بر این، محدودیت ۲۴۰ دقیقه یک خطای پرتابی است نه یک پیام اعتبارسنجی — کاربری که واقعاً ۵ ساعت کوه‌پیمایی کرده، نمی‌تواند ثبت کند.

**تصمیم قطعی:**
1. هر خطای دامنه به `MovementErrorCode` (فاز ۰) تبدیل می‌شود.
2. سقف مدت جلسه از خطای پرتابی به **هشدار قابل عبور** تبدیل می‌شود: بالای ۲۴۰ دقیقه دیالوگ تأیید نشان داده می‌شود («۵ ساعت و ۲۰ دقیقه ثبت شود؟») و در صورت تأیید ذخیره می‌شود. سقف سخت‌افزاری ۲۴ ساعت است.
3. محدودیت `actualRpe` ۱..۱۰ می‌ماند ولی پیام خطا از `MovementStrings` می‌آید.

### M-55 — دو کلید ایدم‌پوتنسی برای یک رویداد منطقی

**واقعیت فعلی:** تکمیل یک جلسهٔ نسخه‌ای دو کلید یکتایی موازی تولید می‌کند:
- `workout_logs` با `UNIQUE(sourceModule='ss_prescription', sourceEntityId=<presId>)` و شناسهٔ `'wlog_ss_${prescription.id}'`.
- `ss_workout_session_log` با `UNIQUE idx_ss_session_log_prescription(prescriptionId)`.

اگر یکی موفق و دیگری ناموفق شود، سیستم در حالت نیمه‌تکمیل می‌ماند و هیچ مکانیزم آشتی وجود ندارد.

**تصمیم قطعی:** پس از ادغام جداول (فاز ۲) فقط یک کلید می‌ماند:
```sql
CREATE UNIQUE INDEX IF NOT EXISTS idx_movement_workout_logs_occurrence
  ON movement_workout_logs(occurrenceId) WHERE occurrenceId IS NOT NULL;
```
و کل عملیات تکمیل (لاگ + تغییر وضعیت occurrence + لغو یادآور + رویداد) در یک تراکنش واحد انجام می‌شود.

### M-56 — مفهوم هفتهٔ دیلود منتقل می‌شود (قابلیت ارزشمند SS)

**واقعیت فعلی:** SS مفهوم `isDeloadWeek(week, deloadEveryNWeeks:)` و ستون `deloadEveryNWeeks DEFAULT 4` دارد. `movement` هیچ معادلی ندارد (فقط `deloadWeekIndex` در برنامهٔ قدرتی که جای دیگری مصرف نمی‌شود).

**تصمیم قطعی:** دیلود به ماژول قانونی منتقل می‌شود:
- تنظیم `movement_deload_every_n_weeks` در `movement_preferences` (پیش‌فرض ۴؛ `0` یعنی غیرفعال).
- در هفتهٔ دیلود، `MovementHorizonService` همان occurrence ها را می‌سازد ولی `intensityTier = 'DELOAD'` و هدف زمانی ۶۰٪ می‌شود.
- در UI باید صریحاً برچسب «هفتهٔ سبک‌سازی» با توضیح یک‌خطی نمایش داده شود — کاربر نباید خیال کند برنامه خراب شده.

### M-57 — مفهوم نسخه (`prescription`) در occurrence جذب می‌شود

**تصمیم قطعی:** با ستون‌های جدید `M-23`، دیگر جدول نسخه لازم نیست. قرارداد جدید:
- `movement_occurrences` = «چه چیزی برای چه روزی تجویز شده».
- `movement_workout_logs` = «چه چیزی واقعاً انجام شد».
- رابطه یک‌به‌یک از طریق `occurrenceId`.

هر جایی که کد فعلی `SessionPrescription` مصرف می‌کند، باید به `MovementOccurrence` تغییر کند. کلاس `SessionPrescription` و `SsPrescriptionRepository` حذف می‌شوند.

### M-58 — مقادیر پیش‌فرض کور در تبدیل نوع جلسه

**واقعیت فعلی:** نگاشت `SlotType` به کد فعالیت به مقادیر ثابت `SS_SESSION`، `CARDIO_GENERIC`، `YOGA`، `WALKING`، `OTHER` ختم می‌شود که هیچ‌کدام با هشت شناسهٔ واقعی `movement_activity_kinds` (`kind_walking`، `kind_running`، `kind_cycling`، `kind_swimming`، `kind_team_sports`، `kind_hiking`، `kind_yoga_mobility`، `kind_strength`) مطابقت ندارند.

**تصمیم قطعی:** یک جدول نگاشت صریح و تک‌نقطه‌ای در `movement_slot_mapping.dart` بساز:
```
STRENGTH     -> kind_strength
CARDIO       -> kind_running
MOBILITY     -> kind_yoga_mobility
ACTIVE_REST  -> kind_walking
REST         -> بدون activityKind؛ occurrence با status='restDay'
```
هر کد ناشناخته باید خطای صریح بدهد، نه اینکه به `OTHER` بیفتد.

### 🚦 دروازهٔ پذیرش فاز ۴

- [ ] فقط یک سرویس آمادگی وجود دارد و منطق غنی SS درونش است.
- [ ] دیتابیس خالی → `tier == unknown && score == null`.
- [ ] `grep -rn "?? 3\|?? 1" lib/features/movement/application/movement_readiness_service.dart` بدون نتیجه.
- [ ] منطق سقف تجمیعی است؛ تست «قاعدگی + انرژی ۱ + خواب ۴ ساعت» باید `minimal` بدهد.
- [ ] گارد `cycle_consent_sports` حفظ شده.
- [ ] `grep -rn "plan_w" lib/` بدون نتیجه.
- [ ] `MovementProgramWeek` سه حالته است و حالت پایان برنامه در UI دیده می‌شود.
- [ ] پیشرفت با کمتر از ۴ جلسه هیچ تغییری اعمال نمی‌کند.
- [ ] هیچ `throw StateError` یا `ArgumentError` با متن خام در مسیر UI نیست.
- [ ] سه فرمان تأیید سبز.

---

## فاز ۵ — کد مرده و وعده‌های دروغین

قاعدهٔ این فاز: هر قابلیتی که در کد پیاده شده ولی هرگز فراخوانی نمی‌شود، دو سرنوشت بیشتر ندارد: **یا وصل می‌شود یا حذف**. رها کردنش در درخت کد ممنوع است.

### M-59 🔥 — کل سرویس اعلان کد مرده است

**واقعیت فعلی:** `MovementNotificationService` (حدود ۹ کیلوبایت) متدهای کاملی برای `scheduleSessionReminder`، یادآور صبح، و یادآور جلسهٔ نیمه‌تمام دارد. جستجو در کل ماژول نشان می‌دهد **هیچ مسیری این متدها را صدا نمی‌زند**. یعنی کاربر در ویرایشگر برنامه نوع یادآور را انتخاب می‌کند، مقدار در `movement_plan_templates.reminderType` ذخیره می‌شود، و **هیچ اعلانی هرگز زمان‌بندی نمی‌شود**.

این جدی‌ترین نوع باگ است: محصول یک وعدهٔ صریح به کاربر می‌دهد و عمل نمی‌کند.

**تصمیم قطعی:** سرویس به متد مرکزی `applyOccurrenceTransition` (فاز ۳، `M-37`) و به مسیر ذخیره/ویرایش برنامه وصل می‌شود. قرارداد فراخوانی:

| رویداد | اقدام اعلان |
|---|---|
| occurrence جدید ساخته شد | زمان‌بندی یادآور مطابق `reminderType` قالب |
| occurrence به `completed`/`partial`/`skipped`/`moved` رفت | لغو `mov_rem_<id>` |
| occurrence جابه‌جا شد | لغو مبدأ + زمان‌بندی مقصد |
| قالب حذف/آرشیو شد | لغو همهٔ یادآورهای مربوطه |
| جلسه نیمه‌تمام رها شد | زمان‌بندی `mov_partial_<id>` |
| ماژول خاموش شد | لغو همهٔ یادآورهای با `sourceSystem = 'movement'` |

**معیار پذیرش:** تست با fake از `NotificationGateway`: برنامهٔ دوروزه بساز → دقیقاً دو `schedule` ثبت شود؛ یکی را تکمیل کن → دقیقاً یک `cancel` با شناسهٔ درست ثبت شود.

### M-60 — زمان‌بندی یادآور گارد زمان گذشته ندارد

**واقعیت فعلی:** هیچ جای سرویس بررسی نمی‌کند که زمان محاسبه‌شده در گذشته نباشد. وقتی برنامهٔ چندهفته‌ای ساخته می‌شود، occurrence های امروز که ساعتشان گذشته هم وارد صف می‌شوند. بسته به پلتفرم، نتیجه یا خطاست یا بدتر: شلیک فوری چندین اعلان پشت سر هم.

**تصمیم قطعی:** پیش از هر `schedule`، اگر `scheduledAt.isBefore(clock.nowLocal())` بود، زمان‌بندی انجام نمی‌شود و در خروجی متد، شمارندهٔ `skippedPastDue` برمی‌گردد. این عدد در صفحهٔ تشخیص (`M-99`) دیده می‌شود.

### M-61 — مقادیر تاریخ ساختگی در مسیر اعلان

**واقعیت فعلی:** در ساخت زمان یادآور، وقتی پارس تاریخ شکست می‌خورد، مقادیر ثابت جایگزین می‌شوند:
```dart
int.tryParse(parts[0]) ?? 2026,
int.tryParse(parts[1]) ?? 1,
int.tryParse(parts[2]) ?? 1,
```
یعنی در صورت دادهٔ خراب، اعلانی برای اول ژانویهٔ ۲۰۲۶ زمان‌بندی می‌شود. عدد `2026` هم یعنی این کد سال آینده رفتار دیگری خواهد داشت.

**تصمیم قطعی:** پارس تاریخ فقط از `MovementDate.fromDateIso` انجام می‌شود که `DateTime?` برمی‌گرداند. در صورت `null`، زمان‌بندی انجام نمی‌شود و یک ردیف خطا در `movement_analytics_events` ثبت می‌شود. **هیچ عدد تاریخ ثابتی در کل ماژول مجاز نیست.**

**معیار پذیرش:** `grep -rnE "\?\? *(19|20)[0-9]{2}" lib/features/movement` بدون نتیجه.

### M-62 — حریم خصوصی اعلان هرگز اعمال نمی‌شود

**واقعیت فعلی:** ماژول مقدار `NotificationPrivacy.redacted` را می‌شناسد و متن‌های خنثی (`notificationNeutralTitle`، `notificationNeutralBody`) در `MovementStrings` هم آماده است، ولی پارامتر `isPrivate` هرگز از تنظیمات کاربر خوانده و پاس داده نمی‌شود. یعنی کل زیرساخت حریم خصوصی ساخته شده ولی وصل نیست.

**تصمیم قطعی:** کلید `quiet_mode` در `movement_preferences` منبع حقیقت است. هر فراخوانی `NotificationGateway.schedule` باید مقدار را بخواند و در حالت روشن، `NotificationPrivacy.redacted` با متن‌های خنثی بفرستد. در صفحهٔ تنظیمات، کنار این کلید پیش‌نمایش واقعی متن اعلان نشان داده می‌شود.

### M-63 — دو فیلد یادآور ذخیره می‌شوند و هرگز خوانده نمی‌شوند

**واقعیت فعلی:** `movement_plan_templates.reminderType` و `movement_plan_templates.reminderOffsetMin` در مسیر ذخیره نوشته می‌شوند ولی در هیچ کوئری خوانده نمی‌شوند.

**تصمیم قطعی:** با وصل شدن `M-59` مصرف می‌شوند. قرارداد معنایی را صریح کن:
```
reminderType = 'none'      -> هیچ یادآوری
reminderType = 'atTime'    -> دقیقاً در startTime
reminderType = 'before'    -> startTime منهای reminderOffsetMin
reminderType = 'morning'   -> ساعت default_reminder_time همان روز
```
هر مقدار دیگر در دیتابیس به `'none'` نگاشت می‌شود و در گزارش فاز ذکر می‌شود. اگر `reminderType = 'before'` ولی `reminderOffsetMin` خالی باشد، یادآور زمان‌بندی نمی‌شود (مقدار پیش‌فرض نمی‌سازیم).

### M-64 — نه کلید تنظیمات مرده

**واقعیت فعلی:** `MovementPreferencesService` این کلیدها را می‌خواند و می‌نویسد و در صفحهٔ تنظیمات هم کلید دارند، ولی هیچ مصرف‌کننده‌ای در منطق اپ ندارند:
```
distance_unit • weight_unit • morning_reminder • pre_session_reminder
keep_screen_on • sound_enabled • countdown_seconds
smart_suggestions_enabled • intervention_level • plan_b_behavior
```
کاربر واحد را روی کیلومتر یا مایل می‌گذارد و هیچ عددی در اپ تغییر نمی‌کند. کلید «روشن ماندن صفحه» را روشن می‌کند و صفحه وسط جلسه خاموش می‌شود.

**تصمیم قطعی — سرنوشت تک‌تک:**

| کلید | اقدام |
|---|---|
| `distance_unit` | وصل شود: هر نمایش مسافت از یک فرمتر مرکزی عبور کند |
| `weight_unit` | وصل شود: همان قاعده برای وزنه |
| `morning_reminder` ، `pre_session_reminder` | وصل شوند به `M-59` |
| `keep_screen_on` | وصل شود به `WakelockPlus` یا معادل؛ اگر پکیجِ لازم در `pubspec.yaml` نیست، کلید حذف شود (افزودن پکیج ممنوع است — قاعدهٔ ۰-۱۴) |
| `sound_enabled` ، `countdown_seconds` | وصل شوند به شمارش معکوس شروع جلسه و به `SsAudioCuePlayer` منتقل‌شده |
| `smart_suggestions_enabled` | وصل شود به `MovementSuggesterService` (`M-21`) |
| `intervention_level` ، `plan_b_behavior` | وصل شوند به منطق `PlanBSheet` |

**قاعده:** هر کلیدی که در پایان این فاز مصرف‌کننده ندارد، **از صفحهٔ تنظیمات حذف می‌شود**. نمایش کلید بی‌اثر به کاربر ممنوع است.

### M-65 — حذف کامل داده ناقص است

**واقعیت فعلی:** `deleteAllMovementData` فقط زیرمجموعه‌ای از جداول را پاک می‌کند. جداول SS، اعلان‌های زمان‌بندی‌شده، و ترجیحات دست‌نخورده می‌مانند. کاربری که «حذف همهٔ داده‌ها» را می‌زند، هفتهٔ بعد یادآور تمرین دریافت می‌کند.

**تصمیم قطعی:** متد بازنویسی می‌شود تا در یک تراکنش:
1. همهٔ جداول با پیشوند `movement_` را خالی کند (فهرست از `sqlite_master` خوانده شود، نه لیست هاردکد — تا جداول آینده هم خودکار پوشش داده شوند).
2. همهٔ اعلان‌های با `sourceSystem = 'movement'` را لغو کند.
3. seed اولیه (هشت نوع فعالیت و ۱۲ گروه عضلانی) را دوباره بریزد.
4. یک `RitmoEvent` منتشر کند تا آژاندا و داشبورد به‌روز شوند.

در UI، این عملیات باید دیالوگ تأیید با `impactList` داشته باشد که **تعداد دقیق ردیف‌های حذف‌شدنی** را قبل از اجرا نشان می‌دهد (`ConfirmDialog` در ماژول این قابلیت را دارد).

### M-66 — ثبت رکورد شخصی: سه مشکل هم‌زمان

**واقعیت فعلی:**
1. `evaluateAndSaveRecord` در هیچ مسیری فراخوانی نمی‌شود — پس هیچ رکورد شخصی از مسیر عادی ثبت نمی‌شود.
2. پردیکات جستجوی رکورد قبلی از `OR` بدون پرانتز استفاده می‌کند؛ با تقدم `AND` بر `OR` در SQL، شرط عملاً چیز دیگری را می‌سنجد.
3. `movement_personal_records` قید یکتایی ندارد، پس حتی اگر وصل شود، رکوردهای تکراری انباشته می‌شوند.

**تصمیم قطعی:**
- ایندکس یکتایی `idx_movement_pr_unique` (فاز ۲، `M-23`) مبنا است.
- پردیکات با پرانتز صریح بازنویسی می‌شود.
- متد در پایان هر جلسهٔ تکمیل‌شده درون همان تراکنش تکمیل صدا زده می‌شود.
- وقتی رکورد جدیدی ثبت شد، در صفحهٔ خلاصهٔ جلسه با یک نشانهٔ مشخص و مقدار قبلی/جدید نمایش داده می‌شود (این یکی از معدود لحظات پاداش واقعی ماژول است و نباید بی‌صدا باشد).

### M-67 🔥 — صفحهٔ پیشرفت قدرتی عدد جعلی نشان می‌دهد

**واقعیت فعلی:** در `MovementProgressService.getStrengthProgressData`:
- `completionRate: 0.85` هاردکد است — یعنی هر کاربری، با هر میزان تمرین، عدد ۸۵٪ می‌بیند.
- حجم هفتگی زیر یک کلید ثابت `'تمرین'` جمع می‌شود — پس نمودار تفکیک حرکت‌ها همیشه یک ستون دارد.

**تصمیم قطعی:** هر عددی که قابل محاسبه نیست، `null` است و UI به‌جای عدد، حالت خالی با توضیح نشان می‌دهد. قالب خروجی اجباری برای هر متریک در کل لایهٔ پیشرفت:
```dart
class MovementMetric<T> {
  final T? value;
  final int sampleSize;              // تعداد ردیف واقعی پشت این عدد
  final MovementMetricReason reason; // ok | noData | partialData | notApplicable
}
```
حجم هفتگی باید بر اساس `movement_set_logs` (وزن × تکرار) و به تفکیک `exerciseId` محاسبه شود، نه یک کلید ثابت.

### M-68 🔥 — نمودار روند: بازه نادیده گرفته می‌شود و برچسب‌ها بی‌معنا هستند

**واقعیت فعلی:** در `getTrendData`:
- پارامتر `range` (`week`، `month`، `threeMonths`، `all`) دریافت می‌شود ولی در کوئری اعمال نمی‌شود — کاربر فیلتر را عوض می‌کند و نمودار تکان نمی‌خورد.
- برچسب هر ستون این‌گونه ساخته می‌شود:
  ```dart
  'هفته ${(dt.difference(DateTime(2025, 1, 1)).inDays ~/ 7) + 1}'
  ```
  یعنی کاربر برچسب‌هایی مثل «هفته ۸۵» می‌بیند که نسبت به یک مبدأ مخفی در ژانویهٔ ۲۰۲۵ شمارش شده‌اند.
- `volumeKg` هاردکد `0.0` است.

**تصمیم قطعی:**
1. `range` واقعاً به `WHERE dateIso >= ?` ترجمه شود (`week` → ۷ روز، `month` → ۳۰، `threeMonths` → ۹۰، `all` → بدون فیلتر).
2. برچسب‌ها شمسی و نسبی باشند (`Jalali.fromDateTime(...).formatter.mN` در پروژه در دسترس است) — مثلاً «۱۲ مرداد» یا «هفتهٔ گذشته»، نه شمارهٔ مطلق.
3. `volumeKg` از `movement_set_logs` محاسبه شود؛ در نبود داده `null` باشد نه صفر. صفر یعنی «تمرین کردی و هیچ وزنی نزدی»؛ `null` یعنی «نمی‌دانیم». این دو را هرگز یکی نکن.

### M-69 🔥 — `getKpiData`: خطای یک‌روزه، فرمت تاریخ مخلوط، و پایبندی ۱۰۰٪ جعلی

**واقعیت فعلی:** سه نقص مستقل در یک متد:
1. پایان بازه این‌گونه ساخته می‌شود:
   ```dart
   final endDateIso = _formatIso(targetNow.add(const Duration(days: 1)));
   ```
   یعنی فردا هم داخل بازه است.
2. در بعضی کوئری‌ها ستون `dateIso` (فقط تاریخ) با مقادیر ISO کامل (با زمان) مقایسه می‌شود — مقایسهٔ رشته‌ای در SQLite نتیجهٔ نادرست می‌دهد.
3. `adherence` در نبود هر برنامه‌ای مقدار `1.0` می‌گیرد — کاربری که هیچ برنامه‌ای ندارد، «۱۰۰٪ پایبندی» می‌بیند.

**تصمیم قطعی:**
- بازه بسته‌باز باشد: `dateIso >= :start AND dateIso <= :endInclusive` که `endInclusive` دقیقاً امروز است.
- همهٔ مقایسه‌های تاریخ از طریق `MovementDate.toDateIso` بروند؛ هیچ جا تاریخ کامل با ستون `dateIso` مقایسه نشود.
- `adherence` در نبود برنامه `null` است (`MovementMetric.notApplicable`) و UI متن مناسب نشان می‌دهد.

### M-70 — بار عضلانی تعداد ست را به جای حجم می‌شمارد

**واقعیت فعلی:** `getMuscleWorkload` تعداد ست‌ها را می‌شمارد و برچسب‌های ناسازگار `'سایر'` و `'عمومی'` تولید می‌کند. ۳ ست اسکوات با ۱۰۰ کیلو و ۳ ست جلوبازو با ۵ کیلو برابر شمرده می‌شوند.

**تصمیم قطعی:** بار عضلانی = مجموع `weightKg × reps` برای ست‌های `completed = 1`، به تفکیک `movement_muscle_groups.code` از طریق `movement_exercise_muscles` (نقش `PRIMARY` وزن ۱، `SECONDARY` وزن ۰٫۵). ست‌های بدون وزن (مثل حرکات با وزن بدن) در خروجی جداگانه به‌عنوان `bodyweightSets` برمی‌گردند، نه اینکه با وزن صفر در حجم گم شوند.

### M-71 — مسیرهای نام‌دار ثبت‌نشده

**واقعیت فعلی:** `MovementRoutes` دوازده مسیر نام‌دار تعریف می‌کند (`movement.center`، `movement.picker`، `movement.plan_editor`، `movement.occurrence`، `movement.session`، `movement.summary`، `movement.strength`، `movement.strength.onboarding`، `movement.strength.preview`، `movement.progress`، `movement.library`، `movement.settings`)، ولی ناوبری واقعی اپ از `MaterialPageRoute` مستقیم استفاده می‌کند. پیامد مهم: دیپ‌لینک اعلان‌ها (مسیر `navigateFromPayload`) نمی‌تواند کاربر را به جلسهٔ مربوطه ببرد.

**تصمیم قطعی:** هر دوازده مسیر در جدول مسیرهای اپ ثبت می‌شوند و هر کدام آرگومان تایپ‌دار می‌گیرد. پس از آن، اعلان یادآور جلسه باید مستقیماً `movement.occurrence` را با شناسهٔ occurrence باز کند. **تست اجباری:** برای هر دوازده مسیر، تستی که ثبت بودن مسیر را تأیید کند.

### M-72 — قاعدهٔ کلی: موجودی کد مرده

**تصمیم قطعی:** برای هر یک از قطعات زیر، دقیقاً یکی از دو سرنوشت «وصل شد» یا «حذف شد» را انتخاب کن و در گزارش فاز ذکر کن. رها کردن مجاز نیست:

| قطعه | پیشنهاد پیش‌فرض |
|---|---|
| `MovementOccurrenceService.moveOccurrence` | حذف (`M-32`) |
| `MovementAnalyticsService._recordedEventsForTesting` | حذف و جایگزینی با جدول واقعی (`M-20`) |
| `SsCompensationService` | وصل شود به مسیر جبران جلسهٔ از‌دست‌رفته |
| `SsAudioCuePlayer` | وصل شود به `sound_enabled` و شمارش معکوس |
| `ss_ai_memory` | حذف (مصرف‌کنندهٔ معنادار ندارد) |
| `movement_campaigns` | حذف |
| `MovementSuggester` | وصل شود به `SmartFillSheet` (`M-21`) |
| `ss_exercise_similarity` | وصل شود به شیت تعویض حرکت |
| `station_bundles` | وصل شود یا حذف؛ تصمیم را مستند کن |

**معیار پذیرش:** در پایان فاز، `flutter analyze` هیچ هشدار «اعلان استفاده‌نشده» در `lib/features/movement` ندهد.

### 🚦 دروازهٔ پذیرش فاز ۵

- [ ] سرویس اعلان وصل است و تست fake سبز است.
- [ ] گارد زمان گذشته وجود دارد.
- [ ] `grep -rnE "\?\? *(19|20)[0-9]{2}" lib/features/movement` بدون نتیجه.
- [ ] حالت حریم خصوصی اعمال می‌شود.
- [ ] هیچ کلید تنظیماتی بدون مصرف‌کننده در UI نیست.
- [ ] `deleteAllMovementData` جداول را از `sqlite_master` کشف می‌کند و اعلان‌ها را لغو می‌کند.
- [ ] هیچ عدد جعلی در لایهٔ پیشرفت نیست؛ `MovementMetric<T>` همه‌جا استفاده می‌شود.
- [ ] هر دوازده مسیر ثبت شده‌اند.
- [ ] سه فرمان تأیید سبز.

---

## فاز ۶ — یکپارچگی بین‌ماژولی (آژاندا، داشبورد، رویدادها)

ماژول حرکت جزیره نیست. این فاز تضمین می‌کند بقیهٔ اپ دقیقاً یک حقیقت از حرکت می‌بیند.

### M-73 🔥 — دو منبع آژاندا هر دو `AgendaDomain.sport` تولید می‌کنند

**واقعیت فعلی:** دو کلاس مستقل هم‌زمان ردیف ورزشی تولید می‌کنند:
- `MovementAgendaSource` → از `movement_occurrences`.
- `SsAgendaSource` → از `ss_session_prescription` ، `ss_workout_plan` ، `routines` (با `category='fitness'`).

مکانیزم حذف تکراری `SsAgendaSource` کلید `'${domain.name}_${sourceId}_${dateStr}_${title}'` می‌سازد ولی **فقط درون خودش** کار می‌کند — ردیف‌های `MovementAgendaSource` را نمی‌بیند. نتیجهٔ مستقیم: کاربر یک جلسهٔ تمرین را **دو بار** در آژاندای روزانه‌اش می‌بیند، یکی را تکمیل می‌کند و آن یکی همچنان باز می‌ماند.

**تصمیم قطعی:** فقط و فقط `MovementAgendaSource` حق تولید `AgendaDomain.sport` دارد. `SsAgendaSource` حذف می‌شود و از ثبت منابع آژاندا حذف می‌گردد. تنها منطقی که از آن باقی می‌ماند، خواندن روتین‌های ورزشی (`routines.category = 'fitness'`) است که به `MovementAgendaSource` منتقل می‌شود و **در همان جا با occurrence ها دیداپ می‌شود**:
```
قاعدهٔ دیداپ: اگر یک occurrence و یک routine در یک روز، با همان activityKind
و با فاصلهٔ زمانی کمتر از ۶۰ دقیقه باشند، فقط occurrence نمایش داده می‌شود.
```

**معیار پذیرش (الزامی):** تست `test/unit/agenda/movement_agenda_no_duplicates_test.dart`: یک occurrence و یک routine معادل برای یک روز بساز؛ خروجی آژاندای آن روز باید دقیقاً یک ردیف با `AgendaDomain.sport` داشته باشد.

### M-74 — `isModuleEnabled` در منبع آژاندای حرکت هاردکد `true` است

**واقعیت فعلی:** `MovementAgendaSource` مقدار ثابت `true` برمی‌گرداند و هرگز `ModuleGate` را نمی‌خواند. یعنی کاربری که ماژول ورزش را **خاموش کرده**، همچنان جلسات تمرین را در آژاندا می‌بیند.

**تصمیم قطعی:** مقدار از `ModuleGate.instance.isEnabledFrom(settingsMap, 'module_sports_enabled')` خوانده می‌شود (کلید واحد از `M-31`). در حالت خاموش، منبع لیست خالی برمی‌گرداند و **هیچ کوئری‌ای به دیتابیس نمی‌زند**.

### M-75 🔥 — خطای بلعیده‌شده در مسیر آژاندا

**واقعیت فعلی:** در `MovementAgendaSource.load`:
```dart
} catch (_) {}
```
خطای دیتابیس کاملاً بلعیده می‌شود و منبع، لیست خالی برمی‌گرداند. از نظر کاربر، این دقیقاً مثل «امروز تمرینی نداری» به نظر می‌رسد — در حالی که برنامه وجود دارد و دیتابیس خراب است.

**تصمیم قطعی:** خطا ثبت می‌شود (`RitmoLog`) و منبع یک ردیف خطای قابل نمایش برمی‌گرداند (یا پرچم `hasError` در خروجی) تا آژاندا بتواند تفاوت «خالی» و «خراب» را نشان دهد. قاعدهٔ کلی فاز ۰ (ممنوعیت `catch (_) {}`) اینجا هم جاری است.

### M-76 — جابه‌جایی زمانی UTC در آژاندا

**واقعیت فعلی:** در ساخت شناسه و تاریخ آیتم آژاندا:
```dart
start.toIso8601String().substring(0, 10)
```
در تهران (+۳:۳۰)، اگر `start` به UTC تبدیل شده باشد، هر جلسهٔ قبل از ساعت `03:30` بامداد به **روز قبل** منتقل می‌شود و در ترکیب با `M-02` جلسات شب به روز بعد. این دقیقاً همان کلاس باگی است که کاربر را متقاعد می‌کند اپ خراب است ولی در گزارش باگ قابل توضیح نیست.

**تصمیم قطعی:** هر تبدیل تاریخ به رشته از `MovementDate.toDateIso` (محلی) عبور می‌کند.
**معیار پذیرش:** `grep -rn "toIso8601String().substring" lib/` بدون نتیجه.

### M-77 — مدت و اولویت آیتم آژاندا هاردکد است

**واقعیت فعلی:** هر آیتم ورزشی با مدت ثابت ۳۰ دقیقه و مقادیر اولویت ثابت `2.0` / `1.0` تولید می‌شود. یعنی یک دوی ۶۰ دقیقه‌ای و یک کشش ۱۰ دقیقه‌ای در تقویم روزانه دقیقاً هم‌اندازه دیده می‌شوند.

**تصمیم قطعی:** مدت واقعی از این ترتیب گرفته شود: `goalType == 'duration'` ← `goalValue` ؛ وگرنه `movement_activity_kinds.defaultDurationMin` (ستون `M-35`) ؛ وگرنه مدت را `null` بگذار و آژاندا آیتم را بدون طول زمانی رندر کند. اولویت از وضعیت مشتق شود: `inProgress` > `late` > `planned` > `restDay`.

### M-78 — `itemsForDate` به ازای هر روز یک کوئری جداگانه می‌زند

**واقعیت فعلی:** در نمای هفتگی و ماهانهٔ آژاندا، برای هر روز یک فراخوانی مجزا انجام می‌شود؛ برای یک ماه یعنی حدود ۳۰ رفت‌وبرگشت جداگانه به دیتابیس. در SS وضع بدتر است: `load` تمام ردیف‌های سه جدول را **بدون هیچ فیلتر تاریخی** می‌خواند و در حافظه فیلتر می‌کند.

**تصمیم قطعی:** منبع باید متد بازه‌ای داشته باشد:
```dart
Future<Map<String, List<AgendaItem>>> itemsForRange({
  required String startDateIso,
  required String endDateIso,
});
```
یک کوئری با `WHERE dateIso BETWEEN ? AND ?` و گروه‌بندی در حافظه. `itemsForDate` فقط یک پوشش نازک روی آن می‌ماند.

### M-79 — ماژول به رویدادهای سراسری اپ گوش نمی‌دهد

**واقعیت فعلی:** ماژول `RitmoEventBus` را فقط برای **انتشار** مصرف می‌کند و هیچ اشتراکی ندارد. یعنی وقتی کاربر از صفحهٔ دیگری جلسه‌ای را ثبت می‌کند یا دادهٔ خواب/انرژی ثبت می‌شود، مرکز حرکت تا بازسازی دستی بی‌خبر می‌ماند.

**تصمیم قطعی:** `MovementCenterController` در `init` به رویدادهای مرتبط (حداقل `workoutLogChanged` و رویداد تغییر تنظیمات ماژول) مشترک می‌شود و با همان دبونس `M-39` بازتازه‌سازی می‌کند. در `dispose` اشتراک لغو می‌شود — نشت اشتراک ممنوع است.

### M-80 — خاموش کردن ماژول همهٔ اثرات را پاک نمی‌کند

**تصمیم قطعی:** وقتی `module_sports_enabled` خاموش می‌شود، دقیقاً این اتفاقات باید بیفتد (و در تست تأیید شود، مشابه الگوی `test/unit/module_deactivation_sync_test.dart`):
1. همهٔ اعلان‌های با `sourceSystem = 'movement'` لغو شوند.
2. منبع آژاندا هیچ ردیفی برنگرداند.
3. ویجت داشبورد مربوطه مخفی شود.
4. **هیچ داده‌ای حذف نشود** — خاموشی ماژول غیر از حذف داده است. روشن کردن دوباره باید همه‌چیز را بازگرداند.

### M-81 — دیپ‌لینک و پیمایش بین ماژولی

**تصمیم قطعی:** `AgendaDeepLink(domain: AgendaDomain.sport, targetId:, params:)` برای هر آیتم ورزشی ساخته می‌شود و به مسیرهای ثبت‌شدهٔ `M-71` وصل می‌شود:
```
occurrence با status planned/late      -> movement.occurrence
occurrence با status inProgress         -> movement.session
occurrence با status completed/partial  -> movement.summary
restDay                                   -> movement.center با روز انتخاب‌شده
```
لمس روی آیتم آژاندا باید دقیقاً به همان مقصد برسد — نه فقط به صفحهٔ مرکز حرکت.

### M-82 — رندرر آژاندای ورزش باید وضعیت واقعی را منعکس کند

**تصمیم قطعی:** در `sport_agenda_renderer.dart` نگاشت وضعیت به `AgendaCompletion` صریح و کامل شود:
```
planned    -> pending
inProgress -> pending  (با نشانهٔ «در حال اجرا»)
completed  -> done
partial    -> partial
skipped    -> skipped
moved      -> در روز مبدأ نمایش داده نمی‌شود
late       -> missed
restDay    -> آیتم اطلاع‌رسان؛ قابل تکمیل نیست
```
هر وضعیت ناشناخته باید خطای کامپایل بدهد (`switch` جامع بدون `default`) — این تضمین می‌کند وضعیت جدید آینده فراموش نشود.

### 🚦 دروازهٔ پذیرش فاز ۶

- [ ] فقط یک منبع آژاندا برای `sport` ثبت است.
- [ ] تست عدم تکرار آژاندا سبز است.
- [ ] `isModuleEnabled` واقعاً گیت را می‌خواند.
- [ ] `grep -rn "catch (_) {}" lib/features/movement` بدون نتیجه.
- [ ] `grep -rn "toIso8601String().substring" lib/` بدون نتیجه.
- [ ] `itemsForRange` وجود دارد و نمای ماهانه یک کوئری می‌زند.
- [ ] اشتراک `RitmoEventBus` وجود دارد و در `dispose` لغو می‌شود.
- [ ] تست خاموشی ماژول سبز است و هیچ داده‌ای حذف نمی‌شود.
- [ ] سه فرمان تأیید سبز.

---

## فاز ۷ — رابط کاربری و تجربهٔ کاربری

تا اینجا داده درست شده است. این فاز دربارهٔ این است که کاربر چه می‌بیند و چه حسی دارد.

دو قاعدهٔ حاکم بر کل فاز:
1. **هیچ صفحه‌ای نباید مبهم باشد.** هر حالت باید صریح باشد: در حال بارگذاری، داده دارد، خالی، یا خطا.
2. **ماژول قبلاً اجزای خوبی دارد.** ممنوع است جایگزین بسازی وقتی این‌ها موجودند: `MovementScreenShell` ، `skeletons.dart` ، `empty_state_block.dart` ، `error_block.dart` ، `undo_toast.dart` ، `confirm_dialog.dart` (با `impactList`) ، `diff_list.dart` ، `reason_chip.dart` ، `status_chip.dart` ، `offline_banner.dart` ، `movement_semantics.dart` ، `movement_layout.dart` ، `metric_stat.dart`.

### M-83 🔥 — مدیریت وضعیت صفحه با پرچم‌های پراکنده

**واقعیت فعلی:** `MovementCenterController` وضعیت را با چند متغیر مستقل نگه می‌دارد (`_isLoading`، `_errorMessage`، لیست‌های داده، و مشتقات). ترکیب‌های غیرممکن قابل بیان‌اند (مثلاً هم‌زمان در حال بارگذاری و خطا) و در عمل هم رخ می‌دهند. علاوه بر آن، خطا این‌گونه به UI می‌رسد:
```dart
catch (e) { _errorMessage = e.toString(); }
// ...
ErrorBlock(message: _errorMessage!)
```
یعنی کاربر فارسی‌زبان متنی مثل `DatabaseException(no such column: cycleWeek)` می‌بیند.

**تصمیم قطعی:** وضعیت به یک نوع جبری تبدیل می‌شود:
```dart
sealed class MovementViewState {}
class MovementLoading extends MovementViewState {}
class MovementReady   extends MovementViewState { final MovementCenterData data; }
class MovementEmpty   extends MovementViewState { final MovementEmptyKind kind; }
class MovementError   extends MovementViewState { final MovementErrorCode code; final Object? cause; }
```
قواعد:
- `build` یک `switch` جامع روی این نوع است؛ بدون `if (isLoading) ... else if (error != null) ...`.
- متن خطا از `MovementStrings` بر اساس `MovementErrorCode` ساخته می‌شود. `e.toString()` فقط به لاگ می‌رود.
- هر `ErrorBlock` باید دکمهٔ «تلاش دوباره» واقعی داشته باشد که بارگذاری را دوباره اجرا می‌کند.

همین الگو برای تمام کنترلرهای ماژول تکرار می‌شود: پیشرفت، کتابخانه، تنظیمات، جزئیات occurrence، ویرایشگر برنامه، جلسهٔ زنده.

### M-84 — بستار کهنه در نوار روزهای هفته

**واقعیت فعلی:** `WeekRail` کال‌بک `onDayReselected` را در یک بستار می‌گیرد که روی مقدار قدیمی `_selectedDate` بسته شده. وقتی کاربر سریع بین روزها جابه‌جا می‌شود، گاهی روز قبلی مجدداً انتخاب می‌شود.

**تصمیم قطعی:** کال‌بک باید خود تاریخ را پارامتر بگیرد: `onDayReselected(DateTime date)` و کنترلر بر اساس آرگومان تصمیم بگیرد، نه بر اساس حالت بسته‌شده. هیچ ویجتی در ماژول نباید مقدار مشتق‌شده را در بستار ذخیره کند.

### M-85 — شمارهٔ جلسهٔ جاری هاردکد است

**واقعیت فعلی:** در کارت ورود به برنامهٔ قدرتی، مقدار `currentSessionIndex: 1` ثابت پاس داده می‌شود. یعنی کاربر در هفتهٔ ۶ هم می‌بیند «جلسهٔ ۱».

**تصمیم قطعی:** شماره از تعداد جلسات تکمیل‌شدهٔ همان هفته محاسبه شود (`جلسهٔ n از m`)؛ در نبود داده، برچسب حذف شود نه اینکه عدد جعلی نمایش داده شود.

### M-86 — دکمهٔ برنامهٔ قدرتی وضعیت واقعی را نمی‌داند

**واقعیت فعلی:** مسیر `onStrengthHome` مقدار `hasActiveStrengthProgram` را نادیده می‌گیرد؛ کاربری که برنامهٔ فعال دارد و کاربری که ندارد، هر دو به یک صفحه می‌روند.

**تصمیم قطعی:** مسیریابی صریح:
```
برنامهٔ فعال دارد            -> movement.strength (هاب)
پیش‌نویس نیمه‌تمام دارد     -> movement.strength.onboarding با draftStep ذخیره‌شده
هیچ‌کدام                    -> movement.strength.onboarding از قدم ۱
```
ستون‌های `draftStep` و `draftDataJson` در `movement_strength_programs` موجودند و باید واقعاً مصرف شوند — کاربری که وسط آنبوردینگ خارج شده، باید از همان قدم ادامه دهد.

### M-87 🔥 — `SmartFillSheet` به ازای هر پیشنهاد یک تراکنش جداگانه می‌زند

**واقعیت فعلی:** تأیید پر کردن هوشمند هفته، برای هر روز یک `createPlan` جداگانه صدا می‌زند. اگر مورد چهارم شکست بخورد، سه تای اول ذخیره شده‌اند و کاربر با یک هفتهٔ نیمه‌ساخته می‌ماند و پیام خطا هم می‌گیرد.

**تصمیم قطعی:** یک متد دسته‌ای `createPlansBatch(List<MovementPlanDraft>)` که در **یک تراکنش** همه را می‌نویسد. شکست = رول‌بک کامل. پیش از ذخیره، شیت باید `DiffList` کامل نشان دهد (چه چیزی اضافه، چه چیزی جابه‌جا می‌شود) — کامپوننتش موجود است.

### M-88 — لیست occurrence ها مجازی‌سازی نشده

**واقعیت فعلی:** در `movement_center_screen.dart`، بدنهٔ صفحه `CustomScrollView` است ولی هر جلسه یک `SliverToBoxAdapter` جداگانه است که در یک لیست ثابت ساخته می‌شود. یعنی همهٔ کارت‌ها همزمان ساخته می‌شوند. با یک روز شلوغ یا نمای هفتگی، هزینهٔ فریم اول بالا می‌رود.

**تصمیم قطعی:** لیست جلسات به `SliverList.builder` تبدیل می‌شود. هدر، نوار هفته، کارت قهرمان و داک می‌توانند `SliverToBoxAdapter` بمانند. همچنین:
- هر کارت باید `Key` پایدار بر اساس `occurrence.id` داشته باشد.
- `const` بودن ویجت‌های بدون حالت الزامی است.
- فاصلهٔ انتهای لیست دقیقاً `MovementLayout.kDockHeight` باشد تا آخرین کارت زیر داک گم نشود.

### M-89 — پیشنهاد UX: ردیف «چرا این جلسه؟»

**مسئله:** اپ تصمیم‌های زیادی می‌گیرد (انتخاب روز، شدت، دیلود، جابه‌جایی) و هیچ‌کدام را توضیح نمی‌دهد. کاربر حس می‌کند اپ خودسرانه عمل می‌کند.

**تصمیم قطعی:** کامپوننت `reason_chip.dart` از قبل وجود دارد و باید مصرف شود. روی کارت قهرمان و جزئیات occurrence، حداکثر دو چیپ دلیل نشان داده می‌شود، مستقیماً از دادهٔ واقعی:
```
«امروز در برنامهٔ توست»                (منبع: templateId)
«امتیاز آمادگی امروز: ۶۰»                (منبع: readiness)
«هفتهٔ سبک‌سازی»                        (منبع: intensityTier = DELOAD)
«از شنبه جابه‌جا شده»                   (منبع: movedFromOccurrenceId)
«جبران جلسهٔ از‌دست‌رفته»                 (منبع: سرویس جبران)
```
**قاعدهٔ سخت:** چیپ دلیل فقط وقتی نمایش داده می‌شود که دادهٔ پشتیبان واقعی دارد. متن عمومی و تزئینی ممنوع است.

### M-90 — پیشنهاد UX: تکمیل سریع با سوایپ و لغو پنج‌ثانیه‌ای

**مسئله:** ثبت یک جلسهٔ انجام‌شده در حال حاضر چند لمس می‌خواهد. برای کاربری که فقط می‌خواهد بگوید «انجام شد»، این اصطکاک اصلی ماژول است.

**تصمیم قطعی:** روی کارت جلسه، سوایپ افقی فعال شود:
- سوایپ به سمت شروع خط (RTL: راست) ← تکمیل سریع.
- سوایپ به سمت پایان خط ← رد کردن/جابه‌جایی.
- پس از هر دو، `UndoToast` با مهلت ۵ ثانیه نمایش داده شود (کامپوننت موجود است).

**قاعدهٔ حیاتی لغو:** لغو باید **همهٔ اثرات جانبی** را برگرداند: وضعیت occurrence، لاگ تمرین، رکوردهای شخصی ثبت‌شده، **و یادآور لغو‌شده را دوباره زمان‌بندی کند**. این مورد آخر دقیقاً جایی است که پیاده‌سازی‌های لغو می‌شکنند. تست اجباری: تکمیل → لغو → fake اعلان باید دقیقاً یک `cancel` و سپس یک `schedule` با همان شناسه دیده باشد.

### M-91 — پیشنهاد UX: شیت یکپارچهٔ عملیات جلسه

**مسئله:** امروز برای یک جلسه چند شیت جداگانه وجود دارد (`move_session_sheet`، `skip_session_sheet`، `quick_complete_sheet`، `plan_b_sheet`، `week_reshuffle_sheet`، `add_command_sheet`) که مسیرهای ورودی متفاوتی دارند و کاربر نمی‌داند کدام کجاست.

**تصمیم قطعی:** یک شیت واحد `MovementSessionActionsSheet` بساز که با لمس طولانی روی کارت یا دکمهٔ سه‌نقطه باز می‌شود و همهٔ عملیات را یکجا نشان می‌دهد:
```
شروع جلسه • تکمیل سریع • ثبت دستی • جابه‌جایی
نسخهٔ کوتاه • رد کردن • ویرایش قالب • جزئیات
```
شیت‌های موجود حذف نمی‌شوند؛ از این شیت مرکزی فراخوانی می‌شوند. گزینه‌های نامرتبط با وضعیت فعلی **حذف** می‌شوند، نه غیرفعال.

### M-92 — پیشنهاد UX: پیش‌نمایش زنده در ویرایشگر برنامه

**مسئله:** در `activity_plan_editor_screen.dart` کاربر روزها و ساعت و تکرار را انتخاب می‌کند و تا قبل از ذخیره نمی‌داند چه چیزی درست می‌شود.

**تصمیم قطعی:** پایین ویرایشگر، یک نوار پیش‌نمایش چهار هفتهٔ آینده اضافه شود که با هر تغییر فوراً به‌روز می‌شود، بدون نوشتن در دیتابیس. منطق تولید occurrence باید تابع خالص و قابل فراخوانی بدون دیتابیس باشد — همین تابع هم در پیش‌نمایش و هم در ذخیره مصرف می‌شود (تضمین تطابق پیش‌نمایش و نتیجه).

در صورت تداخل با جلسات موجود (`M-35`)، تداخل در همین نوار با رنگ هشدار و نام جلسهٔ مقابل نشان داده می‌شود.

### M-93 — پیشنهاد UX: جستجو، فیلتر و مرتب‌سازی در کتابخانه

**مسئله:** پس از فاز ۲، کتابخانهٔ حرکات صدها ردیف خواهد داشت (`movement_exercises` با نام‌های فارسی و انیمیشن). `movement_library_screen.dart` فعلاً ابزار پیمایش جدی ندارد.

**تصمیم قطعی:** این موارد اضافه شوند:
- جستجوی متنی روی نام فارسی و انگلیسی و مستعارها (`aliasesJson`)، با نرمال‌سازی ارقام فارسی/عربی و ی/ک.
- فیلتر بر اساس گروه عضلانی (۱۲ کد `movement_muscle_groups`) و تجهیزات.
- مرتب‌سازی: تازه‌ترین استفاده • پرتکرارترین • الفبایی.
- بخش «اخیراً استفاده‌شده» در بالای لیست.
- لیست باید `SliverList.builder` باشد و جستجو با دبونس ۲۵۰ میلی‌ثانیه اجرا شود.

### M-94 — مهاجرت قابلیت‌های ارزشمند SS به رابط کاربری حرکت

**تصمیم قطعی:** این اجزای SS باید در `lib/features/movement/presentation/` بازساخته شوند (با تم و کامپوننت‌های خود ماژول، نه کپی مستقیم):

| مبدأ SS | مقصد در حرکت مرکزی | چرا ارزشمند است |
|---|---|---|
| `ss_cant_today_sheet.dart` | شیت «امروز نمی‌توانم»؛ وصل به `plan_b_sheet` | تنها مسیر همدلانهٔ رد کردن در کل دو ماژول |
| `ss_recovery_card.dart` | کارت ریکاوری در مرکز حرکت | `recovery_day_card.dart` فعلی خیلی فقیرتر است |
| `ss_program_diff_sheet.dart` | پیش از هر بازتولید برنامه | کاربر باید ببیند چه چیزی تغییر می‌کند |
| RPE/RIR در ثبت ست | `set_row.dart` و `rir_picker.dart` موجودند؛ کامل شوند | پایهٔ منطق پیشرفت (`M-53`) |
| تعویض حرکت / جایگزین‌ها | `swap_exercise_sheet.dart` موجود است؛ به `movement_exercise_similarity` وصل شود | در نبود تجهیزات، تنها راه ادامهٔ جلسه |
| `ss_ai_coach_sheet.dart` | شیت مربی در حرکت؛ فقط با دادهٔ واقعی | متن راهنما ارزش دارد، ولی باید از `movement_decision_log` تغذیه شود |
| `ss_daily_checkin_widget.dart` | به `readiness_checkin_sheet.dart` ادغام شود | فیلدهای غنی‌تر (درد، خستگی، عضلات دردناک) |
| `ss_audio_cue_player.dart` | جلسهٔ زنده + شمارش معکوس | کلید `sound_enabled` را معنادار می‌کند (`M-64`) |
| `ss_compensation_service.dart` | منطق جبران جلسهٔ از‌دست‌رفته | پشتوانهٔ چیپ دلیل در `M-89` |
| `unified_week_planner_screen.dart` | نمای برنامه‌ریز هفتگی در حرکت | تنها جایی که کل هفته یکجا دیده می‌شود |

**قاعده:** هر جزء مهاجرت‌کرده باید از `context.colors` و `context.modules.sports` و `RitmoSpacing`/`RitmoRadius`/`RitmoTextStyles` استفاده کند و هیچ رنگ یا اندازهٔ ثابتی نداشته باشد.

### M-95 — تجربهٔ آنبوردینگ واحد

**واقعیت فعلی:** دو مسیر آنبوردینگ کاملاً مستقل وجود دارد: `strength_onboarding_flow.dart` (حرکت، ۵ قدم) و `ss_onboarding_flow.dart` (۶۵,۹۰۵ بایت). کاربر ممکن است هر دو را طی کند و دو بار همان سؤال‌ها (هدف، سطح، تجهیزات، روزهای هفته) را جواب دهد — با دو نتیجهٔ متفاوت و دو محل ذخیره.

**تصمیم قطعی:** فقط `strength_onboarding_flow.dart` باقی می‌ماند و به آنبوردینگ کل ماژول ارتقا می‌یابد. دو قدم از SS جذب می‌شوند: پرسش محدودیت‌های فیزیکی/درد، و پرسش زمان در دسترس در هر روز. خروجی در `movement_preferences` و `movement_strength_programs` ذخیره می‌شود. قدم‌ها باید قابل رد شدن باشند و `draftStep` واقعاً ذخیره شود (`M-86`).

### M-96 — فایل‌های غیرقابل‌نگهداری باید شکسته شوند

**واقعیت فعلی — فهرست با اندازهٔ واقعی:**

| فایل | بایت |
|---|---|
| `ss_home_dashboard_screen.dart` | ۱۳۴,۸۰۶ |
| `ss_workout_session_screen.dart` | ۱۱۶,۳۸۴ |
| `ss_onboarding_flow.dart` | ۶۵,۹۰۵ |
| `ss_ai_coach_sheet.dart` | ۴۹,۶۱۱ |
| `ss_workout_session_notifier.dart` | ۴۶,۹۹۳ |
| `movement_plan_sheet.dart` (درخت سوم) | ۴۱,۷۱۰ |
| `ss_progress_screen.dart` | ۳۸,۸۰۴ |
| `movement_log_sheet.dart` (درخت سوم) | ۳۷,۷۲۰ |
| `ss_daily_checkin_widget.dart` | ۳۷,۶۳۷ |
| `ss_plan_day_detail_screen.dart` | ۳۵,۰۳۶ |
| `ss_plan_overview_screen.dart` | ۳۳,۶۲۵ |
| `movement_strings.dart` | ۳۲,۹۷۵ |
| `movement_center_screen.dart` | ۳۲,۶۹۶ |
| `ss_exercise_library_screen.dart` | ۳۲,۲۱۰ |
| `ss_settings_screen.dart` | ۲۹,۸۴۲ |

**تصمیم قطعی:**
1. همهٔ مگااسکرین‌های SS **پس از احراز برابری قابلیت‌ها** (یعنی پس از `M-94`) حذف می‌شوند. این آخرین کار فاز ۷ است، نه اولین.
2. هر فایل باقی‌مانده در `lib/features/movement/**` که بیش از **۸۰۰ خط** باشد، باید شکسته شود. قاعدهٔ شکستن: ویجت‌های فرزند به `widgets/`، شیت‌ها به `sheets/`، منطق به کنترلر/سرویس. **هیچ تغییر رفتاری در این شکستن مجاز نیست** — فقط جابه‌جایی.
3. `movement_strings.dart` استثنا نیست: به فایل‌های موضوعی (`movement_strings_center.dart`، `..._session.dart`، `..._plan.dart`، `..._settings.dart`، `..._errors.dart`) شکسته می‌شود با یک `movement_strings.dart` که فقط صادر می‌کند.

**معیار پذیرش:** `find lib/features/movement -name '*.dart' -exec wc -l {} + | awk '$1 > 800'` خروجی خالی داشته باشد (به جز خط `total`).

### M-97 — حالت‌های خالی باید عمل‌گرا باشند

**تصمیم قطعی:** `empty_state_block.dart` موجود است؛ هر حالت خالی باید دقیقاً یک دکمهٔ اقدام اولیه و یک جملهٔ توضیح داشته باشد:

| جایگاه | پیام | اقدام |
|---|---|---|
| مرکز حرکت، بدون هیچ برنامه | «هنوز برنامه‌ای نداری» | «ساخت برنامه» |
| روز بدون جلسه (`noPlanToday`) | «امروز جلسه‌ای در برنامه نیست» | «ثبت تمرین آزاد» |
| روز استراحت (`restDay`) | توضیح اینکه عمدی است | «کشش سبک» |
| پیشرفت بدون داده | «هنوز داده‌ای برای نمودار نیست» | «ثبت اولین جلسه» |
| کتابخانه بدون نتیجهٔ جستجو | عبارت جستجوشده ذکر شود | «پاک کردن فیلترها» |
| پایان برنامه (`ProgramFinished`) | خلاصهٔ دستاورد | «تکرار» / «برنامهٔ جدید» |
| افق تمام‌شده (`M-34`) | صریحاً بگو برنامه تا کی ادامه دارد | «تمدید برنامه» |

### M-98 — اسکلت به‌جای اسپینر

**تصمیم قطعی:** `skeletons.dart` موجود است و باید در همهٔ مسیرهای بارگذاری ماژول مصرف شود. قاعده:
- بارگذاری اولیه → اسکلت با همان چیدمان محتوای نهایی (بدون پرش چیدمان).
- بازتازه‌سازی در حالی که داده داریم → دادهٔ قبلی باقی بماند با یک نوار پیشرفت نازک بالای صفحه. پاک کردن صفحه در بازتازه‌سازی ممنوع است.
- عملیات خوش‌بینانه (تکمیل/رد) → هیچ اسکلتی؛ فقط تغییر فوری + `UndoToast`.

### M-99 — صفحهٔ تشخیص یکپارچه (فقط حالت توسعه)

**تصمیم قطعی:** صفحهٔ `MovementDiagnosticsScreen` بساز که فقط پشت `dev_only_banner.dart` قابل دسترس است و این‌ها را نشان می‌دهد:
- آخرین ۵۰ ردیف `movement_analytics_events`.
- آخرین ۵۰ ردیف `movement_decision_log` (چرا برنامه تغییر کرد).
- وضعیت افق: آخرین تاریخ occurrence موجود و تعداد هفته‌های باقی‌مانده (`M-34`).
- شمارش اعلان‌های زمان‌بندی‌شده، لغوشده و `skippedPastDue` (`M-60`).
- خروجی `MovementDataDoctor.diagnose(db)`: occurrence های یتیم (با `templateId` ناموجود)، لاگ‌های بدون occurrence، جلسات زندهٔ رهاشده، ردیف‌های `_legacy_*` باقی‌مانده.

این صفحه در بیلد محصول نباید قابل دسترس باشد و نباید در مسیرهای نام‌دار عمومی ثبت شود.

### M-100 — لمس و بازخورد حسی

**تصمیم قطعی:** `RitmoHapticsPolicy` باید یکدست اعمال شود (و تابع کلید `haptic_enabled` باشد):
```
انتخاب روز / تغییر تب           -> selection()
تکمیل جلسه / ثبت رکورد      -> success
خطا / عملیات مسدود            -> error
شروع و پایان تایمر              -> impact
```
هر دکمهٔ ماژول باید حداقل ناحیهٔ لمس ۴۸×۴۸ داشته باشد؛ دکمه‌های کوچک‌تر باید با `MaterialTapTargetSize` یا `Padding` جبران شوند.

### 🚦 دروازهٔ پذیرش فاز ۷

- [ ] `MovementViewState` در همهٔ کنترلرهای ماژول استفاده می‌شود.
- [ ] `grep -rn "e.toString()" lib/features/movement/presentation` بدون نتیجه.
- [ ] هیچ مقدار هاردکد در ویجت‌ها نیست (`currentSessionIndex`، `fontSize`، رنگ).
- [ ] `SmartFillSheet` یک تراکنش می‌زند و `DiffList` نشان می‌دهد.
- [ ] لیست جلسات `SliverList.builder` است.
- [ ] سوایپ تکمیل + لغو ۵ ثانیه‌ای کار می‌کند و یادآور را برمی‌گرداند.
- [ ] همهٔ اجزای جدول `M-94` مهاجرت کرده‌اند و مگااسکرین‌های SS حذف شده‌اند.
- [ ] هیچ فایل بالای ۸۰۰ خط در `lib/features/movement` نیست.
- [ ] هر حالت خالی دکمهٔ اقدام دارد.
- [ ] سه فرمان تأیید سبز.

---

## فاز ۸ — تم، دسترس‌پذیری، بومی‌سازی و RTL

### M-101 — حذف سیستم طراحی دوم

**تصمیم قطعی:** `supplementary_sports_theme.dart` (۵,۶۳۲ بایت) حذف می‌شود (فاز ۲، `M-27`). در این فاز باید تأیید شود که هیچ بازمانده‌ای ندارد:
- `grep -rn "SupplementarySportsTheme\|SsTheme" lib/` بدون نتیجه.
- `grep -rnE "Color\(0x[0-9a-fA-F]{8}\)" lib/features/movement` بدون نتیجه.
- `grep -rn "fontSize:" lib/features/movement` بدون نتیجه (همهٔ متن‌ها از `RitmoTextStyles`).
- `grep -rnE "EdgeInsets\.(all|symmetric|only)\( *[0-9]" lib/features/movement` فقط وقتی مجاز است که مقدار از `RitmoSpacing` بیاید.

### M-102 — حالت تاریک و کنتراست

**تصمیم قطعی:** همهٔ صفحات ماژول باید در حالت روشن و تاریک بررسی شوند. در حالت تاریک، مرزها از `RitmoElevation.borderWidthDark` استفاده کنند. نسبت کنتراست متن اصلی حداقل `4.5:1` و متن ثانویه حداقل `3:1` باشد. **رنگ نباید تنها حامل معنا باشد** — هر وضعیت (تکمیل، ردشده، جابه‌جاشده، عقب‌افتاده) باید آیکون یا متن هم داشته باشد (`status_chip.dart` را برای این تکمیل کن).

### M-103 — دسترس‌پذیری و صفحه‌خوان

**تصمیم قطعی:** `movement_semantics.dart` موجود است و باید به همهٔ اجزای تعاملی ماژول تسری یابد:
- هر کارت جلسه یک برچسب معنایی کامل دارد: نام فعالیت + ساعت + وضعیت.
- هر آیکون‌دکمه `tooltip` دارد.
- نوار روزهای هفته باید نام کامل روز را در `semanticsLabel` داشته باشد، نه حروف تک‌حرفی `['ش','ی','د','س','چ','پ','ج']`.
- تایمر جلسه باید `liveRegion` باشد ولی نه با فرکانس ثانیه‌ای — اعلام هر یک دقیقه.
- پشتیبانی از `MediaQuery.textScalerOf(context)` تا مقیاس ۲٫۰ بدون سرریز چیدمان.

### M-104 — RTL واقعی

**تصمیم قطعی:** در کل ماژول، `left`/`right` ممنوع است و باید به `start`/`end` تبدیل شود:
- `EdgeInsets.only(left:/right:)` → `EdgeInsetsDirectional.only(start:/end:)`
- `Alignment.centerLeft` → `AlignmentDirectional.centerStart`
- `BorderRadius.only` → `BorderRadiusDirectional.only`
- آیکون‌های جهت‌دار (فلش بازگشت، فلش هفتهٔ قبل/بعد) باید در RTL معکوس شوند.
- نوار هفته باید از راست به چپ شروع شود (شنبه اول از راست).
- در متن‌های ترکیبی فارسی + عدد + واحد، از `RitmoNumber.toFa` و `toPersianDigits` استفاده شود تا ترتیب دوجهتی نشکند.

**معیار پذیرش:** `grep -rnE "(EdgeInsets\.only\(.*\b(left|right):|Alignment\.(centerLeft|centerRight|topLeft|topRight|bottomLeft|bottomRight))" lib/features/movement` بدون نتیجه.

### M-105 — بومی‌سازی

**واقعیت فعلی:** در عین وجود `MovementStrings` (۳۲,۹۷۵ بایت)، متن‌های فارسی ثابت در کد پراکنده‌اند (مثال قطعی: `'تمرین حرکتی'` ، `'سایر'` ، `'عمومی'` ، `'تمرین'` ، `'تب ۳'` ، `'محتوای تب ۳'`).

**تصمیم قطعی:**
1. هر رشتهٔ قابل نمایش به `MovementStrings` (یا فایل‌های شکسته‌شدهٔ `M-96`) منتقل می‌شود.
2. رشته‌های مشترک بین ماژول‌ها به `lib/l10n/app_fa.arb` و `app_en.arb` می‌روند و `flutter gen-l10n` اجرا می‌شود.
3. هر متن دارای عدد (مثل «۳ جلسه») باید قالب پارامتری داشته باشد، نه الحاق رشته.
4. متن خطاهای فنی هرگز به کاربر نشان داده نمی‌شود (`M-83`).

**معیار پذیرش:** تست گارد منبع باید هر رشتهٔ حاوی حروف فارسی در فایل‌های `presentation/` را خطا بداند، مگر در فایل‌های رشته.

### M-106 — تاریخ شمسی و ارقام فارسی

**تصمیم قطعی:** هر تاریخ قابل نمایش باید شمسی باشد (`Jalali.fromDateTime`)؛ هیچ تاریخ میلادی در UI مجاز نیست. هر عدد قابل نمایش باید از `RitmoNumber.toFa` یا `toPersianDigits` عبور کند. **اما در دیتابیس همیشه میلادی و ارقام لاتین ذخیره می‌شود** — تبدیل فقط در مرز نمایش رخ می‌دهد. هر جا ورودی کاربر عدد می‌گیرد، ارقام فارسی/عربی باید نرمال شوند.

### M-107 — انیمیشن و حرکت

**تصمیم قطعی:** مدت انیمیشن‌ها یکدست شود (تغییر وضعیت ۲۰۰ms، جابه‌جایی صفحه ۳۰۰ms) و `MediaQuery.disableAnimationsOf(context)` رعایت شود. هیچ انیمیشن حلقوی بی‌پایان در حالت بیکار نباید اجرا شود (مصرف باتری).

### M-108 — حالت آفلاین

**تصمیم قطعی:** `offline_banner.dart` موجود است. چون کل ماژول محلی است، بنر فقط وقتی نشان داده می‌شود که قابلیتی واقعاً به شبکه نیاز دارد (مثل دانلود انیمیشن حرکات). نمایش بنر آفلاین روی محتوای کاملاً محلی ممنوع است — پیام نادرست به کاربر می‌دهد.

### 🚦 دروازهٔ پذیرش فاز ۸

- [ ] هیچ رنگ، اندازهٔ فونت یا فاصلهٔ ثابتی در ماژول نیست.
- [ ] هر دو حالت روشن و تاریک بررسی شده‌اند.
- [ ] وضعیت‌ها فقط با رنگ منتقل نمی‌شوند.
- [ ] گرپ RTL بدون نتیجه.
- [ ] تست گارد رشتهٔ فارسی سبز است.
- [ ] `flutter gen-l10n` بدون خطا اجرا می‌شود.
- [ ] مقیاس متن ۲٫۰ بدون سرریز.
- [ ] سه فرمان تأیید سبز.

---

## فاز ۹ — تست‌ها و تأیید نهایی

این فاز اختیاری نیست. بدون آن، تغییرات فازهای ۰ تا ۸ قابل دفاع نیستند.

### M-109 — زیرساخت تست دیتابیس

**تصمیم قطعی:** یک fixture مشترک در `test/unit/movement/movement_test_db.dart` بساز که با `sqflite_common_ffi` یک دیتابیس in-memory می‌سازد و کل زنجیرهٔ مهاجرت را اجرا می‌کند. قواعد:
- هیچ تستی نباید جدول را دستی بسازد؛ همه از همین fixture عبور کنند (وگرنه تست‌ها طرحوارهٔ واقعی را تأیید نمی‌کنند — دقیقاً همان اشتباهی که باعث شد `M-09` دیده نشود).
- تاریخ/زمان همیشه تزریقی است (`MovementClock`)؛ `DateTime.now()` در تست ممنوع است.

### M-110 🔥 — تست مهاجرت بدون از دست رفتن داده

**تصمیم قطعی:** `test/unit/movement/movement_unification_migration_test.dart` باید دقیقاً این سناریو را اجرا کند:
1. دیتابیس را تا نسخهٔ قبل از مهاجرت وحدت بالا بیاور.
2. در هر چهار خانهٔ داده (`movement_*`، `workout_*`، `ss_*`، `routines`) دادهٔ نمونه بریز — شامل ردیف‌های لبه: تاریخ `NULL`، مدت `0`، ردیف تکراری در دو جدول مبدأ، و یک ردیف با کاراکتر فارسی در متن.
3. مهاجرت را اجرا کن.
4. تأیید کن مجموع ردیف‌های مقصد دقیقاً برابر مجموع ردیف‌های منحصربه‌فرد مبدأ است.
5. تأیید کن هیچ مقداری مخدوش نشده (مقایسهٔ میدان‌به‌میدان برای حداقل ۵ ردیف نمونه).
6. مهاجرت را **دوباره** اجرا کن و تأیید کن هیچ تغییری رخ نمی‌دهد (ایدم‌پوتنسی).

اگر این تست سبز نشود، **مجاز نیستی فاز ۲ را تمام‌شده اعلام کنی.**

### M-111 — تست گارد تصادم طرحواره

**تصمیم قطعی:** `test/unit/movement/schema_collision_guard_test.dart` کل `lib/core/database/` را می‌خواند، هر `CREATE TABLE` را استخراج می‌کند و خطا می‌دهد اگر یک نام جدول در بیش از یک جا تعریف شده باشد. این دقیقاً همان تستی است که اگر وجود داشت، `movement_session_events` هرگز دو تعریف متناقض پیدا نمی‌کرد.

### M-112 — تست جدولی قرارداد روز هفته

**تصمیم قطعی:** `test/unit/movement/movement_date_contract_test.dart` با جدول کامل ورودی/خروجی:

| تاریخ میلادی | `DateTime.weekday` | `MovementDate.ritmoWeekday` | روز فارسی |
|---|---|---|---|
| شنبه | 6 | 0 | شنبه |
| یکشنبه | 7 | 1 | یکشنبه |
| دوشنبه | 1 | 2 | دوشنبه |
| سه‌شنبه | 2 | 3 | سه‌شنبه |
| چهارشنبه | 3 | 4 | چهارشنبه |
| پنجشنبه | 4 | 5 | پنجشنبه |
| جمعه | 5 | 6 | جمعه |

همچنین برای `toLegacySsDay` / `fromLegacySsDay` باید تست رفت‌وبرگشت (round-trip) برای هر هفت روز وجود داشته باشد.

### M-113 — تست‌های منطقهٔ زمانی تهران

**تصمیم قطعی:** تست‌های اجباری برای سناریوهای زیر (منطقهٔ `Asia/Tehran`، اختلاف `+03:30`):
1. جلسهٔ ساعت `23:30` محلی باید `dateIso` همان روز بگیرد، نه روز بعد.
2. جلسهٔ ساعت `02:00` بامداد باید `dateIso` همان روز بگیرد، نه روز قبل.
3. جلسه‌ای که از `23:45` شروع و `00:30` تمام می‌شود، مدت مثبت داشته باشد و به روز شروع نسبت داده شود.
4. محاسبهٔ فاصلهٔ روز تقویمی بین دو تاریخ در دو طرف تغییر ساعت باید درست باشد (از `calendarDaysBetween` استفاده کن، نه `difference().inDays`).

### M-114 — تست‌های یکپارچگی آژاندا

**تصمیم قطعی:** بر اساس الگوی `test/unit/agenda/course_agenda_source_test.dart`:
- عدم تکرار ردیف (`M-73`).
- احترام به گیت ماژول (`M-74`).
- درستی نگاشت وضعیت (`M-82`) — هر هشت مقدار `MovementOccurrenceStatus`.
- درستی مدت و اولویت (`M-77`).
- یک کوئری برای کل بازه (`M-78`) — با شمارندهٔ کوئری در fake دیتابیس.

### M-115 — تست‌های موتور جلسه و برنامه

**تصمیم قطعی:** حداقل این سناریوها باید پوشش داده شوند:
- دو بار `startSession` پشت سر هم → `MovementActiveSessionConflict` (`M-12`).
- `pause` → `resume` → `finish` → مدت محاسبه‌شده دقیق باشد و `durationSource == 'TIMER'` (`M-15`).
- `abandonSession` → وضعیت occurrence به `planned` برنگردد (`M-16`).
- `moveOccurrence` → دقیقاً دو ردیف (مبدأ `moved`، مقصد `planned`) و لغو+زمان‌بندی دوبارهٔ یادآور (`M-32`، `M-37`).
- دو بار اجرای `createPlan` با همان قالب و روز → یک ردیف (`M-33`).
- جهش ساعت به شش ماه بعد → هنوز حداقل ۸ هفته occurrence موجود باشد (`M-34`).
- تداخل بازه‌ای: جلسهٔ `18:00` به مدت ۶۰ دقیقه با جلسهٔ `18:30` تداخل دارد (`M-35`).

### M-116 — تست‌های ویجت

**تصمیم قطعی:** برای مرکز حرکت، سه تست ویجت حداقلی:
1. وضعیت `MovementLoading` → اسکلت دیده می‌شود، هیچ داده‌ای نه.
2. وضعیت `MovementError` → `ErrorBlock` با متن فارسی و دکمهٔ تلاش دوباره؛ متن نباید حاوی `Exception` یا `SqliteException` باشد.
3. وضعیت `MovementEmpty` با `kind = noPlanToday` → دکمهٔ «ثبت تمرین آزاد» دیده می‌شود.

همچنین یک تست روی صفحهٔ باریک (الگوی `test/narrow_screen_fallback_test.dart`) تا سرریز چیدمان در عرض کم رخ ندهد.

### M-117 — تست گارد منبع باید کاملاً سبز شود

**تصمیم قطعی:** `test/unit/movement/movement_source_guards_test.dart` (ساخته‌شده در `M-07`، بر اساس الگوی `test/prompt_036_source_guards_test.dart`) در این فاز باید لیست استثنای خالی داشته باشد. جدول کامل الگوهای ممنوع که باید صفر تطابق داشته باشند:

| # | الگو | دامنه |
|---|---|---|
| 1 | `catch (_) {}` | `lib/features/movement/**` |
| 2 | `debugPrint(` | `lib/features/movement/**` |
| 3 | `DateTime.now()` خارج از `MovementClock` | `lib/features/movement/**` |
| 4 | `toIso8601String().substring` | `lib/**` |
| 5 | `plan_w` | `lib/**` |
| 6 | `?? 2026` و هر `?? <سال>` | `lib/features/movement/**` |
| 7 | `fontSize:` | `lib/features/movement/**` |
| 8 | `Color(0x` | `lib/features/movement/**` |
| 9 | `EdgeInsets.only(left:` و `right:` | `lib/features/movement/**` |
| 10 | `Alignment.centerLeft`/`centerRight`/... | `lib/features/movement/**` |
| 11 | رشتهٔ حاوی حروف فارسی در `presentation/` | خارج از فایل‌های رشته |
| 12 | `SET status` / `'status':` | خارج از `applyOccurrenceTransition` |

### M-118 — تأیید نهایی

**تصمیم قطعی:** پیش از اعلام پایان کار، هر سه فرمان باید بدون هیچ خطا و هیچ هشدار اجرا شوند (مطابق `.agents/AGENTS.md` §۳ که معتبر است):
```bash
flutter analyze                          # ۰ error, ۰ warning
flutter test                             # همه سبز
dart format --set-exit-if-changed lib test
flutter gen-l10n                         # بدون خطا
```
علاوه بر آن، گرپ‌های زیر باید خروجی خالی داشته باشند:
```bash
grep -rn "supplementary_sports" lib/ | grep -v "_legacy_"
grep -rn "SsAgendaSource\|SSReadinessService\|SsWeekResolver" lib/
grep -rn "ss_prescription\|ss_daily_checkin\|ss_exercise\b" lib/
find lib/features/movement -name '*.dart' -exec wc -l {} + | awk '$1 > 800 && $2 != "total"'
```

### 🚦 دروازهٔ پذیرش فاز ۹ (دروازهٔ نهایی پروژه)

- [ ] fixture دیتابیس in-memory وجود دارد و همهٔ تست‌های دیتابیس از آن عبور می‌کنند.
- [ ] تست مهاجرت بدون ازدست‌رفتن داده و ایدم‌پوتنسی سبز است.
- [ ] تست گارد تصادم طرحواره سبز است.
- [ ] جدول قرارداد روز هفته کامل و سبز است.
- [ ] چهار تست منطقهٔ زمانی تهران سبزند.
- [ ] تست‌های آژاندا و موتور جلسه سبزند.
- [ ] سه تست ویجت سبزند.
- [ ] لیست استثنای تست گارد منبع **خالی** است.
- [ ] چهار فرمان تأیید و چهار گرپ نهایی پاک‌اند.
- [ ] هر یکصد و هجده مورد `M-01` تا `M-118` دقیقاً یکی از سه وضعیت «انجام شد / منتفی شد / مسدود شد» را دارد.

---

## ۱۰. قواعد کامیت

یک کامیت به ازای هر فاز. قالب اجباری:

```
fix(movement): phase N — <خلاصهٔ یک‌خطی> [M-xx, M-yy, M-zz]
```

مثال‌ها:
```
fix(movement): phase 1 — رفع تصادم طرحواره و خرابی خاموش دیتابیس [M-09..M-20]
fix(movement): phase 2 — تلفیق ورزش تکمیلی در حرکت مرکزی [M-21..M-31]
```

قواعد:
- متن کامیت فارسی، ولی پیشوند و شناسه‌ها لاتین.
- هر کامیت باید روی درخت کدی زده شود که هر سه فرمان تأیید روی آن سبزند.
- ممنوع: کامیت کردن کد نیمه‌تمام یا فازی که دروازهٔ پذیرشش کامل نشده.
- ممنوع: ترکیب دو فاز در یک کامیت.
- مهاجرت دیتابیس (فاز ۲) باید در کامیت خودش باشد و هیچ تغییر UI همراهش نباشد.

در پایان هر فاز، یک گزارش کوتاه بده با دقیقاً این ساختار:
```
فاز N — تمام شد
انجام شد: M-xx, M-yy, ...
منتفی شد: M-zz (دلیل یک‌خطی)
مسدود شد: M-ww (چه چیزی لازم داری)
فایل‌های تغییریافته: <تعداد>
خروجی سه فرمان تأیید: <وضعیت>
```

---

## ۱۱. تکرار قاعدهٔ اصلی (مهم‌ترین بخش این فایل)

این فایل **خودِ نقشهٔ پیاده‌سازی است**. تحلیل انجام شده، تصمیم‌ها گرفته شده، ترتیب قفل شده است.

**ممنوعیت‌های مطلق:**

1. ننویس «نقشهٔ پیاده‌سازی»، «پلن اجرا»، «تحلیل اولیه»، «پیش‌نویس طراحی»، یا هر سند برنامه‌ریزی دیگر.
2. **بند ڧ۲ فایل `.agents/AGENTS.md` (چرخهٔ اجباری سه‌مرحله‌ای پیش‌نویس ← ارزیابی ← بازنویسی) برای این مأموریت صریحاً لغو شده است.** بندهای ڧ۱ (تحلیل عمیق پیش از تغییر) و ڧ۳ (صفر خطا و صفر هشدار) کاملاً معتبرند.
3. ترتیب فازها را عوض نکن. فاز N+1 پیش از سبز شدن دروازهٔ پذیرش فاز N شروع نمی‌شود.
4. تصمیم‌های قطعی را بازطراحی نکن. اگر تصمیمی واقعاً غیرقابل اجراست، آن مورد را `مسدود شد` علامت بزن و دلیل فنی بنویس — ولی طراحی جایگزین نکن.
5. داده جعل نکن. هیچ عدد پیش‌فرض، هیچ درصد ثابت، هیچ تاریخ جایگزین. «نمی‌دانیم» یک مقدار معتبر است و باید `null` باشد.
6. در تلفیق، مهاجرت کن نه حذف. هیچ جدولی بدون مهاجرت داده `DROP` نمی‌شود؛ قاعدهٔ `_legacy_<name>` (فاز ۲، `M-22`) الزامی است.
7. خارج از فهرست فایل‌های تحت مالکیت (بخش ۰) فایل دستکاری نکن، مگر جایی که صریحاً اجازه داده شده (مهاجرت‌ها، ثبت مسیرها، `l10n`، و `assets` در `M-26`).
8. پکیج جدید به `pubspec.yaml` اضافه نکن.

**معیار پایان کار:**

کار وقتی تمام است که هر یکصد و هجده مورد `M-01` تا `M-118` دقیقاً یک وضعیت نهایی داشته باشد، هر ده دروازهٔ پذیرش فاز سبز باشد، و چهار فرمان تأیید بدون خطا و بدون هشدار اجرا شوند. **نه زودتر.**

در پایان، یک جدول جمع‌بندی نهایی بده با ستون‌های: فاز • تعداد موارد انجام‌شده • تعداد منتفی • تعداد مسدود • وضعیت دروازه.
