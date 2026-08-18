# پرامپت اجرایی: پیش‌بینی چندچرخه‌ای و نمایش ماه‌های آینده در تقویم «چرخه بدن» — پروژهٔ ریتمو

> **مخاطب:** ایجنت کدنویس.
> **دامنهٔ کار:** `lib/features/cycle/**` و `lib/core/domain/engines/cycle_engine.dart`.
> **خروجی:** تقویم چرخه باید برای **هر ماهی که کاربر به آن پیمایش می‌کند** پیش‌بینی داشته باشد، نه فقط یک دورهٔ بعدی. پیش‌بینی باید از داده‌های موتورهای موجود ساخته شود، نه از فرض‌های تازه.

---

## ۰. قواعد اجرای اجباری

**۰-۱.** این فایل خودِ نقشهٔ پیاده‌سازی است. **نقشهٔ پیاده‌سازی ننویس.** سند برنامه‌ریزی، پیش‌نویس طراحی، تحلیل اولیه، یا فایل «پلن» تولید نکن.

**۰-۲.** **بند ۲ فایل `.agents/AGENTS.md` (چرخهٔ اجباری سه‌مرحله‌ای پیش‌نویس ← ارزیابی ← بازنویسی) برای این مأموریت صریحاً لغو شده است.** بند ۱ (تحلیل عمیق پیش از تغییر) و بند ۳ (صفر خطا و صفر هشدار) کاملاً معتبر می‌مانند.

**۰-۳.** ترتیب فازها قفل است. فاز N+1 پیش از سبز شدن دروازهٔ پذیرش فاز N شروع نمی‌شود.

**۰-۴.** هر مورد `F-xx` باید در پایان دقیقاً یکی از این سه وضعیت را داشته باشد: `انجام شد` / `منتفی شد` / `مسدود شد`. حالت چهارم وجود ندارد.

**۰-۵.** **داده جعل نکن.** این مهم‌ترین قاعدهٔ این فایل است. پیش‌بینی چرخهٔ قاعدگی یک ادعای سلامتی است. هیچ عدد پیش‌فرضی نباید به‌جای دادهٔ واقعی جا زده شود. اگر نمی‌دانیم، خروجی `null` است و رابط کاربری باید «نمی‌دانیم» را صادقانه نشان دهد.

**۰-۶.** **عدم‌قطعیت باید با فاصله رشد کند.** پیش‌بینی چرخهٔ ششم نمی‌تواند به همان قطعیت چرخهٔ اول نمایش داده شود. هر پیاده‌سازی‌ای که همهٔ چرخه‌های آینده را با یک ظاهر یکسان بکشد، رد است.

**۰-۷.** از موتورهای موجود استفاده کن، موتور جدید موازی نساز. فهرست موتورهای موجود در بخش ۰-۹ آمده است. اگر خروجی یک موتور برای پیش‌بینی لازم است ولی در تایپ خروجی نیست، آن فیلد را **به همان موتور اضافه کن**؛ محاسبهٔ تکراری در لایهٔ بالاتر ممنوع است.

**۰-۸.** ممنوعیت‌های مطلق در کل دامنهٔ کار:
- `catch (_) {}` و `catch (e) {}` بدون لاگ.
- `debugPrint(`.
- `DateTime.now()` مستقیم داخل موتور یا ویجت — زمان باید تزریق شود.
- `DateTime.parse(...)` و `toIso8601String().substring(0, 10)` — همه‌چیز از `CycleDateContract` عبور می‌کند.
- `fontSize:` و `Color(0x...)` هاردکد در ویجت‌های تقویم.
- رشتهٔ فارسی هاردکد در لایهٔ نمایش.
- پکیج جدید در `pubspec.yaml`.

**۰-۹. موتورهای موجود که باید مصرف شوند (نه بازنویسی):**

| موتور | فایل | چه چیزی می‌دهد |
|---|---|---|
| `CycleEngine` | `lib/core/domain/engines/cycle_engine.dart` | `avgCycleLength`، `avgPeriodDuration`، `completedCycles`، `regularityScore`، `regularityLevel`، `dataMaturity`، `discardedOutliers`، `trendPoints` |
| `CycleDataQualityEngine` | `logic/cycle_data_quality_engine.dart` | `DataQualityReport`: `qualityLevel`، `hasEnoughCycles`، `hasPredictionConfidence`، `hasForgottenOpenPeriod`، `warningCodes` |
| `CycleAnomalyDetector` | `logic/cycle_anomaly_detector.dart` | `CycleAnomaly`: چرخهٔ کوتاه/بلند غیرعادی، خونریزی طولانی، تأخیر |
| `CyclePersonalPatternEngine` | `logic/cycle_personal_pattern_engine.dart` | `SymptomForecast`: `symptomKey`، `likelyCycleDay`، `confidence` |
| `CycleDateContract` | `logic/cycle_date_contract.dart` | `toDayKey`، `parseDayKey`، `daysBetween`، `cleanDate`، `isSameDay`، `isSameOrBefore`، `isSameOrAfter`، `inWindow` |
| `CycleSettings` | `logic/cycle_settings.dart` | کلیدهای متعارف و بازه‌های مجاز |

**۰-۱۰.** سه فرمان تأیید در پایان هر فاز، بدون خطا و بدون هشدار:
```bash
flutter analyze
flutter test
dart format --set-exit-if-changed lib test
```

**۰-۱۱.** یک کامیت به ازای هر فاز. قالب: `feat(cycle): phase N — <خلاصه> [F-xx, F-yy]`.

---

## ۰-۱۲. تشخیص ریشه‌ای (چرا فقط یک دوره نمایش داده می‌شود)

این بخش را بخوان و دوباره تحلیل نکن. علت دقیقاً مشخص است.

### علت یکم — موتور فقط یک عدد تولید می‌کند

در `CycleEngine._evaluateWithStart`:

```dart
if (!needsUserAttention) {
  var cyclesElapsedForPrediction = (daysSinceStart / L).ceil();
  if (cyclesElapsedForPrediction < 1) cyclesElapsedForPrediction = 1;
  nextPeriodPrediction = cleanStart.add(
    Duration(days: cyclesElapsedForPrediction * L),
  );

  predictedOvulation = nextPeriodPrediction.subtract(
    Duration(days: lutealDays),
  );
  fertileStart = predictedOvulation.subtract(const Duration(days: 5));
  fertileEnd = predictedOvulation.add(const Duration(days: 1));
  ...
}
```

یک `nextPeriodPrediction`. یک `predictedOvulation`. یک `fertileStart/End`. یک `pmsWindowStart/End`. تایپ `CycleEngineOutput` هم همین را منعکس می‌کند — همهٔ این فیلدها `DateTime?` **مفرد** هستند، نه `List`. موتور اصلاً ظرفی برای چرخهٔ دوم به بعد ندارد.

### علت دوم — تقویم فقط همان یک عدد را می‌خواند

در `cycle_calendar_view.dart`:

```dart
bool _checkIsPredictedDay(DateTime date) {
  if (widget.engineOutput == null) return false;
  final nextPeriod = widget.engineOutput!.nextPeriodPrediction;
  if (nextPeriod == null) return false;
  ...
  final diff = cleanDate.difference(cleanNextPeriod).inDays;
  return diff >= 0 && diff < pDur;
}
```

`_checkIsOvulationDay` یک مقایسهٔ تساوی با یک روز است. `_checkIsFertileDay` و `_checkIsPmsDay` هرکدام یک بازهٔ واحد. پس حتی اگر موتور فهرست بدهد، تقویم آن را نمی‌خواند.

### علت سوم — پیمایش ماه هیچ محاسبه‌ای را دوباره اجرا نمی‌کند

`CycleStateNotifier.loadState()` موتور را **یک بار** با `now: DateTime.now()` اجرا می‌کند. `onMonthChanged` فقط `calendarMonth` را عوض می‌کند و `engineOutput` دست‌نخورده می‌ماند. بنابراین کاربر هرچقدر جلو برود، همان یک پیش‌بینی ثابت را دارد و بقیهٔ ماه‌ها خالی‌اند.

### علت چهارم — بهترین خروجی موتور اصلاً مصرف نمی‌شود

موتور `nextPeriodWindowStart` و `nextPeriodWindowEnd` را محاسبه می‌کند (بازهٔ عدم‌قطعیت)، ولی **هیچ‌جای تقویم آن را نمی‌کشد**. این یعنی ارزشمندترین خروجی آماری موجود، دادهٔ مرده است.

### علت پنجم — مدل عدم‌قطعیت فعلی آماری نیست

```dart
final minL = cycleLengths.reduce(math.min);
final maxL = cycleLengths.reduce(math.max);
...
if (winEnd.difference(winStart).inDays > 7) {
  winStart = nextPeriodPrediction.subtract(const Duration(days: 3));
  winEnd = nextPeriodPrediction.add(const Duration(days: 3));
}
```

از `min`/`max` استفاده شده که حساس‌ترین آمارهٔ ممکن به داده پرت است، و بعد اگر بازه از ۷ روز عبور کند به ±۳ روز **قیچی** می‌شود. یعنی هرچه چرخهٔ کاربر نامنظم‌تر باشد، اپ با اطمینان بیشتری حرف می‌زند. این وارونهٔ رفتار درست است. انحراف معیار (`sd`) در `_computeRegularity` محاسبه می‌شود ولی به بیرون داده نمی‌شود.

---

## ۰-۱۳. تصمیم‌های قطعی معماری

این هفت تصمیم گرفته شده‌اند. بازطراحی نکن.

**ت-۱.** یک تایپ جدید `PredictedCycle` ساخته می‌شود که یک چرخهٔ آینده را کامل توصیف می‌کند. `CycleEngineOutput` یک فیلد `List<PredictedCycle> forecast` می‌گیرد.

**ت-۲.** فیلدهای مفرد فعلی (`nextPeriodPrediction`، `ovulationDay`، `fertileWindowStart/End`، `pmsWindowStart/End`، `nextPeriodWindowStart/End`) **حذف نمی‌شوند**. آن‌ها به getter تبدیل می‌شوند که از `forecast.first` مشتق می‌گردند. هیچ مصرف‌کنندهٔ فعلی نباید بشکند.

**ت-۳.** لنگر پیش‌بینی همیشه **آخرین شروع دورهٔ واقعی ثبت‌شده** است، نه امروز. چرخهٔ k ام: `anchor + round(k × L)`.

**ت-۴.** عدم‌قطعیت با ریشهٔ دوم فاصله رشد می‌کند: `sigma(k) = sd × sqrt(k)`. این مدل گام تصادفی است و برای تجمع خطای چرخه‌ای درست است. `sd` از همان `_computeRegularity` می‌آید و باید روی خروجی expose شود.

**ت-۵.** افق پیش‌بینی **پویا** است. پیش‌فرض ۱۲ چرخه، ولی وقتی کاربر به ماهی فراتر از افق فعلی پیمایش می‌کند، افق کشیده می‌شود. سقف مطلق: ۲۴ چرخه.

**ت-۶.** اطمینان با فاصله افت می‌کند و این افت باید **دیده شود**. سه پلهٔ گسسته (نه محو پیوسته) تا خوانایی و کنتراست حفظ شود.

**ت-۷.** تقویم دیگر به‌ازای هر خانه روی همهٔ دوره‌ها حلقه نمی‌زند. یک `Map<String, CycleDayMark>` یک‌بار ساخته می‌شود و هر خانه با `O(1)` خوانده می‌شود.

---

## فاز ۰ — قرارداد داده

### F-01 — تایپ `PredictedCycle`

**تصمیم قطعی:** فایل جدید `lib/features/cycle/models/cycle_forecast_models.dart`:

```dart
enum ForecastBasis {
  measured,            // sd از >= 3 چرخهٔ کامل واقعی
  partiallyMeasured,   // 1..2 چرخهٔ کامل؛ sd قابل اتکا نیست
  defaultAssumption,   // هیچ چرخهٔ کاملی نیست؛ فقط تنظیمات
}

class PredictedCycle {
  const PredictedCycle({
    required this.index,
    required this.predictedStart,
    required this.predictedEnd,
    required this.windowStart,
    required this.windowEnd,
    required this.sigmaDays,
    required this.periodDays,
    required this.confidence,
    required this.confidenceLevel,
    required this.basis,
    this.ovulationDay,
    this.fertileStart,
    this.fertileEnd,
    this.pmsStart,
    this.pmsEnd,
  });

  final int index;               // 1 = نزدیک‌ترین چرخهٔ آینده
  final DateTime predictedStart;
  final DateTime predictedEnd;   // predictedStart + periodDays - 1
  final DateTime windowStart;    // predictedStart - round(sigmaDays)
  final DateTime windowEnd;      // predictedStart + round(sigmaDays)
  final double sigmaDays;
  final int periodDays;
  final double confidence;       // 0..1
  final PredictionConfidenceLevel confidenceLevel;
  final ForecastBasis basis;
  final DateTime? ovulationDay;
  final DateTime? fertileStart;
  final DateTime? fertileEnd;
  final DateTime? pmsStart;
  final DateTime? pmsEnd;
}
```

`PredictionConfidenceLevel` از `models/cycle_intelligence_models.dart` می‌آید و **دوباره تعریف نمی‌شود**.

**معیار پذیرش:** `grep -rn "enum PredictionConfidenceLevel" lib/` دقیقاً یک نتیجه بدهد.

### F-02 — نشانهٔ روز تقویم

**تصمیم قطعی:** در همان فایل:

```dart
enum CycleDayKind {
  actualPeriod,
  predictedPeriod,
  predictionWindow,   // بازهٔ عدم‌قطعیت، بیرون از باند اصلی
  ovulation,
  fertile,
  pms,
}

class CycleDayMark {
  const CycleDayMark({
    required this.kind,
    this.cycleIndex,        // null برای روزهای واقعی
    this.confidence,        // null برای روزهای واقعی
    this.hasLog = false,
  });

  final CycleDayKind kind;
  final int? cycleIndex;
  final double? confidence;
  final bool hasLog;
}
```

**قاعدهٔ اولویت رنگ‌آمیزی** (بالاترین برنده است، بدون استثنا):
`actualPeriod` › `predictedPeriod` › `ovulation` › `predictionWindow` › `fertile` › `pms`

### F-03 — expose کردن انحراف معیار

**واقعیت فعلی:** `_computeRegularity` مقدار `sd` را محاسبه می‌کند ولی فقط `score` و `level` را برمی‌گرداند.

**تصمیم قطعی:** به `CycleRegularity` فیلد `final double? sdDays;` اضافه کن و در `CycleEngineOutput` فیلد `final double? cycleLengthSd;` قرار بده. وقتی `cycleLengths.length < 3` است، هر دو `null` می‌مانند — **مقدار جایگزین نگذار**.

### F-04 — تعداد چرخه‌های کامل روی خروجی

**تصمیم قطعی:** `CycleEngineOutput` باید `stats.completedCycles` را داشته باشد (دارد) و علاوه بر آن `final DateTime? forecastAnchor;` که همان آخرین شروع دورهٔ واقعی است. اگر هیچ دوره‌ای ثبت نشده، `null`.

### F-05 — تزریق ساعت

**تصمیم قطعی:** `CycleEngineInput.now` هم‌اکنون وجود دارد و درست است. ولی `CycleStateNotifier.loadState()` مقدار `DateTime.now()` را مستقیم می‌سازد. یک `CycleClock` سبک با `static DateTime Function() nowProvider = DateTime.now;` بساز و همه‌جا از آن استفاده کن تا تست‌های فاز ۵ بتوانند زمان را ثابت کنند.

**معیار پذیرش:** `grep -rn "DateTime.now()" lib/features/cycle/ lib/core/domain/engines/cycle_engine.dart` فقط داخل `CycleClock` نتیجه بدهد.

### F-06 — رفع باگ اثرانگشت کش

**واقعیت فعلی:** در `CycleEngine.fingerprint`:

```dart
final avgLen = input.appSettings['cycle_avg_length'] ?? '28';
final avgPeriod = input.appSettings['cycle_avg_period'] ?? '6';
final pmsWindow = input.appSettings['cycle_pms_window_days'] ?? '4';
```

ولی `CycleSettings.setCycleLength` کلید متعارف `cycle_length_days` را می‌نویسد و **عمداً `cycle_avg_length` را حذف می‌کند**. نتیجه: اثرانگشت همیشه `28|6` است، و چون `ttl` برابر ۶۰ دقیقه است، **تغییر طول چرخه در تنظیمات تا یک ساعت هیچ اثری روی پیش‌بینی ندارد**.

**تصمیم قطعی:** اثرانگشت را از `CycleSettings.getCycleLength/getPeriodDuration/getLutealPhase` و `keyPmsWindowDays` بساز، و `forecastAnchor` و `completedCycles` را هم در آن بگنجان تا ثبت یک دورهٔ جدید بلافاصله کش را باطل کند.

**معیار پذیرش:** تست: طول چرخه را از ۲۸ به ۳۱ تغییر بده، موتور را دوباره اجرا کن، `forecast.first.predictedStart` باید تغییر کند.

### F-07 — حذف `catch (_) {}` از مسیر باطل‌سازی

**واقعیت فعلی:**
```dart
@override
void invalidate() {
  try {
    RitmoEngineBus.instance.invalidate(CycleEngine);
  } catch (_) {}
}
```
و در `CycleStateNotifier.loadState`:
```dart
} catch (_) {
  final fallbackEngine = CycleEngine();
  engineOutput = await fallbackEngine.calculate(cycleInput);
}
```

**تصمیم قطعی:** هر دو باید با `RitmoLogger.error(...)` لاگ شوند. سقوط به موتور پشتیبان مجاز است، ولی خاموش بودنش نه.

### 🚦 دروازهٔ پذیرش فاز ۰

- [ ] `cycle_forecast_models.dart` با `PredictedCycle`، `ForecastBasis`، `CycleDayMark`، `CycleDayKind` ساخته شده.
- [ ] `cycleLengthSd` و `forecastAnchor` روی `CycleEngineOutput` موجودند و وقتی داده کافی نیست `null`اند.
- [ ] `CycleClock` ساخته شده و گرپ `DateTime.now()` تمیز است.
- [ ] اثرانگشت کش از کلیدهای متعارف ساخته می‌شود و تست تغییر طول چرخه سبز است.
- [ ] هیچ `catch (_) {}` در دامنهٔ کار نمانده.
- [ ] سه فرمان تأیید سبز.

---

## فاز ۱ — موتور پیش‌بینی چندچرخه‌ای

این قلب کار است. منطق در `CycleEngine` می‌ماند (موتور جداگانه نساز)، ولی در یک متد خصوصی مستقل و خالص جمع می‌شود تا قابل تست باشد.

### F-08 — امضای تابع تولید پیش‌بینی

**تصمیم قطعی:** در `cycle_engine.dart`:

```dart
@visibleForTesting
static List<PredictedCycle> buildForecast({
  required DateTime anchorStart,     // آخرین شروع دورهٔ واقعی
  required int cycleLength,          // L
  required int periodDays,
  required int lutealDays,
  required int pmsWindowDays,
  required double? sdDays,           // null => قابل محاسبه نیست
  required int completedCycles,
  required int? regularityScore,
  required String dataMaturity,      // LOW / MEDIUM / HIGH
  required int discardedOutliers,
  required int horizonCycles,
  required DateTime now,
  required bool fertilityVisible,
})
```

این تابع **خالص** است: نه دیتابیس، نه `DateTime.now()`، نه `async`.

### F-09 — حلقهٔ چرخه‌ها

**واقعیت فعلی:** یک محاسبه، با `cyclesElapsedForPrediction`.

**تصمیم قطعی:** ابتدا مشخص کن اولین چرخهٔ آینده کدام است، بعد از آنجا تا افق جلو برو:

```dart
final daysSinceAnchor = CycleDateContract.daysBetween(anchorStart, now);
var firstK = (daysSinceAnchor / cycleLength).ceil();
if (firstK < 1) firstK = 1;

final out = <PredictedCycle>[];
for (var i = 0; i < horizonCycles; i++) {
  final k = firstK + i;
  final start = anchorStart.add(Duration(days: k * cycleLength));
  ...
  out.add(PredictedCycle(index: i + 1, predictedStart: start, ...));
}
```

**دقت کن:** `index` موقعیت **نسبت به امروز** است (۱ = نزدیک‌ترین آینده)، ولی `k` موقعیت **نسبت به لنگر** است. این دو را قاطی نکن. عدم‌قطعیت بر پایهٔ `k` محاسبه می‌شود نه `index`، چون خطا از لنگر تجمیع می‌شود.

