// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Persian (`fa`).
class AppLocalizationsFa extends AppLocalizations {
  AppLocalizationsFa([String locale = 'fa']) : super(locale);

  @override
  String get learningGrowthInsightTitle => 'رشد چشمگیر یادگیری 📈';

  @override
  String learningGrowthInsightMessage(int percent) {
    return 'فعالیت‌های یادگیری شما در این هفته نسبت به هفته گذشته $percent٪ رشد داشته است. مسیر مطالعه خود را ادامه دهید!';
  }

  @override
  String get healthDeclineInsightTitle => 'توجه به سلامت و ورزش ⚠️';

  @override
  String healthDeclineInsightMessage(int percent) {
    return 'تعداد روتین‌های سلامتی شما در ۷ روز گذشته $percent٪ کاهش یافته است. تلاش کنید دوباره آنها را در برنامه قرار دهید.';
  }

  @override
  String get morningLeadInsightTitle => 'برتری عملکرد صبحگاهی ☀️';

  @override
  String get morningLeadInsightMessage =>
      'روتین‌های صبحگاهی شما (۶:۰۰ تا ۱۲:۰۰) نرخ تکمیل بالاتری نسبت به روتین‌های عصرگاهی دارند. برای کارهای مهم‌تر روی صبح‌ها سرمایه‌گذاری کنید.';

  @override
  String get fatigueWarningInsightTitle => 'بازه حساس خستگی ⚡';

  @override
  String fatigueWarningInsightMessage(String window) {
    return 'بازه زمانی $window شایع‌ترین دوره خستگی و از دست رفتن روتین‌های شماست. در این ساعات تسک‌های سبک‌تر قرار دهید.';
  }

  @override
  String get productiveWeekdayInsightTitle => 'روز درخشان شما 🌟';

  @override
  String productiveWeekdayInsightMessage(String weekday) {
    return 'روز «$weekday» پربازده‌ترین روز هفته برای شماست. کارهای سنگین و پروژه‌های خود را در این روز برنامه‌ریزی کنید.';
  }

  @override
  String get gatheringDataInsightTitle => 'در حال شناخت ریتم شما 🔍';

  @override
  String get gatheringDataInsightMessage =>
      'ریتمو برای ارائه تحلیل‌های معتبر نیاز به داده‌های بیشتری دارد. لطفاً به ثبت فعالیت‌های خود ادامه دهید.';

  @override
  String get contextExplanationRest => 'استراحت و بازیابی انرژی 🌿';

  @override
  String contextExplanationEssential(String title) {
    return 'سیستم زندگی «$title» به دلیل اهمیت حیاتی، در اولویت بالاتر قرار گرفت.';
  }

  @override
  String contextExplanationSick(String title) {
    return 'به دلیل کسالت و بیماری، روتین‌های فیزیکی تعلیق شده و روتین «$title» پیشنهاد می‌شود.';
  }

  @override
  String contextExplanationExam(String title) {
    return 'با توجه به بازه امتحانات، روتین‌های یادگیری و مطالعه نظیر «$title» تقویت شده‌اند.';
  }

  @override
  String contextExplanationBusy(String title) {
    return 'به دلیل تراکم بالای برنامه‌های امروز، اقدام بهینه بعدی روتین «$title» است.';
  }

  @override
  String contextExplanationWorship(String season, String title) {
    return 'با توجه به فصل عبادی جاری ($season)، روتین «$title» پیشنهاد می‌شود.';
  }

  @override
  String contextExplanationZone(String title) {
    return 'با توجه به حضور در زون فعال، روتین «$title» جهت همگامی با ریتم جاری پیشنهاد می‌شود.';
  }

  @override
  String contextExplanationLowEnergy(String title) {
    return 'با توجه به سطح انرژی پایین، نسخه متناسب از روتین «$title» پیشنهاد می‌شود.';
  }

  @override
  String contextExplanationDynamic(String title) {
    return 'با تحلیل پویای ریتم روزانه، روتین «$title» به عنوان بهترین اقدام بهینه بعدی پیشنهاد می‌شود.';
  }

  @override
  String get hormonalMenstrualAdjustment1 => 'فعالیت‌های سنگین را کاهش دهید';

  @override
  String get hormonalMenstrualAdjustment2 =>
      'بین کارها استراحت کوتاه اضافه کنید';

  @override
  String get hormonalMenstrualAdjustment3 =>
      'روی کارهای سبک و ضروری تمرکز کنید';

  @override
  String get hormonalMenstrualAdjustment4 =>
      'آب کافی بنوشید و استراحت کافی داشته باشید';

  @override
  String get hormonalPreCycleAdjustment1 =>
      'ممکن است خستگی بدنی یا نوسانات انرژی خفیف را تجربه کنید 🔋';

  @override
  String get hormonalPreCycleAdjustment2 =>
      'اولویت‌دهی به کارهای مهم در ساعات اولیه روز ⏰';

  @override
  String get hormonalPreCycleAdjustment3 =>
      'پیشنهاد می‌شود زمان خواب شبانه را افزایش دهید 🌙';

  @override
  String get hormonalPostCycleAdjustment1 =>
      'سطح انرژی و توانایی تمرکز در حال افزایش است 📈';

  @override
  String get hormonalPostCycleAdjustment2 =>
      'زمان عالی برای شروع برنامه‌ها یا یادگیری کارهای جدید 🎓';

  @override
  String get hormonalContextMenstrual =>
      'به دلیل فاز قاعدگی فعال، پیشنهاد می‌شود فعالیت‌های بدنی سبک‌تری داشته باشید و زمان ریکاوری را افزایش دهید. 🌸';

  @override
  String get hormonalContextPreCycle =>
      'در فاز پیش از قاعدگی (Pre-cycle)، احتمال خستگی یا حساسیت عاطفی ملایم وجود دارد. انعطاف‌پذیری برنامه به آسایش شما کمک می‌کند. 🧘';

  @override
  String get hormonalContextPostCycle =>
      'در فاز پس از قاعدگی (Post-cycle)، سطح آمادگی ذهنی و انرژی بدنی رو به افزایش است. زمان خوبی برای چالش‌های جدید است. ⚡';

  @override
  String get hormonalContextNormal =>
      'وضعیت بدنی در حالت عادی و متعادل قرار دارد. 🍃';

  @override
  String get hormonalContextNoData =>
      'هنوز داده کافی برای پیش‌بینی دقیق وضعیت شما وجود ندارد.';

  @override
  String get hormonalContextDisabled => 'ماژول چرخه بدنی فعال نیست.';

  @override
  String medicineStockAlert(String title, int count) {
    return 'موجودی داروی «$title» رو‌به‌اتمام است (موجودی فعلی: $count).';
  }

  @override
  String timeConflictAlert(String title1, String title2) {
    return 'تداخل زمانی بین روتین‌های «$title1» و «$title2» شناسایی شد.';
  }

  @override
  String get pulseCardMoodGood => 'امروز روز خوبی بوده 🌱';

  @override
  String get pulseCardMoodExcellent => 'ریتم زندگی شما عالی است! 🌟';

  @override
  String get pulseCardMoodRestore => 'بیا ریتم زندگی را بازیابی کنیم 🌿';

  @override
  String get pulseCardTitle => 'نبض زندگی';

  @override
  String get pulseCardTrend => 'روند این هفته +۱۱٪';

  @override
  String get currentEnergyTitle => 'انرژی فعلی';

  @override
  String get manageEnergy => 'مدیریت انرژی';

  @override
  String get currentRealmTitle => 'قلمرو فعلی';

  @override
  String get outOfRealm => 'خارج از قلمرو';

  @override
  String get noActiveSchedule => 'بدون زمان‌بندی فعال';

  @override
  String get logNewDailyRealm => 'ثبت قلمرو جدید روزانه';

  @override
  String routinesConnectedToRealm(int count) {
    return '$count روتین متصل به این قلمرو';
  }

  @override
  String get addRealm => 'افزودن قلمرو ›';

  @override
  String get manageRealm => 'مدیریت قلمرو ›';

  @override
  String get energyLevelHigh => 'بالا';

  @override
  String get energyLevelLow => 'پایین';

  @override
  String get energyLevelMedium => 'متوسط';

  @override
  String get energyDescHigh => 'آماده برای کارهای عمیق و تمرکز سنگین';

  @override
  String get energyDescLow => 'زمان مناسب برای استراحت و کار سبک';

  @override
  String get energyDescMedium => 'مناسب برای مطالعه، پروژه‌ها و روتین‌ها';

  @override
  String get contextNormal => 'عادی 🍃';

  @override
  String get contextSick => 'بیماری 🤒';

  @override
  String get contextTravel => 'سفر ✈️';

  @override
  String get contextExam => 'امتحانات 📚';

  @override
  String get contextBusy => 'مشغله زیاد 🔥';

  @override
  String get contextWorship => 'فصل عبادی';

  @override
  String get energyLevelHighSymbol => 'بالا 🔥';

  @override
  String get energyLevelLowSymbol => 'پایین 💤';

  @override
  String get energyLevelMediumSymbol => 'متوسط ⚡';

  @override
  String get outOfRealmSymbol => 'خارج از قلمرو 🌐';

  @override
  String get resolveScheduleConflict => '⚡ رفع تداخل برنامه';

  @override
  String get labelContext => 'بستر:';

  @override
  String get labelEnergy => 'انرژی:';

  @override
  String get labelRealm => 'حالت:';

  @override
  String get quickSystemsTitle => 'سیستم‌های سریع';

  @override
  String get systemWorships => 'عبادات';

  @override
  String get systemHealth => 'سلامت';

  @override
  String get systemGoals => 'اهداف';

  @override
  String get systemEducation => 'آموزش';

  @override
  String get worshipItemsToday => '۳ مورد امروز';

  @override
  String medicineToday(int count) {
    return '$count دارو امروز';
  }

  @override
  String get goalsAndPlans => 'اهداف و برنامه‌ها';

  @override
  String get activeCourse => '۱ دوره فعال';

  @override
  String get disabled => 'غیرفعال';

  @override
  String get moduleDisabled => 'ماژول غیرفعال است';

  @override
  String get restAndRecovery => 'استراحت و بازیابی 🌿';

  @override
  String minutesLight(int minutes) {
    return '$minutes دقیقه (سبک)';
  }

  @override
  String minutes(int minutes) {
    return '$minutes دقیقه';
  }

  @override
  String get freeTime => 'زمان آزاد';

  @override
  String get smartAssistantTitle => 'دستیار هوشمند ریتمو';

  @override
  String get focusOnThisToday => 'امروز روی این تمرکز کن:';

  @override
  String get balanceAndImprovement => '🎯 تعادل و بهبود مستمر';

  @override
  String get bestNextAction => 'بهترین کار بعدی برای شما';

