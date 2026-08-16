import 'package:ritmo/core/utils/persian_digits.dart';

abstract final class MovementStrings {
  // center.* / hero.* / banner.* / week.*
  static const centerTitle = 'حرکت';
  static const centerThisWeek = 'این هفته';
  static const centerDayPlan = 'برنامهٔ روز';
  static const centerAddActivity = 'افزودن فعالیت';
  static const heroBuildWeek = 'هفته‌ات را بساز';
  static const heroSmartWeek = 'پیشنهاد هوشمند یک هفته';
  static const heroStart = 'شروع';
  static const heroLate = 'زمان پیشنهادی گذشته';
  static const heroRestDay = 'امروز روز ریکاوری است';
  static const heroAllDone = 'کار امروز انجام شد';
  static const heroNoPlanToday = 'امروز برنامه‌ای تعریف نشده است';
  static const bannerResumeSession = 'ادامهٔ جلسه';
  static const weekNoSessionYet = 'هنوز جلسه‌ای ثبت نشده';

  // Statuses
  static const statusPlanned = 'برنامه‌ریزی‌شده';
  static const statusInProgress = 'در حال انجام';
  static const statusCompleted = 'انجام‌شده';
  static const statusPartial = 'نیمه‌تمام';
  static const statusSkipped = 'ردشده';
  static const statusMoved = 'جابه‌جاشده';
  static const statusLate = 'زمان پیشنهادی گذشته';

  // Reasons
  static const reasonInterest = 'بر اساس علاقه';
  static const reasonAvailableTime = 'مناسب زمان در دسترس';
  static const reasonRecoveryGap = 'برای فاصلهٔ ریکاوری';
  static const reasonEquipment = 'متناسب با تجهیزات';
  static const reasonWhySuggestion = 'چرا این پیشنهاد؟';

  // Hero Actions
  static const heroActionShortVersion = 'نسخهٔ کوتاه';
  static const heroActionLogManual = 'ثبت دستی';
  static const heroActionMove = 'جابه‌جایی';
  static const heroActionDoNow = 'انجام همین حالا';
  static const heroActionSkip = 'رد کردن';
  static const heroActionLogAnother = 'ثبت فعالیت دیگر';
  static const heroActionReviewWeek = 'مرور هفته';
  static const heroActionLightMovement = 'حرکت سبک ۱۰ دقیقه‌ای';

  // Banner Actions
  static const bannerFinishAndSave = 'پایان و ثبت';
  static const bannerDiscardSession = 'حذف جلسهٔ ناتمام';

  // Recovery Day Card
  static const recoveryDayTitle = 'روز ریکاوری';
  static const recoveryDayDesc = 'این روز برای بازیابی بین جلسه‌ها نگه داشته شده';
  static const recoveryDayAddLight = 'افزودن حرکت سبک';

  // Week Summary Card
  static const summaryCompletedPlanned = 'انجام‌شده از برنامه‌ریزی‌شده';
  static const summaryActiveMinutes = 'دقیقهٔ فعال';
  static const summaryRecoveryDays = 'روز ریکاوری';

  // Strength Card
  static const strengthTitle = 'قدرت در خانه';
  static const strengthBuildProgram = 'ساخت برنامهٔ من';
  static const strengthCardDesc = 'تمرینات ساختاریافته برای افزایش قدرت بدنی و سلامت مفاصل';
  static const strengthBenefit1 = 'بدون نیاز به باشگاه';
  static const strengthBenefit2 = 'تنظیم خودکار با پیشرفت';
  static const strengthBenefit3 = 'جلوگیری از آسیب';
  static const strengthNextSession = 'جلسهٔ بعدی';
  static const strengthViewProgram = 'مشاهدهٔ برنامه';
  static const strengthResumeSession = 'ادامهٔ جلسه';
  static const strengthDeload = 'هفتهٔ Deload';
  static const strengthDeloadDesc = 'هفتهٔ کاهش بار جهت بازیابی عضلانی و جلوگیری از تمرین‌زدگی';
  static const strengthCycleFinished = 'دوره تمام شد';
  static const strengthStartNextCycle = 'شروع دورهٔ بعد';
  static const strengthNotMedical = 'این بخش جایگزین مشاورهٔ پزشکی نیست';
  static const strengthActivate = 'فعالسازی برنامه';

