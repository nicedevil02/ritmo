# پرامپت اجرایی — بازسازی و رفع باگ‌های «تنظیمات» در پروژه Ritmo

> نسخه: ۱٫۰ — مرجع کد: شاخهٔ اصلی، commit `2b6f358c4c3b43065eff8a2a27acdb1430afd14a`
> دامنهٔ کار: `lib/core/settings/**`، `lib/features/settings/**` و نقاطی از `lib/core/**` که مستقیماً به تنظیمات دست می‌زنند.

---

## بخش ۰ — نحوهٔ استفاده (برای بهمن؛ ایجنت این بخش را نادیده بگیرد)

این فایل را کامل به ایجنت برنامه‌نویس بده. نیازی به توضیح اضافه نیست. اگر جلسه قطع شد، دوباره همین فایل را بده و بگو: «از روی `docs/settings/SETTINGS_FIX_PROGRESS.md` ادامه بده.»

---

## بخش ۱ — نقش تو و قوانین آهنین

تو یک مهندس ارشد Flutter/Dart هستی که روی پروژهٔ فارسی و راست‌به‌چپ «ریتمو» کار می‌کند. کار تو **اجرا** است، نه طراحی.

### ۱۸ قانون آهنین — نقض هر یک، خرابی کار است

۱. **هیچ نقشه، رودمپ، فازبندی جدید یا «برنامهٔ پیاده‌سازی» ننویس.** نقشه همین فایل است. اولین خروجی تو باید یک تغییر کد واقعی باشد، نه یک سند.
۲. **ترتیب تسک‌ها را عوض نکن.** از SET-01 شروع کن و به ترتیب تا SET-70 برو. وابستگی‌ها عمداً به این ترتیب چیده شده‌اند.
۳. **همیشه فقط یک تسک در دست داشته باش.** تسک بعدی را تا وقتی تسک فعلی commit نشده شروع نکن.
۴. **چرخهٔ هر تسک دقیقاً این است:** فایل‌ها را بخوان ← تغییر بده ← `flutter analyze` ← `flutter test` ← ردیف ledger را `DONE` کن ← commit بزن.
۵. **یک commit به‌ازای هر تسک.** نه بیشتر، نه کمتر. پیام commit دقیقاً طبق فرمت هر تسک.
۶. **`catch (_) {}` و `catch (e) {}` خالی ممنوع.** همیشه `RitmoLog.error('[Settings] ...', e, st)`.
۷. **`debugPrint` ممنوع.** همه‌جا `RitmoLog`.
۸. **هیچ رشتهٔ رابط کاربری انگلیسی ننویس.** همهٔ متن‌های کاربر فارسی. هرگز خطای خام را به کاربر نشان نده.
۹. **هیچ SQL خامی روی جدول `app_settings` بیرون از `SettingsService` ننویس.** اگر جایی دیدی، همان‌جا اصلاحش کن.
۱۰. **هیچ کلید تنظیماتی را بدون ثبت در `SettingsRegistry` نخوان و ننویس.** کلید رشته‌ای پراکنده ممنوع.
۱۱. **هر تغییر رفتاری باید تست داشته باشد.** اگر تست نمی‌شود نوشت، در ledger بنویس چرا.
۱۲. **کد مرده را پاک کن، کامنت‌گذاری نکن.**
۱۳. **اگر کاری قبلاً انجام شده،** ردیف را `SKIPPED` بزن و برو بعدی. دوباره‌کاری نکن.
۱۴. **اگر کد با توصیف این فایل فرق داشت،** ردیف را `BLOCKED` بزن، یک جملهٔ توضیح در ستون یادداشت بنویس، و **برو تسک بعدی**. متوقف نشو و سؤال نپرس.
۱۵. **فقط این مسیرها را دست بزن:** `lib/core/settings/`، `lib/features/settings/`، `lib/core/utils/`، `lib/core/logging/`، `lib/core/security/`، `test/`. برای هر فایل خارج از این‌ها که مجبور شدی تغییر دهی، در ledger یک خط توضیح بنویس.
۱۶. **پایان هر فاز، `flutter analyze` باید صفر ایراد بدهد.**
۱۷. **هیچ راز (PIN، کلید API، توکن) را log نکن، در پیام خطا نیاور، و در حافظهٔ عمومی نگه ندار.**
۱۸. **هیچ تنظیمی را بی‌صدا از دست نده.** اگر نوشتن شکست خورد، کاربر باید ببیند و مقدار UI باید برگردد.

---

## بخش ۲ — قانون ضد فراموشی (اولین کاری که می‌کنی)

قبل از SET-01، فایل `docs/settings/SETTINGS_FIX_PROGRESS.md` را بساز با این ساختار:

```markdown
# پیشرفت رفع باگ‌های تنظیمات

| ID | عنوان | فاز | وضعیت | commit | یادداشت |
|----|-------|-----|--------|--------|---------|
| SET-01 | ... | A | TODO | | |
```

هر ۷۰ ردیف (SET-01 تا SET-70) را با وضعیت `TODO` بساز.
وضعیت‌های مجاز: `TODO` / `DOING` / `DONE` / `SKIPPED` / `BLOCKED`.

قواعد:
- **ابتدای هر جلسهٔ کاری این فایل را بخوان** و از اولین ردیف غیر-`DONE` ادامه بده.
- ردیف را **در همان commit تسک** به‌روز کن، نه در commit جدا.
- اولین commit: `chore(settings): SET-00 — ساخت ledger پیشرفت`

---

## بخش ۳ — شناخت کد (خواندن اجباری قبل از SET-01)

این فایل‌ها را کامل بخوان. بدون خواندن این‌ها شروع نکن:

```
lib/core/settings/settings_registry.dart
lib/core/settings/settings_service.dart
lib/core/settings/settings_flags.dart
lib/features/settings/presentation/settings_screen.dart
lib/features/settings/presentation/settings_search_delegate.dart
lib/features/settings/presentation/widgets/settings_tile.dart
lib/features/settings/presentation/widgets/settings_section.dart
lib/features/settings/presentation/widgets/identity_header.dart
lib/features/settings/presentation/widgets/danger_zone.dart
lib/features/settings/presentation/groups/identity_group_screen.dart
lib/features/settings/presentation/groups/modules_group_screen.dart
lib/features/settings/presentation/groups/notifications_group_screen.dart
lib/features/settings/presentation/groups/notification_privacy_screen.dart
lib/features/settings/presentation/groups/appearance_group_screen.dart
lib/features/settings/presentation/groups/assistant_privacy_group_screen.dart
lib/features/settings/presentation/groups/data_backup_group_screen.dart
lib/features/settings/presentation/groups/security_group_screen.dart
lib/features/settings/presentation/groups/calendar_group_screen.dart
lib/core/services/secure_key_store.dart
lib/core/services/account_reset_service.dart
lib/core/modules/module_gate.dart
lib/core/modules/module_registry.dart
lib/core/modules/module_deactivation_service.dart
lib/core/services/module_management_service.dart
lib/core/theme/theme_repository.dart
lib/core/localization/locale_repository.dart
lib/core/utils/cycle_privacy_guard.dart
lib/core/utils/persian_digits.dart
lib/core/utils/snapshot_helper.dart
lib/core/logging/ritmo_logger.dart
lib/core/database/database_helper.dart
```

همچنین اجرا کن و خروجی را بخوان:

```bash
rg -n "app_settings" lib/ --glob '!lib/core/settings/**'
rg -n "SettingsService.instance" lib/ -l
rg -n "SettingsRegistry" lib/ -l
ls test/
```

### حقایق تأییدشده — دوباره تحقیق نکن

- `SettingsRegistry.all` یک `List<SettingDescriptor>` ثابت با حدود ۷۰ ورودی است.
- `SettingDescriptor` این فیلدها را دارد: `key`, `type`, `scope`, `defaultValue`, `labelFa`, `group`, `descriptionFa`, `min`, `max`, `allowed`, `aiWritable`, `searchTerms`.
- `SettingScope` = `{ db, prefs, secure }` و `SettingType` = `{ boolean, integer, text, enumeration, time }`.
- `SettingsGroup` = `{ identity, modules, notifications, appearance, assistant, dataBackup, security, calendar }`.
- `SettingsService` یک singleton با `_cache`، `revision` (`ValueNotifier<int>`) و `_initialized` است.
- `SettingsService.set` فقط `integer`، `enumeration` و `boolean` را اعتبارسنجی می‌کند. برای `text` و `time` هیچ اعتبارسنجی‌ای وجود ندارد.
- `SettingsRegistry.userVisibleByGroup` فیلترش این است: `descriptionFa != null && !key.endsWith('_asked') && key != 'onboarding_completed'`.
- `SettingsRegistry.aiWritableKeys` وجود دارد ولی **هیچ‌جا استفاده نمی‌شود**.
- `SettingsFlags.fromMap` کلیدهای `cycle_consent`، `proactive_assistant_enabled`، `briefing_enabled`، `energy_tuning_enabled` را می‌خواند که **هیچ‌کدام در رجیستری نیستند**.
- در رجیستری ۱۷ تنظیم با گروه `calendar` هست، ولی `CalendarGroupScreen` فقط ۵ تای آن‌ها را رندر می‌کند.
- `SettingsTile` پارامتر `highlighted` دارد که **هیچ‌جا پاس داده نمی‌شود**.
- `security_group_screen.dart` بستهٔ `local_auth` را import می‌کند ولی هرگز استفاده نمی‌کند.
- `SecurityGroupScreen` رمزها را مستقیماً با `SecureKeyStore.getKey` می‌خواند، نه با `SettingsService.get` — چون مسیر دوم کار نمی‌کند.
- `SettingsService.init()` برای scope `secure` فقط `defaultValue` را در کش می‌گذارد و هیچ بارگذار تنبلی وجود ندارد.

---

# بخش ۴ — تسک‌ها

از اینجا به بعد فقط اجرا. هر تسک را کامل تمام کن، commit بزن، ledger را به‌روز کن، برو بعدی.

---

## فاز A — زیرساخت رجیستری (SET-01 … SET-10)

### SET-01 — تبدیل رجیستری به منبع حقیقت با جست‌وجوی O(1)

**باگ:** `SettingsRegistry.find` یک حلقهٔ خطی روی ~۷۰ توصیفگر است و در `get<T>()` و `set()` صدا زده می‌شود. `get<T>()` داخل متد `build()` صفحه‌ها فراخوانی می‌شود (مثلاً `SecurityGroupScreen.build` و `ModulesGroupScreen.build`) پس هر فریم چند صد مقایسهٔ رشته‌ای انجام می‌شود.

**فایل‌ها:** `lib/core/settings/settings_registry.dart`

**کار دقیق:**
1. اضافه کن:
   ```dart
   static final Map<String, SettingDescriptor> _byKey = {
     for (final d in all) d.key: d,
   };
   ```
2. `find` را به `static SettingDescriptor? find(String key) => _byKey[key];` تغییر بده.
3. اضافه کن: `static final Map<SettingsGroup, List<SettingDescriptor>> _byGroup` و `userVisibleByGroup` را از روی آن بساز.
4. اضافه کن: `static int get count => all.length;`

**معیار پذیرش:** `find` و `userVisibleByGroup` هیچ پیمایش خطی روی `all` انجام نمی‌دهند.

**تست:** ندارد (SET-61 پوشش می‌دهد).

**commit:** `perf(settings): SET-01 — جست‌وجوی نگاشتی در رجیستری`

---

### SET-02 — افزودن فیلدهای گمشده به `SettingDescriptor`

**باگ:** رجیستری اطلاعات لازم برای رندر خودکار، وابستگی، و کنترل دسترسی را ندارد. به همین دلیل هر صفحهٔ گروه دستی نوشته شده و از رجیستری جدا افتاده است.

**فایل‌ها:** `lib/core/settings/settings_registry.dart`

**کار دقیق:** این فیلدها را به `SettingDescriptor` اضافه کن (همه با مقدار پیش‌فرض تا کد موجود نشکند):

```dart
final SettingVisibility visibility;      // پیش‌فرض: SettingVisibility.normal
final String? dependsOn;                 // کلید تنظیم والد
final bool affectsAgenda;                // پیش‌فرض: false
final bool requiresRestart;              // پیش‌فرض: false
final IconData? icon;
final String? unitFa;                    // 'دقیقه' / 'ثانیه' / 'روز'
final Map<String, String>? optionLabelsFa;
final List<String> searchTermsEn;        // پیش‌فرض: const []
```

و این enum را اضافه کن:

```dart
enum SettingVisibility {
  /// در فهرست گروه و جست‌وجو دیده می‌شود.
  normal,
  /// فقط وقتی «نمایش تنظیمات پیشرفته» روشن باشد.
  advanced,
  /// وضعیت داخلی؛ نه در فهرست، نه در جست‌وجو.
  internal,
}
```

**معیار پذیرش:** پروژه بدون تغییر در ورودی‌های موجود رجیستری کامپایل می‌شود.

**تست:** ندارد.

**commit:** `feat(settings): SET-02 — فیلدهای visibility و dependsOn در توصیفگر`

---

### SET-03 — اعتبارسنجی خودِ رجیستری در زمان ساخت

**باگ:** `defaultValue` از نوع `Object` است و هیچ چیز تضمین نمی‌کند با `type` بخواند. یک اشتباه تایپی مثل `defaultValue: '25'` روی یک تنظیم `integer` بی‌صدا رفتار را خراب می‌کند. همچنین `defaultValue` یک `enumeration` ممکن است در `allowed` نباشد.

**فایل‌ها:** `lib/core/settings/settings_registry.dart`

**کار دقیق:**
1. در سازندهٔ `SettingDescriptor` این `assert`ها را اضافه کن:
   - `type == boolean` یعنی `defaultValue is bool`
   - `type == integer` یعنی `defaultValue is int`
   - `type == text || enumeration || time` یعنی `defaultValue is String`
   - `type == enumeration` یعنی `allowed != null && allowed.isNotEmpty`
   - `type == enumeration` یعنی `allowed.contains(defaultValue)`
   - اگر `min != null && max != null` آنگاه `min <= max`
   - اگر `type == integer && min != null` آنگاه `defaultValue >= min`
   - اگر `type == integer && max != null` آنگاه `defaultValue <= max`
   - `type == time` یعنی `defaultValue` با الگوی ساعت ۲۴ساعته `HH:mm` بخواند
2. `min` و `max` را از `num?` به `int?` تغییر بده (هیچ تنظیم اعشاری‌ای وجود ندارد و `num` فقط اجازهٔ خطا می‌دهد).

**معیار پذیرش:** با تغییر عمدی یک `defaultValue` به نوع اشتباه، اپ در حالت debug بلافاصله assert می‌دهد.

**تست:** SET-61.

**commit:** `fix(settings): SET-03 — اعتبارسنجی ساختاری توصیفگرها`

---

### SET-04 — پاک‌سازی فهرست `allowed` تنظیم `user_gender`

**باگ:** `allowed` برابر است با `['UNSET','MALE','FEMALE','OTHER','PREFER_NOT_TO_SAY','male','female','other']` — یعنی سه گزینه دو بار با حروف کوچک تکرار شده‌اند. چون `SettingsService.set` مقایسه را بی‌توجه به بزرگی/کوچکی حروف انجام می‌دهد ولی **مقدار تایپ‌شده را ذخیره می‌کند نه مقدار متعارف را**، در پایگاه داده هم `FEMALE` و هم `female` می‌نشیند. هر کد مصرف‌کننده‌ای که `== 'FEMALE'` می‌نویسد برای نیمی از کاربران خاموش می‌شود.

**فایل‌ها:** `lib/core/settings/settings_registry.dart`

**کار دقیق:**
1. `allowed` را به `['UNSET', 'MALE', 'FEMALE', 'OTHER', 'PREFER_NOT_TO_SAY']` تغییر بده.
2. `optionLabelsFa` را پر کن: `{'UNSET': 'نامشخص', 'MALE': 'مرد', 'FEMALE': 'زن', 'OTHER': 'دیگر', 'PREFER_NOT_TO_SAY': 'ترجیح می‌دهم نگویم'}`.
3. تصحیح داده‌های موجود در SET-20 (مهاجرت) انجام می‌شود؛ اینجا فقط فهرست را تمیز کن.

**معیار پذیرش:** `allowed` هیچ گزینهٔ تکراری با حروف متفاوت ندارد.

**تست:** SET-61.

**commit:** `fix(settings): SET-04 — حذف گزینه‌های تکراری جنسیت`

---

### SET-05 — اصلاح پیش‌فرض خطرناک `onboarding_completed`

**باگ:** `onboarding_completed` با `defaultValue: true` ثبت شده است. روی نصب تازه که هیچ مقداری در `SharedPreferences` نیست، `init()` مقدار `true` را در کش می‌گذارد، یعنی **مرحلهٔ راه‌اندازی اولیه از قبل «تمام‌شده» تلقی می‌شود**. این تقریباً قطعاً یک باقی‌ماندهٔ دیباگ است.

**فایل‌ها:** `lib/core/settings/settings_registry.dart` و هر مصرف‌کنندهٔ این کلید (با `rg -n "onboarding_completed" lib/` پیدا کن).

**کار دقیق:**
1. `defaultValue` را به `false` تغییر بده.
2. `visibility` را `SettingVisibility.internal` بگذار.
3. در SET-20 یک مهاجرت بنویس که اگر دیتابیس هر دادهٔ کاربری دارد (یعنی کاربر قدیمی است)، `onboarding_completed = true` نوشته شود تا کاربر فعلی دوباره به onboarding پرت نشود.
4. اگر `rg` نشان داد این کلید هیچ مصرف‌کننده‌ای ندارد، در ledger بنویس «بدون مصرف‌کننده» و فقط پیش‌فرض و visibility را اصلاح کن.

**معیار پذیرش:** نصب تازه به onboarding می‌رود؛ کاربر موجود نمی‌رود.

**تست:** SET-62.

**commit:** `fix(settings): SET-05 — پیش‌فرض onboarding_completed به false`

---

### SET-06 — حد بالا و پایین برای `calendar_overdue_lookback_days`

**باگ:** این تنها تنظیم `integer` رجیستری است که `min` و `max` ندارد. `SettingsService.set` وقتی `min`/`max` نداشته باشد هر عددی را می‌پذیرد — از جمله عدد منفی، که پرس‌وجوی «کارهای معوقه» را به جای گذشته به آینده می‌برد.

**فایل‌ها:** `lib/core/settings/settings_registry.dart`

**کار دقیق:** `min: 0, max: 365` و `unitFa: 'روز'` را اضافه کن.

**معیار پذیرش:** `SettingsService.instance.set('calendar_overdue_lookback_days', -1)` مقدار `false` برمی‌گرداند.

**تست:** SET-62.

**commit:** `fix(settings): SET-06 — کران‌گذاری بازهٔ معوقه`

---

### SET-07 — مستندسازی مقدار نگهبان `-1` در مهلت قفل

**باگ:** `app_lock_timeout_seconds` بازهٔ `[-1, 3600]` دارد. `-1` در `SecurityGroupScreen` معنی «هرگز» می‌دهد، ولی این معنا هیچ‌جا مستند یا نام‌گذاری نشده است. یک عدد جادویی داخل یک بازهٔ عددی، بدترین ترکیب ممکن است.

**فایل‌ها:** `lib/core/settings/settings_registry.dart`، `lib/features/settings/presentation/groups/security_group_screen.dart`

**کار دقیق:**
1. در `settings_registry.dart` یک کلاس ثابت بساز:
   ```dart
   abstract final class AppLockTimeout {
     static const int immediate = 0;
     static const int never = -1;
     static const List<int> presets = [immediate, 60, 300, 900, never];
   }
   ```
2. `descriptionFa` را به‌روز کن و ذکر کن که `-1` یعنی «هرگز».
3. در `security_group_screen.dart` نگاشت `timeoutLabels` را از `AppLockTimeout.presets` بساز و اعداد جادویی `0`، `60`، `300`، `900`، `-1` را از بدنهٔ ویجت حذف کن.

**معیار پذیرش:** هیچ عدد جادویی مربوط به مهلت قفل در بدنهٔ ویجت باقی نمانده است.

**تست:** ندارد.

**commit:** `refactor(settings): SET-07 — نام‌گذاری مقادیر مهلت قفل`

---

### SET-08 — علامت‌گذاری صریح تنظیمات داخلی

**باگ:** `userVisibleByGroup` قابلیت دیده‌شدن را از روی یک قرارداد ضمنی و شکننده استنتاج می‌کند: «اگر `descriptionFa` نداشته باشد یعنی مخفی است». یعنی هر توسعه‌دهنده‌ای که یادش برود توضیح بنویسد، تنظیمش بی‌صدا از رابط کاربری ناپدید می‌شود و بج «N تنظیم» هم بی‌صدا عوض می‌شود. برعکسش هم هست: `SettingsSearchDelegate` روی `SettingsRegistry.all` می‌چرخد نه روی تنظیمات قابل‌نمایش، پس `identity_gender_asked` و `identity_age_asked` و `onboarding_completed` در جست‌وجو ظاهر می‌شوند و با لمس، کاربر را به صفحه‌ای می‌برند که اصلاً شامل آن‌ها نیست.

**فایل‌ها:** `lib/core/settings/settings_registry.dart`

**کار دقیق:**
1. `visibility: SettingVisibility.internal` را روی `identity_gender_asked`، `identity_age_asked`، `onboarding_completed` بگذار.
2. `userVisibleByGroup` را بازنویسی کن تا فقط بر اساس `visibility` تصمیم بگیرد و یک پارامتر `bool includeAdvanced = true` بگیرد. دیگر به `descriptionFa` و پسوند `_asked` تکیه نکن.
3. اضافه کن: `static List<SettingDescriptor> searchable()` که همهٔ توصیفگرهای غیرداخلی را برمی‌گرداند.

**معیار پذیرش:** حذف `descriptionFa` از یک تنظیم، آن را از رابط کاربری حذف **نمی‌کند**.

**تست:** SET-61.

**commit:** `fix(settings): SET-08 — قابلیت دیده‌شدن صریح به‌جای قرارداد ضمنی`

---

### SET-09 — علامت‌گذاری `affectsAgenda` و `dependsOn`

**باگ (`affectsAgenda`):** `SettingsService.set` برای **هر** کلیدی `_scheduleAgendaRefreshSignal()` را صدا می‌زند که در نهایت `RitmoEvents.notifyRoutineChanged()` می‌فرستد. صفحهٔ خانه، تقویم و هاب سیستم‌ها به این سیگنال گوش می‌دهند و **کل روز را دوباره می‌سازند**. یعنی عوض کردن عکس پروفایل، روشن کردن «سیاه خالص OLED» یا خاموش کردن گزارش خطا، یک بازسازی کامل اجندا راه می‌اندازد.

