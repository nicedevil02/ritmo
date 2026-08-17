# پرامپت اجرایی: رفع کامل باگ‌ها و مشکلات ماژول «چرخه بدن» در پروژه Ritmo

> **مخزن:** `nicedevil02/ritmo` — شاخهٔ پیش‌فرض
> **دامنهٔ کار:** ماژول چرخه بدن (Cycle) و همهٔ نقاط اتصالش
> **مبنای بازبینی:** commit `acd5ec2`
> **نسخهٔ پرامپت:** 1.0

---

## ۰. قواعد اجرای اجباری — قبل از هر کاری این بخش را بخوان

1. **هیچ نقشهٔ پیاده‌سازی، رودمپ، طرح، برنامه یا فازبندی جدیدی نمی‌نویسی.** این فایل خودش نقشهٔ پیاده‌سازی نهایی و تأییدشده است. فازها، ترتیب، دامنه و معیار پذیرش همه در همین فایل قطعی شده‌اند.
2. **قاعدهٔ بند ۲ فایل `.agents/AGENTS.md` مخزن (چرخهٔ سه‌مرحله‌ای Draft → Evaluate → Rewrite رودمپ) برای این تسک صریحاً لغو است.** مستقیم برو سر اجرا. بند ۱ و ۳ همان فایل (تحلیل عمیق، عدم تنبلی، اجرای `flutter analyze`) به قوت خود باقی است.
3. **هیچ فایل markdown برنامه‌ریزی نساز** — نه `PLAN.md`، نه `ROADMAP.md`، نه `TODO.md`، نه `*_PLAN.md`، نه مستند طراحی جدید. تنها مستند مجاز، فایل گزارش نهایی است که در فاز ۸ مشخص شده.
4. **ترتیب فازها اجباری است.** فاز `N+1` را شروع نکن تا «گیت پذیرش» فاز `N` سبز نشده باشد.
5. **در پایان هر فاز این سه فرمان را اجرا کن و خروجی باید تمیز باشد:**
   ```
   flutter analyze
   flutter test
   dart format --set-exit-if-changed lib test
   ```
   اگر خطا یا warning داشتی همان‌جا رفعش کن. با کد شکسته به فاز بعد نرو.
6. **هر فاز = یک کامیت اتمیک** با پیام `fix(cycle): phase N — <خلاصه>`.
7. **سؤال نپرس و منتظر تأیید نمان.** جاهایی که دو راه‌حل ممکن بود، همان راه‌حلی را بردار که در متن این پرامپت با برچسب **«تصمیم قطعی»** مشخص شده. اگر تصمیم قطعی ذکر نشده، محافظه‌کارانه‌ترین گزینه‌ای را بردار که رفتار کاربران فعلی را نمی‌شکند و آن را در گزارش فاز ۸ ثبت کن.
8. **ممنوعیت `TODO` و کد جایگزین (placeholder).** هیچ `// TODO`، `throw UnimplementedError`، یا تابع خالی باقی نگذار.
9. **هیچ `catch (_) {}` جدیدی ننویس** و همهٔ موارد موجود در دامنهٔ کار را با `RitmoLogger` جایگزین کن (جزئیات در فاز ۰).
10. **رفتار کاربران فعلی نباید بشکند.** هر تغییر شِما یا کلید تنظیمات باید migration نسخه‌دار داشته باشد.
11. **هر باگ در این فایل با یک شناسه دارد (`C-01` … `C-48`).** در پیام کامیت و در کامنت کد اصلاحی، شناسه را ذکر کن تا قابل ردیابی باشد.

### فایل‌های تحت مالکیت این تسک

```
lib/core/domain/engines/cycle_engine.dart
lib/core/domain/engines/hormonal_intelligence_engine.dart
lib/core/domain/agenda/sources/cycle_agenda_source.dart
lib/core/services/cycle_notification_service.dart
lib/core/utils/cycle_privacy_guard.dart
lib/core/utils/cycle_consent_bridge.dart
lib/core/database/schema/tables/cycle_tables.dart
lib/core/database/seed/seed_service.dart                     (فقط کلیدهای cycle_*)
lib/core/database/migration/migrations_registry.dart         (افزودن migration جدید)
lib/features/cycle/**                                        (تمام درخت)
lib/features/profile/presentation/cycle_reminders_screen.dart
lib/features/profile/presentation/cycle_harmony_screen.dart
lib/l10n/app_fa.arb , lib/l10n/app_en.arb                    (کلیدهای cycle*)
test/cycle_engine_test.dart , test/cycle/**                  (+ فایل‌های تست جدید)
```

---

## فاز ۰ — ریل‌گذاری و زیرساخت سنجش

**هدف:** قبل از رفع باگ، ابزارهای تشخیص و قراردادهای پایه را بساز تا فازهای بعد قابل اثبات باشند.

### C-01 — ثبت وضعیت پایه و شناسایی تست شکسته
- `flutter analyze` و `flutter test` را اجرا کن و تعداد خطا/warning/تست‌های شکسته را برای مقایسه در فاز ۸ نگه دار.
- **تست شکستهٔ شناسایی‌شده:** در `test/cycle_engine_test.dart`، تست `returns fallback insights when logs are fewer than 3` انتظار `contains('کافی نیست')` دارد، در حالی که `CycleCorrelationAnalyzer` رشتهٔ `'داده‌های کافی برای محاسبه همبستگی ... وجود ندارد'` تولید می‌کند. رشتهٔ `کافی نیست` در آن متن **وجود ندارد**، پس این تست fail است. آن را در فاز ۷ به‌درستی اصلاح کن (اتصال به کلید l10n)، نه با عوض کردن انتظار به یک رشتهٔ دلخواه.

### C-02 — قرارداد قطعی تاریخ (Single Date Contract)
**تصمیم قطعی:** فایل جدید `lib/features/cycle/logic/cycle_date_contract.dart` بساز که تنها مرجع تاریخ ماژول چرخه باشد:
- `String toDayKey(DateTime d)` → همیشه `YYYY-MM-DD` بر مبنای تاریخ **محلی** (نه UTC، نه `toIso8601String()` روی DateTime محلی).
- `DateTime? parseDayKey(String? s)` → مقاوم به هر دو فرمت `YYYY-MM-DD` و ISO کامل؛ همیشه `DateTime(y, m, d)` برمی‌گرداند.
- `int daysBetween(DateTime a, DateTime b)` → تفاضل روز تقویمی، **مقاوم به DST**. از `difference().inDays` روی `DateTime` محلی استفاده نکن؛ از `DateTime.utc(y, m, d)` برای هر دو طرف استفاده کن تا تغییر ساعت رسمی خطای یک‌روزه نسازد.
- `bool isSameOrBefore / isSameOrAfter / inWindow(...)`.

سپس **هر** محاسبهٔ تاریخ در فایل‌های تحت مالکیت را به این utility منتقل کن. این الگوها باید در دامنهٔ کار به صفر برسند:
- `toIso8601String().substring(0, 10)`
- `DateTime.parse(...)` بدون `tryParse` روی دادهٔ پایگاه‌داده
- `DateTime(x.year, x.month, x.day)` تکراری و inline

### C-03 — حذف خطاهای خفه‌شده
- در `cycle_consent_bridge.dart` (۳ مورد)، `cycle_data_quality_engine.dart`، `cycle_personal_pattern_engine.dart` و `cycle_correlation.dart` تمام `catch (_) {}` را به `catch (e, st) { RitmoLogger.error(...); }` تبدیل کن.
- **مهم:** پیام لاگ نباید هیچ دادهٔ خام چرخه (تاریخ دوره، علائم، شدت جریان) را چاپ کند. فقط نام عملیات + نوع خطا. تست `test/logger_redaction_test.dart` نباید بشکند.

### C-04 — ابزار تشخیص داده
تابع `CycleDataDoctor.diagnose(db)` بساز که برمی‌گرداند: تعداد دوره‌های همپوشان، دوره‌های با `endDate < startDate`، دوره‌های با `endDate` در آینده، دوره‌های باز قدیمی‌تر از ۱۵ روز، ردیف‌های `cycle_logs` قدیمی که در `cycle_periods` معادل ندارند، و کلیدهای تنظیمات ناهمگام. این تابع در فاز ۲ برای migration و در فاز ۷ برای تست استفاده می‌شود.

### گیت پذیرش فاز ۰
- `cycle_date_contract.dart` وجود دارد و حداقل ۱۰ تست واحد دارد (شامل تست DST و تست فرمت مخلوط تاریخ).
- `grep -rn "catch (_) {}" lib/features/cycle lib/core/utils/cycle_* lib/core/domain/engines/cycle_engine.dart` هیچ نتیجه‌ای برنمی‌گرداند.
- `flutter analyze` تمیز.

---

## فاز ۱ — امنیت و حریم خصوصی (اولویت بحرانی، غیرقابل مذاکره)

**هدف:** ماژول چرخه حساس‌ترین دادهٔ اپ است و الان چند رخنهٔ جدی دارد. این فاز باید اول انجام شود.

### C-05 🔴 دور زدن کامل احراز هویت — `cycle_reminders_screen.dart`
**باگ:** متد `_onFingerprintTapped()` هیچ احراز هویتی انجام نمی‌دهد. فقط `setState(() { _isLocked = false; })` می‌زند. هر کسی با گرفتن گوشی و زدن دکمهٔ «ورود با اثر انگشت» به تمام دادهٔ خصوصی چرخه دسترسی پیدا می‌کند.
**رفع:** این متد باید از `local_auth` (`LocalAuthentication.authenticate`) استفاده کند و **فقط** در صورت `didAuthenticate == true` قفل را باز کند. در صورت عدم پشتیبانی دستگاه یا `kIsWeb`، قفل بسته بماند و پیام خطا نمایش داده شود — نه اینکه باز شود.

### C-06 🔴 ذخیرهٔ رمز به‌صورت متن ساده در پایگاه‌داده
**باگ‌ها:**
- `cycle_lock_gate.dart` علاوه بر `SecureKeyStore.setKey('cycle_lock_password', pin)`، همان PIN را با `SettingsService.instance.set('cycle_lock_password', _enteredPin)` در جدول `app_settings` **به‌صورت متن خام** می‌نویسد.
- `cycle_reminders_screen.dart` با `rawInsert` مقدار `app_lock_password` را خام در `app_settings` می‌نویسد و مقایسه هم با همان مقدار خام انجام می‌شود.
- `cycle_onboarding_controller.loadInitialData()` هم `settingsMap['cycle_lock_password']` را می‌خواند، که وجود این نشتی را تأیید می‌کند.

**رفع (تصمیم قطعی):**
- PIN **فقط و فقط** در `SecureKeyStore` و **هَش‌شده** نگهداری شود: KDF با salt تصادفی به‌ازای هر نصب (`PBKDF2`/`scrypt`؛ اگر پکیجی موجود نیست، `Hmac-SHA256` با salt ذخیره‌شده در SecureKeyStore و تعداد تکرار مناسب). مقایسه باید **constant-time** باشد.
- تمام نوشتن/خواندن PIN از `app_settings` حذف شود.
- در migration فاز ۲، کلیدهای `cycle_lock_password` و `app_lock_password` از `app_settings` **پاک شوند** (پس از یک‌بار مهاجرت به SecureKeyStore به‌صورت هَش‌شده).
- `loadInitialData()` فقط از وجود کلید در SecureKeyStore استنتاج کند که PIN تنظیم شده یا نه.

