# نقشهٔ پیاده‌سازی سیستم کنترل اندازهٔ متن و المان‌ها (Ritmo UI Scale System)

> **دامنه:** افزودن یک سیستم سرتاسری که کاربر از «تنظیمات ← ظاهر و زبان» بتواند (۱) اندازهٔ متن‌ها و (۲) بزرگی/فشردگی المان‌های رابط کاربری را در کل اپ تغییر دهد.
>
> **مبنای بررسی:** درخت کد روی شاخهٔ `main`، کامیت `392eb245ac14db3185c7077304d3fcbe0f1b09e3`.
>
> **مخاطب این سند:** ایجنت/توسعه‌دهنده‌ای که فازها را اجرا می‌کند. هر فاز «معیار پذیرش» دارد و بدون سبز شدن آن، فاز بعد شروع نمی‌شود.

---

## ۰. خلاصهٔ اجرایی (TL;DR)

| موضوع | تصمیم |
|---|---|
| محورهای کنترل | دو محور مستقل: `ui_text_scale` (متن) و `ui_density` (المان‌ها) |
| منبع حقیقت ذخیره‌سازی | `SettingsRegistry` + `SettingsService` (مثل بقیهٔ تنظیمات، `scope: db`) |
| مسیر اعمال متن | تزریق `TextScaler` در `MediaQuery` ریشهٔ اپ (`lib/main.dart`) — هیچ `fontSize` ای در کد ضرب نمی‌شود |
| مسیر اعمال المان | `ThemeExtension` تازه به نام `RitmoMetrics` + `visualDensity` + تم‌های کامپوننتی مقیاس‌پذیر |
| بدون ری‌استارت | تغییر هر دو مقدار زنده اعمال می‌شود (`requiresRestart: false`) |
| گارد رگرسیون | دو متریک جدید در `tool/theme_audit.dart` + تست‌های ماتریسی مقیاس |
| فازبندی | ۵ فاز: توکن → تنظیمات → کامپوننت‌های مشترک → مهاجرت ماژول‌ها → ارتقای سقف مقیاس به ۱.۶ |

---

## ۱. یافته‌های بررسی وضعیت فعلی

### ۱.۱ سیستم تم و تایپوگرافی

| فایل | نقش | یافتهٔ کلیدی |
|---|---|---|
| `lib/core/theme/ritmo_theme.dart` | منبع حقیقت بصری | `RitmoSpacing` (۷ مقدار ثابت)، `RitmoRadius` (۷ مقدار)، `RitmoTypography.textTheme()` با **۱۵ استایل و fontSize ثابت** (۱۱ تا ۳۲)، `RitmoTextStyles` با **۹ هلپر و fontSize ثابت** (۱۱ تا ۴۴) |
| همان فایل، `RitmoTheme.build()` | ساخت `ThemeData` | fontSize‌های هاردکد در `appBarTheme` (۱۸)، دکمه‌ها (۱۴)، `chipTheme` (۱۳)، `dialogTheme` (۱۸/۱۴)، `navigationBarTheme` (۱۲)، `tooltipTheme` (۱۲)، `popupMenuTheme` (۱۴)، `inputDecorationTheme` (padding 16/14)، `iconTheme` (size: 24)، `minimumSize: Size(48, 48)` |
| `lib/core/theme/theme_preferences.dart` | مدل تنظیمات ظاهر | فقط `mode`، `paletteId`، `reduceTransparency`, `trueBlack`, `autoDarkAtMaghrib` — **هیچ فیلدی برای اندازه وجود ندارد** |
| `lib/core/theme/theme_repository.dart` | پل بین `SettingsService` و تم | تنها به ۴ کلید `theme_mode`, `theme_palette`, `theme_reduce_transparency`, `theme_true_black` گوش می‌دهد |
| `lib/core/theme/tokens/ritmo_breakpoints.dart` | هندسهٔ پاسخ‌گو | `supportedMinTextScale = 0.9`، `supportedMaxTextScale = 1.3`، `minTouchTarget = 48`، `tileMinWidth*`، `context.textScale`، `context.isLargeTextScale (> 1.2)` |
| `lib/main.dart` | ریشهٔ اپ | مقیاس متن فقط از سیستم‌عامل می‌آید: `mq.textScaler.clamp(min: 0.9, max: 1.3)`. کش تم با کلید `'${paletteId}|${mode}|${reduceTransparency}|${trueBlack}'` |

**نتیجه:** امروز کاربر هیچ کنترلی داخل اپ ندارد؛ فقط تنظیم اندازهٔ فونت سیستم‌عامل (و آن هم سقف ۱.۳) اثر دارد و «بزرگی المان‌ها» به‌کل کنترل‌پذیر نیست.

