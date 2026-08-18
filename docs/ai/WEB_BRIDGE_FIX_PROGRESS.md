# پیشرفت رفع پل وب چت‌جی‌پی‌تی و سرکوب پیام‌های ابزار در ریتمو (WEB-01 تا WEB-35)

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
- `__RITMO_BRIDGE_V` ✅ (مقدار: ۷)
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
- `docs/ai/WEB_BRIDGE_ARCHITECTURE.md` ✅

### ۵-۳ — آزمون‌های جامع
- `flutter analyze lib/core/ai test/core/ai`: **No issues found!**
- `flutter test test/core/ai/web_bridge/ test/core/ai/`: **199/199 Tests Passed!**