**باگ (`dependsOn`):** تنظیمات وابسته هرگز غیرفعال نمی‌شوند. کاربر «شروع ساعات سکوت» را عوض می‌کند در حالی که «ساعات سکوت» خاموش است و هیچ اتفاقی نمی‌افتد؛ «دورهٔ پشتیبان‌گیری» را تنظیم می‌کند در حالی که پشتیبان‌گیری خودکار خاموش است.

**فایل‌ها:** `lib/core/settings/settings_registry.dart`

**کار دقیق:**
1. `affectsAgenda: true` را **فقط** روی این کلیدها بگذار:
   `calendar_show_tasks`، `calendar_show_events`، `calendar_show_commitments`، `calendar_show_appointments`، `calendar_show_sleep_band`، `calendar_show_worship_obligatory`، `calendar_show_worship_mustahab`، `calendar_show_worship_qada`، `calendar_compress_recurring`، `calendar_show_occasions`، `calendar_overdue_lookback_days`، `show_cycle_in_calendar`، `wake_time`، `sleep_time`، `daily_capacity_minutes`، و همهٔ کلیدهای `module_*`.
2. `dependsOn` را بگذار:
   - `notif_quiet_start` و `notif_quiet_end` به `notif_quiet_enabled`
   - `notif_biometric_enabled`، `digest_mode`، `coalescing_window_minutes`، `max_non_essential_per_hour`، `snooze_minutes`، `snooze_max_defer_count`، `persistent_status_notification_enabled`، `daily_planning_nudge_enabled` به `notif_master_enabled`
   - `daily_planning_nudge_time` به `daily_planning_nudge_enabled`
   - `backup_frequency_days` به `auto_backup_enabled`
   - `ai_memory_implicit_enabled` به `ai_memory_enabled`
   - `app_biometric_enabled`، `app_lock_timeout_seconds`، `app_use_device_lock` به `app_lock_enabled`
   - `cycle_biometric_enabled` به `module_cycle_enabled`

**معیار پذیرش:** تعداد `affectsAgenda: true` دقیقاً برابر تعداد کلیدهای فهرست بالا است.

**تست:** SET-61 بررسی می‌کند هر `dependsOn` به کلیدی اشاره می‌کند که واقعاً در رجیستری هست و از نوع `boolean` است.

**commit:** `feat(settings): SET-09 — علامت‌گذاری وابستگی و اثر بر اجندا`

---

### SET-10 — پشتیبانی از وابستگی غیربولی

**باگ:** `ai_base_url`، `ai_model` و `ai_api_key` فقط وقتی معنا دارند که `ai_mode == 'personal_key'` باشد، ولی `ai_mode` یک enum است نه بولی، پس `dependsOn` تنهایی کافی نیست.

**فایل‌ها:** `lib/core/settings/settings_registry.dart`

**کار دقیق:**
1. فیلد `final String? dependsOnValue;` را اضافه کن.
2. قرارداد: تنظیم فعال است اگر `dependsOn == null`، یا `dependsOnValue == null` و مقدار والد بولیِ `true` باشد، یا `dependsOnValue != null` و مقدار والد رشته‌ای دقیقاً برابر `dependsOnValue` باشد.
3. یک متد کمکی اضافه کن:
   ```dart
   static bool isEnabledNow(SettingDescriptor d, Object? Function(String key) read)
   ```
   که همین قرارداد را پیاده کند. این متد در SET-40 توسط رندر خودکار استفاده می‌شود.
4. روی سه کلید `ai_base_url`، `ai_model`، `ai_api_key` مقدار `dependsOn: 'ai_mode', dependsOnValue: 'personal_key'` بگذار.

**معیار پذیرش:** `isEnabledNow` برای `ai_model` وقتی `ai_mode == 'ritmo_server'` است `false` برمی‌گرداند.

**تست:** SET-61.

**commit:** `feat(settings): SET-10 — وابستگی مبتنی بر مقدار برای تنظیمات هوش مصنوعی`

---

## فاز B — سرویس تنظیمات و درستی داده (SET-11 … SET-22)

### SET-11 — بارگذاری واقعی تنظیمات scope `secure` [بحرانی]

**باگ:** در `SettingsService.init()`، شاخهٔ `SettingScope.secure` فقط `_cache[desc.key] = desc.defaultValue` انجام می‌دهد با کامنت «Lazy loaded or defaults in cache» — ولی **هیچ بارگذار تنبلی وجود ندارد** و `get<T>()` فقط از `_cache` می‌خواند. نتیجه: پس از هر راه‌اندازی مجدد اپ، `get<String>('ai_api_key')` و `get<String>('app_lock_password')` و `get<String>('cycle_lock_password')` همیشه رشتهٔ خالی برمی‌گردانند، در حالی که مقدار واقعی در `SecureKeyStore` سالم است.

**مدرک قطعی:** `SecurityGroupScreen._loadState` رمزها را مستقیماً با `await SecureKeyStore.getKey(...)` می‌خواند و هرگز از `SettingsService.get` استفاده نمی‌کند. یعنی کسی قبلاً به این مشکل خورده و به جای رفع ریشه، دورش زده است.

**فایل‌ها:** `lib/core/settings/settings_service.dart`

**کار دقیق:**
1. در `init()`، برای هر توصیفگر با `scope == SettingScope.secure` مقدار را واقعاً از `SecureKeyStore.getKey(desc.key)` بخوان. همهٔ این خواندن‌ها را با `Future.wait` موازی کن تا زمان راه‌اندازی طولانی نشود.
2. **اما مقدار خام را در `_cache` نگذار.** به جایش یک نگاشت جداگانه `Map<String, bool> _secureKeyPresence` بساز که فقط می‌گوید این کلید مقدار دارد یا نه. در `_cache` برای کلیدهای `secure` همیشه رشتهٔ خالی بماند.
3. دو متد جدید بساز: `bool hasSecureValue(String key)` که بدون افشای مقدار می‌گوید مقداری ذخیره شده یا نه، و `Future<String?> readSecure(String key)` که فقط در لحطهٔ مصرف می‌خواند و هرگز کش نمی‌کند.
4. در `get<T>()` اگر توصیفگر `secure` بود، یک `assert(false, 'برای کلیدهای امن از readSecure استفاده کن')` بگذار تا هیچ‌کس دوباره این مسیر را اشتباه نرود.
5. هر جایی که قبلاً `get<String>('ai_api_key')` می‌زد (با `rg -n "ai_api_key" lib/` پیدا کن) به `await readSecure('ai_api_key')` تبدیل کن.

**معیار پذیرش:** پس از تنظیم کلید شخصی هوش مصنوعی و ریستارت کامل اپ، دستیار همچنان کار می‌کند.

**تست:** `test/settings/secure_scope_test.dart` — با یک `SecureKeyStore` جعلی، پس از `init()` مقدار `hasSecureValue('ai_api_key')` باید `true` باشد و کش باید خالی بماند.

**commit:** `fix(settings): SET-11 — خواندن واقعی تنظیمات امن بدون کش کردن راز`

---

### SET-12 — ذخیرهٔ مقدار متعارف enum به جای مقدار تایپ‌شده [بحرانی]

**باگ:** در `set()`، شاخهٔ `enumeration` ابتدا با مقایسهٔ بی‌توجه به بزرگی و کوچکی حروف یک `match` پیدا می‌کند، ولی بعد `value = strVal` می‌گذارد — یعنی رشتهٔ خامی که فراخوان‌کننده داده، نه مقدار متعارف `match`. پس `'female'` در پایگاه داده می‌نشیند در حالی که بقیهٔ کد با `== 'FEMALE'` مقایسه می‌کند. این باگ ریشهٔ مستقیم فهرست آلودهٔ `allowed` در SET-04 است.

**فایل‌ها:** `lib/core/settings/settings_service.dart`

**کار دقیق:** در شاخهٔ `enumeration`، بعد از پیدا کردن `match`، دقیقاً `value = match` بگذار (نه `strVal`). اگر `match` پیدا نشد، رد کن و لاگ بزن — ولی **مقدار ردشده را در لاگ نیاور** (فقط کلید و فهرست مجاز).

**معیار پذیرش:** `set('user_gender', 'female')` موفق می‌شود و `get<String>('user_gender')` دقیقاً `'FEMALE'` برمی‌گرداند.

**تست:** `test/settings/enum_canonicalization_test.dart`.

**commit:** `fix(settings): SET-12 — ذخیرهٔ مقدار متعارف enum`

---

### SET-13 — یکسان‌سازی تجزیهٔ مقادیر

**باگ:** دو مسیر تجزیهٔ متفاوت وجود دارد: `_parseRaw` برای بولی سختگیرانه `raw == 'true'` می‌زند، ولی `get<T>()` سهل‌گیرانه `'true'`، `'1'`، `'yes'` و اعداد را قبول می‌کند. یعنی یک ردیف قدیمی با مقدار `'1'` در مسیر `init` به `false` و در مسیر `get` به `true` ترجمه می‌شود. علاوه بر این، `SettingsFlags.fromMap` یک تجزیه‌گر سوم است.

**فایل‌ها:** `lib/core/settings/settings_service.dart`، فایل جدید `lib/core/settings/setting_value_codec.dart`

**کار دقیق:**
1. یک کلاس تنها-مرجع بساز:
   ```dart
   abstract final class SettingValueCodec {
     static bool decodeBool(Object? raw, {required bool fallback});
     static int decodeInt(Object? raw, {required int fallback});
     static String decodeString(Object? raw, {required String fallback});
     static String encode(Object value);
   }
   ```
2. `decodeBool` مقادیر `true`، `'true'`، `'1'`، `'yes'`، `1` را `true` بگیرد و `false`، `'false'`، `'0'`، `'no'`، `0` را `false`؛ هر چیز دیگر `fallback`.
3. هم `_parseRaw` و هم `get<T>()` را وادار کن فقط از این تابع‌ها استفاده کنند. هیچ مقایسهٔ دستی در این دو باقی نماند.

**معیار پذیرش:** جست‌وجوی مقایسهٔ دستی با رشتهٔ `true` در `lib/core/settings/` فقط داخل `setting_value_codec.dart` نتیجه می‌دهد.

**تست:** `test/settings/setting_value_codec_test.dart` با همهٔ مقادیر بالا.

**commit:** `fix(settings): SET-13 — تجزیه‌گر واحد برای مقادیر تنظیمات`

---

### SET-14 — `set()` نباید پس از موفقیت شکست اعلام کند

**باگ:** `SnapshotHelper.updateNotificationSettingsSnapshot(...)` داخل همان بلوک `try` نوشتن فراخوانی می‌شود. اگر این فراخوانی خطا بدهد، `catch` مقدار `false` برمی‌گرداند — در حالی که مقدار قبلاً هم در پایگاه داده نوشته شده و هم در `_cache` نشسته. کاربر پیام «ذخیره نشد» می‌بیند در حالی که تغییر اعمال شده است.

**فایل‌ها:** `lib/core/settings/settings_service.dart`

**کار دقیق:**
1. نوشتن در منبع داده و به‌روزرسانی `_cache` را در بلوک `try` اصلی نگه دار.
2. فراخوانی‌های جانبی (snapshot، سیگنال اجندا، بالا بردن revision) را **بعد از** بلوک موفقیت، هر کدام در `try/catch` مستقل خودش قرار بده که فقط لاگ می‌زنند و روی مقدار بازگشتی اثر ندارند.
3. نتیجهٔ گویا بساز و جایگزین `bool` کن:
   ```dart
   sealed class SettingWriteResult {}
   final class SettingWriteOk extends SettingWriteResult {}
   final class SettingWriteRejected extends SettingWriteResult {
     final String reasonFa;
   }
   final class SettingWriteFailed extends SettingWriteResult {
     final String reasonFa;
   }
   ```
   `SettingWriteRejected` یعنی اعتبارسنجی رد کرد (خارج از بازه، enum نامعتبر، کلید ناشناخته)؛ `SettingWriteFailed` یعنی ذخیره‌سازی شکست خورد. `reasonFa` متن فارسی آمادهٔ نمایش است.
4. متد `Future<bool> set(...)` را نگه دار ولی به `setChecked(...)` که `SettingWriteResult` می‌دهد دلگیت کن.

**معیار پذیرش:** با یک `SnapshotHelper` جعلی که همیشه خطا می‌دهد، `setChecked` همچنان `SettingWriteOk` می‌دهد.

**تست:** `test/settings/set_result_test.dart`.

**commit:** `fix(settings): SET-14 — نتیجهٔ نوشتن مستقل از کارهای جانبی`

---

### SET-15 — اعتبارسنجی نوع `time`

**باگ:** در `set()` فقط سه شاخهٔ `integer`، `enumeration` و `boolean` اعتبارسنجی دارند. نوع `time` هیچ شاخه‌ای ندارد، پس `'25:99'`، رشتهٔ خالی، `'abc'` و `'8'` همه پذیرفته می‌شوند و در `wake_time`، `sleep_time`، `notif_quiet_start`، `notif_quiet_end` و `daily_planning_nudge_time` می‌نشینند. تجزیه‌گرهای پایین‌دستی این‌ها را بی‌صدا به نیمه‌شب ترجمه می‌کنند — یعنی کاربر ساعت بیداری را اشتباه وارد می‌کند و کل برنامهٔ روز از نیمه‌شب حساب می‌شود.

**فایل‌ها:** `lib/core/settings/settings_service.dart`، `lib/core/utils/time_of_day_minutes.dart` (اگر وجود ندارد بساز)

**کار دقیق:**
1. تابع `int? parseHhMm(String raw)` بساز که: ارقام فارسی و عربی را اول با `toEnglishDigits` به لاتین تبدیل کند، `trim` کند، سپس ساعت ۰ تا ۲۳ و دقیقهٔ ۰ تا ۵۹ را بپذیرد و در غیر این صورت `null` بدهد. **خطا را به صفر نگاشت نکن.**
2. در `set()` یک شاخهٔ `SettingType.time` اضافه کن: اگر `parseHhMm` مقدار `null` داد، `SettingWriteRejected` با متن «ساعت واردشده معتبر نیست.» بده.
3. مقدار ذخیره‌شده را متعارف کن: همیشه دو رقمی با صفر پیشوند و با ارقام لاتین (مثلاً `'8:5'` به `'08:05'`).

**معیار پذیرش:** `set('wake_time', '25:99')` رد می‌شود؛ مقدار با ارقام فارسی پذیرفته و به صورت `'08:30'` ذخیره می‌شود.

**تست:** `test/settings/time_validation_test.dart`.

**commit:** `fix(settings): SET-15 — اعتبارسنجی و متعارف‌سازی مقادیر ساعت`

---

### SET-16 — اعتبارسنجی نوع `text`

**باگ:** نوع `text` هم هیچ اعتبارسنجی‌ای ندارد. `user_name` می‌تواند هزاران کاراکتر باشد و لی‌آوت هدر هویت را بشکند؛ `ai_base_url` می‌تواند یک متن فارسی باشد و درخواست شبکه را در زمان اجرا بشکند.

**فایل‌ها:** `lib/core/settings/settings_registry.dart`، `lib/core/settings/settings_service.dart`

**کار دقیق:**
1. دو فیلد به توصیفگر اضافه کن: `final int? maxLength;` و `final SettingTextFormat textFormat;` با `enum SettingTextFormat { free, url, filePath }` (پیش‌فرض `free`).
2. مقادیر را بگذار: `user_name` با `maxLength: 40`؛ `ai_base_url` با `textFormat: url`؛ `ai_model` با `maxLength: 80`؛ `user_avatar_path` با `textFormat: filePath`.
3. در `set()` یک شاخهٔ `SettingType.text` اضافه کن: `trim` کن؛ اگر از `maxLength` گذشت رد کن؛ اگر `textFormat == url` و مقدار خالی نیست، با `Uri.tryParse` بررسی کن که مطلق است و طرحش `http` یا `https` است.
4. پیام‌های رد را فارسی و مشخص بنویس: «نشانی واردشده معتبر نیست. باید با https شروع شود.»

**معیار پذیرش:** `set('ai_base_url', 'abc')` رد می‌شود و پیام فارسی می‌دهد.

**تست:** `test/settings/text_validation_test.dart`.

**commit:** `fix(settings): SET-16 — اعتبارسنجی مقادیر متنی`

---

### SET-17 — خطای `init()` نباید بی‌صدا به پیش‌فرض کارخانه برگردد [بحرانی]

**باگ:** بلوک `catch` در `init()` همهٔ پیش‌فرض‌ها را در کش می‌ریزد و باز هم `_initialized = true` می‌گذارد. یعنی اگر دیتابیس یک لحطه قفل باشد، کاربر صفحهٔ تنطیمات را کاملاً کارخانه‌ای می‌بیند — ماژول‌ها خاموش، قفل برنامه غیرفعال، حالت حریم خصوصی بازگشته به پیش‌فرض — و بدتر: اولین تغییر بعدی او، این پیش‌فرض‌ها را روی دادهٔ سالم می‌نویسد. این یک مسیر از-دست-رفتن داده است.

**فایل‌ها:** `lib/core/settings/settings_service.dart`

**کار دقیق:**
1. وضعیت صریح اضافه کن:
   ```dart
   enum SettingsLoadState { notLoaded, loaded, degraded }
   final ValueNotifier<SettingsLoadState> loadState =
       ValueNotifier(SettingsLoadState.notLoaded);
   ```
2. در `catch` مقدار `loadState.value = SettingsLoadState.degraded` بگذار و `RitmoLog.error('[SettingsService] init failed', e, st)` بزن.
3. **در حالت `degraded` هر فراخوانی `set` باید `SettingWriteFailed` بدهد** با متن «تنطیمات هنوز کامل بارگذاری نشده است.» تا روی دادهٔ سالم ننویسد.
4. یک متد `Future<void> retryInit()` بساز که کش را خالی می‌کند و دوباره تلاش می‌کند.
5. بنر قرمز متناطر این حالت در SET-42 ساخته می‌شود.

**معیار پذیرش:** با یک `DatabaseHelper` جعلی که خطا می‌دهد، `loadState` برابر `degraded` می‌شود و `set` هیچ چیزی نمی‌نویسد.

**تست:** `test/settings/degraded_init_test.dart`.

**commit:** `fix(settings): SET-17 — حالت تخریب‌شده به جای بازگشت بی‌صدا به پیش‌فرض`

---

### SET-18 — نوشتن مقدار تکراری باید بی‌اثر باشد

**باگ:** `revision.value++` حتی وقتی مقدار جدید دقیقاً برابر مقدار قبلی است هم اجرا می‌شود. در ترکیب با اینکه همهٔ صفحه‌ها به یک `revision` سراسری گوش می‌دهند، هر لمس تکراری یک بازسازی سراسری و یک نوشتن دیسک می‌سازد.

**فایل‌ها:** `lib/core/settings/settings_service.dart`

**کار دقیق:** در `set()` بعد از اعتبارسنجی و متعارف‌سازی، مقدار متعارف را با `_cache[key]` مقایسه کن؛ اگر برابر بود بدون نوشتن دیسک، بدون بالا بردن `revision` و بدون سیگنال اجندا، `SettingWriteOk` برگردان. برای کلیدهای `secure` این میان‌بر را **اعمال نکن** (چون کش عمداً خالی است).

**معیار پذیرش:** دو بار فراخوانی پشت سر هم با مقدار یکسان، فقط یک بار `revision` را بالا می‌برد.

**تست:** `test/settings/no_op_write_test.dart`.

**commit:** `perf(settings): SET-18 — نادیده گرفتن نوشتن مقدار تکراری`

---

### SET-19 — سیگنال اجندا: فقط کلیدهای مرتبط، و قابل لغو

**باگ ۱:** `_scheduleAgendaRefreshSignal()` برای **هر** کلیدی اجرا می‌شود. تغییر مسیر آواتار، روشن کردن سیاهی مطلق تم، یا خاموش کردن گزارش خرابی هم یک بازسازی کامل اجندا راه می‌اندازد.

**باگ ۲:** `_agendaSignalScheduled` یک متغیر `static` است و تایمر با `Future.delayed(agendaSignalDebounce)` ساخته می‌شود که **قابل لغو نیست**. در تست‌ها بین موارد تست نشت می‌کند و پس از dispose شدن شنونده‌ها شلیک می‌کند.

**فایل‌ها:** `lib/core/settings/settings_service.dart`

**کار دقیق:**
1. فراخوانی را مشروط کن به `desc.affectsAgenda == true` (فیلد ساخته‌شده در SET-02 و مقداردهی‌شده در SET-09).
2. `_agendaSignalScheduled` را به یک فیلد نمونه‌ای `Timer? _agendaSignalTimer` تبدیل کن و از `Timer(agendaSignalDebounce, ...)` استفاده کن. در هر فراخوانی جدید، اول `_agendaSignalTimer?.cancel()`.
3. یک متد `void disposeForTest()` اضافه کن که تایمر را لغو می‌کند، کش را خالی می‌کند و `_initialized` را `false` می‌گذارد. در `tearDown` همهٔ تست‌های تنطیمات صدایش بزن.

**معیار پذیرش:** تغییر `theme_true_black` هیچ سیگنال اجندایی تولید نمی‌کند؛ تغییر `wake_time` دقیقاً یک سیگنال تولید می‌کند.

**تست:** `test/settings/agenda_signal_test.dart` با `fakeAsync` یا `FakeTimer`.

**commit:** `perf(settings): SET-19 — سیگنال اجندا فقط برای کلیدهای موردی`

---

### SET-20 — مهاجرت طرحواره و پاک‌سازی ردیف‌های یتیم

**باگ:** جدول `app_settings` هیچ نسخهٔ طرحواره‌ای ندارد. هر کلیدی که در گذشته حذف یا تغییرنام شده باشد برای همیشه به عنوان ردیف یتیم باقی می‌ماند و مسیر مهاجرتی وجود ندارد — دقیقاً همین مسأله باعث می‌شود کلیدهای دروغین SET-23 قابل تشخیص نباشند.

**فایل‌ها:** `lib/core/settings/settings_service.dart`، فایل جدید `lib/core/settings/settings_migrations.dart`

