# پرامپت اصلاحی دور ۲ — ماژول «چرخهٔ بدن» ریتمو

**مخزن:** `nicedevil02/ritmo`
**نقطهٔ شروع:** تیپ فعلی `main` = `2c8487fc56ad5b6bd88c4192ccf5600970b9070e`
**محیط اجرا:** لوکال. پروژه روی همان سیستمی است که تو رویش کار می‌کنی. بعد از اتمام، با گیت‌هاب سینک می‌شود.

---

## ۰. قواعد اجرا — این بخش را نقض نکن

1. **برای خودت نقشهٔ پیاده‌سازی نساز.** این سند نقشه است. فازها را به ترتیب ۱ تا ۲۱ اجرا کن. هیچ فازی را جابه‌جا، ادغام، حذف یا «بهینه» نکن.
2. **هیچ فایل مستندات، نقشه، TODO، CHANGELOG، PLAN یا REPORT جدیدی نساز.** فقط کد و تست بنویس. تنها استثنا: فایل‌های تستی که این سند صریحاً نام برده.
3. **دور نزن.** اگر یک فاز به‌نظرت غیرضروری یا «قبلاً درست» است، باز هم کد را باز کن و با معیار پذیرش همان فاز تطبیق بده. دور قبل دقیقاً به این دلیل شکست خورد که تست‌ها سبز بودند ولی محصول خراب بود.
4. **هیچ فایلی را rename یا move نکن.** هیچ فایلی را حذف نکن مگر این سند نام برده باشد.
5. **به این مسیرها دست نزن:** `lib/features/cycle/presentation/widgets/pregnancy/`، `cycle_pregnancy_mode.dart`، `labor_mode_screen.dart`، `kick_session_tracker.dart`. خارج از محدودهٔ این دور هستند.
6. **تلهٔ دو لاگر — مهم:** در این مخزن دو لاگر متفاوت وجود دارد و قابل تعویض نیستند:
   - `RitmoLog` از `lib/core/logging/ritmo_logger.dart` → فقط در `cycle_screen.dart` استفاده می‌شود.
   - `RitmoLogger` از `lib/core/observability/ritmo_logger.dart` → در `cycle_settings.dart`، `cycle_period_repository.dart`، `cycle_confirmation_service.dart`، `cycle_state_provider.dart` استفاده می‌شود.
   در هر فایل، همان لاگری را که الان import شده نگه دار. هرگز یکی را با دیگری عوض نکن و import جدید از لاگر دیگر اضافه نکن.
7. **پس از هر فاز:** `flutter analyze` را اجرا کن. اگر تعداد خطاها از خط پایه بیشتر شد، همان فاز را درست کن، به فاز بعد نرو.
8. **کامیت:** هر فاز یک کامیت جدا با پیام دقیقی که در همان فاز آمده. کامیت‌ها را با هم ادغام نکن.
9. **شاخه:** روی `main` کامیت نکن. شاخهٔ `fix/cycle-round2-contract` را از `main` بساز و همهٔ کار را روی آن انجام بده.
10. اگر جایی این سند با کد فعلی تناقض داشت (مثلاً امضای تابعی عوض شده)، **این سند حاکم است**؛ کد را با سند هم‌راست کن، نه برعکس.

---

## ۰.۱ تصمیم‌های قطعی — دربارهٔ این‌ها تصمیم‌گیری مجدد نکن

| # | تصمیم | چرا |
|---|---|---|
| D1 | `cycle_periods.id` از نوع **`TEXT`** می‌ماند. به INTEGER مهاجرت نمی‌دهیم. | داده‌های موجود کاربران و مسیر onboarding (`period_onboarding_seed`) از رشته استفاده می‌کنند. |
| D2 | **هیچ ستون جدیدی به `cycle_periods` اضافه نمی‌شود.** ستون‌های خیالی `periodDuration`، `notes`، `suppressedPrayer`، `fastDebtCreated` از کد **حذف** می‌شوند، نه از دیتابیس اضافه. | `periodDuration` از `startDate`/`endDate` مشتق‌شدنی است؛ ذخیره‌اش منبع drift است. `notes` املای غلط `note` است. دو مورد آخر منطق مشتق هستند. |
| D3 | کلید `cycle_fertility_visible` **کاملاً حذف می‌شود**. نمایش باروری همیشه روشن است. | خودِ `DESIGN_SYSTEM_CYCLE.md` مخزن می‌گوید این کلید کنار گذاشته شده و باروری پیش‌فرض روشن داخل vault است. کل ماژول پشت `cycle_lock_gate` است، پس گیت دوم لازم نیست. |
| D4 | **تنها مسیر نوشتن روی `cycle_periods`، کلاس `CyclePeriodRepository` است.** هیچ `db.insert` / `db.update` / `db.delete` خامی روی این جدول در لایهٔ UI باقی نمی‌ماند. | مسیر خام همهٔ گاردها و `invalidate()` را رد می‌کند. |
| D5 | `CycleEngine().invalidate()` **درون خودِ متدهای نوشتنِ ریپازیتوری** صدا زده می‌شود، نه در فراخوان‌ها. | تا هیچ مسیری نتواند فراموشش کند. |
| D6 | DDL تست‌ها **دست‌نویس نمی‌شود**. همهٔ تست‌ها جدول‌ها را از `CycleTables` می‌سازند. | دور قبل به همین دلیل تست سبز و محصول خراب داشت. |

---

## فاز ۱ — خط پایه و شاخه

```bash
cd <ریشهٔ پروژه>
git checkout main
git pull
git rev-parse HEAD          # باید 2c8487fc... باشد؛ اگر نبود، ادامه بده ولی در پیام نهایی گزارش کن
git checkout -b fix/cycle-round2-contract
flutter analyze > /tmp/r2_analyze_before.txt 2>&1 || true
flutter test  > /tmp/r2_test_before.txt    2>&1 || true
```

تعداد خطاهای `analyze` و تعداد تست‌های ناموفق را یادداشت کن. این‌ها خط پایه‌اند.

**کامیت:** ندارد.

---

## فاز ۲ — قرارداد اسکیما: تک‌منبعِ حقیقت

**مسئله:** `lib/core/database/schema/tables/cycle_tables.dart` جدول را این‌طور می‌سازد:

```sql
CREATE TABLE cycle_periods (
    id TEXT PRIMARY KEY,
    startDate TEXT NOT NULL,
    endDate TEXT,
    flowIntensity TEXT DEFAULT 'MEDIUM',
    isPredicted INTEGER DEFAULT 0,
    note TEXT,
    createdAt INTEGER,
    updatedAt INTEGER
);
```

ولی `CyclePeriodRepository` ستون‌های `periodDuration`، `notes`، `suppressedPrayer`، `fastDebtCreated` را می‌نویسد که وجود ندارند. هیچ `ALTER TABLE cycle_periods` در کل مخزن نیست.

### کاری که می‌کنی

**۲.۱** فایل جدید بساز: `lib/features/cycle/logic/cycle_period_contract.dart`

محتوا: یک کلاس فقط‌ثابت که نام هر ستون واقعی و نام جدول را به‌عنوان `static const String` نگه می‌دارد، به‌علاوه یک `static const List<String> allColumns`. مثال ساختار:

```dart
/// تک‌منبعِ حقیقت برای نام ستون‌های جدول cycle_periods.
/// هر نوشتن یا خواندنی روی این جدول باید از این ثابت‌ها استفاده کند.
/// اگر CycleTables.create عوض شد، این فایل و تست قرارداد باید با آن عوض شوند.
class CyclePeriodContract {
  const CyclePeriodContract._();

  static const String table = 'cycle_periods';

  static const String colId = 'id';
  static const String colStartDate = 'startDate';
  static const String colEndDate = 'endDate';
  static const String colFlowIntensity = 'flowIntensity';
  static const String colIsPredicted = 'isPredicted';
  static const String colNote = 'note';
  static const String colCreatedAt = 'createdAt';
  static const String colUpdatedAt = 'updatedAt';

  static const List<String> allColumns = <String>[
    colId, colStartDate, colEndDate, colFlowIntensity,
    colIsPredicted, colNote, colCreatedAt, colUpdatedAt,
  ];

  /// شناسهٔ یکتا برای ردیف جدید. تصادم دو ضربهٔ هم‌زمان را هم پوشش می‌دهد.
  static String newId() {
    final ms = DateTime.now().millisecondsSinceEpoch;
    final rnd = Random().nextInt(0x10000).toRadixString(16).padLeft(4, '0');
    return 'period_' + ms.toString() + '_' + rnd;
  }
}
```

`Random` را از `dart:math` import کن.

**۲.۲** در `cycle_tables.dart`، بالای تعریف `cycle_periods` این کامنت را اضافه کن:

```dart
// هر تغییری در ستون‌های این جدول باید هم‌زمان در
// lib/features/cycle/logic/cycle_period_contract.dart و
// test/cycle/cycle_schema_contract_test.dart اعمال شود.
```

**۲.۳** تأیید کن که تعریف `cycle_periods` در `lib/core/database/migration/migrations_registry.dart` دقیقاً با `cycle_tables.dart` یکی است (کاراکتر به کاراکتر از نظر ستون‌ها). اگر اختلافی بود، `cycle_tables.dart` را مرجع بگیر و `migrations_registry.dart` را با آن هم‌راست کن.

**معیار پذیرش:** `CyclePeriodContract.allColumns` دقیقاً و تنها همان ۸ ستونی است که `CycleTables` می‌سازد.

**کامیت:** `fix(cycle): تک‌منبع قرارداد ستون‌های cycle_periods`

---

## فاز ۳ — بازنویسی مدل `CyclePeriod`

**مسئله:** `CyclePeriod.id` از نوع `int?` است و `fromMap` مقدار `'period_1755…'` را با `int.tryParse` می‌خواند که `null` می‌دهد. بعد گاردهای `if (period.id != null)` در `CycleStateNotifier.endPeriod` و `CycleConfirmationService.recordAnswer` رد می‌شوند و **هیچ خطایی هم نمی‌دهند**. این ریشهٔ «دکمهٔ پایان قاعدگی کار نمی‌کند» است.

### کاری که می‌کنی

**۳.۱** در فایل مدل `CyclePeriod`:

- `id` را از `int?` به **`String`** (غیرnullable) تغییر بده.
- فیلدهای `cycleLength`، `periodDuration`، `notes`، `suppressedPrayer`، `fastDebtCreated` را از مدل **حذف** کن.
- فیلدهای جدید مطابق اسکیما اضافه کن: `flowIntensity` (`String`، پیش‌فرض `'MEDIUM'`)، `isPredicted` (`bool`، پیش‌فرض `false`)، `note` (`String?`).
- `fromMap` را طوری بنویس که فقط از ثابت‌های `CyclePeriodContract` بخواند و برای `id`:
  ```dart
  id: (map[CyclePeriodContract.colId] as String?) ?? '',
  ```
