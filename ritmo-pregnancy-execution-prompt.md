# پرامپت اجرایی — تکمیل بخش بارداری ریتمو (آنبوردینگ اختصاصی + صفحهٔ تنظیمات)

**مخزن:** `nicedevil02/ritmo`
**کامیت پایه:** `22da22e82693d62e7f52d2c804334878323bf4e7`
**دفترچهٔ پیشرفت:** `docs/cycle/PREGNANCY_SETUP_PROGRESS.md`
**دامنهٔ شناسه‌ها:** PRG-01 تا PRG-50
**زبان رابط:** فارسی، راست‌به‌چپ

---

## بخش ۰ — قواعد اجرا (بیست قانون آهنین)

۱. **نقشه ننویس.** این فایل خودش نقشهٔ نهایی است. هیچ سند برنامه‌ریزی، هیچ فایل «plan» و هیچ خلاصهٔ معماری جدید تولید نکن. فقط تسک‌ها را به ترتیب اجرا کن.

۲. **ترتیب فازها اجباری است:** A → B → C → D → E → F → G → H → I → J. هیچ فازی را جلو نینداز. داخل هر فاز هم تسک‌ها به ترتیب شماره اجرا می‌شوند.

۳. **هر تسک یک کامیت.** پیام کامیت با شناسهٔ تسک شروع می‌شود، مثل `PRG-07: add gestational age calculator`.

۴. **بعد از هر تسک، دفترچه را به‌روز کن.** سطر همان تسک در `docs/cycle/PREGNANCY_SETUP_PROGRESS.md` را از `TODO` به `DONE` ببر و هش کامیت را بنویس. اگر تسکی را نتوانستی تمام کنی، `BLOCKED` بگذار و دلیل را در ستون یادداشت بنویس. هیچ تسکی را بی‌سروصدا رد نکن.

۵. **هیچ فایل موجودی را بازنویسی کامل نکن.** ویرایش هدفمند و کوچک انجام بده.

۶. **هیچ‌کدام از این فایل‌ها را دست نزن** مگر تسکی صریحاً بگوید: `labor_mode_screen.dart`، `kick_session_tracker.dart`، `weekly_share_card.dart`، `pregnancy_report.dart`، `pregnancy_week_data.dart`، `pregnancy_ring_painter.dart`.

۷. **هیچ داده‌ای پاک نمی‌شود** مگر تسک صریحاً بگوید. تاریخچهٔ چرخه، جداول بارداری و لاگ‌های روزانه در هیچ تسکی حذف نمی‌شوند به‌جز PRG-45.

۸. **کلیدهای موجود را تغییر نام نده.** `cycle_pregnancy_mode` و نام مستعارش `pregnancy_mode` و همچنین `cycle_is_pregnant` باید دقیقاً همان بمانند. کلیدهای تازه فقط اضافه می‌شوند.

۹. **هر نوشتن در `app_settings` باید از یک لایهٔ واحد بگذرد.** بعد از فاز A، هیچ `db.insert('app_settings', ...)` خامی برای کلیدهای `preg_*` نباید در فایل‌های UI باقی بماند.

۱۰. **ساعت و تاریخ:** همیشه `CycleClock.now` و `CycleClock.nowMillisecondsSinceEpoch`. هرگز `DateTime.now()`.

۱۱. **تاریخ‌ها:** برای تبدیل و کلید روز فقط `CycleDateContract.toDayKey` و `CycleDateContract.parseDayKey` و `CycleDateContract.cleanDate`. برای انتخاب تاریخ فقط `RitmoDatePicker.showJalali`. هیچ تاریخ‌گزین تازه‌ای نساز.

۱۲. **اعداد:** هر عدد فارسی که به کاربر نشان داده می‌شود از `PersianDigits.toFa` یا `RitmoNumber.fa` می‌گذرد.

۱۳. **رنگ و فاصله:** فقط `context.colors` و توکن‌های `RitmoSpacing` و `RitmoRadius`. هیچ رنگ هارد‌کد شده‌ای اضافه نکن.

۱۴. **لاگ:** در فایل‌های چرخه از `RitmoLogger.error(message, error: e, stack: st)` استفاده کن. توجه: در `cycle_screen.dart` امضای دیگری (`RitmoLog.error`) هم استفاده شده؛ در هر فایل همان الگویی را که در بالای فایل import شده ادامه بده و import تازه اضافه نکن.

۱۵. **هیچ اطلاعات بارداری در لاگ ننویس.** نه تاریخ زایمان، نه هفته، نه علائم. فقط شناسهٔ رویداد.

۱۶. **تست:** هر تسکی که فیلد «تست» دارد باید فایل تستش ساخته یا به‌روز شود و `flutter test` سبز باشد. تست‌های بارداری در `test/cycle/pregnancy/` قرار می‌گیرند (این پوشه را در PRG-01 بساز). تست‌های آنبوردینگ در `test/onboarding/` که از قبل وجود دارد.

۱۷. **قبل از هر تسک، فایل‌های فهرست‌شدهٔ آن تسک را کامل بخوان.** امضا حدس نزن.

۱۸. **`flutter analyze` باید بدون خطا و بدون هشدار جدید باشد** پیش از هر کامیت.

۱۹. **هیچ وابستگی تازه‌ای به `pubspec.yaml` اضافه نکن.**

۲۰. **در پایان هر فاز یک بار کل تست‌ها را اجرا کن.** اگر تستی که قبلاً سبز بود شکست، همان‌جا درستش کن و در فاز بعد نرو.

### قالب اجباری هر تسک

هر تسک را با همین شش سرفصل جلو ببر:

```
**باگ:** چه چیزی الان خراب یا ناقص است
**فایل‌ها:** مسیرهای دقیق
**کار دقیق:** چه بنویس و چه عوض کن
**معیار پذیرش:** چه چیزی باید قابل مشاهده یا قابل اثبات باشد
**تست:** نام فایل تست
**commit:** پیام کامیت
```

---

## بخش ۱ — وضعیت فعلی (شواهد، نه حدس)

این بخش را قبل از شروع بخوان تا بدانی چه چیزی هست و چه چیزی نیست.

### چه چیزی سالم است و نباید دست بخورد

| فایل | اندازه | وضعیت |
|---|---|---|
| `lib/features/cycle/presentation/widgets/cycle_pregnancy_mode.dart` | 20102 | صفحهٔ اصلی بارداری با پنج تب. سالم |
| `lib/features/cycle/presentation/widgets/pregnancy/pregnancy_header.dart` | 9787 | هدر. فقط اتصال دکمه‌اش غلط است |
| `lib/features/cycle/presentation/widgets/pregnancy/pregnancy_progress_tab.dart` | 19257 | تب پیشرفت. سالم |
| `lib/features/cycle/presentation/widgets/pregnancy/pregnancy_tabs.dart` | 8158 | نوار تب. سالم |
| `lib/features/cycle/presentation/widgets/pregnancy/pregnancy_ring_painter.dart` | 1302 | حلقهٔ پیشرفت. سالم |
| `lib/features/cycle/presentation/widgets/pregnancy_today_card.dart` | 8621 | کارت امروز. سالم |
| `lib/features/cycle/presentation/widgets/kick_session_tracker.dart` | 6962 | لگدشماری. سالم |
| `lib/features/cycle/presentation/widgets/labor_mode_screen.dart` | 21314 | حالت زایمان. سالم |
| `lib/features/cycle/presentation/widgets/weekly_share_card.dart` | 11620 | کارت اشتراک. سالم |
| `lib/features/health/data/pregnancy_repository.dart` | 8013 | مخزن داده. سالم |
| `lib/features/health/data/pregnancy_helpers.dart` | 4091 | `GestationalAge` و `formatHumanCountdown`. سالم |
| `lib/features/health/data/pregnancy_week_data.dart` | 5908 | داده هفته‌به‌هفته. سالم |
| `lib/features/health/presentation/widgets/pregnancy_report.dart` | — | گزارش پزشک. سالم |

### شش ریشهٔ خرابی

| # | ریشه | محل اثبات | تسک‌های بستن |
|---|---|---|---|
| P-A | دکمهٔ «فعالسازی حالت بارداری» فقط یک پرچم بولی را وارونه می‌کند. هیچ ورودی، تأیید یا آنبوردینگی ندارد | `cycle_screen.dart` داخل `_openSettingsSheet` در پارامتر `onTogglePregnancyMode` | PRG-25 تا PRG-29 |
| P-B | `preg_start_date` و `preg_due_date` هیچ‌جای مخزن نوشته نمی‌شوند، پس همیشه به `CycleClock.now` و `now + 280` سقوط می‌کنند و همه در «هفتهٔ صفر» می‌مانند | `cycle_screen.dart` در ساخت `CyclePregnancyModeView` | PRG-01 تا PRG-06، PRG-24 |
| P-C | آنبوردینگ اختصاصی بارداری هرگز ساخته نشده. `onNavigateToPregnancy` در هر دو محل فراخوانی دقیقاً کپی `onCompleted` است | `cycle_screen.dart` و `cycle_settings_panel.dart` | PRG-12 تا PRG-24 |
| P-D | صفحهٔ تنظیمات بارداری وجود ندارد. دکمهٔ سه‌نقطه با tooltip «تنظیمات بارداری» به `_showEndPregnancySheet` وصل است | `pregnancy_header.dart` پارامتر `onShowSettings` و اتصالش در `cycle_pregnancy_mode.dart` | PRG-30 تا PRG-37 |
| P-E | کلیدهای `preg_tone` و `preg_edd_source` خوانده می‌شوند ولی هیچ‌جا نوشته نمی‌شوند. کلیدهای `preg_section_hidden` و `preg_cycle_resume_reminder` نوشته می‌شوند ولی هیچ‌جا خوانده نمی‌شوند | `cycle_pregnancy_mode.dart` | PRG-38 تا PRG-42 |
| P-F | فعال‌شدن بارداری، پیش‌بینی‌ها و یادآوری‌های پریود را متوقف نمی‌کند و دورهٔ باز را نمی‌بندد | `cycle_onboarding_controller.dart` و `cycle_screen.dart` | PRG-21، PRG-27 |

### قرارداد نام‌گذاری تازه

همهٔ کلیدهای تازه با `preg_` شروع می‌شوند و در `PregnancySettings` متمرکز هستند. هیچ کلید تازه‌ای در `CycleSettings` اضافه نمی‌شود؛ `CycleSettings` فقط مالک `cycle_pregnancy_mode` می‌ماند.

---

## فاز A — قرارداد داده و لایهٔ تنظیمات (PRG-01 تا PRG-06)

هدف فاز: یک منبع حقیقت برای همهٔ دادهٔ بارداری بساز تا دیگر هیچ فایل UI مستقیماً در `app_settings` ننویسد.

### PRG-01

**باگ:** پوشهٔ تست بارداری وجود ندارد و دفترچهٔ پیشرفت هم نیست.
**فایل‌ها:** `docs/cycle/PREGNANCY_SETUP_PROGRESS.md` (جدید)، `test/cycle/pregnancy/.gitkeep` (جدید)
**کار دقیق:** پوشهٔ `docs/cycle/` را اگر نیست بساز. دفترچه را با همان جدول ۵۰ سطری که در پایان این فایل آمده ایجاد کن، همه با وضعیت `TODO`. پوشهٔ تست را بساز.
**معیار پذیرش:** دفترچه در مخزن موجود است و دقیقاً ۵۰ سطر داده دارد.
**تست:** —
**commit:** `PRG-01: add pregnancy setup ledger and test folder`

### PRG-02

**باگ:** هیچ مدلی برای تنطیمات بارداری وجود ندارد. مقدارها به شکل رشتهٔ خام از `Map<String, String>` خوانده می‌شوند.
**فایل‌ها:** `lib/features/cycle/models/pregnancy_models.dart` (جدید)
**کار دقیق:** سه چیز بساز:

