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
| CAL-11 | بازگردانی مبتنی بر snapshot در MoveItemCommand و ResizeItemCommand | B | DONE | 79fc50c | بازگردانی snapshot-based در Move/Resize برای جلوگیری از پاک شدن overrideهای پیشین |
| CAL-12 | allFutureDays: snapshot و transaction برای removeAllFuture | B | DONE | c13a57d | پشتیبان‌گیری snapshot و بازگردانی کلیه overrideهای آینده در صورت undo با سقف زمانی امن |
| CAL-13 | حذف کلید برهنهٔ sourceId در نگاشت override | B | DONE | 666b960 | حذف کلید برهنه و fallback، استفاده از formatKey با پیشوند sourceType و تفکیک دامنه‌ها |
| CAL-14 | پایهٔ مشترک دستورات تقویم: بی‌اعتبارسازی کش اجباری | B | DONE | e793518 | ایجاد _CalendarCommand با الگوی Template Method و بی‌اعتبارسازی اجباری تک‌روزه و چندروزه کش |
| CAL-15 | skipItem برای دامنه‌های غیرروتین | B | DONE | e0f16d9 | ایجاد _SkipItemCommand با override وضعیت SKIPPED و اتصال کامل به CommandStack با قابلیت undo |
| CAL-16 | postponeItem برای همه دامنه‌ها | B | DONE | a0e9baf | تعویق تسک‌ها بر مبنای max(today, dueDate) و تعویق آیتم‌های تکراری با override دوطرفه و پشتیبانی undo |
| CAL-17 | توکن نسل بارگذاری برای جلوگیری از نوشتن بی‌ترتیب | C | DONE | 0d24e3b | افزودن _loadGeneration و محافظت در برابر race condition بارگذاری‌های ناهمگام |
| CAL-18 | حذف شاخهٔ مردهٔ agenda و یک تعریف واحد برای پنجرهٔ اجندا | C | DONE | fe7c06d | حذف شاخهٔ مردهٔ agenda از محاسبهٔ بازه، پرتاب StateError، و تعریف ثابت‌های پنجرهٔ اجندا |
| CAL-19 | پنجرهٔ بارگذاری صریح و عبور isBackgroundRefresh | C | DONE | 8f6c3ad | ذخیرهٔ windowStart/End و عبور کامل پرچم isBackgroundRefresh برای جلوگیری از پرش لودینگ |
| CAL-20 | تعویض مقیاس: دادهٔ مقیاس قبلی پاک شود | C | DONE | 41f68ee | ریست فوری اسنپ‌شات‌ها و فعال‌سازی isLoading در setScale و selectDate با مقیاس جدید |
| CAL-21 | یک fallback واحد برای snapshot تهی | C | DONE | e394cf6 | ایجاد _snapshotForSelectedDate و تضمین بازگشت اسنپ‌شات خالی معتبر در تمام مقیاس‌ها |
| CAL-22 | loadDefaultScale: خواندن تنظیمات از SettingsService | C | DONE | 52df4f2 | خواندن مقیاس از SettingsService، بارگذاری واقعی داده‌ها، و اولویت‌بخشی به scale صریح |
| CAL-23 | setScale: ذخیره مقیاس در تنظیمات | C | DONE | a6c4352 | ذخیرهٔ ناهمگام مقیاس انتخابی در SettingsService با نگاشت 1-به-1 نام enum |
| CAL-24 | طوفان رفرش: ادغام دو منبع رویداد و اعمال debounce | C | DONE | abd52f8 | اعمال debounce 250ms، فیلتر رویدادهای خارج از پنجرهٔ فعال، و جایگزینی زنجیره if با Set |
| CAL-25 | نشتی حافظه: مدیریت اشتراک CommandStack | C | DONE | 7c6fe3d | حذف closureهای onRefresh از دستورات و مستقل‌سازی پشته با سقف ظرفیت ۵۰ آیتم |
| CAL-26 | درگ و ریسایز: اعتبارسنجی و تشخیص تداخل | D | DONE | e7bca7b | اعتبارسنجی زمان، snap به بازه‌های زمانی، کنترل عبور از نیمه‌شب، و ثبت هشدار تداخل |
| CAL-27 | محاسبهٔ totalLanes: خوشه‌بندی هم‌پوشانی تراگذر | D | DONE | 3cfce05 | پیاده‌سازی خوشه‌بندی مؤلفه‌های همبند برای محاسبهٔ عرض و ستون‌های هماهنگ در چیدمان تقویم |
| CAL-28 | کارت overflow: عدم شمارش مجدد آیتم‌های دیده‌شده | D | DONE | 68886d0 | دسته‌بندی قطعی primary/overflow در هر خوشه، حذف شمارش مجدد و افزودن assert عدم تکرار |
| CAL-29 | رفع خطای یک‌واحدی primaryCount در نمای دوستونی | D | DONE | 936279d | رزرو ستون سرریز فقط در صورت وجود آیتم اضافی واقعی و امکان نمایش ۲ کارت در نمای دوستونی |
| CAL-30 | snapDurationMinutes: جلوگیری از عبور از نیمه‌شب | D | DONE | a1d96bb | بازگرداندن null در صورت عدم گنجایش حداقل مدت و محدودسازی سخت‌گیرانه به انتهای روز |
| CAL-31 | اصلاح معناشناسی isTruncated و renderDurationMinutes | D | DONE | cfc6a85 | تفکیک دقیق مدت قابل رندر از ارتفاع و محاسبهٔ امن ارتفاع بدون احتمال پرتاب استثنا در clamp |
| CAL-32 | ترتیب چیدمان قطعی | D | DONE | cf19400 | قطعی‌سازی ترتیب مرتب‌سازی با افزودن شناسه آیتم به عنوان tie-break در تمام مراحل چیدمان |
| CAL-33 | رفع برچسب بی‌معنی «۳ روز از ۱» در اجندا | E | DONE | pending | بازگرداندن صفر برای سطل‌های خالی آخر هفته و ایمن‌سازی برچسب‌های تکرار در برابر کسر نامعتبر |
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
