# پرامپت اجرایی: رفع نرسیدن پاسخ چت‌جی‌پی‌تی به صفحهٔ «دستیار هوشمند» — پروژهٔ ریتمو

 
> **دامنه:** `lib/core/ai/web_bridge/`، `lib/core/ai/agent/`، `lib/core/ai/chat/`، `lib/features/assistant/`، `lib/features/chat/`
> **بستهٔ وب‌ویو:** `webview_flutter` نسخهٔ ۴ — مهاجرت به بستهٔ دیگر **ممنوع**.

---

## ۰. قواعد اجرای اجباری

**۰-۱ — نقشهٔ پیاده‌سازی ننویس.** این سند خودش نقشهٔ پیاده‌سازی است. هیچ فایل طرح، هیچ سند برنامه‌ریزی، هیچ فهرست «قدم‌های پیشنهادی» و هیچ خلاصهٔ پیش از اجرا تولید نکن. از فاز ۰ شروع کن و مستقیم کد بنویس.

**۰-۲ — بند ۲ فایل `.agents/AGENTS.md` (چرخهٔ اجباری سه‌مرحله‌ای Draft → Evaluate → Rewrite) برای این وظیفه صراحتاً لغو می‌شود.** بند ۱ (تحلیل عمیق پیش از تغییر) و بند ۳ (صفر خطا و صفر هشدار) به قوت خود باقی است و رعایتشان الزامی است.

**۰-۳ — ترتیب فازها قفل است.** فاز ۰ → ۱ → ۲ → ۳ → ۴ → ۵. ورود به فاز بعد فقط پس از سبز شدن دروازهٔ پذیرش فاز جاری مجاز است.

**۰-۴ — هر شناسهٔ `A-xx` باید صریحاً بسته شود.** در پایان هر فاز برای تک‌تک شناسه‌های آن فاز یکی از سه وضعیت را بنویس: `انجام شد` / `منتفی شد` / `مسدود شد`. اگر `منتفی شد` یا `مسدود شد` نوشتی، دلیل فنی دقیق با ارجاع به فایل و شمارهٔ خط بده. حذف بی‌صدای یک شناسه ممنوع است.

**۰-۵ — داده جعل نکن.** اگر پاسخی از مرورگر استخراج نشد، «متن خالی» یا «متن جایگزین» نساز. حالت خطای صادقانه با علت مشخص نشان بده.

**۰-۶ — هیچ خطایی را بی‌صدا نبلع.** الگوی `catch (_) {}` و `catch (e) {}` بدون لاگ در کل دامنهٔ این پرامپت ممنوع است. هر `catch` باید یا `RitmoLog.error` بزند یا خطا را بالا بدهد.

**۰-۷ — از موتورها و زیرساخت موجود استفاده کن.** `ChatGptBridgeTimeouts`، `WebBridgeException`، `RITMO_SELECTORS`، `AgentToolCallParser`، `AgentTurnKind`، `AgentDisplayResetEvent`، `PendingWebBridgeRequest` و `RitmoLog` همگی موجودند. آن‌ها را **گسترش بده**، نسخهٔ موازی نساز.

**۰-۸ — ممنوعیت‌های قطعی این پرامپت:**

- `catch (_) {}` و `catch (e) {}` بدون لاگ
- `debugPrint(` در `lib/core/ai/**` (در حال حاضر در `streaming_chat_service.dart` سه مورد وجود دارد — همه باید به `RitmoLog` تبدیل شوند)
- `document.querySelector` / `document.querySelectorAll` خام در جاوااسکریپت (فقط `querySafe` و `queryAllSafe`)
- `fontSize:` سخت‌کدشده و `Color(0x...)` سخت‌کدشده در ویجت‌های این دامنه
- رشتهٔ فارسی سخت‌کدشده در ویجت‌های جدید (باید در `app_fa.arb` باشد)
- افزودن بستهٔ جدید به `pubspec.yaml`
- تغییر `bridgeVersion` بدون به‌روزرسانی هم‌زمان تست نگهبان نسخه
- استفاده از `StreamController` تک‌مشترک در مسیری که بیش از یک شنونده دارد

**۰-۹ — فهرست اجزای موجود که باید استفاده شوند (نه بازنویسی):**

| جزء | مسیر | نقش فعلی |
|---|---|---|
| `ChatGptWebBridgeManager` | `lib/core/ai/web_bridge/chatgpt_web_bridge_manager.dart` | چرخهٔ حیات وب‌ویو، کانال JS، انتشار جریان |
| `ChatGptJsInjector` | `lib/core/ai/web_bridge/chatgpt_js_injector.dart` | اسکریپت تزریقی v7، قلاب fetch، واچر DOM |
| `ChatGptBridgeTimeouts` | `lib/core/ai/web_bridge/chatgpt_bridge_timeouts.dart` | منبع واحد مهلت‌ها |
| `WebBridgeException` | `lib/core/ai/web_bridge/web_bridge_exception.dart` | خطای نوع‌دار با پیام فارسی |
| `AgentLoopRunner` | `lib/core/ai/agent/agent_loop_runner.dart` | حلقهٔ ReAct، رندر دومرحله‌ای |
| `AgentToolCallParser` | `lib/core/ai/agent/agent_tool_call_parser.dart` | `scan`، `hasOpenTag`، `stripToolCalls`، `cleanForDisplay` |
| `StreamingChatService` | `lib/core/ai/chat/streaming_chat_service.dart` | مصرف‌کنندهٔ `ai_chat_screen` |
| `UnifiedAssistantSheet` | `lib/features/assistant/presentation/widgets/unified_assistant_sheet.dart` | مصرف‌کنندهٔ «دستیار هوشمند» |

**۰-۱۰ — فرمان‌های تایید هر فاز:**

```bash
flutter analyze                          # باید صفر error و صفر warning بدهد
flutter test                             # همهٔ تست‌ها سبز
dart format --set-exit-if-changed lib test
flutter gen-l10n                         # در فازهایی که رشتهٔ محلی‌سازی اضافه شده
```

**۰-۱۱ — قالب کامیت:** `fix(bridge): phase N — <خلاصه> [A-xx, A-yy]`

---

## ۰-۱۲. تشخیص ریشه‌ای — چرا پاسخ در کرومیوم دیده می‌شود ولی به برنامه نمی‌رسد

این یک باگ نیست؛ **شش نقص مستقل** است که هر کدام به‌تنهایی می‌تواند دقیقاً همین نشانه را بسازد. رفع یکی بدون بقیه مشکل را برنمی‌دارد.

### ریشهٔ ۱ — بن‌بست «تگ باز» در `AgentLoopRunner`: متن برای همیشه سرکوب می‌شود

در `agent_loop_runner.dart`، داخل حلقهٔ مصرف جریان:

```dart
// Stage 1: بررسی وضعیت partial token
final live = (soFar.contains('<') || soFar.contains('[') || soFar.contains('`'))
    ? AgentToolCallParser.scan(soFar)
    : AgentToolCallScan.empty;

// Stage 2: رندر فقط در صورتی که تگ باز نداریم
if (!live.hasOpenTag) {
  final combined = AgentToolCallParser.cleanForDisplay(
    _join(rawBuffer, AgentToolCallParser.stripToolCalls(soFar)),
  );
  if (combined != displayed) {
    ...
    yield AgentTokenStreamEvent(delta: delta, accumulated: combined);
  }
}
// else: تگ باز است — متن سرکوب می‌شود (Stage 2 کامیت نمی‌کند)
```

این مهلک‌ترین نقص است:

1. شرط فعال‌سازی اسکنر `soFar.contains('<') || soFar.contains('[') || soFar.contains('`')` است. یک پاسخ فارسی معمولی چت‌جی‌پی‌تی تقریباً **همیشه** حداقل یکی از این سه کاراکتر را دارد: بلوک کد با بک‌تیک، فهرست شماره‌دار با براکت، علامت کوچک‌تر در متن، یا حتی بازتاب `[دستورالعمل سیستم ریتمو]` که خود ریتمو در پرامپت فرستاده است. پس اسکنر عملاً روی همهٔ پاسخ‌ها اجرا می‌شود.
2. اگر `scan()` تشخیص دهد یک نشانهٔ ابزار **باز شده ولی بسته نشده** — که با یک بک‌تیک تکی یا یک `<` رها به‌سادگی رخ می‌دهد — `hasOpenTag` تا انتهای جریان `true` می‌ماند.
3. تا وقتی `hasOpenTag` صادق است، **هیچ `AgentTokenStreamEvent` منتشر نمی‌شود.** نه یک توکن، نه یک کاراکتر.
4. هیچ سقف زمانی و هیچ سقف طولی برای این سرکوب وجود ندارد. هیچ واچ‌داگی نیست.

نتیجه: چت‌جی‌پی‌تی در کرومیوم کامل جواب می‌دهد، پل هم چانک‌ها را درست تحویل `AgentLoopRunner` می‌دهد، اما لایهٔ رندر همهٔ آن‌ها را دور می‌ریزد و صفحهٔ چت خالی می‌ماند. **این دقیقاً نشانه‌ای است که گزارش شده.**

### ریشهٔ ۲ — `sendPrompt` روی یک استریم تک‌مشترک دوبار `listen` می‌کند و `StateError` می‌دهد

```dart
if (_status == ChatGptBridgeStatus.generating &&
    _currentStreamController != null &&
    !_currentStreamController!.isClosed) {
  RitmoLog.debug('ChatGptWebBridgeManager', 'sendPrompt BLOCKED: ...');
  yield* _currentStreamController!.stream;
  return;
}
```

`_currentStreamController` با `StreamController<String>(onCancel: ...)` ساخته می‌شود؛ یعنی **تک‌مشترک (single-subscription)**. مشترک اول همان `yield* streamController.stream` در انتهای فراخوانی قبلی است. این `yield*` دوم بلافاصله `Bad state: Stream has already been listened to.` پرتاب می‌کند.

آن استثنا در `agent_loop_runner.dart` اینجا بلعیده می‌شود:

```dart
} catch (e, st) {
  streamErrorFa = e.toString();
  RitmoLog.error('Agent', 'stream error on turn $turn: $e', e, st);
}
```

و چون `turnRaw` خالی است، حلقه با پاسخ خالی تمام می‌شود. کاربر «هیچ پاسخی دریافت نشد» می‌بیند در حالی که مرورگر در حال نوشتن جواب است.

### ریشهٔ ۳ — `_emitChunk` هنگام کوتاه‌شدن متن، بقیهٔ پاسخ را برای همیشه دور می‌ریزد

```dart
if (full != null && full.isNotEmpty) {
  final cleanFull = _sanitizeResponseText(full);
  if (cleanFull != _emittedText) {
    if (cleanFull.length > _emittedText.length) {
      final d = cleanFull.substring(_emittedText.length);
      _emittedText = cleanFull;
      controller.add(d);
    } else if (_emittedText.isEmpty) {
      _emittedText = cleanFull;
      controller.add(cleanFull);
    }
    // در غیر این صورت: بی‌صدا دور ریخته می‌شود
  }
  ...
}
```

سه نقص در همین بلوک:

- تصمیم فقط بر اساس **طول** گرفته می‌شود، نه بر اساس پیشوند بودن. اگر متن جدید پیشوند متن قبلی نباشد ولی بلندتر باشد، `substring(_emittedText.length)` وسط یک کلمه یا وسط یک کاراکتر فارسی می‌بُرد و خروجی مخدوش می‌شود.
- اگر متن جدید **کوتاه‌تر** باشد — که هنگام بازرندر شدن گره DOM توسط چت‌جی‌پی‌تی مرتب رخ می‌دهد، مثلاً وقتی پیشوند «ChatGPT said:» حذف می‌شود یا بلوک استریم با بلوک مارک‌داون نهایی جایگزین می‌شود — `_emittedText` برای همیشه جلوتر می‌ماند و **تمام چانک‌های بعدی دور ریخته می‌شوند**. بدون لاگ، بدون خطا.
- هیچ آشتی‌دهنده‌ای (reconciler) بین دو منبع مستقل وجود ندارد؛ ادامهٔ بحث در ریشهٔ ۴.

### ریشهٔ ۴ — دو تولیدکنندهٔ موازی روی یک انباره، بدون داوری

هنگام ارسال پیام، **هر دو** مسیر زیر هم‌زمان فعال می‌شوند:

- **مسیر SSE:** قلاب `window.fetch` بدنهٔ پاسخ را با `response.body.tee()` دوشاخه می‌کند و `readSSEStream` توکن‌ها را با `source: 'sse'` می‌فرستد.
- **مسیر DOM:** `__ritmo_startStreamingWatcher` با `MutationObserver` و تایمر ۳۵۰ میلی‌ثانیه‌ای متن را از DOM می‌خواند و با `source: 'dom'` می‌فرستد.

هر دو `chunk` و `done` می‌فرستند و هر دو `fullText` **خودشان** را دارند که با هم یکی نیست (نسخهٔ DOM شامل زباله‌های رابط کاربری است). `_lastChunkSource` فقط ثبت می‌شود و **هرگز برای اولویت‌دهی استفاده نمی‌شود**. نتیجه:

- هر کدام زودتر `done` بدهد جریان را می‌بندد. اگر SSE با `[DONE]` زودتر برسد و متن انباشتهٔ آن ناقص باشد، `_finishGeneration` جریان را می‌بندد و بقیهٔ پاسخ از بین می‌رود.
- تناوب `full` بین دو منبع با طول‌های متفاوت، دقیقاً همان تلهٔ «کوتاه‌شدن» ریشهٔ ۳ را می‌سازد.

### ریشهٔ ۵ — پایان زودهنگام در `evaluateStreamCompletion`

```js
var sendButton = querySafe(RITMO_SELECTORS.sendButton);
var hasSendButton = !!sendButton && !sendButton.disabled;
var idleMs = Date.now() - lastChangeTimestamp;

if (isGenerating) return false;

if (lastLength > 0) {
  if (hasSendButton && idleMs > 400) {
    return true; // Fast completion when composer send button is restored
  }
  if (idleMs > 2500) {
    return true; // Idle fallback completion
  }
}
return false;
```

جدول `RITMO_SELECTORS.sendButton` شامل `form button[type="submit"]` است که در chatgpt.com **همیشه** وجود دارد و لزوماً غیرفعال نیست. از سوی دیگر `RITMO_SELECTORS.stopButton` به `data-testid="fruitjuice-stop-button"` و `.result-streaming` تکیه دارد که نشانه‌های نسل قدیم رابط چت‌جی‌پی‌تی‌اند. اگر این‌ها دیگر مچ نشوند، `isGenerating` از همان تیک اول `false` است و با یک مکث ۴۰۰ میلی‌ثانیه‌ای — که در استریم کاملاً عادی است — `done` شلیک می‌شود و جریان با اولین تکهٔ پاسخ بسته می‌شود.

### ریشهٔ ۶ — `__ritmo_resume` پس از ناوبری SPA، پاسخ ناقص را «تمام‌شده» اعلام می‌کند

اولین پیام هر گفتگو باعث تغییر نشانی از `/` به `/c/<id>` می‌شود. `handlePageFinished` اجرا می‌شود، `_navigationReloadCount` بالا می‌رود و `__ritmo_resume` صدا زده می‌شود:

```js
var currentText = findLatestAssistantText();

