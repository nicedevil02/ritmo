# پرامپت اجرایی «ورزش تکمیلی ریتمو v2» — مدل لنگر و پرکننده

> **نسخه:** ۱٫۰ • **تاریخ صدور:** 2026-08-25 • **مخزن هدف:** `nicedevil02/ritmo`
> **شاخهٔ کاری اجباری:** `feat/sports-v2-anchor-filler` (از `main`)
> **این فایل «قرارداد اجرا» است، نه پیشنهاد و نه سند طراحی.**

---

## ۰. قرارداد اجرا — این بخش را قبل از هر کاری کامل بخوان

### ۰٫۱ قوانین سخت (نقض هر کدام = توقف کار)

1. **نقشهٔ راه ننویس.** ممنوع است هر نوع plan، roadmap، RFC، ADR جدید، «تحلیل اولیه»، «پیشنهاد معماری»، یا فایل برنامه‌ریزی بسازی. نقشهٔ راه همین فایل است.
2. **ترتیب را عوض نکن.** اجرا دقیقاً به ترتیب `S0-T1 → S0-T2 → … → S6-T10 → S7-T1` است. تسک‌ها را ادغام نکن، جابه‌جا نکن، و نپر.
3. **بعد از هر تسک، این پروتکل چهارمرحله‌ای را اجرا کن:**
   1. دستور تأیید همان تسک (`دستور تأیید:`) را اجرا کن.
   2. اگر سبز بود، فقط تغییرات همان تسک را commit کن با پیام `<type>(sports): <کد تسک> <خلاصه>`.
   3. در **همین فایل** چک‌باکس آن تسک را از `- [ ]` به `- [x]` تغییر بده و در انتهای همان خط `— <hash کوتاه کامیت>` اضافه کن.
   4. یک ردیف به `docs/movement/IMPLEMENTATION_LOG.md` اضافه کن: `| کد تسک | تاریخ | hash | نتیجهٔ تأیید | یادداشت |`.
4. **اگر پذیرش یک تسک دو بار پشت‌سرهم شکست خورد:** کار را متوقف کن، در لاگ ردیف `BLOCKED` با متن کامل خطا بنویس، و **به تسک بعدی نرو**. منتظر تصمیم انسان بمان.
5. **صفر placeholder.** ممنوع: `TODO`، `FIXME`، `throw UnimplementedError`، تابع خالی، دادهٔ mock در مسیر اجرا، عدد ساختگی، و «فعلاً این‌طور بگذاریم».
6. **صفر دادهٔ ساختگی.** هیچ عددی که به کاربر نشان داده می‌شود نباید تخمینی، تقریبی، یا مشتق از فرمول بی‌پشتوانه باشد. اگر داده کافی نیست، حالت «دادهٔ کافی نیست» نشان بده.
7. **حذف کد legacy فقط بعد از پورت.** هیچ فایلی از فهرست §۹ (دفتر انتقال) حذف نمی‌شود تا تسک پورت مربوطه‌اش تیک نخورده باشد.
8. **این فایل را ویرایش نکن** مگر برای: تیک‌زدن چک‌باکس، افزودن hash کامیت، و پر کردن «دفتر پیشرفت» در §۱۲. متن تسک‌ها را تغییر نده و بازنویسی نکن.
9. **تصمیم معماری جدید نگیر.** همهٔ تصمیم‌های باز در §۳ قفل شده‌اند. اگر چیزی در این فایل نیست، جواب را با **خواندن کد مخزن** پیدا کن، نه با اختراع.
10. **هیچ تغییری خارج از دامنهٔ مجاز نده.** دامنهٔ مجاز: `lib/features/supplementary_sports/**`، `lib/core/database/schema/tables/supplementary_sports_tables.dart`، `lib/core/database/database_helper.dart` و مسیر مایگریشن‌ها، `lib/core/navigation/ritmo_router.dart` (فقط اگر تسک گفته)، `test/unit/sports/**`، `docs/movement/**`، فایل‌های l10n. خارج از این‌ها فقط با ذکر صریح تسک.
11. **زبان کاربر فارسی است.** هر رشتهٔ نمایشی از کلید l10n می‌آید (§۱۰). هیچ رشتهٔ فارسی هاردکد در `.dart` نمی‌نویسی (به‌جز فایل‌های seed داده).
12. **هر تسک باید کامپایل و تست بگذرد.** commit شکسته ممنوع.

### ۰٫۲ گیت‌های کیفیت (بعد از هر تسک اجرا می‌شوند)

```bash
flutter analyze
flutter test test/unit/sports/
dart format --set-exit-if-changed lib/features/supplementary_sports test/unit/sports
```

در پایان هر اسپرینت، اضافه:

```bash
flutter test
```

### ۰٫۳ کاری که در شروع باید بکنی (فقط همین، بعد برو سر S0-T1)

- [x] **S-INIT-1** — شاخهٔ `feat/sports-v2-anchor-filler` را از `main` بساز. — c53234b5
- [x] **S-INIT-2** — این فایل‌ها را کامل بخوان و خلاصه نکن، فقط بخوان: `docs/CONSTITUTION.md`، `docs/RITMO_DESIGN_TOKENS.md`، `docs/DESIGN_SYSTEM_ACTION_SHEETS.md`، `docs/movement/P0_AUDIT.md`، `docs/movement/MIGRATION_REPORT.md`، `docs/adr/0008-movement-unification.md`، `docs/l10n_audit.md`. — c53234b5
- [x] **S-INIT-3** — فایل `docs/movement/IMPLEMENTATION_LOG.md` را با هدر جدول ردیف‌های لاگ بساز و commit کن. — c53234b5
- [x] **S-INIT-4** — نسخهٔ فعلی اسکیما را از `lib/core/database/database_helper.dart` بخوان و در دفتر پیشرفت §۱۲ ثبت کن (انتظار: v121 از `MigrationV121SportsUnification`). شمارهٔ مایگریشن‌های این پرامپت باید **پشت‌سرهم** از این عدد جلو برود. — c53234b5

---

## ۱. زمینه — وضعیت فعلی مخزن (این‌ها بررسی‌شده‌اند، دوباره حسابرسی نکن)

بخش ورزش تکمیلی در `lib/features/supplementary_sports/` یک بازطراحی نیمه‌کاره دارد: لایهٔ نمایش (`mv_*`) ساخته شده، ولی لایهٔ دانش وصل نشده. واقعیت‌های قطعی:

| # | واقعیت | محل |
| --- | --- | --- |
| ۱ | `PlanEngine` برای هر روز تمرینی فقط `slotType: MvSlotType.strength` و `kindCode: 'bodyweight'` می‌نویسد و برای بقیه `rest`. هیچ `cardio`/`mobility`/`activeRest` تولید نمی‌کند و هیچ ورودی‌ای از `movement_kinds` نمی‌گیرد. | `domain/engines/plan_engine.dart` |
| ۲ | `BudgetEngine` برای همهٔ ورزش‌ها MET ثابت `5.0` می‌گذارد: `currentMet += minutes * 5.0` و `targetMetMinutes = daysTarget * 30.0 * 5.0`، و اگر `elapsedMinutes == 0` بود `30` فرض می‌کند. | `domain/engines/budget_engine.dart` |
| ۳ | `MvHubController` به بودجه `getRecentSessions(limit: 20)` می‌دهد — نه فیلترشده به هفتهٔ جاری، نه به جلسات کامل‌شده. | `application/mv_hub_controller.dart` |
| ۴ | «هفته‌های فعال پیوسته» ساختگی است: `return (sessions.length / 3).ceil().clamp(1, 52);` | `application/mv_hub_controller.dart` |
| ۵ | `MvSession.toMap()` فیلدهای `overallFeeling` و `note` را نمی‌نویسد و `fromMap` نمی‌خواند → هر بازخورد کاربر خاموش دور ریخته می‌شود. | `domain/models/mv_session.dart` |
| ۶ | `MvSession` هیچ فیلد متریکی ندارد (مسافت، ارتفاع، دور، وزن پشتی، RPE). فقط `targetJson`/`liveJson`. | `domain/models/mv_session.dart` |
| ۷ | جدول `movement_kinds` با **۴۹ نوع فعال در ۷ خانواده** seed می‌شود (شامل `FOOTBALL`, `FUTSAL`, `VOLLEYBALL`, `BASKETBALL`, `SQUASH`, `HIKING`, `ROCK_CLIMBING`, `SWIMMING`, …) با ستون‌های `baseMet`, `metLow`, `metHigh`, `primaryMetric`, `secondaryMetric`, `isOutdoor`, `isSocial`, `needsVenue`, `seasonMask`, `jointImpact`, `aliasesFa`, `usageCount`, `lastUsedAt`, `sessionModeOverride`. **هیچ ریپازیتوری‌ای این جدول را نمی‌خواند.** | `movement/data/seed/movement_kinds_seed.dart` |
| ۸ | کدهای نوع در seed **حروف بزرگ** است، ولی UI جدید رشته‌های **حروف کوچک** هاردکد می‌فرستد (`'walking'`, `'running'`, `'football'`, `'cycling'`, `'bodyweight'`, `'stretching'`, `'cardio'`) → lookup نوع، MET، و `usageCount` همه می‌شکند. | `presentation/sheets/mv_quick_log_sheet.dart`، `presentation/screens/mv_today_tab.dart` |
| ۹ | `mv_day_plan_sheet.dart` هیچ انتخابگر «نوع ورزش» ندارد (فقط عنوان، `MvSlotType`، مدت، شدت، ۶ گروه عضلانی) و `TextStyle(fontSize: 13)` دارد. | `presentation/sheets/mv_day_plan_sheet.dart` |
| ۱۰ | `MvStartSessionUseCase` همیشه حالت `guided` می‌سازد → ۶ حالت دیگر پلیر مرده‌اند. | `application/mv_start_session_use_case.dart` |
| ۱۱ | `MvReadinessUseCase` فقط `ss_daily_checkin` را می‌خواند؛ `sleepHours` و `energyLevel1To5` هرگز از کنترلر پاس داده نمی‌شوند. | `application/mv_readiness_use_case.dart` |
| ۱۲ | `mv_guard_test.dart` فقط ۳ بررسی دارد (وجود ۱۱ موتور، پاک بودن domain از Flutter، عدم import مستقیم data در presentation). | `test/unit/sports/mv_guard_test.dart` |
| ۱۳ | هیچ کلید l10n با پیشوند `mv_` در مخزن وجود ندارد؛ همهٔ رشته‌ها فارسی هاردکد‌اند. | سراسر `mv_*` |
| ۱۴ | جداول `movement_campaigns`، `station_bundles`، `movement_slot_overrides` در اسکیما هستند و **هیچ خواننده‌ای ندارند**. | `lib/core/database/schema/tables/supplementary_sports_tables.dart` |
| ۱۵ | حدود ۷۰۰KB UI قدیمی (`ss_*` و `movement/presentation/*`) از ناوبری قطع شده ولی حذف نشده. | §۹ |
| ۱۶ | دو تاکسونومی موازی: `MvMovementFamily` (کوچک: cardio/strength/mobility/sports/walking/recovery/custom) در کنار `MovementFamily` (بزرگ: ENDURANCE/SPORT/MIND_BODY/OUTDOOR/MARTIAL_SKILL/DAILY/STRENGTH). | `domain/models/mv_enums.dart` و `movement/domain/movement_kind.dart` |
| ۱۷ | مسیرهای `/sports`, `/sport`, `/movement` همه به `MvHubScreen` می‌روند. | `lib/core/navigation/ritmo_router.dart` |
| ۱۸ | `MvSlot` از قبل ستون‌های `kindCode`, `plannedTime`, `routineId`, `occurrenceId`, `sourceRef`, `isLocked`, `movedToDateIso` را دارد. | `domain/models/mv_slot.dart` |

**نتیجه‌گیری قطعی که پایهٔ این پرامپت است:** سیستم فعلی یک فرض ناگفته دارد — «یک روز تمرینی = یک جلسهٔ قدرتی خانگی». هر ورزشی که در این قالب نگنجد (فوتبال، کوه، شنا، رزمی) از برنامه‌ریزی حذف شده. کار این پرامپت **عوض کردن آن فرض** است.

---

## ۲. اصول غیرقابل نقض (Invariants)

- **I-01 صفر از دست رفتن داده.** هر فیلدی که کاربر پر می‌کند باید در دیتابیس نوشته و بازخوانی شود. تست واحد round-trip اجباری است.
- **I-02 صفر دادهٔ ساختگی.** هیچ عدد نمایشی بدون منبع واقعی. کمبود داده = حالت `MvInsufficientData`.
- **I-03 صفر حذف ویژگی.** هر قابلیت legacy یا پورت می‌شود یا صریحاً در دفتر انتقال §۹ با دلیل «حذف عمدی» علامت می‌خورد.
- **I-04 صفر رشتهٔ هاردکد.** همهٔ متن نمایشی از l10n.
- **I-05 صفر استایل خام.** بدون `fontSize`، بدون `Color(0x…)`، بدون `EdgeInsets` عددی خام؛ فقط توکن‌های `docs/RITMO_DESIGN_TOKENS.md`.
- **I-06 لایه‌بندی.** `domain` بدون import فلاتر؛ `presentation` بدون import مستقیم `data`؛ عبور از `application`.
- **I-07 همیشه-خروجی.** هیچ مسیری نباید به «برنامه‌ای وجود ندارد» برسد. آخرین fallback: «۱۰ دقیقه حداقل مؤثر» با دلیل شفاف.
- **I-08 شفافیت تصمیم.** هر اسلات تولیدشده باید `reasonKey` (کلید l10n) + پارامترها داشته باشد تا UI بتواند یک جملهٔ فارسی نشان دهد.
- **I-09 سقف ۶۰۰ خط** برای هر فایل `.dart` جدید یا ویرایش‌شده در دامنهٔ ورزش.
- **I-10 تقویم شمسی.** هیچ محاسبهٔ دستی روز هفته یا ماه؛ فقط `MvCalendar`.

---

## ۳. تصمیم‌های قفل‌شده (بحث تمام است — اجرا کن)

