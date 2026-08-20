# پرامپت اجرایی: رفع کامل باگ «تشخیص‌نشدن پاسخ چت‌جی‌پی‌تی» در پل وب ریتمو

> **نسخهٔ فعلی پل:** `ChatGptJsInjector.bridgeVersion = 8`
> **شناسهٔ تسک‌ها:** `DET-01` تا `DET-36` (عمداً با `A-xx` قبلی تداخل ندارد)
> **دفترچهٔ ثبت:** `docs/ai/WEB_BRIDGE_DETECTION_FIX.md`

---

## بخش ۰ — قواعد آهنین اجرا (نقض این‌ها یعنی شکست کل کار)

۱. **هیچ سند نقشه یا طرح جدیدی ننویس.** این فایل خودش نقشه است. تنها سند مجاز برای ساختن، دفترچهٔ ثبت `docs/ai/WEB_BRIDGE_DETECTION_FIX.md` است.

۲. **ترتیب اجرا دقیقاً از `DET-01` تا `DET-36` است.** فازها به هم وابسته‌اند: فاز A ابزار دقیق می‌سازد که فازهای بعدی با آن راستی‌آزمایی می‌شوند. پرش ممنوع.

۳. **هر بار فقط یک تسک.** تا وقتی تسک جاری کامل و کامیت نشده، سراغ بعدی نرو.

۴. **چرخهٔ اجباری هر تسک:** خواندن فایل‌های هدف ← اعمال تغییر ← `flutter analyze` ← نوشتن و اجرای تست ← به‌روزرسانی دفترچهٔ ثبت ← کامیت.

۵. **هر تسک دقیقاً یک کامیت** با همان پیام کامیتی که در تسک نوشته شده. نه بیشتر، نه کمتر، نه ادغام‌شده.

۶. **`catch` خالی ممنوع.** هر `catch` یا باید لاگ بزند یا رویداد ردیابی ثبت کند. در جاوااسکریپت هم `catch (e) {}` ممنوع است؛ حداقل `notifyFlutter('error', ...)` یا یک `trace` بفرست.

۷. **`debugPrint` ممنوع.** فقط `RitmoLog.debug/warning/error` با پیشوندهای `[ChatGptWebBridge]`، `[ChatGptWebBridgeManager]`، `[Agent]`.

۸. **همهٔ رشته‌های قابل نمایش به کاربر فارسی‌اند.** رشته‌های فنی داخل لاگ و trace انگلیسی می‌مانند.

۹. **هیچ `querySelector` خامی خارج از توابع کمکی مرکزی مجاز نیست.** همه‌چیز از `RITMO_SELECTORS` و توابع `querySafe` / `queryAllSafe` / `queryFirstVisible` عبور می‌کند.

۱۰. **هیچ عدد زمانی خام (literal) در جاوااسکریپت یا دارت مجاز نیست.** همهٔ مقادیر زمانی از `ChatGptBridgeTimeouts` می‌آیند و در صورت نیاز به JS تزریق می‌شوند.

۱۱. **تست‌ها فقط در این دو مسیر:** `test/core/ai/web_bridge/` برای پل، `test/core/ai/` برای لایهٔ ایجنت. مسیر `test/agent/` وجود ندارد و نباید ساخته شود.

۱۲. **اگر تسکی از قبل انجام شده**، در دفترچه وضعیت `SKIPPED` بزن و دلیل را با ارجاع به خط کد بنویس. **اگر واقعیت کد با توصیف تسک فرق دارد**، وضعیت `BLOCKED` بزن، تفاوت را دقیق بنویس و برو تسک بعد. هرگز توصیف تسک را «تقریبی» تفسیر نکن.

۱۳. **مسیرهای مجاز برای تغییر:** `lib/core/ai/web_bridge/`، `lib/core/ai/agent/`، `lib/core/ai/chat/`، `lib/features/assistant/presentation/`، `lib/core/logging/`، `test/`، `docs/ai/`. خارج از این‌ها دست نزن.

۱۴. **`flutter analyze` باید صفر issue بدهد.** با warning هم کامیت نکن.

۱۵. **هرگز محتوای گفتگو، کوکی، توکن یا هدر احراز هویت را لاگ نکن.** فقط طول متن، شناسهٔ درخواست و نوع رویداد.

۱۶. **هر `Timer`، `setInterval` و `MutationObserver` باید مسیر تخریب صریح داشته باشد.** ساختن بدون پاک‌سازی متناظر ممنوع.

۱۷. **بستهٔ جدید اضافه نکن.** `webview_flutter` نسخهٔ ۴ است؛ `WebViewController.dispose()` و `onDocumentStart` وجود ندارند.

۱۸. **در فایل‌های جاوااسکریپت تزریقی از regex با کاراکتر فرار استفاده نکن** مگر جایی که تسک صریحاً گفته. تطبیق رشته را با `indexOf` بنویس تا در فرار دادن رشته‌های دارت خراب نشود.

۱۹. **هر تغییر رفتاری باید حداقل یک تست ضدبازگشت داشته باشد** که بدون آن تغییر شکست بخورد. تست بی‌ادعا ننویس.

۲۰. **در پایان، بخش «واگرایی از پرامپت» دفترچه را پر کن.** هر جا مجبور شدی متفاوت عمل کنی، آنجا بنویس.

---

## قالب هر تسک

هر تسک دقیقاً این شش بخش را دارد و باید همه رعایت شوند:

```
**باگ:**      چه چیزی الان خراب است
**فایل‌ها:**   کدام فایل‌ها تغییر می‌کنند
**کار دقیق:**  چه کاری باید انجام شود
**معیار پذیرش:** چه چیزی باید بعد از تغییر درست باشد
**تست:**      نام دقیق فایل تست و ادعای آن
**commit:**    پیام دقیق کامیت
```

---

## فرمت دفترچهٔ ثبت

فایل `docs/ai/WEB_BRIDGE_DETECTION_FIX.md` را در همان تسک `DET-01` بساز و پس از هر تسک به‌روزرسانی کن:

```
| ID | عنوان | فاز | وضعیت | commit | یادداشت |
|----|-------|-----|-------|--------|---------|
| DET-01 | ... | A | DONE | abc1234 | ... |
```

وضعیت‌های مجاز: `TODO` / `DOING` / `DONE` / `SKIPPED` / `BLOCKED`

در انتهای فایل دو بخش اجباری:
- `## واگرایی از پرامپت`
- `## نتیجهٔ نهایی DoD`

---

## بخش ۱ — زمینه و شواهد (بخوان، ولی رویش کار نکن)

### علائم گزارش‌شدهٔ کاربر

چت‌جی‌پی‌تی در مرورگر داخلی پاسخ کامل می‌دهد، اما صفحهٔ چت دستیار هوشمند تا ابد روی لودینگ می‌ماند و هیچ متنی دریافت نمی‌کند.

### لاگ ردیابی واقعی (۱۳ رکورد)

```
[21:24:10.405] [ERROR] type=vpn_required src=unknown
[21:24:10.458] [WARN]  type=unknown_event note="type=cloudflare_resolved"
[21:24:10.460] [INFO]  type=selector_health v=8 {composer:0, sendButton:0, assistantMessage:0, ...}
[21:24:16.326] [ERROR] type=vpn_required src=unknown
[21:24:16.329] [WARN]  type=unknown_event note="type=cloudflare_resolved"
[21:24:16.330] [INFO]  type=selector_health v=8 {composer:0, sendButton:0, ...}
[21:25:12.496] [WARN]  type=unknown_event note="type=cloudflare_resolved"
[21:25:12.503] [INFO]  type=selector_health v=8 {composer:1, sendButton:9, assistantMessage:0, ...}
[21:25:12.505] [INFO]  type=ready src=unknown
[21:25:26.563] [INFO]  type=ready src=unknown
[21:25:26.878] [INFO]  type=resumed src=dom req=req_1787162114570350_1 len=0
[21:25:27.372] [INFO]  type=ready src=unknown
[21:25:27.684] [INFO]  type=resumed src=dom req=req_1787162114570350_1 len=0
(سپس ۷۴ ثانیه سکوت مطلق تا لحظهٔ خروجی‌گرفتن)
```

### استنتاج‌های قطعی از این لاگ

**الف) زمان دقیق ارسال:** شناسهٔ `req_1787162114570350_1` در `_generateRequestId()` از `microsecondsSinceEpoch` ساخته می‌شود. پس `sendPrompt` دقیقاً در **21:25:14.570** اجرا شده و همانجا `_status = generating` شده.

**ب) دو رویداد `ready` آخر از مسیر گارد گرم آمده‌اند، نه بارگذاری مجدد.** در `setupBridgeScript` وقتی `currentVersion === requiredVersion` باشد، فوراً `ready` می‌فرستد و `return` می‌کند — یعنی `runSelectorSelfTest()` اجرا نمی‌شود. نبودن `selector_health` کنار دو `ready` آخر ثابت می‌کند سند عوض نشده و فقط **ناوبری داخلی SPA** رخ داده (رفتن از `/` به `/c/<id>`).

**ج) فاصلهٔ ۳۱۵ و ۳۱۲ میلی‌ثانیه‌ای بین هر `ready` و `resumed`** دقیقاً همان `Future.delayed(300ms)` داخل `_attemptResumePendingRequest` است. آن متد فقط وقتی صدا می‌شود که `hasPendingRequest || _status == generating`. پس در ۲۱:۲۵:۲۶ قطعاً درخواست در جریان بوده.

**د) اثبات قاتل اصلی:** `checkpoint1Delay = 25s` و `checkpoint2Delay = 55s`. هر دو باید پیش از لحظهٔ خروجی‌گرفتن (۷۴ ثانیه پس از ارسال) شلیک می‌شدند و `checkpoint_check_started` می‌زدند. هیچ‌کدام در لاگ نیست. خط اول `_runCheckpointCheck` این است:

```dart
if (!identical(_currentStreamController, streamController) ||
    _status != ChatGptBridgeStatus.generating) return;  // بدون هیچ ردی
```

استریم‌کنترلر عوض نشده بود (چیزی تمام نشده بود)، پس تنها توضیح ممکن این است که `_status` دیگر `generating` نبوده.

### پنج ریشهٔ تأییدشده

| # | ریشه | محل | تسک‌های رفع |
|---|------|------|-------------|
| R-A | هندلر `ready` گارد `generating` ندارد و وضعیت را وسط تولید به `ready` برمی‌گرداند | `chatgpt_web_bridge_manager.dart` | DET-11..15 |
| R-B | `case 'error'` در `WebBridgeEvent.parse` وجود ندارد؛ پنج محل در JS آن را می‌فرستند | `web_bridge_event.dart` | DET-06..10 |
| R-C | هوک شبکه endpoint واقعی `/backend-api/f/conversation` را نمی‌گیرد | `chatgpt_js_injector.dart` | DET-16..19 |
| R-D | `__ritmo_resume` واچر را کاملاً ریست می‌کند و حافظهٔ متن را صفر می‌کند | `chatgpt_js_injector.dart` | DET-20..24 |
| R-E | `sendButton` نه کاندیدا دارد و هیچ ردی از ارسال ثبت نمی‌شود | `chatgpt_js_injector.dart` | DET-01..05، DET-25..27 |