۱. `enum PregnancyEddSource { lmp, ultrasound, doctorEdd }` با دو عضو کمکی `String get storageValue` که به ترتیب `'lmp'`، `'ultrasound'`، `'doctor_edd'` برمی‌گرداند، و `static PregnancyEddSource fromStorage(String? raw)` که پیش‌فرضش `lmp` است. توجه: کد فعلی در `pregnancy_header.dart` فقط برای مقدار `'ultrasound'` نشان می‌سازد، پس `doctor_edd` هم باید در PRG-33 نشان بگیرد.
۲. `enum PregnancyTone { warm, neutral }` با `storageValue` معادل `'warm'` و `'neutral'` و `fromStorage` با پیش‌فرض `warm`.
۳. `enum PregnancyAgeUnit { weeks, months }` با `storageValue` معادل `'weeks'` و `'months'` و پیش‌فرض `weeks`.
۴. کلاس تغییرناپذیر `PregnancyProfile` با فیلدهای: `DateTime lmpDate`، `DateTime dueDate`، `PregnancyEddSource eddSource`، `PregnancyTone tone`، `PregnancyAgeUnit ageUnit`، `bool isMultiple`، `bool isHighRisk`، `bool sectionHidden`، `bool maskNotifications`، `bool lockEnabled`، `bool cycleResumeReminder`، `int kickTargetCount`، `int kickWindowMinutes`، `bool kickBaselineComparison`، `int visitReminderLeadDays`، `int reminderHour`. متدهای `copyWith`، `toMap()` که `Map<String, String>` برمی‌گرداند با همان کلیدهای PRG-03، و `factory PregnancyProfile.fromMap(Map<String, String> map)` که هر مقدار غایب را با پیش‌فرض پر می‌کند.
پیش‌فرض‌ها را به شکل `static const` در همین فایل بگذار: `defaultKickTargetCount = 10`، `defaultKickWindowMinutes = 120`، `defaultVisitReminderLeadDays = 2`، `defaultReminderHour = 10`، `gestationTotalDays = 280`، `maxGestationDays = 300`، `minGestationDays = 0`.
**معیار پذیرش:** `PregnancyProfile.fromMap({})` بدون پرتاب خطا یک پروفایل با پیش‌فرض‌های بالا می‌دهد. `toMap()` و `fromMap()` رفت و برگشت کامل دارند.
**تست:** `test/cycle/pregnancy/pregnancy_profile_roundtrip_test.dart`
**commit:** `PRG-02: add PregnancyProfile model and enums`

### PRG-03

**باگ:** نوشتن در `app_settings` پراکنده است و هر فایل UI مستقیم `db.insert` می‌زند. هیچ فاسادی برای کلیدهای `preg_*` وجود ندارد.
**فایل‌ها:** `lib/features/cycle/logic/pregnancy_settings.dart` (جدید)، مرجع الگو: `lib/features/cycle/logic/cycle_settings.dart`
**کار دقیق:** کلاس `PregnancySettings` را دقیقاً با همان الگوی `CycleSettings` بساز: متدهای ایستا، خواندن از `Map<String, dynamic>`، نوشتن با `DatabaseExecutor?` اختیاری، همان `_saveSetting` و `_deleteSetting` خصوصی با `ConflictAlgorithm.replace` و `CycleClock.nowMillisecondsSinceEpoch` و try/catch با لاگ.

کلیدهای دقیق (همین‌ها و نه چیز دیگر):

```
keyStartDate            = 'preg_start_date'
keyDueDate              = 'preg_due_date'
keyEddSource            = 'preg_edd_source'
keyTone                 = 'preg_tone'
keyAgeUnit              = 'preg_age_unit'
keyIsMultiple           = 'preg_is_multiple'
keyIsHighRisk           = 'preg_is_high_risk'
keySectionHidden        = 'preg_section_hidden'
keyMaskNotifications    = 'preg_mask_notifications'
keyLockEnabled          = 'preg_lock_enabled'
keyCycleResumeReminder  = 'preg_cycle_resume_reminder'
keyKickTargetCount      = 'preg_kick_target_count'
keyKickWindowMinutes    = 'preg_kick_window_minutes'
keyKickBaselineCompare  = 'preg_kick_baseline_compare'
keyVisitReminderLead    = 'preg_visit_reminder_lead_days'
keyReminderHour         = 'preg_reminder_hour'
keySetupDone            = 'preg_setup_done'
```

متدهای لازم: `loadProfile(Map<String, dynamic> settings)` که `PregnancyProfile` می‌دهد؛ `saveProfile(PregnancyProfile profile, [DatabaseExecutor? db])` که همه را در یک batch می‌نویسد؛ `isSetupDone(Map<String, dynamic>)`؛ `clearAll([DatabaseExecutor? db])` که همهٔ کلیدهای بالا را حذف می‌کند.
مقدارهای بولی دقیقاً به شکل `'true'` و `'false'` ذخیره می‌شوند (همان قرارداد `CycleSettings`). مقدارهای تاریخ با `CycleDateContract.toDayKey`.
در `saveProfile` پس از commit باید `CycleEngine().invalidate()` صدا زده شود.
**معیار پذیرش:** نوشتن و خواندن یک پروفایل کامل روی یک دیتابیس حقیقی بدون تلفات داده کار می‌کند. `clearAll` هیچ کلید `preg_*` باقی نمی‌گذارد.
**تست:** `test/cycle/pregnancy/pregnancy_settings_persistence_test.dart`
**commit:** `PRG-03: add PregnancySettings facade`

### PRG-04

**باگ:** دو جای مختلف پرچم بارداری را می‌نویسند و هر دو مجموعهٔ متفاوتی از کلیدها را دست می‌زنند. `cycle_screen.dart` فقط `cycle_pregnancy_mode` می‌نویسد، اما `cycle_onboarding_controller.dart` سه کلید `cycle_pregnancy_mode` و `pregnancy_mode` و `cycle_is_pregnant` را می‌نویسد. پس حالت ناسازگار ممکن است.
**فایل‌ها:** `lib/features/cycle/logic/pregnancy_settings.dart`
**کار دقیق:** یک متد ایستای واحد اضافه کن:
`static Future<void> setPregnancyActive(bool active, {required DatabaseExecutor db})`.
این متد باید هر سه کلید `cycle_pregnancy_mode` و `pregnancy_mode` و `cycle_is_pregnant` را همزمان با همان مقدار بنویسد، سپس `CycleEngine().invalidate()` را صدا بزند. این یگانه مسیر مجاز برای روشن یا خاموش کردن بارداری در کل برنامه می‌شود.
**معیار پذیرش:** تست نشان می‌دهد که پس از یک فراخوانی، هر سه کلید مقدار یکسان دارند.
**تست:** `test/cycle/pregnancy/pregnancy_flag_single_writer_test.dart`
**commit:** `PRG-04: unify pregnancy flag writes behind one setter`

### PRG-05

**باگ:** هیچ محافظی وجود ندارد که مانع حالت نیمه‌فعال شود: پرچم روشن ولی تاریخ خالی. همین باعث ریشهٔ P-B است.
**فایل‌ها:** `lib/features/cycle/logic/pregnancy_settings.dart`
**کار دقیق:** دو متد ایستا اضافه کن:
۱. `static bool hasValidDates(Map<String, dynamic> settings)` که تروه می‌شود فقط وقتی هر دو `preg_start_date` و `preg_due_date` حاضر و قابل پارس باشند و فاصلهٔ روزانه‌شان بین ۲۰۰ تا ۳۲۰ روز باشد.
۲. `static bool isPregnancyUsable(Map<String, dynamic> settings)` که معادل `CycleSettings.isPregnancyMode(settings) && hasValidDates(settings)` است.
**معیار پذیرش:** با پرچم روشن و تاریخ خالی، `isPregnancyUsable` فالس می‌دهد.
**تست:** `test/cycle/pregnancy/pregnancy_usable_guard_test.dart`
**commit:** `PRG-05: add pregnancy date validity guard`

### PRG-06

**باگ:** در `cycle_settings_panel.dart` متد `_updateSetting` مستقیم `db.insert('app_settings', ...)` می‌زند و در `cycle_screen.dart` هم دو جای دیگر همین کار تکرار شده.
**فایل‌ها:** `lib/features/cycle/presentation/cycle_screen.dart`
**کار دقیق:** فقط آن دو نوشتنی که مربوط به بارداری هستند را عوض کن: یکی داخل `onTogglePregnancyMode` و یکی داخل `onDeactivated` در ساخت `CyclePregnancyModeView`. هر دو باید به `PregnancySettings.setPregnancyActive(...)` تبدیل شوند. توجه مهم: نوشتن داخل `onDeactivated` حتی `updatedAt` هم نمی‌نویسد، پس این خودش یک باگ جداگانه است که همین‌جا بسته می‌شود. بقیهٔ نوشتن‌های این فایل (مانند `cycle_send_fasting_debt_to_worship`) را دست نزن.
**معیار پذیرش:** جستجوی `cycle_pregnancy_mode` در `lib/features/cycle/presentation/` هیچ `db.insert` خامی برای این کلید برنمی‌گرداند.
**تست:** `test/cycle/pregnancy/no_raw_pregnancy_writes_test.dart` — این تست متن فایل‌های `lib/features/cycle/presentation/` را می‌خواند و اطمینان می‌دهد هیچ فایلی همزمان `app_settings` و `pregnancy` را در یک فراخوانی insert ندارد.
**commit:** `PRG-06: route pregnancy flag writes through facade`

---

## فاز B — موتور محاسبهٔ سن بارداری (PRG-07 تا PRG-11)

هدف فاز: محاسبهٔ تاریخ زایمان و سن بارداری را در یک جای قابل تست جمع کن، تا هیچ صفحه‌ای خودش حساب نکند.

### PRG-07

**باگ:** محاسبهٔ هفته و روز در چند فایل تکرار شده و هیچ تابع مرکزی برای تبدیل مبنای تاریخ وجود ندارد.
**فایل‌ها:** `lib/features/cycle/logic/pregnancy_date_engine.dart` (جدید)، مرجع خواندن: `lib/features/health/data/pregnancy_helpers.dart`
**کار دقیق:** اول `pregnancy_helpers.dart` را کامل بخوان تا بفهمی `GestationalAge` چه امضایی دارد. بعد کلاس `PregnancyDateEngine` با متدهای ایستای خالص بساز:

- `static DateTime dueDateFromLmp(DateTime lmp)` که `lmp + 280 روز` می‌دهد.
- `static DateTime lmpFromDueDate(DateTime due)` که `due - 280 روز` می‌دهد.
- `static DateTime lmpFromUltrasound({required DateTime scanDate, required int weeksAtScan, required int daysAtScan})` که `scanDate - (weeksAtScan * 7 + daysAtScan)` می‌دهد.
- `static GestationalAge ageAt({required DateTime lmp, required DateTime now})` که اختلاف روز را بر ۷ تقسیم می‌کند و باقیمانده را روز می‌گیرد.
- `static int remainingDays({required DateTime due, required DateTime now})` که هرگز عدد منفی برنمی‌گرداند و در صورت گذشت موعد صفر می‌دهد.
- `static int trimesterOf(GestationalAge age)` که هفتهٔ ۱ تا ۱۳ را ۱، ۱۴ تا ۲۷ را ۲ و ۲۸ به بالا را ۳ می‌دهد.
همهٔ محاسبات روی تاریخ پاک‌شده با `CycleDateContract.cleanDate` انجام می‌شود تا ساعت در محاسبه دخالت نکند.
**معیار پذیرش:** برای یک LMP مشخص، رفت و برگشت `dueDateFromLmp` و `lmpFromDueDate` همان تاریخ را می‌دهد. برای سونوگرافی در هفتهٔ ۲۰ و ۳ روز، سن محاسبه‌شده در همان روز دقیقاً ۲۰ و ۳ است.
**تست:** `test/cycle/pregnancy/pregnancy_date_engine_test.dart`
**commit:** `PRG-07: add PregnancyDateEngine`

### PRG-08

