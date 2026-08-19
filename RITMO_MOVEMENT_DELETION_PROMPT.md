# پرامپت حذف — پاک‌سازی سخت‌گیرانهٔ «ورزش تکمیلی» و «حرکت مرکزی»

> **این فایل قبل از `RITMO_MOVEMENT_MERGE_PROMPT.md` اجرا می‌شود.**
> کارِ این پرامپت ادغام نیست. کارِ این پرامپت **حذف** است.
> حجم تقریبی کدی که باید ناپدید شود: **حدود ۱٫۹ مگابایت Dart** (حدود ۱٫۴۸ مگابایت از `supplementary_sports` و حدود ۰٫۴۲ مگابایت از `movement`).
> هر بندی که با `D-xx` شماره‌گذاری شده، یک تصمیم قطعی است. تصمیم‌ها را دوباره باز نکن، وزن‌شان نکن، و برایشان جایگزین «موقت» نساز.

---

## ۰ — قوانین اجرا (غیرقابل مذاکره)

**۰-۱ — تو نقشه نمی‌نویسی.** این فایل خودش نقشه است. برای خودت plan، roadmap، RFC یا فایل markdown تحلیلی نساز. فقط `D-xx` ها را به ترتیب اجرا کن.

**۰-۲ — اجرا لوکال است.** پروژه روی همین ماشین است. مستقیم روی فایل‌سیستم کار کن، بعد از هر فاز commit بزن، و در پایان کل کار یک‌بار push کن. از GitHub API استفاده نکن.

**۰-۳ — شاخه.** همه چیز روی `chore/movement-deletion` که از `main` گرفته می‌شود. روی `main` مستقیم کار نکن.

**۰-۴ — این بند بند ۲ فایل `.agents/AGENTS.md` را برای این تسک لغو می‌کند.** آنجا نوشته «کد را حذف نکن، deprecate کن». اینجا دقیقاً برعکس است: **deprecate ممنوع است، حذف اجباری است.** هیچ `@Deprecated`، هیچ فایل خالیِ باقی‌مانده، هیچ کلاس یتیم، هیچ `// TODO: remove later`.

**۰-۵ — حذف یعنی حذف فیزیکی.** `git rm` روی فایل. کامنت‌کردن کد حذف‌شده ممنوع. نگه‌داشتن فایل با بدنهٔ خالی ممنوع. انتقال فایل به پوشهٔ `legacy/` یا `archive/` یا `_old/` ممنوع.

**۰-۶ — دادهٔ کاربر تلف نمی‌شود.** حذف جدول فقط بعد از مهاجرتِ داده به جدول قانونی مجاز است. الگو: در یک مهاجرت داده منتقل می‌شود و جدول به `_legacy_<name>` تغییر نام می‌دهد؛ در مهاجرت بعدی `DROP` می‌شود. اگر جدولی هیچ دادهٔ ارزشمندی ندارد (در فهرست «بدون نجات» آمده)، همان مهاجرت اول `DROP` شود.

**۰-۷ — بدون حدس زدن.** اگر نام جدول یا کلید یا مسیری در این فایل نیامده، آن را از خود کد بخوان. **نام جدول اختراع نکن.**

**۰-۸ — بعد از هر فاز، سه فرمان باید سبز باشند:**
```
flutter pub get
flutter analyze
flutter test
```
اگر `flutter analyze` بعد از یک فاز قرمز است، فاز تمام نشده. به فاز بعدی نرو.

**۰-۹ — یک commit به ازای هر فاز.** پیام commit در بخش ۹ آمده. commit نصفه‌کاره نزن.

**۰-۱۰ — گزارش نهایی.** در پایان یک فایل `DELETION_REPORT.md` در ریشهٔ مخزن بساز که برای هر `D-xx` بنویسد: `DONE` یا `SKIPPED` + دلیل یک‌خطی + تعداد فایل و بایت حذف‌شده. این تنها فایل markdown ای است که اجازه داری بسازی.

**۰-۱۱ — ممنوعیت مطلق:** تغییر `pubspec.yaml` فقط برای **حذف** asset و dependency مجاز است، نه اضافه‌کردن. هیچ پکیج جدیدی نصب نمی‌شود. هیچ فایل تولیدشده‌ای (`*.g.dart`, `*.freezed.dart`) دستی ویرایش نمی‌شود.

---

## ۱ — معیار حذف (چرا این چیزها می‌روند)

هر تکه کد در این دو ماژول باید از **هر پنج** تست زیر رد شود. اگر حتی یکی را رد کرد، حذف است — نه بهبود، نه ریفکتور، نه «فعلاً بماند».

1. **تست مصرف‌کننده:** آیا از UI فعلی مسیری وجود دارد که کاربر واقعاً به آن برسد؟ (route ثبت‌نشده = کاربر هرگز نمی‌رسد = حذف)
2. **تست دادهٔ واقعی:** آیا خروجی‌اش از دادهٔ واقعی کاربر می‌آید؟ (مقدار hardcode، نرخ ۸۵٪ ثابت، adherence ۱٫۰ = حذف)
3. **تست تکرار:** آیا کارِ کس دیگری را دوباره انجام می‌دهد؟ (دو منبع agenda، دو ناوبر هفته، دو انبار حرکات، دو سیستم تم = یکی می‌ماند، بقیه حذف)
4. **تست هزینه/فایده برای کاربر:** آیا کاربر برای چیزی که می‌گیرد، اطلاعات یا تپ اضافه می‌دهد؟ (RIR، واحد وزن، شمارش معکوس قابل تنظیم = حذف)
5. **تست تمایز:** آیا این چیزی است که ریتمو به خاطر دانستنِ چرخه و خواب و انرژی بهتر از یک اپ اختصاصی انجام می‌دهد؟ اگر نه و رقیب اختصاصی (Hevy، Strava) بهتر انجامش می‌دهد → حذف.

**قاعدهٔ حاکم:** «کد خوب برای قابلیتی که کاربر نمی‌خواهد، باز هم حذف می‌شود.» کیفیت کد دلیل نگه‌داشتن نیست.

---

## ۲ — فهرست نجات (فقط این چیزها از `supplementary_sports` بیرون کشیده می‌شوند)

قبل از حذف درخت `supplementary_sports`، **فقط و فقط** این سه چیز استخراج می‌شوند. هر چیز دیگری که وسوسه شدی نگه داری، حذف است.

**S-1 — نام‌های فارسی حرکات.**
منبع: `lib/features/supplementary_sports/data/seed/ss_exercise_farsi_names.dart` (۴۲٬۹۵۳ بایت مپ Dart هاردکد).
مقصد: یک فایل `assets/movement/exercise_names.json` با ساختار `[{"code": "...", "nameFa": "...", "nameEn": "..."}]`.
این JSON فقط یک‌بار در مسیر seed دیتابیس خوانده می‌شود و به `movement_exercises` می‌رود. بعد از seed، منبع حقیقت دیتابیس است.
سپس فایل Dart حذف می‌شود.

**S-2 — دادهٔ جلسات و ست‌های ثبت‌شدهٔ کاربر.**
هر ردیفی در جداول SS که یک جلسهٔ واقعاً انجام‌شده یا ست واقعاً ثبت‌شده را نگه می‌دارد، به `movement_workout_logs` و `movement_set_logs` مهاجرت می‌کند. یک ردیف هم نباید گم شود.

**S-3 — تاریخ شروع برنامهٔ فعال کاربر (اگر برنامهٔ فعالی دارد).**
فقط برای اینکه occurrence های آینده درست ساخته شوند. خودِ برنامه مهاجرت نمی‌کند (رجوع به `D-24`).

**هیچ چیز دیگری نجات داده نمی‌شود.** مشخصاً این‌ها **نجات داده نمی‌شوند**: پروفایل کاربر SS، چک‌این روزانه، تجویزها، الگوهای split، تاکسونومی عضلات، نقشهٔ انیمیشن، تصاویر عضلات، بودجهٔ هفتگی، کمپین‌ها، override های اسلات، لاگ تصمیم‌ها.

---

## فاز ۱ — حذف کامل درخت `lib/features/supplementary_sports/`

در پایان این فاز، دستور زیر باید خروجی خالی بدهد:
```
ls lib/features/supplementary_sports
```

### D-01 — صفحات غول‌پیکر SS

**واقعیت فعلی:** ۱۶ فایل در `presentation/` که روی هم ۶۲۲٬۶۰۲ بایت است. دو تای اولش به تنهایی ۲۵۱ کیلوبایت است. هیچ‌کدام route ثبت‌شده ندارند یا از مسیری باز می‌شوند که خودش در حال حذف است.

