# RITMO — پرامپت طراحی و پیاده‌سازی مجدد ماژول حرکت

**اجرا کن این پرامپت را فقط بعد از آنکه `RITMO_MOVEMENT_DELETION_PROMPT.md` کاملاً اجرا و `DELETION_REPORT.md` تولید شد.**

**برانچ:** `feat/movement-redesign`
**ابزار:** محلی است — کار روی سیستم، پوش در انتها.

---

## §۰ قوانین اجرا

- **۰-۱** نقشه‌ای برای خودت ننویس. دقیقاً همین پرامپت را خط به خط اجرا کن.
- **۰-۲** این پرامپت روی سیستم محلی اجرا می‌شود. فایل‌ها را مستقیم ویرایش کن. یک بار پوش در انتها. هیچ‌گونه فراخوانی GitHub API در طول اجرا نداری.
- **۰-۳** ترتیب فازها قفل است. فاز N را بدون تأیید سبز بودن `flutter analyze` از فاز N−1 شروع نکن.
- **۰-۴** هر `P-xx` باید در `DESIGN_REPORT.md` وضعیت `DONE` یا `SKIPPED + دلیل` داشته باشد.
- **۰-۵** هیچ متن فارسی هاردکد در ویجت‌ها نیست؛ همه از `MovementStrings` می‌آید.
- **۰-۶** هیچ رنگ یا `fontSize` هاردکد نیست؛ همه از `RitmoTheme` می‌آید.
- **۰-۷** هیچ `catch (_) {}` بی‌لاگ نداری.
- **۰-۸** سقف هر فایل `dart` در این ماژول **۵۰۰ خط** است. اگر بیشتر شد، تقسیم کن.
- **۰-۹** هیچ import از `lib/features/supplementary_sports/` نداری (آن ماژول دیگر وجود ندارد).
- **۰-۱۰** یک کامیت به ازای هر فاز.
- **۰-۱۱** سه دستور بررسی بعد از هر فاز: `flutter pub get` → `flutter analyze` → `flutter test`.
- **۰-۱۲** تنها فایل markdown که می‌توانی بسازی: `DESIGN_REPORT.md` در ریشهٔ repo.

---

## §۰-۲ تصمیم‌های معماری (قفل شده)

1. **سه تیر، نه سه اپ.** تیر ۱ پیش‌فرض است. تیر ۲ بعد از ۶ جلسهٔ ثبت‌شده انلاک می‌شود. تیر ۳ با انتخاب صریح کاربر.
2. **یک سؤال، یک صفحهٔ خانه:** «امروز چی‌کار کنم و چطور بگم انجامش دادم؟»
3. **ثبت ≤ ۵ ثانیه.** یک تپ = جلسه ثبت شد. سه ایموجی اختیاری بعدش.
4. **ماشین آمادگی پشت صحنه کار می‌کند.** کاربر نتیجه را می‌بیند، نه فرمول را.
5. **حریم خصوصی:** اعلان‌های حرکت هیچ‌وقت دربارهٔ چرخه یا وضعیت بدن حرف نمی‌زنند.
6. **حداکثر ۴ اعلان در هفته** از کل ماژول حرکت.
7. **ضد-گناه:** هیچ‌جا رنگ قرمز برای روز ازدست‌رفته نیست. واژه‌هایی مثل «شکست»، «جا ماندی» ممنوع.
8. **داده با حداقل نمونه پنهان می‌شود.** `sampleSize < minimum` → عدد نشان نده، فقط وضعیت نشان بده.
9. **کنترلرها از `sealed class Loading | Ready(data) | Empty(reason) | Error(code)` استفاده می‌کنند.**
10. **شناسه‌ها از `RitmoIdFactory`** می‌آیند.

---

## فاز ۱ — مدل سه تیری و قرارداد داده

### P-01 — فایل قرارداد تیر

فایل `lib/features/movement/domain/models/movement_tier.dart` بساز:

```dart
enum MovementTier { one, two, three }

/// چند جلسهٔ تأییدشده برای انلاک تیر ۲
const int kTierTwoUnlockSessions = 6;

extension MovementTierX on MovementTier {
  bool get isStrengthAvailable => this == MovementTier.three;
  bool get isPlannerAvailable => this != MovementTier.one;
}
```

### P-02 — کلید preference تیر در MovementPreferencesService