### F-10 — مدل عدم‌قطعیت

**تصمیم قطعی:** مدل گام تصادفی:

```dart
static const double _minSigmaDays = 0.5;
static const double _maxSigmaDays = 12.0;
static const double _fallbackSigmaDays = 3.5;

double sigmaFor(int k, double? sdDays) {
  final base = (sdDays == null || sdDays <= 0) ? _fallbackSigmaDays : sdDays;
  final raw = base * math.sqrt(k);
  return raw.clamp(_minSigmaDays, _maxSigmaDays);
}
```

قواعد الزامی:
1. `windowStart = predictedStart - round(sigma)`، `windowEnd = predictedStart + round(sigma)`. پنجره **متقارن حول پیش‌بینی** است. منطق فعلی که پنجره را از `anchor + minL` تا `anchor + maxL` می‌ساخت **حذف می‌شود**.
2. منطق قیچی کردن به ±۳ روز وقتی پنجره از ۷ روز رد می‌شود **حذف می‌شود**. دادهٔ نامنظم باید پنجرهٔ پهن بدهد، نه پنجرهٔ جعلی باریک.
3. `_fallbackSigmaDays` فقط وقتی مجاز است که `basis != ForecastBasis.measured`، و در آن حالت `confidenceLevel` اجباراً `low` است.

**معیار پذیرش:** تستی که ثابت کند برای هر `i`، `forecast[i+1].sigmaDays >= forecast[i].sigmaDays` (مگر هر دو به سقف رسیده باشند).

### F-11 — محاسبهٔ اطمینان از دادهٔ موتورها

**قاعدهٔ مطلق:** عدد اطمینان **هرگز** هاردکد نمی‌شود. از ورودی‌های واقعی موتورها ساخته می‌شود.

**تصمیم قطعی:** پایه را از سه مؤلفه بساز، بعد با فاصله میرا کن:

```dart
// 1) کیفیت نظم — از CycleEngine._computeRegularity
double regularityFactor;
if (regularityScore == null) {
  regularityFactor = 0.35;            // داده ناکافی
} else {
  regularityFactor = regularityScore / 100.0;
}

// 2) بلوغ داده — از CycleEngine.dataMaturity
final maturityFactor = switch (dataMaturity) {
  'HIGH' => 1.0,
  'MEDIUM' => 0.8,
  _ => 0.55,
};

// 3) نویز داده — از discardedOutliers
final noisePenalty = (discardedOutliers == 0)
    ? 1.0
    : (1.0 - (discardedOutliers * 0.06)).clamp(0.6, 1.0);

final base = (regularityFactor * maturityFactor * noisePenalty).clamp(0.0, 1.0);

// میرایی با فاصله
final confidence = (base / (1.0 + 0.18 * (k - 1))).clamp(0.0, 1.0);
```

نگاشت به سطح:
```dart
final level = confidence >= 0.66
    ? PredictionConfidenceLevel.high
    : (confidence >= 0.38
        ? PredictionConfidenceLevel.medium
        : PredictionConfidenceLevel.low);
```

هر سه ضریب (`0.18`، `0.66`، `0.38`) باید به صورت `static const` نام‌دار در بالای کلاس با کامنت توضیحی تعریف شوند، نه عدد برهنه در دل تابع.

### F-12 — تعیین `ForecastBasis`

**تصمیم قطعی:**
```dart
final basis = completedCycles >= 3
    ? ForecastBasis.measured
    : (completedCycles >= 1
        ? ForecastBasis.partiallyMeasured
        : ForecastBasis.defaultAssumption);
```
عدد ۳ با `CyclePersonalPatternEngine.minCompletedCycles` و آستانهٔ `insufficientData` در `_computeRegularity` و `DataQualityReport.hasEnoughCycles` هم‌خوان است و باید یکی بماند. یک ثابت مشترک `CycleSettings.minCyclesForReliableForecast = 3` بساز و هر چهار جا از آن استفاده کن.

### F-13 — تخمین تخمک‌گذاری، باروری و PMS برای هر چرخه

**تصمیم قطعی:** همان فرمول‌های موجود، ولی برای هر `k`:

```dart
final ovulation = start.subtract(Duration(days: lutealDays));
final fertileStart = ovulation.subtract(const Duration(days: 5));
final fertileEnd = ovulation.add(const Duration(days: 1));
final pmsStart = start.subtract(Duration(days: pmsWindowDays));
final pmsEnd = start.subtract(const Duration(days: 1));
```

قید `lutealDays = math.min(lutealPhaseSetting, math.max(1, L - 10))` که در `_evaluateWithStart` هست باید عیناً حفظ شود.

**قاعدهٔ حریم خصوصی:** اگر `fertilityVisible == false` (کلید `CycleSettings.keyFertilityVisible`)، مقادیر `ovulationDay`، `fertileStart`، `fertileEnd` باید `null` باشند. **این هم‌اکنون رعایت نمی‌شود** — تقویم بدون توجه به این کلید، روز تخمک‌گذاری و پنجرهٔ باروری را می‌کشد.

### F-14 — پایان دورهٔ پیش‌بینی‌شده از داده، نه تنظیمات

**واقعیت فعلی:** تقویم پهنای باند را از `CycleSettings.getPeriodDuration(widget.settings)` می‌گیرد، ولی موتور `avgPeriodDuration` واقعی را از داده محاسبه می‌کند. این دو می‌توانند فرق کنند و می‌کنند.

**تصمیم قطعی:** `periodDays` در `PredictedCycle` همان `pDuration` موتور است (میانگین واقعی، clamp شده به `minPeriodDuration..maxPeriodDuration`). تقویم دیگر حق ندارد خودش این را بخواند؛ فقط `predictedStart..predictedEnd` را مصرف می‌کند.

**معیار پذیرش:** `grep -n "getPeriodDuration" lib/features/cycle/presentation/widgets/cycle_calendar_view.dart` بدون نتیجه.

### F-15 — افق پویا

**تصمیم قطعی:**
```dart
static const int defaultHorizonCycles = 12;
static const int maxHorizonCycles = 24;
```
موتور پیش‌فرض `defaultHorizonCycles` می‌سازد. وقتی کاربر به ماهی پیمایش کند که فراتر از `forecast.last.predictedEnd` است، لایهٔ وضعیت افق را تا سقف `maxHorizonCycles` کش می‌دهد (فاز ۲). فراتر از سقف، تقویم پیام صریح «فراتر از افق پیش‌بینی» نشان می‌دهد و چیزی نمی‌کشد. ساکت ماندن ممنوع است.

### F-16 — رفتار در حالت تأخیر و `dataStale`