**تصمیم قطعی:** هر ۱۶ فایل حذف می‌شوند.
```
lib/features/supplementary_sports/presentation/new_movement_section.dart              (2,620)
lib/features/supplementary_sports/presentation/ss_custom_exercise_sheet.dart          (4,110)
lib/features/supplementary_sports/presentation/ss_exercise_library_screen.dart        (32,210)
lib/features/supplementary_sports/presentation/ss_home_dashboard_screen.dart          (134,806)
lib/features/supplementary_sports/presentation/ss_intro_screen.dart                   (7,480)
lib/features/supplementary_sports/presentation/ss_movement_tab_screen.dart            (22,582)
lib/features/supplementary_sports/presentation/ss_onboarding_flow.dart                (65,905)
lib/features/supplementary_sports/presentation/ss_plan_day_detail_screen.dart         (35,036)
lib/features/supplementary_sports/presentation/ss_plan_overview_screen.dart           (33,625)
lib/features/supplementary_sports/presentation/ss_premium_muscle_category_screen.dart (21,261)
lib/features/supplementary_sports/presentation/ss_program_settings_screen.dart        (9,195)
lib/features/supplementary_sports/presentation/ss_progress_screen.dart                (38,804)
lib/features/supplementary_sports/presentation/ss_session_summary_screen.dart         (21,749)
lib/features/supplementary_sports/presentation/ss_settings_screen.dart                (29,842)
lib/features/supplementary_sports/presentation/ss_workout_session_notifier.dart       (46,993)
lib/features/supplementary_sports/presentation/ss_workout_session_screen.dart         (116,384)
```
**معادل ساخته نمی‌شود.** در `movement` الان معادل زنده دارند: `movement_center_screen`، `movement_live_session_screen`، `session_summary_screen`، `movement_settings_screen`. فقط مطمئن شو هر ورودی‌ای که قبلاً به صفحات SS می‌رفت، حالا به معادل movement می‌رود یا خودش حذف شده.

### D-02 — ویجت‌های اختصاصی SS

**تصمیم قطعی:** حذف هر شش فایل.
```
presentation/widgets/ss_ai_coach_sheet.dart        (49,746)
presentation/widgets/ss_cant_today_sheet.dart      (5,145)
presentation/widgets/ss_daily_checkin_widget.dart  (37,637)
presentation/widgets/ss_log_session_sheet.dart     (7,750)
presentation/widgets/ss_program_diff_sheet.dart    (4,291)
presentation/widgets/ss_recovery_card.dart         (5,875)
```
دربارهٔ `ss_ai_coach_sheet.dart`: ۴۹ کیلوبایت UI برای مربی هوشمندی که اگر قرار باشد فقط از دادهٔ واقعی حرف بزند، خروجی‌اش یک پاراگراف است. معادلِ قانونی آن در طراحی جدید یک کارت «چی عوض شد و چرا» است که در فاز طراحی ساخته می‌شود، نه اینجا.
دربارهٔ `ss_cant_today_sheet.dart`: مفهوم «امروز نمی‌تونم» زنده می‌ماند ولی به‌عنوان یکی از سه دکمهٔ `session_actions_sheet` — نه شیت مستقل.
دربارهٔ `ss_daily_checkin_widget.dart`: ۳۷ کیلوبایت فرم برای گرفتن خواب/انرژی/کوفتگی/استرس. ریتمو سه تا از این چهار را از ماژول‌های دیگر می‌داند. معادلِ قانونی: `readiness_checkin_sheet.dart` در movement.

### D-03 — سیستم طراحی دوم و ویجت‌های مشترک SS

**واقعیت فعلی:** `supplementary_sports_theme.dart` یک سیستم طراحی کاملاً موازی با `RitmoTheme` است. پوشهٔ `presentation/widgets/shared/` ۱۵ ویجت پایه دارد که همه در `RitmoTheme` یا `movement/presentation/common/` معادل دارند.

**تصمیم قطعی:** حذف کامل.
```
lib/features/supplementary_sports/supplementary_sports_theme.dart  (5,632)
lib/features/supplementary_sports/presentation/widgets/shared/     (کل پوشه، ۱۵ فایل، 55,977)
```
نگاشت معادل‌ها در مواردی که مصرف‌کنندهٔ باقی‌مانده دارند:
| حذف‌شده | جایگزین قانونی |
|---|---|
| `primary_button.dart` / `secondary_button.dart` | دکمه‌های `RitmoTheme` |
| `empty_state_view.dart` | `movement/presentation/common/empty_state_block.dart` |
| `loading_shimmer.dart` | `movement/presentation/common/skeletons.dart` |
| `stat_card.dart` | `movement/presentation/common/metric_stat.dart` |
| `bottom_sheet_container.dart` | شیت استاندارد `RitmoTheme` |
| `selectable_card.dart` / `multi_select_card.dart` / `stepper_input.dart` | جایگزین ندارند — مصرف‌کننده‌هاشان هم حذف می‌شوند |
| `onboarding_progress_bar.dart` / `chat_bubble.dart` / `continuity_bar.dart` | جایگزین ندارند — قابلیتشان حذف می‌شود |
| `ss_lottie_player.dart` (18,285) | رجوع به `D-04` — جایگزین ندارد |
| `ss_muscle_image_resolver.dart` | رجوع به `D-04` — جایگزین ندارد |
| `ss_screen_awake.dart` | منطق بیدارماندن صفحه به `movement_live_session_screen` منتقل می‌شود (در حین جلسهٔ فعال همیشه روشن، بدون تنظیمات) |

### D-04 — انیمیشن حرکات و تصاویر عضلات: کل قابلیت حذف می‌شود

**واقعیت فعلی:** `ss_exercise_animation_map.dart` (۲۸٬۲۳۰) + `ss_lottie_player.dart` (۱۸٬۲۸۵) + `ss_muscle_image_resolver.dart` + حجم نامعلومی از asset های lottie و تصویر در `assets/`.

**تصمیم قطعی:** کل این قابلیت حذف می‌شود. دلیل: این یک قابلیتِ Fitbod/Hevy است، تمایز ریتمو نیست، و فقط به درد کاربر قدرتیِ جدی می‌خورد که اقلیت است، و برای همان اقلیت هم یک سرچ یوتیوب بهتر از این است.
اقدامات:
1. `ss_exercise_animation_map.dart` حذف.
2. `ss_lottie_player.dart` حذف.
3. `ss_muscle_image_resolver.dart` حذف.
4. هر asset که فقط توسط این سه فایل مصرف می‌شد از دیسک حذف شود و ردیفش از `pubspec.yaml` دربیاید.
5. اگر پکیج `lottie` بعد از این حذف هیچ مصرف‌کننده‌ای در کل پروژه ندارد، از `pubspec.yaml` حذف شود.
6. ستون `animationAsset` در هر مدل/جدولی که قرار بود ساخته شود، ساخته نمی‌شود.

### D-05 — دامنهٔ SS

**تصمیم قطعی:** کل `lib/features/supplementary_sports/domain/` حذف.
```
domain/sports_detail_mode.dart               (1,194)
domain/ss_adaptive_scheduler.dart            (4,661)
domain/ss_agenda_source.dart                 (10,522)   → منبع دوم agenda، منشأ ردیف تکراری
domain/ss_program_calendar.dart              (1,752)
domain/ss_readiness_service.dart             (9,820)    → دومین موتور آمادگی
domain/ss_session_completion_gateway.dart    (5,536)
domain/ss_session_settings.dart              (1,824)
domain/ss_unit_formatter.dart                (2,360)    → واحدها ثابت می‌شوند، رجوع به D-27
domain/ss_week_resolver.dart                 (3,690)    → دومین منطق هفته
domain/prescription/muscle_group.dart        (2,896)
domain/prescription/session_prescription.dart (7,550)
domain/prescription/split_pattern.dart       (3,207)
```
**مهم:** `SsAgendaSource` تنها جایی است که روتین‌های `category = 'fitness'` خوانده می‌شوند. قبل از حذف، همین یک کار را به `MovementAgendaSource` منتقل کن با dedup بر اساس `(dateIso, sourceId)`. هیچ چیز دیگری از این فایل منتقل نمی‌شود.
**مهم:** منطق آمادگیِ قانونی `movement_readiness_service.dart` است. اگر در `ss_readiness_service.dart` قاعده‌ای دیدی که در نسخهٔ قانونی نیست، **منتقلش نکن** — فقط در `DELETION_REPORT.md` یک خط درباره‌اش بنویس.

### D-06 — لایهٔ دادهٔ SS