| کد | موضوع | تصمیم قفل‌شده |
| --- | --- | --- |
| **D-A** | مدل «تعهد ورزشی» | جدول اختصاصی جدید **`mv_commitments`** به‌عنوان منبع حقیقت. از `routines` استفاده نمی‌کنیم. پروجکشن به آجندای مرکزی در این نسخه انجام **نمی‌شود** (خارج از دامنه). |
| **D-B** | کد یتیم | راهبرد **Strangler Fig**: پورت → نمایش در UI جدید → سپس حذف فایل legacy. حذف یک‌جا ممنوع. دفتر انتقال §۹ اجباری. |
| **D-C** | دامنهٔ اجتماعی | فقط شخصی. بدون RSVP، بدون گروه، بدون اشتراک‌گذاری. فقط فیلد متنی آزاد `partnerNote` روی تعهد. |
| **D-D** | تاکسونومی | `MovementFamily` (۷ خانوادهٔ حروف‌بزرگ) منبع حقیقت است. `MvMovementFamily` **حذف** می‌شود و همهٔ استفاده‌ها به `MovementFamily` نگاشت می‌شوند. |
| **D-E** | کد نوع ورزش | همیشه **UPPER_SNAKE_CASE** و همیشه از `movement_kinds` می‌آید. هیچ رشتهٔ نوع در UI هاردکد نمی‌شود. |
| **D-F** | GPS و نقشه | خارج از دامنه. مسافت/ارتفاع ورود دستی یا از `mv_routes` ذخیره‌شده. |
| **D-G** | مقیاس تلاش | سه گزینهٔ کاربری («سبک بود / خوب بود / سخت بود») → نگاشت به `3 / 6 / 8` روی مقیاس ۱–۱۰، با امکان اصلاح دستی. مبدأ `effortSource` ثبت می‌شود (`user` یا `estimated`). |
| **D-H** | هدف سلامت | معیار WHO: **۱۵۰ دقیقهٔ حداقل و ۳۰۰ دقیقهٔ مطلوب** «معادل متوسط» در هفته + حداقل **۲ روز قدرتی**. |
| **D-I** | حالت پلیر | از `movement_kinds.primaryMetric` و `sessionModeOverride` مشتق می‌شود، نه از انتخاب کاربر. |
| **D-J** | ابعاد جدید UI | هیچ تب جدیدی در هاب اضافه نمی‌شود. ساختار «۱ هاب / ۳ تب» حفظ می‌شود. |

---

## ۴. واژگان و فرمول‌های قطعی (دقیقاً همین‌ها را پیاده کن)

### ۴٫۱ واژگان

- **روز لنگر (Anchor):** اسلاتی که از یک `MvCommitment` یا رویداد تک‌بار می‌آید، `isLocked = true`، `plannedTime` دارد، و موتور حق حذف/جابه‌جایی‌اش را ندارد.
- **روز پرکننده (Filler):** اسلاتی که `PlanEngine` می‌سازد تا سهمیهٔ سلامت کامل شود و بدن برای لنگرها آماده/بازیابی شود.
- **لنگر پرضربه (Heavy Anchor):** لنگری که `kind.jointImpact >= 2` **یا** `plannedMinutes >= 60` باشد.

### ۴٫۲ فرمول «دقیقهٔ سلامت» (معادل متوسط WHO)

```
moderateEquivalentMinutes(session):
  met = kind.baseMet
  if met < 3.0  -> 0                     // سبک، شمرده نمی‌شود
  if met < 6.0  -> minutes               // متوسط
  else          -> minutes * 2           // شدید، دو برابر
```

- `weeklyModerateEquivalent` = مجموع بر روی جلسات **کامل‌شدهٔ هفتهٔ شمسی جاری** (شنبه تا جمعه، با `MvCalendar`).
- هدف: `150` حداقل، `300` مطلوب.
- «دقیقهٔ MET خام» (`minutes * baseMet`) فقط برای نمایش ثانویه محاسبه می‌شود و جای معادل متوسط را نمی‌گیرد.
- `strengthDays` = تعداد روزهای متمایز هفته با حداقل یک جلسهٔ کامل‌شده از خانوادهٔ `STRENGTH`. هدف `>= 2`.

### ۴٫۳ فرمول «بار جلسه» (sRPE)

```
sessionLoad = rpe1To10 * elapsedMinutes
acuteLoad   = مجموع sessionLoad در ۷ روز گذشته
chronicLoad = (مجموع sessionLoad در ۲۸ روز گذشته) / 4
loadRatio   = acuteLoad / chronicLoad        // فقط اگر chronicLoad > 0
```

**بازه‌های نمایش (فقط با زبان احتمالی، هرگز به‌عنوان تشخیص):**

| بازه | کلید نمایش |
| --- | --- |
| `< 0.8` | `mv_load_band_low` |
| `0.8 – 1.3` | `mv_load_band_optimal` |
| `1.3 – 1.5` | `mv_load_band_watch` |
| `> 1.5` | `mv_load_band_spike` |

**گارد اجباری:** اگر تاریخچه کمتر از **۱۴ روز** یا کمتر از **۶ جلسهٔ کامل‌شده** باشد، هیچ نسبتی نشان داده نمی‌شود؛ `MvInsufficientData` برمی‌گردد.

### ۴٫۴ سقف رشد

```
plannedWeeklyLoadCap:
  if chronicLoad موجود -> 1.10 * (chronicLoad * 7 / 7)   // یعنی ۱۱۰٪ میانگین هفتگی مزمن
  else                 -> معادل متوسط برنامه‌ریزی‌شده حداکثر 150 دقیقه
```

### ۴٫۵ قواعد مجاورت (Adjacency) — ترتیب اعمال دقیقاً همین است

| کد | قاعده |
| --- | --- |
| **ADJ-1** | روز خود لنگر: هیچ اسلات دیگری اضافه نمی‌شود مگر گرم‌کردن/سرد‌کردن پیوست همان لنگر. |
| **ADJ-2** | روز قبل از هر لنگر: حداکثر شدت `MvIntensityTier.light` و نوع اسلات فقط `mobility` یا `activeRest`. طول حداکثر ۲۰ دقیقه. |
| **ADJ-3** | روز بعد از **لنگر پرضربه**: فقط `activeRest` یا `mobility`، حداکثر ۲۵ دقیقه. |
| **ADJ-4** | حداقل ۴۸ ساعت بین دو جلسهٔ `hard` با تمرکز عضلانی مشترک. |
| **ADJ-5** | اگر تعداد لنگرهای هفته `>= 3` بود، حداقل یک روز `rest` کامل تضمین شود. |
| **ADJ-6** | دو لنگر پرضربهٔ پشت‌سرهم → هشدار تعارض (`mv_conflict_back_to_back`) در تب هفته، و روز بعد از دومی اجباراً `activeRest`. |
| **ADJ-7** | قدرتی سنگین هرگز روی روز لنگر یا روز قبل از لنگر نمی‌نشیند. |

### ۴٫۶ ترتیب شش‌مرحله‌ای `PlanEngine v2`

```
1. ANCHORS   : تعهدهای فعال + رویدادهای تک‌بار → اسلات قفل‌شده با kindCode و plannedTime
2. HARD_LIMITS: بازه‌های BLOCKED/SILENT تقویم، اوقات نماز، محدودیت جسمی، حالت آپارتمان
3. ADJACENCY : اعمال ADJ-1..ADJ-7 و علامت‌گذاری روزهای قفل‌شدهٔ نرم
4. FILL      : پرکردن تا هدف §۴٫۲ با رعایت سقف §۴٫۴
5. COMPLEMENT: انتخاب تمرکز قدرتی پشتیبان از mv_kind_profile برای هر لنگر
6. FALLBACK  : اگر خروجی خالی شد، شل‌کردن محدودیت‌ها به ترتیب معکوس و در نهایت «۱۰ دقیقه حداقل مؤثر»
```

هر مرحله باید `MvDecision` با `reasonKey` تولید کند و در `ss_decision_log` ثبت شود.

---

## ۵. اسپرینت S0 — تثبیت پایه (قبل از این کار، هر ویژگی جدیدی روی شن ساخته می‌شود)

**هدف اسپرینت:** هر عددی که امروز در اپ دیده می‌شود واقعی شود و هر داده‌ای که کاربر وارد می‌کند ذخیره شود.

### - [x] S0-T1 — ذخیرهٔ واقعی بازخورد جلسه — b3021b27

**فایل‌ها:** `lib/features/supplementary_sports/domain/models/mv_session.dart`، `lib/core/database/schema/tables/supplementary_sports_tables.dart`

**کار:**
1. جدول `movement_sessions` را باز کن. اگر ستون‌های `overallFeeling` (INTEGER) و `note` (TEXT) وجود ندارند، مایگریشن بعدی (مطابق §۰٫۳ S-INIT-4) را با نام `MigrationV<N>SessionFeedbackFields` بساز و همین دو ستون را `ALTER TABLE ADD COLUMN` کن.
2. در `MvSession.toMap()` این دو کلید را بنویس: `'overallFeeling': overallFeeling`، `'note': note`.
3. در `MvSession.fromMap()` هر دو را بخوان (نوع ایمن، `int?` و `String?`).
4. مقدار `kindCode` در `fromMap` را با پیش‌فرض `'BODYWEIGHT'` برگردان (حروف بزرگ — در S0-T2 تکمیل می‌شود).

**پذیرش:** تست جدید `test/unit/sports/mv_session_roundtrip_test.dart`: یک `MvSession` با `overallFeeling: 4` و `note: 'زانو کمی درد گرفت'` بساز، `toMap` کن، `fromMap` کن، و برابری هر ۲ فیلد را assert کن. همچنین تست کن که هیچ فیلدی از کلاس در `toMap` جا نمانده باشد (فهرست کلیدها را صریحاً بنویس).

**دستور تأیید:** `flutter test test/unit/sports/mv_session_roundtrip_test.dart && flutter analyze`

---

### - [x] S0-T2 — یکسان‌سازی `kindCode` به UPPER_SNAKE_CASE — e5de0795

**فایل‌ها:** `presentation/sheets/mv_quick_log_sheet.dart`، `presentation/screens/mv_today_tab.dart`، `domain/engines/plan_engine.dart`، `domain/models/mv_session.dart`، هر فایل دیگری که grep پیدا کرد.

**کار:**
1. اجرا کن: `rg -n "'walking'|'running'|'cycling'|'football'|'stretching'|'cardio'|'bodyweight'" lib/features/supplementary_sports`
2. هر کدام را به معادل UPPER موجود در `movement/data/seed/movement_kinds_seed.dart` تغییر بده: `WALKING`, `RUNNING`, `CYCLING`, `FOOTBALL`, `STRETCHING`, `BODYWEIGHT`. کد `'cardio'` یک نوع نیست — جایگزینش `RUNNING` برای ثبت سریع هوازی.
3. اگر کدی در seed نبود، **آن را نساز** — متوقف شو و BLOCKED ثبت کن.
4. یک متد داخلی برای نرمال‌سازی دادهٔ قدیمی در همان مایگریشن S0-T1 اضافه کن: `UPDATE movement_sessions SET kindCode = UPPER(kindCode)`. همین کار را برای `movement_slots` یا هر جدولی که `kindCode` دارد تکرار کن.

**پذیرش:** `rg` بالا صفر نتیجه بدهد. تست جدید `mv_kind_code_test.dart`: هر رشتهٔ لیترالی که به پارامتری با نام `kindCode` داده می‌شود، با `RegExp(r'^[A-Z][A-Z0-9_]*$')` مطابقت داشته باشد.

**دستور تأیید:** `flutter test test/unit/sports/ && flutter analyze`

---

### - [x] S0-T3 — حذف «هفته‌های پیوستهٔ ساختگی» — 141df7a2

**فایل:** `application/mv_hub_controller.dart`

**کار:**
1. خط `return (sessions.length / 3).ceil().clamp(1, 52);` را کامل حذف کن.
2. محاسبهٔ واقعی: هفته‌های شمسی را از هفتهٔ جاری به عقب پیمایش کن. هفته «فعال» است اگر حداقل **۲ جلسهٔ کامل‌شده** داشته باشد. شمارش به محض رسیدن به یک هفتهٔ غیرفعال متوقف می‌شود.
3. منبع داده: `MvSessionRepository` — یک متد جدید `Future<List<MvSession>> getCompletedSessionsBetween(DateTime fromIso, DateTime toIso)` اضافه کن.
4. اگر هیچ جلسهٔ کامل‌شده‌ای وجود نداشت، مقدار `null` برگردان و UI باید حالت `MvInsufficientData` با کلید `mv_streak_insufficient` نشان دهد — عدد نشان نده.

**پذیرش:** تست جدولی `mv_streak_test.dart` با ۴ سناریو: بدون جلسه (→ null)؛ ۳ هفتهٔ پیوسته با ۲+ جلسه (→ 3)؛ وقفه در هفتهٔ دوم (→ 1)؛ ۱ جلسه در هفته (→ 0).

**دستور تأیید:** `flutter test test/unit/sports/mv_streak_test.dart`

---

### - [x] S0-T4 — `BudgetEngine` با MET واقعی و معیار WHO — 1715480d

**فایل:** `domain/engines/budget_engine.dart`

**کار:**
1. امضا را طوری تغییر بده که یک `Map<String, MvMovementKind> kindsByCode` بگیرد.
2. منطق `currentMet += minutes * 5.0` را حذف کن و فرمول §۴٫۲ را پیاده کن. خروجی باید شامل باشد: `moderateEquivalentMinutes`, `rawMetMinutes`, `strengthDays`, `targetMin = 150`, `targetOptimal = 300`, `strengthDaysTarget = 2`.
3. `targetMetMinutes = daysTarget * 30.0 * 5.0` را حذف کن.
4. فرض `minutes = 30` وقتی `elapsedMinutes == 0` را **حذف** کن. جلسهٔ با مدت صفر در بودجه شمرده نمی‌شود.
5. پیش‌بینی پایان هفته فقط وقتی حداقل ۳ روز از هفته گذشته باشد؛ وگرنه `null`.

**پذیرش:** `mv_budget_engine_test.dart` با این جدول دقیق:

| ورودی | خروجی مورد انتطار |
| --- | --- |
| `WALKING` (MET 3.5) ۶۰ دقیقه | `moderateEquivalentMinutes == 60` |
| `FOOTBALL` (MET 7) ۹۰ دقیقه | `== 180` |
| `STRETCHING` (MET 2.3) ۳۰ دقیقه | `== 0` |
| `HIKING` (MET 6) ۲۴۰ دقیقه | `== 480` |
| جلسهٔ ناتمام (`completed == false`) | شمرده نشود |

**دستور تأیید:** `flutter test test/unit/sports/mv_budget_engine_test.dart`

---

### - [x] S0-T5 — ورودی هفته‌محدود برای بودجه — 57fc6a03

**فایل‌ها:** `application/mv_hub_controller.dart`، `data/repositories/mv_session_repository.dart`

**کار:** فراخوانی `getRecentSessions(limit: 20)` در مسیر بودجه را با `getCompletedSessionsBetween(weekStart, weekEnd)` عوض کن (حدود هفته از `MvCalendar`). جلسات ناتمام را فیلتر کن.