**کار دقیق:**
1. یک کلید داخلی `settings_schema_version` (از نوع `integer`، `visibility: internal`، پیش‌فرض `0`) ثبت کن.
2. در `settings_migrations.dart` یک لیست مرتب از مهاجرت‌ها بساز:
   ```dart
   typedef SettingsMigration = Future<void> Function(SettingsMigrationContext ctx);
   /// ctx.renameKey(from, to), ctx.deleteKey(key), ctx.setIfAbsent(key, value)
   const List<SettingsMigration> settingsMigrations = [ /* v1, v2, ... */ ];
   ```
3. مهاجرت v1 را بنویس که: کلیدهای قدیمی مربوط به پرچم‌های SET-23 را به کلیدهای ثبت‌شده در رجیستری تغییرنام می‌دهد (فقط اگر مقصد خالی باشد؛ مقدار موجود مقصد را بازنویسی نکن).
4. در پایان `init()` مهاجرت‌های لازم را در یک تراکنش اجرا کن و نسخه را بالا ببر. اگر مهاجرت خطا داد، وارد حالت `degraded` شو (SET-17) و نسخه را بالا نبر.
5. **ردیف‌های یتیم را خودکار حذف نکن.** فقط تعدادشان را لاگ کن و در ابزار بازرسی دیباگ (SET-70) نمایش بده — حذف خودکار دادهٔ ناشناخته ریسک از-دست-رفتن داده دارد.

**معیار پذیرش:** با یک پایگاه دادهٔ دارای کلید قدیمی، پس از `init()` مقدار روی کلید جدید قرار گرفته و `settings_schema_version` بالا رفته است؛ اجرای دوم `init()` هیچ کاری نمی‌کند (idempotent).

**تست:** `test/settings/settings_migrations_test.dart`.

**commit:** `feat(settings): SET-20 — نسخهٔ طرحواره و مهاجرت کلیدها`

---

### SET-21 — نوشتن دسته‌ای `setMany`

**مشکل:** جریان پایان آنبوردینگ و دریافت داده از پشتیبان، ده‌ها فراخوانی `set` پشت سر هم می‌زند. هر کدام یک نوشتن دیسک، یک `revision++` و یک بازسازی سراسری درست می‌کند. لرزش محسوس رابط کاربری در پایان آنبوردینگ نتیجهٔ مستقیم این الگوست.

**فایل‌ها:** `lib/core/settings/settings_service.dart`

**کار دقیق:**
1. متد جدید:
   ```dart
   Future<Map<String, SettingWriteResult>> setMany(Map<String, Object> values);
   ```
2. همهٔ مقادیر را اول اعتبارسنجی کن، سپس موارد معتبر را در **یک تراکنش پایگاه داده** (با `batch`) بنویس، بعد یک بار `revision` را بالا ببر و حداکثر یک بار سیگنال اجندا بده (فقط اگر دست‌کم یک کلید `affectsAgenda` داشت).
3. جریان پایان آنبوردینگ و بازگردانی پشتیبان را به این متد منتقل کن (با `rg -n "SettingsService.instance.set\(" lib/` موارد متوالی را پیدا کن).

**معیار پذیرش:** نوشتن ۱۰ تنطیم با `setMany` دقیقاً یک بار `revision` را بالا می‌برد.

**تست:** `test/settings/set_many_test.dart`.

**commit:** `perf(settings): SET-21 — نوشتن دسته‌ای تنطیمات`

---

### SET-22 — `watch`، `reset`، `resetGroup` و حذف کامل `debugPrint`

**باگ ۱:** تنها راه واکنش به تغییرات، `revision` سراسری است؛ هر ویجت برای یک کلید، با تغییر هر ۷۲ کلید دیگر بازسازی می‌شود.

**باگ ۲:** بازگرداندن یک تنطیم به پیش‌فرض هیچ API‌ای ندارد، در حالی که رجیستری همهٔ پیش‌فرض‌ها را می‌داند.

**باگ ۳:** پنج مورد `debugPrint` در `settings_service.dart` وجود دارد که یکی از آن‌ها **مقدار ردشده را چاپ می‌کند** — با توجه به اینکه رمز قفل و کلید API هم از همین مسیر رد می‌شوند، این یک نشت راز در لاگ است.

**فایل‌ها:** `lib/core/settings/settings_service.dart`

**کار دقیق:**
1. `ValueListenable<T> watch<T>(String key)` بساز که فقط وقتی مقدار همان کلید عوض شد خبر می‌دهد. پیاده‌سازی: یک `Map<String, ValueNotifier<Object>> _watchers` که تنبل ساخته می‌شود.
2. `Future<SettingWriteResult> reset(String key)` که مقدار را به `SettingsRegistry.find(key).defaultValue` بازمی‌گرداند.
3. `Future<void> resetGroup(SettingsGroup group)` که از `setMany` استفاده می‌کند. **کلیدهای `secure` و `visibility: internal` را بازنشان نکن** (رمز قفل نباید با یک دکمهٔ «بازنشانی گروه» پاک شود).
4. هر پنج `debugPrint` را با `RitmoLog.error` یا `RitmoLog.debug` جایگزین کن و مقدار داده را از پیام حذف کن؛ فقط کلید، نوع و دلیل رد را بنویس.

**معیار پذیرش:** `rg -n "debugPrint" lib/core/settings` خروجی خالی می‌دهد.

**تست:** `test/settings/watch_and_reset_test.dart` شامل تستی که ثابت کند `resetGroup(SettingsGroup.security)` مقدار `app_lock_password` را دست نمی‌زند.

**commit:** `feat(settings): SET-22 — watch تک‌کلید، بازنشانی و لاگ ایمن`

---

## فاز C — امنیت و حریم خصوصی (SET-23 … SET-30)

### SET-23 — کلیدهای دروغین `SettingsFlags` [بحرانی‌ترین باگ این فاز]

**باگ:** `SettingsFlags.fromMap` چهار کلید می‌خواند که **هیچ‌کدام در `SettingsRegistry` وجود ندارند**:

| کلیدی که `SettingsFlags` می‌خواند | کلید واقعی در رجیستری |
|---|---|
| `cycle_consent` | **وجود ندارد** |
| `proactive_assistant_enabled` | `assistant_proactive_enabled` |
| `briefing_enabled` | `assistant_briefing_enabled` |
| `energy_tuning_enabled` | `module_energy_enabled` |

نتیجهٔ مستقیم: `canShowCycle` روی `cycleConsent` شرط گذاشته و هیچ جایی این کلید را نمی‌نویسد، پس قاعدهٔ حریم خصوصی M-12 همیشه روی پیش‌فرض ثابت ارزیابی می‌شود. دو پرچم دیگر هم همیشه مقدار پیش‌فرض دارند، یعنی **خاموش کردن دستیار پیش‌دستانه و خلاصهٔ روزانه در مسیر پرچم‌ها بی‌اثر است**.

**باگ دوم:** پیش‌فرض‌های `SettingsFlags` با رجیستری در تضادند: جنسیت پیش‌فرض `'MALE'` در مقابل `'UNSET'` در رجیستری، و `module_cycle_enabled` پیش‌فرض `'true'` در مقابل `false` در رجیستری.

**فایل‌ها:** `lib/core/settings/settings_flags.dart`، `lib/core/settings/settings_registry.dart`

**کار دقیق:**
1. اول تصمیم بگیر که `cycle_consent` واقعاً لازم است یا نه. با `rg -n "cycle_consent" lib/` همهٔ موارد مصرف را ببین. **پاسخ مورد انتطار: لازم است** — رضایت صریح برای دادهٔ چرخه یک مفهوم جداگانه از «ماژول روشن است» است. پس یک توصیفگر واقعی ثبت کن:
   ```dart
   SettingDescriptor(
     key: 'cycle_consent',
     type: SettingType.boolean,
     scope: SettingScope.db,
     defaultValue: false,           // رضایت هرگز پیش‌فرض مفروض نمی‌شود
     labelFa: 'رضایت برای دادهٔ چرخه',
     descriptionFa: 'با روشن بودن این گزینه، برنامه مجاز است دادهٔ چرخه را ثبت و در تقویم نمایش دهد.',
     group: SettingsGroup.security,
     aiWritable: false,             // هرگز قابل نوشتن توسط هوش مصنوعی
   )
   ```
2. سه کلید دیگر را در `SettingsFlags.fromMap` به نام واقعی رجیستری اصلاح کن (طبق جدول بالا).
3. پیش‌فرض‌های `SettingsFlags` را حذف کن و جایش **از همان رجیستری بخوان**:
   `SettingsRegistry.find(key)!.defaultValue`. دیگر هیچ پیش‌فرض دستی‌ای در این فایل نماند.
4. در `fromMap` برای تجزیهٔ بولی از `SettingValueCodec.decodeBool` (SET-13) استفاده کن؛ تجزیه‌گر سوم را حذف کن.
5. مهاجرت v1 در SET-20 را کامل کن: اگر ردیفی با کلیدهای قدیمی `proactive_assistant_enabled`، `briefing_enabled` یا `energy_tuning_enabled` در پایگاه داده وجود دارد، مقدارش را به کلید واقعی منتقل کن.

**معیار پذیرش:**
- همهٔ کلیدهایی که `SettingsFlags` می‌خواند در رجیستری موجودند.
- خاموش کردن «دستیار پیش‌دستانه» در تنطیمات، واقعاً `flags.proactiveAssistantEnabled` را `false` می‌کند.
- تا وقتی کاربر رضایت نداده، `canShowCycle` مقدار `false` است.

**تست:** `test/settings/settings_flags_keys_test.dart` — یک تست که برای **هر** کلیدی که `SettingsFlags` مصرف می‌کند `SettingsRegistry.find(key) != null` را تأیید کند، به اضافهٔ تست قاعدهٔ M-12.

**commit:** `fix(settings): SET-23 — اصلاح کلیدهای دروغین پرچم‌ها و ثبت cycle_consent`

---

### SET-24 — `aiWritable` باید در مسیر نوشتن اعمال شود [بحرانی]

**باگ:** رجیستری فیلد `aiWritable` و گرداورندهٔ `aiWritableKeys` دارد، اما **`SettingsService.set()` هرگز آن را بررسی نمی‌کند.** یعنی هر ابزار هوش مصنوعی که به `SettingsService` دسترسی دارد می‌تواند `app_lock_enabled` را `false` کند، `assistant_cloud_consent` را روشن کند یا `notif_privacy_mode` را به `none` ببرد. محافط موجود، دکور است.

**فایل‌ها:** `lib/core/settings/settings_service.dart`، و هر ابزار هوش مصنوعی که تنطیمات می‌نویسد (با `rg -n "SettingsService.instance.set" lib/core/ai lib/features/assistant` پیدا کن)

**کار دقیق:**
1. منشأ نوشتن را صریح کن:
   ```dart
   enum SettingsWriteOrigin { user, system, ai }
   Future<SettingWriteResult> setChecked(
     String key,
     Object value, {
     SettingsWriteOrigin origin = SettingsWriteOrigin.user,
   });
   ```
2. **فیل-کلوزد:** اگر `origin == SettingsWriteOrigin.ai` و `desc.aiWritable != true`، فوراً `SettingWriteRejected` بده با متن «این تنطیم فقط توسط خود شما قابل تغییر است.» — و این رد را در ژورنال ایجنت ثبت کن.
3. یک متد اختصاصی برای هوش مصنوعی بساز تا فراموشی پارامتر ممکن نباشد:
   ```dart
   Future<SettingWriteResult> setByAi(String key, Object value) =>
       setChecked(key, value, origin: SettingsWriteOrigin.ai);
   ```
4. **هر فراخوانی نوشتن تنطیمات در مسیر ایجنت/دستیار را به `setByAi` تغییر بده.** هیچ کد ایجنتی نباید مستقیماً `set` یا `setChecked` بزند.
5. فهرست `aiWritable` را بازبینی کن. در حال حاضر فقط سه کلید `notif_master_enabled`، `notif_quiet_enabled` و `theme_mode` علامت خورده‌اند. **این فهرست را گسترش نده.** فقط مطمئن شو که هیچ کلید امنیتی، هیچ کلید `secure`، `cycle_consent`، `assistant_cloud_consent`، `notif_privacy_mode` و `app_lock_*` علامت `aiWritable` نخورده‌اند.
6. در توصیفگر، برای هر کلید `secure` یک `assert(aiWritable == false)` بگذار (در همان اعتبارسنجی سازندهٔ SET-03).

**معیار پذیرش:** `setByAi('app_lock_enabled', false)` رد می‌شود و مقدار در پایگاه داده دست نمی‌خورد؛ `setByAi('theme_mode', 'dark')` موفق می‌شود.

**تست:** `test/settings/ai_write_guard_test.dart` — حلقه‌ای روی **همهٔ** توصیفگرها: برای هر توصیفگر با `aiWritable == false`، `setByAi` باید رد کند. به علاوه یک تست که ثابت کند هیچ کلید `secure` یا امنیتی در `aiWritableKeys` نیست.

**commit:** `fix(settings): SET-24 — اعمال واقعی محافط aiWritable`

---

### SET-25 — PIN: حذف نوشتن دوگانه و ذخیرهٔ هش‌شده [بحرانی]

**باگ ۱ (نوشتن دوگانه):** `SecurityGroupScreen._setPin` هم `SecureKeyStore.setKey(keyName, pin)` می‌زند و هم `SettingsService.instance.set(keyName, pin)`. مورد دوم باعث می‌شود **PIN به صورت متن ساده در `_cache` سینگلتون تا پایان عمر پروسه بماند** و در هر دامپ حافطه قابل مشاهده باشد.

**باگ ۲ (ذخیرهٔ بازگشت‌پذیر):** PIN به صورت متن قابل بازیابی ذخیره می‌شود، نه هش نمک‌دار. برای قفل محلی هیچ دلیلی برای بازیابی‌پذیر بودن PIN وجود ندارد.

**باگ ۳:** `_hasAppPassword` برای فهمیدن «آیا رمزی هست؟» **خود رمز واقعی را می‌خواند**. راز بی‌دلیل در حافطهٔ ویجت می‌نشیند.

**فایل‌ها:** `lib/features/settings/presentation/groups/security_group_screen.dart`، فایل جدید `lib/core/security/pin_credential.dart`

**کار دقیق:**
1. `pin_credential.dart` بساز:
   ```dart
   abstract final class PinCredential {
     /// نمک تصادفی ۱۶ بایتی تولید می‌کند و رشتهٔ ذخیره‌شدنی می‌دهد.
     static Future<String> hash(String pin);
     /// مقایسهٔ زمان-ثابت.
     static Future<bool> verify(String pin, String stored);
   }
   ```
   قالب ذخیره: `v1.` سپس نمک به base64 سپس خروجی PBKDF2 یا SHA-256 به base64 (بسته به وابستگی موجود در `pubspec.yaml`؛ وابستگی جدید اضافه نکن مگر `crypto` قبلاً هست).
2. در `_setPin`: فراخوانی `SettingsService.instance.set(keyName, pin)` را **حذف کن**. فقط `SecureKeyStore.setKey(keyName, await PinCredential.hash(pin))`.
3. منطق تأیید قفل (با `rg -n "app_lock_password" lib/` پیدا کن) را به `PinCredential.verify` تغییر بده.
4. `_hasAppPassword` را به `SettingsService.instance.hasSecureValue('app_lock_password')` (SET-11) تغییر بده تا دیگر راز را نخواند.
5. مهاجرت: اگر مقدار ذخیره‌شده با `v1.` شروع نمی‌شود، یعنی PIN قدیمی متن ساده است: در اولین تأیید موفق، بی‌سروصدا به فرم هش‌شده ارتقا بده (کاربر نباید دوباره PIN تعیین کند).
6. **پاک‌سازی کش آلوده:** در مهاجرت SET-20 یک مرحله اضافه کن که ردیف‌های `app_lock_password` و `cycle_lock_password` را از جدول `app_settings` حذف می‌کند (اگر نوشتن دوگانه قبلاً آن‌جا را آلوده کرده). این تنها حذف خودکار مجاز است، چون داده رازی در جای اشتباه است.

**معیار پذیرش:** جست‌وجوی جدول `app_settings` پس از تعیین PIN هیچ ردیف رمزی ندارد؛ مقدار ذخیره‌شده در `SecureKeyStore` برابر PIN واردشده نیست؛ ورود با PIN قدیمی همچنان کار می‌کند.

**تست:** `test/settings/pin_credential_test.dart` شامل تست مهاجرت از متن ساده به هش.

**commit:** `fix(settings): SET-25 — ذخیرهٔ هش‌شدهٔ PIN و حذف نوشتن دوگانه`

---

### SET-26 — قفل برنامه بدون رمز نباید قابل روشن شدن باشد

**باگ:** کلید `app_lock_enabled` مستقل از وجود `app_lock_password` و مستقل از فعال بودن بیومتریک قابل روشن شدن است. کاربر می‌تواند قفل را روشن کند بدون اینکه هیچ راه باز کردنی داشته باشد. علاوه بر این PIN فقط ۴ رقم، بدون فیلد تکرار، بدون الزام رقمی بودن (`keyboardType` فقط یک راهنمای صفحه‌کلید است، محدودیت واقعی نیست) و بدون مسیر بازیابی است.

**فایل‌ها:** `lib/features/settings/presentation/groups/security_group_screen.dart`

**کار دقیق:**
1. در منطق سویچ `app_lock_enabled`: اگر کاربر روشن کرد و هیچ رمزی وجود ندارد، **اول دیالوگ تعیین PIN را باز کن**؛ اگر کاربر لغو کرد، سویچ را برگردان و هیچ تنطیمی ذخیره نکن.
2. دیالوگ PIN را بازنویسی کن: دو فیلد (رمز و تکرار رمز)، `inputFormatters: [FilteringTextInputFormatter.digitsOnly]`، حداقل ۴ و حداکثر ۸ رقم، پیام خطای فارسی وقتی دو فیلد یکسان نیستند، و رد کردن PIN‌های بدیهی مانند `0000` و `1234` با متن «این رمز خیلی قابل حدس است.»
3. یک متن هشدار صریح زیر دیالوگ بگذار: «این رمز فقط روی این دستگاه ذخیره می‌شود و قابل بازیابی نیست. اگر فراموشش کنید، تنها راه، بازنشانی کارخانه است.»
4. همین منطق را برای `cycle_biometric_enabled` و `cycle_lock_password` هم اعمال کن.

**معیار پذیرش:** روشن کردن قفل بدون تعیین رمز غیرممکن است؛ `app_lock_enabled == true` همیشه یعنی دست‌کم یک روش باز کردن وجود دارد.

**تست:** `test/settings/app_lock_invariant_test.dart` (تست ویجت).

**commit:** `fix(settings): SET-26 — قفل برنامه بدون روش باز کردن ممکن نیست`

---

### SET-27 — بیومتریک: بررسی واقعی در دسترس بودن

**باگ:** بستهٔ `local_auth` در `security_group_screen.dart` **import شده ولی `LocalAuthentication` هرگز استفاده نشده است.** یعنی سویچ «احراز هویت بیومتریک» روی دستگاهی که اثر انگشت یا چهره ندارد هم روشن می‌شود — کاربر فکر می‌کند محافطت دارد و ندارد.

**فایل‌ها:** `lib/features/settings/presentation/groups/security_group_screen.dart`

**کار دقیق:**
1. در `initState` یک بار `LocalAuthentication().canCheckBiometrics` و `isDeviceSupported()` را بخوان و در `bool _biometricsAvailable` نگه دار (این خواندن را در `try/catch` بگذار که در صورت خطا `false` بماند و خطا با `RitmoLog` ثبت شود).
2. اگر در دسترس نیست، سویچ‌های `app_biometric_enabled` و `cycle_biometric_enabled` و `notif_biometric_enabled` را غیرفعال کن و زیرشان بنویس: «این دستگاه احراز هویت بیومتریک ندارد یا ثبت نشده است.»
3. قبل از روشن کردن هر سویچ بیومتریک، یک بار `authenticate` را واقعاً اجرا کن؛ فقط در صورت موفقیت تنطیم را ذخیره کن.

**معیار پذیرش:** `rg -n "local_auth" lib/features/settings` نتیجه دارد **و** `rg -n "LocalAuthentication" lib/features/settings` هم نتیجه دارد (یعنی import بی‌مصرف نیست).

**تست:** تست ویجت با یک `LocalAuthentication` جعلی که `canCheckBiometrics == false` می‌دهد.

**commit:** `fix(settings): SET-27 — بررسی واقعی در دسترس بودن بیومتریک`

---

### SET-28 — مهلت قفل: معنای مقدار ویژه را در رابط کاربری روشن کن

**باگ:** `app_lock_timeout_seconds` بازهٔ `min: -1` و `max: 3600` دارد و مقدار `-1` در عمل به معنای «هرگز» است — این فقط در `timeoutLabels` داخل ویجت دیده می‌شود و در رجیستری هیچ جا مستند نشده. هر مصرف‌کنندهٔ جدیدی که عدد را مقایسهٔ عددی کند، `-1` را به اشتباه به معنای «فوری» تفسیر می‌کند.

**فایل‌ها:** `lib/features/settings/presentation/groups/security_group_screen.dart`، `lib/core/settings/settings_registry.dart`

**کار دقیق:**
1. از ثابت‌های `AppLockTimeout` (SET-07) استفاده کن؛ عدد خام `-1` و `0` دیگر در هیچ کدی نوشته نشود.
2. در `descriptionFa` همین توصیفگر صریح بنویس: «مقدار «هرگز» یعنی تا وقتی خودتان برنامه را نبندید، قفل فعال نمی‌شود.»
3. در رابط کاربری، کنار گزینهٔ «هرگز» یک نشانهٔ هشدار زرد بگذار با متن «کمترین میزان محافطت».
4. مقداردهی با عددی خارج از مجموعهٔ پیش‌تعیین‌شده را در `set()` رد کن (از `allowed` عددی یا یک اعتبارسنج اختصاصی استفاده کن) تا مقادیر معنادار محفوط بمانند.

**معیار پذیرش:** `rg -n "== -1|: -1" lib/features/settings` خروجی خالی می‌دهد.

**تست:** در `test/settings/registry_integrity_test.dart` (SET-64) پوشش داده می‌شود.

**commit:** `refactor(settings): SET-28 — شفاف‌سازی مقدار ویژهٔ مهلت قفل`

---

### SET-29 — منطقهٔ خطر: نرمال‌سازی فارسی، `mounted` و dispose