کلید `'movement_tier'` را به `MovementPreferencesService` اضافه کن.
- خواندن: `int` از `app_settings`، پیش‌فرض `1`.
- نوشتن: `setTier(MovementTier t)` → `UPDATE app_settings SET value = ... WHERE key = 'movement_tier'`.
- متد `Future<MovementTier> resolveTier()`: اگر tier ذخیره‌شده ۳ یا ۲ بود اعتبارسنجی کن (تعداد جلسات واقعی). اگر کاربر تیر ۳ دارد ولی هنوز ۶ جلسه ندارد، تیر ۲ برگردان (بدون reset کلید).

### P-03 — مدل `MovementWeekStats` (جایگزین `D-15`)

فایل `lib/features/movement/domain/models/movement_week_stats.dart`:
```dart
class MovementWeekStats {
  final int plannedCount;
  final int doneCount;
  final int activeStreakDays; // روزهای متوالی فعالیت (نه هفت‌روزه)
  final int totalMinutes;
  final MovementMetric<double> adherence; // M-67: با sampleSize
  final bool hasAnyData;
}
```

`MovementMetric<T>` را از `M-67` دقیقاً پیاده کن: `{value, sampleSize, reason: ok|noData|partialData|notApplicable}`.

### P-04 — `weekStats` در `MovementOccurrenceService`

متد `Future<MovementWeekStats> weekStats(DateTime anchor)` را پیاده کن (≤ ۴۰ خط). قوانین:
- هفته از شنبه شروع می‌شود (ایران).
- `adherence` فقط اگر `sampleSize ≥ 4` محاسبه و برگردانده می‌شود، وگرنه `reason: noData`.
- هیچ fallback دروغینی مثل `0.85` یا `1.0` نداری.

**دروازهٔ پذیرش فاز ۱**
- [x] `flutter analyze` سبز.
- [x] `flutter test test/movement/movement_week_stats_test.dart` سبز (تست را خودت بساز: حداقل ۵ سناریو شامل هفتهٔ خالی، هفتهٔ کامل، و `sampleSize < 4`).

---

## فاز ۲ — ماشین آمادگی واقعی

### P-05 — اصلاح `MovementReadinessService` (رفع M-44 تا M-47)

مشکلات فعلی:
- `sleep ?? 3, energy ?? 3, soreness ?? 1, stress ?? 1` → وقتی داده نیست، هنوز `tier: full, score: 0` برمی‌گردد.
- شاخهٔ قاعدگی `light/50` برمی‌گرداند به‌جای `minimal/40`.

**قرارداد جدید:**

```dart
sealed class ReadinessResult {}
class ReadinessReady extends ReadinessResult {
  final ReadinessTier tier; // rest | minimal | light | full
  final int score;          // 0-100
  final String suggestionFa; // یک جمله، فارسی
  final bool isEstimated;   // true اگر هر داده‌ای null بود
}
class ReadinessNoData extends ReadinessResult {}
```

نقشهٔ سقف (ceiling) برای ترکیب وضعیت‌ها:
| وضعیت چرخه | سقف تیر | سقف امتیاز |
|---|---|---|
| قاعدگی فعال | minimal | 40 |
| PMS | light | 65 |
| پنجرهٔ باروری | full | 100 |
| بارداری | rest | 20 |
| بقیه | full | 100 |

فرمول نهایی: `min(ceilScore, rawScore)` جایی که `rawScore` از sleep/energy/soreness/stress حساب می‌شود.

اگر هیچ داده‌ای از ۲۴ ساعت گذشته نیست → `ReadinessNoData`.
اگر بعضی داده‌ها null هستند → محاسبه با موجودی‌ها، `isEstimated: true`.

### P-06 — جملهٔ پیشنهاد آمادگی

جملهٔ `suggestionFa` دقیقاً یک الگو دارد:
```
«با توجه به وضعیت امروزت، [X دقیقه / استراحت] بهت میاد.»
```
- هیچ اشاره‌ای به چرخه یا وضعیت بدن در این جمله نیست.
- تیر `rest` → «امروز استراحت کردن هم یه انتخاب خوبه.»
- همیشه زیر جمله دکمهٔ «نه، کاملش رو می‌خوام» وجود دارد که کاربر می‌تواند تیر را override کند. این override ذخیره نمی‌شود و برای جلسهٔ فعلی است.