### مقادیر فعلی `ChatGptBridgeTimeouts` (تأییدشده از مخزن)

```
bootTimeout           60s
generationTimeout    180s
inactivityTimeout      5min
firstTokenTimeout     60s
checkpoint1Delay      25s
checkpoint2Delay      55s
composerReadyTimeout   8s
heartbeatInterval    350ms
resendMaxWindow       15s
pollFastInterval     200ms
sourceRelockSilence    4s
harvestTimeout         6s
```

---

## فاز A — رصدپذیری (اول از همه، چون بدون آن لاگ بعدی هم بی‌فایده است)

---

### DET-01 — ساخت دفترچهٔ ثبت و افزودن `source` به تمام پیلودها

**باگ:** در لاگ، `ready`، `vpn_required`، `cloudflare_*` و `error` همه `src=unknown` هستند، چون `notifyFlutter` در این موارد کلید `source` را در پیلود نمی‌گذارد و `parseBridgeSource` به مقدار پیش‌فرض می‌افتد.

**فایل‌ها:** `lib/core/ai/web_bridge/chatgpt_js_injector.dart`، `docs/ai/WEB_BRIDGE_DETECTION_FIX.md`

**کار دقیق:**
1. فایل `docs/ai/WEB_BRIDGE_DETECTION_FIX.md` را با جدول خالی و هر ۳۶ ردیف `DET-01` تا `DET-36` در وضعیت `TODO` بساز.
2. در `chatgpt_js_injector.dart` تابع `notifyFlutter` را طوری تغییر بده که اگر `payload.source` تعریف نشده باشد، مقدار `'lifecycle'` را خودش بگذارد.
3. برای رویدادهایی که منبأ معنادار دارند، مقدار صریح بگذار: `ready` و `selector_health` و `auto_dismiss` با `'lifecycle'`؛ `vpn_required` و `cloudflare_challenge` و `cloudflare_resolved` با `'lifecycle'`؛ خطاهای مربوط به واچر با `'dom'`؛ خطاهای مسیر ارسال با `'dart'` نه، بلکه `'dom'`.

**معیار پذیرش:** در کل فایل اینجکتور، هیچ فراخوانی از `notifyFlutter` نباید بدون `source` به دارت برسد. هیچ خط جدیدی در لاگ نباید `src=unknown` داشته باشد.

**تست:** `test/core/ai/web_bridge/notify_payload_has_source_test.dart` — متن `ChatGptJsInjector.setupBridgeScript` و `earlyHookScript` را به عنوان رشته بخوان، همهٔ فراخوانی‌های `notifyFlutter(` را بشمار و assert کن تعداد مواردی که در پیلودشان کلمهٔ `source` هست برابر کل فراخوانی‌هاست، یا تابع `notifyFlutter` خودش مقدار پیش‌فرض می‌گذارد.

**commit:** `fix(web-bridge): always attach source to bridge event payloads (DET-01)`

---

### DET-02 — رویدادهای ردیابی مسیر ارسال پرامپت

**باگ:** هیچ رویدادی برای «متن تایپ شد»، «دکمهٔ ارسال کلیک شد»، «فالبک Enter زده شد» یا «کادر متن پیدا نشد» وجود ندارد. به همین دلیل لاگ نمی‌تواند بین «اصلاً ارسال نشد» و «ارسال شد ولی تشخیص داده نشد» تفکیک قائل شود.

**فایل‌ها:** `chatgpt_js_injector.dart`، `web_bridge_event.dart`، `chatgpt_web_bridge_manager.dart`

**کار دقیق:** در `__ritmo_sendPrompt` این چهار رویداد را با `notifyFlutter` بفرست:

- `prompt_typed` — بلافاصله پس از قرار دادن متن در کادر، با `{ length: promptText.length, requestId: reqId }`
- `send_clicked` — پس از کلیک موفق، با `{ requestId: reqId, matchedSelector: <رشتهٔ سلکتوری که مچ شد>, candidateCount: <تعداد کاندیداها> }`
- `send_fallback_enter` — وقتی دکمه پیدا نشد و رویداد کیبورد Enter ارسال شد
- `composer_not_found` — وقتی حلقهٔ انتظار کادر متن بی‌نتیجه تمام شد

در `WebBridgeEvent.parse` برای هر چهار یک کلاس بساز یا حداقل به یک `BridgeDiagnosticEvent` مشترک نگاشت کن که فقط در `BridgeTraceLog` ثبت می‌شود و روی استریم اثر ندارد. این‌ها نباید به `BridgeUnknownEvent` بیفتند.

**معیار پذیرش:** پس از یک پرسش موفق، خروجی ردیابی باید دقیقاً ترتیب `prompt_typed` سپس `send_clicked` یا `send_fallback_enter` را نشان دهد، هر دو با همان `requestId`.

**تست:** `test/core/ai/web_bridge/send_path_trace_events_test.dart` — assert کن هر چهار نوع رویداد در `WebBridgeEvent.parse` به چیزی غیر از `BridgeUnknownEvent` نگاشت می‌شوند.

**commit:** `feat(web-bridge): add send-path trace events (DET-02)`

---

### DET-03 — ضربان واچر (`watcher_tick`)

**باگ:** در ۷۴ ثانیه سکوت، هیچ راهی وجود ندارد بفهمیم واچر زنده بوده یا نه، و اگر زنده بوده چه چیزی در DOM می‌دیده.

**فایل‌ها:** `chatgpt_js_injector.dart`، `web_bridge_event.dart`، `chatgpt_web_bridge_manager.dart`

**کار دقیق:** در `__ritmo_startStreamingWatcher`، هر ۵ ثانیه یک‌بار (یعنی هر زمان `tickCount` مضرب عددی باشد که با `heartbeatInterval` برابر ۵ ثانیه می‌شود) رویداد `watcher_tick` بفرست با این پیلود:

```
{
  requestId: reqId,
  source: 'dom',
  textLength: lastLength,
  hasStopButton: <boolean>,
  hasStreamingIndicator: <boolean>,
  assistantNodes: <تعداد گره‌های assistantMessage>,
  turnCount: <تعداد conversationTurns>,
  markdownBodies: <تعداد>,
  idleMs: <مدت بی‌تغییری>,
  elapsedMs: <از شروع واچر>
}
```

در دارت این رویداد را فقط در `BridgeTraceLog` با سطح `info` ثبت کن و هیچ اثری روی استریم نگذار. فقط وقتی واچر فعال است بفرست، نه در حالت بیکار.

**معیار پذیرش:** در هر درخواستی که بیش از ۵ ثانیه طول بکشد، در خروجی ردیابی حداقل یک `watcher_tick` دیده می‌شود. اگر دیده نشد، یعنی واچر مرده است — و این دقیقاً اطلاعاتی است که امروز نداریم.

**تست:** `test/core/ai/web_bridge/watcher_heartbeat_test.dart` — assert کن `watcher_tick` در پارسر شناخته می‌شود، به `BridgeUnknownEvent` نمی‌افتد، و پردازشش باعث بسته شدن یا تغییر وضعیت استریم نمی‌شود.

**commit:** `feat(web-bridge): emit watcher heartbeat trace every 5s (DET-03)`

---

### DET-04 — اجرای مجدد `selector_health` در لحظات حیاتی

**باگ:** `runSelectorSelfTest()` فقط یک‌بار در بوت اجرا می‌شود — روی صفحهٔ خالی که هنوز هیچ پیامی ندارد. به همین دلیل `assistantMessage: 0` در لاگ هیچ معنایی ندارد و نمی‌دانیم سلکتورها در لحظهٔ وجود پاسخ کار می‌کنند یا نه.

**فایل‌ها:** `chatgpt_js_injector.dart`

**کار دقیق:** `runSelectorSelfTest()` را در سه نقطهٔ دیگر هم صدا بزن و در پیلود یک کلید `phase` بگذار تا قابل تفکیک باشند:

- `phase: 'boot'` — همان رفتار فعلی
- `phase: 'pre_send'` — دقیقاً پیش از تایپ کردن متن در `__ritmo_sendPrompt`
- `phase: 'post_first_text'` — ۳ ثانیه پس از اولین باری که `lastLength` از صفر بیشتر می‌شود
- `phase: 'pre_timeout'` — دقیقاً پیش از ارسال هر خطای تایم‌اوت از واچر

هر چهار حالت باید `requestId` را هم حمل کنند (به جز `boot` که هنوز درخواستی ندارد).

**معیار پذیرش:** در یک درخواست شکست‌خورده، لاگ باید `selector_health phase=pre_timeout` داشته باشد تا بدانیم در لحظهٔ شکست چند گرهٔ دستیار روی صفحه بوده.

**تست:** `test/core/ai/web_bridge/selector_health_phases_test.dart` — assert کن متن اسکریپت هر چهار مقدار `boot` و `pre_send` و `post_first_text` و `pre_timeout` را شامل می‌شود و `BridgeSelectorHealthEvent` فیلد `phase` را پارس می‌کند.

**commit:** `feat(web-bridge): run selector self-test at send, first-text and timeout (DET-04)`

---

### DET-05 — ارتقای نسخهٔ پل به ۹

**باگ:** گارد گرم بر اساس `bridgeVersion` کار می‌کند. اگر نسخه را بالا نبری، اسکریپت جدید روی سندهای گرم تزریق نمی‌شود و همهٔ تغییرات فازهای بعدی بی‌اثر می‌مانند.

**فایل‌ها:** `chatgpt_js_injector.dart`

**کار دقیق:** `static const int bridgeVersion = 8;` را به `9` تغییر بده. مطمئن شو همهٔ محل‌هایی که عدد نسخه در رشتهٔ JS تزریق می‌شود از همین ثابت می‌خوانند و هیچ عدد خامی جایی نمانده.

**معیار پذیرش:** دستور جستجوی `__RITMO_BRIDGE_V` در پروژه باید فقط ارجاع به ثابت نشان دهد، نه عدد هاردکد. در لاگ بعدی باید `v=9` دیده شود.

**تست:** `test/core/ai/web_bridge/bridge_version_bump_test.dart` — assert `ChatGptJsInjector.bridgeVersion == 9` و assert کن رشتهٔ `setupBridgeScript` عدد نسخه را از همان ثابت می‌گیرد.

