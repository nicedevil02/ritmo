# قرارداد اجرای اصلاحی — اسپرینت S8 «اتصال به کاربر»

- **نسخه:** ۱٫۰
- **تاریخ:** ۱۴۰۵/۰۶/۰۴ (2026-08-26)
- **شاخهٔ اجباری:** `fix/sports-v2-wiring`
- **پیش‌نیاز:** کامیت `08831ee` روی `main` (مرج «sports v2 anchor filler»)
- **این فایل جانشین `RITMO_SPORTS_V2_EXECUTION_PROMPT.md` نیست — مکمل آن است.**

---

## ۰. چرا این فایل وجود دارد — بخوان و تکرار نکن

اسپرینت‌های S0 تا S7 اجرا شدند. مدل‌ها، مخازن، مایگریشن‌ها، موتورها و شیت‌ها ساخته شدند و تست‌ها سبز شدند. **اما کاربر هیچ تغییری نمی‌بیند.**

علت با شاهد کد:

| # | شاهد | فایل | پیامد برای کاربر |
| :-- | :-- | :-- | :-- |
| E-01 | هیچ دکمه، آیکون یا منویی برای ساخت «لنگر» در کل اپ وجود ندارد | `mv_hub_screen.dart` (سه اکشن: کتابخانه، مربی، تنظیمات) | جدول `mv_commitments` برای همیشه خالی می‌ماند |
| E-02 | تنها محل پرسش لنگر، آنبوردینگ است و آنبوردینگ پشت گیت `if (!profile.onboardingCompleted)` قفل است | `mv_hub_screen.dart` | کاربر فعلی که آنبوردینگ را رد کرده، **هرگز** به آن نمی‌رسد |
| E-03 | `MvSettingsScreen` هیچ اشاره‌ای به تعهد/لنگر ندارد | `mv_settings_screen.dart` (فقط روز، مدت، شدت، آپارتمان، صدا، چرخه) | راه دوم هم بسته است |
| E-04 | چون لنگری ساخته نمی‌شود، `_placeAnchors()` همیشه لیست خالی می‌گیرد | `PlanEngine` | خروجی `PlanEngine v2` عیناً برابر v1 است — **هفته دقیقاً مثل قبل** |
| E-05 | `MvWeekTab(cycleWeek: 1)` عدد ثابت پاس داده شده | `mv_hub_screen.dart` | شمارندهٔ هفته هرگز جلو نمی‌رود |
| E-06 | `MvProgressTab` فقط ۵ پارامتر قدیمی می‌گیرد؛ نه بار تمرینی، نه بینش، نه دوره، نه ترکیب ورزش | `mv_hub_screen.dart` | `LoadEngine`، `InsightEngine`، `CampaignEngine` ساخته شدند ولی خروجی‌شان به هیچ پیکسلی نمی‌رسد |
| E-07 | `MvKindPickerSheet` فقط از یک مسیر باز می‌شود: تب امروز ← ثبت سریع ← تراشهٔ «بیشتر...» | `mv_quick_log_sheet.dart` | ۴۹ ورزش فقط برای **ثبت گذشته** است، نه **برنامه‌ریزی آینده** — یعنی خواستهٔ اصلی محصول اجرا نشده |
| E-08 | رشته‌های فارسی هاردکد سر جایشان هستند: `'ورزش و حرکت'`، `'کتابخانهٔ حرکات'`، `'امروز'`، `'هفته'`، `'پیشرفت'`، `'برنامهٔ هفتگی (هفتهٔ $cycleWeek)'`، `'تنظیمات ورزشی'` | `mv_hub_screen.dart`, `mv_week_tab.dart`, `mv_settings_screen.dart` | ادعای S6-T1 و گارد l10n نادرست است |
| E-09 | `TextStyle(fontSize: 14)`, `fontSize: 20`, `fontSize: 10`, `size: 20` خام | `mv_quick_log_sheet.dart`, `mv_week_tab.dart` | ادعای S6-T2 نادرست است |
| E-10 | گاردهای گزارش‌شده (G-01..G-12) با گاردهای تعریف‌شده در S6-T3 پرامپت اصلی **هیچ انطباقی ندارند** | `SPORTS_V2_REPORT.md` §۵ | گاردها بازتعریف شده‌اند تا سبز شوند |
| E-11 | گزارش می‌گوید «BLOCKED: ۰ مورد» ولی کامیت `dc048a8` می‌گوید `S5-T5 ... (BLOCKED missing seed data)` | `SPORTS_V2_REPORT.md` §۳ | گزارش با تاریخچهٔ کامیت خودش در تناقض است |