**واقعیت فعلی:**
```dart
final needsUserAttention =
    (!isBleeding && (missedCycles >= 2 || daysOverdue >= 45));
...
if (!needsUserAttention) { /* همهٔ پیش‌بینی‌ها */ }
```
یعنی کاربری که دو چرخه عقب افتاده، **تقویم کاملاً خالی** می‌بیند. دقیقاً در لحظه‌ای که بیشترین نیاز به اطلاعات دارد، اپ لال می‌شود.

**تصمیم قطعی:** این رفتار عوض می‌شود:
- در `needsUserAttention`، `forecast` **خالی نمی‌شود**. حداکثر **۳** چرخه تولید می‌شود، همه با `confidenceLevel = low`.
- `sigmaDays` در این حالت با ضریب `1.5` پهن‌تر می‌شود (پس از clamp).
- `CyclePhase.dataStale` دست‌نخورده می‌ماند تا لایهٔ نمایش بتواند بنر هشدار را هم‌زمان نشان دهد.

**منطق:** نشان دادن یک تخمین صریحاً کم‌اطمینان بهتر از تقویم خالی بدون توضیح است.

### F-17 — حالت‌های سرکوب کامل

**تصمیم قطعی:** `forecast` دقیقاً در این چهار حالت خالی است و در هیچ حالت دیگری:
1. `isPregnancyMode == true`
2. `hasData == false` (هیچ دوره‌ای ثبت نشده)
3. ماژول غیرفعال یا محرمانگی مسدود (همان مسیر `_emptyOutput`)
4. `forecastAnchor == null`

در هر چهار حالت، تقویم باید **پیام دلیل‌دار** نشان دهد، نه شبکهٔ خالی بدون توضیح.

### 🚦 دروازهٔ پذیرش فاز ۱

- [ ] `buildForecast` خالص است (نه DB، نه `DateTime.now()`، نه `async`).
- [ ] `CycleEngineOutput.forecast` پر می‌شود و طولش در حالت عادی `12` است.
- [ ] تست گسترش عدم‌قطعیت: `sigmaDays` صعودی یا ثابت، هرگز نزولی.
- [ ] تست میرایی اطمینان: `forecast[i+1].confidence <= forecast[i].confidence`.
- [ ] هیچ عدد اطمینان ثابتی در کد نیست: `grep -rn "confidence: 0\." lib/` بدون نتیجه.
- [ ] حالت بارداری و بدون‌داده فهرست خالی می‌دهند؛ حالت تأخیر فهرست ۳تایی کم‌اطمینان.
- [ ] فیلدهای مفرد قدیمی هنوز کار می‌کنند و با `forecast.first` یکی هستند.
- [ ] سه فرمان تأیید سبز.

---

## فاز ۲ — اتصال به لایهٔ وضعیت، کش، و کش‌دادن افق

### F-18 — مصرف افق در `CycleStateNotifier`

**واقعیت فعلی:** `loadState()` یک‌بار موتور را اجرا می‌کند و `CycleState` هیچ مفهومی از «ماهی که کاربر دارد نگاه می‌کند» ندارد.

**تصمیم قطعی:** به `CycleState` اضافه کن:
```dart
final int horizonCycles;   // پیش‌فرض CycleEngine.defaultHorizonCycles
```
و به `CycleStateNotifier` متد:
```dart
Future<void> ensureHorizonCovers(DateTime lastVisibleDay);
```
رفتار: اگر `lastVisibleDay` از `forecast.last.predictedEnd` جلوتر است، `horizonCycles` را تا حد لازم (سقف `maxHorizonCycles`) بالا ببر، کش را باطل کن و دوباره محاسبه کن. اگر افق فعلی کافی است، **هیچ کاری نکن** و `notifyListeners` صدا نزن.

**معیار پذیرش:** تست: پیمایش به ماه ۱۸ ماه بعد باعث شود `forecast.length` رشد کند؛ پیمایش به ماه بعد باعث هیچ محاسبهٔ دوباره‌ای نشود.

### F-19 — اثرانگشت باید افق را ببیند

**تصمیم قطعی:** `horizonCycles` باید جزئی از `CycleEngineInput` و جزئی از `fingerprint()` باشد. وگرنه کش ۶۰ دقیقه‌ای، درخواست کش‌دادن افق را بلع می‌کند و F-18 بی‌اثر می‌شود.

### F-20 — اتصال `CycleDataQualityEngine` به مسیر پیش‌بینی

**واقعیت فعلی:** `CycleDataQualityEngine.evaluateDataQuality` در محاسبهٔ پیش‌بینی مصرف نمی‌شود، درحالی‌که دقیقاً `hasPredictionConfidence` و `hasForgottenOpenPeriod` دارد.

**تصمیم قطعی:** `CycleState` باید `DataQualityReport? dataQuality` داشته باشد و `loadState()` آن را پر کند. دو قاعدهٔ الزامی:
- اگر `hasForgottenOpenPeriod == true`، لنگر مشکوک است. کل `forecast` باید `confidenceLevel = low` شود و تقویم بانر «دورهٔ باز ثبت‌نشده» با دکمهٔ اصلاح نشان دهد.
- `qualityLevel` باید در `noisePenalty` یا به صورت ضریب چهارم در محاسبهٔ F-11 لحاظ شود.

### F-21 — اتصال `CycleAnomalyDetector` به اطمینان

**تصمیم قطعی:** اگر در خروجی `detectAnomalies` یک آیتم با `severity == CycleAnomalySeverity.consultClinician` وجود دارد، سقف `confidenceLevel` کل `forecast` برابر `medium` می‌شود، و اگر نوع آن `highVariabilityTrend` یا `abnormallyShortCycle` یا `abnormallyLongCycle` باشد، `sigmaDays` با ضریب `1.25` پهن‌تر می‌شود.

**منطق:** موتور تشخیص ناهنجاری الان فقط پیام هشدار تولید می‌کند. دانش آن باید به کیفیت پیش‌بینی هم تزریق شود.

### F-22 — زنده کردن `CyclePersonalPatternEngine`

**واقعیت فعلی:** `CyclePersonalPatternEngine.computePersonalForecasts` از `CycleStateNotifier` **هرگز صدا زده نمی‌شود**. یک موتور کامل با منطق آماری واقعی که در مسیر تقویم مرده است.

**تصمیم قطعی:** `CycleState` باید `List<SymptomForecast> symptomForecasts` داشته باشد، و `loadState()` آن را پر کند. در تقویم (فاز ۳)، روزهای پیش‌بینی‌شده‌ای که `likelyCycleDay` آن‌ها با یک `SymptomForecast` مطابقت دارد، یک نشانگر کوچک متمایز می‌گیرند و در شیت جزئیات روز توضیح داده می‌شوند.

**دقت:** این موتور `async` و دیتابیس‌خوان است. در `loadState()` صدا زده می‌شود، **نه** در `build`.

### F-23 — باطل‌سازی پس از تغییر داده

**تصمیم قطعی:** `startPeriod`، `endPeriod`، `deletePeriod` و هر مسیری که `cycle_periods` را دستکاری می‌کند، باید قبل از `loadState()` مجدد، `CycleEngine().invalidate()` را صدا بزند. امروز این کار به اثرانگشت معیوب (F-06) تکیه دارد و قابل اطمینان نیست.

