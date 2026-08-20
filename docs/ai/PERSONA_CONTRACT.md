# سند قرارداد دستیارهای تخصصی و قوانین لایهٔ هوش مصنوعی (Persona Contract)

این سند مرجع یکپارچه و قرارداد قطعی برای معماری، توسعه و نگهداری دستیارهای تخصصی (Personas)، پرامپت‌ها، مهارت‌ها و اعتبارسنجی خروجی هوش مصنوعی در Ritmo است.

---

## ۱. پنج لایهٔ ساخت پرامپت (Prompt Architecture Layers)

پرامپت نهایی ارسالی به مدل زبانی توسط `PersonaPromptBuilder` (`lib/core/ai/personas/persona_prompt_builder.dart`) از ترکیب ۵ لایه با ترتیب زیر ساخته می‌شود:

1. **لایه ۰ — سیاست‌های مرکزی و قواعد تحلیلی (Core Policy & Rules):**
   - تعریف‌شده در `lib/core/ai/personas/assistant_core_policy.dart` و `lib/core/ai/personas/policy_rule_ids.dart`.
   - شامل قواعد غیرقابل‌نقض ایمنی، لحن و قالب‌بندی. در دو حالت `conversational` و `taskOriented`.
2. **لایه ۱ — منشور پرسونا (Persona Charter):**
   - تعریف‌شده در `lib/core/ai/personas/assistant_charters.dart`.
   - سند مأموریت و هویت تخصصی پرسونا.
3. **لایه ۲ — خلاصهٔ داده‌های دامنه (Domain Brief):**
   - ارائه‌شده توسط `PersonaContextProvider` (`lib/core/ai/brief/persona_context_provider.dart`).
   - خروجی ساختاریافته از وضعیت زنده داده‌های مجاز کاربر مطابق با پرچم‌های رضایت دروازه.
4. **لایه ۳ — کاتالوگ مهارت‌های منتخب (Skills Block):**
   - تولید‌شده از `PersonaSkillRegistry` (`lib/core/ai/personas/persona_skill_registry.dart`).
   - فهرست مهارت‌های مرتبط بر اساس شرایط جاری brief و فرمان‌های در دسترس.
5. **لایه ۴ — منوی فرمان‌های اجرایی و دایرکتوری واگذاری (Commands & Handoff):**
   - تولید‌شده از `PersonaRegistry` (`lib/core/domain/personas/persona_registry.dart`) و `CommandsRegistry`.
   - فرمان‌های مجاز پرسونا به همراه دایرکتوری ارجاع به سایر دستیاران تخصصی.

---

## ۲. چک‌لیست هفت‌گانهٔ افزودن پرسونای جدید

برای اضافه کردن یک پرسونای جدید، حتماً باید این ۷ مرحله به ترتیب طی شوند:

1. **کلید منشور:** افزودن متن منشور جامع (> ۲۰۰ کاراکتر) در `AssistantCharters.charters` (`lib/core/ai/personas/assistant_charters.dart`).
2. **ثبت در رجیستری:** ثبت شیء `AssistantPersona` در `PersonaRegistry._initPersonas` (`lib/core/domain/personas/persona_registry.dart`) با تعیین دقیق `id`, `displayName`, `reads`, `commandIds` و `systemPromptKey`.
3. **پروفایل استنتاج صریح:** تعریف `PersonaInferenceProfile` در `lib/core/ai/personas/persona_inference_profile.dart` با مشخص کردن `maxTokens`, `temperature`, `timeout` و `policyMode`.
4. **ثبت مهارت‌ها:** افزودن حداقل ۳ مهارت تخصصی برای پرسونا در `PersonaSkillRegistry.all` (`lib/core/ai/personas/persona_skill_registry.dart`).
5. **فرمان‌های ثبت‌شده:** اطمینان از اینکه تمامی شناسه‌های موجود در `commandIds` در `CommandsRegistry` ثبت شده و دامنه (`touches`) آن‌ها زیرمجموعهٔ `reads` پرسونا باشد.
6. **سازندهٔ Brief:** پیاده‌سازی متد ساخت brief در `PersonaContextProvider` برای دامنه‌های مورد نیاز پرسونا.
7. **قلاب واگذاری:** افزودن فرمان `assistant.handoff` و `app.openPage` به مجموعه فرمان‌های پرسونا.

