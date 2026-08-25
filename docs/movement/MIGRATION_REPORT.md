# گزارش رسمی مهاجرت پایگاه‌داده — فاز C (M1 تا M7)

**تاریخ اجرا:** ۲۵ اوت ۲۰۲۶  
**شماره نسخهٔ مایگریشن:** `MigrationV121SportsUnification` (نسخه ۱۲۱)  
**وضعیت:** کامل، مستقل و بدون افت داده (Zero Data Loss)

---

## ۱. جدول وضعیت تغییرات اسکیمای داده (M1 تا M7)

| کد | هدف مهاجرت | منبع قبلی | مقصد واحد | سازگاری با گذشته |
|:---|:---|:---|:---|:---:|
| **M1** | ستون‌ها و ایندکس‌های تقویمی نسخه | `ss_session_prescription` | `ss_session_prescription` + `kindCode`, `movedToDateIso`, `intensityTier`, `targetRpe`, `coachNoteFa`, `actualRpe`, `actualRir`, `actualFeeling`, `dayOfWeekSat0` | ۱۰۰٪ |
| **M2** | تبدیل روتین‌های فیتنس به اسلات تقویم | `routine_completions` (category='fitness'/'sports') | اسلات‌های انجام‌شده در `ss_session_prescription` | ۱۰۰٪ |
| **M3** | تجمیع تاریخچه جلسات | `ss_workout_session_log` | منبع واحد `movement_sessions` | ۱۰۰٪ |
| **M4** | تجمیع ست‌های ثبت‌شده | `ss_workout_set_log` | منبع واحد `ss_session_set_log` | ۱۰۰٪ |
| **M5** | رکوردهای شخصی PR | `ss_exercise_pr` | منبع واحد `movement_pr` (با کلید `EXERCISE:id`) | ۱۰۰٪ |
| **M6** | اصلاح کلید خارجی ست‌ها | ارجاع به لاگ قدیمی | کلید خارجی استاندارد به `movement_sessions(id)` | ۱۰۰٪ |
| **M7** | رضایت چرخه و اعلان صوتی | پروفایل کاربر | ستون‌های `voiceCuesEnabled` و `cycleConsentGranted` در `ss_user_profile` | ۱۰۰٪ |

---

## ۲. گزارش تست‌های مهاجرت

- تست نصب تازه (`Fresh Install`): ایجاد خودکار کلیه جداول واحد با ایندکس‌های بهینه
- تست ارتقای پایگاه‌داده قدیمی (`v120 -> v121`): اجرای موفقیت‌آمیز `MigrationV121SportsUnification` از طریق `MigrationRunner`
- حفظ ۱۰۰٪ سوابق بدون نیاز به بازتنظیم یا پیام ریست دیتابیس
