# قرارداد داده و معماری حالت بارداری (Pregnancy Data Contract)

این سند مرجع رسمی و فنی برای ذخیره‌سازی، خواندن، یکپارچگی و جریان‌های دادهٔ حالت بارداری در پروژه ریتمو است.

---

## ۱. جدول کامل کلیدهای تنظیمات بارداری (`preg_*` و پرچم‌های همگام)

| کلید در `app_settings` | نوع داده | مقدار پیش‌فرض | محل‌های نوشتن (فقط از فاساد) | محل‌های خواندن و استفاده |
|---|---|---|---|---|
| `preg_start_date` | `String` (YYYY-MM-DD) | — | `PregnancySettings.saveProfile` | هدر بارداری، محاسبهٔ سن، رندرر حلقه |
| `preg_due_date` | `String` (YYYY-MM-DD) | — | `PregnancySettings.saveProfile` | هدر بارداری، شمارش معکوس، کارت امروز |
| `preg_edd_source` | `String` (lmp/conception/ultrasound) | `lmp` | `PregnancySettings.saveProfile` | نشانگر مبنا در تنظیمات و کارت اطلاعات |
| `preg_tone` | `String` (warm/medical/calm/neutral) | `warm` | `PregnancySettings.saveProfile` | پیام‌های روزانه، راهنمایی‌های هوشمند |
| `preg_age_unit` | `String` (weeks/months) | `weeks` | `PregnancySettings.saveProfile` | هدر بارداری (هفته و روز یا ماه و هفته) |
| `preg_is_multiple` | `String` (true/false) | `false` | `PregnancySettings.saveProfile` | کارت‌های مراقبت و توصیه‌های چندقلویی |
| `preg_is_high_risk` | `String` (true/false) | `false` | `PregnancySettings.saveProfile` | هشدارها و توصیه‌های پرخطر |
| `preg_section_hidden` | `String` (true/false) | `false` | `PregnancySettings.saveProfile` | مخفی‌سازی بخش بارداری از داشبورد |
| `preg_mask_notifications` | `String` (true/false) | `true` | `PregnancySettings.saveProfile` | زمان‌بند اعلان‌ها (قاعدهٔ ادغام حریم خصوصی) |
| `preg_lock_enabled` | `String` (true/false) | `false` | `PregnancySettings.saveProfile` | گیت قفل مستقل بارداری (`PregnancyLockGate`) |
| `preg_cycle_resume_reminder`| `String` (epoch ms) | — | `PregnancySettings.saveSetting` | زمان‌بند یادآوری ۴۰ روز پس از زایمان |
| `preg_kick_target_count` | `String` (int) | `10` | `PregnancySettings.saveSetting` | شمارشگر لگد، تب ثبت لگد |
| `preg_kick_window_minutes` | `String` (int) | `120` | `PregnancySettings.saveSetting` | محدودیت زمانی جلسهٔ لگدشماری |
| `preg_kick_baseline_compare`| `String` (true/false) | `true` | `PregnancySettings.saveSetting` | تحلیل مقایسه‌ای الگوی حرکات جنین |
| `preg_visit_reminder_lead_days`| `String` (int) | `3` | `PregnancySettings.saveSetting` | زمان‌بند اعلان‌های ویزیت و مراقبت |
| `preg_reminder_hour` | `String` (int 0..23) | `9` | `PregnancySettings.saveSetting` | زمان‌بند اعلان‌های روزانهٔ بارداری |
| `preg_setup_done` | `String` (true/false) | `false` | `PregnancyOnboardingController` | اعتبارسنجی تکمیل آنبوردینگ بارداری |
| `preg_show_countdown` | `String` (true/false) | `true` | `PregnancySettings.saveSetting` | نمایش شمارش معکوس روزها در هدر |
| `preg_supplement_reminder` | `String` (true/false) | `true` | `PregnancySettings.saveSetting` | زمان‌بند اعلان‌های مکمل و ویتامین روزانه |
| `preg_kick_reminder` | `String` (true/false) | `true` | `PregnancySettings.saveSetting` | زمان‌بند اعلان‌های لگدشماری (هفته ۲۸+) |
| `preg_prev_consent_reminders` | `String` (true/false) | — | `PregnancyOnboardingController` | بازگردانی موافقت یادآوری در خروج |
| `preg_prev_consent_worship` | `String` (true/false) | — | `PregnancyOnboardingController` | بازگردانی موافقت عبادات در خروج |
| `preg_prev_consent_dashboard` | `String` (true/false) | — | `PregnancyOnboardingController` | بازگردانی موافقت داشبورد در خروج |
| `preg_migration_prompt_shown` | `String` (true/false) | `false` | `CycleScreen._checkPregnancyMigrationPrompt` | نمایش یک‌بارهٔ دیالوگ مهاجرت کاربران قدیمی |
| `preg_hospital_bag` | `String` (JSON) | — | `PregnancySettings.saveSetting` | ذخیره وضعیت چک‌لیست ساک بیمارستان |
| `cycle_pregnancy_mode` | `String` (true/false) | `false` | `PregnancySettings.setPregnancyActive` | پرچم اصلی حالت بارداری |
| `pregnancy_mode` | `String` (true/false) | `false` | `PregnancySettings.setPregnancyActive` | پرچم سازگاری موتور چرخه |
| `cycle_is_pregnant` | `String` (true/false) | `false` | `PregnancySettings.setPregnancyActive` | پرچم ارث‌بری UI و داشبورد |