---

## ۳. هفت ناوردای پایداری (Persona Invariants)

| ناوردا | عنوان | شرح | تست محافظ |
|---|---|---|---|
| **Invariant 1** | وجود منشور | هر پرسونای ثبت‌شده باید کلید منشور غیرخالی داشته باشد | `persona_invariants_test.dart` |
| **Invariant 2** | عدم وجود منشور یتیم | هیچ منشوری نباید بدون پرسونای معادل در رجیستری بماند | `persona_invariants_test.dart` |
| **Invariant 3** | پروفایل استنتاج صریح | تمامی ۱۵ پرسونا باید پروفایل استنتاج صریح و معتبر داشته باشند | `persona_invariants_test.dart` |
| **Invariant 4** | پوشش کاتالوگ مهارت | هر پرسونا باید حداقل ۳ مهارت ثبت‌شده در رجیستری داشته باشد | `persona_invariants_test.dart` |
| **Invariant 5** | توازن مهارت‌ها | توزیع مهارت‌ها متعادل بوده و هیچ مهارتی بدون پرسونا نیست | `persona_invariants_test.dart` |
| **Invariant 6** | دامنه‌های فرمان درون خواندنی | دامنه‌های `touches` هر فرمان باید زیرمجموعهٔ `reads` پرسونا باشد | `persona_invariants_test.dart` |
| **Invariant 7** | رجیستری یکپارچه فرمان‌ها | تمام `commandIds` پرسوناها باید در `CommandsRegistry` موجود باشند | `persona_invariants_test.dart` |

---

## ۴. جدول قوانین لایهٔ صفر و نگاشت‌ها (Policy Rules)

| شناسه ثابت (`PolicyRule`) | متن خلاصه قانون | نگاشت به قوانین تحلیلی |
|---|---|---|
| `PolicyRule.identityPreamble` | هویت Ritmo و لحن حرفه‌ای همدلانه | Base Identity |
| `PolicyRule.correlationOnly` | ممنوعیت ادعای علیت قطعی و تمرکز بر همبستگی | RULE 21/30 |
| `PolicyRule.jalaliInReply` | اجبار استفاده از تقویم جلالی در متن برای کاربر | RULE 22 |
| `PolicyRule.cycleFence` | حصار حفظ حریم خصوصی چرخه قاعدگی | RULE 25 |
| `PolicyRule.medicalSafetyFence` | ممنوعیت ارائه دستورات قطعی پزشکی | Medical Disclaimers |
| `PolicyRule.structuredOnly` | الزام به خروجی ساختاریافته JSON تمیز | JSON Protocol |
| `PolicyRule.toolAuthorization` | ممنوعیت صدور فرمان فراتر از دسترسی | Command Fence |

---

## ۵. سطوح هشدار اعتبارسنجی خروجی (Validation Severities)

اعتبارسنج خروجی `PersonaResponseValidator` (`lib/core/ai/personas/persona_response_validator.dart`) پاسخ‌ها را بررسی کرده و در ۳ سطح برخورد می‌کند:

| سطح (`ValidationSeverity`) | نوع خطا / رخداد | رفتار سیستم |
|---|---|---|
| **block** | نقض حصار چرخه قاعدگی توسط پرسونای غیرمجاز، شکست کامل ساختار JSON | رد کامل پاسخ و درخواست تولید مجدد (`retryMessage`) |
| **sanitize** | وجود تاریخ میلادی در متن فارسی، ارسال شناسه‌های فرمان ثبت‌نشده یا نامعتبر | اصلاح خودکار متن به جلالی و حذف فرمان‌های غیرمجاز |
| **annotate** | کاهش سطح اطمینان (Confidence Monotonic Downgrade)، ارجاع به فیلد غایب در brief | الصاق یادداشت به پاسخ و ثبت در لاگ و تله‌متری |