**پذیرش:** تست: ۲۵ جلسهٔ پراکنده در ۳ هفته بساز؛ بودجه باید فقط جلسات هفتهٔ جاری را بشمارد. گاردتست: `rg -n "getRecentSessions" lib/features/supplementary_sports` نباید در مسیر بودجه نتیجه بدهد.

**دستور تأیید:** `flutter test test/unit/sports/ && flutter analyze`

---

### - [x] S0-T6 — ورودی‌های کامل آمادگی — 7cd729e7

**فایل‌ها:** `application/mv_readiness_use_case.dart`، `application/mv_hub_controller.dart`

**کار:** `sleepHours` و `energyLevel1To5` را از کنترلر به use case پاس بده. اگر چک‌این امروز وجود ندارد، خروجی باید `MvReadinessTier.full` با `reasonKey: 'mv_readiness_no_checkin'` باشد — نه حدس وضعیت.

**پذیرش:** تست: ۳ حالت (بدون چک‌این / خواب ۴ ساعت → tier پایین‌تر / انرژی ۱ → `rest`).

**دستور تأیید:** `flutter test test/unit/sports/`

---

### - [x] S0-T7 — حالت «دادهٔ کافی نیست» واقعاً متصل شود — a8fccd93

**فایل‌ها:** `presentation/components/mv_insufficient_data.dart`، `presentation/screens/mv_progress_tab.dart`، `presentation/screens/mv_today_tab.dart`

**کار:** هر جایی که عددی نمایش داده می‌شود ولی منبعش می‌تواند خالی باشد، باید `MvInsufficientData` رندر کند با پیام «چه چیزی لازم است» (مثلاً `mv_need_n_more_sessions`). صفر نمایش ندادن عدد جعلی.

**پذیرش:** widget test: با ریپازیتوری خالی، تب پیشرفت هیچ عددی نشان ندهد و `MvInsufficientData` پیدا شود.

**دستور تأیید:** `flutter test test/unit/sports/`

---

### - [x] S0-T8 — مهار رگرسیون S0 — 2b35fa8e

**کار:** تست‌های S0-T1..T7 را جمع کن و مطمئن شو کل سویت سبز است. در `docs/movement/IMPLEMENTATION_LOG.md` بخش `## S0 — نتیجه` با عدد تست‌های سبز بنویس.

**دستور تأیید:** `flutter test && flutter analyze`

---

## ۶. اسپرینت S1 — «نوع ورزش» شهروند درجه‌یک می‌شود

**هدف اسپرینت:** کاربر بتواند هر کدام از ۴۹ نوع ورزش (فوتبال، کوه، والیبال، شنا، رزمی، …) را در هر جایی که ورزش انتخاب می‌شود برگزیند.

### - [x] S1-T1 — مدل کامل `MvMovementKind` — aa56104b

**فایل:** `domain/models/mv_movement_kind.dart`

**کار:** اگر الان typedef یا مدل ناقص است، به کلاس کامل immutable تبدیل کن با دقیقاً همین فیلدها (نام‌ها عیناً از ستون‌های `movement_kinds`):

```dart
class MvMovementKind {
  final String code;               // UPPER_SNAKE_CASE
  final String titleFa;
  final String emoji;
  final MovementFamily family;
  final double baseMet;
  final double metLow;
  final double metHigh;
  final MovementMetric primaryMetric;
  final MovementMetric? secondaryMetric;
  final bool isOutdoor;
  final bool isSocial;
  final bool needsVenue;
  final String? seasonMask;        // "1,2,3,7,8,9"
  final int jointImpact;           // 0..3
  final String? aliasesFa;         // جداشده با کاما
  final bool isCustom;
  final bool isEnabled;
  final int usageCount;
  final DateTime? lastUsedAt;
  final int sortOrder;
  final MvSessionMode? sessionModeOverride;
}
```

به همراه `fromMap` / `toMap` / `copyWith` و یک getter محاسباتی `List<String> get aliasList`.

**پذیرش:** تست round-trip روی ۳ ردیف واقعی از seed (`FOOTBALL`, `HIKING`, `STRETCHING`).

**دستور تأیید:** `flutter test test/unit/sports/`

---

### - [x] S1-T2 — `MvKindRepository` (کلید اصلی باز شدن ۴۹ نوع ورزش) — 97aa213b

**فایل جدید:** `data/repositories/mv_kind_repository.dart`

**کار:** دقیقاً این امضاها را پیاده کن (نه کمتر، نه بیشتر):

```dart
class MvKindRepository {
  Future<List<MvMovementKind>> getAll({bool onlyEnabled = true});
  Future<MvMovementKind?> getByCode(String code);
  Future<Map<String, MvMovementKind>> getMapByCodes(List<String> codes);
  Future<List<MvMovementKind>> getByFamily(MovementFamily family);
  Future<List<MvMovementKind>> searchFa(String query);   // titleFa + aliasesFa
  Future<List<MvMovementKind>> getRecent({int limit = 6}); // usageCount DESC, lastUsedAt DESC
  Future<List<MvMovementKind>> getSeasonal(int jalaliMonth); // seasonMask ماه را دارد
  Future<void> bumpUsage(String code);                    // usageCount+1, lastUsedAt=now
  Future<MvMovementKind> saveCustomKind(MvMovementKind kind); // isCustom=true
}
```

قواعد:
- `searchFa` باید هم `titleFa` و هم هر عنصر `aliasesFa` را با `LIKE '%q%'` پوشش دهد، پس از نرمال‌سازی کاراکترهای عربی/فارسی (`ي→ی`، `ك→ک`، حذف اعراب و نیم‌فاصله).
- هیچ کوئری راهی به UI ندارد — فقط از `application`.
- اگر جدول `movement_kinds` خالی بود، seed موجود (`movement/data/seed/movement_kinds_seed.dart`) را فراخوانی کن — seed جدید ننویس.

**پذیرش:** `mv_kind_repository_test.dart` با DB در‌حافطه: `getAll()` حداقل **۴۹** رکورد بدهد؛ `searchFa('کوه')` باید `HIKING` بدهد؛ `searchFa('فوتسال')` → `FUTSAL`؛ `bumpUsage('HIKING')` دو بار باید `usageCount == 2` بدهد.

**دستور تأیید:** `flutter test test/unit/sports/mv_kind_repository_test.dart`

---

### - [x] S1-T3 — حذف تاکسونومی دوگانه — 5e0c48ca

**فایل‌ها:** `domain/models/mv_enums.dart` و هر فایلی که `MvMovementFamily` دارد.

**کار:** طبق D-D، enum `MvMovementFamily` را حذف کن و همهٔ موارد مصرف را به `MovementFamily` ببر. نگاشت قطعی برای دادهٔ موجود: `cardio→ENDURANCE`، `strength→STRENGTH`، `mobility→MIND_BODY`، `sports→SPORT`، `walking→DAILY`، `recovery→MIND_BODY`، `custom→DAILY`.

**پذیرش:** `rg -n "MvMovementFamily" lib/` → صفر نتیجه. گاردتست دایمی برای این در S6-T3.

**دستور تأیید:** `flutter analyze && flutter test`

---

### - [x] S1-T4 — `MvSlotType.sport` و اجباری شدن `kindCode` — 347ced07

**فایل‌ها:** `domain/models/mv_enums.dart`، `domain/models/mv_slot.dart`

**کار:**
1. به `MvSlotType` دو مقدار اضافه کن: `sport` و `outdoor`. ترتیب موجود را برهم نزن (اضافه کن به انتها) چون مقدار index در DB ذخیره می‌شود — اگر ذخیره با name است، در کامنت کد ذکر کن.
2. در `MvSlot`، وقتی `slotType` برابر `sport`/`outdoor`/`cardio` است، `kindCode` نمی‌تواند null باشد. یک `assert` در سازنده و یک تست اضافه کن.

**پذیرش:** تست: ساخت `MvSlot(slotType: MvSlotType.sport, kindCode: null)` باید بیندازد.

**دستور تأیید:** `flutter test test/unit/sports/`

---

### - [x] S1-T5 — شیت انتخاب نوع ورزش — f3120fbd

**فایل جدید:** `presentation/sheets/mv_kind_picker_sheet.dart`

**کار:** یک شیت با `MvSheetScaffold` موجود. دقیقاً این چینش از بالا به پایین:

1. عنوان: `mv_kind_picker_title`
2. فیلد جستجو با placeholder `mv_kind_picker_search_hint` و debounce ۲۵۰ms
3. ردیف «اخیر»: حداکثر ۶ `MvChip` از `getRecent()` — اگر خالی بود، کل ردیف مخفی شود
4. ردیف «مناسب این فصل»: از `getSeasonal(currentJalaliMonth)`، حداکثر ۶
5. ۷ بخش تاشو بر اساس `MovementFamily` با ترتیب ثابت: `SPORT`, `OUTDOOR`, `ENDURANCE`, `STRENGTH`, `MARTIAL_SKILL`, `MIND_BODY`, `DAILY`
6. هر ردیف نوع: `emoji + titleFa + برچسب متریک اولیه + نشانهٔ فضای باز/نیاز به مکان`
7. پایین‌ترین مورد: دکمهٔ `mv_kind_picker_create_custom`

خروجی شیت: `Future<String?>` که `code` برمی‌گرداند. شیت خودش `bumpUsage` را صدا **نمی‌زند** — مصرف‌کننده بعد از ثبت نهایی می‌زند.

**ممنوع:** `fontSize`، رنگ خام، رشتهٔ فارسی هاردکد، فایل بالای ۶۰۰ خط.

**پذیرش:** widget test: تایپ `کوه` باید `کوه‌نوردی` را نشان دهد؛ تپ بر روی آن باید `'HIKING'` برگرداند.

**دستور تأیید:** `flutter test test/unit/sports/`

---

### - [x] S1-T6 — اتصال شیت به ثبت سریع — 36558b58

**فایل‌ها:** `presentation/sheets/mv_quick_log_sheet.dart`، `application/mv_quick_log_use_case.dart`

**کار:**
1. چیپ‌های هاردکد را حذف کن و با ۴ چیپ از `getRecent(limit: 4)` به‌علاوهٔ دکمهٔ «همهٔ ورزش‌ها» (بازکنندهٔ `mv_kind_picker_sheet`) عوض کن.
2. برای کاربر بدون تاریخچه، چیپ‌های پیش‌فرض = ۴ نوع اول بر اساس `sortOrder`.
3. پس از ثبت موفق، `bumpUsage(code)` صدا شود.
4. مدت پیشنهادی پیش‌فرض = میانهٔ `elapsedMinutes` در ۵ جلسهٔ قبلی همان نوع؛ اگر نبود، میدان خالی (عدد فرضی نگذار).

**پذیرش:** `rg -n "kindCode: '" presentation/sheets/mv_quick_log_sheet.dart` → صفر لیترال. تست: ثبت سریع `VOLLEYBALL` باید یک `MvSession` با همان کد و MET واقعی بسازد.

**دستور تأیید:** `flutter test test/unit/sports/ && flutter analyze`

---

### - [x] S1-T7 — اتصال شیت به برنامهٔ روز — a57aab8d

**فایل:** `presentation/sheets/mv_day_plan_sheet.dart`

**کار:** چینش جدید شیت دقیقاً این ترتیب باشد:

| ترتیب | میدان | قاعده |
| --- | --- | --- |
| ۱ | **نوع ورزش** (اجباری) | بازکنندهٔ `mv_kind_picker_sheet` |
| ۲ | مدت (دقیقه) | پیش‌فرض از میانهٔ تاریخچهٔ همان نوع؛ وگرنه خالی |
| ۳ | ساعت شروع (`plannedTime`) | اختیاری؛ اگر پر شود و تکرار فعال باشد → تعهد می‌سازد (S2) |
| ۴ | مکان (`venueNote`) | فقط اگر `kind.needsVenue == true` نمایش داده شود |
| ۵ | شدت | سه گزینهٔ `MvIntensityTier` |
| ۶ | تمرکز عضلانی | فقط اگر `family == STRENGTH` |
| ۷ | «هر هفته تکرار شود» | سویچ؛ منطق در S2-T4 وصل می‌شود. در این تسک فقط UI + ذخیرهٔ مقدار در مدل فرم |

همچنین `TextStyle(fontSize: 13)` را حذف کن و از توکن تایپوگرافی پروژه استفاده کن.

**پذیرش:** widget test: باز کردن شیت و انتخاب `FUTSAL` باید میدان «مکان» را نشان دهد و میدان «تمرکز عضلانی» را مخفی کند. `rg -n "fontSize" presentation/sheets/mv_day_plan_sheet.dart` → صفر.

**دستور تأیید:** `flutter test test/unit/sports/ && flutter analyze`

---

### - [x] S1-T8 — تب «انواع ورزش» در کتابخانه + ورزش سفارشی — cd539920

**فایل‌ها:** `presentation/screens/mv_library_screen.dart`، فایل جدید `presentation/sheets/mv_custom_kind_sheet.dart`

**کار:**
1. کتابخانه دو تب درونی می‌گیرد: «حرکات» (موجود، `ss_exercise`) و «انواع ورزش» (جدید، `movement_kinds`). بدون افزودن تب به هاب (D-J).
2. هر ردیف نوع ورزش قابل لمس است و یک جزئیات ساده نشان می‌دهد: MET، متریک اولیه، فصل مناسب، ضربهٔ مفاصل، تعداد دفعات انجام‌شده، دکمهٔ «افزودن به برنامهٔ روز».
3. شیت ورزش سفارشی: میدان‌های `titleFa` (اجباری)، ایموجی، خانواده (اجباری)، شدت درک‌شده به سه سطح که به `baseMet` نگاشت می‌شود (`3.0 / 5.0 / 7.0`)، متریک اولیه، فضای باز؟، نیاز به مکان؟. ذخیره با `saveCustomKind` و `code` تولیدشده به فرم `CUSTOM_<SLUG>_<epochSeconds>`.
4. **پورت از legacy:** منطق و میدان‌های `movement/presentation/movement_custom_kind_sheet.dart` (15.8KB) مرجع تو است. در دفتر انتقال §۹ ردیفش را `PORTED` کن.

**پذیرش:** تست: ورزش سفارشی «پینگ‌پونگ دونفره» بساز؛ باید بلافاصله در `mv_kind_picker_sheet` قابل جستجو باشد.

**دستور تأیید:** `flutter test test/unit/sports/ && flutter analyze`

---

### - [x] S1-T9 — گاردتست اعتبار `kindCode` — 975f32dc

**فایل:** `test/unit/sports/mv_guard_test.dart`