if (currentText && currentText.length > 0 && currentText.length >= receivedLength) {
  notifyFlutter('resumed', { stage: 'done', requestId: reqId, source: 'dom' });
  notifyFlutter('done', { fullText: currentText, requestId: reqId, source: 'dom' });
  return;
}
```

دو نقص:

- شرط `currentText.length >= receivedLength` هنگام استریم زنده تقریباً همیشه صادق است. پس `done` با **متن ناقص لحظه‌ای** فرستاده می‌شود و جریان بسته می‌شود، در حالی که چت‌جی‌پی‌تی همچنان می‌نویسد.
- `__ritmo_resume` هرگز `window.__ritmo_active_req_id` را ست نمی‌کند. پس قلاب `fetch` پس از resume با شناسهٔ قدیمی رویداد می‌فرستد و فیلتر ضدکهنگی در `_handleJsMessage` همهٔ چانک‌های SSE را دور می‌ریزد:

```dart
if (reqId != null && reqId.isNotEmpty && reqId != _currentRequestId) {
  RitmoLog.debug('ChatGptWebBridge', 'Dropping stale JS event: ...');
  return;
}
```

همچنین سقف `_navigationReloadCount > 3` باعث می‌شود چند ناوبری بی‌ضرر SPA، تولید را با خطای «صفحه چت مکرراً بازنشانی شد» بکشد.

### ریشهٔ ۷ — دو مسیر مصرف‌کنندهٔ واگرا در UI

- `unified_assistant_sheet.dart` رویداد `AgentDisplayResetEvent` را می‌شناسد و `_suppressUntilTurnEnd` دارد.
- `streaming_chat_service.dart` که `ai_chat_screen.dart` از آن استفاده می‌کند، در زنجیرهٔ `if / else if` خود **`AgentDisplayResetEvent`، `AgentAwaitingQuestionEvent` و `AgentQuestionResolvedEvent` را اصلاً پوشش نمی‌دهد**:

```dart
if (event is AgentTokenStreamEvent) { ... }
else if (event is AgentStatusChangedEvent ||
    event is AgentStepStartedEvent ||
    event is AgentStepCompletedEvent ||
    event is AgentTurnStartedEvent ||
    event is AgentAwaitingConfirmationEvent ||
    event is AgentConfirmationResolvedEvent ||
    event is AgentConfirmationTimedOutEvent) { ... }
else if (event is AgentCompletedEvent) { ... }
else if (event is AgentErrorEvent) { ... }
```

اگر مدل ابزار `ask_user` را صدا بزند، `AgentLoopRunner` روی `AgentQuestionBroker.instance.ask(qReq)` **برای همیشه معلق می‌ماند** چون هیچ‌کس کارت پرسش را نشان نمی‌دهد. کاربر یک اسپینر ابدی می‌بیند.

### ریشهٔ ۸ — نبود هرگونه قابلیت تشخیص

هیچ نمای تشخیصی وجود ندارد. وقتی این زنجیرهٔ هشت‌حلقه‌ای می‌شکند، تنها بازخورد کاربر جملهٔ «هیچ پاسخی از هوش مصنوعی دریافت نشد.» است و تنها بازخورد توسعه‌دهنده `RitmoLog.debug` است که روی دستگاه کاربر دیده نمی‌شود. **بدون رفع این مورد، هر تغییر آیندهٔ رابط chatgpt.com دوباره همین وضعیت را می‌سازد و باز هم کور خواهیم بود.**

---

## ۰-۱۳. تصمیم‌های قطعی معماری (غیرقابل مذاکره)

**ت-۱ — انباشتگر پاسخ یک مالک واحد دارد.** یک کلاس `BridgeResponseAccumulator` تنها جایی است که متن پاسخ جمع می‌شود. `_emittedText` به‌عنوان فیلد خام حذف می‌شود.

**ت-۲ — بین SSE و DOM داوری صریح انجام می‌شود.** هر تولید یک «منبع قفل‌شده» دارد. اولین منبعی که توکن معتبر بدهد قفل را می‌گیرد؛ منبع دیگر تا پایان همان تولید فقط نقش پشتیبان دارد و `done` او نادیده گرفته می‌شود مگر منبع قفل‌شده مرده باشد.

**ت-۳ — سرکوب رندر باید سقف داشته باشد.** هیچ حالتی مجاز نیست که متن به‌طور نامحدود سرکوب شود. واچ‌داگ اجباری است.

**ت-۴ — پاسخ نهایی همیشه فلاش می‌شود.** حتی اگر تمام طول استریم سرکوب شده باشد، `AgentCompletedEvent` باید متن نهایی را به UI برساند. این تور ایمنی نهایی است.

**ت-۵ — هیچ جریانی نباید بدون علت قابل‌نمایش بسته شود.** هر بستن جریان یک `WebBridgeException` نوع‌دار با پیام فارسی و علت فنی همراه دارد.

**ت-۶ — تشخیص‌پذیری بخشی از قابلیت است، نه ابزار جانبی.** حلقهٔ رویداد پل باید یک بافر حلقوی قابل‌مشاهده داشته باشد.

**ت-۷ — سازگاری با نسخهٔ قبل حفظ می‌شود.** امضاهای عمومی موجود (`sendPrompt`، `ensureBooted`، `cancelCurrentStream`، `attachViewer`، `forceReboot`) نباید بشکنند. تست‌های موجود در `test/core/ai/web_bridge/` باید بدون تغییر سبز بمانند مگر آن‌که این سند صراحتاً تغییرشان را بخواهد.

---

## فاز ۰ — قرارداد داده و ابزار تشخیص

هدف این فاز: پیش از دست زدن به منطق، چشم باز کن. بدون `A-01` بقیهٔ کار کورکورانه است.

### A-01 — بافر ردیابی رویدادهای پل

فایل جدید `lib/core/ai/web_bridge/bridge_trace_log.dart`.

```dart
enum BridgeTraceLevel { info, warn, error }

class BridgeTraceEntry {
  final DateTime at;
  final String type;        // ready | chunk | done | http_error | ...
  final String source;      // sse | dom | fetch | lifecycle | dart
  final String? requestId;
  final int? textLength;
  final String? note;
  final BridgeTraceLevel level;
}
```

کلاس `BridgeTraceLog` تک‌نمونه با بافر حلقوی ثابت `maxEntries = 300`، متد `add(BridgeTraceEntry)`، `List<BridgeTraceEntry> get entries`، `void clear()` و `String exportAsText()` برای اشتراک‌گذاری.

قواعد:

- بافر حلقوی است؛ ورودی قدیمی حذف می‌شود و حافظه رشد نمی‌کند.
- **هرگز متن کامل پاسخ را ذخیره نکن** — فقط `textLength`. پاسخ‌ها دادهٔ شخصی کاربرند.
- `requestId` را کامل ذخیره کن؛ برای همبستگی لازم است.

### A-02 — مدل نوع‌دار رویداد پل به‌جای `Map<String, dynamic>` خام

در `chatgpt_web_bridge_manager.dart`، منطق پارس داخل `_handleJsMessage` با `readString` تودرتو و `nested['payload']` شکننده است. یک `sealed class WebBridgeEvent` با زیرکلاس‌های `BridgeReadyEvent`، `BridgeChunkEvent`، `BridgeDoneEvent`، `BridgeHttpErrorEvent`، `BridgeAuthRequiredEvent`، `BridgeCloudflareEvent`، `BridgeFirstTokenEvent`، `BridgeResumedEvent`، `BridgeUnknownEvent` بساز و یک `factory WebBridgeEvent.parse(String rawJson)`.

`_handleJsMessage` باید به `switch` روی این نوع تبدیل شود. `BridgeUnknownEvent` باید در `BridgeTraceLog` با سطح `warn` ثبت شود، نه بی‌صدا رد شود.

### A-03 — `BridgeResponseAccumulator`: تنها مالک متن پاسخ

فایل جدید `lib/core/ai/web_bridge/bridge_response_accumulator.dart`.

```dart
class AccumulatorDelta {
  final String delta;      // متنی که باید به پایین‌دست فرستاده شود
  final bool isRewrite;    // true یعنی متن قبلی باید کنار گذاشته شود
  final String fullText;
}

class BridgeResponseAccumulator {
  String get text;
  int get length;
  bool get isEmpty;
  void reset();
  AccumulatorDelta? applyFull(String incomingFull, {required String source});
  AccumulatorDelta? applyDelta(String incomingDelta, {required String source});
}
```

منطق اجباری `applyFull`:

1. متن ورودی را با همان `_sanitizeResponseText` موجود پاک کن (این تابع را به این کلاس منتقل کن و از منیجر حذف کن).
2. اگر پاک‌شده برابر متن فعلی است → `null` برگردان (بدون تغییر).
3. اگر متن فعلی خالی است → همه را به‌عنوان delta بده.
4. **اگر متن فعلی پیشوند متن ورودی است** → فقط دنبالهٔ اضافه را به‌عنوان delta بده. این تنها حالتی است که `substring` مجاز است.
5. **اگر پیشوند نیست** → این یک بازنویسی است. `AccumulatorDelta(isRewrite: true, ...)` با متن کامل جدید برگردان. **متن جدید را دور نریز.** این دقیقاً همان جایی است که کد فعلی پاسخ را می‌بلعد.
6. اگر ورودی کوتاه‌تر است ولی متن فعلی با آن شروع می‌شود، ورودی را نادیده بگیر (عقب‌گرد گذرای DOM) و در `BridgeTraceLog` با سطح `info` ثبت کن.

هیچ جای دیگری در کل مخزن اجازه ندارد متن پاسخ را دستی انباشته کند.

### A-04 — `BridgeSource` و قفل داوری منبع

```dart
enum BridgeSource { sse, dom, fetch, lifecycle }
```

در منیجر یک فیلد `BridgeSource? _lockedSource` اضافه کن:

- اولین `chunk` با متن ناتهی، منبع خود را قفل می‌کند و در `BridgeTraceLog` ثبت می‌شود.
- `chunk` از منبع غیرقفل‌شده: به انباشتگر داده می‌شود ولی فقط اگر `isRewrite` نباشد و طول را افزایش دهد (نقش پشتیبان).
- `done` از منبع غیرقفل‌شده: **نادیده گرفته می‌شود** و در ردیاب ثبت می‌شود. تنها استثنا: اگر منبع قفل‌شده بیش از `ChatGptBridgeTimeouts.heartbeatInterval * 12` هیچ چیزی نفرستاده باشد، قفل به منبع دیگر منتقل می‌شود.
- `_lockedSource` در `_finishGeneration`، `_failGeneration`، `cancelCurrentStream` و `disposeWebView` صفر می‌شود.

فیلد فعلی `_lastChunkSource` باقی می‌ماند (تست‌ها به آن وابسته‌اند) ولی دیگر تصمیم‌گیر نیست.

### A-05 — نسخهٔ پل به ۸ و تست نگهبان نسخه

`ChatGptJsInjector.bridgeVersion` را به `8` تغییر بده. علت: تمام تغییرات فاز ۳ روی بدنهٔ اسکریپت است و اسناد گرم با نسخهٔ ۷ نباید زنده بمانند.

همراه آن تست `test/core/ai/web_bridge/bridge_version_guard_test.dart` بنویس که هش پایدار `_bridgeScriptBody` را با یک ثابت مورد انتظار مقایسه کند و اگر بدنه تغییر کرده ولی `bridgeVersion` ثابت مانده، شکست بخورد. پیام شکست باید صریح بگوید: «بدنهٔ اسکریپت تغییر کرده — `bridgeVersion` را افزایش بده و ثابت هش را به‌روز کن.»

### A-06 — حذف بلع خطا در دامنهٔ پل

دو مورد `catch (_) {}` در `_safeDisposeController` و یک `catch (e) {}` در `isSidebarOpen` (سمت جاوااسکریپت) وجود دارد. همه باید لاگ بگیرند. سمت Dart با `RitmoLog.warning`، سمت JS با `console.warn('[Ritmo] ...')`.

### A-07 — حذف `debugPrint` از `streaming_chat_service.dart`

سه فراخوانی `debugPrint` وجود دارد (مسیر fallback گیت‌وی و دو مورد در پردازش `memory_ops`). همه به `RitmoLog.debug` / `RitmoLog.error` تبدیل شوند. `import 'package:flutter/foundation.dart';` اگر بلااستفاده شد حذف شود.

### A-08 — یکسان‌سازی `RitmoLog.warn` و `RitmoLog.warning`

در `chatgpt_web_bridge_manager.dart` در شاخهٔ `auth_required` از `RitmoLog.warn` استفاده شده در حالی که بقیهٔ فایل `RitmoLog.warning` را صدا می‌زند. یکی را به‌عنوان نام رسمی انتخاب کن، دیگری را در `RitmoLog` با `@Deprecated` علامت بزن و همهٔ فراخوانی‌ها را در دامنهٔ این پرامپت یکدست کن.

### 🚦 دروازهٔ پذیرش فاز ۰

- [ ] `bridge_trace_log.dart` و `bridge_response_accumulator.dart` ساخته شده‌اند و تست واحد دارند.
- [ ] `BridgeResponseAccumulator.applyFull` برای هر شش حالت (بدون تغییر، خالی، پیشوند، بازنویسی، عقب‌گرد، ورودی خالی) تست دارد.
- [ ] `WebBridgeEvent.parse` روی هر نه نوع رویداد و روی JSON خراب تست دارد.
- [ ] `bridgeVersion == 8` و تست نگهبان نسخه سبز است.
- [ ] `rg -n "catch \(_\) \{\}" lib/core/ai` خروجی خالی می‌دهد.
- [ ] `rg -n "debugPrint" lib/core/ai` خروجی خالی می‌دهد.
- [ ] `flutter analyze` صفر error و صفر warning.
- [ ] وضعیت هر هشت شناسهٔ `A-01`…`A-08` صریحاً نوشته شده است.

---

## فاز ۱ — رفع علت اصلی: پاسخ باید به صفحهٔ چت برسد

این فاز دقیقاً مشکلی را که کاربر گزارش کرده می‌بندد. پس از این فاز باید پاسخ در صفحهٔ چت دیده شود، حتی اگر فازهای بعد اجرا نشوند.

### A-09 — واچ‌داگ سرکوب: متن نباید برای همیشه حبس شود

این مهم‌ترین تغییر کل سند است.

در `agent_loop_runner.dart`، در حلقهٔ `await for (final chunk in stream)`، دو متغیر محلی اضافه کن:

```dart
var suppressedSince = 0;                 // طول soFar در لحظهٔ شروع سرکوب
DateTime? suppressedAt;                  // زمان شروع سرکوب
```

دو ثابت جدید روی کلاس:

```dart
/// اگر پس از باز شدن یک تگ، بیش از این تعداد کاراکتر بدون بسته شدن آمد،
/// تگ را متن عادی تلقی کن و رندر را آزاد کن.
static const int _maxSuppressedChars = 600;

/// سقف زمانی سرکوب — مستقل از طول متن.
static const Duration _maxSuppressionWindow = Duration(seconds: 6);
```

منطق جدید داخل حلقه:

```dart
final live = _shouldScan(soFar)
    ? AgentToolCallParser.scan(soFar)
    : AgentToolCallScan.empty;

var renderAllowed = !live.hasOpenTag;