  // Cutover Callout
  static const cutoverCalloutTitle = 'بخش حرکت بازسازی شده است';
  static const cutoverCalloutDesc = 'بخش حرکت بازسازی شده و برنامه از صفر ساخته می‌شود';
  static const cutoverCalloutDismiss = 'متوجه شدم';

  // Card Menu Actions
  static const menuStart = 'شروع';
  static const menuManualLog = 'ثبت دستی';
  static const menuMove = 'جابه‌جایی';
  static const menuShortVersion = 'نسخهٔ کوتاه';
  static const menuSkip = 'رد کردن';
  static const menuEditPlan = 'ویرایش برنامه';
  static const menuDelete = 'حذف';

  // add.* / scope.* / plan.* / skip.* / smartfill.* / undo.*
  static const addQuestion = 'چه کاری می‌خواهی انجام بدهی؟';
  static const addStartNow = 'شروع همین حالا';
  static const addStartNowDesc = 'یک ورزش را انتخاب کن و جلسه را آغاز کن';
  static const addToPlan = 'افزودن به برنامه';
  static const addToPlanDesc = 'برای یک بار یا به‌صورت هفتگی زمان‌بندی کن';
  static const addRetroLog = 'ثبت فعالیت انجام‌شده';
  static const addRetroLogDesc = 'ورزشی را که قبلاً انجام داده‌ای ثبت کن';
  static const addResumeLive = 'ادامهٔ جلسهٔ نیمه‌تمام';
  static const addUseTemplate = 'استفاده از قالب';
  static const addStrengthHome = 'قدرت در خانه';

  // Scope Picker Sheet
  static const scopeTitle = 'دامنهٔ اعمال تغییرات';
  static const scopeOnlyThis = 'فقط این جلسه';
  static const scopeOnlyThisDesc = 'فقط همین تاریخ؛ قالب دست‌نخورده';
  static const scopeThisAndFuture = 'این جلسه و جلسه‌های بعد';
  static const scopeThisAndFutureDesc = 'از این تاریخ به بعد اعمال می‌شود';
  static const scopeWholePlan = 'کل برنامه';
  static const scopeWholePlanDesc = 'قالب تغییر می‌کند؛ گذشته دست‌نخورده';

  // Activity Picker
  static const searchPlaceholder = 'جست‌وجوی فعالیت ورزشی...';
  static const searchRecent = 'اخیر';
  static const searchFavorites = 'علاقه‌مندی‌ها';
  static const searchTemplates = 'قالب‌های ذخیره‌شده';
  static const searchNoResult = 'فعالیتی با این نام پیدا نشد';
  static const searchCustomActivity = 'فعالیت مورد نظرم نیست';
  static const categoryWalkingRunning = 'پیاده‌روی و دویدن';
  static const categoryCycling = 'دوچرخه‌سواری';
  static const categoryTeamSports = 'ورزش‌های تیمی';
  static const categorySwimmingWater = 'شنا و ورزش‌های آبی';
  static const categoryStrength = 'قدرتی';
  static const categoryYogaMobility = 'کشش و یوگا و تحرک';
  static const categoryMartialArts = 'رزمی';
  static const categoryHikingNature = 'طبیعت و کوه';
  static const categoryOther = 'سایر';

  // Custom Activity Sheet
  static const customActivityTitle = 'ایجاد فعالیت سفارشی';
  static const customActivityName = 'نام فعالیت';
  static const customActivityFamily = 'خانوادهٔ ورزشی';
  static const customActivityPrimaryMetric = 'متریک اصلی';
  static const customActivityUnits = 'واحدهای اندازه‌گیری';
  static const customActivityEnvironment = 'محیط انجام (اختیاری)';
  static const customActivityEquipment = 'تجهیزات (اختیاری)';
  static const customActivitySave = 'ذخیرهٔ فعالیت';
  static const customActivityDuplicateWarning = 'فعالیتی با نام مشابه وجود دارد. آیا مایل به ذخیره هستید؟';