### P-07 — `ReadinessNoData` در UI

وقتی `ReadinessNoData` برگشت:
- در کارت اصلی: «امروز داده‌ای برای پیشنهاد نداریم. هر مقداری که راحتی تمرین کن."
- رنگ خنثی (نه قرمز، نه سبز).
- دکمهٔ «شروع جلسه» فعال است.

**دروازهٔ پذیرش فاز ۲**
- [x] `flutter analyze` سبز.
- [x] `flutter test test/movement/readiness_service_test.dart` — حداقل: شاخهٔ قاعدگی سقف `minimal/40` را برمی‌گرداند، شاخهٔ بدون داده `ReadinessNoData` برمی‌گرداند.

---

## فاز ۳ — صفحهٔ خانه (سه حالت، یک سؤال)

### P-08 — پاک کردن `movement_center_screen.dart`

**وضعیت فعلی:** ۳۲٬۶۹۶ بایت، سقف ۵۰۰ خط نقض شده، چندین حالت مختلف درهم.

**قرارداد جدید:**
- فایل را به سه فایل تقسیم کن:
  - `movement_center_screen.dart` ≤ ۲۰۰ خط — scaffold و انتخاب حالت.
  - `center/states/movement_has_session_view.dart` ≤ ۲۵۰ خط
  - `center/states/movement_rest_day_view.dart` ≤ ۱۵۰ خط
  - `center/states/movement_no_plan_view.dart` ≤ ۱۵۰ خط

**سه حالت دقیقاً:**

#### حالت A — «جلسه دارم» (`movement_has_session_view`)
نمایش:
1. **کارت اصلی** (`hero_session_card` ← از پاک‌سازی قبلی نجات داده‌شده) با نام فعالیت + پیشنهاد مدت.
2. **یک نوار هفتگی** (`week_rail`) — فقط ۷ دایره، وضعیت هر روز.
3. **یک عدد:** «این هفته: X از Y» — فقط اگر `adherence.sampleSize ≥ 4`.
4. **دکمهٔ بزرگ «شروع»** یا **دکمهٔ «ثبت ۵ ثانیه»** بسته به تیر.
5. **زیر دکمه:** جملهٔ آمادگی از `P-06`.

#### حالت B — «روز استراحت» (`movement_rest_day_view`)
- «امروز استراحت کردن خودش تمرینه.»
- دکمهٔ «همین‌طور ثبتش کن» که occurrence را `restDay` می‌کند.
- دکمهٔ «بازم می‌خوام تمرین کنم» که به picker می‌رود.

#### حالت C — «برنامه‌ای ندارم» (`movement_no_plan_view`)
- برای **تیر ۱:** فقط «یه فعالیت ثبت کن».
- برای **تیر ۲ یا ۳:** «برنامه‌ریزی» + «ثبت آزاد».
- هیچ متن خالی یا صفحهٔ سفید نیست.

### P-09 — پاک کردن `movement_center_controller.dart`

**وضعیت فعلی:** ۱۵٬۷۰۴ بایت.

**قرارداد جدید (≤ ۲۵۰ خط):**

```dart
sealed class MovementCenterState {}
class MovementCenterLoading extends MovementCenterState {}
class MovementCenterReady extends MovementCenterState {
  final MovementCenterView view; // hasSession | restDay | noPlan
  final ReadinessResult readiness;
  final MovementWeekStats weekStats;
  final MovementTier tier;
}
class MovementCenterError extends MovementCenterState {
  final MovementErrorCode code;
}
```

- بارگذاری موازی: `readiness` و `weekStats` همزمان.
- هر بار که `RitmoEventBus` رویداد `movementOccurrenceChanged` یا `movementSessionLogged` فایر کرد → `refresh()`.
- کنترلر هیچ منطق UI ندارد.

### P-10 — `week_rail` ساده

**وضعیت فعلی:** `week_navigator_bar` 7٬297 بایت (پیچیده).

**قرارداد جدید** (`week_rail.dart` — همان فایل ۳٬۹۶۸ بایتی که بعد از حذف ماند):
- ۷ دایره، قابل اسکرول نیست.
- وضعیت هر روز: `done ✓ | planned ○ | rest zzz | today → | empty ·`
- رنگ فقط از `RitmoTheme`.
- tap روی هر روز → Navigation به `movement.occurrence` اگر ورودی دارد، وگرنه هیچ.
- هیچ انیمیشن پیچیده‌ای ندارد.

