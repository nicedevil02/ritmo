# پرامپت اجرایی: تکمیل سیستم ایجنتینگ پروژه Ritmo

> **این فایل یک دستورکار اجرایی است، نه یک سند طراحی.**
> نقشه‌ی پیاده‌سازی از قبل نوشته شده و داخل همین فایل است. وظیفه‌ی تو **فقط اجرای مرحله‌به‌مرحله** آن است.

**ریپو:** `nicedevil02/ritmo` · **پلتفرم:** Flutter / Dart · **زبان UI:** فارسی (RTL)

---

# بخش ۰ — قوانین آهنین (قبل از هر کاری بخوان)

1. **هیچ فایل نقشه/رودمپ/پلن جدیدی نساز.** ننویس «برنامه‌ی پیاده‌سازی من این است». نقشه همین فایل است. مستقیم برو سر تسک اول.
2. **ترتیب تسک‌ها را عوض نکن.** تسک‌ها به هم وابسته‌اند. `T01` قبل از `T02`، فاز `A` قبل از فاز `B`.
3. **یک تسک در یک زمان.** تسک را کامل کن، تست کن، کامیت کن، در فایل پیشرفت ثبت کن، بعد برو سر بعدی. هرگز چند تسک را با هم قاطی نکن.
4. **حلقه‌ی اجباری هر تسک:**
   ```
   بخوان فایل‌های هدف → تغییر بده → flutter analyze → تست مربوطه را اجرا کن → کامیت کن → PROGRESS را آپدیت کن
   ```
5. **هرگز `catch (_) {}` یا `catch (e) {}` خالی ننویس.** هر catch باید یا لاگ کند یا خطا را به بالا بدهد. اگر در مسیرت به یکی برخوردی، همان‌جا درستش کن.
6. **هرگز برای نوشتن در دیتابیس SQL خام نزن.** هر نوشتنی باید از `RitmoCommandBus` بگذرد. این «اصل ۱» پروژه است.
7. **هر رشته‌ی فارسی که می‌نویسی را از نظر املا چک کن.** غلط‌های رایج موجود در پروژه: `تنطیم` → `تنظیم`، `منتطر` → `منتظر`، `حافطه` → `حافظه`، `لحطه` → `لحظه`.
8. **کد مرده را حذف کن، deprecate نکن.** اگر تسکی می‌گوید فایلی را جایگزین کن، فایل قدیمی را `git rm` کن.
9. **هیچ `TODO`، `FIXME` یا کد کامنت‌شده باقی نگذار.**
10. **تغییر schema دیتابیس بدون migration ممنوع.** اگر جدول یا ستون جدید لازم شد، migration نسخه‌دار بنویس و در `test/db_migration_test.dart` پوشش بده.
11. **هر تغییر رفتاری باید تست داشته باشد.** بدون تست، تسک تمام‌شده حساب نمی‌شود.
12. **اگر تسکی از قبل انجام‌شده بود** (کد الان درست است)، آن را `SKIPPED` علامت بزن با یک خط دلیل در PROGRESS و برو بعدی. تسک را دوباره ننویس.
13. **اگر تسکی به‌خاطر واقعیت کد قابل اجرا نبود**، آن را `BLOCKED` علامت بزن، دقیقاً بنویس چه چیزی متفاوت بود، **برو سراغ تسک بعدی** و در آخر همه‌ی BLOCKEDها را یک‌جا گزارش بده. هرگز کل کار را متوقف نکن.
14. **در پایان هر فاز**، `flutter analyze` و کل `flutter test` را اجرا کن. فاز بعدی را با تست شکسته شروع نکن.
15. **نام‌های دقیق را از خود کد بخوان.** مسیرها و نام کلاس‌ها در این فایل دقیق‌اند ولی اگر جایی اختلاف دیدی، **کد منبع حقیقت است**، این فایل نه.

---

# بخش ۱ — سازوکار ضد فراموشی (اجباری)

قبل از تسک `T01`، این فایل را بساز:

**`docs/ai/AGENTING_COMPLETION_PROGRESS.md`**

```markdown
# پیشرفت تکمیل ایجنتینگ

وضعیت‌های مجاز: TODO | DOING | DONE | SKIPPED | BLOCKED

| ID | عنوان | وضعیت | کامیت | یادداشت |
|----|-------|-------|-------|---------|
| T01 | پاس دادن personaId به حلقه | TODO | | |
| T02 | نصب AgentConfirmationHost | TODO | | |
... (همه‌ی T01 تا T50 را از بخش‌های بعدی همین فایل کپی کن)
```

**قواعد استفاده از این فایل:**

- **در ابتدای هر نشست کاری**، اول این فایل را بخوان. اولین ردیف با وضعیت `TODO` یا `DOING` را بردار. هیچ‌وقت از حافظه‌ات حدس نزن کجا بودی.
- قبل از شروع هر تسک، وضعیتش را `DOING` کن.
- بعد از کامیت، وضعیتش را `DONE` کن و هش کامیت را بنویس.
- این فایل را در همان کامیت تسک آپدیت کن، نه در یک کامیت جدا.
- **هرگز یک تسک را DONE نکن بدون اینکه کامیتی برایش وجود داشته باشد.**

---

# بخش ۲ — شناخت پیش از دست زدن (فقط خواندن، بدون تغییر)

قبل از `T01` این فایل‌ها را بخوان تا مدل ذهنی درستی داشته باشی. **در این مرحله هیچ چیزی تغییر نده و هیچ خروجی متنی طولانی تولید نکن.**

```
lib/core/ai/agent/agent_loop_runner.dart
lib/core/ai/agent/agent_tool.dart
lib/core/ai/agent/agent_tool_registry.dart
lib/core/ai/agent/agent_tool_scope.dart
lib/core/ai/agent/agent_tool_protocol.dart
lib/core/ai/agent/agent_tool_call_parser.dart
lib/core/ai/agent/agent_policy_gate.dart
lib/core/ai/agent/agent_journal.dart
lib/core/ai/agent/agent_event.dart
lib/core/ai/agent/agent_budget.dart
lib/core/ai/agent/agent_transcript.dart
lib/core/ai/agent/agent_intent_prefetcher.dart
lib/core/ai/agent/intent/agent_intent_router.dart
lib/core/ai/agent/intent/ritmo_date_parser.dart
lib/core/ai/agent/catalog/agent_tools_initializer.dart
lib/core/ai/agent/catalog/kernel_command_tool.dart
lib/core/ai/agent/ui/agent_confirmation_card.dart
lib/core/ai/chat/streaming_chat_service.dart
lib/features/assistant/presentation/widgets/unified_assistant_sheet.dart
lib/core/domain/commands/ritmo_command_bus.dart
lib/core/domain/commands/commands_registry.dart
lib/core/domain/commands/param_spec.dart
lib/core/domain/personas/persona_gate.dart
lib/core/domain/personas/persona_registry.dart
```

**حقایق تأییدشده‌ای که باید بدانی (اینها را دوباره تحقیق نکن):**

- همه‌ی دستیارهای تخصصی از **یک** ویجت می‌آیند: `AssistantSheet` در `unified_assistant_sheet.dart`، با پارامتر `AssistantPersona`. شیت جداگانه‌ی هر دامنه وجود ندارد.
- تنها استثنای احتمالی: `lib/features/supplementary_sports/presentation/widgets/ss_ai_coach_sheet.dart` — در `T27` بررسی و مهاجرت داده می‌شود.
- دو مصرف‌کننده‌ی `AgentLoopRunner` وجود دارد و **فقط دو تا**: `streaming_chat_service.dart` (چت اصلی) و `unified_assistant_sheet.dart` (دستیارهای تخصصی). هر تغییری در قرارداد حلقه باید در هر دو اعمال شود.
- `intent/agent_intent_router.dart` و `intent/ritmo_date_parser.dart` نوشته شده‌اند ولی **هیچ‌جا صدا زده نمی‌شوند**.
- `AgentConfirmationHost` نوشته شده ولی **در هیچ درخت ویجتی نصب نشده**.
- در `test/` **هیچ تستی برای هسته‌ی ایجنت وجود ندارد**.

---

# فاز A — رفع بحرانی‌های سیم‌کشی

> هدف فاز: بدون هیچ ریفکتور معماری، قابلیت‌هایی که از قبل نوشته شده‌اند را وصل کن. این فاز کم‌ریسک‌ترین و پرسودترین است.

### T01 · پاس دادن `personaId` به حلقه

**فایل‌ها:** `unified_assistant_sheet.dart`، `streaming_chat_service.dart`، `agent_loop_runner.dart`

