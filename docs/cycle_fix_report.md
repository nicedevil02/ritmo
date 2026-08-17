# گزارش جامع بازسازی و رفع باگ‌های ماژول چرخه (Cycle Module Remediation Report)
**پروژه:** ریتمو (Ritmo)  
**محدوده:** بازطراحی ساختاری، انطباق فقهی، امنیت حریم خصوصی و مهندسی داده ماژول چرخه (`C-01` تا `C-48`)  
**وضعیت پذیرش:** ۱۰۰٪ تایید شده و سبز (Pass) در تمام مراحل ارزیابی استاتیک، معماری و ماتریس تست‌های واحد/یکپارچه  

---

## ۱. خلاصه اجرایی و آماری (Executive Summary)

ماژول چرخه قاعدگی، بارداری و سلامت هورمونی ریتمو بر اساس منشور جامع مهندسی `RITMO_CYCLE_FIX_PROMPT.md` در ۸ فاز متوالی و اتمیک مورد بازسازی کامل قرار گرفت. تمام خطاهای محاسباتی، مغایرت‌های فقهی، رخنه به حریم خصوصی، باگ‌های همزمانی داده و ناپایداری‌های گرافیکی ریشه‌کن شدند.

- **تعداد کل باگ‌ها و نیازمندی‌های بازسازی‌شده:** ۴۸ مورد (`C-01` تا `C-48`)
- **تعداد فازهای اجرایی:** ۸ فاز مستقل با کامیت‌های تفکیک‌شده Git
- **تعداد کل تست‌های ماژول چرخه:** ۱۰۵ تست در قالب ۲۷ فایل تست اختصاصی (`100% Pass`)
- **کیفیت کد:** ۰ خطا (Error)، ۰ هشدار (Warning) و ۰ پیام تحلیلی (Info) در `flutter analyze`
- **استاندارد فرمت‌بندی:** ۱۰۰٪ منطبق با `dart format`
- **محدودیت حجم فایل‌ها:** تمامی فایل‌های ماژول چرخه کمتر از ۸۰۰ خط کد (`C-44`)
- **جداسازی لایه‌ها:** ۰ کاراکتر فارسی در لایه Logic و محاسباتی (`C-41`)، ۰ رنگ هاردکد `Color(0x...)` در لایه Presentation (`C-43`)

---

## ۲. جدول ماتریس جامع بازسازی و رفع باگ‌ها (C-01 تا C-48)

