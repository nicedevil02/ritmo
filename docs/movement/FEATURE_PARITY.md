# جدول تطبیق قابلیت‌های ورزش تکمیلی ریتمو v2 (Feature Parity F-01..F-50)

این جدول وضعیت انطباق کامل ۵۰ قابلیت مندرج در استاندارد معماری ورزش تکمیلی را مستند می‌کند.

| کد | عنوان قابلیت | وضعیت | مسیر فایل متناظر | تست مربوطه | یادداشت |
| :--- | :--- | :--- | :--- | :--- | :--- |
| F-01 | سیستم تعهدات ثابت و لنگر | DONE | `domain/models/mv_commitment.dart` | `test/unit/sports/mv_commitment_test.dart` | تعهدات ثابت هفتگی با ساعت و محل |
| F-02 | پنجرهٔ جابجایی هوشمند لنگر | DONE | `domain/models/mv_commitment.dart` | `test/unit/sports/mv_commitment_test.dart` | متدهای occursOnWeek و nextOccurrenceAfter |
| F-03 | گارد استراحت بعد از جلسهٔ دوگانه | DONE | `domain/engines/plan_engine.dart` | `test/unit/sports/mv_commitment_test.dart` | قاعده ADJ-4 و استراحت روز بعد |
| F-04 | اکشن این هفته لغو شد | DONE | `application/mv_cancel_anchor_use_case.dart` | `test/unit/sports/mv_cancel_anchor_use_case_test.dart` | ثبت در slot_overrides و جبران بودجه |
| F-05 | پیشنهاد غیرفعالسازی پس از ۲ لغو متوالی | DONE | `presentation/sheets/mv_cant_today_sheet.dart` | `test/widget/sports/mv_cant_today_anchor_test.dart` | پیشنهاد لغو همیشگی با دیالوگ تایید |
| F-06 | سوال لنگر در آنبوردینگ | DONE | `presentation/screens/mv_onboarding_screen.dart` | `test/widget/sports/mv_onboarding_anchor_test.dart` | امکان ثبت تا ۳ تعهد ثابت هفتگی |
| F-07 | ساخت تعهد از شیت برنامهٔ روز | DONE | `presentation/sheets/mv_day_plan_sheet.dart` | `test/widget/sports/mv_day_plan_commitment_test.dart` | سوییچ تکرار هفتگی و ذخیره در مخزن |
| F-08 | نشانگرهای قفل و ساعت روی کارت اسلات | DONE | `presentation/components/mv_day_slot_card.dart` | `test/widget/sports/mv_anchor_display_test.dart` | نمایش آیکون قفل و ساعت لنگر |
| F-09 | نوار یادآوری لنگر فردا در تب امروز | DONE | `presentation/screens/mv_today_tab.dart` | `test/widget/sports/mv_anchor_display_test.dart` | بنر یادآوری لنگر روز بعد |
| F-10 | نشانگر لنگر روی ریل ۷ روزهٔ هفته | DONE | `presentation/components/mv_week_rail.dart` | `test/widget/sports/mv_anchor_display_test.dart` | نقطهٔ قفل‌دار روی روزهای تعهد |
| F-11 | بنر هشدار تعارض جلسات متوالی | DONE | `presentation/screens/mv_week_tab.dart` | `test/widget/sports/mv_anchor_display_test.dart` | هشدار دو جلسه فشرده پشت سر هم |
| F-12 | تاکسونومی ۴۹ ورزش در دیتابیس | DONE | `movement/data/seed/movement_kinds_seed.dart` | `test/unit/sports/mv_kind_code_test.dart` | سید قطعی ۴۹ ورزش با متادیتا |
| F-13 | مخزن انواع ورزش با کش و فیلتر | DONE | `data/repositories/mv_kind_repository.dart` | `test/unit/sports/mv_kind_repository_test.dart` | واکشی، جستجو و تفکیک فصلی/اخیر |
| F-14 | شیت انتخابگر ورزش با جستجوی ۲۵۰ms | DONE | `presentation/sheets/mv_kind_picker_sheet.dart` | `test/unit/sports/mv_kind_picker_sheet_test.dart` | جستجوی بهینه و چیپ‌های دسته‌بندی |
| F-15 | شیت ثبت ورزش سفارشی دلخواه | DONE | `presentation/sheets/mv_custom_kind_sheet.dart` | `test/widget/sports/mv_library_kinds_tab_test.dart` | ثبت ورزش کاربر با متغیرهای MET و متریک |
| F-16 | تب ورزش‌ها در کتابخانه | DONE | `presentation/screens/mv_library_screen.dart` | `test/widget/sports/mv_library_kinds_tab_test.dart` | تفکیک تب انواع ورزش و حرکات بدنسازی |
| F-17 | پروفایل و ریکاوری ورزش‌ها (mv_kind_profile) | DONE | `data/repositories/mv_kind_profile_repository.dart` | `test/unit/sports/mv_kind_profile_repository_test.dart` | ساعات ریکاوری و عضلات درگیر ۴۹ ورزش |
| F-18 | سیستم دلیل‌محوری اسلات‌ها (reasonKey) | DONE | `domain/models/mv_reason_keys.dart` | `test/unit/sports/mv_slot_reason_test.dart` | پوشش ۱۰۰٪ اسلات‌ها با کلیدهای مجاز |
| F-19 | مرحله ۱ موتور برنامه: ANCHORS | DONE | `domain/engines/plan_engine.dart` | `test/unit/sports/mv_plan_engine_anchors_test.dart` | جانمایی اسلات‌های لنگر با زمان دقیق |
| F-20 | مرحله ۲ موتور برنامه: HARD_LIMITS | DONE | `domain/engines/plan_engine.dart` | `test/unit/sports/mv_plan_engine_hard_limits_test.dart` | فیلتر محدودیت‌ها و معافیت لنگر با نوت |
| F-21 | مرحله ۳ موتور برنامه: ADJACENCY | DONE | `domain/engines/plan_engine.dart` | `test/unit/sports/mv_plan_engine_adjacency_test.dart` | قواعد ۷ گانه تحرک قبل و ریکاوری بعد |
| F-22 | مرحله ۴ موتور برنامه: FILL | DONE | `domain/engines/plan_engine.dart` | `test/unit/sports/mv_plan_engine_fill_test.dart` | اولویت ۲ روز قدرتی و سقف بار رشد |
| F-23 | مرحله ۵ موتور برنامه: COMPLEMENT | DONE | `domain/engines/plan_engine.dart` | `test/unit/sports/mv_plan_engine_complement_test.dart` | تمرکز قدرتی پشتیبان ورزش‌های لنگر |
| F-24 | مرحله ۶ موتور برنامه: FALLBACK | DONE | `domain/engines/plan_engine.dart` | `test/unit/sports/mv_plan_engine_fallback_test.dart` | حداقل ۱۰ دقیقه مؤثر در شرایط حاد |
| F-25 | ذخیره متریک‌های جلسه در دیتابیس (v127) | DONE | `data/repositories/mv_session_repository.dart` | `test/unit/sports/mv_session_metrics_test.dart` | ۷ ستون مسافت، ارتفاع، کوله، دور، RPE |
| F-26 | قالب پلیر زمان‌محور (Timed) | DONE | `presentation/player/templates/mv_timed_template.dart` | `test/widget/sports/mv_player_templates_test.dart` | کرنومتر، فازها و اسلایدر تلاش |
| F-27 | قالب پلیر مسافت‌محور (Distance) | DONE | `presentation/player/templates/mv_distance_template.dart` | `test/widget/sports/mv_player_templates_test.dart` | ثبت کیلومتر و گام‌شمار |
| F-28 | قالب پلیر مسیرمحور (Route) | DONE | `presentation/player/templates/mv_route_template.dart` | `test/widget/sports/mv_player_templates_test.dart` | مسافت، ارتفاع، وزن کوله و انتخاب مسیر |
| F-29 | قالب پلیر دورمحور (Laps) | DONE | `presentation/player/templates/mv_laps_template.dart` | `test/widget/sports/mv_player_templates_test.dart` | شمارندهٔ دور استخر و زمان کل |
| F-30 | قالب پلیر مسابقه/بازی (Match) | DONE | `presentation/player/templates/mv_match_template.dart` | `test/widget/sports/mv_player_templates_test.dart` | تایمر مسابقه، گل/امتیاز و نتیجه |
| F-31 | انتخاب قطعی حالت پلیر (resolveSessionMode) | DONE | `application/mv_start_session_use_case.dart` | `test/unit/sports/mv_start_session_mode_test.dart` | اولویت ۷ گانه بر اساس متادیتا و متریک |
| F-32 | صفحه خلاصه پایان جلسه | DONE | `presentation/player/mv_session_summary_screen.dart` | `test/widget/sports/mv_session_summary_test.dart` | نمایش متریک‌ها، انتخاب ۳ دکمه و اسلایدر RPE |
| F-33 | محاسبهٔ بار sRPE و ACWR | DONE | `domain/engines/load_engine.dart` | `test/unit/sports/mv_load_engine_test.dart` | نسبت بار ۷ به ۲۸ روز و ۴ محدوده |
| F-34 | جدول مسیرهای تکراری (mv_routes v128) | DONE | `data/repositories/mv_route_repository.dart` | `test/unit/sports/mv_route_test.dart` | دفعات تکرار، بهترین زمان و آخرین رکورد |
| F-35 | دوره‌های هدف‌دار (movement_campaigns) | DONE | `data/repositories/mv_campaign_repository.dart` | `test/unit/sports/mv_campaign_repository_test.dart` | ذخیره و بازیابی کمپین‌های چند هفته‌ای |
| F-36 | موتور دوره‌بندی معکوس کمپین‌ها | DONE | `domain/engines/campaign_engine.dart` | `test/unit/sports/mv_campaign_engine_test.dart` | ۳ فاز پایه، بارگذاری پله‌ای و تیپر |
| F-37 | رکوردهای تفکیک‌شده بر اساس نوع ورزش | DONE | `data/repositories/mv_pr_repository.dart` | `test/unit/sports/mv_pr_kind_test.dart` | رکورد ارتفاع، مسافت، کوله و سرعت به تفکیک |
| F-38 | تب پیشرفت ۵ کارتی با دو ارز سلامت | DONE | `presentation/screens/mv_progress_tab.dart` | `test/widget/sports/mv_progress_tab_test.dart` | کارت سلامت WHO، بار ACWR، توزیع و رکورد |
| F-39 | ۵ بینش قطعی مبتنی بر داده | DONE | `domain/engines/insight_engine.dart` | `test/unit/sports/mv_insight_engine_s5_test.dart` | لحن فرضیه‌ای بدون تولید جملات عمومی فیک |
| F-40 | بودجه معادل متوسط WHO | DONE | `domain/engines/budget_engine.dart` | `test/unit/sports/mv_budget_engine_test.dart` | فرمول MET/4.0 و هدف هفتگی ۱۵۰ دقیقه |
| F-41 | ارزیابی آمادگی با ۴ ورودی روزانه | DONE | `domain/engines/readiness_engine.dart` | `test/unit/sports/mv_readiness_inputs_test.dart` | خواب، انرژی، درد و کوفتگی |
| F-42 | نوار تداوم هفتگی پیوسته | DONE | `domain/engines/insight_engine.dart` | `test/unit/sports/mv_streak_test.dart` | محاسبه بر اساس حداقل ۲ روز در هر هفته |
| F-43 | جایگزینی حرکت بر اساس ۴ دلیل | DONE | `domain/engines/substitution_engine.dart` | `test/widget/sports/mv_screens_test.dart` | سختی، درد، نبود وسیله و صدا |
| F-44 | ساختار مخازن با الگوی تک‌منبع حقیقت | DONE | `data/repositories/` | `test/unit/sports/mv_repositories_test.dart` | جداسازی لایه‌های داده و برنامه |
| F-45 | ایزوله‌سازی موتورها در Pure Dart | DONE | `domain/engines/` | `test/unit/sports/mv_guard_test.dart` | عدم وابستگی موتورها به Flutter UI |
| F-46 | مدیریت خطای دیتابیس و تراکنش‌ها | DONE | `core/database/` | `test/unit/sports/mv_migration_test.dart` | مایگریشن‌های امن idempotent |
| F-47 | رابط کاربری واکنش‌گرا و متریک‌های ریتمو | DONE | `presentation/components/` | `test/widget/sports/mv_components_test.dart` | پشتیبانی از تم‌های تیره و روشن |
| F-48 | بسته‌های ایستگاهی تمرین (station_bundles) | DROPPED | `data/repositories/mv_station_bundle_repository.dart` | `test/unit/sports/mv_station_bundle_repository_test.dart` | جدول در دیتابیس موجود است اما دادهٔ seed در پروژه وجود ندارد و تسک مسدود شد |
| F-49 | ردیابی GPS و نقشه زنده | DROPPED | — | — | طبق بند ۱۵ پرامپت (چیزهایی که مطلقاً نباید ساخته شود) حذف عمدی شد |
| F-50 | قابلیت‌های اجتماعی و لیدربورد | DROPPED | — | — | طبق بند ۱۵ پرامپت به منظور حفظ تمرکز و حریم خصوصی کاربر حذف عمدی شد |