**تصمیم قطعی:** کل `lib/features/supplementary_sports/data/` حذف (پس از اجرای S-1 و S-2).
```
data/models/ss_daily_checkin_model.dart      (2,240)
data/models/ss_exercise_model.dart           (5,725)
data/models/ss_plan_models.dart              (3,954)
data/models/ss_session_models.dart           (4,519)
data/models/ss_user_profile_model.dart       (13,983)
data/repositories/ss_audio_cue_player.dart   (1,396)
data/repositories/ss_compensation_service.dart (6,796)
data/repositories/ss_exercise_repository.dart  (383)
data/repositories/ss_plan_generator.dart     (26,593)
data/repositories/ss_plan_repository.dart    (1,476)
data/repositories/ss_prescription_repository.dart (4,392)
data/repositories/ss_profile_repository.dart (2,865)
data/repositories/ss_program_builder.dart    (6,551)
data/repositories/ss_session_repository.dart (835)
data/repositories/ss_session_repository_impl.dart (10,967)
data/seed/ss_exercise_animation_map.dart     (28,230)
data/seed/ss_exercise_farsi_names.dart       (42,953)
```
دربارهٔ `ss_compensation_service.dart`: سرویسِ «جلسهٔ جبرانی». این مکانیسم دقیقاً همان چیزی است که در یک اپ سلامت بانوان باعث ریزش می‌شود: تبدیل روز ازدست‌رفته به بدهی. **نه منتقل می‌شود، نه بازسازی.**
دربارهٔ `ss_audio_cue_player.dart`: راهنمای صوتی در حین جلسه حذف می‌شود. اگر asset صوتی دارد، آن‌ها هم از دیسک و `pubspec.yaml` حذف شوند.

### D-07 — درخت سوم: `supplementary_sports/movement/`

**واقعیت فعلی:** یک ماژول حرکتِ کاملِ سوم وسط ماژول دوم. ۳۳۸ کیلوبایت. کلاس‌هایی با همان نام‌های `movement` ولی مدل دادهٔ متفاوت.

**تصمیم قطعی:** حذف کل درخت بدون استثنا.
```
supplementary_sports/movement/data/movement_campaign_repository.dart      (9,349)
supplementary_sports/movement/data/movement_reminder_service.dart         (3,986)
supplementary_sports/movement/data/movement_repository.dart               (17,263)
supplementary_sports/movement/data/movement_session_repository.dart       (10,147)
supplementary_sports/movement/data/movement_slot_override_repository.dart (10,177)
supplementary_sports/movement/data/unified_planner_repository.dart        (11,094)
supplementary_sports/movement/data/seed/movement_kinds_seed.dart          (15,656)
supplementary_sports/movement/domain/  (۱۳ فایل، 61,187)
supplementary_sports/movement/presentation/  (کل درخت، 338,111)
```
**استثنای تک-موردی:** `movement_kinds_seed.dart` قبل از حذف باید بررسی شود که هشت نوع فعالیت قانونی (`kind_walking`, `kind_running`, `kind_cycling`, `kind_swimming`, `kind_team_sports`, `kind_hiking`, `kind_yoga_mobility`, `kind_strength`) در seed ِ `movement_activity_kinds` وجود دارند. اگر ندارند، همین هشت ردیف را منتقل کن. هر نوع فعالیت اضافی دیگری در آن فایل بود، منتقل نمی‌شود.

### D-08 — قابلیت‌هایی که همراه درخت سوم می‌میرند (و بازساخته نمی‌شوند)

این فهرست را به‌عنوان قانون بخوان: هرگز معادلِ این‌ها را در `movement` نساز.

| قابلیت | فایل منبع | چرا می‌میرد |
|---|---|---|
| بودجهٔ حرکتی هفتگی | `movement_budget.dart` + `weekly_budget_card.dart` | یک مفهوم حسابداری است که کاربر نمی‌فهمد. جایگزین در طراحی جدید: یک جملهٔ «این هفته: ۲ از ۳» |
| کمپین حرکتی | `movement_campaign.dart` + repository | هیچ ورودی UI ندارد، هیچ کاربری تا امروز یکی نساخته |
| override اسلات | `movement_slot_override.dart` + repository (۱۰٬۱۷۷) | یک لایهٔ پیچیدگی روی برنامه که همان کار `movement_occurrences.status = moved` را می‌کند |
| برنامه‌ریز هفتگی یکپارچه | `unified_week_planner_screen.dart` (۳۵٬۵۸۸) | دومین برنامه‌ریز؛ یکی می‌ماند (`activity_plan_editor_screen`) |
| پرکردن هوشمند هفته | `week_smart_fill_sheet.dart` + `smart_fill_sheet.dart` | رجوع به `D-20` |
| قالب‌های جلسه (۵ قالب) | `session/templates/**` (۳۴٬۵۹۸) | رجوع به `D-23` |
| بازیابی جلسه | `movement_session_recovery.dart` (۱۱٬۶۰۳) | `movement_live_sessions` خودش این کار را می‌کند |
| نوع فعالیت سفارشی | `movement_custom_kind_sheet.dart` (۱۵٬۸۰۴) | هشت نوع کافی است؛ نوع نهم را کاربر یک‌بار می‌سازد و دیگر سراغش نمی‌رود |
| پیشنهاددهندهٔ حرکت | `movement_suggester.dart` (۱۷٬۴۰۶) | پیشنهاد در طراحی جدید فقط از آمادگی می‌آید، نه از یک موتور جداگانه |
| پیشرفت استقامتی | `endurance_progression.dart` | رجوع به `D-21` |

**دروازهٔ پذیرش فاز ۱**
- [ ] `ls lib/features/supplementary_sports` خطای «No such file» می‌دهد.
- [ ] `grep -rn "supplementary_sports" lib/ test/` خروجی خالی دارد.
- [ ] `grep -rni "ss_" lib/features/movement/` خروجی خالی دارد.
- [ ] `grep -rn "lottie" lib/ pubspec.yaml` خروجی خالی دارد.
- [ ] `assets/movement/exercise_names.json` وجود دارد و در `pubspec.yaml` ثبت است.
- [ ] `flutter analyze` سبز.
- [ ] `flutter test` سبز.

---

## فاز ۲ — حذف درون `lib/features/movement/`

این فاز سخت‌تر از فاز ۱ است، چون اینجا کدِ تمیز را حذف می‌کنیم. دلیلش هم همین است: ماژول حرکت امروز پنج محصول است (سازندهٔ برنامهٔ قدرتی + ردیاب فعالیت + برنامه‌ریز هفتگی + مشاور ریکاوری + دایرة‌المعارف حرکات) و در هیچ‌کدام از رقیب اختصاصی بهتر نیست. در پایان این فاز باید **یک** محصول بماند: ثبت حرکت در پنج ثانیه، با توجه به وضعیت امروز بدن.

### D-09 — مقصد «کتابخانهٔ حرکات» حذف می‌شود

**واقعیت فعلی:** `presentation/library/movement_library_screen.dart` (۱۴٬۵۶۰) به‌علاوهٔ پوشه‌های `sheets/` و `widgets/` زیرش. یک مقصد مستقل در نوار پیمایش برای مرور حرکات.

**تصمیم قطعی:** حذف کل `lib/features/movement/presentation/library/` با تمام زیرپوشه‌ها.

**دلیل:** کاربر دایرة‌المعارف حرکات را فقط در یک لحظه می‌خواهد: وقتی دارد یک حرکت به جلسه اضافه می‌کند. اون جا یک فیلد جستجو با debounce کافی است. یک تب دائمی در پیمایش برای مرورِ ۳۰۰ حرکت، یک مقصد مرده است.

**جایگزین مجاز (در فاز طراحی، نه اینجا):** یک `TextField` در بالای شیت افزودن حرکت، حداکثر ۸۰ خط.

### D-10 — سازندهٔ برنامهٔ قدرتی: صفحات و انبوردینگ

**واقعیت فعلی:** یک مسیر ۶ مرحله‌ای (هدف → سطح/ایمنی → تجهیزات → برنامهٔ زمانی → ترجیحات → پیش‌نمایش) قبل از اینکه کاربر حتی یک حرکت ثبت کند.

**تصمیم قطعی:** حذف.
```
presentation/strength/strength_hub_screen.dart              (13,661)
presentation/strength/strength_onboarding_flow.dart         (11,693)
presentation/strength/strength_program_preview_screen.dart  (15,270)
presentation/strength/onboarding/step_goal.dart             (5,604)
presentation/strength/onboarding/step_level_safety.dart      (7,396)
presentation/strength/onboarding/step_equipment.dart        (4,984)
presentation/strength/onboarding/step_schedule.dart         (5,443)
presentation/strength/onboarding/step_preferences.dart      (4,135)
```
**دلیل:** معیار «۶۰ ثانیه تا اولین ارزش». این مسیر حداقل ۳ دقیقه طول می‌کشد و در پایانش کاربر هنوز صفر جلسه ثبت کرده. ریتمو اپ برنامه‌نویسی بدنسازی نیست.

### D-11 — سازندهٔ برنامهٔ قدرتی: شیت‌ها و ویجت‌ها