**کار:**
- در `unified_assistant_sheet.dart` در فراخوانی `AgentLoopRunner.instance.runAgent(...)` آرگومان `personaId: widget.persona.id` را اضافه کن.
- در `streaming_chat_service.dart` همان‌جا `personaId` را از پرسونای فعال چت پاس بده. اگر چت اصلی پرسونای مشخصی ندارد، `'global'` را **صریح** پاس بده (نه با تکیه بر مقدار پیش‌فرض).
- در `agent_loop_runner.dart` مقدار پیش‌فرض `personaId = 'global'` را حذف کن و پارامتر را `required` کن، تا کامپایلر جلوی فراموشی آینده را بگیرد.
- مطمئن شو همان `personaId` به `KernelCommandTool` هم می‌رسد تا `PersonaGate` پرسونای واقعی را ببیند، نه `'global'`.

**معیار پذیرش:** جست‌وجوی `runAgent(` در کل `lib/` هیچ فراخوانی بدون `personaId` نشان ندهد. `flutter analyze` پاک باشد.

**کامیت:** `fix(agent): pass real personaId into agent loop and persona gate`

---

### T02 · نصب کارت تایید در UI

**فایل‌ها:** `unified_assistant_sheet.dart`، `agent_confirmation_card.dart`

**کار:**
- `AgentConfirmationHost` را import کن و در `build` شیت، **بالای نوار ورودی و پایین `AgentTimelineVisualizer`** قرار بده.
- در `AgentConfirmationBroker`، `timeout` را از `Duration(minutes: 3)` به `Duration(seconds: 90)` تغییر بده.
- روی timeout، **دیگر بی‌صدا `expired` برنگردان**: یک رویداد `AgentConfirmationTimedOutEvent` منتشر کن و در UI پیام فارسی نشان بده: «زمان تایید تمام شد، اقدام انجام نشد. اگر می‌خواهی، دوباره درخواست بده.»

**معیار پذیرش:** یک ابزار با policy `actionInteractive` را دستی صدا بزن؛ کارت تایید باید ظاهر شود و دکمه‌های تایید/رد کار کنند.

**کامیت:** `fix(agent): mount confirmation host and surface confirmation timeout`

---

### T03 · نشتی اشتراک و broker در dispose

**فایل:** `unified_assistant_sheet.dart`

**کار:** در `dispose()` این دو خط را اضافه کن:
```dart
_agentSubscription?.cancel();
AgentConfirmationBroker.instance.cancelAll();
```

**معیار پذیرش:** بستن شیت در میانه‌ی یک ران، حلقه را متوقف کند و هیچ `setState after dispose` در لاگ نباشد.

**کامیت:** `fix(agent): cancel agent subscription and pending confirmations on dispose`

---

### T04 · استفاده از `rawAnswer` به‌جای متن تمیزشده

**فایل:** `unified_assistant_sheet.dart`

**مشکل فعلی:** `fullResponse` از `event.accumulated` پر می‌شود که خروجی `cleanForDisplay` است و تگ‌های `<actions>` و `<memory_ops>` از آن حذف شده‌اند. بعد همان متن به `ChatActionParser.parse` داده می‌شود، پس همیشه خالی است و کل مسیر اجرای اکشن مرده است.

**کار:**
- متن **نمایشی** همان `accumulated` بماند (کاربر نباید تگ ببیند).
- برای پارس، از `AgentCompletedEvent.rawAnswer` استفاده کن. یعنی `_validateAndExecute(event.rawAnswer)`.
- پردازش `<memory_ops>` را هم به شیت اضافه کن، همان‌طور که `streaming_chat_service` انجام می‌دهد، تا حافظه در دستیارهای تخصصی فقط خوانده نشود بلکه نوشته هم بشود.

**معیار پذیرش:** یک پاسخ ساختگی با بلوک `<actions>` بده؛ شیت پیش‌نمایش باید ظاهر شود. حافظه هم باید نوشته شود.

**کامیت:** `fix(assistant): parse actions and memory ops from rawAnswer, not display text`

---

### T05 · هندل کردن همه‌ی رویدادها در چت اصلی

**فایل:** `streaming_chat_service.dart`

**کار:** الان فقط ۴ نوع رویداد هندل می‌شود. این‌ها را هم اضافه کن:
- `AgentTurnStartedEvent`، `AgentStepStartedEvent`، `AgentStatusChangedEvent` → به `agent_step_timeline.dart` بده تا تایم‌لاین در چت اصلی هم زنده شود.
- `AgentAwaitingConfirmationEvent` و `AgentConfirmationResolvedEvent` → به `AgentConfirmationHost` وصل کن (میزبان را در درخت چت اصلی هم نصب کن).
- `AgentStepCompletedEvent` را از `debugPrint` صرف به آپدیت واقعی تایم‌لاین تبدیل کن.

**معیار پذیرش:** در چت اصلی، گام‌های ایجنت به‌صورت زنده دیده شوند و کارت تایید کار کند — دقیقاً مثل شیت.

**کامیت:** `fix(chat): surface all agent events to timeline and confirmation host`

---

### T06 · اصلاح «تاریخچه اخیر» معکوس

**فایل:** `unified_assistant_sheet.dart`

**مشکل فعلی:** `_messages.where(...).take(4)` ۴ پیام **قدیمی‌ترین** را می‌گیرد، نه آخرین‌ها. پس کانتکست گفتگو هرگز جلو نمی‌رود.

**کار:** همان الگوی درست `streaming_chat_service` را به کار ببر:
```dart
final recentHistory = _messages
    .where((m) => m.content.trim().isNotEmpty)
    .toList()
    .reversed
    .take(4)
    .toList()
    .reversed
    .map((m) => '${m.role == ChatRole.user ? "کاربر" : "دستیار"}: ${m.content}')
    .toList();
```

**معیار پذیرش:** یک تست ویجت یا یونیت که با ۱۰ پیام، ۴ پیام آخر را به ترتیب زمانی درست برگرداند.

**کامیت:** `fix(assistant): send the last four messages as recent history, not the first four`

---

### T07 · اعمال یا حذف `PersonaInferenceProfile`

**فایل:** `unified_assistant_sheet.dart`

**مشکل فعلی:** `profile = PersonaInferenceProfile.getProfile(...)` و `messagesToSend` ساخته می‌شوند و فقط `debugPrint` می‌شوند — متغیر مرده.

**کار:** پروفایل را واقعاً اعمال کن. `maxTokens` و `temperature` را به `runAgent` (و از آن به `AIGateway`) پاس بده. متغیر `messagesToSend` که کاملاً بی‌استفاده است را حذف کن.

**معیار پذیرش:** هیچ متغیر بی‌استفاده‌ای در `_sendMessage` نماند؛ `flutter analyze` هیچ هشدار unused ندهد.

**کامیت:** `fix(assistant): actually apply persona inference profile and drop dead locals`

---

### T08 · بودجه‌ی نوشتن نباید با شکست مصرف شود

**فایل:** `agent_loop_runner.dart`

**کار:** شمارش نوشتن را مشروط به موفقیت کن:
```dart
if (tool.policy != ToolPolicy.readOnly && result.isSuccess) {
  writesUsed++;
}
```

**معیار پذیرش:** تست: ۳ نوشتن ناموفق پشت‌سرهم، بودجه‌ی نوشتن را تمام نکند.

**کامیت:** `fix(agent): only consume write budget on successful writes`

---

### T09 · `trimToBudget` نباید سؤال کاربر را حذف کند

**فایل:** `agent_transcript.dart`

**مشکل فعلی:** `_messages.removeAt(1)` اولین پیام بعد از system را برمی‌دارد که همان درخواست اصلی کاربر است.

**کار:** پیام system و **اولین پیام user** را به‌عنوان «سنجاق‌شده» علامت‌گذاری کن و از حذف مستثنی کن. هرس را از قدیمی‌ترین **نتایج ابزار** شروع کن. اگر باز هم جا کم بود، نتایج ابزار قدیمی را با یک خط خلاصه جایگزین کن، نه حذف کامل.

**معیار پذیرش:** تست: ترنسکریپت را تا سقف پر کن؛ پیام system و سؤال اصلی کاربر باید همیشه باقی بمانند.

**کامیت:** `fix(agent): pin system prompt and original user question when trimming transcript`

---

### T10 · بریدن نادرست متن نهایی

**فایل:** `streaming_chat_service.dart`

**مشکل فعلی:** `cap = 8000` با `substring` می‌برد (احتمال بریدن وسط جفت surrogate یا ایموجی) و **بعد از** `ChatActionParser.parse` اجرا می‌شود، پس بلوک `<actions>` دیرآمده قطع می‌شود.

**کار:**
- **اول** پارس کن، **بعد** ببر.
- برای بریدن از `characters` (پکیج `characters`) استفاده کن، نه `substring` روی code unit.
- در انتهای متن بریده‌شده یک نشانگر فارسی اضافه کن: `\n\n…[پاسخ طولانی بود و کوتاه شد]`

**معیار پذیرش:** تست: متنی با ایموجی در مرز `cap` نباید کاراکتر خراب تولید کند؛ بلوک `<actions>` در انتهای متن بلند باید همچنان پارس شود.

