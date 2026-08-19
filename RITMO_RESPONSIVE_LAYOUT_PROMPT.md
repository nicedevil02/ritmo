# پرامپت اصلاح پاسخ‌گویی چیدمان و رفع سرریز رابط کاربری ریتمو (`R-01` … `R-92`)

**مخزن:** `nicedevil02/ritmo`
**مرجع کد این حسابرسی:** `2c8487fc56ad5b6bd88c4192ccf5600970b9070e`
**دامنه:** کل `lib/` — تمام ۲۸ ماژول ویژگی، به‌علاوهٔ `lib/core/`
**تعداد یافته:** ۹۲ مورد در ۷ فاز

---

## ۰. قواعد اجرای اجباری — پیش از نوشتن اولین خط کد بخوان

**۰-۱. نقشهٔ پیاده‌سازی نساز.** این سند خودش نقشهٔ پیاده‌سازی است. ترتیب فازها، ترتیب یافته‌ها و معیار پذیرش هر فاز از قبل تعیین شده. هیچ سند برنامه‌ریزی، هیچ فایل `PLAN.md`، هیچ بخش «تحلیل اولیه» و هیچ چرخهٔ «پیش‌نویس → ارزیابی → بازنویسی» تولید نکن. مستقیم برو سراغ `R-01` و کد بنویس.

**۰-۲. بخش ۲ فایل `.agents/AGENTS.md` برای این کار لغو است.** آن بخش تو را به نوشتن یک نقشهٔ سه‌چرخه‌ای اجباری موظف می‌کند؛ در این کار اجرا نمی‌شود. بخش ۱ (سبک کد) و بخش ۳ (قواعد کامیت) کاملاً برقرار می‌مانند.

**۰-۳. ترتیب فازها اجباری است.** فاز ۰ زیرساخت است و همهٔ فازهای بعدی به آن تکیه می‌کنند. اگر فاز ۰ را رد کنی، فازهای ۱ تا ۵ به کدی ارجاع می‌دهند که وجود ندارد و کامپایل نمی‌شود. فاز بعدی را شروع نکن تا دروازهٔ پذیرش فاز فعلی سبز نشده باشد.

**۰-۴. هر یافته سه حالت پایانی دارد و فقط سه حالت:**
- `انجام شد` — کد نوشته شد، تست سبز است، دستور تأیید اجرا شد.
- `منتفی شد` — با خواندن کد ثابت شد که مشکل وجود ندارد. **باید** فایل و شمارهٔ خط و دلیل را بنویسی.
- `مسدود شد` — به تصمیم محصولی یا مهاجرت داده یا بستهٔ جدید نیاز دارد. **باید** بنویسی چه چیزی مسدودش کرده.

هیچ یافته‌ای را با «تا حدی انجام شد» یا «در فاز بعد» رها نکن.

**۰-۵. خودگزارش‌دهی ممنوع است؛ فقط کد سند است.** در این مخزن سابقهٔ مستند وجود دارد که سند پیشرفت، پیاده‌سازی‌هایی را ✅ اعلام کرده که در کد نبودند — مثلاً `docs/ai/WEB_BRIDGE_FIX_PROGRESS.md` نام‌های `__ritmo_detach` و `__ritmo_stopGeneration` و `__ritmo_composerReady` و `__ritmo_origFetch` را تأییدشده اعلام کرد، در حالی که کد واقعی `__ritmo_cleanup` و `__ritmo_cancelGeneration` و `__ritmo_checkComposerReady` و `__ritmo_original_fetch` داشت. برای هر ادعا در این کار، خروجی `rg` یا مسیر فایل و شمارهٔ خط بگذار.

**۰-۶. فهرست تغییرات مجاز.** فقط این‌ها را لمس کن:
- `lib/core/theme/tokens/` — فایل جدید نقطه‌شکست
- `lib/core/widgets/` و `lib/core/widgets/sheet/` — ویجت‌های مشترک پاسخ‌گو
- `lib/main.dart` — فقط بند مربوط به `textScaler`
- فایل‌های ویجت و صفحهٔ نام‌برده‌شده در یافته‌ها
- `test/` — افزودن تست، و اصلاح دو تست تقلبی که در `R-09` و `R-10` نام برده شده‌اند
- `lib/l10n/app_fa.arb` و `lib/l10n/app_en.arb` — فقط کلیدهای نام‌برده‌شده
- `docs/` — فقط فایل‌های نام‌برده‌شده در فاز ۶

**۰-۷. جدول ممنوعیت‌ها.** هیچ‌کدام از این‌ها در کد جدید مجاز نیست:

| # | ممنوع | چرا |
|---|---|---|
| ۱ | `height: MediaQuery.of(context).size.height * <ضریب>` | ارتفاع صُلب؛ ریشهٔ اصلی سرریز (ریشهٔ ۲) |
| ۲ | `MediaQuery.of(context).size` برای تصمیم چیدمان | نوار وضعیت و نوار ناوبری و صفحه‌کلید را نادیده می‌گیرد؛ از `constraints` یا `RitmoBreakpoints` استفاده کن |
| ۳ | `childAspectRatio` ثابت همراه `crossAxisCount` ثابت | با بزرگ‌شدن متن، محتوای خانه بلندتر از خانه می‌شود |
| ۴ | `fontSize:` سخت‌کدشده | تم و مقیاس متن را دور می‌زند |
| ۵ | `Color(0x...)` سخت‌کدشده | توکن‌های `context.colors` را دور می‌زند |
| ۶ | رشتهٔ فارسی سخت‌کدشده در ویجت جدید | باید از `AppLocalizations` بیاید |
| ۷ | `catch (_) {}` یا `catch (e) {}` بدون ثبت لاگ | خفه‌کردن خطا |
| ۸ | `skip:` در تست‌های `test/` این کار | پنهان‌کردن شکست |
| ۹ | خفه‌کردن خطای `overflowed` در `FlutterError.onError` | همان تقلبی که در `R-09` رفع می‌شود |
| ۱۰ | `tester.view.physicalSize` بزرگ‌تر از ۴۱۴×۹۰۰ برای فرار از سرریز | همان تقلبی که در `R-10` رفع می‌شود |
| ۱۱ | بستهٔ جدید در `pubspec.yaml` | همه‌چیز با Flutter خالص قابل حل است |
| ۱۲ | `Expanded` یا `Flexible` به‌عنوان فرزند مستقیم `SingleChildScrollView` | خطای زمان اجرا |

**۰-۸. قاعدهٔ «کوچک‌ترین اول».** هر چیدمانی را با فرض بدترین حالت طراحی کن، نه بهترین: عرض ۳۲۰ منطقی، ارتفاع قابل استفادهٔ ۵۶۰ منطقی، مقیاس متن ۱٫۶، جهت راست‌به‌چپ، و صفحه‌کلید باز. اگر در این شرایط جا شد، در همهٔ گوشی‌ها جا می‌شود. عکسش درست نیست.

**۰-۹. قاعدهٔ «سرریز هرگز پذیرفتنی نیست، اما بریدن متن پذیرفتنی است».** وقتی فضا کم است، ترتیب راه‌حل‌ها این است: (۱) شکستن به چند خط، (۲) `TextOverflow.ellipsis` با `maxLines`، (۳) تبدیل `Row` به `Wrap`، (۴) اسکرول‌پذیر کردن، (۵) حذف عنصر کم‌اهمیت با `Semantics` جانشین. **هیچ‌وقت** راه‌حل «کوچک‌کردن فونت با ضریب» نیست، و **هیچ‌وقت** راه‌حل «پنهان‌کردن خطا» نیست.

**۰-۱۰. هیچ تغییر رفتاری بدون تست محافظ.** هر یافته‌ای که چیدمان را عوض می‌کند باید یک تست داشته باشد که پیش از تغییر قرمز و پس از آن سبز است. اگر نمی‌توانی تست بنویسی، یافته را `مسدود شد` علامت بزن و دلیل را بنویس؛ بی‌تست تغییر نده.

**۰-۱۱. دستورهای تأیید هر فاز.** در پایان هر فاز این‌ها را اجرا کن و خروجی واقعی را در سند پیشرفت بنویس:
```
flutter analyze
flutter test
dart format --set-exit-if-changed lib test
```
و هرجا `l10n` عوض شد:
```
flutter gen-l10n
```

**۰-۱۲. گاردهای متنی سرتاسری.** این‌ها باید در پایان فاز ۵ خروجی خالی بدهند:
```
rg -n "height: MediaQuery.of(context).size.height" lib/
rg -n "fontSize:" lib/core/widgets lib/core/theme/tokens
rg -n "overflowed" test/ --glob '!**/responsive_*'
rg -n "catch \\(_\\) \\{\\}" lib/
```
و این‌ها باید خروجی **غیرخالی** بدهند:
```
rg -n "RitmoBreakpoints" lib/            # حداقل ۲۵ مورد
rg -n "RitmoSheetScaffold" lib/          # حداقل ۲۰ مورد
rg -n "RitmoAdaptiveGrid" lib/           # حداقل ۱۲ مورد
```

**۰-۱۳. زبان.** همهٔ متن‌های کاربرپسند فارسی است. توضیحات کد فارسی یا انگلیسی، اما نام نمادها انگلیسی. اعداد فارسی از همان کمکی که در پروژه هست (`persian_digits.dart`) عبور کنند.

**۰-۱۴. حدس نزن.** اگر نام نماد یا امضای تابعی در این سند نیست، **اول فایل را بخوان**. این سند دقیقاً ۹۲ یافته دارد و هرکدام مسیر فایل دقیق دارد. مسیر را باز کن، بخوان، بعد تغییر بده.

**۰-۱۵. کامیت صادق.** یک کامیت به‌ازای هر فاز، با فهرست دقیق شناسه‌ها. هرگز شناسه‌ای را در کامیت ننویس که کدش را ننوشته‌ای. در این مخزن سابقهٔ ادعای دوگانه وجود دارد (`A-48` تا `A-50` هم در `05d56e03` و هم در `9fbb460` ادعا شده‌اند) — تکرارش نکن.

---

## ۱. تشخیص ریشه‌ای تأییدشده — چرا رابط کاربری در گوشی‌های مختلف می‌شکند

هر شش ریشه با جست‌وجوی کد در مرجع `2c8487fc` تأیید شده‌اند. اعداد، شمارش واقعی هستند.

### ریشهٔ ۱ — هیچ سیستم نقطه‌شکستی در برنامه وجود ندارد

جست‌وجوی سرتاسری برای هر نوع نقطه‌شکست در کد Dart، **صفر** نتیجه داد. هیچ فایلی به نام نقطه‌شکست، هیچ کلاس `Breakpoints`، هیچ `enum` کلاس دستگاه، هیچ نقطهٔ مرجع مشترکی وجود ندارد.

نتیجه: هر ویجتی که خواسته پاسخ‌گو باشد، عدد جادویی خودش را از نو ساخته. سه نمونهٔ واقعی با سه عدد متفاوت:
- `lib/features/movement/presentation/activity_picker/widgets/activity_category_section.dart` → `isWide = constraints.maxWidth >= 600` و بعد `crossAxisCount = isWide ? 3 : (constraints.maxWidth > 340 ? 2 : 1)`
- `lib/features/calendar/presentation/widgets/now_pill.dart` → `showPrefix = width >= 300`
- `lib/features/calendar/presentation/widgets/timeline_split_day_view.dart` → `constraints.maxWidth < CalendarGeometry.splitMinScreenWidth`

سه آستانهٔ ۶۰۰ و ۳۴۰ و ۳۰۰ و یک ثابت ماژولی، هیچ‌کدام با هم هماهنگ نیستند. هیچ‌کس نمی‌داند «گوشی کوچک» در ریتمو یعنی چه.

### ریشهٔ ۲ — ارتفاع شیت‌ها صُلب است و از ارتفاع **کل** صفحه گرفته می‌شود

این بزرگ‌ترین و پرتکرارترین ریشه است: **۳۹ مورد** استفاده از `MediaQuery.of(context).size` در `lib/` که اکثر قاطعشان این شکل را دارند:

```dart
Container(
  height: MediaQuery.of(context).size.height * 0.85,
  child: Column(children: [...]),
)
```

سه اشکال مستقل در همین سه خط جمع شده‌اند:

۱. **`size.height` ارتفاع کل نمایشگر است**، شامل نوار وضعیت و نوار ناوبری سیستم. در گوشی‌ای با نوار ناوبری بزرگ، ۸۵٪ ارتفاع کل ممکن است از ۱۰۰٪ ارتفاع قابل استفاده بیشتر باشد.

۲. **`height:` صُلب است، نه `maxHeight:`**. یعنی جعبه هم کف دارد هم سقف. اگر محتوا کمتر باشد فضای خالی می‌ماند؛ اگر بیشتر باشد `Column` سرریز می‌کند و همان خط زرد و مشکی «BOTTOM OVERFLOWED BY … PIXELS» ظاهر می‌شود.

۳. **صفحه‌کلید نادیده گرفته می‌شود**. وقتی کاربر روی فیلد متنی می‌زند، ارتفاع قابل استفاده تقریباً نصف می‌شود، اما `height:` عوض نمی‌شود.

ضریب‌های واقعی که در کد پیدا شدند، بدون هیچ منطقی پراکنده‌اند: `0.6` و `0.65` و `0.68` و `0.7` و `0.75` و `0.76` و `0.8` و `0.82` و `0.85` و `0.88` و `0.9` و `0.92`. دوازده ضریب متفاوت برای یک مسئله.

### ریشهٔ ۳ — گریدها نسبت ابعاد ثابت و شمار ستون ثابت دارند

**۱۶ مورد** `childAspectRatio` در `lib/` که همه‌شان با `crossAxisCount` ثابت جفت شده‌اند. مثال‌های واقعی:
- `lib/features/settings/presentation/widgets/quick_settings_sheet.dart` → `childAspectRatio: 2.2`
- `lib/features/profile/presentation/cycle_harmony_screen.dart` → `crossAxisCount: 2, childAspectRatio: 2.3`
- `lib/features/energy/presentation/widgets/quick_log_sheet.dart` → `crossAxisCount: 4, childAspectRatio: 1.1`
- `lib/features/assistant/presentation/widgets/assistant_briefing_section.dart` → `crossAxisCount: 2, childAspectRatio: 2.1`

ریاضیات این باگ ساده و قطعی است. با `crossAxisCount: 2` و `childAspectRatio: 2.2` در عرض ۳۲۰ منطقی، ارتفاع هر خانه حدود ۷۰ پیکسل می‌شود. کارتی که دو خط متن و یک آیکون دارد، در مقیاس متن ۱٫۶ به بیش از ۹۰ پیکسل نیاز دارد. خانه بزرگ نمی‌شود، چون نسبتش قفل است. پس محتوا سرریز می‌کند. `crossAxisCount: 4` با عرض ۳۲۰ یعنی خانه‌های ۷۰ پیکسلی — هر برچسبی بلندتر از یک کلمه می‌شکند.

### ریشهٔ ۴ — مشکل مقیاس متن با یک چسب زخم پنهان شده است

در `lib/main.dart`:

```dart
return MediaQuery(
  data: mq.copyWith(
    textScaler: mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.3),
  ),
  child: AppLockGate(child: child!),
);
```

این سقف ۱٫۳ سه پیامد دارد:

۱. **دسترس‌پذیری را می‌شکند.** کاربری که در تنظیمات اندروید فونت را روی بزرگ‌ترین حالت گذاشته، عملاً نادیده گرفته می‌شود. این یک تصمیم محصولی است که هیچ‌جا مستند نشده.

۲. **باگ را پنهان می‌کند، حل نمی‌کند.** چیدمان‌ها هنوز شکننده‌اند؛ فقط با اسلحهٔ کم‌قدرت‌تری به آن‌ها شلیک می‌شود.

۳. **با تست‌ها ناسازگار است.** `test/golden/component_gallery_golden_test.dart` و `test/settings/settings_text_scale_resilience_test.dart` تا مقیاس ۱٫۶ و بیشتر تست می‌کنند، در حالی که برنامهٔ واقعی هرگز بالای ۱٫۳ نمی‌رود. یعنی یا تست‌ها بی‌ربط هستند یا کلمپ اشتباه است. هر دو نمی‌توانند درست باشند.

توجه: عدد ۱٫۳ در جدول ممنوعیت‌ها نیست و قرار نیست همین حالا به ۲٫۰ برود. `R-08` تصمیم قطعی را مشخص می‌کند.

### ریشهٔ ۵ — تست‌ها سرریز را خفه یا پنهان می‌کنند

دو تقلب مستند در پوشهٔ تست پیدا شد. این‌ها بدترین بخش این حسابرسی‌اند، چون یعنی سرریز **دیده شده** و بعد ساکت شده.

**تقلب یک** — `test/widget/niyyah_edit_sheet_stays_open_test.dart`:
```dart
// Suppress expected overflow exceptions from planner date picker in constrained test environment
FlutterError.onError = (FlutterErrorDetails details) {
  if (details.toString().contains('overflowed') || details.toString().contains('databaseFactory')) {
    return; // suppress known test-environment-only issues
  }
```
کامنت می‌گوید «مسئلهٔ مخصوص محیط تست». این درست نیست. سرریز انتخاب‌گر تاریخ در محیط تنگ، **دقیقاً همان چیزی است که کاربر روی گوشی کوچک می‌بیند**. این تست یک باگ واقعی را برچسب «مصنوع تست» زده و ساکتش کرده.

**تقلب دو** — `test/features/movement/presentation/activity_plan_editor_test.dart`:
```dart
testWidgets('Renders all 8-step building blocks without overflow', (tester) async {
  tester.view.physicalSize = const Size(800, 1800);
```
عنوان تست می‌گوید «بدون سرریز»، اما بومِ تست را به ۸۰۰×۱۸۰۰ بزرگ کرده — بزرگ‌تر از هر گوشی‌ای که این برنامه روی آن اجرا می‌شود. این تست هیچ‌چیز را اثبات نمی‌کند.

**پوشش تست سرریز فقط چهار ماژول است:** حرکت، تقویم، تنظیمات، حال و تعادل. بیست‌وچهار ماژول دیگر هیچ تست سرریزی ندارند. و فقط **یک** فایل در کل مخزن روی چند عرض حلقه می‌زند: `test/settings/settings_text_scale_resilience_test.dart` با `screenWidths = [320.0, 390.0, 414.0]`.

### ریشهٔ ۶ — الگوی درست وجود دارد، ولی تقریباً استفاده نمی‌شود

فایل `lib/core/widgets/ritmo_sheet_scaffold.dart` تقریباً همه‌چیز را درست انجام می‌دهد:

```dart
return Padding(
  padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
  child: Container(
    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [ /* ... */ Flexible(child: SingleChildScrollView(child: child)) ],
    ),
  ),
);
```

`maxHeight` به‌جای `height`، `mainAxisSize: MainAxisSize.min`، `Flexible` دور محتوا، `SingleChildScrollView`، احترام به `viewInsets.bottom`، و در متد `present` هم `useSafeArea: true` و `isScrollControlled: true`. این دقیقاً معماری درست است.

دو مشکل: اول، کامنت خودش دامنه را محدود کرده — «تنها راه مجاز باز کردن شیت **در بخش حال و تعادل**». دوم، همان `size.height * 0.9` را دارد که باید به `constraints` تبدیل شود.

پس تیم راه‌حل را یک بار پیدا کرده، در یک ماژول به کار برده، و بعد ۳۹ جای دیگر از صفر و غلط نوشته. کار این پرامپت این است که آن راه‌حل را سرتاسری کند.

---

## ۲. تصمیم‌های قطعی معماری — قابل مذاکره نیستند

**ت-۱ — یک منبع حقیقت برای اندازه.** همهٔ تصمیم‌های چیدمانی وابسته به اندازه، از `RitmoBreakpoints` می‌آیند. هیچ عدد جادویی جدیدی در هیچ ویجتی مجاز نیست. آستانه‌های موجود (۳۰۰، ۳۴۰، ۶۰۰، `CalendarGeometry.splitMinScreenWidth`، `MovementLayout.kDaySlotMinSize`) به این منبع مهاجرت می‌کنند یا با ارجاع به آن بازنویسی می‌شوند.

**ت-۲ — `constraints` بر `MediaQuery.size` مقدم است.** برای تصمیم چیدمان، اندازهٔ **جعبهٔ خودت** مهم است نه اندازهٔ نمایشگر. یک کارت داخل یک ستون داخل یک شیت، عرضش هیچ ربطی به عرض گوشی ندارد. استفاده از `MediaQuery.of(context).size` برای چیدمان یک باگ است، نه یک سبک.

**ت-۳ — ارتفاع همیشه سقف است، هرگز مقدار قطعی نیست.** برای هر ظرفی که محتوای متنی دارد: `maxHeight` بله، `height` نه. تنها استثنا عناصر تزئینی با ابعاد ثابت واقعی هستند (دستهٔ شیت، جداکننده، حلقهٔ پیشرفت).

**ت-۴ — ارتفاع قابل استفاده، نه ارتفاع نمایشگر.** فرمول درست ارتفاع در دسترس این است:
```
size.height - padding.top - padding.bottom - viewInsets.bottom
```
این در `RitmoBreakpoints.usableHeight(context)` یک بار پیاده می‌شود و همه‌جا از آن استفاده می‌شود.

**ت-۵ — گرید بر پایهٔ عرض کمینهٔ خانه، نه شمار ستون.** به‌جای «۴ ستون بساز»، بگو «هر خانه دست‌کم ۱۵۰ منطقی عرض داشته باشد و بقیه را خودت حساب کن». این تنها راهی است که یک گرید هم روی ۳۲۰ و هم روی ۴۳۰ درست کار کند.

**ت-۶ — ارتفاع خانهٔ گرید از محتوا می‌آید، نه از نسبت.** `childAspectRatio` برای محتوای متنی ممنوع است. جانشین‌ها به ترتیب اولویت: `Wrap` با عرض محاسبه‌شده (الگوی موجود در `kpi_grid.dart`)، یا `SliverGridDelegateWithMaxCrossAxisExtent` با `mainAxisExtent` محاسبه‌شده، یا `StaggeredGrid`. نسبت ابعاد فقط برای محتوای واقعاً مربعی مثل خانهٔ تقویم مجاز است، و آنجا هم باید کف ارتفاع داشته باشد.

**ت-۷ — بریدن متن باید صریح و آگاهانه باشد.** هر `Text` که ممکن است بلند شود، یا `maxLines` و `overflow` دارد، یا داخل `Expanded`/`Flexible` است، یا داخل `Wrap` است. «هیچ‌کدام» پذیرفتنی نیست. و هرجا متن بریده می‌شود، `Semantics(label:)` یا `Tooltip` متن کامل را نگه می‌دارد تا اطلاعات از دست نرود.

**ت-۸ — صفحه‌کلید یک حالت چیدمانی است، نه یک رویداد.** هر صفحه‌ای که ورودی متنی دارد باید در حالت صفحه‌کلید-باز هم قابل استفاده باشد: دکمهٔ ثبت در دسترس، فیلد فعال دیده شود، و هیچ سرریزی نباشد. `viewInsets.bottom` و `Scaffold(resizeToAvoidBottomInset:)` ابزار کارند.

**ت-۹ — تست، بومش را بزرگ نمی‌کند.** تست چیدمان روی کوچک‌ترین بوم واقعی اجرا می‌شود، نه بزرگ‌ترین. اگر تستی برای عبور کردن به بوم بزرگ نیاز دارد، آن تست دارد یک باگ را پنهان می‌کند. این قاعده مستقیماً `R-10` را می‌سازد.

**ت-۱۰ — خطای سرریز هرگز خفه نمی‌شود.** `FlutterError.onError` فقط برای **ثبت و اثبات** سرریز مجاز است، هرگز برای رد کردنش. هر جای موجودی که سرریز را رد می‌کند، در `R-09` اصلاح می‌شود.

**ت-۱۱ — واقعیت میدانی مقدم بر تست سبز است.** صاحب محصول گفته: «تقریباً در هیچ جای برنامه برای گوشی‌ها با اندازه‌های مختلف فکر نشده و در بعضی گوشی‌ها بعضی جاهای برنامه سرریز می‌شود». در حال حاضر `flutter test` سبز است. پس سبزیِ تست، معیار موفقیت نیست. معیار موفقیت این است که فاز ۶ تست‌هایی بسازد که **امروز قرمز شوند**. اگر تست‌های جدید فاز ۶ از اول سبز باشند، یعنی بد نوشته شده‌اند.

**ت-۱۲ — بدون بستهٔ جدید.** همهٔ این‌ها با `LayoutBuilder` و `ConstrainedBox` و `Wrap` و `Flexible` و `FittedBox` و `MediaQuery` خالص حل می‌شوند. هیچ بستهٔ پاسخ‌گویی از pub اضافه نکن.

---

## فاز ۰ — زیرساخت پاسخ‌گویی (`R-01` … `R-12`)

این فاز هیچ باگ قابل مشاهده‌ای را رفع نمی‌کند. ابزارهایی را می‌سازد که فازهای ۱ تا ۶ بدون آن‌ها مجبورند همان اعداد جادویی را تکرار کنند. **این فاز را رد نکن.**

### R-01 — فایل نقطه‌شکست مرکزی

فایل جدید بساز: `lib/core/theme/tokens/ritmo_breakpoints.dart`

این فایل باید دقیقاً این اجزا را داشته باشد:

```dart
/// کلاس عرض دستگاه. مرزها بر پایهٔ عرض منطقی (logical pixels) هستند.
enum RitmoWidthClass {
  /// تا ۳۵۹ — گوشی‌های کوچک و قدیمی (iPhone SE، اندرویدهای ارزان)
  compact,
  /// ۳۶۰ تا ۴۰۹ — حالت مرجع طراحی
  regular,
  /// ۴۱۰ تا ۵۹۹ — گوشی‌های بزرگ و پلاس
  large,
  /// ۶۰۰ و بالاتر — تبلت و حالت افقی
  expanded,
}

/// کلاس ارتفاع دستگاه — بر پایهٔ ارتفاع **قابل استفاده**، نه ارتفاع نمایشگر.
enum RitmoHeightClass {
  /// تا ۶۳۹ — گوشی کوتاه یا صفحه‌کلید باز
  short,
  /// ۶۴۰ تا ۸۴۳
  regular,
  /// ۸۴۴ و بالاتر
  tall,
}

abstract final class RitmoBreakpoints {
  // مرزهای عرض
  static const double compactMaxWidth = 359.0;
  static const double regularMaxWidth = 409.0;
  static const double largeMaxWidth = 599.0;

  // مرزهای ارتفاع قابل استفاده
  static const double shortMaxHeight = 639.0;
  static const double regularMaxHeight = 843.0;

  // کمینهٔ عرض خانه‌ها — جانشین قانونی crossAxisCount ثابت
  static const double tileMinWidthCompact = 140.0;
  static const double tileMinWidthRegular = 160.0;
  static const double tileMinWidthWide = 190.0;

  // هدف لمس — راهنمای دسترس‌پذیری
  static const double minTouchTarget = 48.0;

  // سقف مقیاس متن که برنامه رسماً پشتیبانی می‌کند (R-08)
  static const double supportedMaxTextScale = 1.6;
  static const double supportedMinTextScale = 0.9;

  static RitmoWidthClass widthClassOf(double width) { /* ... */ }
  static RitmoHeightClass heightClassOf(double usableHeight) { /* ... */ }

  /// ارتفاع واقعاً قابل استفاده: ارتفاع نمایشگر منهای نوارهای سیستمی و صفحه‌کلید.
  /// این تنها فرمول مجاز محاسبهٔ ارتفاع در کل برنامه است.
  static double usableHeight(BuildContext context) {
    final mq = MediaQuery.of(context);
    return mq.size.height - mq.padding.top - mq.padding.bottom - mq.viewInsets.bottom;
  }

  /// سقف ارتفاع یک شیت. هرگز مقدار قطعی نیست — فقط سقف.
  static double sheetMaxHeight(BuildContext context, {double factor = 0.9}) { /* ... */ }

  /// شمار ستون محاسبه‌شده از عرض موجود و کمینهٔ عرض خانه.
  /// همیشه دست‌کم ۱ برمی‌گرداند.
  static int columnsFor({
    required double availableWidth,
    required double minTileWidth,
    required double spacing,
    int maxColumns = 4,
  }) { /* ... */ }
}
```

**قواعد طراحی این فایل:**
۱. هیچ وابستگی به تم یا رنگ نداشته باشد — فقط `flutter/widgets.dart`. این یک فایل هندسه است، نه فایل سبک.
۲. `columnsFor` باید خالص (pure) و مستقیماً قابل تست باشد — بدون `BuildContext`.
۳. `usableHeight` و `sheetMaxHeight` تنها توابعی هستند که `BuildContext` می‌گیرند.
۴. مرز ۶۰۰ را عوض نکن — دو جای موجود در کد همین عدد را دارند (`activity_category_section.dart`) و تغییرش رفتار دیده‌شده را عوض می‌کند.
۵. مقادیر `tileMinWidth*` را از خودت درنیاور — همین سه عدد را بگذار.

**دستور تأیید:** `rg -n "class RitmoBreakpoints|enum RitmoWidthClass|enum RitmoHeightClass" lib/` باید سه خط بدهد.

### R-02 — گسترش `BuildContext` برای دسترسی راحت

در همان فایل `R-01`، یک `extension` اضافه کن تا کد مقصد خوانا بماند:

```dart
extension RitmoScreenX on BuildContext {
  RitmoWidthClass get widthClass =>
      RitmoBreakpoints.widthClassOf(MediaQuery.sizeOf(this).width);

  RitmoHeightClass get heightClass =>
      RitmoBreakpoints.heightClassOf(RitmoBreakpoints.usableHeight(this));

  bool get isCompactWidth => widthClass == RitmoWidthClass.compact;
  bool get isShortHeight => heightClass == RitmoHeightClass.short;

  /// مقیاس متن فعلی به‌صورت عدد.
  double get textScale => MediaQuery.textScalerOf(this).scale(1.0);

  /// مقیاس متن بزرگ — مرز تصمیم‌گیری برای چیدمان جایگزین.
  bool get isLargeTextScale => textScale > 1.2;

  /// صفحه‌کلید باز است.
  bool get isKeyboardOpen => MediaQuery.viewInsetsOf(this).bottom > 0;
}
```

**دلیل وجود `isLargeTextScale` با مرز ۱٫۲:** دو جای موجود در کد دقیقاً همین مرز را دارند و باید به این گسترش مهاجرت کنند (بدون تغییر رفتار):
- `lib/features/movement/presentation/session/widgets/session_primary_cta.dart` → `final textScale = MediaQuery.textScalerOf(context).scale(1.0); final buttonHeight = textScale > 1.2 ? MovementLayout.kPrimaryButtonHeightLarge : MovementLayout.kPrimaryButtonHeight;`
- `lib/features/movement/presentation/common/undo_toast.dart` → `final isAccessible = textScale > 1.2 || MediaQuery.accessibleNavigationOf(context);`

این دو فایل را به `context.isLargeTextScale` منتقل کن. منطق را عوض نکن؛ فقط منبع عدد را یکی کن. تست‌های موجود `test/features/movement/undo_toast_test.dart` باید **بدون تغییر** سبز بمانند. اگر قرمز شدند، رفتار را عوض کرده‌ای — برگرد و درستش کن.

### R-03 — ارتقای `RitmoSheetScaffold` به استاندارد سرتاسری

فایل: `lib/core/widgets/ritmo_sheet_scaffold.dart` (فعلاً ۳٬۸۰۱ بایت)

چهار تغییر دقیق:

**الف — کامنت دامنه را حذف کن.** خط فعلی این است:
```dart
/// تنها راه مجاز باز کردن شیت در بخش حال و تعادل (T-4.7 / W-45).
```
جایگزین کن با:
```dart
/// تنها راه مجاز باز کردن شیت در کل برنامه (R-03).
/// این ویجت ارتفاع را سقف می‌گیرد نه قطعی، به صفحه‌کلید احترام می‌گذارد،
/// و محتوا را اسکرول‌پذیر می‌کند. هیچ شیت جدیدی بیرون این ویجت ساخته نشود.
```

**ب — `size.height * 0.9` را حذف کن.** خط فعلی:
```dart
constraints: BoxConstraints(
  maxHeight: MediaQuery.of(context).size.height * 0.9,
),
```
جایگزین:
```dart
constraints: BoxConstraints(
  maxHeight: RitmoBreakpoints.sheetMaxHeight(context, factor: maxHeightFactor),
),
```

**ج — دو پارامتر جدید اضافه کن:**
```dart
/// سقف ارتفاع نسبت به ارتفاع قابل استفاده. پیش‌فرض ۰٫۹.
final double maxHeightFactor;

/// ویجت‌های چسبیده به پایین شیت که اسکرول نمی‌شوند (معمولاً دکمهٔ ثبت).
/// این پارامتر دلیل اصلی وجود ۳۹ شیت دست‌ساز است — بدون آن، تیم مجبور شد دورش را بزند.
final Widget? footer;
```
`footer` باید **بیرون** `Flexible(child: SingleChildScrollView(...))` و درون همان `Column` قرار بگیرد، با `SafeArea(top: false)` دورش.

**د — در متد `present`، یک پارامتر اختیاری اضافه کن** تا شیت‌هایی که محتوای خودشان را اسکرول می‌کنند (مانند شیت‌های دارای `ListView`) دوبار اسکرول نشوند:
```dart
/// اگر محتوا خودش اسکرول‌پذیر است (ListView / CustomScrollView)، این را true بگذار.
/// در این حالت بدنه در `Flexible` می‌رود ولی در SingleChildScrollView پیچیده نمی‌شود.
final bool childIsScrollable;
```

**ممنوع:** `Container(height: ...)` در این فایل. **ممنوع:** حذف `useSafeArea: true` یا `isScrollControlled: true` از `present`.

### R-04 — ویجت گرید واقعاً پاسخ‌گو

فایل جدید: `lib/core/widgets/ritmo_adaptive_grid.dart`

```dart
/// گریدی که شمار ستون را از عرض موجود می‌سازد و ارتفاع خانه را از محتوا.
/// جانشین مستقیم هر GridView با crossAxisCount و childAspectRatio ثابت.
class RitmoAdaptiveGrid extends StatelessWidget {
  const RitmoAdaptiveGrid({
    super.key,
    required this.children,
    this.minTileWidth,
    this.spacing = RitmoSpacing.md,
    this.maxColumns = 4,
  });

  final List<Widget> children;
  /// پیش‌فرض: از کلاس عرض دستگاه گرفته می‌شود.
  final double? minTileWidth;
  final double spacing;
  final int maxColumns;
}
```

**پیاده‌سازی اجباری با `LayoutBuilder` + `Wrap`**، دقیقاً به سبک الگوی موجود و سالم در `lib/features/movement/presentation/progress/widgets/kpi_grid.dart`:
```dart
return LayoutBuilder(
  builder: (context, constraints) {
    final itemWidth = (constraints.maxWidth - RitmoSpacing.md) / 2;
    return Wrap(/* ... */);
  },
);
```

اما با دو اصلاح: شمار ستون از `RitmoBreakpoints.columnsFor` بیاید (نه عدد ثابت ۲)، و عرض خانه با احتساب فاصله‌های بین ستون‌ها محاسبه شود:
```dart
final columns = RitmoBreakpoints.columnsFor(
  availableWidth: constraints.maxWidth,
  minTileWidth: minTileWidth ?? _defaultMinTileWidth(context),
  spacing: spacing,
  maxColumns: maxColumns,
);
final itemWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
```

**چرا `Wrap` و نه `GridView`:** در `Wrap` ارتفاع هر ردیف از بلندترین خانهٔ همان ردیف می‌آید. این دقیقاً ریشهٔ ۳ را حل می‌کند: محتوا دیگر در قفس نسبت ابعاد نیست.

**کجا `RitmoAdaptiveGrid` کافی نیست:** وقتی تعداد آیتم زیاد و اسکرول‌شدنی است (مانند فهرست حرکات در `ss_premium_muscle_category_screen.dart`). برای آن موارد از `SliverGridDelegateWithMaxCrossAxisExtent` با `mainAxisExtent` محاسبه‌شده استفاده کن و یک سازندهٔ دوم به نام `RitmoAdaptiveGrid.sliverDelegate(...)` در همین فایل بگذار. دو پیاده‌سازی جداگانه در دو فایل نساز.

### R-05 — ویجت ردیف ایمن از سرریز

فایل جدید: `lib/core/widgets/ritmo_adaptive_row.dart`

```dart
/// ردیفی که وقتی عرض کم می‌آید، به چیدمان عمودی می‌ریزد.
/// جانشین هر Row که دو بلوک متنی کنار هم دارد (عنوان + مقدار، برچسب + دکمه).
class RitmoAdaptiveRow extends StatelessWidget {
  const RitmoAdaptiveRow({
    super.key,
    required this.primary,
    required this.secondary,
    this.minWidthForRow = 280.0,
    this.spacing = RitmoSpacing.sm,
  });
}
```

منطق: `LayoutBuilder` → اگر `constraints.maxWidth >= minWidthForRow` و `!context.isLargeTextScale` بود، `Row` با `Expanded` دور `primary`؛ وگرنه `Column` با `crossAxisAlignment: CrossAxisAlignment.start`.

**مهم:** این ویجت را به زور همه‌جا نبر. فقط در یافته‌های فاز ۳ که صریحاً نام برده شده‌اند. استفادهٔ بی‌مورد، ردیف‌های ساده را بیهوده پیچیده می‌کند.

### R-06 — سازندهٔ مشترک شیت برای مواردی که به `RitmoSheetScaffold` نمی‌آیند

برخی شیت‌ها ساختار بسیار خاص دارند (مثلاً وب‌ویو تمام‌قد در `chatgpt_auth_modal.dart` و `cloudflare_challenge_modal.dart`) و به هدر و اسکرول `RitmoSheetScaffold` نیاز ندارند. برای این‌ها در فایل `lib/core/widgets/sheet/` یک کمکی بساز:

```dart
/// ظرف ارتفاع-ایمن برای شیت‌هایی که محتوای تمام‌قد دارند (وب‌ویو، نقشه، بوم نقاشی).
/// برخلاف RitmoSheetScaffold محتوا را اسکرول نمی‌کند، ولی ارتفاع را سقف می‌گیرد
/// و به نوارهای سیستمی و صفحه‌کلید احترام می‌گذارد.
class RitmoFullBleedSheet extends StatelessWidget {
  const RitmoFullBleedSheet({
    super.key,
    required this.child,
    this.maxHeightFactor = 0.9,
    this.minHeightFactor = 0.5,
  });
}
```

پیاده‌سازی: `ConstrainedBox` با `minHeight` و `maxHeight` هر دو از `RitmoBreakpoints.usableHeight`، درون `Padding(bottom: viewInsets.bottom)`، درون `SafeArea(top: false)`.

**دلیل وجود `minHeightFactor`:** وب‌ویو برای رندر شدن به ارتفاع حداقل نیاز دارد؛ اگر فقط سقف بگذاری و محتوا ارتفاع ذاتی نداشته باشد، به صفر جمع می‌شود. این تنها جایی است که کف ارتفاع مجاز است، و مقدارش باید از `usableHeight` بیاید نه `size.height`.

### R-07 — هارنس تست مشترک پاسخ‌گویی

فایل جدید: `test/support/responsive_harness.dart`

این فایل قلب فاز ۶ است. باید دقیقاً این را داشته باشد:

```dart
/// مجموعهٔ رسمی دستگاه‌های مرجع برای تست چیدمان.
/// هر عدد از یک دستگاه واقعی می‌آید، نه از حدس.
const kRitmoTestViewports = <String, Size>{
  'compact-short': Size(320, 568),   // بدترین حالت واقعی
  'compact': Size(360, 640),         // اندروید اقتصادی رایج
  'regular': Size(390, 844),         // حالت مرجع طراحی
  'large': Size(430, 932),           // پلاس
};

const kRitmoTestTextScales = <double>[1.0, 1.3, 1.6];

/// ویجت را در محیط واقعی برنامه می‌پیچد: RTL، تم ریتمو، مقیاس متن، نوارهای سیستمی.
Widget wrapResponsive(
  Widget child, {
  required Size size,
  double textScale = 1.0,
  EdgeInsets padding = const EdgeInsets.only(top: 24, bottom: 16),
  double keyboardInset = 0,
  Brightness brightness = Brightness.light,
}) { /* ... */ }

/// هر سرریز RenderFlex را جمع می‌کند و در صورت وجود، تست را با پیام خوانا می‌شکند.
/// این تابع هرگز خطا را خفه نمی‌کند.
Future<void> expectNoOverflow(
  WidgetTester tester, {
  required String label,
}) async { /* ... */ }

/// حلقهٔ استاندارد: ۴ دستگاه × ۳ مقیاس = ۱۲ حالت برای هر ویجت.
void testAcrossViewports(
  String description,
  Widget Function() build, {
  bool withKeyboard = false,
}) { /* ... */ }
```

**قواعد اجباری این هارنس:**
۱. `expectNoOverflow` باید پیام خطا را شامل نام دستگاه و مقیاس متن بدهد، وگرنه دیباگ کردن ۱۲ حالت غیرممکن می‌شود.
۲. `wrapResponsive` باید `Directionality(textDirection: TextDirection.rtl)` داشته باشد. این برنامه فارسی و راست‌به‌چپ است؛ تست چپ‌به‌راست بی‌ارزش است.
۳. از الگوی موجود و درست `test/features/movement/rtl_overflow_test.dart` و `test/features/movement/center_rtl_overflow_test.dart` تقلید کن — هر دو `MediaQueryData(textScaler:, size:, padding:)` را درست می‌سازند.
۴. از الگوی حلقهٔ `test/settings/settings_text_scale_resilience_test.dart` تقلید کن — همان الگوی `FlutterError.onError` و `recordedErrors` و `finally { FlutterError.onError = originalOnError; }`. این فایل درست‌ترین تست پاسخ‌گویی موجود در مخزن است.
۵. **ممنوع:** هر کدی که `tester.view.physicalSize` را بزرگ‌تر از بزرگ‌ترین مقدار `kRitmoTestViewports` قرار دهد.
۶. `setSurfaceSize` باید در `finally` با `null` پاک شود، وگرنه به تست بعدی نشت می‌کند.

### R-08 — تصمیم قطعی دربارهٔ سقف مقیاس متن در `main.dart`

فایل: `lib/main.dart`

خط فعلی:
```dart
textScaler: mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.3),
```

**تصمیم:** سقف را به `1.6` ببر و هر دو عدد را از `RitmoBreakpoints` بگیر:
```dart
textScaler: mq.textScaler.clamp(
  minScaleFactor: RitmoBreakpoints.supportedMinTextScale,
  maxScaleFactor: RitmoBreakpoints.supportedMaxTextScale,
),
```

**چرا ۱٫۶ و نه ۲٫۰:** چون باید عددی را انتخاب کنیم که فاز ۶ واقعاً تأمینش کند. دو تست موجود در مخزن الان تا `1.6` می‌روند (`test/calendar/calendar_golden_and_e2e_test.dart` با `[1.0, 1.3, 1.6]` و `test/settings/settings_text_scale_resilience_test.dart` با `[1.0, 1.3, 1.5, 1.6]`). پس `1.6` عددی است که پیش‌از-این هم در مخزن معیار بوده، و فقط برنامهٔ واقعی به آن احترام نمی‌گذاشته.

**ترتیب اجرا مهم است:** این یافته را **در فاز ۰ فقط به شکل ثابت‌های نام‌دار پیاده کن ولی مقدار را روی `1.3` نگه دار**؛ یعنی `supportedMaxTextScale = 1.3` در فاز ۰. سپس در **دروازهٔ پذیرش فاز ۵**، وقتی همهٔ چیدمان‌ها اصلاح شدند، مقدار را به `1.6` ببر و کل تست را دوباره اجرا کن.

اگر از اول به `1.6` ببری، برنامه در دورهٔ فازهای ۱ تا ۵ برای کاربر واقعی **بدتر** می‌شود، چون چیدمان‌های شکستنی را در معرض فشار بیشتر می‌گذاری. این دقیقاً همان دامی است که قاعدهٔ ۰-۳ (ترتیب اجباری فازها) جلوگیری می‌کند. در سند پیشرفت صریح بنویس که `R-08` دو مرحله دارد و مرحلهٔ دوم در فاز ۵ انجام می‌شود.

### R-09 — حذف خفه‌کنندهٔ خطای سرریز در تست

فایل: `test/widget/niyyah_edit_sheet_stays_open_test.dart`

کد فعلی:
```dart
// Suppress expected overflow exceptions from planner date picker in constrained test environment
final originalOnError = FlutterError.onError;
FlutterError.onError = (FlutterErrorDetails details) {
  if (details.toString().contains('overflowed') || details.toString().contains('databaseFactory')) {
    return; // suppress known test-environment-only issues
  }
```

**کاری که باید بکنی:**
۱. شرط `contains('overflowed')` را حذف کن. شرط `databaseFactory` می‌تواند بماند — آن واقعاً مسئلهٔ محیط تست است.
۲. تست را اجرا کن. **قرمز خواهد شد.** این خوب است — یعنی یک باگ واقعی را پیدا کردی.
۳. پیام خطا به تو می‌گوید کدام ویجت سرریز می‌کند. طبق کامنت، مشکوک اصلی انتخاب‌گر تاریخ در `lib/core/utils/ritmo_date_picker.dart` است که `crossAxisCount: 3, childAspectRatio: 2.2` دارد — همان یافتهٔ `R-31`.
۴. **اگر ریشه در `ritmo_date_picker.dart` بود، این یافته را `مسدود شد` علامت بزن با دلیل «وابسته به `R-31`»**، خفه‌کننده را موقتاً برگردان با کامنت `// TODO(R-31): پس از اصلاح گرید انتخاب‌گر تاریخ حذف شود`، و در فاز ۲ پس از `R-31` برگرد و قطعی حذفش کن.
۵. در دروازهٔ پذیرش فاز ۲، `rg -n "overflowed" test/widget/` باید خالی باشد.

**حدس نزن که ریشه کجاست. تست را اجرا کن و پیام خطا را بخوان.**

### R-10 — حذف بوم مصنوعی بزرگ در تست

فایل: `test/features/movement/presentation/activity_plan_editor_test.dart`

کد فعلی:
```dart
testWidgets('Renders all 8-step building blocks without overflow', (tester) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
```

عنوان تست ادعا می‌کند سرریز ندارد، ولی در بومی تست می‌شود که روی هیچ گوشی‌ای وجود ندارد.

**کاری که باید بکنی:**
۱. `Size(800, 1800)` را به `kRitmoTestViewports['regular']!` (۳۹۰×۸۴۴) تبدیل کن.
۲. تست را اجرا کن. اگر قرمز شد، صفحهٔ ویرایشگر طرح فعالیت واقعاً در گوشی مرجع سرریز می‌کند.
۳. مسیر درست این است: صفحه باید اسکرول‌پذیر باشد، نه اینکه تست بوم را بزرگ کند. اگر هشت بلوک در ۸۴۴ پیکسل جا نمی‌شوند، باید در `SingleChildScrollView` باشند.
۴. اگر اصلاح چیدمان بزرگ است و به فاز ۳ تعلق دارد، همین رویهٔ `R-09` را دنبال کن: `TODO(R-xx)` بگذار و در فاز مربوطه برگرد.

**ممنوع مطلق:** حل کردن این مورد با پاک کردن خود تست یا زدن `skip:`.

### R-11 — مستند معماری پاسخ‌گویی

فایل جدید: `docs/ui/RESPONSIVE_LAYOUT.md`

محتوای اجباری:
۱. جدول کلاس‌های عرض و ارتفاع با مرزهای دقیق و دو مثال دستگاه واقعی برای هر کلاس.
۲. قانون طلایی: «ارتفاع سقف است، نه مقدار» با دو قطعه کد کوتاه (غلط و درست).
۳. قانون گرید: «عرض کمینهٔ خانه، نه شمار ستون» با محاسبهٔ عددی که نشان می‌دهد چرا `crossAxisCount: 4` در عرض ۳۲۰ می‌شکند.
۴. جدول ۱۲ حالت تست استاندارد (۴ دستگاه × ۳ مقیاس).
۵. سیاست مقیاس متن: چرا سقف وجود دارد، عددش چند است، و کجا تغییر می‌کند (یک جا: `RitmoBreakpoints`).

**قاعدهٔ مطلق:** این سند فقط از کد نوشته می‌شود. هر نام نماد در این سند باید با `rg` قابل تأیید باشد. هیچ وعدهٔ آینده در این سند ننویس.

### R-12 — تست محافظ زیرساخت

فایل جدید: `test/core/theme/ritmo_breakpoints_test.dart`

جدول حالت‌های اجباری — هر ردیف یک `test`:

| # | ورودی | انتظار |
|---|---|---|
| ۱ | `widthClassOf(320)` | `RitmoWidthClass.compact` |
| ۲ | `widthClassOf(359)` | `compact` (مرز بالا) |
| ۳ | `widthClassOf(360)` | `regular` (مرز پایین) |
| ۴ | `widthClassOf(600)` | `expanded` |
| ۵ | `heightClassOf(568)` | `RitmoHeightClass.short` |
| ۶ | `columnsFor(availableWidth: 320, minTileWidth: 160, spacing: 12)` | `1` — چون دو خانهٔ ۱۶۰ به‌علاوهٔ فاصله بیش از ۳۲۰ است |
| ۷ | `columnsFor(availableWidth: 390, minTileWidth: 160, spacing: 12)` | `2` |
| ۸ | `columnsFor(availableWidth: 1200, minTileWidth: 160, spacing: 12, maxColumns: 4)` | `4` — سقف رعایت می‌شود |
| ۹ | `columnsFor(availableWidth: 10, minTileWidth: 160, spacing: 12)` | `1` — **هرگز صفر یا منفی برنمی‌گرداند** |
| ۱۰ | `usableHeight` با `size.height: 800, padding.top: 24, padding.bottom: 16, viewInsets.bottom: 300` | `460` |

**ردیف ۹ مهم‌ترین تست این فایل است.** اگر `columnsFor` صفر برگرداند، `itemWidth` به تقسیم بر صفر می‌خورد و کل برنامه در دستگاه‌های باریک کرش می‌کند. این بدتر از سرریز است.

ردیف ۱۰ را با `wrapResponsive` از `R-07` و یک `Builder` بنویس تا `BuildContext` واقعی داشته باشی.

### 🚦 دروازهٔ پذیرش فاز ۰

فاز ۱ را شروع نکن تا هر ده مورد زیر تیک نخورده باشد:

- [ ] `flutter analyze` — صفر خطا، صفر اخطار.
- [ ] `flutter test test/core/theme/ritmo_breakpoints_test.dart` — هر ده حالت سبز.
- [ ] `rg -n "class RitmoBreakpoints" lib/` — دقیقاً یک نتیجه.
- [ ] `rg -n "RitmoAdaptiveGrid|RitmoAdaptiveRow|RitmoFullBleedSheet" lib/core/widgets/` — هر سه موجود.
- [ ] `rg -n "MediaQuery.of(context).size.height \\* 0.9" lib/core/widgets/ritmo_sheet_scaffold.dart` — خالی.
- [ ] `rg -n "حال و تعادل" lib/core/widgets/ritmo_sheet_scaffold.dart` — خالی (کامنت دامنه حذف شده).
- [ ] `rg -n "textScale > 1.2" lib/` — خالی؛ هر دو مورد به `context.isLargeTextScale` مهاجرت کرده‌اند.
- [ ] `flutter test test/features/movement/undo_toast_test.dart` — بدون تغییر در خود تست، سبز.
- [ ] `test/support/responsive_harness.dart` وجود دارد و `kRitmoTestViewports` دقیقاً ۴ ورودی دارد.
- [ ] `docs/ui/RESPONSIVE_LAYOUT.md` وجود دارد و هیچ نام نمادی در آن نیست که در کد نباشد.

**کامیت:** `fix(ui): phase 0 — زیرساخت پاسخ‌گویی [R-01 … R-12]`

---

## فاز ۱ — شیت‌ها و مودال‌ها (`R-13` … `R-30`)

این فاز بزرگ‌ترین منبع سرریز را می‌بندد: **۳۹ محل** استفاده از `MediaQuery.of(context).size` که تقریباً همه‌شان ارتفاع صُلب شیت هستند. ۳۸ مورد اصلاح می‌شود و یک مورد (`ritmo_sheet_scaffold.dart`) در فاز ۰ اصلاح شد.

### R-13 — قرارداد مهاجرت شیت‌ها (این را اول بخوان، بعد سراغ R-14 برو)

همهٔ یافته‌های `R-14` تا `R-29` **یک** الگوی تکراری دارند. این دستور را یک بار بخوان و برای هر ۳۸ محل اجرا کن.

**الگوی غلط موجود** (شکل رایج در مخزن):
```dart
void _showSomethingSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E2C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: ListView(children: items)),
          _buildSaveButton(),
        ],
      ),
    ),
  );
}
```

