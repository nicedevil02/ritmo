# پرامپت اجرایی (لوکال): اصلاح چرخهٔ حیات و حریم خصوصی ماژول «چرخه بدن» در ریتمو

> این سند، دستور کار نهایی است. تو مجری هستی، نه طراح.
> پروژه به‌صورت **لوکال** روی همین سیستم در دسترس تو است و بعد از اتمام با GitHub سینک می‌شود.

---

### ۰.۲ قواعد غیرقابل‌مذاکره

1. **نقشه ننویس.** این سند خودش نقشهٔ نهایی است. هیچ `PLAN.md`، هیچ «فازبندی پیشنهادی من»، و هیچ سند برنامه‌ریزی جدید تولید نکن. مستقیم از فاز ۱ شروع کن و به ترتیب تا فاز ۱۳ برو.
2. **ترتیب فازها اجباری است.** فاز n+1 را قبل از سبز شدن گیت تأیید فاز n شروع نکن.
3. **قبل از تغییر هر فایل، آن فایل را کامل بخوان.** حق حدس زدن امضای متد، نام فیلد، نام کلاس یا نام import را نداری.
4. **از کامپایلر استفاده کن.** برخلاف اجراهای قبلی، این بار کامپایلر در دسترس تو است. بنابراین:
   - در پایان هر فاز `flutter analyze` را اجرا کن.
   - خطاها را همان‌جا رفع کن. **فاز را با خطای باز رها نکن.**
   - حدس زدن دربارهٔ اینکه «احتمالاً کامپایل می‌شود» ممنوع است. اجرا کن و ببین.
5. **نام لاگر را از خود فایل بردار.** در این مخزن دو لاگر متفاوت وجود دارد:
   - `RitmoLog` از `lib/core/logging/ritmo_logger.dart`
   - `RitmoLogger` از `lib/core/observability/ritmo_logger.dart`
   
   در هر فایل دقیقاً همان چیزی را استفاده کن که همان فایل الان import کرده است. هرگز یکی را با دیگری جایگزین نکن. اگر مطمئن نیستی:

```bash
rg -n "import.*ritmo_logger" lib/path/to/file.dart
rg -n "RitmoLog\.|RitmoLogger\." lib/path/to/file.dart
```

6. **قاعدهٔ معماری اعلان را نشکن.** تست `test/notifications/single_gateway_test.dart` بررسی می‌کند که `scheduleExactAlarm` هرگز خارج از `NotificationGateway` و `AlarmPlatform` صدا زده نشود.
7. **هیچ متن قابل‌مشاهده در سطح سیستم‌عامل** (عنوان/بدنهٔ اعلان اندروید، ویجت، نوتیفیکیشن پایدار) نباید این کلمات را داشته باشد: `پریود`، `قاعدگی`، `چرخه`، `سیکل`، `خونریزی`، `period`، `cycle`، `menstrual`، `pregnancy`. متن‌های مجاز در فاز ۲ تعریف شده‌اند.
8. **زبان و سبک:** کامنت‌ها و رشته‌های کاربری فارسی، ارقام با `PersianDigits.toFa`، تاریخ شمسی با `shamsi_date`، چیدمان RTL، فونت `Vazirmatn`.
9. اگر جایی این سند با کد واقعی تناقض داشت، **امضای واقعی کد را رعایت کن** ولی **رفتار خواسته‌شده را تغییر نده**. تناقض را در بخش گزارش نهایی بنویس.
10. توقف برای پرسیدن سؤال لازم نیست. در ابهام، محافظه‌کارانه‌ترین تفسیر را انتخاب کن: بیشترین حفاظت از حریم خصوصی، و **هرگز نوشتن دادهٔ سلامتی بدون تأیید صریح کاربر**.

### ۰.۳ آماده‌سازی و شاخهٔ کاری

```bash
# ۱. مطمئن شو درخت کاری تمیز است
git status --porcelain

# اگر تغییر محلیِ بی‌ربط وجود دارد، متوقف شو و در گزارش نهایی اعلام کن.
# هرگز تغییرات محلی کاربر را stash یا discard نکن.

# ۲. همگام‌سازی با ریموت
git fetch origin
git checkout main
git pull --ff-only origin main

# ۳. ساخت شاخهٔ کاری با همین نام دقیق
git checkout -b fix/cycle-lifecycle-and-privacy

# ۴. نصب وابستگی‌ها
flutter pub get

# ۵. گرفتن خط پایه — قبل از هر تغییر
flutter analyze 2>&1 | tee /tmp/ritmo_analyze_baseline.txt
flutter test 2>&1 | tail -40 | tee /tmp/ritmo_test_baseline.txt
```

**خط پایه را ذخیره کن.** اگر پروژه از قبل خطا یا تست شکسته دارد، آن‌ها را یادداشت کن تا در پایان بتوانی خطاهای «از قبل موجود» را از خطاهای «ساختهٔ خودت» تفکیک کنی. رفع خطاهای از قبل موجودِ بی‌ربط، وظیفهٔ تو نیست — فقط گزارشش کن.

### ۰.۴ کامیت‌ها

- **محدودیت «یک فایل در هر کامیت» دیگر وجود ندارد.** آن محدودیت مربوط به کار با API گیت‌هاب بود. تو لوکال هستی.
- به‌جای آن: **یک کامیت به‌ازای هر فاز**، بعد از سبز شدن گیت تأیید همان فاز.
- الگوی پیام کامیت:

```
fix(cycle): <خلاصهٔ فارسی فاز>

- <تغییر ۱>
- <تغییر ۲>

Phase: <شمارهٔ فاز>
```

- هرگز `git push --force` روی `main` نزن.
- هرگز فایل‌های build را کامیت نکن. قبل از کامیت بررسی کن:

```bash
git status --short
# نباید build/ ، .dart_tool/ ، *.g.dart تولیدی، یا فایل‌های .lock غیرمرتبط دیده شود
```

### ۰.۵ گیت تأیید هر فاز

در پایان هر فاز، این سه دستور را اجرا کن و تا سبز شدن جلو نرو:

```bash
dart format --set-exit-if-changed lib test || dart format lib test
flutter analyze
flutter test
```

اگر `flutter test` کامل کند بود، فقط تست‌های مرتبط را اجرا کن:

```bash
flutter test test/cycle test/notifications
```

ولی در فاز ۱۳ اجرای کامل `flutter test` اجباری است.

---

## ۱. مهاجرت دیتابیس و کلیدهای تنظیمات

### ۱.۱ کشف وضعیت فعلی

```bash
rg -n "version:" lib/core/database/database_helper.dart
rg -n "CREATE TABLE" lib/core/database/schema/tables/system_tables.dart | head -30
rg -n "onUpgrade|migrations" lib/core/database/migration/migrations_registry.dart | head -30
```

### ۱.۲ جدول جدید

هم در `lib/core/database/schema/tables/system_tables.dart` (برای نصب تازه) و هم در `lib/core/database/migration/migrations_registry.dart` (به‌صورت `IF NOT EXISTS`) اضافه کن:

```sql
CREATE TABLE cycle_confirmations (
  id TEXT PRIMARY KEY,
  kind TEXT NOT NULL,
  targetDate TEXT NOT NULL,
  answer TEXT,
  answeredAt INTEGER,
  askCount INTEGER NOT NULL DEFAULT 0,
  lastAskedAt INTEGER,
  createdAt INTEGER NOT NULL,
  updatedAt INTEGER NOT NULL
)
```

ایندکس‌ها:

```sql
CREATE INDEX IF NOT EXISTS idx_cycle_confirm_kind_date ON cycle_confirmations(kind, targetDate);
CREATE INDEX IF NOT EXISTS idx_cycle_confirm_answer ON cycle_confirmations(answer);
```

شمارهٔ نسخهٔ دیتابیس را یک واحد بالا ببر و مهاجرت را با **همان الگوی مهاجرت‌های قبلی همان فایل** ثبت کن. الگو را اول بخوان، بعد تقلید کن.

### ۱.۳ کلیدهای جدید `app_settings`

این کلیدها را با همین پیش‌فرض‌ها، هم در `lib/core/database/seed/seed_service.dart` و هم در بلوک پیش‌فرض‌های `migrations_registry.dart` اضافه کن:

| کلید | پیش‌فرض |
|---|---|
| `cycle_reminder_lead_days` | `'3,1'` |
| `cycle_reminder_hour` | `'10'` |
| `cycle_confirm_start_enabled` | `'true'` |
| `cycle_confirm_end_enabled` | `'true'` |
| `cycle_inbox_mask_enabled` | `'true'` |
| `cycle_confirm_snooze_until` | `''` |

### ۱.۴ افزودن به `CycleSettings`

فایل: `lib/features/cycle/logic/cycle_settings.dart`

```dart
static const String keyReminderLeadDays = 'cycle_reminder_lead_days';
static const String keyReminderHour = 'cycle_reminder_hour';
static const String keyConfirmStartEnabled = 'cycle_confirm_start_enabled';
static const String keyConfirmEndEnabled = 'cycle_confirm_end_enabled';
static const String keyInboxMaskEnabled = 'cycle_inbox_mask_enabled';
static const String keyConfirmSnoozeUntil = 'cycle_confirm_snooze_until';
static const String keyBiometricEnabled = 'cycle_biometric_enabled';

/// آستانهٔ واحد «دورهٔ باز فراموش‌شده».
/// قبلاً همین مفهوم در سه فایل با سه عملگر متفاوت (>=12، >12، <12) پیاده شده بود.
static const int forgottenOpenPeriodDays = 12;

/// مهلت اضافه پیش از پرسیدن «هنوز ادامه دارد؟»
static const int prolongedBleedingGraceDays = 2;

static List<int> getReminderLeadDays(Map<String, String> s);
static int getReminderHour(Map<String, String> s);
static bool isConfirmStartEnabled(Map<String, String> s);
static bool isConfirmEndEnabled(Map<String, String> s);
static bool isInboxMaskEnabled(Map<String, String> s);
static bool isBiometricEnabled(Map<String, String> s);
```

قواعد:

- `getReminderLeadDays`: رشتهٔ کاماجدا را پارس کن، مقادیر خارج از بازهٔ ۱ تا ۱۴ را حذف کن، تکراری‌ها را حذف کن، نزولی مرتب کن، و اگر نتیجه خالی شد `[3, 1]` برگردان.
- `getReminderHour`: بین ۶ و ۲۲ clamp کن، پیش‌فرض ۱۰.
- `isBiometricEnabled`: پیش‌فرض `false`.
- بقیهٔ سوییچ‌ها: پیش‌فرض `true`.

### گیت تأیید فاز ۱

```bash
flutter analyze
flutter test test/cycle
git add -A && git commit -m "fix(cycle): جدول تأییدها و کلیدهای تنظیمات جدید"
```

---

## ۲. متن‌های خنثی — فایل جدید

فایل جدید: `lib/features/cycle/logic/cycle_privacy_text.dart`

```dart
/// تک‌منبعِ همهٔ متن‌هایی که ممکن است بیرون از بخش قفل‌شده دیده شوند.
/// هیچ‌کدام نباید واژهٔ صریح داشته باشند.
abstract final class CyclePrivacyText {
  // سطح سیستم‌عامل — روی قفل‌صفحه و در سایهٔ اعلان
  static const String osPublicTitle = 'ریتمو';
  static const String osPublicBody = 'یک یادآوری خصوصی دارید';

  // عنوان مبهم‌شدهٔ اعلان
  static const String osRedactedTitle = 'ریتمو: یادآوری خصوصی 🌸';
  static const String osRedactedBody = 'برای مشاهده باز کنید';

  // عنوان‌های داخلی — بدون واژهٔ صریح
  static const String leadReminderTitle = 'یادآور ریتم بدنی';
  static String leadReminderBody(int days) =>
      'تا شروع پنجرهٔ ریتم بدنی حدود $days روز مانده است.';

  static const String startConfirmTitle = 'بازبینی ریتم بدنی';
  static const String startConfirmBody =
      'امروز موعد تخمینی آغاز پنجرهٔ ریتم بدنی است. برای تأیید یا اصلاح، باز کنید.';

  static const String endConfirmTitle = 'بازبینی ریتم بدنی';
  static const String endConfirmBody =
      'بر اساس میانگین شما، پنجرهٔ فعلی احتمالاً به پایان رسیده است. برای تأیید، باز کنید.';

  static const String prolongedTitle = 'بازبینی ریتم بدنی';
  static const String prolongedBody =
      'پنجرهٔ فعلی طولانی‌تر از میانگین شما شده است. برای بررسی، باز کنید.';

  // متن ماسک‌شدهٔ صندوق پیام پیش از احراز هویت
  static const String inboxMaskedTitle = 'یادآوری خصوصی';
  static const String inboxMaskedBody = 'برای مشاهده، هویت خود را تأیید کنید.';
}
```

**هیچ رشتهٔ دیگری** برای اعلان‌های چرخه نساز. فازهای بعدی فقط از این کلاس استفاده می‌کنند.

### گیت تأیید فاز ۲

```bash
flutter analyze
git add -A && git commit -m "fix(cycle): تک‌منبع متن‌های خنثی حریم خصوصی"
```

---

## ۳. اصلاح موتور — جدا کردن «واقعیت ثبت‌شده» از «پیش‌بینی»

فایل: `lib/core/domain/engines/cycle_engine.dart`

اول کامل بخوانش:

```bash
wc -l lib/core/domain/engines/cycle_engine.dart
rg -n "isOverdue|daysOverdue|missedCycles|needsUserAttention|isBleeding|dayOfPeriod" lib/core/domain/engines/cycle_engine.dart
```

### ۳.۱ فیلدهای جدید `CycleEngineOutput`

به فیلدهای کلاس و سازندهٔ نام‌دار اضافه کن. **همه پیش‌فرض داشته باشند** تا کد موجود نشکند:

```dart
/// آیا خونریزی امروز از رکورد واقعی کاربر استنتاج شده (نه از میانگین)؟
final bool isBleedingConfirmed;            // پیش‌فرض false

/// دورهٔ بازِ فعلی از میانگین طول دورهٔ کاربر گذشته است.
final bool isOpenPeriodBeyondAverage;      // پیش‌فرض false

/// شمارهٔ روز دورهٔ باز فعلی (۰ اگر دورهٔ بازی نیست).
final int openPeriodDayCount;              // پیش‌فرض 0

/// تاریخ شروع آخرین دورهٔ واقعیِ ثبت‌شده.
final DateTime? actualPeriodStart;

/// امروز دقیقاً موعد تخمینی شروع است.
final bool isStartDueToday;                // پیش‌فرض false

/// موعدهای تخمینی گذشته که کاربر شروعی ثبت نکرده — قدیمی‌ترین اول.
final List<DateTime> missedExpectedStarts; // پیش‌فرض const []

/// منتظر تأیید کاربر برای شروع.
final bool awaitingStartConfirmation;      // پیش‌فرض false

/// منتظر تأیید کاربر برای پایان.
final bool awaitingEndConfirmation;        // پیش‌فرض false
```

همهٔ این‌ها را در `CycleEngineOutput` بازگشتی، در `_emptyOutput` و در مسیر بارداری مقداردهی کن.

### ۳.۲ چهار اصلاح دقیق در `_evaluateWithStart`

**اصلاح ۱ — دورهٔ باز نباید با میانگین بسته شود.**

منطق فعلی چیزی شبیه این است:

```dart
} else {
  if (daysSinceStart < pDuration) {
    isBleeding = true;
    dayOfPeriod = daysSinceStart + 1;
  }
}
```

جایگزین کن با:

```dart
} else {
  // دورهٔ باز: تا تأیید کاربر، وضعیت واقعی «در جریان» است.
  // قبلاً از میانگین pDuration استفاده می‌شد و همین باعث می‌شد UI
  // بی‌اجازه فاز را به فولیکولار ببرد در حالی که رکورد هنوز باز بود.
  if (daysSinceStart <= maxPlausiblePeriodDays) {
    isBleeding = true;
    dayOfPeriod = daysSinceStart + 1;
    openPeriodDayCount = daysSinceStart + 1;
    isOpenPeriodBeyondAverage = daysSinceStart >= pDuration;
    awaitingEndConfirmation =
        daysSinceStart >= pDuration + CycleSettings.prolongedBleedingGraceDays;
  } else {
    hasImplausiblePeriodData = true;
    openPeriodDayCount = maxPlausiblePeriodDays;
    awaitingEndConfirmation = true;
  }
}
```

`isBleedingConfirmed` را `true` بگذار هر وقت رکورد دورهٔ فعلی وجود دارد و `isProjected == false`.

**اصلاح ۲ — موعدِ دقیق امروز باید «سررسید» شمرده شود.**

منطق فعلی:

```dart
final daysOverdue = (!isBleeding && daysSinceStart >= L) ? (daysSinceStart - L) : 0;
final isOverdue = daysOverdue > 0;
```

مشکل: در روز دقیق موعد، `daysSinceStart == L` است، پس `daysOverdue == 0` و `isOverdue == false`؛ یعنی هیچ سیگنالی تولید نمی‌شود. جایگزین کن با:

```dart
final rawOverdue = (!isBleeding && daysSinceStart >= L) ? (daysSinceStart - L) : 0;
final isStartDueToday = !isBleeding && daysSinceStart == L;
final daysOverdue = rawOverdue;
final isOverdue = !isBleeding && daysSinceStart >= L;
```

**اصلاح ۳ — موعدهای ازدست‌رفته نباید ناپدید شوند.**

`missedExpectedStarts` را بساز: برای هر `k` از ۱ تا `floor(daysSinceStart / L)`، تاریخ `cleanStart.add(Duration(days: k * L))` را اضافه کن، به شرط `!isBleeding` و `تاریخ <= cleanNow`. حداکثر ۶ قلم نگه دار.

**اصلاح ۴ — انتظار تأیید شروع.**

```dart
awaitingStartConfirmation = !isBleeding && daysSinceStart >= L;
```

### ۳.۳ ممنوعیت اعلام فاز قطعی بدون تأیید

در بلوک تعیین فاز، **قبل از** بررسی `isBleeding`:

```dart
if (needsUserAttention) {
  phase = CyclePhase.dataStale;
} else if (isBleeding) {
  phase = CyclePhase.menstrual;
} else if (awaitingStartConfirmation) {
  // موعد گذشته و کاربر چیزی ثبت نکرده:
  // حق نداریم فاز فولیکولار را قطعی اعلام کنیم.
  phase = CyclePhase.dataStale;
} else {
  // منطق فعلی فولیکولار/تخمک‌گذاری/لوتئال، بدون تغییر
}
```

### گیت تأیید فاز ۳

```bash
flutter analyze
flutter test test/cycle
git add -A && git commit -m "fix(cycle): تفکیک وضعیت واقعی از پیش‌بینی در موتور"
```

---

## ۴. یکسان‌سازی آستانهٔ ۱۲ روز

همین الان تناقض را ببین:

```bash
rg -n "12" lib/features/cycle/logic/cycle_data_quality_engine.dart lib/features/cycle/presentation/widgets/cycle_overview_tab.dart lib/features/cycle/presentation/cycle_screen.dart lib/features/cycle/logic/cycle_period_repository.dart
```

همه را به `CycleSettings.forgottenOpenPeriodDays` و عملگر `>=` تبدیل کن:

1. `lib/features/cycle/logic/cycle_data_quality_engine.dart` — ثابت محلی `forgottenOpenPeriodThresholdDays` را حذف کن؛ شرط `daysOpen >= CycleSettings.forgottenOpenPeriodDays`.
2. `lib/features/cycle/presentation/widgets/cycle_overview_tab.dart` — در `_isPeriodForgotten` عملگر `> 12` را به `>= CycleSettings.forgottenOpenPeriodDays` تغییر بده.
3. `lib/features/cycle/presentation/cycle_screen.dart` — همهٔ `>= 12` و `< 12` را یکسان کن.
4. `lib/features/cycle/logic/cycle_period_repository.dart` — `maxActivePeriodDays` را حذف کن و همه‌جا `CycleSettings.forgottenOpenPeriodDays` بگذار.