**دروازهٔ پذیرش فاز ۳**
- [ ] صفحهٔ خانه با سه حالت مختلف در widget test رندر می‌شود.
- [ ] هیچ فایل `dart` در این فاز بیشتر از ۵۰۰ خط نیست.
- [ ] `flutter analyze` سبز.

---

## فاز ۴ — ثبت ۵ ثانیه (تیر ۱)

### P-11 — دکمهٔ «ثبت ۵ ثانیه»

این قابلیت اصلی‌ترین تفاوت Ritmo با رقباست.

**جریان دقیق:**
1. کاربر روی «ثبت ۵ ثانیه» می‌زند.
2. یک `BottomSheet` بدون عنوان باز می‌شود با سه ایموجی:
   ```
   😌 سبک      😊 خوب      💪 سنگین
   ```
3. هر کدام را که زد:
   - `movement_workout_logs` یک ردیف می‌گیرد با `intensityTag = light|moderate|hard`.
   - occurrence وضعیت `completed` می‌گیرد.
   - Sheet بسته می‌شود.
   - `UndoToast` با ۵ ثانیه فرصت.
4. اگر کاربر Sheet را بدون انتخاب بست → **اتفاقی نمی‌افتد** (برخلاف M-90 قدیمی).

**ویجت:** `quick_log_sheet.dart` در `presentation/session/sheets/` (≤ ۸۰ خط).

### P-12 — `UndoToast` (باقی‌مانده از D-18)

از `presentation/common/undo_toast.dart` استفاده کن. هیچ ویجت جدیدی نساز. فقط مطمئن شو که از `RitmoEventBus` استفاده می‌کند تا controller refresh کند.

### P-13 — اولین تجربه (۶۰ ثانیه)

اگر کاربر هیچ جلسه‌ای ندارد و تیر ۱ است:
- صفحهٔ خانه حالت C نشان می‌دهد.
- یک `Callout` زرد بالای صفحه: «اولین تمرینت رو ثبت کن، ۵ ثانیه طول می‌کشه."
- دکمهٔ بزرگ → مستقیم به `quick_log_sheet` با یک `ActivityPicker` قبلش.
- `ActivityPicker` فقط ۸ نوع از `movement_activity_kinds` را نشان می‌دهد.

**دروازهٔ پذیرش فاز ۴**
- [ ] از لحظهٔ tap تا دیدن toast ≤ ۵ ثانیه (widget test با timer mock).
- [ ] اگر sheet بسته شود بدون انتخاب، هیچ ردیفی در DB نیست.
- [ ] `flutter analyze` سبز.

---

## فاز ۵ — برگشت پس از غیبت

### P-14 — تشخیص غیبت

در `MovementOccurrenceService` متد `Future<AbsenceStatus> checkAbsence()` اضافه کن:

```dart
enum AbsenceStatus { none, shortAbsence, longAbsence }
// shortAbsence: 7-20 روز بدون جلسه
// longAbsence: >21 روز بدون جلسه
```

منطق:
- آخرین `movement_workout_logs.startedAt` را بگیر.
- اگر null بود → `none` (هیچ‌وقت تمرین نکرده، `P-13` مسئول است).
- اگر بین ۷ و ۲۰ روز → `shortAbsence`.
- اگر بیشتر از ۲۱ → `longAbsence`.

### P-15 — UI برگشت پس از غیبت

در `movement_no_plan_view.dart` (حالت C):

**کوتاه‌مدت (۷-۲۰ روز):**
```
«یه مدت نبودی. مهم نیست — بریم از یه تمرین سبک شروع کنیم.»
[دکمهٔ «یه تمرین سبک ثبت کن»]
```

**بلندمدت (>۲۱ روز):**
```
«بعد از مدتی برگشتی. خوش اومدی."
[دکمهٔ «یه تمرین کوتاه ثبت کن»]
```

قوانین:
- **هیچ رنگ قرمزی** وجود ندارد.
- **هیچ عددی** از تعداد روز غیبت نشان داده نمی‌شود.
- **هیچ سری** به سابقه زده نمی‌شود. از روز اول دوباره شروع می‌کنیم.
- هر دو دکمه مستقیم به `quick_log_sheet` می‌روند.