### C-07 🔴 ناسازگاری PIN اپ و PIN چرخه
**باگ:** در `cycle_lock_gate.dart` متغیر `hasPasswordSet` از `_settings['app_lock_password']` (رمز کل اپ) محاسبه می‌شود، اما تأیید رمز در `_onPinKeyTapped` با `SecureKeyStore.getKey('cycle_lock_password')` انجام می‌شود. نتیجه:
- کاربری که PIN اپ دارد ولی PIN چرخه ندارد: عنوان «این بخش خصوصی است — رمز را وارد کنید» می‌بیند، اما در واقع مسیر «ساخت PIN جدید» اجرا می‌شود و ۴ رقم اولش به‌عنوان رمز جدید ثبت می‌شود.
- کاربری که PIN چرخه دارد ولی PIN اپ ندارد: عنوان «تعیین رمز عبور جدید» می‌بیند در حالی که باید رمز موجودش را وارد کند.

همین منطق شکسته در `cycle_reminders_screen.dart` هم هست، که آنجا کلاً از `app_lock_password` استفاده می‌کند و **مستقیماً الزام `test/prompt_058/cycle_pin_independent_from_app_pin_test.dart` را نقض می‌کند.**

**رفع (تصمیم قطعی):** یک سرویس واحد `CycleLockService` در `lib/features/cycle/logic/cycle_lock_service.dart` بساز که تنها مرجع وضعیت قفل چرخه است و این API را بدهد:
`isLockEnabled()`, `hasCyclePin()`, `verifyPin(String)`, `setPin(String)`, `clearPin()`, `authenticateBiometric()`, `remainingLockoutSeconds()`.
هم `CycleLockGate` و هم `CycleRemindersScreen` **فقط** از این سرویس استفاده کنند. PIN چرخه هیچ‌گاه با PIN اپ اشتراک یا fallback نداشته باشد.

### C-08 🔴 نبود محدودیت تلاش (brute force)
**باگ:** PIN چهاررقمی است، بازخورد فوری است، و هیچ شمارندهٔ تلاش، تأخیر، یا قفل موقتی وجود ندارد. کل فضای ۱۰٬۰۰۰ حالته با دست قابل پیمایش است.
**رفع:** در `CycleLockService`:
- شمارندهٔ تلاش ناموفق در SecureKeyStore (نه در `app_settings`).
- پس از ۵ تلاش ناموفق: قفل ۳۰ ثانیه‌ای؛ ۱۰ تلاش: ۵ دقیقه؛ ۱۵ تلاش: ۳۰ دقیقه (backoff نمایی با سقف).
- زمان پایان قفل به‌صورت timestamp ذخیره شود تا با kill کردن اپ ری‌ست نشود.
- شمارنده پس از ورود موفق صفر شود.
- UI زمان باقی‌مانده را نمایش دهد و کیپد را غیرفعال کند.

### C-09 🟠 نشت محتوا از زیر لایهٔ قفل — `cycle_lock_gate.dart`
**باگ‌ها:**
- `IgnorePointer(ignoring: _isLocked, child: widget.child)` — فرزند (صفحهٔ واقعی چرخه) در حالت قفل هم **ساخته و رندر می‌شود**؛ فقط با `BackdropFilter` تار شده. محتوا در درخت ویجت و در درخت Semantics حاضر است و برای screen reader خواناست؛ همچنین کوئری‌های پایگاه‌دادهٔ صفحهٔ چرخه در حالت قفل اجرا می‌شوند.
- `didChangeAppLifecycleState` فقط روی `AppLifecycleState.paused` قفل می‌کند. در iOS اسنپ‌شات سوئیچر اپ در `inactive` گرفته می‌شود، پس محتوای خصوصی **قبل از** ظاهر شدن لایهٔ قفل در اسنپ‌شات ثبت می‌شود.
- هیچ محافظتی در برابر اسکرین‌شات/ضبط صفحه نیست.

**رفع:**
- در حالت قفل، `widget.child` **ساخته نشود** (به‌جای `IgnorePointer` از شرط `if (!_isLocked) widget.child` استفاده کن) و بارگذاری دادهٔ صفحهٔ چرخه تا باز شدن قفل شروع نشود.
- محتوا در حالت قفل با `ExcludeSemantics` هم پوشش داده شود.
- قفل شدن روی `inactive`، `hidden`، `paused` و `detached` هر چهار حالت اتفاق بیفتد.
- روی اندروید `FLAG_SECURE` و روی iOS پوشش اسنپ‌شات برای مسیر چرخه فعال شود (اگر زیرساخت پلتفرمی در پروژه هست از آن استفاده کن؛ اگر نه، حداقل به‌صورت شرطی برای مسیرهای چرخه پیاده کن).
- **تصمیم قطعی:** پیش‌فرض `lockEnabled = settings['cycle_lock_enabled'] != 'false'` را نگه دار (fail-secure)، اما مسیر «هنوز PIN نداری» را طوری اصلاح کن که کاربر بتواند صریحاً «فعلاً قفل نمی‌خواهم» را انتخاب کند و آن انتخاب به‌صورت `'false'` نوشته شود — نه اینکه مجبور به ساخت PIN شود.

### C-10 🟠 نشت اطلاعات از طریق نوتیفیکیشن — `cycle_notification_service.dart`
**باگ‌ها:**
- `showImmediateNotification` روی کانال `NotificationChannelId.planning` (کانال عمومی) با `title`/`body` بدون redaction ارسال می‌کند، در حالی که یادآورهای دوره درست روی `privateChannel` با `NotificationPrivacy.redacted` هستند. این تابع در سرویس چرخه است ولی `sourceSystem: 'backup'` دارد — یعنی یک تابع بی‌ارتباط داخل سرویس حساس.
- `cancelAll()` و `scheduleReminders()` از دو شناسهٔ متفاوت `NotificationIds.cyclePeriod` و `NotificationIds.cyclePill` استفاده می‌کنند؛ استفاده از `cyclePill` برای یادآور دوره باعث برخورد شناسه با یادآورهای واقعی دارو/قرص و لغو ناخواستهٔ آن‌ها می‌شود.

**رفع:**
- `showImmediateNotification` را از این سرویس **بیرون ببر** به سرویس مربوط به backup.
- هر دو یادآور دوره را با namespace شناسهٔ اختصاصی چرخه بساز (`cycle_period_t2`, `cycle_period_t1`) و از `NotificationIds.cyclePill` در مسیر چرخه استفاده نکن.
- متن نوتیفیکیشن‌ها هم در حالت `redacted` و هم غیر آن نباید کلمهٔ پریود/قاعدگی داشته باشد (الگوی موجود در `bodyRhythmInfluence` که در تست هم چک شده را حفظ کن).

### C-11 🟡 منطق شکنندهٔ تشخیص جنسیت — `cycle_privacy_guard.dart`
**باگ:** `isVisible` مقدار سه کلید (`user_gender`, `ss_onboarding_gender`, `profile_gender`) را با هم concat می‌کند و `contains('FEMALE'|'WOMAN'|'ZAN'|'زن')` می‌زند. نتیجه:
- اگر یک کلید `MALE` باشد و یک کلید قدیمی و بی‌اعتبار `FEMALE`، خروجی `true` می‌شود.
- تطبیق زیررشته‌ای است: هر مقداری که `ZAN` یا `زن` را در خود داشته باشد (مقادیر آزاد یا localized) اشتباه تشخیص داده می‌شود.
- هیچ حالت «نامشخص/نگفتم» وجود ندارد.

**رفع:** یک enum قطعی (`CycleAudience { eligible, notEligible, unknown }`) و **یک کلید متعارف** (`user_gender`) تعریف کن. تطبیق باید **دقیق** باشد (`==` روی مقادیر نرمال‌شدهٔ مجاز)، نه `contains`. دو کلید دیگر فقط در migration یک‌بار به کلید متعارف مهاجرت شوند و بعد از آن خوانده نشوند. برای `unknown` ماژول مخفی بماند (fail-closed).

### گیت پذیرش فاز ۱
- تست جدید: زدن دکمهٔ بیومتریک در حالت شکست/عدم پشتیبانی، قفل را باز **نمی‌کند**.
- تست جدید: `SELECT * FROM app_settings WHERE key IN ('cycle_lock_password','app_lock_password')` پس از migration خالی است.
- تست جدید: PIN چرخه و PIN اپ کاملاً مستقل‌اند (تست `prompt_058` پاس می‌شود) و PIN چرخه هَش‌شده ذخیره می‌شود (مقدار ذخیره‌شده برابر PIN خام نیست).
- تست جدید: پس از ۵ تلاش ناموفق، `verifyPin` با PIN صحیح هم تا پایان lockout رد می‌شود.
- تست ویجت: در حالت قفل، هیچ ویجتی از صفحهٔ چرخه در درخت نیست.
- `isVisible` با `{user_gender: 'MALE', profile_gender: 'FEMALE'}` مقدار «مجاز نیست» برمی‌گرداند.

---

## فاز ۲ — یکپارچگی داده، شِما و مهاجرت

**هدف:** ماژول چرخه در حال حاضر روی سه جدول موازی و چهار خانوادهٔ کلید تنظیمات ناهمگام سوار است. تا این لایه یکپارچه نشود، هیچ رفع باگی در موتور پایدار نمی‌ماند.

### C-12 🔴 سه جدول موازی و متناقض
**وضعیت موجود** (`lib/core/database/schema/tables/cycle_tables.dart`):
- `cycle_logs` (نسخهٔ V2، legacy) — ستون‌های `cycleStartDate`, `cycleEndDate`
- `cycle_periods` (نسخهٔ V14، متعارف) — ستون‌های `startDate`, `endDate`
- `cycle_day_logs` (نسخهٔ V14) — ثبت روزانه

**باگ‌های ناشی از آن:**
- `CycleConsentBridge.isUserMenstruating()` هر سه منبع را OR می‌کند. یک ردیف قدیمیِ باقی‌مانده در `cycle_logs` می‌تواند تعلیق عبادت (نماز/روزه) را **پس از حذف دوره در `cycle_periods`** هم فعال نگه دارد. این باگ اثر فقهی/عملی مستقیم دارد و شدیدترین باگ دادهٔ ماژول است.
- `cycle_reminders_screen.dart` تاریخچه را از `DatabaseHelper.getCycleLogs()` (جدول legacy) می‌خواند، در حالی که هیچ‌جای اپ دیگر در آن نمی‌نویسد → تاریخچه همیشه خالی است.
- همان صفحه، کفایت داده را با `DataMaturityEngine.hasEnoughDataForCyclePrediction(_cycleLogs.length)` می‌سنجد → همیشه «در حال شناخت ریتم شما» نمایش می‌دهد، حتی برای کاربری با ۱۲ دورهٔ ثبت‌شده در `cycle_periods`.

**رفع (تصمیم قطعی):**
1. `cycle_periods` تنها منبع حقیقت دوره‌ها و `cycle_day_logs` تنها منبع حقیقت ثبت روزانه اعلام می‌شود.
2. migration نسخه‌دار جدید بنویس که ردیف‌های `cycle_logs` را به `cycle_periods` منتقل کند (نگاشت `cycleStartDate→startDate`, `cycleEndDate→endDate`, `flowLevel→flowIntensity`, `note→note`)، duplicate‌ها را بر مبنای `startDate` ادغام کند، سپس `cycle_logs` را **drop** کند.
3. `CycleConsentBridge` مسیر مرحلهٔ ۳ (خواندن `cycle_logs`) را حذف کند.
4. `DatabaseHelper.getCycleLogs()` و هر مصرف‌کننده‌اش به `cycle_periods` منتقل شوند.