### ۱.۲ زیرساخت تنظیمات (آماده و قابل استفاده)

- `lib/core/settings/settings_registry.dart` — `SettingDescriptor` با فیلدهای `key`, `type`, `scope`, `defaultValue`, `min`, `max`, `requiresRestart`, `searchTerms` و `assert`های اعتبارسنجی. انواع: `boolean`, `integer`, `text`, `enumeration`, `time`.
- `lib/core/settings/settings_service.dart` — `get<T>()`, `set()`, `setMany()`, استریم `changes`, `isInitialized`, نرمال‌سازی مقدار در `_validateAndNormalize`.
- `lib/features/settings/presentation/widgets/setting_field_builder.dart` — رندر خودکار فیلد از توصیفگر (`SettingField`).
- `lib/features/settings/presentation/groups/appearance_group_screen.dart` — گروه «ظاهر و زبان»؛ محل طبیعی کنترل‌های جدید.
- `lib/features/settings/presentation/widgets/quick_settings_sheet.dart` — شیت دسترسی سریع (مثل کلید OLED).
- `lib/core/settings/settings_transfer_service.dart` — Export/Import تنظیمات؛ کلیدهای جدید باید با `scope: db` ثبت شوند تا در پشتیبان بیایند.

### ۱.۳ زیرساخت پاسخ‌گویی و گارد (آماده و قابل توسعه)

- `docs/ui/RESPONSIVE_LAYOUT.md` — ماتریس ۱۲ حالته (۴ ویوپورت × ۳ مقیاس متن)، سیاست مقیاس متن (سقف ۱.۳ در فازهای ۰–۴ و ۱.۶ در فاز ۵).
- `test/support/responsive_harness.dart` — `testAcrossViewports` و `expectNoOverflow`.
- `tool/theme_audit.dart` + `tool/theme_baseline.json` — گارد رگرسیون متریک‌محور با `--check` و `--update-baseline`.
- `test/guards/theme_guards_test.dart`، `test/theme/*`، `test/golden/component_gallery_golden_test.dart`، `test/settings/settings_text_scale_resilience_test.dart`، `test/features/calendar/calendar_text_scale_test.dart`.
- کامپوننت‌های آمادهٔ مقیاس‌پذیر: `lib/core/widgets/ritmo_adaptive_grid.dart`، `ritmo_adaptive_row.dart`، `ritmo_sheet_scaffold.dart`، خانوادهٔ `lib/core/widgets/ritmo/*` (۱۵ پریمیتیو).

### ۱.۴ اندازهٔ بدهی فنی (چرا مهاجرت باید تدریجی باشد)

- `fontSize` در **~۴۱۲ فایل** دارت ظاهر می‌شود (اکثراً `TextStyle(fontSize: …)` محلی در `lib/features/**`).
- `tool/theme_baseline.json` نشان می‌دهد بدهی مشابه در رنگ‌ها هم بزرگ است (۱۵۱۶ رنگ هاردکد، ۱۷۴ سایهٔ دستی، ۱۰۲ `Scaffold` خام).
- بنابراین **هر راه‌حلی که نیاز به لمس ۴۰۰ فایل داشته باشد، شکست می‌خورد.** طرح زیر عمداً به‌گونه‌ای است که ۹۰٪ اثر با تغییر <۱۵ فایل هسته به دست بیاید.

---

## ۲. تصمیم‌های معماری

### ADR-1: دو محور مستقل، نه یک اسلایدر

- `ui_text_scale` → فقط تایپوگرافی (خطوط متن، ارتفاع خط، حباب‌های متنی).
- `ui_density` → فقط هندسه (padding، gap، شعاع، اندازهٔ آیکن، هدف لمس، ارتفاع ردیف/نوار).

دلیل: کاربر کم‌بینا معمولاً متن بزرگ + المان بزرگ می‌خواهد، ولی کاربر «حرفه‌ای» متن کوچک + چگالی زیاد (اطلاعات بیشتر در صفحه). ادغام این دو در یک محور یکی از این دو گروه را ناراضی می‌کند.

### ADR-2: متن از مسیر `MediaQuery.textScaler` اعمال شود، نه با ضرب `fontSize`

```dart
// lib/main.dart — builder
final effective = RitmoUiScale.effectiveTextScale(
  osScale: mq.textScaler.scale(1.0),
  appFactor: prefs.textScaleFactor,      // از تنظیمات
  followOs: prefs.followOsTextScale,     // از تنظیمات
);
return MediaQuery(
  data: mq.copyWith(textScaler: TextScaler.linear(effective)),
  child: AppLockGate(child: child!),
);
```

مزایای قطعی:

1. تمام ۴۱۲ فایل با `fontSize` هاردکد **بدون تغییر** مقیاس می‌گیرند.
2. ویجت‌های شخص‌ثالث (`persian_datetime_picker`, `fl_chart`, markdown parser…) هم مقیاس می‌گیرند.
3. کدهای موجودِ آگاه از مقیاس (`context.textScale`، `context.isLargeTextScale`، تست‌های `calendar_text_scale_test`) بدون تغییر درست کار می‌کنند، چون همه از `MediaQuery` می‌خوانند.
4. فرمول واحد + کلَمپ سخت، خطر «مقیاس دوبار اعمال شده» را حذف می‌کند.

**ممنوعیت‌ها:** ضرب دستی `fontSize` در `RitmoTypography`؛ فراخوانی `MediaQuery.copyWith(textScaler:)` در هیچ صفحهٔ دیگری (به‌جز تست‌ها و پیش‌نمایش زندهٔ تنظیمات).

### ADR-3: هندسه از مسیر `ThemeExtension` جدید (`RitmoMetrics`) اعمال شود

`textScaler` روی padding/gap/آیکن اثر ندارد، پس محور دوم به یک توکنِ زمان‌اجرا نیاز دارد که در `ThemeData.extensions` ثبت شود و از `context` خوانده شود.

### ADR-4: فرمول و کلَمپ سخت (تنها منبع حقیقت اعداد)

```dart
// متن
appFactor ∈ {0.85, 0.925, 1.00, 1.10, 1.25, 1.40}   // ۶ پله، پیش‌فرض 1.00
effectiveText = clamp(followOs ? appFactor * osScale : appFactor,
                      RitmoBreakpoints.supportedMinTextScale,   // 0.9  → فاز ۵: 0.85
                      RitmoBreakpoints.supportedMaxTextScale)   // 1.3  → فاز ۵: 1.6

// المان‌ها
density ∈ { compact: 0.92, comfortable: 1.00, spacious: 1.12, xl: 1.24 }
scaledSpacing  = round(base * density)                  // شبکهٔ ۴ پیکسلی حفظ می‌شود
scaledIcon     = clamp(round(base * density), 16, 40)
scaledTouch    = max(48, round(48 * density))           // هرگز کمتر از ۴۸ (WCAG)
scaledRadius   = round(base * (1 + (density - 1) * 0.5)) // شعاع نصفِ نرخ رشد می‌کند
```

نکتهٔ مهم: شعاع و سایه با نرخ کمتری رشد می‌کنند تا در حالت `xl` کارت‌ها «بادکرده» دیده نشوند.

### ADR-5: بدون ری‌استارت، با کش تم

هر دو مقدار وارد کلید کش تم در `lib/main.dart` می‌شوند تا تم فقط هنگام تغییر واقعی بازساخته شود:

```dart
final inputsKey = '${prefs.paletteId}|${prefs.mode}|${prefs.reduceTransparency}'
    '|${prefs.trueBlack}|${prefs.density}|${prefs.textScaleFactor}|${prefs.followOsTextScale}';
```

---

## ۳. مدل داده و توکن‌های جدید

### ۳.۱ فایل جدید: `lib/core/theme/tokens/ritmo_metrics.dart`

```dart
enum RitmoDensityLevel { compact, comfortable, spacious, xl }

@immutable
class RitmoMetrics extends ThemeExtension<RitmoMetrics> {
  const RitmoMetrics({
    required this.density,         // RitmoDensityLevel
    required this.densityFactor,   // 0.92 … 1.24
    required this.space,           // RitmoSpaceSet (xs…xxxl مقیاس‌خورده)
    required this.radius,          // RitmoRadiusSet
    required this.icon,            // RitmoIconSet (sm 16 / md 20 / lg 24 / xl 32)
    required this.touchTarget,     // >= 48
    required this.rowHeight,       // ارتفاع پایهٔ ردیف لیست
    required this.navBarHeight,    // ارتفاع نوار ناوبری پایین
    required this.hourSlotHeight,  // ارتفاع هر ساعت در تایم‌لاین تقویم
  });

  factory RitmoMetrics.of(RitmoDensityLevel level) { /* اعداد از ADR-4 */ }

  @override RitmoMetrics copyWith({...});
  @override RitmoMetrics lerp(RitmoMetrics? other, double t); // lerpDouble روی همهٔ فیلدها
}

extension RitmoMetricsX on BuildContext {
  RitmoMetrics get metrics =>
      Theme.of(this).extension<RitmoMetrics>() ??
      RitmoMetrics.of(RitmoDensityLevel.comfortable);

  RitmoSpaceSet  get space => metrics.space;   // context.space.lg
  RitmoIconSet   get icons => metrics.icon;    // context.icons.md
}
```

قواعد الزامی:

- `lerp` باید واقعی باشد (نه `t < 0.5 ? this : other`) تا تغییر چگالی انیمیشن نرم داشته باشد؛ مدت انیمیشن = `RitmoMotion.themeSwap` و در حالت `disableAnimations` صفر.
- مقادیر `const`ِ `RitmoSpacing` / `RitmoRadius` **حذف نمی‌شوند** (سازگاری عقب‌رو)، ولی در سند طراحی به‌عنوان «مقدار مرجع طراحی» علامت می‌خورند و استفادهٔ جدید از آن‌ها در `lib/features/**` توسط گارد شمرده می‌شود.

### ۳.۲ فایل جدید: `lib/core/theme/ui_scale.dart`

منطق خالص و تست‌پذیر (بدون وابستگی به Flutter widgets):

```dart
abstract final class RitmoUiScale {
  static const List<double> textSteps = [0.85, 0.925, 1.0, 1.10, 1.25, 1.40];
  static const double defaultTextFactor = 1.0;

  static double effectiveTextScale({
    required double osScale,
    required double appFactor,
    required bool followOs,
  });

  static double snapToStep(double raw);                 // برای اسلایدر
  static String labelFor(double factor);                 // «کوچک»، «معمولی»، «بزرگ»…
  static RitmoDensityLevel parseDensity(String raw);     // با fallback ایمن + لاگ هشدار
  static String serializeDensity(RitmoDensityLevel v);
}
```

### ۳.۳ کلیدهای تنظیمات (ثبت در `lib/core/settings/settings_registry.dart`)

| کلید | نوع | دامنه | پیش‌فرض | توضیح |
|---|---|---|---|---|
| `ui_text_scale` | `integer` (درصد) | `min: 85`, `max: 140` | `100` | ذخیره به‌صورت عدد صحیح درصدی برای پرهیز از خطای اعشار در DB |
| `ui_text_follow_os` | `boolean` | — | `true` | اگر روشن باشد، مقیاس اپ در مقیاس سیستم‌عامل ضرب می‌شود |
| `ui_density` | `enumeration` | `compact\|comfortable\|spacious\|xl` | `comfortable` | بزرگی/فشردگی المان‌ها |

هر سه با `scope: SettingScope.db`، `requiresRestart: false` و `searchTerms` فارسی:
`['اندازه متن','فونت','بزرگنمایی','درشتی','ریزی','چگالی','فشردگی','بزرگی المان','دسترس‌پذیری','کم‌بینا']`.

---

## ۴. تغییرات فایل‌به‌فایل (چک‌لیست اجرا)

### گروه A — هسته (اثر سرتاسری، ۹ فایل)

1. **`lib/core/theme/tokens/ritmo_metrics.dart`** *(جدید)* — توکن هندسه + اکستنشن `context.metrics/space/icons`.
2. **`lib/core/theme/ui_scale.dart`** *(جدید)* — فرمول‌ها، پله‌ها، برچسب‌ها، parse/serialize.
3. **`lib/core/theme/theme_preferences.dart`** — افزودن `textScalePercent (int)`, `followOsTextScale (bool)`, `density (RitmoDensityLevel)` به کلاس، `defaults`, `copyWith`, `==`, `hashCode`.
4. **`lib/core/theme/theme_repository.dart`** — خواندن سه کلید جدید در `_syncFromSettings`، افزودن آن‌ها به شرط `changes.listen`، متدهای `updateTextScale(int)`, `updateFollowOsTextScale(bool)`, `updateDensity(RitmoDensityLevel)`، و گنجاندن‌شان در `resetAppearance()`.
5. **`lib/core/settings/settings_registry.dart`** — سه `SettingDescriptor` جدید در بخش ظاهر (کنار `theme_true_black`).
6. **`lib/core/theme/ritmo_theme.dart`** — امضای `build` می‌شود:
   ```dart
   static ThemeData build({
     required RitmoPalette palette,
     required Brightness brightness,
     bool reduceTransparency = false,
     bool trueBlack = false,
     RitmoDensityLevel density = RitmoDensityLevel.comfortable, // جدید
   })
   ```
   و در بدنه:
   - `final m = RitmoMetrics.of(density);`
   - ثبت `m` در `extensions`.
   - `visualDensity: VisualDensity(horizontal: vd, vertical: vd)` که `vd = (densityFactor - 1) * 8` و کلَمپ `[-2, 2]`.
   - جایگزینی اعداد ثابت در تم‌های کامپوننتی با `m.*`: `iconTheme.size`, `appBarTheme.iconTheme/toolbarHeight`, `minimumSize` دکمه‌ها (`Size(m.touchTarget, m.touchTarget)`), `inputDecorationTheme.contentPadding`, `chipTheme.padding`, `listTileTheme.contentPadding`, `bottomSheetTheme` شعاع, `dialogTheme` شعاع, `navigationBarTheme` (اندازهٔ آیکن).
   - **fontSize‌ها دست‌نخورده می‌مانند** (طبق ADR-2).