**تصمیم قطعی:** حذف.
```
presentation/strength/sheets/program_manage_sheet.dart   (11,519)
presentation/strength/sheets/swap_exercise_sheet.dart    (13,248)
presentation/strength/widgets/program_header.dart        (4,372)
presentation/strength/widgets/program_session_tile.dart  (4,094)
presentation/strength/widgets/program_week_strip.dart    (4,266)
presentation/strength/widgets/why_this_program_block.dart (5,892)
presentation/strength/widgets/rir_picker.dart            (2,535)
```
دربارهٔ `rir_picker.dart`: RIR (تکرار در ذخیره) یک مفهوم تخصصی بدنسازی است. کاربر ریتمو نمی‌داند یعنی چه، و هر ست یک تپ اضافه تحمیل می‌کند در برابر صفر خروجی قابل مشاهده. ستون `rir` در `movement_set_logs` هم حذف می‌شود (رجوع به `D-35`).
دربارهٔ `swap_exercise_sheet.dart`: تعویض حرکت فقط وقتی معنا دارد که برنامه‌ای وجود داشته باشد. برنامه حذف شد → تعویض هم حذف می‌شود. جدول `movement_exercise_similarity` هم در `D-34` می‌میرد.

### D-12 — موتور برنامهٔ قدرتی و مدل‌هایش

**تصمیم قطعی:** حذف.
```
application/strength_program_service.dart          (25,759)
domain/models/movement_strength_program.dart       (6,342)
domain/models/movement_strength_day.dart           (2,752)
domain/models/movement_strength_exercise.dart      (3,206)
```
**با این حذف، این باگ‌های شناسایی‌شده دیگر وجود ندارند و نباید رفع شوند:**
`M-48` (fallback به `DateTime.now()` در `resolveProgramStartDate`) · `M-49` (لوپ بی‌پایان `((diff ~/ 7) % totalWeeks) + 1`) · `M-50` (`RegExp(r'^plan_w(\d+)_')` با `?? 4`) · `M-51` (تکمیل هفته برابر `1.0` در نبود داده) · `M-52` (`daysPerWeek` که هرگز برنمی‌گردد).
این پنج مورد در `DELETION_REPORT.md` با وضعیت `CANCELLED (code deleted)` ثبت شوند.

### D-13 — از بخش قدرتی فقط این‌ها زنده می‌مانند (فهرست بسته)

ثبت تمرین قدرتی به صورت **ad-hoc** زنده می‌ماند: کاربر در حین جلسه حرکت اضافه می‌کند و ست می‌زند. بدون برنامه، بدون دوره‌بندی، بدون دلود.

**باقی می‌مانند (دست نزن):**
```
presentation/session/modes/strength_session_view.dart     (11,667)
presentation/strength/widgets/set_row.dart                (7,441)
presentation/strength/widgets/set_table.dart              (4,326)
presentation/strength/widgets/current_exercise_card.dart  (4,117)
presentation/strength/widgets/rest_timer_bar.dart         (5,440)
```
این پنج فایل باید از `presentation/strength/widgets/` به `presentation/session/widgets/strength/` منتقل شوند، چون دیگر بخش «strength» مستقلی وجود ندارد. پوشهٔ `presentation/strength/` بعد از این انتقال باید کاملاً حذف شود.
جداول `movement_workout_logs` و `movement_set_logs` زنده می‌مانند.

### D-14 — مقصد «پیشرفت» حذف می‌شود

**واقعیت فعلی:** یک صفحه و هشت ویجت، جمعاً ۴۷٬۳۶۶ بایت، که اعدادی را نشان می‌دهند که بخش بزرگی ازشان جعلی است (`M-67` نرخ تکمیل ثابت ۰٫۸۵، `M-68` شمارهٔ هفته از مبدأ ۲۰۲۵ و `volumeKg = 0.0`، `M-69` پایبندی ۱۰۰٪، `M-70` بار عضلانی بر اساس تعداد ست نه حجم).

**تصمیم قطعی:** حذف کل `lib/features/movement/presentation/progress/`.
```
presentation/progress/movement_progress_screen.dart          (10,299)
presentation/progress/widgets/body_map_card.dart             (4,279)
presentation/progress/widgets/distribution_card.dart         (3,054)
presentation/progress/widgets/kpi_grid.dart                  (5,032)
presentation/progress/widgets/pr_list.dart                   (5,314)
presentation/progress/widgets/range_filter_bar.dart          (2,513)
presentation/progress/widgets/status_breakdown_card.dart     (4,379)
presentation/progress/widgets/strength_progress_card.dart    (4,289)
presentation/progress/widgets/trend_chart_card.dart          (8,207)
```
**چرا بهبود نه، حذف:** اصلاحِ `M-67` تا `M-70` یعنی نوشتنِ `MovementMetric<T>` و پنهان‌کردن متریک‌هایی که `sampleSize` کافی ندارند. اگر صادقانه این کار را بکنی، برای کاربری که هفته‌ای دو بار حرکت می‌کند، هر نه کارت خالی می‌مانند. یک مقصد کامل که در عمل خالی است، بدتر از نبودن آن است.

**جایگزین (در فاز طراحی ساخته می‌شود، نه اینجا):** یک بلوک در پایین صفحهٔ مرکزی با دقیقاً دو عدد: «این هفته: X جلسه» و «۴ هفتهٔ اخیر: Y جلسه». هر دو مستقیماً از `COUNT(*)` روی `movement_workout_logs`.

### D-15 — دو سرویس تحلیلی حذف می‌شوند

**تصمیم قطعی:** حذف.
```
application/movement_analytics_service.dart   (5,646)
application/movement_progress_service.dart    (16,350)
```
`movement_analytics_service` رویداد در `movement_analytics_events` می‌نویسد که هیچ‌کس نمی‌خواند. جدولش در `D-34` می‌میرد.
`movement_progress_service` منبع همهٔ اعداد جعلی است.
جایگزین: یک متد در `movement_occurrence_service.dart` با امضای `Future<MovementWeekStats> weekStats(DateTime anchor)` که فقط دو عدد از `D-14` را برمی‌گرداند. حداکثر ۴۰ خط.

### D-16 — صفحهٔ جزئیات occurrence حذف می‌شود

**واقعیت فعلی:** `presentation/occurrence/occurrence_details_screen.dart` (۱۶٬۷۰۱) + پوشهٔ `widgets/` زیرش. یک صفحهٔ کامل برای نمایش اطلاعات یک جلسهٔ برنامه‌ریزی‌شده.

**تصمیم قطعی:** حذف کل `lib/features/movement/presentation/occurrence/`.

**دلیل:** یک occurrence در مجموع پنج داده دارد: نوع، تاریخ، مدت، وضعیت، یادداشت. این پنج داده در `hero_session_card` و `session_card` الان هم دیده می‌شوند. یک تپ اضافه برای رسیدن به صفحه‌ای که همان پنج داده را بزرگ‌تر نشان می‌دهد، ارزش ندارد.

**رفتار جدید:** تپ روی کارت جلسه = شروع جلسه. فشار طولانی = `session_actions_sheet`. تمام.

### D-17 — برنامه‌ریز: یکی می‌ماند، لاغر می‌شود

**واقعیت فعلی:** `presentation/planner/activity_plan_editor_screen.dart` (۱۷٬۲۸۴) + `activity_plan_editor_controller.dart` (۸٬۲۶۲) + پوشه‌های `sheets/` و `widgets/`.

**تصمیم قطعی:**
- `activity_plan_editor_screen.dart` و `activity_plan_editor_controller.dart` می‌مانند (این هستهٔ تیر ۲ است).
- **کل `presentation/planner/sheets/` حذف می‌شود.** هر چیزی که آنجا بود، به فیلد درون‌خطی در خود صفحه تبدیل می‌شود.
- `presentation/planner/widgets/` فقط ویجت‌هایی را نگه می‌دارد که دقیقاً در همین صفحه مصرف می‌شوند؛ بقیه حذف.
- سقف نهایی: صفحه حداکثر **۴۰۰ خط**، کنترلر حداکثر **۲۵۰ خط**.
- برنامه‌ریز باید دقیقاً سه چیز بپرسد: هفته‌ای چند روز؟ چه روزهایی؟ چه نوع فعالیتی؟ هر فیلد چهارمی حذف می‌شود.

### D-18 — ویجت‌های صفحهٔ مرکزی

**حذف می‌شوند:**
```
presentation/center/widgets/week_navigator_bar.dart     (7,297)
presentation/center/widgets/day_slot.dart               (6,457)
presentation/center/widgets/day_status_indicators.dart  (4,564)
presentation/center/widgets/strength_entry_card.dart    (13,110)
presentation/center/widgets/week_summary_card.dart      (4,788)
```
- `week_navigator_bar` دومین ناوبر هفته کنار `week_rail` است. دو تا لازم نیست. `week_rail` (۳٬۹۶۸) می‌ماند چون کوچک‌تر است.
- `day_slot` و `day_status_indicators` به یک نمای گریدی هفتگی تعلق دارند که در طراحی جدید وجود ندارد.
- `strength_entry_card` (۱۳ کیلوبایت) کارت تبلیغ برنامهٔ قدرتی است که در `D-10` مرد.
- `week_summary_card` با یک خط متن در `D-14` جایگزین می‌شود.

**باقی می‌مانند (فهرست بسته):** `hero_session_card` · `session_card` · `live_session_banner` · `add_activity_dock` · `movement_app_bar` · `week_rail` · `recovery_day_card`.