**الگوی درست مقصد:**
```dart
Future<void> _showSomethingSheet(BuildContext context) {
  return RitmoSheetScaffold.present(
    context: context,
    title: l10n.somethingSheetTitle,
    subtitle: l10n.somethingSheetSubtitle,
    childIsScrollable: true,
    footer: _buildSaveButton(context),
    builder: (context) => ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: items,
    ),
  );
}
```

**پنج تغییر اجباری در هر محل:**

**۱ — `height:` حذف می‌شود.** به‌جایش `RitmoSheetScaffold` سقف را از `RitmoBreakpoints.sheetMaxHeight` می‌گیرد. ضریب پیش‌فرض `0.9` است. اگر شیت اصلی خیلی کوچک است و `0.9` بی‌معناست، `maxHeightFactor` را بگذار — ولی **هیچ ضریب جدیدی نساز**: فقط `0.6` یا `0.75` یا `0.9` مجاز است. سه سطح، نه دوازده. ضریب‌های موجود `0.65` و `0.68` و `0.7` و `0.76` و `0.8` و `0.82` و `0.85` و `0.88` و `0.92` همه به نزدیک‌ترین یکی از این سه سطح گرد می‌شوند.

**۲ — هدر دستی حذف می‌شود.** `RitmoSheetScaffold` خودش دستهٔ ۳۶×۴، عنوان، زیرعنوان، دکمهٔ بستن با `tooltip: 'بستن'` و `Divider(height: 1)` را می‌سازد. هر `_buildHeader()` دستی که همین‌ها را می‌سازد حذف می‌شود. اگر هدر دستی چیز اضافه‌ای دارد (مثلاً یک تب‌بار یا فیلد جست‌وجو)، آن را به بالای `builder` منتقل کن نه اینکه هدر را نگه داری.

**۳ — `Expanded` دور محتوا به `childIsScrollable: true` تبدیل می‌شود.** الگوی `Column(children: [header, Expanded(child: ListView(...)), button])` در یک شیت با ارتفاع سقف‌دار **کار نمی‌کند**، چون `Expanded` به کف ارتفاع نیاز دارد و شیت کف ندارد. این دقیقاً دلیل فنی‌ای است که تیم مجبور شد `height:` صُلب بگذارد. `RitmoSheetScaffold` با `Flexible` این را حل می‌کند.

**۴ — دکمهٔ پایین به `footer` می‌رود.** اگر دکمهٔ ثبت/ذخیره باید همیشه دیده شود، در `footer` می‌رود نه در `builder`. اگر داخل `builder` بگذاری، در گوشی کوتاه پایین اسکرول پنهان می‌شود و کاربر فکر می‌کند دکمه‌ای وجود ندارد.

**۵ — `Color(0x...)` سخت‌کدشده حذف می‌شود.** پنج فایل رنگ پس‌زمینهٔ سخت‌کدشده دارند: `Color(0xFF0F111E)` در دو فایل روتین، `Color(0xFF1E1E2C)` در شیت دستیار، `Color(0xFF131B2E)` در چک‌این ورزش تکمیلی. اینها در تم روشن، شیت را سیاه می‌کنند. `RitmoSheetScaffold` رنگ را از `context.colors` می‌گیرد. رنگ سخت‌کدشده را حذف کن، جایگزین نساز.

**قاعدهٔ رفتار:** مهاجرت به `RitmoSheetScaffold` نباید هیچ قابلیتی را حذف کند. اگر شیتی رفتار خاصی دارد که `RitmoSheetScaffold` پشتیبانی نمی‌کند (مثلاً `enableDrag: false` یا `isDismissible: false` یا کنترل ارتفاع کشیدنی)، **آن پارامتر را به `RitmoSheetScaffold.present` اضافه کن** و همه‌جا از آن استفاده کن. هرگز به این بهانه یک شیت را از قرارداد بیرون نگذار.

**قاعدهٔ ترتیب:** یافته‌ها را به همان ترتیب `R-14` تا `R-29` انجام بده. اولین دو تا (`R-14` و `R-15`) را تمام کن، تست بنویس، و مطمئن شو الگو کار می‌کند. بعد بقیه سریع می‌روند. اگر بخواهی همه را با هم عوض کنی و الگو ایراد داشته باشد، ۳۸ فایل را باید برگردانی.

### R-14 — شیت دستیار هوشمند (بزرگ‌ترین و پرریسک‌ترین)

فایل: `lib/features/assistant/presentation/widgets/unified_assistant_sheet.dart`

دو مشکل هم‌زمان: `MediaQuery.of(context).size.height * 0.85` و `Color(0xFF1E1E2C)`.

این شیت **ورودی متنی دارد**، پس بدترین حالت را نمایش می‌دهد: کاربر روی فیلد می‌زند، صفحه‌کلید نصف ارتفاع را می‌گیرد، ارتفاع صُلب ۸۵٪ عوض نمی‌شود، و کل محتوا سرریز می‌کند. این محتمل‌ترین جایی است که کاربر باگ را دیده.

**تأیید اجباری بعد از اصلاح:** شیت را روی ۳۲۰×۵۶۸ باز کن، روی فیلد متنی بزن، و مطمئن شو (الف) هیچ سرریزی نیست، (ب) فیلد فعال دیده می‌شود، (ج) دکمهٔ ارسال در دسترس است. این سه شرط را در تست `R-30` کدنویسی کن.

### R-15 — دو شیت پیش‌نمایش برنامه‌ریز دستیار

فایل‌ها:
- `lib/features/assistant/presentation/widgets/ai_day_planner_preview_sheet.dart` — ضریب `0.9`
- `lib/features/assistant/presentation/widgets/ai_weekly_planner_preview_sheet.dart` — ضریب `0.85`

هر دو فهرست بلند تولیدشده توسط هوش مصنوعی نشان می‌دهند، پس تعداد آیتم غیرقابل پیش‌بینی است. این یعنی ارتفاع صُلب حتماً یا فضای خالی می‌گذارد یا سرریز می‌کند — بستگی به این دارد که مدل چند مورد برگردانده.

هر دو با `maxHeightFactor: 0.9` و `childIsScrollable: true` مهاجرت می‌کنند. دکمه‌های «تأیید» و «رد» به `footer` می‌روند — اگر کاربر نتواند دکمهٔ تأیید را ببیند، کل قابلیت مرده است.

### R-16 — صفحهٔ چت هوش مصنوعی (دو محل)

فایل: `lib/features/chat/presentation/ai_chat_screen.dart` (۶۷٬۵۰۹ بایت)

دو محل جدا: یکی با ضریب `0.75` و یکی با `0.7`.

**این فایل بزرگ‌ترین فایل رابط کاربری مخزن است. قبل از تغییر، هر دو محل را پیدا کن و بفهم هرکدام چه شیتی را باز می‌کند.** حدس نزن که هر دو یک چیزند.

احتمال بالا: یکی انتخاب‌گر مدل/تنظیمات است و دیگری تاریخچهٔ گفتگو. اگر یکی از آنها شیت نیست بلکه یک پنل درون‌صفحه‌ای است، `RitmoSheetScaffold` جواب نمی‌دهد و باید با `ConstrainedBox(maxHeight: RitmoBreakpoints.usableHeight(context) * 0.75)` و `Flexible` اصلاح شود. در آن حالت این را در سند پیشرفت بنویس.

### R-17 — حباب‌های پیام با عرض نسبی

فایل‌ها:
- `lib/features/chat/presentation/widgets/streaming_message_bubble.dart` — `maxWidth: MediaQuery.of(context).size.width * 0.76`
- `lib/features/supplementary_sports/presentation/widgets/shared/chat_bubble.dart` — `maxWidth: ... * 0.75` و `minHeight: 40`

**این دو مورد از بقیه متفاوتند و نباید کورکورانه اصلاح شوند.** عرض نسبی برای حباب چت **درست** است — این استاندارد رابط کاربری چت است. مشکل جای دیگری است:

**اشکال واقعی:** ضریب روی `size.width` اعمال شده، یعنی عرض **نمایشگر**. اما حباب داخل یک `ListView` با `padding` است، پس عرض واقعی در دسترس کمتر است. در گوشی باریک با `padding: RitmoSpacing.lg` دو طرف، ۷۶٪ عرض نمایشگر می‌تواند از عرض در دسترس بیشتر باشد.

**اصلاح درست:** ضریب را روی `constraints.maxWidth` از یک `LayoutBuilder` اعمال کن، نه روی `size.width`. ضریب `0.76` و `0.75` را نگه دار — آنها تصمیم طراحی‌اند نه باگ. فقط مبنا را عوض کن. دو ضریب را به یک عدد یکی کن و در `RitmoBreakpoints` بگذار:
```dart
/// حداکثر عرض حباب چت نسبت به عرض در دسترس.
static const double chatBubbleMaxWidthFactor = 0.76;
```

`minHeight: 40` در `chat_bubble.dart` را حذف کن. برای یک حباب تک‌کلمه‌ای در مقیاس متن ۱٫۶، ارتفاع طبیعی از ۴۰ بیشتر است؛ برای اموجی تنها کمتر است و کف ۴۰ فضای بی‌مورد می‌گذارد. اگر هدف هدف لمس بود، از `RitmoBreakpoints.minTouchTarget` استفاده کن و در کامنت بنویس چرا.

### R-18 — دو مودال پل وب

فایل‌ها:
- `lib/core/ai/web_bridge/chatgpt_auth_modal.dart` — ضریب `0.85`
- `lib/core/ai/web_bridge/cloudflare_challenge_modal.dart` — ضریب `0.7`

هر دو یک `WebView` تمام‌قد میزبانی می‌کنند. **این دو تنها موارد مجازِ استفاده از `RitmoFullBleedSheet` از `R-06` هستند** — چون محتوایشان ارتفاع ذاتی ندارد و اگر فقط سقف بگذاری به صفر جمع می‌شود.

```dart
RitmoFullBleedSheet(
  maxHeightFactor: 0.9,
  minHeightFactor: 0.6,
  child: WebViewWidget(controller: controller),
)
```

**بحرانی — چالش کلادفلیر:** ضریب `0.7` برای این مودال خطرناک است. چالش کلادفلیر یک چک‌باکس در مرکز صفحه دارد؛ اگر مودال کوتاه باشد و وب‌ویو اسکرول نشود، چک‌باکس ممکن است بیرون کادر بیفتد و **کاربر هرگز نتواند احراز هویت را کامل کند**. این یک باگ عملکردی است، نه زیبایی‌شناختی. `minHeightFactor: 0.6` و `maxHeightFactor: 0.9` بگذار و مطمئن شو وب‌ویو اسکرول عمودی دارد.

### R-19 — سه شیت تقویم

فایل‌ها:
- `lib/features/calendar/presentation/widgets/journey_smart_panel.dart` — ضریب `0.68`
- `lib/features/calendar/presentation/widgets/calendar_management_sheet.dart` — `maxHeight` با ضریب `0.88`
- `lib/features/calendar/presentation/widgets/agenda_diagnostics_sheet.dart` — `maxHeight` با ضریب `0.85` و **دارای `SafeArea`**

**`agenda_diagnostics_sheet.dart` نزدیک‌ترین فایل به درستی است** — از `maxHeight` استفاده می‌کند نه `height`، و `SafeArea` دارد. آن را به‌عنوان مرجع بخوان قبل از اصلاح دو تای دیگر. مهاجرتش کم‌ریسک است.

`journey_smart_panel.dart` با ضریب `0.68` به `maxHeightFactor: 0.75` گرد می‌شود. اگر پنل واقعاً باید کوچک بماند، `0.75` سقف است نه مقدار — پس کوچک می‌ماند و مشکلی نیست. این دقیقاً مزیت سقف بر مقدار قطعی است.

### R-20 — دو شیت اهداف

فایل‌ها:
- `lib/features/goals/presentation/widgets/week_review_sheet.dart` — ضریب `0.85`
- `lib/features/goals/presentation/widgets/week_planner_sheet.dart` — ضریب `0.85`

هر دو محتوای هفتگی نشان می‌دهند، یعنی هفت ردیف حداقلی. در گوشی ۳۲۰×۵۶۸ با مقیاس متن ۱٫۶، هفت ردیف با عنوان فارسی قطعاً از ۸۵٪ ارتفاع بیشتر می‌شود. `childIsScrollable: true` اجباری است.

**تأیید خاص:** بعد از اصلاح، مطمئن شو نام روزهای هفته (`['ش','ی','د','س','چ','پ','ج']`) در گوشی باریک بریده نمی‌شوند. اینها تک‌حرفی‌اند پس نباید مشکلی باشد — ولی اگر جایی نام کامل روز (`شنبه`, `چهارشنبه`) استفاده شده، `چهارشنبه` بلندترین است و مبنای تست باید باشد.

### R-21 — سه شیت دوره‌های آموزشی

فایل‌ها:
- `lib/features/courses/presentation/widgets/ai_syllabus_sheet.dart` — ضریب `0.8`
- `lib/features/courses/presentation/widgets/create_course_sheet.dart` — ضریب `0.85`
- `lib/features/courses/presentation/widgets/study_timer_sheet.dart` — ضریب `0.6`

`create_course_sheet.dart` **فرم با چند ورودی متنی** است — همان دستهٔ پرریسک `R-14`. صفحه‌کلید + ارتفاع صُلب = سرریز قطعی. اولویت بالا.

`study_timer_sheet.dart` با ضریب `0.6` را با دقت بررسی کن: یک تایمر معمولاً محتوای ثابت و کم دارد، پس ممکن است `0.6` عمداً کوچک باشد. با `maxHeightFactor: 0.6` مهاجرت کن. **اما** اگر تایمر یک عدد بزرگ با `fontSize:` سخت‌کدشده دارد، آن یافتهٔ فاز ۴ است — یادداشتش کن و در `R-59` رسیدگی کن، الان دستش نزن.

`ai_syllabus_sheet.dart` فهرست تولیدی هوش مصنوعی است — همان استدلال `R-15`. `maxHeightFactor: 0.9` و `childIsScrollable: true`.

### R-22 — دو شیت روتین‌ها (هر دو رنگ سخت‌کدشده دارند)

فایل‌ها:
- `lib/features/routines/presentation/widgets/dedicated_builder_sheet.dart` — ضریب `0.9` و `Color(0xFF0F111E)`
- `lib/features/routines/presentation/universal_planner_sheet.dart` — ضریب `0.92` و `Color(0xFF0F111E)`

ضریب `0.92` بالاترین عدد در کل مخزن است. یعنی این شیت عملاً تمام صفحه است ولی به‌شکل شیت پیاده شده. **سؤال معماری را بپرس:** اگر شیتی ۹۲٪ ارتفاع می‌خواهد، آیا نباید یک صفحهٔ کامل با `Navigator.push` باشد؟

**تصمیم:** به صفحهٔ کامل تبدیل نکن — این تغییر ناوبری است و از دامنهٔ این کار بیرون است. با `maxHeightFactor: 0.9` مهاجرت کن. ولی در سند پیشرفت یک خط بنویس: «`universal_planner_sheet` عملاً تمام‌صفحه است؛ تبدیلش به مسیر ناوبری مستقل، کار جداگانه‌ای است.» این را به‌عنوان یافتهٔ جدید ثبت کن، نه به‌عنوان کاری که انجام دادی.

هر دو `Color(0xFF0F111E)` را حذف کن. این رنگ تقریباً سیاه است و در تم روشن رابط کاربری را می‌شکند.

### R-23 — چهار شیت عبادت

فایل‌ها:
- `lib/features/worship/presentation/widgets/prayer_city_picker.dart` — ضریب `0.75`
- `lib/features/worship/presentation/widgets/mustahab_section.dart` — ضریب `0.7`
- `lib/features/worship/presentation/widgets/worship_day_detail_panel.dart` — `maxHeight` با ضریب `0.85`
- `lib/features/worship/presentation/widgets/worship_reminder_settings_sheet.dart` — `maxHeight` با ضریب `0.85`

دو تای آخر از `maxHeight` استفاده می‌کنند — کم‌ریسک، مهاجرت ساده.

**`prayer_city_picker.dart` مورد خاص است:** انتخاب‌گر شهر یعنی فهرست بلند + فیلد جست‌وجو. یعنی هم صفحه‌کلید دارد هم فهرست طولانی. دو عامل بدترین حالت با هم. این را با دقت `R-14` انجام بده: فیلد جست‌وجو در بالای `builder`، فهرست با `childIsScrollable: true`، و `maxHeightFactor: 0.9` (نه `0.75` — یک انتخاب‌گر با جست‌وجو به فضا نیاز دارد).

**نکتهٔ محلی‌سازی:** نام شهرهای فارسی طول متغیر دارند (`قم` تا `شهرکرد`). در فهرست، هر نام شهر باید `maxLines: 1` و `TextOverflow.ellipsis` داشته باشد. این یافتهٔ فاز ۳ است ولی چون همین‌جا دستت است، همین‌جا انجامش بده و در سند پیشرفت به `R-45` ارجاع بده.

### R-24 — دو شیت مدیریت در صفحهٔ امروز

فایل‌ها:
- `lib/features/today/presentation/widgets/education_management_sheet.dart` — ضریب `0.7`
- `lib/features/today/presentation/widgets/realm_management_sheet.dart` — ضریب `0.88`

هر دو شیت «مدیریت» با فهرست چک‌باکس یا سوییچ‌اند. تعداد آیتم به دادهٔ کاربر بستگی دارد، پس ارتفاع صُلب غلط است. `maxHeightFactor: 0.9` و `childIsScrollable: true`.

**تأیید خاص برای سوییچ‌ها:** هر ردیف با `Switch` باید در `Row` با `Expanded` دور برچسب باشد. اگر برچسب فارسی بلند باشد و `Expanded` نداشته باشد، سرریز افقی می‌دهد. این را همین‌جا چک کن.

### R-25 — سلامت: یک شیت و یک ConstrainedBox بدقلق

**بخش اول — شیت خلاصهٔ ویزیت:**
فایل: `lib/features/health/presentation/widgets/doctor_visit_summary_sheet.dart` — ضریب `0.8`. مهاجرت استاندارد با `maxHeightFactor: 0.9`.

**بخش دوم — بخش بارداری، این یکی متفاوت است:**
فایل: `lib/features/health/presentation/widgets/pregnancy_section.dart`

کد فعلی:
```dart
ConstrainedBox(
  constraints: BoxConstraints(
    minHeight: 380,
    maxHeight: 520 * MediaQuery.textScalerOf(context).scale(1.0),
  ),
  child: TabBarView(children: [...]),
)
```

**سه اشکال مستقل در همین چهار خط:**

۱. **`minHeight: 380` سخت‌کدشده و مقیاس متن را نمی‌بیند.** در گوشی ۳۲۰×۵۶۸ با نوارهای سیستمی، ارتفاع در دسترس حدود ۵۰۰ است. کف ۳۸۰ به‌علاوهٔ هدر و تب‌بار، فضای کمی می‌گذارد. و در مقیاس متن ۱٫۶ محتوای هر تب بیش از ۳۸۰ می‌خواهد ولی کف عوض نمی‌شود.

۲. **`maxHeight` با مقیاس متن ضرب شده ولی `minHeight` نه.** این ناسازگاری منطقی است: یعنی نویسنده می‌دانست مقیاس متن مهم است، ولی فقط نصف راه رفت. در مقیاس ۱٫۶ سقف می‌شود ۸۳۲ — بیشتر از ارتفاع در دسترس هر گوشی متوسط. یعنی سقف عملاً بی‌اثر است و سرریز آزاد.

۳. **`TabBarView` درون `ConstrainedBox` با سقف، محتوای بلندتر را نمی‌اسکرولد.** هر تب باید خودش `SingleChildScrollView` داشته باشد، وگرنه سقف فقط محل بریدن را تعیین می‌کند.

**اصلاح:**
```dart
LayoutBuilder(
  builder: (context, constraints) {
    final scale = context.textScale;
    final available = RitmoBreakpoints.usableHeight(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: (380 * scale).clamp(280.0, available * 0.5),
        maxHeight: available * 0.7,
      ),
      child: TabBarView(
        children: tabs.map((t) => SingleChildScrollView(child: t)).toList(),
      ),
    );
  },
)
```

هر تب در `SingleChildScrollView` می‌رود. کف با مقیاس متن رشد می‌کند **ولی به نصف ارتفاع در دسترس محدود می‌شود** — این `clamp` مهم‌ترین بخش اصلاح است. سقف از ارتفاع در دسترس می‌آید نه از عدد جادویی ۵۲۰.

### R-26 — بخش آزمون‌های کنکور

فایل: `lib/features/konkur/presentation/widgets/konkur_exams_section.dart` — ضریب `0.75`

مهاجرت استاندارد. فهرست آزمون‌ها به دادهٔ کاربر بستگی دارد، پس `childIsScrollable: true` و `maxHeightFactor: 0.9`.

**تأیید خاص:** ردیف آزمون معمولاً «نام آزمون + تاریخ + درصد» در یک `Row` است. سه بلوک متنی در یک ردیف در عرض ۳۲۰ = سرریز محتمل. اگر چنین ردیفی دیدی، `RitmoAdaptiveRow` از `R-05` را به کار ببر و در سند پیشرفت به `R-46` ارجاع بده.

### R-27 — تنظیمات و پریمیوم

**بخش اول:**
فایل: `lib/features/settings/presentation/widgets/ai_write_history_sheet.dart` — `maxHeight` با ضریب `0.75`. کم‌ریسک، مهاجرت ساده با `maxHeightFactor: 0.75`.

**بخش دوم — این یکی الگوی متفاوتی دارد:**
فایل: `lib/features/premium/presentation/premium_upgrade_sheet.dart`

کد فعلی: `final size = MediaQuery.of(context).size;` — یعنی متغیر `size` گرفته شده و **جاهای متعدد** در همان فایل از آن استفاده می‌کنند، نه فقط یک ارتفاع شیت.

**قبل از تغییر، همهٔ استفاده‌های `size` در این فایل را پیدا کن.** برای هر استفاده تصمیم بگیر:
- `size.height * ضریب` برای ارتفاع شیت → به `RitmoSheetScaffold` می‌رود.
- `size.width * ضریب` برای عرض کارت → به `LayoutBuilder` و `constraints.maxWidth` می‌رود.
- `size.width` برای موقعیت عنصر تزئینی در `Stack` → یافتهٔ فاز ۴، الان دستش نزن، در `R-64` ثبتش کن.

این فایل صفحهٔ فروش است. سرریز در صفحهٔ فروش یعنی درآمد از دست رفته، پس تأیید بصری روی هر چهار دستگاه `kRitmoTestViewports` اجباری است.

### R-28 — چهار شیت ورزش تکمیلی

فایل‌ها:
- `lib/features/supplementary_sports/presentation/ss_settings_screen.dart` — ضریب `0.85`
- `lib/features/supplementary_sports/presentation/widgets/ss_ai_coach_sheet.dart` — ضریب `0.85` و **یک `maxHeight` تودرتوی `0.4`**
- `lib/features/supplementary_sports/presentation/widgets/ss_daily_checkin_widget.dart` — `maxHeight` با ضریب `0.65` و `Color(0xFF131B2E)`
- `lib/features/supplementary_sports/presentation/ss_plan_day_detail_screen.dart` — ضریب `0.7`

**`ss_ai_coach_sheet.dart` بدترین مورد این دسته است.** دو محدودیت ارتفاع تودرتو: شیت `0.85` ارتفاع صفحه، و درونش یک ناحیه با سقف `0.4` ارتفاع صفحه. هر دو نسبت به **ارتفاع نمایشگر** محاسبه شده‌اند، نه نسبت به ارتفاع والد. یعنی در گوشی کوتاه، `0.4` ارتفاع صفحه می‌تواند از فضای واقعی باقی‌مانده درون شیت بیشتر باشد.

**اصلاح:** ضریب درونی باید نسبت به `constraints.maxHeight` والد باشد:
```dart
LayoutBuilder(
  builder: (context, constraints) => ConstrainedBox(
    constraints: BoxConstraints(maxHeight: constraints.maxHeight * 0.45),
    child: ...,
  ),
)
```
این دقیقاً مصداق تصمیم `ت-۲` است: محدودیت درونی از والد می‌آید، نه از نمایشگر.

**نکته:** بخش ورزش تکمیلی طبق پرامپت قبلی (`RITMO_MOVEMENT_MERGE_PROMPT.md`) در حال ادغام با حرکت مرکزی است. اگر فایلی از این چهار مورد دیگر وجود ندارد یا تغییر نام داده، یافته را `منتفی شد` علامت بزن با ذکر اینکه به کدام فایل منتقل شده. **حدس نزن — با `rg` وجودش را چک کن.**

### R-29 — سه شیت حرکت

فایل‌ها:
- `lib/features/supplementary_sports/movement/presentation/movement_log_sheet.dart` — ضریب `0.9`
- `lib/features/supplementary_sports/movement/presentation/movement_plan_sheet.dart` — ضریب `0.90`
- `lib/features/supplementary_sports/movement/presentation/planner/week_smart_fill_sheet.dart` — ضریب `0.85`

هر سه با `maxHeightFactor: 0.9` و `childIsScrollable: true` مهاجرت می‌کنند.

**`movement_log_sheet.dart` ورودی عددی دارد** (تکرار، وزن، مدت) پس صفحه‌کلید عددی باز می‌شود. همان دستهٔ `R-14`. دکمهٔ ثبت در `footer`.

**تست‌های موجود را نشکن:** ماژول حرکت تنها ماژولی است که تست سرریز واقعی دارد (`test/features/movement/rtl_overflow_test.dart` و `center_rtl_overflow_test.dart`). بعد از این یافته، هر دو باید **بدون تغییر** سبز بمانند. اگر قرمز شدند، مهاجرت رفتار را عوض کرده — برگرد و درستش کن، تست را عوض نکن.

### R-30 — تست محافظ شیت‌ها

فایل جدید: `test/core/widgets/sheet_responsive_test.dart`

این تست باید **قبل از فاز ۱ نوشته شود و قرمز باشد**، بعد سبز شود. اگر از اول سبز است، بد نوشته شده.

ساختار اجباری:

```dart
group('Sheet responsiveness (R-30)', () {
  for (final entry in kRitmoTestViewports.entries) {
    for (final scale in kRitmoTestTextScales) {
      testWidgets('RitmoSheetScaffold fits on ${entry.key} at scale $scale', (tester) async {
        // ...
        await expectNoOverflow(tester, label: '${entry.key} @ $scale');
      });

      testWidgets('RitmoSheetScaffold fits with keyboard on ${entry.key} at scale $scale', (tester) async {
        // keyboardInset: 300 — صفحه‌کلید باز
        // ...
      });
    }
  }
});
```

