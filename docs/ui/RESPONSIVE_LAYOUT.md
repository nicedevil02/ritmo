# معماری چیدمان پاسخ‌گو و دسترس‌پذیری ریتمو (Ritmo Responsive Layout Architecture)

این سند مرجع واحد اصول، کلاس‌های اندازه، گریدها، شیت‌ها و قواعد تست چیدمان پاسخ‌گو در اپلیکیشن ریتمو است (`R-01` … `R-92`).

---

## ۱. کلاس‌های اندازه و نقطه‌شکست‌ها (Breakpoints)

تمامی تعاریف هندسی در کلاس [`RitmoBreakpoints`](file:///c:/Users/bahman/Desktop/Besme-Allah/Ritmo3/ritmo/lib/core/theme/tokens/ritmo_breakpoints.dart) متمرکز هستند.

### کلاس‌های عرض (`RitmoWidthClass`)
| کلاس | محدوده عرض منطقی (Logical Px) | نمونه دستگاه‌های واقعی |
|---|---|---|
| `compact` | تا ۳۵۹ پیکسل | iPhone SE (1st gen), Samsung Galaxy A01 Core, گوشی‌های باریک |
| `regular` | ۳۶۰ تا ۴۰۹ پیکسل | iPhone 13/14/15, Samsung Galaxy S22/S23/S24, مرجع استاندارد طراحی |
| `large` | ۴۱۰ تا ۵۹۹ پیکسل | iPhone Pro Max/Plus, Samsung Galaxy Ultra, Pixel Pro |
| `expanded` | ۶۰۰ پیکسل و بالاتر | iPad Mini/Air, تبلت‌های اندرویدی, چرخش افقی (Landscape) |

### کلاس‌های ارتفاع قابل استفاده (`RitmoHeightClass`)
| کلاس | محدوده ارتفاع قابل استفاده | شرایط و دستگاه‌های نمونه |
|---|---|---|
| `short` | تا ۶۳۹ پیکسل | iPhone SE, نمایشگرهای کوتاه, یا **هر دستگاهی در زمان باز بودن صفحه‌کلید** |
| `regular` | ۶۴۰ تا ۸۴۳ پیکسل | گوشی‌های متداول در حالت عادی |
| `tall` | ۸۴۴ پیکسل و بالاتر | گوشی‌های بلند و تبلت‌ها |

---

## ۲. قانون طلایی: «ارتفاع سقف است، نه مقدار»

### ❌ الگوی اشتباه (باعث سرریز صلب در گوشی‌های کوتاه یا زمان باز شدن کیبورد):
```dart
// نادرست: ارتفاع صلب و وابسته به کل نمایشگر
Container(
  height: MediaQuery.of(context).size.height * 0.85,
  child: Column(
    children: [
      header,
      Expanded(child: ListView(...)),
      saveButton,
    ],
  ),
)
```

### ✅ الگوی صحیح (با استفاده از `RitmoSheetScaffold` یا `RitmoBreakpoints`):
```dart
// درست: ارتفاع سقف است و محتوا اسکرول‌پذیر با دکمه در فوتر
RitmoSheetScaffold.present(
  context: context,
  title: 'عنوان شیت',
  maxHeightFactor: 0.9,
  footer: saveButton,
  builder: (context) => ListView(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    children: items,
  ),
);
```

---

## ۳. قانون گرید: «عرض کمینهٔ خانه، نه شمار ستون ثابت»

در گرید با شمار ستون ثابت مانند `crossAxisCount: 4` و `childAspectRatio: 2.2` در عرض ۳۲۰ منطقی:
- عرض هر ستون: `(320 - 3 * 12) / 4 = 71` پیکسل.
- ارتفاع خانه: `71 / 2.2 = 32` پیکسل.
- در مقیاس متن `1.3x` یا `1.6x`، یک متن دو خطی به بیش از ۵۰ پیکسل ارتفاع نیاز دارد؛ بنابراین قفل بودن نسبت ابعاد منجر به سرریز حتمی (`RenderFlex overflowed`) می‌شود.

### راه‌حل استاندارد: [`RitmoAdaptiveGrid`](file:///c:/Users/bahman/Desktop/Besme-Allah/Ritmo3/ritmo/lib/core/widgets/ritmo_adaptive_grid.dart)
محاسبه پویای ستون‌ها بر مبنای کمینه عرض مورد نیاز هر خانه (`tileMinWidth`) با چیدمان بر مبنای `Wrap` که ارتفاع سطر از بلندترین محتوای آن به صورت خودکار تعیین می‌گردد.

---

## ۴. ماتریس ۱۲ حالته تست‌های استاندارد پاسخ‌گویی

تمام ویجت‌های کلیدی در ماتریس ۴ نمای دید × ۳ مقیاس متن اعتبارسنجی می‌شوند:

| نمای دید (Viewport) | ابعاد (Px) | مقیاس ۱.۰x | مقیاس ۱.۳x | مقیاس ۱.۶x |
|---|---|---|---|---|
| `compact-short` | 320 × 568 | ✅ | ✅ | ✅ |
| `compact` | 360 × 640 | ✅ | ✅ | ✅ |
| `regular` | 390 × 844 | ✅ | ✅ | ✅ |
| `large` | 430 × 932 | ✅ | ✅ | ✅ |

ابزار تست: [`testAcrossViewports`](file:///c:/Users/bahman/Desktop/Besme-Allah/Ritmo3/ritmo/test/support/responsive_harness.dart) و [`expectNoOverflow`](file:///c:/Users/bahman/Desktop/Besme-Allah/Ritmo3/ritmo/test/support/responsive_harness.dart).

---

## ۵. سیاست مقیاس متن و چگالی المان‌ها (Text & Density Scaling Policy)

- مبدأ تعیین سقف و کف مجاز: `RitmoBreakpoints.supportedMinTextScale` (۰.۸۵) و `RitmoBreakpoints.supportedMaxTextScale` (۱.۳۰ فعلی؛ ۱.۶۰ پس از تکمیل ماتریس مقیاس).
- دو محور مستقل مقیاس:
  ۱. **اندازهٔ متن (`ui_text_scale`):** منحصراً از طریق `MaterialApp.builder` به `MediaQuery.textScaler` تزریق می‌شود و شامل ۶ پله استاندارد (۸۵٪ تا ۱۴۰٪) با قابلیت پیروی از مقیاس سیستم‌عامل (`ui_text_follow_os`).
  ۲. **چگالی المان‌ها (`ui_density`):** فواصل، اهداف لمس و رادیوس‌ها را از طریق اکستنشن `RitmoMetrics` و `VisualDensity` در تم مدیریت می‌کند (شامل ۴ چگالی: `compact`, `comfortable`, `spacious`, `xl`).
- تمام ویجت‌های سفارشی و بوم‌های ترسیمی با `FittedBox` یا `context.metrics` محافظت می‌شوند تا در سقف مقیاس بدون سرریز رندر شوند.

### قوانین تکمیلی سیستم مقیاس (Scale & Density Rules)

- **`R-93` (No Raw Font Size in Features):** هیچ `fontSize` تازه‌ای در لایهٔ `lib/features` مجاز نیست و کلیهٔ متن‌ها باید از تایپوگرافی ساختاریافتهٔ تم (`context.t.*` یا `RitmoTextStyles`) استفاده کنند.
- **`R-94` (Minimum Touch Target Floor):** هدف لمس برای تمامی عناصر تعاملی و دکمه‌ها هرگز نباید از ۴۸ پیکسل (`RitmoBreakpoints.minTouchTarget` / `context.metrics.touchTarget`) کمتر شود.
- **ماتریس تست ۱۶ حالته:** ۴ ویوپورت × ۴ مقیاس متن × ۴ سطح چگالی (پیاده‌سازی‌شده در `test/theme/ui_scale_matrix_test.dart`).