**باگ ۱:** تأیید بازنشانی کارخانه مقایسهٔ دقیق با رشتهٔ `'پاک کن'` است. اگر کاربر نیم‌فاصله بزند، یا کی‌بوردش کاف و یای عربی بدهد، یا فاصلهٔ اضافی بگذارد، دکمه فعال نمی‌شود و دلیلش را هم نمی‌فهمد.

**باگ ۲:** در `DangerZone` ترتیب فراخوانی `Navigator.pop(ctx)` سپس `await AccountResetService.wipeUserData()` سپس `RitmoToast.show(context, ...)` است — استفاده از `context` پس از `await` بدون محافط `context.mounted`.

**باگ ۳:** دو `TextEditingController` نشت می‌کنند: یکی در `DangerZone` و یکی `pinController` در `SecurityGroupScreen._setPin`. هیچ‌کدام dispose نمی‌شوند.

**فایل‌ها:** `lib/features/settings/presentation/widgets/danger_zone.dart`، `lib/features/settings/presentation/groups/security_group_screen.dart`، فایل جدید `lib/core/utils/persian_text_normalizer.dart`

**کار دقیق:**
1. `persian_text_normalizer.dart` بساز با تابع `String normalizeFa(String input)` که: فاصلهٔ مجازی و نیم‌فاصله را حذف می‌کند، کاف و یای عربی را به فارسی تبدیل می‌کند، ارقام را یکدست می‌کند، فاصله‌های تکراری را جمع می‌کند و `trim` می‌کند. **این تابع در SET-49 برای جست‌وجو هم استفاده می‌شود؛ دوباره ننویسش.**
2. مقایسهٔ عبارت تأیید را به `normalizeFa(input) == normalizeFa('پاک کن')` تغییر بده.
3. زیر فیلد ورودی یک راهنمای زنده بگذار: تا وقتی عبارت درست نشده، متن خاکستری «باید دقیقاً بنویسید: پاک کن» و پس از درست شدن، تیک سبز.
4. در هر دو فایل، پس از هر `await` قبل از استفاده از `context` محافط `if (!context.mounted) return;` بگذار. ترتیب را هم اصلاح کن: اول کار را انجام بده، بعد پیام بده، بعد دیالوگ را ببند.
5. هر دو کنترلر را درست dispose کن: در `StatefulWidget` مربوطه در `dispose()`، و برای کنترلر موقت دیالوگ در بلوک `finally` پس از بسته شدن دیالوگ.
6. `debugPrint` در `danger_zone.dart` را با `RitmoLog.error` جایگزین کن.

**معیار پذیرش:** عبارت تأیید با نیم‌فاصله یا کاف عربی هم پذیرفته می‌شود؛ `flutter analyze` هیچ هشدار `use_build_context_synchronously` نمی‌دهد.

**تست:** `test/settings/persian_text_normalizer_test.dart` با هر چهار نوع ورودی معیوب.

**commit:** `fix(settings): SET-29 — تأیید مقاوم در منطقهٔ خطر و رفع نشت کنترلر`

---

### SET-30 — حسابرسی بازنشانی کارخانه و مخزن امن [حسابرسی — ممکن است باگ نباشد]

**مشکوک:** مشخص نیست `AccountResetService.wipeUserData()` محتوای `SecureKeyStore` را هم پاک می‌کند یا نه. اگر نکند، پس از «بازنشانی کارخانه» رمز قفل برنامه، رمز چرخه و کلید API باقی می‌مانند — کاربر بعدی با یک اپ خالی ولی قفل‌شده روبرو می‌شود، و یک راز مالک قبلی روی دستگاه می‌ماند.

**فایل‌ها:** `lib/core/services/account_reset_service.dart`، `lib/core/services/secure_key_store.dart`، `lib/features/settings/presentation/widgets/danger_zone.dart`

**کار دقیق:**
1. هر دو فایل سرویس را کامل بخوان. مشخص کن `wipeUserData` دقیقاً چه جداولی را پاک می‌کند.
2. اگر مخزن امن پاک نمی‌شود: یک متد `Future<void> clearAll()` در `SecureKeyStore` بساز که **فقط کلیدهای ثبت‌شده در رجیستری با `scope == secure`** را حذف کند (نه کل مخزن که ممکن است دادهٔ سایر بخش‌ها را هم ببرد)، و در پایان `wipeUserData` صدایش بزن.
3. متن دیالوگ بازنشانی را دقیق کن: فهرست صریح و کوتاه از چیزهایی که پاک می‌شوند، و یک خط صریح دربارهٔ رمزها و کلیدها.
4. مطمئن شو `LegacyDatabaseRecovery.createEmergencyBackup(db.path)` قبل از پاک‌سازی واقعاً اجرا می‌شود و اگر خطا داد **عملیات متوقف می‌شود** (در حال حاضر ممکن است خطا بلعیده شود و با وجود نبود پشتیبان، پاک‌سازی ادامه یابد). متن خطا: «پشتیبان اضطراری ساخته نشد؛ برای ایمنی، بازنشانی لغو شد.»
5. اگر پس از خواندن کد مشخص شد مخزن امن قبلاً پاک می‌شود، این تسک را `SKIPPED` بزن و در یادداشت لجر بنویس کدام خط این را انجام می‌دهد — ولی موارد ۳ و ۴ را در هر حالت انجام بده.

**معیار پذیرش:** پس از بازنشانی کارخانه، `hasSecureValue('app_lock_password')` مقدار `false` می‌دهد.

**تست:** `test/settings/factory_reset_test.dart`.

**commit:** `fix(settings): SET-30 — پاک‌سازی کامل رازها در بازنشانی کارخانه`

---

## فاز D — یک منبع حقیقت برای هر تنطیم (SET-31 … SET-37)

### SET-31 — دوگانگی تم: توصیفگرهای یتیم در مقابل صفحهٔ جداگانه [بحرانی]

**باگ:** چهار توصیفگر `theme_mode`، `theme_palette`، `theme_reduce_transparency` و `theme_true_black` در رجیستری ثبت شده‌اند، اما `AppearanceGroupScreen` **هیچ‌یک را رندر نمی‌کند**؛ فقط یک ردیف می‌گذارد که `ThemeSettingsScreen(themeRepository:)` را باز می‌کند. پس:
- این چهار توصیفگر عملاً یتیمند و معلوم نیست منبع حقیقت، `SettingsService` است یا `ThemeRepository`.
- جست‌وجوی تنطیمات این چهار را پیدا می‌کند و کاربر را به صفحه‌ای می‌برد که آن تنطیم درش نیست — یک بن‌بست.
- بج «N تنطیم» گروه ظاهر، عددی می‌شمارد که در صفحه دیده نمی‌شود.

**فایل‌ها:** `lib/features/settings/presentation/groups/appearance_group_screen.dart`، `lib/features/profile/presentation/theme_settings_screen.dart`، `lib/core/theme/theme_repository.dart`

**کار دقیق:**
1. اول `theme_settings_screen.dart` و `theme_repository.dart` را کامل بخوان و مشخص کن `ThemeRepository` داده را در کدام محل ذخیره می‌کند.
2. **تصمیم قطعی (تحقیق دوباره لازم نیست): `SettingsService` منبع حقیقت است.** `ThemeRepository` باید به یک لایهٔ نازک روی `SettingsService` تبدیل شود: خواندن از `get`، نوشتن با `setChecked`، و اطلاع با `watch` (SET-22). هیچ حالت موازی دیگری نگه ندارد.
3. اگر `ThemeRepository` داده را در جای دیگری (مثلاً `SharedPreferences` با کلید متفاوت) می‌نویسد، یک مرحلهٔ مهاجرت در SET-20 اضافه کن که مقدار موجود کاربر را به کلیدهای رجیستری منتقل کند. **تم فعلی کاربر نباید عوض شود.**
4. `ThemeSettingsScreen` را حذف نکن (طراحی اختصاصی پالت دارد)، ولی وادارش کن فقط از طریق `SettingsService` بخواند و بنویسد.
5. در `AppearanceGroupScreen`، دو سویچ سادهٔ `theme_reduce_transparency` و `theme_true_black` را مستقیماً همین جا رندر کن (برای دسترسی سریع و دسترس‌پذیری)، و ردیف «تم و پالت رنگی» را برای دو تای دیگر نگه دار ولی مقدار فعلی را کنار چورون نشان بده (مانند «تیره · زمرد»).

**معیار پذیرش:** تغییر تم از `ThemeSettingsScreen` بلافاصله در `SettingsService.get<String>('theme_mode')` منعکس می‌شود، و برعکس.

**تست:** `test/settings/theme_single_source_test.dart`.

**commit:** `refactor(settings): SET-31 — تم با یک منبع حقیقت`

---

### SET-32 — زبان: نوشتن دوگانهٔ غیراتمی و گزینهٔ انگلیسی نیمه‌کاره [بحرانی]

**باگ ۱:** `_changeLocale` دو نوشتن جداگانه و غیراتمی انجام می‌دهد: یکی `SettingsService.set('locale', loc)` و یکی `localeRepository.updateLocale(Locale(loc))`. اگر دومی خطا بدهد، تنطیمات می‌گوید انگلیسی و رابط کاربری فارسی می‌ماند.

**باگ ۲:** گزینهٔ `'en'` با برچسب `English` عرضه می‌شود، در حالی که **تمام رشته‌های این فیچر فارسی هاردکد شده‌اند** (`labelFa`، `descriptionFa`، عناوین گروه‌ها، پیام‌های خطا). انتخاب انگلیسی یک اپ نیمه‌ترجمه تحویل می‌دهد.

**فایل‌ها:** `lib/features/settings/presentation/groups/appearance_group_screen.dart`، `lib/core/localization/locale_repository.dart`

**کار دقیق:**
1. مانند SET-31، `LocaleRepository` را به لایهٔ نازک روی `SettingsService` تبدیل کن. فقط **یک** نوشتن باقی بماند: `setChecked('locale', loc)`؛ و `LocaleRepository` با `watch('locale')` از همان تغییر باخبر شود.
2. **گزینهٔ انگلیسی را حذف نکن، ولی دروغ نگو.** در همین ویجت دو حالت بساز:
   - اگر ترجمهٔ انگلیسی واقعی وجود دارد (فایل arb یا معادلش در پروژه هست) → فعال بماند.
   - وگرنه گزینه را غیرفعال (disabled) کن و زیرش بنویس: «نسخهٔ انگلیسی در دست ساخت است.» با برچسب «به‌زودی».
   تشخیص را با `ls lib/l10n` یا `rg -n "AppLocalizations" lib/ -l` انجام بده. اگر زیرساخت بومی‌سازی وجود ندارد، حالت دوم را پیاده کن.
3. در `descriptionFa` کلید `locale` بنویس که برای اعمال کامل، ریستارت لازم است و فیلد `requiresRestart: true` (SET-02) را بگذار.

**معیار پذیرش:** در کل فیچر تنطیمات فقط یک محل برای نوشتن زبان وجود دارد؛ کاربر نمی‌تواند به وضعیت نیمه‌ترجمه برسد.

**تست:** `test/settings/locale_single_source_test.dart`.

**commit:** `fix(settings): SET-32 — نوشتن واحد زبان و رفع گزینهٔ فریبنده`

---

### SET-33 — بستن حفرهٔ انسجام کش [بحرانی]

**باگ:** هر کدی که مستقیماً روی جدول `app_settings` SQL بنویسد، `_cache` سینگلتون را دور می‌زند و تا راه‌اندازی مجدد، خواندن‌ها منقضی می‌مانند. دست‌کم یک مورد تأییدشده وجود دارد: `JourneyController.loadDefaultScale` که `calendar_default_scale` را مستقیم می‌خواند.

**فایل‌ها:** همهٔ فایل‌هایی که دستور زیر پیدا می‌کند

**کار دقیق:**
1. اجرا کن:
   ```bash
   rg -n "app_settings" lib/ --glob '!lib/core/settings/**'
   ```
2. هر مورد را به `SettingsService.instance.get<T>(...)` یا `setChecked(...)` تغییر بده. اگر در جایی به دلیل ترتیب راه‌اندازی، سرویس هنوز آماده نیست، به جای SQL خام، `await SettingsService.instance.init()` را زودتر صدا بزن (تابع idempotent است).
3. یک تست معماری بساز که این قانون را برای همیشه قفل کند: `test/architecture/settings_no_raw_sql_test.dart` که درخت `lib/` را پیمایش می‌کند و اگر رشتهٔ `app_settings` خارج از `lib/core/settings/` پیدا شد، فیل می‌شود (مانند الگوی موجود در `test/architecture/`).

**معیار پذیرش:** دستور `rg` بالا خروجی خالی می‌دهد و تست معماری سبز است.

**تست:** `test/architecture/settings_no_raw_sql_test.dart`

**commit:** `fix(settings): SET-33 — حذف دسترسی SQL خام به جدول تنطیمات`

---

### SET-34 — ماژول‌ها: سه منبع حقیقت را به یکی برسان [بحرانی]

**باگ:** وضعیت روشن/خاموش ماژول‌ها از **سه جا** می‌آید:
1. پانزده توصیفگر `module_*` در `SettingsRegistry`
2. `ModuleRegistry.modules` به علاوهٔ `ModuleGate.instance.isEnabled`
3. `ModuleManagementService.setModuleEnabled`

و **هیچ‌کدام از مسیر `SettingsService` رد نمی‌شوند.** نتیجه: `ModulesGroupScreen` از `ModuleGate` می‌خواند، جست‌وجوی تنطیمات از رجیستری می‌خواند، و بج «N تنطیم» عدد سومی را نشان می‌دهد. دو نمای مختلف از همین حقیقت می‌توانند مخالف هم باشند.

**فایل‌ها:** `lib/core/modules/module_gate.dart`، `lib/core/modules/module_registry.dart`، `lib/core/services/module_management_service.dart`، `lib/features/settings/presentation/groups/modules_group_screen.dart`، `lib/core/settings/settings_registry.dart`

**کار دقیق:**
1. اول سه فایل هستهٔ ماژول را کامل بخوان.
2. **تصمیم قطعی: جدول `app_settings` با کلیدهای `module_*` منبع حقیقت است.** `ModuleGate.isEnabled` باید مقدار را از `SettingsService.get<bool>(descriptorKeyFor(moduleKey))` بخواند و `ModuleManagementService.setModuleEnabled` باید از `setChecked` استفاده کند.
3. یک نگاشت صریح و تنها در یک فایل بساز که کلید ماژول در `ModuleRegistry` را به کلید تنطیم `module_*` می‌نگارد. این نگاشت در `module_registry.dart` قرار بگیرد به صورت فیلد `settingsKey` روی `ModuleDescriptor`. **نگاشت رشته‌ای حدسی مانند `'module_' + key + '_enabled'` ننویس** — دو کلید `module_today_routines` و `module_calendar_journey` از این الگو تبعیت نمی‌کنند و پسوند `_enabled` ندارند.
4. یک تست انطباق بنویس: هر ماژول در `ModuleRegistry` دقیقاً یک توصیفگر موجود دارد، و هر توصیفگر `module_*` دقیقاً یک ماژول دارد. هیچ یتیم در هیچ طرف.
5. `defaultEnabled` در `ModuleDescriptor` را حذف کن یا به `SettingsRegistry.find(settingsKey)!.defaultValue` دلگیت کن — دو پیش‌فرض موازی نماند.

**معیار پذیرش:** خاموش کردن یک ماژول از صفحهٔ ماژول‌ها، بلافاصله هم در `ModuleGate.isEnabled` و هم در `SettingsService.get` منعکس می‌شود.

**تست:** `test/settings/module_source_of_truth_test.dart`.

**commit:** `refactor(settings): SET-34 — وضعیت ماژول‌ها با یک منبع حقیقت`

---

### SET-35 — مدیریت کامل نتایج تغییر وضعیت ماژول

**باگ ۱:** `_toggleModule` فقط `ModuleToggleResult.limitReached` را مدیریت می‌کند؛ هر نتیجهٔ دیگری به عنوان موفقیت تلقی می‌شود و رابط کاربری دروغ می‌گوید.

**باگ ۲:** `_showDeactivationWarningDialog` پس از `await` بدون محافط `mounted` فراخوانی `setState` می‌کند.

**فایل‌ها:** `lib/features/settings/presentation/groups/modules_group_screen.dart`، `lib/core/services/module_management_service.dart`

**کار دقیق:**
1. تمام مقادیر `enum ModuleToggleResult` را ببین و در `_toggleModule` یک `switch` **جامع بدون `default`** بنویس تا افزودن مقدار جدید در آینده خطای کامپایل بدهد (این مهم‌ترین قسمت این تسک است).
2. برای هر حالت یک پیام فارسی مشخص بنویس؛ برای حالت‌های شکست، سویچ را به حالت قبل برگردان.
3. برای `limitReached` پیام را عددی و قابل اقدام کن: «سقف ماژول فعال پر است (N از N). برای روشن کردن این ماژول، یکی را خاموش کنید یا به پرمیوم ارتقا دهید.» به همراه دو دکمهٔ مستقیم.
4. بعد از هر `await` محافط `if (!mounted) return;` بگذار.

**معیار پذیرش:** `flutter analyze` هیچ هشدار جامعیت `switch` یا `use_build_context_synchronously` نمی‌دهد؛ هر شکست تغییر وضعیت، سویچ را برمی‌گرداند.

**تست:** تست ویجت با سرویس جعلی برای هر مقدار `ModuleToggleResult`.

**commit:** `fix(settings): SET-35 — مدیریت جامع نتایج تغییر وضعیت ماژول`

---

### SET-36 — تقارن حفاطت در عملیات مخرب

**باگ:** یک عدم‌تقارن جدی در طراحی خطر وجود دارد:
- **بازنشانی کارخانه:** تایپ کردن عبارت دقیق «پاک کن» (محافطت بالا)
- **پاک‌سازی دادهٔ یک ماژول:** یک دکمهٔ «خاموش کن» در یک دیالوگ ساده، بدون تایپ تأیید، بدون پیشنهاد خروجی، بدون بازگشت — در حالی که ممکن است ماه‌ها دادهٔ خواب یا چرخه را ببرد.

**فایل‌ها:** `lib/features/settings/presentation/groups/modules_group_screen.dart`، `lib/core/modules/module_deactivation_service.dart`

**کار دقیق:**
1. در دیالوگ غیرفعال‌سازی، دو گزینه را به طور بصری جدا کن:
   - **«خاموش کن و داده را نگه دار»** — دکمهٔ اصلی و پیش‌فرض
   - **«خاموش کن و داده را پاک کن»** — دکمهٔ قرمز کم‌رنگ
2. برای گزینهٔ دوم، یک مرحلهٔ تأیید دوم بگذار که **تعداد واقعی رکوردهایی که پاک می‌شوند را نشان دهد**: «۱۴۲ رکورد خواب پاک می‌شود. این کار قابل بازگشت نیست.» اگر سرویس دغدغه را نمی‌دهد، یک متد `Future<int> countModuleRecords(String moduleKey)` در `ModuleDeactivationService` اضافه کن.
3. قبل از پاک‌سازی، یک پشتیبان خودکار با همان مکانیزم `LegacyDatabaseRecovery.createEmergencyBackup` بگیر و در پیام موفقیت به این اشاره کن.
4. کلیدهای تنطیمات مختص آن ماژول را هم پاک کن (مثلاً با خاموش کردن ماژول چرخه، `show_cycle_in_calendar` و `cycle_consent` باید `false` شوند) — این را با `setMany` انجام بده.

**معیار پذیرش:** پاک‌سازی دادهٔ ماژول دست‌کم دو تأیید می‌خواهد و تعداد رکوردها را نشان می‌دهد؛ خاموش کردن ساده داده را دست نمی‌زند.

**تست:** تست ویجت دومرحله‌ای بودن تأیید.

**commit:** `feat(settings): SET-36 — تقارن حفاطت در عملیات مخرب`

---

### SET-37 — گروه‌بندی و عنوان گروه: یک منبع، سه مصرف‌کننده

**باگ ۱ (جابه‌جایی گروه):** چند تنطیم در گروه اشتباهی هستند:
- `tasks_confirm_delete` در گروه `appearance` — یک تنطیم رفتاری است، نه طاهری.
- `tasks_completion_sound_enabled` در گروه `notifications` — صدای درون‌برنامه‌ای است، نه اعلان.
- تنطیمات چرخه در چهار گروه مختلف پراکنده‌اند: `modules`، `calendar`، `security`، `assistant`.

**باگ ۲ (عنوان در سه جا تکرار شده و قبلاً واگرا شده):**

| گروه | `SettingsScreen._GroupItem.title` | `SettingsSearchDelegate._getGroupName` | `RitmoModuleAppBar` در صفحه |
|---|---|---|---|
| assistant | دستیار و روان‌شناسی | دستیار | — |
| calendar | تقویم و برنامه‌ریزی | تقویم | تنطیمات تقویم و برنامه‌ریزی |
| modules | ماژول‌ها و بخش‌های برنامه | ماژول‌ها | — |

**فایل‌ها:** `lib/core/settings/settings_registry.dart`، `lib/features/settings/presentation/settings_screen.dart`، `lib/features/settings/presentation/settings_search_delegate.dart`، همهٔ فایل‌های `groups/`

**کار دقیق:**
1. کنار `enum SettingsGroup` یک اکستنشن بساز که **تنها مرجع** اطلاعات نمایشی گروه باشد:
   ```dart
   extension SettingsGroupMeta on SettingsGroup {
     String get titleFa;        // عنوان کوتاه و یکسان در همه جا
     String get subtitleFa;     // توضیح یک‌خطی
     IconData get icon;
     List<Color> get gradient;
   }
   ```
2. `_GroupItem.title`، `_GroupItem.subtitle`، `_GroupItem.icon`، `_GroupItem.gradient` و `_getGroupName` را حذف کن و هر سه مصرف‌کننده (صفحهٔ اصلی، جست‌وجو، نوار بالای صفحهٔ گروه) را به این اکستنشن وصل کن. عنوان نوار بالا را `'تنطیمات ' + group.titleFa` بساز.
3. `tasks_confirm_delete` را به گروه مناسب منتقل کن (گروه رفتاری، مانند `assistant` یا یک مقدار جدید در enum اگر منطقی‌تر بود) و `tasks_completion_sound_enabled` را هم همراهش ببر. **تغییر گروه، کلید را عوض نمی‌کند، پس مقادیر کاربر حفظ می‌شوند؛ مهاجرت لازم نیست.**
4. تنطیمات چرخه را **جابه‌جا نکن** (رمز چرخه واقعاً در امنیت جای درستی دارد). به جایش در SET-58 یک کارت خلاصهٔ حریم خصوصی می‌سازیم که هر چهار را یکجا نشان می‌دهد.