**باگ:** هیچ اعتبارسنجی وجود ندارد؛ کاربر می‌تواند تاریخی وارد کند که به هفتهٔ ۵۰ یا منفی برسد.
**فایل‌ها:** `lib/features/cycle/logic/pregnancy_date_engine.dart`
**کار دقیق:** یک کلاس نتیجه بساز: `class PregnancyDateValidation { final bool isValid; final String? messageFa; }` و متد `static PregnancyDateValidation validate({required DateTime lmp, required DateTime now})`.
قواعد دقیق رد:
- اگر LMP در آینده باشد: «تاریخ واردشده در آینده است. یک بار دیگر بررسی کن.»
- اگر فاصله بیش از ۲۹۴ روز باشد (۴۲ هفته): «این تاریخ بیش از ۴۲ هفته فاصله دارد و با بازهٔ بارداری هم‌خوان نیست.»
- در غیر این دو حالت: معتبر.
**معیار پذیرش:** هر سه مسیر در تست پوشش دارند و پیام فارسی دقیقاً همین‌هایی است که بالا نوشته شده.
**تست:** `test/cycle/pregnancy/pregnancy_date_validation_test.dart`
**commit:** `PRG-08: add pregnancy date validation with Persian messages`

### PRG-09

**باگ:** واحد نمایش سن فقط «هفته + روز» است در حالی که مادرها در فارسی معمولاً ماه می‌گویند.
**فایل‌ها:** `lib/features/cycle/logic/pregnancy_date_engine.dart`
**کار دقیق:** متد `static String formatAgeFa(GestationalAge age, PregnancyAgeUnit unit)` بساز. برای `weeks` خروجی مثل «هفته ۲۴ و ۳ روز»؛ برای `months` ماه را از تقسیم هفته بر ۴ به‌علاوهٔ باقیماندهٔ هفته بساز، مانند «ماه ۶ و ۲ هفته». همهٔ اعداد از `PersianDigits.toFa` بگذرند.
**معیار پذیرش:** هر دو واحد خروجی فارسی درست بدون رقم لاتین می‌دهند.
**تست:** `test/cycle/pregnancy/pregnancy_age_format_test.dart`
**commit:** `PRG-09: add gestational age formatting in weeks and months`

### PRG-10

**باگ:** هیچ جایی نمی‌داند که با تغییر تاریخ زایمان، تایم‌لاین مراقبت‌ها و کارت‌های هفتگی جابه‌جا می‌شوند.
**فایل‌ها:** `lib/features/cycle/logic/pregnancy_date_engine.dart`، خواندن مرجع: `lib/features/health/data/pregnancy_repository.dart`
**کار دقیق:** متد `static int dayShiftBetween({required DateTime oldLmp, required DateTime newLmp})` بساز که اختلاف روز با علامت می‌دهد. این عدد در PRG-31 برای نشان دادن هشدار به کاربر لازم می‌شود. در این تسک هیچ داده‌ای جابه‌جا نمی‌شود؛ فقط محاسبه.
**معیار پذیرش:** برای دو تاریخ با پنج روز اختلاف، خروجی دقیقاً پنج یا منفی پنج است.
**تست:** `test/cycle/pregnancy/pregnancy_date_shift_test.dart`
**commit:** `PRG-10: add due date shift calculator`

### PRG-11

**باگ:** `cycle_screen.dart` خودش تاریخ را از `_settings` می‌خواند و به `CyclePregnancyModeView` به شکل رشته می‌دهد، با همان سقوط خطرناک به `CycleClock.now`.
**فایل‌ها:** `lib/features/cycle/presentation/cycle_screen.dart`
**کار دقیق:** در محل ساخت `CyclePregnancyModeView`، دو مقدار `pregnancyStartDate` و `pregnancyDueDate` را دیگر با عملگر `??` به امروز نرسان. جایش این کار را بکن:
اگر `PregnancySettings.isPregnancyUsable(_settings)` فالس بود، به‌جای `CyclePregnancyModeView` یک حالت ترمیم نشان بده: یک `RitmoEmptyState` با عنوان «تاریخ بارداری ثبت نشده»، توضیح «برای محاسبهٔ هفتهٔ بارداری و مراقبت‌ها، لازم است یک بار تاریخ را وارد کنی.» و دکمهٔ «تکمیل راه‌اندازی بارداری» که همان آنبوردینگ فاز C را باز می‌کند (در این تسک دکمه را موقتاً غیرفعال بگذار و در PRG-17 وصل کن).
وقتی قابل استفاده بود، تاریخ‌ها را از `PregnancySettings.loadProfile(_settings)` بگیر.
**معیار پذیرش:** دیگر هیچ حالتی وجود ندارد که کاربر در هفتهٔ صفر با دویست و هشتاد روز مانده قرار بگیرد.
**تست:** `test/cycle/pregnancy/no_week_zero_fallback_test.dart`
**commit:** `PRG-11: remove today fallback for pregnancy dates`

---

## فاز C — پوسته و ناوبری آنبوردینگ بارداری (PRG-12 تا PRG-17)

هدف فاز: مقصدی که سه سال است قلابش هست و خودش نیست را بساز.

### PRG-12

**باگ:** هیچ کنترلری برای آنبوردینگ بارداری وجود ندارد.
**فایل‌ها:** `lib/features/cycle/logic/pregnancy_onboarding_controller.dart` (جدید)، مرجع الگو: `lib/features/cycle/logic/cycle_onboarding_controller.dart`
**کار دقیق:** اول کنترلر چرخه را کامل بخوان. بعد بساز:
- `class PregnancyOnboardingData` با فیلدهای قابل تغییر: `PregnancyTone tone`، `PregnancyEddSource eddSource`، `DateTime? lmpDate`، `DateTime? dueDate`، `DateTime? scanDate`، `int scanWeeks`، `int scanDays`، `bool isMultiple`، `bool isHighRisk`، `bool pauseCyclePredictions`، `bool suspendWorship`، `bool lockEnabled`، `bool hideFromDashboard`، `bool maskNotifications`، `PregnancyAgeUnit ageUnit`. با `copyWith`.
- `PregnancyOnboardingController.instance` به سبک سینگلتون خصوصی مشابه همان فایل.
- `Future<PregnancyOnboardingData> loadInitialData()` که اگر پروفایل قبلی هست مقدارها را پر می‌کند (حالت ویرایش) و در غیر این صورت پیش‌فرض‌ها را می‌دهد. پیش‌فرض `lockEnabled` برابر `CycleSettings.isLockEnabled(settings)` و پیش‌فرض `hideFromDashboard` و `maskNotifications` ترو باشند.
- در این تسک فقط خواندن؛ ذخیره‌سازی در PRG-21 می‌آید.
**معیار پذیرش:** `loadInitialData()` روی دیتابیس خالی بدون خطا پیش‌فرض برمی‌گرداند.
**تست:** `test/cycle/pregnancy/pregnancy_onboarding_controller_test.dart`
**commit:** `PRG-12: add pregnancy onboarding controller and data`

### PRG-13

**باگ:** هیچ پوسته‌ای برای گام‌های آنبوردینگ بارداری وجود ندارد.
**فایل‌ها:** `lib/features/cycle/presentation/onboarding/pregnancy_onboarding_shell.dart` (جدید)، مرجع الگو: `lib/features/cycle/presentation/onboarding/cycle_onboarding_shell.dart`
**کار دقیق:** پوسته را دقیقاً با همان الگوی `CycleOnboardingShell` بساز، ولی با پنج گام بارداری. عیناً این اجزا باید تکرار شوند:
- `_isLoadingInitial` و `_isSaving` و `_errorMessage` با همان منطق.
- صفحهٔ خطای اختصاصی با دکمهٔ «تلاش مجدد» (همان الگوی Bug چ-۲).
- `PopScope` با `canPop: false` و بازگشت گام‌به‌گام.
- دیالوگ تأیید خروج با متن «اگر الان خارج شوی، حالت بارداری فعال نمی‌شود و اطلاعات واردشده ذخیره نمی‌شوند.» دکمه‌ها: «ادامه می‌دهم» و «خروج».
- هدر پیشرفت با متن `'گام X از ۵'` و نوار پنج‌قطعه‌ای، دقیقاً با همان `RitmoNumber.fa`.
- عنوان هدر: در حالت عادی «راه‌اندازی بارداری» و در حالت ویرایش «بازبینی راه‌اندازی بارداری».
پارامترهای ویجت: `required VoidCallback onCompleted`، `required VoidCallback onCancelled`، `bool isEditMode = false`.
**معیار پذیرش:** ویجت بدون خطا رندر می‌شود و نوار پیشرفت پنج قطعه دارد.
**تست:** `test/cycle/pregnancy/pregnancy_onboarding_shell_test.dart`
**commit:** `PRG-13: add pregnancy onboarding shell with five steps`

---

### PRG-14

**باگ:** دکمهٔ «الان باردارم» در گام ۲ آنبوردینگ چرخه به یک کالبک پوچ وصل است. در `cycle_screen.dart` و `cycle_settings_panel.dart` مقدار `onNavigateToPregnancy` دقیقاً همان دو خط `Navigator.pop(ctx); _loadData();` است که در `onCompleted` هم هست.
**فایل‌ها:** `lib/features/cycle/presentation/cycle_screen.dart`
**کار دقیق:** در `cycle_screen.dart` دو محل وجود دارد که `CycleOnboardingShell` ساخته می‌شود: یکی در `RitmoEmptyState` در مسیر «دوره‌ای ثبت نشده». در همان محل، `onNavigateToPregnancy` را به یک متد تازه به نام `_openPregnancyOnboarding()` وصل کن که اول شیت فعلی را می‌بندد و بعد `PregnancyOnboardingShell` را در یک `showModalBottomSheet` با `isScrollControlled: true` و `backgroundColor: Colors.transparent` باز می‌کند.
در `onCompleted` آن شیت، `_loadData()` را صدا بزن. در `onCancelled` فقط شیت را ببند و هیچ پرچمی را عوض نکن.
**معیار پذیرش:** فشردن «الان باردارم» در گام ۲ آنبوردینگ چرخه، آنبوردینگ بارداری را باز می‌کند. دیگر هیچ مسیری وجود ندارد که این دکمه فقط شیت را ببندد.
**تست:** `test/onboarding/pregnancy_branch_opens_onboarding_test.dart`
**commit:** `PRG-14: wire pregnancy branch in cycle screen`

### PRG-15

**باگ:** همان کالبک پوچ در پنل تنطیمات چرخه هم تکرار شده.
**فایل‌ها:** `lib/features/cycle/presentation/widgets/cycle_settings_panel.dart`
**کار دقیق:** در دکمهٔ «ویرایش و بازبینی راه‌اندازی چرخه»، مقدار `onNavigateToPregnancy` در `CycleOnboardingShell` را عوض کن. چون این ویجت به `cycle_screen` دسترسی ندارد، یک پارامتر تازه به `CycleSettingsPanel` اضافه کن: `required VoidCallback onOpenPregnancyOnboarding` و همان را از `cycle_screen.dart` به متد `_openPregnancyOnboarding` وصل کن.
توجه: این پارامتر اجباری است، پس هر محل دیگری که `CycleSettingsPanel` را می‌سازد هم باید به‌روز شود. اول با جستجو مطمئن شو چند جا است.
**معیار پذیرش:** پروژه کمپایل می‌شود و هر دو مسیر به همان آنبوردینگ می‌روند.
**تست:** —
**commit:** `PRG-15: wire pregnancy onboarding from cycle settings panel`

### PRG-16

**باگ:** برخی از کاربران از مسیر خالیٔ چرخه وارد می‌شوند و مسیر بارداری را نمی‌بینند، چون دکمه داخل گام ۲ پنهان است.
**فایل‌ها:** `lib/features/cycle/presentation/cycle_screen.dart`
**کار دقیق:** در همان `RitmoEmptyState` مسیر خالی چرخه، یک مسیر ثانویه زیر دکمهٔ اصلی اضافه کن: یک `TextButton` با متن «باردارم — مستقیم برو به راه‌اندازی بارداری» که `_openPregnancyOnboarding()` را صدا می‌زند.
اگر `RitmoEmptyState` امکان دومین دکمه را ندارد، فایل `lib/core/ux/ritmo_empty_state.dart` را بخوان و اگر پارامتر اختیاری مناسبی ندارد، کل مجموعه را در یک `Column` بپیچ و دکمه را زیرش بگذار. ویجت مشترک `RitmoEmptyState` را برای این کار تغییر نده.
**معیار پذیرش:** در نصب تازه، دو مسیر قابل دیدن است: راه‌اندازی چرخه و راه‌اندازی بارداری.
**تست:** `test/cycle/pregnancy/empty_state_has_pregnancy_path_test.dart`
**commit:** `PRG-16: add direct pregnancy entry from cycle empty state`