  @override
  String get reasonForSuggestion => 'دلیل پیشنهاد:';

  @override
  String get reasonEssential =>
      'این روتین به دلیل اهمیت حیاتی در اولویت است 🎯';

  @override
  String reasonActiveZone(String zone) {
    return 'شما در زون «$zone» هستید 💼';
  }

  @override
  String reasonEnergyLevel(String energy) {
    return 'سطح انرژی شما $energy است ⚡';
  }

  @override
  String get reasonSick =>
      'به دلیل کسالت، برنامه به حالت بهینه سبک تغییر یافته 🤒';

  @override
  String get reasonExam =>
      'با توجه به بازه امتحانات، اولویت یادگیری افزایش یافته 📚';

  @override
  String get reasonBusy =>
      'به دلیل شلوغی برنامه امروز، این کار پیشنهاد بهینه است ⏳';

  @override
  String reasonWorship(String season) {
    return 'با توجه به فصل عبادی جاری ($season) 🌙';
  }

  @override
  String get reasonCompleted => 'کارهای امروز با موفقیت تکمیل شده‌اند ✨';

  @override
  String get reasonRestTime => 'زمان استراحت و ریکاوری است 🍃';

  @override
  String get start => 'شروع';

  @override
  String get whyThisSuggestion => 'چرا این پیشنهاد؟';

  @override
  String get todaysTasksTitle => 'کارهای امروز';

  @override
  String get resolveConflictBtn => '⚡ رفع تداخل';

  @override
  String get viewAll => 'مشاهده همه';

  @override
  String routineDoneMsg(String title) {
    return 'روتین «$title» انجام شد! 🌟';
  }

  @override
  String routineDoneLightMsg(String title) {
    return 'روتین «$title» به صورت سبک انجام شد! ⚡';
  }

  @override
  String routineDoneMinimalMsg(String title) {
    return 'روتین «$title» به صورت حداقلی انجام شد! 🌿';
  }

  @override
  String routineSkippedMsg(String title) {
    return 'روتین «$title» رد شد. ✕';
  }

  @override
  String routinePostponedMsg(String title) {
    return 'روتین «$title» به تعویق افتاد. ⏳';
  }

  @override
  String loggedAtTime(int time) {
    return 'ثبت شده در $time دقیقه پیش';
  }

  @override
  String loggedAtTimeWithNote(int time, String note) {
    return 'ثبت شده در $time دقیقه پیش ($note)';
  }

  @override
  String get basedOnCalculationsAndDefaults =>
      'بر اساس محاسبات و مقادیر پیش‌فرض';

  @override
  String get basedOnDefaults => 'بر اساس پیش‌فرض';

  @override
  String get worshipDebt => 'بدهی عبادی';

  @override
  String snoozeTimeMinutes(int count) {
    return '$count دقیقه';
  }

  @override
  String snoozeTimeHours(int count) {
    return '$count ساعت';
  }

  @override
  String welcomeUser(String name) {
    return 'سلام $name';
  }

  @override
  String get noRoutinesToday => 'هیچ روتینی برای امروز باقی نمانده است. ✨';

  @override
  String get timeLabel => 'ساعت:';

  @override
  String get checkinReminderTitle => 'ثبت وضعیت صبحگاهی (چک‌این) ☀️';

  @override
  String get checkinReminderDesc =>
      'ثبت وضعیت به ریتمو کمک می‌کند برنامه‌تان را متناسب با سطح انرژی‌تان تنظیم کند.';

  @override
  String get reflectionReminderTitle => 'ثبت تأمل و خودارزیابی روزانه 🌙';

  @override
  String get reflectionReminderDesc =>
      'زمانی را برای ارزیابی امروز و یادگیری‌های آن اختصاص دهید.';

  @override
  String get laterOrDismiss => 'بعداً / صرف‌نظر';

  @override
  String get yesRecord => 'بله، ثبت کنم';

  @override
  String get criticalSystemAlerts => 'هشدارهای بحرانی سیستم ⚠️';

  @override
  String get worshipPrayer => 'نماز';

  @override
  String get worshipFast => 'روزه';

  @override
  String get totalDebtsLabel => 'تعداد کل قضاها';

  @override
  String get dailyTargetLabel => 'هدف انجام روزانه';

  @override
  String get cancelBtn => 'انصراف';

  @override
  String get registerDebtBtn => 'ثبت بدهی';

  @override
  String get timeConflictWarning => 'هشدار تداخل زمانی';

  @override
  String medMinIntervalAlert(double minInterval) {
    return 'فاصله زمانی مجاز بین هر بار مصرف این دارو (حداقل $minInterval ساعت) رعایت نشده است. آیا مایل به ثبت مصرف هستید؟';
  }

  @override
  String get overdoseDanger => 'خطر بیش‌مصرف (اوردوز)';

  @override
  String medMaxDosesAlert(int maxDoses) {
    return 'تعداد دفعات مصرف مجاز روزانه این دارو ($maxDoses بار در روز) به سقف خود رسیده است. مصرف بیشتر خطرناک است. آیا مطمئن به ثبت هستید؟';
  }

  @override
  String get dosageUnit => '1 عدد';

  @override
  String medLoggedSuccess(String title) {
    return 'مصرف داروی «$title» با موفقیت ثبت شد.';
  }

  @override
  String get noCancel => 'خیر، لغو ثبت';

  @override
  String get yesLog => 'بله، ثبت مصرف';

  @override
  String refillStockTitle(String title) {
    return 'شارژ مجدد موجودی: $title';
  }

  @override
  String get refillCountLabel => 'تعداد داروی اضافه شده';

  @override
  String get refillStockBtn => 'شارژ موجودی';

  @override
  String niyyahTitle(String title) {
    return 'آماده‌سازی و شروع: $title';
  }

  @override
  String get completionModeFull => 'کامل 🎯';

  @override
  String get completionModeLight => 'سبک ⚡';

  @override
  String get completionModeMinimal => 'حداقلی 🌿';

  @override
  String get startFocusTimer => 'شروع تایمر تمرکز';

  @override
  String get logWithoutTimer => 'ثبت فوری بدون تایمر';

  @override
  String get contextEngineExplanation =>
      'سیستم بر اساس موتور تحلیل بافت (Context Engine)، شرایط زمانی و انرژی فعلی شما را سنجیده است.';

  @override
  String get ritmoSmartAnalysis => 'تحلیل هوشمند ریتمو ✨';

  @override
  String get understood => 'فهمیدم';

  @override
  String get energyManagementTitle => 'مدیریت و تحلیل انرژی ریتمو';

  @override
  String currentDynamicEnergyLabel(String label) {
    return 'درصد پویای انرژی فعلی شما: $label';
  }

  @override
  String get whyThisNumberTitle => 'چرا این عدد؟ (فرمول محاسبه پویای انرژی)';

  @override
  String get calculating => 'در حال محاسبه...';

  @override
  String get setBaseEnergyLabel => 'تنظیم سطح انرژی پایه ثبت دستی:';

  @override
  String get factorsAffectingEnergyLabel =>
      'فاکتورهای مؤثر بر خستگی یا افت انرژی امروز:';

  @override
  String get factorPoorSleep => 'خواب ضعیف 🛌';

  @override
  String get factorHighStress => 'استرس بالا 🧠';

  @override
  String get factorPhysicalFatigue => 'خستگی جسمی 🏋️';

  @override
  String get factorLackOfFocus => 'عدم تمرکز ذهنی 🎯';

  @override
  String get moodNotesPlaceholder => 'توضیحات کوتاه یا خلق‌و‌خو (اختیاری)';

  @override
  String get lackOfFocusStr => 'عدم تمرکز ذهنی';

  @override
  String get energyUpdatedSuccess => 'سطح انرژی با موفقیت به روز شد.';

  @override
  String get saveStatusBtn => 'ثبت و ذخیره‌سازی وضعیت';

  @override
  String get aiSmartAnalysisTitle => 'تحلیل هوشمند دستیار ریتمو (AI)';

  @override
  String get dataSentToAiLabel => 'داده‌های ارسالی به هوش مصنوعی جهت تحلیل:';

  @override
  String bulletCalculatedEnergy(int percent) {
    return '• درصد پویای محاسبه شده فعلی: $percent٪\n';
  }

  @override
  String bulletReportedFactors(String factors) {
    return '• عوامل موقت گزارش شده: $factors\n';
  }

  @override
  String get bulletBiologicalClock => '• فاز ساعت زیستی بدن در ساعت فعلی روز\n';

  @override
  String get bulletSleepHistory =>
      '• تاریخچه خواب اخیر و وضعیت روتین‌های تکمیل‌شده';

  @override
  String get agreeToSendData => 'با ارسال امن داده‌های فوق جهت تحلیل موافقم.';

  @override
  String get noRecommendationFound => 'پیشنهادی یافت نشد.';

  @override
  String get networkErrorMsg => 'خطا در اتصال به شبکه یا دریافت پاسخ.';

  @override
  String get analyzeAndGetRecommendation => 'تحلیل و دریافت پیشنهاد ✨';

  @override
  String get analyzingDataMsg =>
      'در حال تحلیل داده‌های خواب و روتین‌ها توسط هوش مصنوعی...';

  @override
  String get reAnalyze => 'تحلیل مجدد 🔄';

  @override
  String get localEnergyEngineReport => 'گزارش آماری موتور تحلیل انرژی (محلی):';

  @override
  String get insufficientData => 'داده ناکافی';

  @override
  String get goldenHourLabel => 'ساعت طلایی بازدهی:';

  @override
  String get fatigueWindowLabel => 'بازه بیشترین خستگی:';

  @override
  String get productiveDayLabel => 'پربازده‌ترین روز:';

  @override
  String get healthScreenTitle => 'سلامت';

  @override
  String get medicationsToday => 'داروهای امروز';

  @override
  String get doctorVisits => 'نوبت‌های پزشک';

  @override
  String get healthMonitoring => 'پایش سلامت';

  @override
  String get medicalDocuments => 'مدارک پزشکی';

  @override
  String get pregnancyTracker => 'بارداری';

  @override
  String get vaccinations => 'واکسن‌ها';

  @override
  String get allergies => 'آلرژی‌ها';

  @override
  String get medicalProfile => 'پرونده پزشکی';

  @override
  String get doctorVisitsTabUpcoming => 'پیش‌رو';

  @override
  String get doctorVisitsTabPast => 'گذشته';

  @override
  String get doctorVisitsNoUpcoming => 'هیچ نوبت پیش‌رویی ثبت نشده است.';

  @override
  String get doctorVisitsNoPast => 'هیچ نوبت گذشته‌ای ثبت نشده است.';

  @override
  String get doctorVisitsAddTitle => 'ثبت نوبت پزشک';

  @override
  String get doctorVisitsEditTitle => 'ویرایش نوبت پزشک';