### F-24 — زمان‌بند یادآوری هم باید چندچرخه‌ای شود

**تصمیم قطعی:** `logic/cycle_reminder_scheduler.dart` را بررسی کن. اگر فقط برای `nextPeriodPrediction` یکتا یادآوری می‌چیند، آن را به مصرف `forecast` منتقل کن با این قیدها:
- حداکثر برای **۳ چرخهٔ اول** یادآوری زمان‌بندی می‌شود. اعلان برای چرخهٔ دوازدهم آزاردهنده و بی‌معناست.
- چرخه‌های با `confidenceLevel == low` اصلاً یادآوری نمی‌گیرند.
- یادآوری‌های قبلی پیش از زمان‌بندی دوباره لغو می‌شوند (جلوگیری از انباشت).

### 🚦 دروازهٔ پذیرش فاز ۲

- [ ] `ensureHorizonCovers` پیاده شده و در حالت کافی بودن افق، بازسازی را تریگر نمی‌کند.
- [ ] `horizonCycles` در اثرانگشت موتور حضور دارد.
- [ ] `dataQuality` و `symptomForecasts` روی `CycleState` پر می‌شوند.
- [ ] `grep -rn "computePersonalForecasts" lib/` حداقل یک مصرف‌کنندهٔ واقعی نشان دهد.
- [ ] یادآوری‌ها حداکثر برای ۳ چرخه و فقط بالای آستانهٔ اطمینان چیده می‌شوند.
- [ ] سه فرمان تأیید سبز.

---

## فاز ۳ — بازنویسی موتور رنگ‌آمیزی تقویم

### F-25 — حذف چهار تابع تک‌هدفه

**تصمیم قطعی:** این چهار تابع حذف می‌شوند:
`_checkIsPredictedDay` ، `_checkIsOvulationDay` ، `_checkIsFertileDay` ، `_checkIsPmsDay`

جایگزین آن‌ها یک سازندهٔ خالص است:

```dart
@visibleForTesting
static Map<String, CycleDayMark> buildMonthMarks({
  required Jalali month,
  required List<Map<String, dynamic>> periods,
  required Set<String> loggedDayKeys,
  required List<PredictedCycle> forecast,
});
```

کلید نقشه، `CycleDateContract.toDayKey(...)` است.

**معیار پذیرش:** `grep -n "_checkIs" lib/features/cycle/presentation/widgets/cycle_calendar_view.dart` بدون نتیجه.

### F-26 — پیش‌محاسبه به‌جای حلقه در هر خانه

**واقعیت فعلی:** داخل `GridView.builder`، هر خانه هر چهار تابع را صدا می‌زند، و `_checkIsPeriodDay` روی همهٔ دوره‌ها حلقه می‌زند، و `_checkHasLog` روی همهٔ لاگ‌ها. یعنی `O(31 × (P + L))` در هر بیلد. با اضافه شدن ۱۲ چرخهٔ پیش‌بینی، این منفجر می‌شود.

**تصمیم قطعی:** نقشه در `didUpdateWidget`/`initState` یک‌بار ساخته و در فیلد وضعیت نگه داشته می‌شود. بازساخت فقط وقتی که `calendarMonth` یا `periods` یا `dayLogs` یا `engineOutput` عوض شود. هر خانه `marks[dayKey]` را با `O(1)` می‌خواند.

**معیار پذیرش:** داخل `itemBuilder` هیچ `for`، `where`، `any` یا `firstWhere` روی `periods`/`dayLogs`/`forecast` نباشد.

### F-27 — تبدیل لاگ‌ها به مجموعه

**واقعیت فعلی:**
```dart
final dateStr = dayGregorian.toIso8601String().substring(0, 10);
```
و `_checkHasLog` که روی `widget.dayLogs` خطی می‌گردد و هم `l['logDate']` هم `l['dateIso']` را امتحان می‌کند.

**تصمیم قطعی:** یک‌بار `Set<String> loggedDayKeys` بساز با `CycleDateContract.parseDayKey(...)` بعد `CycleDateContract.toDayKey(...)`. هر دو نام ستون را همان‌جا نرمال کن. `substring(0, 10)` حذف می‌شود.

### F-28 — حذف `DateTime.parse` خام از تقویم

**واقعیت فعلی:** در `_checkIsPeriodDay`:
```dart
final pStart = DateTime.parse(p['startDate'] as String);
```
اگر `startDate` تهی یا بدشکل باشد، این خط در میانهٔ `build` پرتاب می‌کند و کل صفحه قرمز می‌شود. همچنین قرارداد C-02 را نقض می‌کند.

**تصمیم قطعی:** همه با `CycleDateContract.parseDayKey` که `null`-ایمن است. ردیف نامعتبر رد می‌شود، نه اینکه برنامه را بشکند.

**معیار پذیرش:** `grep -n "DateTime.parse\|toIso8601String" lib/features/cycle/presentation/widgets/cycle_calendar_view.dart` بدون نتیجه.

### F-29 — رندر بازهٔ عدم‌قطعیت

**تصمیم قطعی:** روزهای داخل `[windowStart, windowEnd]` که بیرون از `[predictedStart, predictedEnd]` هستند، `CycleDayKind.predictionWindow` می‌گیرند و با **حاشیهٔ خط‌چین بدون پر‌شدگی** رندر می‌شوند.

این دقیقاً همان داده‌ای است که موتور امروز می‌سازد و دور می‌ریزد. پیام کاربری: «این‌جا محتمل‌ترین روز است، ولی ممکن است در این بازه جابجا شود.»

### F-30 — سه پلهٔ تأکید بصری بر اساس اطمینان

**تصمیم قطعی:** بر اساس `confidenceLevel` (نه `index`، چون کاربر منظم می‌تواند در چرخهٔ پنجم هم اطمینان خوبی داشته باشد):

| سطح | پر‌شدگی | حاشیه | متن |
|---|---|---|---|
| `high` | پر، کدر | پیوسته | کامل |
| `medium` | نیمه‌کدر | پیوستهٔ نازک | کامل |
| `low` | بدون پر‌شدگی | خط‌چین | کم‌رنگ |

**قید الزامی:** محو پیوستهٔ آلفا (مثلاً `alpha: confidence`) **ممنوع** است. در چرخهٔ دهم متن عملاً ناخوانا می‌شود و کنتراست WCAG رد می‌شود. سه پلهٔ گسسته، و شمارهٔ روز همیشه با کنتراست کامل.

### F-31 — احترام به کلید نمایش باروری

**واقعیت فعلی:** `CycleSettings.keyFertilityVisible` تعریف شده است ولی تقویم آن را نمی‌خواند و روز تخمک‌گذاری و پنجرهٔ باروری را بدون قید رنگ می‌کند.

