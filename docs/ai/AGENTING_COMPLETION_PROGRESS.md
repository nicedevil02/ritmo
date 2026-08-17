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
| T28 | Undo یکپارچه روی AgentJournal | DOING | | |
| T29 | یک broker برای تایید و پرسش | TODO | | |
| T30 | AskUserTool که واقعاً حلقه را متوقف می‌کند | TODO | | |
| T31 | تأیید خودکار و اجباری حالت پس از نوشتن | TODO | | |
| T32 | NavigateToAppScreenTool که واقعاً جابه‌جا می‌کند | TODO | | |
| T33 | ابزار simulate_plan (حالت «فقط نشانم بده») | TODO | | |
| T34 | برنامه‌ی چندمرحله‌ای با یک تایید | TODO | | |
| T35 | مرور شبانه‌ی فعال | TODO | | |
| T36 | تحویل بین پرسوناها به‌عنوان ابزار | TODO | | |
| T37 | حافظه به‌عنوان شهروند درجه‌یک | TODO | | |
| T38 | کش نتیجه‌ی ابزار بین نوبتی | TODO | | |
| T39 | تلمتری هر ابزار | TODO | | |
| T40 | شفافیت «چه کاری کردم» | TODO | | |
| T41 | سخت‌سازی گارد تزریق پرامپت | TODO | | |
| T42 | پاکسازی زبانی + تست ترمینولوژی | TODO | | |
| T43 | قابل تنظیم کردن سقف نوشتن | TODO | | |
| T44 | پاکسازی کوئری‌های ابزارها | TODO | | |
| T45 | test/agent/agent_tool_call_parser_test.dart | TODO | | |
| T46 | test/agent/agent_tool_validator_test.dart | TODO | | |
| T47 | test/agent/agent_loop_fake_model_test.dart | TODO | | |
| T48 | test/agent/kernel_command_tool_test.dart | TODO | | |
| T49 | test/agent/agent_policy_gate_test.dart | TODO | | |
| T50 | test/agent/agent_journal_undo_test.dart | TODO | | |