  @override
  String get doctorVisitsDoctorName => 'نام پزشک';

  @override
  String get doctorVisitsSpecialty => 'تخصص (اختیاری)';

  @override
  String get doctorVisitsClinicName => 'نام کلینیک (اختیاری)';

  @override
  String get doctorVisitsClinicAddress => 'آدرس (اختیاری)';

  @override
  String get doctorVisitsClinicPhone => 'تلفن (اختیاری)';

  @override
  String get doctorVisitsReason => 'علت مراجعه (اختیاری)';

  @override
  String get doctorVisitsNotes => 'یادداشت‌ها (اختیاری)';

  @override
  String get doctorVisitsDateTime => 'تاریخ و ساعت نوبت';

  @override
  String get doctorVisitsReminder => 'یادآوری قبل از نوبت';

  @override
  String get doctorVisitsType => 'نوع نوبت';

  @override
  String get doctorVisitsTypeInPerson => 'حضوری';

  @override
  String get doctorVisitsTypeOnline => 'آنلاین';

  @override
  String get doctorVisitsTypeTelephone => 'تلفنی';

  @override
  String get doctorVisitsReminderNone => 'بدون یادآوری';

  @override
  String get doctorVisitsReminder15m => '۱۵ دقیقه قبل';

  @override
  String get doctorVisitsReminder30m => '۳۰ دقیقه قبل';

  @override
  String get doctorVisitsReminder1h => '۱ ساعت قبل';

  @override
  String get doctorVisitsReminder2h => '۲ ساعت قبل';

  @override
  String get doctorVisitsReminder1d => '۱ روز قبل';

  @override
  String get doctorVisitsSave => 'ذخیره نوبت';

  @override
  String get doctorVisitsDeleteConfirm =>
      'آیا مطمئن هستید که می‌خواهید این نوبت را حذف کنید؟';

  @override
  String get doctorVisitsAddAttachment => 'افزودن نسخه یا مدرک';

  @override
  String get doctorVisitsDelete => 'حذف نوبت';

  @override
  String get doctorVisitsCancel => 'انصراف';

  @override
  String get doctorVisitsConfirm => 'تایید';

  @override
  String get bloodSugarTitle => 'قند خون';

  @override
  String get bloodSugarValue => 'میزان قند خون (mg/dL)';

  @override
  String get bloodSugarFasting => 'ناشتا';

  @override
  String get bloodSugarBeforeMeal => 'قبل از غذا';

  @override
  String get bloodSugarAfterMeal => 'بعد از غذا';

  @override
  String get bloodSugarBedtime => 'قبل از خواب';

  @override
  String get bloodSugarRandom => 'تصادفی';

  @override
  String get bloodSugarDiabeticFlag => 'کاربر مبتلا به دیابت است';

  @override
  String get bloodSugarInRange => 'در محدوده نرمال';

  @override
  String get bloodSugarLow => 'پایین (افت قند)';

  @override
  String get bloodSugarHigh => 'بالا (قند خون بالا)';

  @override
  String get bloodSugarSave => 'ثبت قند خون';

  @override
  String get bloodSugarHistory => 'تاریخچه سنجش‌ها';

  @override
  String get bloodSugarEnterValue => 'لطفاً میزان قند خون را وارد کنید';

  @override
  String bloodSugarLastLog(Object type, Object value) {
    return 'آخرین سنجش: $value $type';
  }

  @override
  String get bloodPressureTitle => 'فشار خون';

  @override
  String get bloodPressureSystolic => 'فشار سیستولیک (میلی‌متر جیوه)';

  @override
  String get bloodPressureDiastolic => 'فشار دیاستولیک (میلی‌متر جیوه)';

  @override
  String get bloodPressurePulse => 'ضربان قلب (بار در دقیقه)';

  @override
  String get bloodPressureArm => 'دست مورد استفاده';

  @override
  String get bloodPressureArmLeft => 'دست چپ';

  @override
  String get bloodPressureArmRight => 'دست راست';

  @override
  String get bloodPressurePosition => 'وضعیت بدن';

  @override
  String get bloodPressurePositionSitting => 'نشسته';

  @override
  String get bloodPressurePositionStanding => 'ایستاده';

  @override
  String get bloodPressurePositionLying => 'خوابیده';

  @override
  String get bloodPressureSave => 'ثبت فشار خون';

  @override
  String get bloodPressureHistory => 'تاریخچه فشار خون';

  @override
  String bloodPressureLastLog(Object diastolic, Object systolic) {
    return 'آخرین فشار: $systolic/$diastolic';
  }

  @override
  String get vitalSignsTitle => 'علائم حیاتی';

  @override
  String get vitalSignsWeight => 'وزن';

  @override
  String get vitalSignsTemperature => 'دمای بدن';

  @override
  String get vitalSignsSpo2 => 'اکسیژن خون';

  @override
  String get vitalSignsWaist => 'دور کمر';

  @override
  String get vitalSignsHeight => 'قد (سانتی‌متر)';

  @override
  String get vitalSignsSave => 'ثبت علامت حیاتی';

  @override
  String get vitalSignsValue => 'مقدار';

  @override
  String get vitalSignsHistory => 'سابقه علائم حیاتی';

  @override
  String vitalSignsLastWeight(Object value) {
    return 'آخرین وزن: $value کیلوگرم';
  }

  @override
  String vitalSignsBmi(Object label, Object value) {
    return 'شاخص توده بدنی (BMI): $value ($label)';
  }

  @override
  String get vitalSignsBmiUnderweight => 'کمبود وزن';

  @override
  String get vitalSignsBmiNormal => 'نرمال';

  @override
  String get vitalSignsBmiOverweight => 'اضافه وزن';

  @override
  String get vitalSignsBmiObese => 'چاقی';

  @override
  String get medicalDocumentsTitle => 'مدارک پزشکی';

  @override
  String get medicalDocumentsAddTitle => 'ثبت مدرک جدید';

  @override
  String get medicalDocumentsEditTitle => 'ویرایش مدرک';

  @override
  String get medicalDocumentsDocTitle => 'عنوان مدرک';

  @override
  String get medicalDocumentsCategory => 'دسته‌بندی';

  @override
  String get medicalDocumentsDate => 'تاریخ آزمایش / مدرک';

  @override
  String get medicalDocumentsLabName => 'نام آزمایشگاه / مرکز درمان';

  @override
  String get medicalDocumentsSummary => 'خلاصه گزارش';

  @override
  String get medicalDocumentsDoctorNotes => 'توصیه پزشک';

  @override
  String get medicalDocumentsUserNotes => 'یادداشت کاربر';

  @override
  String get medicalDocumentsSelectImages => 'انتخاب تصاویر مدارک';

  @override
  String get medicalDocumentsHistory => 'آرشیو مدارک پزشکی';

  @override
  String get medicalDocumentsNoDocs => 'هیچ مدرک یا آزمایشی ثبت نشده است.';

  @override
  String get medicalDocumentsDeleteConfirm =>
      'آیا مطمئن هستید که می‌خواهید این مدرک و تمامی تصاویر آن را حذف کنید؟';

  @override
  String get medicalDocumentsSave => 'ذخیره مدرک';

  @override
  String medicalDocumentsCount(int count) {
    return '$count مدرک ثبت شده';
  }

  @override
  String get vaccineName => 'نام واکسن';

  @override
  String get vaccineDiseaseTarget => 'بیماری هدف';

  @override
  String get vaccineDoseNumber => 'شماره دوز';

  @override
  String get vaccineTotalDoses => 'تعداد کل دوزها';

  @override
  String get vaccineDateAdministered => 'تاریخ تزریق';

  @override
  String get vaccineNextDoseDue => 'تاریخ دوز بعدی';

  @override
  String get vaccineBatchNumber => 'شماره سری (بچ)';

  @override
  String get vaccineClinicName => 'نام کلینیک / مرکز تزریق';

  @override
  String get vaccineNotes => 'یادداشت‌ها';

  @override
  String get vaccineSave => 'ثبت واکسیناسیون';

  @override
  String vaccineDaysUntilDue(int days) {
    return '$days روز تا دوز بعدی';
  }

  @override
  String vaccineOverdue(int days) {
    return '⚠️ دوز بعدی تأخیر دارد ($days روز تأخیر)';
  }

  @override
  String get vaccineNoDoses => 'هیچ واکسنی ثبت نشده است.';

  @override
  String get allergyName => 'ماده حساسیت‌زا (آلرژن)';

  @override
  String get allergyCategory => 'دسته‌بندی آلرژی';

  @override
  String get allergyCategoryFood => 'غذایی';

  @override
  String get allergyCategoryDrug => 'دارویی';

  @override
  String get allergyCategoryEnvironment => 'محیطی';

  @override
  String get allergyCategoryOther => 'سایر';

  @override
  String get allergyReaction => 'واکنش بدنی / علائم';

  @override
  String get allergySeverity => 'شدت حساسیت';

  @override
  String get allergySeverityMild => 'خفیف';

  @override
  String get allergySeverityModerate => 'متوسط';

  @override
  String get allergySeveritySevere => 'شدید';

  @override
  String get allergySeverityLifeThreatening => 'تهدیدکننده حیات ⚠️';

  @override
  String get allergyDiagnosedDate => 'تاریخ تشخیص';

  @override
  String get allergySave => 'ثبت آلرژی';

  @override
  String get allergyNoAllergies => 'هیچ آلرژی ثبت نشده است.';

  @override
  String get allergyDeleteConfirm =>
      'آیا مطمئن هستید که می‌خواهید این آلرژی را حذف کنید؟';

  @override
  String get pregnancyTitle => 'بارداری';

  @override
  String get pregnancyLmp => 'اولین روز آخرین قاعدگی (LMP)';

  @override
  String get pregnancyEdd => 'تاریخ تخمینی زایمان (EDD)';

  @override
  String get pregnancyStart => 'شروع پایش بارداری';

  @override
  String get pregnancyEnd => 'غیرفعال‌سازی پایش';

  @override
  String pregnancyWeek(int week, int day) {
    return 'هفته $week بارداری (روز $day)';
  }

  @override
  String get pregnancyTrimester1 => 'سه ماهه اول';

  @override
  String get pregnancyTrimester2 => 'سه ماهه دوم';

  @override
  String get pregnancyTrimester3 => 'سه ماهه سوم';

  @override
  String get pregnancyNoTracker => 'پایش فعال بارداری وجود ندارد.';

  @override
  String get cycleSosButton => 'کمک فوری تسکین درد';

  @override
  String get cyclePregnancyActivate => '🤰 فعال‌سازی حالت بارداری';

  @override
  String get cyclePregnancyConfirmPrompt =>
      'آیا باردار هستید؟ با فعال‌سازی این حالت، پیگیری چرخه قاعدگی متوقف می‌شود و اطلاعات دوران بارداری نمایش داده می‌شود.';