- `toMap` را طوری بنویس که **فقط** کلیدهای `CyclePeriodContract.allColumns` را برگرداند.
- `isPredicted` را از `INTEGER` بخوان: `(map[colIsPredicted] as int? ?? 0) == 1` و در `toMap` به `1`/`0` تبدیل کن.

**۳.۲** getterهای مشتق را به مدل اضافه کن (به‌جای ستون ذخیره‌شده):

```dart
bool get isOpen => endDate == null;

/// طول قاعدگی برحسب روز، فقط برای دورهٔ بسته. دورهٔ باز null می‌دهد.
int? get durationDays => endDate == null
    ? null
    : CycleDateContract.daysBetween(startDate, endDate!) + 1;

/// تعداد روزهای سپری‌شده از شروع تا تاریخ مرجع (برای دورهٔ باز).
int elapsedDaysAt(DateTime reference) =>
    CycleDateContract.daysBetween(startDate, reference) + 1;
```

**۳.۳** `maxActivePeriodDays` را همان‌جا نگه دار و مقدارش را از `CycleSettings.forgottenOpenPeriodDays` بخوان (تک‌منبع، مقدار ۱۲).

**۳.۴** همهٔ جاهایی که کامپایل می‌شکند را پیدا کن و درست کن:

```bash
flutter analyze 2>&1 | grep -n "CyclePeriod\|periodDuration\|suppressedPrayer\|fastDebtCreated\|\.notes"
```

در هر فراخوان، گارد `if (x.id != null)` را حذف کن و به‌جایش `if (x.id.isNotEmpty)` بگذار. **هیچ گارد سکوتی نگذار**: اگر `id` تهی بود، با `RitmoLogger` (یا `RitmoLog` در `cycle_screen.dart`) در سطح error لاگ کن.

**معیار پذیرش:** جست‌وجوی `periodDuration`، `suppressedPrayer`، `fastDebtCreated` در `lib/` صفر نتیجه بدهد.

**کامیت:** `fix(cycle): هم‌راست‌سازی مدل CyclePeriod با اسکیمای واقعی`

---

## فاز ۴ — بازنویسی کامل `CyclePeriodRepository`

فایل: `lib/features/cycle/logic/cycle_period_repository.dart`

این کلاس باید تنها دروازهٔ نوشتن باشد. با این امضاها بازنویسی‌اش کن:

```dart
class CyclePeriodRepository {
  /// شروع دورهٔ جدید. اگر دورهٔ بازی وجود داشته باشد، اول آن را می‌بندد.
  /// در صورت موفقیت id ردیف جدید، در غیر این صورت پرتاب استثنا.
  Future<String> startPeriod({
    required DatabaseExecutor db,
    required DateTime startDate,
    String flowIntensity = 'MEDIUM',
    String? note,
  });

  /// بستن دورهٔ باز. اگر id پیدا نشود یا دوره از قبل بسته باشد، استثنا.
  Future<void> endPeriod({
    required DatabaseExecutor db,
    required String id,
    required DateTime endDate,
  });

  Future<void> updatePeriod({
    required DatabaseExecutor db,
    required String id,
    required DateTime startDate,
    DateTime? endDate,
    String? flowIntensity,
    String? note,
  });

  Future<void> deletePeriod({
    required DatabaseExecutor db,
    required String id,
  });

  Future<List<CyclePeriod>> getAllPeriods(DatabaseExecutor db);
  Future<CyclePeriod?> getOpenPeriod(DatabaseExecutor db);
}
```

### قواعد اجباری برای هر متد نوشتن

**R1 — id همیشه صریح.** `startPeriod` مقدار `CyclePeriodContract.newId()` را در `insert` می‌گذارد و **همان رشته** را برمی‌گرداند. هرگز مقدار برگشتی `db.insert` (که rowid است) را به‌عنوان id برنگردان.

**R2 — فقط ستون‌های واقعی.** map ورودی `insert`/`update` را از `CyclePeriodContract` بساز. هر کلید دیگری ممنوع.

**R3 — نرمال‌سازی تاریخ.** هر تاریخ ورودی از `CycleDateContract.cleanDate()` بگذرد و با `CycleDateContract.toDayKey()` ذخیره شود. هرگز `DateTime.now().toIso8601String()` را در ستون تاریخ ننویس.

**R4 — گاردهای اعتبارسنجی.** هر کدام نقض شد، `ArgumentError` با پیام فارسی روشن پرتاب کن:
- `startDate` نمی‌تواند بعد از امروز باشد.
- `endDate` نمی‌تواند قبل از `startDate` باشد.
- `endDate` نمی‌تواند بعد از امروز باشد.
- طول دورهٔ بسته نمی‌تواند از `CycleSettings.forgottenOpenPeriodDays` (۱۲) بیشتر باشد؛ اگر بیشتر بود استثنا با پیامی که کاربر بفهمد.
- `startDate` جدید نمی‌تواند داخل بازهٔ `[start, end]` هیچ دورهٔ موجودی بیفتد (هم‌پوشانی).
- برای `updatePeriod`، هم‌پوشانی با **سایر** ردیف‌ها بررسی شود (خودش را استثنا کن).

**R5 — دوره تکراری در همان روز.** اگر ردیفی با همان `startDate` وجود دارد، ردیف جدید نساز؛ همان id موجود را برگردان و در سطح warning لاگ کن.

**R6 — بستن خودکار دورهٔ باز.** در `startPeriod`، اگر دورهٔ بازی هست:
- اگر `elapsedDaysAt(today) >= forgottenOpenPeriodDays` → دوره را ببند اما **تاریخ پایان را جعل نکن**؛ `endDate` را روی `startDate + (طول متوسط قاعدگی کاربر − 1)` **نگذار**. به‌جایش `endDate = startDate` بگذار و `note` را با مقدار `'auto_closed_unknown_end'` علامت بزن تا لایهٔ UI بتواند از کاربر بپرسد.
- اگر کمتر بود → استثنا بده که دورهٔ باز فعال وجود دارد؛ اجازه نده دو دورهٔ باز هم‌زمان ساخته شود.

**R7 — `invalidate` اجباری.** در پایان هر یک از `startPeriod`، `endPeriod`، `updatePeriod`، `deletePeriod` — و فقط در مسیر موفق — این را صدا بزن:
```dart
CycleEngine().invalidate();
```

**R8 — بدون گارد سکوتی.** هیچ‌جا `if (rows.isEmpty) return;` ننویس. اگر ردیف پیدا نشد، `StateError` پرتاب کن. سکوت، همان باگی است که کاربر می‌بیند.

**R9 — نوع db.** پارامتر را `DatabaseExecutor` بگیر (پدرِ مشترک `Database`, `Transaction`, `Batch`) تا شرط شکنندهٔ `if (db is Database)` لازم نشود. هیچ `if (db is Database)` جدیدی ننویس.

**R10 — `getAllPeriods`** با `orderBy: 'startDate DESC'` بخواند. **هرگز `id DESC`** — چون id رشته است و مرتب‌سازی لغوی غلط می‌دهد (`period_9…` بالاتر از `period_10…`).

**کامیت:** `fix(cycle): بازنویسی CyclePeriodRepository روی اسکیمای واقعی`

---

## فاز ۵ — حذف کامل SQL خام از `cycle_screen.dart`

فایل: `lib/features/cycle/presentation/cycle_screen.dart`

**مسئله:** چهار محل در این فایل مستقیم روی دیتابیس می‌نویسند و به همین دلیل `CycleEngine().invalidate()` را فراموش می‌کنند. نتیجه: ردیف در دیتابیس نوشته می‌شود، ولی موتور خروجی کش‌شده را برمی‌گرداند و فاز، روزِ چرخه، بنر و اُرب کهنه می‌مانند. **کاربر این را «دکمه کار نمی‌کند» می‌بیند.**

### کاری که می‌کنی

**۵.۱** اول همهٔ محل‌ها را پیدا کن:

```bash
grep -n "cycle_periods" lib/features/cycle/presentation/cycle_screen.dart
```

**۵.۲** این چهار متد را بازنویسی کن تا هیچ SQL خامی نداشته باشند:

| متد | الان چه می‌کند | باید چه کند |
|---|---|---|
| `_togglePeriodToday` | `db.insert` / `db.update` خام | فقط `CyclePeriodRepository.startPeriod` یا `endPeriod` |
| `_openAddEditPeriodSheet` → `onSave` | `db.insert` / `db.update` خام | `startPeriod` (حالت افزودن) یا `updatePeriod` (حالت ویرایش) |
| `_deletePeriod` | `db.delete` خام | `CyclePeriodRepository.deletePeriod` |
| `_closeForgottenPeriod` | `db.update` خام با تاریخ جعلی | فاز ۱۱ این را کامل عوض می‌کند؛ فعلاً فقط به `updatePeriod` وصلش کن |

**۵.۳ رفع باگ «ثبت دوره از روی روز پیش‌بینی‌شده» (باگ سکوتی):**

الان `onRecordPeriodFromDate` یک map بدون `'id'` می‌سازد و شیت چون `period != null` است مسیر ویرایش را می‌گیرد و `where: 'id = ?', whereArgs: [null]` می‌زند → صفر ردیف → هیچ ذخیره‌ای نمی‌شود و هیچ خطایی هم دیده نمی‌شود.

امضای `_openAddEditPeriodSheet` را عوض کن تا در سطح تایپ قابل اشتباه نباشد:

```dart
/// existingId == null  =>  حالت افزودن
/// existingId != null  =>  حالت ویرایش
Future<void> _openAddEditPeriodSheet({
  String? existingId,
  DateTime? initialStartDate,
  DateTime? initialEndDate,
})
```

در `onSave`، انتخاب مسیر فقط بر اساس `existingId == null` باشد. هرگز بر اساس `map['id']`.

و فراخوانی را این‌طور کن:

```dart
onRecordPeriodFromDate: (d) => _openAddEditPeriodSheet(initialStartDate: d),
```

**۵.۴** بعد از هر نوشتن موفق، دقیقاً این ترتیب را رعایت کن:

```dart
// 1) نوشتن از طریق ریپازیتوری (invalidate درونش انجام می‌شود)
// 2) هرس و همگام‌سازی تأییدها (فاز ۱۰)
// 3) بدهی روزه (فاز ۱۲)
// 4) بازخوانی وضعیت
await _loadData();
```

**۵.۵** در پایان فاز، این دستور باید صفر نتیجه بدهد:

```bash
grep -rn "cycle_periods" lib/features/cycle/presentation/
```

**معیار پذیرش:** در کل `lib/features/cycle/presentation/` یک ارجاع مستقیم به نام جدول `cycle_periods` نماند.

**کامیت:** `fix(cycle): عبور همهٔ نوشتن‌های دوره از ریپازیتوری`

---

## فاز ۶ — دکمهٔ شروع/پایان: debounce، خطا، تأیید