### PRG-17

**باگ:** دکمهٔ ترمیم در PRG-11 غیرفعال گذاشته شد.
**فایل‌ها:** `lib/features/cycle/presentation/cycle_screen.dart`
**کار دقیق:** دکمهٔ «تکمیل راه‌اندازی بارداری» را به `_openPregnancyOnboarding()` وصل کن.
**معیار پذیرش:** کاربری که پرچمش روشن ولی تاریخش خالی است می‌تواند با یک فشار وضعیت را درست کند.
**تست:** —
**commit:** `PRG-17: wire pregnancy repair CTA`

---

## فاز D — پنج گام آنبوردینگ (PRG-18 تا PRG-24)

هدف فاز: گام‌ها را بساز و ذخیره‌سازی اتمی را تمام کن.

### PRG-18

**باگ:** گام لحن وجود ندارد و `preg_tone` هیچ راه نوشتنی ندارد.
**فایل‌ها:** `lib/features/cycle/presentation/onboarding/pregnancy_steps/preg_step_1_tone.dart` (جدید)
**کار دقیق:** یک گام ساده بساز با همان امضای گام‌های چرخه: `data`، `onDataChanged`، `onNext`، `colors`، `isDark`.
محتوا: تیتر «قراره کنارت باشیم تا روز تولد»، زیرعنوان «هر چیزی که وارد می‌کنی فقط روی همین گوشی می‌ماند.»
دو کارت انتخابی با همان الگوی `_buildStatusOptionCard` در `step_2_cycle_status.dart` (همان `AnimatedContainer` و همان حاشیه و همان آیکن تیک وقتی انتخاب شده):
- «گرم و صمیمی» با توضیح «پیام‌ها دلگرم‌کننده و همراه با ایموجی» معادل `PregnancyTone.warm`
- «آرام و ساده» با توضیح «فقط اطلاعات، بدون ایموجی و تبریک» معادل `PregnancyTone.neutral`
دکمهٔ پایین: «مرحله بعد».
**معیار پذیرش:** انتخاب لحن در `data.tone` می‌نشیند و کارت انتخاب‌شده حاشیهٔ پررنگ دارد.
**تست:** `test/cycle/pregnancy/preg_step_tone_test.dart`
**commit:** `PRG-18: add pregnancy onboarding step 1 tone`

### PRG-19

**باگ:** مبنای تاریخ هیچ ورودی ندارد. این مهم‌ترین گام است و ریشهٔ P-B را می‌بندد.
**فایل‌ها:** `lib/features/cycle/presentation/onboarding/pregnancy_steps/preg_step_2_dates.dart` (جدید)
**کار دقیق:** سه مسیر با همان الگوی کارت انتخابی:
۱. «اولین روز آخرین پریودم را می‌دانم» → یک تاریخ‌گزین؛ `lmpDate` مستقیم و `dueDate` از `PregnancyDateEngine.dueDateFromLmp`.
۲. «تاریخ زایمان را پزشک گفته» → تاریخ‌گزین؛ `dueDate` مستقیم و `lmpDate` از `lmpFromDueDate`.
۳. «جواب سونوگرافی دارم» → یک تاریخ‌گزین برای تاریخ سونو به‌علاوهٔ دو انتخابگر عددی برای هفته (بازهٔ ۴ تا ۴۲) و روز (بازهٔ ۰ تا ۶)؛ `lmpDate` از `lmpFromUltrasound` و `dueDate` از همان LMP.
برای هر تاریخ‌گزین فقط `RitmoDatePicker.showJalali` با `firstDate` برابر سیصد روز پیش و `lastDate` برابر امروز برای مسیر ۱ و ۳؛ برای مسیر ۲ `firstDate` امروز و `lastDate` سیصد روز بعد.

**بازخورد زنده (اجباری):** زیر هر مسیر، به محض داشتن تاریخ معتبر، یک کادر نتیجه نشان بده: «یعنی الان [سن فارمت‌شده] — حدود [شمارش معکوس انسانی] مانده. درست است?» با `PregnancyDateEngine.formatAgeFa` و `PregnancyHelpers.formatHumanCountdown`.
**مسدودسازی:** دکمهٔ «مرحله بعد» فقط وقتی فعال می‌شود که `PregnancyDateEngine.validate` ترو باشد. در غیر این صورت پیام خطای فارسی PRG-08 را زیر کادر نشان بده.
**معیار پذیرش:** با تاریخ نامعتبر، عبور به گام بعد امکان‌پذیر نیست. هر سه مسیر به مقدار یکسان `lmpDate` می‌رسند وقتی ورودی‌ها معادل باشند.
**تست:** `test/cycle/pregnancy/preg_step_dates_three_paths_test.dart`
**commit:** `PRG-19: add pregnancy onboarding step 2 date basis`

### PRG-20

**باگ:** وضعیت چرخهٔ پیشین و چندقلوبودن و ریسک هیچ جایی پرسیده نمی‌شود.
**فایل‌ها:** `lib/features/cycle/presentation/onboarding/pregnancy_steps/preg_step_3_context.dart` (جدید)
**کار دقیق:** چهار ردیف با همان الگوی `_buildToggleRow` در `cycle_settings_panel.dart` (همان `CupertinoSwitch` و همان `activeTrackColor`):
- «بارداری چندقلو» → `isMultiple`
- «بارداری پرخطر بر اساس نطر پزشک» → `isHighRisk`
- «توقف پیش‌بینی و یادآوری پریود» → `pauseCyclePredictions` با پیش‌فرض ترو
- «تعلیق نماز و روزه در عبادات» → `suspendWorship`
زیر همه، یک یادداشت آرام بدون سویتچ: «سابقهٔ چرخه‌ات دست‌نخورده می‌ماند و بعد از زایمان برمی‌گردد. هیچ داده‌ای حذف نمی‌شود.»
**معیار پذیرش:** هر چهار مقدار در `data` می‌نشینند.
**تست:** —
**commit:** `PRG-20: add pregnancy onboarding step 3 context`

---

### PRG-21

**باگ:** قفل و یادآوری‌ها و پنهان‌سازی در بارداری هیچ ورودی مستقلی ندارند و کلید `preg_section_hidden` فقط نوشته می‌شود و هیچ‌جا خوانده نمی‌شود.
**فایل‌ها:** `lib/features/cycle/presentation/onboarding/pregnancy_steps/preg_step_4_privacy.dart` (جدید)
**کار دقیق:** سه ردیف سویتچ با همان الگوی ردیف تنطیمات:
- «قفل ورود به بخش بارداری» → `lockEnabled`. زیرمتن: «مستقل از قفل بخش چرخه است.»
- «پنهان کردن بارداری از صفحهٔ امروز» → `hideFromDashboard`
- «پوشاندن متن یادآوری‌ها در اعلان‌ها» → `maskNotifications`. زیرمتن: «متن اعلان فقط می‌نویسد یادآوری ریتمو و هیچ اشاره‌ای به بارداری ندارد.»
زیر همه یک پیلز حریم خصوصی با همان متن موجود در `pregnancy_header.dart`: «اطلاعات فقط روی گوشی».
اگر `lockEnabled` را روشن کرد و هنوز رمزی تنطیم نشده، در همین گام یک پیام راهنما نشان بده: «رمز بعد از پایان راه‌اندازی تنطیم می‌شود.» و در PRG-24 مسیر تنطیم رمز را صدا بزن. حالت موجود رمز را با `CycleLockService.instance.hasAppLockPassword()` و `hasCyclePin()` بخوان.
**معیار پذیرش:** هر سه مقدار در `data` می‌نشینند و متن راهنمای رمز فقط در حالت بدون‌رمز دیده می‌شود.
**تست:** —
**commit:** `PRG-21: add pregnancy onboarding step 4 privacy`

### PRG-22

**باگ:** هیچ گام تأییدی وجود ندارد، پس کاربر قبل از فعال‌شدن حالت، خلاصهٔ کارش را نمی‌بیند.
**فایل‌ها:** `lib/features/cycle/presentation/onboarding/pregnancy_steps/preg_step_5_confirm.dart` (جدید)
**کار دقیق:** یک خلاصهٔ خواندنی با همان الگوی `step_5_confirmation.dart` بساز. ردیف‌های اجباری:
- «سن بارداری امروز» با `formatAgeFa`
- «تاریخ تقریبی زایمان» با تاریخ شمسی
- «مبنای محاسبه» که برای سه حالت می‌نویسد «آخرین پریود» یا «نطر پزشک» یا «سونوگرافی»
- «پیش‌بینی پریود» که می‌نویسد «متوقف می‌شود» یا «فعال می‌ماند»
- «عبادات» که می‌نویسد «تعلیق می‌شود» یا «دست نمی‌خورد»
- «قفل» و «پنهان‌سازی» و «پوشش اعلان‌ها» با مقدار روشن یا خاموش
دکمهٔ نهایی: «فعال‌سازی حالت بارداری». در حالت ویرایش متنش «ذخیرهٔ تغییرات» باشد.
دکمه در حین ذخیره باید غیرفعال و با اسپینر شود (همان الگوی `_isSaving`).
**معیار پذیرش:** خلاصه دقیقاً همان مقدارهایی را نشان می‌دهد که در گام‌های قبل انتخاب شدند.
**تست:** `test/cycle/pregnancy/preg_step_confirm_summary_test.dart`
**commit:** `PRG-22: add pregnancy onboarding step 5 confirmation`

### PRG-23

**باگ:** هیچ مسیر ذخیره‌سازی وجود ندارد. اگر ذخیره ناقص بماند، دقیقاً همان حالت معیوب فعلی بازتولید می‌شود.
**فایل‌ها:** `lib/features/cycle/logic/pregnancy_onboarding_controller.dart`
**کار دقیق:** متد `Future<void> savePregnancyOnboarding(PregnancyOnboardingData data, {bool isEditMode = false})` را بساز. تمام نوشتن‌ها باید در یک تراکنش واحد باشند: `await db.transaction((txn) async { ... })`.
ترتیب دقیق داخل تراکنش:
۱. `PregnancySettings.saveProfile(profile, txn)` با پروفایل ساخته‌شده از `data`.
۲. نوشتن `preg_setup_done` برابر `'true'`.
۳. `PregnancySettings.setPregnancyActive(true, db: txn)`.
۴. اگر `pauseCyclePredictions` ترو بود، نوشتن `cycle_consent_reminders` برابر `'false'`.
۵. اگر `suspendWorship` ترو بود، نوشتن `cycle_consent_worship` برابر `'false'`.
۶. اگر `hideFromDashboard` ترو بود، نوشتن `cycle_consent_dashboard` برابر `'false'`.
۷. بستن دورهٔ باز: در جدول دوره‌ها اگر ردیفی با تاریخ پایان خالی وجود دارد، تاریخ پایانش را برابر تاریخ شروع به‌اضافهٔ مدت پیش‌فرض دوره بگذار. اول `cycle_period_repository.dart` را بخوان تا نام دقیق جدول و ستون‌ها را بدانی. هیچ ردیفی را حذف نکن.
پس از تراکنش (بیرون از آن):
- `CycleEngine().invalidate()`
- `DayAgendaService.instance.invalidateDate(todayKey)`
- `WorshipEngine.instance.invalidate()` فقط اگر `suspendWorship` ترو بود
- `RitmoEventBus().fire(RitmoEvent(type: 'WorshipUpdated', ...))` فقط اگر عبادات دست خورد
- `RitmoEvents.notifyRoutineChanged()`
الگوی دقیق هر چهار فراخوانی بالا را از `cycle_settings_panel.dart` و `cycle_onboarding_controller.dart` بردار تا امضای متدها درست باشد.
**معیار پذیرش:** اگر در میانهٔ ذخیره خطا بدهد، هیچ کلیدی نوشته نمی‌ماند و پرچم بارداری خاموش می‌ماند. این معیار اجباری است.
**تست:** `test/cycle/pregnancy/pregnancy_onboarding_atomic_save_test.dart`
**commit:** `PRG-23: add atomic pregnancy onboarding save`