### D-19 — شیت‌های درون‌جلسه

**حذف می‌شوند:**
```
presentation/session/sheets/pain_report_sheet.dart   (7,779)
presentation/session/sheets/pause_exit_sheet.dart    (4,746)
```
- گزارش درد در وسط تمرین نباید یک فرم ۷٫۸ کیلوبایتی باشد. جایگزین: یک چیپ «درد داشتم» کنار سه ایموجی پایان جلسه (سبک / خوب / سنگین). مقدارش در همان ردیف `movement_workout_logs` ذخیره می‌شود.
- توقف/خروج یک دکمه است، نه یک شیت. به `session_actions_sheet` منتقل می‌شود.

### D-20 — هفت شیت صفحهٔ مرکزی می‌شوند یکی

**واقعیت فعلی:** هفت شیت مجزا در `presentation/center/sheets/`، جمعاً ۷۵٬۴۹۱ بایت، که همه در نهایت یک کار می‌کنند: تغییر وضعیت یک جلسه.

**تصمیم قطعی:** هر هفت فایل حذف می‌شوند. کل پوشهٔ `presentation/center/sheets/` حذف می‌شود.
```
presentation/center/sheets/add_command_sheet.dart      (9,985)
presentation/center/sheets/move_session_sheet.dart     (12,032)
presentation/center/sheets/plan_b_sheet.dart           (10,914)
presentation/center/sheets/quick_complete_sheet.dart   (8,905)
presentation/center/sheets/skip_session_sheet.dart     (6,601)
presentation/center/sheets/smart_fill_sheet.dart       (16,715)
presentation/center/sheets/week_reshuffle_sheet.dart   (10,339)
```

**جایگزین — دقیقاً همین و نه بیشتر:**
فایل `presentation/session/sheets/session_actions_sheet.dart` (الان ۵٬۰۶۲ بایت، موجود است) بازنویسی می‌شود تا **دقیقاً سه عمل** داشته باشد:
1. **انجامش دادم** — ثبت فوری با مدت پیش‌فرض، بدون فرم.
2. **می‌ندازم برای روز دیگر** — فقط انتخاب تاریخ، بدون دلیل خواستن.
3. **امروز نمی‌تونم** — بدون سوال، بدون سرزنش، بدون جلسهٔ جبرانی.

سقف فایل جدید: **۱۵۰ خط**. هر عمل چهارمی که وسوسه شدی اضافه کنی، ممنوع است.

**مفاهیمی که همراه این شیت‌ها می‌میرند و بازساخته نمی‌شوند:**
- **پلان B** — یعنی اپ برای کاربری که نتوانسته، یک نسخهٔ کوچک‌تر از همان تکلیف می‌سازد. این چانه‌زدن با کاربر است، نه کمک.
- **بهم‌ریختن هفته (reshuffle)** — جابه‌جایی خودکار چند جلسه با هم. کاربر نمی‌فهمد چه اتفاقی افتاد و اعتمادش را از دست می‌دهد.
- **پرکردن هوشمند (SmartFill)** — `M-87` (نسخهٔ دسته‌ای `createPlansBatch`) لغو می‌شود. پرکردن خودکار هفته توسط اپ دقیقاً همان کاری است که بعداً تبدیل به دیوار قرمز `missed` می‌شود.
- **دکمهٔ فرمان (add_command)** — یک منوی مخفی در یک شیت. `add_activity_dock` کافی است.
- **`M-91`** (ساختن `MovementSessionActionsSheet` به‌عنوان شیت **هشتم**) لغو می‌شود و با همین `D-20` جایگزین می‌شود.
- **`M-90`** (سوایپ روی کارت جلسه) لغو می‌شود. سوایپ افقی در یک لیست عمودی کنار یک ریل افقی هفته، در RTL، یک دام است. جایگزین: دکمهٔ اصلی روی کارت + فشار طولانی. ولی **`UndoToast` ۵ ثانیه‌ای می‌ماند** و برای هر سه عمل فعال است.

### D-21 — موتور پیشرفت تدریجی حذف می‌شود

**واقعیت فعلی:** منطق پیشرفت (افزایش خودکار وزنه/مسافت، پنجرهٔ حداقل ۴ جلسه در ۴۲ روز، دلود) در دو جا پخش است: `endurance_progression.dart` (درخت سوم، در `D-07` می‌میرد) و `strength_program_service.dart` (در `D-12` می‌میرد).

**تصمیم قطعی:** هیچ موتور پیشرفتی بازساخته نمی‌شود. `M-53` لغو است.

**دلیل:** پیشرفت خودکار فقط وقتی کار می‌کند که کاربر منظم باشد. کاربری که منظم است، خودش می‌داند وزنه را کی زیاد کند. کاربری که منظم نیست — یعنی اکثریت — این موتور برایش فقط عددهای بی‌ربط تولید می‌کند.

### D-22 — حالت‌های جلسه: از شش به سه

**حذف می‌شوند:**
```
presentation/session/modes/count_session_view.dart     (1,496)
presentation/session/modes/distance_session_view.dart  (1,394)
presentation/session/modes/lap_session_view.dart       (1,362)
```
**باقی می‌مانند (فهرست بسته):** `time_session_view.dart` · `free_session_view.dart` · `strength_session_view.dart`.

**دلیل:** حالتِ «مسافت» و «دور» فقط وقتی ارزش دارند که اپ خودش اندازه بگیرد (GPS یا سنسور). ریتمو این کار را نمی‌کند و قرار هم نیست بکند. ورودِ دستیِ عدد در پوشش یک «حالت زنده»، فقط فریب‌دادن کاربر است. کاربری که دویده، در `free_session_view` می‌نویسد دویدم ۳۰ دقیقه — تمام.

### D-23 — ویجت‌های درون‌جلسه

**حذف می‌شوند:**
```
presentation/session/widgets/counter_control.dart       (7,049)
presentation/session/widgets/distance_input.dart        (6,522)
presentation/session/widgets/lap_button.dart            (6,925)
presentation/session/widgets/pending_save_badge.dart    (2,069)
presentation/session/widgets/secondary_actions_row.dart (1,002)
presentation/session/widgets/session_status_strip.dart  (2,778)
```
- سه تای اول متعلق به حالت‌های حذف‌شدهٔ `D-22` هستند.
- `pending_save_badge` و `session_status_strip` وضعیت ذخیره/آفلاین را دوباره نشان می‌دهند؛ `common/offline_banner.dart` کافی است. ذخیره باید همیشه موفق فرض شود و فقط در خطا حرف بزند.
- `secondary_actions_row` ۱٬۰۰۲ بایت برای یک `Row` است.

**باقی می‌مانند:** `timer_display` · `session_app_bar` · `session_primary_cta` · `intensity_picker`.
**قالب‌های جلسهٔ درخت سوم (`session/templates/**`، ۵ فایل، ۳۴٬۵۹۸ بایت) معادل ساخته نمی‌شود.** مشخصاً `route_session_template.dart` (۱۵٬۹۶۳) که مسیر جغرافیایی می‌گیرد و `match_session_template.dart` که نتیجهٔ مسابقه می‌گیرد، هرگز بازنمی‌گردند.

### D-24 — برنامه‌ها و تجویزهای SS مهاجرت نمی‌کنند

**تصمیم قطعی:** هیچ برنامه، تجویز، الگوی split، روز برنامه یا تمرینِ تجویز‌شده‌ای از SS به movement منتقل نمی‌شود.

**رفتار مهاجرت:** اگر کاربر برنامهٔ فعالی داشت، فقط دو چیز استخراج می‌شود: تعداد روز در هفته، و روزهای هفته. این دو به یک `movement_plan_schedules` ساده تبدیل می‌شوند با نوع فعالیت `kind_strength` یا نزدیک‌ترین نوع قانونی.
**بعد از مهاجرت، یک اطلاع‌رسانی درون‌اپی یک‌باره نشان داده می‌شود:** «برنامهٔ قبلی‌ات به یک برنامهٔ ساده‌تر تبدیل شد. همهٔ جلساتی که ثبت کرده بودی سر جایش هست.» یک جمله، یک دکمهٔ تأیید. نه معذرت‌خواهی، نه توضیح طولانی.

### D-25 — تاکسونومی عضلات و نقشهٔ بدن حذف می‌شوند

**تصمیم قطعی:** `M-25` (مهاجرت `ss_muscle_group` به `movement_muscle_groups` با ۱۲ ردیف) **لغو می‌شود**. `M-70` (اصلاح محاسبهٔ بار عضلانی) **لغو می‌شود**.

حذف می‌شوند:
- جدول `movement_muscle_groups` (اگر ساخته شده)
- جدول `movement_exercise_muscles` (اگر ساخته شده)
- ستون `movementMuscleFocus` در `routines` **دیگر نوشته نمی‌شود** (ستون به دلیل ریسک مهاجرت می‌ماند ولی هیچ کدی در آن نمی‌نویسد و هیچ UI آن را نمی‌خواند)
- `body_map_card.dart` (در `D-14` حذف شد)