**تصمیم قطعی:** طبق F-13 موتور این مقادیر را `null` می‌کند، پس تقویم خودبه‌خود درست می‌شود. علاوه بر آن، ردیف‌های مربوطه در راهنمای تقویم هم باید مخفی شوند، وگرنه راهنما چیزی را توضیح می‌دهد که روی شبکه نیست.

### F-32 — تمایز قطعی دادهٔ ثبت‌شده از حدس

**تصمیم قطعی:** روز واقعی قاعدگی و روز پیش‌بینی‌شده **هرگز** نباید شبیه هم باشند. تفاوت باید فراتر از رنگ باشد (شکل حاشیه یا الگو)، چون بخشی از کاربران کوررنگی دارند و این تمایز معنای پزشکی دارد.

### F-33 — پاک‌سازی انتخاب هنگام تغییر ماه

**واقعیت فعلی:** `_selectedDay` وقتی کاربر ماه را عوض می‌کند پاک نمی‌شود، پس یک روز در ماهی دیگر انتخاب‌شده باقی می‌ماند.

**تصمیم قطعی:** در `_changeMonth` و `_goToCurrentMonth`، اگر `_selectedDay` در ماه جدید نیست، `null` شود.

### F-34 — دسترسی‌پذیری خانه‌ها

**تصمیم قطعی:** هر خانهٔ تقویم باید `Semantics(label: ...)` داشته باشد که تاریخ شمسی، نوع روز، و اگر پیش‌بینی است **سطح اطمینان** را بگوید. کاربر صفحه‌خوان باید بتواند واقعی را از حدسی تشخیص دهد — امروز این اطلاعات فقط بصری است.

### 🚦 دروازهٔ پذیرش فاز ۳

- [ ] تقویم برای ماه جاری، ماه بعد، و ماه ششم بعد **محتوا دارد**.
- [ ] `buildMonthMarks` خالص و قابل تست مستقل است.
- [ ] داخل `itemBuilder` هیچ پیمایش لیستی نیست.
- [ ] `grep -n "DateTime.parse\|toIso8601String\|_checkIs" cycle_calendar_view.dart` بدون نتیجه.
- [ ] بازهٔ عدم‌قطعیت رندر می‌شود.
- [ ] وقتی `cycle_fertility_visible` خاموش است، نه روی شبکه و نه در راهنما اثری از باروری نیست.
- [ ] سه فرمان تأیید سبز.

---

## فاز ۴ — رابط کاربری، راهنما، و صداقت پیام

### F-35 — راهنمای تقویم باید واقعیت را بگوید

**واقعیت فعلی:** راهنما شش ردیف دارد و ردیف پیش‌بینی، «پیش‌بینی دوره بعدی» (مفرد) است. هیچ ردیفی برای بازهٔ عدم‌قطعیت یا سطح اطمینان وجود ندارد.

**تصمیم قطعی:** راهنما باید شامل این موارد شود:
- قاعدگی ثبت‌شده (دادهٔ واقعی)
- دورهٔ پیش‌بینی‌شده
- بازهٔ احتمالی جابجایی
- پیش‌بینی با اطمینان کم
- روز تخمک‌گذاری (مشروط به F-31)
- پنجرهٔ باروری (مشروط به F-31)
- روزهای پیش از عادت
- امروز
- علائم ثبت‌شده

راهنما باید **پویا** باشد: ردیفی که در ماه جاری مصداق ندارد، نمایش داده نمی‌شود. راهنمای ثابت ۹ ردیفی، نویز بصری است.

### F-36 — نشانگر اطمینان در سربرگ ماه

**تصمیم قطعی:** وقتی کاربر به ماهی می‌رود که فقط محتوای پیش‌بینی‌شده دارد (هیچ دادهٔ واقعی)، کنار نام ماه یک چیپ کوچک با سطح اطمینان غالب آن ماه نشان داده می‌شود.

**منطق UX:** کاربری که شش ماه جلو رفته باید بدون تپ کردن بفهمد که دارد به حدس نگاه می‌کند، نه به واقعیت.

### F-37 — دکمهٔ پرش به دورهٔ بعدی

**تصمیم قطعی:** کنار دکمهٔ موجود «بازگشت به ماه جاری»، یک دکمهٔ ثانویه برای پرش به ماه `forecast.first.predictedStart` اضافه کن. امروز کاربر باید دستی سوایپ کند تا برسد.

### F-38 — شیت جزئیات روز پیش‌بینی‌شده

**تصمیم قطعی:** تپ روی یک روز پیش‌بینی‌شده باید شیتی باز کند که صریحاً می‌گوید:
- این یک تخمین است، نه دادهٔ ثبت‌شده.
- بازهٔ احتمالی: از `windowStart` تا `windowEnd`.
- مبنای تخمین: تعداد چرخهٔ کامل ثبت‌شده و میانگین طول چرخه.
- اگر `SymptomForecast` مرتبط وجود دارد (F-22)، علائم محتمل آن روز.
- دکمهٔ «ثبت دوره از این روز» تا حدس به داده تبدیل شود.

**قید:** این شیت باید `predictionDisclaimer` موجود در `CycleEngineOutput` را مصرف کند، نه متن تازه.

### F-39 — حالت‌های خالی دلیل‌دار

**تصمیم قطعی:** طبق F-17، برای هر چهار حالت سرکوب پیام مختصر متمایز زیر شبکه نمایش داده می‌شود:

| حالت | پیام و کنش |
|---|---|
| بدون داده | دعوت به ثبت اولین دوره + دکمهٔ ثبت |
| کمتر از ۳ چرخه | تخمین نمایش داده می‌شود ولی با برچسب صریح «مبتنی بر دادهٔ کم» |
| حالت بارداری | توضیح اینکه پیش‌بینی غیرفعال است |
| فراتر از افق | توضیح سقف افق پیش‌بینی |

شبکهٔ خالی بدون توضیح، در هیچ‌یک از این حالت‌ها قابل قبول نیست.

### F-40 — انتقال رشته‌ها به l10n

**واقعیت فعلی:** تمام رشته‌های تقویم هاردکدند: نام روزهای هفته، «بازگشت به ماه جاری»، عنوان راهنما، و هر شش برچسب راهنما.

**تصمیم قطعی:** همه به `lib/l10n/app_fa.arb` و `app_en.arb` منتقل می‌شوند، به همراه رشته‌های جدید F-35 تا F-39. `flutter gen-l10n` اجرا می‌شود.

**معیار پذیرش:** هیچ رشتهٔ فارسی‌ای داخل `cycle_calendar_view.dart` نمانده باشد.

### F-41 — حذف اعداد طراحی هاردکد

**واقعیت فعلی:** `fontSize: 19`، `15`، `12.5`، `11.5`، `18.5`، `15.5`، `13.5` و ده‌ها `withValues(alpha: ...)` با اعداد جادویی در همین یک فایل.

**تصمیم قطعی:** همه به `RitmoTextStyles` و توکن‌های تم منتقل می‌شوند. سه پلهٔ اطمینان (F-30) باید به صورت توکن نام‌دار در لایهٔ تم تعریف شوند، نه عدد برهنه در ویجت.

