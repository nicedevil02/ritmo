/// Persian string constants for simple_tasks feature.
/// Enforces non-judgmental, anti-guilt language across all user-facing copy.
abstract final class TaskStrings {
  // Titles & Headers
  static const String myDayTitle = 'روز من';
  static const String simpleTasksTitle = 'کارها';
  static const String myDayPrompt = 'امروز چه کاری برمی‌داری؟';
  static const String myDayEmptyAllClear = 'امروز چیزی روی زمین نمانده.';
  static const String newTaskAction = 'کار جدید';
  static const String suggestionsTitle = 'پیشنهادها';

  // Suggestions reasons
  static const String suggestionReasonOverdue = 'از روزهای قبل مانده';
  static const String suggestionReasonDueToday = 'موعدش امروزه';
  static const String suggestionReasonImportant = 'نشان‌دار کردی';
  static const String suggestionReasonDueTomorrow = 'موعدش فرداست';
  static const String suggestionReasonFromRoutine = 'از روتین امروز';

  // Daily Planning Nudge
  static const String dailyPlanningNudgeTitle = 'برنامه‌ریزی روزانه';
  static const String dailyPlanningNudgeBody = 'امروز چه کاری داری؟';

  // Snooze Presets
  static const String snoozeTenMinutes = '۱۰ دقیقه دیگر';
  static const String snoozeOneHour = 'یک ساعت دیگر';
  static const String snoozeThisEvening = 'امشب';
  static const String snoozeTomorrowMorning = 'فردا صبح';

  // Actions & Feedbacks
  static const String addedToMyDay = 'به روز من اضافه شد';
  static const String removedFromMyDay = 'از روز من برداشته شد';
  static const String undo = 'بازگردانی';
  static const String markDone = 'انجام شد';
  static const String delete = 'حذف';
  static const String edit = 'ویرایش';
  static const String searchHint = 'جست‌وجو در کارها و یادداشت‌ها...';

  // Sorting
  static const String sortSmart = 'مرتب‌سازی هوشمند';
  static const String sortDueDate = 'بر اساس تاریخ سررسید';
  static const String sortImportance = 'بر اساس اهمیت';
  static const String sortAlphabetical = 'بر اساس حروف الفبا';
  static const String sortCreatedAt = 'بر اساس تاریخ ثبت';
  static const String hideCompleted = 'مخفی کردن انجام‌شده‌ها';
  static const String showCompleted = 'نمایش انجام‌شده‌ها';

  // Buckets
  static const String bucketOverdue = 'معوقه';
  static const String bucketToday = 'امروز';
  static const String bucketTomorrow = 'فردا';
  static const String bucketThisWeek = 'این هفته';
  static const String bucketLater = 'بعداً';
  static const String bucketSomeday = 'بدون تاریخ';
  static const String bucketDoneToday = 'انجام‌شدهٔ امروز';

  // Exact Alarm Notice
  static const String exactAlarmNotice =
      'برای پخش به‌موقع یادآورها، لطفاً مجوز هشدارهای دقیق را فعال کنید.';
  static const String openSettings = 'تنظیمات';
}