**کامیت:** `fix(chat): parse before truncating and use grapheme-safe truncation`

---

### T11 · تقارن fallback بین چت اصلی و شیت

**فایل:** `unified_assistant_sheet.dart`

**کار:** رفتار `AgentErrorEvent` در شیت را با چت اصلی هم‌تراز کن: اگر خطا در دور اول و بدون هیچ داده‌ی ابزاری رخ داد، به فراخوانی ساده‌ی `AIGateway` برگرد (همان fallback `streaming_chat_service`) و فقط اگر آن هم شکست خورد پیام خطا نشان بده. منطق fallback را در یک تابع مشترک بگذار تا دوباره واگرا نشود.

**معیار پذیرش:** با شبیه‌سازی خطای provider، شیت هم مثل چت اصلی پاسخ می‌دهد.

**کامیت:** `fix(assistant): share gateway fallback logic between chat and assistant sheet`

---

### T12 · حذف `catch (_) {}` و بررسی جدول `assistant_plans`

**فایل:** `unified_assistant_sheet.dart` و هر جای دیگری از مسیر ایجنت

**کار:**
- در `_checkLastPlan` بدنه‌ی `catch (_) {}` را با لاگ واقعی عوض کن (`RitmoLog.error` یا معادل موجود در پروژه).
- تأیید کن جدول `assistant_plans` واقعاً در schema وجود دارد. اگر ندارد، **جدول را نساز** — چون در `T28` کل undo روی `AgentJournal` یکپارچه می‌شود؛ فقط در PROGRESS ثبت کن که این جدول موجود نیست.
- در کل `lib/core/ai/` و `lib/features/assistant/` با ripgrep `catch (_)` و `catch (e) {}` را پیدا کن و همه را لاگ‌دار کن.

**معیار پذیرش:** `rg 'catch \(_\) \{\}' lib/core/ai lib/features/assistant` خروجی خالی بدهد.

**کامیت:** `fix(assistant): never swallow errors silently in agent paths`

---

**پایان فاز A:** `flutter analyze && flutter test` را اجرا کن. در PROGRESS یک خط گزارش فاز بنویس.

---

# فاز B — کشتن کد مرده و یکی‌سازی نیت‌شناسی

### T13 · وصل کردن `AgentIntentRouter` و حذف `AgentIntentPrefetcher`

**فایل‌ها:** `agent_loop_runner.dart`، `intent/agent_intent_router.dart`، `agent_intent_prefetcher.dart`

**مشکل فعلی:** حلقه `AgentIntentPrefetcher.prefetchForQuery(prompt)` را صدا می‌زند. روتر جدید (توکن‌محور، پرسونا-اسکوپ، با `RitmoDateParser`) هیچ فراخوانی ندارد. هر دو فایل کلاس همنام `PrefetchResult` دارند.

**کار:**
1. در `agent_loop_runner.dart` فراخوانی را عوض کن:
   ```dart
   final prefetch = await AgentIntentRouter.instance.route(
     query: prompt,
     personaId: personaId,
   );
   ```
2. `import` قدیمی را حذف کن.
3. فایل `lib/core/ai/agent/agent_intent_prefetcher.dart` را **`git rm` کن**.
4. کلاس `PrefetchResult` فقط در `intent/agent_intent_router.dart` بماند.
5. اطمینان حاصل کن روتر واقعاً `RitmoDateParser.parse` را برای عبارت‌های تاریخی مثل «شنبه آینده»، «۲۰ مرداد»، «سه روز دیگه» به کار می‌برد و تاریخ ISO به ابزارها می‌دهد.

**معیار پذیرش:** `rg 'AgentIntentPrefetcher' lib/` خروجی خالی. تست: با ورودی «برنامه‌ی شنبه آینده‌م چیه؟» ابزار `get_day_agenda` با تاریخ ISO درست فراخوانی شود، نه رشته‌ی `'today'`.

**کامیت:** `refactor(agent): replace legacy intent prefetcher with scoped intent router`

---

### T14 · اصلاح نام ابزار عبادی در همه‌جا

**فایل‌ها:** `agent_tool_scope.dart`، `intent/agent_intent_router.dart`، `catalog/study_worship_agent_tools.dart`

**مشکل فعلی:** نام واقعی ابزار ثبت‌شده `get_worship_practices` است، ولی در نقشه‌ی اسکوپ و در روتر کلید `get_worship_routines` نوشته شده. نتیجه: `requirement == null` → ابزار از هر پرسونای غیر-`global` مخفی می‌شود و روتر آن را «ابزار ناشناس» رد می‌کند.

**کار:**
- همه‌ی `get_worship_routines` را به `get_worship_practices` تغییر بده.
- برای `create_worship_practice` که **هیچ ورودی در نقشه‌ی اسکوپ ندارد**، ورودی درست اضافه کن.
- در `AgentToolScope`، حالت `requirement == null` را از «برگرد `persona.id == 'global'` با یک debugPrint» به **پرتاب خطا در حالت debug** تغییر بده (`assert`) تا این کلاس باگ دیگر بی‌صدا نماند.

**معیار پذیرش:** تست `T16` پاس شود.

**کامیت:** `fix(agent): correct worship tool scope keys and fail loudly on missing mapping`

---

### T15 · یکی کردن کش prefetch و ثبت در بودجه

**فایل‌ها:** `agent_loop_runner.dart`، `agent_budget.dart`

**مشکل فعلی:** نتایج prefetch با کلید `'${r.toolName}|prefetch'` کش می‌شوند که هرگز با `_cacheKey(tool.name, args)` مطابق نمی‌شود، پس همان خواندن دوباره اجرا می‌شود. `AgentBudget.registerExecuted` هیچ‌جا صدا زده نمی‌شود.

**کار:**
```dart
for (final r in prefetch.results) {
  toolCache[_cacheKey(r.toolName, r.args)] = r.result;
  budget.registerExecuted(r.toolName, r.args);
}
```

**معیار پذیرش:** تست: اگر مدل بعد از prefetch همان ابزار را با همان آرگومان صدا بزند، اجرای واقعی رخ ندهد و از کش برگردد.

**کامیت:** `fix(agent): unify prefetch cache key and register prefetched calls in budget`

---

### T16 · تست یکپارچگی نقشه‌ی اسکوپ (نگهبان CI)

**فایل جدید:** `test/architecture/agent_tool_scope_integrity_test.dart`

**کار:** تستی بنویس که:
1. `initializeAllAgentTools()` را اجرا کند.
2. برای **هر** ابزار ثبت‌شده مطمئن شود یک ورودی در `AgentToolScope.requirements` وجود دارد.
3. برعکسش را هم چک کند: هر کلید در نقشه‌ی اسکوپ باید به یک ابزار واقعاً ثبت‌شده اشاره کند (این همان تستی است که باگ `get_worship_routines` را می‌گرفت).
4. مطمئن شود هر `commandId` که در نقشه به آن ارجاع شده، در `RitmoCommandBus` وجود دارد.

**معیار پذیرش:** تست پاس شود و اگر عمداً یک ابزار را از نقشه حذف کنی، شکست بخورد.

**کامیت:** `test(agent): guard tool/scope/command registry consistency`

---

**پایان فاز B:** `flutter analyze && flutter test`.

---

# فاز C — قرارداد واقعی ابزار

### T17 · اسکیمای واقعی JSON Schema

**فایل:** `lib/core/ai/agent/agent_tool.dart`

**مشکل فعلی:** `ToolParameter.toSchema()` نوع‌های `int`/`double`/`list`/`map` تولید می‌کند که هیچ‌کدام نوع معتبر JSON Schema نیستند، و `required` را به‌عنوان فیلد داخل هر property می‌گذارد که غلط است.

**کار:** این‌ها را پیاده کن:

```dart
enum ToolParamType { string, integer, number, boolean, array, object }

extension ToolParamTypeJson on ToolParamType {
  String get jsonName => switch (this) {
        ToolParamType.integer => 'integer',
        ToolParamType.number => 'number',
        ToolParamType.boolean => 'boolean',
        ToolParamType.array => 'array',
        ToolParamType.object => 'object',
        ToolParamType.string => 'string',
      };
}

class ToolParameter {
  const ToolParameter({
    required this.name,
    required this.type,
    required this.descriptionFa,
    this.isRequired = false,
    this.allowedValues,
    this.min,
    this.max,
    this.pattern,
    this.defaultValue,
  });

  final String name;
  final ToolParamType type;
  final String descriptionFa;
  final bool isRequired;
  final List<String>? allowedValues;
  final num? min;
  final num? max;
  final String? pattern; // مثال ساعت: r'^([01]?\d|2[0-3]):[0-5]\d$'
  final Object? defaultValue;
}
```

و روی `AgentTool`:

```dart
Map<String, dynamic> get jsonSchema => {
      'name': name,
      'description': descriptionFa,
      'parameters': {
        'type': 'object',
        'properties': {
          for (final p in parameters)
            p.name: {
              'type': p.type.jsonName,
              'description': p.descriptionFa,
              if (p.allowedValues != null) 'enum': p.allowedValues,
              if (p.min != null) 'minimum': p.min,
              if (p.max != null) 'maximum': p.max,
              if (p.pattern != null) 'pattern': p.pattern,
            },
        },
        'required': [for (final p in parameters) if (p.isRequired) p.name],
        'additionalProperties': false,
      },
    };
```

- همه‌ی ۲۳ ابزار موجود را به این قرارداد مهاجرت بده. هر پارامتر باید `descriptionFa` معنادار داشته باشد (املا را چک کن).
- برای پارامترهای ساعت `pattern` بگذار، برای عددها `min`/`max`، برای انتخابی‌ها `allowedValues`.
- `import 'package:flutter/foundation.dart'` بی‌استفاده در `agent_tool.dart` را حذف کن.

**معیار پذیرش:** تست: برای هر ابزار ثبت‌شده، `jsonSchema` یک JSON Schema معتبر باشد و هیچ نوع غیراستاندارد نداشته باشد.

**کامیت:** `feat(agent): real JSON Schema contract for tool parameters`

---

### T18 · اعتبارسنج مرکزی آرگومان‌ها

**فایل جدید:** `lib/core/ai/agent/agent_tool_validator.dart`
**فایل تغییریافته:** `agent_tool_registry.dart`

**مشکل فعلی:** `executeTool` فقط try/catch است. `required`/`type`/`allowedValues` هرگز چک نمی‌شوند و هر ابزار جدا پارس دستی می‌کند.

**کار:** پیاده کن:

```dart
class ToolArgValidation {
  const ToolArgValidation.ok(this.coerced)
      : isValid = true, messageFa = null;
  const ToolArgValidation.invalid(this.messageFa)
      : isValid = false, coerced = const {};

  final bool isValid;
  final Map<String, dynamic> coerced;
  final String? messageFa;
}

class AgentToolValidator {
  static ToolArgValidation validate(
    AgentTool tool,
    Map<String, dynamic> raw,
  ) {
    final out = <String, dynamic>{};
    final errors = <String>[];

    // ۱) پارامتر ناشناس خطاست، نه چیزی که بی‌صدا نادیده گرفته شود
    final known = tool.parameters.map((p) => p.name).toSet();
    for (final key in raw.keys) {
      if (!known.contains(key)) {
        errors.add('پارامتر ناشناس «$key». پارامترهای مجاز: ${known.join('، ')}');
      }
    }

    for (final p in tool.parameters) {
      var value = raw[p.name];

      // ۲) خالی/غایب
      final isBlank = value == null ||
          (value is String && value.trim().isEmpty);
      if (isBlank) {
        if (p.isRequired) {
          errors.add('پارامتر «${p.name}» الزامی است (${p.descriptionFa}).');
        } else if (p.defaultValue != null) {
          out[p.name] = p.defaultValue;
        }
        continue;
      }

      // ۳) ارقام فارسی/عربی به لاتین، قبل از هر تبدیل عددی
      if (value is String) {
        value = toEnglishDigits(value.trim());
      }

      // ۴) تبدیل نوع با پیام فارسی روشن
      // integer/number/boolean/array/object → کدِ تبدیل + خطای گویا
      // ۵) بازه min/max
      // ۶) allowedValues (enum)
      // ۷) pattern (RegExp)
      // در هر شکست: errors.add(...) با ذکر نام پارامتر و مقدار دریافتی

      out[p.name] = value;
    }

    if (errors.isEmpty) return ToolArgValidation.ok(out);

    return ToolArgValidation.invalid(
      'آرگومان‌های ابزار «${tool.titleFa}» نامعتبر است:\n'
      '- ${errors.join('\n- ')}\n'
      'با پارامترهای اصلاح‌شده دوباره همین ابزار را فراخوانی کن.',
    );
  }
}
```

**نکته‌ی حیاتی برای رفتار «ایجنت برنامه‌نویس»:** پیام خطا باید **عیناً و بدون خلاصه‌سازی** به‌عنوان نتیجه‌ی ابزار به مدل برگردد تا خودش اصلاح کند. این همان الگویی است که `ToolArgumentError` در `KernelCommandTool` درست پیاده کرده — همان را عمومی کن.

در `AgentToolRegistry.executeTool` این را **قبل از** `tool.execute` بگذار:
```dart
final v = AgentToolValidator.validate(tool, args);
if (!v.isValid) {
  return AgentToolResult.failure(messageFa: v.messageFa!);
}
return await tool.execute(v.coerced);
```

**معیار پذیرش:** تست `T46`.

**کامیت:** `feat(agent): central argument validator with model-facing Persian errors`

---

### T19 · حذف پارسرهای دستی تکراری

**فایل‌ها:** همه‌ی فایل‌های `lib/core/ai/agent/catalog/*.dart`

**کار:** حالا که اعتبارسنج مرکزی آرگومان‌ها را نرمال و تبدیل می‌کند، توابع تکراری داخل ابزارها را حذف کن: `optionalInt`، `clampedInt`، تبدیل دستی ارقام فارسی، `normalizeTimeOfDay` هر جا که کار اعتبارسنج را تکرار می‌کند. ابزارها باید مقدار **قبلاً معتبر** را دریافت کنند.

`normalizeTimeOfDay` و `AgentDateResolver` را اگر منطق دامنه‌ای دارند (مثل تشخیص جلالی با `y >= 1200 && y < 1700`) نگه دار، ولی به یک جای مشترک منتقل کن و از همه‌ی ابزارها همان یکی را صدا بزن.

**معیار پذیرش:** هیچ ابزاری منطق تبدیل نوع تکراری نداشته باشد. تست‌های موجود پاس بمانند.

**کامیت:** `refactor(agent): drop per-tool ad-hoc argument parsing`

---

### T20 · `idempotencyKey`

**فایل:** `agent_tool.dart` و ابزارهای نوشتن

**کار:** به `AgentTool` اضافه کن:
```dart
String? idempotencyKeyFor(Map<String, dynamic> args) => null;
```
برای ابزارهای نوشتن آن را پیاده کن (مثلاً برای ساخت روتین: هش نام + زمان + تاریخ). در حلقه، قبل از اجرا، اگر کلیدی با همان مقدار در همان ران قبلاً موفق اجرا شده، **دوباره اجرا نکن** و نتیجه‌ی قبلی را برگردان با پیام فارسی «این اقدام قبلاً در همین گفتگو انجام شد».

**معیار پذیرش:** تست: دو فراخوانی یکسان نوشتن در یک ران، فقط یک ردیف در DB بسازد.

**کامیت:** `feat(agent): idempotency keys prevent duplicate writes within a run`

---

**پایان فاز C:** `flutter analyze && flutter test`.

---

# فاز D — function calling بومی

### T21 · قابلیت‌سنجی provider

**فایل جدید:** `lib/core/ai/ai_provider_capabilities.dart`

**کار:** کلاسی بساز که برای هر provider/connection بگوید آیا `tools` بومی را پشتیبانی می‌کند:
```dart
class AiProviderCapabilities {
  const AiProviderCapabilities({
    required this.nativeTools,
    required this.parallelToolCalls,
    required this.maxContextChars,
  });

  final bool nativeTools;
  final bool parallelToolCalls;
  final int maxContextChars;

  static AiProviderCapabilities of(AiConnection connection) { /* ... */ }
}
```
مسیر ChatGPT-Web همیشه `nativeTools: false` است.

**کامیت:** `feat(ai): provider capability model for native tool support`

---

### T22 · عبور `tools` از `AIGateway`

**فایل:** `lib/core/ai/ai_gateway.dart`

**مشکل فعلی:** `sendCustomChatStream` فقط `messages` می‌فرستد، پس هیچ‌وقت function calling بومی ممکن نیست.

**کار:** امضا را گسترش بده:
```dart
Stream<String> sendCustomChatStream({
  required List<Map<String, dynamic>> messages,
  List<Map<String, dynamic>>? tools,
  String? toolChoice, // 'auto' | 'none' | 'required'
  int? maxTokens,
  double? temperature,
  ...
});
```
در بدنه‌ی هر provider که پشتیبانی می‌کند، `body['tools'] = tools` و `body['tool_choice'] = toolChoice` را بگذار. برای provider‌های بدون پشتیبانی، `tools` را نادیده بگیر (و در `T23` fallback XML کار می‌کند).

**کامیت:** `feat(ai): forward native tool schemas to supporting providers`

---

### T23 · نرمال‌ساز واحد فراخوانی ابزار + fallback XML

**فایل‌ها:** `agent_loop_runner.dart`، `agent_tool_protocol.dart`، `agent_tool_call_parser.dart`

**مشکل فعلی:** `formatFor(supportsNativeTools: false)` با مقدار literal صدا زده می‌شود؛ `wireFormat` محاسبه و لاگ می‌شود ولی هیچ رفتاری را عوض نمی‌کند و enum `nativeFunctionCalling` مرده است.