**معیار پذیرش:** عنوان هر گروه در صفحهٔ اصلی، در نتایج جست‌وجو و در نوار بالای صفحه یکسان است؛ جست‌وجوی `'تنطیمات تقویم'` در کد فقط یک محل دارد.

**تست:** در `test/settings/registry_integrity_test.dart` یک تست که برای هر مقدار `SettingsGroup`، `titleFa` غیرخالی و منحصربه‌فرد باشد.

**commit:** `refactor(settings): SET-37 — متادادهٔ گروه در یک محل`

---

## فاز E — رندر اعلامی از رجیستری (SET-38 … SET-45)

> این فاز قلب معماری جدید است. پیش از شروع، مطمئن شو فازهای A تا D کامل و commit شده‌اند، چون همهٔ تسک‌های این فاز به `SettingWriteResult`، `watch`، `visibility` و `dependsOn` وابسته‌اند.

### SET-38 — ساخت `SettingsFieldBuilder`: یک ویدجت به ازای هر نوع تنطیم [بحرانی — زیرساخت بقیهٔ فاز]

**مشکل:** رجیستری همهٔ اطلاعات لازم برای رندر را دارد (نوع، برچسب، توضیح، کران، گزینه‌ها)، اما هر صفحهٔ گروه دوباره و دستی ویجت می‌سازد. نتیجه: ۷۲ توصیفگر ثبت شده ولی ده‌ها تای آن‌ها رندر نمی‌شوند (SET-31، SET-39)، و هر تنطیم جدید نیاز به کد دستی دارد.

**فایل جدید:** `lib/features/settings/presentation/widgets/setting_field_builder.dart`

**کار دقیق:**
1. یک ویجت بساز که **فقط یک کلید می‌گیرد** و بقیه را از رجیستری می‌خواند:
   ```dart
   class SettingField extends StatelessWidget {
     const SettingField(this.settingKey, {super.key, this.highlighted = false});
     final String settingKey;
     final bool highlighted;
   }
   ```
2. داخلش روی `desc.type` یک `switch` **جامع بدون `default`** بزن:
   - `boolean` → ردیف با `CupertinoSwitch`
   - `enumeration` → اگر تعداد `allowed` تا ۴ بود، `RitmoSegmentedControl`؛ وگرنه یک شیت انتخاب
   - `integer` → اسلایدر وقتی هم `min` و هم `max` دارد؛ وگرنه فیلد عددی با اعتبارسنجی
   - `time` → ردیف با انتخابگر زمان و نمایش مقدار با ارقام فارسی
   - `text` → ردیف با دیالوگ ویرایش، با احترام به `maxLength` و `SettingTextFormat` (SET-16)
3. مقدار را با `SettingsService.instance.watch<T>(key)` (SET-22) بخوان تا بدون `setState` دستی تازه بماند.
4. نوشتن را فقط با `setChecked` انجام بده و نتیجه را مصرف کن (منطق کاملش در SET-40).
5. برای مواردی که حتماً رابط کاربری اختصاصی می‌خواهند (پالت تم، PIN، انتخاب آواتار)، راه فرار بگذار: یک نگاشت `Map<String, WidgetBuilder> customFields` در همین فایل که برای این کلیدها ویجت دلخواه می‌دهد. **این فهرست را کوتاه نگه دار — حداکثر پنج کلید.**
6. ویجت موجود `SettingsTile` را دور نریز؛ `SettingField` باید از همین `SettingsTile` برای طراحی بصری استفاده کند (یکدستی طاهر حفظ شود).
7. `SettingsSection` را طوری توسعه بده که بتواند یک فهرست کلید بگیرد: `SettingsSection.fromKeys(title, keys)`.

**معیار پذیرش:** یک صفحهٔ گروه می‌تواند فقط با دادن فهرستی از کلیدها رندر شود؛ افزودن یک توصیفگر جدید به رجیستری به تنهایی کافی است تا در رابط کاربری پیدا شود.

**تست:** `test/settings/setting_field_builder_test.dart` — برای هر پنج مقدار `SettingType` یک تست ویجت.

**commit:** `feat(settings): SET-38 — رندر اعلامی تنطیمات از رجیستری`

---

### SET-39 — دوازده تنطیم تقویمی که هیچ راهی به آن‌ها نیست [بحرانی]

**باگ:** رجیستری ۱۷ توصیفگر در گروه `calendar` دارد، اما `CalendarGroupScreen` فقط ۵ تای را رندر می‌کند. ۱۲ تنطیم زیر **از رابط کاربری غیرقابل دسترسی‌اند** و فقط پیش‌فرض خود را دارند، در حالی که موتور تقویم به آن‌ها تکیه می‌کند:

`calendar_show_events`، `calendar_show_commitments`، `calendar_show_appointments`، `calendar_show_sleep_band`، `show_cycle_in_calendar`، `calendar_overdue_lookback_days`، `calendar_show_worship_obligatory`، `calendar_show_worship_mustahab`، `calendar_show_worship_qada`، `calendar_compress_recurring`، و دو کلید باقیمانده که با مقایسهٔ فهرست رجیستری و فهرست رندرشده پیدا می‌کنی.

**فایل‌ها:** `lib/features/settings/presentation/groups/calendar_group_screen.dart`

**کار دقیق:**
1. صفحه را با `SettingField` (SET-38) بازنویسی کن و در چند بخش معنادار گروه کن:
   - **نمای پیش‌فرض و تقویم:** `calendar_default_scale`، `calendar_show_hijri`، `calendar_show_occasions`
   - **چه چیزی در تقویم دیده شود:** `calendar_show_tasks`، `calendar_show_events`، `calendar_show_commitments`، `calendar_show_appointments`، `calendar_show_sleep_band`، `show_cycle_in_calendar`
   - **عبادت:** سه کلید `calendar_show_worship_*`
   - **رفتار اجندا:** `calendar_overdue_lookback_days`، `calendar_compress_recurring`، `calendar_morning_brief_enabled`
2. **گیت ماژول:** ردیف‌های وابسته به ماژول خاموش را مخفی نکن؛ غیرفعال کن و زیرش بنویس «نیاز به روشن بودن ماژول خواب» با یک دکمهٔ میان‌بر به صفحهٔ ماژول‌ها (منطق عمومیش در SET-44). مخفی کردن کامل، همین مشکل فعلی را دوباره می‌سازد.
3. `show_cycle_in_calendar` باید علاوه بر ماژول، به `cycle_consent` و قاعدهٔ M-12 (`CyclePrivacyGuard`) هم مقید باشد.
4. پس از تکمیل، با یک تست ثابت کن هر ۱۷ توصیفگر گروه تقویم در درخت ویجت حاضرند.

**معیار پذیرش:** تعداد ردیف‌های صفحهٔ تقویم با `SettingsRegistry.userVisibleByGroup(SettingsGroup.calendar).length` برابر است (همان عددی که بج صفحهٔ اصلی ادعا می‌کند).

**تست:** `test/settings/group_coverage_test.dart` — این تست را عمومی بنویس: برای **هر هشت گروه**، تعداد ردیف‌های رندرشده باید با تعداد توصیفگرهای قابل مشاهده برابر باشد. این تست مانع تکرار این دسته باگ در آینده می‌شود.

**commit:** `fix(settings): SET-39 — دسترسی به تنطیمات یتیم تقویم`

---

### SET-40 — هیچ صفحه‌ای نتیجهٔ نوشتن را بررسی نمی‌کند [بحرانی]

**باگ:** در هر سه صفحه‌ای که بررسی شد (`CalendarGroupScreen._update`، `AppearanceGroupScreen._changeLocale`، `SecurityGroupScreen._update`) مقدار بازگشتی `set()` **دور ریخته می‌شود** و بلافاصله `setState` صدا می‌شود. پس اگر نوشتن رد یا شکست بخورد، سویچ روشن می‌ماند و کاربر فکر می‌کند تنطیم ذخیره شده — تا راه‌اندازی بعدی که برمی‌گردد. **این بدترین نوع باگ در یک صفحهٔ تنطیمات است: از دست رفتن بی‌صدای خواستهٔ کاربر.**

**فایل‌ها:** همهٔ فایل‌های `lib/features/settings/presentation/groups/`، و `setting_field_builder.dart`

**کار دقیق:**
1. یک کمکی مرکزی بساز (در `setting_field_builder.dart` یا یک فایل کوتاه کنارش) که **الگوی خوش‌بینانه با بازگشت** را پیاده کند:
   - مقدار را فوری در رابط کاربری عوض کن (حس پاسخگویی)
   - `setChecked` را صدا بزن
   - اگر `SettingWriteOk` بود، `RitmoHapticsPolicy.success()`
   - اگر `SettingWriteRejected` یا `SettingWriteFailed` بود: **مقدار را برگردان** و `RitmoToast.show` با `reasonFa` نشان بده
2. در همهٔ نوشتن‌های موجود فیچر تنطیمات از همین کمکی استفاده کن. موارد را با این دستور پیدا کن:
   ```bash
   rg -n "SettingsService.instance.set" lib/features/settings
   ```
3. متن خطا باید فارسی و مشخص باشد، مانند «ذخیره نشد: مقدار باید بین ۱ تا ۶۰ باشد.» — **هرگز `$e` خام را نشان نده.**
4. برای مواردی مانند `_setPin` که نوشتن چندمرحله‌ای است، در صورت شکست مرحلهٔ دوم، مرحلهٔ اول را هم برگردان (یا از `setMany` استفاده کن).

**معیار پذیرش:** با تزریق یک خطای مصنوعی در لایهٔ داده، هر سوییچ در تنطیمات به حالت قبل برمی‌گردد و یک پیام فارسی دیده می‌شود.

**تست:** `test/settings/optimistic_revert_test.dart`.

**commit:** `fix(settings): SET-40 — بازگشت واقعی رابط کاربری در شکست نوشتن`

---

### SET-41 — حذف جست‌وجوی خطی از مسیر رندر

**باگ:** صفحه‌های گروه درون `build()` برای هر ردیف `SettingsRegistry.find(key)` را صدا می‌زنند. SET-01 جست‌وجو را نگاشتی کرد، ولی هنوز در مسیر رندر فراخوانی تکراری و احتمال `null!` وجود دارد.

**فایل‌ها:** همهٔ فایل‌های `groups/`، `setting_field_builder.dart`

**کار دقیق:**
1. در `SettingField`، توصیفگر را یک بار در سازنده/`didChangeDependencies` بگیر، نه در هر `build`.
2. اگر توصیفگر پیدا نشد: در حالت دیباگ `assert` بشکند، در حالت رلیز یک `SizedBox.shrink()` بده و یک بار `RitmoLog.error` بزن. **هرگز `!` کور ننویس.**
3. در صفحه‌هایی که فهرست ردیف‌ها ثابت است، فهرست کلیدها را `static const List<String>` کن تا در هر رندر دوباره ساخته نشود.

**معیار پذیرش:** `rg -n "SettingsRegistry.find" lib/features/settings` فقط در مسیرهای غیر-`build` نتیجه می‌دهد؛ هیچ `find(...)!` در کد نیست.

**تست:** در همان `setting_field_builder_test.dart` یک مورد با کلید ناموجود اضافه کن (نباید کرش کند).

**commit:** `perf(settings): SET-41 — حل توصیفگر خارج از مسیر رندر`

---

### SET-42 — بنر حالت تخریب‌شده در صفحهٔ تنطیمات

**مشکل:** در SET-17 حالت `SettingsLoadState.degraded` ساخته شد، ولی هیچ رابط کاربری‌ای آن را نشان نمی‌دهد. اگر بارگذاری تنطیمات شکست بخورد، کاربر همهٔ مقادیر پیش‌فرض را می‌بیند و خیال می‌کند تنطیماتش پاک شده‌اند و شروع می‌کند به بازتنطیم — که دقیقاً بدترین واکنش است.

**فایل جدید:** `lib/features/settings/presentation/widgets/settings_degraded_banner.dart`

**کار دقیق:**
1. یک کالاوت قرمز/نارنجی بالای صفحهٔ اصلی تنطیمات و بالای هر صفحهٔ گروه بساز که فقط در حالت `degraded` دیده می‌شود:
   «تنطیمات شما خوانده نشد. مقادیر زیر پیش‌فرضند و تغییرشان فعلاً ذخیره نمی‌شود.» + دکمهٔ «تلاش مجدد» که `retryInit()` را صدا می‌زند.
2. در حالت تخریب‌شده، همهٔ `SettingField`‌ها باید غیرفعال باشند (نه مخفی)، تا کاربر تلاش بی‌ثمر نکند.
3. **در این حالت منطقهٔ خطر باید کاملاً مخفی شود** — بازنشانی کارخانه وقتی وضعیت داده نامعلوم است، ریسک غیرقابل قبول است.
4. در حالت `notLoaded` یک اسکلت بارگذاری نشان بده، نه مقادیر پیش‌فرض.

**معیار پذیرش:** با شکست مصنوعی `init()`، بنر دیده می‌شود، همهٔ ردیف‌ها غیرفعالند و منطقهٔ خطر دیده نمی‌شود.

**تست:** `test/settings/degraded_banner_test.dart`.

**commit:** `feat(settings): SET-42 — بنر حالت تخریب‌شده`

---

### SET-43 — رندر قبل از آماده شدن سرویس

**باگ:** هیچ کدام از صفحه‌های تنطیمات `SettingsService.instance.isInitialized` را بررسی نمی‌کنند. اگر کاربر با یک لینک عمیق یا مسیری غیرمعمول به یک صفحهٔ گروه برسد، مقادیر پیش‌فرض را می‌بیند، تغییرشان می‌دهد، و با این تغییر **مقدار واقعی ذخیره‌شدهٔ خودش را پاک می‌کند.**

**فایل‌ها:** `lib/features/settings/presentation/settings_screen.dart`، همهٔ فایل‌های `groups/`

**کار دقیق:**
1. یک ویجت پوششی کوتاه بساز: `SettingsReadyGate({required Widget child})` که:
   - اگر سرویس آماده نیست، `init()` را صدا می‌زند و اسکلت نشان می‌دهد
   - وقتی آماده شد، `child` را رندر می‌کند
   - اگر تخریب‌شده بود، بنر SET-42 را بالای `child` می‌گذارد
2. همهٔ نه صفحهٔ گروه و خود `SettingsScreen` را در این گیت بپیچ.
3. در `SettingsService`، `init()` را واقعاً idempotent و امن در فراخوانی موازی کن: یک `Future<void>? _initFuture` نگه دار و فراخوانی‌های همزمان را به همان فیوچر وصل کن (الان دو فراخوانی همزمان می‌توانند دو بار کل جدول را بخوانند).

**معیار پذیرش:** باز کردن مستقیم یک صفحهٔ گروه در تست، هرگز مقادیر پیش‌فرض را قابل تغییر نشان نمی‌دهد.

**تست:** `test/settings/ready_gate_test.dart` به علاوه یک تست فراخوانی موازی `init()`.

**commit:** `fix(settings): SET-43 — گیت آمادگی سرویس تنطیمات`

---

### SET-44 — گیت‌بندی وابستگی‌ها در رابط کاربری

**باگ:** فیلد `dependsOn` در SET-02/SET-09 ساخته شد ولی هیچ جایی مصرف نمی‌شود. در نتیجه ده‌ها تنطیم بی‌اثر فعال به نطر می‌رسند: مانند `notif_quiet_start` و `notif_quiet_end` وقتی `notif_quiet_enabled` خاموش است، یا همهٔ کلیدهای `ai_*` وقتی `ai_mode` روی سرور ریتموست، یا همهٔ کلیدهای اعلان وقتی `notif_master_enabled` خاموش است.

**فایل‌ها:** `setting_field_builder.dart`، `lib/core/settings/settings_registry.dart`

**کار دقیق:**
1. در `SettingField`، وابستگی را ارزیابی کن. سه حالت خروجی:
   - **فعال:** وابستگی برقرار است
   - **غیرفعال با توضیح:** وابستگی برقرار نیست — ردیف با شفافیت ۵۰ درصد، متن راهنما «نیاز به روشن بودن «{برچسب تنطیم والد}»» و یک دکمهٔ میان‌بر که به همان تنطیم والد پرش می‌کند (از مکانیزم هایلایت SET-46 استفاده کن)
   - **مخفی:** فقط برای موارد حریم خصوصی که قاعدهٔ M-12 می‌گوید نباید دیده شود
2. **قاعدهٔ مهم:** پیش‌فرض باید «غیرفعال با توضیح» باشد، نه «مخفی». مخفی کردن تنطیمات، کاربر را سرگردان می‌کند و همان مشکل SET-39 را دوباره می‌سازد.
3. وابستگی‌های لازم را در رجیستری تکمیل کن (دست‌کم این خانواده‌ها): همهٔ `notif_*` به `notif_master_enabled`؛ `notif_quiet_start`/`notif_quiet_end` به `notif_quiet_enabled`؛ `ai_base_url`/`ai_api_key`/`ai_model`/`ai_provider_preset` به مقدار `personal_key` در `ai_mode`؛ `ai_memory_implicit_enabled` به `ai_memory_enabled`؛ `backup_frequency_days` به `auto_backup_enabled`؛ `app_lock_password`/`app_use_device_lock`/`app_biometric_enabled`/`app_lock_timeout_seconds` به `app_lock_enabled`؛ `snooze_max_defer_count` به `snooze_minutes`؛ `daily_planning_nudge_time` به `daily_planning_nudge_enabled`.
4. وابستگی ماژولی: هر تنطیم مختص یک ماژول باید به کلید `module_*` مربوطه وابسته شود.

**معیار پذیرش:** خاموش کردن `notif_master_enabled` بلافاصله همهٔ ردیف‌های اعلان را به حالت غیرفعال با توضیح می‌برد، بدون ریلود صفحه.

**تست:** `test/settings/depends_on_gating_test.dart`.

**commit:** `feat(settings): SET-44 — گیت‌بندی وابستگی تنطیمات`

---

### SET-45 — رفع پیمایش تودرتوی معیوب

**باگ:** در `SettingsScreen` یک `ListView.separated(shrinkWrap: true, physics: NeverScrollableScrollPhysics())` داخل `SingleChildScrollView` قرار دارد. این الگو تمام ردیف‌ها را یکجا می‌سازد (بدون هیچ تنبلی)، دو بار لیوات می‌دهد و در فهرست‌های بلند فریم‌دراپ می‌سازد.

**فایل‌ها:** `lib/features/settings/presentation/settings_screen.dart`، هر فایل دیگری که این الگو را دارد

**کار دقیق:**
1. موارد را پیدا کن:
   ```bash
   rg -n "shrinkWrap: true" lib/features/settings
   ```
2. ساختار را به یک `CustomScrollView` با چند `SliverList` / `SliverToBoxAdapter` تبدیل کن تا فقط **یک** پیمایشگر باقی بماند و ردیف‌ها تنبل باشند.
3. همین را برای صفحه‌های بلند گروه انجام بده (به‌ویژه `identity_group_screen.dart` و `notifications_group_screen.dart` که بزرگ‌ترینند).
4. کلید `PageStorageKey` برای حفظ موقعیت پیمایش بگذار؛ بازگشت از صفحهٔ گروه باید همان موقعیت قبلی را نشان دهد.
5. در همین تسک یک `RepaintBoundary` دور کارت‌های گرادیانتی گروه بگذار (هشت گرادیانت در یک فهرست پیمایشی، هزینهٔ رنگ‌آمیزی دارد).

**معیار پذیرش:** دستور `rg` بالا در فیچر تنطیمات خروجی خالی می‌دهد (یا فقط موارد توجیه‌شده با کامنت دارد)؛ پیمایش صفحهٔ تنطیمات بدون پرش فریم است.

**تست:** تست ویجت که ثابت کند فقط یک `Scrollable` در درخت وجود دارد.

**commit:** `perf(settings): SET-45 — پیمایش تنبل و حذف لیست تودرتو`

---

## فاز F — جست‌وجوی تنطیمات (SET-46 … SET-50)

### SET-46 — جست‌وجو باید به خود تنطیم برساند، نه به یک چورون

**باگ:** وقتی کاربر در جست‌وجو یک تنطیم را انتخاب می‌کند، فقط صفحهٔ گروه باز می‌شود — بدون پیمایش به محل تنطیم و بدون هیچ نشانه‌ای. در یک صفحهٔ بلند مانند اعلان‌ها یا هویت، کاربر باز هم باید دستی دنبال ردیف بگردد. بدتر اینکه `SettingsTile` پارامتر `highlighted` و یک `AnimatedContainer` ۴۰۰ میلی‌ثانیه دارد که **هیچ جا به آن مقدار `true` داده نمی‌شود** — یعنی قابلیت ساخته شده و وصل نشده است.

**فایل‌ها:** `lib/features/settings/presentation/settings_search_delegate.dart`، `lib/features/settings/presentation/widgets/settings_tile.dart`، همهٔ فایل‌های `groups/`

**کار دقیق:**
1. همهٔ صفحه‌های گروه یک پارامتر اختیاری بگیرند: `final String? focusKey;`
2. در `SettingField` یک `GlobalKey` برای ردیفی که `settingKey == focusKey` بساز و در اولین فریم پس از رندر اجرا کن:
   ```dart
   WidgetsBinding.instance.addPostFrameCallback((_) {
     final ctx = _rowKey.currentContext;
     if (ctx == null) return;
     Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 320), alignment: 0.25);
   });
   ```
3. همزمان `highlighted: true` را به همان `SettingsTile` بده تا انیمیشن موجود بالاخره استفاده شود، و پس از حدود دو ثانیه هایلایت را محو کن (با یک `Timer` که در `dispose` لغو می‌شود — تایمر بدون لغو همان باگ H12 است، تکرارش نکن).
4. در `SettingsSearchDelegate`، هنگام انتخاب نتیجه، `focusKey: desc.key` را به صفحهٔ گروه پاس بده.
5. همین مکانیزم را برای دکمهٔ میان‌بر وابستگی در SET-44 استفاده کن (دو پیاده‌سازی موازی ننویس).

**معیار پذیرش:** جست‌وجوی «ساعات سکوت» و انتخاب نتیجه، مستقیماً به همان ردیف در صفحهٔ اعلان‌ها می‌پیماید و ردیف لحطه‌ای هایلایت می‌شود.

