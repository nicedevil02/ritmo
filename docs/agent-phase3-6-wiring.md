# سند اتصال و تأیید فاز ۳ تا ۶ ایجنت ریتمو

این سند فقط کارهای باقی‌ماندهٔ اتصال (wiring) و روش تأیید روی دستگاه را توضیح
می‌دهد. منطق همهٔ فازها در کد اعمال شده است؛ موارد زیر تنها نقاطی هستند که
به تصمیم طراحی UI یا اجرای دستگاه وابسته‌اند.

## ۱. وضعیت واقعی کد

| فاز | وضعیت | پرونده‌های کلیدی |
| --- | --- | --- |
| ۳ — دروازهٔ سیاست، تایید، ژورنال | پیاده شده | `agent_policy_gate.dart`، `agent_journal.dart`، `ui/agent_confirmation_card.dart`، `ui/agent_step_timeline.dart`، `ui/agent_journal_screen.dart` |
| ۴ — پارسر تاریخ فارسی + روتر نیت توکن‌محور + کش خواندن | پیاده شده | `intent/ritmo_date_parser.dart`، `intent/agent_intent_router.dart`، `agent_loop_runner.dart` |
| ۵ — محدودهٔ پرسونا، ابزار حافطه، مرور شبانه | پیاده شده | `agent_tool_scope.dart`، `catalog/memory_agent_tools.dart`، `agent_nightly_review.dart` |
| ۶ — تست و تأیید | تست پارسر نوشته شد، بقیه نیاز به دستگاه دارد | `test/ritmo_date_parser_test.dart` |

تعداد ابزار ثبت‌شده: **۲۳** (۲۱ قبلی + `remember_fact` + `recall_facts`).

## ۲. اتصال پرسونا به حلقه (یک خط)

`AgentLoopRunner.runAgent` حالا پارامتر اختیاری `personaId` دارد که پیش‌فرضش `global`
است. در `streaming_chat_service.dart` جایی که `runAgent(...)` صدا می‌شود، شناسهٔ پرسونای
فعال را پاس بده:

```dart
AgentLoopRunner.instance.runAgent(
  prompt: prompt,
  personaTitle: persona?.displayName,
  personaSystemPrompt: systemPrompt,
  personaId: persona?.id ?? 'global', // ← فاز ۵ · P5-1
  // ...
);
```

تا وقتی این خط اضافه نشود، رفتار دقیقا مانند قبل است (همهٔ ۲۳ ابزار باز)؛ پس
این تغییر شکننده نیست و فقط محدوده را فعال می‌کند.

رفتار محدوده:

- ابزار خواندنی وقتی مجاز است که دامنه‌اش در `persona.reads` باشد.
- ابزار نوشتنی وقتی مجاز است که فرمان معادلش در `persona.commandIds` باشد.
- ابزارهای زیرساختی (`verify_state`، `ask_user`، `remember_fact`، `recall_facts`) برای همه بازند.
- پرسونای ثبت‌نشده = fail-open (همه باز) با لاگ هشدار؛ عمدی، تا دستیار بی‌صدا فلج نشود.
- ابزار جدید باید در `AgentToolScope.requirements` هم ثبت شود؛ وگرنه فقط برای `global` باز می‌ماند.

## ۳. اتصال UI در `unified_assistant_sheet.dart`

۱. **کارت تایید** — بالای نوار ورودی پیام، بدون هیچ پارامتری:

```dart
const AgentConfirmationHost(),
```

این ویجت خودش به `AgentConfirmationBroker.instance` گوش می‌دهد و وقتی درخواست تاییدی
در جریان نباشد، چیزی رندر نمی‌کند. تا وقتی این اضافه نشود، ابزارهای
`actionInteractive` پس از ۳ دقیقه با تایم‌اوت رد می‌شوند (و این را صادقانه به کاربر
می‌گوید، نه اینکه ادعا کند انجام شد).

۲. **خط زمان گام‌ها** — در لیست پیام‌ها برای پیام در حال پردازش:

```dart
AgentStepTimeline(steps: _currentSteps, statusTextFa: _statusTextFa),
```

۳. **رویدادهای جدید** — در همان `switch`/`if` که رویدادهای ایجنت را مصرف می‌کند:
   `AgentTurnStartedEvent` (نمایش «نوبت n از m»)، `AgentAwaitingConfirmationEvent`،
   `AgentConfirmationResolvedEvent`. اگر مصرف نشوند مشکلی پیش نمی‌آید؛ فقط کاربر
   بازخورد کمتری می‌گیرد.