**کار:**
1. مقدار literal را با قابلیت واقعی عوض کن:
   ```dart
   final caps = AiProviderCapabilities.of(connection);
   final wireFormat = AgentToolProtocol.formatFor(
     supportsNativeTools: caps.nativeTools,
   );
   ```
2. اگر `nativeFunctionCalling` بود: اسکیماها را با `tools` بفرست و **بلوک کاتالوگ XML را از system prompt حذف کن** (صرفه‌جویی بزرگ توکن).
3. اگر XML بود: مثل الان کاتالوگ را در پرامپت بگذار.
4. یک نرمال‌ساز واحد بنویس که خروجی هر دو مسیر را به یک نوع تبدیل کند:
   ```dart
   List<AgentToolCall> normalizeToolCalls({
     Map<String, dynamic>? nativeResponse,
     String? rawText,
   });
   ```
   **`AgentToolCallParser` را دست نزن جز برای وصل شدن به این نرمال‌ساز** — پارسر فعلی واقعاً مقاوم است (چند بلوک، code fence، JSON لخت، `{"tool_calls":[...]}`، brace matching) و باید به‌عنوان fallback حفظ شود.
5. بقیه‌ی حلقه باید **کاملاً بی‌تفاوت** به wire format باشد.

**معیار پذیرش:** تست: با provider جعلی دارای `nativeTools: true` مسیر بومی و با `false` مسیر XML، هر دو به یک `List<AgentToolCall>` یکسان برسند.

**کامیت:** `feat(agent): wire native function calling with XML protocol as fallback`

---

### T24 · فشرده‌سازی پرامپت ابزار

**فایل:** `agent_tool_scope.dart`

**مشکل فعلی:** `promptFor(personaId)` کاتالوگ کامل فارسی ۲۳ ابزار را هر ران از صفر می‌سازد، بدون کش. روی مسیر ChatGPT-Web این متن باید در textarea تایپ شود.

**کار:**
1. **دو لایه:** یک خط تک‌سطری برای همه‌ی ابزارهای مجاز + اسکیمای کامل فقط برای ابزارهایی که `AgentIntentRouter` مرتبط تشخیص داده.
2. خروجی را با کلید `personaId + toolRegistryRevision` کش کن.
3. در مسیر بومی، `tools` را هم به همان زیرمجموعه‌ی مرتبط محدود کن.

**معیار پذیرش:** تست: طول پرامپت ابزار برای یک پرسونای تخصصی حداقل ۵۰٪ کمتر از کاتالوگ کامل باشد و ابزار مرتبط همیشه در آن حاضر باشد.

**کامیت:** `perf(agent): two-tier cached tool catalog scoped by intent`

---

**پایان فاز D:** `flutter analyze && flutter test`.

---

# فاز E — یک مسیر نوشتن، یک منبع حقیقت

### T25 · حذف مسیر موازی `<actions>` از شیت

**فایل:** `unified_assistant_sheet.dart`

**کار:**
- کل `_parseAndExecuteActions`، `_mapActionTypeToNewCommandId` و `_showPreviewSheet` را از شیت **حذف** کن.
- منطق پیش‌نمایش diff (که کد خوبی است) را به `AgentConfirmationHost` منتقل کن تا **همان** پیش‌نمایش برای فراخوانی‌های `<tool_call>` نمایش داده شود: عنوان فارسی، diff قبل/بعد، هشدارها، و شرط بیومتریک.
- `ai_agent_mode` (`suggest` / `confirm` / `auto`) را به سطح `AgentPolicyGate` منتقل کن تا تصمیم تایید در **یک** جا گرفته شود:
  - `suggest` → هیچ نوشتنی خودکار نیست، همه `actionInteractive`
  - `confirm` → نوشتن حساس تایید می‌خواهد
  - `auto` → نوشتن غیرحساس بدون تایید
- بعد از این تسک، **تنها راه نوشتن ایجنت `<tool_call>` است**.

**معیار پذیرش:** `rg 'ChatActionParser' lib/features/assistant` نشان دهد شیت دیگر برای اجرا از آن استفاده نمی‌کند. هر سه حالت `ai_agent_mode` دستی تست شوند.

**کامیت:** `refactor(assistant): single write path through tool calls and policy gate`

---

### T26 · تولید خودکار ابزار از رجیستری فرمان‌ها

**فایل‌ها:** `lib/core/domain/commands/ritmo_command.dart`، `commands_registry.dart`، `param_spec.dart`، `catalog/kernel_command_tool.dart`، `catalog/agent_tools_initializer.dart`

**این مهم‌ترین تسک ساختاری کل کار است.** هدف: دست از نوشتن دستی ابزار نوشتن بردار تا کاتالوگ ابزار هرگز از رجیستری فرمان واگرا نشود.

**کار:**
1. به `RitmoCommand` این فیلدها را اضافه کن:
   ```dart
   bool get exposeToAgent => false;
   String? get agentToolName => null;        // پیش‌فرض از id ساخته می‌شود
   String? get agentDescriptionFa => null;
   bool get isSensitive => false;
   ```
2. یک `ToolParameter.fromParamSpec(ParamSpec spec)` بنویس که `ParamSpec` را به قرارداد `T17` تبدیل کند (نوع، الزامی بودن، بازه، enum، توضیح فارسی).
3. تولیدکننده را بنویس:
   ```dart
   void registerCommandBackedTools(AgentToolRegistry reg) {
     for (final cmd in RitmoCommandBus.instance.allCommands) {
       if (!cmd.exposeToAgent) continue;
       reg.register(KernelCommandTool(
         commandId: cmd.id,
         name: cmd.agentToolName ?? _snakeFromCommandId(cmd.id), // routine.create → create_routine
         titleFa: cmd.humanTitle,
         descriptionFa: cmd.agentDescriptionFa ?? cmd.humanTitle,
         parameters: cmd.paramSpecs.map(ToolParameter.fromParamSpec).toList(),
         policy: cmd.isSensitive
             ? ToolPolicy.actionInteractive
             : ToolPolicy.actionDirect,
       ));
     }
   }
   ```
4. در `initializeAllAgentTools()` اول `registerCommandBackedTools` را صدا بزن، بعد ابزارهای دست‌نویس **فقط خواندنی/تحلیلی** را.
5. اسکوپ پرسونا را از `PersonaGate` بگیر: چون `PersonaGate` قبلاً `commandIds` مجاز هر پرسونا را می‌داند، برای ابزارهای فرمان‌محور **نقشه‌ی دستی لازم نیست**. جدول دستی `requirements` را فقط برای ابزارهای خواندنی نگه دار.
6. `allowedToolNames` را از fail-open به **fail-closed** تغییر بده: پرسونای ثبت‌نشده باید فقط ابزارهای خواندنی عمومی بگیرد، نه همه‌ی ابزارها.

**معیار پذیرش:** تست `T16` بعد از این تغییر هم پاس شود. تست جدید: هر فرمان با `exposeToAgent: true` باید یک ابزار متناظر داشته باشد.

**کامیت:** `feat(agent): generate write tools from the command registry`

---

### T27 · حذف هر ابزاری که SQL خام می‌نویسد

**فایل‌ها:** `catalog/study_worship_agent_tools.dart` و هر فایل دیگر کاتالوگ + `ss_ai_coach_sheet.dart`

**مشکل فعلی — نمونه‌ی شاخص:** `CreateWorshipPracticeTool` مستقیم `db.insert('worship_practices', {...})` می‌زند. یعنی بدون CommandBus، بدون `PersonaGate`، بدون audit، بدون undo، بدون `DayAgendaService.instance.invalidateAll()` و **بدون زمان‌بندی نوتیفیکیشن** — با اینکه `reminderEnabled: 1` ست می‌شود. پس دستیار می‌گوید «ثبت شد» ولی ممکن است در تقویم نیاید و یادآوری هم نفرستد. ضمناً `reminderTimes: '["$reminderTime"]'` ساخت JSON با string interpolation است.

**کار:**
1. با ripgrep همه‌ی `db.insert(`، `db.update(`، `db.delete(`، `db.rawInsert(`، `db.rawUpdate(` را در `lib/core/ai/` پیدا کن.
2. برای هرکدام: اگر فرمان متناظر در `commands_registry` هست، ابزار دست‌نویس را **حذف** کن (با `T26` خودکار تولید می‌شود). اگر نیست، **اول فرمان را بساز** (با diff، معکوس، و پارام‌اسپک) بعد ابزار را حذف کن.
3. مطمئن شو مسیر فرمان `invalidateAll()` و `RitmoEvents.notifyRoutineChanged()` و زمان‌بندی نوتیفیکیشن را انجام می‌دهد.
4. `ss_ai_coach_sheet.dart` را بررسی کن: اگر `AIGateway` را مستقیم صدا می‌زند و ابزار/گیت ندارد، آن را به `AssistantSheet` با پرسونای ورزش مهاجرت بده و فایل را حذف کن.
5. هیچ‌جا JSON را با interpolation نساز؛ از `jsonEncode` استفاده کن.