**دلیل:** نقشهٔ عضلات، متریک فخرفروشی برای برنامه‌ای است که دیگر وجود ندارد. کاربری که هفته‌ای دو بار پیاده‌روی می‌کند، نقشهٔ عضلاتِ کاملاً خالی می‌بیند.

### D-26 — رکوردهای شخصی: جدول می‌ماند، صفحه می‌میرد

**تصمیم قطعی:**
- جدول `movement_personal_records` می‌ماند.
- `pr_list.dart` در `D-14` حذف شد و بازنمی‌گردد.
- از `M-66` فقط و فقط این دو مورد اجرا می‌شوند: (۱) فراخوانی `evaluateAndSaveRecord` در مسیر ذخیرهٔ ست؛ (۲) پرانتزگذاری شرط `OR` و افزودن ایندکس یکتا.
- نمایش رکورد فقط یک جا: یک خط در خلاصهٔ پایان جلسه («رکورد جدید: اسکوات ۴۰ کیلو»). صفحه، تب، لیست و نشان ندارد.

### D-27 — واحدها ثابت می‌شوند

**تصمیم قطعی:** کیلوگرم و کیلومتر، همیشه، بدون تنظیمات.
حذف می‌شوند: `ss_unit_formatter.dart` (در `D-05`)، کلید تنظیمات `distance_unit`، کلید تنظیمات `weight_unit`، و هر منطق تبدیل واحد در کل ماژول.
**دلیل:** کاربر ایرانی پوند و مایل نمی‌خواهد. این دو کلید فقط دو ردیف به صفحهٔ تنظیمات اضافه کردند و صفر کاربرد دارند.

### D-28 — پوشهٔ `common/`: هر ویجتی که بعد از حذف‌ها بدون مصرف‌کننده ماند

**دستور قطعی:** پس از پایان `D-09` تا `D-27`، برای هر فایل در `lib/features/movement/presentation/common/` این را اجرا کن:
```
grep -rn "<ClassName>" lib/ --include=*.dart | grep -v "common/<file>.dart"
```
اگر خروجی خالی بود → فایل حذف می‌شود. بدون استثنا.
کاندیداهای قطعی‌الحذف که از الان مشخص‌اند:
```
presentation/common/diff_list.dart        (8,058)  → فقط مصرف‌کننده‌اش پیش‌نمایش برنامه بود (D-10)
presentation/common/dev_only_banner.dart  (1,380)  → کد دیباگ در باینری کاربر
presentation/common/reason_chip.dart      (4,154)  → مصرف‌کننده‌هایش شیت‌های D-20 بودند
```
**`M-89`** (افزودن چیپ دلیل به کارت‌ها) لغو می‌شود. کاربر به اینکه اپ چرا این را پیشنهاد داده فقط در یک جا اهمیت می‌دهد: کارت قهرمان روز. و آنجا یک جملهٔ متنی است، نه چیپ.

### D-29 — `movement_strings.dart` لاغر می‌شود

**واقعیت فعلی:** ۳۲٬۹۷۵ بایت رشتهٔ فارسی.

**دستور قطعی:** برای هر کلید، `grep` بزن. هر کلیدی که صفر مصرف‌کننده دارد حذف می‌شود.
**سقف نهایی فایل: ۱۲ کیلوبایت.** اگر بعد از حذف کلیدهای یتیم هنوز بزرگ‌تر از ۱۲ کیلوبایت است، یعنی جایی را در فازهای قبل حذف نکرده‌ای — برگرد و پیدایش کن.
**قاعدهٔ لحن:** هر رشته‌ای که شامل این کلمات است بازنویسی یا حذف می‌شود: «عقب افتادی»، «از دست دادی»، «جبران»، «شکست»، «ناموفق»، «استریکت از دست رفت».

### D-30 — سقف خط برای دو فایل مرکزی

بعد از تمام حذف‌های بالا، این دو فایل باید بازنویسی شوند (نه پچ‌شدن):
```
presentation/center/movement_center_screen.dart      (32,696) → حداکثر 500 خط
presentation/center/movement_center_controller.dart  (15,704) → حداکثر 500 خط
```
صفحهٔ مرکزی دقیقاً سه حالت دارد و لاغیر: جلسهٔ امروز دارد / روز استراحت است / برنامه‌ای ندارد.
`M-96` (سقف ۸۰۰ خط) با همین سقف ۵۰۰ خطی جایگزین می‌شود.

**دروازهٔ پذیرش فاز ۲**
- [ ] `ls lib/features/movement/presentation/library` خطا می‌دهد.
- [ ] `ls lib/features/movement/presentation/progress` خطا می‌دهد.
- [ ] `ls lib/features/movement/presentation/occurrence` خطا می‌دهد.
- [ ] `ls lib/features/movement/presentation/strength` خطا می‌دهد.
- [ ] `ls lib/features/movement/presentation/center/sheets` خطا می‌دهد.
- [ ] `grep -rn "rir\|RIR" lib/features/movement/` خالی.
- [ ] `grep -rn "planB\|plan_b\|smartFill\|smart_fill\|reshuffle" lib/` خالی.
- [ ] تعداد فایل‌های `lib/features/movement/**/*.dart` حداکثر **۶۵ فایل** است.
- [ ] `flutter analyze` سبز و `flutter test` سبز.

---

## فاز ۳ — دیتابیس

این فاز خطرناک‌ترین فاز است. قانون `۰-۶` (دادهٔ کاربر تلف نمی‌شود) در هر بند این فاز حاکم است.

### D-31 — جداول `supplementary_sports`: همه می‌روند

**دستور قطعی (حدس ممنوع):**
1. فایل `lib/core/database/schema/tables/supplementary_sports_tables.dart` را کامل بخوان.
2. فهرست **دقیق** هر جدولی که آنجا تعریف شده را در `DELETION_REPORT.md` بنویس.
3. برای هر جدول، دقیقاً یکی از دو مسیر را برو:
   - اگر دادهٔ واقعیِ کاربر دارد (جلسات انجام‌شده یا ست‌های ثبت‌شده) → مهاجرت طبق `S-2` ، سپس `_legacy_` ، سپس `DROP` در مهاجرت بعدی.
   - در غیر این صورت → `DROP TABLE IF EXISTS` مستقیم در همین مهاجرت.
4. فایل `supplementary_sports_tables.dart` در پایان حذف می‌شود و ارجاعش از رجیستری جداول درمی‌آید.
5. متد `SupplementarySportsTables.ensureMovementMuscleFocus` حذف می‌شود. خودِ ستون `routines.movementMuscleFocus` طبق `D-25` می‌ماند ولی دیگر نوشته نمی‌شود.

**ممنوع:** نوشتن نام جدولی که از فایل نخوانده‌ای. اگر جدولی را در فایل پیدا نکردی ولی در دیتابیس هست، در گزارش بنویس و دست نزن.

### D-32 — نجات داده قبل از DROP

**ترتیب اجباری درون یک تراکنش:**
1. `SELECT COUNT(*)` از هر جدول SS که جلسه/ست دارد → عدد را ثبت کن.
2. `INSERT` به `movement_workout_logs` و `movement_set_logs`.
3. `SELECT COUNT(*)` دوباره از مقصد → باید دقیقاً به اندازهٔ منبع زیاد شده باشد.
4. اگر عددها نخواندند → `ROLLBACK` و توقف کل فاز. به فاز بعد نرو.
5. فقط بعد از تطابق عددها، `_legacy_` یا `DROP`.

یک تست مهاجرت بنویس که دقیقاً همین را می‌سنجد: `test/movement/ss_data_survival_test.dart`. دیتابیس تست باید از خود DDL تولید شود، نه از CREATE TABLE دستی در تست. (درسی که از ماژول چرخه گرفتیم: تست سبز با اسکیمای اشتباه بدتر از نبودن تست است.)

### D-33 — جداولی که از ابتدا ساخته نمی‌شوند

در پرامپت ادغام، این جداول جزء فهرست ۲۰تایی جداول قانونی بودند. **از فهرست حذف می‌شوند و هرگز ساخته نمی‌شوند:**
```
movement_budget
movement_slot_overrides
movement_decision_log
movement_analytics_events
movement_strength_programs
movement_exercise_similarity
movement_muscle_groups
movement_exercise_muscles
movement_exercise_tags
```
اگر هرکدام از این‌ها قبلاً در دیتابیس کاربران ساخته شده، `DROP TABLE IF EXISTS` مستقیم (بدون `_legacy_`، چون دادهٔ قابل نجاتی ندارند).

### D-34 — دلیل تک‌تک این حذف‌ها (تا دوباره برنگردند)