**تست:** `test/settings/search_focus_key_test.dart`.

**commit:** `feat(settings): SET-46 — پیمایش و هایلایت نتیجهٔ جست‌وجو`

---

### SET-47 — استفاده از context پس از بستن جست‌وجو

**باگ:** در `SettingsSearchDelegate` اول `close(context, desc)` صدا می‌شود و بعد روی **همان context پاپ‌شده** `Navigator.push(...)` انجام می‌شود. این الگو روی برخی مسیرها جواب می‌دهد و روی برخی بی‌سروصدا کار نمی‌کند — کاربر روی نتیجه می‌زند و هیچ اتفاقی نمی‌افتد.

**فایل‌ها:** `lib/features/settings/presentation/settings_search_delegate.dart`، `lib/features/settings/presentation/settings_screen.dart`

**کار دقیق:**
1. الگوی درست: فقط `close(context, desc)` را صدا بزن و هیچ کار دیگری نکن. ناوبری را در **فراخواننده** انجام بده:
   ```dart
   final desc = await showSearch<SettingDescriptor?>(context: context, delegate: ...);
   if (desc == null || !context.mounted) return;
   // این‌جا با context زندهٔ صفحهٔ تنطیمات پرش کن
   ```
2. یک تابع مرکزی بساز: `Future<void> openSettingsGroup(BuildContext context, SettingsGroup group, {String? focusKey})` که **تنها راه باز کردن صفحه‌های گروه** باشد (هم از صفحهٔ اصلی، هم از جست‌وجو، هم از دکمهٔ میان‌بر وابستگی SET-44).
3. یکدست‌سازی مسیر: در فیچر تنطیمات هم `Ios26PageRoute` و هم `CupertinoPageRoute` استفاده می‌شود و انیمیشن ورود دو جور است. در این تابع مرکزی فقط `Ios26PageRoute` بماند و بقیه را پاک کن.

**معیار پذیرش:** `rg -n "CupertinoPageRoute" lib/features/settings` خروجی خالی می‌دهد؛ انتخاب هر نتیجهٔ جست‌وجو در همهٔ موارد صفحهٔ درست را باز می‌کند.

**تست:** تست ویجت که برای هر هشت گروه، انتخاب نتیجه به صفحهٔ متناطر می‌رسد.

**commit:** `fix(settings): SET-47 — ناوبری امن پس از جست‌وجو و یکدست‌سازی مسیر`

---

### SET-48 — کلیدهای داخلی نباید در نتایج جست‌وجو بیایند

**باگ:** جست‌وجو روی خود رشتهٔ `key` هم تطبیق می‌دهد؛ پس تایپ کردن `notif` یا `module` کلیدهای خام داخلی را نشان می‌دهد. در کنارش، فیلتر قابلیت دیده شدن با قاعدهٔ شکنندهٔ `descriptionFa != null` و چک دستی `_asked` کار می‌کند که در SET-08 با `SettingVisibility` جایگزین شد — جست‌وجو هنوز با قاعدهٔ قدیم کار می‌کند.

**فایل‌ها:** `lib/features/settings/presentation/settings_search_delegate.dart`

**کار دقیق:**
1. منبع نتایج را فقط از توصیفگرهایی بگیر که `visibility` آن‌ها کاربرپسند است (SET-08). کلیدهای داخلی و حالت `_asked` و `settings_schema_version` هرگز نباید دیده شوند.
2. تطبیق را فقط روی `labelFa`، `descriptionFa`، `searchTerms` و عنوان گروه انجام بده. روی `key` تطبیق نده.
3. **استثنای توسعه‌دهنده:** در `kDebugMode` اجازه بده تطبیق روی `key` هم کار کند، ولی کلید را با یک برچسب خاکستری کوچک زیر عنوان نشان بده تا واضح باشد داخلی است.
4. در همین تسک، نتایج را رتبه‌بندی کن: تطبیق دقیق برچسب بالاتر از تطبیق ابتدای برچسب، بالاتر از تطبیق درون توضیح، بالاتر از `searchTerms`.

**معیار پذیرش:** در نسخهٔ رلیز، جست‌وجوی `onboarding` یا `_asked` هیچ نتیجه‌ای نمی‌دهد.

**تست:** `test/settings/search_visibility_test.dart`.

**commit:** `fix(settings): SET-48 — پنهان کردن کلیدهای داخلی از جست‌وجو`

---

### SET-49 — نرمال‌سازی فارسی و مترادف‌های انگلیسی در جست‌وجو

**باگ:** تطبیق متن خام و بدون نرمال‌سازی انجام می‌شود. پس:
- «ماژول‌ها» با نیم‌فاصله با «ماژول ها» با فاصله تطبیق نمی‌دهد.
- کاف و یای عربی (کی‌بوردهای پیش‌فرض برخی گوشی‌ها) تطبیق نمی‌دهند.
- ارقام فارسی در مقابل انگلیسی تطبیق نمی‌دهند.
- کاربران فنی کلمات انگلیسی رایج مانند `dark mode`، `pin`، `backup`، `theme`، `api key` را تایپ می‌کنند و هیچ نتیجه‌ای نمی‌گیرند.

**فایل‌ها:** `lib/features/settings/presentation/settings_search_delegate.dart`، `lib/core/utils/persian_text_normalizer.dart` (ساخته‌شده در SET-29)، `lib/core/settings/settings_registry.dart`

**کار دقیق:**
1. هم متن جست‌وجو و هم متن قابل جست‌وجو را از `normalizeFa` رد کن (همان تابع SET-29، دوباره ننویس).
2. متن نرمال‌شدهٔ هر توصیفگر را **یک بار** در یک نگاشت تنبل محاسبه و کش کن (هر کلید فشار دادن، ۷۲ رشته را دوباره نرمال نکند).
3. مترادف‌های انگلیسی را در همان فیلد موجود `searchTerms` توصیفگرها پر کن (فیلد جدید نساز). دست‌کم برای این موارد: تم و حالت تیره، زبان، اعلان، ساعات سکوت، قفل و رمز، بیومتریک، پشتیبان، کلید API، مدل هوش مصنوعی، حافطه، تقویم، خواب، چرخه، ماژول.
4. رایج‌ترین غلط‌های تایپی فارسی را هم پوشش بده (مانند «تنطیم» در مقابل «تنزیم») — فقط به عنوان مترادف در `searchTerms`، نه با تطبیق فازی پیچیده.

**معیار پذیرش:** هر چهار ورودی «ماژول‌ها»، «ماژول ها»، `module` و «ماژولہا» (با کاف/یای غیرفارسی) به نتایج یکسان می‌رسند.

**تست:** `test/settings/search_normalization_test.dart`.

**commit:** `feat(settings): SET-49 — جست‌وجوی مقاوم فارسی و مترادف انگلیسی`

---

### SET-50 — حالت خالی جست‌وجو و نمایش مقدار فعلی

**باگ ۱:** با پرسوجوی خالی، جست‌وجو **هر ۷۲ تنطیم را یکجا فهرست می‌کند** — یک دیوار متنی که هیچ کمکی نمی‌کند.

**باگ ۲:** نتایج جست‌وجو فقط برچسب و نام گروه را نشان می‌دهند، **نه مقدار فعلی را**. کاربر باید در برود تا بفهمد وضعیت چیست؛ در حالی که بیشتر جست‌وجوها فقط برای دیدن مقدار انجام می‌شوند.

**فایل‌ها:** `lib/features/settings/presentation/settings_search_delegate.dart`، `lib/core/settings/settings_service.dart`

**کار دقیق:**
1. در هر ردیف نتیجه، مقدار فعلی را سمت مخالف عنوان به صورت خوانا نشان بده: بولی → «روشن»/«خاموش»، زمان → ارقام فارسی، enum → برچسب فارسی گزینه (نه مقدار خام)، عددی → عدد با واحد، متنی → خلاصهٔ کوتاه. **برای کلیدهای `secure` حتماً فقط «تنطیم شده» / «تنطیم نشده» بنویس و هرگز خود مقدار را نشان نده** (از `hasSecureValue` استفاده کن، نه `readSecure`).
2. برای پرسوجوی خالی، سه بخش نشان بده:
   - **«اخیراً تغییر دادید»** — پنج کلید با بالاترین `updatedAt` در جدول `app_settings`. برای این، یک متد `Future<List<String>> recentlyChangedKeys({int limit = 5})` در `SettingsService` بساز (داخل سرویس، نه SQL خارجی — قانون SET-33).
   - **«پرکاربرد»** — یک فهرست ثابت و دست‌چین از شش کلید: `theme_mode`، `notif_master_enabled`، `notif_quiet_enabled`، `app_lock_enabled`، `calendar_default_scale`، `wake_time`.
   - **«مرور گروه‌ها»** — هشت چیپ گروه با `titleFa` از SET-37.
3. حالت بدون نتیجه را مفید کن: علاوه بر متن موجود، دو پیشنهاد نزدیک نشان بده (تطبیق جزئی روی متن نرمال‌شده) و یک دکمهٔ «مرور همهٔ تنطیمات».

**معیار پذیرش:** باز کردن جست‌وجو با پرسوجوی خالی دیگر همهٔ تنطیمات را فهرست نمی‌کند؛ مقدار فعلی در نتایج دیده می‌شود؛ هیچ مقدار رازی دیده نمی‌شود.

**تست:** `test/settings/search_empty_state_test.dart` به علاوهٔ یک تست صریح که مقدار کلیدهای `secure` در هیچ ویجتی رندر نمی‌شود.

**commit:** `feat(settings): SET-50 — حالت خالی مفید و نمایش مقدار در نتایج`

---

## فاز G — بهبود رابط و تجربهٔ کاربری (SET-51 … SET-60)

> این فاز پیشنهادهای بهبود است، نه رفع باگ. **ولی اختیاری نیست** — همه را همان‌طور که نوشته شده پیاده کن. هر تسک این فاز به `SettingField` (SET-38) تکیه دارد؛ پس فاز E باید کامل شده باشد.

### SET-51 — نشان «تغییریافته از پیش‌فرض» و بازنشانی هدفمند

**مشکل:** در حال حاضر هیچ راهی نیست بفهمی کدام تنطیمات را خودت عوض کرده‌ای و کدام پیش‌فرضند. وقتی یک رفتار عجیب در اپ دیده می‌شود، کاربر باید ۷۲ تنطیم را دستی مرور کند. هیچ مسیر بازنشانی‌ای هم وجود ندارد جز «بازنشانی کارخانه» که همهٔ دادهٔ کاربر را می‌برد — یعنی فاصلهٔ بین «یک تنطیم را برگردان» و «همه چیز را پاک کن» خالی است.

**فایل‌ها:** `lib/core/settings/settings_service.dart`، `setting_field_builder.dart`، `settings_section.dart`

**کار دقیق:**
1. در سرویس یک متد ساده بساز: `bool isDefault(String key)` که مقدار فعلی را با `defaultValue` توصیفگر مقایسه می‌کند (با همان کدک SET-13 تا مقایسهٔ رشته/عدد درست باشد).
2. در `SettingField`، وقتی مقدار پیش‌فرض نیست، یک نقطهٔ کوچک رنگی (۶ پیکسل) کنار برچسب نشان بده با `Semantics(label: 'تغییریافته از پیش‌فرض')`. برچسب متنی بزرگ نگذار — فقط یک نشانهٔ محجوب.
3. در فشار طولانی روی هر ردیف، یک منوی کوتاه باز کن: «بازگرداندن به پیش‌فرض» (فقط وقتی مقدار پیش‌فرض نیست) و «چرا این تنطیم؟» (SET-59). بازنشانی از `reset(key)` در SET-22 استفاده کند.
4. در سربرگ هر `SettingsSection`، اگر دست‌کم یک ردیف غیرپیش‌فرض دارد، یک دکمهٔ متنی کوچک «بازنشانی این بخش» بگذار که `resetGroup` را با تأیید و فهرست تغییرات صدا می‌زند («۴ تنطیم به حالت پیش‌فرض برمی‌گردد.»).
5. کلیدهای `secure` و داخلی هرگز در بازنشانی گروهی نیایند (قانون SET-22 را رعایت کن).

**معیار پذیرش:** عوض کردن یک تنطیم فوراً نشانه را طاهر می‌کند؛ بازنشانی مقدار را برمی‌گرداند و نشانه محو می‌شود.

**تست:** `test/settings/is_default_and_reset_test.dart`.

**commit:** `feat(settings): SET-51 — نشان تغییر از پیش‌فرض و بازنشانی هدفمند`

---

### SET-52 — حالت ساده و پیشرفته: `app_mode` را واقعاً مصرف کن

**مشکل:** کلید `app_mode` با دو مقدار `full` و `simple` ثبت شده ولی در فیچر تنطیمات هیچ اثری ندارد. کاربر تازه همان ۷۲ تنطیم را می‌بیند که کاربر حرفه‌ای — در حالی که حدود دو‌سوم آن‌ها برای ۹۰ درصد کاربران هرگز لازم نمی‌شوند.

**فایل‌ها:** `lib/core/settings/settings_registry.dart`، `setting_field_builder.dart`، همهٔ فایل‌های `groups/`

**کار دقیق:**
1. فیلد `visibility` (SET-08) را برای همهٔ توصیفگرها دقیق پر کن. دست‌کم این خانواده‌ها `advanced` هستند: `coalescing_window_minutes`، `max_non_essential_per_hour`، `snooze_max_defer_count`، `ai_base_url`، `ai_api_key`، `ai_model`، `ai_timeout`، `ai_provider_preset`، `theme_reduce_transparency`، `theme_true_black`، `calendar_compress_recurring`، `calendar_overdue_lookback_days`، `backup_frequency_days`، `app_lock_timeout_seconds`، `persistent_status_notification_enabled`.
2. در هر صفحهٔ گروه، وقتی `app_mode == 'simple'`، ردیف‌های `advanced` را در یک بخش تاشو با عنوان «تنطیمات پیشرفته (N مورد)» جمع کن. **حذف نکن، فقط تا بزن.** در حالت `full` بخش باز باشد.
3. خود `app_mode` را در بالای صفحهٔ اصلی تنطیمات به عنوان یک دودکمه‌ای قرار بده: «ساده» / «پیشرفته» با یک توضیح یک‌خطی.
4. جست‌وجو (فاز F) باید **همه** را پیدا کند، مستقل از حالت. وقتی کاربر از جست‌وجو به یک تنطیم پیشرفته می‌رود، بخش تاشو باید خودکار باز شود. **مخفی کردن در جست‌وجو دقیقاً باگ H15 را دوباره می‌سازد.**

**معیار پذیرش:** در حالت ساده، تعداد ردیف‌های باز در صفحهٔ اعلان‌ها دست‌کم ۴۰ درصد کمتر است؛ هیچ تنطیمی از دسترس خارج نمی‌شود.

**تست:** `test/settings/app_mode_visibility_test.dart` — شامل تستی که ثابت کند در حالت ساده هم همهٔ کلیدها از طریق جست‌وجو قابل دسترسی اند.

**commit:** `feat(settings): SET-52 — حالت ساده و پیشرفته`

---

### SET-53 — کارت «سلامت تنطیمات» با راه‌حل تک‌ضربه‌ای

**مشکل:** ترکیب‌های متناقض و بی‌اطلاع کاربر وجود دارند که باعث می‌شوند اپ «خراب» به نطر برسد: اعلان اصلی خاموش ولی چند یادآور روشن؛ ساعات سکوت روی تمام روز؛ دستیار در حالت کلید شخصی بدون کلید API؛ قفل برنامه بدون رمز؛ پشتیبان خودکار خاموش؛ حالت حریم خصوصی اعلان `none` روی دستگاه بدون قفل.

**فایل جدید:** `lib/features/settings/presentation/widgets/settings_health_card.dart` به علاوهٔ `lib/core/settings/settings_health.dart`

**کار دقیق:**
1. منطق را جدا از رابط کاربری بنویس تا قابل تست باشد:
   ```dart
   class SettingsHealthIssue {
     final String id;
     final String titleFa;      // مشکل در یک جمله
     final String detailFa;     // توضیح کوتاه
     final String fixLabelFa;   // متن دکمهٔ راه‌حل
     final Future<void> Function() fix;
     final SettingsHealthSeverity severity; // info | warning | critical
   }
   List<SettingsHealthIssue> detectSettingsHealthIssues();
   ```
2. دست‌کم هفت قاعدهٔ بالا را پیاده کن. هر کدام باید یک راه‌حل واقعی داشته باشد (یا یک پرش به همان تنطیم با `focusKey` از SET-46) — **هشدار بدون راه‌حل ننویس.**
3. کارت را بالای صفحهٔ اصلی تنطیمات قرار بده، ولی **فقط وقتی دست‌کم یک مورد وجود دارد**. در حالت سلامت کامل، هیچ فضایی نگیرد (پیام «همه چیز خوب است» ننویس — فقط نویز است).
4. حداکثر سه مورد را نشان بده و بقیه را پشت «نمایش همه (N)» بگذار، مرتب‌شده از بحرانی به اطلاع‌رسانی.
5. هر مورد را قابل رد کردن کن (ذخیره در یک کلید داخلی `health_dismissed_ids`)، مگر موارد با شدت `critical` که قابل رد کردن نیستند.

**معیار پذیرش:** با خاموش کردن اعلان اصلی در حالی که یادآورها روشن هستند، کارت پدیدار می‌شود و دکمهٔ راه‌حل واقعاً مشکل را حل می‌کند.

**تست:** `test/settings/settings_health_test.dart` — برای هر هفت قاعده یک سناریو.

**commit:** `feat(settings): SET-53 — کارت سلامت تنطیمات`

---

### SET-54 — پیش‌نمای حلقهٔ ۲۴ ساعته برای تنطیمات زمانی

**مشکل:** پنج تنطیم زمانی در دو گروه جدا و به صورت عدد خام عرضه می‌شوند: `notif_quiet_start`، `notif_quiet_end`، `wake_time`، `sleep_time`، `daily_planning_nudge_time`. کاربر هیچ تصویر ذهنی از روی هم افتادنشان ندارد — مانند اینکه یادآور برنامه‌ریزی روزانه دقیقاً در وسط ساعات سکوت باشد و هرگز نرسد.

**فایل جدید:** `lib/features/settings/presentation/widgets/day_ring_preview.dart`

**کار دقیق:**
1. یک ویجت حلقه‌ای ۲۴ ساعته با `CustomPainter` بساز که چند قوس رنگی می‌گیرد (ساعات سکوت، پنجرهٔ خواب) و چند نشانگر نقطه‌ای (یادآور برنامه‌ریزی). ورودی بر مبنای دقیقه از نیمه‌شب باشد (همان `parseHhMm` از SET-15).
2. عبور از نیمه‌شب را درست رسم کن (مانند ساعات سکوت ۲۳ تا ۷). این محاسبه را در یک تابع خالص جدا بگذار و تست کن.
3. زیر حلقه، هشدارهای معنادار بنویس: «یادآور برنامه‌ریزی در ساعات سکوت است و نمایش داده نمی‌شود.» یا «پنجرهٔ خواب شما ۷ ساعت و ۳۰ دقیقه است.»
4. حلقه را در دو محل قرار بده: بالای بخش ساعات سکوت در اعلان‌ها، و بالای بخش خواب/بیداری در دستیار. دو نمای مختلف از یک ویجت، نه دو پیاده‌سازی.
5. در حلقه ارقام را فارسی بنویس (`toPersianDigits`) و جهت چرخش را با حس فارسی سازگار کن.

**معیار پذیرش:** تغییر هر یک از پنج تنطیم زمانی، حلقه را بلافاصله عوض می‌کند؛ تناقض یادآور در ساعات سکوت تشخیص داده می‌شود.

**تست:** `test/settings/day_ring_math_test.dart` — شامل مورد عبور از نیمه‌شب، مورد مساوی بودن شروع و پایان، و مورد بازهٔ صفر.

**commit:** `feat(settings): SET-54 — پیش‌نمای حلقهٔ روزانه برای تنطیمات زمانی`

---

### SET-55 — خروجی و ورودی تنطیمات با پیش‌نمای تفاوت

**مشکل:** هیچ راهی برای جابه‌جایی تنطیمات بین دو دستگاه، یا بازگرداندن پس از نصب مجدد، یا گزارش دقیق وضعیت برای پشتیبانی وجود ندارد.

**فایل جدید:** `lib/core/settings/settings_portability.dart`

**کار دقیق:**
1. خروجی: یک JSON نسخه‌دار بساز با سه فیلد ریشه: نسخهٔ طرحواره (SET-20)، زمان ساخت، و نگاشت کلید به مقدار.
2. **قانون مطلق: هیچ کلید `secure` و هیچ کلید داخلی در خروجی نیاید.** فهرست کلیدهای قابل خروجی را از رجیستری بساز، نه از کل جدول. در پایان فایل، یک خط فارسی بنویس: «این فایل شامل رمزها و کلیدهای شما نیست.»
3. ورودی دومرحله‌ای باشد. مرحلهٔ اول **فقط تحلیل و پیش‌نمای تفاوت**، بدون هیچ نوشتن:
   - «۷ تنطیم تغییر می‌کند، ۲ کلید ناشناخته نادیده گرفته می‌شود، ۳ مقدار نامعتبر رد می‌شود.»
   - فهرست خط‌به‌خط: برچسب فارسی تنطیم، مقدار فعلی به مقدار جدید
4. مرحلهٔ دوم با `setMany` (SET-21) در یک تراکنش اعمال شود. هر مقداری که اعتبارسنجی را رد نکند، کنار گذاشته و در گزارش نهایی فهرست می‌شود. **یک مقدار بد نباید کل ورودی را بشکند.**
5. در بخش داده و پشتیبان، دو ردیف اضافه کن: «خروجی گرفتن تنطیمات» و «وارد کردن تنطیمات».

**معیار پذیرش:** خروجی و ورودی روی دو نمونهٔ مختلف درست کار می‌کند؛ جست‌وجوی فایل خروجی برای رشتهٔ `password` یا `api_key` هیچ مقداری نمی‌یابد.

**تست:** `test/settings/portability_test.dart` — شامل تست صریح «هیچ کلید امنی در خروجی نیست» و تست ورودی فایل معیوب.

**commit:** `feat(settings): SET-55 — خروجی و ورودی تنطیمات با پیش‌نمای تفاوت`

---

### SET-56 — شفافیت و کنترل نوشتن توسط دستیار [بحرانی]