**کار:** دو گارد جدید:
1. هر رشتهٔ لیترالی که در `lib/features/supplementary_sports/**` به آرگومان `kindCode` داده می‌شود باید در فهرست کدهای seed موجود باشد.
2. هیچ فایل `presentation/**` نباید رشتهٔ کد نوع ورزش داشته باشد (الگو: `RegExp(r"'[A-Z][A-Z0-9_]{2,}'")` با فهرست سفید محدود).

**دستور تأیید:** `flutter test test/unit/sports/mv_guard_test.dart`

---

## ۷. اسپرینت S2 — لنگرها (تعهدهای ورزشی ثابت)

**هدف اسپرینت:** کاربری که پنجشنبه‌ها ساعت ۲۱ فوتسال دارد، این را **یک بار** به اپ بگوید و اپ تا ابد حولش برنامه بچیند.

### - [x] S2-T1 — مایگریشن جدول `mv_commitments` — 3a053ac2

**فایل‌ها:** `lib/core/database/schema/tables/supplementary_sports_tables.dart`، مایگریشن جدید `MigrationV<N>MvCommitments`

**DDL دقیق (عیناً همین، ستون اضافه/کم نکن):**

```sql
CREATE TABLE IF NOT EXISTS mv_commitments (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  kindCode          TEXT    NOT NULL,
  titleFa           TEXT,
  dayOfWeekSat0     INTEGER NOT NULL,      -- 0=شنبه .. 6=جمعه
  startTime         TEXT    NOT NULL,      -- "HH:mm"
  durationMinutes   INTEGER NOT NULL,
  venueNote         TEXT,
  partnerNote       TEXT,
  recurrence        TEXT    NOT NULL DEFAULT 'WEEKLY',  -- WEEKLY | BIWEEKLY | ONCE
  isActive          INTEGER NOT NULL DEFAULT 1,
  isFlexible        INTEGER NOT NULL DEFAULT 0,         -- 1 = موتور اجازه دارد جابه‌جا کند
  startDateIso      TEXT,
  endDateIso        TEXT,
  reminderMinutes   INTEGER,
  createdAt         TEXT    NOT NULL,
  updatedAt         TEXT    NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_mv_commitments_day ON mv_commitments(dayOfWeekSat0, isActive);
```

**پذیرش:** مایگریشن روی DB خالی و DB نسخهٔ قبل هر دو بدون خطا بالا بیاید. تست: اجرای دو بارهٔ مایگریشن idempotent باشد.

**دستور تأیید:** `flutter test test/unit/sports/`

---

### - [x] S2-T2 — مدل `MvCommitment` — bf5a3ee2

**فایل جدید:** `domain/models/mv_commitment.dart`

**کار:** کلاس immutable با دقیقاً فیلدهای ستون‌های بالا + `fromMap`/`toMap`/`copyWith`. دو getter محاسباتی:

```dart
bool occursOnWeek(int jalaliWeekIndex);   // BIWEEKLY را مدیریت می‌کند
DateTime? nextOccurrenceAfter(DateTime now, MvCalendar calendar);
```

**پذیرش:** تست: تعهد `WEEKLY` پنجشنبه ۲۱:۰۰ → `nextOccurrenceAfter` از چهارشنبه باید پنجشنبه بدهد؛ از جمعه باید پنجشنبهٔ هفتهٔ بعد. تعهد `BIWEEKLY` در هفتهٔ فرد نباید رخ دهد.

**دستور تأیید:** `flutter test test/unit/sports/`

---

### - [x] S2-T3 — `MvCommitmentRepository` — 9702cbef

**فایل جدید:** `data/repositories/mv_commitment_repository.dart`

```dart
class MvCommitmentRepository {
  Future<List<MvCommitment>> getActive();
  Future<List<MvCommitment>> getForDay(int dayOfWeekSat0);
  Future<MvCommitment> upsert(MvCommitment c);
  Future<void> deactivate(int id);
  Future<void> delete(int id);
}
```

**پذیرش:** تست CRUD کامل روی DB در‌حافطه + تست اینکه `deactivate` رکورد را حذف نمی‌کند.

**دستور تأیید:** `flutter test test/unit/sports/`

---

### - [x] S2-T4 — ساخت تعهد از شیت برنامهٔ روز — 50d71ac9

**فایل‌ها:** `presentation/sheets/mv_day_plan_sheet.dart`، فایل جدید `application/mv_save_commitment_use_case.dart`

**کار:** وقتی سویچ «هر هفته تکرار شود» روشن است و `plannedTime` پر شده، ذخیرهٔ شیت باید:
1. یک `MvCommitment` بسازد/بروز کند.
2. بازتولید برنامهٔ هفتهٔ جاری را تریگر کند (`MvWeekRegenUseCase` موجود).
3. برگشت به UI با پیام `mv_commitment_saved` که می‌گوید چند روز دیگر هفته بازچیده شد.

اگر سویچ خاموش باشد → فقط یک اسلات تک‌بار با `isLocked = true` برای همان روز.

**پذیرش:** تست: ثبت تعهد فوتسال پنجشنبه ۲۱:۰۰ → برنامهٔ هفته باید پنجشنبه یک اسلات `sport` با `kindCode == 'FUTSAL'`، `isLocked == true`، `plannedTime == '21:00'` داشته باشد.

**دستور تأیید:** `flutter test test/unit/sports/`

---

### - [x] S2-T5 — سوال لنگر در آنبوردینگ — 26d840fd

**فایل:** `presentation/screens/mv_onboarding_screen.dart`

**کار:** یک مرحلهٔ جدید قبل از مرحلهٔ نهایی:
- عنوان: `mv_onboarding_anchor_title` — متن فارسی: «ورزش ثابتی داری که هفته‌ای انجام بدهی؟»
- ۲ گزینه: «بله، اضافه کنم» (→ `mv_kind_picker_sheet` و بعد روز + ساعت + مدت) و «فعلاً نه»
- امکان افزودن تا ۳ تعهد در همین مرحله
- پرش از این مرحله اجباراً مجاز است (بدون اجبار)

**پذیرش:** widget test کامل مسیر آنبوردینگ با ۲ حالت (با تعهد و بدون تعهد). هر دو باید به برنامهٔ هفتگی معتبر برسند.

**دستور تأیید:** `flutter test test/unit/sports/`

---

### - [x] S2-T6 — نمایش لنگر در تب امروز و تب هفته — 0226a0a4

**فایل‌ها:** `presentation/screens/mv_today_tab.dart`، `presentation/screens/mv_week_tab.dart`، `presentation/components/mv_day_slot_card.dart`

**کار:**
1. کارت اسلات لنگر باید قفل (آیکون قفل از سیستم طراحی)، ساعت، و مکان را نشان دهد.
2. در تب امروز، اگر **فردا** لنگر دارد، یک نوار یک‌خطی با کلید `mv_tomorrow_anchor_notice` نشان بده (پارامترها: عنوان نوع و ساعت).
3. در تب هفته، روزهای لنگر با برجستگی متفاوت و در ریل هفته (`MvWeekRail`) با نشانگر قفل.
4. بانر تعارض: اگر ADJ-6 رخ داد، پیام `mv_conflict_back_to_back` بالای هفته.

**پذیرش:** widget test: هفته‌ای با دو لنگر پشت‌سرهم → بانر دیده شود. هفته‌ای با یک لنگر → بانر دیده نشود.

**دستور تأیید:** `flutter test test/unit/sports/`

---

### - [x] S2-T7 — اکشن «این هفته لغو شد» — ff7a21e8

**فایل‌ها:** `presentation/sheets/mv_cant_today_sheet.dart`، جدول موجود `movement_slot_overrides`

**کار:** روی هر اسلات لنگر، اکشن `mv_anchor_cancelled_this_week`:
1. یک رکورد در `movement_slot_overrides` بنویس (تعهد را غیرفعال **نکن**).
2. `PlanEngine` را برای باقیماندهٔ همان هفته دوباره اجرا کن تا دقیقهٔ ازدست‌رفته جایگزین شود.
3. پیام بازخورد: چند دقیقه جایگزین شد و در کدام روز.
4. اگر در **۴ هفتهٔ متوالی** ۳ بار یا بیشتر لغو شد، یک پیشنهاد نشان بده: `mv_anchor_suggest_deactivate`.

**پذیرش:** تست: لغو لنگر پنجشنبه → تعهد `isActive == 1` بماند، ولی اسلات همان هفته حذف شود و مجموع دقیقهٔ برنامه‌ریزی‌شده در همان محدوده بماند (±۱۵ دقیقه).

**دستور تأیید:** `flutter test test/unit/sports/`

---

### - [x] S2-T8 — تست‌های لنگر — 1df734f2

**فایل جدید:** `test/unit/sports/mv_commitment_test.dart`

حداقل این ۶ تست:
1. تعهد هفتگی در ۴ هفتهٔ متوالی اسلات می‌سازد.
2. `isFlexible == 0` → موتور هرگز روز یا ساعتش را تغییر نمی‌دهد.
3. `isFlexible == 1` → در تعارض مجاز به جابه‌جایی حداکثر ±۱ روز است.
4. دو تعهد در یک روز → هر دو حفظ می‌شوند، ولی روز بعد اجباراً `activeRest`.
5. حذف تعهد → اسلات‌های آینده پاک می‌شوند، جلسات گذشته دست‌نخورده می‌مانند.
6. تعهد با `endDateIso` گذشته → اسلات جدید تولید نمی‌شود.

**دستور تأیید:** `flutter test test/unit/sports/mv_commitment_test.dart && flutter test`

---

## ۸. اسپرینت S3 — `PlanEngine v2` (قلب معماری)

**هدف اسپرینت:** موتور دور لنگرها برنامه بچیند و برای هر اسلات دلیل فارسی بدهد.

### - [x] S3-T1 — جدول `mv_kind_profile` و seed قطعیش — ca53f5c2

**فایل‌ها:** مایگریشن `MigrationV<N>MvKindProfile`، فایل جدید `data/seed/mv_kind_profile_seed.dart`

```sql
CREATE TABLE IF NOT EXISTS mv_kind_profile (
  kindCode              TEXT PRIMARY KEY,
  primaryMuscles        TEXT NOT NULL,   -- csv
  neuroCost             INTEGER NOT NULL, -- 1..3
  recoveryHours         INTEGER NOT NULL,
  complementFocus       TEXT NOT NULL,   -- csv گروه‌های قدرتی پشتیبان
  prehabTags            TEXT,            -- csv برچسب پیشگیری
  recommendedTierBefore TEXT NOT NULL,   -- light|moderate|hard
  recommendedTierAfter  TEXT NOT NULL
);
```

**seed اجباری — دقیقاً این مقادیر را بنویس (عددی اختراع نکن):**

| kindCode | primaryMuscles | neuroCost | recoveryHours | complementFocus | prehabTags |
| --- | --- | --- | --- | --- | --- |
| FOOTBALL | hamstrings,quads,calves,glutes | 3 | 48 | posterior_chain,adductors,ankle | nordic_hamstring,copenhagen,ankle_hop |
| FUTSAL | hamstrings,quads,calves,core | 3 | 48 | posterior_chain,adductors,ankle | nordic_hamstring,copenhagen,ankle_hop |
| BASKETBALL | quads,calves,glutes,core | 3 | 48 | landing,knee,hip | lateral_bound,nordic,copenhagen |
| VOLLEYBALL | calves,quads,shoulders,core | 3 | 48 | landing,rotator_cuff,calf | drop_squat,band_external_rotation,calf_raise |
| TENNIS | shoulders,forearm,quads,core | 2 | 36 | rotator_cuff,thoracic,hip | band_external_rotation,thoracic_rotation |
| BADMINTON | calves,shoulders,quads | 2 | 36 | ankle,rotator_cuff,hip | ankle_hop,band_external_rotation |
| SQUASH | quads,calves,shoulders | 3 | 48 | ankle,hip,rotator_cuff | lateral_bound,ankle_hop |
| TABLE_TENNIS | forearm,shoulders,core | 1 | 12 | thoracic,wrist | wrist_curl,thoracic_rotation |
| HIKING | quads,glutes,calves,erector | 2 | 36 | step_up,carry,eccentric_quad | step_down_eccentric,farmer_carry,tibialis_raise |
| ROCK_CLIMBING | forearm,lats,biceps,core | 3 | 48 | antagonist_push,scapular,wrist | band_press,scapular_pullup,wrist_extension |
| RUNNING | calves,hamstrings,quads | 2 | 24 | posterior_chain,hip_stability | calf_raise,single_leg_bridge |
| TRAIL_RUNNING | calves,quads,glutes,ankle | 3 | 48 | ankle,eccentric_quad,hip | step_down_eccentric,ankle_hop |
| CYCLING | quads,glutes,calves | 1 | 24 | posterior_chain,core,thoracic | hip_hinge,thoracic_extension |
| SWIMMING | lats,shoulders,core | 1 | 12 | thoracic,scapular,hip | scapular_retraction,thoracic_rotation |
| JUMP_ROPE | calves,quads,shoulders | 2 | 24 | ankle,calf | calf_raise,ankle_hop |
| KARATE | hips,core,shoulders | 3 | 48 | hip_mobility,core,neck | hip_flexor_stretch,dead_bug |
| TAEKWONDO | hips,hamstrings,core | 3 | 48 | hip_mobility,hamstring,core | hip_flexor_stretch,hamstring_curl |
| JUDO | back,grip,core,hips | 3 | 48 | grip,posterior_chain,neck | farmer_carry,neck_isometric |
| WRESTLING | back,grip,neck,hips | 3 | 48 | grip,neck,posterior_chain | farmer_carry,neck_isometric |
| BOXING | shoulders,core,calves | 3 | 48 | rotator_cuff,core,neck | band_external_rotation,dead_bug |
| YOGA | full_body | 1 | 0 | none | none |
| STRETCHING | full_body | 1 | 0 | none | none |
| WALKING | calves,glutes | 1 | 0 | none | none |
| SKIING | quads,glutes,core | 3 | 48 | eccentric_quad,ankle,core | wall_sit,step_down_eccentric |
| BODYWEIGHT | full_body | 2 | 36 | mobility,core | none |

برای هر کد دیگری از ۴۹ نوع که در جدول بالا نیست، پروفایل پیش‌فرض بنویس: `primaryMuscles='full_body'`، `neuroCost` از `jointImpact` نوع (`0→1, 1→1, 2→2, 3→3`)، `recoveryHours = jointImpact * 16`، `complementFocus='mobility,core'`، `prehabTags=null`، `recommendedTierBefore='light'`، `recommendedTierAfter='light'`.

**پذیرش:** تست: تعداد ردیف‌های `mv_kind_profile` باید **برابر تعداد ردیف‌های فعال `movement_kinds`** باشد. هیچ نوعی بدون پروفایل نماند.