**تشخیص یک‌جمله‌ای:** لوله‌کشی کامل شد، اما شیر آب به هیچ دیواری وصل نشد. معیار پذیرش اسپرینت‌های قبلی «فایل ساخته شد + یونیت‌تست سبز شد» بود، نه «کاربر می‌تواند به آن برسد». تو دقیقاً همان چیزی را بهینه کردی که اندازه‌گیری می‌شد.

---

## ۰٫۱ قوانین سخت این اسپرینت

1. **نقشهٔ پیاده‌سازی ننویس.** نه roadmap، نه RFC، نه ADR، نه فایل plan. همین فایل نقشه است.
2. **معیار پذیرش عوض شده.** از این به بعد یک تسک فقط وقتی `[x]` می‌خورد که یک **ویجت‌تست** ثابت کند کاربر با شروع از `MvHubScreen` و با تعداد ضربهٔ مشخص به آن قابلیت می‌رسد. یونیت‌تست سبز به‌تنهایی کافی نیست و پذیرفته نمی‌شود.
3. **کد جدید حداقلی بنویس.** تقریباً همه چیز از قبل ساخته شده. کار تو ۹۰٪ «سیم‌کشی» است: پاس‌دادن پارامتر، افزودن دکمه، افزودن مسیر ناوبری. اگر خودت را در حال نوشتن یک موتور جدید دیدی، متوقف شو — احتمالاً آن موتور از قبل هست.
4. **هیچ فایلی را بازنویسی نکن.** فقط ویرایش هدفمند.
5. **ترتیب اجباری است:** `S8-T1` تا `S8-T14` به ترتیب.
6. **پروتکل بعد از هر تسک (چهار مرحله، بدون استثنا):**
   1. دستور تأیید همان تسک را اجرا کن.
   2. کامیت با فرمت `fix(sports): S8-T<n> <خلاصه>`.
   3. در **همین فایل** `- [ ]` را به `- [x] — <hash کوتاه>` تبدیل کن.
   4. یک ردیف به `docs/movement/IMPLEMENTATION_LOG.md` اضافه کن.
7. **دو بار شکست پیاپی = `BLOCKED`.** در §۴ بنویس و برو تسک بعدی. حدس نزن.
8. **گزارش صادق.** در S8-T14 اگر چیزی کار نکرد، بنویس کار نکرد. گزارش خوش‌بینانهٔ قبلی تکرار نشود.
9. **ممنوع:** بازتعریف گاردتست‌ها برای سبز شدن. اگر گاردی قرمز است، **کد** را درست کن نه **گارد** را.
10. **صفر رشتهٔ فارسی هاردکد جدید.** هر متن جدید از `AppLocalizations` می‌آید.

## ۰٫۲ گیت کیفیت (قبل از هر کامیت)

```
flutter analyze --no-fatal-infos
flutter test
```

هر دو باید سبز باشند. کامیت شکسته ممنوع.

---

## ۱. تصمیم‌های قفل‌شده (بحث تمام است)