**معیار پذیرش:** `rg 'db\.(insert|update|delete|rawInsert|rawUpdate)' lib/core/ai/` خروجی خالی بدهد.

**کامیت:** `refactor(agent): route every agent write through the command bus`

---

### T28 · Undo یکپارچه روی `AgentJournal`

**فایل‌ها:** `agent_journal.dart`، `unified_assistant_sheet.dart`، `streaming_chat_service.dart`، `ui/agent_journal_screen.dart`

**مشکل فعلی:** دکمه‌ی «لغو اقدام اخیر» فقط جدول `assistant_plans` را می‌خواند، پس نوشته‌های ابزاری (که در `agent_tool_journal` هستند) را هرگز نمی‌بیند. `AgentJournal.undoLast` از UI اصلی صدا زده نمی‌شود.

**کار:**
1. `AgentJournal` را تنها منبع حقیقت کن. متدها:
   ```dart
   Future<int> undoableCount({String? sessionId});
   Future<UndoResult> undoLast({String? sessionId});
   Future<UndoResult> undoEntry(String entryId);
   ```
2. دکمه‌ی هدر شیت باید `undoableCount` را بخواند (نه `assistant_plans`) و `undoLast` را صدا بزند.
3. هر ابزار نوشتن باید `isUndoable: true` و شناسه‌ی `planId`/`auditId` برگرداند — با `T26` خودکار می‌شود چون `RitmoCommandBus` معکوس فرمان را دارد.
4. **دکمه‌ی inline بازگردانی:** در پیام موفقیت هر نوشتن، یک دکمه‌ی «بازگردانی این اقدام» با `entryId` بگذار، نه فقط یک دکمه‌ی کلی در هدر.
5. `assistant_plans` را کامل بازنشسته کن. اگر جدول وجود دارد، migration پاکسازی بنویس؛ اگر وجود ندارد، هر ارجاعی به آن را حذف کن.
6. اگر ورودی ژورنال `undoKind == null` بود، در UI دکمه‌ی بازگردانی را **نشان نده** و در تولتیپ بنویس چرا.

**معیار پذیرش:** تست `T50`. دستی: با ایجنت یک روتین بساز، دکمه‌ی بازگردانی را بزن، روتین و occurrenceهایش باید حذف شوند.

**کامیت:** `feat(agent): unified undo backed by the agent journal`

---

**پایان فاز E:** `flutter analyze && flutter test`.

---

# فاز F — تعامل واقعی و تأیید حالت

### T29 · یک broker برای تایید و پرسش

**فایل:** `lib/core/ai/agent/agent_interaction_broker.dart` (تغییر نام/تعمیم `AgentConfirmationBroker`)

**کار:**
```dart
sealed class AgentInteractionRequest {
  final String id;
}

class ConfirmWriteRequest extends AgentInteractionRequest {
  final String titleFa;
  final PlanPreview preview;      // diff واقعی از RitmoCommandBus.preview
  final bool needsBiometric;
}

class AskUserRequest extends AgentInteractionRequest {
  final String questionFa;
  final List<String>? choicesFa;  // چیپ آماده، بهتر از تایپ آزاد
  final bool allowFreeText;
}

sealed class AgentInteractionResponse {}
class Approved extends AgentInteractionResponse {}
class Rejected extends AgentInteractionResponse { final String? reasonFa; }
class Answered extends AgentInteractionResponse { final String answer; }
class TimedOut extends AgentInteractionResponse {}
class Cancelled extends AgentInteractionResponse {}
```
- `AgentConfirmationHost` را به `AgentInteractionHost` تعمیم بده تا هر دو نوع درخواست را رندر کند.
- `cancelAll()` باید همه‌ی درخواست‌های معلق را با `Cancelled` تمام کند.

**کامیت:** `refactor(agent): generalize confirmation broker into interaction broker`

---

### T30 · `AskUserTool` که واقعاً حلقه را متوقف می‌کند

**فایل:** `catalog/meta_agent_tools.dart`

**مشکل فعلی:** `AskUserTool` با policy `readOnly` فقط `{'awaitingUserAnswer': true}` برمی‌گرداند و به مدل می‌گوید «بایست». هیچ توقف واقعی، هیچ UI و هیچ جمع‌آوری پاسخی وجود ندارد — فقط یک قرارداد پرامپتی.

**کار:**
- policy را به `actionInteractive` تغییر بده.
- در `execute` واقعاً `await broker.ask(AskUserRequest(...))` بزن.
- پاسخ کاربر را به‌عنوان `AgentToolResult.success` با `data: {'answer': ...}` به مدل برگردان تا حلقه با اطلاعات جدید ادامه دهد.
- روی `TimedOut`/`Cancelled`، نتیجه‌ی شکست با پیام فارسی روشن برگردان.
- برای پرسش‌های بسته (مثلاً «صبح یا شب؟») `choicesFa` بده تا کاربر فقط یک چیپ بزند.

**معیار پذیرش:** تست با مدل جعلی: ایجنت `ask_user` صدا می‌زند، حلقه معلق می‌شود، پاسخ تزریق می‌شود، حلقه با آن پاسخ ادامه می‌دهد.

**کامیت:** `feat(agent): ask_user suspends the loop and collects a real answer`

---

### T31 · تأیید خودکار و اجباری حالت پس از نوشتن

**فایل جدید:** `lib/core/ai/agent/auto_verifier.dart`
**فایل تغییریافته:** `agent_loop_runner.dart`

**مشکل فعلی:** `VerifyStateTool` بهترین ابزار ضدتوهم پروژه است ولی هیچ‌کس مجبور به استفاده‌اش نیست و در دستورات حلقه هم برجسته نشده. نتیجه: کلاس باگ «ثبت شد ولی در تقویم نیست».

**کار:** بررسی را از توصیه‌ی پرامپتی به **قانون کد** تبدیل کن:
```dart
if (tool.policy != ToolPolicy.readOnly && result.isSuccess) {
  final check = await AutoVerifier.verifyAfter(tool, coercedArgs, result);
  transcript.addToolResult(check.toModelTextFa());
  if (!check.visibleToUser) {
    yield AgentWarningEvent(messageFa: check.warningFa!);
  }
}
```
- `AutoVerifier` باید از همان بررسی‌های موجود `VerifyStateTool` استفاده کند: `routine_in_day`، `routine_exists`، `setting_value`، `agenda_count`.
- برای هر نوع نوشتن، بررسی متناظر را نگاشت کن. اگر نگاشت نبود، حداقل «آیا رکورد با شناسه‌ی برگشتی خوانده می‌شود؟» را چک کن.
- از `scheduleCount` و `upcomingOccurrences` استفاده کن تا حالت «ساخته شد ولی هیچ occurrence ندارد» را بگیری و به کاربر هشدار فارسی بدهی.
- این بررسی **از بودجه‌ی ابزار مدل کم نمی‌شود** چون مدل صدایش نزده.

**معیار پذیرش:** تست: یک نوشتن که رکورد می‌سازد ولی occurrence نمی‌سازد، باید `AgentWarningEvent` تولید کند.

**کامیت:** `feat(agent): mandatory post-write state verification`

---

### T32 · `NavigateToAppScreenTool` که واقعاً جابه‌جا می‌کند

**فایل‌ها:** `catalog/system_agent_tools.dart`، `unified_assistant_sheet.dart`، `streaming_chat_service.dart`

**مشکل فعلی:** ابزار `'autoNavigated': false` برمی‌گرداند و خودش اقرار می‌کند مصرف‌کننده‌ای ندارد. ناسازگاری هم دارد: `policy = readOnly` ولی `requirement = command('app.openPage')`.

**کار:**
- policy را به `actionDirect` تغییر بده (جابه‌جایی یک اثر جانبی است، نه خواندن).
- یک رویداد `AgentNavigationRequestedEvent(route, argsFa)` منتشر کن.
- در **هر دو** مصرف‌کننده آن را هندل کن و `Navigator.pushNamed` بزن. مسیر مجاز را با یک allowlist محدود کن (deny-by-default، دقیقاً مثل الگوی خوب `UpdateAppPreferenceTool`).
- `'autoNavigated': true` را فقط وقتی برگردان که واقعاً جابه‌جایی رخ داده.

**معیار پذیرش:** «ببر منو به صفحه‌ی خواب» باید واقعاً صفحه را باز کند. مسیر خارج از allowlist باید با پیام فارسی رد شود.

**کامیت:** `feat(agent): real in-app navigation with route allowlist`

---

**پایان فاز F:** `flutter analyze && flutter test`.

---

# فاز G — قابلیت‌های جدید و سخت‌سازی