  @override
  String get cyclePregnancyDeactivate => 'بازگشت به حالت عادی';

  @override
  String get pregnancyMedicalDisclaimer =>
      'این برنامه یک ابزار پزشکی نیست و جایگزین نظر پزشک متخصص نمی‌شود. در هر وضعیت نگران‌کننده با پزشک یا ماما تماس بگیرید.';

  @override
  String get medicationFormLabel => 'شکل دارویی';

  @override
  String get medicationRouteLabel => 'مسیر مصرف';

  @override
  String get medicationDoseLabel => 'مقدار دوز مصرفی';

  @override
  String get medicationUnitLabel => 'واحد دوز';

  @override
  String get medicationFoodRelationLabel => 'ارتباط با غذا';

  @override
  String get medicationCourseLabel => 'دوره درمان';

  @override
  String get medicationChronic => 'مزمن / دائمی';

  @override
  String get medicationLimitedCourse => 'دوره محدود';

  @override
  String get medicationStockTracking => 'پیگیری موجودی';

  @override
  String get medicationPackageSize => 'اندازه بسته';

  @override
  String get medicationRemainingStock => 'موجودی فعلی';

  @override
  String get medicationRefillWarning => 'آستانه هشدار تمدید';

  @override
  String get medicationPrescriber => 'پزشک تجویزکننده';

  @override
  String get medicationInstructions => 'دستور مصرف / توضیحات';

  @override
  String get medicationCriticalityLabel => 'اهمیت بالینی';

  @override
  String get medicationSiteRotation => 'چرخش محل تزریق';

  @override
  String get medicationActiveIngredient => 'ماده موثره / ژنریک';

  @override
  String get medicationStrength => 'قدرت / غلظت دارو';

  @override
  String get medicationDisclaimers =>
      'همواره طبق تجویز و صلاحدید پزشک خود دارو را مصرف کنید.';

  @override
  String get cycleCalendarGuide => 'راهنمای تقویم چرخه بدنی:';

  @override
  String get cyclePeriodRecorded => 'قاعدگی (ثبت‌شده)';

  @override
  String get cyclePeriodPredicted => 'دوره پیش‌بینی‌شده';

  @override
  String get cyclePredictionWindow => 'بازه احتمالی جابجایی';

  @override
  String get cycleLowConfidence => 'پیش‌بینی با اطمینان کم';

  @override
  String get cyclePmsDays => 'روزهای پیش از عادت (PMS)';

  @override
  String get cycleOvulationDay => 'روز تخمک‌گذاری';

  @override
  String get cycleFertileWindow => 'پنجره باروری (Fertile)';

  @override
  String get cycleToday => 'امروز';

  @override
  String get cycleLoggedSymptoms => 'علائم ثبت شده';

  @override
  String get cycleJumpToNext => 'پرش به دوره بعد';

  @override
  String get cycleCurrentMonth => 'ماه جاری';

  @override
  String get cycleConfidenceHigh => 'اطمینان بالا';

  @override
  String get cycleConfidenceMedium => 'اطمینان متوسط';

  @override
  String get cycleConfidenceLow => 'اطمینان کم';

  @override
  String get bridgeAuthRequired =>
      'برای استفاده از مدل ChatGPT، لطفاً وارد حساب کاربری خود شوید.';

  @override
  String get bridgeAuthRequiredAction => 'ورود به حساب کاربری';

  @override
  String get bridgeCloudflareChallenge => 'تایید امنیتی کلودفلر ضروری است.';

  @override
  String get bridgeCloudflareChallengeAction => 'تکمیل تایید امنیتی';

  @override
  String get bridgeVpnRequired =>
      'دسترسی به چت‌جی‌پی‌تی از این IP مسدود است (تحریم یا فیلترینگ). لطفاً فیلترشکن (VPN) یا تحریم‌شکن خود را فعال کرده و دوباره تلاش کنید.';

  @override
  String get bridgeVpnRequiredAction => 'فعال‌سازی فیلترشکن / تحریم‌شکن';

  @override
  String get bridgeRateLimited =>
      'محدودیت درخواست چت‌جی‌پی‌تی (Rate Limit). لطفاً کمی صبر کرده و مجدداً تلاش کنید.';

  @override
  String get bridgeRateLimitedAction => 'تلاش مجدد پس از چند دقیقه';

  @override
  String get bridgeServerError =>
      'خطای موقت در سرورهای ChatGPT. لطفاً لحظاتی دیگر مجدداً تلاش کنید.';

  @override
  String get bridgeServerErrorAction => 'تلاش مجدد';

  @override
  String get bridgeTimeout =>
      'زمان انتظار برای دریافت پاسخ از ChatGPT به پایان رسید.';

  @override
  String get bridgeTimeoutAction => 'تلاش مجدد';

  @override
  String get bridgeNetworkError =>
      'عدم دسترسی به وب‌سایت ChatGPT. لطفاً اتصال اینترنت خود را بررسی کنید.';

  @override
  String get bridgeNetworkErrorAction => 'بررسی اتصال اینترنت';

  @override
  String get bridgeComposerNotFound =>
      'فیلد ورودی متن ChatGPT هنوز آماده یا در دسترس نیست.';

  @override
  String get bridgeComposerNotFoundAction => 'بازنشانی گفتگو';

  @override
  String get bridgeNavigationLoop =>
      'صفحه چت مکرراً بازنشانی شد و امکان ادامه گفتگو وجود ندارد.';

  @override
  String get bridgeNavigationLoopAction => 'بارگذاری مجدد مرورگر';

  @override
  String get bridgeUnknownError => 'خطای ناشناخته در پل وب ChatGPT.';

  @override
  String get bridgeUnknownErrorAction => 'تلاش مجدد';

  @override
  String get bridgeDiagnosticsTitle => 'تشخیص پل هوش مصنوعی وب';

  @override
  String get bridgeDiagnosticsSubtitle =>
      'وضعیت اتصال، گزارش ردیاب و بازیابی دستی پاسخ';

  @override
  String get bridgeDiagnosticsSearchKeywords =>
      'دستیار هوشمند، پل وب، چت جی پی تی، عیب یابی، تشخیص، لاگ، پاسخ نمی‌آید';

  @override
  String get bridgeHarvestAction => 'بازیابی پاسخ از مرورگر';

  @override
  String get bridgeForceRebootAction => 'راه‌اندازی مجدد اجباری';

  @override
  String get bridgeCopyLogAction => 'کپی گزارش';

  @override
  String get bridgeLiveBrowser => 'مشاهدهٔ پنجرهٔ چت‌جی‌پی‌تی';

  @override
  String get bridgePartialAnswerWarning =>
      '⚠️ این پاسخ کامل دریافت نشد. ارتباط با مرورگر پیش از پایان پاسخ قطع شد.';

  @override
  String get bridgeChipLongPressHint =>
      'برای مشاهدهٔ جزئیات عیب‌یابی، نگه دارید';

  @override
  String get bridgeWhyAction => 'چرا؟';

  @override
  String get cyclePregnancyBannerTitle => 'حالت بارداری فعال است';

  @override
  String get cyclePregnancyBannerDesc =>
      'پیش‌بینی دوره‌ها و پنجره‌های باروری در این حالت متوقف شده است.';

  @override
  String get cycleNoPeriodsBannerTitle => 'هنوز دوره‌ای ثبت نشده است';

  @override
  String get cycleNoPeriodsBannerDesc =>
      'برای دریافت پیش‌بینی‌های دقیق و شناسایی الگوهای بدنی، اولین دوره خود را ثبت کنید.';

  @override
  String get cycleRecordFirstPeriod => 'ثبت اولین دوره';

  @override
  String get cycleEarlyDataBannerTitle => 'پیش‌بینی با داده‌های اولیه';

  @override
  String get cycleEarlyDataBannerDesc =>
      'پیش‌بینی فعلی بر اساس تنظیمات اولیه است. با ثبت حداقل ۳ چرخه، الگوی شخصی شما فعال می‌شود.';

  @override
  String get cycleBeyondHorizonBannerTitle => 'فراتر از افق پیش‌بینی';

  @override
  String get cycleBeyondHorizonBannerDesc =>
      'پیش‌بینی چرخه‌ها تا حداکثر ۲۴ ماه آینده بر اساس ثبات چرخه‌های قبلی محاسبه می‌شود.';

  @override
  String get cycleSemanticsToday => '، امروز';

  @override
  String get cycleSemanticsRecordedPeriod => '، قاعدگی ثبت شده';

  @override
  String get cycleSemanticsPredictedPeriod => '، پیش‌بینی قاعدگی';

  @override
  String get cycleSemanticsLowConfidence => ' با اطمینان کم';

  @override
  String get cycleSemanticsHighConfidence => ' با اطمینان بالا';

  @override
  String get cycleSemanticsPredictionWindow => '، بازه احتمالی جابجایی قاعدگی';

  @override
  String get cycleSemanticsOvulation => '، روز تخمک‌گذاری';

  @override
  String get cycleSemanticsFertileWindow => '، پنجره باروری';

  @override
  String get cycleSemanticsPms => '، روزهای پیش از عادت';

  @override
  String get cycleSemanticsHasLogs => '، دارای علائم ثبت‌شده';

  @override
  String get mv_kind_picker_title => 'انتخاب نوع ورزش و فعالیت';

  @override
  String get mv_kind_picker_search_hint =>
      'جستجوی ورزش (مثلاً فوتبال، شنا، کوه...)';

  @override
  String get mv_kind_picker_recent => 'اخیراً استفاده‌شده';

  @override
  String get mv_kind_picker_seasonal => 'مناسب این فصل';

  @override
  String get mv_kind_picker_all => 'همهٔ ورزش‌ها';

  @override
  String get mv_kind_picker_create_custom => 'ورزش جدید دلخواه';

  @override
  String get mv_kind_picker_empty => 'هیچ ورزشی با این مشخصات یافت نشد.';

  @override
  String get mv_custom_kind_title => 'ساخت نوع ورزش سفارشی';

  @override
  String get mv_custom_kind_name => 'نام ورزش';

  @override
  String get mv_custom_kind_family => 'دسته‌بندی اصلی';

  @override
  String get mv_custom_kind_metric => 'متریک اصلی اندازه‌گیری';

  @override
  String get mv_custom_kind_intensity => 'شدت پیش‌فرض (MET)';

  @override
  String get mv_custom_kind_saved => 'ورزش سفارشی با موفقیت ذخیره شد.';

  @override
  String get mv_onboarding_anchor_title => 'ورزش‌های ثابت هفتگی (لنگر)';

  @override
  String get mv_onboarding_anchor_add => 'افزودن زمان ثابت';

  @override
  String get mv_onboarding_anchor_skip => 'بعداً اضافه می‌کنم';

