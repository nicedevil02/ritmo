# شناسنامهٔ موتورهای محاسباتی ورزش تکمیلی ریتمو v2 (Movement Engines Reference)

این سند مرجع رسمی و قطعی ۱۳ موتور محاسباتی در پوشهٔ `lib/features/supplementary_sports/domain/engines/` است. تمامی موتورها توابعی قطعی (Deterministic)، بدون وابستگی به فریم‌ورک UI و با معماری Pure Dart هستند.

---

### ۱. موتور برنامه‌ریزی هفتگی (`PlanEngine`)
1. **ورودی‌ها:** `List<MvCommitment> activeCommitments`, `List<String> limitations`, `int userExperienceWeeks`, `Map<String, MvKindProfile> profiles`, `DateTime weekStartDate`, `int targetModerateMinutes`
2. **خروجی:** `MvPlanResult` (شامل ۷ اسلات روز `List<MvSlot>` همراه `reasonKey` و `reasonParams` برای هر اسلات)
3. **فرمول/ترتیب:** ۶ مرحله قطعی: ۱. ANCHORS (تعهدات ثابت و قفل) -> ۲. HARD_LIMITS (فیلتر فصل و معافیت لنگر با یادداشت) -> ۳. ADJACENCY (قواعد ADJ-1..7 تحرک قبل و ریکاوری بعد) -> ۴. FILL (سقف رشد و اولویت ۲ روز قدرتی و جبران کسری) -> ۵. COMPLEMENT (تمرکز قدرتی پشتیبان لنگرها) -> ۶. FALLBACK (گارد ۱۰ دقیقه حداقل مؤثر)
4. **شرط دادهٔ ناکافی:** در هر شرایطی برنامه تولید می‌شود؛ در صورت نبود تعهد یا سابقه، برنامه بر اساس پروفایل عمومی با حداقل مؤثر پر می‌شود.
5. **فایل تست:** `test/unit/sports/mv_plan_engine_anchors_test.dart`, `mv_plan_engine_hard_limits_test.dart`, `mv_plan_engine_adjacency_test.dart`, `mv_plan_engine_fill_test.dart`, `mv_plan_engine_complement_test.dart`, `mv_plan_engine_fallback_test.dart`, `mv_golden_paths_test.dart`

---

### ۲. موتور انتخاب تمرین (`SelectionEngine`)
1. **ورودی‌ها:** `List<MvExercise> pool`, `String muscleGroup`, `int availableMinutes`, `List<String> limitations`, `bool neighborFriendly`
2. **خروجی:** `List<MvExercise>` (لیست مرتب‌شده حرکات متناسب با فیلترها و زمان در دسترس)
3. **فرمول/ترتیب:** فیلتر محدودیت‌های مفاصل -> فیلتر سروصدا/همسایه -> انتخاب حرکت اصلی کامپاند متناسب با گروه عضلانی -> انتخاب حرکات ایزوله مکمل تا پر شدن زمان.
4. **شرط دادهٔ ناکافی:** در استخر خالی، لیست خالی برمی‌گرداند.
5. **فایل تست:** `test/unit/sports/mv_guard_test.dart`

---

### ۳. موتور سنجش آمادگی (`ReadinessEngine`)
1. **ورودی‌ها:** `int? sleepQuality1To5`, `int? energyLevel1To5`, `int? sorenessLevel1To5`, `int? painLevel1To5`
2. **خروجی:** `MvDecision<double?>` (امتیاز آمادگی بین ۰.۰ تا ۱.۰ همراه `hasEnoughData`)
3. **فرمول/ترتیب:** `(sleep * 0.35 + energy * 0.35 + (6 - soreness) * 0.15 + (6 - pain) * 0.15) / 5.0`
4. **شرط دادهٔ ناکافی:** اگر چک‌این امروز ثبت نشده باشد (`all inputs == null`)، مقدار `value: null` و `hasEnoughData: false` بازمی‌گردد.
5. **فایل تست:** `test/unit/sports/mv_readiness_inputs_test.dart`

---

### ۴. موتور بودجه و سلامت جهانی (`BudgetEngine`)
1. **ورودی‌ها:** `List<MvSession> completedSessionsInCurrentWeek`, `int targetMinutes` (پیش‌فرض ۱۵۰)
2. **خروجی:** `MvBudgetSnapshot` (شامل `accumulatedModerateMinutes`, `strengthDaysCompleted`, `targetMinutes`, `remainingMinutes`, `isGoalMet`)
3. **فرمول/ترتیب:** `moderateEquivalentMinutes = durationMinutes * (sessionMet / 4.0)` (فقط برای جلسات همان هفته تقویمی شنبه تا جمعه)؛ شمارش روزهای یکتای قدرتی با `MovementFamily.bodyweight` یا `MovementFamily.strength`.
4. **شرط دادهٔ ناکافی:** در ابتدای هفته با صفر جلسه، بودجه با مقدار ۰ دقیقه و ۰ روز و دادهٔ معتبر صفر آغاز می‌شود.
5. **فایل تست:** `test/unit/sports/mv_budget_engine_test.dart`, `mv_budget_week_bounded_test.dart`