### T33 · ابزار `simulate_plan` (حالت «فقط نشانم بده»)

**فایل:** `catalog/planning_agent_tools.dart`

**کار:** ابزار خواندنی `simulate_plan` بساز که یک `CommandPlan` بگیرد، `RitmoCommandBus.instance.preview(plan, personaId: ...)` را اجرا کند و **diff و blockerها و هشدارها** را به مدل برگرداند، بدون هیچ نوشتنی.

این ابزار کیفیت پاسخ را جهش می‌دهد: مدل می‌تواند بگوید «این با روتین ۷ صبح تعارض دارد، پیشنهاد بهتری دارم» — یعنی از «مجری» به «مشاور» ارتقا پیدا می‌کند.

در دستورات حلقه اضافه کن: برای نوشتن‌های چندمرحله‌ای یا مبهم، **اول** `simulate_plan`، بعد اجرا.

**کامیت:** `feat(agent): dry-run plan simulation tool`

---

### T34 · برنامه‌ی چندمرحله‌ای با یک تایید

**فایل‌ها:** `catalog/kernel_command_tool.dart`، `agent_policy_gate.dart`، `AgentInteractionHost`

**کار:** ابزار `apply_plan` بساز که چند `PlanStep` را در **یک** `CommandPlan` بگیرد. مزیت سه‌گانه:
- کاربر **یک** کارت تایید با diff کامل می‌بیند، نه سه کارت پشت سر هم
- سقف نوشتن از «۳ فراخوانی» به «۱ برنامه» تبدیل می‌شود
- undo اتمی می‌شود (کل برنامه با هم برمی‌گردد)

**معیار پذیرش:** «سه‌شنبه‌ها ورزش بذار، یادآوری‌ش رو ۱۸ کن و هدف ماهانه بساز» باید یک کارت تایید و یک ورودی ژورنال بسازد.

**کامیت:** `feat(agent): multi-step plan with single confirmation and atomic undo`

---

### T35 · مرور شبانه‌ی فعال

**فایل‌ها:** `agent_nightly_review.dart`، `lib/core/background/background_worker.dart`، `ai_briefing_service.dart`، `commands_registry.dart`

**کار:**
- فرمان `agent.reviewDay` را بساز و در `background_worker` شب (مثلاً ۲۳:۳۰) زمان‌بندی کن.
- خروجی باید یک کارت آماده برای صبح باشد با پیشنهاد **قابل تایید**، مثل: «دیروز ۳ روتین جا ماند، هر سه بعد از ساعت ۲۲ بودند — جابه‌جا کنم؟» + دکمه‌ی تایید.
- هرگز شب چیزی را خودکار **ننویس**؛ فقط پیشنهاد بساز. نوشتن فقط با تایید صبح.
- نتیجه را از `ai_briefing_service` به بخش بریفینگ صفحه‌ی دستیار وصل کن (`assistant_briefing_section.dart`).

**کامیت:** `feat(agent): proactive nightly review with morning approval card`

---

### T36 · تحویل بین پرسوناها به‌عنوان ابزار

**فایل‌ها:** `catalog/meta_agent_tools.dart`، `unified_assistant_sheet.dart`

**کار:** فرمان `assistant.handoff` از قبل هست. ابزار `handoff_to_persona` بساز که `targetPersonaId` و یک `summaryFa` از کانتکست بگیرد. در شیت، `handoffTo` را طوری تغییر بده که خلاصه را به پرسونای مقصد پاس بدهد (به‌جای پیام ثابت فعلی «سلام، از دستیار … منتقل شدم»).

**معیار پذیرش:** دستیار خواب برای سؤال تمرینی، با کانتکست به دستیار ورزش تحویل بدهد و دستیار مقصد سؤال را بداند.

**کامیت:** `feat(agent): context-preserving persona handoff tool`

---

### T37 · حافظه به‌عنوان شهروند درجه‌یک

**فایل‌ها:** `catalog/memory_agent_tools.dart`، `memory/ai_memory_service.dart`

**کار:**
- `remember_fact` و `recall_facts` را از قرارداد متنی `<memory_ops>` به ابزار واقعی با اسکیمای `T17` تبدیل کن.
- `remember_fact` را `actionInteractive` کن: کاربر باید ببیند چه چیزی درباره‌اش ذخیره می‌شود. برای یک اپ سلامت این الزام اعتماد است، نه لوکس.
- یک صفحه‌ی مرور/حذف حافظه بساز (یا به تنظیمات موجود اضافه کن).
- بعد از این، پردازش متنی `<memory_ops>` را حذف کن تا دو مسیر موازی نداشته باشیم.

**کامیت:** `feat(agent): memory as first-class confirmed tools`

---

### T38 · کش نتیجه‌ی ابزار بین نوبتی

**فایل‌ها:** `ai_cache_manager.dart`، `agent_loop_runner.dart`، `settings_service.dart`

**کار:** نتایج ابزارهای `readOnly` را با TTL کوتاه (۶۰ ثانیه) کش کن، با کلید `toolName + normalizedArgs + dataRevision`. `dataRevision` را از `SettingsService` revision و رویدادهای `RitmoEvents` باطل کن. کش باید بین **نوبت‌های** یک گفتگو هم کار کند، نه فقط داخل یک ران.

**معیار پذیرش:** تست: دو نوبت پشت‌سرهم که همان خواندن را لازم دارند، فقط یک بار به DB بزنند؛ بعد از یک نوشتن، کش باطل شود.

**کامیت:** `perf(agent): cross-turn read-only tool result cache with revision invalidation`

---

### T39 · تلمتری هر ابزار

**فایل‌ها:** `agent_journal.dart`، `ui/agent_journal_screen.dart`

**کار:** روی `agent_tool_journal` که از قبل هست، این معیارها را محاسبه و در صفحه‌ی ژورنال نشان بده: نرخ موفقیت، میانه‌ی زمان اجرا، نرخ رد تایید توسط کاربر، و **نرخ آرگومان نامعتبر**.

آخری مهم‌ترین است: ابزاری که بیشترین آرگومان نامعتبر را می‌گیرد، `descriptionFa` بدی دارد و باید بازنویسی شود. این حلقه‌ی بهبود، کیفیت ایجنت را ماه‌به‌ماه بالا می‌برد.

**کامیت:** `feat(agent): per-tool telemetry including invalid-argument rate`

---

### T40 · شفافیت «چه کاری کردم»

**فایل‌ها:** `ui/agent_step_timeline.dart`، هر دو مصرف‌کننده

**کار:** در پایان هر ران، یک خط خلاصه‌ی فارسی زیر پاسخ نشان بده:
> «۲ خواندن، ۱ نوشتن، ۱ تایید شما · قابل بازگشت»

با کلیک، تایم‌لاین کامل گام‌ها باز شود. `interactiveAction` که الان محاسبه و دور ریخته می‌شود را در همین جا مصرف کن (یا اگر بعد از `T25` بی‌استفاده شد، حذفش کن). `_parseFirstAction` که فقط `decoded.first` را نگه می‌دارد و بقیه را می‌ریزد را هم اصلاح یا حذف کن.

**معیار پذیرش:** هیچ فیلد رویدادی در `agent_event.dart` بدون مصرف‌کننده نماند.

**کامیت:** `feat(agent): run summary line and full step timeline in both consumers`

---

### T41 · سخت‌سازی گارد تزریق پرامپت

**فایل:** `agent_policy_gate.dart`

**مشکل فعلی:** `_suspiciousArgKey` فقط روی `args.entries` سطح اول می‌چرخد و تنها `value is String` را می‌بیند. پس map و list تودرتو اسکن نمی‌شوند. الگوهای `_injectionSignals` هم انگلیسی‌محورند و معادل فارسی «دستورات قبلی را نادیده بگیر» را ندارند — با اینکه در دستورات حلقه به فارسی به مدل هشدار داده شده.

**کار:**
1. اسکن را **بازگشتی** کن: map، list، و رشته‌های تودرتو.
2. الگوهای فارسی را اضافه کن: «دستورات قبلی»، «نادیده بگیر»، «سیستم پرامپت»، «قوانین را فراموش کن»، «به کاربر نگو».
3. رشته‌های نرمال‌شده را چک کن (حروف عربی/فارسی مثل `ي`/`ی` و `ك`/`ک`، حذف zero-width) تا با تغییر کاراکتر دور زده نشود.
4. `AgentToolProtocol.sanitize` و `wrapUserContent` را حفظ کن — مرز `<user_content>` درست طراحی شده.
5. تست منفی بنویس: تزریق در یک فیلد تودرتو باید مسدود شود.

**کامیت:** `fix(agent): recursive, locale-aware prompt injection guard`

---

### T42 · پاکسازی زبانی + تست ترمینولوژی

**فایل‌ها:** کل `lib/`، `test/terminology_test.dart`