  @override
  String get mv_commitment_saved => 'تعهد ثابت ثبت شد';

  @override
  String get mv_commitment_repeat_weekly => 'تکرار هفتگی';

  @override
  String get mv_commitment_venue => 'محل یا سالن تمرین';

  @override
  String get mv_commitment_partner => 'هم‌تمرینی / تیم';

  @override
  String get mv_anchor_cancelled_this_week => 'این هفته لغو شد';

  @override
  String get mv_anchor_suggest_deactivate =>
      'آیا می‌خواهید این تعهد به طور کامل غیرفعال شود؟';

  @override
  String get mv_anchor_constraint_note =>
      'تمرین ثابت لنگر با توجه به محدودیت ثبت‌شده';

  @override
  String mv_tomorrow_anchor_notice(String title, String time) {
    return 'یادآوری: فردا $title (ساعت $time)';
  }

  @override
  String get mv_conflict_back_to_back =>
      'توجه: دو روز ورزش متوالی با تعهد ثابت تنظیم شده است.';

  @override
  String get mv_reason_anchor => 'جلسهٔ ثابت لنگر برنامه‌ریزی شده شما';

  @override
  String get mv_reason_pre_anchor_taper =>
      'کاهش حجم تمرینی جهت حفظ توان برای جلسهٔ لنگر فردا';

  @override
  String get mv_reason_post_anchor_recovery =>
      'ریکاوری و بازتوانی پس از جلسهٔ فشردهٔ لنگر دیروز';

  @override
  String get mv_reason_complement =>
      'تمرین مکمل قدرتی جهت تعادل عضلانی و حمایت از ورزش اصلی';

  @override
  String get mv_reason_who_gap =>
      'جبران کسری فعالیت معادل متوسط جهت دستیابی به هدف ۱۵۰ دقیقه در هفته';

  @override
  String get mv_reason_strength_quota =>
      'تکمیل سهمیهٔ ۲ جلسه تمرین تقویتی عضلانی در هفته';

  @override
  String get mv_reason_rest_guaranteed =>
      'روز استراحت ضروری جهت بازسازی فیزیولوژیک';

  @override
  String get mv_reason_readiness_low =>
      'تعدیل فشار تمرین به دلیل سطح آمادگی پایین امروز';

  @override
  String get mv_reason_load_cap =>
      'کنترل سقف افزایش بار هفتگی برای پیشگیری از خستگی مفرط';

  @override
  String get mv_reason_fallback_minimum =>
      'حداقل فعالیت مؤثر ۱۰ دقیقه‌ای برای حفظ زنجیره';

  @override
  String get mv_reason_season_fit => 'ورزش متناسب با فصل جاری';

  @override
  String get mv_reason_constraint_relaxed =>
      'تطبیق تمرین با شرایط و امکانات فعلی';

  @override
  String get mv_metric_distance => 'مسافت (کیلومتر)';

  @override
  String get mv_metric_elevation => 'ارتفاع (متر)';

  @override
  String get mv_metric_laps => 'تعداد دور / طول';

  @override
  String get mv_metric_pack_weight => 'وزن کوله (کیلوگرم)';

  @override
  String get mv_metric_duration => 'مدت زمان (دقیقه)';

  @override
  String get mv_effort_question => 'فشار این تمرین چطور بود؟';

  @override
  String get mv_effort_easy => 'آسان';

  @override
  String get mv_effort_good => 'مناسب';

  @override
  String get mv_effort_hard => 'سخت';

  @override
  String get mv_effort_refine => 'تنظیم دقیق با اسلایدر RPE';

  @override
  String get mv_new_personal_record => 'رکورد شخصی جدید! 🎉';

  @override
  String get mv_load_band_low => 'بار سبک';

  @override
  String get mv_load_band_optimal => 'بار بهینه و سازنده';

  @override
  String get mv_load_band_watch => 'بار رو به افزایش';

  @override
  String get mv_load_band_spike => 'جهش بار تمرینی (نیازمند احتیاط)';

  @override
  String get mv_budget_moderate_minutes => 'دقیقه فعالیت معادل متوسط';

  @override
  String get mv_budget_strength_days => 'روز تمرین قدرتی';

  @override
  String get mv_budget_remaining => 'باقیمانده تا هدف سلامت هفتگی';

  @override
  String get mv_streak_insufficient =>
      'برای محاسبهٔ تداوم، حداقل ۲ هفته فعالیت لازم است';

  @override
  String get mv_readiness_no_checkin => 'سطح آمادگی امروز هنوز ثبت نشده است';

  @override
  String get mv_need_n_more_sessions =>
      'چند جلسهٔ دیگر برای ارزیابی دقیق مورد نیاز است';

  @override
  String get mv_insufficient_data_generic => 'دادهٔ کافی ثبت نشده است';

  @override
  String get mv_insight_best_day => 'روز طلایی تمرین';

  @override
  String get mv_insight_anchor_adherence => 'پایبندی به لنگرها';

  @override
  String get mv_insight_effort_drift => 'روند ادراک فشار';

  @override
  String get mv_insight_kind_mix => 'تنوع ورزشی ماهانه';

  @override
  String get mv_insight_route_progress => 'پیشرفت در مسیر تکراری';

  @override
  String get mv_campaign_title => 'دورهٔ هدف‌دار';

  @override
  String get mv_campaign_target_date => 'تاریخ رویداد هدف:';

  @override
  String get mv_campaign_phase_base => 'مرحله پایه';

  @override
  String get mv_campaign_phase_build => 'مرحله بارگذاری تدریجی';

  @override
  String get mv_campaign_phase_taper => 'مرحله کاهش حجم و آماده‌سازی';

  @override
  String get mv_campaign_too_short =>
      'زمان باقیمانده تا رویداد کمتر از ۴ هفته است';

  @override
  String get mv_route_select => 'انتخاب مسیر';

  @override
  String get mv_route_new => 'ثبت مسیر جدید';

  @override
  String mv_route_times_done(int count) {
    return 'دفعات انجام: $count';
  }

  @override
  String mv_route_best_time(int minutes) {
    return 'بهترین زمان: $minutes دقیقه';
  }

  @override
  String get mv_day_plan_title => 'برنامهٔ روز';

  @override
  String get mv_library_title => 'کتابخانهٔ ورزشی';

  @override
  String get mv_week_plan_title => 'برنامهٔ هفته';

  @override
  String get mv_library_tab_kinds => 'انواع ورزش';

  @override
  String get mv_library_tab_exercises => 'تمرین‌ها';

  @override
  String get mv_commitments_title => 'ورزش‌های ثابت هفتگی';

  @override
  String get mv_commitments_empty =>
      'هنوز ورزش ثابتی ثبت نکرده‌اید. با افزودن لنگر، برنامهٔ هفتگی به طور هوشمند حول زمان‌های شما تنظیم می‌شود.';

  @override
  String get mv_commitment_add => 'افزودن ورزش ثابت';

  @override
  String get mv_commitment_edit => 'ویرایش ورزش ثابت';

  @override
  String get mv_commitment_delete => 'حذف ورزش ثابت';

  @override
  String get mv_commitment_day_label => 'روز هفته';

  @override
  String get mv_commitment_time_label => 'ساعت شروع';

  @override
  String get mv_commitment_duration_label => 'مدت (دقیقه)';

  @override
  String get mv_commitment_recurrence_label => 'تکرار';

  @override
  String get mv_commitment_venue_label => 'محل تمرین (اختیاری)';

  @override
  String get mv_commitment_reminder_label => 'یادآوری';

  @override
  String get mv_week_anchor_cta => 'تعریف ورزش ثابت هفتگی';

  @override
  String get mv_week_anchor_cta_text =>
      'روزهای فوتسال، شنا یا کوهنوردی ثابت دارید؟ برنامهٔ هفته هوشمندانه دور آنها چیده می‌شود.';

  @override
  String get mv_settings_anchors_section => 'مدیریت ورزش‌های ثابت (لنگر)';

  @override
  String get mv_campaign_create => 'ساخت دورهٔ تمرینی';

  @override
  String mv_campaign_active_phase(
    String phase,
    int currentWeek,
    int totalWeeks,
  ) {
    return 'فاز $phase • هفتهٔ $currentWeek از $totalWeeks';
  }

  @override
  String get mv_plan_change_kind => 'تغییر نوع ورزش';

  @override
  String get mv_hub_title => 'ورزش و حرکت';

  @override
  String get mv_tab_today => 'امروز';

  @override
  String get mv_tab_week => 'هفته';

  @override
  String get mv_tab_progress => 'پیشرفت';

  @override
  String get mv_library_tooltip => 'کتابخانهٔ حرکات';

  @override
  String get mv_coach_tooltip => 'دستیار و مربی';

  @override
  String get mv_settings_tooltip => 'تنظیمات ورزشی';

  @override
  String mv_week_title(int cycleWeek) {
    return 'برنامهٔ هفتگی (هفتهٔ $cycleWeek)';
  }

  @override
  String get mv_week_regenerate => 'بازتولید برنامه';

  @override
  String get mv_week_deload_badge => 'هفته سبک';

  @override
  String get mv_week_deload_subtitle => 'هفتهٔ سبک برای بازیابی بدنی';

  @override
  String get mv_week_regular_subtitle => 'برنامهٔ منظم تمرین و ریکاوری';

  @override
  String get mv_settings_title => 'تنظیمات ورزشی';

  @override
  String get mv_settings_save => 'ذخیره';

  @override
  String get mv_settings_program_goals => 'برنامه و اهداف';

  @override
  String get mv_settings_days_per_week => 'تعداد روزهای تمرین در هفته:';

  @override
  String mv_settings_n_days(int days) {
    return '$days روز';
  }

  @override
  String get mv_settings_session_duration => 'مدت هر جلسه:';

  @override
  String get mv_settings_dur_short => 'کوتاه (۱۵ دقیقه)';

  @override
  String get mv_settings_dur_medium => 'متوسط (۳۰ دقیقه)';

  @override
  String get mv_settings_dur_long => 'بلند (۴۵+ دقیقه)';

  @override
  String get mv_settings_default_intensity => 'شدت پیش‌فرض:';

  @override
  String get mv_settings_env_equipment => 'محیط و تجهیزات';

  @override
  String get mv_settings_neighbor_mode => 'حالت همسایه‌پسند (آپارتمانی)';

  @override
  String get mv_settings_neighbor_desc => 'حذف خودکار تمام حرکات پرشی و پرصدا';

  @override
  String get mv_settings_audio_section => 'راهنمای صوتی و انیمیشن';

  @override
  String get mv_settings_voice_cues => 'راهنمای صوتی مربی';

  @override
  String get mv_settings_voice_desc =>
      'پخش پیام‌های شروع، استراحت و شمارش معکوس';

  @override
  String get mv_settings_privacy_section => 'حریم خصوصی و داده‌های فیزیولوژیک';

