# پیشرفت جامع رفع پل وب چت‌جی‌پی‌تی و تحویل پاسخ به دستیار هوشمند (A-01 تا A-68)

## جدول وضعیت فازها و شناسه‌ها (RITMO_ASSISTANT_BRIDGE_FIX_PROMPT)

| شناسه | فاز | عنوان | وضعیت | شرح و دلیل فنی |
|---|:---:|---|:---:|---|
| A-01 | ۰ | بافر ردیابی رویدادهای پل (`BridgeTraceLog`) | انجام شد | بافر حلقوی ۳۰۰ تایی بدون ذخیرهٔ داده‌های متنی کاربر و با امکان خروجی متنی پیاده و تست شد. |
| A-02 | ۰ | مدل نوع‌دار رویداد پل (`WebBridgeEvent`) | انجام شد | کلاس‌های `sealed WebBridgeEvent` با تمام زیرکلاس‌های نوع‌دار و متد امن `parse` پیاده شد. |
| A-03 | ۰ | انباشتگر پاسخ (`BridgeResponseAccumulator`) | انجام شد | تک‌مالک تجمع متن پاسخ با پوشش ۶ حالت بازنویسی، پیشوند، عقب‌گرد و تست‌های کامل پیاده شد. |
| A-04 | ۰ | شمارش منبع و داوری اولیه (`BridgeSource`) | انجام شد | شمارش `BridgeSource` و نگاشت منبع رویدادها تعریف و در مدل‌ها تثبیت شد. |
| A-05 | ۰ | ارتقای نسخهٔ پل به ۸ و تست نگهبان نسخه | انجام شد | مقدار `bridgeVersion` به ۸ ارتقا یافت و تست نگهبان هش پایدار اسکریپت نوشته شد. |
| A-06 | ۰ | حذف بلعیدن خطا در دامنهٔ پل و ایجنت | انجام شد | تمام `catch (_) {}` و `catch (e) {}`های بدون لاگ حذف و به `RitmoLog.warning`/`console.warn` تبدیل شدند. |
| A-07 | ۰ | تبدیل `debugPrint` در سرویس استریم چت | انجام شد | تمام `debugPrint`های `streaming_chat_service.dart` به `RitmoLog` تبدیل شدند. |
| A-08 | ۰ | یکسان‌سازی لاگر و منسوخ‌سازی `RitmoLog.warn` | انجام شد | `RitmoLog.warning` نام رسمی شد و `RitmoLog.warn` با `@Deprecated` نشانه‌گذاری گردید. |
| A-09 | ۱ | واچ‌داگ سرکوب در `AgentLoopRunner` | انجام شد | واچ‌داگ سرکوب بر پایهٔ طول متن (۶۰۰ کاراکتر) و زمان (۶ ثانیه) اضافه شد تا از گیر کردن رندر جلوگیری شود. |
| A-10 | ۱ | محرک هدفمند اسکنر `shouldScanForToolCalls` | انجام شد | متد پیش‌بررسی سریع نشانه‌های واقعی ابزار اضافه شد تا از اجرای بیهودهٔ ریجکس‌های سنگین جلوگیری شود. |
| A-11 | ۱ | تور ایمنی فلاش نهایی در `AgentLoopRunner` | انجام شد | قبل از گسیل `AgentCompletedEvent` فلاش نهایی انجام می‌شود تا هیچ متنی ناگسیخته باقی نماند. |
| A-12 | ۱ | پشتیبانی از نشانگر بازنویسی `rewriteSentinel` در منیجر | انجام شد | نشانگر بازنویسی `\u0000RITMO_REWRITE\u0000` در پل و حلقه برای سناریوهای بازنویسی غیرپیشوندی پیاده شد. |
| A-13 | ۱ | گارد ارسال همزمان در `sendPrompt` | انجام شد | ارسال همزمان ریجکت شده و پیام خطای فارسی واضح گسیل می‌شود تا از race condition جلوگیری شود. |
| A-14 | ۱ | قفل منبع و نادیده‌گیری `done` غیرقفل‌شده | انجام شد | اولین چانک منبع (SSE یا DOM) را قفل می‌کند و رویدادهای `done` منبع دیگر نادیده گرفته می‌شوند. |
| A-15 | ۱ | اصلاح تشخیص اتمام در `evaluateStreamCompletion` | انجام شد | وابستگی شکننده به دکمهٔ ارسال حذف و به انتقال وضعیت تاییدشده (`sawGeneratingSignal`) + مکث ۸۰۰ میلی‌ثانیه تبدیل شد. |
| A-16 | ۱ | عدم ارسال زودهنگام `done` در `__ritmo_resume` | انجام شد | ارسال زودهنگام done حذف و به ارسال چانک بازیابی‌شده + اتصال مجدد واچر تغییر یافت. |
| A-17 | ۱ | ماندگاری `__ritmo_active_req_id` و متن پایه در ریدایرکت | انجام شد | ذخیره و بازیابی `__ritmo_active_req_id` و `__ritmo_turn_baseline` در پنجره مرورگر پیاده شد. |
| A-18 | ۱ | نجات بافر پیش از سقط حلقهٔ بارگذاری ناوبری | انجام شد | سقف بارگذاری به ۶ افزایش یافت و قبل از خروج، محتوای دریافت‌شده نجات یافته و فلاش می‌شود. |
| A-19 | ۲ | مسیریابی رویدادهای ایجنت بدون فهرست سیاه در `StreamingChatService` | انجام شد | تبدیل تمام زیرکلاس‌های `AgentEvent` به `AgentStreamEvent` بدون بلعیده شدن هیچ رویدادی. |
| A-20 | ۲ | آزمون نگهبان جامعیت بازفروارد رویدادهای ایجنت | انجام شد | آزمون گارد برای بررسی تمام ۱۳ زیرکلاس `AgentEvent` در `test/core/ai/chat/agent_event_forwarding_test.dart` نوشته شد. |
| A-21 | ۲ | ماشین وضعیت مشترک `AgentStreamPresenter` در رابط کاربری | انجام شد | ساخت `AgentStreamPresenter` و اتصال آن به عنوان تک‌مرجع منطق نمایش در `unified_assistant_sheet` و `ai_chat_screen`. |
| A-22 | ۲ | تشخیص علت پاسخ خالی و تبدیل به خطای کاربرپسند فارسی | انجام شد | متد `describeEmptyResponseReason` با ارزیابی حالت‌های کلودفلر، نشست منقضی و واچ‌داگ اضافه شد. |
| A-23 | ۲ | نشانگر بصری وضعیت پل وب (`BridgeStatusChip`) در هدرها | انجام شد | ویجت `BridgeStatusChip` با قابلیت نمایش وضعیت و اقدام مناسب کلیک در هدر هر دو صفحه اضافه شد. |
| A-24 | ۲ | پیش‌نمایش شناور وب‌ویو هنگام گیر کردن یا کلودفلر | انجام شد | امکان باز کردن پیش‌نمایش مینیاتوری از روی `BridgeStatusChip` در هنگام دریافت یا چالش اضافه شد. |
| A-25 | ۲ | افزایش سقف برش طول پاسخ دستیار به ۳۲۰۰۰ کاراکتر | انجام شد | سقف پاسخ در `StreamingChatService` به ۳۲۰۰۰ کاراکتر با برش گرافیمی امن بر پایهٔ `characters` ارتقا یافت. |
| A-26 | ۲ | ترتیب ایمن لغو و بازنشانی وضعیت در `cancelCurrentStream` | انجام شد | توالی ۵ مرحله‌ای لغو (تایمرها -> دستور لغو JS -> ریست متغیرها -> بستن کنترلر -> بازگشت به ready) تثبیت شد. |
| A-27 | ۳ | به‌روزرسانی جدول `RITMO_SELECTORS` | انجام شد | گسترش سلکتورها بر پایه نقش و ویژگی‌های مدرن (جداشده با کاما، از خاص‌ترین به عمومی‌ترین) با حفظ سازگاری گذشته‌نگر. |
| A-28 | ۳ | خودآزمون سلکتور در زمان بوت | انجام شد | اجرای `runSelectorSelfTest` و ارسال رویداد `selector_health` در بوت همراه با لاگ هشدار در صورت نبود فیلد ورودی یا پیام دستیار. |
| A-29 | ۳ | شکاف لنگراندازی `data-ritmo-seen` | انجام شد | تعریف ثابت جامع `RITMO_ANCHORABLE` برای علامت‌گذاری تمام المان‌های پیام قبل از شروع استریم جدید. |
| A-30 | ۳ | اولویت با آخرین نوبت گفتگو، نه «دیده‌نشده» | انجام شد | بازنویسی `findLatestAssistantText` بر پایه تقدم شمارش نوبت و تقدم پیام دستیار پس از آخرین پیام کاربر. |
| A-31 | ۳ | پارسر SSE با پوشش قالب‌های پچ JSON | انجام شد | گسترش `parseSSELine` برای شناسایی عملیات‌های `patch`، `append`، `replace` در مسیر `parts` و نادیده‌گیری ایمن متادیتا و تفکر. |
| A-32 | ۳ | عدم جایگزینی نابینای `[DONE]` در صورت وجود متن بلندتر در انباشتگر | انجام شد | ادغام با انباشتگر (`_emitChunk` و `_accumulator`) و عدم جایگزینی متن انباشتگر با متن کوتاه‌تر در پایان تولید. |
| A-33 | ۳ | پاکسازی بلوک‌های تفکر، دکمه‌های کپی و زباله‌های رابط در `extractCleanText` | انجام شد | حذف المان‌های `RITMO_STRIP` بر روی کپی `cloneNode(true)` و حفظ تمیز و کامل بلوک‌های کد (`pre > code`). |
| A-34 | ۳ | محافظ در دسترس بودن `response.body.tee()` | انجام شد | بررسی امن متد `tee` و بازگشت پاسخ دست‌نخورده به مرورگر در صورت عدم پشتیبانی برای جلوگیری از شکست درخواست در چت‌جی‌پی‌تی. |
| A-35 | ۳ | قلاب کردن `XMLHttpRequest` و `EventSource` | انجام شد | رهگیری ترافیک گفتگو در XHR و EventSource با گارد‌های یکپارچه و بازپخش خطوط به `__ritmo_parseSSELine`. |
| A-36 | ۳ | تزریق در زمان شروع سند (`onPageStarted`) | انجام شد | انتشار `ChatGptJsInjector.earlyHookScript` و تزریق زودهنگام در `NavigationDelegate.onPageStarted`. |
| A-37 | ۳ | بهینه‌سازی اندازه پیام کانال JS با ارسال delta در واچر DOM | انجام شد | ارسال delta در گسترش‌های افزایشی و ارسال دوره‌ای/بازنویسی `fullText` برای بهینه‌سازی کانال جاوااسکریپت. |
| A-38 | ۳ | محدودسازی بستن خودکار مودال‌ها و عدم اجرا در حین تولید | انجام شد | توقف فوری `autoDismissCookiesAndModals` در حین تولید فعال، و محدودسازی دامنه کلیک به مودال‌های واقعی با استثنای فرم‌ها و پیام‌ها. |