| جدول | چرا حذف |
|---|---|
| `movement_budget` | مفهوم بودجهٔ حرکتی در UI جدید وجود ندارد |
| `movement_slot_overrides` | همان کار `movement_occurrences.status = moved` |
| `movement_decision_log` | جدول حسابرسی‌ای که هیچ کدی نمی‌خواند |
| `movement_analytics_events` | مصرف‌کننده‌اش `D-15` بود |
| `movement_strength_programs` | سازندهٔ برنامه در `D-10`/`D-12` مرد |
| `movement_exercise_similarity` | فقط `swap_exercise_sheet` مصرفش می‌کرد (`D-11`) |
| `movement_muscle_groups` | `D-25` |
| `movement_exercise_muscles` | `D-25` |
| `movement_exercise_tags` | تگ‌ها فقط برای فیلتر در کتابخانه لازم بودند (`D-09`) |

### D-35 — حذف در سطح ستون

در جداولی که زنده می‌مانند، این ستون‌ها حذف می‌شوند (SQLite: ساخت جدول جدید + کپی + rename):
```
movement_set_logs.rir                  → D-11
movement_workout_logs.volumeKg         → همیشه 0.0 بود (M-68)
movement_exercises.animationAsset      → D-04 (اگر ساخته شده)
movement_exercises.muscleImageAsset    → D-04 (اگر ساخته شده)
movement_exercises.skillRequired / skill_max / sexyness*  → هرگز مهاجرت نمی‌کنند (M-24)
movement_plan_templates.draftStep      → بلااستفاده (M-86)
movement_plan_templates.draftDataJson  → بلااستفاده (M-86)
```
اگر ستونی از این فهرست در اسکیمای فعلی وجود ندارد، فقط مطمئن شو در مهاجرت‌های آینده هم ساخته نمی‌شود.

### D-36 — فهرست بستهٔ جداول باقی‌مانده (۱۲ جدول، نه ۲۰)

بعد از این فاز، ماژول حرکت **دقیقاً** این جداول را دارد. جدول جدیدی اضافه نمی‌شود.
```
movement_occurrences
movement_activity_kinds
movement_exercises
movement_workout_logs
movement_set_logs
movement_live_sessions
movement_personal_records
movement_readiness_checkins
movement_plan_templates
movement_plan_schedules
movement_plan_versions
movement_preferences
```
هر جدول دیگری که با پیشوند `movement_` در دیتابیس ماند، باگ است.

### D-37 — انضباط مهاجرت

- هر تغییر این فاز در یک فایل مهاجرت جدید با شمارهٔ بعدی، ثبت‌شده در `migrations_registry.dart`.
- مهاجرت موجود ویرایش نمی‌شود. شمارهٔ مهاجرت دوباره استفاده نمی‌شود.
- هر `DROP` با `IF EXISTS`.
- مهاجرت باید روی دیتابیسی که هیچ‌کدام از این جداول را ندارد هم بدون خطا اجرا شود (کاربر تازه‌نصب).
- `seed_service.dart` بعد از این فاز فقط دو چیز seed می‌کند: هشت نوع فعالیت در `movement_activity_kinds` و نام‌های فارسی در `movement_exercises` از `assets/movement/exercise_names.json`.

**دروازهٔ پذیرش فاز ۳**
- [ ] تست `ss_data_survival_test.dart` سبز است.
- [ ] `SELECT name FROM sqlite_master WHERE name LIKE 'ss_%'` خالی.
- [ ] `SELECT name FROM sqlite_master WHERE name LIKE 'movement_%'` دقیقاً ۱۲ ردیف `D-36` را برمی‌گرداند.
- [ ] مهاجرت روی یک دیتابیس خالی و یک دیتابیس پر هر دو بدون خطا اجرا می‌شود.

---

## فاز ۴ — تنظیمات، مسیرها، اعلان‌ها، asset ها

### D-38 — کلیدهای تنظیمات حذف‌شدنی

**واقعیت فعلی (`M-64`):** ده کلید تنظیمات که خوانده می‌شوند ولی روی هیچ رفتاری اثر ندارند.

**تصمیم قطعی:** `M-64` از «سیم‌کشی کن» به «حذف کن» تغییر می‌کند. هر یازده کلید زیر از کد حذف می‌شوند و ردیفشان با `DELETE FROM app_settings WHERE key IN (...)` از دیتابیس پاک می‌شود:
```
distance_unit                       → D-27
weight_unit                         → D-27
morning_reminder                    → D-42
pre_session_reminder                → D-42
keep_screen_on                      → همیشه روشن در جلسهٔ فعال
sound_enabled                       → راهنمای صوتی در D-06 مرد
countdown_seconds                   → ثابت 3 ثانیه
smart_suggestions_enabled           → پیشنهاد فقط از آمادگی می‌آید و قابل خاموش‌کردن نیست
intervention_level                  → کاربر نمی‌داند یعنی چه
plan_b_behavior                     → پلان B در D-20 مرد
module_supplementary_sports_enabled → D-43
```

### D-39 — صفحهٔ تنظیمات: حداکثر هشت کلید

**واقعیت فعلی:** `presentation/settings/movement_settings_screen.dart` ۲۱٬۴۰۱ بایت + پوشهٔ `widgets/`.

**تصمیم قطعی:**
- `presentation/settings/widgets/` حذف می‌شود. یک صفحهٔ تنظیمات با هشت ردیف ویجت اختصاصی نمی‌خواهد؛ `SwitchListTile` استاندارد کافی است.
- `movement_settings_screen.dart` بازنویسی می‌شود، سقف **۲۰۰ خط**.
- حداکثر **هشت** کلید قابل تنظیم. هر کلید نهمی که وسوسه شدی، حذف.
- هر کلیدی که باقی می‌ماند باید **در کد خوانده و روی رفتار اعمال شود.** تست ساده: برای هر کلید، `grep` بزن و حداقل یک محل مصرف خارج از صفحهٔ تنظیمات پیدا کن. اگر پیدا نکردی → کلید حذف می‌شود.

### D-40 — مسیرها: از دوازده به شش

**واقعیت فعلی (`M-71`):** دوازده مسیر تعریف‌شده که هیچ‌کدام در روتر ثبت نشده‌اند.

**حذف می‌شوند (شش مسیر):**
```
movement.library              → D-09
movement.occurrence           → D-16
movement.progress             → D-14
movement.strength             → D-10
movement.strength.onboarding  → D-10
movement.strength.preview     → D-10
```
**ثبت می‌شوند (شش مسیر، فهرست بسته):**
```
movement.center
movement.picker
movement.plan_editor
movement.session
movement.summary
movement.settings
```
فایل `presentation/movement_routes.dart` (۶۲۷ بایت) باید دقیقاً شش ثابت داشته باشد و هر شش در روتر اصلی ثبت شوند. یک تست بنویس که همین را تضمین کند: `test/movement/movement_routes_registered_test.dart`.

### D-41 — asset ها و `pubspec.yaml`

**حذف می‌شوند:**
- هر فایل Lottie حرکات.
- هر تصویر عضلات/آناتومی.
- هر فایل صوتی راهنمای جلسه.
- ردیف‌های متناظرشان در `pubspec.yaml`.
- پکیج‌هایی که بعد از این حذف‌ها صفر مصرف‌کننده دارند.

**اضافه می‌شود (تنها افزودنی مجاز در کل این پرامپت):**
```
assets/movement/exercise_names.json
```

**بررسی:** `flutter pub get` بعد از این تغییرات باید بدون هشدار asset گم‌شده اجرا شود.

### D-42 — اعلان‌ها: چهار نوع می‌شود یکی

**واقعیت فعلی (`M-63`):** چهار نوع یادآور `none` / `atTime` / `before` / `morning`، در حالی که کل `MovementNotificationService` کد مرده است (`M-59`).

**تصمیم قطعی:**
- `application/movement_notification_service.dart` (۸٬۷۹۰) **حذف نمی‌شود** — این تنها راهی است که اپ می‌تواند حرف بزند؛ سیم‌کشی می‌شود.
- ولی از چهار نوع یادآور، **فقط یکی می‌ماند**: یادآور در زمان جلسه. `morning_reminder` و `pre_session_reminder` حذف می‌شوند (`D-38`).
- **سقف سخت: حداکثر چهار اعلان در هفته از کل ماژول حرکت.** این سقف در کد پیاده می‌شود، نه در تنظیمات.
- `M-60` (شمارندهٔ `skippedPastDue`)، `M-61` (`?? 2026, ?? 1, ?? 1`) و `M-62` (`quiet_mode` که اعمال نمی‌شود) همچنان باید رفع شوند — این سه لغو نمی‌شوند.
- اعلان حرکت هرگز دربارهٔ چرخه یا وضعیت بدن حرف نمی‌زند (حریم خصوصی روی قفل صفحه).

### D-43 — یک کلید فعال‌سازی ماژول، نه دو

**واقعیت فعلی (`M-31`):** دو کلید `module_sports_enabled` و `module_supplementary_sports_enabled`.

**تصمیم قطعی:** `module_sports_enabled` تنها کلید است. در مهاجرت، مقدار نهایی = `(sports OR supplementary)`، سپس کلید دوم `DELETE` می‌شود.
`M-74` (مقدار هاردکد `isModuleEnabled = true`) رفع می‌شود و همه از `ModuleGate.instance.isEnabledFrom` می‌خوانند.