**دروازهٔ پذیرش فاز ۵**
- [ ] `flutter test test/movement/absence_detection_test.dart` — سه سناریو: بدون جلسه، ۱۰ روز، ۲۵ روز.
- [ ] در widget test هیچ متنی حاوی واژه‌های «شکست/missed/failed/دیر» نیست.

---

## فاز ۶ — پلنر (تیر ۲ و ۳)

### P-16 — `activity_plan_editor_screen.dart` بازنویسی

**وضعیت فعلی:** ۱۷٬۲۸۴ بایت.

**قرارداد جدید (≤ ۳۰۰ خط):**

سه سؤال، نه بیشتر:
1. «چند روز در هفته می‌خوای فعال باشی؟» — Slider 1 تا 6.
2. «هر جلسه چقدر؟» — Chip: ۱۵ دقیقه / ۳۰ دقیقه / ۴۵ دقیقه / ۱ ساعت.
3. «چه روزهایی؟» — CheckBox هفتهٔ شمسی (ش / ی / د / س / چ / پ / ج).

بعد از تأیید:
- `movement_plan_schedules` و `movement_occurrences` برای ۴ هفتهٔ آینده درج می‌شوند.
- صفحه بسته می‌شود.
- `RitmoEventBus.fire(movementPlanCreated)` فایر می‌شود.

**حذف از این صفحه:**
- هر چیزی مربوط به ورزش قدرتی.
- هر چیزی مربوط به نوع فعالیت.
- هر چیزی بیش از ۳ سؤال.

### P-17 — «قرارداد هفتگی» جایگزین streak

در `MovementWeekStats`، متد نمایشی اضافه کن:
```dart
String weekContractLabel() {
  // «این هفته: 2 از 3»
  // اگر doneCount == plannedCount → «هفته‌ات کامله 🎉»
  // اگر plannedCount == 0 → '' (خالی)
}
```
این جایگزین streak می‌شود. هیچ streak counter نمایش داده نمی‌شود.

**دروازهٔ پذیرش فاز ۶**
- [ ] پلنر با سه سؤال کار می‌کند و occurrences ثبت می‌شوند.
- [ ] `flutter analyze` سبز.

---

## فاز ۷ — بخش قدرتی (تیر ۳)

**پیش‌شرط:** این فاز فقط بعد از اتمام فاز ۶ شروع می‌شود.

### P-18 — ورود به تیر ۳

در `movement_settings_screen.dart`، یک کلید با label «تمرین قدرتی (پیشرفته)».
- پیش‌فرض: خاموش تا کاربر آن را روشن نکند.
- وقتی روشن شد: `MovementPreferencesService.setTier(MovementTier.three)`.
- یک Dialog تأیید: «بخش قدرتی امکانات بیشتری داره — مثل برنامهٔ وزنه و RIR. مطمئنی؟»

### P-19 — جلسهٔ قدرتی (ساده‌شده)

**فایل‌های زنده از حذف قبلی:**
```
presentation/session/modes/strength_session_view.dart  (11,667 B)
presentation/session/widgets/current_exercise_card.dart
presentation/session/widgets/set_row.dart
presentation/session/widgets/set_table.dart
presentation/session/widgets/rest_timer_bar.dart
presentation/session/widgets/intensity_picker.dart
presentation/session/widgets/session_app_bar.dart
presentation/session/widgets/session_primary_cta.dart
presentation/session/widgets/timer_display.dart
```

**وظیفه:** این فایل‌ها را بدون تغییر رفتاری نگه دار. فقط مطمئن شو:
- ستون `rir` از `movement_set_logs` حذف شده (از `D-35`) — کد را اصلاح کن.
- `strength_session_view` هیچ import از `supplementary_sports` ندارد.
- `flutter analyze` روی این فایل‌ها سبز است.

### P-20 — برنامهٔ قدرتی ساده (جایگزین M-48 تا M-52 که لغو شدند)

**نکتهٔ مهم:** `M-48` تا `M-52` (موتور پیچیدهٔ برنامهٔ قدرتی) لغو شدند. جایگزین آن‌ها این است:

- برنامهٔ قدرتی در Ritmo **از پیش تعریف‌شده** است (نه AI-generated).
- سه template ثابت: `beginner_3x_week.json`, `intermediate_4x_week.json`, `advanced_5x_week.json`.
- فایل JSON در `assets/movement/strength_templates/`.
- کاربر یکی را انتخاب می‌کند، template در `movement_plan_templates` ذخیره می‌شود.
- هیچ منطق چرخشی هفته‌به‌هفته وجود ندارد — template ثابت است.