---

### ۵. موتور بار تمرینی و خستگی (`LoadEngine`)
1. **ورودی‌ها:** `List<MvSession> sessionsLast28Days`, `DateTime referenceDate`
2. **خروجی:** `MvLoadSnapshot` (شامل `acuteLoad`, `chronicWeeklyLoad`, `ratio`, `bandKey`, `bandTitleFa`, `daysOfHistory`, `completedSessions`)
3. **فرمول/ترتیب:** محاسبهٔ `sessionLoad = durationMinutes * rpe1To10`؛ محاسبهٔ بار حاد ۷ روز اخیر (`acuteLoad`)؛ محاسبهٔ میانگین هفتگی ۲۸ روز (`chronicWeeklyLoad = sum28 / 4.0`)؛ نسبت `ACWR = acuteLoad / chronicWeeklyLoad`؛ دسته‌بندی در ۴ باند `low`, `optimal`, `watch`, `spike`.
4. **شرط دادهٔ ناکافی:** اگر سابقه کمتر از ۱۴ روز باشد یا جلسات کافی نباشد، `ratio: null`, `bandKey: null` و `hasEnoughData: false` برمی‌گردد.
5. **فایل تست:** `test/unit/sports/mv_load_engine_test.dart`

---

### ۶. موتور جایگزینی حرکت (`SubstitutionEngine`)
1. **ورودی‌ها:** `MvExercise currentExercise`, `String reason` (too_hard, pain, no_equipment, noise), `List<MvExercise> similarCandidates`, `List<MvExercise> fullPool`, `bool neighborFriendly`, `List<String> limitations`
2. **خروجی:** `MvDecision<List<MvExercise>>` (لیست کاندیداهای معتبر جایگزین با دلیل فارسی شفاف)
3. **فرمول/ترتیب:** اگر `too_hard` -> حرکات با سطح سختی کمتر؛ اگر `pain` یا `limitations` -> حذف حرکات دارای تداخل مفصلی؛ اگر `no_equipment` -> حرکات بدون وسیله (`toolsRequired == []`)؛ اگر `noise` -> حرکات با `impact == 0` و `noisy == 0`.
4. **شرط دادهٔ ناکافی:** در نبود کاندیدای منطبق، لیست خالی با توضیح مناسب بازمی‌گردد.
5. **فایل تست:** `test/widget/sports/mv_screens_test.dart`

---

### ۷. موتور پیشرفت و رکوردها (`ProgressionEngine`)
1. **ورودی‌ها:** `MvSession currentSession`, `List<MvPr> existingPrsForKind`
2. **خروجی:** `List<MvPr>` (رکوردهای جدید ارتقایافتهٔ تفکیک‌شده بر اساس نوع ورزش)
3. **فرمول/ترتیب:** مقایسهٔ متریک‌های جلسه با بالاترین مقدار قبلی همان نوع: بیشترین مسافت (`longestDistance`)، بهترین سرعت در ۵+ کیلومتر (`bestPace5k`)، بیشترین ارتفاع (`maxElevation`)، سنگین‌ترین کوله (`maxPackWeight`)، بیشترین دور (`maxLaps`)، بیشترین مدت زمان (`longestDuration`).
4. **شرط دادهٔ ناکافی:** اولین جلسهٔ هر نوع ورزش به عنوان اولین رکورد پایه ثبت می‌شود.
5. **فایل تست:** `test/unit/sports/mv_pr_kind_test.dart`

---

### ۸. موتور انطباق و تغییر شرایط (`AdaptationEngine`)
1. **ورودی‌ها:** `MvSlot originalSlot`, `double? readinessScore`, `bool userSaidCantToday`, `bool isAnchor`
2. **خروجی:** `MvDecision<MvSlot>` (اسلات تعدیل‌شده با `reasonKey` مرتبط)
3. **فرمول/ترتیب:** اگر لنگر است و کاربر لغو کرده -> حفظ در تقویم با برچسب لغو این هفته و جبران کسری بودجه؛ اگر آمادگی پایین است (`< 0.4`) -> تبدیل به اسلات ریکاوری یا پیاده‌روی سبک با `reasonKey = mv_reason_readiness_low`.
4. **شرط دادهٔ ناکافی:** در نبود دادهٔ آمادگی، اسلات بدون تغییر اجرا می‌شود.
5. **فایل تست:** `test/unit/sports/mv_guard_test.dart`

---