**دروازهٔ پذیرش فاز ۴**
- [ ] `grep -rn "module_supplementary_sports_enabled" lib/ test/` خالی.
- [ ] `grep -rn "distance_unit\|weight_unit\|keep_screen_on\|sound_enabled\|countdown_seconds\|intervention_level\|plan_b_behavior\|smart_suggestions_enabled\|morning_reminder\|pre_session_reminder" lib/ test/` خالی.
- [ ] `movement_routes.dart` دقیقاً شش ثابت دارد و هر شش ثبت شده‌اند.
- [ ] `movement_settings_screen.dart` کمتر از ۲۰۰ خط و حداکثر هشت کلید.
- [ ] `flutter pub get` بدون هشدار asset.

---

## فاز ۵ — تست‌ها و جاروی نهایی

### D-44 — تست‌های کدِ مرده

**دستور قطعی:** هر فایل تستی که کلاسی را تست می‌کند که در فازهای ۱ تا ۴ حذف شده، **حذف می‌شود**. کامنت کردن، `skip` کردن، یا `@Skip` زدن ممنوع است.

**ممنوعیت مطلق:** حذف یک تست فقط برای سبز شدن `flutter test`، وقتی کدِ تحت تست زنده است. اگر تستی قرمز شد و کدش زنده است → کد را درست کن، تست را نه.

**تست‌هایی که باید زنده بمانند و سبز باشند:**
```
test/unit/agenda/movement_agenda_no_duplicates_test.dart
test/unit/module_deactivation_sync_test.dart
```
**تست‌هایی که این پرامپت ایجاد می‌کند (سه تا، نه بیشتر):**
```
test/movement/ss_data_survival_test.dart          → D-32
test/movement/movement_routes_registered_test.dart → D-40
test/movement/movement_table_inventory_test.dart   → D-36 (دقیقاً 12 جدول)
```

### D-45 — جاروی یتیم‌ها

بعد از همهٔ فازها، این چرخه را **تا وقتی خروجی خالی شود** تکرار کن:
1. هر فایل `.dart` در `lib/features/movement/` را بگیر.
2. نام کلاس/تابع عمومیِ اصلی‌اش را در کل `lib/` و `test/` grep کن.
3. صفر مصرف‌کننده → `git rm`.
4. دوباره از مرحلهٔ ۱ (چون حذف هر فایل، فایل‌های جدیدی را یتیم می‌کند).

همین را برای `import` ها هم بزن: `dart fix --apply` و سپس دستی هر `import` بلااستفاده را حذف کن.

---

## جدول `M-xx` های لغو‌شده

این بندها در `RITMO_MOVEMENT_MERGE_PROMPT.md` هستند و **دیگر اجرا نمی‌شوند**. وقتی به آن پرامپت رسیدی، وضعیت هرکدام را `CANCELLED (code deleted)` بنویس.

| بند | موضوع | چرا لغو |
|---|---|---|
| `M-25` | جدول ۱۲تایی گروه‌های عضلانی | `D-25` |
| `M-48` | `resolveProgramStartDate` با fallback به `now()` | `D-12` |
| `M-49` | حلقهٔ بی‌پایان `((diff ~/ 7) % totalWeeks) + 1` | `D-12` |
| `M-50` | `RegExp(r'^plan_w(\\d+)_')` و `?? 4` | `D-12` |
| `M-51` | تکمیل هفته = `1.0` روی دادهٔ خالی | `D-12` |
| `M-52` | `daysPerWeek` که هرگز برنمی‌گردد | `D-12` |
| `M-53` | پنجرهٔ پیشرفت تدریجی | `D-21` |
| `M-70` | اصلاح محاسبهٔ بار عضلانی | `D-25` |
| `M-87` | `createPlansBatch` برای پرکردن هوشمند | `D-20` |
| `M-89` | چیپ دلیل روی کارت‌ها | `D-28` |
| `M-90` | سوایپ روی کارت جلسه | `D-20` (فقط `UndoToast` می‌ماند) |
| `M-91` | شیت هشتم برای اقدامات جلسه | `D-20` |
| `M-93` | جستجوی کتابخانه با debounce و `aliasesJson` | `D-09` |
| `M-94` | جدول مهاجرت SS ← movement در UI | `D-02`، `D-24` |
| `M-95` | ادغام دو جریان آنبوردینگ | `D-01`، `D-10` — هر دو جریان حذف شدند |
| `M-96` | سقف ۸۰۰ خط | با سقف ۵۰۰ خطی `D-30` جایگزین شد |
| `M-99` | `MovementDiagnosticsScreen` + `MovementDataDoctor` | صفحهٔ عیب‌یابی در باینری کاربر نهایی جایی ندارد |

**بندهایی که لغو نمی‌شوند و اهمیتشان بیشتر هم شد:** `M-44` تا `M-47` (آمادگی واقعی)، `M-59` تا `M-63` (اعلان)، `M-66` (رکورد)، `M-67` تا `M-69` (عددهای دروغین)، `M-73` تا `M-79` (اجندا و تاریخ)، `M-97` (حالت خالی)، `M-100` (دسترس‌پذیری). این بندها دقیقاً همان چیزی هستند که بعد از این حذف‌ها ماژول را مفید می‌کنند.

---

## دروازهٔ پذیرش نهایی

تا وقتی همهٔ این‌ها سبز نشده، کار تمام نیست.

**ساختار**
- [ ] `lib/features/supplementary_sports/` وجود ندارد.
- [ ] `grep -rn "supplementary_sports\|SupplementarySports\|SsPlan\|SsProfile\|SsSession" lib/ test/` خالی.
- [ ] `grep -rni "lottie" lib/ test/ pubspec.yaml` خالی.
- [ ] تعداد فایل‌های `lib/features/movement/**/*.dart` حداکثر ۶۵.
- [ ] هیچ فایل dart در ماژول حرکت بزرگ‌تر از ۵۰۰ خط نیست.

**دیتابیس**
- [ ] دقیقاً ۱۲ جدول `movement_*`.
- [ ] هیچ جدول `ss_*`.
- [ ] `ss_data_survival_test.dart` سبز.

**رفتار**
- [ ] اپ بالا می‌آید، تب حرکت باز می‌شود، ثبت یک جلسه کار می‌کند، و بعد از restart جلسه هنوز هست.
- [ ] هیچ مسیری به صفحهٔ حذف‌شده لینک نمی‌دهد (بدون صفحهٔ سفید، بدون کرش).
- [ ] در کل ماژول حرکت، حداکثر سه عدد به کاربر نشان داده می‌شود.

**ابزار**
- [ ] `flutter pub get` بدون خطا.
- [ ] `flutter analyze` بدون خطا (تعداد هشدار باید **کمتر** از baseline باشد، نه مساوی).
- [ ] `flutter test` کاملاً سبز.
- [ ] `DELETION_REPORT.md` برای هر `D-01` تا `D-45` یک ردیف با `DONE` یا `SKIPPED` + دلیل + بایت حذف‌شده دارد.
- [ ] جمع بایت‌های حذف‌شده در گزارش حداقل **۱٬۶۰۰٬۰۰۰ بایت** است. اگر کمتر است، یعنی جایی را نگه داشته‌ای که نباید — برگرد.

---

## نقشهٔ کامیت و پوش

یک کامیت به ازای هر فاز، دقیقاً با این پیام‌ها:
```
chore(movement): delete supplementary_sports module entirely (phase 1)
chore(movement): delete dead surfaces in movement module (phase 2)
chore(movement): drop obsolete tables and columns (phase 3)
chore(movement): trim settings, routes, notifications, assets (phase 4)
chore(movement): remove orphan tests and dead files (phase 5)
```
بعد از هر کامیت، هر سه دستور بررسی را اجرا کن. اگر قرمز شد، همانجا درست کن — به فاز بعد نرو.

**پوش:** فقط یک بار، در انتها، روی شاخهٔ `chore/movement-deletion`. بعد از پوش، خروجی `DELETION_REPORT.md` را در پاسخت برای من بگذار.

---

## آخرین حرف

اگر وسط کار به یک فایل رسیدی که حذفش سخت است چون جاهای زیادی بهش وصل است — این دلیل نگه داشتنش نیست؛ دلیل این است که مصرف‌کننده‌هایش هم باید بروند.

اگر به قابلیتی رسیدی که این پرامپت نامش را نبرده و از پنج آزمون `§۱` رد می‌شود — حذفش کن و در `DELETION_REPORT.md` زیر عنوان `EXTRA` بنویس.

هدف این پرامپت کوچک‌کردن کدبیس نیست. هدف این است که وقتی کاربر تب حرکت را باز می‌کند، دقیقاً بداند چه کاری باید بکند و در کمتر از پنج ثانیه ثبتش کند. هر خط کدی که بین کاربر و این دو اتفاق ایستاده، اضافی است.