| کد | تصمیم |
| :-- | :-- |
| W-A | مدیریت لنگر یک **صفحهٔ مستقل** می‌شود: `mv_commitments_screen.dart`. نه شیت، نه بخشی از تنظیمات. |
| W-B | ورودی اصلی لنگر: آیکون قفل در `AppBar` هاب، **آخرین اکشن**. ورودی دوم: کارت دعوت در تب هفته. ورودی سوم: ردیف در تنظیمات. هر سه اجباری. |
| W-C | آنبوردینگ دوباره اجرا نمی‌شود. به‌جای آن، کاربر فعلی از طریق W-B لنگر می‌سازد. |
| W-D | انتخابگر ورزش (`MvKindPickerSheet`) باید از **مسیر برنامه‌ریزی** هم باز شود، نه فقط ثبت سریع. مسیر: تب هفته ← کارت روز ← `MvDayPlanSheet` ← «تغییر نوع ورزش». |
| W-E | `MvProgressTab` امضایش عوض می‌شود و `MvLoadSnapshot?`، `List<MvInsight>`، `MvCampaign?` و `Map<String,int>` ترکیب ورزش را می‌گیرد. مقدار `null` یعنی «دادهٔ ناکافی» و باید `MvInsufficientData` نمایش داده شود، نه عدد صفر. |
| W-F | `cycleWeek` از `MvHubController` می‌آید، نه عدد ثابت. |
| W-G | هیچ تب جدیدی ساخته نمی‌شود. هیچ صفحهٔ جدیدی جز `mv_commitments_screen.dart` و `mv_commitment_edit_sheet.dart` ساخته نمی‌شود. |

---

## ۲. تسک‌ها

### - [x] S8-T1 — کنترلر: بارگذاری و انتشار لنگرها — fa94daa7

**فایل:** `lib/features/supplementary_sports/application/mv_hub_controller.dart`

1. فیلد `List<MvCommitment> commitments = const []` اضافه کن.
2. در `loadAllData()` با `MvCommitmentRepository().getActive()` پرش کن.
3. فیلد `int cycleWeek` اضافه کن و از `MvCalendar` محاسبه کن (هفتهٔ جاری از `profile.programStartDateIso`؛ اگر null بود مقدار `1`).
4. مطمئن شو `regenerateWeek()` این `commitments` را به `PlanEngine.generateWeek(commitments: ...)` پاس می‌دهد. **اگر از قبل پاس می‌دهد، دست نزن و فقط در لاگ بنویس «از قبل متصل بود».**
5. متد `Future<void> saveCommitment(MvCommitment c)` و `Future<void> deleteCommitment(int id)` اضافه کن که بعد از نوشتن، `regenerateWeek()` را صدا بزند.

**تأیید:** `flutter test test/unit/sports/mv_commitment_test.dart`

---

### - [x] S8-T2 — شیت ساخت و ویرایش لنگر — 47253578

**فایل جدید:** `lib/features/supplementary_sports/presentation/sheets/mv_commitment_edit_sheet.dart`

فیلدهای فرم، دقیقاً همین‌ها و به همین ترتیب:

| فیلد | ویجت | اجباری | پیش‌فرض |
| :-- | :-- | :-- | :-- |
| نوع ورزش | تراشه + دکمهٔ «بیشتر...» که `MvKindPickerSheet` را باز می‌کند | بله | — |
| عنوان | `TextField` | خیر | `titleFa` نوع انتخاب‌شده |
| روز هفته | هفت تراشه، شنبه=۰ | بله | — |
| ساعت شروع | `TimePicker` | بله | ۱۸:۰۰ |
| مدت (دقیقه) | تراشه‌های ۳۰/۴۵/۶۰/۹۰/۱۲۰ | بله | ۶۰ |
| تکرار | تراشه: هفتگی / دوهفته‌یک‌بار / یک‌بار | بله | هفتگی |
| محل | `TextField` | خیر | خالی |
| یادآوری | تراشه: بدون / ۳۰ دقیقه / ۲ ساعت / ۱ روز | خیر | ۲ ساعت |

دکمهٔ حذف فقط در حالت ویرایش. از `MvSheetScaffold` استفاده شود.

**تأیید:** `flutter analyze` سبز + شیت از تست T3 باز شود.

---

### - [x] S8-T3 — صفحهٔ مدیریت لنگرها — 0f6b9b85

**فایل جدید:** `lib/features/supplementary_sports/presentation/screens/mv_commitments_screen.dart`

- `AppBar` با عنوان از l10n کلید `mv_commitments_title`.
- اگر لیست خالی است: `MvInsufficientData` با متن کلید `mv_commitments_empty` و دکمهٔ «افزودن ورزش ثابت».
- اگر پر است: کارت به‌ازای هر تعهد شامل ایموجی نوع، عنوان، «هر <روز> ساعت <ساعت>»، مدت، و سوییچ `isActive`.
- `FloatingActionButton` برای افزودن.
- ضربه روی کارت ← `MvCommitmentEditSheet` در حالت ویرایش.