فایل `strength_program_service.dart` (که در `D-12` حذف شد) **جایگزین نمی‌شود**. منطق ساده مستقیم در `MovementPlanningService` قرار می‌گیرد.

**دروازهٔ پذیرش فاز ۷**
- [ ] کلید تیر ۳ کار می‌کند.
- [ ] جلسهٔ قدرتی بدون خطای analyze اجرا می‌شود.
- [ ] هیچ import از کد حذف‌شده ندارد.

---

## فاز ۸ — اعلان‌ها (رفع M-59 تا M-63)

### P-21 — بازسازی `MovementNotificationService`

**وضعیت فعلی:** ۸٬۷۹۰ بایت، کد مرده (`M-59`).

**قرارداد جدید (≤ ۱۵۰ خط):**

چهار نوع اعلان → یک نوع باقی می‌ماند: **یادآوری جلسه در ساعت تعریف‌شده.**

```dart
Future<void> scheduleSessionReminder({
  required DateTime sessionDateTime,
  required String activityNameFa,
}) async { ... }

Future<void> cancelAllMovementNotifications() async { ... }
```

قوانین:
- اعلان هیچ‌وقت درباره چرخه یا وضعیت بدن حرف نمی‌زند.
- متن اعلان: «وقت تمرینته! [activityNameFa]» — نه بیشتر.
- `quiet_mode` (`M-62`) اعمال می‌شود: اگر ساعت فعلی خارج از پنجرهٔ [۸، ۲۲] باشد، اعلان به ۸ صبح روز بعد موکول می‌شود.
- **سقف سخت:** حداکثر ۴ اعلان زنده در `notification_gateway` از کل ماژول حرکت. قبل از schedule جدید، تعداد را بررسی کن.

### P-22 — تست اعلان

فایل `test/movement/movement_notification_test.dart`:
- اعلان با ساعت خارج از [۸,۲۲] → به ۸ صبح موکول می‌شود.
- بیشتر از ۴ schedule → پنجمی نادیده گرفته می‌شود.

**دروازهٔ پذیرش فاز ۸**
- [ ] `flutter test test/movement/movement_notification_test.dart` سبز.
- [ ] `grep -n "morning_reminder\|pre_session_reminder\|smart_suggestions_enabled" lib/` خالی.

---

## فاز ۹ — جوایز و بازخورد چندماژوله

### P-23 — چهار لحظهٔ پاداش

**اول:** وقتی `doneCount == plannedCount` و `plannedCount ≥ 1`:
- `UndoToast`-مانند، ۳ ثانیه: «هفته‌ات کامله 🎉»
- هیچ dialog، هیچ انیمیشن پیچیده نیست.

**دوم:** وقتی ۳ هفتهٔ متوالی `doneCount ≥ 1`:
- «سه هفتهٔ پشت سر هم! 🔥»

**سوم:** اولین جلسهٔ بعد از غیبت:
- «خوش برگشتی 👋»

**چهارم:** رکورد شخصی (وقتی `evaluateAndSaveRecord` در `M-66` ثبت می‌کند):
- یک خط toast: «رکورد جدید! [نوع تمرین]»

همهٔ پیام‌ها از `MovementStrings` می‌آیند. هیچ‌کدام بیشتر از ۳ ثانیه نمایش نمی‌دهند.

### P-24 — رفع `M-66` (رکورد شخصی)

**مشکلات فعلی:**
- `evaluateAndSaveRecord` هرگز فراخوانی نمی‌شود.
- پرس‌وجوی SQL شرط `OR` بدون پرانتز دارد.
- ایندکس یکتا روی `(exerciseId, metricType)` وجود ندارد.

**اصلاح:**
1. `evaluateAndSaveRecord` را بعد از `_logSetToDb` در `MovementSessionService` فراخوانی کن.
2. SQL را اصلاح کن: `WHERE (condition1) OR (condition2)` — پرانتزها اجباری.
3. Migration: `CREATE UNIQUE INDEX IF NOT EXISTS idx_movement_personal_records_unique ON movement_personal_records(exerciseId, metricType)`.

### P-25 — بازخورد چندماژوله (`M-79`)