**commit:** `chore(web-bridge): bump bridge script version to 9 (DET-05)`

---

## فاز B — تاکسونومی رویداد (بحرانی)

---

### DET-06 — [بحرانی] افزودن `BridgeErrorEvent` و `case 'error'`

**باگ:** در `WebBridgeEvent.parse` هیچ `case` برای `'error'` وجود ندارد، در حالی که اینجکتور دست‌کم در پنج جا `notifyFlutter('error', ...)` می‌فرستد: نبودن کادر متن، تایم‌اوت اول واچر، تایم‌اوت دوم واچر، `catch` داخل `__ritmo_sendPrompt` و `catch` داخل `__ritmo_resume`. همهٔ این‌ها به `BridgeUnknownEvent` می‌افتند، فقط یک WARN ثبت می‌کنند و **استریم هرگز fail نمی‌شود**. لاگ زنده بودن این مسیر را با سه بار `unknown_event` ثابت کرده.

**فایل‌ها:** `lib/core/ai/web_bridge/web_bridge_event.dart`، `lib/core/ai/web_bridge/chatgpt_web_bridge_manager.dart`

**کار دقیق:**
1. کلاس `BridgeErrorEvent` را بساز با فیلدهای: `message` (رشتهٔ خام از JS)، `code` (اختیاری)، `requestId`، `source`.
2. `case 'error':` را به `parse` اضافه کن.
3. در `_handleJsMessage` یک `case BridgeErrorEvent(...)` اضافه کن که دقیقاً این ترتیب را طی کند:
   - اگر `requestId` موجود است و با `_currentRequestId` نمی‌خواند، فقط trace بزن و رد شو.
   - در غیر این صورت اول `_harvestForSalvage(reason: 'js_error')` را صدا بزن.
   - اگر برداشت متن غیرخالی داد، با `_finishGeneration` تحویل بده و `partial_finish` ثبت کن.
   - وگرنه `_failGeneration` را با `WebBridgeException.unknown(messageFa: <پیام فارسی دریافتی یا پیش‌فرض>)` صدا بزن.
4. اگر پیام خطا شامل عبارت مربوط به نبودن کادر متن بود، به جای `unknown` از `WebBridgeException.composerNotFound()` استفاده کن؛ اگر شامل عبارت تایم‌اوت بود، از `WebBridgeException.timeout()`.

**معیار پذیرش:** پس از این تغییر، **هیچ مسیر خطایی در جاوااسکریپت نمی‌تواند منجر به لودینگ بی‌پایان شود.** هر `error` در حداکثر ۲ ثانیه یا به تحویل متن می‌رسد یا به پیام خطای فارسی.

**تست:** `test/core/ai/web_bridge/error_event_fails_stream_test.dart` — یک `BridgeErrorEvent` بساز و assert کن پارسر آن را به `BridgeErrorEvent` نگاشت می‌کند (نه `BridgeUnknownEvent`)، و نگاشت پیام به نوع درست `WebBridgeErrorKind` انجام می‌شود.

**commit:** `fix(web-bridge): handle js error events and fail the stream (DET-06)`

---

### DET-07 — [بحرانی] افزودن `case 'cloudflare_resolved'`

**باگ:** `cloudflare_resolved` در سوئیچ پارسر نیست و سه بار در لاگ به شکل `unknown_event` ثبت شده.

**فایل‌ها:** `web_bridge_event.dart`، `chatgpt_web_bridge_manager.dart`

**کار دقیق:** کلاس `BridgeCloudflareResolvedEvent` را بساز و `case 'cloudflare_resolved':` را اضافه کن. در `_handleJsMessage`:
- فقط وقتی `_status == ChatGptBridgeStatus.cloudflareChallenge` است، وضعیت را به `ready` برگردان و مودال چالش را ببند.
- اگر وضعیت `generating` است، **دست به وضعیت نزن** و فقط trace بزن.
- در هر حالت دیگر، فقط trace.

**معیار پذیرش:** دریافت `cloudflare_resolved` در هیچ شرایطی نمی‌تواند یک تولید در جریان را قطع یا وضعیتش را عوض کند.

**تست:** `test/core/ai/web_bridge/cloudflare_resolved_event_test.dart`

**commit:** `fix(web-bridge): map cloudflare_resolved to a typed event (DET-07)`

---

### DET-08 — [بحرانی] دام ایمنی برای رویدادهای ناشناخته

**باگ:** هر نوع رویدادی که در آینده در JS اضافه شود و در دارت فراموش شود، دوباره همین فاجعه را تکرار می‌کند. درمان موردبه‌مورد کافی نیست.

**فایل‌ها:** `chatgpt_web_bridge_manager.dart`

**کار دقیق:** در شاخهٔ `BridgeUnknownEvent` داخل `_handleJsMessage` این منطق را اضافه کن:

- همیشه پیلود خام (بدون محتوای متن پاسخ) را در trace با سطح `warning` ثبت کن.
- اگر `_status == generating` و پیلود یکی از کلیدهای `error` یا `message` یا `reason` را دارد و مقدارش غیرخالی است، آن را دقیقاً مثل `BridgeErrorEvent` مدیریت کن (برداشت نجات سپس تحویل یا شکست). trace را با نوع `unknown_event_promoted_to_error` بزن.
- در غیر این صورت فقط ثبت کن و رد شو.

**معیار پذیرش:** حتی اگر یک نوع رویداد جدید در پارسر جا بیفتد، تا وقتی پیام خطا حمل کند، کاربر لودینگ بی‌پایان نمی‌بیند.

**تست:** `test/core/ai/web_bridge/unknown_event_error_promotion_test.dart` — یک رویداد با نوع جعلی `totally_new_type` و کلید `message` بفرست و assert کن استریم بسته می‌شود.

**commit:** `fix(web-bridge): promote error-bearing unknown events to failures (DET-08)`

---

### DET-09 — [بحرانی] تست پوشش کامل تاکسونومی رویداد

**باگ:** هیچ مکانیزمی وجود ندارد که تضمین کند هر نوع رویدادی که JS می‌فرستد، در دارت هم شناخته می‌شود. دقیقاً همین شکاف `error` و `cloudflare_resolved` را بی‌صدا بلعید.

**فایل‌ها:** `test/core/ai/web_bridge/event_taxonomy_coverage_test.dart`

**کار دقیق:** تستی بنویس که:
1. متن کامل هر سه رشتهٔ اسکریپت را بگیرد: `ChatGptJsInjector.earlyHookScript`، `setupBridgeScript`، و خروجی `buildSendPromptScript('x', requestId: 'r')`.
2. همهٔ رخدادهای الگوی `notifyFlutter('<type>'` را استخراج کند و مجموعهٔ یکتای `type` بسازد.
3. برای هر `type` یک `WebBridgeEvent.parse` روی پیلود کمینه صدا بزند و assert کند نتیجه `BridgeUnknownEvent` **نیست**.
4. پیام خطای تست باید دقیقاً فهرست نوع‌های پوشش‌داده‌نشده را چاپ کند.

**معیار پذیرش:** اگر کسی در آینده یک `notifyFlutter` با نوع جدید اضافه کند و پارسر را به‌روز نکند، **این تست باید قرمز شود**. خودت با افزودن موقت یک نوع جعلی این را یک‌بار تأیید کن و بعد برگردان.

**تست:** خود این تسک یک تست است.

**commit:** `test(web-bridge): assert every js event type is parsed (DET-09)`

---

### DET-10 — حذف `cloudflare_resolved` کاذب

**باگ:** در `checkCloudflareStatus`، متغیر `lastCfState` با `null` مقداردهی شده. اولین مقایسهٔ `false !== null` برقرار می‌شود و روی هر صفحه‌ای رویداد «چالش حل شد» می‌فرستد — حتی روی صفحهٔ مسدود ۲۱:۲۴:۱۰ که اصلاً باز نشده بود. در لاگ هر سه بار دقیقاً بلافاصله پس از بوت دیده می‌شود.

**فایل‌ها:** `chatgpt_js_injector.dart`

**کار دقیق:** منطق را به این شکل بنویس: فقط وقتی `lastCfState === true` بوده و الان مقدار محاسبه‌شده `false` است، رویداد `cloudflare_resolved` بفرست. در اولین اجرا فقط `lastCfState` را مقداردهی کن و هیچ رویدادی نفرست.

همین الگو را برای هر پرچم وضعیتی دیگری که در `checkSecurityAndBlockStatus` مقایسهٔ گذار می‌کند هم اعمال کن.

**معیار پذیرش:** در یک بوت سالم بدون چالش کلودفلر، در کل لاگ **صفر** رویداد `cloudflare_resolved` دیده می‌شود.

**تست:** `test/core/ai/web_bridge/no_spurious_cloudflare_resolved_test.dart` — assert کن متن اسکریپت دیگر الگوی مقایسه با `null` را برای صدور این رویداد ندارد و مقدار اولیه بدون اطلاع‌رسانی تنظیم می‌شود.

**commit:** `fix(web-bridge): stop emitting spurious cloudflare_resolved on first check (DET-10)`

---

## فاز C — گارد وضعیت (قاتل اصلی)

---

### DET-11 — [بحرانی] حمل `isWarm` در رویداد `ready`

**باگ:** گارد گرم در `setupBridgeScript` پیشاپیش `isWarm: true` را در پیلود می‌گذارد، اما `BridgeReadyEvent` آن را پارس نمی‌کند و دارت نمی‌تواند بین «بوت سرد» و «ناوبری SPA» تفکیک قائل شود.

**فایل‌ها:** `web_bridge_event.dart`، `chatgpt_js_injector.dart`

**کار دقیق:**
1. به `BridgeReadyEvent` فیلدهای `isWarm` (بولی، پیش‌فرض `false`)، `currentPath` و `hasComposer` را اضافه کن.
2. مطمئن شو هر دو مسیر صدور `ready` (مسیر گارد گرم و مسیر بوت کامل) هر سه کلید را می‌فرستند، مسیر بوت کامل با `isWarm: false`.
3. در `BridgeTraceLog` مقدار `warm` را در `note` بنویس تا در خروجی دیده شود.

**معیار پذیرش:** در لاگ بعدی، خط `ready` باید به شکل `type=ready src=lifecycle note="warm=true path=/c/..."` دیده شود.

**تست:** `test/core/ai/web_bridge/ready_event_warm_flag_test.dart`

**commit:** `feat(web-bridge): expose isWarm on ready events (DET-11)`

---

### DET-12 — [بحرانی‌ترین تسک کل فایل] گارد `generating` در هندلر `ready`

**باگ:** در `_handleJsMessage` منطق فعلی این است:

```dart
case BridgeReadyEvent(:final isAuthed):
  _isAuthenticated = isAuthed;
  if (_status != ChatGptBridgeStatus.ready) {
    _setStatus(ChatGptBridgeStatus.ready);   // هیچ گاردی برای generating ندارد
  }
```