  @override
  String get mv_settings_cycle_consent => 'تطبیق شدت با چرخهٔ فیزیولوژیک';

  @override
  String get mv_settings_cycle_desc =>
      'پیشنهاد روزهای سبک در فاز استراحت چرخه (کاملاً آفلاین و با رضایت کاربر)';

  @override
  String get mv_settings_advanced_section => 'پیشرفته';

  @override
  String get mv_settings_regen_title => 'بازسازی برنامهٔ هفتگی';

  @override
  String get mv_settings_regen_desc =>
      'برنامهٔ روزها را بازسازی می‌کند بدون اینکه سوابق ورزشی قبلی حذف شود.';

  @override
  String get mv_quick_log_title => 'ثبت سریع فعالیت';

  @override
  String get mv_quick_log_subtitle =>
      'مدت‌زمان فعالیتت را مشخص کن تا در آمار هفتگی ثبت شود.';

  @override
  String get mv_quick_log_kind => 'نوع فعالیت';

  @override
  String get mv_quick_log_more => 'بیشتر...';

  @override
  String get mv_quick_log_duration => 'مدت‌زمان (دقیقه)';

  @override
  String mv_quick_log_duration_min(int minutes) {
    return '$minutes دقیقه';
  }

  @override
  String get mv_quick_log_feeling_prompt => 'احساس چطور بود؟ (اختیاری)';

  @override
  String get mv_quick_log_feeling_easy => 'راحت / جا داشتم';

  @override
  String get mv_quick_log_feeling_good => 'خوب و متناسب';

  @override
  String get mv_quick_log_feeling_hard => 'سخت و چالشی';

  @override
  String mv_quick_log_submit(int minutes) {
    return 'ثبت فعالیت ($minutes دقیقه)';
  }

  @override
  String get mv_exercise_fallback => 'حرکت ورزشی';

  @override
  String get mv_audio_mute_tooltip => 'خاموش کردن راهنمای صوتی';

  @override
  String get mv_audio_unmute_tooltip => 'روشن کردن راهنمای صوتی';

  @override
  String get mv_body_map_weekly_title => 'نقشهٔ عضلانی این هفته';

  @override
  String get mv_slot_anchor_badge_label => 'ورزش ثابت';

  @override
  String get mv_slot_rest_badge_label => 'استراحت';

  @override
  String get mv_insufficient_data_default_title => 'هنوز دادهٔ کافی نیست';

  @override
  String get mv_metric_ring_active_mins => 'دقیقهٔ فعال این هفته';

  @override
  String mv_metric_ring_active_days(String activeDays, String targetDays) {
    return '$activeDays از $targetDays روز فعال';
  }

  @override
  String mv_metric_ring_completed_pct(String percent) {
    return '$percent٪ تکمیل شده';
  }

  @override
  String get mv_quick_log_custom_action => 'ثبت سایر...';

  @override
  String get mv_quick_log_walk_20 => 'پیاده‌روی ۲۰ دقیقه';

  @override
  String get mv_quick_log_stretch_10 => '۱۰ دقیقه نرمش سبک';

  @override
  String get mv_hero_rest_title => 'روز استراحت و ریکاوری';

  @override
  String get mv_hero_minimal_title => 'حداقل مؤثر ۱۰ دقیقه‌ای';

  @override
  String get mv_hero_rest_subtitle =>
      'بدنت به زمان برای بازسازی نیاز دارد. کشش سبک بهترین همراه امروز است.';

  @override
  String get mv_hero_minimal_subtitle =>
      'امروز فقط ۱۰ دقیقه. همین هم زنجیره‌ات را فعال نگه می‌دارد.';

  @override
  String get mv_hero_completed => 'جلسهٔ امروز با موفقیت انجام شد';

  @override
  String get mv_hero_rest_action => 'کشش سبک ۵ دقیقه';

  @override
  String get mv_hero_continue => 'ادامهٔ جلسه';

  @override
  String get mv_hero_start => 'شروع جلسه';

  @override
  String get mv_hero_cant_today => 'نمی‌تونم';

  @override
  String get mv_exercise_default_title => 'تمرین';

  @override
  String get mv_player_rest_time => 'زمان استراحت';

  @override
  String get mv_player_skip_exercise_tooltip => 'رد کردن حرکت';

  @override
  String get mv_player_breathe_ready => 'نفس عمیق بکش و آماده شو';

  @override
  String mv_player_exercise_counter(String current, String total) {
    return 'حرکت $current از $total';
  }

  @override
  String mv_player_set_counter(String current, String total) {
    return 'ست $current از $total';
  }

  @override
  String mv_player_seconds_remaining(String seconds) {
    return '$seconds ثانیه';
  }

  @override
  String mv_player_reps(String reps) {
    return '$reps تکرار';
  }

  @override
  String get mv_player_focus_contraction => 'تمرکز روی انقباض عضله';

  @override
  String get mv_player_skip_rest_action => 'رد کردن استراحت و شروع';

  @override
  String mv_player_complete_set_action(String setNumber) {
    return 'ثبت ست و ادامه (ست $setNumber)';
  }

  @override
  String get mv_summary_title => 'خلاصهٔ جلسه';

  @override
  String mv_summary_mins_done(String minutes) {
    return '$minutes دقیقه تمرین ثبت شد';
  }

  @override
  String get mv_summary_effort_question => 'میزان تلاش این جلسه چطور بود؟';

  @override
  String get mv_summary_effort_easy => 'راحت و آسان';

  @override
  String get mv_summary_effort_good => 'خوب و متناسب';

  @override
  String get mv_summary_effort_hard => 'سخت و چالشی';

  @override
  String get mv_summary_fine_tune_rpe => 'دقیق‌ترش کنم (RPE)';

  @override
  String get mv_summary_free_note_label => 'یادداشت آزاد اختیاری';

  @override
  String get mv_summary_free_note_hint =>
      'مثلاً هوا عالی بود، شیب تند بود، یا حس پیشرفت داشتم...';

  @override
  String get mv_summary_new_pr_title => 'رکورد شخصی جدید (PR)! 🎉';

  @override
  String mv_summary_new_pr_desc(String exercise, String record) {
    return 'در حرکت $exercise به رکورد $record رسیدی.';
  }

  @override
  String mv_summary_equiv_mins_added(String minutes) {
    return '+$minutes دقیقه فعالیت معادل به این هفته اضافه شد';
  }

  @override
  String get mv_summary_goal_achieved =>
      'هدف هفتگی ۱۵۰ دقیقه با موفقیت کامل شد! 🎯';

  @override
  String mv_summary_mins_remaining_to_goal(String minutes) {
    return '$minutes دقیقه تا دستیابی به هدف هفتگی مانده';
  }

  @override
  String get mv_summary_save_session => 'ثبت جلسه و ذخیره';

  @override
  String mv_summary_error_save(String error) {
    return 'خطا در ذخیره جلسه: $error';
  }

  @override
  String get mv_stat_distance => 'مسافت';

  @override
  String get mv_stat_elevation => 'ارتفاع صعود';

  @override
  String get mv_stat_pack_weight => 'وزن کوله';

  @override
  String get mv_stat_tempo => 'تمپو';

  @override
  String get mv_stat_laps => 'تعداد دور';

  @override
  String get mv_stat_duration => 'مدت‌زمان';

  @override
  String get mv_stat_match_duration => 'مدت مسابقه';

  @override
  String get mv_stat_session_load => 'بار جلسه';

  @override
  String get mv_stat_logged_sets => 'ست‌های ثبت‌شده';

  @override
  String get mv_unit_km => 'کیلومتر';

  @override
  String get mv_unit_m => 'متر';

  @override
  String get mv_unit_kg => 'کیلوگرم';

  @override
  String get mv_unit_laps => 'دور';

  @override
  String get mv_unit_min => 'دقیقه';

  @override
  String get mv_unit_set => 'ست';

  @override
  String get mv_unit_pace => 'دق/کم';

  @override
  String get mv_template_distance_title => 'جلسه مسافتی';

  @override
  String get mv_template_distance_adjust => 'تنظیم مسافت';

  @override
  String mv_template_rpe_label(String rpe) {
    return 'میزان تلاش (RPE: $rpe)';
  }

  @override
  String get mv_template_finish => 'پایان جلسه';

  @override
  String get mv_template_laps_title => 'جلسه دورمحور';

  @override
  String get mv_template_laps_recorded => 'دور ثبت‌شده';

  @override
  String get mv_template_plus_1_lap => '+۱ دور ثبت شد';

  @override
  String get mv_template_match_title => 'مسابقه و بازی';

  @override
  String get mv_template_half_1 => 'نیمه اول / ست اول';

  @override
  String get mv_template_half_2 => 'نیمه دوم / ست دوم';

  @override
  String get mv_template_start_half_2 => 'شروع نیمه دوم';

  @override
  String get mv_template_team_us => 'ما';

  @override
  String get mv_template_team_them => 'حریف';

  @override
  String get mv_template_match_note_label =>
      'یادداشت مسابقه (گل‌ها، کارت‌ها، حریف...)';

  @override
  String get mv_template_finish_match => 'پایان مسابقه';

  @override
  String get mv_template_route_title => 'جلسه مسیر و کوه';

  @override
  String get mv_template_route_label => 'مسیر';

  @override
  String get mv_template_route_free => 'مسیر آزاد';

  @override
  String get mv_template_route_tochal => 'توچال - شیرپلا';

  @override
  String get mv_template_route_darakeh => 'درکه - پلنگ‌چال';

  @override
  String get mv_template_timed_title => 'جلسه زمانی';

  @override
  String get mv_template_phase_warmup => 'گرم کردن';

  @override
  String get mv_template_phase_main => 'تمرین اصلی';

  @override
  String get mv_template_phase_cooldown => 'سرد کردن';

  @override
  String get mv_commitment_flexible_title => 'شناوری هوشمند روز';

  @override
  String get mv_commitment_flexible_subtitle =>
      'در صورت خستگی یا فشردگی، امکان جابجایی روز وجود داشته باشد';

  @override
  String get mv_commitment_select_kind_error =>
      'لطفاً نوع ورزش را انتخاب کنید.';

  @override
  String get mv_action_save => 'ذخیره';

  @override
  String get mv_action_more => 'بیشتر...';

  @override
  String get mv_action_none => 'بدون';

  @override
  String get mv_action_weekly => 'هفتگی';

  @override
  String get mv_action_biweekly => 'دوهفته‌یک‌بار';

  @override
  String get mv_action_once => 'یک‌بار';

  @override
  String get mv_action_30_min => '۳۰ دقیقه';

  @override
  String get mv_action_2_hours => '۲ ساعت';

  @override
  String get mv_action_1_day => '۱ روز';

  @override
  String get mv_substitute_title => 'جایگزینی حرکت';