if (live.hasOpenTag) {
  suppressedAt ??= DateTime.now();
  if (suppressedSince == 0) suppressedSince = soFar.length;

  final grewBy = soFar.length - suppressedSince;
  final elapsed = DateTime.now().difference(suppressedAt!);

  if (grewBy > _maxSuppressedChars || elapsed > _maxSuppressionWindow) {
    // تگ هرگز بسته نشد — این متن عادی است، نه فراخوانی ابزار.
    renderAllowed = true;
    RitmoLog.warning(
      'Agent',
      'suppression watchdog released render '
      '(grewBy=$grewBy, elapsedMs=${elapsed.inMilliseconds})',
    );
  }
} else {
  suppressedAt = null;
  suppressedSince = 0;
}

if (renderAllowed) {
  // همان منطق قبلی ساخت combined و yield AgentTokenStreamEvent
}
```

قواعد:

- وقتی واچ‌داگ آزاد می‌کند، باید `RitmoLog.warning` بزند **و** یک ورودی `BridgeTraceLog` با `note: 'suppression_watchdog_release'` ثبت کند. این سیگنال طلایی برای تشخیص آینده است.
- پس از آزادسازی، تا پایان همین نوبت دیگر سرکوب نکن (یک پرچم `bool watchdogReleasedThisTurn`). بازگشت به حالت سرکوب وسط نوبت باعث پرش متن در UI می‌شود.
- متغیرها در ابتدای هر نوبت `for (var turn = 1; ...)` باید بازنشانی شوند.

### A-10 — محدود کردن ماشهٔ اسکنر به نشانه‌های واقعی

شرط فعلی:

```dart
final live = (soFar.contains('<') || soFar.contains('[') || soFar.contains('`'))
```

این عملاً روی همهٔ پاسخ‌ها صادق است. یک متد خصوصی جایگزین کن:

```dart
/// فقط وقتی اسکن کن که نشانهٔ واقعی فراخوانی ابزار در متن باشد.
static bool _shouldScan(String soFar) {
  return soFar.contains('<tool_call') ||
      soFar.contains('<ritmo-tool') ||
      soFar.contains('<actions') ||
      soFar.contains('<memory_ops') ||
      soFar.contains('```tool') ||
      soFar.contains('```json') ||
      soFar.contains('[tool_call');
}
```

فهرست دقیق نشانه‌ها را از `AgentToolCallParser` و `AgentToolProtocol` بخوان و با آن دقیقاً هم‌تراز کن. اگر `AgentToolCallParser` ثابتی برای نشانه‌ها ارائه می‌دهد، همان را مصرف کن و فهرست دوم نساز؛ در غیر این صورت فهرست را به `AgentToolCallParser` منتقل کن تا منبع واحد باشد.

**مهم:** این تغییر نباید باعث نشت متن فراخوانی ابزار به UI شود. `stripToolCalls` و `cleanForDisplay` مستقل از این ماشه روی متن نهایی همچنان اجرا می‌شوند. تست‌های موجود `three_form_tool_parser_test.dart` و `partial_sentinel_guard_test.dart` باید سبز بمانند.

### A-11 — تور ایمنی نهایی: `AgentCompletedEvent` همیشه متن را می‌رساند

در `agent_loop_runner.dart` درست پیش از `yield AgentCompletedEvent(...)`، اگر متن نهایی با آخرین `displayed` فرق دارد، یک `AgentTokenStreamEvent` نهایی منتشر کن:

```dart
if (finalAnswer.isNotEmpty && finalAnswer != displayed) {
  final delta = finalAnswer.startsWith(displayed) && displayed.isNotEmpty
      ? finalAnswer.substring(displayed.length)
      : finalAnswer;
  RitmoLog.debug('Agent', 'final flush: displayedLen=${displayed.length} finalLen=${finalAnswer.length}');
  yield AgentTokenStreamEvent(delta: delta, accumulated: finalAnswer);
  displayed = finalAnswer;
}
```

این تضمین می‌کند حتی اگر تمام طول استریم سرکوب شده باشد، کاربر در نهایت پاسخ را ببیند.

### A-12 — جایگزینی `_emitChunk` با انباشتگر

کل بدنهٔ `_emitChunk` بازنویسی می‌شود تا از `BridgeResponseAccumulator` (A-03) و قفل منبع (A-04) استفاده کند:

```dart
void _emitChunk(String? full, String? delta, {String source = 'dom'}) {
  final src = _parseSource(source);
  if (src == BridgeSource.sse) _hasActiveSseStream = true;
  _lastChunkSource = source;

  final controller = _currentStreamController;
  if (controller == null || controller.isClosed) {
    _trace('chunk', src, note: 'dropped_no_controller');
    return;
  }

  _acquireSourceLockIfNeeded(src);

  AccumulatorDelta? result;
  if (full != null && full.isNotEmpty) {
    result = _accumulator.applyFull(full, source: source);
  } else if (delta != null && delta.isNotEmpty) {
    result = _accumulator.applyDelta(delta, source: source);
  }

  if (result == null) return;

  if (result.isRewrite) {
    // متن قبلی بی‌اعتبار شده — مصرف‌کننده باید بازنویسی کند.
    controller.add(_rewriteSentinel + result.fullText);
  } else {
    controller.add(result.delta);
  }

  _pendingRequest?.stage = PendingRequestStage.streaming;
  _pendingRequest?.receivedLength = _accumulator.length;
  _trace('chunk', src, textLength: _accumulator.length);
}
```

دربارهٔ `isRewrite`: چون `Stream<String>` فقط رشته می‌فرستد، یک نشانهٔ کنترلی لازم است. دو راه مجاز است — **یکی را انتخاب کن و در کل کد پایبند بمان**:

- **راه الف (ترجیحی):** امضای `sendPrompt` را از `Stream<String>` به `Stream<BridgeChunk>` تغییر بده که `BridgeChunk` دارای `text` و `isRewrite` است، و هر دو مصرف‌کننده (`AgentLoopRunner` و `AIGateway`) را به‌روز کن.
- **راه ب:** یک `_rewriteSentinel` ثابت و غیرقابل تولید توسط مدل (مثلاً `'\u0000RITMO_REWRITE\u0000'`) در ابتدای رشته قرار بده و در `AgentLoopRunner` پیش از `turnRaw.write(chunk)` آن را تشخیص بده و `turnRaw.clear()` کن.

اگر راه ب را انتخاب کردی، حتماً تستی بنویس که ثابت‌ماندن نشانه در خروجی نهایی کاربر را ممنوع کند.

فیلد `_emittedText` حذف می‌شود و هر جا به آن مراجعه شده (`sendPrompt`، `_finishGeneration`، `_failGeneration`، `cancelCurrentStream`، `disposeWebView`، `forceReboot`، شاخهٔ `auth_required`، شاخهٔ `http_error`، تایمر تولید) با `_accumulator.isEmpty` یا `_accumulator.length` جایگزین می‌شود. `_accumulator.reset()` در همان نقاطی صدا زده می‌شود که امروز `_emittedText = ''` اجرا می‌شود.

### A-13 — رفع `StateError` در محافظ درخواست در‌جریان

این بلوک در `sendPrompt` معیوب است:

```dart
if (_status == ChatGptBridgeStatus.generating && ...) {
  yield* _currentStreamController!.stream;   // پرتاب StateError
  return;
}
```

دو اصلاح همزمان:

1. `_currentStreamController` را به `StreamController<String>.broadcast()` تبدیل **نکن** — با broadcast، چانک‌های قبل از اشتراک از دست می‌روند و مشکل بدتر می‌شود. به‌جای آن، محافظ را به یک رد صریح تبدیل کن:

```dart
if (_status == ChatGptBridgeStatus.generating &&
    _currentStreamController != null &&
    !_currentStreamController!.isClosed) {
  RitmoLog.warning('ChatGptWebBridgeManager',
      'sendPrompt refused: generation already in flight (reqId: $_currentRequestId)');
  _trace('send_refused', BridgeSource.lifecycle, note: 'already_generating');
  yield 'error:یک پاسخ در حال دریافت است. لطفاً تا پایان آن صبر کنید یا انصراف بدهید.';
  return;
}
```

2. علت ریشه‌ای را هم ببند: در `streaming_chat_service.dart` مسیر fallback به `AIGateway` وقتی `isChatGptWeb` است اجرا نمی‌شود (درست است)، ولی `AIGateway.sendStreamingCompletion` خودش وقتی `baseUrl.contains('chatgpt.com')` است پل را صدا می‌زند. این یعنی دو مسیر موازی می‌توانند همزمان `sendPrompt` بزنند. در `AIGateway` یک گارد بگذار که اگر `ChatGptWebBridgeManager.instance.status == generating` باشد، مسیر پل را دوباره صدا نزند و خطای معنادار بدهد.

### A-14 — حل مسابقهٔ `done` دوگانهٔ SSE و DOM

در `_handleJsMessage`، شاخهٔ `done` باید پیش از فراخوانی `_finishGeneration` از قفل منبع عبور کند:

```dart
case 'done':
  final src = _parseSource(source);
  if (_lockedSource != null && src != _lockedSource) {
    RitmoLog.debug('ChatGptWebBridge',
        'Ignoring done from non-locked source $src (locked: $_lockedSource)');
    _trace('done', src, note: 'ignored_non_locked_source');
    break;
  }
  _finishGeneration(readString('fullText'));
  break;
```

علاوه بر آن، در سمت جاوااسکریپت، `readSSEStream` نباید وقتی `[DONE]` دید فوراً `done` بفرستد اگر واچر DOM هنوز در حال دیدن رشد متن است. پیش از ارسال `done` از SSE، یک تاخیر مهارشده بگذار:

```js
// پس از [DONE] یا پایان ریدر، یک پنجرهٔ کوتاه برای تثبیت DOM بده
setTimeout(function () {
  var domText = findLatestAssistantText();
  var best = (domText && domText.length > state.accumulatedText.length)
      ? domText
      : state.accumulatedText;
  notifyFlutter('done', { fullText: best, requestId: reqId, source: 'sse' });
}, 500);
```

### A-15 — رفع پایان زودهنگام در `evaluateStreamCompletion`

منطق جدید:

```js
function evaluateStreamCompletion() {
  var stopButton = querySafe(RITMO_SELECTORS.stopButton);
  var isStreamingClass = querySafe(RITMO_SELECTORS.streamingIndicator);
  var isGenerating = !!stopButton || !!isStreamingClass;

  // مشاهدهٔ گذار: دکمهٔ توقف باید اول دیده شود و بعد ناپدید شود.
  if (isGenerating) {
    sawGeneratingSignal = true;
    return false;
  }

  if (lastLength === 0) return false;

  var idleMs = Date.now() - lastChangeTimestamp;

  // ۱) مسیر مطمئن: سیگنال تولید را دیدیم و حالا رفته است.
  if (sawGeneratingSignal && idleMs > 700) return true;

  // ۲) مسیر نامطمئن: هرگز سیگنال تولید ندیدیم (سلکتورها منسوخ‌اند).
  //    فقط پس از یک سکوت طولانی پایان را بپذیر.
  if (!sawGeneratingSignal && idleMs > 4000) {
    notifyFlutter('selector_health', {
      issue: 'no_generating_signal_observed',
      requestId: reqId,
      source: 'dom'
    });
    return true;
  }

  return false;
}
```

متغیر `sawGeneratingSignal` در `__ritmo_startStreamingWatcher` کنار `lastLength` تعریف و در هر شروع واچر `false` می‌شود.

**شرط `hasSendButton && idleMs > 400` کاملاً حذف می‌شود.** به دکمهٔ ارسال به‌عنوان سیگنال پایان اعتماد نکن؛ `form button[type="submit"]` در جدول سلکتور است و همیشه موجود است.

تست `multi_signal_done_test.dart` را متناسب با منطق جدید به‌روز کن.

### A-16 — `__ritmo_resume` نباید پاسخ ناقص را تمام‌شده اعلام کند

بلوک فعلی که با `currentText.length >= receivedLength` فوراً `done` می‌فرستد حذف می‌شود. رفتار جدید:

```js
window.__ritmo_resume = function (payload) {
  try {
    payload = payload || {};
    var reqId = payload.requestId || '';
    var receivedLength = payload.receivedLength || 0;

    // A-17: شناسهٔ فعال باید بازگردانده شود، وگرنه رویدادهای SSE کهنه تلقی می‌شوند
    window.__ritmo_active_req_id = reqId;

    var currentText = findLatestAssistantText();
    notifyFlutter('resumed', {
      stage: 'streaming',
      requestId: reqId,
      recoveredLength: currentText ? currentText.length : 0,
      source: 'dom'
    });

    // متن موجود را به‌عنوان chunk بفرست — نه done.
    if (currentText && currentText.length > 0) {
      notifyFlutter('chunk', {
        fullText: currentText,
        requestId: reqId,
        source: 'dom'
      });
    }

    // واچر را با خط پایهٔ درست ادامه بده — نه رشتهٔ خالی.
    window.__ritmo_startStreamingWatcher(RITMO_RESUME_BASELINE, reqId);
  } catch (e) {
    console.error('[Ritmo] Error in __ritmo_resume: ' + e);
    notifyFlutter('error', {
      message: 'خطا در بازیابی پاسخ پس از جابجایی صفحه: ' + e.toString(),
      requestId: payload && payload.requestId,
      source: 'dom'
    });
  }
};
```

دربارهٔ `RITMO_RESUME_BASELINE`: مقدار `''` فعلی غلط است چون باعث می‌شود واچر متن پیام کاربر یا یک نوبت قدیمی را به‌عنوان پاسخ بپذیرد. خط پایه باید متن آخرین پیام دستیاری باشد که **پیش از ارسال این نوبت** وجود داشت. آن را در `injectAndTriggerSend` در یک متغیر سراسری ذخیره کن:

```js
window.__ritmo_turn_baseline = previousBaselineText;
```

و در `__ritmo_resume` از `window.__ritmo_turn_baseline || ''` استفاده کن.

### A-17 — بازگرداندن `__ritmo_active_req_id` پس از ناوبری

در A-16 اعمال شد، ولی دو نقطهٔ دیگر هم باید پوشش داده شوند:

- `window.__ritmo_cleanup` خط `window.__ritmo_active_req_id = null;` دارد. این درست است ولی باید پیش از آن مقدار قدیم در `window.__ritmo_prev_req_id` نگه داشته شود تا در `__ritmo_resume` در صورت خالی بودن payload قابل بازیابی باشد.
- در سمت Dart، زمانی که رویدادی به دلیل عدم تطابق `requestId` دور ریخته می‌شود، **حتماً** در `BridgeTraceLog` با سطح `warn` ثبت شود. دور ریختن بی‌صدای چانک دقیقاً همان چیزی است که این باگ را گرفتنش را غیرممکن کرده بود.

### A-18 — سقف ناوبری نباید ناوبری‌های بی‌ضرر SPA را بکشد

در `handlePageFinished`:

```dart
if (_navigationReloadCount > 3) {
  _failGeneration(WebBridgeException.navigationLoop());
  return;
}
```

دو اصلاح:

1. سقف را به `6` افزایش بده و به‌عنوان ثابت `maxNavigationReloads` در `ChatGptBridgeTimeouts` یا در خود منیجر تعریف کن (عدد جادویی درجا ممنوع).
2. **مهم‌تر:** اگر انباشتگر خالی نیست، به‌جای `_failGeneration` باید `_finishGeneration(null)` صدا زده شود. دور ریختن پاسخی که نصفش رسیده، بدترین رفتار ممکن است:

```dart
if (_navigationReloadCount > maxNavigationReloads) {
  RitmoLog.error('ChatGptWebBridge', 'Navigation reload loop detected.');
  if (!_accumulator.isEmpty) {
    RitmoLog.warning('ChatGptWebBridge',
        'Salvaging ${_accumulator.length} chars before aborting on navigation loop.');
    _finishGeneration(null);
  } else {
    _failGeneration(WebBridgeException.navigationLoop());
  }
  return;
}
```

همین اصل «اول نجات بده، بعد خطا بده» باید در `handleWebResourceError` و `handleHttpError` هم اعمال شود.

### 🚦 دروازهٔ پذیرش فاز ۱

- [ ] واچ‌داگ سرکوب پیاده شده و تستی دارد که با یک `<` رهاشده در وسط پاسخ، متن در نهایت رندر می‌شود.
- [ ] `_shouldScan` پیاده شده و یک پاسخ فارسی حاوی بلوک کد و براکت، اسکنر را فعال نمی‌کند.
- [ ] `_emittedText` دیگر در مخزن وجود ندارد (`rg -n "_emittedText" lib/` خالی).
- [ ] تستی وجود دارد که پس از یک `full` کوتاه‌تر و غیرپیشوند، چانک‌های بعدی همچنان منتشر می‌شوند.
- [ ] فراخوانی دوم `sendPrompt` در حین تولید، `StateError` پرتاب نمی‌کند و خطای فارسی معنادار می‌دهد.
- [ ] `done` از منبع غیرقفل‌شده جریان را نمی‌بندد.
- [ ] `hasSendButton && idleMs > 400` در کد وجود ندارد.
- [ ] `__ritmo_resume` دیگر `done` نمی‌فرستد و `__ritmo_active_req_id` را ست می‌کند.
- [ ] لوپ ناوبری با انباشتگر غیرخالی به `_finishGeneration` می‌رسد، نه `_failGeneration`.
- [ ] `flutter analyze` صفر خطا و صفر هشدار؛ وضعیت `A-09`…`A-18` نوشته شده.

---

## فاز ۲ — یکپارچه‌سازی دو مسیر مصرف‌کنندهٔ UI

در حال حاضر دو صفحه رویدادهای ایجنت را مصرف می‌کنند و رفتارشان متفاوت است. این فاز آن واگرایی را حذف می‌کند.

### A-19 — `StreamingChatService` سه خانواده رویداد را بی‌صدا دور می‌ریزد

زنجیرهٔ `else if` در `streaming_chat_service.dart` را با الگوی پوشش‌کامل جایگزین کن. سه رویداد زیر امروز هیچ شاخه‌ای ندارند و به صفحه نمی‌رسند:

| رویداد | پیامد فعلی |
|---|---|
| `AgentDisplayResetEvent` | متن نوبت فراخوانی ابزار در صفحه باقی می‌ماند و با پاسخ نهایی قاطی می‌شود |
| `AgentAwaitingQuestionEvent` | ایجنت روی `ask_user` برای همیشه معلق می‌ماند — اسپینر ابدی |
| `AgentQuestionResolvedEvent` | کارت پرسش هرگز بسته نمی‌شود |

الگوی اجباری جدید: به‌جای فهرست کردن رویدادهای مجاز برای عبور، فقط رویدادهایی را که رفتار ویژه دارند جدا کن و **بقیه را به‌طور پیش‌فرض عبور بده**:

```dart
await for (final event in agentStream) {
  if (event is AgentTokenStreamEvent) {
    // منطق موجود تولید ChatChunk
    continue;
  }

  if (event is AgentCompletedEvent) {
    // منطق موجود پایان
    continue;
  }

  if (event is AgentErrorEvent) {
    // منطق موجود خطا
    continue;
  }

  // پیش‌فرض: هر رویداد دیگری به UI عبور داده می‌شود.
  // افزودن زیرکلاس جدید به AgentEvent نباید باعث بلع شدن آن شود.
  yield AgentStreamEvent(event);
}
```

این وارونه‌سازی پیش‌فرض (از allow-list به deny-list) تضمین می‌کند هر رویدادی که در آینده به `agent_event.dart` اضافه شود خودبه‌خود به UI می‌رسد.

### A-20 — تست نگهبان پوشش کامل رویدادها

فایل جدید `test/core/ai/chat/agent_event_forwarding_test.dart`:

- یک فهرست ثابت از **تمام** زیرکلاس‌های `AgentEvent` بساز (در حال حاضر ۱۳ مورد).
- هر کدام را در یک استریم جعلی به `StreamingChatService` بده.
- تأیید کن که هر کدام یا به‌صورت `AgentStreamEvent` عبور کرده یا به یک رویداد اختصاصی (`ChatChunk` / `ChatComplete` / `ChatErrorEvent`) ترجمه شده است.
- **هیچ رویدادی نباید بدون خروجی باشد.**

اگر روزی کسی زیرکلاس جدیدی بسازد و فهرست تست را به‌روز نکند، یک تست دوم با مقایسهٔ تعداد زیرکلاس‌های شمارش‌شده در `agent_event.dart` با طول فهرست، شکست خواهد خورد. این شمارش را با خواندن فایل منبع در خود تست و رگکس `class \w+Event extends AgentEvent` انجام بده (همان الگوی `test/prompt_036_source_guards_test.dart`).

### A-21 — یک مسیر واحد برای هر دو مصرف‌کننده

`unified_assistant_sheet.dart` مستقیماً `AgentLoopRunner` را مصرف می‌کند و `ai_chat_screen.dart` از `StreamingChatService` رد می‌شود. نتیجه: هر رفع باگی باید دو بار انجام شود و همیشه یکی فراموش می‌شود.

منطق مشترک زیر را در یک مکان متمرکز کن — فایل جدید `lib/core/ai/agent/ui/agent_stream_presenter.dart`:

```dart
/// ماشین حالت نمایش مشترک بین همهٔ مصرف‌کنندگان جریان ایجنت.
class AgentStreamPresenter {
  String get visibleText;
  bool get isWorking;
  bool get isSuppressed;
  AgentQuestionRequest? get pendingQuestion;
  AgentConfirmationRequest? get pendingConfirmation;
  String? get errorFa;