---

## ۲. قانون یگانهٔ نویسنده (Single Writer Rule)

> [!IMPORTANT]
> **تمام نوشتن‌ها به `app_settings` برای کلیدهای بارداری باید منحصراً از طریق متدهای کلاس فاساد `PregnancySettings` انجام شوند.**

- هیچ ویجت، کنترلر یا ریپازیتوری خارجی مجاز به اجرای `db.insert('app_settings', {'key': 'preg_...'})` یا `db.update` خام نیست.
- تمام به‌روزرسانی‌های پرچم بارداری منحصراً از متد `PregnancySettings.setPregnancyActive(bool)` انجام می‌شوند که هر سه پرچم همگام را به صورت اتمیک در تراکنش ثبت می‌کند.
- تمام تنظیمات کلی و پروفایل از طریق `PregnancySettings.saveProfile` یا `PregnancySettings.saveSetting` نوشته می‌شوند.
- نگهبان تست `test/guards/pregnancy_keys_guard_test.dart` درستی این قانون را به صورت مستمر تضمین می‌کند.

---

## ۳. قانون وابستگی و اعتبار تاریخ‌ها (Date Validity Rule)

> [!IMPORTANT]
> **پرچم فعال بودن بارداری بدون تاریخ شروع و زایمان معتبر فاقد اثر عملیاتی است.**

- یک پروفایل بارداری در صورتی معتبر و قابل استفاده (`isPregnancyUsable`) است که:
  1. `CycleSettings.isPregnancyMode(settings) == true`
  2. `PregnancySettings.hasValidDates(settings) == true` (فاصلهٔ تاریخ LMP تا EDD بین ۲۰۰ تا ۳۲۰ روز باشد).
- اگر پرچم روشن باشد ولی تاریخ‌ها ثبت نشده باشند:
  - هرگز تاریخ امروز به عنوان فالبک استفاده نمی‌شود (جلوگیری از هفتهٔ صفر اشتباه).
  - صفحهٔ چرخه کارت هشدار «اطلاعات بارداری ناقص است» را با دکمهٔ «تکمیل راه‌اندازی بارداری» نمایش می‌دهد.
  - دیالوگ هدایت مهاجرت برای کاربران قدیمی یک‌بار نشان داده می‌شود.

---

## ۴. جدول مسیرهای ۴گانهٔ ورود به بارداری

| مسیر ورود | نقطهٔ شروع در برنامه | رفتار و دیالوگ | اکشن نهایی |
|---|---|---|---|
| **۱. پنل تنظیمات چرخه** | دکمهٔ سوئیچ بارداری در `cycle_settings_panel.dart` | باز کردن `PregnancyOnboardingShell` | ذخیرهٔ اتمیک پروفایل، غیرفعال‌سازی موقت پیش‌بینی چرخه |
| **۲. گام ۲ آنبوردینگ چرخه** | انتخاب گزینهٔ «الان باردارم» در آنبوردینگ اولیه | هدایت مستقیم به آنبوردینگ بارداری | راه‌اندازی همزمان چرخه و پروفایل بارداری |
| **۳. حالت خالی چرخه** | کارت حالت خالی چرخه (بدون دورهٔ ثبت‌شده) | دکمهٔ میانبر «باردار هستید؟» | باز کردن آنبوردینگ بارداری با لغو چرخهٔ خالی |
| **۴. دکمهٔ ترمیم وضعیت ناقص** | کارت هشدار اطلاعات ناقص در `cycle_screen.dart` | لمس دکمهٔ «تکمیل راه‌اندازی بارداری» | باز کردن آنبوردینگ بارداری در حالت ویرایش/تکمیل |