7. **`lib/core/theme/tokens/ritmo_breakpoints.dart`** — افزودن `phase5MaxTextScale = 1.6`; اضافه کردن `supportedTextScaleSteps`; اصلاح مستندات `isLargeTextScale` (آستانه ۱.۲ حفظ می‌شود چون از `MediaQuery` می‌خواند و خودکار درست است).
8. **`lib/main.dart`** — تزریق `TextScaler.linear(effective)`، افزودن سه مقدار جدید به `_themeInputsKey`، پاس دادن `density` به هر دو فراخوانی `RitmoTheme.build`.
9. **`lib/core/theme/tokens/ritmo_material.dart`** — `RitmoMaterial.radius` پیش‌فرض از `context.metrics.radius.card` خوانده شود (الان عدد ۱۶ هاردکد است).

### گروه B — پریمیتیوهای مشترک (۱۵ فایل در `lib/core/widgets/**`)

هدف: با اصلاح این‌ها، اکثر صفحات بدون تغییر مقیاس‌پذیر می‌شوند.

| فایل | تغییر |
|---|---|
| `ritmo/ritmo_button.dart` | ارتفاع/padding/اندازهٔ آیکن از `context.metrics` |
| `ritmo/ritmo_card.dart`, `ritmo_hero_card.dart`, `ritmo_glass_surface.dart` | padding و شعاع از توکن زمان‌اجرا |
| `ritmo/ritmo_list_row.dart` | ارتفاع کمینه = `m.touchTarget`، حذف `fontSize` محلی به‌نفع `textTheme` |
| `ritmo/ritmo_chip.dart`, `ritmo_segmented_control.dart` | padding و ارتفاع مقیاس‌پذیر + شکست به `Wrap` وقتی `context.isLargeTextScale` |
| `ritmo/ritmo_text_field.dart` | padding از تم، حذف `fontSize` ثابت |
| `ritmo/ritmo_dialog.dart`, `sheet/ritmo_form_sheet.dart`, `sheet/ritmo_picker_sheet.dart`, `action/ritmo_action_sheet.dart`, `ritmo_sheet_scaffold.dart` | padding/شعاع/ارتفاع فوتر مقیاس‌پذیر؛ ارتفاع همیشه «سقف» بماند |
| `ritmo_adaptive_grid.dart` | `tileMinWidth` در `densityFactor` و `textScale` ضرب شود تا در مقیاس بالا ستون کم شود |
| `ritmo_adaptive_row.dart` | آستانهٔ سقوط به چیدمان عمودی تابع مقیاس مؤثر |
| `ritmo_module_app_bar.dart`, `ritmo/ritmo_page_scaffold.dart`, `ritmo/ritmo_screen.dart` | padding لبهٔ صفحه از `context.space.lg` |
| `ritmo_progress_ring.dart` | اندازهٔ حلقه و ضخامت خط تابع `densityFactor` (CustomPainter — پارامتری شود) |
| `ritmo/ritmo_empty_state.dart`, `ritmo_error_state.dart`, `ritmo_progress.dart`, `occurrence_status_badge.dart`, `ritmo_swipeable_row.dart` | اندازهٔ آیکن/فاصله از توکن |

### گروه C — رابط تنظیمات (۳ فایل)

1. **`lib/features/settings/presentation/groups/appearance_group_screen.dart`** — بخش جدید «اندازهٔ متن و المان‌ها»:
   - اسلایدر پله‌ای اندازهٔ متن (۶ پله) با برچسب فارسی + هپتیک `RitmoHapticsPolicy.selection()` روی هر پله.
   - کلید «پیروی از تنظیم سیستم» (`ui_text_follow_os`) + متن راهنما.
   - `RitmoSegmentedControl<RitmoDensityLevel>` برای چگالی با ۴ گزینه («فشرده / معمولی / راحت / بزرگ»).
   - **کارت پیش‌نمایش زنده** که فقط داخل خودش `MediaQuery(textScaler:)` را با مقدار انتخابی جایگزین می‌کند و یک عنوان + متن بدنه + دکمه + ردیف لیست + چیپ نمونه نشان می‌دهد.
   - دکمهٔ «بازگردانی به پیش‌فرض» → `themeRepository.resetAppearance()`.
   - `Semantics(label:…, value:…)` روی اسلایدر و رعایت `minTouchTarget`.