### PRG-24

**باگ:** پس از ذخیره، نه رمز تنطیم می‌شود و نه یادآوری‌های بارداری زمان‌بندی می‌شوند.
**فایل‌ها:** `lib/features/cycle/presentation/onboarding/pregnancy_onboarding_shell.dart`
**کار دقیق:** در پوسته، پس از موفقیت `savePregnancyOnboarding`:
۱. اگر `lockEnabled` ترو بود و رمزی وجود ندارد، شیت رمز را در حالت `CyclePasscodeSheetMode.setup` باز کن. اگر کاربر لغو کرد، فقط کلید `preg_lock_enabled` را فالس کن و بقیهٔ راه‌اندازی را دست نزن. هرگز کل راه‌اندازی را لغو نکن.
۲. فراخوانی زمان‌بندی یادآوری بارداری که در PRG-35 ساخته می‌شود. در این تسک یک `TODO PRG-35` بگذار و در PRG-35 حتماً برگرد و وصل کن. این یگانه `TODO` مجاز در کل این پرامپت است.
۳. یک اسنک‌بار موفقیت: در لحن گرم «حالت بارداری فعال شد. از همین امروز کنارت هستیم.» و در لحن آرام «حالت بارداری فعال شد.»
۴. بستن پوسته و صدا زدن `onCompleted`.
**معیار پذیرش:** لغو کردن شیت رمز باعث از دست رفتن راه‌اندازی نمی‌شود.
**تست:** `test/cycle/pregnancy/pregnancy_lock_cancel_keeps_setup_test.dart`
**commit:** `PRG-24: finalize pregnancy onboarding post-save flow`

---

## فاز E — اتصال دکمهٔ فعال‌سازی (PRG-25 تا PRG-29)

هدف فاز: ریشهٔ P-A را ببند. دکمهٔ «فعالسازی حالت بارداری» دیگر نباید یک پرچم را وارونه کند.

### PRG-25

**باگ:** در `cycle_screen.dart` داخل `_openSettingsSheet`، مقدار `onTogglePregnancyMode` این کار را می‌کند: شیت را می‌بندد، مقدار فعلی را می‌خواند، معکوسش را می‌نویسد و `_loadData()` می‌زند. هیچ تاریخی پرسیده نمی‌شود و هیچ آنبوردینگی باز نمی‌شود.
**فایل‌ها:** `lib/features/cycle/presentation/cycle_screen.dart`
**کار دقیق:** منطق را دوشاخه کن:
- اگر بارداری خاموش است (یعنی کاربر می‌خواهد روشن کند): هیچ نوشتنی نکن. فقط شیت را ببند و `_openPregnancyOnboarding()` را صدا بزن.
- اگر بارداری روشن است (یعنی کاربر می‌خواهد خاموش کند): مستقیم خاموش نکن. همان شیت سه‌مسیرهٔ پایان بارداری را که الان در `cycle_pregnancy_mode.dart` به نام `_showEndPregnancySheet` وجود دارد باز کن.
**معیار پذیرش:** هیچ مسیری در برنامه وجود ندارد که `cycle_pregnancy_mode` را ترو کند برای بارداری بدون گذر از آنبوردینگ.
**تست:** `test/cycle/pregnancy/toggle_opens_onboarding_test.dart`
**commit:** `PRG-25: replace pregnancy toggle with onboarding launch`

### PRG-26

**باگ:** متن ردیف در پنل تنطیمات دقیق نیست. الان می‌گوید «فعالسازی حالت بارداری» که حالا به جای فعال‌سازی، یک راه‌اندازی را شروع می‌کند.
**فایل‌ها:** `lib/features/cycle/presentation/widgets/cycle_settings_panel.dart`
**کار دقیق:** متن دو حالت را عوض کن:
- حالت خاموش: «راه‌اندازی حالت بارداری» با زیرمتن «تاریخ و تنطیمات را در پنج مرحله مشخص کن.»
- حالت روشن: «تنطیمات بارداری و پایان دوره» با زیرمتن «تاریخ، یادآوری‌ها، حریم خصوصی، پایان بارداری»
ایموجی‌ها را دست نزن (همان دو ایموجی موجود). در حالت روشن، ردیف باید به صفحهٔ تنطیمات بارداری فاز F برود، نه به شیت پایان.
**معیار پذیرش:** هیچ جایی در برنامه وعدهٔ «فعالسازی فوری» نمی‌دهد.
**تست:** —
**commit:** `PRG-26: clarify pregnancy row labels in cycle settings`

---

### PRG-27

**باگ:** ریشهٔ P-F — فعال شدن بارداری پیش‌بینی پریود را متوقف نمی‌کند. پس کاربر در حالت بارداری هم اعلان «پریودت نزدیک است» می‌گیرد.
**فایل‌ها:** `lib/features/cycle/logic/cycle_reminder_scheduler.dart`
**کار دقیق:** اول این فایل را کامل بخوان. در بالاترین نقطهٔ ورود زمان‌بندی، یک محافط بگذار: اگر `CycleSettings.isPregnancyMode(settings)` ترو بود، هیچ یادآوری پریودی زمان‌بندی نشود و یادآوری‌های قبلی لغو شوند. یک لاگ با همان پیشوند موجود در همان فایل بنویس.
توجه: این محافط بر کلید `cycle_consent_reminders` مقدم است؛ حتی اگر کاربر در PRG-20 مخالف توقف بود، یادآوری پریود در بارداری بی‌معنی است.
**معیار پذیرش:** در حالت بارداری، تعداد یادآوری‌های پریودی زمان‌بندی‌شده صفر است.
**تست:** `test/notifications/pregnancy_suppresses_period_reminders_test.dart`
**commit:** `PRG-27: suppress period reminders during pregnancy`

### PRG-28

**باگ:** پیش‌بینی چرخه در کارت‌ها و تقویم همچنان در حالت بارداری محاسبه می‌شود.
**فایل‌ها:** `lib/core/domain/engines/cycle_engine.dart`
**کار دقیق:** اول فایل را کامل بخوان و ببین آیا الان چیزی دربارهٔ بارداری می‌داند یا نه. اگر نمی‌داند، یک پرچم به خروجی اضافه کن: `bool isPregnancyActive` در `CycleEngineOutput`، و وقتی ترو باشد مقدارهای پیش‌بینی را خالی برگردان و محاسبهٔ فاز را متوقف کن.
مرز دقیق: محاسبهٔ سابقه و آمار گذشته را دست نزن. فقط پیش‌بینی آینده خاموش می‌شود.
اگر این تغییر باعث شکست تست‌های موجود `test/cycle_engine_test.dart` شد، تست‌ها را حذف نکن — فقط ورودی بارداری را در آن‌ها فالس بگذار.
**معیار پذیرش:** در حالت بارداری، تقویم هیچ روز پیش‌بینی‌شدهٔ پریود نشان نمی‌دهد، ولی سابقهٔ گذشته هنوز دیده می‌شود.
**تست:** `test/cycle/pregnancy/engine_pauses_forecast_test.dart`
**commit:** `PRG-28: pause cycle forecasting during pregnancy`

### PRG-29

**باگ:** در `cycle_screen.dart` کالبک `onEditBaselineParameter` یک بدنهٔ خالی است. پس در پنل تنطیمات، چهار ردیف پارامتر قابل لمس هستند ولی هیچ کاری نمی‌کنند. این مستقل از بارداری است ولی در همین مسیر دیده شد و باید بسته شود.
**فایل‌ها:** `lib/features/cycle/presentation/cycle_screen.dart`
**کار دقیق:** بدنهٔ خالی را پر کن: یک دیالوگ ساده با عنوان ورودی `title`، یک اسلایدر یا میدان عددی در بازهٔ `min` تا `max` با مقدار فعلی یا `defVal`، دو دکمهٔ «انصراف» و «ذخیره». در ذخیره، مقدار را در همان `key` بنویس و `_loadData()` بزن.
مرز مهم: کلیدهای ورودی این کالبک کلیدهای مستعار هستند (مانند `cycle_avg_length` و `cycle_avg_period`). پس پس از نوشتن، حتماً مسیر معتبر `CycleSettings` را هم به‌روز کن تا دو منبع حقیقت نسازگار نشوند. اول `cycle_settings.dart` را بخوان و ببین کدام کلید اصل و کدام مستعار است.
**معیار پذیرش:** تغییر طول چرخه از پنل تنطیمات پس از بستن و باز کردن مجدد باقی می‌ماند.
**تست:** `test/cycle/baseline_parameter_edit_test.dart`
**commit:** `PRG-29: implement baseline parameter editor`

---

## فاز F — صفحهٔ تنطیمات بارداری (PRG-30 تا PRG-37)

هدف فاز: ریشهٔ P-D را ببند. دکمهٔ تنطیمات در هدر بارداری باید به یک صفحهٔ واقعی برود، نه به شیت پایان بارداری.

### PRG-30

**باگ:** هیچ صفحهٔ تنطیماتی برای بارداری وجود ندارد.
**فایل‌ها:** `lib/features/cycle/presentation/widgets/pregnancy/pregnancy_settings_sheet.dart` (جدید)
**کار دقیق:** یک شیت قابل پیمایش بساز با همان الگوی ویژوال `cycle_settings_panel.dart`: همان کارت شیشه‌ای، همان دستگیرهٔ بالا، همان عنوان‌های بخش. عنوان کل: «تنطیمات بارداری».
شش بخش با همین ترتیب و همین عنوان‌ها:
۱. «تاریخ و سن بارداری»
۲. «لحن و نمایش»
۳. «مراقبت‌ها و یادآوری‌ها»
۴. «لگدشماری»
۵. «حریم خصوصی»
۶. «ناحیهٔ خطر»
در این تسک فقط پوسته و شش سرفصل خالی را بساز. یک متد ایستای `static Future<void> show(BuildContext context)` هم بگذار، دقیقاً به سبک `PregnancyReportScreen.show` که در `pregnancy_header.dart` فراخوانی می‌شود.
**معیار پذیرش:** شیت باز می‌شود و شش سرفصل دیده می‌شوند.
**تست:** `test/cycle/pregnancy/pregnancy_settings_sheet_sections_test.dart`
**commit:** `PRG-30: add pregnancy settings sheet shell`

### PRG-31

**باگ:** بعد از راه‌اندازی، تاریخ زایمان قابل ویرایش نیست؛ در حالی که پزشک معمولاً بعد از سونوگرافی دوم آن را تصحیح می‌کند.
**فایل‌ها:** `lib/features/cycle/presentation/widgets/pregnancy/pregnancy_settings_sheet.dart`
**کار دقیق:** بخش ۱ را پر کن:
- یک ردیف خواندنی «سن بارداری امروز».
- یک ردیف قابل لمس «تاریخ تقریبی زایمان» که همان سه مسیر PRG-19 را در یک شیت کوچک باز می‌کند.
- یک ردیف خواندنی «مبنای محاسبه» با سه مقدار فارسی.
**هشدار اجباری:** پیش از ثبت تاریخ جدید، اگر `PregnancyDateEngine.dayShiftBetween` غیر صفر بود، یک دیالوگ تأیید نشان بده با متن: «با این تغییر، سن بارداری و تمام یادآوری‌های بعدی [عدد] روز جابه‌جا می‌شوند. داده‌های ثبت‌شدهٔ گذشته حذف نمی‌شوند.» دکمه‌ها: «تأیید و به‌روزرسانی» و «انصراف».
نوشتن فقط از مسیر `PregnancySettings.saveProfile`.
**معیار پذیرش:** تغییر تاریخ بلافاصله در هدر بارداری دیده می‌شود و هیچ داده‌ای پاک نمی‌شود.
**تست:** `test/cycle/pregnancy/pregnancy_edd_edit_test.dart`
**commit:** `PRG-31: add editable due date with shift warning`

### PRG-32