**دستور تأیید:** `flutter test test/unit/sports/`

---

### - [x] S3-T2 — `MvKindProfileRepository` — 0ee12ae5

**فایل جدید:** `data/repositories/mv_kind_profile_repository.dart`

```dart
class MvKindProfileRepository {
  Future<MvKindProfile?> getByCode(String kindCode);
  Future<Map<String, MvKindProfile>> getMapByCodes(List<String> codes);
}
```

به همراه مدل `domain/models/mv_kind_profile.dart`.

**دستور تأیید:** `flutter test test/unit/sports/`

---

### - [x] S3-T3 — `reasonKey` و `reasonParams` روی هر اسلات — dbb21119

**فایل‌ها:** `domain/models/mv_slot.dart`، `domain/models/mv_decision.dart`

**کار:** دو فیلد اضافه کن: `String? reasonKey` و `Map<String, String>? reasonParams` (در DB به‌صورت JSON متنی). هر مرحلهٔ موتور باید این‌ها را پر کند.

**فهرست کامل `reasonKey` های مجاز (بیش از این نساز):**

| reasonKey | متن فارسی (برای l10n) |
| --- | --- |
| `mv_reason_anchor` | لنگر ثابت توست |
| `mv_reason_pre_anchor_taper` | فردا {kind} داری، امروز سبک |
| `mv_reason_post_anchor_recovery` | دیروز {kind} داشتی، امروز بازیابی |
| `mv_reason_complement` | پشتیبانی {kind}: تقویت {focus} |
| `mv_reason_who_gap` | برای رسیدن به هدف هفتگی {remaining} دقیقه مانده |
| `mv_reason_strength_quota` | این هفته فقط {days} روز قدرتی داشتی |
| `mv_reason_rest_guaranteed` | سه لنگر یا بیشتر داری، این روز کامل استراحت |
| `mv_reason_readiness_low` | بر اساس چک‌این امروز کم‌شده |
| `mv_reason_load_cap` | سقف رشد ۱۰٪ رعایت شد |
| `mv_reason_fallback_minimum` | حداقل مؤثر برای حفظ روند |
| `mv_reason_season_fit` | مناسب فصل جاری |
| `mv_reason_constraint_relaxed` | برای اینکه برنامه خالی نماند، یک محدودیت شل شد |

**پذیرش:** گاردتست: هر اسلاتی که `PlanEngine` تولید می‌کند باید `reasonKey != null` داشته باشد و کلید در فهرست بالا باشد.

**دستور تأیید:** `flutter test test/unit/sports/`

---

### - [x] S3-T4 — مرحلهٔ ۱: `ANCHORS` — 47ab1859

**فایل:** `domain/engines/plan_engine.dart`

**کار:** موتور را بازنویسی کن به شش مرحلهٔ مجزا به‌صورت متدهای خصوصی:

```dart
MvPlanResult generateWeek({
  required DateTime weekStartSat,
  required MvUserProfile profile,
  required List<MvCommitment> commitments,
  required List<MvSlotOverride> overrides,
  required Map<String, MvMovementKind> kinds,
  required Map<String, MvKindProfile> kindProfiles,
  required MvBudgetSnapshot budget,       // از BudgetEngine
  required MvLoadSnapshot? load,          // null وقتی داده کافی نیست
  required MvReadinessTier readiness,
});
```

در این تسک فقط `_placeAnchors()` را پیاده کن: برای هر تعهد فعال و هر رویداد تک‌بار، اسلات با `isLocked = true`، `slotType` مشتق از خانوادهٔ نوع (`SPORT→sport`، `OUTDOOR→outdoor`، `ENDURANCE→cardio`، `STRENGTH→strength`، `MIND_BODY→mobility`، `MARTIAL_SKILL→sport`، `DAILY→activeRest`)، `plannedTime`، `reasonKey = 'mv_reason_anchor'`. `overrides` لغوشده را حذف کن.

**پذیرش:** تست: دو تعهد (پنجشنبه فوتسال، جمعه کوه) → دقیقاً ۲ اسلات قفل‌شده در همان دو روز با همان ساعت‌ها.

**دستور تأیید:** `flutter test test/unit/sports/`

---

### - [x] S3-T5 — مرحلهٔ ۲: `HARD_LIMITS` — 2a339dfd

**کار:** `_applyHardLimits()`: بازه‌های ممنوع تقویم، محدودیت‌های جسمی پروفایل (مفصل، حالت آپارتمان، بدون تجهیزات)، و فصل (`seasonMask`). خروجی: مجموعهٔ روزها/نوع‌های مجاز.

**قاعدهٔ قطعی:** لنگرها از این فیلتر **معاف** هستند (کاربر صریحاً خواسته). ولی اگر لنگری با محدودیت جسمی تعارض دارد، یک یادداشت `mv_anchor_constraint_note` روی همان اسلات بزن.

**پذیرش:** تست: پروفایل با درد زانو → پرکننده‌های پرضربه نیایند، ولی لنگر فوتسال سر جایش بماند با یادداشت.

**دستور تأیید:** `flutter test test/unit/sports/`

---

### - [x] S3-T6 — مرحلهٔ ۳: `ADJACENCY` (ADJ-1..ADJ-7) — 2ebdd84c

**کار:** `_applyAdjacency()` را دقیقاً طبق جدول §۴٫۵ پیاده کن. ترتیب اعمال دقیقاً ADJ-1 تا ADJ-7.

**پذیرش (تست جدولی اجباری):**

| ورودی | خروجی مورد انتطار |
| --- | --- |
| فقط لنگر پنجشنبه فوتسال ۹۰د | چهارشنبه = `mobility` حداکثر ۲۰د؛ جمعه = `activeRest` حداکثر ۲۵د |
| لنگر پنجشنبه فوتسال + جمعه کوه | پنجشنبه و جمعه قفل؛ شنبه = `activeRest` (ADJ-6)؛ بانر تعارض فعال |
| ۳ لنگر در هفته | دقیقاً یک روز `rest` تضمین شود (ADJ-5) |
| دو قدرتی سنگین با تمرکز یکسان | حداقل ۴۸ ساعت فاصله (ADJ-4) |
| لنگر ۴۵ دقیقه‌ای پینگ‌پونگ (jointImpact=1) | روز بعد محدود **نشود** (لنگر پرضربه نیست) |

**دستور تأیید:** `flutter test test/unit/sports/mv_plan_engine_adjacency_test.dart`

---

### - [x] S3-T7 — مرحلهٔ ۴: `FILL` با سقف رشد — 838d3f20

**کار:** `_fillToTarget()`: تا رسیدن به معادل متوسط هدف (§۴٫۲) و حداقل ۲ روز قدرتی، اسلات اضافه کن، با رعایت سقف §۴٫۴. انتخاب نوع پرکننده از `SelectionEngine` موجود بگیرد — موتور جدید نساز.

**قواعد قطعی ترتیب اولویت پرکردن:**
1. کمبود روز قدرتی (تا ۲ روز)
2. حرکات پیشگیری مربوط به لنگرها (`prehabTags`)
3. کمبود دقیقهٔ معادل متوسط (تا ۱۵۰)
4. تحرک و بازیابی

**پذیرش:** تست: کاربری با ۲ لنگر جمعاً ۲۷۰ دقیقهٔ معادل → موتور دیگر هوازی اضافه نکند ولی حتماً ۲ روز قدرتی بگذارد.

**دستور تأیید:** `flutter test test/unit/sports/`

---

### - [x] S3-T8 — مرحلهٔ ۵: `COMPLEMENT` (قدرتی پشتیبان لنگر) — 64b8bba2

**کار:** `_addComplements()`: برای هر لنگر، از `mv_kind_profile.complementFocus` تمرکز قدرتی روزهای قدرتی را تعیین کن و `reasonKey = 'mv_reason_complement'` با پارامترهای `kind` و `focus` بگذار.

**پذیرش:** تست: لنگر `FOOTBALL` → در روز قدرتی باید `posterior_chain` در تمرکز باشد. لنگر `HIKING` → `step_up` یا `eccentric_quad`. لنگر `ROCK_CLIMBING` → `antagonist_push`.

**دستور تأیید:** `flutter test test/unit/sports/`

---

### - [x] S3-T9 — مرحلهٔ ۶: `FALLBACK` و ثبت تصمیم — a0c9e048

**کار:**
1. `_fallback()`: اگر خروجی خالی شد، محدودیت‌ها را به ترتیب معکوس شل کن (اول فصل، بعد تجهیزات، بعد مدت). آخرین خروجی همیشه: یک اسلات `mobility` ۱۰ دقیقه‌ای با `reasonKey = 'mv_reason_fallback_minimum'`.
2. هر مرحله یک ردیف در `ss_decision_log` بنویسد: نام مرحله، تعداد اسلات ورودی/خروجی، و قواعد اعمال‌شده.

**پذیرش (گاردتست «همیشه-خروجی»):** ۸ پروفایل حاد (بدون تجهیزات + محدودیت زانو + آپارتمان + خواب ۴ ساعت + بدون زمان …) → هیچ‌کدام نباید برنامهٔ خالی بدهد.

**دستور تأیید:** `flutter test test/unit/sports/`

---

### - [x] S3-T10 — سه مسیر طلایی به‌عنوان تست سراسری — e8163245

**فایل جدید:** `test/unit/sports/mv_golden_paths_test.dart`

**مسیر طلایی ۱ — فوتسالی هفتگی:** تعهد پنجشنبه ۲۱:۰۰ فوتسال ۹۰ دقیقه → موتور باید: پنجشنبه قفل؛ چهارشنبه تحرک ≤۲۰د؛ جمعه بازیابی ≤۲۵د؛ دو روز قدرتی با تمرکز زنجیرهٔ پشتی؛ مجموع معادل متوسط ≥۱۵۰.

**مسیر طلایی ۲ — کوهنورد جمعه:** تعهد جمعه ۰۶:۰۰ کوه ۲۴۰ دقیقه → پنجشنبه سبک؛ شنبه بازیابی؛ دو روز قدرتی با `step_up`/`eccentric_quad`؛ هیچ قدرتی سنگین پایین‌تنه در پنجشنبه.

**مسیر طلایی ۳ — دو لنگر پشت‌سرهم:** پنجشنبه فوتسال + جمعه کوه → بانر تعارض؛ شنبه `activeRest`؛ حداقل یک روز `rest` کامل؛ مجموع بار برنامه‌ریزی‌شده داخل سقف ۱۰٪.

هر سه مسیر باید علاوه بر ساختار، وجود `reasonKey` روی همهٔ اسلات‌ها را چک کنند.

**دستور تأیید:** `flutter test test/unit/sports/mv_golden_paths_test.dart && flutter test`

---

## ۹. اسپرینت S4 — حالت‌های پلیر و متریک‌های واقعی

**هدف اسپرینت:** جلسهٔ کوه مثل جلسهٔ کوه ثبت شود و جلسهٔ فوتسال مثل فوتسال — نه هر دو مثل جلسهٔ قدرتی هدایت‌شده.

### - [x] S4-T1 — مایگریشن ستون‌های متریک جلسه — 0a51fa65

**فایل‌ها:** مایگریشن `MigrationV<N>SessionMetrics`، `lib/core/database/schema/tables/supplementary_sports_tables.dart`

```sql
ALTER TABLE movement_sessions ADD COLUMN distanceM        REAL;
ALTER TABLE movement_sessions ADD COLUMN elevationGainM   REAL;
ALTER TABLE movement_sessions ADD COLUMN laps             INTEGER;
ALTER TABLE movement_sessions ADD COLUMN packWeightKg     REAL;
ALTER TABLE movement_sessions ADD COLUMN rpe1To10         INTEGER;
ALTER TABLE movement_sessions ADD COLUMN effortSource     TEXT;   -- 'user' | 'estimated'
ALTER TABLE movement_sessions ADD COLUMN routeId          INTEGER;
CREATE INDEX IF NOT EXISTS idx_movement_sessions_kind_date
  ON movement_sessions(kindCode, startedAt);
```

**واحدها قطعی و غیرقابل تغییر:** مسافت و ارتفاع برحسب **متر**، وزن برحسب **کیلوگرم**. تبدیل به کیلومتر فقط در لایهٔ نمایش.

**پذیرش:** مایگریشن روی DB موجود بالا بیاید و دادهٔ قبلی سالم بماند (تست: ۳ رکورد قبلی بساز، مایگریشن بزن، همان ۳ رکورد را بخوان).

**دستور تأیید:** `flutter test test/unit/sports/`

---

### - [x] S4-T2 — متریک‌ها در `MvSession` — 30672336

**فایل:** `domain/models/mv_session.dart`

**کار:** همان ۷ فیلد بالا را به مدل اضافه کن (همه nullable)، در `toMap`/`fromMap` پوشش بده، و دو getter محاسباتی:

```dart
int? get sessionLoad => (rpe1To10 != null && elapsedMinutes > 0)
    ? rpe1To10! * elapsedMinutes
    : null;
double? get paceSecPerKm; // فقط وقتی distanceM و elapsedMinutes معتبرند
```

**پذیرش:** تست round-trip کامل برای جلسهٔ کوه: `distanceM: 9400`, `elevationGainM: 780`, `packWeightKg: 6`, `rpe1To10: 7`.

**دستور تأیید:** `flutter test test/unit/sports/`

---

### - [x] S4-T3 — پورت قالب‌های حالت پلیر — 81dd2655

**مرجع legacy (مطلقاً از صفر ننویس):** `lib/features/supplementary_sports/movement/presentation/session/templates/` و `session_shell.dart` و `session_template_router.dart`.

**فایل‌های مقصد (جدید):** `presentation/player/templates/mv_timed_template.dart`، `mv_distance_template.dart`، `mv_route_template.dart`، `mv_laps_template.dart`، `mv_match_template.dart`

**جدول قطعی میدان‌های هر حالت:**

| حالت | میدان‌های زنده | در پایان جلسه می‌پرسد |
| --- | --- | --- |
| `timed` | کرونومتر بالارونده، دکمهٔ توقف/ادامه | تلاش |
| `distance` | کرونومتر + ورودی مسافت (کیلومتر) | مسافت، تلاش |
| `route` | کرونومتر + مسافت + ارتفاع + وزن پشتی + انتخاب مسیر از `mv_routes` | مسافت، ارتفاع، وزن پشتی، تلاش |
| `laps` | شمارندهٔ دور با دکمهٔ بزرگ + کرونومتر | تعداد دور، تلاش |
| `match` | کرونومتر نیمه‌ها + دکمهٔ نیمهٔ دوم | تلاش، یادداشت آزاد |
| `structured` | موجود — دست نزن | — |
| `guided` | موجود — دست نزن | — |