**سه ادعای اجباری در هر حالت:**
۱. هیچ خطای `overflowed` ثبت نشده باشد.
۲. دکمهٔ بستن (`Icons.close`) قابل یافتن و در محدودهٔ صفحه باشد. با `tester.getRect(find.byIcon(Icons.close))` چک کن که `rect.top >= 0` و `rect.bottom <= size.height`.
۳. اگر `footer` داده شده، فوتر هم در محدودهٔ صفحه باشد. **این ادعا مهم‌ترین است** — چون دلیل اصلی مهاجرت این بود که دکمهٔ ثبت پنهان نشود.

**محتوای تست:** یک محتوای مصنوعی بساز که قطعاً بلند است — مثلاً ۳۰ ردیف `ListTile` با عنوان فارسی بلند. هدف این است که مسیر اسکرول را فعال کنی، نه اینکه محتوای واقعی یک شیت را بازسازی کنی.

**علاوه بر این، برای دو شیت پرریسک تست اختصاصی بنویس:**
- `test/features/assistant/unified_assistant_sheet_responsive_test.dart` — برای `R-14`، با صفحه‌کلید باز.
- `test/features/worship/prayer_city_picker_responsive_test.dart` — برای `R-23`، با فیلد جست‌وجو و فهرست بلند.

### 🚦 دروازهٔ پذیرش فاز ۱

فاز ۲ را شروع نکن تا هر ده مورد زیر تیک نخورده باشد:

- [ ] `flutter analyze` — صفر خطا، صفر اخطار.
- [ ] `flutter test` — کامل سبز، شامل تست‌های موجود حرکت و تقویم و تنظیمات.
- [ ] `rg -n "height: MediaQuery.of" lib/` — خروجی خالی.
- [ ] `rg -c "RitmoSheetScaffold" lib/ | wc -l` — دست‌کم ۲۰ فایل.
- [ ] `rg -n "Color\\(0xFF0F111E\\)|Color\\(0xFF1E1E2C\\)|Color\\(0xFF131B2E\\)" lib/` — خروجی خالی.
- [ ] `rg -n "showModalBottomSheet" lib/ --glob '!**/ritmo_sheet_scaffold.dart' --glob '!**/sheet/**'` — خروجی خالی، یا هر مورد باقی‌مانده در سند پیشرفت با دلیل مستند شده.
- [ ] `flutter test test/core/widgets/sheet_responsive_test.dart` — هر ۲۴ حالت (۴ دستگاه × ۳ مقیاس × ۲ حالت صفحه‌کلید) سبز.
- [ ] هر ۱۷ یافتهٔ `R-13` تا `R-29` حالت پایانی دارد.
- [ ] `dart format --set-exit-if-changed lib test` — بدون تغییر.
- [ ] شمارش دقیق در سند پیشرفت: چند محل مهاجرت کرد، چند مورد `منتفی شد`، چند مورد `مسدود شد`. جمع باید ۳۸ باشد.

**کامیت:** `fix(ui): phase 1 — شیت‌ها و مودال‌های پاسخ‌گو [R-13 … R-30]`

---

## فاز ۲ — گریدها و کارت‌ها (`R-31` … `R-44`)

۱۶ محل `childAspectRatio` ثابت. این فاز دومین منبع بزرگ سرریز را می‌بندد، و برخلاف فاز ۱ اینجا یک راه‌حل واحد برای همه جواب نمی‌دهد. دقت کن کدام دسته است.

### R-31 — قرارداد مهاجرت گریدها و انتخاب‌گر تاریخ

**اول سه دسته را از هم تشخیص بده. این مهم‌ترین تصمیم فاز ۲ است:**

**دستهٔ الف — گرید تقویم (۷ ستون ثابت).** شمار ستون **درست است و نباید عوض شود** — هفته هفت روز دارد. فقط `childAspectRatio` باید به کف ارتفاع تبدیل شود. سه فایل در `R-32`.

**دستهٔ ب — گرید کارت‌های محتوایی.** شمار ستون باید محاسبه‌شود و ارتفاع از محتوا بیاید. این‌ها مستقیماً با `RitmoAdaptiveGrid` از `R-04` حل می‌شوند. بیشتر یافته‌های این فاز.

**دستهٔ ج — گرید فهرست بلند و اسکرول‌شدنی.** `Wrap` جواب نمی‌دهد چون همهٔ فرزندان یک‌جا ساخته می‌شوند. این‌ها با `SliverGridDelegateWithMaxCrossAxisExtent` و `mainAxisExtent` محاسبه‌شده حل می‌شوند.

**الگوی درست دستهٔ ب (پرتکرارترین):**
```dart
// غلط
GridView.count(
  crossAxisCount: 2,
  childAspectRatio: 2.2,
  children: cards,
)

// درست
RitmoAdaptiveGrid(
  minTileWidth: RitmoBreakpoints.tileMinWidthRegular,
  children: cards,
)
```

**الگوی درست دستهٔ ج:**
```dart
LayoutBuilder(
  builder: (context, constraints) {
    final columns = RitmoBreakpoints.columnsFor(
      availableWidth: constraints.maxWidth,
      minTileWidth: RitmoBreakpoints.tileMinWidthRegular,
      spacing: RitmoSpacing.md,
    );
    final tileWidth = (constraints.maxWidth - RitmoSpacing.md * (columns - 1)) / columns;
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: RitmoSpacing.md,
        mainAxisSpacing: RitmoSpacing.md,
        // ارتفاع قطعی خانه، محاسبه‌شده از عرض و مقیاس متن — نه نسبت ثابت
        mainAxisExtent: _tileHeight(context, tileWidth),
      ),
      itemBuilder: ...,
    );
  },
)
```

**`mainAxisExtent` در مقابل `childAspectRatio` — تفاوت بنیادین:** با `childAspectRatio` ارتفاع **تابعی از عرض** است، پس وقتی عرض کم می‌شود ارتفاع هم کم می‌شود — دقیقاً عکس آنچه لازم است. با `mainAxisExtent` ارتفاع مستقل است و می‌تواند با مقیاس متن رشد کند. این جمله را در `docs/ui/RESPONSIVE_LAYOUT.md` بنویس.

**بخش دوم این یافته — انتخاب‌گر تاریخ:**
فایل: `lib/core/utils/ritmo_date_picker.dart` — `crossAxisCount: 3, childAspectRatio: 2.2, itemCount: 12`

`itemCount: 12` یعنی این گرید ماه‌های سال را نشان می‌دهد. نام ماه‌های شمسی طول متغیر دارند: `دی` دو حرف، `اردیبهشت` هشت حرف. با سه ستون در عرض ۳۲۰ و فاصله، هر خانه حدود ۹۵ پیکسل عرض دارد و با نسبت `2.2` حدود ۴۳ پیکسل ارتفاع. «اردیبهشت» در ۹۵ پیکسل در مقیاس ۱٫۶ دو خط می‌شود و دو خط در ۴۳ پیکسل جا نمی‌شود. سرریز قطعی.

**این دقیقاً همان سرریزی است که تست `R-09` خفه می‌کرد** — کامنت آن تست می‌گوید «expected overflow exceptions from planner date picker».

اصلاح: به `RitmoAdaptiveGrid` با `minTileWidth: RitmoBreakpoints.tileMinWidthCompact` منتقل کن و `maxColumns: 3` بگذار. در عرض ۳۲۰ به دو ستون می‌ریزد و مشکل حل می‌شود. هر نام ماه را `maxLines: 1` و `TextOverflow.ellipsis` بده.

**پس از این یافته، فوراً برگرد و خط `contains('overflowed')` را از `test/widget/niyyah_edit_sheet_stays_open_test.dart` حذف کن و تست را اجرا کن.** اگر سبز شد، `R-09` را از `مسدود شد` به `انجام شد` تغییر بده. اگر قرمز ماند، یک منبع دوم سرریز داری — پیام خطا را بخوان و یافتهٔ جدیدی ثبت کن.

### R-32 — سه گرید تقویم ۷ ستونه

فایل‌ها:
- `lib/features/cycle/presentation/widgets/cycle_calendar_grid.dart` — `crossAxisCount: 7, childAspectRatio: 0.96`
- `lib/features/calendar/presentation/widgets/journey_month_view.dart` — `crossAxisCount: 7, childAspectRatio: 0.82`
- `lib/features/worship/presentation/widgets/worship_solar_calendar.dart` — `crossAxisCount: 7, childAspectRatio: 0.98`

**`crossAxisCount: 7` را عوض نکن. هرگز.** یک تقویم با شش ستون بی‌معنا است. این مورد استثنای قاعدهٔ `ت-۵` است و در خود قاعده مستثنا شده («نسبت ابعاد فقط برای محتوای واقعاً مربعی مانند خانهٔ تقویم مجاز است»).

**مشکل واقعی دو چیز است:**

**۱ — نسبت زیر یک (`0.82` و `0.96` و `0.98`) در عرض ۳۲۰ خانه‌های ریز می‌سازد.** حساب: عرض ۳۲۰ منهای پد دو طرف (حدود ۳۲) منهای شش فاصلهٔ بین ستونی ≈ ۳۷ پیکسل عرض هر خانه. با نسبت `0.82` می‌شود ۴۵ پیکسل ارتفاع. در ۴۵ پیکسل باید عدد روز (دو رقم) به‌علاوهٔ نشانگرها جا شود. در مقیاس متن ۱٫۶ عدد دورقمی تنها حدود ۲۶ پیکسل ارتفاع می‌خواهد؛ با یک نقطه یا نوار وضعیت زیرش سرریز می‌شود.

**۲ — هیچ کف ارتفاعی وجود ندارد.** در گوشیِ باریک‌تر خانه‌ها باز هم کوچک‌تر می‌شوند، تا بینهایت.

**اصلاح — الگوی اجباری برای هر سه فایل:**
```dart
LayoutBuilder(
  builder: (context, constraints) {
    const columns = 7; // ثابت و درست — هفته هفت روز دارد
    final spacing = RitmoSpacing.xs;
    final cellWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
    // کف ارتفاع: خانه حداقل باید جای عدد دورقمی در بزرگ‌ترین مقیاس متن را داشته باشد
    final cellHeight = math.max(cellWidth, _minCellHeight(context));
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        mainAxisExtent: cellHeight,
      ),
      ...
    );
  },
)
```

`_minCellHeight` باید با `TextPainter` ارتفاع واقعی یک عدد دورقمی را در مقیاس فعلی بسنجد و فضای نشانگرها را اضافه کند. **الگوی این اندازه‌گیری در مخزن موجود و درست است:** `lib/features/today/presentation/widgets/ritmo_nav_bar.dart` تابع `double _measureLabel(String text, TextStyle style, TextScaler scaler)` دارد که از `TextPainter(maxLines: 1, textScaler: scaler)..layout()` استفاده می‌کند. همان را تقلید کن. اگر این تابع را سه بار لازم داری، به `RitmoBreakpoints` منتقلش کن و هر سه جا از همان استفاده کنند.

**نتیجهٔ رفتاری موردانتظار:** در گوشی باریک یا مقیاس متن بالا، خانه‌های تقویم از مربع خارج می‌شوند و کمی عمودی‌تر می‌شوند. این پذیرفتنی است — برخلاف سرریز، یک تقویم کمی بلندتر هنوز قابل استفاده است.

**توجه به کار پیشین:** `cycle_calendar_grid.dart` در دو پرامپت قبلی دستکاری شده (`RITMO_CYCLE_FIX_PROMPT.md` و `RITMO_CYCLE_FORECAST_PROMPT.md`). قبل از تغییر، کل فایل را بخوان — منطق نشانگرهای پیش‌بینی (`CycleDayKind`) در همان خانه رندر می‌شود و نباید خراب شود. تست‌های `test/cycle/` باید سبز بمانند.

### R-33 — نمای سالانهٔ تقویم

فایل: `lib/features/calendar/presentation/widgets/journey_year_view.dart` — `crossAxisCount: 3, childAspectRatio: 0.82`

این فایل **الان `LayoutBuilder` دارد** ولی همزمان `childAspectRatio` ثابت هم دارد. یعنی نویسنده نیمه‌راه را رفته. پیش از تغییر، ببین `LayoutBuilder` موجود چه منطقی دارد و از همان `constraints` برای محاسبهٔ `mainAxisExtent` استفاده کن. `LayoutBuilder` دوم اضافه نکن.

۱۲ ماه در سه ستون یعنی چهار ردیف. هر خانه یک مینی‌تقویم ماهانه دارد. در عرض ۳۲۰ هر خانه حدود ۹۵ پیکسل است و با نسبت `0.82` حدود ۱۱۶ پیکسل ارتفاع. یک مینی‌تقویم با عنوان ماه و پنج ردیف روز در ۱۱۶ پیکسل عملاً غیرقابل خواندن است.

**تصمیم:** در `RitmoWidthClass.compact` به دو ستون برو، در `regular` و `large` سه ستون، در `expanded` چهار ستون. ارتفاع را از `mainAxisExtent` بده با کف منطقی برای پنج ردیف روز.

### R-34 — شیت ثبت سریع انرژی (بدترین گرید مخزن)

فایل: `lib/features/energy/presentation/widgets/quick_log_sheet.dart` — `crossAxisCount: 4, childAspectRatio: 1.1`

**این بدترین ترکیب ممکن است.** حساب دقیق در عرض ۳۲۰:
- پد شیت دو طرف (`RitmoSpacing.xl` ≈ ۲۴ هر طرف) → ۲۷۲ پیکسل باقی
- سه فاصلهٔ بین ستونی (حداقل ۸ پیکسل هرکدام) → ۲۴۸ پیکسل باقی
- تقسیم بر ۴ → **۶۲ پیکسل عرض هر خانه**
- با نسبت `1.1` → **۵۶ پیکسل ارتفاع هر خانه**

۵۶ پیکسل ارتفاع باید جای یک آیکون و یک برچسب فارسی باشد. در مقیاس متن ۱٫۰ مرزی است؛ در ۱٫۳ قطعاً می‌شکند؛ در ۱٫۶ فاجعه است. و ۶۲ پیکسل عرض کمتر از `RitmoBreakpoints.minTouchTarget` (۴۸) نیست ولی برای برچسب دوکلمه‌ای فارسی به‌هیچ‌وجه کافی نیست.

**اصلاح:** `RitmoAdaptiveGrid` با `minTileWidth: RitmoBreakpoints.tileMinWidthCompact` (۱۴۰) و `maxColumns: 4`. در عرض ۳۲۰ به دو ستون می‌ریزد — هر خانه حدود ۱۳۰ پیکسل عرض، کاملاً کافی.

**پرسش طراحی را ثبت کن ولی حلش نکن:** اگر این گرید چهار سطح انرژی یا حالت را نشان می‌دهد، ریختن به دو ستون ترتیب دیداری را عوض می‌کند (مقیاس خطی می‌شود جدول دودردو). در سند پیشرفت بنویس: «اگر این گرید مقیاس ترتیبی است، جایگزین درست `Wrap` یک‌ردیفی اسکرول‌افقی یا یک `Slider` است، نه گرید. این تصمیم محصولی است.» خودت تصمیم محصولی نگیر.

### R-35 — شیت تنظیمات سریع

فایل: `lib/features/settings/presentation/widgets/quick_settings_sheet.dart` — `childAspectRatio: 2.2`

نسبت `2.2` یعنی خانه‌های پهن و کوتاه — معمولاً کارتی با آیکون چپ و متن راست. در عرض ۳۲۰ و دو ستون، ارتفاع حدود ۶۰ پیکسل می‌شود.

**این فایل در ماژولی است که تنها تست مقیاس متن حلقه‌ای مخزن را دارد** (`test/settings/settings_text_scale_resilience_test.dart` با گروه `'Text Scale & Layout Resilience Tests (SET-65)'`). پس اینجا دو کار کن:
۱. اول ببین آیا آن تست این شیت را پوشش می‌دهد. اگر نمی‌دهد، قبل از اصلاح به آن حلقه اضافه‌اش کن تا قرمز شود.
۲. بعد اصلاح کن تا سبز شود. این دقیقاً روش درستی است که قاعدهٔ `۰-۱۰` می‌خواهد.

اصلاح: `RitmoAdaptiveGrid` با `minTileWidth: RitmoBreakpoints.tileMinWidthRegular` و `maxColumns: 2`.

### R-36 — شیت تعویق روتین

فایل: `lib/features/routines/presentation/widgets/routine_snooze_bottom_sheet.dart` — `childAspectRatio: 2.2`

خانه‌های این گرید مدت تعویق هستند («۱۰ دقیقه»، «۱ ساعت»، «تا فردا»). این برچسب‌ها طول متغیر دارند و با اعداد فارسی بلندتر می‌شوند.

اصلاح: `RitmoAdaptiveGrid` با `minTileWidth: RitmoBreakpoints.tileMinWidthCompact`. هر برچسب `maxLines: 2` و `TextOverflow.ellipsis` و `textAlign: TextAlign.center`.

**ممنوع:** کوتاه کردن متن برچسب‌ها برای جا شدن (مثلاً `۱۰ دقیقه` → `۱۰د`). این رابط کاربری را خراب می‌کند. چیدمان را عوض کن، نه محتوا را.

### R-37 — گرید دسته‌های برنامه‌ریز

فایل: `lib/features/routines/presentation/widgets/planner_category_grid.dart` — `crossAxisCount: 3, childAspectRatio: 1.15`

سه ستون در عرض ۳۲۰ → حدود ۸۸ پیکسل عرض، با نسبت `1.15` حدود ۷۷ پیکسل ارتفاع. نام دسته‌ها فارسی‌اند («سلامت»، «مطالعه»، «عبادت»، حتماً دوکلمه‌ای‌ها هم). با آیکون بالا و متن پایین در ۷۷ پیکسل، مقیاس ۱٫۳ می‌شکند.

اصلاح: `RitmoAdaptiveGrid` با `minTileWidth: RitmoBreakpoints.tileMinWidthCompact` و `maxColumns: 3`.

### R-38 — دو گرید صفحهٔ سلامت

فایل: `lib/features/health/presentation/health_screen.dart` — `childAspectRatio: 1.1` در **دو محل جدا**

هر دو محل را پیدا کن. احتمالاً یکی کارت‌های معیار (وزن، فشار خون، …) و دیگری کارت‌های اقدام است. **هر دو را جداگانه بررسی کن** — ممکن است یکی `minTileWidth` متفاوتی لازم داشته باشد.

کارت‌های معیار سلامت معمولاً عدد بزرگ + واحد + برچسب دارند — سه سطر متن. با نسبت `1.1` در دو ستون عرض ۳۲۰، ارتفاع حدود ۱۲۰ پیکسل — در مقیاس ۱٫۰ کافی، در ۱٫۶ تقریباً ۱۸۰ لازم می‌شود. سرریز ۶۰ پیکسلی.

اصلاح: هر دو با `RitmoAdaptiveGrid` و `minTileWidth: RitmoBreakpoints.tileMinWidthRegular`.

### R-39 — صفحهٔ بصیرت‌ها (گرید درون اسکرول دیگر)

فایل: `lib/features/today/presentation/insights_screen.dart` — `childAspectRatio: 1.4` همراه `physics: NeverScrollableScrollPhysics()`

**`NeverScrollableScrollPhysics` یعنی این گرید درون یک اسکرول دیگر قرار دارد** (معمولاً با `shrinkWrap: true`). این الگوی درستی است و نباید عوض شود — ولی یک نکتهٔ فنی مهم دارد:

**وقتی `shrinkWrap: true` باشد، `GridView` ارتفاع خودش را از جمع ارتفاع ردیف‌ها می‌سازد، که خودش از `childAspectRatio` می‌آید.** پس اگر محتوای خانه بلندتر از نسبت باشد، خانه سرریز می‌کند ولی **گرید بزرگ نمی‌شود** — پس اسکرول والد هم کمکی نمی‌کند. این یک سرریز غیرقابل فرار است.

اصلاح: `RitmoAdaptiveGrid` بر پایهٔ `Wrap` این مشکل را کاملاً حل می‌کند، چون `Wrap` ارتفاع واقعی فرزندان را می‌پذیرد. `physics` و `shrinkWrap` دیگر لازم نیستند — حذفشان کن. **این دقیقاً دلیل انتخاب `Wrap` در `R-04` است.**

### R-40 — بخش آمار کنکور

فایل: `lib/features/konkur/presentation/widgets/konkur_stats_section.dart` — `childAspectRatio: 1.4`

کارت‌های آماری با عدد بزرگ و برچسب. اصلاح استاندارد با `RitmoAdaptiveGrid` و `minTileWidth: RitmoBreakpoints.tileMinWidthRegular`.

**توجه به اعداد فارسی:** اگر این کارت‌ها از `toPersianDigits` یا `RitmoNumber` استفاده می‌کنند، ارقام فارسی می‌توانند پهن‌تر از لاتین باشند. در تست، عدد پنج‌رقمی فارسی بده نه دورقمی.

### R-41 — صفحهٔ هماهنگی چرخه (بدترین نسبت مخزن)

فایل: `lib/features/profile/presentation/cycle_harmony_screen.dart` — `crossAxisCount: 2, childAspectRatio: 2.3`

نسبت `2.3` بالاترین عدد مخزن است. دو ستون در عرض ۳۲۰ → حدود ۱۴۰ پیکسل عرض، تقسیم بر `2.3` → **۶۱ پیکسل ارتفاع**. در ۶۱ پیکسل با مقیاس متن ۱٫۳ عملاً فقط یک خط متن جا می‌شود.

**این ماژول محتوای توضیحی فارسی دارد** (هماهنگی چرخه با ورزش و خواب و انرژی). توضیح فارسی در یک خط جا نمی‌شود. این یکی از محتمل‌ترین جاهایی است که کاربر باگ را دیده.

اصلاح: `RitmoAdaptiveGrid` با `minTileWidth: RitmoBreakpoints.tileMinWidthWide` (۱۹۰) — یعنی در عرض ۳۲۰ یک ستون می‌شود. برای محتوای توضیحی، یک ستون درست‌تر از دو ستونِ بریده است.

### R-42 — بخش خلاصهٔ دستیار

فایل: `lib/features/assistant/presentation/widgets/assistant_briefing_section.dart` — `crossAxisCount: 2, childAspectRatio: 2.1`

همان مشکل `R-41` با شدت کمتر: حدود ۶۷ پیکسل ارتفاع در عرض ۳۲۰.

**محتوای خلاصهٔ دستیار تولیدی هوش مصنوعی است**، پس طول متن کاملاً غیرقابل پیش‌بینی است. هیچ نسبت ابعاد ثابتی نمی‌تواند درست باشد.

اصلاح: `RitmoAdaptiveGrid` با `minTileWidth: RitmoBreakpoints.tileMinWidthWide`. علاوه بر این، هر خانه باید `maxLines` داشته باشد وگرنه یک خلاصهٔ ده‌خطی کل صفحه را می‌بلعد. عدد پیشنهادی: `maxLines: 4` با `TextOverflow.ellipsis`.

### R-43 — سه گرید ورزش تکمیلی

فایل‌ها:
- `lib/features/supplementary_sports/presentation/ss_home_dashboard_screen.dart` — `childAspectRatio: 0.82` و `childAspectRatio: 0.9` (دو محل)
- `lib/features/supplementary_sports/presentation/ss_premium_muscle_category_screen.dart` — `crossAxisCount: 2, childAspectRatio: 0.95`

نسبت‌های زیر یک یعنی خانه‌های بلند — معمولاً کارت با تصویر بالا و متن پایین. **این کم‌ریسک‌ترین دستهٔ گرید فاز ۲ است**، چون نسبت زیر یک فضای عمودی فراوان می‌دهد.

**اما یک دام دارد:** اگر خانه تصویر دارد و تصویر با `AspectRatio` یا `Expanded` رندر می‌شود، تبدیل به `Wrap` می‌تواند تصویر را بی‌قید کند. در این دو فایل، اول ببین خانه چطور ساخته می‌شود:
- اگر تصویر ابعاد ثابت دارد → `RitmoAdaptiveGrid` مستقیماً کار می‌کند.
- اگر تصویر `Expanded` است → باید به `AspectRatio(aspectRatio: 16/9, child: Image(...))` تبدیل شود تا ارتفاع ذاتی پیدا کند، بعد `RitmoAdaptiveGrid`.

**`ss_premium_muscle_category_screen.dart` دستهٔ ج است** (فهرست بلند حرکات). از `GridView.builder` با `mainAxisExtent` محاسبه‌شده استفاده کن، نه `Wrap`. این دقیقاً همان موردی است که در `R-04` با عنوان «کجا `RitmoAdaptiveGrid` کافی نیست» نام برده شد.

### R-44 — تست محافظ گریدها

فایل جدید: `test/core/widgets/adaptive_grid_test.dart`

**بخش ۱ — تست خالص منطق ستون‌بندی** (بدون ویجت):

| عرض موجود | کمینهٔ خانه | فاصله | ستون موردانتظار |
|---|---|---|---|
| ۳۲۰ | ۱۴۰ | ۱۲ | ۲ |
| ۳۲۰ | ۱۹۰ | ۱۲ | ۱ |
| ۳۹۰ | ۱۶۰ | ۱۲ | ۲ |
| ۴۳۰ | ۱۴۰ | ۱۲ | ۲ |
| ۶۰۰ | ۱۴۰ | ۱۲ | ۴ (محدود به maxColumns) |

**بخش ۲ — تست ویجتی روی ۱۲ حالت:** یک `RitmoAdaptiveGrid` با خانه‌هایی که متن فارسی دوخطی دارند، روی هر چهار دستگاه و هر سه مقیاس، با `expectNoOverflow`.

**بخش ۳ — تست‌های اختصاصی برای دو مورد حساس:**
- `test/core/utils/ritmo_date_picker_responsive_test.dart` — برای `R-31`. هر ۱۲ نام ماه شمسی را رندر کن و مطمئن شو در `320×568` با مقیاس `1.6` سرریز نیست.
- `test/features/cycle/cycle_calendar_grid_responsive_test.dart` — برای `R-32`. **توجه: پوشهٔ تست چرخه در این مخزن `test/cycle/` است، نه `test/features/cycle/`.** فایل را در `test/cycle/cycle_calendar_grid_responsive_test.dart` بساز تا با ساختار موجود هماهنگ باشد.

در تست تقویم چرخه، ماهی را بده که **۳۱ روز دارد و از پنج‌شنبه شروع می‌شود** — بدترین حالت که شش ردیف لازم دارد. اگر ماه پنج‌ردیفی بدهی، تست باگ را پیدا نمی‌کند.

### 🚦 دروازهٔ پذیرش فاز ۲