تأیید:

```bash
# نباید هیچ ۱۲ سخت‌کدشدهٔ مرتبط با دورهٔ باز باقی بماند
rg -n "maxActivePeriodDays|forgottenOpenPeriodThresholdDays" lib/
rg -n "daysOpen|daysBetween.*> 12|>= 12|< 12" lib/features/cycle/
```

### گیت تأیید فاز ۴

```bash
flutter analyze
flutter test test/cycle
git add -A && git commit -m "fix(cycle): یکسان‌سازی آستانهٔ دورهٔ باز فراموش‌شده"
```

---

## ۵. مدل و سرویس تأیید تعاملی

### ۵.۱ فایل جدید: `lib/features/cycle/models/cycle_confirmation_models.dart`

```dart
enum CycleConfirmationKind { startDue, startOverdue, endDue, bleedingProlonged }

enum CycleConfirmationAnswer {
  startedToday,
  startedOnOtherDate,
  notStartedYet,
  endedToday,
  endedOnOtherDate,
  stillOngoing,
  snoozed,
  dismissed,
}

class CycleConfirmationRequest {
  const CycleConfirmationRequest({
    required this.id,
    required this.kind,
    required this.targetDate,
    required this.askCount,
    this.answer,
    this.answeredAt,
    this.lastAskedAt,
  });

  final String id;
  final CycleConfirmationKind kind;
  final DateTime targetDate;
  final int askCount;
  final CycleConfirmationAnswer? answer;
  final DateTime? answeredAt;
  final DateTime? lastAskedAt;

  bool get isAnswered => answer != null;

  Map<String, dynamic> toMap();
  factory CycleConfirmationRequest.fromMap(Map<String, dynamic> map);
}
```

`id` قطعی و idempotent باشد:

```dart
static String buildId(CycleConfirmationKind kind, DateTime targetDate) =>
    '${kind.name}_${CycleDateContract.toDayKey(targetDate)}';
```

### ۵.۲ فایل جدید: `lib/features/cycle/logic/cycle_confirmation_service.dart`

کلاس `CycleConfirmationService` با همان الگوی singleton که `CyclePeriodRepository` دارد (`CycleConfirmationService._()` و `static final instance`). اول الگوی موجود را بخوان:

```bash
rg -n "class CyclePeriodRepository|instance =" lib/features/cycle/logic/cycle_period_repository.dart
```

متدهای اجباری:

```dart
/// درخواست‌های بی‌پاسخ و سررسیدشدهٔ امروز. ترتیب اولویت:
/// bleedingProlonged > endDue > startOverdue > startDue
Future<List<CycleConfirmationRequest>> pendingForToday({
  DatabaseExecutor? dbExecutor,
  DateTime? now,
});

/// از خروجی موتور، درخواست‌های لازم را upsert می‌کند. کاملاً idempotent.
Future<void> syncFromEngine({
  required CycleEngineOutput output,
  required Map<String, String> appSettings,
  DatabaseExecutor? dbExecutor,
  DateTime? now,
});

/// ثبت پاسخ کاربر و اعمال اثر آن روی cycle_periods.
Future<void> submitAnswer({
  required CycleConfirmationRequest request,
  required CycleConfirmationAnswer answer,
  DateTime? explicitDate,
  DatabaseExecutor? dbExecutor,
  DateTime? now,
});

/// به تعویق انداختن همهٔ پرسش‌ها تا فردا.
Future<void> snoozeUntilTomorrow({DatabaseExecutor? dbExecutor, DateTime? now});

Future<void> purgeAll({DatabaseExecutor? dbExecutor});
```

#### قواعد `syncFromEngine` — دقیقاً همین‌ها

- اگر `CyclePrivacyGuard.isVisible == false` یا ماژول خاموش یا `isPregnancyMode == true` → `purgeAll()` و برگرد.
- اگر `cycle_confirm_snooze_until` در آینده است → هیچ درخواست جدیدی نساز.
- اگر `output.isStartDueToday && CycleSettings.isConfirmStartEnabled(...)` → upsert `kind: startDue`، `targetDate: today`.
- اگر `output.awaitingStartConfirmation && output.daysOverdue >= 1 && CycleSettings.isConfirmStartEnabled(...)` → upsert `kind: startOverdue`، `targetDate: output.missedExpectedStarts.last`.
- اگر `output.isOpenPeriodBeyondAverage && !output.awaitingEndConfirmation && CycleSettings.isConfirmEndEnabled(...)` → upsert `kind: endDue`، `targetDate: today`.
- اگر `output.awaitingEndConfirmation && CycleSettings.isConfirmEndEnabled(...)` → upsert `kind: bleedingProlonged`، `targetDate: today`.
- **upsert هرگز `answer` موجود را پاک نکند و `askCount` را صفر نکند.**

#### قواعد `submitAnswer` — دقیقاً همین‌ها

| پاسخ | اثر روی داده |
|---|---|
| `startedToday` | `CyclePeriodRepository.instance.startPeriod(today)` |
| `startedOnOtherDate` | `startPeriod(explicitDate)`؛ اگر `explicitDate == null` بود `ArgumentError` بینداز و **هیچ نوشتنی انجام نده** |
| `notStartedYet` | فقط پاسخ ثبت شود؛ **هیچ رکورد دوره‌ای ساخته نشود** |
| `endedToday` | `endPeriod(activeId, today)` |
| `endedOnOtherDate` | `endPeriod(activeId, explicitDate)`؛ همان گارد null |
| `stillOngoing` | **هیچ نوشتنی در `cycle_periods` نشود**؛ فقط `answer` ثبت شود و درخواست بعدی برای ۲ روز بعد زمان‌بندی شود |
| `snoozed` | `cycle_confirm_snooze_until` = فردا |
| `dismissed` | فقط ثبت پاسخ |

بعد از هر `submitAnswer` که رکورد دوره را تغییر داده، به همین ترتیب:

```dart
CycleEngine().invalidate();
await CycleStateNotifier.instance.loadState();
await CycleReminderScheduler.rescheduleAll();
RitmoEventBus().fire(RitmoEvent(type: '<CycleStarted|CycleEnded|CycleUpdated>', payload: {...}));
```

`askCount` سقف ۳ دارد. بعد از سه بار پرسش بی‌پاسخ، دیگر اعلان زمان‌بندی نشود و فقط بنر درون‌برنامه‌ای باقی بماند.

### گیت تأیید فاز ۵

```bash
flutter analyze
flutter test test/cycle
git add -A && git commit -m "fix(cycle): سرویس تأیید تعاملی شروع و پایان"
```

---

## ۶. تک‌منبع کردن اعلان‌ها و حذف سامانهٔ قدیمی

### ۶.۰ اول تناقض را ببین

```bash
rg -n "cycle_rem_|cycle_private_reminder|offsets = " lib/core/services/alarm_scheduler_service.dart
rg -n "cycle_period_t1|cycle_period_t2" lib/
```

این دو خروجی ثابت می‌کنند که دو سامانهٔ موازی اعلان وجود دارد.

### ۶.۱ فایل جدید: `lib/features/cycle/logic/cycle_notification_ids.dart`

```dart
abstract final class CycleNotificationIds {
  static const String entityId = 'cycle_period';
  static const String sourceSystem = 'cycle';
  static const String legacyRoutineId = 'cycle_private_reminder';

  static String lead(int cycleIndex, int leadDays) =>
      'cycle_lead_d${leadDays}_c$cycleIndex';
  static String startConfirm(String dayKey) => 'cycle_confirm_start_$dayKey';
  static String endConfirm(String dayKey) => 'cycle_confirm_end_$dayKey';
  static String prolonged(String dayKey) => 'cycle_confirm_prolonged_$dayKey';

  /// همهٔ شناسه‌های تاریخی که باید در cancelAll پاک شوند.
  static List<String> legacyIds();
}
```

`legacyIds()` باید برگرداند: برای `c` از ۰ تا ۴ مقادیر `cycle_period_t2_c$c` و `cycle_period_t1_c$c`؛ به‌علاوه `cycle_period_t2` و `cycle_period_t1`.

### ۶.۲ بازنویسی `lib/core/services/cycle_notification_service.dart`

- متد `scheduleReminders` را **حذف کن**. قبل از حذف، مصرف‌کننده‌ها را بین ببر:

```bash
rg -n "scheduleReminders" lib/ test/
```

- `scheduleForecastReminders` را با این امضا بازنویسی کن:

```dart
static Future<void> scheduleForecastReminders({
  required List<PredictedCycle> forecastCycles,
  required List<CycleConfirmationRequest> pendingConfirmations,
  required Map<String, String> appSettings,
  required bool consentReminders,
  required bool pregnancyMode,
  DateTime? now,
});
```

رفتار اجباری:

1. اگر `!consentReminders || pregnancyMode || (forecastCycles.isEmpty && pendingConfirmations.isEmpty)` → `cancelAll()` و برگرد.
2. ساعت را از `CycleSettings.getReminderHour` و روزها را از `CycleSettings.getReminderLeadDays` بگیر. **مقادیر ۱۰ و ۲ را hardcode نکن.**
3. برای هر چرخه `c` و هر `leadDays`، اعلان با شناسهٔ `CycleNotificationIds.lead(c, leadDays)` بساز؛ فقط اگر زمانش در آینده است.
4. برای هر قلم `pendingConfirmations` که `askCount < 3` است، اعلان مربوطه بساز.
5. همهٔ `NotificationRequest`‌ها اجباراً:

```dart
NotificationRequest(
  id: <شناسه از CycleNotificationIds>,
  channel: NotificationChannelId.privateChannel,
  scheduledAt: <زمان>,
  title: <عنوان از CyclePrivacyText>,
  body: <بدنه از CyclePrivacyText>,
  privacy: NotificationPrivacy.redacted,
  redactedTitle: CyclePrivacyText.osRedactedTitle,
  redactedBody: CyclePrivacyText.osRedactedBody,
  sourceSystem: CycleNotificationIds.sourceSystem,
  entityId: CycleNotificationIds.entityId,
  payload: {
    'moduleId': 'cycle',
    'requiresAuth': true,
    'publicTitle': CyclePrivacyText.osPublicTitle,
    'publicBody': CyclePrivacyText.osPublicBody,
    'confirmKind': <نام kind یا null>,
  },
)
```

6. الگوی **«اول محاسبه، بعد لغو، بعد زمان‌بندی»** را حفظ کن. اگر محاسبه exception داد، **هیچ‌چیز را لغو نکن**.

`cancelAll()` را گسترش بده تا علاوه بر موارد فعلی:

- همهٔ `CycleNotificationIds.legacyIds()` را لغو کند.
- جدول `pending_reminders` را با `where: 'routineId = ?'` و `whereArgs: [CycleNotificationIds.legacyRoutineId]` کوئری کند، هر `id` را `NotificationGateway.cancel` کند، سپس آن ردیف‌ها را `delete` کند.
- `CentralInboxService.purgeForSource(CycleNotificationIds.sourceSystem)` را صدا بزند (این متد در فاز ۸ ساخته می‌شود — پس این فراخوان را در فاز ۸ اضافه کن تا کامپایل نشکند).

### ۶.۳ حذف قطعی سامانهٔ موازی

فایل: `lib/core/services/alarm_scheduler_service.dart`

بلوکی که با کامنت `// Schedule private cycle reminders if gender is FEMALE and consent is granted` شروع می‌شود و شامل `final offsets = [-7, -3, -1, 0];` و شناسهٔ `cycle_rem_...` و `routineId: 'cycle_private_reminder'` است را **کاملاً حذف کن**.

به‌جای آن، در انتهای `scheduleNextAlarms` فقط:

```dart
await CycleReminderScheduler.rescheduleAll();
```

import‌های بی‌استفاده را حذف کن، ولی **قبل از حذف هر import مطمئن شو جای دیگر همان فایل استفاده نشده**:

```bash
rg -n "CyclePrivacyGuard|ModuleGate" lib/core/services/alarm_scheduler_service.dart
```

بعد از حذف، `flutter analyze` خودش import بی‌استفاده را گزارش می‌دهد — همان را مبنا بگیر.

### ۶.۴ به‌روزرسانی `lib/features/cycle/logic/cycle_reminder_scheduler.dart`

در `rescheduleAll`، بعد از گرفتن `engineOutput`:

```dart
await CycleConfirmationService.instance.syncFromEngine(
  output: engineOutput,
  appSettings: settings,
  dbExecutor: db,
  now: effectiveNow,
);
final pending = await CycleConfirmationService.instance.pendingForToday(
  dbExecutor: db,
  now: effectiveNow,
);
```

قواعد:

- فیلتر فعلی `confidenceLevel != PredictionConfidenceLevel.low` را **فقط برای اعلان‌های lead** نگه دار.
- اعلان‌های تأیید (`pendingConfirmations`) **نباید** با اعتماد پایین فیلتر شوند؛ آن‌ها بر پایهٔ رکورد واقعی هستند نه پیش‌بینی.
- در شرط خروج اولیه (`!isFemale || !isCycleEnabled || !consentReminders || isPregnant`) اضافه کن:

```dart
await CycleConfirmationService.instance.purgeAll(dbExecutor: db);
```

### تأیید فاز ۶

```bash
# نباید هیچ اثری از سامانهٔ قدیمی در lib بماند
rg -n "cycle_rem_" lib/ && echo "خطا: سامانهٔ قدیمی هنوز زنده است" || echo "OK"
rg -n "offsets = \[-7" lib/ && echo "خطا" || echo "OK"

flutter analyze
flutter test test/cycle test/notifications
git add -A && git commit -m "fix(cycle): حذف سامانهٔ موازی اعلان و تک‌منبع کردن یادآورها"
```

---

## ۷. رساندن کانال و حریم خصوصی به لایهٔ Native

**مهم‌ترین فاز.** الان `privateChannel` و `redactedBody` هرگز به اندروید نمی‌رسند. اول خودت ثابتش کن:

```bash
rg -n "invokeMethod" -A 12 lib/core/services/native_bridge.dart | rg -n "id|time|title|isEssential|channel"
```

خواهی دید فقط `id`، `time`، `title`، `isEssential` منتقل می‌شود.

### ۷.۱ `lib/core/platform/alarm_platform.dart`

امضای `scheduleExactAlarm` را در **اینترفیس و در `MethodChannelAlarmPlatform`** به این تغییر بده:

```dart
Future<bool> scheduleExactAlarm({
  required String id,
  required int timeMsUTC,
  required String title,
  required bool isEssential,
  String channelId = 'ritmo_routine_v3',
  String? body,
  String? publicTitle,
  String? publicBody,
  String? moduleId,
  bool requiresAuth = false,
});
```

پارامترهای جدید پیش‌فرض دارند تا mock‌های تست فوراً نشکنند؛ ولی در فاز ۱۲ همهٔ mock‌ها را هم به‌روز می‌کنی.

### ۷.۲ `lib/core/services/native_bridge.dart`

همان پارامترها را اضافه کن و در `invokeMethod` این نقشه را بفرست:

```dart
{
  'id': id,
  'time': timeMsUTC,
  'title': title,
  'isEssential': isEssential,
  'channelId': channelId,
  'body': body,
  'publicTitle': publicTitle,
  'publicBody': publicBody,
  'moduleId': moduleId,
  'requiresAuth': requiresAuth,
}
```

### ۷.۳ `lib/core/notifications/notification_gateway.dart`

در گام «Delegate to platform»:

```dart
final effectiveTitle = decision.isRedacted ? decision.redactedTitle! : req.title;
final effectiveBody = decision.isRedacted ? decision.redactedBody : req.body;
final payload = req.payload ?? const <String, dynamic>{};

return await platform.scheduleExactAlarm(
  id: req.id,
  timeMsUTC: scheduledTimeMs,
  title: effectiveTitle,
  isEssential: req.channel.isEssential,
  channelId: req.channel.nativeId,
  body: effectiveBody,
  publicTitle: payload['publicTitle'] as String?,
  publicBody: payload['publicBody'] as String?,
  moduleId: payload['moduleId'] as String?,
  requiresAuth: payload['requiresAuth'] == true,
);
```

همچنین در گام «Push to Central Inbox» متن اصلی را لو نده:

```dart
final isSensitive = req.privacy != NotificationPrivacy.none;
await CentralInboxService.push(
  // ... مقادیر فعلی
  linkModule: req.payload?['moduleId'] as String?,
  payload: {
    'channel': req.channel.name,
    'privacy': req.privacy.name,
    'isRedacted': decision.isRedacted,
    if (isSensitive) 'sensitive': true,
    if (isSensitive) 'maskedTitle': CyclePrivacyText.inboxMaskedTitle,
    if (isSensitive) 'maskedBody': CyclePrivacyText.inboxMaskedBody,
    ...?req.payload,
  },
);
```

بلوک `NotificationPrivacy.hidden` که در حالت suppressed به inbox push می‌کند را هم با همان کلیدهای `sensitive`/`maskedTitle`/`maskedBody` تجهیز کن.

### ۷.۴ کانال Native

کلاس `RitmoNotificationChannels` را پیدا کن:

```bash
rg -rn "object RitmoNotificationChannels|ESSENTIAL|NORMAL" android/app/src/main/kotlin/ir/ritmo/app/
```

یک ثابت اضافه کن:

```kotlin
const val PRIVATE = "ritmo_private_v3"
```

در `ensure(...)` این کانال را بساز با:

- importance معادل `IMPORTANCE_DEFAULT`
- `setLockscreenVisibility(Notification.VISIBILITY_PRIVATE)`
- `setShowBadge(false)`
- نام فارسی `اعلان‌های خصوصی`

مقدار `ritmo_private_v3` باید **دقیقاً** با `NotificationChannelId.privateChannel.nativeId` در Dart یکی باشد. تأیید:

```bash
rg -n "ritmo_private_v3" lib/ android/
```

### ۷.۵ `android/app/src/main/kotlin/ir/ritmo/app/AlarmChannelRegistrar.kt`

در `SCHEDULE_EXACT_ALARM` این آرگومان‌ها را بخوان:

```kotlin
val channelId = call.argument<String>("channelId")
val body = call.argument<String>("body")
val publicTitle = call.argument<String>("publicTitle")
val publicBody = call.argument<String>("publicBody")
val moduleId = call.argument<String>("moduleId")
val requiresAuth = call.argument<Boolean>("requiresAuth") ?: false
```

`scheduleAlarm` را تغییر بده تا این‌ها را با کلیدهای `channelId`, `body`, `publicTitle`, `publicBody`, `moduleId`, `requiresAuth` در `putExtra` قرار دهد.

### ۷.۶ `android/app/src/main/kotlin/ir/ritmo/app/BootReceiver.kt`

1. در `onReceive` این extra‌ها را بخوان: `channelId`, `body`, `publicTitle`, `publicBody`, `moduleId`, `requiresAuth`.
2. امضای `showAlarmNotification` را به این تغییر بده:

```kotlin
private fun showAlarmNotification(
    context: Context,
    id: String,
    title: String,
    isEssential: Boolean,
    channelIdOverride: String? = null,
    body: String? = null,
    publicTitle: String? = null,
    publicBody: String? = null,
    moduleId: String? = null,
    requiresAuth: Boolean = false
)
```

3. انتخاب کانال:

```kotlin
val channelId = channelIdOverride
    ?: if (isEssential) RitmoNotificationChannels.ESSENTIAL else RitmoNotificationChannels.NORMAL
val isPrivate = channelId == RitmoNotificationChannels.PRIVATE
```

4. `buildSanitizedPublicVersion` را طوری تغییر بده که `publicTitle` و `publicBody` بپذیرد و اگر null بودند به رشته‌های فعلی fallback کند.
5. **اعلان‌های کانال PRIVATE هرگز نباید full-screen شوند.** در ابتدای `shouldUseFullScreen`:

```kotlin
if (channelId == RitmoNotificationChannels.PRIVATE) return false
```

6. **اعلان‌های PRIVATE نباید اکشن‌های `DONE`/`SNOOZE`/`DISMISS` داشته باشند** — اکشن‌ها قابلیت را لو می‌دهند و مسیر احراز هویت را دور می‌زنند. برای `isPrivate` هیچ `addAction` نگذار.
7. Intent لمس اعلان — اگر `moduleId != null`:

```kotlin
val launchIntent = Intent(context, MainActivity::class.java).apply {
    action = "com.ritmo.app.OPEN_MODULE"
    putExtra("moduleId", moduleId)
    putExtra("requiresAuth", requiresAuth)
    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
}
```

در غیر این صورت همان `Intent(context, MainActivity::class.java)` فعلی.

8. اعلان‌های PRIVATE را در گروه non-essential قرار **نده** و در شمارش `summaryCount` دخالت نده. برای `isPrivate` مسیر `digestMode`/`summary` را کامل رد کن و فقط یک `notificationManager.notify` ساده انجام بده.

### ۷.۷ `MainActivity.kt`

1. در `onNewIntent`، در شاخهٔ `"com.ritmo.app.OPEN_MODULE"` علاوه بر `moduleId`، مقدار `requiresAuth` را در یک فیلد `private var openModuleRequiresAuth: Boolean = false` ذخیره کن.
2. در `GET_LAUNCH_INTENT`، در پاسخِ `OPEN_MODULE` کلید `requiresAuth` را هم برگردان:

```kotlin
result.success(mapOf(
    "action" to "OPEN_MODULE",
    "moduleId" to mId,
    "requiresAuth" to openModuleRequiresAuth
))
```

بعد از مصرف، فیلد را `false` کن. برای مسیر cold-start هم `launchIntent.getBooleanExtra("requiresAuth", false)` را برگردان.

3. متدهای private و **بی‌استفادهٔ** `scheduleAlarm` و `cancelAlarm` در `MainActivity` را حذف کن (کار واقعی در `AlarmChannelRegistrar` انجام می‌شود) تا دو منبع موازی نماند. اول تأیید کن واقعاً بی‌استفاده‌اند:

```bash
rg -n "scheduleAlarm|cancelAlarm" android/app/src/main/kotlin/ir/ritmo/app/MainActivity.kt
```

### ۷.۸ اسنپشات بازیابی پس از ریبوت

بدون این گام، بعد از ریبوت اعلان‌های خصوصی روی کانال عمومی و با متن کامل ظاهر می‌شوند.

```bash
rg -n "active_reminders_snapshot" lib/ android/
```

در `lib/core/services/snapshot_sync_service.dart` ساختار `active_reminders_snapshot` را گسترش بده تا `channelId`, `body`, `publicTitle`, `publicBody`, `moduleId`, `requiresAuth` را هم ذخیره کند.

سپس در `BootReceiver.restoreAlarmsFromSnapshot` این فیلدها را با `optString`/`optBoolean` بخوان و در `Intent` بازسازی‌شده `putExtra` کن. در مسیر «اعلان ازدست‌رفتهٔ کمتر از ۲ ساعت» هم همین پارامترها را به `showAlarmNotification` پاس بده؛ و برای کانال PRIVATE **پسوند `(دیرکرد)` را به عنوان اضافه نکن** (متن باید دقیقاً همان متن خنثی بماند).

### گیت تأیید فاز ۷

```bash
flutter analyze

# کامپایل سمت اندروید را حتماً تست کن — تغییرات Kotlin فقط این‌جا معلوم می‌شود
flutter build apk --debug 2>&1 | tail -40

flutter test test/notifications
git add -A && git commit -m "fix(cycle): انتقال کانال خصوصی و متن خنثی به لایهٔ Native"
```

اگر `flutter build apk --debug` در این محیط ممکن نبود (مثلاً Android SDK نبود)، حداقل خطای نحوی Kotlin را با بازخوانی دقیق بررسی کن و این محدودیت را در گزارش نهایی صریحاً اعلام کن.

---

## ۸. ماسک کردن صندوق پیام و مسیریابی به بخش قفل‌شده

### ۸.۱ `lib/core/domain/models/inbox_item.dart`

اضافه کن:

```dart
bool get isSensitive => payload['sensitive'] == true;
String? get maskedTitle => payload['maskedTitle'] as String?;
String? get maskedBody => payload['maskedBody'] as String?;

/// عنوان قابل نمایش با توجه به وضعیت احراز هویت.
String displayTitle({required bool isUnlocked}) =>
    (isSensitive && !isUnlocked) ? (maskedTitle ?? 'یادآوری خصوصی') : title;

String? displayBody({required bool isUnlocked}) =>
    (isSensitive && !isUnlocked) ? maskedBody : body;
```

### ۸.۲ `lib/core/services/central_inbox_service.dart`

متد جدید (همانی که فاز ۶ به آن وابسته بود):

```dart
static Future<void> purgeForSource(
  String sourceSystem, {
  DatabaseExecutor? executor,
}) async {
  // DELETE FROM inbox_items WHERE sourceSystem = ?
  // سپس: RitmoEventBus().fire(RitmoEvent(type: 'inbox_updated', timestamp: DateTime.now(), payload: {}));
  // خطاها با همان الگوی try/catch موجود در این فایل مدیریت شوند.
}
```

حالا برگرد و فراخوان این متد را در `CycleNotificationService.cancelAll()` (فاز ۶.۲) فعال کن.

### ۸.۳ `lib/features/inbox/presentation/inbox_screen.dart`

- فیلد `bool _isUnlocked = false;` اضافه کن.
- در `initState` → `_resolveInitialLockState()`: اگر هیچ آیتم حساسی نیست یا `CycleLockService.instance.isLockEnabled()` مقدار `false` دارد یا `CycleSettings.isInboxMaskEnabled` خاموش است → `_isUnlocked = true`.
- در `_buildInboxRow`، به‌جای `item.title` و `item.body`:

```dart
final shownTitle = item.displayTitle(isUnlocked: _isUnlocked);
final shownBody = item.displayBody(isUnlocked: _isUnlocked);
```

- برای آیتم حساسِ قفل، آیکن را با `CupertinoIcons.lock_fill` جایگزین کن.
- در `onTap`:

```dart
if (item.isSensitive && !_isUnlocked) {
  var ok = await CycleLockService.instance.authenticateBiometric();
  if (!ok && mounted) {
    ok = await showCyclePasscodeSheet(context);
  }
  if (!ok) {
    if (mounted) {
      RitmoToast.show(context, 'برای مشاهده این مورد، تأیید هویت لازم است.');
    }
    return; // هیچ ناوبری‌ای انجام نشود
  }
  setState(() => _isUnlocked = true);
}
await InboxNavigator.open(context, item);
await _loadItems();
```

- `markAllRead` را تغییر نده؛ فقط مطمئن شو رندر همیشه از `displayTitle` می‌گذرد.

### ۸.۴ `lib/features/inbox/logic/inbox_navigator.dart`

یک `case 'cycle':` اضافه کن که:

1. اگر قفل چرخه فعال است، ابتدا احراز هویت انجام شود؛ در صورت شکست `return` بدون ناوبری.
2. اگر `item.payload['confirmKind']` مقدار دارد، بعد از پوش `CycleScreen` یک رویداد fire کن:

```dart
RitmoEventBus().fire(RitmoEvent(
  type: 'CycleConfirmationRequested',
  timestamp: DateTime.now(),
  payload: {'kind': item.payload['confirmKind']},
));
```

3. در غیر این صورت فقط:

```dart
await Navigator.push(context, MaterialPageRoute(builder: (_) => const CycleScreen()));
```

### ۸.۵ `lib/features/today/presentation/now_dashboard_screen.dart`

- هر جایی که `_recentInboxItems` رندر می‌شود، متن باید از `displayTitle(isUnlocked: false)` بیاید. یعنی **در صفحهٔ خانه هرگز متن حساس نمایش داده نمی‌شود** و امکان باز کردن درجا وجود ندارد. محل رندر را پیدا کن:

```bash
rg -n "_recentInboxItems" lib/features/today/
rg -n "recentInbox|inboxItems" lib/features/today/presentation/widgets/dashboard/
```

- در `_checkLaunchIntent`، شاخهٔ `OPEN_MODULE`:

```dart
if (launchInfo != null && launchInfo['action'] == 'OPEN_MODULE') {
  final moduleId = launchInfo['moduleId'] as String?;
  if (moduleId != null && moduleId.isNotEmpty && mounted) {
    // requiresAuth لازم به مدیریت دستی نیست: CycleLockGate خودش قفل را اعمال می‌کند.
    // فقط مطمئن شو هیچ داده‌ای از پیش لود و نمایش داده نمی‌شود.
    _openModuleScreen(moduleId);
  }
  return;
}
```

### گیت تأیید فاز ۸

```bash
flutter analyze
flutter test test/notifications
git add -A && git commit -m "fix(cycle): ماسک پیام‌های حساس در صندوق و مسیر احراز هویت"
```

---

## ۹. اصلاح قفل و کنترل‌های حریم خصوصی

### ۹.۱ فایل جدید: `lib/features/cycle/presentation/widgets/cycle_passcode_sheet.dart`

```dart
Future<bool> showCyclePasscodeSheet(
  BuildContext context, {
  bool isChangeMode = false,
});
```

- حالت پیش‌فرض (تأیید هویت): صفحه‌کلید ۴ رقمی، `CycleLockService.instance.verifyPin`، احترام به `remainingLockoutSeconds` با شمارش معکوس، بازگشت `true` در موفقیت.
- در `isChangeMode = true`: اول رمز فعلی (اگر `hasCyclePin`)، بعد رمز جدید، بعد تأیید رمز جدید، در نهایت `setPin(newPin)`.
- ظاهر را از `CycleLockGate` تقلید کن: `RitmoTheme.glassCardLight(borderRadius: 28)`، نقطه‌های ۴گانه، ارقام فارسی، `CupertinoIcons.delete_left` برای backspace.
- گزینهٔ «حذف رمز» با `clearPin()` و یک دیالوگ تأیید.

