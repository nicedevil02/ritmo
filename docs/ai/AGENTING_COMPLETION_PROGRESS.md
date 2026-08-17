# پیشرفت تکمیل ایجنتینگ

وضعیت‌های مجاز: TODO | DOING | DONE | SKIPPED | BLOCKED

| ID | عنوان | وضعیت | کامیت | یادداشت |
|----|-------|-------|-------|---------|
| T01 | پاس دادن personaId به حلقه | DONE | 3b65554 | personaId اجباری شد و به PersonaGate و AgentLoop منتقل شد |
| T02 | نصب AgentConfirmationHost | DONE | 00b01e0 | نصب در شیت دستیار، تایم‌اوت ۹۰ ثانیه و رویداد AgentConfirmationTimedOutEvent |
| T03 | نشتی اشتراک و broker در dispose | DONE | 79701aa | لغو اشتراک ایجنت و پاکسازی تمام تاییدهای معلق در dispose |
| T04 | استفاده از rawAnswer به‌جای متن تمیزشده | DONE | a692322 | پارس اکشن‌ها و اعمال memory_ops از روی rawAnswer در شیت دستیار |
| T05 | هندل کردن همه‌ی رویدادها در چت اصلی | DONE | 56967fa | ارسال AgentStreamEvent و نصب AgentConfirmationHost در چت اصلی |
| T06 | اصلاح «تاریخچه اخیر» معکوس | DONE | 344ce6f | ارسال ۴ پیام اخیر با حفظ ترتیب زمانی صحیح و افزودن تست یونیت |
| T07 | اعمال یا حذف PersonaInferenceProfile | DONE | c440ff0 | دریافت و اعمال PersonaInferenceProfile در حلقه ایجنت و گیت‌وی هوش مصنوعی |
| T08 | بودجه‌ی نوشتن نباید با شکست مصرف شود | DONE | f48fb97 | شمارش writesUsed فقط در صورت اجرای موفقیت‌آمیز ابزار |
| T09 | trimToBudget نباید سؤال کاربر را حذف کند | DONE | 1305448 | تثبیت سیستم پرامپت و سؤال کاربر و برش از نوبت‌های میانی |
| T10 | بریدن نادرست متن نهایی | DONE | c5588a7 | حفظ پیشوند و پسوند هنگام تمیزسازی tool_call برای پاسخ نهایی و افزودن تست‌های جامع |
| T11 | تقارن fallback بین چت اصلی و شیت | DONE | dc2d43d | افزودن مسیر fallback گیت‌وی به شیت دستیار در صورت خطای ایجنت با پاسخ خالی |
| T12 | حذف catch (_) {} و بررسی جدول assistant_plans | DONE | 114c012 | حذف catch خالی، لاگ دقیق خطاها و همگام‌سازی ساختار جدول assistant_plans |
| T13 | وصل کردن AgentIntentRouter و حذف AgentIntentPrefetcher | DONE | 3bff700 | اتصال AgentIntentRouter به حلقه، حذف کامل agent_intent_prefetcher و افزودن تست‌های واحد |
| T14 | اصلاح نام ابزار عبادی در همه‌جا | DONE | 7b4b01a | یکسان‌سازی نام get_worship_practices در روتر، اسکوپ و کاتالوگ ابزارها |
| T15 | یکی کردن کش prefetch و ثبت در بودجه | DONE | 67ba717 | ذخیره نتایج پیش‌واکشی با کلید نرمال‌شده و ثبت مصرف در بودجه ایجنت |
| T16 | تست یکپارچگی نقشه‌ی اسکوپ (نگهبان CI) | DONE | 7701498 | ایجاد تست یکپارچگی تناظر ۱:۱ ابزارهای رجیستری و اسکوپ و تست پرسونای خواب |
| T17 | اسکیمای واقعی JSON Schema | DONE | 5368756 | پیاده‌سازی خروجی استاندارد JSON Schema در AgentTool و ToolParameter |
| T18 | اعتبارسنج مرکزی آرگومان‌ها | DONE | daf34cd | پیاده‌سازی AgentToolArgumentValidator، اعمال type coercion و مقادیر پیش‌فرض |
| T19 | حذف پارسرهای دستی تکراری | DONE | bea2680 | پاکسازی تبدیل‌های نوع تکراری در کاتالوگ ابزارها به اتکای اعتبارسنج مرکزی |
| T20 | idempotencyKey | DONE | cb82c24 | پیاده‌سازی محافظ Idempotency برای ابزارهای تغییردهنده در طول هر نشست اجرا |
| T21 | قابلیت‌سنجی provider | DONE | 5aaed95 | افزودن فلگ و پروپرتی supportsNativeTools به AiProviderPreset و AiConnectionConfig |
| T22 | عبور tools از AIGateway | DONE | 59152c5 | ارسال آرایه tools و tool_choice در متدهای streaming گیت‌وی به پرووایدرهای پشتیبان |
| T23 | نرمال‌ساز واحد فراخوانی ابزار + fallback XML | DONE | 7cb7a0f | پشتیبانی از پارس ساختارهای XML، function tags، کدبلاک‌های مارک‌داون و JSON خام |
| T24 | فشرده‌سازی پرامپت ابزار | DONE | 7d24497 | پیاده‌سازی toCompactPromptDescription و compactPromptFor جهت کاهش مصرف توکن |
| T25 | حذف مسیر موازی <actions> از شیت | DONE | 8866523 | حذف اجرای موازی اکشن‌های متنی در مسیر AgentCompletedEvent شیت دستیار |
| T26 | تولید خودکار ابزار از رجیستری فرمان‌ها | DONE | dcd6573 | پیاده‌سازی CommandToolBridge برای ساخت خودکار AgentTool از روی هر RitmoCommand |
| T27 | حذف هر ابزاری که SQL خام می‌نویسد | DONE | 28128d6 | بازنویسی تمام ابزارهای تغییردهنده بر پایه KernelCommandTool و حذف نوشتن مستقیم در SQL |
| T28 | Undo یکپارچه روی AgentJournal | DONE | 5ef410c | افزودن undoLastPlan به AgentJournal و ایجاد ابزار اختصاصی undo_last_action |
| T29 | یک broker برای تایید و پرسش | DONE | 20c3e1e | پیاده‌سازی AgentQuestionBroker و یکپارچه‌سازی چرخه حیات با AgentConfirmationBroker و پاکسازی در dispose |
| T30 | AskUserTool که واقعاً حلقه را متوقف می‌کند | DONE | 1fd4fec | اتصال AskUserTool به AgentQuestionBroker و ارسال رویداد تعاملی جهت توقف حلقه و دریافت پاسخ کاربر |
| T31 | تأیید خودکار و اجباری حالت پس از نوشتن | DONE | 7a0280e | تقویت پروتکل بازخورد اجرای ابزارها با هشدار اصالت‌سنجی و اعلام وضعیت دقیق پایگاه داده |
| T32 | NavigateToAppScreenTool که واقعاً جابه‌جا می‌کند | DONE | 764c9c2 | افزودن اکشن تعاملی navigation به خروجی NavigateToAppScreenTool و انتشار در AgentCompletedEvent |
| T33 | ابزار simulate_plan (حالت «فقط نشانم بده») | DONE | 43f4a52 | پیاده‌سازی SimulatePlanTool بر پایه RitmoCommandBus.preview برای شبیه‌سازی طرح بدون نوشتن در دیتابیس |
| T34 | برنامه‌ی چندمرحله‌ای با یک تایید | DONE | 496c62f | پیاده‌سازی ExecutePlanTool با قابلیت اجرای اتمیک چندین گام تحت یک تراکنش و ثبت در ژورنال برای Rollback |
| T35 | مرور شبانه‌ی فعال | DONE | 667fbd6 | ارتقا و تثبیت AgentNightlyReview جهت اجرای امن فقط-خواندنی و یکپارچه با محدوده پرسونا |
| T36 | تحویل بین پرسوناها به‌عنوان ابزار | DONE | f0ff643 | پیاده‌سازی HandoffToPersonaTool بر پایه فرمان assistant.handoff جهت واگذاری بین دستیارها |
| T37 | حافظه به‌عنوان شهروند درجه‌یک | DONE | 4a7aecf | یکپارچه‌سازی ابزارهای حافظه (RememberFactTool و RecallFactsTool) و اصلاح خطاهای املایی فارسی |
| T38 | کش نتیجه‌ی ابزار بین نوبتی | DONE | fe2b20f | بهینه‌سازی کش ابزارها و بی‌اعتبارسازی خودکار کش خواندنی پس از موفقیت عملیات جهش داده |
| T39 | تلمتری هر ابزار | DONE | 8ca2d61 | افزودن سیستم تلمتری زمان اجرا، نرخ موفقیت و تعداد فراخوانی به AgentToolRegistry |
| T40 | شفافیت «چه کاری کردم» | DONE | 21d7253 | افزودن امکان استخراج و نمایش خلاصه شفاف اقدامات (actionsSummaryFa) در AgentCompletedEvent |
| T41 | سخت‌سازی گارد تزریق پرامپت | DONE | fa3a6d0 | سخت‌سازی تشخیص عبارات تزریق پرامپت تودرتو و خنثی‌سازی تگ‌های سیستمی در AgentPolicyGate و AgentToolProtocol |
| T42 | پاکسازی زبانی + تست ترمینولوژی | DONE | 2a56528 | پاکسازی کامل غلط‌های املایی فارسی در سرتاسر ماژول‌های AI و ایجاد تست خودکار جامع agent_terminology_test |
| T43 | قابل تنظیم کردن سقف نوشتن | DONE | ce3d248 | قابلیت تنظیم پویای سقف نوشتن در هر اجرا از طریق AgentBudget و AgentPolicyGate |
| T44 | پاکسازی کوئری‌های ابزارها | DONE | f96fa06 | بازبینی و تضمین استفاده از پارامتریزاسیون کامل در کوئری‌های ابزارهای دیتابیس |
| T45 | test/agent/agent_tool_call_parser_test.dart | DONE | 41ca46b | تست‌های جامع پارسر ابزار (فرمت‌های JSON، XML، چندگانه، یونیکد فارسی، stableArgs) |
| T46 | test/agent/agent_tool_validator_test.dart | DONE | db8e6c2 | اعتبارسنجی پارامترهای ابزار با کلاس AgentToolValidator (فیلدهای الزامی، پیش‌فرض، مقادیر مجاز) |
| T47 | test/agent/agent_loop_fake_model_test.dart | DONE | 3258a44 | تست End-to-End چرخه ReAct ایجنت همراه با شبیه‌سازی مدل فیک و گام‌های اجرای ابزار |
| T48 | test/agent/kernel_command_tool_test.dart | DONE | 5b762bd | تست‌های جامع پل KernelCommandTool با تبدیل پارامترها و خطاهای ToolArgumentError |
| T49 | test/agent/agent_policy_gate_test.dart | DONE | 6a4d76f | تست‌های جامع امنیتی AgentPolicyGate (سطوح سیاست، سقف نوشتن، کارت تایید تعاملی، گارد تزریق) |
| T50 | test/agent/agent_journal_undo_test.dart | DOING | | |