- [ ] `flutter analyze` — صفر خطا، صفر اخطار.
- [ ] `flutter test` — کامل سبز.
- [ ] `rg -n "childAspectRatio" lib/` — **دقیقاً صفر نتیجه**، یا فقط درون `RitmoAdaptiveGrid` و با کامنت توضیحی.
- [ ] `rg -n "crossAxisCount: 7" lib/` — دقیقاً سه نتیجه (سه تقویم، عمدی و درست).
- [ ] `rg -n "overflowed" test/widget/` — خالی (خفه‌کنندهٔ `R-09` قطعی حذف شد).
- [ ] `flutter test test/widget/niyyah_edit_sheet_stays_open_test.dart` — سبز **بدون** خفه‌کردن سرریز. `R-09` به `انجام شد` تغییر کرد.
- [ ] `flutter test test/core/widgets/adaptive_grid_test.dart` — هر ۵ حالت منطقی و هر ۱۲ حالت ویجتی سبز.
- [ ] `flutter test test/settings/` — تست مقیاس متن تنظیمات سبز، و اگر شیت تنظیمات سریع را به حلقه اضافه کردی، آن هم سبز.
- [ ] `flutter test test/cycle/` — کامل سبز (تقویم چرخه خراب نشده).
- [ ] هر ۱۴ یافتهٔ `R-31` تا `R-44` حالت پایانی دارد، و جمع محل‌های پوشش‌داده‌شده ۱۶ است.

**کامیت:** `fix(ui): phase 2 — گریدهای پاسخ‌گو و حذف نسبت ابعاد ثابت [R-31 … R-44]`

---

## فاز ۳ — ردیف، متن و چیپ (`R-45` … `R-58`)

فازهای ۱ و ۲ دو منبع سرریزی را بستند که قابل شمارش بودند (۳۹ و ۱۶ محل). این فاز منبعی را می‌بندد که **با جست‌وجوی متنی قابل شمارش نیست**: متن بدون قید درون `Row`.

### R-45 — قرارداد متن در ردیف و روش شمارش (این را اول بخوان)

**دقیقاً چرا این فاز فرق دارد:** برای فاز ۱ دستور `rg -n "height: MediaQuery"` فهرست دقیق می‌داد. برای این فاز، **هیچ دستور جست‌وجویی وجود ندارد که `Text` بدون قید درون `Row` را پیدا کند** — این یک مشکل ساختاری درخت ویجت است، نه متنی.

**پس روش این فاز متفاوت است: تست‌محور نه جست‌وجو‌محور.**

برای هر یافتهٔ `R-46` تا `R-57`، این چرخهٔ چهار مرحله‌ای را اجرا کن:

**مرحلهٔ ۱ — تست را اول بنویس و بگذار قرمز شود.** با `testAcrossViewports` از `R-07`، ویجت را در ۱۲ حالت رندر کن و `expectNoOverflow` بزن. **دادهٔ تست باید بدترین حالت واقعی باشد، نه دادهٔ خوش‌خیم.**

**مرحلهٔ ۲ — پیام خطا را بخوان.** خطای `RenderFlex overflowed by N pixels on the right` دقیقاً می‌گوید کدام `Row` و چند پیکسل. حدس نزن.

**مرحلهٔ ۳ — ترتیب راه‌حل را از قاعدهٔ `۰-۹` رعایت کن.** یعنی:

| ترتیب | راه‌حل | کجا مناسب است |
|---|---|---|
| ۱ | `Expanded` یا `Flexible` دور بلوک متنی اصلی | ردیفی با یک متن بلند و یک عنصر کوتاه (متن + آیکون) |
| ۲ | `maxLines` + `TextOverflow.ellipsis` | متنی که بریدنش قابل قبول است (نام، عنوان) |
| ۳ | `Row` → `Wrap` | چند عنصر هم‌وزن مانند چیپ‌ها یا برچسب‌ها |
| ۴ | `RitmoAdaptiveRow` از `R-05` | دو بلوک متنی که در عرض کم باید زیر هم بروند |
| ۵ | اسکرول افقی | فقط برای ریل‌های عمدی (ریل روزهای هفته) |
| ۶ | حذف عنصر کم‌اهمیت در عرض کم + `Semantics` جانشین | پیشوندها و برچسب‌های تکمیلی |

**راه‌حل شمارهٔ ۶ الگوی موجود و درست در مخزن دارد:** `lib/features/calendar/presentation/widgets/now_pill.dart` می‌گوید `showPrefix = width >= 300` — یعنی در عرض کم پیشوند متن حذف می‌شود. این دقیقاً روش درست است. وقتی این را به کار می‌بری، مرز `300` را به `RitmoBreakpoints` منتقل کن.

**مرحلهٔ ۴ — تست را سبز کن و بشمار چند محل را لمس کردی.** در سند پیشرفت برای هر یافته فهرست دقیق فایل‌ها و شمارهٔ خط‌ها را بنویس. **اگر تست از اول سبز بود، یافته را `منتفی شد` علامت بزن و بنویس دادهٔ تست چه بود — ولی اول مطمئن شو دادهٔ تست واقعاً بدترین حالت بوده.**

**دادهٔ بدترین حالت استاندارد — در همهٔ تست‌های این فاز استفاده کن:**
```dart
/// متن‌های مرجع بدترین حالت برای تست چیدمان فارسی.
/// در test/support/responsive_harness.dart بگذار.
const kWorstCaseFa = (
  // بلندترین نام روز هفته
  weekday: 'چهارشنبه',
  // بلندترین نام ماه شمسی
  month: 'اردیبهشت',
  // عنوان بلند واقعی‌نما
  title: 'تمرین کششی و تقویتی عملکرد مرکزی بدن',
  // عدد پنج‌رقمی فارسی — پهن‌تر از لاتین
  bigNumber: '۱۲۳۴۵',
  // متن تولیدی هوش مصنوعی — طول غیرقابل پیش‌بینی
  aiSummary: 'بر اساس داده‌های این هفته، انرژی شما در بعدازظهرها '
      'به طور محسوسی کاهش می‌یابد و بهتر است جلسات تمرکزی را '
      'به ساعات اولیهٔ روز منتقل کنید.',
);
```

**بخش دوم این یافته — انتخاب‌گر شهر عبادت:**
اگر در `R-23` برای `lib/features/worship/presentation/widgets/prayer_city_picker.dart` به نام‌های شهر `maxLines: 1` و `TextOverflow.ellipsis` دادی، اینجا فقط تأیید کن و به `R-23` ارجاع بده. دوباره انجامش نده.

### R-46 — ردیف‌های سه‌بلوکی داده (عنوان + تاریخ + مقدار)

این پرتکرارترین الگوی سرریز افقی در برنامه‌های فارسی است: سه بلوک متنی در یک `Row` بین `MainAxisAlignment.spaceBetween`.

**ماژول‌های هدف (با اولویت):**
۱. `lib/features/konkur/presentation/widgets/konkur_exams_section.dart` — ردیف آزمون (در `R-26` نام برده شد)
۲. `lib/features/health/presentation/` — ردیف‌های معیار و ردیف دارو
۳. `lib/features/goals/presentation/` — ردیف هدف با درصد پیشرفت
۴. `lib/features/courses/presentation/` — ردیف جلسه با مدت و وضعیت
۵. `lib/features/study/presentation/` و `lib/features/simple_tasks/presentation/`

**الگوی اجباری:**
```dart
Row(
  children: [
    // عنوان می‌تواند بریده شود — پس Expanded می‌گیرد
    Expanded(
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: RitmoTextStyles.cardTitle,
      ),
    ),
    const SizedBox(width: RitmoSpacing.sm),
    // مقدار عددی نباید بریده شود — پس Expanded نمی‌گیرد
    Text(value, style: RitmoTextStyles.caption),
  ],
)
```

**دو قاعدهٔ قطعی:**
- در هر `Row`، **دقیقاً یک بلوک متنی `Expanded` می‌گیرد** — آنکه بریدنش کمترین ضرر را دارد. دو `Expanded` در یک ردیف یعنی هر دو بریده می‌شوند و هیچ‌کدام خوانا نمی‌ماند.
- عدد، تاریخ، درصد و واحد **هرگز** بریده نمی‌شوند. `۱۲۳…` بدتر از هیچ است — عملاً دادهٔ غلط نشان می‌دهد.

**اگر هر سه بلوک باید کامل دیده شوند** (مثلاً نام آزمون + تاریخ + درصد)، `RitmoAdaptiveRow` به کار ببر: در عرض کم به دو سطر می‌ریزد (عنوان بالا، تاریخ و درصد پایین).

### R-47 — چیپ‌ها و برچسب‌ها: هر `Row` چیپ باید `Wrap` شود

چیپ (برچسب گرد با متن کوتاه) پرتکرارترین عنصر رابط کاربری ریتمو است: علائم چرخه، برچسب‌های حرکت، دسته‌های روتین، وضعیت رخداد، فیلترها.

**قاعدهٔ مطلق: هر مجموعهٔ چیپ که تعدادش از داده می‌آید، باید `Wrap` باشد، نه `Row` و نه `SingleChildScrollView(scrollDirection: Axis.horizontal)`.**

```dart
Wrap(
  spacing: RitmoSpacing.xs,
  runSpacing: RitmoSpacing.xs,
  children: tags.map((t) => _Chip(t)).toList(),
)
```

**چرا اسکرول افقی برای چیپ غلط است:** کاربر نمی‌داند چیپ بیشتری هم وجود دارد. در یک ردیف اسکرول‌شونده، علامت بصری وجود محتوای بیشتر دیده نمی‌شود و در جهت راست‌به‌چپ بدتر هم می‌شود. `Wrap` همه را نشان می‌دهد.

**دو استثنای مجاز برای اسکرول افقی:**
۱. ریل روزهای هفته (`lib/features/movement/presentation/center/widgets/week_rail.dart`) — ترتیب زمانی معنادار دارد و ریختن به دو ردیف گمراه‌کننده است. این فایل الان هم درست است (`minRequiredWidth = (MovementLayout.kDaySlotMinSize.width * 7) + (RitmoSpacing.lg * 2)`) — **دستش نزن.**
۲. ریل فیلتر با تعداد ثابت و مشخص (مثلاً فقط چهار فیلتر) که کاربر می‌داند چندتایی است.

### R-48 — نوار عنوان ماژول‌ها

فایل: `lib/core/widgets/ritmo_module_app_bar.dart` (۳٬۸۴۰ بایت)

**این یک ویجت مشترک است، پس یک اصلاح اینجا در همهٔ ۲۸ ماژول اثر می‌گذارد. بالاترین نسبت ارزش به تلاش در این فاز.**

چهار چیز را چک کن:
۱. عنوان `maxLines: 1` و `TextOverflow.ellipsis` دارد؟ عنوان ماژول فارسی ممکن است بلند باشد («ورزش تکمیلی»، «دوره‌های آموزشی»، «حرکت مرکزی»).
۲. عنوان درون `Expanded` است؟ اگر دکمهٔ اقدام سمت چپ دارد و عنوان `Expanded` نیست، سرریز می‌دهد.
۳. ارتفاع نوار ثابت است؟ در مقیاس متن ۱٫۶ عنوان بلندتر می‌شود و ارتفاع ثابت می‌شکند. از `PreferredSize` با ارتفاع محاسبه‌شده از مقیاس متن استفاده کن.
۴. زیرعنوان دارد؟ اگر بله، در مقیاس بالا زیرعنوان باید `maxLines: 1` باشد، یا در `RitmoWidthClass.compact` حذف شود (الگوی `now_pill.dart`).

**مرجع اندازه‌گیری ارتفاع وابسته به مقیاس متن در مخزن موجود است:** `test/features/today/ritmo_nav_bar_height_test.dart` دقیقاً همین را برای نوار پایین تست می‌کند. الگوی تست را از آن بردار و برای نوار بالا بنویس.

### R-49 — نوار ناوبری پایین (تأیید، نه اصلاح)

فایل: `lib/features/today/presentation/widgets/ritmo_nav_bar.dart`

**این فایل بهترین کد پاسخ‌گوی مخزن است.** تابع `double _measureLabel(String text, TextStyle style, TextScaler scaler)` دارد که با `TextPainter(maxLines: 1, textScaler: scaler)..layout()` عرض واقعی برچسب را می‌سنجد و بر اساس آن تصمیم می‌گیرد.

**کاری که باید بکنی — فقط دو چیز:**
۱. تأیید کن که در ۳۲۰×۵۶۸ با مقیاس ۱٫۶ و هرچند قلم ناوبری که وجود دارد، سرریز ندارد. تست `test/features/today/ritmo_nav_bar_height_test.dart` را به حلقهٔ `testAcrossViewports` منتقل کن تا هر ۱۲ حالت پوشش داده شود.
۲. اگر تابع `_measureLabel` در `R-32` به `RitmoBreakpoints` منتقل شد، این فایل را هم به همان تابع مشترک وصل کن — بدون تغییر منطق.

**ممنوع: بازنویسی منطق این فایل.** اگر تست سبز است، یافته را `منتفی شد` علامت بزن و برو. این فایل به کمک تو نیاز ندارد.

### R-50 — ردیف‌های فهرست و `ListTile`

`ListTile` پیش‌فرض فلاتر در فارسی مشکل خاصی دارد: `title` و `subtitle` پیش‌فرض `maxLines` ندارند، و `trailing` با متن طولانی قید نمی‌شود.

**دو قاعده برای هر `ListTile` در برنامه:**
۱. `title` باید `maxLines: 1` و `overflow: TextOverflow.ellipsis` داشته باشد؛ `subtitle` حداکثر `maxLines: 2`.
۲. `trailing` هرگز متن بلند نگیرد. اگر متن بلند لازم است، به `subtitle` منتقل شود یا `ListTile` را با `Row` و `Expanded` دستی جایگزین کن.

**ماژول‌های هدف (فهرست‌محورترین‌ها):** `lib/features/notes/`، `lib/features/simple_tasks/`، `lib/features/inbox/`، `lib/features/registry/`، `lib/features/search/`، `lib/features/settings/`.

**روش شمارش:** `rg -n "ListTile\\(" lib/ -l` فهرست فایل‌ها را می‌دهد. برای هر فایل، چک کن آیا `title:` آن `maxLines` دارد. این دستور قابل اتکاست چون `ListTile` یک نام دقیق است.

### R-51 — دکمه‌ها با آیکون و متن

ویجت‌های مشترک موجود: `RitmoPrimaryButton` و `RitmoSecondaryButton` (در `lib/core/widgets/ritmo/`).

**این دو ویجت را بخوان و چهار چیز را تأیید یا اصلاح کن:**
۱. ارتفاع ثابت دارند؟ **اگر بله، این مهم‌ترین یافتهٔ فاز ۳ است.** الگوی درست در مخزن موجود است: `lib/features/movement/presentation/session/widgets/session_primary_cta.dart` می‌گوید `buttonHeight = textScale > 1.2 ? MovementLayout.kPrimaryButtonHeightLarge : MovementLayout.kPrimaryButtonHeight`. همین الگو را با `context.isLargeTextScale` به دو دکمهٔ مشترک ببر.
۲. متن دکمه `Flexible` و `maxLines: 1` دارد؟ متن دکمهٔ فارسی مانند «مشاهدهٔ وضعیت و تشخیص پل وب» (موجود در `ai_connection_screen.dart`) بلند است و با آیکون در ۳۲۰ قطعاً سرریز می‌دهد.
۳. ردیف دو دکمه کنار هم («لغو» و «تأیید») در عرض کم چه می‌شود؟ اگر متن‌ها بلندند، باید به `Column` بریزد — `RitmoAdaptiveRow`.
۴. هدف لمس دست‌کم `RitmoBreakpoints.minTouchTarget` است؟

**توجه به کار پیشین:** پرامپت `RITMO_CYCLE_FIX_PROMPT.md` در یافتهٔ `C-43` قبلاً دکمه‌های با ارتفاع ثابت ۵۶ و ۶۴ پیکسل را مستند کرده بود. چک کن آیا حل شده یا نه — ولی به سند پرامپت قبلی اعتماد نکن، فقط به کد.

### R-52 — تب‌بارهای فارسی

تب‌بارها در ریتمو زیادند. یک مثال مستند: `lib/features/cycle/presentation/cycle_screen.dart` چهار تب دارد — «داشبورد»، «روندها»، «همبستگی‌ها»، «روزه قضا».

**حساب دقیق:** چهار تب در عرض ۳۲۰ منهای پد = حدود ۷۰ پیکسل هر تب. «همبستگی‌ها» ده حرف است و در مقیاس ۱٫۰ حدود ۷۵ پیکسل پهنا می‌خواهد. در مقیاس ۱٫۶ حدود ۱۲۰. **سرریز قطعی.**

**دو راه‌حل مجاز (به ترتیب اولویت):**
۱. `isScrollable: true` به `TabBar` بده و `tabAlignment: TabAlignment.start`. این ساده‌ترین و امن‌ترین است. تب‌بار از استثناهای مجاز اسکرول افقی است چون تب‌بار فلاتر خودش نشانگر تب فعال و حرکت را نشان می‌دهد.
۲. در `RitmoWidthClass.compact` یا `context.isLargeTextScale`، `isScrollable: true`؛ در بقیه `false`. این زیباتر است ولی دو حالت را باید تست کنی.

**ممنوع:** کوتاه کردن نام تب‌ها («همبستگی‌ها» → «همبستگی»). این تصمیم محتوایی است و از دامنهٔ تو بیرون است.

**فایل‌های هدف:** همهٔ `TabBar` ها را با `rg -n "TabBar\\(" lib/` پیدا کن. برای هرکدام، بلندترین برچسب را با `_measureLabel` در مقیاس ۱٫۶ بسنج و در عرض ۳۲۰ چک کن.

### R-53 — جدول‌های داده

اگر جایی از برنامه `DataTable` یا `Table` استفاده می‌کند، آنجا در گوشی باریک قطعاً می‌شکند. `DataTable` هیچ راهبردی برای عرض کم ندارد.

**روش شمارش:**
```
rg -n "DataTable|DataColumn|DataRow|Table\\(" lib/
```

**اگر خالی بود، این یافته `منتفی شد` است — خروجی دستور را در سند پیشرفت بنویس و برو.** وقت تلف نکن.

اگر پیدا شد، دو راه‌حل مجاز: (الف) `SingleChildScrollView(scrollDirection: Axis.horizontal)` دور جدول — جدول از استثناهای مجاز اسکرول افقی است؛ (ب) در `RitmoWidthClass.compact` جدول را به فهرست کارت تبدیل کن (هر ردیف یک کارت، هر ستون یک برچسب-مقدار).

### R-54 — نشانگرهای پیشرفت و حلقه‌ها

فایل: `lib/core/widgets/ritmo_progress_ring.dart` (۵٬۶۷۳ بایت)

**دو چیز را چک کن:**
۱. قطر حلقه ثابت است؟ اگر بله، در `RitmoWidthClass.compact` ممکن است با محتوای کنارش جا نشود. قطر را از `LayoutBuilder` و `math.min(constraints.maxWidth, constraints.maxHeight)` بگیر.
۲. متن درون حلقه (درصد) با مقیاس متن بزرگ می‌شود ولی حلقه نه. در مقیاس ۱٫۶ متن از حلقه بیرون می‌زند. دو راه‌حل: یا درون حلقه `FittedBox(fit: BoxFit.scaleDown)` بگذار، یا قطر را با مقیاس متن رشد بده.

**`FittedBox(fit: BoxFit.scaleDown)` تنها جایی است که کوچک کردن متن مجاز است**، و فقط برای اعداد کوتاه درون فضای دایره‌ای ثابت. هرگز `FittedBox` را دور جمله یا عنوان نگذار — متن را خواناناپذیر می‌کند و دقیقاً همان چیزی است که قاعدهٔ `۰-۹` ممنوع کرده.

**دو مورد دیگر با ارتفاع نوار ثابت که باید تأیید شوند:**
- `lib/features/today/presentation/widgets/dashboard/today_path_progress_banner.dart` — `barHeight = 8.0`. این درست است؛ نوار پیشرفت متن ندارد پس ارتفاع ثابتش مشکلی نیست. `منتفی شد`.
- `lib/features/courses/presentation/widgets/segmented_visual_journey_track.dart` — `height: 14` و `gap = totalCount > 20 ? 1.0 : 2.0`. این هم `LayoutBuilder` دارد و تعداد را در فاصله دخیل کرده — کد خوبی است. فقط تأیید کن که با `totalCount` خیلی بالا (مبلاً ۱۰۰ جلسه) عرض هر قطعه زیر یک پیکسل نمی‌شود.

### R-55 — نشان‌ها و بج‌ها

فایل: `lib/core/widgets/occurrence_status_badge.dart` (۱٬۶۹۴ بایت)

این نشان وضعیت رخداد را نشان می‌دهد. مقادیر `MovementOccurrenceStatus` هشت حالتند: `planned`، `inProgress`، `completed`، `partial`، `skipped`، `moved`، `late`، `restDay`. برچسب فارسی هرکدام طول متفاوتی دارد («در حال اجرا» بلندترین، «انجام شده» و «جابجا شده» هم بلندند).

**قاعده:** نشان باید عرض ذاتی داشته باشد (`IntrinsicWidth` یا بدون `width:` ثابت) و درون `Row` پدر هرگز `Expanded` نگیرد — ولی متن کنارش بگیرد.

**تست اجباری:** هشت مقدار `MovementOccurrenceStatus.values` را در یک حلقه رندر کن و در هر ۱۲ حالت `expectNoOverflow` بزن. این دقیقاً الگوی تست موجود `test/features/movement/center_rtl_overflow_test.dart` است که `HeroCardVariant.values` را حلقه می‌زند — همان را تقلید کن. و `test/features/movement/day_status_indicators_test.dart` را هم بخوان — ممکن است بخشی از این پوشش را داشته باشد.

### R-56 — حالت‌های خالی

ویجت مشترک: `RitmoEmptyState`

حالت خالی معمولاً آیکون بزرگ + عنوان + توضیح + دکمه دارد. در گوشی کوتاه (`RitmoHeightClass.short`) با مقیاس متن بالا، این چهار عنصر قطعاً در فضای خالی یک تب جا نمی‌شوند.

**اصلاح اجباری — سه تغییر:**
۱. کل محتوا در `SingleChildScrollView` باشد. حالت خالی افقی وسط‌چین اما عمودی اسکرول‌پذیر.
۲. اندازهٔ آیکون در `RitmoHeightClass.short` کوچک‌تر شود. این تنها موردی است که کوچک کردن عنصر مجاز است — چون آیکون تزئینی است و اطلاعاتی نیست.
۳. توضیح `maxLines: 3` و `TextOverflow.ellipsis`.

**یک مورد خاص که قبلاً مستند شده:** `lib/features/cycle/presentation/widgets/cycle_empty_state_banner.dart` (۵٬۸۷۷ بایت) متن فارسی سخت‌کدشده دارد. محلی‌سازیٔ آن از دامنهٔ این کار بیرون است — فقط چیدمانش را درست کن و در سند پیشرفت بنویس که متنش محلی‌سازی نشده و کار جداگانه‌ای است.

### R-57 — موتورهای نمودار

دو فایل موجود که الان `LayoutBuilder` دارند ولی ارتفاع ثابت هم دارند:
- `lib/features/wellbeing/presentation/widgets/wellbeing_pulse_chart.dart` — `SizedBox(height: 160)`
- `lib/features/wellbeing/presentation/widgets/daily_rhythm_card.dart` — `SizedBox(height: 16)`

**نمودار با ارتفاع ثابت مشکل نیست — مشکل برچسب‌های محور است.** دو چیز را چک کن:
۱. برچسب محور افقی (معمولاً نام روز یا ساعت) در مقیاس ۱٫۶ روی هم می‌افتد؟ اگر بله، در عرض کم یکی درمیان نشان بده (منطق `showEvery`)، نه اینکه فونت را کوچک کنی.
۲. ارتفاع ثابت `160` شامل فضای برچسب هم می‌شود؟ اگر برچسب زیر نمودار درون همان `SizedBox(height: 160)` است، در مقیاس بالا سرریز می‌دهد. ارتفاع را به `160 + ارتفاع محاسبه‌شدهٔ برچسب` تبدیل کن.

**یک مورد مستندِ قبلی که باید تأیید شود:** فایل `03.md` در ریشهٔ مخزن، یافتهٔ `B47` را ثبت کرده: «عدد جادویی چیدمان» — ضریب ۱۱۰ پیکسلی درون یک ناحیهٔ ثابت ۱۶۰ پیکسلی در ماژول حال و تعادل، با توصیهٔ «با بزرگ‌شدن فونت سیستم می‌شکند، از `LayoutBuilder` یا `FractionallySizedBox` استفاده کن». **چک کن آیا حل شده یا نه.** اگر حل نشده، همینجا حلش کن و در سند پیشرفت به `B47` ارجاع بده. این نشان می‌دهد مشکل یک بار دیده شده و رفع نشده.

### R-58 — تست‌های محافظ فاز ۳

برای هر یافتهٔ `R-46` تا `R-57` که حالتش `انجام شد` شد، باید دقیقاً یک فایل تست محافظ وجود داشته باشد.

**دو فایل مشترک اجباری:**
- `test/core/widgets/shared_widgets_responsive_test.dart` — پوشش `RitmoModuleAppBar`، `RitmoPrimaryButton`، `RitmoSecondaryButton`، `RitmoEmptyState`، `OccurrenceStatusBadge`، `RitmoProgressRing`. هر ویجت در ۱۲ حالت با `kWorstCaseFa`.
- `test/features/responsive_sweep_test.dart` — یک تست برای هر ماژولی که در فاز ۳ لمس شد.

**قاعدهٔ قطعی کیفیت تست:** هر تست این فاز باید کامنتی داشته باشد که می‌گوید پیش از اصلاح چه خطایی می‌داد. مانند:
```dart
// پیش از R-46: RenderFlex overflowed by 34 pixels on the right
// در عرض 320 با مقیاس 1.6 و عنوان kWorstCaseFa.title
```
این کامنت **مدرک** است که تست واقعاً یک باگ را گرفته، نه اینکه بعد از کار نوشته شده. اگر نمی‌توانی این کامنت را بنویسی، یعنی تست را قبل از اصلاح اجرا نکرده‌ای — برگرد و قاعدهٔ `R-45` را درست اجرا کن.

### 🚦 دروازهٔ پذیرش فاز ۳