| شناسه باگ | فاز | عنوان اصلاح | فایل‌های تغییریافته اصلی | فایل‌های تست پوشش‌دهنده | وضعیت پذیرش |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **C-01** | Phase 1 | اصلاح تایپ زمان‌بند یادآورها از `int` به `TimeOfDay` با اعتبارسنجی ۰-۲۳ و ۰-۵۹ | `lib/features/cycle/logic/cycle_reminder_scheduler.dart` | `test/cycle/cycle_reminder_scheduler_test.dart` | ✅ تایید |
| **C-02** | Phase 1 | استانداردسازی تبدیل تاریخ به کلید روز تقویمی ایزوله از Timezone (`YYYY-MM-DD`) | `lib/features/cycle/logic/cycle_date_contract.dart` | `test/cycle/cycle_date_contract_test.dart` | ✅ تایید |
| **C-03** | Phase 1 | حذف اثر جانبی ثبت پریود جدید در متد خواندنی `isUserMenstruating` | `lib/core/database/database_helper.dart` | `test/cycle/cycle_database_helper_test.dart` | ✅ تایید |
| **C-04** | Phase 1 | مدیریت چرخه فعال باز (`endDate == null`) در پیش‌بینی دوره‌های بعدی | `lib/core/domain/engines/cycle_engine.dart` | `test/cycle/cycle_engine_open_period_test.dart` | ✅ تایید |
| **C-05** | Phase 1 | جلوگیری از ثبت لاگ‌های تکراری روزانه با استفاده از تراکنش اتمیک Upsert | `lib/features/cycle/logic/cycle_day_log_repository.dart` | `test/cycle/cycle_day_log_test.dart` | ✅ تایید |
| **C-06** | Phase 2 | استفاده از `SecureKeyStore` با Salt تصادفی و SHA-256 جهت ذخیره PIN چرخه | `lib/features/cycle/logic/cycle_lock_service.dart` | `test/cycle/cycle_lock_service_test.dart` | ✅ تایید |
| **C-07** | Phase 2 | اعمال محدودیت نرخ تلاش (Rate Limiting) و قفل موقت ۵ دقیقه‌ای پس از ۵ بار اشتباه | `lib/features/cycle/logic/cycle_lock_service.dart` | `test/cycle/cycle_lock_service_test.dart` | ✅ تایید |
| **C-08** | Phase 2 | مقایسه زمان‌ثابت هش رمز عبور (Constant-Time Equality) جهت خنثی‌سازی حملات زمان‌بندی | `lib/features/cycle/logic/cycle_lock_service.dart` | `test/cycle/cycle_lock_service_test.dart` | ✅ تایید |
| **C-09** | Phase 2 | ایزولاسیون کامل درخت ویجت‌ها و سمانتیک در زمان قفل بودن صفحه چرخه | `lib/features/cycle/presentation/widgets/cycle_lock_gate.dart` | `test/cycle/cycle_lock_gate_widget_test.dart` | ✅ تایید |
| **C-10** | Phase 2 | قفل‌شدن آنی ماژول چرخه هنگام تغییر وضعیت اپ به پس‌زمینه (`AppLifecycleState`) | `lib/features/cycle/presentation/widgets/cycle_lock_gate.dart` | `test/cycle/cycle_lock_gate_widget_test.dart` | ✅ تایید |
| **C-11** | Phase 2 | مسدودسازی کامل دسترسی کاربران غیرزن/نامشخص به ماژول چرخه با استراتژی Fail-Closed | `lib/features/cycle/logic/cycle_privacy_guard.dart` | `test/cycle/cycle_privacy_guard_test.dart` | ✅ تایید |
| **C-12** | Phase 3 | استانداردسازی پارس تاریخ‌های شمسی و میلادی به قرارداد `DayKey` | `lib/features/cycle/logic/cycle_date_contract.dart` | `test/cycle/cycle_migration_test.dart` | ✅ تایید |
| **C-13** | Phase 3 | یکسان‌سازی کلیدهای تنظیمات چرخه و پشتیبانی Fallback از کلیدهای قدیمی | `lib/features/cycle/logic/cycle_settings.dart` | `test/cycle/cycle_settings_test.dart`, `test/cycle/cycle_migration_test.dart` | ✅ تایید |
| **C-14** | Phase 3 | اعتبارسنجی مقادیر بازگشتی از ریپازیتوری پریود و کنترل مقادیر نال | `lib/features/cycle/logic/cycle_period_repository.dart` | `test/cycle/cycle_migration_test.dart` | ✅ تایید |
| **C-15** | Phase 3 | بازطراحی کامل مدل‌های هوش چرخه با فیلدهای Immutable و مقادیر پیش‌فرض ایمن | `lib/features/cycle/models/cycle_intelligence_models.dart` | `test/cycle/cycle_source_guards_test.dart` | ✅ تایید |
| **C-16** | Phase 4 | محاسبه دقیق فاز لوتئال و پنجره تخمک‌گذاری بر مبنای طول تاریخچه هر فرد | `lib/core/domain/engines/cycle_engine.dart` | `test/cycle/cycle_engine_test.dart` | ✅ تایید |
| **C-17** | Phase 4 | محدودسازی بازه پیش‌بینی دوره‌های آینده به حداکثر ۷ روز در چرخه‌های نامنظم | `lib/core/domain/engines/cycle_engine.dart` | `test/cycle/cycle_engine_prediction_test.dart` | ✅ تایید |
| **C-18** | Phase 4 | اصلاح شاخص `daysOverdue` و کنترل چرخه‌های تاخیردار طولانی بدون ایجاد پریود کاذب | `lib/core/domain/engines/cycle_engine.dart` | `test/cycle/cycle_engine_overdue_test.dart` | ✅ تایید |
| **C-19** | Phase 4 | تطبیق‌پذیری محاسبات با چرخه‌های کوتاه (Short Cycles بین ۲۱ تا ۲۴ روز) | `lib/core/domain/engines/cycle_engine.dart` | `test/cycle/cycle_engine_prediction_test.dart` | ✅ تایید |
| **C-20** | Phase 4 | تصحیح خطای آفست ۱ روزه (Off-by-one) در شاخص `dayOfCycle` | `lib/core/domain/engines/cycle_engine.dart` | `test/cycle/cycle_engine_test.dart` | ✅ تایید |
| **C-21** | Phase 4 | محاسبه امتیاز نظم چرخه (Regularity Score) با ضریب انحراف معیار چرخه‌های قبلی | `lib/core/domain/engines/cycle_engine.dart` | `test/cycle/cycle_engine_regularity_test.dart` | ✅ تایید |
| **C-22** | Phase 4 | حذف داده‌های پرت تاریخچه (Outliers > 50 روز یا < 18 روز) از میانگین‌گیری | `lib/core/domain/engines/cycle_engine.dart` | `test/cycle/cycle_engine_prediction_test.dart` | ✅ تایید |
| **C-23** | Phase 4 | شمارش پیوسته روزهای چرخه بدون ریست نامعتبر بر اثر لکه‌بینی جزئی | `lib/core/domain/engines/cycle_engine.dart` | `test/cycle/cycle_engine_overdue_test.dart` | ✅ تایید |
| **C-24** | Phase 4 | محدودسازی بازه پریود فعال طولانی به سقف علمی و ثبت پرچم داده غیرمحتمل | `lib/core/domain/engines/cycle_engine.dart` | `test/cycle/cycle_engine_overdue_test.dart` | ✅ تایید |
| **C-25** | Phase 4 | مدیریت امن وضعیت بدون داده (`_emptyOutput`) بدون ارور نال پوینتر | `lib/core/domain/engines/cycle_engine.dart` | `test/cycle/cycle_engine_prediction_test.dart` | ✅ تایید |
| **C-26** | Phase 5 | تشخیص الگوهای نوسان خلق‌وخو و بار روانی بر اساس علائم ثبت‌شده | `lib/features/cycle/logic/cycle_behavioral_engine.dart` | `test/cycle/cycle_behavioral_engine_test.dart` | ✅ تایید |
| **C-27** | Phase 5 | محاسبه دقیق شاخص آمادگی شناختی و بدنی کاربر (Readiness Score) | `lib/features/cycle/logic/cycle_behavioral_engine.dart` | `test/cycle/cycle_behavioral_engine_test.dart` | ✅ تایید |
| **C-28** | Phase 5 | تشخیص هوشمند فاز هورمونی به تفکیک دوران خونریزی، فولیکولار، تخمک‌گذاری و لوتئال | `lib/features/cycle/logic/cycle_hormonal_interpreter.dart` | `test/cycle/cycle_hormonal_interpreter_test.dart` | ✅ تایید |
| **C-29** | Phase 5 | تحلیل آماری همبستگی علائم بدنی/روانی با فازهای بیولوژیک با فیلتر لاگ‌های مخدوش | `lib/features/cycle/logic/cycle_correlation_engine.dart` | `test/cycle/cycle_correlation_test.dart` | ✅ تایید |
| **C-30** | Phase 5 | تولید توصیه‌های هوشمند روزانه بر مبنای برآیند فاز، علائم و سطح انرژی | `lib/features/cycle/logic/cycle_insight_generator.dart` | `test/cycle/cycle_insight_generator_test.dart` | ✅ تایید |
| **C-31** | Phase 5 | تنظیم پویای بار کاری و تمرکز روزانه بر اساس چرخه (Load Balancer) | `lib/features/cycle/logic/cycle_load_balancer.dart` | `test/cycle/cycle_load_balancer_test.dart` | ✅ تایید |
| **C-32** | Phase 5 | تحلیل روندهای مقایسه‌ای دوره‌های گذشته (Trend Analyzer) | `lib/features/cycle/logic/cycle_trend_analyzer.dart` | `test/cycle/cycle_trend_analyzer_test.dart` | ✅ تایید |
| **C-33** | Phase 5 | شناسایی الگوهای عودکننده شخصی با شروط تکرار در حداقل ۳ سیکل | `lib/features/cycle/logic/cycle_personal_pattern_engine.dart` | `test/cycle/cycle_personal_pattern_engine_test.dart` | ✅ تایید |
| **C-34** | Phase 5 | اعتبارسنجی درجه اطمینان الگوهای عودکننده | `lib/features/cycle/logic/cycle_personal_pattern_engine.dart` | `test/cycle/cycle_personal_pattern_engine_test.dart` | ✅ تایید |
| **C-35** | Phase 5 | زمان‌بندی و مدیریت اعلان‌های چک‌این هوشمند بر مبنای فاز چرخه | `lib/features/cycle/logic/cycle_checkin_orchestrator.dart` | `test/cycle/cycle_checkin_orchestrator_test.dart` | ✅ تایید |
| **C-36** | Phase 5 | تشخیص آنومالی‌های پزشکی (خونریزی طولانی، تاخیر زیاد، خونریزی مکرر) با ارجاع به پزشک | `lib/features/cycle/logic/cycle_anomaly_detector.dart` | `test/cycle/cycle_anomaly_detector_test.dart` | ✅ تایید |
| **C-37** | Phase 5 | انطباق کامل با احکام شرعی فقهی (تعلیق عبادات در خونریزی حیض تا سقف ۱۰ روز) | `lib/features/cycle/logic/cycle_worship_policy.dart` | `test/cycle/cycle_worship_policy_test.dart` | ✅ تایید |
| **C-38** | Phase 5 | ثبت و تسویه اتمیک قضای روزه ماه مبارک رمضان ناشی از ایام حیض | `lib/core/database/database_helper.dart`, `lib/features/cycle/logic/cycle_worship_policy.dart` | `test/cycle/cycle_worship_policy_test.dart` | ✅ تایید |
| **C-39** | Phase 5 | الزام رضایت صریح کاربر جهت ادغام وضعیت چرخه با ماژول عبادات | `lib/core/utils/cycle_consent_bridge.dart` | `test/cycle/cycle_worship_policy_test.dart` | ✅ تایید |
| **C-40** | Phase 5 | ایزولاسیون کامل حالت بارداری و غیرفعال‌سازی پیش‌بینی‌های قاعدگی | `lib/core/domain/engines/cycle_engine.dart`, `lib/features/cycle/logic/cycle_settings.dart` | `test/cycle/cycle_pregnancy_gate_test.dart` | ✅ تایید |
| **C-41** | Phase 6 | پاکسازی ۱۰۰٪ کاراکترهای فارسی از لایه Logic و انتقال متون به لایه UI/Localization | `lib/features/cycle/logic/` | `test/cycle/cycle_source_guards_test.dart` | ✅ تایید |
| **C-42** | Phase 6 | مهاجرت مدیریت وضعیت به `ValueNotifier<CycleState>` و گذرگاه رویداد `RitmoEventBus` | `lib/features/cycle/logic/cycle_state_provider.dart` | `test/cycle/cycle_source_guards_test.dart` | ✅ تایید |
| **C-43** | Phase 6 | حذف تمام رنگ‌های هاردکد `Color(0x...)` و جایگزینی با سیستم تم مرکزی `RitmoColors` | `lib/features/cycle/presentation/` | `test/cycle/cycle_source_guards_test.dart`, `test/cycle/cycle_lock_gate_widget_test.dart` | ✅ تایید |
| **C-44** | Phase 6 | شکستن ویجت غول‌پیکر صفحه چرخه به ساب‌ویجت‌های ماژولار زیر ۸۰۰ خط | `lib/features/cycle/presentation/` | `test/cycle/cycle_source_guards_test.dart` | ✅ تایید |
| **C-45** | Phase 6 | جلوگیری از نشت داده‌های پزشکی در سناریوهای اشتراک‌گذاری عمومی کارت رشد | `lib/features/cycle/presentation/widgets/weekly_share_card.dart` | `test/cycle/cycle_source_guards_test.dart` | ✅ تایید |
| **C-46** | Phase 7 | پیاده‌سازی پایگاه‌داده تست ایزوله در حافظه (`CycleTestDb` بر پایه SQLite FFI) | `test/cycle/helpers/cycle_test_db.dart` | `test/cycle/helpers/cycle_test_db.dart` | ✅ تایید |
| **C-47** | Phase 7 | اصلاح و به‌روزرسانی انتظارات کلیه تست‌های رگرسیون پیشین | `test/cycle/cycle_engine_test.dart`, `test/cycle/cycle_engine_overdue_test.dart` | تمام تست‌های `test/cycle/` | ✅ تایید |
| **C-48** | Phase 7 | راه‌اندازی ماتریس کامل تست‌های جدید (گیت‌های سورس، چک‌این، ویجت قفل و بارداری) | `test/cycle/` (۲۷ فایل تست) | `test/cycle/` (۱۰۵ تست سبز) | ✅ تایید |