---

## ۶. قرارداد دوگانهٔ تاریخ (Date Contract)

- **در متن پاسخ دستیار (User-Facing Reply):** فقط و فقط تاریخ شمسی/جلالی (مانند `۱۴۰۳/۰۶/۰۱` یا `شنبه ۳ شهریور`).
- **در پیلود فرمان‌ها (Command Payload):** تاریخ استاندارد میلادی ایزو (`YYYY-MM-DD` یا ISO-8601 UTC timestamp).

---

## ۷. دو خط قرمز حریم خصوصی و امنیت (Privacy & Safety Fences)

1. **حصار دادهٔ چرخه (Cycle Privacy Fence):**
   - تنها پرسونای `cycle` و `pregnancy` مجاز به خواندن داده‌های چرخه یا استفاده از واژگان مربوط به چرخه قاعدگی هستند.
   - هرگونه ورود واژگان چرخه به خروجی پرسوناهای عمومی بلافاصله `block` می‌شود.
2. **حصار دادهٔ پزشکی و سلامت:**
   - پرسونای سلامت (`health`) توصیه‌های بالینی ارائه نمی‌دهد و صرفاً به تحلیل روند و پایبندی به رژیم دارویی می‌پردازد.
   - دروازه رضایت (`PersonaGate`) رضایت دسترسی ابری را پیش از ساخت brief در لایه خواندن و قبل از اجرای فرمان در لایه نوشتن اعتبارسنجی می‌کند.

---

## ۸. جدول مشخصات دستیارهای تخصصی (Personas Specification)

| شناسه (`id`) | نام نمایشی فارسی | دامنه‌های خواندنی (`reads`) | تعداد فرمان | تعداد مهارت | لایهٔ صفر | واگذاری |
|---|---|---|---|---|---|---|
| `global` | دستیار ریتم زندگی | sports, sleep, worship, cycle, routines, goals, konkur, energy | ۹ | ۳ | conversational | دارد |
| `general` | گفتگوی عمومی | *خالی* | ۲ | ۳ | conversational | دارد |
| `planning` | دستیار تخصصی برنامه‌ریزی | routines, goals, energy, sports | ۱۲ | ۳ | taskOriented | دارد |
| `sleep` | تحلیل‌گر خواب و بازیابی | sleep, energy, routines | ۷ | ۴ | taskOriented | دارد |
| `wellbeing` | پایشگر حال خوب و ذهن‌آگاهی | energy, routines, sleep | ۷ | ۴ | conversational | دارد |
| `reflection` | آینهٔ بازتاب و ثبت روزانه | routines, energy, goals | ۶ | ۳ | conversational | دارد |
| `goals` | معمار اهداف و چشم‌انداز | goals, routines, energy | ۵ | ۳ | taskOriented | دارد |
| `konkur` | مشاور تخصصی کنکور | konkur, routines, energy | ۱۰ | ۵ | taskOriented | دارد |
| `courses` | برنامه‌ریز دوره‌ها و یادگیری | courses, routines, energy | ۶ | ۴ | taskOriented | دارد |
| `sports` | مربی هوشمند ورزشی | sports, energy, routines | ۱۲ | ۵ | taskOriented | دارد |
| `worship` | هم‌مسیر عبادی و بندگی | worship, routines | ۶ | ۵ | conversational | دارد |
| `cycle` | همراه چرخه و سلامتی بانوان | cycle, energy, routines, sleep | ۴ | ۶ | taskOriented | دارد |
| `health` | مشاور عادات سلامت و دارویی | health, sleep, energy, routines | ۷ | ۵ | taskOriented | دارد |
| `notes` | مدیریت یادداشت‌ها و مستندات | notes | ۴ | ۳ | taskOriented | دارد |
| `pregnancy` | همراه هوشمند دوران بارداری | pregnancy, cycle, health, sleep, routines | ۴ | ۵ | taskOriented | دارد |