---

## تاریخچهٔ پیاده‌سازی‌های قبلی (WEB-01 تا WEB-35)

| ID | عنوان | فاز | وضعیت | commit | یادداشت |
|---|---|:---:|:---:|:---:|---|
| WEB-01 | جلوگیری از ریبوت وب‌ویو در میانهٔ تولید پاسخ | A | DONE | 31c3e67 | محافظت از ensureBooted در برابر ریبوت در وضعیت‌های generating و cloudflareChallenge و افزودن forceReboot |
| WEB-02 | کارت پیش‌نمایش فقط مشاهده‌گر شد، راه‌انداز نه | A | DONE | e11306c | تغییر initState به attachViewer و غیرفعال‌سازی دکمهٔ ریفرش در هنگام تولید پاسخ همراه با هدایت به forceReboot |
| WEB-03 | گارد نسخه‌دار و اعلام آمادگی در سند گرم | A | DONE | f84eca4 | جایگزینی پرچم بولی با __RITMO_BRIDGE_V نسخه‌دار (v7)، اعلام آمادگی فوری در سند گرم و تابع پاکسازی خودتوان |
| WEB-04 | وصل مجدد واچر پس از هر بارگذاری صفحه | A | DONE | 7b299dc | بازتزریق اسکریپت و بازیابی درخواست معلق در onPageFinished همراه با سقف ۳ بار بارگذاری برای جلوگیری از لوپ |
| WEB-05 | تبدیل خطای ناوبری به پیام فارسی قابل‌اقدام | A | DONE | 73cb514 | تفکیک خطاهای وب‌ریسورس فریم اصلی از فرعی و بستن جریان با پیام‌های فارسی شبکه و خطاهای HTTP |
| WEB-06 | محافظت از تولید در‌جریان در برابر تایمر بی‌کاری | A | DONE | 5196802 | محافظ از قبل در کد بود؛ فقط تست تثبیت اضافه شد |
| WEB-07 | همبستگی سراسری رویدادها با شناسهٔ درخواست | B | DONE | bc1770b | تولید requestId یکتا برای هر پرامپت، عبور به اسکریپت JS، برچسب‌گذاری رویدادها و دور ریختن رویدادهای کهنه |
| WEB-08 | مدل وضعیت درخواست معلق | B | DONE | 1b1a90b | ایجاد مدل PendingWebBridgeRequest با فیلدهای prefix و مرحله و همگام‌سازی کامل چرخه حیات با Dart |
| WEB-09 | بازیابی پاسخ پس از جابجایی سند | B | DONE | 04c8820 | پیاده‌سازی __ritmo_resume در جاوااسکریپت و ارسال payload درخواست معلق برای بازیابی بی‌وقفه استریم |
| WEB-10 | ارسال مجدد تک‌بار با محافظ تکرار | B | DONE | fc64fad | پیاده‌سازی _handleResendRequired با شروط سفت‌وسخت عدم دریافت توکن و سقف ۱ بار تلاش |
| WEB-11 | لغو دوطرفه با توقف واقعی تولید در صفحه | B | DONE | affc513 | پیاده‌سازی __ritmo_cancelGeneration در جاوااسکریپت و فراخوانی آن در cancelCurrentStream و onCancel استریم |
| WEB-12 | دروازهٔ آمادگی کادر ورودی پیش از نوبت بعدی | B | DONE | 80012e2 | پیاده‌سازی __ritmo_checkComposerReady در جاوااسکریپت و انتظار کنترل‌شده در waitForComposerReady پیش از ارسال |
| WEB-13 | قلاب fetch برای تشخیص درخواست گفتگو | C | DONE | 34d6262 | ایجاد قلاب سراسری window.fetch برای رهگیری درخواست‌های مکالمه ChatGPT و ارسال رویداد شروع به فلاتر |
| WEB-14 | خواندن جریان رویدادی و نگاشت به رویدادهای پل | C | DONE | 8ef5694 | پیاده‌سازی parseSSELine و readSSEStream برای پارس فریم‌های SSE و استخراج مستقیم توکن‌ها با source: sse |
| WEB-15 | دوشاخه کردن بدنهٔ پاسخ بدون اختلال در صفحه | C | DONE | 62aa819 | استفاده از response.body.tee() و بازگرداندن Response کلون‌شده به رابط کاربری بدون بلاک شدن استریم |
| WEB-16 | نگاشت کدهای HTTP به خطای نوع‌دار | C | DONE | b02106b | ارسال رویداد http_error از JS و نگاشت دقیق کدهای ۴۲۹، ۴۰۱، ۴۰۳ و ۵xx به پیام‌های فارسی قابل‌اقدام در Dart |
| WEB-17 | برچسب منبع تشخیص و تلمتری سبک | C | DONE | 726e552 | برچسب‌گذاری دقیق منبع رویدادها (sse/dom/fetch) و هماهنگی بدون انتشار مضاعف بین دو منبع |
| WEB-18 | لنگر هویت پیام جای مقایسهٔ متن پایه | D | DONE | 7343bee | الصاق صفت data-ritmo-seen به پیام‌های موجود پیش از ارسال و اولویت‌بندی استخراج از المان‌های بدون این صفت |
| WEB-19 | جایگزینی پول دائمی با ناظر تغییرات DOM | D | DONE | feb5a1b | جایگزینی پولینگ مداوم با MutationObserver و تنظیم تایمر ضربان قلب به ۳۵۰ میلی‌ثانیه برای بهینه‌سازی منابع |
| WEB-20 | تشخیص پایان با رای چندسیگنالی | D | DONE | 9323667 | پیاده‌سازی evaluateStreamCompletion با ترکیب سیگنال‌های دکمه Stop/Send، کلاس‌های استریم و مکث زمانی |
| WEB-21 | جدول مرکزی selector و پرس‌وجوی محافظت‌شده | D | DONE | c73fe22 | ایجاد جدول ثابت RITMO_SELECTORS و توابع querySafe و queryAllSafe برای حذف تکرار و مقاومت در برابر تغییرات DOM |
| WEB-22 | زمان‌بندی تثبیت و رویداد اولین توکن | D | DONE | 5975d8d | ارسال رویداد first_token و ثبت میزان تاخیر TTFT در SSE و DOM و ارتقای مرحله به streaming |
| WEB-23 | تشخیص وضعیت احراز هویت از روی صفحه | D | DONE | 243dbb6 | پیاده‌سازی checkAuthState و ارسال رویداد auth_required و ذخیره وضعیت در فیلد isAuthenticated |
| WEB-24 | منبع واحد مهلت‌های پل | E | DONE | e1bb128 | ایجاد کلاس ChatGptBridgeTimeouts و ارجاع تمام ثوابت زمانی منیجر به این منبع واحد |
| WEB-25 | خطای نوع‌دار با پیام و اقدام فارسی | E | DONE | e3118c5 | ایجاد کلاس WebBridgeException و دسته‌بندی خطاهای وب‌بریج به انواع نوع‌دار با پیام و اقدام فارسی |
| WEB-26 | پنجرهٔ ورود به حساب درون برنامه | E | DONE | 89b947f | ایجاد ویجت ChatGptAuthModal و متدهای reloadPage و clearSessionCookies برای احراز هویت درون‌برنامه‌ای |
| WEB-27 | حذف تایم‌اوت‌های رقیب و تبدیل تایمر Dart به تور ایمنی | E | DONE | af93ec7 | حذف تایم‌اوت ۳۵ ثانیه‌ای در JS و تبدیل تایمر Dart به تنها تور ایمنی زمان‌بندی کل استریم |
| WEB-28 | پذیرش سه شکل فراخوانی ابزار در پارسر | F | DONE | 5422261 | پشتیبانی از ۳ فرم فراخوانی ابزار (بلوک کد، تگ ساختاریافته، JSON خام) و یکسان‌سازی کلیدها در AgentToolCallParser |
| WEB-29 | پاکسازی سه‌شکلی و محافظ نشانهٔ نیمه‌تمام | F | DONE | ff4f405 | تشخیص و پنهان‌سازی نشانه‌ها و بلوک‌های نیمه‌کاره ابزار در طول استریم توکن‌ها در AgentToolCallParser |
| WEB-30 | دستورالعمل فراخوانی ابزار مخصوص مسیر وب | F | DONE | 5d1d428 | ایجاد متد buildWebBridgeToolPrompt در AgentToolProtocol برای ساخت پرامپت شفاف فراخوانی ابزار |
| WEB-31 | مقاومت در برابر تزریق نشانهٔ ابزار | F | DONE | fcddd75 | گسترش regex خنثی‌سازی در AgentToolProtocol.sanitize برای پوشش تگ‌های XML، براکت، پرامپت‌های سیستمی |
| WEB-32 | رندر دومرحله‌ای با بافر سرکوب و تفکیک نوبت‌ها | G | DONE | df859a1 | Stage 2 rendering in AgentLoopRunner: suppress token emission while hasOpenTag is true |
| WEB-33 | رویداد بازنشانی نمایش و استخراج پاسخ نهایی تمیز | G | DONE | 486fde6 | افزودن AgentTurnKind enum و AgentDisplayResetEvent؛ بازنشانی بافر نمایش پس از نوبت ابزاری در AgentLoopRunner |
| WEB-34 | ارتقای نوار پیشرفت و وضعیت تفکر در شیت دستیار | G | DONE | ba51d33 | پشتیبانی از AgentDisplayResetEvent و متغیر _suppressUntilTurnEnd در AssistantSheet برای عدم نمایش نوبت‌های ابزاری به کاربر |
| WEB-35 | مستندسازی جامع معماری پل وب و ضدرندر | G | DONE | 1b22481 | ایجاد سند جامع docs/ai/WEB_BRIDGE_ARCHITECTURE.md با دیاگرام‌های جریان و تشریح کامل لایه‌های سه‌گانه و پروتکل ضدرندر |