### C-13 🔴 چهار خانوادهٔ کلید تنظیمات برای دو مقدار
طول چرخه و طول دورهٔ خونریزی الان با این کلیدها نوشته/خوانده می‌شوند:

| کلید | نویسنده | خواننده |
|---|---|---|
| `cycle_avg_length` / `cycle_avg_period` | `cycle_onboarding_controller`, `cycle_screen` | `CycleEngine` (متعارف) |
| `user_cycle_length` / `user_period_length` | `cycle_onboarding_controller` (mirror) | — (نوشته می‌شود، خوانده نمی‌شود) |
| `cycle_length_days` / `period_duration_days` | `seed_service`, `migrations_registry`, `cycle_harmony_screen` | `cycle_harmony_screen`, `cycle_reminders_screen`, `pregnancy_section` |

**نتیجه:** کاربر در `cycle_harmony_screen` طول چرخه را عوض می‌کند → `cycle_length_days` نوشته می‌شود → `CycleEngine` که `cycle_avg_length` می‌خواند هیچ تغییری نمی‌بیند. برعکسش هم درست است. مهاجرت یک‌طرفهٔ داخل `cycle_screen.dart` (که در یک فایل UI انجام شده) فقط وقتی کار می‌کند که `cycle_avg_length` **غایب** باشد.
همین مشکل برای بارداری تکرار شده: هم `cycle_pregnancy_mode` و هم `cycle_is_pregnant` نوشته می‌شوند و مصرف‌کننده‌های مختلف یکی‌شان را می‌خوانند.

**رفع (تصمیم قطعی):**
1. کلیدهای متعارف: `cycle_avg_length`, `cycle_avg_period`, `cycle_pregnancy_mode`, `cycle_pms_window_days`.
2. یک façade به نام `CycleSettings` در `lib/features/cycle/logic/cycle_settings.dart` بساز که تنها راه خواندن/نوشتن این مقادیر باشد (با clamp و اعتبارسنجی داخلی: طول چرخه ۲۱..۴۵، طول دوره ۳..۱۰، پنجرهٔ PMS ۱..۷).
3. migration: مقادیر کلیدهای legacy را به کلید متعارف منتقل کن (اولویت: آخرین `updatedAt`)، سپس کلیدهای legacy را حذف کن.
4. هیچ فایلی جز `CycleSettings` این کلیدها را با رشتهٔ خام نخواند. مهاجرت inline داخل `cycle_screen.dart` حذف شود.
5. پیش‌فرض طول دورهٔ خونریزی همه‌جا `6` باشد؛ مقدار `7` سخت‌کدشده در `cycle_reminders_screen` و `cycle_harmony_screen` اصلاح شود.

### C-14 🟠 نبود قید و ایندکس در شِما
**باگ‌ها در `cycle_tables.dart`:**
- `cycle_periods` هیچ ایندکسی روی `startDate` ندارد (در حالی که `cycle_logs` legacy داشت) و هر کوئری موتور، scan کامل است.
- هیچ قید `UNIQUE` روی `startDate` نیست → دو دوره با تاریخ شروع یکسان قابل ثبت است.
- هیچ `CHECK` برای `endDate >= startDate` نیست.
- هیچ جلوگیری از **همپوشانی** دوره‌ها نیست.
- `createdAt`/`updatedAt` در `cycle_periods` و `cycle_day_logs` `NOT NULL` نیستند (در `cycle_logs` بودند) → ناهمگونی.
- فرمت تاریخ در `startDate` مخلوط است (`YYYY-MM-DD` از onboarding، ISO کامل از مسیرهای دیگر). این کوئری `where: 'startDate <= ?', whereArgs: ['${targetStr}T23:59:59']` در `CycleConsentBridge` را می‌شکند، چون مقایسه لغت‌نگارانه است و `'2026-06-20'` با `'2026-06-20T10:00:00'` رفتار متفاوت دارد.

**رفع:**
- migration: ایندکس روی `cycle_periods(startDate)` و `cycle_day_logs(logDate)`؛ `UNIQUE` روی `cycle_periods(startDate)`؛ `NOT NULL DEFAULT` برای `createdAt`/`updatedAt`.
- تمام مقادیر `startDate`/`endDate`/`logDate` موجود را در migration به فرمت متعارف `YYYY-MM-DD` نرمال کن.
- یک لایهٔ repository (`CyclePeriodRepository`) بساز که در `insert`/`update` همپوشانی و `endDate < startDate` را رد کند و خطای معنادار برگرداند. هیچ کد UI مستقیماً `db.insert('cycle_periods', ...)` نزند.
- کوئری‌های `CycleConsentBridge` را به مقایسهٔ روی dayKey متعارف تبدیل کن.

### C-15 🟠 ثبت دادهٔ نامعتبر در onboarding — `cycle_onboarding_controller.dart`
**باگ‌ها:**
- **تاریخ پایان در آینده:** در حالت `endedWithKnownStart`، مقدار `endDate = startDate + periodDuration - 1` بدون clamp به «امروز» نوشته می‌شود (کامنت کد این را عمدی می‌داند). نتیجه: موتور برای روزهای آیندهٔ نزدیک `isBleeding = true` می‌دهد و `isUserMenstruating` هم `true` برمی‌گرداند → تعلیق نادرست عبادت برای روزهایی که کاربر اصلاً خونریزی نداشته.
- **کوئری idempotency خطرناک:** `where: 'note LIKE ? OR startDate = ?'` با `'%ثبت اولیه%'` **هر** ردیفی را که یادداشتش «ثبت اولیه» است می‌گیرد و در حالت edit، `existing.first` را (بدون `ORDER BY`) آپدیت می‌کند → ممکن است ردیف اشتباه بازنویسی شود.
- **no-op خاموش:** در حالت غیر-edit، اگر ردیف منطبق وجود داشته باشد هیچ کاری نمی‌کند؛ کاربر تاریخ شروع را در ویزارد عوض می‌کند و هیچ اتفاقی نمی‌افتد و هیچ پیامی نمی‌بیند.
- **عدم زمان‌بندی یادآور:** بعد از ذخیرهٔ `cycle_consent_reminders = true` هیچ‌جا `CycleNotificationService.scheduleReminders` صدا زده نمی‌شود → کاربر یادآور را روشن می‌کند و هیچ نوتیفیکیشنی نمی‌گیرد.
- **استنتاج مبهم قفل:** `lockEnabled = lockSetting == 'true' || (lockSetting != 'false' && hasPin) || biometric == 'true'` سه‌حالتی و مبهم است و PIN را از `app_settings` می‌خواند (نقض فاز ۱).

**رفع:**
- `endDate` را به `min(startDate + duration - 1, today)` clamp کن. **تصمیم قطعی:** درستی داده (عدم تعلیق نادرست عبادت) بر «حفظ آمار طول دوره» مقدم است؛ برای جبران، دوره‌های clamp‌شدهٔ ناقص را با فلگ `isTruncated` علامت بزن و از میانگین‌گیری طول دوره کنار بگذار — نه اینکه تاریخ آینده بنویسی.
- کوئری idempotency را با یک شناسهٔ پایدار جایگزین کن: ردیف اولیهٔ راه‌اندازی همیشه `id = 'period_onboarding_seed'` باشد و upsert بر مبنای همان `id` انجام شود. `note LIKE` را کاملاً حذف کن.
- در حالت غیر-edit با ردیف موجود، ردیف را **آپدیت** کن (نه no-op) و در صورت تناقض به کاربر بازخورد بده.
- بعد از `saveOnboarding` موفق، زمان‌بندی یادآورها را با خروجی تازهٔ موتور اجرا کن.
- منطق قفل را به `CycleLockService` (فاز ۱) واگذار کن و منطق سه‌حالتی را حذف کن.

### گیت پذیرش فاز ۲
- migration نسخه‌دار جدید نوشته شده، تست migration دارد (روی یک DB با `cycle_logs` پرشده، کلیدهای legacy، و تاریخ‌های فرمت مخلوط) و idempotent است (دو بار اجرا = یک نتیجه).
- `cycle_logs` دیگر وجود ندارد و `grep -rn "cycle_logs" lib` هیچ نتیجهٔ فعالی ندارد.
- `grep -rn "cycle_length_days\|period_duration_days\|user_cycle_length\|user_period_length\|cycle_is_pregnant" lib` فقط داخل فایل migration نتیجه دارد.
- تست: تغییر طول چرخه در `cycle_harmony_screen` بلافاصله در خروجی `CycleEngine` منعکس می‌شود.
- تست: `CyclePeriodRepository` درج دورهٔ همپوشان و `endDate < startDate` را رد می‌کند.
- تست: onboarding با `endedWithKnownStart` و تاریخ شروع ۲ روز پیش، `endDate` در آینده نمی‌نویسد.

---

## فاز ۳ — صحت موتور محاسباتی `CycleEngine`

**فایل:** `lib/core/domain/engines/cycle_engine.dart`

### C-16 🔴 کش بی‌اثر — پیش‌بینی کهنه تا ۶۰ دقیقه
**باگ:** `ttl` برابر ۶۰ دقیقه است، اما `fingerprint(input)` فقط از `dayStamp` و سه کلید تنظیمات ساخته می‌شود و **هیچ ردی از دادهٔ دوره‌ها ندارد**. `invalidate()` هم بدنهٔ خالی دارد. پس وقتی کاربر یک دوره ثبت/ویرایش/حذف می‌کند، داشبورد و agenda تا یک ساعت دادهٔ قبلی را نشان می‌دهند.
**رفع:**
- `fingerprint` باید امضای دادهٔ دوره‌ها را هم شامل شود: `count` + `max(updatedAt)` + `max(startDate)` + هش سبک از جفت‌های `(startDate, endDate)`. برای این کار قبل از ساخت fingerprint یک کوئری سبک aggregate بزن.
- `invalidate()` را واقعاً پیاده کن (پاک کردن ورودی کش).
- در `CyclePeriodRepository` (فاز ۲) بعد از هر نوشتن، invalidate موتور و اعلان تغییر به `RitmoEngineBus` انجام شود.

### C-17 🔴 پنجرهٔ پیش‌بینی منفجر می‌شود
**باگ:** در `_evaluateWithStart`:
```dart
final k = cyclesElapsedForPrediction;
nextPeriodWindowStart = cleanStart.add(Duration(days: k * minL));
nextPeriodWindowEnd   = cleanStart.add(Duration(days: k * maxL));
```
ضرب `k` در `minL` و `maxL` باعث می‌شود پهنای پنجره خطی با `k` رشد کند. برای کاربری با `k = 3`, `minL = 25`, `maxL = 40` پنجره ۴۵ روزه می‌شود — بی‌معنی. این پنجره مبنای زمان‌بندی نوتیفیکیشن و آیتم‌های agenda هم هست.
**رفع:** پنجره باید حول **همان یک چرخهٔ بعدی** لنگر بیندازد:
```
anchor = cleanStart + (k - 1) * L
windowStart = anchor + minL
windowEnd   = anchor + maxL
```
و پهنای پنجره را به سقفی معقول (حداکثر ۷ روز، متقارن حول `nextPeriodPrediction`) clamp کن. حالت `cycleLengths.isEmpty` همان `±۲ روز` فعلی بماند.