**تأیید:** `flutter test test/widget/sports/mv_commitments_screen_test.dart` — تست باید ثابت کند حالت خالی و حالت پر هر دو رندر می‌شوند.

---

### - [x] S8-T4 — سه ورودی اجباری به صفحهٔ لنگر — 7ed80f4c

1. **هاب:** در `mv_hub_screen.dart` یک `IconButton` با `Icons.lock_clock` و `key: ValueKey('mv_open_commitments')` به‌عنوان **آخرین** اکشن `AppBar` اضافه کن.
2. **تب هفته:** اگر `commitments.isEmpty`، یک کارت دعوت بالای هفت کارت روز با کلید `mv_week_anchor_cta` و متن l10n `mv_week_anchor_cta_text` نمایش بده که به همان صفحه می‌رود.
3. **تنظیمات:** در `mv_settings_screen.dart` بخش جدید «ورزش‌های ثابت» با یک `ListTile` که به همان صفحه می‌رود.

**تأیید:** `flutter test test/widget/sports/mv_anchor_reachability_test.dart` — سه تست جدا، هرکدام از `MvHubScreen` شروع می‌کند و به `MvCommitmentsScreen` می‌رسد.

---

### - [x] S8-T5 — نمایش لنگرها در تب هفته و امروز — f5dc8023

1. `MvWeekTab` پارامتر `List<MvCommitment> commitments` بگیرد.
2. `MvDaySlotCard` برای اسلات لنگردار: آیکون قفل، ساعت، و نام محل زیر عنوان.
3. تب امروز: اگر فردا لنگر دارد، نوار اطلاع با کلید `mv_tomorrow_anchor_notice`.
4. `cycleWeek` از کنترلر پاس داده شود (رفع E-05).

**تأیید:** `flutter test test/widget/sports/mv_week_anchor_render_test.dart`

---

### - [x] S8-T6 — انتخاب نوع حرکت در شیت برنامه‌ریزی روز — b9dce612(رفع E-07)

**فایل:** `mv_day_plan_sheet.dart`

- ردیف «نوع ورزش» با تراشهٔ نوع فعلی + دکمهٔ «تغییر» که `MvKindPickerSheet` را باز می‌کند.
- بعد از انتخاب، `slot.kindCode` به‌روز شود و `slotType` طبق نگاشت خانواده (`SPORT→sport`, `OUTDOOR→outdoor`, `ENDURANCE→cardio`, `STRENGTH→strength`, `MIND_BODY→mobility`, `MARTIAL_SKILL→sport`, `DAILY→activeRest`) تنظیم شود.

**تأیید:** `flutter test test/widget/sports/mv_plan_kind_change_test.dart` — تست ثابت کند از هاب، تب هفته، کارت روز، تغییر نوع به `HIKING` ممکن است و ذخیره می‌شود.

---

### - [x] S8-T7 — اتصال `LoadEngine` به تب پیشرفت (رفع E-06 بخش اول) — 786cbdcc

1. در `MvHubController` فیلد `MvLoadSnapshot? loadSnapshot` اضافه کن و در `loadAllData()` از `LoadEngine` پرش کن.
2. `MvProgressTab` پارامتر `MvLoadSnapshot? loadSnapshot` بگیرد.
3. کارت «بار تمرینی»:
   - اگر `loadSnapshot == null` → `MvInsufficientData` با متن `mv_need_n_more_sessions`. **عدد صفر یا نمودار خالی نشان نده.**
   - وگرنه نسبت `ratio` با یکی از چهار کلید `mv_load_band_low|optimal|watch|spike` و نوار رنگی از توکن‌ها.

**تأیید:** `flutter test test/widget/sports/mv_progress_load_card_test.dart` — دو حالت: دادهٔ ناکافی و دادهٔ کافی.

---

### - [x] S8-T8 — اتصال `InsightEngine` به تب پیشرفت (رفع E-06 بخش دوم) — 15fe6ce2