**مسئله:** `GestureDetector(onTap: onTogglePeriodToday)` روی یک هندلر `async` بدون debounce و بدون `try/catch`. دو ضربهٔ سریع = دو درج. اگر استثنا بدهد، `_loadData()` اجرا نمی‌شود و UI در وضعیت قدیم یخ می‌زند.

### کاری که می‌کنی

**۶.۱** در `_CycleScreenState` این فیلد را اضافه کن: `bool _isTogglingPeriod = false;`

**۶.۲** `_togglePeriodToday` را دقیقاً با این اسکلت بنویس:

```dart
Future<void> _togglePeriodToday() async {
  if (_isTogglingPeriod) return;
  setState(() => _isTogglingPeriod = true);
  try {
    final db = await DatabaseHelper.instance.database;
    final open = await _periodRepo.getOpenPeriod(db);
    final today = CycleDateContract.cleanDate(DateTime.now());

    if (open != null) {
      // تأیید قبل از بستن دورهٔ یک‌روزه
      final elapsed = open.elapsedDaysAt(today);
      if (elapsed < 2) {
        final ok = await _confirmShortPeriod(elapsed);
        if (!ok) return;
      }
      await _periodRepo.endPeriod(db: db, id: open.id, endDate: today);
    } else {
      await _periodRepo.startPeriod(db: db, startDate: today);
    }

    await _syncConfirmations();   // فاز ۱۰
    await _syncFastingDebt();     // فاز ۱۲
    await _loadData();
  } catch (e, st) {
    RitmoLog.error('togglePeriodToday failed', error: e, stackTrace: st);
    if (mounted) {
      // پیام خنثی حریم خصوصی — واژگان صریح قاعدگی در SnackBar ممنوع است
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('ثبت انجام نشد. دوباره تلاش کنید.'),
      ));
    }
  } finally {
    if (mounted) setState(() => _isTogglingPeriod = false);
  }
}
```

اگر امضای دقیق `RitmoLog.error` با این فرق دارد، امضای موجود را در فایل `lib/core/logging/ritmo_logger.dart` بخوان و همان را بکار ببر. **فرض نکن.**

**۶.۳** در ویجت دکمه (`cycle_overview_tab.dart`):
- پارامتر `bool isTogglingPeriod` اضافه کن.
- وقتی `true` است، `onTap` را `null` کن و یک `CircularProgressIndicator` کوچک درون دکمه نشان بده.
- رنگ و ارتفاع دکمه را در حالت غیرفعال با `opacity: 0.6` نشان بده. طراحی را عوض نکن.

**۶.۴** متد `_confirmShortPeriod(int days)` را بساز: یک `AlertDialog` با متن خنثی که می‌پرسد این دوره فقط `days` روز طول کشیده — مطمئنی؟ دو دکمه: «بله، ثبت کن» و «انصراف». `Future<bool>` برگردان.

**معیار پذیرش:** دو ضربهٔ سریع روی دکمه فقط یک ردیف بسازد. هر استثنا باید به کاربر نشان داده شود، نه بلعیده شود.

**کامیت:** `fix(cycle): debounce و مدیریت خطای دکمهٔ شروع و پایان`

---

## فاز ۷ — تک‌منبع وضعیت قاعدگی (رفع تناقض UI با خودش)

**مسئله:** سه قاعدهٔ متفاوت برای «امروز روز قاعدگی است؟» در یک صفحه:
- برچسب دکمه ← `endDate == null && daysBetween < 12`
- `_checkIsPeriodDay` ← بازهٔ `[start, start + pDur - 1]`
- موتور ← منطق داخلی خودش

نتیجه: روز ۷ یک دورهٔ باز با `pDur = 6` → دکمه می‌گوید «ثبت پایان قاعدگی» ولی اُرب می‌گوید روز قاعدگی نیست و فاز = فولیکولار.

### کاری که می‌کنی

**۷.۱** فایل جدید: `lib/features/cycle/logic/cycle_period_status.dart`

```dart
/// تنها مرجع برای پاسخ به «این روز چه وضعیتی دارد؟»
/// UI هرگز نباید این محاسبات را دوباره پیاده کند.
class CyclePeriodStatus {
  const CyclePeriodStatus._();

  /// دورهٔ باز (endDate == null) — فقط یکی می‌تواند وجود داشته باشد.
  static CyclePeriod? openPeriod(List<CyclePeriod> periods);

  /// دورهٔ بازی که از آستانهٔ forgottenOpenPeriodDays گذشته.
  static CyclePeriod? forgottenPeriod(List<CyclePeriod> periods, DateTime today);

  /// فقط روزهای قطعی: دورهٔ بسته در بازهٔ [start, end]،
  /// یا دورهٔ باز در بازهٔ [start, today]. هرگز بر اساس pDur حدس نمی‌زند.
  static bool isConfirmedPeriodDay(List<CyclePeriod> periods, DateTime day, DateTime today);

  /// شمارهٔ روز درون دورهٔ فعال (۱-مبنا). اگر روز قاعدگی نیست، null.
  /// هرگز فال‌بک 1 برنمی‌گرداند.
  static int? activeDayNumber(List<CyclePeriod> periods, DateTime today);

  /// برچسب دکمه: true به معنای «ثبت پایان»، false به معنای «ثبت شروع».
  static bool shouldOfferEnd(List<CyclePeriod> periods, DateTime today);
}
```

**۷.۲** این محل‌ها را به این کلاس وصل کن و منطق تکراری را حذف کن:
- `cycle_overview_tab.dart`: `_checkIsPeriodDay` و `_calculateActivePeriodDay` را **حذف** کن و از `CyclePeriodStatus` بخوان.
- `hasActivePeriod` و برچسب دکمه → `CyclePeriodStatus.shouldOfferEnd`.
- هشدار دورهٔ فراموش‌شده → `CyclePeriodStatus.forgottenPeriod`.

**۷.۳** در `cycle_overview_tab.dart` این پیش‌فرض خطرناک را درست کن:

```dart
// غلط — وقتی خروجی موتور null است، UI ادعا می‌کند قاعدگی
engineOutput?.currentPhase ?? CyclePhase.menstrual
// درست
engineOutput?.currentPhase ?? CyclePhase.noData
```

**معیار پذیرش:** در روز ۷ یک دورهٔ باز، برچسب دکمه، اُرب و شمارهٔ روز همه با هم موافق باشند.

**کامیت:** `fix(cycle): تک‌منبع وضعیت روز قاعدگی`

---

## فاز ۸ — پنجرهٔ باروری: حذف کامل گیت

**مسئله (دقیقاً باگی که کاربر گزارش داد):** `seed_service.dart` و `migrations_registry.dart` مقدار `'cycle_fertility_visible': 'false'` را می‌نویسند. `CycleSettings.isFertilityVisible` دقیقاً روی رشتهٔ `'false'` خاموش می‌شود. پس **برای هر کاربر، از روز نصب، پنجرهٔ باروری مرده است** — و هیچ سوئیچی در هیچ جای برنامه برای روشن کردنش وجود ندارد. دو کامیت اخیر (`9d80ce4c` و `2c8487fc`) کد رسم را بهتر کردند ولی مقدار seed را لمس نکردند، پس اثری نداشتند.

### کاری که می‌کنی — دقیقاً همین ۶ گام

**۸.۱** در `lib/features/cycle/logic/cycle_settings.dart`:
- `static const String keyFertilityVisible = 'cycle_fertility_visible';` را **حذف** کن.
- متد `isFertilityVisible(...)` را **حذف** کن.

**۸.۲** در `lib/core/domain/engines/cycle_engine.dart`: هر شرطی که محاسبهٔ تخمک‌گذاری / پنجرهٔ باروری را پشت `isFertilityVisible` گذاشته را حذف کن. محاسبه همیشه انجام می‌شود و `ovulationDay`، `fertileStart`، `fertileEnd` همیشه پر می‌شوند.

**۸.۳** در `cycle_calendar_view.dart` (تابع `buildMonthMarks`): هر دو گیت روی `ovulationDays` و `fertileDays` را حذف کن. هر دو مسیر گذشته‌نگر (`markRetrospectiveCycle`) و مسیر پیش‌بینی باید مارک بزنند.

**۸.۴** در `cycle_calendar_legend.dart`: شرط `settings['cycle_fertility_visible'] != 'false'` را حذف کن. راهنمای تخمک‌گذاری و پنجرهٔ باروری همیشه نشان داده می‌شود.

**۸.۵** در `lib/core/database/seed/seed_service.dart` و `lib/core/database/migration/migrations_registry.dart`: خط `'cycle_fertility_visible': 'false',` را از بلوک تنزیمات **حذف** کن. هیچ مقدار جایگزینی نگذار.

**۸.۶** پاکسازی دادهٔ کاربران موجود. در مجموعهٔ مهاجرت‌ها، یک گام جدید با شمارهٔ نسخهٔ بعدی (مقدار فعلی را از `database_helper.dart` بخوان و یکی اضافه کن) اضافه کن که فقط این را اجرا می‌کند:

```sql
DELETE FROM app_settings WHERE key = 'cycle_fertility_visible';
```

نام جدول تنزیمات را از کد موجود `CycleSettings` بخوان و همان را بکار ببر. **حدس نزن.**

**۸.۷** در `test/cycle/cycle_engine_prediction_test.dart`: خط `'cycle_fertility_visible': 'false'` را از fixture حذف کن. بعد یک assertion جدید اضافه کن که برای یک چرخهٔ معمولی ۲۸ روزه، `fertileStart` و `fertileEnd` و `ovulationDay` هر سه **غیر null** هستند.

**معیار پذیرش:**
```bash
grep -rn "cycle_fertility_visible\|isFertilityVisible\|keyFertilityVisible" lib/ test/
```
فقط یک نتیجه مجاز است: خط `DELETE FROM` در مهاجرت پاکسازی.

**کامیت:** `fix(cycle): حذف گیت cycle_fertility_visible و روشن کردن همیشگی پنجرهٔ باروری`

---

## فاز ۹ — تقویم: دورهٔ باز را قطعی رنگ نکن

**مسئله:** در `buildMonthMarks`:

```dart
final effectiveEnd = pEnd ?? pStart.add(Duration(days: defaultPeriodDuration - 1));
```

برای دورهٔ **باز**، روزهایی که هنوز نرسیده‌اند به‌عنوان `recordedPeriod` (قرمز قطعی) رنگ می‌شوند — و چون `recordedPeriod` بالاترین اولویت است، هر مارک باروری/تخمک‌گذاری داخل آن بازه را پاک می‌کند. همچنین دورهٔ بازِ ۲۰ روزه فقط ۶ روز رنگ می‌شود.

### کاری که می‌کنی

**۹.۱** منطق را دقیقاً این‌طور بنویس:

```dart
final today = CycleDateContract.cleanDate(DateTime.now());

// دورهٔ بسته: همهٔ بازه قطعی است.
// دورهٔ باز: فقط تا امروز قطعی است؛ بقیه پیش‌بینی.
final DateTime confirmedEnd = pEnd ?? today;

// روزهای [pStart, confirmedEnd]  =>  CycleDayKind.recordedPeriod
// فقط اگر دوره باز است، روزهای
//   (today + 1) تا pStart + (defaultPeriodDuration - 1)
// =>  CycleDayKind.predictedPeriod   (نه recordedPeriod)
```

**۹.۲** سقف ایمنی: برای دورهٔ باز، رنگ‌آمیزی را حداکثر تا `CycleSettings.forgottenOpenPeriodDays` روز از `pStart` محدود کن. بیشتر از آن رنگ نزن — دورهٔ فراموش‌شده است و بنر مربوطه کارش را می‌کند.

**۹.۳ یکی‌سازی تعریف پنجرهٔ باروری.** الان دو تعریف موازی وجود دارد:
- مسیر گذشته‌نگر: `ovDate - 5 … ovDate + 1`
- مسیر پیش‌بینی: `cycle.fertileStart / cycle.fertileEnd` از موتور

یک تابع سطح‌بالای خالص در `cycle_date_contract.dart` بساز و هر دو مسیر از این استفاده کنند:

```dart
/// پنجرهٔ باروری استاندارد: ۵ روز قبل تا ۱ روز بعد از تخمک‌گذاری.
static ({DateTime start, DateTime end}) fertileWindowFor(DateTime ovulationDay)
```

و موتور (`cycle_engine.dart`) هم برای پر کردن `fertileStart`/`fertileEnd` از همین تابع استفاده کند.

**۹.۴ مارک PMS ساختگی.** وقتی لیست پیش‌بینی خالی است، `markRetrospectiveCycle` چرخهٔ بعدی را از `effectiveAvgCycle` حدس می‌زند و PMS را روی همان حدس با استایل دادهٔ واقعی رنگ می‌کند. درستش کن: مارک‌های مشتق‌شده از چرخهٔ حدسی باید `predictedCycle: true` و `confidenceLevel: PredictionConfidenceLevel.low` داشته باشند تا در تقویم کم‌رنگ‌تر/نقطه‌چین دیده شوند. استایل را در `cycle_calendar_grid.dart` اعمال کن.

**۹.۵ مقایسهٔ هویتی در `didUpdateWidget`.** الان `oldWidget.periods != widget.periods` است که مقایسهٔ مرجع است و شکننده. عوضش کن به مقایسهٔ محتوایی ارزان:

```dart
String _periodsFingerprint(List<CyclePeriod> ps) =>
    ps.map((p) => p.id + '|' + p.startDate.toIso8601String() + '|' + (p.endDate?.toIso8601String() ?? '')).join(',');
```

و فقط وقتی fingerprint عوض شد `_recomputeMarks` را صدا بزن. برای `settings` و `dayLogs` هم مشابه (طول + کلیدهای مرتبط) عمل کن.

**معیار پذیرش:** با یک دورهٔ باز که امروز روز ۳ام آن است، تقویم باید ۳ روز قطعی و بقیه را پیش‌بینی نشان دهد، و پنجرهٔ باروری همان ماه دیده شود.

**کامیت:** `fix(cycle): تفکیک روزهای قطعی و پیش‌بینی‌شدهٔ دورهٔ باز در تقویم`

---

## فاز ۱۰ — بازنویسی سرویس تأیید تعاملی

فایل: `lib/features/cycle/logic/cycle_confirmation_service.dart`

این سرویس پنج باگ مستقل دارد. همه را در همین فاز حل کن.

### ۱۰.۱ — سقف «۳ بار بپرس» کد مرده است

**مسئله:** `evaluatePendingRequest` درخواست تازه‌ساخته (`askCount: 0`) را هرگز در جدول ذخیره نمی‌کند و `askCount` را افزایش نمی‌دهد. افزایش فقط در `recordAnswer` رخ می‌دهد. پس برای درخواست بی‌پاسخ، `maxAutoAsksPerCycle` هرگز فعال نمی‌شود و همان درخواست بی‌نهایت بار برمی‌گردد.

**درست:** `evaluatePendingRequest` وقتی تصمیم گرفت یک درخواست را نشان دهد، قبل از برگرداندن باید upsert کند:

```dart
// اگر existing == null  =>  insert با askCount: 1, lastAskedAt: now, createdAt: now
// اگر existing != null و امروز با روزِ lastAskedAt فرق دارد:
//     =>  update با askCount: existing.askCount + 1, lastAskedAt: now
// اگر existing != null و همین امروز پرسیده شده =>  دست نزن
// اگر askCount بعد از افزایش > maxAutoAsksPerCycle  =>  null برگردان (دیگر نپرس)
```

مقایسهٔ «روز عوض شده؟» را با `CycleDateContract.isSameDay` انجام بده، نه با مقایسهٔ میلی‌ثانیه.

### ۱۰.۲ — نوع درخواست را از رشتهٔ id بازسازی نکن

**مسئله:** الان این کد وجود دارد:

```dart
requestId.startsWith('endDue') || requestId.startsWith('bleedingProlonged')
    ? 'endDue' : 'startDue'
```

ولی `CycleConfirmationRequest.buildId` الگوی `kind.name + '_' + dayKey` دارد. پس `startOverdue` به شاخهٔ else می‌افتد و غلط به‌عنوان `startDue` ذخیره می‌شود، و `bleedingProlonged` به `'endDue'` تبدیل می‌شود.

**درست:** امضای `recordAnswer` را عوض کن تا نوع را حدس نزند:

```dart
Future<void> recordAnswer({
  required DatabaseExecutor db,
  required CycleConfirmationRequest request,   // خودِ شیء، نه requestId
  required CycleConfirmationAnswer answer,
})
```

و `kind` را از `request.kind` بخوان. در نوشتن روی جدول `cycle_confirmations` مقدار ستون `kind` را `request.kind.name` بگذار. در خواندن هم از همین ستون `kind` بخوان، نه از `id`. فراخوان‌ها در `cycle_confirmation_sheet.dart` و `cycle_screen.dart` را با امضای جدید هم‌راست کن.

### ۱۰.۳ — «هنوز شروع نشده» نباید سکوت ابدی باشد

**مسئله (مهم):** `notStartedYet` پاسخ را با `answeredAt` ذخیره می‌کند، و `evaluatePendingRequest` وقتی `existing.isAnswered` باشد `null` برمی‌گرداند. چون `buildId` برای `startOverdue` از تاریخ ثابتِ پیش‌بینی‌شده استفاده می‌کند، id ثابت می‌ماند → **برنامه هرگز دوباره نمی‌پرسد، حتی ۱۰ روز بعد.** دقیقاً همان سناریویی که کاربر پرسیده بود: «اگر روز شروع برسد و کاربر پریود نشده باشد چه می‌شود؟»

**درست:** برای نوع `startOverdue`، تاریخ هدف باید **امروز** باشد، نه تاریخ پیش‌بینی‌شده:

```dart
// غلط: buildId(CycleConfirmationKind.startOverdue, predictedStart)
// درست: buildId(CycleConfirmationKind.startOverdue, today)
```

این طوری هر روز یک درخواست مجزا ساخته می‌شود و سقف کل توسط فاز ۱۰.۱ کنترل می‌شود. ولی برای شمارش سقف، مجموع `askCount` همهٔ درخواست‌های `startOverdue` از اولین روز تأخیر را حساب کن، نه یک ردیف را. یک متد کمکی بنویس:

```dart
Future<int> _askCountForKindSince(DatabaseExecutor db, CycleConfirmationKind kind, DateTime since);
```

### ۱۰.۴ — ترتیب اولویت

**مسئله:** الان تأیید شروع قبل از تأیید پایان بررسی می‌شود. کاربری که خونریزی طولانی دارد و شروع بعدی‌اش هم رسیده، پرسش شروع می‌گیرد نه پرسش خونریزی.

**درست:** دقیقاً این ترتیب، اولین موردی که مطابقت کرد برمی‌گردد:

1. `bleedingProlonged` — دورهٔ باز از (متوسط + `prolongedBleedingGraceDays`) گذشته
2. `endDue` — طول مورد انتظار قاعدگی رسیده و دوره هنوز باز است
3. `startOverdue` — تاریخ پیش‌بینی‌شدهٔ شروع گذشته و دوره‌ای ثبت نشده
4. `startDue` — امروز روز پیش‌بینی‌شدهٔ شروع است

### ۱۰.۵ — تعویق نباید همهٔ انواع را خفه کند

**مسئله:** یک کلید واحد `cycle_confirm_snooze_until` زود هنگام `null` برمی‌گرداند، پس تعویق یک پرسش «شروع شد؟» همزمان پرسش فوری «خونریزی طولانی» را هم خفه می‌کند.

**درست:**
- کلید تعویق را پر‌نوع کن: `'cycle_confirm_snooze_until_' + kind.name`. ثابت `keyConfirmSnoozeUntil` را به یک تابع تبدیل کن: `static String snoozeKeyFor(CycleConfirmationKind kind)`.
- نوع `bleedingProlonged` را **هرگز** قابل تعویق نکن. این پرسش سلامتی است.
- خطای یک‌واحد را درست کن: گیت فعلی `isSameOrBefore(cleanNow, snoozeDate)` است که خودِ روز تعویق را هم می‌پوشاند پس تعویق ۱ روزه عملاً ۲ روز می‌شود. عوضش کن به:
  ```dart
  if (snoozeDate != null && cleanNow.isBefore(snoozeDate)) return null;
  ```

### ۱۰.۶ — `createdAt` معنای غلط دارد

الان `'createdAt': existing?.targetDate.millisecondsSinceEpoch` است — یک **تاریخ** به‌جای زمان ایجاد. عوضش کن به `DateTime.now().millisecondsSinceEpoch` برای درج و در به‌روزرسانی دست نزن.

### ۱۰.۷ — `onActualCycleStarted` و `pruneOldRequests` کد مرده‌اند

هر دو متد وجود دارند ولی **از هیچ‌جا صدا زده نمی‌شوند**، پس `cycle_confirmations` بی‌مرز رشد می‌کند.

در `cycle_screen.dart` یک متد بساز و بعد از هر نوشتن موفق صدایش بزن (مطابق فاز ۵.۴):

```dart
Future<void> _syncConfirmations() async {
  final db = await DatabaseHelper.instance.database;
  await _confirmationService.onActualCycleStarted(db: db);
  await _confirmationService.pruneOldRequests(db: db);
}
```

همچنین در `pruneOldRequests`، مقایسهٔ `targetDate < ?` به‌عنوان TEXT درست است (فرمت `YYYY-MM-DD` مرتب‌شدنی است) پس نگهش دار، فقط یک کامنت بالایش بنویس که چرا ایمن است.

### ۱۰.۸ — محافظت از خطا