### C-18 🔴 گزارش نادرست تأخیر (overdue)
**باگ:**
```dart
final missedBoundaries = (daysSinceStart / L).floor();
final rawOverdueDays = daysSinceStart - missedBoundaries * L;
```
`daysOverdue` فقط فاصله از **آخرین** مرز مورد انتظار را می‌شمارد. کاربری که ۶۰ روز از آخرین دوره‌اش گذشته (با `L = 28`) پیام «۴ روز تأخیر» می‌بیند، در حالی که واقعاً ۳۲ روز از اولین مرز مورد انتظار گذشته است. برای یک اپ سلامت، گمراه‌کننده و بالقوه خطرناک.
**رفع:** `daysOverdue` را از **اولین** مرز مورد انتظار بشمار (`daysSinceStart - L`) و یک فیلد جداگانهٔ `missedCycles` اضافه کن. اگر `missedCycles >= 2` یا `daysOverdue >= 45`، یک وضعیت `CyclePhase.dataStale` (یا فلگ `needsUserAttention`) برگردان و **پیش‌بینی فاز را متوقف کن** — با دادهٔ ۶۰ روزه نمی‌توان گفت کاربر در فاز لوتئال است.

### C-19 🟠 فاز تخمک‌گذاری در چرخه‌های کوتاه هرگز رخ نمی‌دهد
**باگ:** `ovulationDayNum = L - 14`. برای `L = 21` این عدد `7` است و پنجرهٔ تخمک‌گذاری `[6, 8]` می‌شود. اما اگر `pDuration` (که تا `10` مجاز است) بزرگ‌تر یا مساوی `8` باشد، شرط `isBleeding` تمام آن روزها را می‌گیرد و `phase` هرگز `ovulation` نمی‌شود. علاوه بر این:
- `fertileWindowStart = prediction - 19` و `fertileWindowEnd = prediction - 14` یعنی پنجرهٔ باروری **در روز تخمک‌گذاری تمام می‌شود**، در حالی که پنجرهٔ باروری فیزیولوژیک تا ~۱ روز پس از تخمک‌گذاری ادامه دارد.
- برای `L = 21` مقدار `prediction - 19` دو روز پس از شروع چرخه است؛ یعنی پنجرهٔ باروری با روزهای خونریزی همپوشانی پیدا می‌کند.

**رفع:**
- طول فاز لوتئال را به یک ثابت نام‌دار تبدیل کن و برای چرخه‌های کوتاه متناسب کوتاهش کن. **تصمیم قطعی:** `lutealDays = min(14, L - 10)` تا فاز فولیکولار همیشه حداقل ۱۰ روز بماند.
- پنجرهٔ باروری: `[ovulation - 5, ovulation + 1]` و سپس clamp به بازهٔ پس از پایان خونریزی.
- اولویت فاز: `menstrual` بر همه مقدم است، اما اگر همپوشانی رخ داد باید در خروجی صریحاً `hasPhaseConflict = true` علامت بخورد و در فاز ۶ به کاربر «دادهٔ متناقض» نمایش داده شود.

### C-20 🟠 دو تعریف متناقض از «نظم چرخه» در یک تابع
**باگ:**
- `isIrregular = (maxL - minL) >= 7` با شرط `cycleLengths.length >= 3`
- `regularityLabel = range <= 4 ? 'نسبتاً منظم' : 'نامنظم'` با شرط `totalRecordedCycles >= 2`
- `regularityScore = 100 - (sd * 12).round()`

برای کاربری با `range = 5`: `isIrregular = false` (منظم) اما `regularityLabel = 'نامنظم'`. سه معیار مستقل، سه پاسخ.
بدتر: `sd` با مقدار پیش‌فرض `2.0` و `regularityScore` با `100` مقداردهی می‌شوند؛ اگر `cycleLengths.length < 3` باشد، هیچ‌کدام بازنویسی نمی‌شوند → کاربری با یک ردیف دوره، امتیاز نظم `100` می‌گیرد در حالی که برچسبش «دادهٔ ناکافی» است. UI متناقض.
ضریب `12` هم یک عدد جادویی بدون مبنای مستند است (`sd > 8.3` → امتیاز صفر).

**رفع:** یک تابع خصوصیِ واحد `_computeRegularity(cycleLengths)` بساز که شیء `CycleRegularity { score, level, isIrregular, sampleSize, isComputable }` برگرداند و **هر سه** خروجی از آن مشتق شوند. قواعد:
- `sampleSize < 3` → `isComputable = false`, `score = null`, `level = insufficientData`, `isIrregular = false`.
- معیار عددی از انحراف معیار، اما نرمال‌سازی مستند و نام‌دار (`_regularitySdPenalty`) و آستانه‌ها ثابت نام‌دار.
- `isIrregular` و `level` از **یک** آستانه مشتق شوند.
- `score` نباید `int` غیر-nullable با پیش‌فرض ۱۰۰ باشد؛ `int?` شود.

### C-21 🟠 آمار «تعداد چرخه» اشتباه است
**باگ:** `totalRecordedCycles = periodRows.length` تعداد **رکورد دوره** را می‌شمارد، نه تعداد **چرخهٔ کامل**. با یک رکورد مقدار `1` است در حالی که هیچ چرخهٔ کاملی اندازه‌گیری نشده (چرخه از فاصلهٔ بین دو شروع به دست می‌آید). تمام آستانه‌های `dataMaturity` (`>=3` → MEDIUM، `>6` → HIGH) و `hasEnoughCycles` روی این عدد اشتباه بنا شده‌اند و بلوغ داده را یک واحد بیش‌برآورد می‌کنند.
**رفع:** دو فیلد جدا: `recordedPeriods` (تعداد رکورد) و `completedCycles` (`= cycleLengths.length`). همهٔ آستانه‌های بلوغ و اعتبار پیش‌بینی روی `completedCycles` محاسبه شوند. `CycleStats` را به‌شکل breaking تغییر بده و همهٔ مصرف‌کننده‌ها را اصلاح کن.

### C-22 🟠 ناسازگاری فیلتر پرت (outlier) با clamp
**باگ:** فیلتر پذیرش طول چرخه `15..50` است، اما `L` نهایی به `21..45` clamp می‌شود. مقادیر پرت ۱۵–۲۰ و ۴۶–۵۰ همچنان در میانگین می‌مانند و — مهم‌تر — `minL`/`maxL` که مبنای پنجرهٔ پیش‌بینی‌اند **بدون clamp** از همان لیست گرفته می‌شوند. یک چرخهٔ ۵۰ روزهٔ خطاثبت‌شده، پنجرهٔ پیش‌بینی را برای همیشه خراب می‌کند.
**رفع:** یک بازهٔ پذیرش واحد (`_minPlausibleCycle = 21`, `_maxPlausibleCycle = 45`) تعریف کن و همه‌جا (فیلتر، میانگین، `minL`/`maxL`, `trendPoints`) از آن استفاده کن. علاوه بر آن، برای `minL`/`maxL` از صدک‌های ۱۰ و ۹۰ (یا IQR) به‌جای min/max خام استفاده کن تا یک پرت تنها پنجره را نبلعد. تعداد مقادیر ردشده را در `discardedOutliers` برگردان تا UI بتواند بگوید «۲ ثبت نامعتبر نادیده گرفته شد».

### C-23 🟠 معنای متناقض `dayOfCycle`
**باگ:** در شاخهٔ خونریزی، `dayOfCycle = (daysSinceStart % L) + 1` (باقی‌مانده‌ای، پس ری‌ست می‌شود)؛ در شاخهٔ غیرخونریزی، `dayOfCycle = cleanNow.difference(currentPredictedStart).inDays + 1` (بدون باقی‌مانده، پس می‌تواند از `L` بیشتر شود). دو معنای مختلف برای یک فیلد. اگر دوره‌ای با `endDate` طولانی‌تر از `L` ثبت شده باشد، شاخهٔ خونریزی عدد wrap شده می‌دهد.
**رفع:** یک تعریف قطعی: `dayOfCycle` = روز شمرده‌شده از **شروع چرخهٔ جاری** بدون باقی‌مانده، و اگر از `L` عبور کرد همان عدد بزرگ‌تر برگردد (که همراه با `isOverdue` معنا پیدا می‌کند). این محاسبه یک بار قبل از شاخه‌بندی انجام شود، نه دو بار با دو فرمول.

### C-24 🟠 `dayOfPeriod` بی‌سقف
**باگ:** وقتی `endDate != null`, مقدار `dayOfPeriod = daysSinceStart + 1` بدون هیچ سقفی محاسبه می‌شود. با یک `endDate` خطاثبت‌شدهٔ دور، «روز ۴۷ قاعدگی» نمایش داده می‌شود.
**رفع:** `dayOfPeriod` را به سقف فیزیولوژیک (`_maxPlausiblePeriodDays = 15`) clamp کن و در صورت عبور، فلگ `hasImplausiblePeriodData = true` برگردان.

### C-25 🟠 خروجی خالیِ جعلی
**باگ:** `_emptyOutput` با `hasData: false` مقدار `nextPeriodPrediction = now + 14 days` و پنجره‌های ساختگی برمی‌گرداند. هر مصرف‌کننده‌ای که `hasData` را چک نکند، یک پیش‌بینی کاملاً ساختگی نمایش می‌دهد. مصداق واقعی: `HormonalIntelligenceEngine` برای `noData` مقدار `nextCycleStartDate: now` می‌دهد و `cycle_reminders_screen` از آن `daysToNext` می‌سازد.
**رفع (تصمیم قطعی):** فیلدهای پیش‌بینی را nullable کن (`DateTime?`) و در `_emptyOutput` همه را `null` بگذار. همهٔ مصرف‌کننده‌ها را وادار کن حالت null را مدیریت کنند. این تغییر breaking است — همهٔ فراخوان‌ها را اصلاح کن.

### C-26 🟡 حالت fallback «همهٔ دوره‌ها در آینده»
**باگ:** وقتی `currentPeriodRow == null`، موتور با `cyclesToSubtract = (daysDiff / L).ceil()` یک تاریخ شروع **ساختگی** در گذشته می‌سازد و بعد از آن، خروجی دقیقاً مثل دادهٔ واقعی برگردانده می‌شود — بدون هیچ نشانه‌ای که این داده تخمینی است.
**رفع:** در این حالت `isProjected = true` (یا `dataOrigin: projected`) برگردان و در UI فاز ۶ صریحاً «تخمینی» برچسب بخورد. همچنین اگر همهٔ دوره‌ها در آینده‌اند، این خودش یک دادهٔ نامعتبر است — از `CycleDataDoctor` استفاده کن و به کاربر پیشنهاد اصلاح بده.

### C-27 🟡 نشت رشتهٔ UI به لایهٔ موتور
**باگ:** `regularityLabel` و `predictionDisclaimer` رشتهٔ فارسی سخت‌کدشده داخل موتور دامنه‌اند (متن disclaimer دو بار تکرار شده: در `_evaluateWithStart` و `_emptyOutput`). هم نقض لایه‌بندی است و هم مانع l10n.
**رفع:** موتور باید enum/کد برگرداند (`RegularityLevel`, `DisclaimerCode`) و ترجمه در لایهٔ presentation از `AppLocalizations` خوانده شود. (پیاده‌سازی l10n در فاز ۶.)

