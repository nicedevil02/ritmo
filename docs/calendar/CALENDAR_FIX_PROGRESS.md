# پیشرفت بازسازی و رفع باگ‌های تقویم (CAL-01 تا CAL-60)

| ID | عنوان | فاز | وضعیت | commit | یادداشت |
|---|---|:---:|:---:|:---:|---|
| CAL-01 | یک سازندهٔ کلید تاریخ برای کل اپ (DateKey) | A | DONE | 07876d0 | ایجاد DateKey تک‌منبع با تست‌های واحد |
| CAL-02 | جایگزینی همهٔ سازنده‌های کلید تاریخ با DateKey | A | DONE | d037011 | حذف _dateStr/_formatDateKey و یکسان‌سازی کلیدها با DateKey |
| CAL-03 | یک پارسر زمان با معناشناسی درست (TimeOfDayMinutes) | A | DONE | c277443 | ایجاد TimeOfDayMinutes با پشتیبانی ارقام فارسی/عربی و اعتبارسنجی بازه |
| CAL-04 | حذف سه پارسر زمان تکراری | A | DONE | edb1951 | حذف پارسرهای تکراری و یکپارچه‌سازی با TimeOfDayMinutes |
| CAL-05 | یک منبع برای ثابت‌های مدت و زمان پیش‌فرض | A | DONE | 75135f2 | یکپارچه‌سازی ثابت‌های مدت و زمان پیش‌فرض در CalendarDefaults |
| CAL-06 | RitmoLog به‌جای debugPrint | A | DONE | 240eb0a | انتقال کامل لاگ‌های تقویم و اجندا به خط لوله RitmoLog |
| CAL-07 | پیام‌های خطای فارسی و بدون افشای استثنا | A | DONE | 0d21123 | ایجاد CalendarMessagesFa و حذف افشای استثنا از رشته‌های خطا |
| CAL-08 | نرمال‌سازی selectedDate به نیمه‌شب | A | DONE | 7459a86 | نرمال‌سازی کامل selectedDate به نیمه‌شب محلی در همه مقیاس‌ها و ناوبری‌ها |
| CAL-09 | upsert ادغامی: توقف نابودی ستون‌های همسایه | B | DONE | 0b66b20 | بازنویسی upsert به صورت تراکنشی و ادغامی بدون نابودی ستون‌ها |
| CAL-10 | snapshot خواندن override برای بازگردانی درست | B | DONE | ff2dce3 | افزودن readAllFuture و restoreAll به مخزن override برای بازگردانی دقیق |
| CAL-11 | بازگردانی مبتنی بر snapshot در MoveItemCommand و ResizeItemCommand | B | DONE | pending | بازگردانی snapshot-based در Move/Resize برای جلوگیری از پاک شدن overrideهای پیشین |
| CAL-12 | allFutureDays: snapshot و transaction برای removeAllFuture | B | TODO | - | - |
| CAL-13 | حذف کلید برهنهٔ sourceId در نگاشت override | B | TODO | - | - |
| CAL-14 | پایهٔ مشترک دستورات تقویم: بی‌اعتبارسازی کش اجباری | B | TODO | - | - |
| CAL-15 | skipItem برای دامنه‌های غیرروتین | B | TODO | - | - |
| CAL-16 | postponeItem برای همه دامنه‌ها | B | TODO | - | - |
| CAL-17 | توکن نسل بارگذاری برای جلوگیری از نوشتن بی‌ترتیب | C | TODO | - | - |
| CAL-18 | حذف شاخهٔ مردهٔ agenda و یک تعریف واحد برای پنجرهٔ اجندا | C | TODO | - | - |
| CAL-19 | پنجرهٔ بارگذاری صریح و عبور isBackgroundRefresh | C | TODO | - | - |
| CAL-20 | تعویض مقیاس: دادهٔ مقیاس قبلی پاک شود | C | TODO | - | - |
| CAL-21 | یک fallback واحد برای snapshot تهی | C | TODO | - | - |
| CAL-22 | loadDefaultScale: خواندن تنظیمات از SettingsService | C | TODO | - | - |
| CAL-23 | setScale: ذخیره مقیاس در تنظیمات | C | TODO | - | - |
| CAL-24 | طوفان رفرش: ادغام دو منبع رویداد و اعمال debounce | C | TODO | - | - |
| CAL-25 | نشتی حافظه: مدیریت اشتراک CommandStack | C | TODO | - | - |
| CAL-26 | درگ و ریسایز: اعتبارسنجی و تشخیص تداخل | D | TODO | - | - |
| CAL-27 | محاسبهٔ totalLanes: خوشه‌بندی هم‌پوشانی تراگذر | D | TODO | - | - |
| CAL-28 | کارت overflow: عدم شمارش مجدد آیتم‌های دیده‌شده | D | TODO | - | - |
| CAL-29 | رفع خطای یک‌واحدی primaryCount در نمای دوستونی | D | TODO | - | - |
| CAL-30 | snapDurationMinutes: جلوگیری از عبور از نیمه‌شب | D | TODO | - | - |
| CAL-31 | اصلاح معناشناسی isTruncated و renderDurationMinutes | D | TODO | - | - |
| CAL-32 | ترتیب چیدمان قطعی | D | TODO | - | - |
| CAL-33 | رفع برچسب بی‌معنی «۳ روز از ۱» در اجندا | E | TODO | - | - |
| CAL-34 | محاسبه برچسب تکرار از قاعده واقعی | E | TODO | - | - |
| CAL-35 | ترتیب زمانی ادغام‌شده تک‌آیتم‌ها و سری‌ها | E | TODO | - | - |
| CAL-36 | یکپارچه‌سازی ارقام و نام روزهای فارسی | E | TODO | - | - |
| CAL-37 | لاگ خطا به‌جای catch (_) های خاموش در سطل‌بندی | E | TODO | - | - |
| CAL-38 | اصلاح بازهٔ معوقه در سطل‌بندی | E | TODO | - | - |
| CAL-39 | بارگذاری مرحله‌ای پنجرهٔ طولانی تقویم | F | TODO | - | - |
| CAL-40 | Negative cache برای روزهای خالی | F | TODO | - | - |
| CAL-41 | قطع وابستگی تقویم به فیچر دوره‌ها (courses) | F | TODO | - | - |
| CAL-42 | اعمال بودجهٔ کارایی و بهینه‌سازی | F | TODO | - | - |
| CAL-43 | جا کردن هوشمند: تشخیص تداخل و پیشنهاد شکاف خالی | G | TODO | - | - |
| CAL-44 | نوار بازگردانی با redo | G | TODO | - | - |
| CAL-45 | رها کردن آیتم بی‌زمان روی نوار شکاف‌های خالی | G | TODO | - | - |
| CAL-46 | قالب روز | G | TODO | - | - |
| CAL-47 | نقشهٔ حرارتی در نمای سال | G | TODO | - | - |
| CAL-48 | درگ چندروزه در نمای هفته و ماه | G | TODO | - | - |
| CAL-49 | علامت‌گذاری سریع روز استراحت و سفر | G | TODO | - | - |
| CAL-50 | حالت تمرکز روی بلوک زمانی | G | TODO | - | - |
| CAL-51 | ارتقای نشان «الان چی؟» | G | TODO | - | - |
| CAL-52 | ورود و خروج تقویم ICS | G | TODO | - | - |
| CAL-53 | تست سطل‌بندی اجندا (agenda_bucketing_test.dart) | H | TODO | - | - |
| CAL-54 | تست موتور چیدمان زمان (timeline_layout_engine_test.dart) | H | TODO | - | - |
| CAL-55 | تست اسنپ زمان (timeline_snapping_test.dart) | H | TODO | - | - |
| CAL-56 | تست کنترلر تقویم (journey_controller_test.dart) | H | TODO | - | - |
| CAL-57 | تست ریپازیتوری اورراید (occurrence_override_repository_test.dart) | H | TODO | - | - |
| CAL-58 | تست مرزهای وابستگی و معماری (calendar_dependency_test.dart) | H | TODO | - | - |
| CAL-59 | تست کلید تاریخ و تبدیل زمان (date_key_test / time_of_day_minutes_test) | H | TODO | - | - |
| CAL-60 | تست طلایی RTL و رگرسیون سرتاسری | H | TODO | - | - |