2. **`lib/features/settings/presentation/widgets/quick_settings_sheet.dart`** — یک ردیف دسترسی سریع «اندازهٔ متن» (سه‌حالته: کوچک/معمولی/بزرگ) در کنار سوییچ OLED.
3. **`lib/features/onboarding/presentation/steps/step_focus.dart`** *(اختیاری، فاز ۵)* — یک گام «راحتی خواندن» با سه پیش‌تنظیم برای کاربران کم‌بینا.

### گروه D — نقاط پرخطر که مقیاس‌پذیری خودکار ندارند

این‌ها باید صریحاً پارامتری شوند، وگرنه در مقیاس بالا سرریز یا بُرش می‌دهند:

| ناحیه | فایل‌های شاخص | ریسک |
|---|---|---|
| نقاشی‌های سفارشی (Canvas) | `lib/core/widgets/ritmo_progress_ring.dart`, `lib/features/cycle/presentation/widgets/cycle_mood_chart.dart`, `lib/features/study/presentation/widgets/study_week_heatmap.dart`, `lib/features/cycle/presentation/widgets/weekly_share_card.dart` | `TextPainter` مقیاس `MediaQuery` را خودکار نمی‌گیرد؛ باید `textScaler` صریح به `TextPainter` پاس شود |
| تایم‌لاین تقویم | `lib/features/calendar/presentation/**` (به‌ویژه ارتفاع اسلات ساعت و `day_summary_bar.dart`) | ارتفاع ساعت ثابت → همپوشانی برچسب‌ها؛ از `m.hourSlotHeight` استفاده شود |
| نوار ناوبری پایین | `lib/features/today/presentation/home_navigation_shell.dart` + تست `test/features/today/ritmo_nav_bar_height_test.dart` | ارتفاع ثابت؛ تست موجود باید به «سقف/کمینه» به‌روزرسانی شود |
| کارت‌های Hero | `sleep_hero.dart`, `konkur_hero.dart`, `energy_hero.dart`, `cycle_hero_card.dart`, `cycle_orb_card.dart` | `fontSize: 44` عدد قهرمان + ارتفاع ثابت → `FittedBox`/`AutoSize` منطق لازم دارد |
| گریدهای داشبورد | `lib/features/today/presentation/widgets/dashboard/zone_card.dart` | `childAspectRatio` قفل‌شده → مهاجرت به `RitmoAdaptiveGrid` |
| حباب چت | `lib/features/chat/**`, `chatBubbleMaxWidthFactor = 0.76` | در مقیاس ۱.۴ نیاز به کاهش padding افقی |
| ویجت اندروید و اعلان‌ها | `android/**` (App Widget)، `lib/core/notifications/**` | Flutter رندر نمی‌کند؛ **خارج از دامنهٔ فاز ۱–۴**. در فاز ۵ مقدار `ui_text_scale` از طریق `SharedPreferences` به لایهٔ نیتیو پل شود و در `RemoteViews` روی `setTextViewTextSize` اعمال گردد |
| اسپلش و صفحهٔ خطای بوت | `lib/features/onboarding/presentation/splash_screen.dart`, `lib/main.dart` (پنل خطا), `lib/core/observability/ritmo_friendly_error_pane.dart` | پیش از آماده شدن تنظیمات رندر می‌شوند → باید با مقیاس پیش‌فرض ایمن باشند |
| کارت‌های اشتراک‌گذاری/خروجی | `weekly_share_card.dart`, `pregnancy_report.dart` | اندازهٔ خروجی تصویر باید **مستقل از تنظیم کاربر** ثابت بماند (پیوست ۲) |

---

## ۵. فازبندی اجرا و معیار پذیرش

### فاز ۰ — خط پایه و گارد (نیم‌روز)
- افزودن دو متریک به `tool/theme_audit.dart`:
  - `rawFontSize` → `RegExp(r'fontSize:\s*\d')` روی `lib/features/`.
  - `rawGeometryLiteral` → `RegExp(r'(EdgeInsets\.(all|symmetric|only)\(\s*\d)|(SizedBox\(\s*(height|width):\s*\d)')` روی `lib/features/`.
- اجرای `dart run tool/theme_audit.dart --update-baseline` و کامیت `tool/theme_baseline.json`.
- **پذیرش:** `dart run tool/theme_audit.dart --check` سبز است و اعداد پایه در گزارش `docs/theme_migration.md` ثبت شده‌اند.

### فاز ۱ — توکن و منطق (۱ روز)
- گروه A بندهای ۱، ۲، ۳، ۵، ۷ (بدون تغییر UI).
- تست‌های واحد `test/theme/ui_scale_test.dart`: پله‌ها، کلَمپ، ضرب در مقیاس OS، parse/serialize با ورودی خراب، `lerp`.
- **پذیرش:** `flutter test test/theme` سبز؛ هیچ تغییر بصری‌ای در اپ دیده نمی‌شود (فقط زیرساخت).