هر ناوبری SPA وسط تولید، وضعیت را از `generating` به `ready` می‌برد و از آن لحظه هر سازوکاری که شرط `_status == generating` دارد مرده است: دو چک‌پوینت برداشت، شرط تحویل در `harvestVisibleAnswer`، و هر دو `_failGeneration` در هندلرهای `auth_required` و `vpn_required`.

**فایل‌ها:** `chatgpt_web_bridge_manager.dart`

**کار دقیق:** منطق را دقیقاً به این قاعده تبدیل کن:

1. `_isAuthenticated` همیشه به‌روز می‌شود (این بی‌خطر است).
2. **اگر `_status == ChatGptBridgeStatus.generating` یا `_pendingRequest != null` باشد، وضعیت را مطلقاً دست نزن.** فقط یک trace با نوع `ready_ignored_during_generation` و سطح `info` بزن که `warm` و `requestId` جاری را حمل کند.
3. در غیر این صورت، فقط اگر وضعیت جاری یکی از `idle`، `booting`، `error`، `cloudflareChallenge` یا `vpnRequired` باشد، وضعیت را `ready` کن.
4. تکمیل `_bootCompleter` را از تغییر وضعیت جدا کن: حتی وقتی وضعیت عوض نمی‌شود، اگر `_bootCompleter` ناتمام است باید کامل شود (وگرنه `_waitForReady` قفل می‌کند).

**معیار پذیرش:** پس از این تغییر، در سناریوی دقیق لاگ کاربر (ارسال در `t`، دو `ready` گرم در `t+12` و `t+13`)، وضعیت تا انتها `generating` می‌ماند و هر دو چک‌پوینت در ۲۵ و ۵۵ ثانیه قطعاً شلیک می‌کنند.

**تست:** `test/core/ai/web_bridge/ready_does_not_reset_generating_test.dart` — وضعیت را `generating` کن، یک `BridgeReadyEvent(isWarm: true)` بفرست، assert کن وضعیت هنوز `generating` است و `ready_ignored_during_generation` در ردیابی ثبت شده.

**commit:** `fix(web-bridge): never downgrade generating status on ready event (DET-12)`

---

### DET-13 — [بحرانی] مستقل‌کردن چک‌پوینت‌ها از `_status`

**باگ:** `_runCheckpointCheck` در خط اول با شرط `_status != generating` بدون هیچ ردی برمی‌گردد. این هم بازیابی را می‌کشد و هم هیچ اثری در لاگ نمی‌گذارد — دقیقاً همین سکوت تشخیص مشکل را ۷۴ ثانیه کور کرد.

**فایل‌ها:** `chatgpt_web_bridge_manager.dart`

**کار دقیق:**
1. شرط خروج زودهنگام را فقط به `!identical(_currentStreamController, streamController)` یا `streamController.isClosed` محدود کن. شرط `_status` را حذف کن.
2. پیش از هر خروج زودهنگام، یک trace با نوع `checkpoint_skipped` و دلیل دقیق ثبت کن. **هیچ مسیر خروجی بدون رد مجاز نیست.**
3. همین قاعده را برای `_generationTimer` و هر تایمر دیگری که با `_status` گیت می‌شود اعمال کن: گیت فقط روی هویت استریم‌کنترلر، نه وضعیت.

**معیار پذیرش:** در هر درخواستی که بیش از مدت چک‌پوینت اول طول بکشد، حتماً یکی از دو رویداد `checkpoint_check_started` یا `checkpoint_skipped` در لاگ می‌آید. سکوت کامل دیگر ممکن نیست.

**تست:** `test/core/ai/web_bridge/checkpoint_runs_regardless_of_status_test.dart`

**commit:** `fix(web-bridge): gate checkpoints on stream identity, not status (DET-13)`

---

### DET-14 — اصلاح شرط تحویل در برداشت دستی

**باگ:** در `harvestVisibleAnswer` و `_emitChunk` شرط `_status == ChatGptBridgeStatus.generating` وجود دارد. اگر وضعیت به هر دلیلی عوض شود، حتی متن برداشت‌شدهی موفق هم دور ریخته می‌شود.

**فایل‌ها:** `chatgpt_web_bridge_manager.dart`

**کار دقیق:** در هر دو تابع، شرط `_status == generating` را با این جایگزین کن: استریم‌کنترلر جاری `null` نباشد و بسته نشده باشد. اگر متن معتبر است ولی وضعیت `generating` نیست، متن را تحویل بده و یک trace با نوع `delivered_outside_generating` و سطح `warning` بزن تا اگر باز هم رخ داد، دیده شود.

**معیار پذیرش:** متن برداشت‌شده هرگز فقط به خاطر وضعیت دور ریخته نمی‌شود.

**تست:** `test/core/ai/web_bridge/harvest_delivers_outside_generating_test.dart`

**commit:** `fix(web-bridge): deliver harvested text based on stream liveness (DET-14)`

---

### DET-15 — مرکزی‌کردن تغییر وضعیت با گارد مشترک

**باگ:** منطق «چه وقت مجازیم وضعیت را عوض کنیم» در چند نقطه پخش شده و هر کدام می‌تواند جداگانه خراب شود. `DET-12` فقط یک نقطه را درمان کرد.

**فایل‌ها:** `chatgpt_web_bridge_manager.dart`

**کار دقیق:** یک متد خصوصی بساز:

```dart
bool _canLeaveGenerating(String reason) { ... }
```

قاعده: خروج از `generating` فقط از طریق سه مسیر مجاز است: `_finishGeneration`، `_failGeneration`، و `cancelCurrentStream`. هر فراخوانی دیگری از `_setStatus` که بخواهد وضعیت را از `generating` خارج کند باید رد شود و `status_change_blocked` با دلیل ثبت کند.

این گارد را داخل خود `_setStatus` پیاده کن تا هیچ مسیری نتواند دورش بزند، و یک پارامتر نام‌دار `force: true` فقط برای آن سه مسیر مجاز بگذار.

**معیار پذیرش:** دستور جستجو برای `_setStatus(` در فایل مدیر نشان دهد فقط سه فراخوانی `force: true` دارند و هر سه در همان سه متد مجازند.

**تست:** `test/core/ai/web_bridge/status_exit_guard_test.dart` — برای هر مقدار `ChatGptBridgeStatus` تلاش کن از `generating` خارج شوی و assert کن بدون `force` بلاک می‌شود.

**commit:** `refactor(web-bridge): centralize generating-status exit guard (DET-15)`

---

## فاز D — زنده‌کردن لایهٔ شبکه

---

### DET-16 — [بحرانی] اصلاح تطبیق endpoint گفتگو

**باگ:** در کل لاگ حتی یک `network_conversation_started` نیست. شرط تطبیق در هر دو جای `earlyHookScript` و بدنهٔ اسکریپت پل فقط این دو رشته را می‌شناسد:

```
'/backend-api/conversation'
'/backend-anon/conversation'
```

اما چت‌جی‌پی‌تی امروز روی `/backend-api/f/conversation` پست می‌کند. رشتهٔ `/backend-api/f/conversation` شامل `/backend-api/conversation` **نیست**، پس تطبیق رخ نمی‌ده، `tee()` اجرا نمی‌شود، SSE خوانده نمی‌شود و کل بار تشخیص روی واچر DOM می‌افتد.

**فایل‌ها:** `chatgpt_js_injector.dart`

**کار دقیق:** یک تابع کمکی واحد در هر دو اسکریپت تعریف کن و هر دو جای تطبیق را به آن بسپار. **از regex استفاده نکن** تا در فرار دادن رشتهٔ دارت مشکل پیش نیاید:

```js
function ritmoIsConversationEndpoint(rawUrl) {
  if (!rawUrl) return false;
  var s = String(rawUrl);
  if (s.indexOf('conversation') === -1) return false;
  if (s.indexOf('/lat/r') !== -1) return false;
  if (s.indexOf('/conversation/init') !== -1) return false;
  if (s.indexOf('/conversation/prepare') !== -1) return false;
  if (s.indexOf('/conversations') !== -1) return false;
  return s.indexOf('/backend-api/') !== -1
      || s.indexOf('/backend-anon/') !== -1
      || s.indexOf('/backend-alt/') !== -1;
}
```

توجه: شرط `/conversations` (جمع) عمداً کنار گذاشته می‌شود چون فهرست گفتگوهاست و استریم SSE نیست.

در لحظهٔ تطبیق موفق، رویداد `network_conversation_started` را با کلیدهای `{ endpoint: <مسیر بدون کوئری‌استرینگ>, method: <متد>, source: 'fetch' }` بفرست تا دفعهٔ بعد بدانیم دقیقاً کدام endpoint مچ شده.

**معیار پذیرش:** در اولین پرسش موفق، لاگ باید دقیقاً یک `network_conversation_started` با endpoint واقعی نشان دهد.

**تست:** `test/core/ai/web_bridge/conversation_endpoint_matcher_test.dart` — تابع تطبیق را در دارت هم به صورت یک تابع قابل تست پیاده کن (مثلاً `ChatGptJsInjector.isConversationEndpoint`) و همان منطق را در JS تکرار کن. برای این ورودی‌ها assert کن:
- `true`: `/backend-api/conversation`، `/backend-api/f/conversation`، `/backend-anon/conversation`، `/backend-anon/f/conversation`، `/backend-alt/conversation`، و نسخهٔ کامل با دامنه و کوئری‌استرینگ
- `false`: `/backend-api/conversations`، `/backend-api/conversation/init`، `/backend-api/conversation/prepare`، `/ces/v1/t`، `/backend-api/me`، رشتهٔ خالی

**commit:** `fix(web-bridge): match the real chatgpt conversation endpoints (DET-16)`

---

### DET-17 — پوشش فراخوانی‌های `fetch` با شیء `Request`

**باگ:** هوک `fetch` فقط حالتی را پوشش می‌دهد که آرگومان اول رشته باشد. اگر کتابخانهٔ داخلی چت‌جی‌پی‌تی شیء `Request` بفرستد (که رایج است)، آدرس خوانده نمی‌شود و هوک رد می‌شود.

**فایل‌ها:** `chatgpt_js_injector.dart`

**کار دقیق:** در هر دو هوک، استخراج آدرس و متد را به یک تابع کمکی بسپار که هر سه حالت را پوشش می‌دهد: آرگومان رشته‌ای، شیء دارای خاصیت `url`، و شیء قابل تبدیل به رشته. متد را اول از آرگومان دوم و سپس از خود شیء `Request` بخوان و پیش‌فرض `GET` بگذار.

فقط وقتی متد `POST` است و تطبیق endpoint برقرار است، مسیر `tee` را فعال کن. برای `GET` فقط trace بزن.