۴. **صفحهٔ ژورنال** — `AgentJournalScreen` ساخته شده ولی روت ندارد. یک مسیر در
   `ritmo_router.dart` (مثلا `/agent-journal`) یا دکمه در منوی دستیار کافی است. این صفحه
   امکان «بازگرداندن آخرین تغییر» را می‌دهد.

## ۴. اتصال مرور شبانه (P5-3)

`AgentNightlyReview.instance.run()` فقط می‌خواند: ابزاری که `policy != readOnly` باشد را
حتی اگر در فهرست بیاید رد می‌کند و هیچ نوتیفیکیشنی نمی‌فرستد. خروجی متن فارسی
است و اگر داده‌ای نباشد صریحا می‌گوید داده نبود.

در `background_worker.dart` درون تسک شبانه:

```dart
final review = await AgentNightlyReview.instance.run();
if (review.hasData) {
  // متن را به بریفینگ بده یا در دیتابیس بریفینگ ذخیره کن
}
```

توصیه: خروجی را مستقیم به مدل نده تا خودش متن بسازد؛ همین متن قطعی بی‌ادعا
برای کارت صبحگاهی کافی است.

## ۵. ابزارهای حافطه (P5-2)

- `remember_fact` پیش از نوشتن `isMemoryEnabled()` را چک می‌کند و پس از نوشتن با
  `retrieve` تأیید می‌گیرد؛ دلیلش این است که `AiMemoryService.applyOperations` خطاها را
  درون خودش فرو می‌دهد و هرگز استثنا نمی‌دهد. بدون این تأیید، دستیار می‌توانست
  بگوید «یادم موند» در حالی که چیزی ذخیره نشده بود.
- دامنهٔ `cycle` و `health` اجبارا `sensitive: true` می‌خورند؛ پس در گفتگوی دامنه‌های
  دیگر بازخوانی نمی‌شوند.
- `importance = 10` در سرویس حافطه معنای پین دارد (از فراموشی خودکار معاف)؛ در
  توضیح ابزار به مدل گفته شده که فقط با تاکید صریح کاربر از ۱۰ استفاده کند.
- پیشنهاد بعدی: در `ai_memory_service.dart` جملهٔ دستور `<memory_ops>` (تابع
  `memoryInstruction()`) را برای مسیر ایجنت حذف کن تا مدل دو راه موازی برای حافطه
  نداشته باشد (فعلا هر دو کار می‌کنند، ولی مسیر ابزار قابل تأیید است).

## ۶. دستور تأیید روی دستگاه

```bash
flutter test test/ritmo_date_parser_test.dart
flutter analyze
flutter run -d NE2211 --flavor bazaar --dart-define-from-file=env.json
adb logcat | grep -E "\[Agent\]|\[AgentIntent\]|\[AgentScope\]|\[AgentReview\]|\[MemoryTool\]|\[AgentKernelTool\]"
```

سناریوی آزمون:

۱. «برنامه پس‌فردا چیه؟» ← انتطار: `[AgentIntent] ... tools=get_day_agenda | date=<دو روز بعد>`
۲. «یادت باشه من صبح‌ها قبل از ۷ نمی‌تونم ورزش کنم» ← انتطار: `[MemoryTool] remember_fact -> ok | domain=...`
۳. در پیام بعدی: «چی از من یادت هست؟» ← انتطار: `[MemoryTool] recall_facts -> n/m`
۴. در دستیار خواب، درخواست ورزشی ← انتطار: `[Agent] scope denied | ... | persona=sleep`
   (فقط اگر خط بند ۲ اضافه شده باشد)
۵. «یه روتین ساعت ۷ صبح به اسم پیاده‌روی بساز» ← انتطار: `[Agent] gate create_new_routine`، سپس `[AgentKernelTool] create_new_routine (routine.create) -> ok`

## ۷. محدودیت‌های اعلام‌شده

- `flutter analyze` و `flutter test` در محیطی که این تغیییرات نوشته شده اجرا نشده‌اند.
- تست قبلی و نامربوط `test/execution_kernel_test.dart` در HEAD از قبل شکسته بود
  (`MockDatabase.isOpen` → `type 'Null' is not a subtype of type 'bool'`).
- تست واحد برای `AgentToolScope` نوشته نشد، چون به راه‌اندازی `PersonaRegistry` و
  `RitmoCommandBus` نیاز دارد و بدون اجرای واقعی تست، نوشتنش ریسک تست قرمز دارد.
- P4-3 (یکپارچه‌سازی `ConversationRAG` و `ConversationContextBuilder` با روتر نیت) انجام نشده.