`recordAnswer` هیچ `try/catch` ندارد و مستقیم `startPeriod` را صدا می‌زند. هر استثنا از callback برگه بیرون می‌زند. در `cycle_confirmation_sheet.dart`، `onAnswered` را در `try/catch` بپیچ و در خطا یک SnackBar خنثی نشان بده و برگه را باز نگه دار.

### ۱۰.۹ — بازمحاسبهٔ بنر

`_pendingConfirmation` فقط در `_loadData()` محاسبه می‌شود، ولی `_onStateNotifierChanged` آن را بازمحاسبه نمی‌کند → بنر بعد از تغییرات پس‌زمینه کهنه می‌ماند. در `_onStateNotifierChanged` هم `evaluatePendingRequest` را باز صدا بزن.

**کامیت:** `fix(cycle): بازنویسی منطق سرویس تأیید تعاملی`

---

## فاز ۱۱ — دورهٔ فراموش‌شده: دیگر داده جعل نکن

**مسئله:** `_closeForgottenPeriod` همچنان `endDate = start + (periodDuration - 1)` می‌نویسد بدون پرسیدن. اگر خونریزی واقعاً ادامه داشته، رکورد غلط و ماندگار می‌شود و همهٔ محاسبات متوسط را مسموم می‌کند.

### کاری که می‌کنی

**۱۱.۱** متد `_closeForgottenPeriod` را حذف کن.

**۱۱.۲** دکمهٔ هشدار دورهٔ فراموش‌شده باید یک شیت باز کند که از کاربر **تاریخ واقعی پایان** را بپرسد:

```dart
// شیت باید سه گزینه داشته باشد:
// 1) «هنوز ادامه دارد»  =>  دوره باز بماند، تعویق ۱ روزه، و
//                          اگر از آستانهٔ prolongedBleedingGraceDays گذشته،
//                          پیام ارجاع به پزشک (متن خنثی، بدون تشخیص)
// 2) انتخاب تاریخ پایان از تقویم  =>  endPeriod با همان تاریخ
// 3) «یادم نیست»  =>  endPeriod با endDate = startDate
//                     و note = 'auto_closed_unknown_end'
```

برای گزینهٔ ۲ از همان date picker موجود در `add_edit_period_sheet.dart` استفاده کن. ویجت جدید نساز اگر می‌توانی همان را دوباره استفاده کنی.

**۱۱.۳** ردیف‌های با `note == 'auto_closed_unknown_end'` باید از محاسبهٔ **متوسط طول قاعدگی** در موتور حذف شوند (ولی از محاسبهٔ متوسط طول چرخه حذف نشوند — تاریخ شروعشان معتبر است). در `cycle_engine.dart` این فیلتر را اعمال کن.

**کامیت:** `fix(cycle): پرسیدن تاریخ واقعی پایان دورهٔ فراموش‌شده`

---

## فاز ۱۲ — بدهی روزه: پوشش کامل

**مسئله:** `addFastingDebtIfNeeded(db, todayStr)` فقط برای **روز شروع** و فقط در `_togglePeriodToday` صدا زده می‌شود. روزهای ۲ تا n هیچ بدهی نمی‌گیرند. `_openAddEditPeriodSheet` و سرویس تأیید هیچ بدهی نمی‌سازند. حذف دوره بدهی را پاک نمی‌کند.

### کاری که می‌کنی

**۱۲.۱** یک متد مرکزی بساز در همان فایلی که `addFastingDebtIfNeeded` الان درش هست:

```dart
/// بدهی روزه را برای همهٔ روزهای قطعیِ همهٔ دوره‌ها همگام می‌کند.
/// برای روزهایی که دیگر در هیچ دوره‌ای نیستند، بدهی را حذف می‌کند.
/// idempotent است: چندبار صدا زدنش نتیجهٔ یکسان می‌دهد.
Future<void> syncFastingDebtForAllPeriods(DatabaseExecutor db);
```

منطق:
- اگر `cycle_consent_worship != 'true'` → هیچ کاری نکن و خروج.
- مجموعهٔ همهٔ روزهای قطعی قاعدگی را از `CyclePeriodStatus.isConfirmedPeriodDay` بساز (دورهٔ باز فقط تا امروز).
- برای هر روزی که در مجموعه هست و بدهی ندارد → بساز.
- برای هر بدهیِ خودکارِ موجود که تاریخش در مجموعه نیست و پرداخت نشده → حذف کن. **بدهی‌های دستیِ کاربر یا پرداخت‌شده را هرگز حذف نکن.** برای تفکیک، ستون/فیلد موجود در جدول بدهی را بخوان؛ اگر چنین تفکیکی نیست، **هیچ بدهی‌ای را حذف نکن** و فقط افزودن را پیاده کن.

**۱۲.۲** متد `_syncFastingDebt()` را در `cycle_screen.dart` بساز که فقط همین را صدا می‌زند، و بعد از **هر** نوشتن موفق (شروع، پایان، ویرایش، حذف، پاسخ برگهٔ تأیید) صدایش بزن.

**۱۲.۳** متد قدیمی `addFastingDebtIfNeeded` را نگه دار اما فقط از درون `syncFastingDebtForAllPeriods` صدا زده شود. فراخوانی مستقیم از UI را حذف کن.

**کامیت:** `fix(cycle): همگام‌سازی بدهی روزه برای همهٔ روزهای دوره`

---

## فاز ۱۳ — دو قابلیت که بدنهٔ خالی دارند

### ۱۳.۱ — `onOpenPasscodeSheet: () {}`

در `cycle_screen._openSettingsSheet` این callback یک no-op خالی است. کاربر روی «تغییر رمز چرخه» می‌زند و هیچ اتفاقی نمی‌افتد.

فایل جدید بساز: `lib/features/cycle/presentation/widgets/cycle_passcode_sheet.dart`

```dart
/// شیت تعیین/تغییر/حذف رمز ماژول چرخه.
class CyclePasscodeSheet {
  static Future<bool> show(BuildContext context);
}
```

رفتار لازم:
- اگر رمزی تنزیم نشده: دو فیلد «رمز جدید» و «تکرار رمز».
- اگر رمز تنزیم شده: اول «رمز فعلی»، بعد دو فیلد بالا. دکمهٔ «حذف رمز» هم باشد که فقط با وارد کردن رمز فعلی کار می‌کند.
- حداقل ۴ رقم. فقط عدد. ورودی مخفی (`obscureText: true`).
- ذخیره و اعتبارسنجی رمز را از همان سرویس موجود `cycle_lock_service.dart` انجام بده. **متدهای موجود آن فایل را بخوان و همان‌ها را بکار ببر؛ متد جدید ذخیره‌سازی رمز نساز و رمز را خام در تنزیمات ننویس.**

بعد در `cycle_screen.dart`:
```dart
onOpenPasscodeSheet: () => CyclePasscodeSheet.show(context),
```

### ۱۳.۲ — `onEditBaselineParameter` بدنهٔ خالی دارد

الان دقیقاً این است:

```dart
onEditBaselineParameter: (key, title, min, max, defVal) async {
  // Implementation for parameter edit
},
```

**کاربر نمی‌تواند طول چرخه، طول قاعدگی یا فاز لوتئال را عوض کند.** پیاده‌اش کن:

```dart
onEditBaselineParameter: (key, title, min, max, defVal) async {
  final current = await CycleSettings.getInt(key) ?? defVal;
  final picked = await showModalBottomSheet<int>(...);   // یک اسلایدر یا NumberPicker با بازهٔ [min, max]
  if (picked == null || picked == current) return;
  await CycleSettings.setInt(key, picked);
  CycleEngine().invalidate();          // اجباری — پارامترهای پایه پیش‌بینی را عوض می‌کنند
  await _loadData();
}
```

امضای واقعی setter/getter در `CycleSettings` را از همان فایل بخوان و همان را بکار ببر. مقدار انتخابی را با `clamp(min, max)` محدود کن. بازه‌های مجاز: طول چرخه [21,45]، طول قاعدگی [2,10]، فاز لوتئال [10,16].

**کامیت:** `fix(cycle): پیاده‌سازی شیت رمز و ویرایش پارامترهای پایه`

---

## فاز ۱۴ — کارت ناهنجاری: محاسبه می‌شود ولی رسم نمی‌شود

**مسئله:** `CycleState.anomalies` در `loadState()` محاسبه می‌شود ولی `cycle_screen.dart` هرگز آن را نمی‌خواند، و فایل `cycle_anomaly_card.dart` اصلاً وجود ندارد.

**۱۴.۱** فایل جدید: `lib/features/cycle/presentation/widgets/cycle_anomaly_card.dart`

```dart
class CycleAnomalyCard extends StatelessWidget {
  const CycleAnomalyCard({
    super.key,
    required this.anomalies,
    required this.onDismiss,
  });

  final List<CycleAnomaly> anomalies;
  final VoidCallback onDismiss;
}
```

قواعد رندر:
- اگر `anomalies` خالی است → `SizedBox.shrink()`.
- فقط شدیدترین مورد را پرومیننت نشان بده؛ بقیه در یک تاگل.
- رنگ بر اساس `CycleAnomalySeverity`: `info` → خنثی، `watch` → کهربایی، `consultClinician` → قرمز کم‌اشباع.
- متن برای `consultClinician` حتماً شامل ارجاع به پزشک باشد، ولی **هرگز تشخیص پزشکی نده**. از حالت توصیفی استفاده کن: «این الگو از محدودهٔ معمول خودت خارج شده؛ بهتر است با پزشک مشورت کنی.»
- متن‌ها باید از همان منبع متن‌های خنثی موجود بیایند (کامیت `d1df66fd` تک‌منبعش را ساخته)؛ متن هاردکد ننویس اگر همان منبع وجود دارد.

**۱۴.۲** در `cycle_overview_tab.dart` این کارت را دقیقاً زیر `CycleStatusBanner` و بالای اُرب قرار بده. پارامتر `anomalies` را از `cycle_screen.dart` پاس بده.

**۱۴.۳** یک کلید تنزیمات برای رد کردن (dismiss) بساز: `'cycle_anomaly_dismissed_until'` که تاریخ `YYYY-MM-DD` ذخیره می‌کند. `onDismiss` این را روی `امروز + 7` می‌گذارد. **اما موارد با شدت `consultClinician` قابل رد کردن نیستند** — کارت دکمهٔ dismiss را در این حالت نشان ندهد.

**کامیت:** `feat(cycle): رندر کارت ناهنجاری چرخه`

---

## فاز ۱۵ — درگاه قفل و پرچم بیومتریک

**مسئله:** `CycleSettings.isBiometricEnabled` (کلید `cycle_biometric_enabled`، پیش‌فرض `false`) در دور قبل اضافه شد، اما `cycle_lock_gate.dart` دست‌نخورده ماند (SHA همان `b645138c…` قبل از اجرای پرامپت است). پس درگاه قفل هنوز هرجا PIN وجود داشته باشد بیومتریک پیشنهاد می‌دهد و این پرچم را نادیده می‌گیرد. یعنی `isBiometricEnabled` هیچ‌جا مصرف نمی‌شود.