**معیار پذیرش:** هر سه شکل فراخوانی `fetch` به درستی آدرس را می‌دهند.

**تست:** `test/core/ai/web_bridge/fetch_hook_url_extraction_test.dart` — assert کن متن اسکریپت هر سه مسیر استخراج را دارد و متد پیش‌فرض تعریف شده.

**commit:** `fix(web-bridge): extract url and method from Request-style fetch calls (DET-17)`

---

### DET-18 — تضمین دردسترس‌بودن خوانندهٔ SSE در هوک زودهنگام

**باگ:** `earlyHookScript` در `onPageStarted` تزریق می‌شود، اما در مسیر `tee` تابع `window.__ritmo_readSSEStream` را صدا می‌زند که فقط پس از اجرای `setupBridgeScript` در `onPageFinished` وجود دارد. هر درخواست گفتگویی که در این فاصله شروع شود، خوانده نمی‌شود.

**فایل‌ها:** `chatgpt_js_injector.dart`

**کار دقیق:** دو کار:
1. تابع `parseSSELine` و `readSSEStream` را از بدنهٔ اصلی به `earlyHookScript` منتقل کن (یا در هر دو تعریف کن با گارد «اگر قبلاً تعریف نشده») تا از لحظهٔ شروع صفحه در دسترس باشند.
2. اگر با وجود این خواننده در دسترس نبود، به جای رد شدن خاموش، شاخهٔ `tee` را در یک صف موقت `window.__ritmo_pending_streams` بگذار و در انتهای `setupBridgeScript` صف را تخلیه کن. هر دو حالت باید trace بزنند.

**معیار پذیرش:** هیچ استریم گفتگویی به خاطر زمان‌بندی تزریق از دست نمی‌رود.

**تست:** `test/core/ai/web_bridge/early_hook_has_sse_reader_test.dart` — assert کن `earlyHookScript` هم تعریف خواننده را دارد و هم مسیر صف موقت را.

**commit:** `fix(web-bridge): make sse reader available to the early fetch hook (DET-18)`

---

### DET-19 — ترجیح منبع شبکه بر DOM در داوری

**باگ:** وقتی لایهٔ شبکه زنده شود، دو منبع هم‌زمان متن می‌فرستند. قفل منبع فعلی بر اساس «هر که اول رسید» کار می‌کند، در حالی که SSE همیشه دقیق‌تر از DOM است.

**فایل‌ها:** `chatgpt_web_bridge_manager.dart`

**کار دقیق:** در `_acquireSourceLockIfNeeded` قاعده را این کن: اگر قفل فعلی `BridgeSource.dom` است و یک رویداد از `BridgeSource.sse` می‌رسد، **قفل را به `sse` منتقل کن** و انبارهٔ متن را با `BridgeResponseAccumulator.reset()` پاک کن تا متن SSE از صفر بنشیند. یک trace با نوع `source_upgrade_dom_to_sse` بزن. عکس این مسیر (انتقال از `sse` به `dom`) مجاز نیست مگر پس از سکوت `sourceRelockSilence`.

**معیار پذیرش:** وقتی هر دو منبع فعالند، متن نهایی همیشه از SSE می‌آید و هیچ متن تکراری یا درهم‌ریخته‌ای تولید نمی‌شود.

**تست:** `test/core/ai/web_bridge/sse_wins_over_dom_test.dart` — ابتدا دو رویداد `dom` بفرست، سپس یک `sse`، و assert کن متن نهایی فقط محتوای SSE است.

**commit:** `fix(web-bridge): let sse take over an active dom source lock (DET-19)`

---

## فاز E — ایدمپوتنت‌کردن resume

---

### DET-20 — [بحرانی] انتقال حالت واچر به فضای پایدار

**باگ:** متغیرهای lastLength و lastText و tickCount و sawGeneratingSignal و streamStartTime داخل closure تابع `__ritmo_startStreamingWatcher` زندگی می‌کنند. هر فراخوانی دوباره همهٔ آن‌ها را صفر می‌کند.

**فایل‌ها:** `chatgpt_js_injector.dart`

**کار دقیق:** یک مخزن پایدار روی `window.__ritmo_stream_state` بساز که کلیدش `reqId` است و مقدارش شیئی با این خاصیت‌ها: lastText، lastLength، tickCount، sawGeneratingSignal، streamStartTime، lastChangeTime، watcherAlive، baseline.

در ابتدای `__ritmo_startStreamingWatcher(baseline, reqId)`:
- اگر ورودی مربوط به آن `reqId` از قبل وجود دارد، همان را بردار و **هیچ مقداری را صفر نکن**.
- اگر وجود ندارد، تازه بساز و مقداردهی کن.

هر نوشتن در این مقادیر باید روی همین شیء انجام شود، نه روی متغیر محلی closure. در `__ritmo_cleanup` و پس از `done` یا خطا، ورودی مربوط به آن `reqId` را حذف کن (قانون ۱۶: هر ساختن مسیر تخریب دارد).

**معیار پذیرش:** پس از دو بار ناوبری پشت سر هم، متنی که تا آن لحظه جمع شده بود از دست نمی‌رود و دوباره از صفر ارسال نمی‌شود.

**تست:** `test/core/ai/web_bridge/watcher_state_survives_resume_test.dart` — assert کن متن اسکریپت مخزن پایدار را دارد و در مسیر ادامه، مقداردهی مجدد به صفر وجود ندارد.

**commit:** `fix(web-bridge): persist watcher state across resumes (DET-20)`

---

### DET-21 — [بحرانی] `__ritmo_resume` دیگر واچر زنده را نکشد

**باگ:** `__ritmo_resume` بی‌قید و شرط `__ritmo_startStreamingWatcher` را صدا می‌زند، و آن تابع ابتدا تایمر بازه‌ای را پاک و ناظر DOM را متوقف می‌کند. در لاگ کاربر این در فاصلهٔ حدود یک ثانیه دو بار رخ داده و هر دو بار سیگنال پایان را خلع سلاح کرده است.

**فایل‌ها:** `chatgpt_js_injector.dart`

**کار دقیق:** منطق `__ritmo_resume` را دقیقاً به این سه شاخه تبدیل کن:

1. **واچر زنده برای همین `reqId`** (یعنی watcherAlive برقرار است و تایمر نال نیست): واچر را دست نزن. فقط ناظر DOM را دوباره به بدنهٔ سند جدید وصل کن و یک بار همگام‌سازی کامل متن بزن. رویداد `resumed` را با کلید mode برابر `reattached` بفرست.
2. **واچر مرده ولی حالت پایدار موجود است:** واچر را دوباره راه بینداز اما بدون صفرکردن حالت (متکی به DET-20). رویداد `resumed` با mode برابر `restarted`.
3. **هیچ حالتی نیست:** یعنی سند واقعاً سرد است. از صفر شروع کن. رویداد `resumed` با mode برابر `cold`.

در هر سه حالت، مقدار `len` در رویداد `resumed` باید طول متن حالت پایدار باشد، نه همیشه صفر. دقیقاً همین صفر بودن در لاگ کاربر نشان می‌دهد شاخهٔ سوم اجرا شده است.

**معیار پذیرش:** در لاگ بعدی، دو `resumed` پشت سر هم باید mode برابر `reattached` داشته باشند، نه ریست کامل.

**تست:** `test/core/ai/web_bridge/resume_is_idempotent_test.dart`

**commit:** `fix(web-bridge): make resume reattach instead of restarting the watcher (DET-21)`

---

### DET-22 — دباونس resume‌های پشت سر هم

**باگ:** چت‌جی‌پی‌تی در یک گفتگو چند ناوبری پشت سر هم می‌زند. لاگ کاربر دو بار در کمتر از یک ثانیه را نشان می‌دهد.

**فایل‌ها:** `chatgpt_web_bridge_manager.dart`، `chatgpt_bridge_timeouts.dart`

**کار دقیق:** در `_attemptResumePendingRequest` زمان آخرین ادامه را در یک فیلد `_lastResumeAt` نگه دار. اگر فاصله از ادامهٔ قبلی برای همان `requestId` کمتر از `ChatGptBridgeTimeouts.resumeDebounce` باشد، ادامه را رد کن و `resume_debounced` ثبت کن.

ثابت جدید `resumeDebounce` با مقدار ۱۵۰۰ میلی‌ثانیه را به `ChatGptBridgeTimeouts` اضافه کن (قانون ۱۰: هیچ عدد زمانی خارج این کلاس نوشته نمی‌شود).

**معیار پذیرش:** دو پایان‌بارگذاری صفحه در فاصلهٔ کمتر از یک و نیم ثانیه فقط یک ادامه تولید می‌کنند.

**تست:** `test/core/ai/web_bridge/resume_debounce_test.dart`

**commit:** `fix(web-bridge): debounce back-to-back resume attempts (DET-22)`

---

### DET-23 — شمارش فقط بارگذاری‌های سرد در حلقهٔ ناوبری

**باگ:** `_navigationReloadCount` روی هر پایان‌بارگذاری بالا می‌رود و سقفش `maxNavigationReloads = 6` است. ناوبری‌های داخلی به راحتی از این عدد رد می‌شوند و یک گفتگوی طولانی را با خطای جعلی حلقهٔ ناوبری می‌کشند.

**فایل‌ها:** `chatgpt_js_injector.dart`، `chatgpt_web_bridge_manager.dart`

**کار دقیق:**
1. در `setupBridgeScript`، در مسیر بوت سرد (نه مسیر گارد گرم)، یک شناسهٔ تصادفی روی `window.__ritmo_document_id` بگذار و آن را در پیلود `ready` بفرست.
2. در مدیر، `_navigationReloadCount` را فقط وقتی بالا ببر که شناسهٔ سند دریافتی با مقدار قبلی فرق داشته باشد.
3. `maxNavigationReloads` را از ۶ به ۱۲ ببر.

**معیار پذیرش:** ده‌ها ناوبری داخلی در یک گفتگو هیچ تأثیری روی شمارنده ندارند.

**تست:** `test/core/ai/web_bridge/cold_reload_counter_test.dart`

**commit:** `fix(web-bridge): count only cold document loads as reloads (DET-23)`

---

### DET-24 — پذیرش رویدادهای بدون شناسهٔ درخواست

**باگ:** `_handleJsMessage` رویدادهایی را که `requestId` شان با شناسهٔ جاری نمی‌خواند دور می‌ریزد. ولی `window.__ritmo_active_req_id` روی سند سرد تا پیش از اجرای `__ritmo_resume` خالی است، پس رویدادهای بین تزریق و ادامه با شناسهٔ خالی می‌آیند و بی‌صدا دور ریخته می‌شوند.

**فایل‌ها:** `chatgpt_web_bridge_manager.dart`