  // Planner 8 Steps
  static const plannerTitle = 'برنامه‌ریزی فعالیت';
  static const plannerStepActivity = 'انتخاب فعالیت';
  static const plannerStepSessionType = 'نوع جلسه';
  static const plannerStepGoal = 'هدف جلسه';
  static const plannerStepSchedule = 'زمان‌بندی';
  static const plannerStepReminder = 'یادآوری';
  static const plannerStepConstraints = 'محدودیت‌ها و تداخل';
  static const plannerStepPreview = 'پیش‌نمایش برنامه';
  static const plannerStepConfirm = 'تأیید و ذخیره';
  static const plannerSaveDisabledReason = 'برای ذخیره، انتخاب روز و هدف معتبر الزامی است';
  static const plannerDiscardTitle = 'خروج از ویرایشگر';
  static const plannerDiscardMessage = 'تغییرات ذخیره‌نشده دارید. مایل به ذخیره هستید یا تغییرات لغو شوند؟';
  static const plannerActionSaveAndExit = 'ذخیره و خروج';
  static const plannerActionDiscard = 'دور ریختن';
  static const plannerActionContinue = 'ادامهٔ ویرایش';

  static const plannerSessionSimple = 'ساده';
  static const plannerSessionStructured = 'ساختاریافته';
  static const plannerSessionRepeating = 'تکراری';
  static const plannerSessionEvent = 'رویدادی';
  static const plannerSessionRetro = 'گزارشی گذشته‌نگر';

  static const plannerRecurrenceOnce = 'یک بار';
  static const plannerRecurrenceWeekly = 'هر هفته';
  static const plannerRecurrenceMultiWeek = 'برنامهٔ چندهفته‌ای';

  static const plannerReminderNone = 'بدون یادآوری';
  static const plannerReminderPreSession = 'پیش از جلسه';
  static const plannerReminderMorning = 'صبح روز';

  static const plannerDifferentTimes = 'ساعت متفاوت برای هر روز';
  static const plannerSharedTime = 'ساعت مشترک برای همهٔ روزها';

  static const planAddToPlan = 'افزودن به برنامه';
  static const planEdit = 'ویرایش';
  static const planNoConflict = 'تداخلی پیدا نشد';
  static const plannerConflictTitle = 'تداخل زمانی شناسایی شد';
  static const plannerConflictSuggestionTime = 'ساعت دیگر';
  static const plannerConflictSuggestionShorten = 'کوتاه‌کردن جلسه';
  static const plannerConflictSuggestionKeepBoth = 'حفظ هر دو با هشدار';
  static const plannerConflictSuggestionMove = 'انتقال به روز آزاد';
  static const plannerSuggestedBadge = 'پیشنهادی';

  // Occurrence Details
  static const occurrenceDetailsTitle = 'جزئیات جلسه';
  static const occurrenceGoal = 'هدف جلسه';
  static const occurrenceOrigin = 'منشأ جلسه';
  static const occurrenceOriginTemplate = 'قالب تکرارشونده';
  static const occurrenceOriginOnce = 'جلسهٔ تک‌باره';
  static const occurrenceOriginStrength = 'برنامهٔ تمرین قدرتی';
  static const occurrenceOriginManual = 'ثبت دستی';
  static const occurrenceReminder = 'وضعیت یادآور';
  static const occurrenceHistory = 'تاریخچهٔ ثبت تمرین';
  static const occurrenceNoHistory = 'هنوز لاگی برای این جلسه ثبت نشده است.';
  static const occurrenceDeleteConfirmTitle = 'حذف جلسهٔ ورزشی';
  static const occurrenceDeleteConfirmDesc = 'با حذف این جلسه، تمام سوابق و لاگ‌های تاریخی شما دست‌نخورده باقی می‌مانند.';