  @override
  String mv_substitute_reason_prompt(String exercise) {
    return 'علت جایگزینی «$exercise» را مشخص کن.';
  }

  @override
  String get mv_substitute_too_hard => 'سخت است';

  @override
  String get mv_substitute_pain => 'احساس درد یا ناراحتی';

  @override
  String get mv_substitute_no_equipment => 'وسیله ندارم';

  @override
  String get mv_substitute_noise => 'سروصدا دارد';

  @override
  String get mv_substitute_suggestions => 'حرکات پیشنهادی جایگزین';

  @override
  String get mv_substitute_empty => 'حرکت جایگزین دیگری با این شرایط یافت نشد.';

  @override
  String get mv_substitute_select => 'انتخاب';

  @override
  String get mv_checkin_title => 'آمادگی امروزت چطوره؟';

  @override
  String get mv_checkin_subtitle =>
      'با یک لمس، برنامهٔ امروز متناسب با انرژی بدنت تنظیم می‌شود.';

  @override
  String get mv_checkin_great_title => 'عالی و پرانرژی';

  @override
  String get mv_checkin_great_desc => 'آماده برای جلسهٔ کامل';

  @override
  String get mv_checkin_good_title => 'خوب و معمولی';

  @override
  String get mv_checkin_good_desc => 'انرژی متناسب';

  @override
  String get mv_checkin_tired_title => 'خسته یا کوفته';

  @override
  String get mv_checkin_tired_desc => 'پیشنهاد جلسه سبک';

  @override
  String get mv_checkin_close_details => 'بستن جزئیات دقیق‌تر';

  @override
  String get mv_checkin_open_details => 'ثبت دقیق‌تر (درد، کوفتگی و خستگی)...';

  @override
  String get mv_checkin_energy_label => 'سطح انرژی (۱ تا ۵):';

  @override
  String get mv_checkin_soreness_label => 'کوفتگی عضلانی (۱ تا ۵):';

  @override
  String get mv_checkin_fatigue_label => 'خستگی عمومی (۱ تا ۵):';

  @override
  String get mv_checkin_pain_label => 'میزان درد موضعی (۰ تا ۱۰):';

  @override
  String get mv_checkin_submit_details => 'ثبت جزئیات دقیق';

  @override
  String get mv_kind_picker_subtitle =>
      'از میان بیش از ۴۰ نوع فعالیت ورزشی و حرکتی';

  @override
  String get mv_kind_picker_tab_all => 'همه';

  @override
  String get mv_kind_picker_outdoor => 'فضای باز 🌿';

  @override
  String get mv_kind_picker_hall => 'نیازمند سالن 🏟';

  @override
  String mv_kind_picker_impact(String impact) {
    return 'ضربه: $impact/3';
  }

  @override
  String mv_kind_picker_unit(String unit) {
    return 'واحد: $unit';
  }

  @override
  String get mv_kind_picker_create_new => 'تعریف ورزش یا فعالیت جدید';

  @override
  String get mv_day_plan_type => 'نوع برنامه';

  @override
  String get mv_day_plan_kind_select => 'نوع ورزش / فعالیت';

  @override
  String get mv_day_plan_kind_picker_prompt => 'انتخاب نوع حرکت...';

  @override
  String mv_day_plan_met_factor(String met) {
    return 'ضریب MET: $met';
  }

  @override
  String get mv_day_plan_change => 'تغییر';

  @override
  String mv_day_plan_custom_header(String title) {
    return 'ورزش تخصصی $title';
  }

  @override
  String mv_day_plan_custom_desc(String met) {
    return 'ورزش توپی/تخصصی — کالری‌سوزی و ردیابی زمان جلسه بر اساس ضریب مت ($met MET)';
  }

  @override
  String get mv_day_plan_target_minutes => 'مدت هدف (دقیقه)';

  @override
  String get mv_day_plan_start_time => 'ساعت شروع (اختیاری)';

  @override
  String get mv_day_plan_not_set => 'مشخص نشده';

  @override
  String get mv_day_plan_venue => 'مکان یا سالن (اختیاری)';

  @override
  String get mv_day_plan_venue_hint => 'مثلاً سالن شهدای غواص، زمین چمن آزادی';

  @override
  String get mv_day_plan_intensity => 'شدت تمرین';

  @override
  String get mv_day_plan_focus => 'تمرکز عضلانی';

  @override
  String get mv_day_plan_repeat_weekly => 'هر هفته تکرار شود';

  @override
  String get mv_day_plan_repeat_weekly_desc =>
      'این فعالیت در هفته‌های بعد در همین روز قرار می‌گیرد';

  @override
  String get mv_day_plan_custom_title => 'عنوان دلخواه (اختیاری)';

  @override
  String get mv_day_plan_save => 'ثبت و ذخیره برنامه';

  @override
  String get mv_plan_rest => 'استراحت';

  @override
  String get mv_plan_strength => 'تمرین قدرتی';

  @override
  String get mv_commitment_select_kind => 'لطفاً نوع ورزش را انتخاب کنید.';

  @override
  String get mv_commitment_pick_more => 'بیشتر...';

  @override
  String get mv_commitment_recurrence_weekly => 'هفتگی';

  @override
  String get mv_commitment_recurrence_biweekly => 'دوهفته‌یک‌بار';

  @override
  String get mv_commitment_recurrence_once => 'یک‌بار';

  @override
  String get mv_commitment_reminder_none => 'بدون';

  @override
  String get mv_commitment_reminder_30m => '۳۰ دقیقه';

  @override
  String get mv_commitment_reminder_2h => '۲ ساعت';

  @override
  String get mv_commitment_reminder_1d => '۱ روز';

  @override
  String get mv_commitment_smart_flexibility => 'شناوری هوشمند روز';

  @override
  String get mv_commitment_smart_flexibility_desc =>
      'در صورت خستگی یا فشردگی، امکان جابجایی روز وجود داشته باشد';

  @override
  String get mv_custom_kind_metric_duration => 'فقط زمان (دقیقه)';

  @override
  String get mv_custom_kind_metric_distance => 'مسافت (کیلومتر)';

  @override
  String get mv_custom_kind_metric_sets => 'ست و تکرار';

  @override
  String get mv_custom_kind_metric_laps => 'دور / طول';

  @override
  String get mv_custom_kind_name_error => 'لطفاً نام ورزش را وارد کنید';

  @override
  String mv_custom_kind_save_error(String error) {
    return 'خطا در ذخیره‌سازی: $error';
  }

  @override
  String get mv_custom_kind_sheet_title => 'ورزش سفارشی جدید';

  @override
  String get mv_custom_kind_sheet_subtitle =>
      'ورزش یا فعالیت دلخواهت را به کتابخانه اضافه کن';

  @override
  String get mv_custom_kind_name_label => 'نام ورزش یا فعالیت';

  @override
  String get mv_custom_kind_name_hint => 'مثلاً پدل، اسکواش، تیراندازی...';

  @override
  String get mv_custom_kind_emoji_label => 'انتخاب نماد (ایموجی)';

  @override
  String get mv_custom_kind_family_label => 'دسته‌بندی (خانواده)';

  @override
  String mv_custom_kind_met_label(String met) {
    return 'شدت انرژی متابولیک (MET): $met';
  }

  @override
  String get mv_custom_kind_metric_label => 'متریک ثبت اصلی';

  @override
  String get mv_custom_kind_venue_switch => 'نیاز به سالن یا زمین اختصاصی دارد';

  @override
  String get mv_custom_kind_outdoor_switch => 'در فضای باز انجام می‌شود';

  @override
  String get mv_custom_kind_submit_btn => 'افزودن به ورزش‌ها';

  @override
  String get mv_pr_title => 'رکوردهای شخصی';

  @override
  String get mv_pr_empty_desc =>
      'هنوز رکوردی ثبت نشده است. با اتمام جلسات تمرین، رکوردهای جدید شما در اینجا ثبت می‌شوند.';

  @override
  String get mv_pr_by_sport => 'رکوردهای شخصی به تفکیک ورزش';

  @override
  String get mv_campaign_active_header => 'دورهٔ هدف‌دار فعال';

  @override
  String mv_campaign_pack_weight_label(String weight) {
    return 'وزن کوله‌پشتی هدف این هفته: $weight کیلوگرم';
  }

  @override
  String get mv_campaign_inactive_desc =>
      'برنامه‌ریزی معکوس و تمرین برای رویداد ورزشی (کوهنوردی، پیمایش و ...)';

  @override
  String get mv_streak_continuous_weeks => 'هفته‌های فعال پیوسته';

  @override
  String mv_streak_weeks_count(String count) {
    return '$count هفته';
  }

  @override
  String get mv_progress_insights => 'بینش‌های پیشرفت';

  @override
  String get mv_campaign_target_sport => 'نوع ورزش هدف:';

  @override
  String mv_campaign_hiking_title(String code) {
    return 'کوهنوردی و پیمایش ($code)';
  }

  @override
  String mv_campaign_weeks_later(String weeks, String date) {
    return '$weeks هفته بعد ($date)';
  }

  @override
  String get mv_campaign_body_weight => 'وزن بدن (کیلوگرم):';

  @override
  String get mv_campaign_submit => 'ثبت دوره';

  @override
  String mv_commitment_recurrence_summary(
    String day,
    String time,
    String duration,
  ) {
    return 'هر $day ساعت $time • $duration دقیقه';
  }

  @override
  String get mv_day_detail_edit_tooltip => 'ویرایش برنامه';

  @override
  String mv_day_detail_session_exercises(int count) {
    return 'حرکات این جلسه ($count حرکت)';
  }

  @override
  String mv_day_detail_reps_count(int count) {
    return '$count تکرار';
  }

  @override
  String get mv_day_detail_timed => 'زمان‌دار';

  @override
  String get mv_day_detail_start_session => 'شروع جلسهٔ تمرینی';

  @override
  String get mv_library_tab_programs => 'برنامه‌ها';

  @override
  String get mv_library_search_exercises_hint =>
      'جستجوی حرکت (مثلاً شنا، اسکات، پلانک)...';

  @override
  String get mv_library_filter_apartment => 'بی‌صدا (آپارتمانی)';

  @override
  String get mv_library_filter_no_equipment => 'بدون وسیله';

  @override
  String get mv_library_exercises_empty_title => 'حرکتی پیدا نشد';

  @override
  String get mv_library_exercises_empty_desc =>
      'فیلترها را تغییر بده یا عبارت دیگری را جستجو کن.';

  @override
  String mv_library_exercise_skill(String skill) {
    return 'مهارت: سطح $skill';
  }

  @override
  String get mv_library_exercise_noisy => 'پرصدا';

  @override
  String get mv_library_exercise_quiet => 'بی‌صدا / آپارتمانی';

  @override
  String get mv_library_exercise_low_impact => 'کم‌ضربه';