**مشکل:** پس از SET-24 دستیار واقعاً محدود می‌شود، ولی کاربر همچنان نمی‌داند کدام تنطیمات را دستیار می‌تواند عوض کند، چه وقت عوض کرده، و چگونه برگرداند. این هم مسئلهٔ اعتماد است و هم مسئلهٔ دیباگ.

**فایل‌ها:** `setting_field_builder.dart`، `lib/core/settings/settings_service.dart`، `assistant_privacy_group_screen.dart`

**کار دقیق:**
1. در هر ردیفی که `aiWritable == true` است، یک چیپ کوچک «قابل تغییر توسط دستیار» نشان بده.
2. یک کلید اصلی جدید در رجیستری بساز: `ai_settings_write_enabled`، دامنه `db`، پیش‌فرض `true`، گروه `assistant`، **`aiWritable: false`** (دستیار نباید بتواند مجوز خودش را بالا ببرد). در `setChecked` وقتی `origin == SettingsWriteOrigin.ai` و این کلید خاموش است، `SettingWriteRejected('تغییر تنطیمات توسط دستیار خاموش است.')` برگردان.
3. یک ژورنال سبک برای نوشتن‌های دستیار نگه دار: کلید، مقدار قبل، مقدار بعد، زمان. حداکثر بیست رکورد آخر را نگه دار (حلقهٔ محدود). **اگر پروژه از قبل `AgentJournal` دارد، از همان استفاده کن و موازی‌سازی نکن** — اول `rg -n "AgentJournal" lib/ -l` بزن.
4. در گروه دستیار، یک بخش «تغییرات اخیر دستیار» بگذار که هر رکورد را با دکمهٔ «بازگرداندن» نشان می‌دهد. بازگرداندن باید از مسیر `origin: user` انجام شود.
5. مقدار کلیدهای `secure` هرگز در ژورنال نوشته نشود (قانون ۱۷).

**معیار پذیرش:** با خاموش بودن کلید اصلی، هیچ مسیر هوش مصنوعی نمی‌تواند هیچ تنطیمی را عوض کند؛ هر نوشتن موفق در ژورنال دیده می‌شود و قابل بازگرداندن است.

**تست:** `test/settings/ai_write_journal_test.dart`.

**commit:** `feat(settings): SET-56 — شفافیت و کنترل نوشتن دستیار`

---

### SET-57 — کشوی تنطیمات سریع

**مشکل:** برای خاموش کردن موقت اعلان‌ها یا عوض کردن تم، کاربر باید سه تا چهار لمس انجام دهد: پروفایل، تنطیمات، گروه، ردیف. این در طول روز چند بار تکرار می‌شود.

**فایل جدید:** `lib/features/settings/presentation/widgets/quick_settings_sheet.dart`

**کار دقیق:**
1. یک شیت پایینی بساز با دقیقاً شش کلید پرکاربرد (همان فهرست SET-50): `theme_mode`، `notif_master_enabled`، `notif_quiet_enabled`، `app_lock_enabled`، `calendar_default_scale`، `wake_time`.
2. همهٔ ردیف‌ها با همان `SettingField` رندر شوند — **هیچ پیاده‌سازی دومی ننویس.** این دقیقاً همان دامی است که در مورد تم (C6) و ماژول‌ها (H22) در این پروژه رخ داد.
3. ورودی‌ها: فشار طولانی روی چیپ تنطیمات در نوار بالایی، به علاوهٔ یک دکمهٔ «تنطیمات سریع» در بالای صفحهٔ اصلی تنطیمات.
4. در پایین شیت، یک دکمهٔ «همهٔ تنطیمات» بگذار که شیت را می‌بندد و با الگوی امن SET-47 ناوبری می‌کند.
5. `RitmoHaptics.tap()` را روی هر تغییر وصل کن، مطابق الگوی موجود پروژه.

**معیار پذیرش:** خاموش کردن اعلان اصلی در دو لمس ممکن است؛ تغییر در شیت فوراً در صفحهٔ گروه هم دیده می‌شود (همان `watch` از SET-22).

**تست:** تست ویجت که تغییر در شیت در ویجت دیگر منعکس می‌شود.

**commit:** `feat(settings): SET-57 — شیت تنطیمات سریع`

---

### SET-58 — کارت خلاصهٔ حریم خصوصی [بحرانی]

**مشکل:** تنطیمات حساس در چهار گروه مختلف پراکنده‌اند و هیچ‌جا یکجا دیده نمی‌شوند. در SET-37 تصمیم گرفتیم تنطیمات چرخه را جابه‌جا نکنیم (تا منطق موجود نشکند)؛ پس **راه‌حل این کارت است.** مسئلهٔ جدی این است: هیچ روایت واحدی برای کاربر وجود ندارد که «چه چیزی روی دستگاه مانده، چه چیزی به ابر می‌رود، چه چیزی در اعلان قفل دیده می‌شود».

**فایل جدید:** `lib/features/settings/presentation/widgets/privacy_summary_card.dart`

**کار دقیق:**
1. یک کارت با چهار خط خوانا، هر خط با وضعیت و یک میان‌بر (با `focusKey` از SET-46):
   - **دادهٔ چرخه:** `module_cycle_enabled` به علاوهٔ `cycle_consent` (SET-23) به علاوهٔ `cycle_lock_password` به علاوهٔ `show_cycle_in_calendar` — یک جملهٔ جمع‌بندی، مانند «روشن، با رمز، در تقویم مخفی».
   - **دستیار و ابر:** `assistant_cloud_consent` به علاوهٔ `ai_mode` به علاوهٔ `ai_memory_enabled` به علاوهٔ `ai_memory_implicit_enabled`.
   - **اعلان روی قفل صفحه:** `notif_privacy_mode` به علاوهٔ `notif_biometric_enabled`.
   - **قفل برنامه و گزارش خرابی:** `app_lock_enabled` به علاوهٔ `app_biometric_enabled` به علاوهٔ `crash_reports_enabled`.
2. وقتی ترکیب خطرناک است، رنگ هشدار بده و دلیل را فارسی بنویس — مانند «دادهٔ چرخه روشن است ولی رمز ندارد» یا «متن کامل اعلان‌ها روی قفل صفحه دیده می‌شود».
3. کارت را در بالای گروه امنیت قرار بده و **یک ردیف میان‌بر هم در گروه دستیار و هم در گروه اعلان‌ها** بگذار که به همین کارت می‌برد.
4. قاعدهٔ M-12 حریم خصوصی را رعایت کن: اگر `CyclePrivacyGuard` می‌گوید چرخه نباید دیده شود، خط اول را **کاملاً مخفی** کن — این تنها جایی است که «مخفی کردن» درست است و نه «غیرفعال با توضیح» (قاعدهٔ SET-44 این‌جا استثنا دارد، چون خود وجود توضیح افشای اطلاعات است).

**معیار پذیرش:** کاربر بدون ترک کردن یک صفحه می‌فهمد وضعیت حریم خصوصیاش چیست؛ هیچ مقدار رازی نمایش داده نمی‌شود؛ برای کاربر مرد، خط چرخه دیده نمی‌شود.

**تست:** `test/settings/privacy_summary_test.dart` — شامل تست M-12.

**commit:** `feat(settings): SET-58 — کارت خلاصهٔ حریم خصوصی`

---

### SET-59 — توضیح‌گر «چرا؟» درون‌خطی

**مشکل:** `descriptionFa` یک‌خطی و برای تنطیمات فنی ناکافی است. کاربر نمی‌داند «پنجرهٔ تجمیع» یا «سقف اعلان غیرضروری در ساعت» یا «فشرده‌سازی تکرارشونده» یعنی چه، پس یا دست نمی‌زند یا بدتر، تصادفی عوض می‌کند.

**فایل‌ها:** `settings_registry.dart`، `setting_field_builder.dart`

**کار دقیق:**
1. یک فیلد اختیاری به توصیفگر اضافه کن: `final String? whyFa;` — دو تا چهار جمله با یک مثال واقعی.
2. برای دست‌کم بیست تنطیم فنی این فیلد را پر کن. اولویت: `coalescing_window_minutes`، `max_non_essential_per_hour`، `digest_mode`، `notif_privacy_mode`، `snooze_max_defer_count`، `app_lock_timeout_seconds`، `ai_mode`، `ai_timeout`، `ai_memory_implicit_enabled`، `assistant_cloud_consent`، `gentleness_level`، `daily_capacity_minutes`، `calendar_compress_recurring`، `calendar_overdue_lookback_days`، `theme_reduce_transparency`، `theme_true_black`، `persistent_status_notification_enabled`، `crash_reports_enabled`، `backup_frequency_days`، `app_use_device_lock`.
3. در ردیف‌هایی که `whyFa` دارند، یک آیکون کوچک علامت سوال بگذار که یک بخش تاشوی درون‌خطی باز می‌کند. **دیالوگ مودال باز نکن** — جریان خواندن کاربر نباید قطع شود.
4. وقتی یک تنطیم غیرفعال است (SET-44)، درون همین بخش تاشو توضیح وابستگی را هم بنویس و دکمهٔ میان‌بر به تنطیم والد را همان‌جا قرار بده.
5. متن‌ها باید فارسی روان و بدون اصطلاح فنی انگلیسی باشند؛ واحدها را با ارقام فارسی بنویس.

**معیار پذیرش:** باز کردن توضیح جایی از صفحه را نمی‌پراند و با برگشت به عقب بسته نمی‌شود.

**تست:** `test/settings/why_fa_coverage_test.dart` — ثابت کن هر کلیدی که `visibility` آن `advanced` است، `whyFa` دارد.

**commit:** `feat(settings): SET-59 — توضیح‌گر درون‌خطی چرا`

---

### SET-60 — چیپ «نیاز به راه‌اندازی مجدد» و تحویل دسته‌ای از ورود اولیه

**مشکل ۱:** فیلد `requiresRestart` در SET-02 ساخته شد و در SET-32 برای زبان مقدار `true` گرفت، ولی هیچ کدام از ردیف‌ها آن را نشان نمی‌دهند. کاربر زبان را عوض می‌کند، هیچ اتفاقی نمی‌افتد و فکر می‌کند اپ خراب است.

**مشکل ۲:** جریان ورود اولیه چند تنطیم را پشت سر هم و تک‌تک می‌نویسد — یعنی چند تراکنش مجزا، چند بار `revision.value++` و در بدترین حالت حالت نیمه‌کاره اگر کاربر وسط کار خارج شود.

**فایل‌ها:** `setting_field_builder.dart`، `settings_registry.dart`، جریان ورود اولیه (اول با `rg -n "onboarding_completed" lib/ -l` پیدایش کن)

**کار دقیق:**
1. در `SettingField`، وقتی `desc.requiresRestart == true` و مقدار در این نشست عوض شده، یک چیپ محجوب زیر ردیف نشان بده: «برای اعمال کامل، برنامه را یک بار ببند و باز کن.» بدون دکمهٔ «حالا راه‌اندازی مجدد» — بستن برنامه به زور روی موبایل کار مناسبی نیست.
2. دست‌کم این کلیدها را مرور کن و اگر واقعاً به راه‌اندازی مجدد نیاز دارند، `requiresRestart: true` بگذار: `locale`، `persistent_status_notification_enabled`، `theme_true_black` (فقط اگر واقعاً زنده اعمال نمی‌شود — اول تست کن). **فقط جایی که واقعیت دارد، وگرنه چیپ دروغ می‌شود.**
3. جریان ورود اولیه را به `setMany` (SET-21) تغییر بده: همهٔ تنطیمات جمع‌شده در یک تراکنش نوشته شوند و `onboarding_completed` **فقط در همان تراکنش و به عنوان آخرین کلید** مقدار `true` بگیرد. این مستقیماً باگ H1 را ماندگار می‌کند: ورود اولیه یا کامل انجام شده یا هیچ.
4. اگر جریان ورود اولیه وجود ندارد یا خارج از مسیرهای مجاز قانون ۱۵ است، فقط قسمت چیپ را انجام بده و در ledger یادداشت بنویس که قسمت دوم `BLOCKED` شد — و برو سراغ تسک بعدی. سوال نپرس.

**معیار پذیرش:** عوض کردن زبان چیپ را نشان می‌دهد؛ خروج وسط جریان ورود اولیه هیچ تنطیم نیمه‌کاره‌ای برجا نمی‌گذارد.

**تست:** `test/settings/onboarding_atomic_test.dart`.

**commit:** `feat(settings): SET-60 — چیپ راه‌اندازی مجدد و تحویل دسته‌ای ورود اولیه`

---

## فاز H — دسترس‌پذیری، پاک‌سازی و تست (SET-61 … SET-70)

### SET-61 — دسترس‌پذیری و هدف لمس استاندارد

**مشکل:** ردیف‌های تنطیمات با `GestureDetector` ساخته شده‌اند، نه `InkWell` یا `CupertinoButton`. نتیجه:
- هیچ بازخورد بصری لمس وجود ندارد (فقط لرزش).
- `Semantics(button: true)` نیست، پس صفحه‌خوان ردیف را به عنوان دکمه اعلام نمی‌کند.
- کلیدهای دووضعیتی برچسب معنادار ندارند؛ صفحه‌خوان فقط «روشن/خاموش» بدون اینکه چه چیزی می‌گوید.
- ارتفاع برخی نواحی لمس کمتر از ۴۸ پیکسل است.

**فایل‌ها:** `settings_tile.dart`، `settings_screen.dart` (ویجت `_Ios26SettingsTile`)، `setting_field_builder.dart`، `danger_zone.dart`

**کار دقیق:**
1. هر ناحیهٔ قابل لمس را در `Semantics` بپیچ با `button: true` و `label` فارسی معنادار. برای کلیدهای دووضعیتی، `Semantics(toggled: value, label: desc.labelFa)` بگذار.
2. `GestureDetector` را در ردیف‌های قابل کلیک با یک ویجت دارای بازخورد لمس عوض کن. لرزش موجود (`RitmoHaptics.tap()`) را نگه دار.
3. حداقل ارتفاع هر ردیف را ۴۸ پیکسل کن (`ConstrainedBox` یا `minHeight`).
4. در منطقهٔ خطر، دکمهٔ نهایی باید `Semantics` صریح با متن هشدار داشته باشد (کاربر نابینا نباید تصادفی همهٔ داده‌اش را پاک کند).
5. ترتیب پیمایش صفحه‌خوان را درست کن: عنوان بخش باید قبل از ردیف‌های همان بخش خوانده شود.

**معیار پذیرش:** با روشن بودن صفحه‌خوان، هر ردیف با برچسب فارسی و وضعیتش اعلام می‌شود.

**تست:** `test/settings/semantics_test.dart` — با `tester.getSemantics` دست‌کم برای سه نوع ردیف (دووضعیتی، پرشی، مقداری).

**commit:** `fix(settings): SET-61 — دسترس‌پذیری و هدف لمس استاندارد`

---

### SET-62 — یکسان‌سازی آیکون جهت و حاشیهٔ جهت‌مند

**باگ:** در یک فیچر دو آیکون متفاوت برای یک معنا استفاده شده: `CupertinoIcons.chevron_left` در `settings_screen.dart` و `CupertinoIcons.chevron_back` در `settings_tile.dart`. طاهر این دو در کنار هم ناهماهنگ است. همچنین `EdgeInsets.only(right: 4)` به جای نسخهٔ جهت‌مند استفاده شده که در چیدمان راست‌به‌چپ معنای اشتباه دارد.

**فایل‌ها:** `settings_tile.dart`، `settings_screen.dart`، همهٔ فایل‌های `groups/` و `widgets/`

**کار دقیق:**
1. `rg -n "CupertinoIcons.chevron_back" lib/features/settings` بزن و همه را به `CupertinoIcons.chevron_left` تغییر بده (یا برعکس) — فقط یک انتخاب در کل فیچر باقی بماند.
2. `rg -n "EdgeInsets.only\(" lib/features/settings` بزن. هر جا `left` یا `right` دارد و معنای جهتی دارد، به `EdgeInsetsDirectional.only(start:/end:)` تغییر بده. جاهایی که عمداً فیزیکی هستند (مانند سایه) را دست نزن.
3. همین را برای `Alignment.centerLeft/centerRight` در متن‌های فارسی بررسی کن و به `AlignmentDirectional` ببر.
4. `Icon` هایی که معنای جهتی دارند را با `Directionality` سازگار کن (در فارسی، چورون «برو جلو» باید به چپ باشد).

**معیار پذیرش:** هر دو دستور `rg` در بالا خروجی تمیز می‌دهند؛ طاهر چورون‌ها در همهٔ نه صفحه یکسان است.

**تست:** `test/settings/directionality_test.dart` — رندر یک صفحهٔ گروه در `TextDirection.rtl` بدون خطای چیدمان.

**commit:** `fix(settings): SET-62 — یکسان‌سازی آیکون جهت و حاشیهٔ جهت‌مند`

---

### SET-63 — حذف رنگ‌های درجشده در کد

**باگ:** فیچر تنطیمات یک سیستم تم کامل دارد (`context.colors`) ولی در چند جا رنگ خام نوشته شده: چهار رنگ ششضلعی تیره، `Colors.amber`، و هشت گرادیان دورنگی کارت گروه‌ها. در تم روشن، برخی از این رنگ‌ها متن را تقریباً خواناناپذیر می‌کنند، و در حالت «مشکی واقعی» و «کاهش شفافیت» هیچ واکنشی نشان نمی‌دهند.

**فایل‌ها:** همهٔ فایل‌های `lib/features/settings/`

**کار دقیق:**
1. `rg -n "Color\(0x" lib/features/settings` و `rg -n "Colors\." lib/features/settings` بزن و فهرست کن.
2. گرادیان‌های کارت گروه را از `settings_screen.dart` به همان اکستنشن `SettingsGroupMeta` (SET-37) منتقل کن — یک محل، نه هشت لیترال پراکنده.
3. برای متن روی گرادیان، رنگ را بر اساس روشنایی پس‌زمینه حساب کن (`ThemeData.estimateBrightnessForColor`)، نه با فرض سفید بودن.
4. رنگ‌های معنادار (خطر، هشدار، موفقیت) را به معادل تم وصل کن (مانند `context.colors.medicalRed` برای خطر). اگر تم رنگ هشدار ندارد، فقط **یک رنگ** به تم اضافه کن و همه را به آن وصل کن.
5. `theme_reduce_transparency` را محترم بدار: وقتی روشن است، بلور و شفافیت کارت‌ها را به رنگ توپر تبدیل کن.

**معیار پذیرش:** در هر چهار حالت (روشن، تیره، مشکی واقعی، کاهش شفافیت) همهٔ متن‌ها خوانا هستند.

**تست:** `test/settings/theme_hardcoded_colors_test.dart` — تست معماری که وجود رنگ خام در فیچر تنطیمات را مردود کند (به جز فایل متادادهٔ گروه).

**commit:** `fix(settings): SET-63 — رنگ‌ها از تم، نه از کد`

---

### SET-64 — تست یکپارگی رجیستری [بحرانی]

**مشکل:** رجیستری ۷۲ توصیفگر دارد و هیچ تستی ندارد (`test/settings/` وجود ندارد). دقیقاً همین باعث شد C1 (کلیدهای دروغین پرچم‌ها)، H2 (گزینهٔ تکراری جنسیت) و H21 (مقدار ویژهٔ منفی) هرگز دیده نشوند. این تسک **تور محافط کل فازهای قبلی** است.

**فایل جدید:** `test/settings/registry_integrity_test.dart`

**کار دقیق — دست‌کم این دوازده تأکید:**
1. هیچ کلید تکراری در `SettingsRegistry.all` وجود ندارد.
2. هر `allowed` بدون عنصر تکراری است (مستقیماً H2).
3. هر توصیفگر `enumeration` دقیقاً `allowed` غیرخالی دارد، و `defaultValue` او در `allowed` هست.
4. هیچ توصیفگر غیر `enumeration` فیلد `allowed` ندارد.
5. هر `integer` مقدار `min` و `max` دارد و `min` کوچکتر یا مساوی `defaultValue` کوچکتر یا مساوی `max` است. مقدار ویژهٔ مهلت قفل فقط از مسیر ثابت‌های SET-07/SET-28 مجاز است، نه به عنوان `min` منفی دلبخواه.
6. هر `time` پیش‌فرض معتبری دارد (ساعت بین صفر تا ۲۳ و دقیقه بین صفر تا ۵۹، با دو رقم و دونقطه) — با `parseHhMm` از SET-15 بسنج، نه با الگوی مجزا.
7. نوع دادهٔ `defaultValue` با `type` هماهنگ است (بولی، عدد صحیح، رشته).
8. هیچ توصیفگر با دامنهٔ `secure` مقدار `aiWritable: true` ندارد (تأکید SET-24).
9. همهٔ کلیدهایی که `SettingsFlags` می‌خواند در رجیستری وجود دارند (تأکید C1 — این تست باید قبل از SET-23 قرمز باشد و بعد از آن سبز).
10. هر `SettingsGroup` درست یک `titleFa` غیرخالی دارد و همهٔ عناوین گروه بین هم یکتا هستند (تأکید SET-37).
11. هر کلیدی که `dependsOn` دارد، کلید والدش در رجیستری وجود دارد و هیچ حلقهٔ وابستگی وجود ندارد (تأکید SET-44).
12. هر توصیفگر کاربرپسند دقیقاً در یکی از نه صفحهٔ گروه رندر می‌شود (همان تست پوشش SET-39 را این‌جا هم فراخوانی کن — دوباره ننویس).

**معیار پذیرش:** همهٔ دوازده تأکید سبزند. اگر یکی قرمز شد، **تست را ضعیف نکن — کد را درست کن.**

**تست:** همین فایل خود تست است.

**commit:** `test(settings): SET-64 — تست یکپارگی رجیستری`

---

### SET-65 — مقیاس متن و تست گلدن

**باگ:** اندازهٔ قلم در ردیف‌های تنطیمات عدد ثابت است (۱۱، ۱۲، ۱۵، ۱۶) و توضیح‌ها `maxLines: 2` دارند. وقتی کاربر مقیاس متن سیستم را بالا می‌برد (کاری که کاربران مسن حتماً می‌کنند)، توضیح‌ها بریده می‌شوند یا سرریز می‌کنند.

**فایل‌ها:** `settings_tile.dart`، `settings_section.dart`، `setting_field_builder.dart`، `settings_screen.dart`