### ۹. موتور بینش‌های مبتنی بر داده (`InsightEngine`)
1. **ورودی‌ها:** `List<MvSession> completedSessions`, `List<MvCommitment> activeCommitments`, `int commitmentWeeks`, `int plannedAnchorSessions`, `int completedAnchorSessions`, `List<MvRoute> routes`, `Map<String, MvMovementKind> kindsMap`, `DateTime? referenceDate`
2. **خروجی:** `List<MvInsight>` (دقیقاً ۵ بینش قطعی با لحن فرضیه‌ای بدون هیچ جملهٔ عمومی فیک)
3. **فرمول/ترتیب:** ۱. `best_day` (حداقل ۸ جلسه، نرخ روز >= ۲۰٪ بالاتر از میانگین)؛ ۲. `anchor_adherence` (حداقل ۴ هفته تعهد، محاسبه درصد حضور)؛ ۳. `effort_drift` (حداقل ۱۰ جلسه، مقایسه میانگین RPE دو ماه با اختلاف >= ۰.۵)؛ ۴. `kind_mix` (حداقل ۳ ورزش در ماه جاری)؛ ۵. `route_progress` (حداقل ۳ بار انجام مسیر).
4. **شرط دادهٔ ناکافی:** هر بینشی که شرطش برقرار نباشد تولید نمی‌شود (کاربر با کمتر از ۳ جلسه -> صفر بینش).
5. **فایل تست:** `test/unit/sports/mv_insight_engine_s5_test.dart`, `mv_insight_engine_test.dart`

---

### ۱۰. موتور مربیگری و تحلیل (`CoachEngine`)
1. **ورودی‌ها:** `MvBudgetSnapshot budget`, `MvLoadSnapshot load`, `MvDecision<double?> readiness`
2. **خروجی:** `List<String>` (توصیه‌های شفاف و انگیزشی بدون ادعای درمانی یا پزشکی)
3. **فرمول/ترتیب:** بررسی کسری بودجه هفتگی -> بررسی جهش بار تمرینی -> ارائه پیشنهادهای هماهنگ با سبک زندگی.
4. **شرط دادهٔ ناکافی:** در غیاب داده، پیام خوش‌آمدگویی و راهنمای شروع نمایش می‌یابد.
5. **فایل تست:** `test/unit/sports/mv_guard_test.dart`

---

### ۱۱. موتور یادآورها و نوتیفیکیشن (`ReminderEngine`)
1. **ورودی‌ها:** `MvCommitment commitment`, `DateTime targetDate`
2. **خروجی:** `DateTime? reminderScheduledTime`
3. **فرمول/ترتیب:** محاسبه زمان جلسه منهای `reminderMinutes` (پیش‌فرض ۶۰ دقیقه قبل از شروع).
4. **شرط دادهٔ ناکافی:** در نبود زمان یا غیرفعال بودن تعهد، یادآور تنظیم نمی‌شود.
5. **فایل تست:** `test/unit/sports/mv_commitment_test.dart`

---

### ۱۲. موتور پروفایل و ریکاوری ورزش‌ها (`ProfileEngine`)
1. **ورودی‌ها:** `String kindCode`, `Map<String, MvKindProfile> profileCache`
2. **خروجی:** `MvKindProfile` (شامل `recoveryHours`, `primaryMuscles`, `secondaryMuscles`, `metTypical`)
3. **فرمول/ترتیب:** واکشی پروفایل از دیتابیس/سید جدول `mv_kind_profile` و اعمال در الگوریتم‌های همجواری.
4. **شرط دادهٔ ناکافی:** استفاده از پروفایل عمومی پیش‌فرض در صورت ناشناخته بودن نوع.
5. **فایل تست:** `test/unit/sports/mv_kind_profile_repository_test.dart`, `mv_kind_profile_seed_test.dart`

---

### ۱۳. موتور دوره‌بندی معکوس کمپین‌ها (`CampaignEngine`)
1. **ورودی‌ها:** `DateTime targetEventDate`, `String goalCode`, `int packWeightTargetKg`, `DateTime? startDate`
2. **خروجی:** `MvCampaignPlan` (برنامهٔ چند هفته‌ای با ۳ فاز پایه، بارگذاری پله‌ای، و کاهش حجم)
3. **فرمول/ترتیب:** محاسبهٔ `totalWeeks`؛ گارد حداقل ۴ هفته (`isTooShort`); فاز ۱ پایه (هفته‌های ۱ تا ۴ با وزن کوله ۰)؛ فاز ۲ بارگذاری پله‌ای (پله‌های ۲ هفته‌ای با ۵٪، ۱۰٪، ۱۵٪ و ۲۰٪ وزن هدف)؛ فاز ۳ تیپر (هفتهٔ پایانی با ۶۰٪ حجم و کوله سبک).
4. **شرط دادهٔ ناکافی:** اگر زمان باقیمانده کمتر از ۴ هفته باشد، `isTooShort: true` و هشدار `mv_campaign_too_short` برمی‌گردد.
5. **فایل تست:** `test/unit/sports/mv_campaign_engine_test.dart`