**باگ:** ریشهٔ P-E — `preg_tone` فقط خوانده می‌شود و واحد نمایش سن هم قابل انتخاب نیست.
**فایل‌ها:** `lib/features/cycle/presentation/widgets/pregnancy/pregnancy_settings_sheet.dart`
**کار دقیق:** بخش ۲ را پر کن:
- دو گزینهٔ لحن مطل گام ۱، حالا قابل تغییر در هر زمان.
- یک سویتچ «نمایش شمارش معکوس تا زایمان».
- یک انتخابگر دوگانهٔ واحد: «هفته و روز» یا «ماه و هفته» معادل `PregnancyAgeUnit`.
هر سه باید بلافاصله بر هدر بارداری اثر بگذارند.
کلید تازه برای شمارش معکوس: اگر در `PregnancySettings` نیست، یک کلید `preg_show_countdown` اضافه کن و در همان فاساد ثبت کن. هرگز کلیدی را بیرون از فاساد ننویس.
**معیار پذیرش:** عوض کردن لحن به آرام، عنوان هدر را از حالت ایموجی‌دار به حالت ساده برمی‌گرداند (همان منطقی که الان در `pregnancy_header.dart` هست).
**تست:** `test/cycle/pregnancy/pregnancy_tone_writable_test.dart`
**commit:** `PRG-32: make pregnancy tone and age unit editable`

### PRG-33

**باگ:** مقدار `doctor_edd` در هدر نشان نمی‌گیرد؛ منطق فعلی فقط برای مقدار سونوگرافی نشان می‌دهد.
**فایل‌ها:** `lib/features/cycle/presentation/widgets/pregnancy/pregnancy_header.dart`
**کار دقیق:** منطق نشان را سه‌حالته کن:
- `ultrasound` → همان نشان موجود «سونوگرافی» با همان ایموجی.
- `doctor_edd` → نشان تازه «تایید پزشک».
- `lmp` → بدون نشان (همان رفتار فعلی).
ساختار ویژوال نشان را دست نزن؛ فقط متن و شرط.
**معیار پذیرش:** هر سه مقدار درست رندر می‌شوند.
**تست:** `test/cycle/pregnancy/pregnancy_edd_source_badge_test.dart`
**commit:** `PRG-33: show doctor EDD badge in pregnancy header`

---

### PRG-34

**باگ:** مراقبت‌ها و یادآوری‌های بارداری هیچ تنطیمی ندارند. کاربر نمی‌تواند ساعت یا فاصلهٔ یادآوری را عوض کند.
**فایل‌ها:** `lib/features/cycle/presentation/widgets/pregnancy/pregnancy_settings_sheet.dart`
**کار دقیق:** بخش ۳ را پر کن با چهار ردیف:
- «یادآوری ویزیت مامایی» با انتخابگر عددی در بازهٔ یک تا هفت روز قبل، معادل `preg_visit_reminder_lead_days`.
- «ساعت یادآوری‌های بارداری» با انتخابگر ساعت در بازهٔ شش تا بیست و دو، معادل `preg_reminder_hour`. همان محدوده‌ای که `CycleSettings.getReminderHour` دارد.
- «یادآوری مکمل‌ها و ویتامین‌ها» با سویتچ.
- «یادآوری لگدشماری از هفتهٔ ۲۸» با سویتچ، که تا هفتهٔ ۲۸ غیرفعال و خاموش نشان داده می‌شود با زیرمتن «از هفتهٔ ۲۸ به بعد فعال می‌شود.»
دو کلید تازه لازم است: `preg_supplement_reminder` و `preg_kick_reminder`. هر دو را در `PregnancySettings` و `PregnancyProfile` اضافه کن.
**معیار پذیرش:** هر چهار مقدار پس از بستن و باز کردن مجدد شیت باقی می‌مانند.
**تست:** `test/cycle/pregnancy/pregnancy_care_settings_test.dart`
**commit:** `PRG-34: add pregnancy care and reminder settings`

### PRG-35

**باگ:** هیچ زمان‌بندی‌ای برای یادآوری‌های بارداری وجود ندارد؛ پس تنطیمات PRG-34 هنوز بی‌اثر هستند.
**فایل‌ها:** `lib/features/cycle/logic/pregnancy_reminder_scheduler.dart` (جدید)، مرجع الگو: `lib/features/cycle/logic/cycle_reminder_scheduler.dart`
**کار دقیق:** اول زمان‌بند چرخه را کامل بخوان تا بدانی الان از چه سرویس اعلانی استفاده می‌شود و شناسهٔ اعلان‌ها چطور ساخته می‌شود. دقیقاً از همان سرویس استفاده کن و سرویس تازه نساز.
سه دسته یادآوری زمان‌بندی کن:
۱. ویزیت مامایی: از مخزن ویزیت‌های موجود در ماجول سلامت بخوان (اول `lib/features/health/data/pregnancy_repository.dart` و صفحهٔ `visits_page.dart` را بخوان تا منبع داده را بفهمی). فاصله بر اساس `preg_visit_reminder_lead_days` و ساعت بر اساس `preg_reminder_hour`.
۲. مکمل روزانه: فقط اگر `preg_supplement_reminder` ترو باشد، هر روز در همان ساعت.
۳. لگدشماری: فقط اگر `preg_kick_reminder` ترو باشد و سن بارداری در هفتهٔ ۲۸ یا بیشتر باشد.
**پوشش متن (اجباری):** اگر `preg_mask_notifications` ترو بود، عنوان و متن همهٔ این اعلان‌ها باید فقط «یادآوری ریتمو» باشد و هیچ واژهٔ مربوط به بارداری یا ویزیت یا لگد در متن نباشد.
**معیار پذیرش:** با فعال بودن پوشش، هیچ اعلانی واژهٔ حساس ندارد. در هفتهٔ ۲۰، یادآوری لگدشماری زمان‌بندی نمی‌شود.
**تست:** `test/notifications/pregnancy_reminder_scheduler_test.dart`
**commit:** `PRG-35: add pregnancy reminder scheduler with masking`

### PRG-36

**باگ:** در `kick_session_tracker.dart` هدف تعداد لگد و پنجرهٔ زمانی سخت‌کد هستند و هیچ تنطیمی ندارند.
**فایل‌ها:** `lib/features/cycle/presentation/widgets/kick_session_tracker.dart`، `lib/features/cycle/presentation/widgets/pregnancy/pregnancy_settings_sheet.dart`
**کار دقیق:** اول فایل لگدشماری را کامل بخوان و مقدارهای سخت‌کد را پیدا کن. آن‌ها را به دو پارامتر ویجت تبدیل کن با همان پیش‌فرض‌های فعلی به عنوان مقدار پیش‌فرض، تا رفتار موجود تغییر نکند. مقدارها از `PregnancySettings` خوانده شوند.
بخش ۴ شیت تنطیمات را پر کن با سه ردیف:
- «تعداد هدف لگد» بازهٔ پنج تا بیست، پیش‌فرض ده.
- «مدت پنجرهٔ شمارش» بازهٔ سی تا سیصد دقیقه، پیش‌فرض یکصد و بیست.
- «مقایسه با الگوی شخصی خودم» با سویتچ، معادل `preg_kick_baseline_compare`.
**مرز:** منطق شمارش و ذخیرهٔ جلسات لگد را دست نزن. فقط دو عدد پارامتری می‌شوند.
**معیار پذیرش:** با پیش‌فرض‌ها، رفتار لگدشماری دقیقاً مطل قبل است. با تغییر عدد، هدف در ویجت عوض می‌شود.
**تست:** `test/cycle/pregnancy/kick_tracker_configurable_test.dart`
**commit:** `PRG-36: make kick counter target and window configurable`

### PRG-37

**باگ:** دکمهٔ تنطیمات در هدر بارداری به شیت پایان بارداری می‌رود. در `pregnancy_header.dart` مقدار `onShowSettings` در `cycle_pregnancy_mode.dart` به `_showEndPregnancySheet` وصل است، در حالی که تولتیپ می‌گوید «تنطیمات بارداری».
**فایل‌ها:** `lib/features/cycle/presentation/widgets/cycle_pregnancy_mode.dart`
**کار دقیق:** مقدار `onShowSettings` را به `PregnancySettingsSheet.show(context)` وصل کن. مسیر پایان بارداری را حذف نکن — همان `_showEndPregnancySheet` موجود حالا فقط از بخش ۶ شیت تنطیمات (ناحیهٔ خطر) فراخوانی می‌شود.
بخش ۶ را پر کن: یک جداکنندهٔ ویژوال و یک دکمهٔ تکی با متن «پایان دورهٔ بارداری» در رنگ هشدار، دقیقاً در پایین‌ترین نقطهٔ شیت. زیرمتن: «در مرحلهٔ بعد از تو می‌پرسیم که چه اتفاقی افتاده.»
**معیار پذیرش:** فشردن دکمهٔ تنطیمات در هدر دیگر هرگز شیت پایان بارداری را باز نمی‌کند.
**تست:** `test/cycle/pregnancy/header_settings_opens_settings_test.dart`
**commit:** `PRG-37: rewire header settings button to pregnancy settings`

---

## فاز G — بستن کلیدهای یتیم (PRG-38 تا PRG-42)

هدف فاز: ریشهٔ P-E را کامل ببند. هیچ کلیدی نباید فقط نوشته یا فقط خوانده شود.

### PRG-38

**باگ:** `preg_section_hidden` نوشته می‌شود ولی هیچ‌جا خوانده نمی‌شود. پس وعدهٔ پنهان‌سازی عملی نیست.
**فایل‌ها:** محل مصرف در صفحهٔ امروز و داشبورد
**کار دقیق:** اول پیدا کن کجا کارت بارداری در صفحهٔ امروز نشان داده می‌شود. نقطهٔ شروع جستجو: فایل `pregnancy_today_card.dart` را بخوان و ببین کجا ساخته می‌شود. در همان محل یک محافط بگذار: اگر `preg_section_hidden` ترو بود، کارت را رندر نکن.
**معیار پذیرش:** روشن کردن سویتچ پنهان‌سازی، کارت بارداری را از صفحهٔ امروز حذف می‌کند، ولی بخش بارداری در خود ماجول چرخه دست نمی‌خورد.
**تست:** `test/cycle/pregnancy/section_hidden_respected_test.dart`
**commit:** `PRG-38: honor pregnancy section hidden flag`

### PRG-39

**باگ:** `preg_cycle_resume_reminder` نوشته می‌شود ولی هیچ یادآوری‌ای زمان‌بندی نمی‌کند.
**فایل‌ها:** `lib/features/cycle/logic/pregnancy_reminder_scheduler.dart`
**کار دقیق:** یک یادآوری تک‌باره اضافه کن: چهل روز پس از تاریخ پایان بارداری، با متن «اگر چرخه‌ات برگشته، می‌توانی حالت عادی را دوباره فعال کنی.» فقط اگر کلید ترو باشد. در حالت پوشش متن، همان متن خنطی PRG-35 را بگذار.
**معیار پذیرش:** پس از پایان بارداری با کلید روشن، دقیقاً یک یادآوری زمان‌بندی می‌شود.
**تست:** `test/notifications/pregnancy_cycle_resume_reminder_test.dart`
**commit:** `PRG-39: schedule postpartum cycle resume reminder`

### PRG-40

**باگ:** قفل بارداری کلید دارد ولی هیچ دروازه‌ای آن را اعمال نمی‌کند.
**فایل‌ها:** `lib/features/cycle/presentation/widgets/cycle_lock_gate.dart`
**کار دقیق:** این فایل بزرگ است؛ اول کامل بخوان و ببین الان چطور `cycle_lock_enabled` را اعمال می‌کند. منطق را توسعه بده: در حالت بارداری، معیار قفل باید یا `cycle_lock_enabled` باشد یا `preg_lock_enabled`. یکی از دو کافی است.
مرز مهم: رفتار حالت غیربارداری را دست نزن. منطق fail-secure موجود در `CycleSettings.isLockEnabled` را هم دست نزن.
**معیار پذیرش:** با روشن بودن فقط `preg_lock_enabled`، ورود به بخش بارداری رمز می‌خواهد.
**تست:** `test/cycle/pregnancy/pregnancy_lock_gate_test.dart`
**commit:** `PRG-40: enforce independent pregnancy lock`

### PRG-41