- [ ] `flutter analyze` — صفر خطا، صفر اخطار.
- [ ] `flutter test` — کامل سبز.
- [ ] هر ۱۴ یافتهٔ `R-45` تا `R-58` حالت پایانی دارد. موارد `منتفی شد` خروجی دستور جست‌وجو را دارند.
- [ ] `test/support/responsive_harness.dart` حالا `kWorstCaseFa` دارد و دست‌کم ۶ فایل تست از آن استفاده می‌کنند.
- [ ] `rg -n "isScrollable" lib/` — هر `TabBar` با بیش از دو تب فارسی، یا `isScrollable: true` دارد یا منطق وابسته به عرض.
- [ ] `rg -n "FittedBox" lib/` — فقط درون فضای دایره‌ای ثابت (حلقهٔ پیشرفت)، هرگز دور جمله یا عنوان.
- [ ] `flutter test test/core/widgets/shared_widgets_responsive_test.dart` — هر شش ویجت مشترک در هر ۱۲ حالت سبز.
- [ ] هر تست جدید این فاز کامنت «پیش از R-xx» دارد که خطای واقعی پیش از اصلاح را نقل می‌کند.
- [ ] `flutter test test/features/movement/` — هر سه تست موجود سرریز (`rtl_overflow_test.dart`، `center_rtl_overflow_test.dart`، `undo_toast_test.dart`) **بدون تغییر** سبز.

**کامیت:** `fix(ui): phase 3 — قید متن در ردیف و چیپ و تب‌بار [R-45 … R-58]`

---

## فاز ۴ — اندازه‌های ثابت و `Stack`/`Positioned` (`R-59` … `R-70`)

این فاز منبع پنجم را می‌بندد: اعداد جادویی در کد. برخلاف فاز ۳، این‌ها **کاملاً قابل شمارش‌اند** — پس اول بشمار، بعد دست بزن.

### R-59 — هر `fontSize:` سخت‌کدشده (بزرگ‌ترین یافتهٔ این فاز)

**اول بشمار:**
```
rg -n "fontSize:" lib/ | wc -l
rg -n "fontSize:" lib/ -l | wc -l
```
هر دو عدد را در سند پیشرفت بنویس. این عدد مرجع توست.

**دقیقاً چرا `fontSize:` سخت‌کدشده یک مشکل پاسخ‌گویی است و نه فقط مسئلهٔ طراحی:** وقتی کسی `fontSize: 9` می‌نویسد، دارد متن را کوچک می‌کند تا در فضای تنگ جا شود. یعنی **هر `fontSize:` کوچک یک سرریزِ پنهان‌شده است.** و در مقیاس متن ۱٫۶ همان متن ۹ پیکسلی به ۱۴٫۴ می‌رود و سرریز برمی‌گردد — ولی حالا متن هم ریز است و هم سرریز می‌دهد.

**مقادیر مستندِ دو پرامپت پیشین (مدرک اینکه مشکل قدیمی است):**
- `RITMO_COURSES_FIX_PROMPT.md` یافتهٔ `K-89`: مقادیر `9`، `9.5`، `10`، `10.5`، `11`، `11.5`، `12.5` در ماژول دوره‌های آموزشی.
- `RITMO_CYCLE_FIX_PROMPT.md` یافتهٔ `C-43`: مقادیر `10`، `10.5`، `11` در ماژول چرخه.

**روش اصلاح — هر مورد در یکی از این چهار دسته می‌افتد:**

| دسته | نشانه | کار |
|---|---|---|
| الف | `fontSize` معادل یکی از سبک‌های `RitmoTextStyles` است | جایگزین کن با همان سبک. ساده‌ترین دسته. |
| ب | `fontSize` کوچک (زیر ۱۱) برای جا شدن در فضای تنگ | **مشکل واقعی چیدمان است.** فضا را درست کن، بعد `fontSize` را بردار و سبک استاندارد بگذار. |
| ج | `fontSize` بزرگ (بالای ۲۴) برای عدد نمایشی | اگر در `RitmoTextStyles` معادل ندارد، **یک سبک جدید به `RitmoTextStyles` اضافه کن** و همه جا از آن استفاده کن. |
| د | `fontSize` درون `TextPainter` یا محاسبهٔ اندازه | مجاز است. دست نزن. کامنت توضیحی بگذار. |

**دو مورد خاص که قبلاً نام برده شدند:**
- `lib/features/courses/presentation/widgets/study_timer_sheet.dart` — ارقام تایمر. در `R-21` گفتم فقط ثبت کن و دست نزن — **حالا جایِ رسیدگی است.** ارقام تایمر دستهٔ ج هستند: یک سبک `RitmoTextStyles.timerDisplay` بساز و از آن استفاده کن. مهم: ارقام تایمر باید `FontFeature.tabularFigures()` داشته باشند تا با عوض شدن عدد جابجا نشوند — اگر ندارد، اضافه کن.
- `lib/features/cycle/presentation/widgets/cycle_empty_state_banner.dart` — در `R-56` نام برده شد.

**ممنوع مطلق:** حل کردن دستهٔ ب با تغییر عدد (مبلاً `9` → `8`). این دقیقاً ریشهٔ چهارم است که در فاز ۰ برایش دروازه گذاشتیم.

**گارد پایانی این یافته:** عدد `rg -n "fontSize:" lib/ | wc -l` باید دست‌کم **۷۰ درصد** کمتر از عدد مرجع شود. موارد باقی‌مانده فقط دستهٔ د باشند و هرکدام کامنت داشته باشد. عدد قبل و بعد را در پیام کامیت بنویس.

### R-60 — عرض و ارتفاع ثابت در `Container` و `SizedBox`

**اول بشمار:**
```
rg -n "width: [0-9]{3}" lib/
rg -n "height: [0-9]{3}" lib/
rg -n "SizedBox\\(width: [0-9]{3}" lib/
```
الگوی سه‌رقمی را عمداً انتخاب کردم: اعداد دورقمی معمولاً فاصله یا آیکون هستند و مشکلی ندارند؛ **اعداد سه‌رقمی تقریباً همیشه یک فرض دربارهٔ عرض صفحه‌اند.**

**مقادیر مستندِ `C-43` که باید خاص چک شوند:** `width: 320`، `SizedBox(width: 240)`، `SizedBox(width: 260)`.

**`width: 320` بدترین عدد ممکن است**، چون دقیقاً مساوی عرض کوچک‌ترین گوشی پشتیبانی‌شده است. یعنی در آن گوشی، این عنصر دقیقاً کل عرض صفحه را می‌گیرد و هر پدی در جد والدیِ آن باعث سرریز می‌شود.

**جایگزین‌های مجاز:**

| الگوی غلط | جایگزین |
|---|---|
| `Container(width: 320)` | `ConstrainedBox(constraints: BoxConstraints(maxWidth: 320))` |
| `SizedBox(width: 240, child: Text(...))` | `Flexible(child: Text(...))` یا `Expanded` |
| `Container(height: 200, child: متن)` | حذف ارتفاع؛ بگذار محتوا ارتفاع بسازد |
| `SizedBox(width: 100, child: دکمه)` | حداقل `minWidth` با `ConstrainedBox`، نه عرض قطعی |

**قاعدهٔ تفکیک:** `SizedBox` با عرض یا ارتفاع ثابت **برای فاصله** کاملاً درست است (`SizedBox(height: RitmoSpacing.md)`). مشکل فقط وقتی است که `child` داشته باشد و `child` متن یا محتوای پویا باشد.

### R-61 — صفحهٔ اسپلش

فایل: `lib/features/onboarding/presentation/splash_screen.dart`

کد موجود:
```dart
Positioned(
  top: MediaQuery.of(context).size.height * 0.4 + dy2,
  left: -90 + dx1,
  child: Container(width: 280, ...),
)
```

**سه مشکل مستقل در سه خط:**
۱. `left: -90` — عدد جادویی منفی. عنصر عمداً از لبه بیرون می‌زند (اثر تزئینی). در عرض ۳۲۰ یعنی ۲۸ درصد عرض صفحه بیرون است؛ در ۴۳۰ ۲۱ درصد. اکثر درجهٔ اثر بین دستگاه‌ها فرق می‌کند.
۲. `width: 280` ثابت — در عرض ۳۲۰ ۸۸ درصد عرض صفحه، در عرض ۴۳۰ ۶۵ درصد.
۳. ترکیب `size.height * 0.4` (نسبی) با `-90` و `280` (مطلق) — نمی‌توان بینی روی چه دستگاهی چه می‌شود.

**اما یک نکتهٔ مهم:** این یک اثر تزئینی است و درون `Stack` قرار دارد — **`Stack` سرریز دادن را خطا نمی‌داند، پس خطای `overflowed` تولید نمی‌شود و تست هم نمی‌گیردش.** پس مشکل اینجا باگ فنی نیست — باگ بصری است.

**اصلاح:** هر سه عدد را نسبی کن تا اثر در همهٔ دستگاه‌ها یکسان دیده شود:
```dart
LayoutBuilder(
  builder: (context, constraints) {
    final w = constraints.maxWidth;
    final h = constraints.maxHeight;
    return Positioned(
      top: h * 0.4 + dy2,
      left: -w * 0.28 + dx1,      // به جای -90
      child: Container(width: w * 0.72, ...),  // به جای 280
    );
  },
)
```
ضرایب `0.28` و `0.72` را طوری انتخاب کردم که در عرض ۳۹۰ (دستگاه مرجع طراحی) معادل تقریبی عدد فعلی باشد. **بررسی بصری روی هر چهار دستگاه الزامی است** — این اولین چیزی است که کاربر می‌بیند.

### R-62 — نوار پیشرفت ورود ورزش تکمیلی

فایل: `lib/features/supplementary_sports/presentation/ss_onboarding_flow.dart`

کد موجود:
```dart
Positioned(
  left: (MediaQuery.of(context).size.width - 92) * percent.clamp(0.02, 0.95),
  top: -6,
  child: Container(width: 24, ...),
)
```

**عدد `92` یک عدد جادویی مرکب است** — احتمالاً جمع پد دو طرف به‌علاوهٔ عرض نشانگر (`24`) به‌علاوهٔ چیزی دیگر. ولی:

**دو خطای قطعی:**
۱. `MediaQuery.of(context).size.width` **عرض کل صفحه** است، ولی این نوار درون یک کارت با پد خودش است. پس عدد پایه غلط است و نشانگر در درصدهای بالا از کارت بیرون می‌زند.
۲. `92` ثابت است ولی پد کارت ممکن است در دستگاه‌های مختلف فرق کند (مخصوصاً اگر `SafeArea` در میان باشد).

**اصلاح — عدد جادویی به کلی حذف می‌شود:**
```dart
const indicatorWidth = 24.0;
LayoutBuilder(
  builder: (context, constraints) {
    // constraints.maxWidth عرض واقعی نوار است، نه عرض صفحه
    final travel = math.max(0.0, constraints.maxWidth - indicatorWidth);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _track(),
        Positioned(
          left: travel * percent.clamp(0.0, 1.0),
          top: -6,
          child: SizedBox(width: indicatorWidth, ...),
        ),
      ],
    );
  },
)
```

**دو تغییر مهم در این اصلاح:**
- `math.max(0.0, ...)` اضافه شد تا اگر عرض نوار کمتر از عرض نشانگر شد (در دستگاه فوق‌العاده باریک)، مقدار منفی تولید نشود.
- `clamp(0.02, 0.95)` به `clamp(0.0, 1.0)` تغییر کرد. مقادیر `0.02` و `0.95` دقیقاً چسب زخم بودند برای همان عدد پایهٔ غلط. وقتی عدد پایه درست شد، چسب زخم باید برود — وگرنه نوار هرگز به ۱۰۰ درصد نمی‌رسد و کاربر فکر می‌کند ورود تمام نشده.

**توجه:** این فایل ممکن است در ادغام ورزش تکمیلی جابجا شده باشد. با `rg` پیدایش کن. اگر حذف شده، `منتفی شد` علامت بزن. ویجت مشابهٔ `lib/features/supplementary_sports/presentation/widgets/shared/onboarding_progress_bar.dart` را هم چک کن — **توجه: این فایل پایان‌خط CRLF دارد.** هنگام ویرایش، سبک پایان‌خط موجود را حفظ کن وگرنه دیف کل فایل را تغییریافته نشان می‌دهد و بازبینی غیرممکن می‌شود.

### R-63 — صفحهٔ تحلیل حرکت

فایل: `lib/features/supplementary_sports/movement/presentation/movement_analytics_screen.dart`

کد موجود: `width: (MediaQuery.of(context).size.width - 44) / 2`

**این دقیقاً همان محاسبه‌ای است که `kpi_grid.dart` درست انجام می‌دهد — ولی اینجا غلط انجام شده.** مقایسه کن:

```dart
// غلط — movement_analytics_screen.dart
width: (MediaQuery.of(context).size.width - 44) / 2

// درست — kpi_grid.dart (در همین مخزن!)
LayoutBuilder(builder: (context, constraints) {
  final itemWidth = (constraints.maxWidth - RitmoSpacing.md) / 2;
  ...
})
```

**دو تفاوت قطعی:** نسخهٔ درست از `constraints.maxWidth` (عرض واقعی ناحیه) و `RitmoSpacing.md` (ثابت نام‌دار) استفاده می‌کند؛ نسخهٔ غلط از عرض صفحه و عدد `44`.

**اصلاح: عیناً الگوی `kpi_grid.dart` را بگیر.** بهتر از آن: اگر محتوا مشابه است، مستقیماً `RitmoAdaptiveGrid` را به کار ببر. **این یافته مدرک زندهٔ ریشهٔ ششم است: الگوی درست در مخزن وجود دارد ولی دو فایل آن‌طرف‌تر ازش استفاده نمی‌شود.**

### R-64 — شیت ارتقای پرمیوم (لایهٔ تزئینی)

فایل: `lib/features/premium/presentation/premium_upgrade_sheet.dart`

در `R-27` متغیر `final size = MediaQuery.of(context).size` را دسته‌بندی کردیم: ارتفاع شیت → اسکفولد؛ عرض کارت → `LayoutBuilder`؛ **لایهٔ تزئینی `Stack` → همین یافته.**

برای لایهٔ تزئینی، قاعده ساده است: از `FractionallySizedBox` یا ضریبی از `constraints` استفاده کن، و `clipBehavior: Clip.none` بگذار تا افکت بریده نشود.

**ولی مهم‌تر از خود اصلاح:** این صفحه درآمدزاست. **پس از اصلاح، بررسی بصری روی هر چهار دستگاه و هر سه مقیاس متن الزامی است**، و نتیجه را در سند پیشرفت با جملهٔ صریح «دکمهٔ خرید در هر ۱۲ حالت کامل دیده و قابل لمس است» ثبت کن. اگر نمی‌توانی بصری بررسی کنی، دست‌کم تستی بنویس که مستطیل دکمهٔ خرید را با `tester.getRect` می‌گیرد و درون محدودهٔ صفحه بودنش را تأیید می‌کند.

### R-65 — قاعدهٔ عمومی `Stack` و `Positioned`

**اول بشمار:**
```
rg -n "Positioned\\(" lib/ -c
rg -n "Positioned\\(" lib/ -l
```

**چرا `Stack` خطرناک‌تر از `Row` است:** `Row` وقتی سرریز می‌دهد، خطای `RenderFlex overflowed` می‌دهد و تست می‌گیردش. **`Stack` هیچ خطایی نمی‌دهد — فقط محتوا را بی‌صدا می‌برد یا بیرون می‌زند.** پس هیچ‌کدام از تست‌های `expectNoOverflow` این دسته را نمی‌گیرند.

**برای این دسته باید نوع دیگری تست بنویسی — تست محدوده:**
```dart
// مطمئن می‌شود عنصر درون محدودهٔ والد مانده است.
// برای Stack لازم است چون Stack خطای overflowed تولید نمی‌کند.
void expectWithinBounds(
  WidgetTester tester,
  Finder child,
  Finder parent, {
  required String label,
  double tolerance = 0.5,
}) {
  final c = tester.getRect(child);
  final p = tester.getRect(parent);
  expect(c.left, greaterThanOrEqualTo(p.left - tolerance), reason: '$label از چپ بیرون زد');
  expect(c.right, lessThanOrEqualTo(p.right + tolerance), reason: '$label از راست بیرون زد');
  expect(c.top, greaterThanOrEqualTo(p.top - tolerance), reason: '$label از بالا بیرون زد');
  expect(c.bottom, lessThanOrEqualTo(p.bottom + tolerance), reason: '$label از پایین بیرون زد');
}
```
این تابع را به `test/support/responsive_harness.dart` اضافه کن (کنار `expectNoOverflow` از `R-07`).

**سه قاعده برای هر `Positioned` در برنامه:**
۱. هر عدد `left`، `right`، `top`، `bottom` باید یا از `RitmoSpacing` بیاید، یا ضریبی از `constraints` باشد، یا کامنتی داشته باشد که می‌گوید چرا مطلق است.
۲. اگر `Positioned` متن دارد، باید `width` یا `right` داشته باشد تا متن قید شود. `Positioned(left: x, child: Text(...))` بدون قید عرض، متن را تا بینهایت کشش می‌دهد.
۳. اگر افکت عمداً بیرون می‌زند، `Stack` باید `clipBehavior` صریح داشته باشد — `Clip.none` اگر می‌خواهی دیده شود، `Clip.hardEdge` اگر می‌خواهی بریده شود. پیش‌فرض را رها نکن.

### R-66 — دیالوگ‌ها

دیالوگ‌ها در فاز ۱ پوشش داده نشدند چون `showDialog` می‌زنند نه `showModalBottomSheet`.

**روش شمارش:**
```
rg -n "showDialog|AlertDialog|SimpleDialog|Dialog\\(" lib/ -l
```

**دو مشکل رایج دیالوگ در گوشی کوتاه:**
۱. `AlertDialog` با `content` بلند در گوشی `short` با مقیاس متن ۱٫۶ سرریز می‌دهد. **اصلاح: `content` را در `SingleChildScrollView` بگذار.** این تقریباً همیشه لازم است و هیچ ضرری ندارد.
۲. `actions` با دو دکمهٔ فارسی بلند در یک `Row` سرریز می‌دهد. **اصلاح: `AlertDialog` خودش `OverflowBar` دارد که در عرض کم به ستون می‌ریزد — ولی فقط اگر دکمه‌ها را درون `Row` دستی نپیچیده باشی.** اگر جایی `actions: [Row(children: [...])]` دیدی، `Row` را حذف کن و دکمه‌ها را مستقیماً در `actions` بگذار.

**قاعدهٔ قطعی:** دیالوگ باید در `320×568` با مقیاس `1.6` کامل قابل استفاده باشد — عنوان خوانا، محتوا اسکرول‌شونده، و **هر دو دکمه دیده و قابل لمس**. دکمهٔ تأییدی که دیده نمی‌شود یعنی کاربر در برنامه گیر می‌کند.

### R-67 — آیکون‌ها و هدف لمس

آیکون با `size:` ثابت مشکلی ندارد — آیکون متن نیست و لازم نیست با مقیاس متن بزرگ شود.

**ولی دو چیز را باید تأیید کنی:**
۱. هر آیکونِ **قابل لمس** باید ناحیهٔ لمس دست‌کم `RitmoBreakpoints.minTouchTarget` (۴۸) داشته باشد. `IconButton` پیش‌فرض ۴۸ می‌دهد، ولی `GestureDetector(child: Icon(size: 16))` فقط ۱۶ می‌دهد. **این یک باگ واقعی دسترسی‌پذیری است که در گوشی‌های با چگالی بالا بدتر می‌شود.**
۲. ردیف آیکون و متن: وقتی مقیاس متن بالا می‌رود، متن بزرگ می‌شود ولی آیکون نه — نتیجه بصری نامتوازن ولی بدون سرریز. این مشکل طراحی است و دامنهٔ این کار نیست. **ثبت کن، دست نزن.**

**روش شمارش مورد ۱:**
```
rg -n "GestureDetector|InkWell" lib/ -l
```
برای هر فایل، چک کن فرزندِ لمسی دست‌کم ۴۸ پیکسل ناحیه دارد. اگر ندارد، با `Padding` یا `SizedBox(width: 48, height: 48)` دورش بزن — **این تنها جایی است که `SizedBox` با عدد ثابت در این فاز مجاز است**، و عدد باید از `RitmoBreakpoints.minTouchTarget` بیاید نه عدد خام.

### R-68 — پدینگ و فاصله‌های خام

**روش شمارش:**
```
rg -n "EdgeInsets.all\\([0-9]" lib/ | wc -l
rg -n "SizedBox\\(height: [0-9]+\\.?[0-9]*\\)" lib/ | wc -l
```

این موارد معمولاً سرریز نمی‌دهند، ولی یک مشکل واقعی دارند: **وقتی فاصله‌ها با مقیاس متن رشد نمی‌کنند، در مقیاس ۱٫۶ متن‌ها به هم می‌چسبند و صفحه خواناناپذیر می‌شود.**

**اما این یافته دامنهٔ محدودی دارد. دقیقاً این دو کار را بکن و بیشتر نه:**
۱. هر عدد خامی که دقیقاً معادل یکی از مقادیر `RitmoSpacing` است، با همان ثابت جایگزین کن. تغییر رفتاری صفر است و خوانایی بالا می‌رود.
۲. مقادیری که معادل ندارند، **دست نزن.** فقط در سند پیشرفت فهرستشان را بنویس با عنوان «بدهی فنی فاصله‌گذاری — کار جداگانه».

**ممنوع مطلق: وابسته کردن فاصله‌ها به مقیاس متن.** فلاتر این کار را نمی‌کند و نباید بکنیم — نتیجه طرحی می‌شود که در مقیاس بالا بی‌دلیل توخالی است. مقیاس متن فقط متن را بزرگ می‌کند؛ چیدمان باید فقط انعطاف داشته باشد.

### R-69 — تصاویر و رسانه

**قاعده:** هر `Image` در برنامه باید یکی از این دو را داشته باشد: یا `AspectRatio` دورش باشد، یا `height` و `fit: BoxFit.cover` داشته باشد. تصویری بدون قید، ارتفاع ذاتی خود را تحمیل می‌کند که می‌تواند هزار پیکسل باشد.

**ماژول هدف اصلی:** `lib/features/supplementary_sports/` — ماژولی است که تصویر حرکت‌ها دارد. در `R-43` هم این را لمس کردیم.

**دو مورد دیگر که باید تأیید شوند (هر دو الان درست‌اند، فقط تأیید کن):**
- `lib/features/worship/presentation/widgets/prayer_arc_hero.dart` — `aspectRatio: 1.0` دارد. درست. `منتفی شد`.
- `lib/features/onboarding/presentation/steps/step_day_arc.dart` — `SizedBox(height: 200)` به‌علاوهٔ `math.min(maxWidth, maxHeight)`. منطق `min` درست است؛ فقط چک کن در `RitmoHeightClass.short` ۲۰۰ پیکسل با متن ورود بالایش جا می‌شود. اگر نمی‌شود، ۲۰۰ را به `math.min(200.0, usableHeight * 0.3)` تبدیل کن.

### R-70 — تست‌های محافظ فاز ۴ و گاردهای جست‌وجویی

فایل جدید: `test/core/theme/no_magic_numbers_test.dart`

**این یک تست متنی است، نه ویجتی.** فایل‌های `lib/` را می‌خواند و الگوهای ممنوع را رد می‌کند. الگوی این نوع تست در مخزن موجود است: `test/prompt_036_source_guards_test.dart` و `test/cycle/cycle_source_guards_test.dart`. **همان الگو را بخوان و دقیقاً تقلید کن** — الگوی خودت را نساز.

چهار گارد اجباری در این تست:
۱. هیچ فایلی در `lib/core/widgets/` یا `lib/core/theme/tokens/` نباید `fontSize:` داشته باشد.
۲. هیچ فایلی در `lib/` نباید `height: MediaQuery.of(context).size.height` داشته باشد.
۳. هیچ فایلی جز `ritmo_sheet_scaffold.dart` و `lib/core/widgets/sheet/` نباید `showModalBottomSheet` صدا بزند.
۴. هیچ فایلی نباید `childAspectRatio` داشته باشد جز در `RitmoAdaptiveGrid` و سه تقویم `R-32`.

**چرا تست متنی و نه فقط دستور `rg` در دروازه؟** چون دروازه یک‌بار اجرا می‌شود و تمام؛ تست در CI هر بار اجرا می‌شود و مانع بازگشت مشکل می‌شود. **بدون این تست، همهٔ کار این پرامپت در سه ماه برمی‌گردد.**

فایل دوم: `test/features/stack_bounds_test.dart` — برای `R-61`، `R-62`، `R-63`، `R-64` با `expectWithinBounds` از `R-65`.

### 🚦 دروازهٔ پذیرش فاز ۴

- [ ] `flutter analyze` — صفر خطا، صفر اخطار.
- [ ] `flutter test` — کامل سبز.
- [ ] `rg -n "fontSize:" lib/ | wc -l` — دست‌کم ۷۰ درصد کمتر از عدد مرجع. عدد قبل و بعد در پیام کامیت.
- [ ] `rg -n "fontSize:" lib/core/widgets lib/core/theme/tokens` — خالی.
- [ ] `rg -n "width: 320" lib/` — خالی.
- [ ] `flutter test test/core/theme/no_magic_numbers_test.dart` — هر چهار گارد سبز.
- [ ] `flutter test test/features/stack_bounds_test.dart` — سبز.
- [ ] هر `Positioned` باقی‌مانده با عدد مطلق، کامنتی دارد که دلیلش را می‌گوید.
- [ ] بررسی بصری صفحهٔ اسپلش و شیت پرمیوم روی هر چهار دستگاه انجام شد و نتیجه در سند پیشرفت ثبت شد.
- [ ] هر ۱۲ یافتهٔ `R-59` تا `R-70` حالت پایانی دارد.

**کامیت:** `fix(ui): phase 4 — حذف اعداد جادویی و مهار Stack [R-59 … R-70]`

---

## فاز ۵ — صفحه‌کلید، `SafeArea` و جهت‌گیری (`R-71` … `R-80`)

تا اینجا عرض و محتوا را درست کردیم. این فاز چیزی را درست می‌کند که در شبیه‌ساز هرگز دیده نمی‌شود ولی کاربر واقعی هر روز می‌بیند: **فضای قابل‌استفادهٔ واقعی دستگاه.**

### R-71 — قرارداد صفحه‌کلید

**مسئلهٔ بنیادین:** وقتی صفحه‌کلید بالا می‌آید، ارتفاع قابل‌استفاده تا **۴۵ درصد** کم می‌شود. در یک گوشی `320×568`، صفحه‌کلید فارسی حدود ۲۶۰ پیکسل می‌گیرد — یعنی فقط **حدود ۲۵۰ پیکسل** باقی می‌ماند. هر شیتی که ارتفاعش را از ارتفاع کل صفحه می‌گیرد، در این حالت قطعاً می‌شکند.

**سه لایهٔ دفاعی که هر سه لازم‌اند:**

**لایهٔ ۱ — پد پایین برابر `viewInsets.bottom`.** این محتوا را بالای صفحه‌کلید هل می‌دهد. `RitmoSheetScaffold` الان این را دارد — پس هر شیتی که در فاز ۱ منتقل شد، این لایه را مجانی گرفت.