**کار دقیق:** قاعدهٔ دورریز را صریح کن:
- شناسهٔ خالی یا غایب و درخواست جاری موجود ← رویداد را **بپذیر** و به درخواست جاری نسبت بده، سپس `event_adopted_empty_request_id` ثبت کن.
- شناسهٔ موجود و متفاوت ← دور بریز با `stale_event_dropped` (رفتار فعلی درست است).

**معیار پذیرش:** هیچ متن معتبری فقط به دلیل خالی بودن شناسه دور ریخته نمی‌شود.

**تست:** `test/core/ai/web_bridge/empty_request_id_adoption_test.dart`

**commit:** `fix(web-bridge): adopt events with empty request ids (DET-24)`

---

## فاز F — مسیر ارسال پیام و انتخاب دکمه

---

### DET-25 — [بحرانی] انتخاب هوشمند دکمهٔ ارسال

**باگ:** آخرین `selector_health` کاربر مقدار `sendButton: 9` را نشان می‌دهد. یعنی نه عنصر در صفحه با سلکتورهای دکمهٔ ارسال تطبیق دارند. کد فعلی اولین مورد را برمی‌دارد، که ممکن است دکمهٔ مخفی میکروفون، دکمهٔ گفتگوی صوتی یا دکمهٔ غیرفعال باشد. اگر کلیک روی عنصر اشتباه بیفتد، پیام اصلاً ارسال نمی‌شود و دقیقاً همین الگوی لاگ (صفر رویداد شبکه، صفر گره دستیار) تولید می‌شود.

**فایل‌ها:** `chatgpt_js_injector.dart`

**کار دقیق:** یک تابع کمکی مشترک بساز:

```js
function ritmoQueryFirstVisible(selectorList) {
  for (var i = 0; i < selectorList.length; i++) {
    var nodes = queryAllSafe(selectorList[i]);
    for (var j = 0; j < nodes.length; j++) {
      var el = nodes[j];
      if (!el) continue;
      if (el.disabled === true) continue;
      if (el.getAttribute && el.getAttribute('aria-disabled') === 'true') continue;
      if (el.offsetParent === null) continue;
      var r = el.getBoundingClientRect();
      if (r.width <= 1 || r.height <= 1) continue;
      return el;
    }
  }
  return null;
}
```

سپس سلکتورهای `sendButton` در `RITMO_SELECTORS` را از یک رشتهٔ کامایی به یک آرایهٔ **مرتب بر اساس اولویت** تبدیل کن:
1. دکمه با شناسهٔ صریح ارسال (مثلاً `data-testid` مربوط به ارسال)
2. دکمهٔ نوع submit داخل فرمی که کادر متن در آن است
3. دکمه با برچسب دسترسی ارسال
4. فالبک‌های عمومی فعلی

مواردی که باید صریحاً **حذف** شوند: هر عنصری که برچسب دسترسی‌اش شامل میکروفون، صوت، دیکته، یا توقف باشد — چون در رابط کاربری جدید دقیقاً کنار دکمهٔ ارسال‌اند.

**معیار پذیرش:** در `send_clicked` باید هر سه کلید `candidateCount`، `matchedSelectorIndex` و `ariaLabel` گزارش شوند، تا دفعهٔ بعد دقیقاً بدانیم روی چه عنصری کلیک شده.

**تست:** `test/core/ai/web_bridge/send_button_priority_test.dart` — assert کن آرایهٔ اولویت مرتب است، تابع دیده‌شدن و غیرفعال نبودن را چک می‌کند، و برچسب‌های میکروفون و توقف در فهرست حذف آمده‌اند.

**commit:** `fix(web-bridge): pick a visible enabled send button by priority (DET-25)`

---

### DET-26 — فالبک ارسال با کلید ورود و تأیید واقعی ارسال

**باگ:** اگر کلیک کار نکند، هیچ مکانیزمی برای تشخیص این موضوع وجود ندارد. بریج فرض می‌کند ارسال موفق بوده و سه دقیقه منتظر پاسخی می‌ماند که هرگز درخواست نشده.

**فایل‌ها:** `chatgpt_js_injector.dart`

**کار دقیق:** در `__ritmo_sendPrompt` پس از تلاش ارسال:
1. ۸۰۰ میلی‌ثانیه صبر کن، سپس دو شرط را بررسی کن: کادر متن خالی شده باشد **و** تعداد گره‌های پیام کاربر یکی بیشتر از مقدار قبل از ارسال شده باشد.
2. اگر هر دو برقرار بود، رویداد `send_confirmed` بفرست.
3. اگر نه، یک بار فالبک کلید ورود را روی کادر متن امتحان کن، `send_fallback_enter` بفرست، ۸۰۰ میلی‌ثانیه صبر کن و دوباره بسنج.
4. اگر باز هم تأیید نشد، رویداد `send_failed` با دلیل دقیق بفرست. در دارت، این رویداد باید بلافاصله استریم را با `WebBridgeException.composerNotFound()` شکست دهد — نه اینکه سه دقیقه منتظر تایم‌اوت بماند.

**معیار پذیرش:** ارسال ناموفق حداکثر در حدود دو ثانیه معلوم می‌شود، نه سه دقیقه.

**تست:** `test/core/ai/web_bridge/send_confirmation_test.dart`

**commit:** `feat(web-bridge): confirm the prompt actually left the composer (DET-26)`

---

### DET-27 — ثبت تعداد گره‌ها پیش از ارسال به عنوان خط مبنا

**باگ:** متغیر `__ritmo_turn_count_at_send` فقط تعداد دورهای گفتگو را می‌گیرد. اگر رابط کاربری دورها را مجازی‌سازی کند (مقدار صفر در لاگ کاربر دقیقاً همین را نشان می‌دهد)، هر چهار استراتژی تشخیص متن با هم کور می‌شوند.

**فایل‌ها:** `chatgpt_js_injector.dart`

**کار دقیق:** پیش از ارسال، علاوه بر شمارش دورها، این سه مقدار را هم ذخیره کن و در `send_clicked` گزارش بده: تعداد گره پیام دستیار، تعداد گره پیام کاربر، و طول متن آخرین گره دستیار. این سه مقدار خط مبنای مطمئن‌تری از شمارش دورها می‌دهند.

در `findLatestAssistantText`، اگر شمارش دورها صفر بود، استراتژی اول را رد کن و مستقیم سراغ استراتژی مبتنی بر تعداد گره برو و `anchor_strategy_downgraded` ثبت کن.

**معیار پذیرش:** در صفحهاتی که دورها مجازی‌سازی می‌شوند، تشخیص متن همچنان کار می‌کند.

**تست:** `test/core/ai/web_bridge/anchor_baseline_fallback_test.dart`

**commit:** `fix(web-bridge): capture richer baselines before sending (DET-27)`

---

## فاز G — تشخیص وضعیت ورود

---

### DET-28 — تشخیص واقعی نشست مهمان

**باگ:** در مدیر، مقدار احراز هویت به این شکل خوانده می‌شود:

```dart
isAuthed: readBool('isAuthed') ?? readBool('hasComposer') ?? true
```

یعنی اگر JS این کلید را نفرستد، وجود کادر متن به معنای «وارد شده» تفسیر می‌شود و در نهایت پیش‌فرض `true` است. صفحهٔ مهمان چت‌جی‌پی‌تی **هم کادر متن دارد و هم دکمهٔ ورود**، پس دقیقاً همین حالت اشتباه تشخیص داده می‌شود. در تصویری که کاربر فرستاده، دکمه‌های ورود و ثبت‌نام دیده می‌شوند. نشست مهمان محدودیت نرخ بسیار سخت‌گیرانه‌تری دارد و می‌تواند پاسخ را بی‌صدا دروپ کند.

**فایل‌ها:** `chatgpt_js_injector.dart`، `chatgpt_web_bridge_manager.dart`

**کار دقیق:**
1. در JS، تابع تشخیص را قطعی کن: وارد شده یعنی هیچ عنصر مطابق با سلکتور `loginButton` دیده نمی‌شود **و** مسیر صفحه شامل مسیر ورود نیست. وجود `userProfile` یک سیگنال تقویتی مثبت است ولی به تنهایی لازم نیست.
2. این مقدار را در هر سه جای پیلود `ready`، `selector_health` و `watcher_tick` بفرست.
3. در دارت، فالبک را به `readBool('isAuthed') ?? false` تغییر بده. **دیگر هرگز `hasComposer` را به عنوان نشانهٔ ورود نخوان.**
4. وقتی تشخیص دادی نشست مهمان است، جلوی ارسال را نگیر (چون گاهی کار می‌کند) ولی یک رویداد `anonymous_session` با سطح `warning` ثبت کن و در `describeEmptyResponseReason` در صورت پاسخ خالی، دلیل فارسی مختص برگردان: «بدون ورود به حساب چت‌جی‌پی‌تی، پاسخ ممکن است دریافت نشود. یک بار وارد شو.»

**معیار پذیرش:** در صفحهٔ مهمان، لاگ قطعاً `anonymous_session` نشان می‌دهد و پیام خطای نهایی به جای لودینگ بی‌پایان، دلیل واقعی را می‌گوید.

**تست:** `test/core/ai/web_bridge/anonymous_session_detection_test.dart`

**commit:** `fix(web-bridge): detect anonymous sessions instead of assuming authed (DET-28)`

---

### DET-29 — منبع واقعی به جای `src=unknown`

**باگ:** در لاگ کاربر، ۱۱ رکورد از ۱۳ رکورد مقدار `src=unknown` دارند. یعنی در عمل نمی‌دانیم هر رویداد از کدام لایه آمده.

**فایل‌ها:** `chatgpt_js_injector.dart`، `web_bridge_event.dart`، `chatgpt_web_bridge_manager.dart`

**کار دقیق:** این تسک متمم DET-01 است. قاعدهٔ قطعی: هر فراخوانی `notifyFlutter` باید کلید `source` داشته باشد و مقدارش دقیقاً یکی از مقادیر `BridgeSource` باشد. نگاشت الزامی:
- رویدادهای چرخهٔ عمر (`ready`، `selector_health`، `resumed`، `watcher_tick`، `auto_dismiss`) ← `lifecycle`
- رویدادهای مسیر شبکه (`network_conversation_started`، تکه‌های SSE، `http_error`) ← `sse` یا `fetch`
- رویدادهای مشتق از DOM ← `dom`
- نتیجهٔ برداشت دستی ← `harvest`
- رویدادهای مسدودی و احراز هویت (`vpn_required`، `cloudflare_challenge`، `cloudflare_resolved`، `auth_required`) ← `lifecycle`

در سمت دارت، اگر یک رویداد بدون `source` رسید، علاوه بر مقداردهی پیش‌فرض، یک trace با نوع `missing_source` و سطح `warning` بزن تا در توسعه دیده شود.