  // Retro Log
  static const retroLogTitle = 'ثبت فعالیت انجام‌شده';
  static const retroLogDate = 'تاریخ انجام';
  static const retroLogTime = 'ساعت تقریبی';
  static const retroLogDuration = 'مدت زمان (دقیقه)';
  static const retroLogMetricValue = 'مقدار متریک';
  static const retroLogFeeling = 'حس بعد از تمرین';
  static const retroLogNote = 'یادداشت (اختیاری)';
  static const retroLogSubmit = 'ثبت و ذخیره';
  static const retroLogMatchPrompt = 'یک جلسهٔ برنامه‌ریزی‌شده در همین روز یافت شد. مایلید همین جلسه به عنوان انجام‌شده ثبت شود؟';

  // Move / Skip / QuickComplete / PlanB / SmartFill / WeekReshuffle Sheets
  static const moveSessionTitle = 'جابه‌جایی جلسه';
  static const moveSelectDay = 'انتخاب روز از ریل هفته';
  static const moveSelectTime = 'انتخاب ساعت';
  static const moveSuggestedDay = 'روز پیشنهادی';
  static const skipTitle = 'امروز انجام نمی‌دهم';
  static const skipOptionTodayOnly = 'فقط امروز رد شود';
  static const skipOptionMove = 'به روز دیگری منتقل شود';
  static const skipOptionShortVersion = 'نسخهٔ کوتاه جایگزین شود';
  static const skipOptionEditTemplate = 'قالب دائمی ویرایش شود';
  static const quickCompleteTitle = 'ثبت سریع جلسه';
  static const quickCompleteButton = 'ثبت سریع';
  static const quickCompleteDetailsLater = 'تکمیل جزئیات بعداً';
  static const planBTitle = 'نسخهٔ جایگزین (Plan B)';
  static const planBFull = 'نسخهٔ کامل';
  static const planBShort = 'نسخهٔ کوتاه';
  static const planBMinDose = 'حداقل مؤثر';
  static const planBMove = 'جابه‌جایی به روز دیگر';
  static const planBRecovery = 'تبدیل به ریکاوری';
  static const planBKept = 'موارد حفظ‌شده';
  static const planBDropped = 'موارد حذف‌شده';
  static const planBNewDuration = 'مدت زمان جدید';
  static const smartFillTitle = 'پیشنهاد هوشمند برنامه';
  static const smartFillNoSuggestion = 'با این محدودیت‌ها پیشنهاد مطمئنی پیدا نشد';
  static const smartFillFixConstraints = 'اصلاح محدودیت‌ها';
  static const smartFillApplySelected = 'اعمال موارد انتخاب‌شده';
  static const weekReshuffleTitle = 'بازآرایی برنامهٔ هفتگی';
  static const weekReshuffleApplyAll = 'اعمال همه';
  static const weekReshuffleSelect = 'انتخاب تغییرها';

  // Undo Toasts
  static const undoMovedTodayOnly = 'فقط جلسهٔ امروز جابه‌جا شد';
  static const undoMovedThisAndFuture = 'جلسهٔ امروز و جلسات بعد جابه‌جا شدند';
  static const undoMovedWholePlan = 'کل برنامه جابه‌جا شد';
  static const undoSkippedToday = 'جلسهٔ امروز رد شد';
  static const undoPlanSaved = 'برنامه با موفقیت ذخیره شد';
  static const undoSessionDeleted = 'جلسه حذف شد (سوابق حفظ شدند)';

  // Activity Picker & Search
  static const pickerTitle = 'انتخاب فعالیت ورزشی';
  static const pickerFavorites = 'علاقه‌مندی‌ها';
  static const searchActivitiesHint = 'جست‌وجوی فعالیت ورزشی...';
  static const searchClear = 'پاک کردن';
  static const favoriteAdd = 'افزودن به علاقه‌مندی‌ها';
  static const favoriteRemove = 'حذف از علاقه‌مندی‌ها';
  static const customActivityNewButton = 'ایجاد فعالیت سفارشی';
  static const customActivityNameRequired = 'وارد کردن نام فعالیت الزامی است';
  static const customActivityCategory = 'خانوادهٔ ورزشی';
  static const customActivityMetric = 'شاخص اصلی';
  static const customActivitySubmit = 'ذخیرهٔ فعالیت';
  static const customActivityCreatedToast = 'فعالیت جدید با موفقیت ایجاد شد';
  static const customActivityDuplicateError = 'فعالیتی با این نام از قبل وجود دارد';