**مشکل:** `MovementOccurrenceService` به `RitmoEventBus` گوش نمی‌دهد.

**اصلاح:** در `init()` سرویس:
```dart
_eventBus.on<SleepLoggedEvent>().listen((_) => _invalidateTodayReadiness());
_eventBus.on<EnergyCheckinEvent>().listen((_) => _invalidateTodayReadiness());
_eventBus.on<CyclePeriodChangedEvent>().listen((_) => _invalidateTodayReadiness());
```

بعد از invalidate، کنترلر صفحهٔ خانه خودبه‌خود refresh می‌کند (چون `M-79`+`P-09` یکپارچه هستند).

**دروازهٔ پذیرش فاز ۹**
- [ ] toast پاداش در ۴ سناریو نمایش داده می‌شود.
- [ ] رکورد شخصی بعد از ثبت سِت ارزیابی می‌شود.
- [ ] `RitmoEventBus` اشتراک‌ها فعال هستند.

---

## فاز ۱۰ — تنظیمات و مسیرها (نهایی)

### P-26 — ثبت مسیرها (`M-71`)

فایل `presentation/movement_routes.dart` را بررسی کن. باید **دقیقاً ۶ مسیر** ثبت‌شده داشته باشد:
```
movement.center
movement.picker
movement.plan_editor   (تیر 2 و 3)
movement.session
movement.summary
movement.settings
```
هر مسیر دیگری → حذف فیزیکی.

### P-27 — تنظیمات (≤ ۲۰۰ خط، حداکثر ۸ کلید)

بعد از حذف `D-38`، فقط این‌ها باقی می‌مانند:
```
module_sports_enabled         — ماژول را خاموش/روشن کن
movement_tier                 — تیر فعلی
notification_enabled          — اعلان‌ها
notification_hour             — ساعت اعلان (1-22)
movement_plan_active          — آیا برنامه دارم؟
cycle_consent_sports          — مجوز دسترسی آمادگی به داده‌های چرخه
movement_preferred_duration   — مدت ترجیحی (۱۵/۳۰/۴۵/۶۰)
movement_tier_unlock_hidden   — «مخفی کردن دکمهٔ تیر ۳» (پیش‌فرض false)
```

هر کلید دیگری که در `app_settings` با پیشوند `movement_` وجود دارد → `DELETE FROM app_settings WHERE key = '...'`.

### P-28 — دروازهٔ پذیرش نهایی

**ساختار**
- [ ] `lib/features/supplementary_sports/` وجود ندارد.
- [ ] `grep -rn "supplementary_sports" lib/ test/` خالی.
- [ ] هیچ فایل `dart` در ماژول حرکت بیشتر از ۵۰۰ خط نیست.
- [ ] دقیقاً ۶ مسیر ثبت‌شده.
- [ ] حداکثر ۸ کلید در تنظیمات.

**دیتابیس**
- [ ] دقیقاً ۱۲ جدول `movement_*`.
- [ ] هیچ جدول `ss_*`.
- [ ] `idx_movement_personal_records_unique` وجود دارد.

**رفتار**
- [ ] از tap تا ثبت جلسه: ≤ ۲ tap.
- [ ] از نصب تا اولین جلسه: ≤ ۶۰ ثانیه.
- [ ] حداکثر ۳ عدد در صفحهٔ خانه.
- [ ] حداکثر ۴ اعلان در هفته.
- [ ] هیچ رنگ قرمزی برای روز ازدست‌رفته.

**ابزار**
- [ ] `flutter pub get` بدون خطا.
- [ ] `flutter analyze` صفر خطا (تعداد هشدار ≤ baseline).
- [ ] `flutter test` ۱۰۰٪ سبز.
- [ ] `DESIGN_REPORT.md` برای `P-01` تا `P-28` وضعیت دارد.

**پوش:** فقط یک بار، در انتها، روی شاخهٔ `feat/movement-redesign`.

---

## آخرین حرف

اگر به قابلیتی رسیدی که این پرامپت نامش را نبرده ولی برای سبز شدن `flutter analyze` لازم است — حداقل پیاده‌سازی را بنویس و در `DESIGN_REPORT.md` زیر عنوان `UNLISTED` ثبت کن.

هر چیزی که پنج آزمون §۱ پرامپت حذف را رد کند، این‌جا هم ساخته نمی‌شود.