### گیت پذیرش فاز ۳
تست‌های واحد زیر در `test/cycle/cycle_engine_*_test.dart` نوشته و پاس شوند:
1. ثبت دورهٔ جدید → fingerprint تغییر می‌کند و خروجی کش‌شده بی‌اعتبار می‌شود.
2. `k = 3` → پهنای `nextPeriodWindow` حداکثر ۷ روز است.
3. `daysSinceStart = 60`, `L = 28` → `daysOverdue == 32` و `missedCycles == 2` و موتور پیش‌بینی فاز نمی‌دهد.
4. `L = 21`, `pDuration = 10` → فاز `ovulation` در طول چرخه قابل دستیابی است.
5. `range = 5` → `isIrregular` و `regularityLabel` هم‌داستان‌اند.
6. یک ردیف دوره → `completedCycles == 0`, `regularityScore == null`, `dataMaturity == 'LOW'`.
7. یک چرخهٔ ۵۰ روزه در تاریخچه → پنجرهٔ پیش‌بینی خراب نمی‌شود و `discardedOutliers == 1`.
8. `endDate` نامعتبر دور → `dayOfPeriod <= 15` و `hasImplausiblePeriodData == true`.
9. `_emptyOutput` → همهٔ فیلدهای پیش‌بینی `null` هستند.
10. تست DST: چرخه‌ای که از تغییر ساعت رسمی عبور می‌کند، `dayOfCycle` را یک روز جابجا نمی‌کند.

---

## فاز ۴ — موتورهای هوشمند و اعتبار آماری

### C-28 🔴 اعتبار آماری همبستگی‌ها — `lib/features/cycle/logic/cycle_correlation.dart`
**باگ‌ها:**
1. **سوگیری انتخاب (selection bias):** `mergedData` فقط از ردیف‌های `cycle_day_logs` ساخته می‌شود و در حلقهٔ ساخت بردار، شرط `if (flow > 0)` اعمال می‌شود. یعنی همبستگی «شدت جریان ↔ پایبندی به روتین» **فقط روی روزهای خونریزی** محاسبه می‌شود و هیچ روز مبنایی (غیرخونریزی) در محاسبه نیست. این عدد از نظر آماری بی‌معناست.
2. **حجم نمونهٔ ناکافی:** آستانهٔ `>= 3` نقطه برای اعلام همبستگی، به‌علاوهٔ آستانهٔ دلبخواه `|r| > 0.3`، بدون هیچ p-value یا بازهٔ اطمینان. با ۳ نقطه، `|r| > 0.3` تقریباً همیشه رخ می‌دهد.
3. **مقیاس نادرست:** `energyLevel` یک متغیر ترتیبی سه‌سطحی است که به `30/65/100` نگاشت و با Pearson تحلیل می‌شود؛ `quality` خواب هم لیکرت ۱..۵ است. Pearson روی دادهٔ ترتیبی کم‌سطح نامناسب است.
4. **جابجایی زمانی خواب:** `bedtime_diagnostics.date` بدون هیچ offset به همان روز نگاشت می‌شود، در حالی که خواب شب روز X معمولاً به صبح روز X+1 نسبت داده می‌شود.
5. **تناقض نوع دادهٔ `flowLevel`:** کد رشته‌های `'LIGHT'|'MEDIUM'|'HEAVY'` را مقایسه می‌کند، اما تست موجود مقدار عددی پاس می‌دهد و ستون در شِما `TEXT` است. هیچ enum یا اعتبارسنجی‌ای نیست؛ مقدار نامعتبر بی‌صدا به `0.0` تبدیل می‌شود.
6. رشته‌های بینش (`insight`) فارسی و سخت‌کدشده در لایهٔ منطق‌اند.

**رفع:**
- بردارها را روی **کل بازهٔ چرخه** بساز، نه فقط روزهای خونریزی: روزهای بدون خونریزی با `flow = 0` وارد شوند (در یک بازهٔ مشخص، مثلاً ۹۰ روز اخیر). صریحاً بین «صفر ثبت‌شده» و «ثبت نشده» تفکیک کن و تصمیم را در کد مستند کن.
- آستانهٔ حداقل نمونه را به `n >= 14` (روز) برسان و همراه با `r` مقدار **p-value** یا بازهٔ اطمینان ۹۵٪ محاسبه و برگردان. اگر معنادار نبود، `isSignificant = false` بگذار و UI باید بگوید «هنوز قابل نتیجه‌گیری نیست».
- برای متغیرهای ترتیبی از **Spearman** (همبستگی رتبه‌ای) استفاده کن. Pearson را فقط برای متغیرهای پیوسته نگه دار.
- برای خواب یک offset صریح `sleepAttributionOffsetDays = 1` تعریف کن (مستند و قابل تنطیم).
- یک `enum CycleFlowLevel { none, light, medium, heavy }` با `fromDb`/`toDb` بساز و همه‌جا استفاده کن؛ مقدار نامعتبر لاگ شود.
- `_calculatePearson` رفتار درست فعلی (بازگرداندن `null` وقتی مخرج صفر است) را حفظ کند.

### C-29 🔴 پارس محافطت‌نشده در `analyzeSymptomStats`
**باگ:** در حلقهها، `DateTime.parse(...)` برای `logDate` و `periods[i]['startDate']` بدون `tryParse` و بدون try/catch استفاده شده — یک ردیف خراب در پایگاه‌داده کل تحلیل را پرتاب می‌کند. همچنین `cycleDay` سقف ندارد، پس یک log ۶۰ روز پس از آخرین شروع دوره، تبدیل به «روز ۶۱ چرخه» می‌شود.
**رفع:** از `CycleDateContract.parseDayKey` استفاده کن و ردیف‌های غیرقابل‌پارس را با لاگ رد کن. `cycleDay` را به سقف `L + 10` محدود کن و موارد خارج از آن را در `unattributedLogs` بشمار.

### C-30 🟠 امتیاز بار بدنی همیشه «بالا» می‌شود — `cycle_burden_engine.dart`
**باگ:** مجموع حداکثری ممکن `10 + 35 + 25 + 30 + 15 + 15 = 130` است که به `100` clamp می‌شود؛ یعنی مقیاس اشباع‌شده است. مهم‌تر: یک روز کاملاً معمولی قاعدگی با جریان متوسط `10 + 35 + 15 = 60` می‌گیرد که دقیقاً روی آستانهٔ `HIGH` است. نتیجه: `CycleLoadBalancer` حالت `lighter` را فعال می‌کند، `energyDelta = -15` و `sessionLengthMultiplier = 0.70` اعمال می‌شود و **کل برنامهٔ کاربر برای همهٔ روزهای قاعدگی سرکوب می‌شود** — حتی وقتی کاربر هیچ علامتی ثبت نکرده. همچنین جریان `MEDIUM` مقدار امتیاز می‌افزاید اما هیچ دلیلی در `reasonsFa` نمی‌گذارد → «مشارکت خاموش» و غیرقابل توضیح برای کاربر.
**رفع:**
- وزن‌ها را نرمال‌سازی کن (مجموع حداکثر = ۱۰۰ بدون clamp) و به ثابت‌های نام‌دار در کلاس `CycleBurdenWeights` منتقل کن.
- آستانه‌ها را بازکالیبره کن: یک روز قاعدگی با جریان متوسط و بدون علامت باید `MODERATE` باشد، نه `HIGH`.
- امتیاز باید **حداقل داده** لازم داشته باشد: اگر نه علامتی ثبت شده، نه `energyTag`، نه `sleepHours`، سطح را حداکثر `MODERATE` بگذار و `confidence: low` برگردان.
- خروجی باید `contributingFactors` ساخت‌یافته (کد + وزن) داشته باشد تا هر مشارکتی قابل توضیح باشد؛ لیست رشتهٔ فارسی حذف شود.

### C-31 🟠 توصیه‌های سخت‌کدشده — `cycle_load_balancer.dart`
**باگ:** کل توصیه‌ها لیست رشتهٔ فارسی `const` هستند و ضرایب (`0.70/0.85/1.0`، `breaks 10/5/0`، `energyDelta -15/-7/0`) اعداد جادویی‌اند. مقدار `-15` در `CycleConsentBridge.bodyRhythmInfluence` هم دوباره سخت‌کد شده (دو منبع حقیقت). علاوه بر این برای `LOW` حالت `higher-focus` برمی‌گرداند حتی اگر کاربر در میانهٔ خونریزی باشد و فقط چیزی ثبت نکرده باشد.
**رفع:** توصیه‌ها به کلید l10n تبدیل شوند؛ `loadMode` یک enum شود؛ ضرایب به ثابت نام‌دار منتقل و در یک جا متمرکز شوند؛ ورودی تابع علاوه بر `burden` مقدار `phase` را هم بگیرد تا در فاز `menstrual` هرگز `higher-focus` پیشنهاد نشود.

### C-32 🟠 تشخیص ناهنجاری ناکارآمد — `cycle_anomaly_detector.dart`
**باگ‌ها:**
- طول آخرین چرخه با `avgCycleLength` مقایسه می‌شود که **خودِ همان چرخه در آن میانگین هست** → خود-ارجاعی و کاهش حساسیت (به‌ویژه با تعداد کم چرخه).
- فقط **دو دورهٔ اخیر** بررسی می‌شود؛ مهم‌ترین ناهنجاری یعنی **نبود دوره / تأخیر طولانی** (وقتی ردیف جدیدی ثبت نشده) اصلاً تشخیص داده نمی‌شود.
- `isMild` همیشه `true` است — سطح شدت بی‌معناست و هیچ مسیر escalation یا پیشنهاد مراجعه وجود ندارد.
- تنها یک نوع ناهنجاری و با رشتهٔ فارسی سخت‌کدشده.

**رفع:**
- میانگین مرجع را از **چرخه‌های قبلی، بدون احتساب چرخهٔ مورد بررسی** محاسبه کن (leave-one-out).
- انواع ناهنجاری را به enum تبدیل کن و حداقل این موارد را پوشش بده: `lateOrMissedPeriod` (بر مبنای `daysOverdue`/`missedCycles` از C-18)، `abnormallyShortCycle`، `abnormallyLongCycle`، `unusuallyLongBleeding`، `unusuallyHeavyFlowStreak`، `highVariabilityTrend`.
- سطح شدت واقعی (`info | watch | consultClinician`) محاسبه شود. **مهم:** هیچ متن ناهنجاری نباید تشخیص پزشکی بدهد؛ فقط مشاهده + پیشنهاد مراجعه.
- متن‌ها از l10n بیایند.

### C-33 🟠 پارامتر نادیده‌گرفته‌شده — `cycle_data_quality_engine.dart`
**باگ:** تابع پارامتر `todayIso` را می‌گیرد اما **هیچ‌جا استفاده نمی‌کند**؛ به‌جایش از `DateTime.now()` داخلی استفاده می‌کند. نتیجه: تابع غیرقابل‌تست دترمینیستیک است و با تزریق `now` در بقیهٔ موتورها ناهمگام است. علاوه بر این، خطای کوئری `cycle_day_logs` با `catch (_) {}` خفه می‌شود، پس یک خطای شِما شبیه «هیچ logی نیست» دیده می‌شود.
**رفع:** `todayIso` را به `DateTime now` تغییر بده و همهٔ `DateTime.now()`های داخلی را با آن جایگزین کن. آستانهٔ روزهای فراموشی دورهٔ باز را به یک ثابت نام‌دار مشترک با UI منتقل کن (الان در دو جا تکرار شده).