---

## واگرایی از پرامپت
- طبق بند ۷.۲ پرامپت (اصلاحیه‌های الزامی پس از هم‌ترازی با مخزن)، مسیر تست‌های وب‌بریج به `test/core/ai/web_bridge/` و مسیر تست‌های ایجنت به `test/core/ai/` نگاشت شدند تا با ساختار استاندارد مخزن ریتمو کاملاً همگام باشند.

---

## جدول بسته شدن باگ‌ها

| باگ ریشه‌ای | تسک بسته‌کننده | تأیید شد؟ |
| --- | --- | --- |
| R1 — ریبوت وب‌ویو در میانهٔ تولید | WEB-01، WEB-02 | ✅ بله (تایید با تست‌های no_reboot_while_generating_test و preview_is_viewer_only_test) |
| R2 — وصل نشدن دوبارهٔ واچر پس از بارگذاری | WEB-04 | ✅ بله (تایید با reattach_after_navigation_test) |
| R3 — بازگشت زودهنگام و نفرستادن رویداد آمادگی | WEB-03 | ✅ بله (تایید با bridge_script_idempotent_test) |
| R4 — تشخیص از روی مقایسهٔ متن پایه | WEB-18 | ✅ بله (تایید با message_identity_anchor_test) |
| R5 — پایان از روی نبودن دکمهٔ توقف | WEB-20 | ✅ بله (تایید با multi_signal_done_test) |
| R6 — قطع یک‌طرفه و نبود همبستگی درخواست | WEB-07، WEB-11 | ✅ بله (تایید با stale_event_dropped_test و two_way_cancellation_test) |
| R7 — سه تایم‌اوت رقیب | WEB-24، WEB-27 | ✅ بله (تایید با bridge_timeouts_test و single_master_timer_test) |
| R8 — نشست مهمان و دیوار ورود | WEB-23، WEB-26 | ✅ بله (تایید با auth_state_detection_test و auth_modal_test) |
| R9 — نشت متن فراخوانی ابزار | WEB-28، WEB-29 | ✅ بله (تایید با three_form_tool_parser_test و partial_sentinel_guard_test) |
| R10 — چسبیدن نوبت‌ها به هم | WEB-32، WEB-33 | ✅ بله (تایید با two_stage_render_test و display_reset_event_test) |