  /// تنها نقطهٔ ورود. هر رویداد ایجنت از اینجا رد می‌شود.
  void apply(AgentEvent event);
  void reset();
}
```

قواعد:

- منطق `_suppressUntilTurnEnd` موجود در `unified_assistant_sheet.dart` به این کلاس منتقل می‌شود، نه کپی.
- هر دو صفحه از این پرزنتر استفاده می‌کنند. هیچ صفحه‌ای اجازه ندارد خودش روی `AgentEvent` شرط بزند.
- پرزنتر هیچ وابستگی به Flutter widget ندارد تا قابل تست واحد باشد.

### A-22 — خطای «هیچ پاسخی دریافت نشد» باید علت فنی حمل کند

خط فعلی:

```dart
if (accumulated.trim().isEmpty) {
  yield ChatErrorEvent('هیچ پاسخی از هوش مصنوعی دریافت نشد.', '');
  return;
}
```

این دقیقاً پیامی است که کاربر می‌بیند و هیچ اطلاعی نمی‌دهد. باید علت را از وضعیت پل بخواند:

```dart
if (accumulated.trim().isEmpty) {
  final reason = ChatGptWebBridgeManager.instance.describeEmptyResponseReason();
  RitmoLog.error('StreamingChat', 'empty response: $reason');
  yield ChatErrorEvent(reason.messageFa, reason.technicalDetail);
  return;
}
```

متد جدید `describeEmptyResponseReason()` در منیجر، بر اساس وضعیت و آخرین ورودی‌های `BridgeTraceLog` یکی از این موارد را برمی‌گرداند:

| شرایط تشخیصی | پیام فارسی به کاربر |
|---|---|
| هیچ `chunk` ثبت نشده و وضعیت `ready` بوده | «چت‌جی‌پی‌تی پاسخ داد، اما برنامه نتوانست متن را از صفحهٔ مرورگر بخواند. احتمالاً رابط کاربری چت‌جی‌پی‌تی تغییر کرده است.» |
| چانک دریافت شده ولی رندر سرکوب شده | «پاسخ دریافت شد ولی قابل نمایش نبود. دوباره تلاش کنید.» |
| رویدادها به دلیل `requestId` کهنه دور ریخته شده | «ارتباط با گفتگو قطع شد. پیام را دوباره بفرستید.» |
| وضعیت `cloudflareChallenge` | پیام موجود `WebBridgeException.cloudflareChallenge()` |
| وضعیت `error` با احراز هویت | پیام موجود `WebBridgeException.authRequired()` |
| مهلت تولید تمام شده | «پاسخ در زمان مقرر کامل نشد.» |

همراه هر خطا، یک دکمهٔ ثانویهٔ «چرا؟» نشان داده می‌شود که `WebBridgeDiagnosticsScreen` (A-39) را باز می‌کند.

### A-23 — تراشهٔ وضعیت پل در سربرگ دستیار

در سربرگ `unified_assistant_sheet.dart` و `ai_chat_screen.dart`، یک ویجت کوچک `BridgeStatusChip` بر اساس `ChatGptWebBridgeManager.instance.statusNotifier` بساز. تنها وقتی نمایش داده می‌شود که اتصال فعال، `chatgpt_web` باشد.

| وضعیت | متن تراشه | رفتار |
|---|---|---|
| `idle` | تراشه مخفی است | — |
| `booting` | «در حال اتصال به چت‌جی‌پی‌تی…» | غیرقابل لمس |
| `ready` | «متصل» | پس از ۲ ثانیه محو می‌شود |
| `generating` | «در حال دریافت پاسخ…» | لمس → پیش‌نمایش مرورگر |
| `cloudflareChallenge` | «نیاز به تأیید امنیتی» | لمس → `CloudflareChallengeModal` |
| `error` | «اتصال قطع است» | لمس → صفحهٔ تشخیص |

تمام رشته‌ها از `app_fa.arb` خوانده می‌شوند. رنگ‌ها از `Theme.of(context).colorScheme`؛ هیچ `Color(0x...)`.

### A-24 — دسترسی مستقیم به پیش‌نمای مرورگر در حین تولید

`chatgpt_mini_preview.dart` وجود دارد ولی کاربر در حین انتظار راهی برای باز کردنش ندارد. در حالت `generating`، دکمهٔ «مشاهدهٔ مرورگر» را فعال کن.

قواعد مهم:

- پیش‌نما **فقط خواندنی** است. تست موجود `preview_is_viewer_only_test.dart` باید سبز بماند.
- باز کردن پیش‌نما **نباید** باعث `disposeWebView` یا `forceReboot` شود. تست‌های `no_dispose_while_generating_test.dart` و `no_reboot_while_generating_test.dart` باید سبز بمانند.
- بستن پیش‌نما نباید جریان را لغو کند.

### A-25 — سقف `cap = 8000` جریان را وسط پاسخ قطع می‌کند

در `streaming_chat_service.dart` یک سقف `const cap = 8000;` وجود دارد که وقتی متن انباشته از آن رد می‌شود، مصرف را متوقف می‌کند. در زبان فارسی هر کاراکتر یک کد‌پوینت است و ۸۰۰۰ کاراکتر حدود ۱۳۰۰ کلمه است — یک پاسخ تفصیلی برنامهٔ تمرین یا تحلیل چرخه به‌راحتی از آن عبور می‌کند.

اصلاح:

- سقف را به `32000` افزایش بده و به‌عنوان ثابت نام‌دار `maxAssistantResponseChars` تعریف کن.
- رسیدن به سقف **نباید** جریان را در سکوت ببندد. باید متن تا همان جا حفظ شود، یک `ChatChunk` نهایی منتشر شود و یک نشانگر «پاسخ بسیار طولانی بود و کوتاه شد�� در UI نشان داده شود.
- برش باید روی مرز گرافم (`characters` از بستهٔ موجود) انجام شود، نه `substring` خام، وگرنه کاراکترهای ترکیبی فارسی می‌شکنند.

### A-26 — ترتیب لغو و آزادسازی

چند نقطه در مخزن `cancelCurrentStream()` را صدا می‌زنند (از جمله `ss_ai_coach_sheet.dart`). ترتیب امن را تثبیت کن:

1. تایمرها را لغو کن (`_generationTimer`، `_inactivityTimer`).
2. به جاوااسکریپت `__ritmo_cancelGeneration` بده و خطای آن را لاگ کن (نه بلع).
3. `_lockedSource = null`، `_accumulator.reset()`، `_pendingRequest = null`، `_currentRequestId = null`.
4. استریم کنترلر را ببند و `null` کن.
5. وضعیت را به `ready` برگردان (نه `idle`، مگر وب‌ویو آزاد شده باشد).

همین ترتیب باید در `_finishGeneration` و `_failGeneration` هم رعایت شود تا حالت نشتی بین دو درخواست متوالی باقی نماند. تست `two_way_cancellation_test.dart` باید سبز بماند.

### 🚦 دروازهٔ پذیرش فاز ۲

- [ ] `StreamingChatService` هر زیرکلاس `AgentEvent` را یا ترجمه یا عبور می‌دهد؛ تست نگهبان سبز است.
- [ ] `AgentStreamPresenter` ساخته شده و هر دو صفحه از آن استفاده می‌کنند.
- [ ] `rg -n "AgentDisplayResetEvent" lib/features` دیگر منطق شرطی مستقیم نشان نمی‌دهد.
- [ ] خطای پاسخ خالی دیگر پیام ثابت نیست و دست‌کم شش حالت متمایز دارد.
- [ ] تراشهٔ وضعیت در هر دو صفحه دیده می‌شود و در حالت `idle` مخفی است.
- [ ] سقف پاسخ `32000` است و رسیدن به آن پیام صریح می‌دهد.
- [ ] `flutter analyze` صفر خطا و صفر هشدار؛ وضعیت `A-19`…`A-26` نوشته شده.

---

## فاز ۲.۵ — پروتکل کانال صریح

این فاز دقیقاً پس از فاز ۲ و پیش از فاز ۳ اجرا می‌شود. ترتیب را جابه‌جا نکن.

**مسئلهٔ معماری که این فاز حل می‌کند:** تشخیص فعلی **تفریقی** است — یعنی «هر چیزی که تگ ابزار نیست، متن کاربر است». سیستم هیچ راهی ندارد بفهمد در لحظه داخل بلوک ابزار است یا نه، پس مجبور است حدس بزند و متن را سرکوب کند. `AgentToolProtocol.buildWebBridgeToolPrompt` امروز فقط **جهت ابزار** را علامت‌گذاری می‌کند (`<tool_call>`)؛ هیچ علامت مثبتی برای «این متن را به کاربر نشان بده» وجود ندارد. این عدم تقارن را از بین ببر.

### A-57 — قرارداد علامت‌ها

فایل جدید `lib/core/ai/agent/agent_channel_protocol.dart`.

قالب قطعی:

```
RITMO_SAY
<متن فارسی برای کاربر>