### ۹.۲ `lib/features/cycle/presentation/cycle_screen.dart`

این را پیدا کن — الان **کاملاً بی‌اثر است**:

```bash
rg -n "onOpenPasscodeSheet" lib/features/cycle/
```

جایگزین کن با:

```dart
onOpenPasscodeSheet: () async {
  final ok = await showCyclePasscodeSheet(context, isChangeMode: true);
  if (ok) await _loadData();
},
```

### ۹.۳ `lib/features/cycle/presentation/widgets/cycle_lock_gate.dart`

پیشنهاد بیومتریک باید به سوییچ کاربر احترام بگذارد. شرط فعلی:

```dart
if (hasPin && lockoutSecs == 0 && !kIsWeb) {
```

به این تغییر بده:

```dart
final biometricEnabled = await _lockService.isBiometricEnabled();
if (hasPin && lockoutSecs == 0 && !kIsWeb && biometricEnabled) {
```

دکمهٔ «ورود با اثر انگشت / چهره» را هم با همان شرط نمایش بده.

متد جدید در `CycleLockService`:

```dart
Future<bool> isBiometricEnabled([DatabaseExecutor? dbExecutor]);
// کلید cycle_biometric_enabled را می‌خواند؛ پیش‌فرض false
```

### ۹.۴ پس‌گرفتن رضایت باید فوری اثر کند

در `lib/features/cycle/presentation/widgets/cycle_settings_panel.dart`، سوییچ `یادآوری‌های حریم خصوصی` بعد از نوشتن مقدار:

```dart
if (!v) {
  await CycleNotificationService.cancelAll();
  await CycleConfirmationService.instance.purgeAll();
} else {
  await CycleReminderScheduler.rescheduleAll();
}
onDataReloadNeeded();
```

همین رفتار را برای `onTogglePregnancyMode` در `cycle_screen.dart` و برای خاموش کردن ماژول در `toggleModule` اعمال کن.

### ۹.۵ تنظیمات جدید کاربر

در همان پنل، بعد از سوییچ یادآوری‌ها:

| ردیف | کلید | نوع |
|---|---|---|
| روزهای یادآوری قبل از شروع | `cycle_reminder_lead_days` | چیپ چندانتخابی ۷/۵/۳/۲/۱ — حداقل یک انتخاب اجباری |
| ساعت یادآوری | `cycle_reminder_hour` | انتخابگر ۶ تا ۲۲ |
| پرسش تأیید شروع | `cycle_confirm_start_enabled` | سوییچ |
| پرسش تأیید پایان | `cycle_confirm_end_enabled` | سوییچ |
| ماسک پیام‌های خصوصی در صندوق | `cycle_inbox_mask_enabled` | سوییچ |

هر تغییر باید `CycleReminderScheduler.rescheduleAll()` را صدا بزند.

### گیت تأیید فاز ۹

```bash
flutter analyze
flutter test test/cycle
git add -A && git commit -m "fix(cycle): اصلاح قفل، رمز و تنظیمات یادآوری"
```

---

## ۱۰. رابط کاربری — نمایش واقعیت

### ۱۰.۱ فایل جدید: `lib/features/cycle/presentation/widgets/cycle_status_banner.dart`

```dart
class CycleStatusBanner extends StatelessWidget {
  const CycleStatusBanner({
    super.key,
    required this.output,
    required this.pendingConfirmations,
    required this.onConfirm,
    required this.onEditDates,
  });

  final CycleEngineOutput output;
  final List<CycleConfirmationRequest> pendingConfirmations;
  final ValueChanged<CycleConfirmationRequest> onConfirm;
  final VoidCallback onEditDates;
}
```

اولویت نمایش، از بالا به پایین. فقط **یک** حالت نمایش داده می‌شود:

| شرط | آیکن / رنگ | متن |
|---|---|---|
| `awaitingEndConfirmation` | `exclamationmark_triangle_fill` / `warning` | دورهٔ فعلی از میانگین شما (X روز) طولانی‌تر شده است. آیا هنوز ادامه دارد؟ |
| `isOpenPeriodBeyondAverage` | `question_circle_fill` / `primary` | بر اساس میانگین شما، این دوره احتمالاً تمام شده. آیا پایان یافته است؟ |
| `daysOverdue >= 1` | `clock_fill` / `warning` | X روز از موعد تخمینی گذشته و شروعی ثبت نشده است. + اگر `missedCycles >= 1`: تعداد موعدهای بدون ثبت: N |
| `isStartDueToday` | `calendar_circle_fill` / `primary` | امروز موعد تخمینی شروع است. آیا شروع شده؟ |
| `needsUserAttention` | `exclamationmark_circle_fill` / `error` | داده‌های چرخه به‌روز نیست و پیش‌بینی فعلاً معتبر نیست. |

هر حالت دو دکمه دارد: دکمهٔ اصلی که `onConfirm` را با درخواست مربوطه صدا می‌زند، و دکمهٔ فرعی `ویرایش تاریخ‌ها`. اعداد با `PersianDigits.toFa`.

اگر هیچ شرطی برقرار نبود → `SizedBox.shrink()`.

### ۱۰.۲ فایل جدید: `lib/features/cycle/presentation/widgets/cycle_confirmation_sheet.dart`

```dart
Future<void> showCycleConfirmationSheet(
  BuildContext context, {
  required CycleConfirmationRequest request,
  required int avgPeriodDuration,
  required VoidCallback onCompleted,
});
```

**`startDue` و `startOverdue`:**

- `بله، امروز شروع شد` → `startedToday`
- `بله، اما تاریخ دیگری شروع شد` → date picker سپس `startedOnOtherDate`
- `نه، هنوز شروع نشده` → `notStartedYet`
- `فردا بپرس` → `snoozed`

**`endDue` و `bleedingProlonged`:**

- `بله، امروز تمام شد` → `endedToday`
- `بله، اما تاریخ دیگری تمام شد` → date picker سپس `endedOnOtherDate`
- `نه، هنوز ادامه دارد` → `stillOngoing`
- `فردا بپرس` → `snoozed`

قواعد اجباری:

- انتخابگر تاریخ را از همان الگوی موجود پروژه بردار. اول پیدا کن: `rg -n "DatePicker|showDatePicker|Jalali.*picker" lib/ | head -20`
- `lastDate` برابر امروز — **تاریخ آینده مجاز نیست**.
- برای `endedOnOtherDate`، `firstDate` برابر `output.actualPeriodStart`.
- برای `bleedingProlonged` یک کارت اطلاعاتی غیرتشخیصی: `اگر خونریزی بیش از ۱۰ روز ادامه دارد یا بسیار شدید است، مشورت با پزشک توصیه می‌شود. این پیام تشخیص پزشکی نیست.`
- در انتها `CycleConfirmationService.instance.submitAnswer(...)` و سپس `onCompleted()`.

### ۱۰.۳ فایل جدید: `lib/features/cycle/presentation/widgets/cycle_anomaly_card.dart`

```dart
class CycleAnomalyCard extends StatelessWidget {
  const CycleAnomalyCard({super.key, required this.anomalies});
  final List<CycleAnomaly> anomalies;
}
```

`CycleAnomaly.titleFa` و `descriptionFa` الان nullable و خالی هستند. متن‌ها را در همین ویجت با `switch` روی `type` بساز:

| type | عنوان | توضیح |
|---|---|---|
| `lateOrMissedPeriod` | تأخیر در شروع | X روز از موعد تخمینی گذشته است. |
| `abnormallyShortCycle` | چرخهٔ کوتاه‌تر از معمول | آخرین چرخه X روز بود؛ میانگین شما Y روز است. |
| `abnormallyLongCycle` | چرخهٔ بلندتر از معمول | همان الگو |
| `unusuallyLongBleeding` | خونریزی طولانی‌تر از معمول | آخرین دوره X روز طول کشید. |
| `unusuallyHeavyFlowStreak` | شدت جریان بالاتر از معمول | متن عمومی |
| `highVariabilityTrend` | نوسان در طول چرخه‌ها | متن عمومی |

رنگ بر اساس `severity`: `info` → `textSecondary`، `watch` → `warning`، `consultClinician` → `error`.

برای `consultClinician` اجباراً: `توصیه می‌شود این مورد را با پزشک متخصص مطرح کنید. این پیام تشخیص پزشکی نیست.`

اگر `anomalies` خالی بود → `SizedBox.shrink()`.

### ۱۰.۴ `lib/features/cycle/presentation/widgets/cycle_orb_card.dart`

`switch (phase)` فعلی سه فاز `dataStale`، `pregnancy` و `noData` را به `default` می‌فرستد و آن‌ها را مثل **فولیکولار** نشان می‌دهد. هر سه را صریح کن:

- `dataStale`: `phaseText = 'وضعیت نامشخص'`، `emoji = '❓'`، `phaseColor = colors.warning`، `remainingText = 'در انتظار ثبت اطلاعات شما'`، `statusTip = 'برای محاسبهٔ دقیق، وضعیت فعلی خود را در بنر بالای صفحه تأیید کنید.'`، و `progress = 0.0` (حلقه خالی).
- `pregnancy`: `phaseText = 'دوران بارداری'`، `emoji = '🤰'`، محاسبات چرخه غیرفعال.
- `noData`: `phaseText = 'بدون داده'`، `emoji = '📋'`.

پارامتر جدید `required bool isAwaitingConfirmation`: وقتی `true` است، زیر عدد روز یک برچسب `تأیید نشده` با `colors.warning`. همهٔ صداکننده‌ها را به‌روز کن:

```bash
rg -n "CycleOrbCard(" lib/
```

### ۱۰.۵ `lib/features/cycle/presentation/widgets/cycle_sos_section.dart`