**معیار پذیرش:** در لاگ صادرشدهٔ بعدی، تعداد `src=unknown` باید **صفر** باشد.

**تست:** `test/core/ai/web_bridge/notify_payload_has_source_test.dart` (همان تست DET-01 را گسترش بده تا نگاشت بالا را هم چک کند)

**commit:** `fix(web-bridge): stamp a real source on every bridge event (DET-29)`

---

## فاز H — افق شکست و منبع واحد زمان‌ها

---

### DET-30 — سه چک‌پوینت به جای دو

**باگ:** چک‌پوینت‌های فعلی روی `checkpoint1Delay = 25s` و `checkpoint2Delay = 55s` هستند، ولی `generationTimeout = 180s` است. یعنی بین ثانیهٔ ۵۵ تا ۱۸۰ یک درهٔ ۱۲۵ ثانیه‌ای بدون هیچ تلاش برای بازیابی وجود دارد.

**فایل‌ها:** `chatgpt_bridge_timeouts.dart`، `chatgpt_web_bridge_manager.dart`

**کار دقیق:**
1. ثابت `checkpoint3Delay` با مقدار ۱۲۰ ثانیه اضافه کن.
2. مقادیر را به این شکل تنظیم کن: `checkpoint1Delay = 12s`، `checkpoint2Delay = 30s`، `checkpoint3Delay = 60s`، و یک چک‌پوینت چهارم در ۱۲۰ ثانیه.
3. هر چک‌پوینت باید شمارهٔ خود را در trace بنویسد تا در لاگ بفهمیم کدام شلیک کرده.
4. چک‌پوینت اول (۱۲ ثانیه) مهم‌ترین است: اگر تا آن لحظه نه رویداد شبکه‌ای آمده و نه گره دستیار جدیدی ساخته شده، یک برداشت اجباری بزن و `selector_health` با فاز `post_first_text` بفرست.

**معیار پذیرش:** در هر درخواستی که شکست بخورد، دست‌کم چهار رکورد تشخیصی در لاگ ثبت شده باشد، نه سکوت.

**تست:** `test/core/ai/web_bridge/checkpoint_schedule_test.dart`

**commit:** `feat(web-bridge): add a third recovery checkpoint (DET-30)`

---

### DET-31 — شکست سریع وقتی هیچ نشانه‌ای از تولید نیست

**باگ:** `firstTokenTimeout = 60s` بلند است، و مهم‌تر اینکه وقتی مطمئنیم پیام اصلاً ارسال نشده، انتظار ۶۰ ثانیه‌ای بی‌معنی است.

**فایل‌ها:** `chatgpt_bridge_timeouts.dart`، `chatgpt_web_bridge_manager.dart`

**کار دقیق:**
1. `firstTokenTimeout` را از ۶۰ به ۴۵ ثانیه بیاور.
2. یک شرط شکست سریع اضافه کن: اگر در ثانیهٔ ۱۲ همزمان هر سه شرط برقرار بود — رویداد `send_confirmed` دریافت نشده، هیچ `network_conversation_started` نیامده، و تعداد گره‌های دستیار تغییر نکرده — استریم را فوراً با `WebBridgeException.composerNotFound()` شکست بده و `fast_fail_no_send_evidence` ثبت کن.
3. پیام کاربر در این حالت باید دقیق باشد، نه پیام عمومی تایم‌اوت.

**معیار پذیرش:** سناریوی دقیق لاگ کاربر (صفر رویداد شبکه، صفر گره دستیار) در ثانیهٔ ۱۲ با پیام فارسی مشخص تمام می‌شود، نه پس از سه دقیقه لودینگ.

**تست:** `test/core/ai/web_bridge/fast_fail_no_send_evidence_test.dart`

**commit:** `feat(web-bridge): fail fast when there is no evidence the prompt was sent (DET-31)`

---

### DET-32 — حذف اعداد زمانی خام از JS

**باگ:** در `chatgpt_js_injector.dart` اعداد `170000` و `175000` مستقیم نوشته شده‌اند. این اعداد با `generationTimeout = 180s` دارت هماهنگ‌اند ولی هیچ چیز این هماهنگی را حفظ نمی‌کند. هر تغییر طرف دارت، دو لایه را بی‌صدا ناهماهنگ می‌کند.

**فایل‌ها:** `chatgpt_js_injector.dart`، `chatgpt_bridge_timeouts.dart`

**کار دقیق:** اسکریپت‌ها را به توابع سازنده تبدیل کن که مقادیر زمانی را از `ChatGptBridgeTimeouts` می‌خوانند و درون متن JS تزریق می‌کنند. دو ثابت جدید اضافه کن: `jsHardTimeout` و `jsFinalHarvestTimeout`، و مقدارشان را بر اساس `generationTimeout` محاسبه کن (مثلاً ده و پنج ثانیه کمتر) تا همیشه درون پنجرهٔ دارت بمانند.

**معیار پذیرش:** جستجوی اعداد `170000` و `175000` در کل مخزن باید خالی باشد.

**تست:** `test/core/ai/web_bridge/timeout_values_single_source_test.dart` — متن اسکریپت را بساز و assert کن مقادیر زمانی درونش دقیقاً با ثابت‌های کلاس مطابقت دارند.

**commit:** `refactor(web-bridge): inject timeout values into the injected scripts (DET-32)`

---

### DET-33 — پنجرهٔ سکوت واقعی برای پایان تولید

**باگ:** `evaluateStreamCompletion` با رأی‌گیری و شرط سکوت ۸۰۰ میلی‌ثانیه کار می‌کند، که برای پاسخ‌های کند یا ارتباط ضعیف خیلی کوتاه است و می‌تواند پاسخ نیمه‌کاره را تمام‌شده اعلام کند.

**فایل‌ها:** `chatgpt_js_injector.dart`، `chatgpt_bridge_timeouts.dart`

**کار دقیق:** دو ثابت جدید `streamSettleSilence` (۱۲۰۰ میلی‌ثانیه) و `streamSettleSilenceFallback` (۵۰۰۰ میلی‌ثانیه) اضافه کن و اعداد خام ۸۰۰ و ۴۰۰۰ را با آن‌ها جایگزین کن. علاوه بر این، شرط پایان را فقط وقتی معتبر بدان که دست‌کم یک از این دو برقرار باشد: دکمهٔ توقف ناپدید شده باشد، یا نشانگر درحال‌تایپ ناپدید شده باشد. سکوت خالی بدون هیچ‌کدام فقط پس از پنجرهٔ فالبک معتبر است.

**معیار پذیرش:** پاسخ‌های بلند با مکث‌های طبیعی دیگر وسط کار بریده نمی‌شوند.

**تست:** `test/core/ai/web_bridge/stream_settle_window_test.dart`

**commit:** `fix(web-bridge): require a real stop signal before declaring completion (DET-33)`

---

## فاز I — لایهٔ نمایش و تجربهٔ کاربر

---

### DET-34 — تصمیم دربارهٔ استریم زنده

**باگ:** در مدیر، مقدار `enableWebBridgeStreaming = false` است. یعنی کاربر تا لحظهٔ پایان مطلقاً هیچ متنی نمی‌بیند. در کنار هر خطای تشخیص، این دقیقاً همان تجربه‌ای است که کاربر گزارش کرد: پاسخ در مرورگر حاضر است ولی صفحهٔ چت سه دقیقه خالی می‌ماند و هیچ سرنخی به کاربر نمی‌دهد.

**فایل‌ها:** `chatgpt_web_bridge_manager.dart`، `streaming_chat_service.dart`

**کار دقیق:**
1. `enableWebBridgeStreaming` را به `true` تغییر بده.
2. برای جلوگیری از لرزش متن، تحویل تکه‌ها را با یک تایمر جمع‌بندی ۲۰۰ میلی‌ثانیه‌ای به لایهٔ نمایش بفرست، نه به ازای هر تیک ۳۵۰ میلی‌ثانیه‌ای.
3. قاعدهٔ کتمان ابزار را دست نزن: اگر متن در حال دریافت شامل سنتینل فراخوانی ابزار باشد، همچنان نباید به کاربر نشان داده شود (همان منطق موجود در لایهٔ ایجنت).
4. اگر روی دستگاه‌های کند مشکل عملکردی دیدی، مقدار را به یک کلید تنظیمات وصل کن، نه یک ثابت کد. مقدار پیش‌فرض باید روشن باشد.

**معیار پذیرش:** کاربر حداکثر چند ثانیه پس از شروع پاسخ، اولین حروف را روی صفحه می‌بیند.

**تست:** `test/core/ai/web_bridge/streaming_enabled_test.dart`

**commit:** `feat(web-bridge): stream partial answers to the chat screen (DET-34)`

---

### DET-35 — جایگزینی لودینگ بی‌پایان با خطای دقیق فارسی

**باگ:** در تصویر کاربر، صفحه روی پیام «در حال نگارش و تحلیل پاسخ نهایی...» قفل مانده. این پیام وقتی تا ابد بماند، دروغ است.

**فایل‌ها:** `chatgpt_web_bridge_manager.dart`، `agent_loop_runner.dart`، `unified_assistant_sheet.dart`

**کار دقیق:**
1. هر مسیر شکست در مدیر باید `WebBridgeException` با `kind` و `messageFa` درست پرتاب کند. ممنوع: بستن استریم بدون خطا و بدون متن.
2. در لایهٔ نمایش، وقتی استریم با خطا تمام می‌شود، همین متن فارسی را درون حباب پیام نشان بده به همراه دکمهٔ کنش از `actionTextFa`.
3. یک دکمهٔ ثانویه «نمایش گزارش فنی» اضافه کن که خروجی `BridgeTraceLog.instance.exportAsText()` را نشان می‌دهد و دکمهٔ کپی دارد. همین گزارش بود که تشخیص این دفعه را ممکن کرد؛ باید همیشه یک کلیک فاصله داشته باشد.
4. پیام حالت را پس از ۲۰ ثانیه بی‌حرکتی به «هنوز منتظر پاسخ چت‌جی‌پی‌تی هستم...» تغییر بده تا کاربر بداند برنامه زنده است.

**معیار پذیرش:** هیچ مسیری در برنامه وجود ندارد که کاربر را بیش از پنجرهٔ تایم‌اوت روی لودینگ نگه دارد.

**تست:** `test/core/ai/web_bridge/no_infinite_loading_test.dart`

**commit:** `feat(web-bridge): replace endless loading with a real persian error (DET-35)`

---

## فاز J — بستن کار

---

### DET-36 — بازرسی نهایی و تحویل

**کار دقیق:** این تسک فقط وقتی اجرا می‌شود که DET-01 تا DET-35 همه در دفترچه وضعیت `DONE` یا `SKIPPED` با دلیل داشته باشند.