**قاعده:** هر قالب حداکثر ۳۰۰ خط. منطق مشترک در `presentation/player/mv_session_player_screen.dart` بماند.

**پذیرش:** widget test برای هر ۵ قالب جدید: رندر می‌شود و میدان‌های جدول بالا را دارد.

**دستور تأیید:** `flutter test test/unit/sports/ && flutter analyze`

---

### - [x] S4-T4 — انتخاب حالت پلیر از داده — f5fa60b7

**فایل:** `application/mv_start_session_use_case.dart`

**منطق قطعی (دقیقاً همین ترتیب):**

```
1. if (kind.sessionModeOverride != null) -> همان
2. else switch (kind.primaryMetric):
     DISTANCE  -> kind.isOutdoor ? route : distance
     ELEVATION -> route
     LAPS      -> laps
     DURATION  -> (kind.family == SPORT || kind.family == MARTIAL_SKILL) ? match : timed
     SETS      -> اگر تجویز موجود بود guided وگرنه structured
     STEPS     -> timed
     NONE      -> timed
```

**پذیرش:** تست جدولی با حداقل این ۸ ردیف: `HIKING→route`، `RUNNING→distance` (یا route اگر outdoor)، `SWIMMING→laps`، `FUTSAL→match`، `FOOTBALL→match`، `KARATE→match`، `STRETCHING→timed`، `BODYWEIGHT→guided`.

**گاردتست:** `rg -n "MvSessionMode.guided" application/` نباید مقدار پیش‌فرض بی‌قید داشته باشد.

**دستور تأیید:** `flutter test test/unit/sports/`

---

### - [x] S4-T5 — صفحهٔ پایان جلسه با متریک و تلاش — 31272444

**فایل‌ها:** `presentation/player/mv_session_summary_screen.dart`، `application/mv_finish_session_use_case.dart`

**چینش قطعی از بالا به پایین:**
1. عنوان نوع ورزش + ایموجی + مدت
2. کارت متریک‌ها — فقط میدان‌های مربوط به حالت جلسه (جدول S4-T3)
3. سوال تلاش: سه دکمهٔ `mv_effort_easy` / `mv_effort_good` / `mv_effort_hard` → `rpe1To10 = 3 / 6 / 8`، `effortSource = 'user'`
4. اسلایدر اختیاری «دقیق‌ترش کنم» ۱–۱۰
5. یادداشت آزاد (همان `note` که در S0-T1 درست شد)
6. اگر رکورد شخصی جدید بود: نوار `mv_new_personal_record` با ذکر نوع رکورد
7. دو خط تأثیر بر هفته: چند دقیقهٔ معادل اضافه شد و چند دقیقه تا هدف مانده

**قاعده:** اگر کاربر تلاش را رد کرد، `rpe1To10` را از `kind.baseMet` تخمین بزن (`met<3→3`، `3–6→5`، `>6→7`) و `effortSource = 'estimated'` بگذار. تخمین هرگز به کاربر مثل عدد واقعی نشان داده نمی‌شود.

**پذیرش:** widget test: جلسهٔ `HIKING` → میدان ارتفاع دیده شود؛ جلسهٔ `FUTSAL` → میدان ارتفاع دیده نشود.

**دستور تأیید:** `flutter test test/unit/sports/`

---

### - [ ] S4-T6 — `LoadEngine` و فرمول sRPE

**فایل جدید:** `domain/engines/load_engine.dart` و اضافه به `domain/engines/engines.dart`

**کار:** فرمول §۴٫۳ را پیاده کن. خروجی:

```dart
class MvLoadSnapshot {
  final int acuteLoad;
  final double chronicWeeklyLoad;
  final double? ratio;          // null وقتی داده کافی نیست
  final String? bandKey;        // یکی از ۴ کلید جدول §۴٫۳
  final int daysOfHistory;
  final int completedSessions;
}
```

**گارد اجباری:** اگر `daysOfHistory < 14 || completedSessions < 6` → `ratio == null` و `bandKey == null`.

**پذیرش:** تست جدولی ۵ ردیفی: دادهٔ کم → null؛ نسبت ۰٫۶ → low؛ ۱٫۰ → optimal؛ ۱٫۴ → watch؛ ۱٫۸ → spike.

**دستور تأیید:** `flutter test test/unit/sports/mv_load_engine_test.dart`

---

### - [ ] S4-T7 — جدول `mv_routes` (مسیرهای تکرارشونده)

**فایل‌ها:** مایگریشن `MigrationV<N>MvRoutes`، `data/repositories/mv_route_repository.dart`، `domain/models/mv_route.dart`

```sql
CREATE TABLE IF NOT EXISTS mv_routes (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  titleFa         TEXT    NOT NULL,
  kindCode        TEXT    NOT NULL,
  distanceM       REAL,
  elevationGainM  REAL,
  notes           TEXT,
  timesCompleted  INTEGER NOT NULL DEFAULT 0,
  bestDurationMin INTEGER,
  lastDoneAt      TEXT,
  createdAt       TEXT    NOT NULL
);
```

**کار:** در قالب `route`، کاربر می‌تواند مسیر موجود را انتخاب کند (مسافت/ارتفاع پیش‌پر می‌شود) یا مسیر جدید ذخیره کند. پس از پایان جلسه، `timesCompleted`، `bestDurationMin` و `lastDoneAt` بروز شوند.

**پذیرش:** تست: دو بار انجام مسیر «دارآباد» با مدت ۲۴۰ و ۲۲۵ دقیقه → `timesCompleted == 2`، `bestDurationMin == 225`.

**دستور تأیید:** `flutter test test/unit/sports/`

---

### - [ ] S4-T8 — مهار رگرسیون S4

**کار:** یک تست سراسری: شروع جلسهٔ کوه از اسلات لنگر → قالب `route` باز شود → مسافت/ارتفاع/وزن پر شود → تلاش «سخت بود» → جلسه با همهٔ متریک‌ها و `rpe1To10 == 8` و `effortSource == 'user'` در DB باشد → بودجهٔ هفته بروز شود.

**دستور تأیید:** `flutter test && flutter analyze`

---

## ۱۰. اسپرینت S5 — دورهٔ هدف‌دار و تحلیل واقعی

**هدف اسپرینت:** کاربری که می‌گوید «دو ماه دیگر قله می‌روم»، برنامهٔ رو به جلو بگیرد.

### - [ ] S5-T1 — فعال‌سازی `movement_campaigns`

**فایل‌ها:** `data/repositories/mv_campaign_repository.dart` (جدید)، `domain/models/mv_campaign.dart` (موجود)

**کار:** جدول موجود را متصل کن — جدول جدید نساز. اگر ستون لازم ندارد، فقط ستون کمبود را اضافه کن و در لاگ بنویس.

```dart
class MvCampaignRepository {
  Future<MvCampaign?> getActive();
  Future<MvCampaign> upsert(MvCampaign c);
  Future<void> complete(int id);
}
```

**دستور تأیید:** `flutter test test/unit/sports/`

---

### - [ ] S5-T2 — برنامهٔ برگشتی برای رویداد هدف

**فایل جدید:** `domain/engines/campaign_engine.dart`

**منطق قطعی برای هدف نوع `OUTDOOR`/`HIKING` (پیاده‌سازی دقیقاً همین):**

```
weeksToGoal = تعداد هفته‌های باقیمانده تا تاریخ رویداد
فاز 1 (۴ هفتهٔ اول یا تا نیمهٔ مدت، هر کدام کمتر):
  پایه‌سازی — بدون وزن پشتی، رشد مدت حداکثر 10% در هفته
فاز 2:
  وزن پشتی پله‌ای: 5% → 10% → 15% → 20% وزن بدن
  هر پله حداقل ۲ هفته تکرار
فاز 3 (۱ هفتهٔ مانده به رویداد):
  سبک‌سازی — حجم 60% هفتهٔ قبل، بدون جلسهٔ طولانی
```

اگر `weeksToGoal < 4` باشد، پیام `mv_campaign_too_short` نشان بده و فازبندی را به پایه + سبک‌سازی محدود کن. **هیچ وعدهٔ عددی به کاربر نده** (ممنوع: «تا قله آماده می‌شوی»).

**پذیرش:** تست جدولی: هدف ۱۲ هفته بعد و وزن بدن ۸۰کگ → وزن پشتی هفتهٔ ۹ باید ۱۲کگ (۱۵٪) باشد؛ هفتهٔ ۱۲ باید سبک‌سازی باشد؛ هفتهٔ ۱–۴ باید وزن پشتی صفر.

**دستور تأیید:** `flutter test test/unit/sports/mv_campaign_engine_test.dart`

---

### - [ ] S5-T3 — رکورد شخصی به تفکیک نوع ورزش

**فایل‌ها:** `data/repositories/mv_pr_repository.dart`، `presentation/screens/mv_progress_tab.dart`

**قواعد قطعی رکورد (فقط این‌ها، بیشتر نساز):**

| متریک اولیه | رکوردها |
| --- | --- |
| DISTANCE | بیشترین مسافت در یک جلسه؛ بهترین تمپو در ۵کم+ |
| ELEVATION | بیشترین ارتفاع در یک جلسه؛ بیشترین وزن پشتی |
| LAPS | بیشترین تعداد دور |
| DURATION | بلندترین جلسه؛ بیشترین تکرار در یک ماه |
| SETS | موجود — دست نزن |

**پذیرش:** تست: دو جلسهٔ کوه با ارتفاع ۶۰۰ و ۷۸۰ → رکورد ارتفاع = ۷۸۰ و رکورد فوتسال دست‌نخورده بماند (جدایی رکورد به تفکیک نوع).

**دستور تأیید:** `flutter test test/unit/sports/`

---

### - [ ] S5-T4 — تب پیشرفت با دو ارز و زبان فرضیه‌ای

**فایل:** `presentation/screens/mv_progress_tab.dart`

**چینش قطعی:**
1. کارت «سلامت این هفته»: دقیقهٔ معادل متوسط / ۱۵۰ و تعداد روز قدرتی / ۲
2. کارت «بار تمرینی»: ۷ روز در برابر میانگین ۲۸ روز + بازهٔ متنی. اگر `MvLoadSnapshot.ratio == null` → `MvInsufficientData` با متن «چند جلسهٔ دیگر لازم است»
3. کارت «توزیع ورزش‌ها»: سهم هر نوع از دقیقهٔ ماه جاری
4. کارت رکوردها به تفکیک نوع
5. دورهٔ هدف‌دار فعال (اگر وجود دارد)

**قاعدهٔ زبان (اجباری):** هر بینش با قید احتمال بیاید («به نظر می‌رسد…»، «در ۴ هفتهٔ گذشته…»). ممنوع مطلق: هر متنی با ماهیت تشخیص پزشکی، آسیب، یا توصیهٔ درمانی.

**پذیرش:** widget test دو حالت: کاربر تازه (همه کارت‌ها در حالت دادهٔ ناکافی) و کاربر با ۶ هفته داده (همه پر).

**دستور تأیید:** `flutter test test/unit/sports/`

---

### - [ ] S5-T5 — فعال‌سازی `station_bundles`

**فایل‌ها:** `data/repositories/mv_station_bundle_repository.dart` (جدید)، `domain/models/mv_station_bundle.dart` (موجود)، `presentation/sheets/mv_exercise_substitution_sheet.dart`

**کار:** جدول موجود را وصل کن تا در محدودیت تجهیزات، بستهٔ جایگزین پیشنهاد شود. اگر جدول خالی است و دادهٔ seed وجود ندارد، **داده اختراع نکن** — این تسک را BLOCKED کن و در لاگ بنویس که seed لازم است.

**دستور تأیید:** `flutter test test/unit/sports/`

---

### - [ ] S5-T6 — بینش‌های مبتنی بر دادهٔ واقعی

**فایل:** `domain/engines/insight_engine.dart` (موجود)

**دقیقاً این ۵ بینش و نه بیشتر:**

| کلید | شرط فعال‌شدن |
| --- | --- |
| `mv_insight_best_day` | حداقل ۸ جلسهٔ کامل‌شده؛ روزی که نرخ تکمیلش حداقل ۲۰ درصد بالاتر از میانگین است |
| `mv_insight_anchor_adherence` | حداقل ۴ هفته تعهد فعال؛ نرخ حضور در لنگر |
| `mv_insight_effort_drift` | حداقل ۱۰ جلسه با `effortSource == 'user'`؛ تغییر میانگین RPE بین دو ماه |
| `mv_insight_kind_mix` | حداقل ۳ نوع متفاوت در ماه؛ سهم غالب |
| `mv_insight_route_progress` | حداقل ۳ بار انجام یک مسیر؛ روند مدت |

هر بینشی که شرطش برقرار نباشد **نمایش داده نمی‌شود** — جملهٔ عمومی جایگزین نساز.

**پذیرش:** تست: کاربر با ۳ جلسه → صفر بینش. کاربر با دادهٔ کامل → دقیقاً بینش‌هایی که شرطشان برقرار است.

**دستور تأیید:** `flutter test test/unit/sports/`

---

### - [ ] S5-T7 — مهار رگرسیون S5

**دستور تأیید:** `flutter test && flutter analyze && dart format --set-exit-if-changed lib/features/supplementary_sports test/unit/sports`

---

## ۱۱. اسپرینت S6 — بدهی فنی، مستندات، و پاکسازی کد یتیم

**قاعدهٔ طلایی این اسپرینت:** هیچ فایلی حذف نمی‌شود مگر در `PORT_LEDGER.md` یک ردیف با وضعیت `PORTED` یا `INTENTIONALLY_DROPPED` داشته باشد.

### - [ ] S6-T1 — استخراج کامل l10n

**فایل‌ها:** همهٔ فایل‌های `lib/features/supplementary_sports/presentation/`، فایل arb فارسی

**کار:**
1. اجرا: `rg -n "'[\u0600-\u06FF]" lib/features/supplementary_sports/presentation/ | wc -l` → عدد اولیه را در لاگ بنویس.
2. هر رشتهٔ فارسی را به کلید `mv_` منتقل کن.
3. کلیدهای شناخته‌شدهٔ واجب (حداقل): `mv_day_plan_title`, `mv_library_title`, `mv_week_plan_title`.
4. اجرای مجدد دستور ۱ → باید **صفر** شود.

**ممنوع:** کلید بدون پیشوند `mv_`. کلید تکراری با معنای یکسان.

**پذیرش:** خروجی `rg` بالا برابر صفر؛ `flutter analyze` پاک.

**دستور تأیید:** `flutter analyze && flutter test`

---

### - [ ] S6-T2 — حذف مقادیر سبک خام