**باگ:** پوشش متن اعلان‌ها در بارداری جداگانه است ولی کلید موجود چرخه (`cycle_inbox_mask_enabled`) ممکن است با آن تناقض پیدا کند.
**فایل‌ها:** `lib/features/cycle/logic/pregnancy_reminder_scheduler.dart`
**کار دقیق:** قاعدهٔ ادغام را صریح کن: پوشش فعال است اگر یا `preg_mask_notifications` ترو باشد یا `cycle_inbox_mask_enabled` ترو باشد. یعنی سخت‌گیرانه‌ترین مقدار برنده است. این قاعده را در یک تابع خالص بگذار تا قابل تست باشد.
**معیار پذیرش:** هر چهار ترکیب دو کلید در تست پوشش دارند.
**تست:** `test/cycle/pregnancy/mask_merge_rule_test.dart`
**commit:** `PRG-41: define notification mask merge rule`

### PRG-42

**باگ:** هیچ محافطی وجود ندارد که در آینده کلید تازه‌ای با پیشوند `preg_` درست شود و فراموش شود که در فاساد ثبت شود.
**فایل‌ها:** `test/guards/pregnancy_keys_guard_test.dart` (جدید)
**کار دقیق:** یک تست نگهبان بنویس که تمام فایل‌های `lib/features/cycle/` و `lib/features/health/` را می‌خواند، هر رشتهٔ متنی که با `preg_` شروع می‌شود را جمع می‌کند، و مطمئن می‌شود همهٔ آن کلیدها در لیست کلیدهای `PregnancySettings` وجود دارند. برای یافتن رشته‌ها از جستجوی سادهٔ متنی استفاده کن و از عبارت منطقی پیچیده پرهیز کن.
**معیار پذیرش:** تست سبز است و اگر کسی کلید تازه‌ای را بیرون از فاساد اضافه کند، قرمز می‌شود.
**تست:** همان فایل
**commit:** `PRG-42: add pregnancy key registry guard test`

---

## فاز H — پایان بارداری و پاکسازی (PRG-43 تا PRG-46)

هدف فاز: پایان دوره باید کامل و بی‌بازگشت باشد، ولی فقط وقتی کاربر صریحاً خواسته.

### PRG-43

**باگ:** مسیر پایان بارداری در `cycle_pregnancy_mode.dart` وجود دارد و سه مسیر دارد، ولی هیچ جایی مستند نشده که هر مسیر دقیقاً چه چیزی را لمس می‌کند.
**فایل‌ها:** `lib/features/cycle/presentation/widgets/cycle_pregnancy_mode.dart`
**کار دقیق:** اول `_showEndPregnancySheet` و هر چه فراخوانی می‌کند را کامل بخوان. سپس متن هر سه مسیر را دقیق کن تا کاربر بداند چه اتفاقی می‌افتد:
- مسیر تولد موفق: «داده‌های بارداری نگه داشته می‌شوند و حالت بارداری بسته می‌شود.»
- مسیر از دست دادن: «حالت بارداری بسته می‌شود. می‌توانی انتخاب کنی داده‌ها بمانند یا پاک شوند.»
- مسیر اشتباه فعال‌سازی: «همهٔ داده‌های بارداری پاک می‌شوند و چرخه برمی‌گردد.»
منطق موجود هر مسیر را دست نزن. فقط متن و ترتیب.
**معیار پذیرش:** هر سه مسیر پیام صریح دربارهٔ سرنوشت داده‌ها دارند.
**تست:** —
**commit:** `PRG-43: clarify end-of-pregnancy path wording`

### PRG-44

**باگ:** پس از پایان بارداری، موافقت‌هایی که در PRG-23 خاموش شدند (یادآوری پریود، عبادات، داشبورد) دوباره روشن نمی‌شوند. کاربر بعد از زایمان در یک برنامهٔ نیمه‌خاموش می‌ماند.
**فایل‌ها:** `lib/features/cycle/presentation/widgets/cycle_pregnancy_mode.dart`، `lib/features/cycle/logic/pregnancy_settings.dart`
**کار دقیق:** پیش از خاموش کردن موافقت‌ها در PRG-23، مقدار قبلی هر سه کلید را در سه کلید پشتیبان ذخیره کن: `preg_prev_consent_reminders`، `preg_prev_consent_worship`، `preg_prev_consent_dashboard`. هر سه را در لیست کلیدهای فاساد ثبت کن (وگرنه تست PRG-42 قرمز می‌شود).
در هر سه مسیر پایان بارداری، مقدارهای پشتیبان را برگردان و سپس کلیدهای پشتیبان را حذف کن.
اگر کلید پشتیبان موجود نبود (کاربران قدیمی)، موافقت‌ها را به حالت روشن برگردان، چون پیش‌فرض طبیعی برنامه همین است.
**معیار پذیرش:** یک چرخهٔ کامل روشن کردن و پایان دادن بارداری، هر سه موافقت را دقیقاً به مقدار اولیه برمی‌گرداند.
**تست:** `test/cycle/pregnancy/consent_restore_after_pregnancy_test.dart`
**commit:** `PRG-44: restore cycle consents after pregnancy ends`

### PRG-45

**باگ:** تابع پاکسازی موجود (همان مسیری که جدول‌های بارداری را پاک می‌کند) کلیدهای `preg_*` در `app_settings` را پاک نمی‌کند. پس پس از «پاکسازی کامل»، تاریخ و لحن و تنطیمات بارداری قبلی باقی می‌مانند و در بارداری بعدی مقدار اشتباه نشان داده می‌شود.
**فایل‌ها:** `lib/features/cycle/presentation/widgets/cycle_pregnancy_mode.dart`
**کار دقیق:** در همان تابع پاکسازی، فراخوانی `PregnancySettings.clearAll(txn)` را اضافه کن، درون همان تراکنشی که جدول‌ها را پاک می‌کند.
**مرز مطلق:** این یگانه تسکی است که در کل این پرامپت مجاز به حذف داده است، و فقط درون همان مسیری که الان هم وجود دارد و کاربر صریحاً تأیید کرده. مسیر تازه‌ای برای حذف نساز.
**معیار پذیرش:** پس از پاکسازی کامل، جستجوی کلیدهای `preg_` در `app_settings` هیچ ردیفی برنمی‌گرداند. جدول دوره‌های چرخه دست‌نخورده می‌ماند.
**تست:** `test/cycle/pregnancy/pregnancy_purge_clears_settings_test.dart`
**commit:** `PRG-45: purge pregnancy settings keys on full reset`

### PRG-46

**باگ:** پس از پایان بارداری، یادآوری‌های زمان‌بندی‌شدهٔ بارداری لغو نمی‌شوند. مادری که بارداری را از دست داده، هفته‌ها بعد هم یادآوری لگدشماری می‌گیرد. این بدترین حالت ممکن است و اولویت بالا دارد.
**فایل‌ها:** `lib/features/cycle/logic/pregnancy_reminder_scheduler.dart`، `lib/features/cycle/presentation/widgets/cycle_pregnancy_mode.dart`
**کار دقیق:** یک متد `Future<void> cancelAll()` در زمان‌بند بارداری بساز که هر سه دستهٔ PRG-35 را لغو می‌کند. این متد را در هر سه مسیر پایان بارداری، بدون استثنا، فراخوانی کن. یادآوری بازگشت چرخه (PRG-39) از این لغو مستقل است و پس از آن زمان‌بندی می‌شود.
**معیار پذیرش:** پس از پایان بارداری، تعداد یادآوری‌های بارداری زمان‌بندی‌شده صفر است.
**تست:** `test/notifications/pregnancy_reminders_cancelled_on_end_test.dart`
**commit:** `PRG-46: cancel pregnancy reminders when pregnancy ends`

---

## فاز I — مهاجرت کاربران فعلی (PRG-47 تا PRG-49)

هدف فاز: کاربرانی که الان در حالت معیوب گیر کرده‌اند (پرچم روشن، تاریخ خالی) باید بدون از دست دادن داده نجات پیدا کنند.

### PRG-47

**باگ:** کاربری که قبلاً دکمهٔ فعالسازی را زده، الان پرچم روشن و تاریخ خالی دارد. با PRG-11 دیگر هفتهٔ صفر نمی‌بیند، ولی باید فعالانه راهنمایی شود.
**فایل‌ها:** `lib/features/cycle/presentation/cycle_screen.dart`
**کار دقیق:** در متد بارگذاری داده، پس از خواندن `_settings`، یک بررسی یک‌باره بگذار: اگر `CycleSettings.isPregnancyMode` ترو بود و `PregnancySettings.hasValidDates` فالس بود و `preg_setup_done` هم ترو نبود، یک بار (با یک کلید یک‌بارمصرف) یک دیالوگ نشان بده:
عنوان: «تاریخ بارداری‌ات را کامل کنیم?»
متن: «حالت بارداری فعال است ولی تاریخ را هرگز ثبت نکرده‌ایم. با یک مرحلهٔ کوتاه همه چیز درست می‌شود.»
دو دکمه: «الان انجام می‌دهم» (باز کردن آنبوردینگ) و «بعداً».
کلید یک‌بارمصرف: `preg_migration_prompt_shown`. این را هم در فاساد ثبت کن.
**معیار پذیرش:** دیالوگ دقیقاً یک بار دیده می‌شود، حتی اگر کاربر «بعداً» را بزند.
**تست:** `test/cycle/pregnancy/pregnancy_migration_prompt_test.dart`
**commit:** `PRG-47: prompt existing users with missing pregnancy dates`

### PRG-48

**باگ:** کاربرانی که از مسیر آنبوردینگ چرخه گزینهٔ «الان باردارم» را زده بودند، سه کلید پرچم بارداری را دارند ولی ممکن است مقدارها ناسازگار باشند (مثلاً یکی ترو و دو تای دیگر غایب).
**فایل‌ها:** `lib/features/cycle/logic/pregnancy_settings.dart`
**کار دقیق:** یک متد `static Future<void> reconcileFlags(Map<String, dynamic> settings, DatabaseExecutor db)` بساز. قاعده: اگر حتی یکی از سه کلید ترو باشد، هر سه ترو می‌شوند. اگر هیچ‌کدام ترو نبود، دست نزن. این متد را در مسیر بارگذاری دادهٔ صفحهٔ چرخه یک بار فراخوانی کن.
مرز: این متد فقط پرچم را یکدست می‌کند. هرگز تاریخ حدس نمی‌زند و هرگز داده نمی‌سازد.
**معیار پذیرش:** با ورودی ناسازگار، پس از فراخوانی هر سه کلید یکسان می‌شوند.
**تست:** `test/cycle/pregnancy/pregnancy_flag_reconcile_test.dart`
**commit:** `PRG-48: reconcile legacy pregnancy flags`

### PRG-49

**باگ:** هیچ مستندی برای بخش بارداری وجود ندارد. پوشهٔ `docs/` برای تقویم و تنطیمات و هوش مصنوعی مستند دارد ولی برای بارداری هیچ.
**فایل‌ها:** `docs/cycle/PREGNANCY_CONTRACT.md` (جدید)
**کار دقیق:** یک مستند کوتاه فارسی بنویس با چهار بخش:
۱. جدول کامل کلیدهای `preg_*` با ستون‌های کلید، نوع، پیش‌فرض، محل نوشتن، محل خواندن.
۲. قانون یگانهٔ نویسنده: هر نوشتنی فقط از `PregnancySettings`.
۳. قانون وابستگی: پرچم بارداری بدون تاریخ معتبر بی‌معنی است.
۴. جدول مسیرهای ورود به بارداری (چهار مسیر: دکمهٔ تنطیمات، گام ۲ آنبوردینگ، حالت خالی چرخه، دکمهٔ ترمیم).
**معیار پذیرش:** مستند وجود دارد و هر کلیدی که در `PregnancySettings` هست در جدول هم هست.
**تست:** —
**commit:** `PRG-49: document pregnancy data contract`

---

## فاز J — بازرسی نهایی (PRG-50)

### PRG-50

