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
| T09 | trimToBudget نباید سؤال کاربر را حذف کند | DOING | | |
| T10 | بریدن نادرست متن نهایی | TODO | | |
| T11 | تقارن fallback بین چت اصلی و شیت | TODO | | |
| T12 | حذف catch (_) {} و بررسی جدول assistant_plans | TODO | | |
| T13 | وصل کردن AgentIntentRouter و حذف AgentIntentPrefetcher | TODO | | |
| T14 | اصلاح نام ابزار عبادی در همه‌جا | TODO | | |
| T15 | یکی کردن کش prefetch و ثبت در بودجه | TODO | | |
| T16 | تست یکپارچگی نقشه‌ی اسکوپ (نگهبان CI) | TODO | | |
| T17 | اسکیمای واقعی JSON Schema | TODO | | |
| T18 | اعتبارسنج مرکزی آرگومان‌ها | TODO | | |
| T19 | حذف پارسرهای دستی تکراری | TODO | | |
| T20 | idempotencyKey | TODO | | |
| T21 | قابلیت‌سنجی provider | TODO | | |
| T22 | عبور tools از AIGateway | TODO | | |
| T23 | نرمال‌ساز واحد فراخوانی ابزار + fallback XML | TODO | | |
| T24 | فشرده‌سازی پرامپت ابزار | TODO | | |
| T25 | حذف مسیر موازی <actions> از شیت | TODO | | |
| T26 | تولید خودکار ابزار از رجیستری فرمان‌ها | TODO | | |
| T27 | حذف هر ابزاری که SQL خام می‌نویسد | TODO | | |
| T28 | Undo یکپارچه روی AgentJournal | TODO | | |
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