**کار:** در کل `lib/features/supplementary_sports/`:
- هر `fontSize:` خام → توکن تایپوگرافی سیستم طراحی
- هر `Color(0x` خام → توکن رنگ
- هر فاصلهٔ عددی خارج از مقیاس ۴ پیکسلی → نزدیک‌ترین توکن

**مرجع:** `docs/RITMO_DESIGN_TOKENS.md` و `docs/DESIGN_SYSTEM_ACTION_SHEETS.md`. توکن جدید اختراع نکن.

**پذیرش:** `rg -n "fontSize:" lib/features/supplementary_sports/ | wc -l` → صفر. `rg -n "Color\(0x" lib/features/supplementary_sports/ | wc -l` → صفر.

**دستور تأیید:** `flutter analyze && flutter test`

---

### - [ ] S6-T3 — دوازده گاردتست دائمی

**فایل جدید:** `test/unit/sports/mv_architecture_guard_test.dart`

**دقیقاً این ۱۲ تست را بنویس:**

| # | گاردتست | میزان پاس |
| --- | --- | --- |
| G-01 | هیچ `kindCode` هاردکدی در `domain/engines/` و `application/` | صفر تطابق |
| G-02 | همهٔ `kindCode` ها UPPER_SNAKE_CASE | رگکس `^[A-Z][A-Z0-9_]*$` |
| G-03 | هر `kindCode` موجود در `movement_sessions` در `movement_kinds` هم هست | بدون یتیم |
| G-04 | هر نوع فعال پروفایل دارد | `count(kinds) == count(profiles)` |
| G-05 | هر اسلات تولیدی `reasonKey` دارد و در فهرست مجاز است | ۱۰۰٪ |
| G-06 | همهٔ فیلدهای `MvSession` در `toMap` هستند (بازتاب یا فهرست صریح) | صفر گم‌شده |
| G-07 | موتور برنامه هرگز لنگر `isFlexible == 0` را جابه‌جا نمی‌کند | ۲۰ سناریوی تصادفی |
| G-08 | هیچ برنامهٔ خالی تولید نمی‌شود | ۲۰ پروفایل حاد |
| G-09 | هیچ رشتهٔ فارسی در `presentation/` | صفر |
| G-10 | هیچ `fontSize:`/`Color(0x` در فیچر | صفر |
| G-11 | مقادیر تخمینی هرگز بدون `effortSource == 'estimated'` ذخیره نمی‌شوند | ۱۰۰٪ |
| G-12 | هیچ موتوری بدون دادهٔ کافی عدد نمایش نمی‌دهد | همهٔ موتورها |

**دستور تأیید:** `flutter test test/unit/sports/mv_architecture_guard_test.dart`

---

### - [ ] S6-T4 — `docs/movement/IA.md`

**فایل جدید:** `docs/movement/IA.md`

**محتوای اجباری:** یک هاب، سه تب (امروز/هفته/پیشرفت)، شش شیت، درخت مسیرهای راوتر، و نقشهٔ «از کدام صفحه به کدام شیت می‌رود». به علاوه جدول دو شیت جدید این اجرا (`mv_kind_picker_sheet`, `mv_custom_kind_sheet`).

**دستور تأیید:** فایل موجود و غیرخالی باشد: `test -s docs/movement/IA.md`

---

### - [ ] S6-T5 — `docs/movement/ENGINES.md`

**فایل جدید:** `docs/movement/ENGINES.md`

**محتوای اجباری — برای هر موتور یک بلوک با این ۵ خط:**
1. ورودی‌ها (نوع دقیق)
2. خروجی (نوع دقیق)
3. فرمول یا ترتیب قواعد
4. شرط دادهٔ ناکافی
5. فایل تست مربوطه

موتورهای مشمول: plan, selection, readiness, budget, load, substitution, progression, adaptation, insight, coach, reminder, profile, campaign.

**دستور تأیید:** `test -s docs/movement/ENGINES.md`

---

### - [ ] S6-T6 — جدول تطبیق F-01..F-50

**فایل جدید:** `docs/movement/FEATURE_PARITY.md`

**کار:** برای هر قابلیت F-01 تا F-50 مندرج در ضمیمهٔ A پرامپت اولیه، یک ردیف با این ستون‌ها:

`کد | عنوان قابلیت | وضعیت (DONE|PARTIAL|MISSING|DROPPED) | مسیر فایل متنازر | تست مربوطه | یادداشت`

**قاعده:** `DROPPED` فقط با دلیل یک‌خطی مجاز است. `PARTIAL` باید بگوید چه چیزی کم است.

**پذیرش:** دقیقاً ۵۰ ردیف. هیچ سلول خالی.

**دستور تأیید:** `grep -c "^| F-" docs/movement/FEATURE_PARITY.md` → `50`

---

### - [ ] S6-T7 — `docs/movement/PORT_LEDGER.md`

**فایل جدید:** `docs/movement/PORT_LEDGER.md`

**کار:** برای **هر** فایل legacy در ۲ مسیر زیر، یک ردیف:
- `lib/features/supplementary_sports/presentation/ss_*`
- `lib/features/supplementary_sports/movement/**`

ستون‌ها: `مسیر فایل | اندازه | وضعیت | مقصد پورت | دلیل حذف`

وضعیت‌های مجاز (بیش از این نساز): `PORTED` / `INTENTIONALLY_DROPPED` / `KEEP_AS_REFERENCE` / `PENDING`.

**قاعدهٔ قطعی:** تا وقتی یک ردیف `PENDING` است، فایلش ممنوع‌الحذف است.

**دستور تأیید:** `test -s docs/movement/PORT_LEDGER.md`

---

### - [ ] S6-T8 — حذف یتیم دستهٔ ۱: صفحه‌های `ss_*`

**فهرست دقیق حذف (فقط و فقط پس از `PORTED`/`INTENTIONALLY_DROPPED` در لجر):**

| فایل | اندازه | پیش‌نیاز پورت |
| --- | --- | --- |
| `presentation/ss_home_dashboard_screen.dart` | 135KB | تب امروز کامل باشد |
| `presentation/ss_workout_session_screen.dart` | 117KB | قالب `guided` پایدار باشد |
| `presentation/ss_onboarding_flow.dart` | 66KB | S2-T5 تمام شده |
| `presentation/ss_premium_muscle_category_screen.dart` | 21KB | کتابخانه کامل |
| `presentation/ss_progress_screen.dart` | — | S5-T4 تمام شده |
| `presentation/ss_plan_overview_screen.dart` | — | تب هفته |
| `presentation/ss_plan_day_detail_screen.dart` | — | `mv_day_detail_screen` |
| `presentation/ss_exercise_library_screen.dart` | — | `mv_library_screen` |
| `presentation/ss_settings_screen.dart` | — | `mv_settings_screen` |
| `presentation/ss_program_settings_screen.dart` | — | `mv_settings_screen` |
| `presentation/ss_movement_tab_screen.dart` | — | راوتر پاک |
| `presentation/ss_session_summary_screen.dart` | — | S4-T5 تمام شده |
| `presentation/ss_intro_screen.dart` | — | آنبوردینگ |
| `presentation/ss_workout_session_notifier.dart` | — | `mv_session_controller` |
| `presentation/ss_custom_exercise_sheet.dart` | — | S1-T8 تمام شده |
| `presentation/new_movement_section.dart` | — | هاب فعال |
| `presentation/widgets/` (پوشه) | — | ۱۵ کامپوننت `mv_` موجود |

**روش اجباری:** قبل از حذف هر فایل، اجرا کن `rg -n "<نام کلاس>" lib/ test/` — اگر خروجی غیر از خود فایل بود، حذف نکن و ردیف را `PENDING` بگذار.

**پذیرش:** `flutter analyze` پاک؛ `flutter test` کامل سبز؛ در لاگ مجموع کیلوبایت حذف‌شده را بنویس.

**دستور تأیید:** `flutter analyze && flutter test`

---

### - [ ] S6-T9 — حذف یتیم دستهٔ ۲: `movement/**`

**فهرست دقیق حذف (پس از پورت):**

پوشهٔ `movement/presentation/`:
`movement_plan_sheet.dart` (42KB)، `movement_log_sheet.dart` (37.9KB)، `movement_custom_kind_sheet.dart` (15.8KB)، `movement_analytics_screen.dart` (9.5KB)، `planner/unified_week_planner_screen.dart` (35.5KB)، `planner/week_smart_fill_sheet.dart` (14.1KB)، `planner/movement_slot_actions_sheet.dart`، `session/movement_session_screen.dart` (30.7KB)، `session/session_shell.dart` (19.8KB)، `session/session_template.dart`، `session/session_widgets.dart`، `session/open_session.dart`، `session/session_template_router.dart`، `session/session_surface.dart`، `session/movement_session_notifier.dart`، `session/templates/` (پوشه)، `widgets/` (پوشه)

پوشهٔ `movement/domain/`:
`movement_suggester.dart` (17.4KB)، `movement_budget.dart`، `movement_kind.dart`، `week_slot_resolver.dart`، `week_plan_item.dart`، `movement_campaign.dart`، `endurance_progression.dart`، `movement_plan_writer.dart`، `movement_event.dart`، `session_mode.dart`، `movement_slot_override.dart`، `movement_reminder_defaults.dart`، `movement_session.dart`

پوشهٔ `movement/data/`:
`unified_planner_repository.dart`، `movement_reminder_service.dart`

**مستنا — حتماً نگه دار:** `movement/data/seed/movement_kinds_seed.dart` و جدول `movement_kinds`. این‌ها منبع حقیقت ۴۹ نوع ورزشی هستند. حذف آن تحت هر شرایطی ممنوع است.

**پذیرش:** `flutter analyze` پاک؛ `flutter test` کامل سبز؛ `rg -n "movement/presentation" lib/ | wc -l` → صفر.

**دستور تأیید:** `flutter analyze && flutter test`

---

### - [ ] S6-T10 — حذف دوگانگی موتورها و مخازن تکراری

**فهرست دقیق:**

| یتیم/تکراری | جایگزین زنده |
| --- | --- |
| `data/repositories/ss_plan_generator.dart` | `domain/engines/plan_engine.dart` |
| `data/repositories/ss_program_builder.dart` | `domain/engines/plan_engine.dart` |
| `data/repositories/ss_prescription_repository.dart` | `data/repositories/mv_prescription_repository.dart` |
| `data/repositories/ss_session_repository_impl.dart` | `data/repositories/mv_session_repository.dart` |
| `data/repositories/ss_compensation_service.dart` | `domain/engines/substitution_engine.dart` |
| `domain/ss_readiness_service.dart` | `domain/engines/readiness_engine.dart` |
| `domain/ss_adaptive_scheduler.dart` | `domain/engines/adaptation_engine.dart` |
| `domain/ss_agenda_source.dart` | `application/mv_hub_controller.dart` |
| `domain/ss_week_resolver.dart` | `domain/engines/plan_engine.dart` |
| `domain/ss_program_calendar.dart` | `domain/models/mv_calendar.dart` |
| `domain/ss_session_completion_gateway.dart` | `application/mv_finish_session_use_case.dart` |
| `domain/prescription/` (پوشه) | `data/repositories/mv_prescription_repository.dart` |

**مستنا — حتماً نگه دار:** `data/seed/ss_exercise_animation_map.dart` (28KB) و `data/seed/ss_exercise_farsi_names.dart` (43KB). این دو پشتوانهٔ ۳۲۱ انیمیشن و ۸۰۴ نام فارسی هستند.

**پذیرش:** `flutter analyze` پاک؛ تمام تست‌ها سبز؛ هر دو فایل seed موجود.

**دستور تأیید:** `flutter analyze && flutter test && test -s lib/features/supplementary_sports/data/seed/ss_exercise_animation_map.dart`

---

## ۱۲. اسپرینت S7 — تحویل و گزارش پایانی

### - [ ] S7-T1 — گزارش نهایی

**فایل جدید:** `docs/movement/SPORTS_V2_REPORT.md`

**دقیقاً این ۸ بخش را بنویس (نه کمتر، نه بیشتر):**
1. جدول همهٔ تسک‌ها با وضعیت نهایی و هش کامیت
2. فهرست مایگریشن‌های افزوده‌شده با شمارهٔ نسخه
3. فهرست فایل‌های حذف‌شده + مجموع کیلوبایت
4. فهرست فایل‌های جدید + تعداد خط
5. جدول همهٔ گاردتست‌ها با وضعیت پاس/فیل
6. اعداد تعریف تمام‌شده (§۱۴) با مقدار واقعی اندازه‌گیری‌شده
7. فهرست تسک‌های `BLOCKED` با دلیل دقیق و چیزی که از کاربر لازم است
8. فهرست انحرافات از این پرامپت (کپی از §۱۶)

**دستور تأیید:** `flutter analyze && flutter test && dart format --set-exit-if-changed lib/features/supplementary_sports test/unit/sports`

---

### - [ ] S7-T2 — پایان اجرا

**کار:**
1. مطمئن شو همهٔ چک‌باکس‌های این فایل یا `[x]` هستند یا در §۱۶ به‌عنوان `BLOCKED` ثبت شده‌اند.
2. جدول §۱۳ را کامل کن.
3. یک pull request با عنوان `feat(sports): anchor-and-filler architecture for supplementary sports` باز کن، بدنه = خلاصهٔ `SPORTS_V2_REPORT.md`.
4. در همان PR فهرست تسک‌های BLOCKED را جداگانه بنویس.
5. توقف. هیچ کار دیگری شروع نکن.

**دستور تأیید:** `flutter analyze && flutter test`

---

## ۱۳. دفتر پیشرفت (همین جدول را پر کن)

> پس از هر تسک، ردیف مربوطه را پر کن. ردیف را حذف نکن و ترتیب را عوض نکن.