### کاری که می‌کنی

**۱۵.۱** در `cycle_lock_gate.dart`، مسیر بیومتریک را فقط وقتی فعال کن که **هر دو** شرط برقرار باشند:
```dart
final biometricAllowed = await CycleSettings.isBiometricEnabled(settings)
    && await <سرویس موجود>.isDeviceBiometricAvailable();
```
نام دقیق متد تشخیص دستگاه را از کد موجود همین فایل بخوان. **حدس نزن.**

**۱۵.۲** اگر بیومتریک مجاز نیست، دکمهٔ «ورود با اثر انگشت/چهره» را **رندر نکن**. فقط غیرفعالش نکن — حذفش کن.

**۱۵.۳** در `cycle_settings_panel.dart` یک سویچ برای `cycle_biometric_enabled` اضافه کن. اگر دستگاه بیومتریک ندارد، سویچ را غیرفعال نشان بده با زیرنویس توضیحی.

**۱۵.۴** `isLockEnabled` پیش‌فرض `true` است (fail-secure). این درست است — عوضش نکن.

**کامیت:** `fix(cycle): احترام درگاه قفل به پرچم بیومتریک`

---

## فاز ۱۶ — switch های غیرجامع روی `CyclePhase`

**مسئله:** `_getActivePhaseColor` در `cycle_overview_tab.dart` این را دارد:

```dart
case CyclePhase.follicular:
default:
  return <رنگ فولیکولار>;
```

پس `dataStale`، `pregnancy` و `noData` همه بی‌صدا رنگ فولیکولار می‌گیرند — یعنی UI ادعای دادهٔ معتبر می‌کند در حالی که داده‌ای نیست.

### کاری که می‌کنی

**۱۶.۱** `default:` را حذف کن و هر ۷ مقدار `CyclePhase` را صریح بنویس: `menstrual`, `follicular`, `ovulation`, `luteal`, `dataStale`, `pregnancy`, `noData`.

**۱۶.۲** رنگ و متن مختص برای سه حالت جدید:
- `dataStale` → خاکستری خنثی + متن «داده‌ها قدیمی است»
- `noData` → خاکستری خنثی + متن «هنوز داده‌ای نداریم»
- `pregnancy` → رنگ مختص حالت بارداری

**۱۶.۳** همان کار را در `cycle_sos_section.dart` و `cycle_orb_card.dart` انجام بده. این دو فایل در دور قبل دست‌نخورده ماندند. دنبال `switch` روی `CyclePhase` بگرد:

```bash
grep -rn "CyclePhase" lib/features/cycle/presentation/widgets/ | grep -n "default"
```

**۱۶.۴** در `analysis_options.yaml` مطمئن شو `exhaustive_cases` فعال است. اگر نیست، فعالش کن. این جلوی تکرار این دسته باگ را می‌گیرد.

**کامیت:** `fix(cycle): جامع‌سازی switch فازهای چرخه`

---

## فاز ۱۷ — دو کارت هشدار روی هم

**مسئله:** `cycle_overview_tab.dart` هم `CycleStatusBanner` را با `onCloseForgottenPeriod` می‌سازد و هم `_buildForgottenPeriodWarning` را وقتی `forgottenPeriod != null && pendingConfirmation == null`. پس کاربر دو کارت هشدار با دو دکمهٔ «ثبت پایان» متفاوت می‌بیند.

### کاری که می‌کنی

**۱۷.۱** `_buildForgottenPeriodWarning` را کامل **حذف** کن.

**۱۷.۲** `CycleStatusBanner` تنها محل نمایش همهٔ حالت‌های هشدار باشد. یک اولویت واحد درونش پیاده کن و فقط یک حالت را رندر کن:

1. درخواست تأیید معلق (`pendingRequest != null`) → دکمهٔ «پاسخ می‌دهم» که `onOpenConfirmation` را صدا می‌زند
2. دورهٔ فراموش‌شده → دکمهٔ «تعیین تاریخ پایان» که `onCloseForgottenPeriod` را صدا می‌زند (فاز ۱۱)
3. تأخیر در شروع → متن اطلاع‌رسانی بدون دکمه
4. دادهٔ کهنه (`dataStale`) → متن دعوت به ثبت
5. هیچ‌کدام → `SizedBox.shrink()`

**۱۷.۳** امضای فعلی محل فراخوانی `CycleStatusBanner` این است: `engineOutput:`، `pendingRequest:`، `onOpenConfirmation:`، `onCloseForgottenPeriod:`. **همین امضا را نگه دار** و فقط پارامتر `anomalies` را اگر لازم داشتی اضافه کن. امضا را بیهوده عوض نکن.

**کامیت:** `fix(cycle): حذف هشدار تکراری دورهٔ فراموش‌شده`

---

## فاز ۱۸ — اعتبارسنجی شیت افزودن/ویرایش

فایل: `lib/features/cycle/presentation/widgets/add_edit_period_sheet.dart`

**مسئله:** `onValidate` فقط `end.isBefore(start)` را چک می‌کند. نه تاریخ آینده، نه هم‌پوشانی، نه حداکثر طول. کاربر می‌تواند دورهٔ ۶۰ روزه یا دو دورهٔ هم‌پوشان بسازد که `avgCycleLength` را نابود می‌کند.

### کاری که می‌کنی

**۱۸.۱** اعتبارسنجی را از شیت بیرون بکش و درون ریپازیتوری بگذار (فاز ۴، قاعدهٔ R4). شیت فقط پیام خطای برگشتی را نشان می‌دهد. این کار تکرار منطق را حذف می‌کند.

**۱۸.۲** برای پیش‌اعتبارسنجی زنده (قبل از زدن ذخیره)، یک تابع خالص در ریپازیتوری بساز که شیت هم می‌تواند صدایش بزند:

```dart
/// null به معنای معتبر؛ در غیر این صورت پیام خطای فارسی برای کاربر.
String? validatePeriodRange({
  required List<CyclePeriod> existing,
  required String? editingId,
  required DateTime startDate,
  DateTime? endDate,
});
```

قواعد دقیقاً همان R4 فاز ۴ باشد. هرگز دو جای مختلف قواعد متفاوت ننویس.

**۱۸.۳** دکمهٔ ذخیره را تا وقتی `validatePeriodRange` غیرnull برمی‌گرداند غیرفعال کن و پیام را زیر فیلد نشان بده.

**۱۸.۴** مقدار `flowIntensity` را قابل انتخاب کن. الان هر شروع، `'MEDIUM'` هاردکد می‌شود و سطح جریانِ لاگ روزانه هرگز به ردیف دوره منتقل نمی‌شود. سه گزینه: `LIGHT`، `MEDIUM`، `HEAVY`. مقادیر مجاز را از همان جایی که `cycle_day_logs.flowLevel` استفاده می‌کند بخوان تا دو واژگان متفاوت نسازی.

**کامیت:** `fix(cycle): اعتبارسنجی کامل و انتخاب شدت جریان در شیت دوره`

---

## فاز ۱۹ — کارت پیش‌بینی و آستانه‌های متناقض

### ۱۹.۱ — سه آستانهٔ متفاوت «دادهٔ کافی» در یک صفحه

الان:
- کارت پیش‌بینی: `totalRecordedCycles >= 2`
- `CycleSettings.minCyclesForReliableForecast`: `3`
- `_predictionConfidence`: `_periods.length >= 5` و `>= 3`

**درست:** همه از `CycleSettings.minCyclesForReliableForecast` بخوانند. هر عدد هاردکدی (`2`، `3`، `5`) را حذف کن. اگر برای سطح بالای اطمینان به آستانهٔ دوم لازم داری، یک ثابت جدید در `CycleSettings` بساز: `static const int cyclesForHighConfidence = 5;` و همه‌جا از همان بخوان.

### ۱۹.۲ — کارت پیش‌بینی تاریخ گذشته را «تاریخ تخمینی شروع» نشان می‌دهد

`_buildNextPeriodPredictionCard` هیچ گیتی روی `isOverdue` یا `awaitingStartConfirmation` ندارد.

**درست:** سه حالت مجزا رندر کن:
- تاریخ پیش‌بینی‌شده در آینده → متن فعلی «تاریخ تخمینی شروع»
- تاریخ گذشته و دوره‌ای ثبت نشده → «X روز از تاریخ تخمینی گذشته» + دکمهٔ «ثبت کنم» که مستقیم شیت افزودن را باز می‌کند
- دورهٔ باز وجود دارد → کارت پیش‌بینی **شروع** را رندر نکن؛ به‌جایش تخمین پایان را نشان بده

### ۱۹.۳ — `_predictionConfidence` از دادهٔ کهنه می‌خواند

در `_onStateNotifierChanged` از `_periods.length` استفاده می‌کند، ولی `_periods` فقط در `_loadData` تازه می‌شود. درستش کن: از `stateNotifier.state.periods` بخوان که همیشه تازه است، یا `_periods` را در همان callback هم به‌روز کن.

### ۱۹.۴ — `loadState()` سه بار دوره‌ها را می‌خواند

در `cycle_state_provider.dart`، `loadState` هم `getAllPeriods`، هم `getActivePeriod`، و هم یک `db.query('cycle_periods', orderBy: 'startDate ASC')` خام را صدا می‌زند.

**درست:** یک بار `getAllPeriods` را صدا بزن و بقیه را در حافظه مشتق کن:
```dart
final periods = await _repo.getAllPeriods(db);
final active = CyclePeriodStatus.openPeriod(periods);
// ورودی موتور را هم از همین لیست بساز (مرتب صعودی اگر لازم است)
```
متد `getActivePeriod` را حذف کن و هر مصرف‌کننده‌اش را به `getOpenPeriod` یا `CyclePeriodStatus.openPeriod` وصل کن.

### ۱۹.۵ — `loadState()` کش موتور را باطل نمی‌کند

این درست است و نباید عوض شود — `loadState` یک خواندن است. اما مطمئن شو بعد از فاز ۴ (قاعدهٔ R7)، هر مسیر نوشتنی `invalidate` را خودش انجام داده باشد. یک کامنت بالای `loadState` بنویس که چرا اینجا `invalidate` لازم نیست.

### ۱۹.۶ — ستون مرده `dateIso`

`_openLogTodaySheet` شرط `l?['dateIso'] == dateStr` دارد، ولی جدول `cycle_day_logs` ستون `dateIso` ندارد — نام واقعی `logDate` است. درستش کن.

### ۱۹.۷ — ناسازگاری ترتیب

`cycle_screen` با `startDate DESC` می‌خواند، `CycleStateNotifier` با `startDate ASC`. بعد از فاز ۵، `cycle_screen` دیگر مستقیم نمی‌خواند. مطمئن شو هر جایی که ترتیب مهم است (محاسبهٔ متوسط چرخه، تاریخچه) مرتب‌سازی را صریح اعمال کن و به ترتیب خروجی ریپازیتوری تکیه نکن.