1. در `MvHubController` فیلد `List<MvInsight> insights = const []` اضافه کن و از `InsightEngine` پر کن.
2. `MvProgressTab` آن را بگیرد و زیر کارت‌ها رندر کند.
3. اگر لیست خالی است، **هیچ چیز نشان نده.** جملهٔ عمومی جایگزین ممنوع است.
4. فقط پنج کلید مجازند: `mv_insight_best_day`, `mv_insight_anchor_adherence`, `mv_insight_effort_drift`, `mv_insight_kind_mix`, `mv_insight_route_progress`.

**تأیید:** `flutter test test/widget/sports/mv_progress_insights_test.dart`

---

### - [x] S8-T9 — ورودی دورهٔ هدف‌دار (`CampaignEngine`) — 91aed1a6

1. در تب پیشرفت، کارت «دورهٔ هدف‌دار»:
   - اگر دورهٔ فعال نیست: دکمهٔ «ساخت دورهٔ تمرینی» با کلید `mv_campaign_create`.
   - اگر فعال است: نام هدف، فاز جاری، هفتهٔ n از m، و مقدار وزن پشتی این هفته.
2. فرم ساخت دوره در همان شیت `MvCommitmentEditSheet` نیاید؛ یک `AlertDialog` ساده با سه فیلد کافی است: نوع ورزش هدف، تاریخ هدف، وزن بدن.
3. اگر `weeksToGoal < 4` پیام `mv_campaign_too_short` نشان بده و ذخیره نکن.

**تأیید:** `flutter test test/unit/sports/mv_campaign_engine_test.dart` و `flutter test test/widget/sports/mv_campaign_entry_test.dart`

---

### - [x] S8-T10 — تأیید رسیدن واقعی به پنج قالب پلیر — d93dc28b

این تسک کد جدید نمی‌نویسد؛ **اثبات می‌کند**.

یک تست جدولی بنویس که برای هر ردیف، از `MvHubScreen` شروع کند، نوع اسلات امروز را عوض کند، تمرین را شروع کند، و اثبات کند قالب درست رندر شده:

| کد ورزش | قالب مورد انتظار | ویجت کلیدی که باید دیده شود |
| :-- | :-- | :-- |
| `HIKING` | `MvRouteTemplate` | فیلد صعود و وزن پشتی |
| `SWIMMING` | `MvLapsTemplate` | شمارندهٔ دور |
| `FUTSAL` | `MvMatchTemplate` | کرونومتر مسابقه |
| `RUNNING` | `MvDistanceTemplate` | فیلد مسافت |
| `STRETCHING` | `MvTimedTemplate` | تایمر ساده |

اگر هر ردیف قرمز شد، مسیر ناوبری `mv_start_session_use_case.dart` را درست کن تا سبز شود. تست را تضعیف نکن.

**تأیید:** `flutter test test/widget/sports/mv_player_template_routing_test.dart`

---

### - [x] S8-T11 — l10n واقعی با گاردی که واقعاً کار کند (رفع E-08) — d910b27f

1. همهٔ رشته‌های فارسی هاردکد در این چهار فایل را به `app_fa.arb` و `app_en.arb` منتقل کن:
   `mv_hub_screen.dart`, `mv_week_tab.dart`, `mv_settings_screen.dart`, `mv_quick_log_sheet.dart`.
2. گاردتست `test/guard/mv_no_hardcoded_persian_test.dart` بنویس که:
   - همهٔ فایل‌های `lib/features/supplementary_sports/presentation/**.dart` را بخواند.
   - با رجکس `RegExp(r"'[^']*[\u0600-\u06FF][^']*'")` دنبال رشتهٔ فارسی داخل کوتیشن بگردد.
   - لیست تخطی‌ها را با نام فایل و شمارهٔ خط چاپ کند و `expect(violations, isEmpty)`.
   - ایموجی و کد ورزش مجازند (لیست سفید).
3. **این گارد نباید تضعیف شود.** اگر قرمز ماند، رشته‌های بیشتری منتقل کن.

**تأیید:** `flutter test test/guard/mv_no_hardcoded_persian_test.dart`

---

### - [x] S8-T12 — توکن‌های طراحی (رفع E-09) — c45d9278

1. هر `fontSize:` خام در پوشهٔ `presentation/` را با سبک از `Theme.of(context).textTheme` جایگزین کن.
2. هر `size:` خام در آیکون‌ها را با `metrics.iconSm|iconMd|iconLg` جایگزین کن.
3. گاردتست `test/guard/mv_no_raw_typography_test.dart` بنویس که بر اساس رجکس `fontSize:\s*\d` در پوشهٔ presentation فیل شود.