**لایهٔ ۲ — سقف ارتفاع بر اساس ارتفاع قابل‌استفاده.** تابع `RitmoBreakpoints.usableHeight(context)` از `R-01` دقیقاً برای این ساخته شد: `size.height - padding.top - padding.bottom - viewInsets.bottom`. **این تفریق چهارم (`viewInsets.bottom`) دقیقاً چیزی است که در کل مخزن وجود نداشت.**

**لایهٔ ۳ — محتوای اسکرول‌شونده.** حتی با دو لایهٔ قبلی، اگر محتوا در ۲۵۰ پیکسل جا نشود باید قابل اسکرول باشد.

**مدرک اینکه لایهٔ ۲ وجود ندارد:** در هر ۳۹ محل `MediaQuery.of(context).size` که در فاز ۱ فهرست شد، حتی یک مورد هم `viewInsets` را کم نمی‌کرد. در فاز ۱ همه را به `sheetMaxHeight` منتقل کردیم که این کار را می‌کند. **پس در این فاز فقط باید تأیید کنی و مواردی که فاز ۱ پوشش نداد را پیدا کنی.**

**روش شمارش موارد پوشش‌نداده‌شده:**
```
rg -n "TextField|TextFormField" lib/ -l
```
برای هر فایل در این فهرست که **شیت نیست** (یعنی صفحهٔ کامل یا دیالوگ است)، چک کن محتوا درون `SingleChildScrollView` یا `ListView` است. اگر `Column` خالی است، **قطعاً با صفحه‌کلید باز سرریز می‌دهد.**

### R-72 — فرم‌های چندفیلدی

بدترین حالت ممکن: فرمی با پنج فیلد، در گوشی `320×568`، با مقیاس متن `1.6`، با صفحه‌کلید باز. ارتفاع قابل‌استفاده حدود ۲۵۰ پیکسل و هر فیلد با برچسب در مقیاس `1.6` حدود ۹۰ پیکسل. **پنج فیلد ۴۵۰ پیکسل می‌خواهد در ۲۵۰ پیکسل فضا.**

**فایل‌های هدف (همه در فاز ۱ لمس شدند — حالا با صفحه‌کلید تست کن):**
- `lib/features/courses/presentation/widgets/create_course_sheet.dart` (`R-21` — فرم چندفیلدی، بالاترین اولویت)
- `lib/features/assistant/presentation/widgets/unified_assistant_sheet.dart` (`R-14`)
- `lib/features/worship/presentation/widgets/prayer_city_picker.dart` (`R-23` — فیلد جست‌وجو به‌علاوهٔ فهرست بلند)
- `lib/features/supplementary_sports/movement/presentation/movement_log_sheet.dart` (`R-29` — صفحه‌کلید عددی)
- `lib/features/routines/presentation/universal_planner_sheet.dart` (`R-22`)

**سه قاعدهٔ اجباری برای هر فرم:**
۱. محتوا اسکرول‌شونده (در `RitmoSheetScaffold` مجانی است).
۲. دکمهٔ ثبت در `footer` باشد، نه انتهای محتوای اسکرول‌شونده. **دقیقاً دلیل وجود `footer` در `R-03` همین است:** کاربر باید بدون بستن صفحه‌کلید دکمه را ببیند. اگر دکمه در انتهای لیست باشد، کاربر در گوشی کوتاه فکر می‌کند دکمه‌ای وجود ندارد.
۳. فیلد فعال باید خودکار به دید بیاید. اگر جایی این رفتار نیست، به `TextField` مربوطه `scrollPadding` یا `Scrollable.ensureVisible` اضافه کن.

### R-73 — صفحهٔ گفتگو و دستیار با صفحه‌کلید

فایل: `lib/features/chat/presentation/ai_chat_screen.dart` (۶۷ کیلوبایت — بزرگ‌ترین صفحهٔ مخزن)

صفحهٔ گفتگو منحصربه‌فرد است چون صفحه‌کلید تقریباً همیشه باز است. چهار چیز را تأیید کن:
۱. فهرست پیام‌ها با بالا آمدن صفحه‌کلید کوتاه می‌شود و آخرین پیام همچنان دیده می‌شود؟
۲. ناحیهٔ ورودی متن با متن چندخطی بزرگ می‌شود ولی سقف دارد؟ **بدون سقف، کاربری که پنج خط می‌نویسد کل صفحه را اشغال می‌کند.** سقف پیشنهادی: `maxLines: 5` به‌علاوهٔ `ConstrainedBox(maxHeight: usableHeight * 0.3)`.
۳. دکمهٔ ارسال در کنار ورودی، وقتی ورودی چندخطی می‌شود، کجا می‌رود؟ باید `CrossAxisAlignment.end` باشد تا پایین بماند.
۴. `R-17` حبابه‌های پیام را به `constraints.maxWidth` منتقل کرد. **تأیید کن که حباب پیامِ طولانی، در عرض ۳۲۰ با مقیاس ۱٫۶، هم از لبه بیرون نمی‌زند و هم خوانا می‌ماند.**

**یک مورد خاص و مهم:** ماژول دستیار یک وب‌ویو مخفی دارد (`chatgpt_mini_preview.dart`، `chatgpt_auth_modal.dart`). در `R-18` این دو را به `RitmoFullBleedSheet` منتقل کردیم. **وب‌ویو صفحه‌کلید خودش را دارد و `viewInsets` را متفاوت مدیریت می‌کند.** اگر پس از فاز ۱ ورود کاربر در مودال احراز هویت خراب شد، برگرد و `RitmoFullBleedSheet` را طوری اصلاح کن که برای وب‌ویو `viewInsets` را دوباره اعمال نکند. **این یک دام واقعی است: دو بار اعمال `viewInsets` باعث می‌شود محتوا دو برابر بالا بپرد.**

### R-74 — `SafeArea`: ناحیهٔ ناقص و نوار خانه

**دو مشکل واقعی و قابل دیدن:**
۱. **بالا:** در گوشی با ناحیهٔ ناقص (نُچ) یا دوربین حفره‌ای، محتوای بدون `SafeArea` زیر آن می‌رود.
۲. **پایین:** در گوشی‌های بدون دکمهٔ خانه، نوار اشاره‌ای حدود ۳۴ پیکسل می‌گیرد. دکمهٔ چسبیده به پایین زیر آن می‌رود و **قابل لمس نیست** — سیستم‌عامل لمس را می‌قاپد.

**مورد ۲ یک باگ عملکردی است، نه بصری.** دکمه‌ای که قابل لمس نیست یعنی قابلیت مرده.

**روش شمارش:**
```
rg -n "SafeArea" lib/ -c
rg -n "SafeArea" lib/ -l | wc -l
```
عدد را با شمار صفحه‌های سطح بالا مقایسه کن (`rg -n "class \\w+Screen extends" lib/ | wc -l`). اگر شمار `SafeArea` به طور محسوسی کمتر است، فهرست صفحه‌های بدون پوشش را دربیاور و در سند پیشرفت بنویس.

**قاعدهٔ قطعی:**
- هر صفحهٔ سطح بالا باید `SafeArea` داشته باشد یا `Scaffold` با `AppBar` داشته باشد (`AppBar` خودش بالا را حل می‌کند).
- هر عنصر چسبیده به پایین (دکمهٔ شناور، نوار اقدام، پانویس شیت) باید `SafeArea(top: false)` داشته باشد. **`R-03` این را برای `footer` شیت‌ها انجام داد — حالا برای بقیه بررسی کن.**
- `SafeArea` توی توی ممنوع است. دو `SafeArea` توی هم باعث پد دوبرابر نمی‌شود (فلاتر `MediaQuery` را مصرف می‌کند) ولی کد را گیج‌کننده می‌کند. اگر دیدی، درونی را حذف کن.

### R-75 — گوشی‌های کوتاه

`RitmoHeightClass.short` یعنی ارتفاع تا ۶۳۹ پیکسل. این گوشی‌ها واقعی‌اند و در ایران کم نیستند.

**چهار موردی که در گوشی کوتاه قطعاً می‌شکنند و باید تک‌تک تأیید شوند:**
۱. **حالت‌های خالی** — در `R-56` پوشش داده شد. فقط تأیید کن.
۲. **مراحل ورود (آن‌بوردینگ)** — `lib/features/onboarding/presentation/onboarding_screen.dart` و `steps/`. مرحلهٔ ورود معمولاً تصویر بزرگ + عنوان + توضیح + دکمه دارد. در ۵۶۸ پیکسل با مقیاس `1.6` حتماً می‌شکند. **اگر کاربر در مرحلهٔ ورود گیر کند، کل برنامه را از دست دادیم. بالاترین اولویت فاز ۵.**
۳. **دیالوگ‌ها** — در `R-66` پوشش داده شد.
۴. **شیت‌های با ضریب `0.9`** — در گوشی ۵۶۸ پیکسلی، `0.9` یعنی ۵۱۱ پیکسل ولی `usableHeight` حدود ۵۲۰ است — یعنی شیت تقریباً کل صفحه را می‌گیرد. این مشکل فنی نیست (چون `sheetMaxHeight` درست کار می‌کند) ولی تجربهٔ بدی است. **ثبت کن، دست نزن** — تصمیم محصولی است که آیا این شیت‌ها باید صفحهٔ کامل شوند (در `R-22` هم همین را گفتم).

### R-76 — جهت‌گیری افقی

**اول این را روشن کن:** برنامه جهت‌گیری را قفل کرده یا نه؟
```
rg -n "SystemChrome.setPreferredOrientations|DeviceOrientation" lib/
```

**اگر قفل شده (فقط عمودی):** این یافته `منتفی شد` است. خروجی دستور را در سند پیشرفت بنویس و برو. **وقت تلف نکن.**

**اگر قفل نشده، دو کار داری — و ترتیبش مهم است:**

**کار ۱ — تصمیم بگیر و ثبت کن.** ریتمو یک برنامهٔ عمودی است: تقویم، فهرست، فرم. **پشتیبانی کامل از افقی دامنهٔ این پرامپت نیست** — پروژهٔ جداگانه‌ای است و باید تصمیم محصولی باشد.

**کار ۲ — حداقل کاری که باید بکنی:** مطمئن شو در افقی **هیچ صفحه‌ای گیر نمی‌کند و هیچ داده‌ای گم نمی‌شود.** زیبا بودن لازم نیست؛ قابل استفاده بودن لازم است. عملاً یعنی: هر صفحه باید در `Size(844, 390)` (افقیِ دستگاه مرجع) قابل اسکرول و بدون سرریز باشد. **این تقریباً مجانی حاصل می‌شود** اگر فازهای ۰ تا ۴ درست انجام شده باشند — چون افقی فقط یک حالت عرض‌زیاد/ارتفاع‌کم است که `RitmoWidthClass.expanded` و `RitmoHeightClass.short` پوششش می‌دهند.

**دو حالت افقی را به `kRitmoTestViewports` اضافه کن:**
```dart
'landscape': Size(844, 390),
'landscape-compact': Size(568, 320),
```
ولی **این دو را فقط در تست‌های فاز ۵ به کار ببر، نه در `testAcrossViewports` عمومی.** وگرنه همهٔ تست‌های فازهای قبلی ۲۴ حالته می‌شوند و اجرایشان بی‌دلیل کند می‌شود.

### R-77 — مرحلهٔ دوم `R-08`: بالا بردن سقف مقیاس متن به ۱٫۶

**این یافته تنها کاری است که در این پرامپت عمداً به تأخیر انداختیم. الان وقتش است.**

در `R-08` در فاز ۰، `lib/main.dart` را به این شکل درآوردیم:
```dart
textScaler: mq.textScaler.clamp(
  minScaleFactor: RitmoBreakpoints.supportedMinTextScale,   // 0.9
  maxScaleFactor: RitmoBreakpoints.supportedMaxTextScale,   // در فاز ۰ مقدار 1.3 ماند
),
```

**حالا دقیقاً این دو خط را عوض کن:**
```dart
// در lib/core/theme/tokens/ritmo_breakpoints.dart
static const double supportedMaxTextScale = 1.6;   // بود: 1.3
```

**مراحل اجباری پس از تغییر — دقیقاً به این ترتیب:**
۱. `flutter test` کامل را اجرا کن. هر تستی که قرمز شد، یک سرریز واقعی است که چسب زخم پنهانش کرده بود.
۲. هر قرمزی را درست کن. **ممنوع مطلق: برگرداندن عدد به `1.3` به دلیل قرمز شدن تست.** اگر تعداد قرمزی‌ها زیاد است، فهرستشان را در سند پیشرفت بنویس و یکی‌یکی حل کن.
۳. پس از سبز شدن کامل، بررسی بصری دست‌کم شش صفحهٔ پرکاربرد (امروز، تقویم، حرکت مرکزی، دوره‌ها، چرخه، تنطیمات) در مقیاس ۱٫۶.

**دقیقاً چرا تا اینجا صبر کردیم:** اگر در فاز ۰ سقف را بالا می‌بردیم، در تمام فازهای ۱ تا ۴ برنامه برای کاربر واقعی **بدتر** می‌شد: متن بزرگ ولی چیدمان هنوز خراب. الان که شیت‌ها، گریدها، ردیف‌ها و اعداد ثابت درست شده‌اند، بالا بردن سقف برنامه را **بهتر** می‌کند.

**معیار موفقیت قطعی این یافته:** کاربری که در تنطیمات سیستم‌عامل اندازهٔ قلم را تا آخر بالا برده، باید بتواند از برنامه کامل استفاده کند و متن واقعاً بزرگ‌تر ببیند. **این دقیقاً همان قابلیتی است که امروز در برنامه مرده است.**

### R-78 — دسترسی‌پذیری در چیدمان

دو پرچم دسترسی‌پذیری فلاتر که بر چیدمان اثر می‌گذارند:

**۱ — `MediaQuery.accessibleNavigationOf(context)`.** وقتی کاربر صفحه‌خوان دارد. الان در مخزن **یک جا** درست استفاده می‌شود: `lib/features/movement/presentation/common/undo_toast.dart` می‌گوید `isAccessible = textScale > 1.2 || MediaQuery.accessibleNavigationOf(context)` و مدت نمایش را از ۶ به ۱۰ ثانیه می‌برد. **این کد عالی است. دستش نزن.**

کار تو: هر جایی که پیامی خودکار محو می‌شود (توست، اسنک‌بار، بنر موقت)، همین الگو را اعمال کن. فهرست: `rg -n "SnackBar|showToast|ritmo_toast" lib/ -l`.

**۲ — `MediaQuery.boldTextOf(context)`.** وقتی کاربر در تنطیمات سیستم «متن ضخیم» را روشن کرده. **متن ضخیم پهن‌تر است — در فارسی تا حدود ۸ درصد.** پس چیدمانی که در مقیاس `1.6` دقیقاً جا می‌شود، با متن ضخیم می‌شکند.

**تمرکز محدود ولی قطعی:** در تست‌های فاز ۶، دست‌کم **یک حالت متن ضخیم** اضافه کن (`MediaQueryData(boldText: true, textScaler: TextScaler.linear(1.6), size: Size(320, 568))`) و روی ویجت‌های مشترک `R-58` اجرا کن. **این بدترین حالت ممکن در کل پرامپت است.** لازم نیست همه جا را پوشش بدهی — ویجت‌های مشترک کافی است.

### R-79 — چیدمان راست‌به‌چپ در عرض‌های مختلف

برنامه کاملاً راست‌به‌چپ است. سه الگوی مشکل‌ساز که فقط در عرض کم ظاهر می‌شوند:

**۱ — `EdgeInsets.only(left:)` یا `right:` به جای `EdgeInsetsDirectional`.** در عرض زیاد کسی متوجه نمی‌شود؛ در عرض کم پد در سمت غلط باعث می‌شود متن به لبهٔ راست بچسبد.
```
rg -n "EdgeInsets.only\\((left|right):" lib/ | wc -l
```
مواردی را که بر متن اثر دارند به `EdgeInsetsDirectional.only(start:)` / `end:` تبدیل کن. مواردی که تزئینی‌اند را رها کن.

**۲ — `Alignment.centerLeft` به جای `AlignmentDirectional.centerStart`.** همین منطق.

**۳ — بریدن متن در راست‌به‌چپ:** `TextOverflow.ellipsis` در فارسی سه نقطه را سمت **چپ** می‌گذارد (انتهای متن). این درست است. ولی اگر متن مخلوط فارسی و لاتین باشد (مانند نام دورهٔ انگلیسی)، نتیجه می‌تواند گیج‌کننده باشد. **ثبت کن، دست نزن** — دودوجهتی متن موضوع جداگانه‌ای است.

**توجه مهم:** هر تست این پرامپت باید `Directionality(textDirection: TextDirection.rtl)` داشته باشد. تابع `wrapResponsive` از `R-07` این را اجباری کرد. **اگر تستی بدون راست‌به‌چپ اجرا شود، نتیجه‌اش بی‌ارزش است** چون عرض متن فارسی و جایِ سرریز فرق می‌کند.

### R-80 — تست‌های محافظ فاز ۵

دو فایل جدید:

**۱ — `test/core/widgets/keyboard_insets_test.dart`**
برای هر پنج فایل `R-72`، دو حالت بساز: با `viewInsets: EdgeInsets.zero` و با `viewInsets: EdgeInsets.only(bottom: 300)`. در هر دو:
- سرریز نباشد؛
- دکمهٔ ثبت درون محدودهٔ صفحه باشد (با `expectWithinBounds` از `R-65`)؛
- فیلد اول قابل دیدن باشد.

**مهم‌ترین حالت تست کل فاز ۵:** `Size(320, 568)` با `textScaler: 1.6` و `viewInsets.bottom: 300`. این ترکیب فقط **۱۰۸ پیکسل** ارتفاع قابل‌استفاده می‌دهد (۵۶۸ منهای پد بالا و پایین منهای ۳۰۰). در این حالت هیچ فرمی کامل دیده نمی‌شود — **ولی باید قابل اسکرول باشد و دکمه دیده شود. همین معیار قبولی است.**

**۲ — `test/core/widgets/safe_area_test.dart`**
دو حالت `padding` بساز: گوشی بدون نُچ (`EdgeInsets.only(top: 24, bottom: 0)`) و گوشی با نُچ و نوار اشاره‌ای (`EdgeInsets.only(top: 47, bottom: 34)`). مقادیر واقعی دستگاه‌های رایج‌اند. تست کن هر عنصر تعاملی چسبیده به پایین، بالای `padding.bottom` مانده.

**مقدار `34` را به `kRitmoTestPaddings` در هارنس اضافه کن** تا در فاز ۶ قابل استفاده باشد:
```dart
const kRitmoTestPaddings = {
  'no-notch': EdgeInsets.only(top: 24),
  'notch': EdgeInsets.only(top: 47, bottom: 34),
};
```

### 🚦 دروازهٔ پذیرش فاز ۵

- [ ] `flutter analyze` — صفر خطا، صفر اخطار.
- [ ] `flutter test` — کامل سبز **پس از بالا بردن سقف مقیاس متن به ۱٫۶**.
- [ ] `rg -n "supportedMaxTextScale = 1.6" lib/core/theme/tokens/ritmo_breakpoints.dart` — یک نتیجه.
- [ ] `rg -n "1.3" lib/main.dart` — خالی (چسب زخم قطعاً رفت).
- [ ] `flutter test test/core/widgets/keyboard_insets_test.dart` — هر پنج فرم در هر دو حالت صفحه‌کلید سبز.
- [ ] `flutter test test/core/widgets/safe_area_test.dart` — هر دو حالت پد سبز.
- [ ] مرحلهٔ ورود در `320×568` با مقیاس ۱٫۶ کامل قابل طی کردن است (بررسی بصری یا تست پایان‌به‌پایان).
- [ ] بررسی بصری شش صفحهٔ پرکاربرد در مقیاس ۱٫۶ انجام و در سند پیشرفت ثبت شد.
- [ ] تصمیم جهت‌گیری افقی (`R-76`) صریحاً در سند پیشرفت ثبت شد.
- [ ] هر ۱۰ یافتهٔ `R-71` تا `R-80` حالت پایانی دارد.

**کامیت:** `fix(ui): phase 5 — صفحه‌کلید، SafeArea و سقف مقیاس متن ۱٫۶ [R-71 … R-80]`

---

## فاز ۶ — تست‌های محافظ و دروازهٔ سرتاسری (`R-81` … `R-92`)

**این فاز تزئینی نیست. بدون آن، کار پنج فاز قبل ظرف چند ماه برمی‌گردد.** مدرک این ادعا در همین مخزن است: پرامپت‌های `C-43`، `K-89` و `B47` هر سه دقیقاً همین دستهٔ مشکل را در ماژول خودشان پیدا و حل کردند، و مشکل در ماژول بعدی دوباره متولد شد — چون هیچ گاردی وجود نداشت که جلوی تولد دوباره‌اش را بگیرد.

### R-81 — سوییپ سرتاسری: پوشش هر ۲۸ ماژول

فایل: `test/features/responsive_sweep_test.dart` (در `R-58` ایجاد شد — اینجا کامل می‌شود)

**دقیقاً همین ۲۸ ماژول را پوشش بده:**
`assistant` · `calendar` · `chat` · `courses` · `cycle` · `dev` · `energy` · `goals` · `health` · `inbox` · `konkur` · `movement` · `notes` · `onboarding` · `premium` · `profile` · `reflection` · `registry` · `routines` · `search` · `settings` · `simple_tasks` · `sleep` · `study` · `supplementary_sports` · `today` · `wellbeing` · `worship`

**قاعدهٔ پوشش — یک صفحه از هر ماژول کافی است.** هدف پوشش کامل نیست؛ هدف این است که هیچ ماژولی بدون دست‌کم یک تست سرریز نماند. صفحهٔ اصلی هر ماژول را انتخاب کن.

**مشکل واقعی که با آن مواجه می‌شوی — و راه‌حلش:** اکثر صفحه‌ها به پایگاه داده وابسته‌اند و در محیط تست خطا می‌دهند. **الگوی راه‌اندازی را دقیقاً از `test/settings/settings_text_scale_resilience_test.dart` کپی کن** — همان فایل که در `R-07` هارنس را از رویش ساختیم:

```dart
sqfliteFfiInit();
databaseFactory = databaseFactoryFfi;
// جعل کانال ذخیره‌سازی امن
const MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
DatabaseHelper.instance.overrideDatabaseForTesting(db);
SettingsService.instance.resetForTesting();
```

**اگر صفحه‌ای با وجود این راه‌اندازی بالا نیامد:** آن ماژول را با یک ویجت سطح پایین‌تر پوشش بده (مثلاً کارت اصلی داشبوردش، نه کل صفحه). **ممنوع مطلق: رها کردن یک ماژول بدون هیچ تست.** اگر ماژولی واقعاً غیرقابل تست است، در سند پیشرفت با دلیل فنی دقیق بنویس چرا — و آن دلیل باید یک پیام خطای واقعی باشد، نه حدس.

**ماژول `dev` استثناست:** اگر فقط ابزار توسعه است و در نسخهٔ انتشار دیده نمی‌شود، `منتفی شد` با ذکر دلیل.

### R-82 — ماتریس حالت‌ها: چه چیزی اجرا شود و چقدر هزینه دارد

**این یافته دربارهٔ یک تصمیم مهندسی است که اگر اشتباه بگیری، مجموعه تست‌ها آن‌قدر کند می‌شود که تیم خاموشش می‌کند — و آن‌وقت همه چیز از دست رفت.**

**حساب هزینه:** ۴ ویوپورت × ۳ مقیاس متن = ۱۲ حالت. ۲۸ ماژول × ۱۲ = **۳۳۶ اجرای ویجت** فقط برای سوییپ. با میانگین ۲۵۰ میلی‌ثانیه، حدود **۸۴ ثانیه**. این قابل قبول است.

ولی اگر هر تست هر فاز را هم ۱۲ حالته کنی، مجموعه به چند دقیقه می‌رسد. **پس این قاعدهٔ سه‌سطحی را دقیقاً رعایت کن:**

| سطح | چه تستی | چند حالت | کدام حالت‌ها |
|---|---|---|---|
| **کامل** | ویجت‌های مشترک (`R-30`، `R-44`، `R-58`) | ۱۲ | همهٔ ویوپورت‌ها × همهٔ مقیاس‌ها |
| **بدترین حالت** | سوییپ ۲۸ ماژول (`R-81`) | ۲ | `compact-short` با ۱٫۶ و `regular` با ۱٫۰ |
| **نقطه‌ای** | تست‌های تک‌یافته‌ای | ۱ | فقط حالتی که باگ را نشان می‌داد |

**منطق سطح دوم:** اگر چیزی در `320×568` با مقیاس `1.6` نمی‌شکند، در ۹۹ درصد موارد در هیچ حالت دیگری هم نمی‌شکند. حالت `regular` با `1.0` فقط برای اطمینان از این است که رفعِ حالتِ باریک، حالت عادی را خراب نکرده باشد. **این دو حالت با هم، ۹۵ درصد ارزش را با ۱۷ درصد هزینه می‌دهند.**

این جدول را عیناً در `docs/ui/RESPONSIVE_LAYOUT.md` بنویس.

### R-83 — تست‌های طلایی: به‌روزرسانی، نه گسترش

فایل موجود: `test/golden/component_gallery_golden_test.dart` (`Size(390, 844)`)
فایل موجود: `test/calendar/calendar_golden_and_e2e_test.dart` (`CAL-60`، مقیاس‌های `[1.0, 1.3, 1.6]`، `Size(390, 844)`)

**تصمیم قطعی: تست طلایی جدید اضافه نکن.** تست‌های طلایی هزینهٔ نگهداری بالایی دارند و هر تغییر بصری آن‌ها را قرمز می‌کند. برای مسئلهٔ سرریز، تست‌های `expectNoOverflow` بسیار مؤثرترند چون **دقیقاً همان چیزی را می‌سنجند که مهم است** و به تغییر رنگ و فاصله حساس نیستند.

**دو کاری که باید بکنی:**

**۱ — تصاویر مرجع موجود را بازتولید کن.** فازهای ۰ تا ۵ چیدمان را عوض کرده‌اند، پس تصاویر مرجع قدیمی معتبر نیستند:
```
flutter test --update-goldens test/golden/
flutter test --update-goldens test/calendar/calendar_golden_and_e2e_test.dart
```
**قبل از پذیرش، تصاویر جدید را واقعاً نگاه کن.** اگر جایی بدتر شده، این یک باگ فاز قبلی است که باید برگردی و حلش کنی. **بازتولید کورکورانهٔ تصاویر مرجع، دقیقاً همان چسب زخمی است که در ریشهٔ شمارهٔ ۵ محکومش کردیم.**