**کار دقیق:**
1. اعداد ثابت قلم را با سبک‌های تم عوض کن (مانند `Theme.of(context).textTheme.bodyMedium`) تا مقیاس متن خودکار اعمال شود.
2. `maxLines: 2` را از توضیح‌ها بردار یا به عدد بالاتر ببر؛ ارتفاع ردیف باید رشد کند، نه متن بریده شود.
3. در ردیف‌هایی که برچسب و مقدار در یک خط هستند، در مقیاس‌های بالا به چیدمان دوخطی سویچ کن.
4. سه تست گلدن بساز برای مقیاس‌های ۱، ۱.۵ و ۲ روی دو صفحهٔ پرردیف (اعلان‌ها و امنیت). اگر دایرکتوری `test/golden/` هست، همان الگوی موجود پروژه را دنبال کن و سازوکار جدید نساز.
5. موارد سرریز (`RenderFlex overflowed`) باید صفر باشند. در تست، هر خطای چیدمان باید تست را قرمز کند.

**معیار پذیرش:** در مقیاس متن ۲، هیچ ردیفی سرریز نمی‌کند و هیچ توضیحی بریده نمی‌شود.

**تست:** `test/settings/text_scale_golden_test.dart`.

**commit:** `fix(settings): SET-65 — مقیاس متن و تست گلدن`

---

### SET-66 — پاک‌سازی چرخهٔ عمر و نشت کنترلرها

**باگ:** در فیچر تنطیمات دست‌کم دو نشت تأییدشده وجود داشت: کنترلر متن در منطقهٔ خطر و کنترلر رمز در گروه امنیت (در SET-29 و SET-26 درست شدند). این تسک باقیٔ فیچر را جارو می‌کند — مخصوصاً چهار فایل بزرگی که در مرور اولیه کامل خوانده نشدند.

**فایل‌ها:** همهٔ `lib/features/settings/`، با تمرکز روی `identity_group_screen.dart`، `identity_header.dart`، `notifications_group_screen.dart`، `notification_privacy_screen.dart`، `data_backup_group_screen.dart`، `assistant_privacy_group_screen.dart`

**کار دقیق:**
1. این چهار دستور را بزن و هر مورد را بررسی کن:
   ```bash
   rg -n "TextEditingController" lib/features/settings
   rg -n "AnimationController" lib/features/settings
   rg -n "ScrollController" lib/features/settings
   rg -n "FocusNode" lib/features/settings
   ```
2. برای هر مورد، مطمئن شو در `dispose` رها می‌شود. کنترلرهای محلی درون توابع دیالوگ را با `try/finally` یا با تبدیل دیالوگ به `StatefulWidget` درست کن.
3. همهٔ `Timer` و `StreamSubscription` ها را هم چک کن: `rg -n "Timer\(|Timer\.|\.listen\(" lib/features/settings`.
4. هر جا پس از `await` از `context` یا `setState` استفاده شده، گارد `if (!mounted) return;` یا `if (!context.mounted) return;` بگذار: `rg -n "await" lib/features/settings -A 3 | rg -n "setState|context"`.
5. `ValueNotifier` های محلی را هم رها کن. `revision` کلی سرویس استناست و طول عمر اپ دارد — آن را رها نکن.

**معیار پذیرش:** هر کنترلری که ساخته می‌شود دقیقاً یک مسیر رهاسازی دارد؛ اجرای تست‌ها هیچ هشدار نشت نمی‌دهد.

**تست:** `test/settings/lifecycle_dispose_test.dart` — باز و بسته کردن هر نه صفحهٔ گروه در یک حلقه، بدون خطا.

**commit:** `fix(settings): SET-66 — پاک‌سازی چرخهٔ عمر و رهاسازی کنترلرها`

---

### SET-67 — حذف کامل debugPrint و catch خالی

**باگ:** در مرور، شش `debugPrint` در فیچر تنطیمات تأیید شد (پنج در سرویس، یک در منطقهٔ خطر) که یکی از آن‌ها **مقدار ردشده را چاپ می‌کند** — یعنی اگر روزی یک کلید امن از مسیر عادی بگذرد، راز در لاگ می‌نشیند. همچنین `_loadPackageInfo` یک `catch (_) {}` کاملاً خاموش دارد که باعث می‌شود نسخهٔ اپ بی‌صدا روی مقدار ثابت «۱.۰.۰» بماند و گزارش خرابی ها با نسخهٔ دروغ ثبت شوند.

**فایل‌ها:** `lib/core/settings/`، `lib/features/settings/`

**کار دقیق:**
1. `rg -n "debugPrint" lib/core/settings lib/features/settings` بزن و همه را به `RitmoLog` ببر (`RitmoLog.error` برای خطا، `RitmoLog.debug` برای دیباگ). پیشوند لاگ را `[Settings]` یکدست کن.
2. **در هیچ لاگی مقدار تنطیم را ننویس.** فقط نام کلید، نوع خطا و طول مقدار مجاز است. اگر پروژه سامانهٔ حذف اطلاعات دارد (تست `logger_redaction` وجود دارد)، از همان استفاده کن.
3. `rg -n "catch \(_\) \{\}|catch \(_\) \{ \}" lib/core/settings lib/features/settings` بزن. هر مورد باید یا لاگ بشود یا مقدار بدیل روشنی داشته باشد. قانون ۶ را یاد بیاور.
4. برای `_loadPackageInfo` به طور خاص: خطا را لاگ کن و وقتی نسخه خوانده نشد، به جای نمایش مقدار ثابت، ردیف نسخه را خالی یا «نامشخص» نشان بده. **مقدار ثابت «۱.۰.۰» و «۱» را از کد حذف کن** و واقعاً از `PackageInfo` بخوان؛ ارقام را با `toPersianDigits` فارسی کن.

**معیار پذیرش:** هر دو دستور `rg` خروجی خالی می‌دهند؛ نسخهٔ نمایشی با نسخهٔ واقعی اپ یکی است.

**تست:** `test/settings/no_secret_logging_test.dart` — لاگر را جعل کن، یک نوشتن ردشده روی کلید امن انجام بده و ثابت کن مقدار در خروجی لاگ نیست.

**commit:** `fix(settings): SET-67 — لاگ ایمن و حذف catch خالی`

---

### SET-68 — افوردنس‌های دیباگ در مسیر تولید

**باگ ۱:** در صفحهٔ اصلی تنطیمات، هفت بار لمس روی شمارهٔ نسخه، صفحهٔ گزارش‌های خرابی را باز می‌کند، و شمارنده مادام‌العمر است (ریست نمی‌شود). کاربری که طی یک ماه چند بار روی نسخه لمس کرده، ناگهان در یک صفحهٔ فنی می‌افتد و نمی‌داند چطور و چرا.

**باگ ۲:** یک دکمهٔ دیباگ که هفت شب خواب جعلی در دیتابیس می‌ریزد در درخت ویجت صفحهٔ تنطیمات است. هرچند پشت `kDebugMode` است، ولی در کنار دکمهٔ بازنشانی کارخانه قرار گرفتن این دکمه در نسخهٔ دیباگ هم خطرناک است — مخصوصاً با دادهٔ واقعی یک تستر.

**فایل‌ها:** `lib/features/settings/presentation/settings_screen.dart`

**کار دقیق:**
1. شمارندهٔ لمس را در یک پنجرهٔ زمانی محدود کن: اگر بین دو لمس بیش از ۲ ثانیه فاصله بود، شمارنده را صفر کن.
2. پیش از باز کردن صفحهٔ فنی، بازخورد پیشرونده بده: از لمس چهارم به بعد یک پیام کوتاه نشان بده: «۳ لمس تا حالت توسعه‌دهنده». غافلگیر کردن کاربر ممنوع است.
3. دکمهٔ پرکردن دادهٔ خواب را از صفحهٔ تنطیمات **حذف** کن و به همان صفحهٔ دیباگ منتقل کن (همان جایی که با هفت لمس باز می‌شود). اگر بازرس SET-70 را ساختی، همان‌جا بگذار.
4. در خود صفحهٔ دیباگ، پرکردن دادهٔ جعلی را پشت یک تأیید ببر که صریحاً می‌گوید دادهٔ جعلی در دیتابیس واقعی نوشته می‌شود.
5. مطمئن شو همهٔ مسیرهای دیباگ درون `kDebugMode` هستند: `rg -n "kDebugMode" lib/features/settings`.

**معیار پذیرش:** در نسخهٔ رلیز، هیچ دکمهٔ دیباگی در درخت ویجت نیست؛ رسیدن به مسیر هفت لمسی تصادفی نیست.

**تست:** `test/settings/debug_affordance_test.dart` — شامل تست ریست شدن شمارنده پس از وقفه.

**commit:** `fix(settings): SET-68 — امن‌سازی افوردنس‌های دیباگ`

---

### SET-69 — شکستن فایل‌های غول

**مشکل:** چهار فایل فیچر تنطیمات بیش از حد بزرگ شدند و مرور کردنشان عملاً غیرممکن است: صفحهٔ گروه هویت (حدود ۵۸ کیلوبایت)، سربرگ هویت (حدود ۲۴ کیلوبایت)، صفحهٔ اصلی تنطیمات (حدود ۲۳ کیلوبایت) و صفحهٔ گروه اعلان‌ها (حدود ۲۳ کیلوبایت). دقیقاً در همین فایل‌ها بود که باگ‌های تکراری پنهان ماندند.

**فایل‌ها:** `identity_group_screen.dart`، `identity_header.dart`، `settings_screen.dart`، `notifications_group_screen.dart`

**کار دقیق:**
1. پس از SET-38 و SET-45، بخش بزرگی از این فایل‌ها دیگر لازم نیست — اول کد مرده را بردار (قانون ۱۲)، بعد بشکن.
2. هر ویجت خصوصی بالای دویست خط را به فایل جداگانه در `widgets/` منتقل کن. نام فایل را از نام کلاس بساز.
3. هدف عملی: هیچ فایلی در `lib/features/settings/` بیش از ۶۰۰ خط نماند. اگر فایلی با تلاش معقول به این عدد نرسید، در ledger بنویس و برو جلو.
4. **مطلقاً رفتار را عوض نکن.** این تسک فقط جابه‌جایی کد است. اگر حین جابه‌جایی باگ جدیدی دیدی، در ledger بنویس و در همین تسک حلش نکن.
5. پس از هر جابه‌جایی، `flutter analyze` و `flutter test` بزن. اگر حتی یک تست قرمز شد، قبل از ادامه برگردان.

**معیار پذیرش:** تعداد خطوط چهار فایل غول دست‌کم نصف می‌شود؛ هیچ تستی نمی‌شکند؛ طاهر اپ یکسان می‌ماند.

**تست:** تست جدید لازم نیست؛ همهٔ تست‌های موجود باید سبز بمانند.

**commit:** `refactor(settings): SET-69 — شکستن فایل‌های غول`

---

### SET-70 — بازرس تنطیمات فقط در دیباگ

**مشکل:** هیچ راهی برای دیدن وضعیت واقعی تنطیمات وجود ندارد: کدام کلیدها در دیتابیس هستند ولی در رجیستری نیستند (ردیف‌های یتیم)، کدام در رجیستری هستند ولی هرگز نوشته نشدند، مقدار خام در دیتابیس چیست، و نسخهٔ طرحواره چند است. دقیقاً همین کوری باعث شد چهار کلید دروغین پرچم‌ها (C1) مدت‌ها زنده بمانند.

**فایل جدید:** `lib/features/settings/presentation/settings_inspector_screen.dart`

**کار دقیق:**
1. صفحه فقط درون `kDebugMode` قابل دسترس باشد (از مسیر هفت لمسی SET-68).
2. چهار بخش نشان بده:
   - **ردیف‌های یتیم:** کلیدهای موجود در `app_settings` که `SettingsRegistry.find` برایشان `null` برمی‌گرداند (همان مواردی که در SET-20 لاگ می‌شوند).
   - **کلیدهای نوشته‌نشده:** توصیفگرهایی که هیچ ردیفی در دیتابیس ندارند (یعنی روی پیش‌فرضند).
   - **همهٔ مقادیر:** کلید، مقدار خام، مقدار تجزیه‌شده، دامنه، زمان آخرین تغییر. **برای دامنهٔ `secure` فقط وجود یا عدم وجود را نشان بده، نه مقدار — حتی در دیباگ.** قانون ۱۷ استثنا ندارد.
   - **وضعیت سرویس:** `SettingsLoadState`، نسخهٔ طرحواره، تعداد کلیدهای کش‌شده، و شمارندهٔ `revision`.
3. یک دکمهٔ «رونویسی تشخیص» بگذار که خروجی متنی را در کلیپ‌بورد می‌گذارد — با همان قاعدهٔ حذف رازها.
4. دکمهٔ «پاک‌سازی ردیف‌های یتیم» با تأیید دومرحله‌ای و فهرست دقیق چیزی که حذف می‌شود.

**معیار پذیرش:** در نسخهٔ دیباگ، بازرس هر مشکل یکپارگی را در یک نگاه نشان می‌دهد؛ در نسخهٔ رلیز به هیچ روشی قابل دسترس نیست.

**تست:** `test/settings/inspector_no_secrets_test.dart` — ثابت کن مقدار کلیدهای امن در خروجی بازرس و در متن رونوشت نیست.

**commit:** `feat(settings): SET-70 — بازرس تنطیمات در حالت دیباگ`

---

## بخش ۵ — تعریف اتمام کار (Definition of Done)

کار تمام نیست تا وقتی هر ۶ مورد زیر برقرار باشد.

### ۵.۱ — لجر کامل است

در `docs/settings/SETTINGS_FIX_PROGRESS.md` همهٔ ۷۰ ردیف SET-01 تا SET-70 وضعیت `DONE` یا `SKIPPED` یا `BLOCKED` دارند و هیچ `TODO` یا `DOING` باقی نمانده است. هر `SKIPPED` و `BLOCKED` یک دلیل یک‌خطی دارد.

### ۵.۲ — تحلیلگر و تست‌ها سبزند

```bash
flutter analyze
flutter test
```
هر دو باید بدون خطا تمام شوند. هشدار جدید هم قابل قبول نیست.

### ۵.۳ — دستورهای پاکیزگی خروجی خالی می‌دهند

هر دوازده دستور زیر باید **خروجی خالی** بدهد. اگر خروجی داشت، کار تمام نیست.

```bash
# ۱) هیچ لاگ خامی در فیچر تنطیمات نمانده (SET-22، SET-29، SET-67)
rg -n "debugPrint" lib/core/settings lib/features/settings

# ۲) هیچ دسترسی SQL خامی به جدول تنطیمات از بیرون سرویس (SET-33 — ریشهٔ C5)
rg -n "app_settings" lib/ --glob '!lib/core/settings/**'

# ۳) هیچ کلید دروغین پرچم‌ها باقی نمانده (SET-23 — ریشهٔ C1)
rg -n "proactive_assistant_enabled|briefing_enabled|energy_tuning_enabled" lib/

# ۴) هر فراخوانی رجیستری از مسیر نگاشتی می‌گذرد (SET-01، SET-41)
rg -n "SettingsRegistry.all.firstWhere|SettingsRegistry.all.where" lib/

# ۵) هیچ چورون ناهماهنگی نمانده (SET-62)
rg -n "CupertinoIcons.chevron_back" lib/features/settings

# ۶) هیچ حاشیهٔ فیزیکی جهت‌داری نمانده (SET-62)
rg -n "EdgeInsets.only\(right:|EdgeInsets.only\(left:" lib/features/settings

# ۷) هیچ نتیجهٔ نوشتنی نادیده گرفته نشده (SET-14، SET-40 — ریشهٔ H8)
rg -n "await SettingsService.instance.set" lib/features/settings | rg -v "if \(|final ok|final res"

# ۸) هیچ لیست تودرتوی کوتاه‌شده‌ای نمانده (SET-45)
rg -n "shrinkWrap: true" lib/features/settings

# ۹) هیچ مقدار ویژهٔ جادویی بدون نام نمانده (SET-07، SET-28 — ریشهٔ H21)
rg -n "== -1|: -1" lib/features/settings

# ۱۰) هیچ catch خالی‌ای نمانده (قانون ۶، SET-67 — ریشهٔ H27)
rg -n "catch \(_\) \{\}" lib/core/settings lib/features/settings

# ۱۱) مسیر ناوبری یکدست است (SET-47 — ریشهٔ M3)
rg -n "CupertinoPageRoute" lib/features/settings

# ۱۲) هیچ رنگ خامی در فیچر نمانده جز فایل متادادهٔ گروه (SET-63)
rg -n "Color\(0x" lib/features/settings --glob '!**/settings_group_meta.dart'
```

دو دستور زیر برعکس، باید **خروجی داشته باشند** (خروجی خالی یعنی کار انجام نشده):

```bash
# بیومتریک باید واقعاً استفاده شود، نه فقط import شود (SET-27 — ریشهٔ H20)
rg -n "LocalAuthentication" lib/features/settings

# محافط نوشتن هوش مصنوعی باید وجود داشته باشد (SET-24 — ریشهٔ C2)
rg -n "SettingsWriteOrigin" lib/core/settings
```

### ۵.۴ — هفت مورد بحرانی بسته شده‌اند

برای هر مورد، یک تست وجود دارد که قبل از اصلاح قرمز بود:

| مورد | موضوع | تسک | تست ناطر |
| --- | --- | --- | --- |
| C1 | کلیدهای دروغین پرچم‌ها و قاعدهٔ حریم خصوصی | SET-23 | `settings_flags_keys_test.dart` به علاوهٔ `registry_integrity_test.dart` |
| C2 | محافط نوشتن هوش مصنوعی | SET-24 | `ai_write_guard_test.dart` |
| C3 | خواندن تنطیمات امن | SET-11 | `secure_scope_test.dart` |
| C4 | رمز به صورت هش، بدون نوشتن دوگانه | SET-25 | `pin_credential_test.dart` |
| C5 | کش و دیتابیس همیشه هماهنگ | SET-33 | `settings_no_raw_sql_test.dart` |
| C6 | تم با یک منبع حقیقت | SET-31 | `theme_single_source_test.dart` |
| C7 | زبان با یک منبع حقیقت | SET-32 | `locale_single_source_test.dart` |

### ۵.۵ — مرور دستی روی دستگاه

این هشت مسیر را دستی اجرا کن و نتیجه را در لجر بنویس:

1. قفل برنامه را روشن کن و رمز بگذار؛ برنامه را ببند و باز کن؛ قفل باید کار کند و رمز درست تشخیص داده شود.
2. قفل برنامه را بدون رمز و بدون بیومتریک روشن کن — باید غیرممکن باشد.
3. زبان را عوض کن — چیپ راه‌اندازی مجدد باید دیده شود و مقدار باید پس از راه‌اندازی مجدد باقی بماند.
4. تم را از دو مسیر مختلف عوض کن — هر دو مسیر باید همیشه یک مقدار را نشان دهند.
5. یک ماژول را خاموش کن — تنطیمات مربوط باید غیرفعال با توضیح شوند، نه ناپدید.
6. در حالت هواپیما یا با دیتابیس قفل‌شده، باید بنر حالت تخریب‌شده دیده شود و منطقهٔ خطر پنهان باشد.
7. جست‌وجوی «ساعات سکوت» را بزن — باید دقیقاً به همان ردیف برود و هایلایت کند.
8. مقیاس متن سیستم را دو برابر کن و هر نه صفحهٔ گروه را پیمایش کن — هیچ سرریزی نباید باشد.

### ۵.۶ — هیچ رازی جایی نرفته

این چهار مورد را صریحاً تأیید کن:
1. مقدار هیچ کلید امنی در کش حافطه نیست (SET-11).
2. مقدار هیچ کلید امنی در لاگ، ژورنال، خروجی JSON یا بازرس نیست (SET-55، SET-56، SET-67، SET-70).
3. رمز به صورت متن ساده در جدول تنطیمات نیست و ردیف‌های قدیمی مهاجرت و حذف شدند (SET-20، SET-25).
4. بازنشانی کارخانه رازها را هم پاک می‌کند (SET-30).

---

## بخش ۶ — یادآوری نهایی (ضد لغزش)

این بخش را قبل از شروع و دوباره قبل از هر فاز بخوان.

1. **نقشه ننویس.** این فایل خود نقشه است. پاسخ اول تو باید ساختن لجر و شروع SET-01 باشد، نه خلاصه کردن این فایل.
2. **ترتیب را عوض نکن.** فاز A زیرساخت رجیستری است؛ فاز E روی فازهای B تا D ساخته می‌شود؛ فاز G بی فاز E کار نمی‌کند. پریدن به جلو دوباره‌کاری می‌سازد.
3. **یک تسک، یک کامیت.** تسک‌ها را در یک کامیت جمع نکن — برگشت را غیرممکن می‌کند.
4. **بعد از هر تسک، لجر را به‌روز کن.** اگر حافطه‌ات ریست شد، لجر تنها چیزی است که می‌داند کجا بودی.
5. **کد فرق داشت؟ متوقف نشو.** وضعیت را `BLOCKED` یا `SKIPPED` بزن، یک خط دلیل بنویس، برو تسک بعدی. سوال نپرس.
6. **هرگز تست را ضعیف نکن.** اگر تستی قرمز شد، کد را درست کن، نه تست را.
7. **متن خطای خام را به کاربر نشان نده.** همهٔ پیام‌ها فارسی و قابل فهم باشند.
8. **تنطیم را بی‌صدا گم نکن.** هر نوشتن ناموفق باید هم دیده شود و هم رابط کاربری را برگرداند.
9. **راز را نه لاگ کن، نه کش کن، نه خروجی بگیر، نه نمایش بده.** حتی در دیباگ.
10. **کد مرده را حذف کن، کامنت نکن.**
11. **دو پیاده‌سازی موازی نساز.** دقیقاً همین کار C6 (تم)، C7 (زبان) و H22 (ماژول‌ها) را ساخت. هر تنطیم، یک منبع حقیقت.
12. **در پایان هر فاز، `flutter analyze` باید صفر مورد بدهد.** بدهی تحلیلگر را به فاز بعد منتقل نکن.

### خروجی نهایی که از تو می‌خواهم

پس از SET-70، دقیقاً این چهار چیز را تحویل بده:
1. یک جدول نهایی از وضعیت هر ۷۰ تسک.
2. فهرست کامیت‌ها به ترتیب.
3. خروجی همهٔ دستورهای بخش ۵.۳.
4. فهرست موارد `BLOCKED` و `SKIPPED` با دلیل، به علاوهٔ هر باگ جدیدی که دیدی ولی در این فایل نبود.

موفق باشی. از SET-00 شروع کن.