**مرجع:** `docs/RITMO_DESIGN_TOKENS.md`

**تأیید:** `flutter test test/guard/mv_no_raw_typography_test.dart`

---

### - [ ] S8-T13 — گاردتست دسترس‌پذیری (مهم‌ترین تسک این اسپرینت)

**فایل جدید:** `test/guard/mv_reachability_guard_test.dart`

این گارد مانع تکرار این شکست در آینده می‌شود. برای هر قابلیت زیر، یک تست که از `MvHubScreen` شروع می‌کند:

| کد | قابلیت | حداکثر ضربه از هاب |
| :-- | :-- | :-- |
| R-01 | ساخت لنگر جدید | ۳ |
| R-02 | تغییر نوع ورزش یک روز برنامه | ۴ |
| R-03 | ثبت سریع با ورزش دلخواه | ۳ |
| R-04 | دیدن کارت بار تمرینی | ۱ |
| R-05 | ساخت دورهٔ هدف‌دار | ۲ |
| R-06 | شروع تمرین کوه‌نوردی با قالب مسیر | ۴ |

هر تست باید واقعاً `tester.tap` کند و `pumpAndSettle` بزند. موک‌کردن کل مسیر ممنوع است.

**تأیید:** `flutter test test/guard/mv_reachability_guard_test.dart`

---

### - [ ] S8-T14 — تصحیح گزارش و تحویل صادقانه

1. `docs/movement/SPORTS_V2_REPORT.md` را ویرایش کن:
   - جدول گاردها را با گاردهای **واقعی موجود در `test/guard/`** جایگزین کن. نام فایل هر گارد را بنویس.
   - در §۳ بنویس S5-T5 وضعیت `BLOCKED` دارد (مطابق کامیت `dc048a8`)، نه «DROPPED».
   - بخش جدید «وضعیت دسترس‌پذیری» با جدول R-01..R-06 و وضعیت واقعی هرکدام.
2. در `docs/movement/IMPLEMENTATION_LOG.md` یک بخش `## S8` با همهٔ ردیف‌ها.
3. در پیام پایانی دقیقاً بنویس: چند تسک `[x]`، چند تا `BLOCKED`، و کدام قابلیت‌ها هنوز از UI قابل دسترسی نیستند.

**تأیید:** `flutter test` کاملاً سبز + هر دو فایل مستند به‌روز.

---

## ۳. دفتر پیشرفت

| کد تسک | وضعیت | کامیت | یادداشت |
| :-- | :-- | :-- | :-- |
| S8-T1 | DONE | fa94daa7 | کنترلر: بارگذاری و انتشار لنگرها با cycleWeek و متدهای ذخیره/حذف |
| S8-T2 | DONE | 47253578 | شیت ساخت و ویرایش لنگر (MvCommitmentEditSheet) با ۸ فیلد و توکن‌های طراحی |
| S8-T3 | DONE | 0f6b9b85 | صفحهٔ مدیریت لنگرها (MvCommitmentsScreen) با حالت خالی و پر و FAB |
| S8-T4 | DONE | 7ed80f4c | اتصال ۳ ورودی اجباری به صفحهٔ لنگر (هاب، تب هفته، تنظیمات) |
| S8-T5 | DONE | f5dc8023 | نمایش لنگرها در تب هفته (MvDaySlotCard) و بنر فردا در تب امروز (MvTodayTab) |
| S8-T6 | DONE | b9dce612 | اتصال انتخابگر حرکت و جزئیات ورزش در MvDayPlanSheet |
| S8-T7 | DONE | 786cbdcc | اتصال LoadEngine به تب پیشرفت با محاسبه ACWR و مدیریت داده ناکافی |
| S8-T8 | DONE | 15fe6ce2 | اتصال InsightEngine به تب پیشرفت با رندر بینش‌های معتبر |
| S8-T9 | DONE | 91aed1a6 | ورودی و دیالوگ ساخت دورهٔ هدف‌دار بر مبنای CampaignEngine |
| S8-T10 | DONE | d93dc28b | تأیید مسیردهی ۵ قالب پلیر (Route, Laps, Match, Distance, Timed) از هاب |
| S8-T11 | DONE | d910b27f | پاک‌سازی کامل رشته‌های هاردکد در presentation و گاردتست mv_no_hardcoded_persian_test |
| S8-T12 | DONE | c45d9278 | پاک‌سازی کامل تایپوگرافی و اندازه‌های خام و گاردتست mv_no_raw_typography_test |
| S8-T13 | | | |
| S8-T14 | | | |