---

## خروجی فرمان‌های تایید نهایی (Definition of Done)

### ۵-۱ — فرمان‌های با خروجی خالی (صفر خطا)
- `rg -n "debugPrint" lib/core/ai/web_bridge lib/core/ai/agent lib/core/ai/chat` -> **خروجی خالی (۰ نتیجه)**
- `rg -n "setInterval" lib/core/ai/web_bridge/chatgpt_js_injector.dart` -> **تنها تایمرهای مجاز پس‌زمینه**
- `rg -n "catch \(_\) \{\}" lib/core/ai/web_bridge` -> **خروجی خالی (۰ نتیجه)**
- `rg -n "__RITMO_BRIDGE_INITIALIZED__" lib/` -> **خروجی خالی (۰ نتیجه)**
- `rg -n "35000|70000" lib/core/ai/web_bridge` -> **خروجی خالی (۰ نتیجه)**
- `rg -n "generationTimeout = Duration\(seconds: 120\)" lib/` -> **خروجی خالی (۰ نتیجه)**
- `rg -n "document\.querySelector|document\.querySelectorAll" lib/core/ai/web_bridge/chatgpt_js_injector.dart` -> **دقیقاً ۲ خط درون دو helper امن querySafe و queryAllSafe**
- `rg -n "تنطیم|منتطر|حافطه|لحطه" lib/core/ai` -> **خروجی خالی (۰ نتیجه)**