RITMO_CALL:<nonce>
{"name": "...", "parameters": {...}}
RITMO_END
```

قیدهای طراحی که هیچ‌کدام قابل مذاکره نیستند:

1. علامت‌ها فقط ASCII بزرگ و `_` و `:` هستند. **هیچ `<`، `[` یا بک‌تیکی در علامت به کار نبر** — دقیقاً همین سه کاراکتر ماشهٔ باگ سرکوب در `AgentLoopRunner` هستند.
2. علامت باید **سرِ خط** باشد، نه سرِ پیام. یک نوبت چت‌جی‌پی‌تی یک پیام است که می‌تواند هم‌زمان متن و فراخوانی ابزار داشته باشد؛ پیشوند ابتدای پیام این دو را جدا نمی‌کند.
3. پیش از تطبیق، کاراکترهای کنترلی دوجهته حذف شوند: `U+200E`، `U+200F`، `U+061C`، `U+202A`…`U+202E`، `U+2066`…`U+2069`. در جملهٔ فارسی، الگوریتم bidi دور متن ASCII این کاراکترها را درج می‌کند و تطبیق خام شکست می‌خورد.
4. علامت باید هم لخت و هم داخل حصار کد پذیرفته شود. چت‌جی‌پی‌تی وقتی پروتکل می‌بیند اغلب آن را داخل ``` می‌گذارد.
5. علامت باید به ضخامت‌دادن مقاوم باشد: `**RITMO_SAY**` و `__RITMO_SAY__` هم معتبرند.

مقادیر صادرشده: `channelSayMarker`، `channelCallMarker`، `channelEndMarker`، `bidiControlPattern`، `normalizeMarkerLine(String)`.

### A-58 — توکن تصادفی هر جلسه (nonce)

بدون این مورد، پروتکل یک حفرهٔ امنیتی جدید باز می‌کند: هر متنی که کاربر پیست کند یا هر محتوایی که مدل از وب بخواند می‌تواند عبارت `RITMO_CALL` داشته باشد و ابزار اجرا شود.

- `AgentChannelNonce.forSession(String sessionId)` — شش کاراکتر hex از `Random.secure()`، یک بار در ابتدای هر جلسه ساخته می‌شود.
- توکن در متن دستورالعمل به مدل داده می‌شود.
- هر `RITMO_CALL` بدون توکن درست، **متن عادی است**، نه فراخوانی ابزار. رد شدن توکن باید در `BridgeTraceLog` با سطح هشدار ثبت شود.
- `AgentToolProtocol.sanitize()` باید هر سه علامت و هر رشتهٔ شبیه توکن را از متنی که منشأ آن کاربر است پاک کند. الگوی `_controlTags` موجود را گسترش بده، حذفش نکن.
- توکن هرگز لاگ نمی‌شود (اصل `test/logger_redaction_test.dart`).

### A-59 — تزریق دستورالعمل به پرامپت پل وب

`AgentToolProtocol.buildWebBridgeToolPrompt(List<AgentTool> tools)` را گسترش بده تا امضای جدید `({required String nonce})` داشته باشد و قواعد کانال را هم بنویسد:

- هر متنی که کاربر باید ببیند، زیر خط `RITMO_SAY` بیاید.
- هر فراخوانی ابزار، بین `RITMO_CALL:<nonce>` و `RITMO_END`.
- یک مثال کوتاه دونمونه‌ای (few-shot) بگذار: یکی فقط متن، یکی متن + فراخوانی.
- صریح بنویس: «اگر علامت را فراموش کردی، متن باز هم نمایش داده می‌شود؛ ولی علامت بگذار تا دقیق‌تر باشد.» این جمله عمدی است و با A-60 هماهنگ است.

دستورالعمل `<tool_call>` موجود را **حذف نکن**؛ هر دو را کنار هم نگه دار تا پایبندی مدل سنجیده شود (A-66).

### A-60 — قاعدهٔ شکست به سمت باز (مهم‌ترین قاعدهٔ این فاز)

**اگر در کل متن هیچ علامتی نبود، تمام متن به کاربر نشان داده می‌شود.**

این قاعده قابل مذاکره نیست. دلیل: در رابط وب چت‌جی‌پی‌تی هیچ تضمین پرامپت سیستمی وجود ندارد. دستورالعمل فقط یک پیام کاربر است که در گفتگوی طولانی بالا می‌رود، و پس از رفرش صفحه یا `__ritmo_resume` ممکن است عملاً فراموش شود.

اگر منطق را به شکل «فقط متنی را نشان بده که `RITMO_SAY` دارد» بنویسی، دقیقاً همین باگ گزارش‌شده را برمی‌گردانی — این بار عمدی، دائمی و سخت‌تر برای دیباگ.

جدول تصمیم قطعی:

| وضعیت متن دریافتی | رفتار |
|---|---|
| هیچ علامتی نیست | کل متن به کاربر؛ سپس پارسر قدیمی برای کشف ابزار اجرا می‌شود |
| فقط `RITMO_SAY` هست | متن زیر آن به کاربر |
| فقط `RITMO_CALL` معتبر هست | فقط ابزار؛ هیچ متنی نمایش داده نمی‌شود |
| هر دو هستند | متن `SAY` نمایش، بلوک `CALL` اجرا |
| `RITMO_CALL` با توکن غلط | متن عادی؛ هشدار در ردیاب |
| `RITMO_CALL` باز ولی `RITMO_END` نیامده تا پایان نوبت | بلوک دور ریخته می‌شود؛ متن پیش از آن نمایش داده می‌شود |

ردیف آخر مهم است: حتی در حالت بلوک ناتمام، کاربر چیزی می‌بیند.

### A-61 — پارسر کانال

`AgentChannelParser.scan(String raw, {required String nonce})` → `ChannelScan`.

```dart
class ChannelScan {
  final String visibleText;
  final List<AgentToolCall> calls;
  final bool hasOpenCallBlock;
  final bool usedLegacyFallback;
  final int rejectedNonceCount;
}
```

الزامات:

- تطبیق فقط خط‌به‌خط و با `RegExp(..., multiLine: true)` لنگرزده به `^`.
- امن برای جریان: اگر انتهای متن یک علامت نیمه‌کاره است (مثلاً `RITM`)، آن را نه نمایش بده و نه علامت بشمار — این همان الگوی `partial_sentinel_guard_test.dart` موجود است؛ از آن تقلید کن.
- بدنهٔ `RITMO_CALL` با همان `_extractFirstJsonObject` موجود در `AgentToolCallParser` دکد می‌شود. کد جدید ننویس؛ آن تابع را عمومی کن و دوباره استفاده کن.
- `visibleText` باید از همان `_noisePrefixRe` موجود (حذف `ChatGPT said:` و مشابه) عبور کند.

### A-62 — یکپارچه‌سازی با پارسر موجود

ترتیب اجرا در `AgentLoopRunner`:

1. `AgentChannelParser.scan(...)` اول اجرا می‌شود.
2. اگر هیچ علامتی پیدا نشد (`usedLegacyFallback == true`)، `AgentToolCallParser.scan(...)` موجود اجرا می‌شود.
3. هیچ کدی از `AgentToolCallParser` حذف نمی‌شود. همهٔ تست‌های موجود از جمله `three_form_tool_parser_test.dart` باید سبز بمانند.

### A-63 — تنزل دو fallback خطرناک

این یک حفرهٔ واقعی در کد فعلی است، نه یک فرضیه.

```dart
static final RegExp _codeBlockJsonRe =
    RegExp(r'```(?:json|tool)?\s*(\{[\s\S]*?\})\s*```', caseSensitive: false);
```

برچسب زبان `(?:json|tool)?` **اختیاری** است، و `_decodeBareJsonCall` هم اگر متن فقط یکی از کلیدهای `"name"`، `"data"`، `"input"` را داشته باشد آن را فراخوانی ابزار می‌شمارد.

نتیجه: اگر کاربر بپرسد «این کانفیگ JSON را برایم توضیح بده» و مدل آن را در یک بلوک کد بازتاب دهد، برنامه ممکن است آن را اجرا کند.

اصلاح:

- `_codeBlockJsonRe` فقط با برچسب صریح `json` یا `tool` معتبر باشد (`?` را حذف کن).
- `_decodeBareJsonCall` فقط وقتی اجرا شود که یا علامت کانال حاضر باشد، یا نام ابزار در `AgentToolRegistry` ثبت شده باشد.
- در هر دو حالت، نام ابزار باید پیش از اجرا در رجیستری راستی‌آزمایی شود.

### A-64 — حذف وابستگی به سقف کاراکتری در مسیر علامت‌دار

در فاز ۱، `_maxSuppressedChars = 600` یک مصالحه بود: اگر فراخوانی ابزار واقعاً بلند باشد، JSON خام به چت کاربر نشت می‌کند.

با پروتکل صریح، مرز قطعی است: سرکوب فقط بین `RITMO_CALL` و `RITMO_END` اتفاق می‌افتد و هیچ سقف کاراکتری لازم نیست.

- وقتی `ChannelScan` علامت دارد: سقف کاراکتری و سقف زمانی اعمال **نمی‌شوند**.
- وقتی fallback قدیمی فعال است: هر دو سقف دقیقاً مطابق فاز ۱ باقی می‌مانند.

این دو مسیر باید در کد صریح و قابل تمایز باشند، نه درهم‌تنیده.

### A-65 — بلوک کد عادی نباید سرکوب را فعال کند

در `AgentToolCallParser.scan`، منطق `hasOpenFenceTool` با شمارش **فرد** علامت ``` فعال می‌شود. در جریان استریم، **هر بلوک کد عادی** حتماً از فاز «فرد» عبور می‌کند — یعنی هر بار که مدل نمونه کد می‌نویسد، نمایش قطع می‌شود.

پس از این فاز:

- در مسیر علامت‌دار، `hasOpenFenceTool` کاملاً کنار گذاشته می‌شود.
- در مسیر قدیمی، فقط وقتی فعال شود که متن پس از حصار با برچسب صریح `json`/`tool` شروع شود.

نتیجهٔ ملموس: کاربر برای اولین بار می‌تواند پاسخ‌های حاوی کد را به صورت جریانی ببیند.

### A-66 — سنجش پایبندی مدل به پروتکل

بدون اندازه‌گیری، نمی‌دانی پروتکل جواب داده یا نه.

- برای هر نوبت، یک رکورد در `BridgeTraceLog` با یکی از مقادیر `channel_ok`، `channel_partial`، `channel_absent`، `channel_bad_nonce` ثبت کن.
- در `WebBridgeDiagnosticsScreen` (A-39) یک ردیف اضافه کن: «پایبندی پروتکل: N از M نوبت اخیر».
- هیچ متن پاسخی در این رکوردها ذخیره نمی‌شود — فقط دسته و طول.

این عدد معیار تصمیم آینده است: اگر پایبندی بالای ۹۵٪ باشد، می‌توان مسیر قدیمی را در نسخهٔ بعدی محدودتر کرد. **در این فاز این کار را نکن.**

### A-67 — راست‌گویی قاعدهٔ ۷ در `loopInstructions`

قاعدهٔ ۷ فعلی به مدل می‌گوید:

> «اگر پیش از فراخوانی ابزار جمله‌ای نوشته‌ای، آن جمله همان لحظه به کاربر نمایش داده شده است؛ در ادامه آن را تکرار نکن.»

با باگ سرکوب فعلی، این جمله **دروغی است که به مدل گفته می‌شود**: جمله نمایش داده نشده، ولی مدل بر اساس این فرض ادامه می‌دهد — و کاربر یک پاسخ بریده و بی‌مقدمه می‌بیند.

پس از فازهای ۱ و ۲.۵ این جمله بالاخره راست می‌شود. متن قاعده را به‌روز کن تا به `RITMO_SAY` ارجاع دهد، و در کنارش قاعدهٔ ۶ («در پاسخ نهایی هیچ JSON خامی نگذار») را حفظ کن.

### A-68 — تست‌های پروتکل کانال

فایل `test/core/ai/agent/channel_protocol_test.dart`:

1. متن فقط با `RITMO_SAY` — کل متن قابل نمایش، صفر ابزار.
2. متن با هر دو علامت — تفکیک درست.
3. **متن بدون هیچ علامت — کل متن نمایش داده می‌شود** (نگهبان A-60؛ مهم‌ترین تست این فایل).
4. `RITMO_CALL` با توکن غلط — ابزار اجرا نمی‌شود و متن عادی دیده می‌شود.
5. علامت داخل حصار کد و علامت ضخیم‌شده — هر دو معتبر.
6. علامت با کاراکترهای `U+200F` اطرافش در جملهٔ فارسی — معتبر.
7. علامت نیمه‌کاره در انتهای تکهٔ جریان — نه نمایش داده می‌شود نه اجرا.
8. `RITMO_CALL` بدون `RITMO_END` تا پایان نوبت — متن پیش از آن نمایش داده می‌شود.
9. پاسخ حاوی بلوک کد عادی ```dart — هیچ سرکوبی رخ نمی‌دهد (نگهبان A-65).
10. بلوک کد ```json حاوی `{"name": "..."}` بدون علامت و بدون نام ابزار ثبت‌شده — **اجرا نمی‌شود** (نگهبان A-63).
11. متن کاربر حاوی عبارت `RITMO_CALL` — پس از `sanitize()` دیگر علامت نیست (نگهبان A-58).

### 🚦 دروازهٔ پذیرش فاز ۲.۵

- [ ] `agent_channel_protocol.dart` و `AgentChannelParser` ساخته شده‌اند.
- [ ] nonce هر جلسه تولید، تزریق و در `sanitize()` خنثی می‌شود.
- [ ] **تست شمارهٔ ۳ در A-68 سبز است** — بدون علامت، متن همچنان دیده می‌شود.
- [ ] `three_form_tool_parser_test.dart` و `partial_sentinel_guard_test.dart` موجود هنوز سبزند.
- [ ] `rg -n "json|tool\)\?" lib/core/ai/agent/agent_tool_call_parser.dart` دیگر علامت سؤال اختیاری را نشان نمی‌دهد.
- [ ] یک نوبت واقعی با ابزار `ask_user` تا انتها کار می‌کند (وابسته به A-52 در فاز ۵؛ اگر هنوز نوشته نشده، دستی راستی‌آزمایی کن).
- [ ] ردیف پایبندی پروتکل در صفحهٔ تشخیص دیده می‌شود.
- [ ] `flutter analyze` صفر خطا و صفر هشدار؛ وضعیت `A-57`…`A-68` نوشته شده.

---

## فاز ۳ — سخت‌سازی لایهٔ تشخیص در DOM و SSE

این فاز دلیل اصلی شکنندگی درازمدت را می‌بندد: رابط کاربری chatgpt.com مدام تغییر می‌کند و پل فعلی به نشانه‌های منسوخ تکیه دارد.

### A-27 — به‌روزرسانی `RITMO_SELECTORS`

جدول فعلی به نشانه‌های نسل قدیم متکی است — مهم‌ترینشان `data-testid="fruitjuice-send-button"` و `data-testid="fruitjuice-stop-button"` که نام‌گذاری دورهٔ ۲۰۲۳ است، و `.result-streaming` که دیگر روی پیام‌های در حال تولید گذاشته نمی‌شود.

هر کلید را به فهرستی از سلکتورهای جداشده با کاما تبدیل کن که **از خاص‌ترین به عمومی‌ترین** مرتب شده باشد، و نسخهٔ مبتنی بر نقش (`aria-label`) را هم اضافه کن چون پایدارتر از `data-testid` است:

```js
var RITMO_SELECTORS = {
  composer: [
    '#prompt-textarea',
    'div[contenteditable="true"][id="prompt-textarea"]',
    'form div[contenteditable="true"]',
    'textarea[data-id]',
    'textarea[placeholder]'
  ].join(', '),

  sendButton: [
    'button[data-testid="send-button"]',
    'button[data-testid="fruitjuice-send-button"]',
    'button[aria-label*="Send"]',
    'button[aria-label*="ارسال"]',
    'form button[type="submit"]'
  ].join(', '),

  stopButton: [
    'button[data-testid="stop-button"]',
    'button[data-testid="fruitjuice-stop-button"]',
    'button[aria-label*="Stop"]',
    'button[aria-label*="توقف"]'
  ].join(', '),

  streamingIndicator: [
    '.result-streaming',
    '[data-message-streaming="true"]',
    '[data-is-streaming="true"]',
    'button[data-testid="stop-button"]'
  ].join(', '),

  assistantMessage: [
    '[data-message-author-role="assistant"]',
    'article[data-testid*="conversation-turn"] [data-message-author-role="assistant"]',
    'div.agent-turn'
  ].join(', '),
  // ... بقیهٔ کلیدها به همین سبک
};
```

قواعد:

- سلکتورهای قدیمی را **حذف نکن** — فقط بعد از جدیدها بگذار. کاربرانی روی نسخه‌های قدیمی‌تر رابط هستند.
- `streamingIndicator` دیگر نباید تنها به `.result-streaming` وابسته باشد؛ وجود دکمهٔ توقف خودش قوی‌ترین نشانهٔ تولید است.
- هیچ سلکتوری خارج از این جدول در کد نوشته نمی‌شود.

### A-28 — خودآزمون سلکتور در زمان بوت

درست پیش از `notifyFlutter('ready', ...)`، یک خودآزمون اجرا کن:

```js
function runSelectorSelfTest() {
  var report = {};
  var keys = ['composer', 'sendButton', 'assistantMessage', 'conversationTurns',
              'markdownBodies', 'userMessage'];
  for (var i = 0; i < keys.length; i++) {
    report[keys[i]] = queryAllSafe(RITMO_SELECTORS[keys[i]]).length;
  }
  return report;
}

notifyFlutter('selector_health', {
  report: runSelectorSelfTest(),
  bridgeVersion: window.__RITMO_BRIDGE_V,
  source: 'lifecycle'
});
```

در سمت Dart، رویداد `selector_health` باید:

- در `BridgeTraceLog` ثبت شود.
- اگر `composer == 0` یا `assistantMessage == 0` باشد، وضعیت `error` با `WebBridgeException.composerNotFound()` یا یک خطای معادل بدهد — نه این‌که مثل امروز ساکت بماند و در مرحلهٔ ارسال شکست بخورد.
- در `WebBridgeDiagnosticsScreen` به‌صورت جدول نمایش داده شود.

این تنها راهی است که دفعهٔ بعد که chatgpt.com رابطش را عوض کرد، در عرض ده ثانیه متوجه شویم و نه پس از گزارش کاربر.

### A-29 — شکاف لنگراندازی `data-ritmo-seen`

کد فعلی پیش از ارسال پیام، عناصر موجود را علامت می‌زند:

```js
queryAllSafe('article, [data-message-author-role], [data-testid*="conversation-turn"], div.markdown, div.prose')
  .forEach(function (el) { el.setAttribute('data-ritmo-seen', 'true'); });
```

اما بعداً در `unseenAssistantMessage` و `unseenMarkdownBodies` و `unseenConversationTurns` سلکتورهایی مثل `[data-testid*="assistant"]`، `div.agent-turn`، `[class*="agent-turn"]`، `[class*="markdown"]` و `[class*="prose"]` پرس‌وجو می‌شوند که **در مرحلهٔ علامت‌گذاری پوشش داده نشده‌اند**.

نتیجه: یک پیام قدیمی که کلاسش فقط `[class*="markdown"]` مچ می‌شود، هرگز `data-ritmo-seen` نگرفته و به‌عنوان «پاسخ جدید» برداشت می‌شود. یعنی پل ممکن است پاسخ دیروز را به‌جای پاسخ امروز بردارد — یا برعکس، پاسخ جدید را نادیده بگیرد.

اصلاح: یک ثابت واحد بساز و در هر دو جا از همان استفاده کن:

```js
// تمام عناصری که ممکن است بعداً به‌عنوان «دیده‌نشده» پرس‌وجو شوند.
var RITMO_ANCHORABLE = [
  'article',
  '[data-message-author-role]',
  '[data-testid*="conversation-turn"]',
  '[data-testid*="assistant"]',
  'div.agent-turn',
  '[class*="agent-turn"]',
  'div.markdown',
  '[class*="markdown"]',
  'div.prose',
  '[class*="prose"]'
].join(', ');
```

تست `message_identity_anchor_test.dart` را طوری تقویت کن که این هم‌ترازی را تضمین کند: هر سلکتوری که در کلیدهای `unseen*` ظاهر می‌شود، باید در `RITMO_ANCHORABLE` هم باشد.

### A-30 — اولویت با آخرین نوبت گفتگو، نه «دیده‌نشده»

راهبرد `data-ritmo-seen` ذاتاً شکننده است چون به دستکاری DOM وابسته است و رندرر واکنشی chatgpt.com می‌تواند صفت را پاک کند.

`findLatestAssistantText` را بازنویسی کن تا به ترتیب این سه راهبرد را امتحان کند:

1. **لنگر شناسه‌محور (بهترین):** پیش از ارسال، تعداد نوبت‌های گفتگو را در `window.__ritmo_turn_count_at_send` ذخیره کن. پس از ارسال، پاسخ یعنی آخرین پیام با `data-message-author-role="assistant"` در حالی که شمارش نوبت‌ها بیشتر شده باشد.
2. **آخرین پیام دستیاری پس از آخرین پیام کاربر:** در فهرست نوبت‌ها، از انتها به عقب بگرد تا اولین نقش `user` را پیدا کنی؛ پاسخ دستیاری بلافاصله بعد از آن است.
3. **`data-ritmo-seen` (پشتیبان آخر):** رفتار فعلی.

نتیجهٔ هر سه راهبرد را در خروجی `notifyFlutter` با کلید `strategy` برچسب بزن تا در ردیاب مشخص باشد کدام مسیر جواب داده است.

### A-31 — پارسر SSE باید قالب پچ JSON فعلی را پوشش بدهد

`__ritmo_parseSSELine` فقط سه قالب ر�� می‌شناسد (`message.content.parts`، `delta.content`، `v` ساده). chatgpt.com امروز عمدتاً قالب عملیات پچ می‌فرستد:

```json
{"p": "/message/content/parts/0", "o": "append", "v": "متن جدید"}
{"o": "patch", "v": [{"p": "/message/content/parts/0", "o": "append", "v": "..."}]}
{"v": {"message": {"content": {"parts": ["..."]}}}}
```

پارسر را گسترش بده:

- اگر `o === 'append'` و `p` با `/message/content/parts/` شروع می‌شود → `v` را به‌عنوان delta برگردان.
- اگر `o === 'patch'` و `v` آرایه است → روی عناصر حلقه بزن و تمام append‌های مربوط به `parts` را به هم بچسبان.
- اگر `o === 'replace'` و `p` مربوط به `parts` است → به‌عنوان `fullText` برگردان (نه delta).
- عملیات مربوط به `/message/metadata`، `/message/status`، و مسیرهای استدلال (`/message/content/thoughts`) را **نادیده بگیر** — این‌ها پاسخ نیستند.
- هر قالب ناشناخته را یک بار در هر جریان با `notifyFlutter('selector_health', { issue: 'unknown_sse_shape', ... })` گزارش کن (نه بیشتر، وگرنه کانال اشباع می‌شود).

تست `sse_parser_test.dart` را با نمونه‌های واقعی هر چهار قالب گسترش بده.

### A-32 — `[DONE]` نباید پایان قطعی باشد اگر DOM متن بیشتری دارد

در A-14 پنجرهٔ تثبیت ۵۰۰ میلی‌ثانیه‌ای اضافه شد. اینجا قاعدهٔ مکمل را بگذار: در سمت Dart، `_finishGeneration(fullText)` پیش از بستن جریان باید متن ورودی را با محتوای انباشتگر مقایسه کند و **بلندتر را بردارد**:

```dart
void _finishGeneration(String? fullText) {
  if (fullText != null && fullText.isNotEmpty) {
    _emitChunk(fullText, null, source: _lockedSource?.name ?? 'dom');
  }
  final finalText = _accumulator.text;
  _trace('finish', _lockedSource ?? BridgeSource.lifecycle, textLength: finalText.length);
  // ... بستن کنترلر، لغو تایمرها، بازنشانی قفل منبع
}
```

هرگز `fullText` ورودی را مستقیماً جایگزین انباشتگر نکن.

### A-33 — `extractCleanText` باید بلوک‌های استدلال و زبالهٔ رابط را حذف کند

امروز متن DOM خام شامل موارد زیر هم می‌شود که همه به صفحهٔ چت ریتمو نشت می‌کنند:

- بلوک تفکر/استدلال («Thought for N seconds» و محتوای تاشوی زیرش)
- دکمهٔ «Copy code» / «Copy» / «کپی» در سربرگ بلوک‌های کد
- نوار اقدام زیر پیام (پسندیدم/نپسندیدم، خواندن بلند، ویرایش، دوباره‌سازی)
- برچسب مدل و شمارندهٔ نسخه («2/2»)

`extractCleanText` را طوری بازنویسی کن که پیش از خواندن `innerText`، روی یک کپی `cloneNode(true)` عمل کند و این عناصر را حذف کند:

```js
var RITMO_STRIP = [
  'button',
  '[role="button"]',
  '[data-testid*="thinking"]',
  '[data-testid*="reasoning"]',
  'details[data-testid*="thought"]',
  '[class*="sr-only"]',
  '[aria-hidden="true"]'
].join(', ');
```

مهم: بلوک‌های کد واقعی (`pre > code`) باید **حفظ** شوند و با حصار سه‌بک‌تیک خروجی بگیرند، وگرنه مارک‌داون در صفحهٔ ریتمو خراب می‌شود. حذف `button` نباید باعث حذف خود کد شود.

### A-34 — محافظ در دسترس بودن `response.body.tee()`

قلاب fetch مستقیماً `response.body.tee()` صدا می‌زند. در برخی موتورهای وب‌ویو (به‌ویژه WebView قدیمی‌تر اندروید) `body` ممکن است `null` یا `tee` تعریف‌نشده باشد. در آن صورت قلاب خطا می‌دهد و **پاسخ اصلی را هم خراب می‌کند** — یعنی خود چت‌جی‌پی‌تی هم در مرورگر می‌شکند.

```js
if (!response.body || typeof response.body.tee !== 'function') {
  console.warn('[Ritmo] response.body.tee unavailable, falling back to DOM watcher only');
  notifyFlutter('selector_health', { issue: 'tee_unavailable', source: 'fetch' });
  return response;   // پاسخ دست‌نخورده برگردد
}
```

قاعدهٔ طلایی: **قلاب fetch هرگز نباید باعث شکست درخواست اصلی شود.** کل بدنهٔ قلاب باید در `try/catch` باشد که در صورت خطا، `originalFetch` را بدون دستکاری برمی‌گرداند. تست `response_tee_test.dart` را با این حالت گسترش بده.

### A-35 — قلاب کردن `XMLHttpRequest` و `EventSource`

قلاب فعلی فقط `window.fetch` را پوشش می‌دهد. اگر chatgpt.com برای بخشی از ترافیک به `EventSource` یا `XMLHttpRequest` سوئیچ کند، مسیر SSE کاملاً نابینا می‌شود و فقط مسیر DOM می‌ماند.

دو قلاب اضافه کن، هر دو با همان محافظ یک‌باره (`window.__ritmo_xhr_hooked`، `window.__ritmo_es_hooked`):

- `XMLHttpRequest.prototype.open` را پوشش بده تا URL را ثبت کند؛ در `addEventListener('progress')` متن تجمیعی `responseText` را بخوان و از همان `__ritmo_parseSSELine` رد کن.
- `window.EventSource` را با یک پراکسی جایگزین کن که `onmessage` را تکثیر می‌کند.
- هر دو باید همان فیلتر مسیر را بزنند (`/backend-api/conversation` یا `/backend-anon/conversation`، با استثنای `/lat/r`).
- هر دو باید `source: 'sse'` بفرستند تا داوری منبع (A-04) کار کند.

### A-36 — تزریق در زمان شروع سند

اسکریپت امروز در `handlePageFinished` تزریق می‌شود، یعنی **پس از** این‌که اسکریپت‌های chatgpt.com اجرا شدند. اگر اپلیکیشن مرجع `fetch` را در یک متغیر محلی گرفته باشد (الگوی رایج در باندلرها)، قلاب ما هرگز دیده نمی‌شود.

راه‌حل در چارچوب `webview_flutter` v4:

- بخش قلاب fetch/XHR/EventSource را از بدنهٔ اصلی جدا کن و به‌عنوان `ChatGptJsInjector.earlyHookScript` منتشر کن.
- در `NavigationDelegate.onPageStarted` آن را با `runJavaScript` تزریق کن (نه بعد از `onPageFinished`).
- این اسکریپت باید کاملاً خودکفا و بی‌اثر در صورت تکرار باشد؛ محافظ `window.__ritmo_fetch_hooked` همین کار را می‌کند.
- بدنهٔ اصلی (واچر DOM، ارسال پرامپت، مودال‌ها) همچنان در `onPageFinished` تزریق می‌شود چون به DOM نیاز دارد.

تست `bridge_script_idempotent_test.dart` را طوری گسترش بده که تزریق دومرحله‌ای را پوشش دهد.

### A-37 — اندازهٔ پیام کانال JS: ارسال delta به‌جای متن کامل در هر تیک

واچر DOM هر ۳۵۰ میلی‌ثانیه **متن کامل** را در `fullText` می‌فرستد. برای یک پاسخ ۸۰۰۰ کاراکتری که در ۴۰ ثانیه تولید می‌شود، این یعنی حدود ۱۱۵ پیام که مجموعاً صدها کیلوبایت JSON از کانال رد می‌شود — رفتار درجه دو. برای متن فارسی که در JSON به دنباله‌های `\uXXXX` تبدیل می‌شود، حجم تا شش برابر باد می‌کند. برخی پلتفرم‌ها پیام‌های بزرگ کانال را بی‌صدا حذف می‌کنند.

اصلاح:

- در واچر DOM، وقتی متن جدید پیشوندش را حفظ کرده، فقط `delta` بفرست.
- هر `n` تیک (مثلاً هر ۱۰ تیک ≈ ۳.۵ ثانیه) یک بار `fullText` بفرست به‌عنوان همگام‌سازی دوره‌ای.
- همیشه در `done` یک `fullText` کامل بفرست.
- اگر متن جدید پیشوند قبلی نیست (بازنویسی)، حتماً `fullText` بفرست و نه delta.

انباشتگر (A-03) هر دو حالت را درست ترکیب می‌کند، پس این تغییر ایمن است.

### A-38 — `autoDismissCookiesAndModals` نباید دکمه‌های رابط چت‌جی‌پی‌تی را بزند

این تابع روی همهٔ `button, div[role="button"], a[role="button"], a` حلقه می‌زند و هر چیزی که متنش شبیه «close»، «dismiss»، «بستن» یا «باشه» باشد را کلیک می‌کند. در رابط چت‌جی‌پی‌تی دکمه‌های زیادی با `aria-label` حاوی این کلمات وجود دارند (بستن نوار کناری، بستن پنل کد، بستن پنجرهٔ اشتراک). کلیک تصادفی وسط استریم می‌تواند پاسخ را قطع یا ناوبری را تغییر دهد.

اصلاحات اجباری:

1. **فقط در حالت غیرتولید اجرا شود.** اگر `window.__ritmo_active_req_id` مقدار دارد، بلافاصله برگرد.
2. **دامنه را محدود کن.** فقط داخل عناصری بگرد که واقعاً مودال‌اند: `[role="dialog"]`، `[aria-modal="true"]`، `[data-testid*="modal"]`، `[id*="cookie"]`، `[class*="cookie"]`.
3. **دکمه‌های رابط اصلی را مستثنا کن.** هر دکمه‌ای که داخل `form`، داخل `main`، یا داخل یک نوبت گفتگو باشد، هرگز کلیک نشود.
4. هر کلیک خودکار باید با `notifyFlutter('auto_dismiss', { label, source: 'lifecycle' })` ثبت شود تا در ردیاب دیده شود.

همین محدودیت برای منطق بستن نوار کناری (`sidebarClose` و `isSidebarOpen`) هم اعمال می‌شود.

### 🚦 دروازهٔ پذیرش فاز ۳

- [ ] هر کلید `RITMO_SELECTORS` دست‌کم یک سلکتور غیروابسته به `fruitjuice-*` دارد.
- [ ] رویداد `selector_health` در بوت منتشر می‌شود و در ردیاب دیده می‌شود.
- [ ] تستی وجود دارد که هر سلکتور در کلیدهای `unseen*` در `RITMO_ANCHORABLE` هم هست.
- [ ] `sse_parser_test.dart` هر چهار قالب را پوشش می‌دهد، از جمله `o: "patch"`.
- [ ] قلاب fetch در صورت نبود `tee` پاسخ را دست‌نخورده برمی‌گرداند.
- [ ] قلاب‌های XHR و EventSource پیاده و بی‌اثر‌در‌تکرارند.
- [ ] اسکریپت قلاب در `onPageStarted` تزریق می‌شود.
- [ ] واچر DOM در حالت عادی delta می‌فرستد، نه متن کامل.
- [ ] `autoDismissCookiesAndModals` در حین تولید اجرا نمی‌شود.
- [ ] `bridgeVersion` همچنان با بدنهٔ اسکریپت همگام است (تست A-05 سبز).
- [ ] `flutter analyze` صفر خطا و صفر هشدار؛ وضعیت `A-27`…`A-38` نوشته شده.

---

## فاز ۴ — تشخیص‌پذیری و تجربهٔ کاربری صادقانه

هدف: کاربر هرگز نباید در موقعیتی باشد که می‌بیند چت‌جی‌پی‌تی در مرورگر جواب داده ولی برنامه ساکت است و هیچ کاری از دستش برنمی‌آید.

### A-39 — صفحهٔ تشخیص پل وب

فایل جدید `lib/features/profile/presentation/web_bridge_diagnostics_screen.dart`، قابل دسترسی از `ai_connection_screen.dart` و از دکمهٔ «چرا؟» در A-22.

بخش‌های اجباری:

1. **وضعیت لحظه‌ای:** وضعیت پل، شناسهٔ درخواست جاری، منبع قفل‌شده، طول انباشتگر، وضعیت احراز هویت، نسخهٔ پل.
2. **سلامت سلکتورها:** جدول خروجی `selector_health` (A-28) — هر کلید با تعداد عناصر مچ‌شده؛ صفرها قرمز.
3. **ردیاب رویدادها:** فهرست معکوس `BridgeTraceLog` با زمان، نوع، منبع، طول و یادداشت.
4. **دکمهٔ «کپی گزارش تشخیص»:** خروجی `exportAsText()` را در کلیپ‌بورد می‌گذارد.

قواعد:

- این صفحه فقط خواندنی است به جز دو اقدام بازیابی (A-40 و دکمهٔ موجود `forceReboot`).
- متن پاسخ‌ها نمایش داده نمی‌شود — فقط طول. محرمانگی را رعایت کن (همان اصل `test/logger_redaction_test.dart`).
- تمام رشته‌ها از `app_fa.arb`.

### A-40 — دکمهٔ بازیابی: «پاسخ در مرورگر هست ولی در برنامه نیامد»

این دقیقاً راه‌حل دستی مشکل گزارش‌شده است و باید حتی اگر همهٔ لایه‌های خودکار شکست خوردند کار کند.

در جاوااسکریپت:

```js
window.__ritmo_forceHarvest = function (reqId) {
  try {
    var text = findLatestAssistantText();
    notifyFlutter('harvest_result', {
      fullText: text || '',
      requestId: reqId || window.__ritmo_active_req_id || '',
      source: 'dom',
      strategy: 'manual'
    });
  } catch (e) {
    console.error('[Ritmo] forceHarvest failed: ' + e);
    notifyFlutter('harvest_result', { fullText: '', error: e.toString(), source: 'dom' });
  }
};
```

در سمت Dart، متد عمومی `Future<String?> harvestVisibleAnswer()` در منیجر:

- `runJavaScript('window.__ritmo_forceHarvest(...)')` را صدا می‌زند.
- روی `harvest_result` منتظر می‌ماند (با مهلت `ChatGptBridgeTimeouts.composerReadyTimeout`).
- متن را برمی‌گرداند. اگر جریانی فعال است، متن را از طریق انباشتگر هم منتشر می‌کند.

در UI دو نقطهٔ ورود:

1. در کارت خطای پاسخ خالی (A-22): دکمهٔ «بازیابی پاسخ از مرورگر».
2. در `WebBridgeDiagnosticsScreen`: همان دکمه.

اگر متن بازیابی شد، باید به‌عنوان پیام دستیار در همان جلسه ذخیره شود (از `ChatRepository` موجود استفاده کن)، نه این‌که فقط در حافظه نشان داده شود.

### A-41 — جدول قطعی حالات خالی و خطا

هیچ حالتی نباید با اسپینر بی‌پایان یا صفحهٔ سفید تمام شود. جدول زیر را در هر دو صفحه پیاده کن:

| وضعیت | عنوان | متن کمکی | اقدام اول | اقدام دوم |
|---|---|---|---|---|
| اتصال تنظیم نشده | «هوش مصنوعی متصل نیست» | «برای گفتگو با دستیار، ابتدا یک اتصال تنظیم کنید.» | تنظیم اتصال | �� |
| نیاز به ورود | «ورود به چت‌جی‌پی‌تی لازم است» | پیام `WebBridgeException.authRequired()` | ورود | — |
| چالش کلادفلر | «تأیید امنیتی لازم است» | پیام موجود | باز کردن مرورگر | — |
| پاسخ خالی — متن در مرورگر هست | «پاسخ دریافت نشد» | علت دقیق از A-22 | بازیابی از مرورگر | چرا؟ |
| پاسخ خالی — مرورگر هم خالی | «چت‌جی‌پی‌تی پاسخ نداد» | «دوباره تلاش کنید.» | ارسال مجدد | چرا؟ |
| مهلت تمام شده — متن ناقص داریم | «پاسخ ناقص ماند» | «بخشی از پاسخ دریافت شد.» | بازیابی ادامه | چرا؟ |
| خطای شبکه | «اتصال اینترنت قطع شد» | پیام موجود | تلاش مجدد | — |
| محدودیت نرخ | «محدودیت درخواست» | پیام موجود | — | — |

هیچ‌کدام از این رشته‌ها نباید در کد سخت‌کد شود.

### A-42 — محلی‌سازی رشته‌های فارسی دامنهٔ پل

امروز ده‌ها رشتهٔ فارسی در `web_bridge_exception.dart`، `chatgpt_auth_modal.dart`، `cloudflare_challenge_modal.dart`، `agent_loop_runner.dart` و `streaming_chat_service.dart` سخت‌کد شده‌اند.

قواعد:

- هر رشته‌ای که به کاربر نشان داده می‌شود باید به `lib/l10n/app_fa.arb` و `lib/l10n/app_en.arb` منتقل شود. پیشوند کلید: `bridge`.
- `WebBridgeException.messageFa` و `actionTextFa` نباید در لایهٔ دامنه ترجمه شوند (این کلاس به `BuildContext` دسترسی ندارد). به جای آن، یک فیلد `messageKey` اضافه کن و لایهٔ UI کلید را به رشته تبدیل کند. `messageFa` فعلی به‌عنوان پشتیبان حفظ می‌شود تا تست `web_bridge_exception_test.dart` نشکند.
- پیام‌های دیباگ و لاگ محلی‌سازی نمی‌شوند.
- پس از هر تغییر، `flutter gen-l10n` اجرا و خروجی کامیت می‌شود.
- `docs/l10n_audit.md` را با ردیف‌های جدید به‌روز کن.

### A-43 — حذف اندازهٔ قلم و رنگ سخت‌کدشده

ویجت‌های جدید (تراشهٔ وضعیت، کارت خطا، صفحهٔ تشخیص) نباید هیچ `fontSize:` عددی یا `Color(0x...)` داشته باشند. همه از `Theme.of(context).textTheme` و `colorScheme` بخوانند، مطابق `docs/theme_migration.md`.

علاوه بر آن، در همین فاز موارد موجود در `chatgpt_auth_modal.dart`، `cloudflare_challenge_modal.dart` و `chatgpt_mini_preview.dart` را هم مهاجرت بده — این سه فایل در دامنهٔ همین پرامپت‌اند.

تضمین دسترسی‌پذیری: نسبت کنتراست متن روی پس‌زمینه در هر دو تم روشن و تیره حداقل **۴.۵:۱** باشد. حالت `error` نباید فقط با رنگ قرمز متمایز شود؛ آیکون و متن هم لازم است.

### A-44 — پیام‌رسانی مهلت‌ها در حین انتظار

مهلت‌های فعلی: اولین توکن ۳۵ ثانیه، تولید ۹۰ ثانیه، بوت ۴۰ ثانیه. کاربر هیچ تصوری از این اعداد ندارد و فقط یک اسپینر می‌بیند.

متن وضعیت باید پلکانی باشد (از `PendingRequestStage` موجود استفاده کن):

| مرحله / زمان سپری‌شده | متن |
|---|---|
| `sending` | «در حال ارسال پیام…» |
| `awaitingFirstToken` تا ۸ ثانیه | «در حال فکر کردن…» |
| `awaitingFirstToken` پس از ۸ ثانیه | «پاسخ کمی طول کشیده…» |
| `awaitingFirstToken` پس از ۲۰ ثانیه | «هنوز منتظریم. می‌توانید مرورگر را ببینید.» + دکمهٔ پیش‌نما |
| `streaming` | «در حال نوشتن…» |

هیچ تایمر جدیدی نساز. از همان تایمر واحد موجود استفاده کن (تست `single_master_timer_test.dart` باید سبز بماند).

### A-45 — سطح‌آوردن وضعیت احراز هویت و کلادفلر پیش از ارسال

امروز کاربر پیام می‌فرستد، منتظر می‌ماند، و فقط پس از شکست متوجه می‌شود که از چت‌جی‌پی‌تی خارج شده است.

- در `waitForComposerReady`، پیش از ارسال پرامپت، `__ritmo_checkAuthState` را صدا بزن و اگر احراز هویت نشده، پیش از مصرف نوبت کاربر خطا بده.
- پیام کاربر در این حالت **نباید حذف شود**؛ باید در کادر ورودی باقی بماند تا پس از ورود دوباره قابل ارسال باشد.
- تست `auth_state_detection_test.dart` و `composer_ready_gate_test.dart` باید سبز بمانند.

### A-46 — پیوند تراشهٔ وضعیت به صفحهٔ تشخیص

تراشهٔ A-23 در حالت `error` باید با یک لمس، `WebBridgeDiagnosticsScreen` را باز کند. در حالت `generating` پیش‌نمای مرورگر. در حالت `cloudflareChallenge` مودال موجود. هیچ مسیر بن‌بستی باقی نماند.

### A-47 — پیش‌نمای مرورگر باید همیشه قابل باز شدن باشد

در منوی سربرگ دستیار، گزینهٔ دائمی «مشاهدهٔ پنجرهٔ چت‌جی‌پی‌تی» بگذار که در هر وضعیتی کار کند — حتی `idle`. اگر وب‌ویو آزاد شده باشد، اول `ensureBooted()` را صدا بزن و در حین بوت پیام «در حال اتصال…» نشان بده.

این گزینه به کاربر امکان می‌دهد خودش راستی‌آزمایی کند که آیا چت‌جی‌پی‌تی پاسخ داده یا نه — دقیقاً همان کاری که امروز مجبور شده از طریق پنجرهٔ کرومیوم دستی انجام دهد.

### 🚦 دروازهٔ پذیرش فاز ۴

- [ ] `WebBridgeDiagnosticsScreen` ساخته شده و هر چهار بخش را دارد.
- [ ] `harvestVisibleAnswer()` کار می‌کند و متن بازیابی‌شده در دیتابیس ذخیره می‌شود.
- [ ] هر هشت ردیف جدول حالات A-41 پیاده شده است.
- [ ] `rg -n "fontSize:" lib/core/ai lib/features/assistant` خروجی خالی.
- [ ] `rg -n "Color\(0x" lib/core/ai lib/features/assistant` خروجی خالی.
- [ ] `flutter gen-l10n` اجرا شده و کلیدهای `bridge*` در هر دو `app_fa.arb` و `app_en.arb` وجود دارند.
- [ ] گزینهٔ دائمی «مشاهدهٔ پنجرهٔ چت‌جی‌پی‌تی» در دسترس است.
- [ ] `flutter analyze` صفر خطا و صفر هشدار؛ وضعیت `A-39`…`A-47` نوشته شده.

---

## فاز ۵ — تست‌های نگهبان

هدف این فاز: هیچ‌کدام از باگ‌های این سند دوباره برنگردد. هر تست باید **پیش از اصلاح قرمز و پس از آن سبز** باشد. اگر تستی از همان اول سبز است، یعنی تست اشتباه نوشته شده — دوباره بنویس.

### A-48 — `test/core/ai/agent/display_suppression_cap_test.dart`

نگهبان ریشهٔ اول (A-09 تا A-11).

1. متن فارسی حاوی `<` تنها (مثلاً «دما < ۳۷ درجه») — باید کامل به `AgentTokenStreamEvent` برسد.
2. متن حاوی یک بک‌تیک بازنشده در پایان — پس از عبور از `_maxSuppressedChars` یا `_maxSuppressionWindow`، متن آزاد می‌شود.
3. متن حاوی یک فراخوانی ابزار واقعی — بخش ابزار سرکوب می‌ماند و بقیه منتشر می‌شود.
4. متن ۲۰۰۰ کاراکتری عادی بدون `<`، `[` یا بک‌تیک — هیچ سرکوبی رخ نمی‌دهد و `_shouldScan` فالس برمی‌گرداند.
5. در پایان نوبت، مجموع تمام `delta`‌های منتشرشده دقیقاً برابر `accumulated` آخرین رویداد است — بدون تکرار و بدون افت.

### A-49 — `test/core/ai/web_bridge/accumulator_shrink_test.dart`

نگهبان ریشهٔ دوم (A-03 و A-12).

1. دنبالهٔ `applyFull` صعودی — هر بار فقط دلتای جدید.
2. `applyFull` با متن کوتاه‌تر که پیشوند متن قبلی است — نادیده گرفته می‌شود، `delta` خالی.
3. `applyFull` با متن کوتاه‌تری که **پیشوند نیست** (بازنویسی) — `isRewrite == true` و `fullText` متن جدید است.
4. متن فارسی با جفت‌های جانشین یونیکد (ایموجی) در مرز برش — هیچ کاراکتر معیوبی تولید نمی‌شود.
5. دنبالهٔ ترکیبی `applyDelta` و `applyFull` — نتیجه همان متن کامل است.
6. متنی بلندتر از `maxAssistantResponseChars` — برش می‌خورد و پرچم برش ثبت می‌شود.

### A-50 — `test/core/ai/web_bridge/source_arbitration_test.dart`

نگهبان مسابقهٔ SSE و DOM (A-04 و A-13).

1. اولین تکه از `sse` می‌رسد — منبع قفل می‌شود؛ تکه‌های بعدی `dom` نادیده گرفته می‌شوند مگر بلندتر باشند.
2. `done` از `sse` و سپس `done` از `dom` — فقط یک بار جریان بسته می‌شود و هیچ خطایی پرتاب نمی‌شود.
3. `done` از `sse` می‌رسد ولی DOM متن بلندتری دارد — متن نهایی باید نسخهٔ بلندتر باشد (A-32).
4. دو `done` همزمان در یک تیک — هیچ `Bad state: Cannot add event after closing` رخ نمی‌دهد.

### A-51 — `test/core/ai/web_bridge/concurrent_send_test.dart`

نگهبان باگ `Stream has already been listened to` (A-15).

1. دو بار فراخوانی `sendPrompt` در حالی که جریان اول فعال است — دومی باید خطای قابل فهم بدهد، نه پرتاب `Bad state`.
2. دو مصرف‌کنندهٔ همزمان روی یک جریان (صفحهٔ چت + شیت دستیار) — هر دو تمام تکه‌ها را می‌گیرند (`broadcast`).
3. لغو در وسط جریان — `cancelCurrentStream()` هم در Dart و هم در JS اثر می‌گذارد (`two_way_cancellation_test.dart` موجود باید سبز بماند).

### A-52 — `test/core/ai/chat/agent_event_forwarding_test.dart`

نگهبان ریشهٔ سوم (A-19 تا A-21).

1. **تست جامعیت:** فهرستی از هر ۱۳ زیرنوع `AgentEvent` بساز و از `StreamingChatService` رد کن؛ هیچ‌کدام نباید بی‌صدا افتاده شود. این تست باید با افزودن هر زیرنوع جدید در آینده قرمز شود.
2. `AgentDisplayResetEvent` تا UI می‌رسد.
3. `AgentAwaitingQuestionEvent` تا UI می‌رسد و پاسخ کاربر به `AgentQuestionBroker` می‌رسد.
4. `AgentTokenStreamEvent` با `delta` خالی و `accumulated` غیرخالی — UI همچنان متن را نشان می‌دهد.
5. پایان نوبت با `accumulated` خالی ولی `rawAnswer` غیرخالی — باید `rawAnswer` ذخیره شود، نه `ChatErrorEvent`.

### A-53 — `test/core/ai/web_bridge/bridge_version_guard_test.dart`

نگهبان نسخهٔ پل (A-05).

تست باید یک هش پایدار از متن اسکریپت تزریقی بگیرد و با مقدار ثبت‌شده مقایسه کند. پیام شکست باید صریح باشد:

> متن اسکریپت پل تغییر کرده ولی `bridgeVersion` به‌روز نشده است. مقدار را به N+1 برسان و هش مرجع را در همین تست به‌روز کن.

این تنها نگهبان در قبال باگ «سند گرم، اسکریپت کهنه» است که می‌تواند تمام کار این سند را بی‌اثر کند.

### A-54 — `test/core/ai/web_bridge/selector_contract_test.dart`

نگهبان فاز ۳ (A-27 تا A-30).

1. هر کلید `RITMO_SELECTORS` مقدار غیرخالی دارد.
2. هر سلکتوری که در `unseenAssistantMessage`، `unseenMarkdownBodies` و `unseenConversationTurns` ظاهر می‌شود، در `RITMO_ANCHORABLE` هم هست.
3. هیچ `document.querySelector` یا `document.querySelectorAll` خامی در متن اسکریپت نیست (فقط `querySafe`/`queryAllSafe`).
4. هیچ سلکتوری خارج از جدول `RITMO_SELECTORS` در کد تعریف نشده است (به جز `RITMO_ANCHORABLE` و `RITMO_STRIP`).

### A-55 — `test/core/ai/web_bridge/end_to_end_happy_path_test.dart`

تست پوششی که هر سه لایه را با هم می‌بندد — این بازتولید دقیق مشکل گزارش‌شده است.

سناریو:

1. یک دنبالهٔ واقعی از پیام‌های کانال JS را به `handleJsMessageForTest` بده: `ready` ← `first_token` ← چند `chunk` فارسی حاوی یک بلوک کد و یک `<` تنها ← `done`.
2. خروجی را از مسیر `AgentLoopRunner` ← `StreamingChatService` رد کن.
3. ادعا: متن نهایی ذخیره‌شده دقیقاً برابر متن `done` است، دست‌کم یک `ChatChunk` منتشر شده، و هیچ `ChatErrorEvent` وجود ندارد.
4. همین سناریو را یک بار با حذف کامل رویدادهای SSE (فقط DOM) و یک بار فقط با SSE تکرار کن — هر دو باید همان متن را بدهند.

اگر این تست و بقیه سبز باشند، مشکل کاربر قطعاً حل شده است.

### A-56 — `test/core/ai/web_bridge/no_silent_catch_test.dart`

نگهبان قاعدهٔ ۰-۸ و A-06.

تست متن تمام فایل‌های `lib/core/ai/**` را می‌خواند و می‌سنجد:

- هیچ `catch (_) {}` یا `catch (e) {}` خالی وجود ندارد.
- هیچ `debugPrint(` وجود ندارد.
- هیچ `print(` وجود ندارد.
- هیچ `_emittedText` باقی نمانده — جایش را `BridgeResponseAccumulator` گرفته است.

این الگو را از `test/prompt_036_source_guards_test.dart` موجود تقلید کن — همان ساختار، همان سبک پیام خطا.

### 🚦 دروازهٔ پذیرش فاز ۵

- [ ] هر نه فایل تست `A-48`…`A-56` ساخته شده‌اند و سبزند.
- [ ] برای هر تست، در پیام کامیت ذکر کن که پیش از اصلاح قرمز بوده است.
- [ ] `flutter test` کاملاً سبز؛ هیچ تست موجودی حذف یا `skip` نشده است.
- [ ] `rg -n "skip:" test/core/ai` خروجی خالی.
- [ ] `flutter analyze` صفر خطا و صفر هشدار.
- [ ] `dart format --set-exit-if-changed lib test` موفق.
- [ ] وضعیت `A-48`…`A-56` نوشته شده است.

---

## ۶. قواعد کامیت

۶-۱. هر فاز دقیقاً یک کامیت دارد. فازها را در یک کامیت ادغام نکن.

۶-۲. قالب پیام کامیت:

```
fix(bridge): phase N — <خلاصه> [A-xx, A-yy, A-zz]
```

مثال:

```
fix(bridge): phase 1 — پاسخ به صفحهٔ چت می‌رسد [A-09, A-10, A-11, A-12, A-13, A-14, A-15, A-16, A-17, A-18]
```

۶-۳. بدنهٔ کامیت باید سه خط داشته باشد:

```
- analyze: 0 errors, 0 warnings
- tests: <تعداد> passed, 0 failed
- دروازهٔ پذیرش فاز N: عبور کرد
```

۶-۴. هیچ کامیتی نباید زده شود تا دروازهٔ پذیرش همان فاز کاملاً عبور کرده باشد. کامیت با تست قرمز یا هشدار باقی‌مانده ممنوع است.

۶-۵. فایل `docs/ai/WEB_BRIDGE_FIX_PROGRESS.md` را در همان کامیت فاز به‌روز کن: برای هر `A-xx` یک ردیف با وضعیت `انجام شد` / `منتفی شد` / `مسدود شد` و یک جمله دلیل.

۶-۶. اگر یک `A-xx` منتفی می‌شود، دلیل فنی بنویس و ادامه بده. حذف بی‌سروصدا ممنوع است.

۶-۷. هیچ کدی خارج از دامنهٔ این سند تغییر نکند. دامنه دقیقاً:

- `lib/core/ai/web_bridge/**`
- `lib/core/ai/chat/**`
- `lib/core/ai/agent/**`
- `lib/features/assistant/presentation/**`
- `lib/features/chat/presentation/ai_chat_screen.dart`
- `lib/features/profile/presentation/web_bridge_diagnostics_screen.dart` (جدید) و لینک ورود آن در `ai_connection_screen.dart`
- `lib/l10n/app_fa.arb`، `lib/l10n/app_en.arb`
- `test/core/ai/**`
- `docs/ai/WEB_BRIDGE_FIX_PROGRESS.md`، `docs/l10n_audit.md`

۶-۸. منطق چرخهٔ بدن، دوره‌های آموزشی، حرکت مرکزی و ورزش تکمیلی در این کار دست نمی‌خورد. اگر لازم شد به آن‌ها دست بزنی، متوقف شو و در گزارش مسدود بنویس.

۶-۹. هیچ پکیج جدیدی به `pubspec.yaml` اضافه نکن و نسخهٔ `webview_flutter` را تغییر نده.

---

## ۷. خلاصهٔ قطعی

مشکل گزارش‌شده، به زبان کاربر:

> در دستیار هوشمند پیام می‌دهم، چت‌جی‌پی‌تی در پنجرهٔ کرومیوم جواب می‌دهد، ولی جواب در صفحهٔ چت برنامه نمی‌آید.

این یک باگ نیست — **سه باگ مستقل است که روی هم افتاده‌اند** و هر سه باید حل شوند. حل یکی یا دوتا مشکل را فقط کمتر تکرارشونده می‌کند، نه حل.

**لایهٔ یک — سرکوب رندر در `AgentLoopRunner`.**
تا زمانی که `hasOpenTag` درست است، هیچ توکنی منتشر نمی‌شود. ماشهٔ این حالت `soFar.contains('<') || soFar.contains('[') || soFar.contains('\`')` است که عملاً با هر پاسخ فارسی مارک‌داونی مطابقت دارد. یک بک‌تیک یا یک `<` بازنشده کافی است تا تمام پاسخ تا ابد حبس شود، در حالی که کرومیوم همان متن را کامل نشان می‌دهد. هیچ سقف زمانی یا طولی برای این سرکوب وجود ندارد. → فاز ۱.

**لایهٔ دو — انباشتگر و جریان در `ChatGptWebBridgeManager`.**
سه نقص مستقل:

1. `_emitChunk` هر `fullText` که اکیداً بلندتر از `_emittedText` نباشد را در سکوت دور می‌ریزد. یک بار کوچک‌شدن DOM در بازرندر — که در ChatGPT عادی است — خروجی را برای همیشه قفل می‌کند.
2. SSE و DOM دو منبع رقیب‌اند با دو `done` مستقل و هیچ داوری؛ `_lastChunkSource` ذخیره می‌شود ولی هرگز خوانده نمی‌شود.
3. گارد درخواست درجریان در `sendPrompt` یک `StreamController` تک‌مشترکی را دوباره `yield*` می‌کند و `Bad state: Stream has already been listened to` می‌دهد که بالادست به یک خطای بی‌معنا تبدیل می‌شود.

به این‌ها اضافه کن: `__ritmo_resume` که `done` زودرس می‌فرستد و `window.__ritmo_active_req_id` را هرگز مقداردهی نمی‌کند (پس تمام SSE بعدی به‌عنوان کهنه دور ریخته می‌شود)؛ `evaluateStreamCompletion` که با `hasSendButton && idleMs > 400` تمام می‌کند در حالی که `form button[type="submit"]` همیشه مچ می‌شود؛ سقف `_navigationReloadCount > 3` که روی گذار طبیعی `/` ← `/c/<id>` می‌شکند؛ و سلکتورهای دوران `fruitjuice-*` که مربوط به ۲۰۲۳ است. → فازهای ۱ و ۳.

**لایهٔ سه — شکاف ارسال رویداد در `StreamingChatService`.**
فقط چهار خانواده رویداد مدیریت می‌شوند. `AgentDisplayResetEvent`، `AgentAwaitingQuestionEvent` و `AgentQuestionResolvedEvent` بی‌صدا می‌افتند — یعنی اگر ایجنت `ask_user` بزند، برنامه تا ابد منتظر پاسخی می‌ماند که هرگز پرسیده نشده. علامت نهایی دقیقاً همان `ChatErrorEvent('هیچ پاسخی از هوش مصنوعی دریافت نشد.', '')` است که کاربر می‌بیند. → فاز ۲.

**ترتیب اجرا ثابت است:**

| فاز | موضوع | شناسه‌ها |
|---|---|---|
| ۰ | قرارداد داده و ابزار تشخیص | A-01 … A-08 |
| ۱ | رفع علت اصلی: پاسخ باید به صفحهٔ چت برسد | A-09 … A-18 |
| ۲ | یکپارچه‌سازی دو مسیر مصرف‌کنندهٔ UI | A-19 … A-26 |
| ۲.۵ | پروتکل کانال صریح | A-57 … A-68 |
| ۳ | سخت‌سازی تشخیص DOM و SSE | A-27 … A-38 |
| ۴ | تشخیص‌پذیری و تجربهٔ کاربری صادقانه | A-39 … A-47 |
| ۵ | تست‌های نگهبان | A-48 … A-56 |

فاز را جابه‌جا نکن، دروازه را رد نکن، و فاز بعدی را پیش از عبور فاز قبلی شروع نکن.

**تعریف قطعی موفقیت:** کاربر در دستیار هوشمند پیام می‌دهد، متن پاسخ در همان لحظه در صفحهٔ چت برنامه جریان پیدا می‌کند، در دیتابیس ذخیره می‌شود، و در هر حالت شکست یک دلیل مشخص به‌علاوهٔ دکمهٔ «بازیابی پاسخ از مرورگر» می‌بیند. هیچ مسیری به اسپینر بی‌پایان یا پیام خالی ختم نمی‌شود.

**تعریف قطعی موفقیت برای سیستم ایجنت:** یک نوبت چندمرحله‌ای تا انتها کار می‌کند: مدل ابزار را صدا می‌زند، کاربر مرحله‌ها را می‌بیند، نتیجهٔ ابزار در نوبت بعدی برمی‌گردد، پاسخ نهایی فارسی نوشته می‌شود، و **هیچ JSON خامی در چت دیده نمی‌شود**. ابزار `ask_user` دیگر قفل نمی‌کند و پرسش واقعاً به کاربر نشان داده می‌شود. هیچ متن عادی که فقط شبیه JSON است به اشتباه اجرا نمی‌شود.

---

### یادآوری نهایی — مهم‌ترین قاعدهٔ این سند

این سند خودش نقشهٔ پیاده‌سازی است.

**نقشهٔ پیاده‌سازی جدید ننویس. سند طراحی ننویس. چرخهٔ پیش‌نویس ← ارزیابی ← بازنویسی موضوع بند ۲ فایل `.agents/AGENTS.md` برای این کار صریحاً لغو شده است.** بند ۱ (تحلیل عمیق پیش از تغییر) و بند ۳ (صفر خطا و صفر هشدار) همچنان لازم‌الاجرا هستند.

از فاز ۰ شروع کن. `A-01` را بردار و کد بنویس.