| کد تسک | وضعیت | کامیت | یادداشت |
| --- | --- | --- | --- |
| S-INIT-1 | DONE | c53234b5 | ایجاد شاخهٔ feat/sports-v2-anchor-filler از main |
| S-INIT-2 | DONE | c53234b5 | مطالعهٔ کامل ۷ سند پایه |
| S-INIT-3 | DONE | c53234b5 | ساخت فایل لاگ docs/movement/IMPLEMENTATION_LOG.md |
| S-INIT-4 | DONE | c53234b5 | نسخه اسکیما v123 ثبت شد (مایگریشن‌های جدید از v124) |
| S0-T1 | DONE | b3021b27 | افزودن overallFeeling و note به مدل MvSession و مایگریشن v124 |
| S0-T2 | DONE | e5de0795 | یکسان‌سازی کدهای kindCode به UPPER_SNAKE_CASE و گاردتست |
| S0-T3 | DONE | 141df7a2 | محاسبهٔ واقعی هفته‌های پیوسته و بازگشت null در صورت عدم سابقه |
| S0-T4 | DONE | 1715480d | پیاده‌سازی فرمول معادل متوسط WHO و MET در BudgetEngine |
| S0-T5 | DONE | 57fc6a03 | محاسبهٔ بودجهٔ فعالیت محدود به هفتهٔ تقویمی جاری |
| S0-T6 | DONE | 7cd729e7 | ورودی‌های خواب و انرژی و هندلینگ پیش‌فرض آمادگی |
| S0-T7 | DONE | a8fccd93 | نمایش MvInsufficientData در تب پیشرفت هنگام خالی بودن مخازن |
| S0-T8 | DONE | 2b35fa8e | تست جامع Golden Path Phase A و تأیید کامل تست‌های اسپرینت ۰ |
| S1-T1 | DONE | aa56104b | پیاده‌سازی مدل کامل و ایمیوتبل MvMovementKind و لیست آلیاس‌ها |
| S1-T2 | DONE | 97aa213b | ایجاد مخزن MvKindRepository با متدهای جستجو و سابقه و فیلتر |
| S1-T3 | DONE | 5e0c48ca | حذف کامل MvMovementFamily و یکپارچه‌سازی با MovementFamily |
| S1-T4 | DONE | 347ced07 | افزودن sport و outdoor به MvSlotType و شرط اجباری بودن kindCode |
| S1-T5 | DONE | f3120fbd | شیت انتخاب کامل ۴۹ ورزش با جستجوی ۲۵۰ میلی‌ثانیه و بخش فصلی |
| S1-T6 | DONE | 36558b58 | اتصال شیت انتخاب ورزش به ثبت سریع با ۴ چیپ اخیر و bumpUsage |
| S1-T7 | DONE | a57aab8d | اتصال شیت برنامه روز به انتخابگر ورزش با ۷ فیلد و شرط مکان و تمرکز عضلانی |
| S1-T8 | DONE | cd539920 | افزودن تب انواع ورزش به کتابخانه و شیت ساخت ورزش سفارشی جدید |
| S1-T9 | DONE | 975f32dc | افزودن گاردتست‌های اعتبار seed برای kindCode و پاکسازی لیترال‌های presentation |
| S2-T1 | DONE | 3a053ac2 | ایجاد جدول mv_commitments، مایگریشن v125 و ایندکس idx_mv_commitments_day |
| S2-T2 | DONE | bf5a3ee2 | پیاده‌سازی مدل MvCommitment با متدهای occursOnWeek و nextOccurrenceAfter و اعتبارسنجی |
| S2-T3 | DONE | 9702cbef | پیاده‌سازی MvCommitmentRepository با عملیات کامل CRUD، getActive، upsert، deactivate و فیلتر روز |
| S2-T4 | DONE | 50d71ac9 | پیاده‌سازی ساخت تعهد از شیت برنامه روز و یوزکیس MvSaveCommitmentUseCase و تست‌های مربوطه |
| S2-T5 | DONE | 26d840fd | پیاده‌سازی سوال لنگر در آنبوردینگ با امکان ثبت تا ۳ تعهد و MvCommitmentUseCase |
| S2-T6 | DONE | 0226a0a4 | نمایش نشانگرهای قفل و ساعت در کارت اسلات، نوار یادآوری فردا در تب امروز، آیکون ریل هفته، و بانر تعارض پشت‌سرهم |
| S2-T7 | DONE | ff7a21e8 | پیاده‌سازی اکشن این هفته لغو شد، ثبت در movement_slot_overrides، جبران دقایق، و پیشنهاد غیرفعالسازی |
| S2-T8 | DONE | 1df734f2 | پیاده‌سازی ۶ تست حیاتی لنگر و تعهدات شامل بازه ۴ هفته، انجماد انعطاف‌ناپذیر، پنجره جابجایی، استراحت بعد از جلسه دوگانه، پاکسازی آینده و انقضا |
| S3-T1 | DONE | ca53f5c2 | ایجاد جدول mv_kind_profile، مایگریشن v126 و seed قطعی پروفایل ۴۹ ورزش با ریکاوری و عضلات درگیر |
| S3-T2 | DONE | 0ee12ae5 | پیاده‌سازی مدل ایمیوتبل MvKindProfile و مخزن MvKindProfileRepository همراه متدهای getByCode و getMapByCodes و تست‌های مربوطه |
| S3-T3 | DONE | dbb21119 | افزودن فیلدهای reasonKey و reasonParams به MvSlot و MvDecision، کلاس کمکی MvReasonKeys، و گاردتست عدم مقدار null برای reasonKey |
| S3-T4 | DONE | 47ab1859 | پیاده‌سازی متد generateWeek و مرحله ۱ ANCHORS در PlanEngine و جانمایی اسلات‌های قفل‌شده لنگر با زمان دقیق و نوع ورزش |
| S3-T5 | DONE | 2a339dfd | پیاده‌سازی مرحله ۲ HARD_LIMITS در PlanEngine، فیلتر فصل و محدودیت‌های جسمی و معافیت لنگرها با یادداشت |
| S3-T6 | DONE | 2ebdd84c | پیاده‌سازی مرحله ۳ ADJACENCY در PlanEngine طبق قواعد قطعی ADJ-1 تا ADJ-7 شامل تحرک قبل و ریکاوری بعد و تعارض لنگرهای متوالی |
| S3-T7 | DONE | 838d3f20 | پیاده‌سازی مرحله ۴ FILL با سقف رشد و اولویت ۲ روز قدرتی و جبران کسری فعالیت معادل متوسط |
| S3-T8 | DONE | 64b8bba2 | پیاده‌سازی مرحله ۵ COMPLEMENT برای تمرکز قدرتی پشتیبان لنگرها با reasonKey = mv_reason_complement |
| S3-T9 | DONE | a0c9e048 | پیاده‌سازی مرحله ۶ FALLBACK با گارد ۱۰ دقیقه حداقل مؤثر و پاس‌شدن تست ۸ پروفایل حاد |
| S3-T10 | DONE | e8163245 | پیاده‌سازی سویت ۳ مسیر طلایی سرتاسری و تأیید کامل اجرای شش مرحله PlanEngine |
| S4-T1 | DONE | 0a51fa65 | مایگریشن v127 برای ۷ ستون متریک جلسه در movement_sessions و ایندکس نوع ورزش و تاریخ |
| S4-T2 | DONE | 30672336 | افزودن ۷ فیلد متریک به MvSession با تبدیل toMap/fromMap و گترهای محاسباتی sessionLoad و paceSecPerKm |
| S4-T3 | DONE | 81dd2655 | پورت ۵ قالب پلیر (timed, distance, route, laps, match) با رابط تعاملی و ویجت تست کامل |
| S4-T4 | DONE | f5fa60b7 | پیاده‌سازی متد resolveSessionMode در MvStartSessionUseCase و تست جدولی ۸ ورزش و گاردتست معماری |
| S4-T5 | DONE | 31272444 | صفحه پایان جلسه با نمایش متریک‌های اختصاصی هر مود، انتخاب ۳ سطحی تلاش و اسلایدر RPE و تأثیر هفتگی |
| S4-T6 |  |  |  |
| S4-T7 |  |  |  |
| S4-T8 |  |  |  |
| S5-T1 |  |  |  |
| S5-T2 |  |  |  |
| S5-T3 |  |  |  |
| S5-T4 |  |  |  |
| S5-T5 |  |  |  |
| S5-T6 |  |  |  |
| S5-T7 |  |  |  |
| S6-T1 |  |  |  |
| S6-T2 |  |  |  |
| S6-T3 |  |  |  |
| S6-T4 |  |  |  |
| S6-T5 |  |  |  |
| S6-T6 |  |  |  |
| S6-T7 |  |  |  |
| S6-T8 |  |  |  |
| S6-T9 |  |  |  |
| S6-T10 |  |  |  |
| S7-T1 |  |  |  |
| S7-T2 |  |  |  |

---

## ۱۴. تعریف تمام‌شده، فقط با عدد

این ۱۲ عدد را در گزارش پایانی اندازه‌گیری و ثبت کن. هر کدام که برقرار نیست → کار تمام نشده.

| # | معیار | مقدار هدف |
| --- | --- | --- |
| ۱ | نوع ورزش قابل انتخاب در UI | ≥ ۴۹ |
| ۲ | حالت پلیر پیاده‌شده | ۷ از ۷ |
| ۳ | فیلد گم‌شده در `MvSession.toMap` | ۰ |
| ۴ | `kindCode` هاردکد در موتور/کاربرد | ۰ |
| ۵ | رشتهٔ فارسی خام در `presentation/` | ۰ |
| ۶ | `fontSize:` خام در فیچر | ۰ |
| ۷ | گاردتست فعال | ≥ ۱۲ |
| ۸ | درصد اسلات‌های دارای `reasonKey` | ۱۰۰٪ |
| ۹ | پروفایل حاد با برنامهٔ خالی | ۰ از ۲۰ |
| ۱۰ | ردیف `PENDING` در `PORT_LEDGER.md` | ۰ |
| ۱۱ | ردیف جدول تطبیق F | ۵۰ از ۵۰ |
| ۱۲ | خروجی `flutter analyze` | ۰ issue |

---

## ۱۵. چیزهایی که مطلقاً نباید ساخته شود

اگر وسوسه شدی یکی از این‌ها را بسازی، نساز و در §۱۶ بنویس که چرا وسوسه شدی:

1. ردیاب GPS، نقشه، یا مسیر زنده
2. هر قابلیت اجتماعی: دعوت، تیم، حضور، چت، جدول رده‌بندی
3. تب چهارم در هاب
4. اتصال به ساعت هوشمند، HealthKit، Google Fit، یا نوار قلب
5. موتور جدید خارج از فهرست §۱۱ S6-T5
6. جدول دیتابیس خارج از `mv_commitments`، `mv_kind_profile`، `mv_routes`
7. تخمین کالری، VO2max، یا هر عدد فیزیولوژیک دیگری
8. متن تشخیصی، درمانی، یا ادعای پیشگیری از آسیب
9. فراخوانی مدل زبانی در مسیر تولید برنامه (موتورها قطعی و قابل تست باقی می‌مانند)
10. تغییر معماری خارج از تصمیم‌های §۳

---

## ۱۶. انحرافات و تسک‌های مسدود (فقط تو این را پر می‌کنی)

> قالب اجباری هر ردیف. اگر جدول خالی بماند یعنی هیچ انحرافی رخ نداده.

| کد تسک | نوع (BLOCKED / DEVIATION) | چه چیزی طبق پرامپت ممکن نشد | دلیل فنی | چه تصمیمی از کاربر لازم است |
| --- | --- | --- | --- | --- |
|  |  |  |  |  |

---

## ۱۷. ضمیمه — فهرست کامل کلیدهای l10n که این اجرا می‌سازد

همهٔ کلیدها با پیشوند `mv_`. در فایل arb فارسی بنویس. کلید خارج از این فهرست فقط وقتی مجاز است که یک رشتهٔ موجود را استخراج کرده باشی.

**انتخابگر نوع ورزش:** `mv_kind_picker_title`, `mv_kind_picker_search_hint`, `mv_kind_picker_recent`, `mv_kind_picker_seasonal`, `mv_kind_picker_all`, `mv_kind_picker_create_custom`, `mv_kind_picker_empty`

**نوع سفارشی:** `mv_custom_kind_title`, `mv_custom_kind_name`, `mv_custom_kind_family`, `mv_custom_kind_metric`, `mv_custom_kind_intensity`, `mv_custom_kind_saved`

**لنگر:** `mv_onboarding_anchor_title`, `mv_onboarding_anchor_add`, `mv_onboarding_anchor_skip`, `mv_commitment_saved`, `mv_commitment_repeat_weekly`, `mv_commitment_venue`, `mv_commitment_partner`, `mv_anchor_cancelled_this_week`, `mv_anchor_suggest_deactivate`, `mv_anchor_constraint_note`, `mv_tomorrow_anchor_notice`, `mv_conflict_back_to_back`

**دلایل اسلات:** `mv_reason_anchor`, `mv_reason_pre_anchor_taper`, `mv_reason_post_anchor_recovery`, `mv_reason_complement`, `mv_reason_who_gap`, `mv_reason_strength_quota`, `mv_reason_rest_guaranteed`, `mv_reason_readiness_low`, `mv_reason_load_cap`, `mv_reason_fallback_minimum`, `mv_reason_season_fit`, `mv_reason_constraint_relaxed`

**متریک و تلاش:** `mv_metric_distance`, `mv_metric_elevation`, `mv_metric_laps`, `mv_metric_pack_weight`, `mv_metric_duration`, `mv_effort_question`, `mv_effort_easy`, `mv_effort_good`, `mv_effort_hard`, `mv_effort_refine`, `mv_new_personal_record`

**بار و بودجه:** `mv_load_band_low`, `mv_load_band_optimal`, `mv_load_band_watch`, `mv_load_band_spike`, `mv_budget_moderate_minutes`, `mv_budget_strength_days`, `mv_budget_remaining`

**دادهٔ ناکافی:** `mv_streak_insufficient`, `mv_readiness_no_checkin`, `mv_need_n_more_sessions`, `mv_insufficient_data_generic`

**بینش:** `mv_insight_best_day`, `mv_insight_anchor_adherence`, `mv_insight_effort_drift`, `mv_insight_kind_mix`, `mv_insight_route_progress`

**دورهٔ هدف‌دار:** `mv_campaign_title`, `mv_campaign_target_date`, `mv_campaign_phase_base`, `mv_campaign_phase_build`, `mv_campaign_phase_taper`, `mv_campaign_too_short`

**مسیر:** `mv_route_select`, `mv_route_new`, `mv_route_times_done`, `mv_route_best_time`

**عمومی صفحه‌ها:** `mv_day_plan_title`, `mv_library_title`, `mv_week_plan_title`, `mv_library_tab_kinds`, `mv_library_tab_exercises`

---

## ۱۸. پیام آخر به ایجنت اجراکننده

تو قرار نیست معمار باشی. معماری در §۲ تا §۴ قفل شده.

تو قرار نیست برنامه‌ریز باشی. برنامه در §۵ تا §۱۲ نوشته شده.

کار تو دقیقاً این است: اولین چک‌باکس خالی را پیدا کن، متن همین تسک را کامل بخوان، فقط همان را پیاده کن، دستور تأییدش را اجرا کن، کامیت بزن، تیک بزن، دفتر را پر کن، برو سر بعدی.

اگر جایی مبهم بود، حدس نزن. `BLOCKED` بزن، در §۱۶ بنویس، و برو سر تسک بعدی مستقل.

از `S-INIT-1` شروع کن. الان.