#### ۱) دستورهایی که باید خروجی **خالی** بدهند

هر کدام را اجرا کن و خروجی را در دفترچه بنویس:

```
rg -n "debugPrint" lib/core/ai/web_bridge lib/core/ai/agent
rg -n "catch \(e\) \{\}" lib/core/ai
rg -n "170000|175000" lib
rg -n "readBool\('hasComposer'\)" lib
rg -n "_status != ChatGptBridgeStatus.generating" lib/core/ai/web_bridge/chatgpt_web_bridge_manager.dart
```

اگر هر کدام خروجی داشت، کار تمام نیست. برگرد و تسک مربوطه را درست کن.

#### ۲) رشته‌هایی که باید **وجود داشته باشند**

```
rg -n "watcher_tick" lib
rg -n "prompt_typed" lib
rg -n "send_clicked" lib
rg -n "send_confirmed" lib
rg -n "ready_ignored_during_generation" lib
rg -n "ritmoIsConversationEndpoint" lib
rg -n "ritmoQueryFirstVisible" lib
rg -n "__ritmo_stream_state" lib
rg -n "BridgeErrorEvent" lib
rg -n "BridgeCloudflareResolvedEvent" lib
rg -n "checkpoint_skipped" lib
rg -n "anonymous_session" lib
rg -n "resumeDebounce" lib
rg -n "checkpoint3Delay" lib
```

هر کدام که خالی باشد یعنی تسک مربوطه واقعاً انجام نشده، حتی اگر در دفترچه `DONE` زده شده باشد.

#### ۳) دستورهای سلامت پروژه

```
flutter analyze
flutter test
dart format --set-exit-if-changed lib test
```

هر سه باید سبز باشند. تعداد تست‌های عبوری را در دفترچه ثبت کن.

#### ۴) تست دستی اجباری

برنامه را روی دستگاه اجرا کن و دقیقاً این شش سناریو را طی کن. برای هر کدام گزارش ردیابی را صادر کن و در دفترچه بچسبان:

| # | سناریو | انتظار |
|---|--------|--------|
| ۱ | یک پرسش کوتاه در حالت واردشده | متن در صفحهٔ چت ظاهر می‌شود؛ لاگ شامل `prompt_typed`، `send_clicked`، `send_confirmed`، `network_conversation_started`، `first_token`، `done` |
| ۲ | یک پرسش بلند که بیش از ۶۰ ثانیه طول بکشد | تیک‌های `watcher_tick` پیوسته‌اند؛ وضعیت تا انتها `generating` می‌ماند |
| ۳ | وسط پاسخ، از برنامه خارج شو و برگرد | دو `resumed` با mode برابر `reattached`؛ متن از دست نمی‌رود |
| ۴ | حالت مهمان (بدون ورود) | رویداد `anonymous_session` ثبت می‌شود؛ در صورت شکست، پیام فارسی مختص نمایش داده می‌شود |
| ۵ | قطع اینترنت وسط پاسخ | حداکثر تا چک‌پوینت دوم خطای فارسی می‌آید؛ لودینگ بی‌پایان نداریم |
| ۶ | پرسشی که منجر به فراخوانی ابزار می‌شود | متن فراخوانی ابزار هرگز دیده نمی‌شود؛ فقط پاسخ نهایی |

#### ۵) تکمیل دفترچه

در `docs/ai/WEB_BRIDGE_DETECTION_FIX.md` دو بخش پایانی را پر کن:

**بخش «واگرایی از پرامپت»** — هر جایی که مجبور شدی متفاوت عمل کنی، با این سه ستون: شمارهٔ تسک، آنچه پرامپت گفته بود، آنچه واقعاً انجام دادی و چرا.

**بخش «موارد باقی‌مانده»** — هر مشکلی که حین کار دیدی و در دامنهٔ این پرامپت نبود. حدس نزن و خودت سراغش نرو — فقط ثبت کن.

**commit:** `docs(web-bridge): close out the detection fix cycle (DET-36)`

---

## جدول دفترچهٔ ثبت

این جدول را در اولین کارت (DET-01) در `docs/ai/WEB_BRIDGE_DETECTION_FIX.md` بساز و پس از هر تسک دقیقاً یک سطر را به‌روز کن:

| ID | عنوان | فاز | وضعیت | commit | یادداشت |
|----|------|-----|-------|--------|---------|
| DET-01 | دفترچه و کلید source روی همهٔ پیلودها | A | DONE | f85ac419 | انجام شد |
| DET-02 | رویدادهای مسیر ارسال | A | DONE | f84ac071 | انجام شد |
| DET-03 | تیک دوره‌ای واچر | A | DONE | 5547eaf7 | انجام شد |
| DET-04 | فازبندی selector_health | A | DONE | dbd9502f | انجام شد |
| DET-05 | افزایش نسخهٔ بریج به ۹ | A | DONE | 5f0b3f0f | انجام شد |
| DET-06 | افزودن case error | B | DONE | a37a60cf | انجام شد |
| DET-07 | افزودن case cloudflare_resolved | B | DONE | pending | انجام شد |
| DET-08 | دام ایمنی رویداد ناشناخته | B | TODO | | |
| DET-09 | تست پوشش تاکسونومی | B | TODO | | |
| DET-10 | حذف cloudflare_resolved کاذب | B | TODO | | |
| DET-11 | حمل isWarm در ready | C | TODO | | |
| DET-12 | گارد generating در هندلر ready | C | TODO | | |
| DET-13 | مستقل‌کردن چک‌پوینت‌ها | C | TODO | | |
| DET-14 | شرط تحویل برداشت دستی | C | TODO | | |
| DET-15 | گارد مرکزی خروج از وضعیت | C | TODO | | |
| DET-16 | اصلاح تطبیق endpoint | D | TODO | | |
| DET-17 | پوشش fetch با شیء Request | D | TODO | | |
| DET-18 | خوانندهٔ SSE در هوک زودهنگام | D | TODO | | |
| DET-19 | ترجیح SSE بر DOM | D | TODO | | |
| DET-20 | حالت پایدار واچر | E | TODO | | |
| DET-21 | resume ایدمپوتنت | E | TODO | | |
| DET-22 | دباونس resume | E | TODO | | |
| DET-23 | شمارش بارگذاری سرد | E | TODO | | |
| DET-24 | پذیرش شناسهٔ خالی | E | TODO | | |
| DET-25 | انتخاب هوشمند دکمهٔ ارسال | F | TODO | | |
| DET-26 | تأیید واقعی ارسال | F | TODO | | |
| DET-27 | خط مبنای غنی‌تر پیش از ارسال | F | TODO | | |
| DET-28 | تشخیص نشست مهمان | G | TODO | | |
| DET-29 | حذف src=unknown | G | TODO | | |
| DET-30 | چک‌پوینت سوم | H | TODO | | |
| DET-31 | شکست سریع | H | TODO | | |
| DET-32 | حذف اعداد خام از JS | H | TODO | | |
| DET-33 | پنجرهٔ سکوت پایان | H | TODO | | |
| DET-34 | روشن‌کردن استریم زنده | I | TODO | | |
| DET-35 | حذف لودینگ بی‌پایان | I | TODO | | |
| DET-36 | بازرسی نهایی | J | TODO | | |

---

## نقشهٔ بستن ریشه‌ها

این جدول نشان می‌دهد هر ریشه دقیقاً با کدام تسک‌ها بسته می‌شود. تا وقتی تمام تسک‌های یک سطر `DONE` نشوند، آن ریشه بسته نیست.

| ریشه | توضیح | تسک‌های بستن |
|------|--------|----------------|
| R-A | هندلر `ready` گارد وضعیت ندارد و تولید در جریان را می‌کشد | DET-11، DET-12، DET-13، DET-14، DET-15 |
| R-B | `case 'error'` در پارسر نیست؛ خطاهای JS بی‌صدا دور ریخته می‌شوند | DET-06، DET-07، DET-08، DET-09، DET-10 |
| R-C | هوک شبکه endpoint واقعی گفتگو را نمی‌گیرد | DET-16، DET-17، DET-18، DET-19 |
| R-D | `__ritmo_resume` واچر زنده را ریست می‌کند | DET-20، DET-21، DET-22، DET-23، DET-24 |
| R-E | مسیر ارسال صفر ابزار دقیق دارد و دکمهٔ ارسال کورکورانه انتخاب می‌شود | DET-01، DET-02، DET-03، DET-04، DET-05، DET-25، DET-26، DET-27 |
| جانبی | تشخیص غلط ورود، افق شکست بلند، لودینگ بی‌پایان | DET-28، DET-29، DET-30، DET-31، DET-32، DET-33، DET-34، DET-35 |

---

## ترتیب اجرای اجباری

ترتیب فازها تصادفی نیست. فاز A اول است چون بدون ابزار دقیق، هیچ کدام از تسک‌های بعدی قابل تأیید نیستند. ترتیب مجاز:

```
A → B → C → D → E → F → G → H → I → J
```

اگر در میانهٔ کار مجبور شدی یک تسک را رد کنی، آن را `BLOCKED` بزن، دلیل را بنویس و **برو سراغ تسک بعدی**. هرگز به خاطر یک تسک مسدود، کل فاز را رها نکن.

دو تسک از همه مهم‌ترند و اگر فقط وقت انجام دو تا را داشتی، این دو را انجام بده: **DET-12** (گارد وضعیت) و **DET-16** (تطبیق endpoint). این دو به تنهایی احتمالاً مشکل گزارش‌شدهٔ کاربر را رفع می‌کنند، اما بدون فاز A نمی‌توانی این را ثابت کنی.

---

## یادآوری پایانی به ایجنت مجری

- نقشهٔ پیاده‌سازی ننویس. نقشه همین فایل است.
- خلاصهٔ تغییرات را به جای کد تحویل نده. هر تسک باید کامیت واقعی داشته باشد.
- از شماره‌گذاری خودساخته استفاده نکن. فقط `DET-01` تا `DET-36`.
- هر تسک با تست خودش تمام می‌شود، نه با «بعداً تست می‌نویسم».
- اگر کدی که در مخزن می‌بینی با توصیف این فایل فرق داشت، **توصیف را تغییر بده نه هدف را**: هدف ثابت است و در بخش معیار پذیرش هر تسک نوشته شده. تفاوت را در بخش واگرایی ثبت کن.
- معیار نهایی موفقیت یک جمله است: **وقتی چت‌جی‌پی‌تی در مرورگر پاسخ داده باشد، همان پاسخ باید در صفحهٔ دستیار هوشمند ریتمو دیده شود؛ و اگر نشد، کاربر باید دلیل دقیقش را به فارسی ببیند، نه یک لودینگ بی‌پایان.**