### فاز ۲ — اتصال زنده (۱ روز)
- گروه A بندهای ۴، ۶، ۸، ۹ + گروه C بند ۱.
- **پذیرش:**
  1. تغییر اسلایدر → کل اپ بی‌درنگ و بدون ری‌استارت تغییر می‌کند.
  2. مقدار پس از بستن و باز کردن اپ حفظ می‌شود (تست roundtrip روی DB).
  3. `theme_mode`/`palette` هنوز درست کار می‌کنند (رگرسیون نداشتن `_themeInputsKey`).
  4. تعداد بازساخت تم روی هر تغییر دقیقاً ۱ بار است (تست شمارش `build`).

### فاز ۳ — پریمیتیوهای مشترک (۲ روز)
- گروه B کامل.
- گلدن‌های `test/golden/component_gallery_golden_test.dart` برای سه چگالی بازتولید و مرور می‌شوند.
- **پذیرش:** در ماتریس ۴ ویوپورت × {۰.۹، ۱.۰، ۱.۳} × {compact, comfortable, xl} هیچ `RenderFlex overflowed` رخ نمی‌دهد.

### فاز ۴ — ماژول‌های پرترافیک (۳–۵ روز، ترتیب اولویت)
ترتیب پیشنهادی بر مبنای بازدید کاربر: `today` → `routines` → `calendar` → `goals` → `study/courses` → `cycle/health` → `worship` → `chat/assistant` → بقیه.
در هر ماژول: حذف `TextStyle(fontSize:)` محلی به‌نفع `context.t.*`، تبدیل `EdgeInsets` عددی به `context.space.*`، تبدیل گریدهای ستون‌ثابت به `RitmoAdaptiveGrid`، تبدیل ارتفاع‌های ثابت به سقف.
- **پذیرش هر ماژول:** متریک‌های `rawFontSize`/`rawGeometryLiteral` کاهش یافته (baseline پایین آورده شده) + تست پاسخ‌گویی ماژول سبز.

### فاز ۵ — ارتقای سقف و لبه‌ها (۲ روز)
- `supportedMaxTextScale: 1.3 → 1.6` و `supportedMinTextScale: 0.9 → 0.85`.
- پل نیتیو برای ویجت اندروید و اعلان‌ها.
- گام آنبوردینگ «راحتی خواندن».
- **پذیرش:** ماتریس کامل ۴×۴×۴ سبز؛ هیچ متن بریده‌شده‌ای در حالت `xl + 1.6` در ۱۰ صفحهٔ اصلی دیده نمی‌شود.

---

## ۶. تست‌ها و گاردها

### فایل‌های تست جدید

| فایل | پوشش |
|---|---|
| `test/theme/ui_scale_test.dart` | فرمول‌ها، کلَمپ، پله‌ها، `lerp`، parse ایمن |
| `test/theme/metrics_tokens_test.dart` | یکنوایی (monotonic) اعداد: `compact < comfortable < spacious < xl`، `touchTarget >= 48` در همهٔ سطوح، شبکهٔ ۴ پیکسلی |
| `test/settings/ui_scale_settings_test.dart` | وجود توصیفگرها، پیش‌فرض‌ها، `requiresRestart == false`، اعمال زنده از طریق `SettingsService.changes`، حضور در Export/Import |
| `test/widget/ui_scale_matrix_test.dart` | `testAcrossViewports` × مقیاس متن × چگالی روی ۱۰ صفحهٔ کلیدی با `expectNoOverflow` |
| `test/golden/ui_scale_gallery_golden_test.dart` | گلدن گالری کامپوننت‌ها در ۳ چگالی × ۲ مقیاس متن |
| `test/guards/ui_scale_guards_test.dart` | ممنوعیت `MediaQuery.copyWith(textScaler:` خارج از `lib/main.dart`؛ ممنوعیت `fontSize:` تازه در فایل‌های مهاجرت‌شده |

### به‌روزرسانی تست‌های موجود
- `test/features/today/ritmo_nav_bar_height_test.dart` → از «ارتفاع دقیق» به «بازهٔ مجاز تابع چگالی».
- `test/settings/settings_text_scale_resilience_test.dart` و `test/features/calendar/calendar_text_scale_test.dart` → افزودن حالت چگالی `xl`.
- `test/support/responsive_harness.dart` → افزودن پارامتر `density` به هارنس (پیش‌فرض `comfortable` تا تست‌های فعلی نشکنند).

---

## ۷. ریسک‌ها و راه‌کاهش