---

## ۴. انحرافات و تسک‌های مسدود (فقط تو این را پر می‌کنی)

| کد تسک | چه چیزی شکست خورد | دو تلاش چه بود | چه تصمیمی لازم است |
| :-- | :-- | :-- | :-- |
| | | | |

---

## ۵. تعریف تمام‌شده، فقط با عدد

این اسپرینت وقتی تمام است که همهٔ این اعداد برقرار باشند:

1. کاربری که قبلاً آنبوردینگ را تمام کرده، با **حداکثر ۳ ضربه** از هاب می‌تواند لنگر بسازد.
2. بعد از ساخت لنگر «فوتسال پنجشنبه ۲۱:۰۰»، تب هفته **قفل روی پنجشنبه** نشان می‌دهد.
3. پس از آن، چهارشنبه خودبه‌خود سبک می‌شود و جمعه ریکاوری می‌شود (خروجی `_applyAdjacency`).
4. ۶ تست دسترس‌پذیری R-01..R-06 سبزند.
5. ۰ رشتهٔ فارسی هاردکد در `presentation/`.
6. ۰ مقدار `fontSize:` خام در `presentation/`.
7. تب پیشرفت حداقل دو مورد از این سه را واقعاً رندر می‌کند: کارت بار، بینش، دوره.
8. `flutter analyze` و `flutter test` هر دو سبز.

---

## ۶. چیزهایی که مطلقاً نباید انجام شود

1. ساخت موتور جدید. همه از قبل هستند.
2. تغییر اسکیمای دیتابیس یا افزودن مایگریشن v129. نیازی نیست.
3. بازنویسی `PlanEngine`.
4. تضعیف یا حذف یک تست برای سبز شدن.
5. ساخت تب چهارم در هاب.
6. اجرای دوبارهٔ آنبوردینگ برای کاربر موجود.
7. حذف یا جابجایی فایل‌های موجود `mv_*`.
8. نوشتن گزارش خوش‌بینانه بدون شاهد تست.

---

## ۷. کلیدهای l10n جدید که این اسپرینت می‌سازد

`mv_commitments_title`, `mv_commitments_empty`, `mv_commitment_add`, `mv_commitment_edit`, `mv_commitment_delete`, `mv_commitment_day_label`, `mv_commitment_time_label`, `mv_commitment_duration_label`, `mv_commitment_recurrence_label`, `mv_commitment_venue_label`, `mv_commitment_reminder_label`, `mv_week_anchor_cta`, `mv_week_anchor_cta_text`, `mv_settings_anchors_section`, `mv_campaign_create`, `mv_campaign_active_phase`, `mv_plan_change_kind`, `mv_hub_title`, `mv_tab_today`, `mv_tab_week`, `mv_tab_progress`, `mv_library_tooltip`, `mv_coach_tooltip`, `mv_settings_tooltip`, `mv_week_title`, `mv_week_regenerate`

---

## ۸. پیام آخر به ایجنت اجراکننده

اسپرینت قبلی را خوب ساختی ولی وصل نکردی. این اسپرینت کوتاه است و تقریباً هیچ کد منطقی جدیدی ندارد — فقط پارامتر پاس بده، دکمه اضافه کن، و ثابت کن که کاربر می‌رسد.

معیار موفقیت این است: کاربر اپ را باز کند، برود به بخش ورزش، و **بدون اینکه کسی راهنمایی‌اش کند** بتواند بگوید «من پنجشنبه‌ها فوتسال دارم و جمعه‌ها کوه می‌روم» و برنامهٔ هفته خودش را دور این دو بچیند.

از `S8-T1` شروع کن. نقشهٔ جدید ننویس.