`else` نهایی در `_buildPhaseSpecificContent` برای فازهای `dataStale`، `noData` و `pregnancy` محتوای مخصوص درد قاعدگی نشان می‌دهد. یک شاخهٔ صریح اضافه کن که برای این سه فاز فقط محتوای خودمراقبتی عمومی (آب، خواب، پیاده‌روی سبک) و کارت دستیار هوشمند را نشان دهد. همین شرط را در `build` برای `title`/`subtitle` هم اعمال کن.

### ۱۰.۶ `lib/features/cycle/presentation/widgets/cycle_overview_tab.dart`

**تغییر ۱ — دکمهٔ متناقض.** `_buildQuickActionButtons` برچسب را از `periods.any(...)` می‌گیرد که با فاز موتور همگام نیست. برچسب و آیکن را از `engineOutput!.isBleedingConfirmed` بگیر. اگر `awaitingEndConfirmation` بود، برچسب `ثبت پایان (نیاز به بازبینی)` با `colors.warning`.

**تغییر ۲ — کارت پیش‌بینی نباید موعد ازدست‌رفته را پنهان کند.** در `_buildNextPeriodPredictionCard`، اگر `missedExpectedStarts.isNotEmpty`، بالای تاریخ پیش‌بینی: `موعد تخمینی قبلی (تاریخ) بدون ثبت گذشت.` و متن اعتماد را به `اعتبار پیش‌بینی: پایین — نیاز به تأیید شما` تغییر بده.

**تغییر ۳ — بانر فراموش‌شده.** دکمهٔ `ثبت پایان (X روزه)` که پایان را روی میانگین می‌گذارد و می‌تواند دادهٔ نادرست بنویسد را حذف کن و جایش `بازبینی و تأیید` بگذار که `showCycleConfirmationSheet` با `kind: bleedingProlonged` را باز کند. `onCloseForgottenPeriod` را از امضای ویجت و از `cycle_screen.dart` حذف کن و متد `_closeForgottenPeriod` را پاک کن.

### ۱۰.۷ `lib/features/cycle/presentation/cycle_screen.dart`

1. فیلدهای جدید: `List<CycleAnomaly> _anomalies = [];` و `List<CycleConfirmationRequest> _pendingConfirmations = [];`
2. در `_onStateNotifierChanged` و `_loadData` اضافه کن `_anomalies = state.anomalies;` — الان anomaly‌ها در `CycleState` هستند ولی **هیچ‌وقت به UI نمی‌رسند**. تأیید:

```bash
rg -n "state.anomalies|_anomalies" lib/features/cycle/
```

3. در `_loadData` بعد از `rescheduleAll`:

```dart
_pendingConfirmations =
    await CycleConfirmationService.instance.pendingForToday(dbExecutor: db);
```

4. در تب ۰ این ترتیب دقیق (بالا به پایین):
   - `CycleStatusBanner`
   - `CycleAnomalyCard(anomalies: _anomalies)`
   - کارت اعتماد پیش‌بینی (موجود)
   - بقیهٔ کارت‌ها بدون تغییر ترتیب
5. یک listener روی `RitmoEventBus` برای `type == 'CycleConfirmationRequested'` که شیت تأیید مناسب را باز کند. در `dispose` لغوش کن.
6. `_togglePeriodToday`: وقتی `_engineOutput!.awaitingEndConfirmation` است، به‌جای نوشتن مستقیم، `showCycleConfirmationSheet` باز شود.
7. یک دیالوگ تأیید قبل از `_deletePeriod` اضافه کن (الان بدون هیچ تأییدی حذف می‌کند).

### گیت تأیید فاز ۱۰

```bash
flutter analyze
flutter test test/cycle
git add -A && git commit -m "fix(cycle): بنر وضعیت، کارت هشدارها و شیت تأیید در رابط کاربری"
```

---

## ۱۱. مهاجرت صفحهٔ یادآورهای قاعدگی و حذف منبع سوم

### ۱۱.۱ مسئله را خودت ثابت کن

```bash
rg -n "HormonalIntelligenceEngine|privateReminderQueue" lib/
```

`lib/features/profile/presentation/cycle_reminders_screen.dart` از `HormonalIntelligenceEngine` (که `@Deprecated` است) و `privateReminderQueue` استفاده می‌کند. این صفه داده‌هایی را نشان می‌دهد که **هیچ ارتباطی با اعلان‌های واقعاً زمان‌بندی‌شده ندارند** — یعنی کاربر لیستی می‌بیند که دروغ است.

### ۱۱.۲ بازنویسی صفحه

داده را از این دو منبع واقعی بگیر:

1. جدول `pending_reminders` با `WHERE sourceSystem = 'cycle'` یا معادل موجود در طرحواره — اول ستون‌های واقعی را ببین:

```bash
rg -n "pending_reminders" -A 20 lib/core/database/schema/tables/system_tables.dart
```

2. `CycleConfirmationService.instance.pendingForToday()` برای موارد نیازمند تأیید.

قواعد:

- هر ردیف فقط تاریخ/ساعت و نوع را نشان دهد؛ متن اعلان را **فقط پس از عبور از `CycleLockGate`** نشان بده.
- دکمهٔ `لغو همهٔ یادآوری‌ها` که `CycleNotificationService.cancelAll()` را صدا می‌زند.
- اگر هیچ یادآوری فعالی نیست، حالت خالی صریح: `یادآوری فعالی وجود ندارد.` به‌علاوه دلیل: رضایت خاموش است / حالت بارداری فعال است / دادهٔ کافی نیست.
- import مربوط به `HormonalIntelligenceEngine` را از این فایل حذف کن.

### ۱۱.۳ خالی کردن منبع سوم

در `lib/core/domain/engines/hormonal_intelligence_engine.dart`:

- `privateReminderQueue` را همیشه لیست خالی برگردان.
- روی هر دو، یعنی فیلد و محل محاسبه، کامنت بگذار:

```dart
// منبع واقعی یادآوری‌ها: CycleNotificationService + CycleReminderScheduler.
// این صف فقط برای سازگاری عقب‌رو نگه داشته شده و همیشه خالی است.
```

- اگر بعد از این تغییر هیچ مصرف‌کننده‌ای باقی نماند، فایل را **حذف نکن** (ممکن است جای دیگر موتور استفاده شود). تأیید:

```bash
rg -n "HormonalIntelligenceEngine" lib/ test/
```

### گیت تأیید فاز ۱۱

```bash
flutter analyze
flutter test
git add -A && git commit -m "fix(cycle): مهاجرت صفحهٔ یادآورها به منبع واقعی داده"
```

---

## ۱۲. تست‌ها — اجباری

این فاز قابل حذف نیست. اول الگوی تست موجود را بخوان تا همان سبک را تکرار کنی:

```bash
sed -n '1,60p' test/cycle/cycle_engine_overdue_test.dart
sed -n '1,60p' test/notifications/single_gateway_test.dart
```

### ۱۲.۱ فایل‌های جدید

**`test/cycle/cycle_lifecycle_confirmation_test.dart`**

- موعد دقیقاً امروز بدون رکورد → `isStartDueToday == true` و `daysOverdue == 0` و `awaitingStartConfirmation == true`.
- ۳ روز گذشته بدون رکورد → `daysOverdue == 3` و `isOverdue == true`.
- دورهٔ باز طولانی‌تر از میانگین → `currentPhase == CyclePhase.menstrual` و `isOpenPeriodBeyondAverage == true` و `isBleedingConfirmed == true`.
- دورهٔ باز بیش از `میانگین + prolongedBleedingGraceDays` → `awaitingEndConfirmation == true`.
- **تست رگرسیون بحرانی**: دورهٔ باز، فاز هرگز `follicular` نشود.
- `notStartedYet` → تعداد ردیف‌های `cycle_periods` تغییر نکند.
- `stillOngoing` → `endDate` همچنان `null` بماند.
- `syncFromEngine` دو بار پشت سر هم → دقیقاً یک ردیف (idempotency).
- بعد از `submitAnswer(startedToday)` → `syncFromEngine` مجدد پاسخ را پاک نکند.

**`test/cycle/cycle_missed_start_test.dart`**

- دو موعد متوالی بدون رکورد → `missedExpectedStarts.length == 2` و ترتیب صعودی.
- `forecast.cycles.first.predictedStart` با `nextPeriodPrediction` متناقض نباشد.

**`test/cycle/cycle_privacy_notification_test.dart`**

- هر `NotificationRequest` ساخته‌شده توسط `CycleNotificationService`:
  - `channel == NotificationChannelId.privateChannel`
  - `privacy == NotificationPrivacy.redacted`
  - `redactedTitle` و `redactedBody` غیرخالی
  - `payload['requiresAuth'] == true` و `payload['moduleId'] == 'cycle'`
- **تست واژگان ممنوع** روی `redactedTitle`، `redactedBody`، `payload['publicTitle']`، `payload['publicBody']`:

```dart
final forbidden = RegExp(
  r'(چرخه|قاعدگی|پریود|سیکل|خونریزی|menstrual|period|cycle|pregnancy)',
  caseSensitive: false,
);
expect(forbidden.hasMatch(text), isFalse, reason: 'متن خنثی نشت دارد: $text');
```

- رضایت خاموش → صفر فراخوانی `scheduleExactAlarm`.
- `pregnancyMode` روشن → صفر فراخوانی.

**`test/cycle/cycle_notification_single_source_test.dart`**

- `AlarmSchedulerService.scheduleNextAlarms` را با یک `AlarmPlatform` جعلی اجرا کن؛ هیچ شناسه‌ای نباید با `cycle_rem_` شروع شود.
- برای یک موعد مشخص، هیچ دو اعلانی نباید `timeMsUTC` یکسان داشته باشند (عدم تکرار).
- `cancelAll()` → همهٔ `CycleNotificationIds.legacyIds()` در لیست لغوشده‌ها باشند.

**`test/cycle/cycle_channel_passthrough_test.dart`**

- `NotificationGateway.schedule` با یک درخواست `privateChannel` → mock الزاماً `channelId == 'ritmo_private_v3'` دریافت کند.
- `title` رسیده به پلتفرم برابر `redactedTitle` باشد، نه `title` اصلی.
- `requiresAuth == true` و `moduleId == 'cycle'` منتقل شوند.

