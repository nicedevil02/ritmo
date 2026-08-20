# دفترچه ثبت رفع باگ تشخیص پاسخ پل وب چت‌جی‌پی‌تی (DET-01 تا DET-36)

> **سند مرجع:** itmo-webbridge-detection-fix-prompt.md
> **نسخه هدف پل:** ChatGptJsInjector.bridgeVersion = 9

---

## جدول وضعیت تسک‌ها

| ID | عنوان | فاز | وضعیت | commit | یادداشت |
|----|------|-----|-------|--------|---------|
| DET-01 | دفترچه و کلید source روی همهٔ پیلودها | A | DONE | f85ac419 | ساخت لاگ‌بوک و تضمین وجود source در تمام رویدادها |
| DET-02 | رویدادهای مسیر ارسال | A | DONE | f84ac071 | رویدادهای prompt_typed، send_clicked، send_fallback_enter و composer_not_found اضافه شدند |
| DET-03 | تیک دوره‌ای واچر | A | DONE | 5547eaf7 | ارسال watcher_tick هر ۵ ثانیه یک‌بار با تمام آمارهای DOM |
| DET-04 | فازبندی selector_health | A | DONE | dbd9502f | ارسال selector_health در ۴ فاز boot، pre_send، post_first_text و pre_timeout |
| DET-05 | افزایش نسخهٔ بریج به ۹ | A | DONE | 5f0b3f0f | ارتقای نسخه پروتکل بریج به ۹ در دارت و جاوا اسکریپت |
| DET-06 | افزودن case error | B | DONE | a37a60cf | مدیریت صریح رویداد خطا در JS و فیل‌کردن فوری استریم با WebBridgeException |
| DET-07 | افزودن case cloudflare_resolved | B | DONE | 97bfad7a | مدیریت رویداد حل کلودفلر و بازگردانی خودکار وضعیت به ready |
| DET-08 | دام ایمنی رویداد ناشناخته | B | DONE | ee5078ff | ثبت رویدادهای ناشناخته با سطح error و متن خام در لاگ و فیل‌کردن استریم در صورت خطا |
| DET-09 | تست پوشش تاکسونومی | B | DONE | 6bf64094 | تست تطابق خودکار ۱۰۰٪ تمام رویدادهای JS با پارسر دارت |
| DET-10 | حذف cloudflare_resolved کاذب | B | DONE | 57f8d1ec | جلوگیری از ارسال کاذب cloudflare_resolved در بوت اولیه و ارسال فقط پس از چالش واقعی |
| DET-11 | حمل isWarm در ready | C | DONE | pending | پشتیبانی از فیلدهای isWarm، currentPath و hasComposer در BridgeReadyEvent |
| DET-12 | گارد generating در هندلر ready | C | DONE | 6090ca4b | جلوگیری کامل از ریست شدن وضعیت generating در اثر رویدادهای ready ناوبری SPA |
| DET-13 | مستقل‌کردن چک‌پوینت‌ها | C | DONE | fdac94be | حذف گیت وضعیت از اجرای چک‌پوینت‌ها و محدودسازی صرفاً به یکسانی کنترلر استریم با ثبت دقیق trace |
| DET-14 | شرط تحویل برداشت دستی | C | DONE | ce85dd6c | تحویل خروجی harvest_result به استریم بر اساس باز بودن کنترلر استریم نه وضعیت، با ثبت دقیق لاگ رد |
| DET-15 | گارد مرکزی خروج از وضعیت | C | DONE | 68f2485b | ایجاد گارد مرکزی در _setStatus برای جلوگیری از هرگونه خروج غیرمجاز از generating در حین باز بودن استریم |
| DET-16 | اصلاح تطبیق endpoint | D | DONE | 602add47 | گسترش ریجکس تطبیق endpointهای مکالمه در fetch/XHR/EventSource و افزودن لاگ رویداد fetch_matched |
| DET-17 | پوشش fetch با شیء Request | D | DONE | 80e6cfd2 | پشتیبانی از ورودی Request Object در هوک fetch و استخراج صحیح URL و متد HTTP |
| DET-18 | خوانندهٔ SSE در هوک زودهنگام | D | DONE | pending | تعبیهٔ کامل پارسر خطوط SSE و ریدر استریم در earlyHookScript برای عملکرد مستقل از زمان تزریق اسکریپت اصلی |
| DET-19 | ترجیح SSE بر DOM | D | TODO | | |
| DET-20 | حالت پایدار واچر | E | TODO | | |
| DET-21 | resume ایدمپوتنت | E | TODO | | |
| DET-22 | دباونس resume | E | TODO | | |
| DET-23 | شمارش بارگذاری سرد | E | TODO | | |
| DET-24 | پذیرش شناسهٔ خالی | E | TODO | | |
| DET-25 | انتخاب هوشمند دکمهٔ ارسال | F | TODO | | |
| DET-26 | تأیید واقعی ارسال | F | TODO | | |
| DET-27 | خط مبنای غنی‌تر پیش از ارسال | F | TODO | | |
| DET-28 | تشخیص نشست مهمان | G | TODO | | |
| DET-29 | حذف src=unknown | G | TODO | | |
| DET-30 | چک‌پوینت سوم | H | TODO | | |
| DET-31 | شکست سریع | H | TODO | | |
| DET-32 | حذف اعداد خام از JS | H | TODO | | |
| DET-33 | پنجرهٔ سکوت پایان | H | TODO | | |
| DET-34 | روشن‌کردن استریم زنده | I | TODO | | |
| DET-35 | حذف لودینگ بی‌پایان | I | TODO | | |
| DET-36 | بازرسی نهایی | J | TODO | | |

---

## واگرایی از پرامپت

| شماره تسک | آنچه پرامپت گفته بود | آنچه واقعاً انجام شد | دلیل |
|-----------|----------------------|----------------------|------|
| - | - | - | - |

---

## نتیجهٔ نهایی DoD

(پس از تکمیل تسک DET-36 پر می‌شود)

---

## موارد باقی‌مانده

(هر موضوع خارج از دامنه که هنگام اجرا مشاهده شد در این بخش ثبت می‌شود)