**کامیت:** `fix(cycle): یکی‌سازی آستانه‌ها و حالت‌های کارت پیش‌بینی`

---

## فاز ۲۰ — کارایی بازمحاسبهٔ مارک‌های تقویم

**مسئله:** `_recomputeMarks` روی UI thread اجرا می‌شود و برای **هر تغییر ماه** کل `sortedStarts` را با حلقهٔ روز‌به‌روز از صفر می‌سازد. با تاریخچهٔ بلند و افق ۱۲ چرخه‌ای، هنگام swipe ماه‌ها jank می‌دهد.

### کاری که می‌کنی

**۲۰.۱** محدوده را قبل از حلقه برش بزن: فقط دوره‌ها و چرخه‌هایی را پردازش کن که با بازهٔ `[اول ماه - 45روز, آخر ماه + 45روز]` تلاقی دارند. ۴۵ روز چون حداکثر طول چرخه ۴۵ است.

**۲۰.۲** نتیجه را پر‌ماه کش کن:
```dart
final Map<String, Map<DateTime, CycleDayMark>> _marksByMonth = {};
// کلید: 'YYYY-MM' + '|' + fingerprint
```
وقتی fingerprint عوض شد، کل کش را پاک کن.

**۲۰.۳** محاسبه را به isolate منتقل **نکن**. با برش محدوده و کش، پیچیدگی اضافی لازم نیست.

**کامیت:** `perf(cycle): کش و برش محدودهٔ مارک‌های تقویم`

---

## فاز ۲۱ — تست‌ها: ریشهٔ اصلی اینکه دور قبل سبز شد ولی کار نکرد

### مهم‌ترین درس این دور

دور قبل، تست‌ها سبز شدند اما قابلیت خراب ماند، چون `test/cycle/cycle_engine_cache_test.dart` جدول را دستی و **متفاوت از واقعیت** می‌سازد:

```dart
// در تست (غلط):
'CREATE TABLE cycle_periods (id INTEGER PRIMARY KEY AUTOINCREMENT, ...)'
// در محصول (درست):
'CREATE TABLE cycle_periods (id TEXT PRIMARY KEY, ...)'
```

در SQLite، `INTEGER PRIMARY KEY AUTOINCREMENT` یعنی درج بدون `id` مجاز است. در `TEXT PRIMARY KEY` مجاز نیست. پس تست موفق می‌شد و محصول در دستگاه کاربر می‌شکست. **این الگو نباید تکرار شود.**

### ۲۱.۱ — فیکسچر مشترک تست (اجباری)

فایل جدید: `test/cycle/helpers/cycle_test_db.dart`

```dart
/// تنها راه مجاز ساخت دیتابیس در تست‌های چرخه.
/// جدول‌ها را از همان منبع محصول (CycleTables) می‌سازد.
/// هرگز DDL دستی نمی‌نویسد.
Future<Database> openCycleTestDb();
```

قواعد پیاده‌سازی:
- `sqflite_common_ffi` را همان‌طور که تست‌های موجود می‌کنند مقداردهی کن.
- لیست DDL را از `CycleTables` بخوان و در حلقه execute کن. **نام دقیق فیلد/متد لیست DDL را از خود `lib/core/database/schema/tables/cycle_tables.dart` بخوان. حدس نزن.**
- اگر جدول تنزیمات (`app_settings` یا هر نامی که واقعاً دارد) لازم است، آن را هم از منبع واقعیِ اسکیما بساز.
- یک تابع کمکی هم بگذار برای درج سریع دوره:
  ```dart
  Future<String> seedPeriod(Database db, {required DateTime start, DateTime? end, String? note});
  ```
  این تابع باید از `CyclePeriodContract.newId()` و `CyclePeriodContract.col*` استفاده کند.

### ۲۱.۲ — بازنویسی همهٔ تست‌های چرخه روی فیکسچر

این فایل‌ها DDL دستی دارند و باید به `openCycleTestDb()` منتقل شوند:

| فایل | مشکل فعلی |
|---|---|
| `test/cycle/cycle_engine_cache_test.dart` | `id INTEGER PRIMARY KEY AUTOINCREMENT` — **غلط** |
| `test/cycle/cycle_onboarding_test.dart` | `id TEXT PRIMARY KEY` دستی |
| `test/cycle/cycle_correlation_test.dart` | `id TEXT PRIMARY KEY` دستی |
| `test/cycle/cycle_engine_prediction_test.dart` | دستی + ادعای `cycle_fertility_visible` |
| `test/cycle/cycle_engine_overdue_test.dart` | بررسی کن |
| `test/migration_test.dart` | دست نزن — این عمداً مهاجرت را تست می‌کند |

قاعده: هر `CREATE TABLE cycle_` در `test/cycle/` باید حذف شود. این را با همین دستور تأیید کن:

```bash
grep -rn "CREATE TABLE cycle_" test/cycle/
# انتظار: فقط test/cycle/helpers/cycle_test_db.dart یا هیچ‌چیز
```

### ۲۱.۳ — تست قرارداد اسکیما (جدید، اجباری)

فایل جدید: `test/cycle/cycle_schema_contract_test.dart`

این تست دقیقاً باگی را که دور قبل رد شد می‌گیرد. حداقل پنج مورد:

```dart
// 1) ستون‌های واقعی جدول دقیقاً با CyclePeriodContract.allColumns برابر باشند
//    (از PRAGMA table_info(cycle_periods) بخوان، هر دو طرف را مرتب کن و مقایسه کن)
//    این مورد، هر ستون فانتوم در کد را فوری قرمز می‌کند.

// 2) نوع ستون id دقیقاً 'TEXT' باشد

// 3) درج بدون id باید خطا بدهد
//    expect(() => db.insert('cycle_periods', {'startDate': '2026-01-01'}), throwsA(...))
//    اگر این تست سبز شود، یعنی فیکسچر باز هم اشتباه است.

// 4) DDL در cycle_tables.dart و migrations_registry.dart برای cycle_periods
//    مجموعهٔ ستون یکسان بدهند (تست برابری دو منبع)

// 5) هیچ ردیفی در app_settings با key = 'cycle_fertility_visible' باقی نماند
//    (بعد از اجرای seed و مهاجرت)
```

### ۲۱.۴ — تست‌های رفتاری جدید

فایل جدید: `test/cycle/cycle_period_repository_test.dart`

```dart
// T1  startPeriod یک ردیف می‌سازد و id غیرخالی برمی‌گرداند
// T2  startPeriod دوباره در همان روز ردیف دوم نمی‌سازد (همان id برمی‌گردد)
// T3  startPeriod وقتی دورهٔ باز وجود دارد خطا می‌دهد
// T4  startPeriod با تاریخ آینده خطا می‌دهد
// T5  endPeriod با تاریخ قبل از شروع خطا می‌دهد
// T6  endPeriod با طول بیش از 12 روز خطا می‌دهد
// T7  updatePeriod با هم‌پوشانی دورهٔ دیگر خطا می‌دهد
// T8  updatePeriod با id ناموجود StateError می‌دهد (نه سکوت)
// T9  رفت و برگشت: نوشتن با ریپازیتوری و خواندن با getAllPeriods
//     همهٔ فیلدها را بدون تغییر برمی‌گرداند (خصوصاً flowIntensity و note)
// T10 deletePeriod ردیف را حقیقتاً حذف می‌کند
```

فایل جدید: `test/cycle/cycle_period_status_test.dart`

```dart
// S1 دورهٔ باز را درست تشخیص می‌دهد
// S2 دورهٔ بازِ فراتر از 12 روز را forgotten می‌داند
// S3 isConfirmedPeriodDay برای روز آیندهٔ دورهٔ باز false می‌دهد
// S4 activeDayNumber برای حالت بدون دورهٔ باز null می‌دهد (نه 1)
// S5 activeDayNumber روز شروع برابر 1 است
```

فایل جدید: `test/cycle/cycle_confirmation_service_test.dart`

```dart
// C1 درخواست تازه با askCount = 1 ذخیره می‌شود
// C2 بار دوم در روز بعد، askCount = 2 می‌شود
// C3 بعد از maxAutoAsksPerCycle دیگر null برمی‌گردد
// C4 kind از ستون kind خوانده می‌شود: startOverdue در دیتابیس
//    دقیقاً 'startOverdue' ذخیره شده (نه 'startDue')
// C5 پاسخ notStartedYet فردا دوباره می‌پرسد (سکوت ابدی نیست)
// C6 تعویق 1 روزه فردا رفع می‌شود (نه پس‌فردا)
// C7 تعویق startDue روی bleedingProlonged اثر ندارد
// C8 اولویت: وقتی هم bleedingProlonged و هم startDue مطابقت دارند،
//    bleedingProlonged برمی‌گردد
```

فایل جدید: `test/cycle/cycle_fertile_window_test.dart`

```dart
// F1 CycleDateContract.fertileWindowFor دقیقاً [ov-5, ov+1] می‌دهد
// F2 buildMonthMarks برای یک چرخهٔ معمولی حداقل یک fertileWindow
//    و دقیقاً یک ovulation تولید می‌کند  <<< باگ مورد اشارهٔ کاربر
// F3 مسیر بازنگر (گذشته) و مسیر موتور (آینده) برای همان
//    روز تخمک‌گذاری پنجرهٔ یکسان می‌دهند
// F4 هیچ مسیری دیگر به cycle_fertility_visible وابسته نیست:
//    حتی با درج دستی 'false' در تنزیمات، مارک‌های باروری تولید شوند
```

فایل جدید: `test/cycle/cycle_fasting_debt_test.dart`

```dart
// D1 دورهٔ 6 روزهٔ بسته → 6 بدهی (نه 1)
// D2 اجرای دوباره → باز 6 بدهی (idempotent)
// D3 حذف دوره → بدهی‌های خودکار پاک می‌شوند
// D4 با cycle_consent_worship = false → هیچ بدهی‌ای ساخته نمی‌شود
```

### ۲۱.۵ — قاعدهٔ طلایی تست

قبل از نوشتن هر assert، اول تست را برای **فایل قدیمی** اجرا کن تا مطمئن شوی **قرمز می‌شود**. اگر تست قبل از اصلاح سبز بود، تست بی‌ارزش است و باید بازنویسی شود. این را برای حداقل این سه مورد صریحاً انجام بده: مورد ۳ تست قرارداد، F2، و D1.

**کامیت:** `test(cycle): فیکسچر مشترک و تست قرارداد اسکیما`

---

## فاز ۲۲ — راستی‌آزمایی نهایی

به ترتیب اجرا کن و خروجی را با مبنای فاز ۱ مقایسه کن:

```bash
flutter analyze > /tmp/r2_analyze_after.txt 2>&1
diff /tmp/r2_analyze_before.txt /tmp/r2_analyze_after.txt || true

flutter test > /tmp/r2_test_after.txt 2>&1
diff /tmp/r2_test_before.txt /tmp/r2_test_after.txt || true
```

### شرایط پذیرش قطعی

- تعداد خطاهای `flutter analyze` **برابر ۰** باشد. هیچ error جدیدی قابل قبول نیست. اگر مبنا هم خطا داشته، خطاهای مربوط به ماژول چرخه را حتماً صفر کن.
- همهٔ تست‌های موجود که قبلاً سبز بودند باز سبز باشند.
- همهٔ تست‌های جدید فاز ۲۱ سبز باشند.

### گرپ‌های پذیرش (همه باید دقیقاً نتیجهٔ مورد انتظار بدهند)

```bash
# 1) هیچ SQL خامی روی cycle_periods در لایهٔ نمایش نماند
grep -rn "cycle_periods" lib/features/cycle/presentation/
# انتظار: خالی

# 2) ستون‌های فانتوم حذف شده باشند
grep -rn "periodDuration'\|'notes'\|suppressedPrayer\|fastDebtCreated" lib/features/cycle/
# انتظار: هیچ ارجاعی به عنوان ستون دیتابیس؛
#          cycle_logs قدیمی مجاز است چون واقعاً این ستون‌ها را دارد

# 3) گیت باروری کاملاً مرده باشد
grep -rn "cycle_fertility_visible\|isFertilityVisible\|keyFertilityVisible" lib/ test/
# انتظار: فقط یک مورد در فایل مهاجرت (DELETE FROM)

# 4) DDL دستی در تست‌های چرخه نماند
grep -rn "CREATE TABLE cycle_" test/cycle/
# انتظار: فقط test/cycle/helpers/cycle_test_db.dart یا هیچ

# 5) AUTOINCREMENT در هیچ تست چرخه‌ای نماند
grep -rn "AUTOINCREMENT" test/cycle/
# انتظار: خالی

# 6) callback خالی نماند
grep -rn "onOpenPasscodeSheet: () {}" lib/
# انتظار: خالی

# 7) default روی CyclePhase نماند
grep -rn -A2 "case CyclePhase.follicular" lib/features/cycle/ | grep "default"
# انتظار: خالی

# 8) مقدار پیش‌فرض خطرناک فاز نماند
grep -rn "?? CyclePhase.menstrual" lib/
# انتظار: خالی

# 9) دو فایل جدید واقعاً ساخته شده باشند
ls lib/features/cycle/presentation/widgets/cycle_anomaly_card.dart
ls lib/features/cycle/presentation/widgets/cycle_passcode_sheet.dart
ls lib/features/cycle/logic/cycle_period_contract.dart
ls lib/features/cycle/logic/cycle_period_status.dart
```

### تست دستی روی دستگاه (اجباری — تست واحد کافی نیست)

برنامه را با `flutter run` بالا بیاور و این هشت سناریو را عملاً طی کن. نتیجهٔ هر یک را در پیام کامیت نهایی یا توضیح PR بنویس:

1. دکمهٔ «شروع قاعدگی» را بزن → ردیف ساخته شود، اُرب به فاز قاعدگی برود، تقویم امروز را قرمز کند.
2. بلافاصله دوباره بزن → ردیف دوم ساخته **نشود**.
3. دکمهٔ «پایان قاعدگی» در روز ۱ → دیالوگ تأیید طول کوتاه نشان داده شود.
4. تقویم را باز کن → **پنجرهٔ باروری و روز تخمک‌گذاری دیده شوند** (باگ مورد اشارهٔ کاربر).
5. در تقویم روی یک روز گذشته بزن و «ثبت از این تاریخ» → دوره واقعاً ساخته شود (قبلاً بی‌صدا شکست می‌خورد).
6. تاریخ دستگاه را به بعد از روز پیش‌بینی‌شدهٔ شروع جلو ببر → پرسش تأیید شروع بیاید؛ پاسخ «هنوز نشده» بده → فردا **باز بپرسد**.
7. دورهٔ باز را ۱۴ روز رها کن → شیت «تاریخ واقعی پایان را بگو» بیاید، **نه** بستن خودکار.
8. تنزیمات → تغییر طول چرخه از ۲۸ به ۳۲ → پیش‌بینی‌ها فوری جابجا شوند (قبلاً هیچ کاری نمی‌کرد).

---

## فاز ۲۳ — کامیت، پوش و PR

یک کامیت پر فاز، دقیقاً با همان پیامی که در انتهای هر فاز نوشته شده. ترتیب کامیت‌ها:

```
fix(cycle): قرارداد واحد ستون‌های جدول دوره            (فاز 2)
fix(cycle): بازنویسی مدل CyclePeriod                      (فاز 3)
fix(cycle): بازنویسی کامل ریپازیتوری دوره              (فاز 4)
fix(cycle): حذف SQL خام از لایهٔ نمایش                 (فاز 5)
fix(cycle): منطق امن دکمه‌های شروع و پایان            (فاز 6)
fix(cycle): تک‌منبع وضعیت روز قاعدگی                   (فاز 7)
fix(cycle): حذف کامل گیت نمایش باروری               (فاز 8)
fix(cycle): اصلاح مارک‌ها و پنجرهٔ باروری تقویم       (فاز 9)
fix(cycle): بازنویسی منطق سرویس تأیید تعاملی          (فاز 10)
fix(cycle): پرسیدن تاریخ واقعی پایان دورهٔ فراموش‌شده (فاز 11)
fix(cycle): همگام‌سازی بدهی روزه برای همهٔ روزهای دوره (فاز 12)
fix(cycle): پیاده‌سازی شیت رمز و ویرایش پارامترهای پایه (فاز 13)
feat(cycle): رندر کارت ناهنجاری چرخه                  (فاز 14)
fix(cycle): احترام درگاه قفل به پرچم بیومتریک         (فاز 15)
fix(cycle): جامع‌سازی switch فازهای چرخه              (فاز 16)
fix(cycle): حذف هشدار تکراری دورهٔ فراموش‌شده        (فاز 17)
fix(cycle): اعتبارسنجی کامل و انتخاب شدت جریان در شیت دوره (فاز 18)
fix(cycle): یکی‌سازی آستانه‌ها و حالت‌های کارت پیش‌بینی (فاز 19)
perf(cycle): کش و برش محدودهٔ مارک‌های تقویم        (فاز 20)
test(cycle): فیکسچر مشترک و تست قرارداد اسکیما      (فاز 21)
```

سپس:

```bash
git push -u origin fix/cycle-round2-contract
```

و یک PR به `main` باز کن با عنوان:

```
fix(cycle): دور دوم — قرارداد اسکیما، تک‌مسیر نوشتن، و رفع ۴۱ باگ ماژول چرخه
```

در توضیح PR این چهار بخش را بنویس:
1. فهرست فازهای انجام‌شده
2. خروجی هر ۹ گرپ پذیرش فاز ۲۲
3. نتیجهٔ هر ۸ سناریوی تست دستی
4. مقایسهٔ تعداد خطای analyze و تعداد تست قبل/بعد

**پرامپت را به مخزن اضافه نکن.** هیچ فایل `.md` جدیدی کامیت نکن.

---

## چک‌لیست نهایی — قبل از اعلام اتمام علامت بزن

اگر هر یک از این‌ها علامت نخورد، کار تمام نشده:

- [ ] `CyclePeriodContract` ساخته شد و تنها مرجع نام ستون‌هاست
- [ ] `id` در مدل و ریپازیتوری `String` غیرنال است — هیچ `int?` باقی نمانده
- [ ] هیچ کدی ستون فانتوم را نمی‌خواند/نمی‌نویسد
- [ ] هیچ مهاجرتی برای افزودن ستون یا تغییر نوع `id` نوشته نشده
- [ ] `grep -rn "cycle_periods" lib/features/cycle/presentation/` خالی است
- [ ] `invalidate()` درون همهٔ متدهای نوشتنی ریپازیتوری صدا زده می‌شود
- [ ] دکمهٔ شروع/پایان debounce دارد و در `try/catch` است
- [ ] تنها یک منبع برای «امروز روز قاعدگی است؟» وجود دارد
- [ ] کلید `cycle_fertility_visible` از کد، seed، تست و دیتابیس پاک شد
- [ ] پنجرهٔ باروری و روز تخمک‌گذاری در تقویم واقعاً دیده می‌شوند
- [ ] پنجرهٔ باروری یک تعریف دارد (`fertileWindowFor`)، نه دو
- [ ] `maxAutoAsksPerCycle` واقعاً محدود می‌کند
- [ ] پاسخ «هنوز شروع نشده» روز بعد دوباره می‌پرسد
- [ ] `bleedingProlonged` قابل تعویق نیست
- [ ] دورهٔ فراموش‌شده دیگر تاریخ پایان جعل نمی‌کند
- [ ] بدهی روزه برای همهٔ روزهای دوره ساخته می‌شود و idempotent است
- [ ] شیت رمز و ویرایش پارامترهای پایه واقعاً کار می‌کنند
- [ ] کارت ناهنجاری رندر می‌شود
- [ ] درگاه قفل به `cycle_biometric_enabled` احترام می‌گذارد
- [ ] هیچ `default:` روی `CyclePhase` نمانده
- [ ] فقط یک کارت هشدار همزمان رندر می‌شود
- [ ] همهٔ تست‌های `test/cycle/` از `openCycleTestDb()` استفاده می‌کنند
- [ ] `test/cycle/cycle_schema_contract_test.dart` وجود دارد و سبز است
- [ ] `grep -rn "AUTOINCREMENT" test/cycle/` خالی است
- [ ] `flutter analyze` صفر خطا
- [ ] همهٔ تست‌ها سبز
- [ ] هر ۸ سناریوی تست دستی روی دستگاه طی شد و نتیجه گزارش شد
- [ ] برنش پوش شد و PR باز شد

---

## اگر جایی گیر کردی

در هر یک از این حالت‌ها، **حدس نزن و طرح جایگزین نساز**. متوقف شو، فازهای تمام‌شده را کامیت کن، و دقیقاً بنویس کدام فاز و کدام خط مشکل دارد:

- امضای واقعی یک متد با چیزی که این سند می‌گوید متفاوت است → **کد واقعی مقدم است**؛ همان را بکار ببر و در PR ذکر کن.
- دو لاگر را قاطی کردی و کمپایل نشد → یادآوری فاز ۰، قاعدهٔ دو لاگر را بخوان.
- یک تست قدیمی بعد از حذف گیت باروری قرمز شد → درست است؛ تست را بروز کن، کد را برنگردان.
- مطمئن نیستی یک ردیفِ موجودِ کاربر را می‌شود دست‌کاری کرد یا نه → **دست نزن**. حفظ دادهٔ کاربر از هر اصلاحی مهم‌تر است.

تمام.