**۲ — تصاویر مرجع را در همان اندازه‌ها نگه دار.** `Size(390, 844)` بماند. اضافه کردن ۱۲ حالت طلایی یعنی ۱۲ برابر شدن تصاویر مرجع — نکن.

### R-84 — حذف قطعی چیت‌های تست

**دو چیت مشخص در مخزن وجود دارند. هر دو باید مرده باشند:**

**چیت ۱ — خفه کردن سرریز.** `test/widget/niyyah_edit_sheet_stays_open_test.dart`:
```dart
// Suppress expected overflow exceptions from planner date picker in constrained test environment
if (details.toString().contains('overflowed') || details.toString().contains('databaseFactory')) {
  return; // suppress known test-environment-only issues
}
```
در `R-09` علامت‌گذاری شد، در `R-31` علتش (`ritmo_date_picker.dart`) حل شد، و در دروازهٔ فاز ۲ باید حذف شده باشد. **اینجا فقط تأیید نهایی:**
```
rg -n "contains\('overflowed'\)" test/
```
باید خالی باشد. اگر نیست، فاز ۲ ناقص اجرا شده — برگرد.

**چیت ۲ — بزرگ کردن صفحهٔ مجازی.** `test/features/movement/presentation/activity_plan_editor_test.dart`:
```dart
tester.view.physicalSize = const Size(800, 1800);
```
در `R-10` حل شد. تأیید:
```
rg -n "physicalSize" test/
```
هر نتیجهٔ باقی‌مانده باید یا `resetPhysicalSize` باشد یا در فایلی که دلیل موجه مستند دارد.

**چیت سوم که ممکن است تازه ساخته باشی — مراقب باش.** در فازهای ۱ تا ۵، اگر جایی برای سبز کردن تست، **حالت را از ماتریس حذف کرده‌ای** (مثلاً `1.6` را از یک حلقه برداشته‌ای)، آن هم چیت است. جست‌وجو کن:
```
rg -n "1.0, 1.3\]" test/
rg -n "skip:" test/
```
هر `skip:` باید دلیل مکتوب داشته باشد.

### R-85 — گارد منبع: جلوگیری از تولد دوبارهٔ الگوهای ممنوع

فایل جدید: `test/responsive_source_guards_test.dart`

**الگو را از `test/prompt_036_source_guards_test.dart` و `test/cycle/cycle_source_guards_test.dart` بگیر** — هر دو در مخزن هستند و دقیقاً همین کار را می‌کنند: فایل‌های منبع را می‌خوانند و روی محتوایشان `expect` می‌زنند.

**این تنها چیزی است که واقعاً جلوی برگشت مشکل را می‌گیرد.** یک برنامه‌نویس جدید که فردا `childAspectRatio: 2.2` می‌نویسد، بلافاصله تست قرمز می‌بیند، نه شش ماه بعد یک گزارش کاربر.

**هفت گارد اجباری — هر کدام با پیام خطای فارسی که راه‌حل را می‌گوید:**

| گارد | الگوی ممنوع | دامنه | پیام خطا باید بگوید |
|---|---|---|---|
| ۱ | `childAspectRatio` | `lib/` به‌جز `ritmo_adaptive_grid.dart` | «از `RitmoAdaptiveGrid` یا `mainAxisExtent` استفاده کن» |
| ۲ | `height: MediaQuery.of(context).size.height` | `lib/` | «از `RitmoBreakpoints.sheetMaxHeight` استفاده کن» |
| ۳ | `showModalBottomSheet` | `lib/` به‌جز `ritmo_sheet_scaffold.dart` و `sheet/` | «از `RitmoSheetScaffold.present` استفاده کن» |
| ۴ | `contains('overflowed')` | `test/` | «سرریز را خفه نکن، حلش کن» |
| ۵ | `fontSize:` | `lib/core/widgets/` و `lib/core/theme/tokens/` | «از `RitmoTextStyles` استفاده کن» |
| ۶ | `textScale > 1.2` | `lib/` | «از `context.isLargeTextScale` استفاده کن» |
| ۷ | `Color(0xFF0F111E)`، `Color(0xFF1E1E2C)`، `Color(0xFF131B2E)` | `lib/` | «از `context.colors` استفاده کن» |

**نکتهٔ فنی مهم دربارهٔ نوشتن این تست:** فایل‌ها را با `Directory('lib').listSync(recursive: true)` بخوان و روی `.dart` فیلتر کن. برای استثناها، مسیر را با `path.contains()` چک کن — نه با نام فایل تنها، چون ممکن است نام تکراری باشد.

**پیام خطا باید نام فایل و شمارهٔ خط را داشته باشد.** یک تست که فقط می‌گوید «گارد ۱ شکست» بی‌فایده است. باید بگوید:
```
lib/features/x/y.dart:42 — childAspectRatio ممنوع است. از RitmoAdaptiveGrid یا mainAxisExtent استفاده کن.
```

### R-86 — تکمیل نهایی `docs/ui/RESPONSIVE_LAYOUT.md`

در `R-11` این سند با پنج بخش اجباری ساخته شد. حالا باید کامل و **قابل استفاده برای برنامه‌نویس بعدی** باشد. هفت بخش نهایی:

۱. **جدول نقطه‌شکست‌ها** — هر چهار کلاس عرض و سه کلاس ارتفاع با عدد دقیق و یک نمونهٔ دستگاه واقعی برای هر کدام.
۲. **درخت تصمیم: کدام ویجت را کی استفاده کنم؟** — «شیت می‌خواهی؟ → `RitmoSheetScaffold`. شیت تمام‌صفحه با وب‌ویو؟ → `RitmoFullBleedSheet`. گرید کارت؟ → `RitmoAdaptiveGrid`. فهرست بلند اسکرول‌شونده؟ → `sliverDelegate`. دو عنصر کنار هم که ممکن است جا نشوند؟ → `RitmoAdaptiveRow`.»
۳. **جدول اولویت رفع سرریز** — همان جدول شش‌ردیفهٔ `R-45`.
۴. **`mainAxisExtent` در برابر `childAspectRatio`** — توضیح `R-31`، چون این تنها نکتهٔ فنی است که برنامه‌نویس‌ها مدام اشتباه می‌گیرند.
۵. **ماتریس حالت‌های تست** — جدول سه‌سطحی `R-82`.
۶. **فهرست هفت گارد** — جدول `R-85` با توضیح اینکه اگر گاردی قرمز شد، **راه‌حل درست کردن کد است، نه اضافه کردن استثنا به گارد**.
۷. **چیزهایی که عمداً حل نشدند** — فهرست تصمیم‌های محصولی معلق: پرسش گرید انرژی (`R-34`)، شیت‌های ضریب `0.9` در گوشی کوتاه (`R-75`)، جهت‌گیری افقی (`R-76`)، دوسویگی متن مخلوط (`R-79`)، بومی‌سازی `cycle_empty_state_banner.dart` (`R-56`).

**قاعدهٔ کیفیت:** هر نماد فارسی یا انگلیسی که در این سند نام برده می‌شود باید با `rg` در مخزن پیدا شود. **سندی که به کد ناموجود ارجاع می‌دهد، از سند نداشتن بدتر است.**

### R-87 — به‌روزرسانی `.agents/AGENTS.md`

یک بخش جدید با عنوان «پاسخ‌گویی چیدمان» اضافه کن که این پنج قاعده را دارد:

۱. هر ویجت جدید باید در `320×568` با مقیاس متن `1.6` بدون سرریز کار کند.
۲. `childAspectRatio` ممنوع است.
۳. ارتفاع شیت فقط از `RitmoBreakpoints.sheetMaxHeight`.
۴. هر `Text` داخل `Row` باید یا `Expanded`/`Flexible` باشد یا `maxLines` داشته باشد.
۵. عدد جادویی چیدمان ممنوع — هر عدد در `RitmoBreakpoints`.

**نکتهٔ حیاتی دربارهٔ ویرایش این فایل:** بخش‌های ۱ و ۳ فایل موجود را دست نزن. **بخش ۲ (نقشهٔ پیاده‌سازی سه‌چرخه‌ای Draft→Evaluate→Rewrite) برای این پرامپت لغو شده است** — همان‌طور که در قواعد اجرای اجباری بالای همین سند نوشته شد. بخش ۲ را در فایل **حذف نکن**؛ فقط از آن پیروی نکن.

### R-88 — سند پیشرفت و جدول وضعیت ۹۲ یافته

فایل جدید: `docs/ui/RESPONSIVE_PROGRESS.md`

یک جدول با دقیقاً ۹۲ ردیف، از `R-01` تا `R-92`. چهار ستون:

| شناسه | عنوان کوتاه | حالت | مدرک |
|---|---|---|---|

حالت‌های مجاز دقیقاً همین چهارتا: `انجام شد` · `منتفی شد` · `مسدود شد` · `به تعویق افتاد`

**ستون «مدرک» اجباری است و باید یکی از این‌ها باشد:**
- برای `انجام شد`: نام فایل تغییریافته و نام تست سبزی که رفتار را تضمین می‌کند.
- برای `منتفی شد`: **خروجی واقعی دستور جست‌وجو** که نشان می‌دهد مسئله وجود نداشت. مثلاً برای `R-53`: خروجی `rg -n "DataTable" lib/`.
- برای `مسدود شد` یا `به تعویق افتاد`: دلیل فنی دقیق و اینکه چه چیزی برای رفع انسداد لازم است.

**این جدول تنها سندی است که من با آن اجرای تو را می‌سنجم.** هر ردیف بدون مدرک، یعنی آن یافته انجام نشده. **ادعا مدرک نیست.**

**هشدار مستقیم و مبتنی بر تجربهٔ همین مخزن:** سند `docs/ai/WEB_BRIDGE_FIX_PROGRESS.md` در مخزن ادعا می‌کند توابع `__ritmo_detach`، `__ritmo_stopGeneration`، `__ritmo_composerReady` و `__ritmo_origFetch` پیاده شده‌اند. در کد واقعی نام‌ها `__ritmo_cleanup`، `__ritmo_cancelGeneration`، `__ritmo_checkComposerReady` و `__ritmo_original_fetch` هستند. **یعنی آن سند پیشرفت با کد نمی‌خواند.** این اتفاق نباید دوباره بیفتد. هر نامی که در سند پیشرفت می‌نویسی را قبل از نوشتن با `rg` تأیید کن.

### R-89 — چک‌لیست دستگاه واقعی

تست ویجت سرریز را می‌گیرد ولی سه چیز را **هرگز** نمی‌گیرد. این سه را فقط روی دستگاه واقعی می‌شود دید:

**۱ — لمس‌پذیری واقعی.** تست می‌گوید دکمه در مختصات درست است؛ نمی‌گوید انگشت به آن می‌رسد. مخصوصاً دکمه‌های نزدیک نوار اشارهٔ پایین (`R-74`).

**۲ — رفتار واقعی صفحه‌کلید.** ارتفاع صفحه‌کلید فارسی با انگلیسی فرق دارد، و صفحه‌کلید با نوار پیش‌بینی کلمه بلندتر است. `viewInsets` شبیه‌سازی‌شده در تست، عدد ثابت است؛ در دستگاه، متغیر و انیمیشن‌دار.

**۳ — تنظیمات دسترسی‌پذیری سیستم.** مقیاس متن سیستم‌عامل با `TextScaler.linear` در تست یکسان نیست؛ اندروید و آی‌اواس منحنی متفاوتی دارند.

**چک‌لیست دقیق — روی دست‌کم دو دستگاه واقعی با اندازهٔ متفاوت:**
- [ ] مرحلهٔ ورود کامل طی می‌شود.
- [ ] در هر ۲۸ ماژول، صفحهٔ اصلی باز و اسکرول می‌شود.
- [ ] یک فرم چندفیلدی با صفحه‌کلید باز پر و ثبت می‌شود (`create_course_sheet.dart`).
- [ ] در صفحهٔ گفتگو، پیام چندخطی نوشته و ارسال می‌شود.
- [ ] تقویم چرخه در ماه ۳۱ روزه‌ای که با پنج‌شنبه شروع می‌شود درست است.
- [ ] با مقیاس متن سیستم روی حداکثر، هر پنج مورد بالا تکرار می‌شود.

نتیجه را در `docs/ui/RESPONSIVE_PROGRESS.md` با نام و اندازهٔ دستگاه‌ها بنویس.

### R-90 — پاک‌سازی نهایی: اعداد پراکنده‌ای که جا مانده‌اند

پس از پنج فاز، هنوز اعداد چیدمانی پراکنده‌ای باقی می‌مانند که هیچ فازی صریحاً نامشان نبرده. این آخرین جاروی سرتاسری است.

**سه دستور، و برای هر نتیجه یک تصمیم صریح:**
```
rg -n "SizedBox\(width: [0-9]{3,}" lib/
rg -n "SizedBox\(height: [0-9]{3,}" lib/
rg -n "maxWidth: [0-9]{3,}|minWidth: [0-9]{3,}" lib/
```

**برای هر نتیجه دقیقاً یکی از این سه:**
- **جابه‌جا کن** به `RitmoBreakpoints` اگر واقعاً یک قاعدهٔ چیدمانی است.
- **پاسخ‌گو کن** با `LayoutBuilder` اگر باید با عرض تغییر کند.
- **رها کن با توضیح** اگر ابعاد ذاتی یک عنصر است (مثلاً اندازهٔ ثابت یک آیکون تزئینی). **در این حالت یک کامنت یک‌خطی بنویس که چرا ثابت است** — تا نفر بعدی وقتش را تلف نکند.

**سابقهٔ ثبت‌شده که باید مشخصاً چک شود:** پرامپت `C-43` موارد `width: 320` و `SizedBox(width: 240)` و `SizedBox(width: 260)` را در ماژول چرخه گزارش کرده بود. **تأیید کن که حل شده‌اند** — و اگر نه، اینجا حلشان کن. به گزارش قدیمی اعتماد نکن؛ کد را ببین.

### R-91 — کارایی مجموعه تست

پس از افزودن این همه تست، زمان اجرا را اندازه بگیر:
```
time flutter test
```

**سقف قابل قبول: مجموع تست‌های پاسخ‌گویی نباید بیش از ۹۰ ثانیه به کل مجموعه اضافه کند.** اگر بیشتر شد، سه راه مجاز — به همین ترتیب:

۱. حالت‌های سطح دوم `R-82` را از ۲ به ۱ کم کن (فقط `compact-short` با `1.6`). **این کم‌خطرترین کاهش است** چون همان یک حالت، بدترین حالت است.
۲. راه‌اندازی پایگاه داده را در `setUpAll` بگذار نه `setUp`، اگر تست‌ها حالت مشترک را خراب نمی‌کنند.
۳. سوییپ ۲۸ ماژول را به یک فایل جدا منتقل کن که با تگ اجرا می‌شود.

**ممنوع مطلق: حذف تست برای سریع‌تر شدن.** اگر مجبور شدی راه ۳ را بروی، در `docs/ui/RESPONSIVE_LAYOUT.md` دقیقاً بنویس چطور اجرا می‌شود.

### R-92 — دروازهٔ نهایی سرتاسری

**این آخرین یافته است. تا وقتی هر بند زیر واقعاً سبز نشده، کار تمام نیست.**

همهٔ دستورهای گارد را یک‌جا اجرا کن و خروجی هر کدام را در `docs/ui/RESPONSIVE_PROGRESS.md` بنویس:

```
flutter analyze
flutter test
dart format --set-exit-if-changed lib test

rg -n "childAspectRatio" lib/
rg -n "height: MediaQuery.of(context).size.height" lib/
rg -n "crossAxisCount: 7" lib/
rg -n "showModalBottomSheet" lib/ --glob '!**/ritmo_sheet_scaffold.dart' --glob '!**/sheet/**'
rg -n "contains('overflowed')" test/
rg -n "physicalSize" test/
rg -n "fontSize:" lib/core/widgets lib/core/theme/tokens
rg -n "textScale > 1.2" lib/
rg -n "Color\(0xFF0F111E\)|Color\(0xFF1E1E2C\)|Color\(0xFF131B2E\)" lib/
rg -n "catch \(_\) \{\}" lib/

rg -n "RitmoBreakpoints" lib/ | wc -l
rg -n "RitmoSheetScaffold" lib/ | wc -l
rg -n "RitmoAdaptiveGrid" lib/ | wc -l
rg -n "1.3" lib/main.dart
```

**نتیجهٔ انتظاری:** ده دستور اول باید **خالی** باشند (به‌جز `crossAxisCount: 7` که باید دقیقاً ۳ باشد، و `physicalSize` که فقط `resetPhysicalSize` مجاز است). سه شمارش بعدی باید به ترتیب دست‌کم ۲۵، ۲۰ و ۱۲ باشند. آخری باید خالی باشد.

### 🚦 دروازهٔ پذیرش فاز ۶

- [ ] `flutter analyze` — صفر خطا، صفر اخطار.
- [ ] `flutter test` — کامل سبز با سقف مقیاس متن ۱٫۶.
- [ ] `dart format --set-exit-if-changed lib test` — بدون تغییر.
- [ ] `test/features/responsive_sweep_test.dart` هر ۲۸ ماژول را پوشش می‌دهد (یا ماژول پوشش‌نداده با دلیل فنی مکتوب ثبت شده).
- [ ] `test/responsive_source_guards_test.dart` وجود دارد، هر هفت گارد را دارد، و سبز است.
- [ ] هر هفت گارد با یک تخلف عمدی و موقت **قرمز شد** و پس از بازگرداندن، سبز شد. **این تنها راه اثبات اینکه گارد واقعاً کار می‌کند.** نتیجه را در سند پیشرفت بنویس.
- [ ] تصاویر مرجع طلایی بازتولید و **چشمی بررسی** شدند.
- [ ] `docs/ui/RESPONSIVE_LAYOUT.md` هر هفت بخش را دارد و هر نمادش با `rg` پیدا می‌شود.
- [ ] `docs/ui/RESPONSIVE_PROGRESS.md` دقیقاً ۹۲ ردیف دارد و هر ردیف مدرک دارد.
- [ ] `.agents/AGENTS.md` بخش «پاسخ‌گویی چیدمان» را دارد.
- [ ] چک‌لیست دستگاه واقعی روی دست‌کم دو دستگاه انجام و ثبت شد.
- [ ] `time flutter test` اندازه‌گیری و ثبت شد و از سقف عبور نکرده.
- [ ] هر ۱۲ یافتهٔ `R-81` تا `R-92` حالت پایانی دارد.

**کامیت:** `fix(ui): phase 6 — گاردهای پاسخ‌گویی و مستندسازی [R-81 … R-92]`

---

## ۳. قواعد کامیت

**یک کامیت به ازای هر فاز. نه کمتر، نه بیشتر.**

```
fix(ui): phase 0 — زیرساخت پاسخ‌گویی [R-01 … R-12]
fix(ui): phase 1 — شیت‌ها و مودال‌های پاسخ‌گو [R-13 … R-30]
fix(ui): phase 2 — گریدهای پاسخ‌گو و حذف نسبت ابعاد ثابت [R-31 … R-44]
fix(ui): phase 3 — ردیف و متن پاسخ‌گو [R-45 … R-58]
fix(ui): phase 4 — حذف اندازه‌های ثابت و اصلاح Stack [R-59 … R-70]
fix(ui): phase 5 — صفحه‌کلید، SafeArea و سقف مقیاس متن ۱٫۶ [R-71 … R-80]
fix(ui): phase 6 — گاردهای پاسخ‌گویی و مستندسازی [R-81 … R-92]
```

**پنج قاعدهٔ قطعی:**

۱. **کامیت فقط وقتی که دروازهٔ آن فاز واقعاً سبز شده باشد.** یک بند ناقص یعنی کامیت نمی‌کنی.
۲. **فازها را در یک کامیت جمع نکن.** اگر در ماه آینده چیزی شکست، باید بتوان فاز را جداگانه برگرداند.
۳. **پیام کامیت را دقیقاً همین‌طور بنویس** — بازهٔ شناسه‌ها در کروشه ماندنی است. دقیقاً همین الگو بود که امکان داد اجرای `A-01 … A-68` را بعداً ممیزی کنیم و بفهمیم کدام ۱۲ یافته اجرا نشده.
۴. **در هر کامیت، `docs/ui/RESPONSIVE_PROGRESS.md` را هم به‌روز کن.** سند پیشرفت باید همیشه با کد هم‌زمان باشد.
۵. **پوش نکن تا هر هفت فاز تمام شود، مگر صریحاً از تو خواسته شود.**

---

## ۴. خلاصهٔ قطعی

| فاز | موضوع | شناسه‌ها | تعداد | خروجی اصلی |
|---|---|---|---|---|
| **۰** | زیرساخت پاسخ‌گویی | `R-01` … `R-12` | ۱۲ | `RitmoBreakpoints`، `RitmoAdaptiveGrid`، `RitmoAdaptiveRow`، `RitmoFullBleedSheet`، هارنس تست |
| **۱** | شیت‌ها و مودال‌ها | `R-13` … `R-30` | ۱۸ | هر ۳۹ محل `MediaQuery.size` پاک شد |
| **۲** | گریدها و کارت‌ها | `R-31` … `R-44` | ۱۴ | هر ۱۶ `childAspectRatio` حذف شد |
| **۳** | ردیف، متن و چیپ | `R-45` … `R-58` | ۱۴ | ویجت‌های مشترک در هر ۲۸ ماژول امن شدند |
| **۴** | اندازهٔ ثابت و `Stack` | `R-59` … `R-70` | ۱۲ | اعداد جادویی و `Positioned` شکننده رفتند |
| **۵** | صفحه‌کلید، `SafeArea`، جهت | `R-71` … `R-80` | ۱۰ | سقف مقیاس متن به `1.6` رسید |
| **۶** | گاردها و مستندات | `R-81` … `R-92` | ۱۲ | مشکل دیگر برنمی‌گردد |
| | **جمع** | `R-01` … `R-92` | **۹۲** | |

### چهار چیزی که در پایان باید وجود داشته باشند

**۱ — یک منبع حقیقت برای هر عدد چیدمانی.** فایل `lib/core/theme/tokens/ritmo_breakpoints.dart`. امروز این فایل وجود ندارد — دستور `search_code "Breakpoints OR breakpoint repo:nicedevil02/ritmo language:dart"` دقیقاً `{"total_count":0}` برمی‌گرداند. این تنها و مهم‌ترین خروجی این کار است.

**۲ — چهار ویجت مشترک که کار را درست انجام می‌دهند.** `RitmoSheetScaffold` (ارتقایافته)، `RitmoAdaptiveGrid`، `RitmoAdaptiveRow`، `RitmoFullBleedSheet`. پس از این، برنامه‌نویس بعدی لازم نیست فکر کند — فقط از ویجت درست استفاده می‌کند.

**۳ — هفت گارد که جلوی بازگشت را می‌گیرند.** این دقیقاً همان چیزی است که در پرامپت‌های قبلی نبود، و به همین دلیل `C-43` و `K-89` و `B47` هر سه مجبور شدند یک مشکل یکسان را دوباره کشف کنند.

**۴ — تستی که در گوشی `320×568` با مقیاس متن `1.6` و صفحه‌کلید باز سبز است.** اگر این تست سبز باشد، برنامه روی هر گوشی ایرانی کار می‌کند.

### سه کاری که مطلقاً نباید بکنی

**۱ — کوچک کردن متن برای جا دادن.** نه `FittedBox` دور جمله، نه کم کردن `fontSize`، نه کلمپ کردن مقیاس متن. کاربری که متن بزرگ را انتخاب کرده، **دلیل دارد**. تنها استثنای مجاز در کل این سند، `R-54` است: `FittedBox` برای عدد کوتاه در فضای دایره‌ای ثابت.

**۲ — کوتاه کردن متن فارسی برای حل سرریز.** نه نام تب‌ها (`R-52`)، نه برچسب دکمه‌ها (`R-36`، `R-51`)، نه متن توضیحی. **متن محتواست؛ چیدمان باید خودش را با محتوا تطبیق دهد، نه برعکس.**

**۳ — خفه کردن خطای سرریز در تست.** دقیقاً همین کار بود که باعث شد باگ `ritmo_date_picker.dart` ماه‌ها زنده بماند. خطای سرریز، دوست توست — دقیقاً جای مشکل را نشان می‌دهد و حتی می‌گوید چند پیکسل.

### دو نکتهٔ روش کار

**دربارهٔ یافته‌های `منتفی شد`:** برخی یافته‌ها عمداً طوری نوشته شده‌اند که ممکن است مصداقی نداشته باشند (`R-49`، `R-53`، `R-76`). **این طراحی عمدی است، نه اشتباه.** وظیفهٔ تو این است که دستور جست‌وجو را اجرا کنی، **خروجی واقعی را در سند پیشرفت بنویسی**، و بروی. باز کردن یک یافته با مدرک «مسئله وجود نداشت» یک نتیجهٔ کاملاً معتبر است.

**دربارهٔ ترتیب:** فازها به هم وابسته‌اند و ترتیبشان مهندسی است، نه دلبخواهی:
- فاز ۰ ابزار را می‌سازد که فازهای ۱ تا ۵ با آن کار می‌کنند.
- فاز ۲ باید پس از فاز ۱ باشد، چون `R-09` را `R-31` می‌بندد.
- **فاز ۵ قطعاً باید آخرین فاز کدی باشد**، چون بالا بردن سقف مقیاس متن پیش از درست شدن چیدمان، برنامه را برای کاربر واقعی بدتر می‌کند.

---

### یادآوری نهایی

این پرامپت خودش نقشهٔ پیاده‌سازی است. **نقشهٔ مجزا ننویس، سند طراحی ننویس، دربارهٔ رویکرد مشورت نخواه.** بخش ۲ فایل `.agents/AGENTS.md` (نقشهٔ سه‌چرخه‌ای) برای این کار لغو شده است.

۹۲ یافته داری. هر یافته مسیر فایل، توضیح مسئله، راه‌حل مشخص و معیار پذیرش دارد. هفت دروازه داری که نمی‌گذارند نیمه‌کاره جلو بروی.

یک جمله را یادت باشد: **مشکل این نیست که کسی کد بد نوشته.** کد مخزن در مجموع خوب است — `ritmo_nav_bar.dart` و `kpi_grid.dart` و `activity_category_section.dart` نمونه‌های واقعاً خوبی از چیدمان پاسخ‌گو هستند. مشکل این است که **هیچ زیرساخت مشترکی وجود نداشت**، پس هر برنامه‌نویس در هر ماژول مجبور شد مسئله را از اول حل کند — و طبیعتاً در ۲۸ ماژول، ۲۸ جواب متفاوت درآمد و بسیاری‌شان غلط بودند.

تو داری آن زیرساخت را می‌سازی.

از فاز ۰ شروع کن. `R-01` را بردار و کد بنویس.