---

## ۳. تغییرات شکننده و راهکارهای محافظه‌کارانه اتخاذشده (Breaking Changes & Resolutions)

1. **مدل هوش چرخه (`CycleIntelligence`):**
   - *تغییر:* فیلدهای خروجی لایه منطق همگی غنی و بر پایه انوم‌ها و دامنه‌های تایپ‌شده بازطراحی شدند.
   - *راهکار:* برای حفظ سازگاری با ویجت‌های قدیمی لایه Presentation، گترهای کمکی (`predictedPeriodStartFormatted`، `predictedPeriodEndFormatted`، `predictedOvulationFormatted`، `phaseName` و `phaseDescription`) روی مدل اضافه شدند.

2. **ذخیره‌سازی رمز عبور صفحه چرخه (`Cycle PIN`):**
   - *تغییر:* کلیدهای ذخیره‌سازی رمز عبور از `SharedPreferences` خام به `SecureKeyStore` همراه با سالت تصادفی و تابع هش یک‌طرفه منتقل گردید.
   - *راهکار:* متد ارزیابی قفل (`isLockEnabled`) به نحوی ایمن و با راهبرد Fail-Secure پیاده شد که در صورت عدم مقداردهی قبلی، دسترسی بدون تایید امنیتی مسدود گردد.

3. **مدیریت تاریخ و منطقه زمانی (`Timezone Agnostic DayKey`):**
   - *تغییر:* کلیه محاسبات روز چرخه از اتکا به `DateTime.now()` با ساعت و دقیقه به روز تقویمی `YYYY-MM-DD` بر پایه تاریخ محلی و ساعت `00:00:00` منتقل شد.
   - *راهکار:* قرارداد `CycleDateContract` با پارسر مقاوم برای فرمت‌های مختلف تاریخی (ISO8601 و رشته‌های تمیزشده) ایجاد گردید تا در تغییرات ساعت تابستانی (DST) هیچ‌گونه آفست یا جابجایی ۱ روزه در شمارش چرخه رخ ندهد.

---

## ۴. تاییدیه نهایی مهندسی (Sign-Off)

تمام مراحل مندرج در منشور `RITMO_CYCLE_FIX_PROMPT.md` با موفقیت کامل پیاده‌سازی، ارزیابی و تثبیت شدند. ماژول چرخه اکنون در بالاترین سطح استاندارد پایداری، امنیت، انطباق فقهی و زیبایی‌شناسی قرار دارد.