### C-34 🟠 پیش‌بینی الگوی شخصی غیرقابل‌اعتماد — `cycle_personal_pattern_engine.dart`
**باگ‌ها:**
- `confidence = (maxCount / periodRows.length).clamp(0.4, 0.95)` — کف `0.4` باعث می‌شود علامتی که ۲ بار در ۲۰ چرخه دیده شده، «۴۰٪ اطمینان» بگیرد. clamp مقدار واقعی را پنهان می‌کند.
- آستانهٔ `maxCount >= 2` برای اعلام یک «پیش‌بینی» بسیار پایین است.
- `if (cycleDay > avgCycleLength + 5) continue` از میانگین استفاده می‌کند نه طول همان چرخهٔ خاص.
- انتساب log به «آخرین شروع دوره ≤ تاریخ log» **هیچ سقف فاصله‌ای ندارد**؛ یک log مربوط به ۹۰ روز بعد از آخرین دوره، به «روز ۹۰ چرخه» نسبت داده می‌شود (و بعد با شرط بالا رد می‌شود، یعنی دادهٔ معتبر هم از دست می‌رود).
- `catch (_) { return []; }` سراسری، هر خطایی را به «هیچ الگویی نیست» تبدیل می‌کند.

**رفع:**
- `clamp` را حذف کن؛ اطمینان واقعی را برگردان و آستانهٔ نمایش را به `confidence >= 0.5` **و** `maxCount >= 3` **و** `completedCycles >= 3` برسان.
- به‌جای طول میانگین، از طول واقعی همان چرخه (فاصله تا شروع بعدی) استفاده کن؛ برای چرخهٔ جاری از `L`.
- سقف فاصلهٔ انتساب: اگر `logDate - activeStart > L + 10` روز، log را به هیچ چرخه‌ای نسبت نده و در `unattributedLogs` ثبت کن.
- `catch` سراسری را با لاگ‌گذاری و بازگرداندن نتیجهٔ جزئی جایگزین کن.
- برچسب‌های فارسی `_getSymptomFarsiLabel` به l10n منتقل شوند (فاز ۶)؛ کلید علامت باید یک enum معتبر باشد نه رشتهٔ آزاد.

### C-35 🟡 پیام چک‌این — `cycle_checkin_orchestrator.dart`
**باگ:** `pmsWindowStart.difference(now).inDays` روی `now` دارای زمان محاسبه می‌شود → خطای یک‌روزه. رشته‌ها هم سخت‌کدشده‌اند.
**رفع:** از `CycleDateContract.daysBetween` استفاده کن؛ پیام‌ها به کد + l10n تبدیل شوند. همچنین پس از C-25 مقدار `pmsWindowStart` می‌تواند `null` باشد — این حالت را مدیریت کن.

### گیت پذیرش فاز ۴
- تست: با ۳ روز log، هیچ همبستگی «معنادار» گزارش نمی‌شود (`isSignificant == false`).
- تست: بردار همبستگی روتین شامل روزهای غیرخونریزی هم می‌شود (سوگیری رفع شده).
- تست: `analyzeSymptomStats` با یک `logDate` خراب در میان داده، پرتاب نمی‌کند.
- تست: روز قاعدگی با جریان متوسط و بدون علامت/انرژی/خواب، سطح `MODERATE` می‌دهد نه `HIGH`.
- تست: در فاز `menstrual`، `loadMode` هرگز `higher-focus` نیست.
- تست: تأخیر ۴۰ روزه یک ناهنجاری `lateOrMissedPeriod` تولید می‌کند.
- تست: `evaluateDataQuality` با `now` تزریق‌شده دترمینیستیک است (`DateTime.now()` در کد نیست).
- تست: علامتی که ۲ بار دیده شده، به‌عنوان forecast منتشر نمی‌شود.
- `enum CycleFlowLevel` وجود دارد و `grep -rn "'HEAVY'\|'MEDIUM'\|'LIGHT'" lib/features/cycle` فقط داخل همان enum نتیجه دارد.

---

## فاز ۵ — یکپارچگی با سیستم‌های بیرونی (agenda، عبادت، نوتیفیکیشن)

### C-36 🔴 آیتم‌های تقویم فقط نسبت به «امروز» درست‌اند — `cycle_agenda_source.dart`
**باگ‌ها:**
- `load()` یک بار `CycleEngine().calculate(... now: DateTime.now())` را صدا می‌زند و همان یک خروجی برای `itemsForDate` **هر تاریخی** استفاده می‌شود. پس پنجره‌های پیش‌بینی برای تاریخ‌های گذشته/آینده همه بر مبنای پیش‌بینیِ امروز محاسبه می‌شوند.
- `if (ctx.isToday && out.dayOfPeriod > 0)` → روزهای قاعدگی **گذشته** هیچ‌وقت در تقویم نمایش داده نمی‌شوند، حتی اگر دوره‌شان در پایگاه‌داده ثبت شده باشد.
- زنجیرهٔ `if / else if` باعث می‌شود در روزی که هم PMS و هم پنجرهٔ پیش‌بینی دوره فعال است، یکی حذف شود.
- موتور را مستقیم صدا می‌زند و `RitmoEngineBus`/کش را دور می‌زند → محاسبهٔ تکراری و ناهمگامی با داشبورد.
- `cycleAllowed` از بیرون پاس می‌شود و رضایت `cycle_consent_dashboard` را چک نمی‌کند.
- عنوان آیتم صریحاً واژهٔ چرخه/قاعدگی دارد و در تقویم مشترک نمایش داده می‌شود — نشت حریم خصوصی در یک سطح عمومی‌تر. همچنین عنوان‌ها فارسی سخت‌کدشده‌اند و هیچ شاخهٔ حالت بارداری وجود ندارد.

**رفع:**
- برای روزهای **گذشته و جاری**، آیتم قاعدگی را از **دادهٔ واقعی `cycle_periods`** بساز (نه از پیش‌بینی): در `load()` دوره‌های بازهٔ مورد نیاز را یک‌بار بخوان و در حافظه نگه دار.
- برای روزهای **آینده** از پنجره‌های پیش‌بینی استفاده کن و آیتم‌ها را صریحاً «پیش‌بینی» برچسب بزن.
- خروجی موتور را از `RitmoEngineBus` (کش‌شده) بگیر، نه با `CycleEngine()` مستقیم.
- اجازه بده یک روز **بیش از یک آیتم** داشته باشد یا اولویت را صریح و مستند کن.
- `cycleAllowed` را داخل منبع از رضایت واقعی (`cycle_consent_dashboard`) بخوان.
- **تصمیم قطعی:** متن آیتم تقویم در حالت پیش‌فرض باید **غیرصریح** باشد (همان الگوی «ریتم بدن» که در `bodyRhythmInfluence` و نوتیفیکیشن‌های redacted استفاده شده)، و متن صریح فقط وقتی نمایش داده شود که کاربر صریحاً رضایت داده باشد. عنوان‌ها به کلید l10n منتقل شوند.
- اگر حالت بارداری فعال است، هیچ آیتم پیش‌بینی دوره/باروری نساز.
- اگر `hasData == false` یا فیلدهای پیش‌بینی `null` باشند (C-25)، هیچ آیتمی نساز.

### C-37 🔴 دو پاسخ متفاوت برای وضعیت فقهی
**باگ:**
- `HormonalIntelligenceEngine` مقدار `fiqhState.prayerSuspended` و `fastingSuspended` را فقط از `isMenstrual` می‌سازد و **هیچ توجهی به `cycle_consent_worship` ندارد**.
- `CycleConsentBridge.isWorshipSuspended()` هم رضایت را چک نمی‌کند و صرفاً `getActivePeriod() != null || isUserMenstruating()` است — در حالی که تست `isWorshipSuspended respects settings` انتطار دارد با `cycle_consent_worship = 'false'` مقدار `false` برگردد. این تست فقط به‌خاطر شکل mock پاس می‌شود، نه به‌خاطر منطق درست.
- در نتیجه دو مسیر مختلف در اپ می‌توانند دو پاسخ متفاوت برای «آیا نماز تعلیق است؟» بدهند.
- سقف ۱۰ روزهٔ فقهی (`daysDiff >= 0 && daysDiff <= 10`) در چند جای فایل تکرار شده.
- `resolveFastingDebt` هم در `fasting_debt` و هم در `worship_debts` می‌نویسد بدون تراکنش → در صورت شکست نیمه‌راه، داده ناسازگار می‌ماند.

**رفع (تصمیم قطعی):** یک مرجع واحد `CycleWorshipPolicy` بساز که **تنها** پاسخ‌دهندهٔ تعلیق عبادت باشد، صریحاً `cycle_consent_worship` را چک کند، و سقف ۱۰ روزه را در یک ثابت نام‌دار نگه دارد. `HormonalIntelligenceEngine.fiqhState` و `CycleConsentBridge.isWorshipSuspended` هر دو به آن delegate کنند. `resolveFastingDebt` در یک تراکنش انجام شود. تست‌های موجود مربوط به عبادت نباید بشکنند.

### C-38 🟠 موتور «deprecated» که هنوز UI زنده را تغذیه می‌کند
**باگ:** `HormonalIntelligenceEngine` در کامنت خودش «Deprecated / compatibility adapter» است، اما `cycle_reminders_screen` مستقیماً از آن استفاده می‌کند. بدتر: `privateReminderQueue` **همیشه `[]`** برگردانده می‌شود، پس کارت «یادآوری‌های محرمانه» در آن صفحه همیشه یک ظرف خالی است — یک UI مرده که به کاربر شکل یک قابلیت را نشان می‌دهد (مدل سطوح `T-7/T-3/T-1/T0` را مستند کرده اما هیچ تولیدکننده‌ای ندارد).
همچنین برای `noData` این کلاس `nextCycleStartDate: now` می‌دهد در حالی که `CycleEngine._emptyOutput` مقدار `now + 14` می‌دهد → دو رفتار متفاوت برای یک وضعیت.
**رفع:**
- `cycle_reminders_screen` را به `CycleEngine` (از طریق `RitmoEngineBus`) منتقل کن.
- **تصمیم قطعی:** `privateReminderQueue` را **واقعاً بساز** (از پنجره‌های `nextPeriodWindow`/`pmsWindow` با سطوح `T-7/T-3/T-1/T0`) — چون UI موجود آن را وعده داده و حذفش یک قابلیت را کم می‌کند.
- پس از انتقال همهٔ مصرف‌کننده‌ها، `HormonalIntelligenceEngine` را با `@Deprecated` واقعی علامت بزن و منطق `fiqhState` را به `CycleWorshipPolicy` بسپار.

### C-39 🟠 زمان‌بندی نوتیفیکیشن ناقص — `cycle_notification_service.dart`
**باگ‌ها:**
- `scheduleReminders` در اولین خط بدون قید و شرط `cancelAll()` می‌زند. پس هر مسیر خروج زودهنگام یا خطا کاربر را با **صفر یادآور** رها می‌کند.
- تنها دو یادآور (T-2 و T-1) زمان‌بندی می‌شوند و هیچ مکانیزم **زمان‌بندی مجدد** بعد از شلیک آن‌ها نیست → کاربر ماه دوم دیگر یادآور نمی‌گیرد.
- زمان‌بندی روی `nextPeriodWindowStart` لنگر می‌اندازد که تا C-17 اصلاح نشده باشد می‌تواند ده‌ها روز خطا داشته باشد.
- `dayMinus2.isAfter(today)` با `today = DateTime.now()` (شامل زمان) مقایسه می‌شود و بعد مجدداً `scheduledDateTime.isAfter(today)` → دو مقایسهٔ ناهمگون؛ یادآوری که قرار بود امروز بعداً بزند بی‌صدا حذف می‌شود.
- هیچ آگاهی از منطقهٔ زمانی/DST در ساخت `DateTime(y, m, d, 10)` نیست.
- `consentReminders` و `pregnancyMode` بولین‌های ورودی‌اند و داخل سرویس از تنطیمات خوانده نمی‌شوند → هر فراخوانِ بی‌دقت می‌تواند رضایت کاربر را دور بزند.
- هیچ نقطهٔ فراخوانی‌ای بعد از تغییر داده (ثبت دوره، تغییر رضایت، تغییر طول چرخه) وجود ندارد.