### F-42 — هماهنگی با کارت‌های موجود

**تصمیم قطعی:** `cycle_prediction_confidence_card.dart` و `cycle_personal_forecast_card.dart` باید از همین منبع جدید تغذیه شوند. دو محاسبهٔ موازی از اطمینان ممنوع است. عددی که کارت نشان می‌دهد باید دقیقاً همان عددی باشد که تقویم بر اساسش رنگ می‌زند.

### 🚦 دروازهٔ پذیرش فاز ۴

- [ ] راهنما پویا است و ردیف بی‌مصداق نشان نمی‌دهد.
- [ ] چیپ اطمینان در ماه‌های کاملاً پیش‌بینی‌شده دیده می‌شود.
- [ ] شیت جزئیات روز پیش‌بینی‌شده بازهٔ احتمالی و مبنا را می‌گوید.
- [ ] هر چهار حالت خالی پیام دارند.
- [ ] `flutter gen-l10n` بدون خطا؛ رشتهٔ فارسی هاردکد در تقویم نیست.
- [ ] `grep -n "fontSize:" cycle_calendar_view.dart` بدون نتیجه.
- [ ] سه فرمان تأیید سبز.

---

## فاز ۵ — تست‌های نگهبان

الگوی موجود را تقلید کن: `test/prompt_036_source_guards_test.dart` و `test/unit/**`.

### F-43 — تست طول افق

با ۶ دورهٔ منظم ۲۸ روزه، `forecast.length == 12` باشد و `forecast[0].predictedStart` دقیقاً ۲۸ روز بعد از آخرین شروع باشد، و `forecast[11].predictedStart` دقیقاً ۳۳۶ روز بعد.

### F-44 — تست گسترش عدم‌قطعیت

برای هر `i`: `forecast[i + 1].sigmaDays >= forecast[i].sigmaDays`. و با دادهٔ نامنظم، `forecast[0].sigmaDays` باید **بزرگ‌تر** از حالت منظم باشد. این تست دقیقاً باگ قیچی کردن به ±۳ روز را می‌گیرد.

### F-45 — تست میرایی اطمینان

برای هر `i`: `forecast[i + 1].confidence <= forecast[i].confidence`. و در دادهٔ با `dataMaturity == 'LOW'`، هیچ عضوی `PredictionConfidenceLevel.high` نگیرد.

### F-46 — تست پوشش ماه دور

`buildMonthMarks` برای ماه ششم آینده باید حداقل یک کلید با `kind == CycleDayKind.predictedPeriod` برگرداند. **این تستی است که دقیقاً مشکل گزارش‌شدهٔ کاربر را قفل می‌کند.**

### F-47 — تست اولویت رنگ‌آمیزی

روزی که هم‌زمان دورهٔ واقعی و پیش‌بینی است، باید `actualPeriod` بگیرد. دادهٔ واقعی همیشه بر حدس مقدم است.

### F-48 — تست اثرانگشت کش

تغییر `cycle_length_days` از `28` به `31` باید بلافاصله `forecast.first.predictedStart` را جابجا کند. این تست F-06 را قفل می‌کند.

### F-49 — تست DST و مرز روز

با تاریخ‌هایی که از مرز تغییر ساعت رسمی عبور می‌کنند، طول چرخهٔ محاسبه‌شده نباید ۱ روز خطا بدهد. `CycleDateContract.daysBetween` برای همین ساخته شده — تست ثابت کند که مسیر جدید هم از آن عبور می‌کند.

### F-50 — تست نگهبان منبع

یک تست که محتوای فایل‌ها را می‌خواند و می‌شکند اگر:
- `cycle_calendar_view.dart` شامل `DateTime.parse`، `toIso8601String`، `fontSize:`، یا `_checkIs` باشد.
- هر فایلی در `lib/features/cycle/` شامل `catch (_) {}` باشد.
- `cycle_engine.dart` شامل `'cycle_avg_length'` یا `'cycle_avg_period'` باشد (کلیدهای منسوخ).

### 🚦 دروازهٔ پذیرش فاز ۵

- [ ] هر هشت تست F-43 تا F-50 نوشته شده و سبزند.
- [ ] تست‌ها زمان را از `CycleClock` تزریق می‌کنند، نه `DateTime.now()`.
- [ ] هیچ تست موجودی نشکسته باشد.
- [ ] سه فرمان تأیید سبز.

---

## ۶. قواعد کامیت

یک کامیت به ازای هر فاز، پس از سبز شدن دروازه:

```
feat(cycle): phase 0 — قرارداد پیش‌بینی و رفع اثرانگشت کش [F-01..F-07]
feat(cycle): phase 1 — موتور پیش‌بینی چندچرخه‌ای [F-08..F-17]
feat(cycle): phase 2 — افق پویا و اتصال موتورها [F-18..F-24]
feat(cycle): phase 3 — بازنویسی موتور رنگ‌آمیزی تقویم [F-25..F-34]
feat(cycle): phase 4 — رابط کاربری و صداقت پیام [F-35..F-42]
test(cycle): phase 5 — تست‌های نگهبان پیش‌بینی [F-43..F-50]
```

کامیت با تست قرمز یا هشدار باز ممنوع است.

---

## ۷. خلاصهٔ قطعی و تکرار قاعدهٔ اصلی

مشکل گزارش‌شده سه لایه دارد و هر سه باید حل شوند؛ حل یکی کافی نیست:

1. **موتور** فقط یک `DateTime?` تولید می‌کند ← فاز ۰ و ۱.
2. **لایهٔ وضعیت** مفهوم «ماه قابل مشاهده» را نمی‌شناسد ← فاز ۲.
3. **تقویم** فقط همان یک عدد را می‌خواند ← فاز ۳ و ۴.

و در پایان، سه قاعده‌ای که نباید فراموش کنی:

**الف.** پیش‌بینی باید از دادهٔ موتورهای موجود بیاید: `regularityScore`، `dataMaturity`، `discardedOutliers`، `completedCycles`، انحراف معیار واقعی، `DataQualityReport`، و `CycleAnomaly`. هیچ عدد اطمینان ثابتی ننویس.

**ب.** عدم‌قطعیت با فاصله **رشد** می‌کند و این رشد باید روی صفحه **دیده شود**. پیش‌بینی چرخهٔ دوازدهم نباید مثل چرخهٔ اول قطعی به نظر برسد.

**ج.** این یک ویژگی سلامت است. کاربر بر اساس این تقویم برنامه‌ریزی می‌کند. تمایز میان «این را ثبت کردی» و «این را حدس می‌زنیم» باید در هر خانه از تقویم، بدون استثنا، قطعی باشد.

**تکرار نهایی:** نقشهٔ پیاده‌سازی ننویس. بند ۲ فایل `.agents/AGENTS.md` لغو است. از فاز ۰ شروع کن و به ترتیب جلو برو.