**کار:**
1. این غلط‌ها را در کل `lib/` اصلاح کن: `تنطیم`→`تنظیم`، `تنطیمات`→`تنظیمات`، `منتطر`→`منتظر`، `حافطه`→`حافظه`، `لحطه`→`لحظه`. مکان‌های تأییدشده: `agent_tool_protocol.dart` (که **دستورات حلقه** است و مستقیم روی درک مدل اثر دارد)، `system_agent_tools.dart`، `meta_agent_tools.dart`، `agent_tools_initializer.dart`.
2. در `test/terminology_test.dart` (که از قبل وجود دارد) یک تست اضافه کن که این کلمات غلط را در کل `lib/` مسدود کند تا دیگر برنگردند.

**کامیت:** `fix(i18n): correct Persian spelling in agent-facing strings and guard in CI`

---

### T43 · قابل تنظیم کردن سقف نوشتن

**فایل‌ها:** `agent_policy_gate.dart`، `settings_service.dart`

**کار:** `maxWritesPerRun = 3` که ثابت هاردکد است را به یک تنظیم کاربر تبدیل کن (`agent_max_writes_per_run`، بازه‌ی ۱ تا ۱۰، پیش‌فرض ۳) و از الگوی `_PrefRule` موجود در `UpdateAppPreferenceTool` استفاده کن. پیام رد را به‌جای «شکست ابزار» به یک پیام روشن فارسی تبدیل کن که به مدل بگوید سقف رسیده و باید خلاصه کند و از کاربر اجازه بگیرد.

**کامیت:** `feat(agent): user-configurable write budget with clear denial message`

---

### T44 · پاکسازی کوئری‌های ابزارها

**فایل‌ها:** `catalog/study_worship_agent_tools.dart`، `catalog/*`، `VerifyStateTool`

**کار:**
1. `GetStudyProgressSummaryTool` که `SELECT *` روی `konkur_study_sessions` با `LIMIT 20` می‌زند و ردیف کامل را در پرامپت می‌ریزد: فقط ستون‌های لازم را select کن و یک خروجی **تجمیعی** بده (جمع دقیقه، تعداد جلسه، روند هفتگی)، نه ردیف خام.
2. در `VerifyStateTool` کاراکترهای `%` و `_` را در ورودی `LIKE` escape کن.
3. ناهمگونی نام ستون (`routine_schedules.routineId` در برابر `routine_occurrences.routine_id`) را بررسی کن: اگر schema واقعاً ناهمگون است، در `docs/DB_TECH_DEBT.md` ثبت کن و کوئری را با نام درست بنویس. اگر یکی از دو نام غلط است، همان کوئری را درست کن.
4. با ripgrep بقیه‌ی `SELECT *` را در `lib/core/ai/` پیدا کن و ستون‌محور کن.

**کامیت:** `perf(agent): column-scoped aggregate queries and safe LIKE escaping`

---

**پایان فاز G:** `flutter analyze && flutter test`.

---

# فاز H — تست‌های نگهبان

> در حال حاضر در `test/` **هیچ تستی برای هسته‌ی ایجنت وجود ندارد**. این فاز اختیاری نیست.

همه‌ی فایل‌ها زیر `test/agent/` (به‌جز `T16` که در `test/architecture/` است).

### T45 · `test/agent/agent_tool_call_parser_test.dart`
پوشش: تگ `<tool_call>` تک و چندگانه · code fence · JSON لخت · `{"tool_calls":[...]}` · `{"function":{"name","arguments"}}` · arguments به‌صورت رشته · JSON ناقص/خراب · دو فراخوانی تکراری (dedupe با `stableArgs`) · `hasOpenTag` و `tailLength`.

### T46 · `test/agent/agent_tool_validator_test.dart`
پوشش: پارامتر الزامی غایب · نوع غلط · بازه‌ی خارج از `min`/`max` · مقدار خارج از `allowedValues` · نقض `pattern` ساعت · **ارقام فارسی و عربی** (`۱۴`، `١٤`) · پارامتر ناشناس · `defaultValue`. تأیید کن پیام خطا فارسی و آموزنده است و نام پارامتر را دارد.

### T47 · `test/agent/agent_loop_fake_model_test.dart`
با یک مدل جعلی قابل اسکریپت: مسیر موفق خواندن→نوشتن→verify · تایید کاربر · رد کاربر · timeout تایید · سقف `maxTurns` · سقف `maxToolCalls` · سقف نوشتن با شکست‌های متوالی (`T08`) · حفظ سؤال کاربر در هرس ترنسکریپت (`T09`) · هر دو wire format (`T23`).

### T48 · `test/agent/kernel_command_tool_test.dart`
پوشش: آرگومان بد → پیام فارسی، نه crash · تشخیص تاریخ جلالی (`y >= 1200 && y < 1700`) · نرمال‌سازی ساعت · فراخوانی `invalidateAll()` و `notifyRoutineChanged()` · `isUndoable: true`.

### T49 · `test/agent/agent_policy_gate_test.dart`
پوشش: حالت‌های `suggest`/`confirm`/`auto` · deny-by-default تنظیمات (`_allowedPrefs` و بلوک پیشوندی `module_*`/`ai_*`/`consent`/`gender`) · گارد تزریق بازگشتی و فارسی (`T41`) · allowlist مسیر navigation (`T32`) · fail-closed بودن اسکوپ (`T26`).

### T50 · `test/agent/agent_journal_undo_test.dart`
پوشش: بنویس → `undoableCount` باید ۱ باشد → `undoLast` → حالت اولیه برگردد · undo برنامه‌ی چندمرحله‌ای به‌صورت اتمی (`T34`) · ورودی با `undoKind == null` نباید قابل بازگشت اعلام شود.

**تست رگرسیون سرتاسری (اجباری، در همان `T50`):**
> «ایجنت یک روتین می‌سازد» → روتین باید در `DayAgendaService.agendaForRange` برای بازه‌ی درست ظاهر شود.

این همان کلاس باگی است که کل این کار برای بستنش انجام شده.

**کامیت‌ها:** هر فایل تست کامیت خودش را دارد: `test(agent): <scope>`

---

# بخش ۳ — تعریف «تمام شد» (Definition of Done)

کار تمام است **فقط وقتی** همه‌ی این‌ها درست باشند:

- [ ] همه‌ی ردیف‌های `T01`–`T50` در PROGRESS وضعیت `DONE` یا `SKIPPED` یا `BLOCKED` با توضیح دارند. هیچ `TODO` یا `DOING` باقی نمانده.
- [ ] `flutter analyze` هیچ error و هیچ warning ندهد.
- [ ] `flutter test` کامل پاس شود.
- [ ] `rg 'AgentIntentPrefetcher' lib/` خالی است.
- [ ] `rg 'db\.(insert|update|delete|rawInsert|rawUpdate)' lib/core/ai/` خالی است.
- [ ] `rg 'catch \(_\) \{\}' lib/core/ai lib/features/assistant` خالی است.
- [ ] `rg 'runAgent\(' lib/` هیچ فراخوانی بدون `personaId` ندارد.
- [ ] `rg 'تنطیم|منتطر|حافطه|لحطه' lib/` خالی است.
- [ ] هیچ `TODO` یا `FIXME` جدیدی اضافه نشده.
- [ ] هیچ فیلدی در `agent_event.dart` بدون مصرف‌کننده نمانده.
- [ ] `AgentInteractionHost` در **هر دو** مصرف‌کننده نصب است.
- [ ] دو مسیر نوشتن موازی وجود ندارد؛ تنها راه نوشتن `<tool_call>` است.
- [ ] Undo تنها یک منبع حقیقت دارد: `AgentJournal`.

**گزارش پایانی (حداکثر ۲۰ خط، در چت — نه در یک فایل جدید):**
1. تعداد `DONE` / `SKIPPED` / `BLOCKED`
2. فهرست `BLOCKED`ها با یک خط دلیل هرکدام
3. هر جایی که واقعیت کد با این دستورکار اختلاف داشت
4. سه ریسکی که برای مرحله‌ی بعد باقی مانده

---

# بخش ۴ — یادآوری‌های ضدلغزش

- هر بار که خواستی «یک نقشه‌ی بهتر» پیشنهاد بدهی: **نده.** اجرا کن. اگر چیزی واقعاً غلط بود، `BLOCKED` بزن و در گزارش پایانی بگو.
- هر بار که خواستی چند تسک را «برای سرعت» با هم کامیت کنی: **نکن.** یک تسک، یک کامیت، یک ردیف PROGRESS.
- هر بار که وسوسه شدی تستی را «بعداً» بنویسی: تسک بدون تست `DONE` نیست.
- هر بار که خواستی فایل قدیمی را `@deprecated` کنی: **حذفش کن.** کد مرده در این پروژه دقیقاً همان چیزی است که این کار برای پاک کردنش انجام می‌شود.
- اگر نشست قطع شد: PROGRESS را بخوان، اولین `TODO`/`DOING` را بردار، ادامه بده. از حافظه‌ات حدس نزن.