  // Planner Goals & Recurrence
  static const goalSuggestedBadge = 'پیشنهادی';
  static const goalTypeDuration = 'مدت زمان';
  static const goalTypeDistance = 'مسافت';
  static const goalTypeCalories = 'کالری';
  static const recurrenceWeekly = 'هر هفته';
  static const recurrenceOnce = 'یک بار';
  static const recurrence4Weeks = '۴ هفته';
  static const plannerSaveButton = 'تأیید و ذخیره';
  static const plannerEditButton = 'ویرایش';

  // Conflicts
  static const conflictNoneFound = 'تداخلی پیدا نشد';
  static const conflictDetectedTitle = 'تداخل زمانی شناسایی شد';
  static const conflictSuggestOtherTime = 'ساعت دیگر';
  static const conflictSuggestShorten = 'کوتاه‌کردن جلسه';
  static const conflictSuggestMoveToFreeDay = 'انتقال به روز آزاد';
  static const conflictSuggestKeepBoth = 'حفظ هر دو با هشدار';

  // session.* / set.* / rest.* / summary.*
  static const sessionStart = 'شروع';
  static const sessionFinish = 'پایان';
  static const sessionResume = 'ادامه';
  static const sessionLapDone = 'یک دور ثبت شد';
  static const sessionPendingSave = 'ذخیره‌سازی در انتظار';
  static const sessionPauseAndBack = 'مکث و برگشت به برنامه';
  static const sessionPainTitle = 'درد دارم';
  static const sessionPainStop = 'حرکت را متوقف کن';
  static const setLogSet = 'ثبت ست';
  static const setNextExercise = 'حرکت بعدی';
  static const restAddFifteen = 'افزودن ۱۵ ثانیه';
  static const summaryDone = 'تمام';
  static const summaryLogAnother = 'ثبت یک جلسهٔ دیگر';
  static const summaryEstimated = 'تخمینی';

  // progress.* / settings.* / common.*
  static const progressNeedMoreData = 'برای نمایش روند به دادهٔ بیشتری نیاز است';
  static const progressShowTable = 'نمایش به‌صورت جدول';
  static const settingsDeleteMovementData = 'حذف دادهٔ حرکت';
  static const commonRetry = 'تلاش دوباره';
  static const commonUndo = 'بازگرداندن';
  static const commonNotRecorded = 'ثبت‌نشده';

  // Navigation & Semantics & Actions
  static const navPreviousWeek = 'هفتهٔ قبل';
  static const navNextWeek = 'هفتهٔ بعد';
  static const navReturnToCurrentWeek = 'بازگشت به هفتهٔ جاری';
  static const progressTitle = 'پیشرفت';
  static const settingsTitle = 'تنظیمات';
  static const commonCancel = 'انصراف';
  static const commonConfirm = 'تأیید';
  static const commonDelete = 'حذف';
  static const devOnlyBannerText = 'نسخهٔ داخلی در حال ساخت';
  static const offlineBannerText = 'عدم دسترسی به اینترنت';
  static const diffBefore = 'قبل';
  static const diffAfter = 'بعد';
  static const diffReason = 'دلیل';
  static const diffLocked = 'غیرقابل تغییر';

  // Dynamic parameterized string functions
  static String strengthStepOf(int step) =>
      'گام ${toPersianDigits(step)} از ${toPersianDigits(5)}';

  static String strengthWeekProgress(int current, int total) =>
      'هفتهٔ ${toPersianDigits(current)} از ${toPersianDigits(total)}';

  static String heroSessionProgress(int current, int total) =>
      'جلسهٔ ${toPersianDigits(current)} از ${toPersianDigits(total)}';

  static String sessionsCount(int count) =>
      '${toPersianDigits(count)} جلسه';

  static String completedSessionsCount(int count) =>
      '${toPersianDigits(count)} انجام شده';

  static String plusMoreSessions(int count) =>
      '+${toPersianDigits(count)}';

  static String planSavedToast(int createdSessionsCount) =>
      'برنامه با ${toPersianDigits(createdSessionsCount)} جلسه ذخیره شد';
}