**رفع:**
- `cancelAll()` را تا لحطه‌ای که یادآورهای جدید محاسبه و معتبر نشده‌اند اجرا نکن (محاسبه → لغو → زمان‌بندی، و در صورت خطا وضعیت قبلی حفظ شود).
- یک `CycleReminderScheduler` بساز که پس از **هر** تغییر مؤثر (نوشتن در `CyclePeriodRepository`، تغییر `cycle_consent_reminders`، تغییر `CycleSettings`، تغییر حالت بارداری، و در هر cold start اپ) کل یادآورها را دوباره بچیند.
- حداقل ۳ چرخهٔ آیندهٔ یادآور را از قبل زمان‌بندی کن تا با یک بار نرفتن کاربر به اپ، زنجیره قطع نشود.
- زمان‌بندی timezone-aware انجام شود و مقایسه‌ها روی `DateTime` نرمال‌شده (از `CycleDateContract`) باشند.
- `consentReminders` و `pregnancyMode` را داخل سرویس از `CycleSettings` بخوان (در عین حال می‌توانی ورودی اختیاری برای تست نگه داری).
- اگر پیش‌بینی `null` است یا اعتماد پیش‌بینی کافی نیست، هیچ یادآوری زمان‌بندی نشود.
- رفتار فعلی در حالت بارداری (لغو همه) درست است — حفظ شود، اما پس از خروج از بارداری مجدداً زمان‌بندی شود.

### C-40 🟠 موتور در حالت بارداری هم پیش‌بینی می‌کند
**باگ:** `cycle_pregnancy_mode` در `CycleConsentBridge.isUserMenstruating` و در سرویس نوتیفیکیشن رعایت می‌شود، اما `CycleEngine.calculate` هیچ گیتی برای بارداری ندارد و همچنان دورهٔ بعدی و پنجرهٔ باروری تولید می‌کند. نتیجه: کاربر باردار، پیش‌بینی پریود می‌بیند.
**رفع:** در `CycleEngine` و در `canRun` یک گیت بارداری اضافه کن: در حالت بارداری، خروجی باید فاز مختصر بارداری باشد با فیلدهای پیش‌بینی `null` — نه پیش‌بینی دوره.

### گیت پذیرش فاز ۵
- تست: `CycleAgendaSource` برای یک تاریخ گذشته که دوره‌اش ثبت شده، آیتم قاعدگی تولید می‌کند.
- تست: روزی که هم در پنجرهٔ PMS و هم در پنجرهٔ پیش‌بینی است، داده از دست نمی‌رود.
- تست: در حالت بارداری هیچ آیتم پیش‌بینی دوره/باروری تولید نمی‌شود و `CycleEngine` پیش‌بینی نمی‌دهد.
- تست: با `cycle_consent_worship = 'false'`، هم `CycleConsentBridge.isWorshipSuspended` و هم `fiqhState.prayerSuspended` مقدار `false` می‌دهند.
- تست: `privateReminderQueue` برای کاربر با دادهٔ کافی غیرخالی است.
- تست: پس از درج یک دوره، زمان‌بندی یادآورها مجدداً اجرا می‌شود و حداقل ۳ چرخهٔ آینده پوشش داده شده.
- تست: اگر محاسبهٔ یادآور شکست بخورد، یادآورهای قبلی حذف نمی‌شوند.

---

## فاز ۶ — بومی‌سازی، دسترس‌پذیری، طراحی و بازسازی ساختاری

### C-41 🟠 بومی‌سازی (l10n)
**باگ:** پروژه `l10n.yaml` و `app_en.arb`/`app_fa.arb` دارد و `docs/l10n_audit.md` هم موجود است، اما کل ماژول چرخه پر از رشتهٔ فارسی سخت‌کدشده در لایه‌های **دامنه، منطق و سرویس** است: `cycle_engine.dart`, `cycle_anomaly_detector.dart`, `cycle_burden_engine.dart`, `cycle_load_balancer.dart`, `cycle_checkin_orchestrator.dart`, `cycle_data_quality_engine.dart`, `cycle_personal_pattern_engine.dart`, `cycle_correlation.dart`, `cycle_consent_bridge.dart`, `cycle_notification_service.dart`, `cycle_agenda_source.dart` و همهٔ ویجت‌ها.
**رفع:**
- قاعدهٔ قطعی: **هیچ رشتهٔ کاربرپسند در `lib/core/**`، `lib/features/cycle/logic/**` و `lib/features/cycle/models/**` مجاز نیست.** این لایه‌ها فقط enum/کد برمی‌گردانند.
- همهٔ متن‌ها به `app_fa.arb` و `app_en.arb` منتقل شوند (هر دو زبان کامل شوند؛ ترجمهٔ انگلیسی واقعی بنویس، نه کپی فارسی).
- برای مقادیر متغیر از placeholder رسمی ARB استفاده کن، نه الحاق دستی رشته.
- یک تست guard بنویس که وجود کاراکتر فارسی در فایل‌های لایهٔ دامنه/منطق چرخه را fail کند (الگوی تست‌های source-guard موجود پروژه را ببین و مشابهش را بساز).

### C-42 🔴 ریسک کرش در بارگذاری — `cycle_reminders_screen.dart`
**باگ:**
```dart
_settings = {for (final s in settingsList) s['key']! as String: s['value']! as String};
```
cast غیر-null روی `value`. هر ردیف `app_settings` با `value = NULL` (که شِما اجازه می‌دهد) باعث `TypeError` می‌شود. `_loadData()` هم هیچ `try/catch` ندارد، پس کل صفحه کرش می‌کند. بقیهٔ کدبیس با `?? ''` محافطت کرده و این فایل خلاف الگو است.
علاوه بر این:
- تاریخ‌ها به‌صورت ISO خام میلادی به کاربر فارسی‌زبان نمایش داده می‌شوند، در حالی که بقیهٔ اپ جلالی است.
- مقادیر پیش‌فرض `'۲۸'` و `'۷'` به‌صورت **رشتهٔ ارقام فارسی** سخت‌کد شده‌اند (و `۷` با پیش‌فرض سراسری `6` تناقض دارد — C-13).
- `ListView.builder` با `shrinkWrap: true` و `NeverScrollableScrollPhysics` داخل `SingleChildScrollView` → همهٔ ردیف‌ها ساخته می‌شوند و مزیت virtualization از بین می‌رود؛ با تاریخچهٔ طولانی jank می‌دهد.
- هیچ `WidgetsBindingObserver` برای قفل مجدد در background ندارد (برخلاف `CycleLockGate`).

**رفع:**
- خواندن تنطیمات را به `?.toString() ?? ''` تغییر بده و `_loadData` را در `try/catch` با حالت خطای کاربرپسند بپیچ.
- همهٔ تاریخ‌ها با فرمت‌کنندهٔ جلالی موجود پروژه نمایش داده شوند.
- پیش‌فرض‌ها از `CycleSettings` بیایند (عدد، نه رشتهٔ ارقام فارسی) و تبدیل ارقام فقط در لایهٔ نمایش انجام شود.
- تاریخچه را در یک `ListView` واقعاً اسکرول‌پذیر (یا `CustomScrollView` با sliver) رندر کن و تعداد ردیف‌های بارگذاری‌شده را محدود/صفحه‌بندی کن.
- این صفحه باید در `CycleLockGate` پیچیده شود و منطق قفل داخلی‌اش حذف شود (یک پیاده‌سازی قفل، نه دو).

### C-43 🟠 دسترس‌پذیری و سرریز چیدمان
**باگ‌ها:**
- اندازه‌های ثابت: `width: 320` در کارت قفل، `SizedBox(width: 240)` و `SizedBox(width: 260)` برای کیپد، دکمه‌های ۵۶/۶۴ پیکسلی.
- فونت‌های سخت‌کدشدهٔ کوچک: `fontSize: 10`, `10.5`, `11` در ده‌ها نقطه، بدون توجه به `MediaQuery.textScaler`. با تنطیم فونت بزرگ سیستم، این چیدمان‌ها overflow می‌کنند.
- رنگ‌های سخت‌کدشده: `Color(0xffF43F5E)`, `Color(0xff08090C)`, `Color(0xff0F0E17)`, `Color(0xff1A1625)`, `Color(0xffFDF8F7)`, `Color(0xffF3E8E6)` — به‌جای توکن‌های تم، در حالی که پروژه `DESIGN_SYSTEM_CYCLE.md`، `docs/theme_migration.md` و `context.colors` دارد.
- کیپد `CycleLockGate` ارقام را فارسی می‌کند (`_toPersianDigits` خصوصی) اما کیپد `cycle_reminders_screen` لاتین نشان می‌دهد → دو کیپد متفاوت در یک اپ.
- دکمه‌های کیپد `GestureDetector` خالی‌اند: بدون `Semantics` label، بدون بازخورد لمس، بدون focus — برای screen reader و ناوبری کیبورد ناکارآمد.
- نقاط نمایشگر PIN هیچ وضعیت دسترس‌پذیری اعلام نمی‌کنند.

**رفع:**
- همهٔ رنگ‌ها به توکن‌های `context.colors` / `RitmoTheme` منتقل شوند. هیچ `Color(0x...)` سخت‌کدشده‌ای در `lib/features/cycle/**` باقی نماند (یک تست guard برای این هم بنویس).
- اندازه‌های ثابت کیپد و کارت با `LayoutBuilder`/`FractionallySizedBox` و سقف/کف معقول جایگزین شوند؛ کیپد در عرض‌های کوچک و `textScaleFactor = 2.0` نباید سرریز کند.
- فونت‌ها از `Theme.of(context).textTheme` بیایند.
- کیپد را به `InkWell`/`IconButton` با `Semantics(label: ...)` تبدیل کن؛ نقاط PIN باید `Semantics(liveRegion: true)` داشته باشند که **تعداد** رقم واردشده را اعلام کند، **بدون** لو دادن خود ارقام.
- تبدیل ارقام فارسی را به یک utility مشترک منتقل کن و در هر دو کیپد استفاده کن.
- تست‌های موجود مربوط به صفحهٔ باریک و golden را بشناس و تست‌های مشابه برای صفحات چرخه اضافه کن.

### C-44 🟠 فایل خداگونه — `cycle_screen.dart`
**باگ:** `lib/features/cycle/presentation/cycle_screen.dart` حدود **۱۸۲ کیلوبایت** در یک فایل است. علاوه بر غیرقابل‌نگهداری بودن، منطق مهاجرت تنطیمات هم درونش انجام می‌شود (C-13). فایل‌های بزرگ دیگر: `cycle_pregnancy_mode.dart` (~۴۸ KB)، `cycle_sos_section.dart` (~۲۵ KB)، `cycle_trends_section.dart` (~۲۳ KB)، `cycle_mood_chart.dart` (~۱۹ KB)، `cycle_lock_gate.dart` (~۱۹ KB)، `labor_mode_screen.dart` (~۱۸ KB).
**رفع:**
- `cycle_screen.dart` را به ویدجت‌های مستقل تحت `lib/features/cycle/presentation/sections/` تجزیه کن و منطق حالت را به یک controller/notifier در `lib/features/cycle/logic/` منتقل کن.
- **معیار قطعی:** هیچ فایلی در `lib/features/cycle/**` بیش از **۸۰۰ خط** نباشد.
- رفتار بصری نباید تغییر کند (این تجزیهٔ مکانیکی است، نه بازطراحی)؛ برای اثبات، تست‌های golden یا widget تهیه کن.
- منطق مهاجرت تنطیمات داخل UI حتماً حذف شود (با C-13 جایگزین شده).