**باگ:** در کارهای قبلی این مخزن، ایجنت کدنویس چند بار دفترچه را «تکمیل‌شده» علامت زد در حالی که فایل و پوشهٔ مدعاشده هرگز ساخته نشده بود.
**فایل‌ها:** `docs/cycle/PREGNANCY_SETUP_PROGRESS.md`
**کار دقیق:** یک بازرسی تک‌تک انجام بده. برای هر تسک PRG-01 تا PRG-49:
۱. فایل‌هایی که در ستون «فایل‌ها» ذکر شده‌اند را واقعاً باز کن و وجود تغییر را با چشم تأیید کن.
۲. فایل تست ذکرشده را واقعاً باز کن و مطمئن شو وجود دارد و خالی نیست.
۳. در دفترچه وضعیت را `DONE` یا `PARTIAL` یا `SKIPPED` با دلیل یک‌خطی بنویس.
سپس سه دستور را اجرا کن و خروجی را عیناً در دفترچه بگذار: `flutter analyze`، `dart format --output=none --set-exit-if-changed .`، `flutter test`.
در پایان دفترچه، یک جدول بستن ریشه‌ها بنویس: برای هر ریشهٔ P-A تا P-F، دقیقاً کدام تسک‌ها آن را بستند.
**مرز مطلق:** اگر حتی یک تسک `PARTIAL` باشد، در پایان دفترچه صریحاً بنویس کدام و چرا. هرگز کار ناتمام را `DONE` علامت نزن.
**معیار پذیرش:** هر سه دستور بدون خطا عبور می‌کنند و جدول ۵۰ سطری کامل است.
**تست:** اجرای کل مجموعهٔ تست
**commit:** `PRG-50: final pregnancy audit and ledger closure`

---

## جدول دفترچهٔ پیشرفت (عیناً در PRG-01 بساز)

مسیر فایل: `docs/cycle/PREGNANCY_SETUP_PROGRESS.md`
وضعیت‌های مجاز: `TODO` / `DOING` / `DONE` / `PARTIAL` / `SKIPPED` / `BLOCKED`
در لحطهٔ ساخت، همهٔ ۵۰ سطر باید `TODO` باشند و ستون commit خالی باشد.

| ID | عنوان | فاز | وضعیت | commit | یادداشت |
|---|---|---|---|---|---|
| PRG-01 | دفترچهٔ پیشرفت و پوشهٔ تست | A | TODO | | |
| PRG-02 | مدل‌های بارداری | A | TODO | | |
| PRG-03 | فاساد PregnancySettings | A | TODO | | بحرانی |
| PRG-04 | setPregnancyActive سه‌پرچمی | A | TODO | | |
| PRG-05 | hasValidDates و isPregnancyUsable | A | TODO | | بحرانی |
| PRG-06 | حذف نوشتن خام در cycle_screen | A | TODO | | |
| PRG-07 | موتور تاریخ بارداری | B | TODO | | |
| PRG-08 | اعتبارسنجی تاریخ | B | TODO | | |
| PRG-09 | قالب‌بندی فارسی سن | B | TODO | | |
| PRG-10 | dayShiftBetween | B | TODO | | |
| PRG-11 | حذف فالبک امروز و حالت خالی | B | TODO | | بحرانی |
| PRG-12 | کنترلر آنبوردینگ بارداری | C | TODO | | |
| PRG-13 | پوستهٔ آنبوردینگ بارداری | C | TODO | | |
| PRG-14 | اتصال onNavigateToPregnancy | C | TODO | | |
| PRG-15 | پارامتر onOpenPregnancyOnboarding | C | TODO | | |
| PRG-16 | دکمهٔ باردارم در حالت خالی | C | TODO | | |
| PRG-17 | اتصال دکمهٔ ترمیم | C | TODO | | |
| PRG-18 | گام ۱ لحن | D | TODO | | |
| PRG-19 | گام ۲ تاریخ سه‌مسیره | D | TODO | | بحرانی |
| PRG-20 | گام ۳ زمینهٔ بارداری | D | TODO | | |
| PRG-21 | گام ۴ حریم خصوصی | D | TODO | | |
| PRG-22 | گام ۵ تأیید | D | TODO | | |
| PRG-23 | ذخیرهٔ تراکنشی آنبوردینگ | D | TODO | | بحرانی |
| PRG-24 | جریان پس از ذخیره | D | TODO | | |
| PRG-25 | بازسیم‌کشی دکمهٔ فعالسازی | E | TODO | | بحرانی |
| PRG-26 | برچسب ردیف پنل تنطیمات | E | TODO | | |
| PRG-27 | توقف یادآوری پریود در بارداری | E | TODO | | |
| PRG-28 | توقف پیش‌بینی چرخه در بارداری | E | TODO | | |
| PRG-29 | پیاده‌سازی ویرایشگر پارامتر پایه | E | TODO | | باگ جانبی |
| PRG-30 | پوستهٔ شیت تنطیمات بارداری | F | TODO | | |
| PRG-31 | تاریخ زایمان قابل ویرایش | F | TODO | | |
| PRG-32 | لحن و واحد سن قابل نوشتن | F | TODO | | |
| PRG-33 | نشان تأیید پزشک در هدر | F | TODO | | |
| PRG-34 | تنطیمات مراقبت و یادآوری | F | TODO | | |
| PRG-35 | زمان‌بند یادآوری بارداری | F | TODO | | بحرانی |
| PRG-36 | پارامتری کردن لگدشماری | F | TODO | | |
| PRG-37 | اتصال دکمهٔ تنطیمات هدر | F | TODO | | |
| PRG-38 | اعمال پنهان‌سازی بخش | G | TODO | | |
| PRG-39 | یادآوری بازگشت چرخه | G | TODO | | |
| PRG-40 | اعمال قفل مستقل بارداری | G | TODO | | |
| PRG-41 | قاعدهٔ ادغام پوشش اعلان | G | TODO | | |
| PRG-42 | تست نگهبان کلیدها | G | TODO | | |
| PRG-43 | دقیق کردن متن سه مسیر پایان | H | TODO | | |
| PRG-44 | بازگردانی موافقت‌ها | H | TODO | | |
| PRG-45 | پاکسازی کلیدهای preg در ریست کامل | H | TODO | | تک تسک مجاز به حذف |
| PRG-46 | لغو یادآوری‌ها در پایان | H | TODO | | اولویت بالا |
| PRG-47 | پرسش مهاجرت کاربران بی‌تاریخ | I | TODO | | |
| PRG-48 | یکدست‌سازی پرچم‌های قدیمی | I | TODO | | |
| PRG-49 | مستند قرارداد دادهٔ بارداری | I | TODO | | |
| PRG-50 | بازرسی نهایی و بستن دفترچه | J | TODO | | |

---

## نقشهٔ بستن ریشه‌ها

این جدول معیار نهایی موفقیت است. اگر همهٔ ۵۰ تسک `DONE` باشند ولی یک ریشه بسته نشده باشد، کار تمام نیست.

| ریشه | شرح کوتاه | تسک‌های بستن | معیار قابل مشاهده |
|---|---|---|---|
| P-A | دکمهٔ فعالسازی فقط پرچم را وارونه می‌کند | PRG-04، PRG-06، PRG-25، PRG-26 | فشردن دکمه هرگز به تنهایی حالت را روشن نمی‌کند |
| P-B | تاریخ‌های بارداری هیچ‌جا نوشته نمی‌شوند | PRG-03، PRG-05، PRG-11، PRG-19، PRG-23 | هیچ کاربری هرگز هفتهٔ صفر نمی‌بیند |
| P-C | آنبوردینگ بارداری وجود ندارد | PRG-12 تا PRG-24 | هر چهار مسیر ورود به یک آنبوردینگ پنج‌گامی می‌رسند |
| P-D | صفحهٔ تنطیمات بارداری وجود ندارد | PRG-30 تا PRG-37 | دکمهٔ تنطیمات هدر به شیت شش‌بخشی می‌رود |
| P-E | کلیدهای یتیم (فقط خواندنی یا فقط نوشتنی) | PRG-32، PRG-33، PRG-38، PRG-39، PRG-40، PRG-41، PRG-42 | تست نگهبان سبز است و هر کلید حداقل یک خواننده دارد |
| P-F | بارداری پیش‌بینی و یادآوری پریود را متوقف نمی‌کند | PRG-23، PRG-27، PRG-28، PRG-44 | در بارداری صفر یادآوری پریودی و صفر روز پیش‌بینی‌شده |

---

## ترتیب اجباری اجرا

`A → B → C → D → E → F → G → H → I → J`

دلیل این ترتیب را بدان تا وسوسهٔ جابه‌جایی نشوی:
- فاز A لایهٔ داده را می‌سازد. بدون فاساد، هر فاز بعدی مجبور می‌شود نوشتن خام انجام دهد و همان بدهی فنی قدیمی تکرار می‌شود.
- فاز B محاسبات را می‌سازد. فاز D به موتور تاریخ و اعتبارسنجی وابسته است.
- فاز C پوسته می‌سازد و فاز D گام‌ها را درون آن جا می‌دهد. عکس این ترتیب یعنی گام‌های بی‌خانه.
- فاز E درها را به آنبوردینگ وصل می‌کند. اگر قبل از D انجام شود، کاربر به یک آنبوردینگ نیمه‌کاره می‌رسد.
- فاز F تنطیمات پس از راه‌اندازی است؛ معنا ندارد پیش از اینکه راه‌اندازی وجود داشته باشد.
- فاز G کلیدهایی را مصرف می‌کند که فازهای F و D تولید کرده‌اند.
- فاز H فقط وقتی امن است که زمان‌بند یادآوری (PRG-35) موجود باشد، وگرنه لغو کردن معنا ندارد.
- فاز I به همهٔ مسیرهای قبلی وابسته است چون کاربر مهاجر را به آنبوردینگ می‌فرستد.
- فاز J فقط بازرسی است و باید آخرین باشد.

در هر فاز، ترتیب عددی تسک‌ها را هم رعایت کن.

---

## یادآوری پایانی

این متن برنامهٔ پیاده‌سازی نیست که برایش نقشه بکشی. خودش نقشه است. پس:

۱. هیچ فایل برنامه‌ریزی تازه‌ای نساز. هیچ طرحی ننویس. هیچ شماره‌گذاری تازه‌ای ابداع نکن. فقط و فقط شناسه‌های PRG-01 تا PRG-50.
۲. پیش از هر تسک، فایل‌های ذکرشده در ستون «فایل‌ها» را کامل بخوان. هرگز حدس نزن که درون یک فایل چیست.
۳. پس از هر تسک، دفترچه را در همان کامیت به‌روز کن. دفترچهٔ به‌روزنشده یعنی تسک انجام‌نشده.
۴. در هیچ تسکی جز PRG-45 داده‌ای را حذف نکن. نه ردیف دوره، نه لاگ روزانه، نه جدول، نه کلید.
۵. در کل این پرامپت دقیقاً یک `TODO` مجاز است: همان `TODO PRG-35` در PRG-24 که در PRG-35 برداشته می‌شود. هیچ `TODO` دیگری در کد باقی نماند.
۶. مسیر لاگر را پر فایل بررسی کن. در این مخزن دو مسیر متفاوت لاگر وجود دارد و ایمپورت اشتباه باعث شکست بیلد می‌شود. هرگز ایمپورت تازه‌ای اضافه نکن — همان را که فایل دارد استفاده کن.
۷. هر متن کاربرپسند فارسی است و اعداد باید فارسی رندر شوند. از همان دو کمکی موجود در مخزن استفاده کن و کمکی تازه نساز.
۸. هر تسک یک کامیت مستقل با همان پیام ذکرشده. کامیت ترکیبی نزن.
۹. اگر در میانهٔ کار دیدی واقعیت مخزن با این متن یکی نیست (مثلاً نام یک متد عوض شده)، کار را متوقف نکن و طرح تازه ننویس. هدف همان تسک را با نام درست انجام بده و انحراف را در ستون یادداشت دفترچه بنویس.
۱۰. تا وقتی PRG-50 سبز نشده، کار تمام نیست. پیام پایانی نده تا هر ۵۰ سطر دفترچه تعیین‌وضعیت شوند.

این بخش برای مادران است. یک عدد اشتباه یا یک اعلان در زمان اشتباه، فقط یک باگ نیست. دقت کن.