### ۵-۲ — حضور تمام نمادهای کلیدی جدید
- `__ritmo_resume` ✅
- `__ritmo_detach` ✅
- `__ritmo_stopGeneration` ✅
- `__ritmo_composerReady` ✅
- `__ritmo_origFetch` ✅
- `__RITMO_BRIDGE_V` ✅ (مقدار: ۸)
- `data-ritmo-seen` ✅
- `requestId` ✅
- `MutationObserver` ✅
- `ritmo-tool` ✅
- `AgentDisplayResetEvent` ✅
- `AgentTurnKind` ✅
- `suppressUntilTurnEnd` ✅
- `loginRequired` / `login_required` ✅
- `WebBridgeErrorCode` ✅
- `ChatGptBridgeTimeouts` ✅
- `RITMO_SELECTORS` ✅
- `WebBridgeDiagnosticsScreen` ✅
- `BridgeTraceLog` ✅
- `docs/ai/WEB_BRIDGE_ARCHITECTURE.md` ✅

### ۵-۳ — آزمون‌های جامع
- `flutter analyze lib/core/ai/ lib/features/profile/presentation/web_bridge_diagnostics_screen.dart lib/features/profile/presentation/ai_connection_screen.dart lib/features/assistant/ lib/features/chat/ test/core/ai/`: **No issues found! (0 errors, 0 warnings)**
- `flutter test test/core/ai/`: **255/255 Tests Passed!**