### C-45 🟡 نمایش دادهٔ نامعتبر و تخمینی به عنوان دادهٔ واقعی
**باگ:** خروجی موتور مقدار `trendPoints` را برای چرخهٔ جاری با فالبک به `cycleLengths.last` (یعنی یک بازهٔ قدیمی‌تر) یا `L` پر می‌کند — یعنی مقداری ساختگی در نمودار روند مثل اندازه‌گیری واقعی نمایش داده می‌شود.
**رفع:** نقطهٔ چرخهٔ درجریان را با فلگ `isInProgress: true` و مقدار nullable برگردان و در UI با سبک متفاوت (خط چین، رنگ محو) رندر کن. در همهٔ کارت‌های چرخه، پرچم‌های `isProjected` (C-26)، `hasImplausiblePeriodData` (C-24)، `hasPhaseConflict` (C-19) و `discardedOutliers` (C-22) باید به کاربر نشان داده شوند — دادهٔ نامطمئن نباید مثل دادهٔ قطعی دیده شود.

### گیت پذیرش فاز ۶
- تست guard: هیچ کاراکتر فارسی در `lib/core/domain/engines/cycle_engine.dart`، `lib/features/cycle/logic/**`، `lib/core/utils/cycle_*.dart` و `lib/core/services/cycle_notification_service.dart` نیست.
- تست guard: هیچ `Color(0x` در `lib/features/cycle/**` نیست.
- تست: `wc -l` هر فایل `lib/features/cycle/**` زیر ۸۰۰ است.
- تست ویجت: `cycle_reminders_screen` با یک ردیف `app_settings` دارای `value = NULL` کرش نمی‌کند.
- تست ویجت: با `textScaleFactor: 2.0` و عرض ۳۲۰ پیکسل، هیچ overflowی در صفحهٔ قفل و صفحهٔ یادآورها رخ نمی‌دهد.
- تست: هر دو کیپد PIN ارقام فارسی نشان می‌دهند و هر دکمه `Semantics` label دارد.

---

## فاز ۷ — تست و تضمین کیفیت

### C-46 🔴 موکِ پایگاه‌داده که فیلتر را نادیده می‌گیرد
**باگ:** در `test/cycle_engine_test.dart`، کلاس‌های موک(`MockCycleDatabase` / `CycleMockDatabase`) در `query` مقادیر `where`، `whereArgs` و `orderBy` را برای اکثر جداول نادیده می‌گیرند و همهٔ ردیف‌ها را برمی‌گردانند. نتیجه: هیچ یک از مسیرهای واقعی کوئری (که دقیقاً محل باگ‌های C-14 و C-12 هستند) تست نمی‌شوند، و برخی تست‌ها (مانند `isWorshipSuspended respects settings`) فقط به‌خاطر رفتار موک سبزند.
**رفع (تصمیم قطعی):** موک‌های دستی را حذف کن و تمام تست‌های چرخه را روی **یک پایگاه‌دادهٔ حقیقی در‌حافطه** (`sqflite_common_ffi` با شِمای واقعی اپ و اجرای migration‌ها) بنویس. یک helper مشترک بساز: `test/cycle/helpers/cycle_test_db.dart` که:
- پایگاه‌داده را با شِمای کامل و تمام migration‌ها می‌سازد؛
- سازنده‌های راحت دارد: `seedPeriods([...])`, `seedDayLogs([...])`, `seedSettings({...})`؛
- پس از هر تست پاک می‌شود.

### C-47 🔴 تست‌هایی که رفتار اشتباه را تثبیت کرده‌اند
**باگ:** در `test/cycle_engine_test.dart` چند انتطار وجود دارد که رفتار باگ‌دار فعلی را تأیید می‌کنند — مثلاً کامنتی که خودش می‌پذیرد محدودهٔ تخمک‌گذاری off-by-one است و با همان فرض انتطار می‌نویسد. این تست‌ها مانع اصلاح C-19 و C-23 می‌شوند.
**رفع:** این تست‌ها را **بازنویسی** کن تا رفتار صحیح جدید را بیان کنند. در کامنت هر تست اصلاح‌شده، شناسهٔ باگ مربوطه (`C-xx`) را بنویس. **حذف تست ممنوع است** — فقط انتطار را بر مبنای رفتار درست اصلاح کن.
تست شکستهٔ `contains('کافی نیست')` (C-01) را با مقایسه بر مبنای **کد/enum** خروجی موتور (پس از C-41) بازنویسی کن، نه مقایسهٔ رشتهٔ فارسی.

### C-48 🔴 پوشش صفر برای اکثر ماژول
**باگ:** پوشش تست ماژول چرخه تقریباً فقط محدود به `test/cycle_engine_test.dart` و `test/cycle/cycle_onboarding_test.dart` است. هیچ تستی برای این موارد وجود ندارد:
trend/overdue، پهنای پنجرهٔ پیش‌بینی، fingerprint/کش، حالت بارداری، `CycleBurdenEngine`، `CycleLoadBalancer`، `CycleDataQualityEngine`، `CyclePersonalPatternEngine`، `CycleAnomalyDetector`، `CycleCheckinOrchestrator`، `CycleNotificationService`، `CycleLockGate`، `CycleAgendaSource`، رفتار منطقهٔ زمانی/DST، و مهاجرت کلیدهای تنطیمات.
**رفع:** فایل‌های تست زیر را بساز (همه روی DB در‌حافطهٔ C-46):

```
test/cycle/cycle_date_contract_test.dart          (فاز ۰)
test/cycle/cycle_lock_service_test.dart           (C-05..C-08)
test/cycle/cycle_lock_gate_widget_test.dart       (C-09, C-43)
test/cycle/cycle_privacy_guard_test.dart          (C-11)
test/cycle/cycle_migration_test.dart              (C-12..C-14)
test/cycle/cycle_period_repository_test.dart      (C-14)
test/cycle/cycle_settings_test.dart               (C-13)
test/cycle/cycle_onboarding_save_test.dart        (C-15)
test/cycle/cycle_engine_cache_test.dart           (C-16)
test/cycle/cycle_engine_prediction_test.dart      (C-17, C-19, C-22, C-25, C-26)
test/cycle/cycle_engine_overdue_test.dart         (C-18, C-23, C-24)
test/cycle/cycle_engine_regularity_test.dart      (C-20, C-21)
test/cycle/cycle_engine_timezone_test.dart        (DST)
test/cycle/cycle_correlation_test.dart            (C-28, C-29)
test/cycle/cycle_burden_engine_test.dart          (C-30)
test/cycle/cycle_load_balancer_test.dart          (C-31)
test/cycle/cycle_anomaly_detector_test.dart       (C-32)
test/cycle/cycle_data_quality_engine_test.dart    (C-33)
test/cycle/cycle_personal_pattern_test.dart       (C-34)
test/cycle/cycle_checkin_orchestrator_test.dart   (C-35)
test/cycle/cycle_agenda_source_test.dart          (C-36)
test/cycle/cycle_worship_policy_test.dart         (C-37, C-38)
test/cycle/cycle_notification_scheduler_test.dart (C-39)
test/cycle/cycle_pregnancy_gate_test.dart         (C-40)
test/cycle/cycle_source_guards_test.dart          (C-41, C-43, C-44)
```

### گیت پذیرش فاز ۷
- `flutter test` کاملاً سبز است (بدون skip و بدون `solo`).
- هیچ تستی حذف نشده است (تعداد تست‌ها نسبت به فاز ۰ فقط زیاد شده).
- هر باگ از `C-01` تا `C-48` **حداقل یک تست** دارد که بدون اصلاح، شکست می‌خورد (رگرسیون‌گیر).
- هیچ تستی به `DateTime.now()` واقعی وابسته نیست (همه `now` تزریقی).

---

## فاز ۸ — تأیید نهایی و گزارش

1. **اعتبارسنجی فنی:**
   ```
   flutter analyze                          → صفر خطا، صفر warning
   flutter test                             → همه سبز
   dart format --set-exit-if-changed lib test
   ```
2. **اعتبارسنجی مهاجرت:** migration را یک بار روی یک پایگاه‌دادهٔ قدیمی همراه با دادهٔ خراب (دورهٔ همپوشان، تاریخ مخلوط، کلیدهای legacy، PIN خام) اجرا کن و خروجی `CycleDataDoctor.diagnose` بعد از مهاجرت باید تمیز باشد.
3. **اعتبارسنجی امنیتی دستی:** مطمئن شو که در هیچ کدام از مسیرهای ورود، PIN خام در پایگاه‌داده نوشته نمی‌شود و دکمهٔ بیومتریک بدون احراز هویت قفل را باز نمی‌کند.
4. **گزارش نهایی:** فایل `docs/cycle_fix_report.md` را بساز که دقیقاً همین ساختار را دارد (و هیچ بخش برنامه‌ریزی آینده ندارد):

   | شناسه | فاز | وضعیت | فایل‌های تغییریافته | تست مربوطه | یادداشت |
   |---|---|---|---|---|---|
   | C-01 | ۰ | ✅/⚠️ | ... | ... | ... |

   در انتهای همین فایل، بخش «تغییرات شکننده (breaking)» و «مواردی که محافطه‌کارانه حل شدند» را فهرست کن.
5. **پیام نهایی:** فقط خلاصهٔ واقعی از کارِ انجام‌شده را گزارش بده (چند باگ، چند فایل، چند تست). **هیچ برنامهٔ مرحلهٔ بعدی و هیچ پیشنهاد فاز جدید ننویس.**

---

## جدول مرجع — نقشهٔ باگ به فاز

| فاز | محور | شناسه‌ها |
|---|---|---|
| ۰ | زیرساخت و قراردادها | C-01 … C-04 |
| ۱ | امنیت و حریم خصوصی | C-05 … C-11 |
| ۲ | داده، شِما و مهاجرت | C-12 … C-15 |
| ۳ | صحت موتور محاسباتی | C-16 … C-27 |
| ۴ | موتورهای هوشمند و آمار | C-28 … C-35 |
| ۵ | یکپارچگی بین‌ماژولی | C-36 … C-40 |
| ۶ | UI، l10n، دسترس‌پذیری، ساختار | C-41 … C-45 |
| ۷ | تست و تضمین کیفیت | C-46 … C-48 |
| ۸ | تأیید نهایی و گزارش | — |

راهنمای شدت: 🔴 بحرانی / مسدودکننده · 🟠 مهم · 🟡 متوسط

---

## یادآوری نهایی

دوباره تأکید: **نقشهٔ پیاده‌سازی جدید ننویس، رودمپ نساز، مرحله‌بندی جدید طراحی نکن، و قبل از شروع مجدداً تحلیل مخزن را از صفر انجام نده.** تحلیل قبلاً انجام شده و نتیجه‌اش همین فایل است. فاز ۰ را شروع کن و تا فاز ۸ پیوسته پیش برو.

فقط مجازی کد را بخوانی تا جزئیات دقیق خطوط را پیدا کنی — این لازم است. اما تشخیص مسأله و ترتیب رفع قطعی شده؛ روی آن مجدداً بحس نکن.