  @override
  String get mv_library_exercise_start_now => 'شروع آنی این حرکت';

  @override
  String get mv_library_programs_title => 'برنامه‌های تمرینی ۴ هفته‌ای';

  @override
  String get mv_library_programs_desc =>
      'برنامه‌ها بر اساس سطح و اهداف شما از تب هفته قابل تنظیم و بازتولید هستند.';

  @override
  String get mv_library_search_kinds_hint =>
      'جستجوی ورزش و فعالیت (مثلاً فوتبال، شنا، پدل)...';

  @override
  String get mv_library_create_custom_kind => 'ورزش سفارشی جدید';

  @override
  String get mv_library_kinds_empty_title => 'ورزشی پیدا نشد';

  @override
  String get mv_library_kinds_empty_desc =>
      'می‌توانی ورزش جدیدی به لیست اضافه کنی.';

  @override
  String get mv_library_custom_tag => 'سفارشی';

  @override
  String mv_library_kind_intensity(String family, String met) {
    return '$family · شدت انرژی: $met MET';
  }

  @override
  String get mv_onboarding_title => 'برنامهٔ ورزشی اختصاصی تو';

  @override
  String get mv_onboarding_subtitle =>
      'با پاسخ به چند سؤال کوتاه، برنامهٔ هفته‌ات را بساز.';

  @override
  String get mv_onboarding_q1_title => '۱. چند روز در هفته می‌خواهی ورزش کنی؟';

  @override
  String mv_onboarding_days_count(String count) {
    return '$count روز';
  }

  @override
  String get mv_onboarding_q2_title => '۲. چقدر زمان داری در هر جلسه؟';

  @override
  String get mv_onboarding_dur_short => '۱۵ دقیقه (کوتاه و سریع)';

  @override
  String get mv_onboarding_dur_medium => '۳۰ دقیقه (متعادل و ایده‌آل)';

  @override
  String get mv_onboarding_dur_long => '۴۵ دقیقه یا بیشتر';

  @override
  String get mv_onboarding_q3_title => '۳. محیط تمرینت کجاست؟';

  @override
  String get mv_onboarding_loc_home => 'خانه (بدون وسیله)';

  @override
  String get mv_onboarding_loc_gym => 'باشگاه ورزشی';

  @override
  String get mv_onboarding_loc_outdoor => 'فضای باز / پارک';

  @override
  String get mv_onboarding_q4_title =>
      '۴. ورزش ثابتی داری که هفته‌ای انجام بدهی؟';

  @override
  String get mv_onboarding_q4_subtitle =>
      'مثل فوتسال پنجشنبه‌ها یا استخر جمعه‌ها (اختیاری)';

  @override
  String get mv_onboarding_anchor_yes => 'بله، اضافه کنم';

  @override
  String get mv_onboarding_anchor_no => 'فعلاً نه';

  @override
  String get mv_onboarding_anchor_add_another => 'افزودن ورزش ثابت دیگر';

  @override
  String get mv_onboarding_submit => 'شروع برنامه و ورود به ریتمو';

  @override
  String mv_onboarding_anchor_sheet_title(String title, String emoji) {
    return 'تنظیم ورزش ثابت: $title $emoji';
  }

  @override
  String get mv_onboarding_anchor_sheet_day => 'روز هفته';

  @override
  String get mv_onboarding_anchor_sheet_time => 'ساعت شروع';

  @override
  String get mv_onboarding_anchor_sheet_duration => 'مدت زمان (دقیقه)';

  @override
  String get mv_onboarding_anchor_sheet_confirm => 'تأیید و افزودن';

  @override
  String get mv_weekly_health_title => 'سلامت این هفته';

  @override
  String get mv_weekly_health_empty =>
      'هنوز در این هفته فعالیتی ثبت نشده است. با ثبت اولین جلسه، پیشرفت نمایش داده می‌شود.';

  @override
  String get mv_weekly_health_who => 'سلامت این هفته (توصیه بهداشت جهانی)';

  @override
  String get mv_weekly_health_moderate => 'فعالیت معادل متوسط';

  @override
  String mv_weekly_health_min_progress(String current, String target) {
    return '$current / $target دقیقه';
  }

  @override
  String get mv_weekly_health_strength => 'روزهای قدرتی و مقاومتی';

  @override
  String mv_weekly_health_day_progress(String current, String target) {
    return '$current / $target روز';
  }

  @override
  String get mv_training_load_title => 'بار تمرینی و تعادل فشار';

  @override
  String get mv_training_load_insufficient =>
      'حداقل ۱۴ روز سابقه و ثبت چند جلسهٔ دیگر لازم است تا نسبت بار حاد به مزمن (ACWR) به درستی محاسبه شود.';

  @override
  String get mv_training_load_card_title => 'بار تمرینی (۷ روز به ۲۸ روز)';

  @override
  String get mv_training_load_acute => 'بار حاد (۷ روز)';

  @override
  String get mv_training_load_chronic => 'میانگین هفتگی ۲۸ روز';

  @override
  String mv_training_load_summary(String ratio, String band) {
    return 'به نظر می‌رسد در ۴ هفتهٔ گذشته، نسبت بار حاد به مزمن شما $ratio بوده و در محدودهٔ $band قرار دارد.';
  }

  @override
  String get mv_kind_distribution_title => 'توزیع ورزش‌ها در این ماه';

  @override
  String get mv_kind_distribution_insufficient =>
      'برای نمایش سهم ورزش‌ها، حداقل به ثبت یک جلسه تمرین در ماه جاری نیاز است.';

  @override
  String get mv_kind_distribution_card_title => 'توزیع ورزش‌ها در ماه جاری';

  @override
  String mv_kind_distribution_progress(String minutes, String percent) {
    return '$minutes دقیقه ($percent٪)';
  }

  @override
  String mv_kind_distribution_focus(String sport) {
    return 'بیشترین تمرکز فعالیت شما بر $sport بوده است.';
  }

  @override
  String get mv_cant_today_title => 'برنامه برای شرایط امروزت';

  @override
  String get mv_cant_today_subtitle =>
      'حتی کوچک‌ترین حرکت هم برای حفظ پیوستگی حساب می‌شود.';

  @override
  String get mv_cant_today_option_cancel_anchor_title => 'این هفته لغو شد';

  @override
  String get mv_cant_today_option_cancel_anchor_desc =>
      'لغو این جلسه فقط برای این هفته؛ تعهد هفتگی شما فعال می‌ماند.';

  @override
  String get mv_cant_today_option_minimal_title => 'حداقل مؤثر (۱۰ دقیقه سبک)';

  @override
  String get mv_cant_today_option_minimal_desc =>
      'فقط چند حرکت ساده برای حفظ زنجیره و جریان خون';

  @override
  String get mv_cant_today_option_stretch_title =>
      'تبدیل به ۵ دقیقه کشش و آرامش';

  @override
  String get mv_cant_today_option_stretch_desc =>
      'کشش سبک بدون عرق‌ریزی برای رفع خستگی';

  @override
  String get mv_cant_today_option_tomorrow_title => 'انتقال جلسه به فردا';

  @override
  String get mv_cant_today_option_tomorrow_desc =>
      'امروز استراحت کن و جلسه را فردا انجام بده';

  @override
  String get mv_cant_today_option_rest_title => 'استراحت کامل برای امروز';

  @override
  String get mv_cant_today_option_rest_desc =>
      'رد کردن جلسهٔ امروز بدون احساس گناه';

  @override
  String get mv_cant_today_recommended => 'پیشنهادی';

  @override
  String get cancel => 'انصراف';

  @override
  String get mv_coach_title => 'مربی هوشمند ریتمو';

  @override
  String get mv_coach_subtitle => 'راهنما و همراه تمرینی شما';

  @override
  String get mv_coach_preset_light => 'چطور تمرین امروز را سبک‌تر کنم؟';

  @override
  String get mv_coach_preset_noise => 'حرکات پرصدا برای آپارتمان؟';

  @override
  String get mv_coach_preset_stretch => 'برای گرفتگی عضلات چه حرکتی خوبه؟';

  @override
  String get mv_coach_preset_general => 'چطور انگیزه‌ام را حفظ کنم؟';

  @override
  String get mv_coach_reply_light =>
      'می‌توانید از گزینه حداقل مؤثر ۱۰ دقیقه‌ای استفاده کنید تا بدون خستگی، زنجیره حفظ شود.';

  @override
  String get mv_coach_reply_noise =>
      'در تنظیمات، حالت همسایه‌پسند را فعال کنید تا حرکات پرشی و پرصدا خودکار فیلتر شوند.';

  @override
  String get mv_coach_reply_stretch =>
      'کشش ۵ دقیقه‌ای همسترینگ و کمر همراه با نوشیدن آب به تخلیه اسید لاکتیک کمک می‌کند.';

  @override
  String get mv_coach_reply_general =>
      'مهم‌ترین اصل در تناسب اندام استمرار است؛ حتی ۵ دقیقه حرکت سبک بهتر از صفر است.';

  @override
  String get mv_coach_input_hint => 'از مربی بپرس...';

  @override
  String mv_at_time(String time) {
    return 'ساعت $time';
  }

  @override
  String get mv_plan_delete_action => 'حذف برنامهٔ این روز';

  @override
  String get mv_plan_delete_confirm_title => 'حذف برنامهٔ ورزشی';

  @override
  String get mv_plan_delete_confirm_desc =>
      'آیا مایلید برنامهٔ ورزشی این روز حذف شود؟ این روز به عنوان استراحت ثبت خواهد شد.';

  @override
  String get mv_plan_delete_recurring_prompt =>
      'این ورزش به صورت هفتگی تکرار می‌شود. مایلید چگونه حذف شود؟';

  @override
  String get mv_plan_delete_this_week_only => 'فقط برای این هفته لغو شود';

  @override
  String get mv_plan_delete_all_weeks => 'حذف دائمی از برنامهٔ هفتگی';

  @override
  String get mv_plan_deleted_snackbar => 'برنامهٔ ورزشی این روز حذف شد';

  @override
  String get mv_undo => 'بازگردانی';

  @override
  String get mv_action_convert_rest => 'تبدیل به روز استراحت';

  @override
  String get mv_action_move_tomorrow => 'انتقال به فردا';

  @override
  String get mv_plan_delete_confirm => 'حذف برنامه';

  @override
  String get mv_cant_today_option_delete_title => 'حذف کامل برنامهٔ امروز';

  @override
  String get mv_cant_today_option_delete_desc =>
      'پاک کردن این ورزش از تقویم و برنامهٔ امروز';

  @override
  String get mv_day_detail_delete_tooltip => 'حذف برنامهٔ ورزشی این روز';

  @override
  String mv_exercise_removed_snackbar(String name) {
    return 'حرکت $name حذف شد';
  }
}