---

## فاز ۴ — رابط کاربری و بهینه‌سازی تجربهٔ کاربری (A-39 تا A-47)

| شناسه | شرح تسک | وضعیت | کامیت | توضیحات فنی |
| --- | --- | --- | --- | --- |
| A-39 | صفحهٔ جامع تشخیص و مانیتورینگ پل هوش مصنوعی وب | DONE | pending | ایجاد WebBridgeDiagnosticsScreen شامل کارت وضعیت چرخه حیات، گرید سلامت سلکتورهای DOM، گزارش ردیاب لاگ زنده |
| A-40 | دکمه و سازوکار بازیابی دستی پاسخ | DONE | pending | اتصال harvestVisibleAnswer به دکمهٔ «بازیابی پاسخ از مرورگر» و کپی در حافظه در صورت قطعی یا تایم‌اوت |
| A-41 | جدول قطعی حالات خالی و خطا با اقدام‌های شفاف | DONE | pending | پیاده‌سازی راهنمای خطای فارسی و کلیدهای بازیابی در AiChatScreen و AssistantSheet طبق جدول ماتریس خطا |
| A-42 | محلی‌سازی کامل پیام‌های دامنهٔ پل وب | DONE | pending | انتقال تمام پیام‌ها به app_fa.arb و app_en.arb با پیشوند bridge، افزودن messageKey به WebBridgeException و اجرای flutter gen-l10n |
| A-43 | بازسازی تایپوگرافی و توکن‌های طراحی مودال‌ها | DONE | pending | تبدیل تمام fontSizeهای هاردکد به Theme.of(context).textTheme در ChatGptAuthModal, CloudflareChallengeModal, ChatGptMiniPreview, BridgeStatusChip و کامپوننت‌های ایجنت |
| A-44 | پیام‌های پلکانی در حین انتظار در AgentStreamPresenter | DONE | pending | پیاده‌سازی getProgressiveStatusText با پیام‌های تفکیک‌شده بر اساس مراحل sending, awaitingFirstToken (<=8s, <=20s, >20s), streaming |
| A-45 | بررسی زودهنگام وضعیت احراز هویت و کلادفلر پیش از مصرف پرامپت | DONE | pending | گیت‌های اولیه در sendPrompt و waitForComposerReady برای جلوگیری از مصرف نوبت در وضعیت‌های unauthenticated و challenge |
| A-46 | اتصال BridgeStatusChip به صفحهٔ تشخیص در وضعیت خطا | DONE | pending | ناوبری خودکار به WebBridgeDiagnosticsScreen با لمس چیپ در وضعیت قرمز خطا و افزودن دکمه در AiConnectionScreen |
| A-47 | دسترسی دائمی به پنجرهٔ مرورگر چت‌جی‌پی‌تی در سربرگ | DONE | pending | افزودن دکمهٔ همیشگی «مشاهدهٔ پنجرهٔ چت‌جی‌پی‌تی» در AppBar صفحه چت و هدر شیت دستیار با فراخوانی خودکار ensureBooted |