| ریسک | احتمال | کاهش |
|---|---|---|
| مقیاس دوبار اعمال شود (اپ × سیستم × ویجت محلی) | بالا | تنها یک نقطهٔ تزریق در `main.dart` + گارد تست روی `textScaler` |
| سرریز چیدمان در `xl + 1.6` | بالا | ماتریس تست، `RitmoAdaptiveGrid/Row`، قانون «ارتفاع سقف است» |
| افت کارایی به‌خاطر بازساخت تم | متوسط | کش `_themeInputsKey`، `RepaintBoundary`، `const` نگه‌داشتن استایل‌های ثابت |
| شکستن گلدن‌ها | قطعی | بازتولید عامدانه در فاز ۳ با مرور بصری، در یک کامیت جدا |
| ناهمگونی با ویجت/اعلان نیتیو | متوسط | صریحاً خارج از دامنهٔ فاز ۱–۴ و مستندشده |
| از دست رفتن مقدار کاربر در Import پشتیبان قدیمی | کم | `scope: db` + مقدار پیش‌فرض ایمن در نبود کلید |

**برگشت‌پذیری:** تمام تغییر رفتاری پشت مقدار پیش‌فرض `100% + comfortable` است؛ با ثابت‌نگه‌داشتن این دو مقدار، رندر خروجی با امروز یکسان می‌شود. در صورت نیاز، مخفی‌سازی UI با یک فلگ در `lib/core/settings/settings_flags.dart` کافی است.

---

## ۸. برآورد

| فاز | حجم | تخمین |
|---|---|---|
| ۰ گارد | ۲ فایل | ۰.۵ روز |
| ۱ توکن و منطق | ۵ فایل + ۲ تست | ۱ روز |
| ۲ اتصال زنده | ۵ فایل | ۱ روز |
| ۳ پریمیتیوها | ~۱۵ فایل | ۲ روز |
| ۴ ماژول‌ها | تدریجی | ۳–۵ روز |
| ۵ سقف ۱.۶ + نیتیو | ~۸ فایل | ۲ روز |
| **جمع** | | **~۱۰ روز کاری** |

---

## پیوست ۱ — جدول نگاشت مقادیر

| توکن | compact ×0.92 | comfortable ×1.00 | spacious ×1.12 | xl ×1.24 |
|---|---|---|---|---|
| `space.xs` (4) | 4 | 4 | 4 | 6 |
| `space.sm` (8) | 8 | 8 | 10 | 10 |
| `space.md` (12) | 12 | 12 | 14 | 16 |
| `space.lg` (16) | 14 | 16 | 18 | 20 |
| `space.xl` (24) | 22 | 24 | 28 | 30 |
| `space.xxl` (32) | 30 | 32 | 36 | 40 |
| `space.xxxl` (48) | 44 | 48 | 54 | 60 |
| `icon.md` (20) | 18 | 20 | 22 | 24 |
| `icon.lg` (24) | 22 | 24 | 28 | 30 |
| `touchTarget` (48) | 48 | 48 | 54 | 60 |
| `radius.card` (16) | 16 | 16 | 17 | 18 |
| `rowHeight` (56) | 52 | 56 | 62 | 68 |
| `navBarHeight` (64) | 60 | 64 | 70 | 76 |

| پلهٔ متن | ضریب | برچسب فارسی |
|---|---|---|
| ۱ | 0.85 | خیلی کوچک |
| ۲ | 0.925 | کوچک |
| ۳ | 1.00 | معمولی (پیش‌فرض) |
| ۴ | 1.10 | بزرگ |
| ۵ | 1.25 | خیلی بزرگ |
| ۶ | 1.40 | بیشینه |

## پیوست ۲ — موارد صریحاً مستثنا

۱. تصاویر اشتراک‌گذاری و گزارش‌های خروجی (باید اندازهٔ ثابت داشته باشند تا خروجی بین کاربران یکسان بماند).
۲. اسپلش و پنل خطای پیش از بوت (تنظیمات هنوز بارگذاری نشده است).
۳. ویجت اندروید، اعلان دائمی و آلارم نیتیو (فاز ۵).
۴. `debugShowCheckedModeBanner` و صفحات `lib/features/dev/**`.

## پیوست ۳ — به‌روزرسانی اسناد پس از اجرا

- `docs/RITMO_DESIGN_TOKENS.md` → بخش جدید «۷. مقیاس زمان‌اجرا (RitmoMetrics)» + علامت‌گذاری `RitmoSpacing`/`RitmoRadius` به‌عنوان مقادیر مرجع طراحی.
- `docs/ui/RESPONSIVE_LAYOUT.md` → به‌روزرسانی بخش ۵ (سیاست مقیاس متن) و ماتریس تست با محور چگالی.
- `docs/CONSTITUTION.md` → افزودن قانون «هیچ `fontSize` تازه‌ای در `lib/features` مجاز نیست».
- `README.md` → یک خط در ویژگی‌های کلیدی: دسترس‌پذیری و کنترل اندازهٔ متن/المان.