**`test/cycle/cycle_inbox_masking_test.dart`**

- `InboxItem` با `payload['sensitive'] == true`:
  - `displayTitle(isUnlocked: false) == maskedTitle`
  - `displayBody(isUnlocked: false) == maskedBody`
  - `displayTitle(isUnlocked: true) == title`
- پس از `CentralInboxService.purgeForSource('cycle')` → صفر ردیف با آن `sourceSystem`؛ و ردیف‌های سایر منابع دست‌نخورده باقی بمانند.

**`test/cycle/cycle_threshold_consistency_test.dart`**

تست معماری روی متن فایل‌ها (مشابه الگوی `single_gateway_test.dart`):

- هیچ فایلی در `lib/features/cycle/` و `lib/core/domain/engines/cycle_engine.dart` نباید عدد خام `12` در مقایسهٔ روز داشته باشد؛ باید `CycleSettings.forgottenOpenPeriodDays` یا `CyclePeriod.maxActivePeriodDays` باشد.
- `CycleSettings.forgottenOpenPeriodDays == CyclePeriod.maxActivePeriodDays`
- `DataQualityReport.forgottenOpenPeriodThresholdDays == CycleSettings.forgottenOpenPeriodDays`

### ۱۲.۲ به‌روزرسانی mock‌های موجود

امضای `scheduleExactAlarm` در فاز ۷ عوض شد. همهٔ mock‌ها را پیدا کن و به‌روز کن:

```bash
rg -ln "scheduleExactAlarm" test/
```

در هر mock، پارامترهای جدید را بپذیر و برای assert ذخیره کن:

```dart
@override
Future<bool> scheduleExactAlarm({
  required String id,
  required int timeMsUTC,
  required String title,
  required bool isEssential,
  String channelId = 'ritmo_routine_v3',
  String? body,
  String? publicTitle,
  String? publicBody,
  String? moduleId,
  bool requiresAuth = false,
}) async {
  calls.add({
    'id': id,
    'timeMsUTC': timeMsUTC,
    'title': title,
    'isEssential': isEssential,
    'channelId': channelId,
    'body': body,
    'publicTitle': publicTitle,
    'publicBody': publicBody,
    'moduleId': moduleId,
    'requiresAuth': requiresAuth,
  });
  return true;
}
```

### گیت تأیید فاز ۱۲

```bash
dart format lib test
flutter analyze
flutter test
git add -A && git commit -m "test(cycle): پوشش چرخهٔ عمر قاعدگی، حریم خصوصی و تک‌منبعی اعلان‌ها"
```

---

## ۱۳. تعریف «انجام شد» — هر ۹ مورد اجباری

قبل از پوش نهایی، همهٔ این دستورات را اجرا کن و خروجی را در گزارش بیاور.

```bash
# ۱) فاز قطعی ممنوع: دورهٔ باز هرگز فولیکولار نمی‌شود
flutter test test/cycle/cycle_lifecycle_confirmation_test.dart

# ۲) موعد امروز سیگنال می‌دهد (daysOverdue == 0 ولی awaitingStartConfirmation == true)
rg -n "isStartDueToday|awaitingStartConfirmation" lib/core/domain/engines/cycle_engine.dart

# ۳) موعدهای ازدست‌رفته گم نمی‌شوند
flutter test test/cycle/cycle_missed_start_test.dart

# ۴) فقط یک سامانهٔ اعلان است
rg -n "cycle_rem_" lib/ ; echo "exit=$?  (باید 1 باشد یعنی هیچ تطابقی نیست)"
flutter test test/cycle/cycle_notification_single_source_test.dart

# ۵) کانال خصوصی واقعاً به Native می‌رسد
rg -n "ritmo_private_v3" lib/ android/
flutter test test/cycle/cycle_channel_passthrough_test.dart

# ۶) متن حساس روی قفل صفحه و در صندوق نشت نمی‌کند
flutter test test/cycle/cycle_privacy_notification_test.dart test/cycle/cycle_inbox_masking_test.dart

# ۷) دکمهٔ رمز دیگر بی‌اثر نیست
rg -n "onOpenPasscodeSheet" -A 4 lib/features/cycle/presentation/cycle_screen.dart

# ۸) هشدارها به کاربر نمایش داده می‌شوند
rg -n "CycleAnomalyCard|CycleStatusBanner" lib/features/cycle/presentation/cycle_screen.dart

# ۹) آستانهٔ ۱۲ روز تک‌منبع است
flutter test test/cycle/cycle_threshold_consistency_test.dart

# گیت نهایی کامل
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

هر ۹ مورد باید سبز باشد. **اگر یکی سبز نشد، کار تمام نشده است. ادعای موفقیت نکن.**

---

## ۱۴. همگام‌سازی با گیت‌هاب

فقط بعد از سبز شدن کامل فاز ۱۳:

```bash
# وضعیت را ببین — مطمئن شو build/ و .dart_tool/ کامیت نشده‌اند
git status --short
git log --oneline main..HEAD

# پوش
git push -u origin fix/cycle-lifecycle-and-privacy
```

سپس Pull Request بساز به `main`:

- **عنوان:** `fix(cycle): مدیریت چرخهٔ عمر قاعدگی، تأیید تعاملی و حریم خصوصی واقعی`
- **بدنه:** فهرست ۱۴ نقص رفع‌شده، فایل‌های جدید، تغییرات طرحوارهٔ دیتابیس، تغییرات لایهٔ Native، خروجی ۹ گیت تأیید
- اگر در مخزن قالب PR وجود دارد (`.github/PULL_REQUEST_TEMPLATE` یا `pull_request_template.md`)، از همان استفاده کن.

قواعد قطعی گیت:

- مستقیم به `main` پوش **نکن**.
- `git push --force` روی `main` یا روی شاخه‌های دیگر **ممنوع**.
- اگر تغییرات محلیِ متعلق به کاربر دیدی، آن‌ها را `stash` یا `checkout --` یا `reset --hard` **نکن**؛ متوقف شو و بپرس.
- شاخه‌های دیگر (`fix/webbridge-answer-detection`، `fix/movement-center-ux`) را لمس نکن.

---

## ۱۵. گزارش نهایی — قالب دقیق

در پایان، دقیقاً با این ساختار و به فارسی گزارش بده:

```
## خلاصه
<۲ تا ۳ خط>

## کامیت‌ها
| فاز | پیام کامیت | SHA |

## فایل‌های جدید
<لیست مسیرها>

## فایل‌های تغییریافته
<مسیر — خلاصهٔ تغییر در یک خط>

## تغییرات طرحوارهٔ دیتابیس
<شمارهٔ مهاجرت، جداول و کلیدهای جدید>

## خروجی گیت‌ها
dart format: <نتیجه>
flutter analyze: <تعداد خطا / هشدار — و مقایسه با baseline>
flutter test: <تعداد موفق / ناموفق — و مقایسه با baseline>
flutter build apk --debug: <موفق / ناممکن به دلیل ...>

## تأیید ۹ مورد «انجام شد»
| مورد | وضعیت | شاهد |

## مواردی که عمداً انجام ندادم
<هر مورد با دلیل>

## ریسک‌ها و موارد نیازمند تست دستی
<مخصوصاً رفتار روی دستگاه واقعی: قفل صفحه، ریبوت، بیومتریک>

## PR
<لینک و شماره>
```

---

## ۱۶. ۱۰ مورد ممنوعهٔ مطلق

1. نقشهٔ پیاده‌سازی جدید ننویس؛ فازها را بازترتیب نکن؛ فاز حذف نکن.
2. متن حساس را در `title` یا `body`ی که روی قفل صفحه یا در صفحهٔ خانه ظاهر می‌شود قرار نده.
3. حتی یک فراخوانی `scheduleExactAlarm` خارج از `NotificationGateway`/`AlarmPlatform` اضافه نکن (تست معماری موجود می‌شکند).
4. برای پایان دوره تاریخ حدسی ننویس؛ فقط پاسخ صریح کاربر.
5. تشخیص پزشکی نده؛ هر متن بالینی باید سلب‌مسئولیت داشته باشد.
6. موتور را طوری تغییر نده که دورهٔ باز فاز غیرقاعدگی بگیرد.
7. فایل بزرگ (بیش از ۳۰ کیلوبایت) را کامل بازنویسی نکن؛ ویرایش هدفمند انجام بده.
8. دو لاگر پروژه را جابجا نکن: `RitmoLog` (در `lib/core/logging/ritmo_logger.dart`) و `RitmoLogger` (در `lib/core/observability/ritmo_logger.dart`) دو چیز متفاوتند. قبل از استفاده از هر متد لاگ، امضای واقعی‌اش را با `rg` ببین.
9. مهاجرت موجود را ویرایش نکن؛ فقط مهاجرت جدید اضافه کن.
10. `build/`، `.dart_tool/`، `*.g.dart` تولیدی و فایل‌های موقت را کامیت نکن.

---

## ۱۷. اگر جایی گیر کردی

متوقف شو و فقط یک سوال بپرس؛ ولی قبلش این را رعایت کن:

- اگر امضای یک متد یا نام یک فیلد در این پرامپت دقیقاً با مخزن جور درنیامد، **مخزن مرجع است**. معنای مورد درخواستی را حفظ کن و نام‌ها را با واقعیت کد تطبیق بده؛ بعد در گزارش ذکر کن کدام نام را تطبیق دادی.
- اگر یک تست موجود به خاطر تغییر امضا شکست، خودت تست را به‌روز کن — سوال نپرس.
- اگر یک تست موجود به خاطر تغییر **رفتار مورد انتظار** شکست (مانند تستی که انتطار دارد دورهٔ باز فولیکولار بشود)، تست را با کامنت توضیحی به‌روز کن و در گزارش صریحاً بنویس کدام انتطار را عوض کردی و چرا.
- اگر `flutter analyze` خطایی داد که در baseline هم بود، تو مسئولش نیستی؛ فقط در گزارش تفکیک کن.

**شروع کن از فاز ۰ و تا فاز ۱۵ بدون توقف پیش برو.**
