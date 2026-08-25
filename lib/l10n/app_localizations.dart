import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fa.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fa'),
  ];

  /// No description provided for @learningGrowthInsightTitle.
  ///
  /// In fa, this message translates to:
  /// **'رشد چشمگیر یادگیری 📈'**
  String get learningGrowthInsightTitle;

  /// No description provided for @learningGrowthInsightMessage.
  ///
  /// In fa, this message translates to:
  /// **'فعالیت‌های یادگیری شما در این هفته نسبت به هفته گذشته {percent}٪ رشد داشته است. مسیر مطالعه خود را ادامه دهید!'**
  String learningGrowthInsightMessage(int percent);

  /// No description provided for @healthDeclineInsightTitle.
  ///
  /// In fa, this message translates to:
  /// **'توجه به سلامت و ورزش ⚠️'**
  String get healthDeclineInsightTitle;

  /// No description provided for @healthDeclineInsightMessage.
  ///
  /// In fa, this message translates to:
  /// **'تعداد روتین‌های سلامتی شما در ۷ روز گذشته {percent}٪ کاهش یافته است. تلاش کنید دوباره آنها را در برنامه قرار دهید.'**
  String healthDeclineInsightMessage(int percent);

  /// No description provided for @morningLeadInsightTitle.
  ///
  /// In fa, this message translates to:
  /// **'برتری عملکرد صبحگاهی ☀️'**
  String get morningLeadInsightTitle;

  /// No description provided for @morningLeadInsightMessage.
  ///
  /// In fa, this message translates to:
  /// **'روتین‌های صبحگاهی شما (۶:۰۰ تا ۱۲:۰۰) نرخ تکمیل بالاتری نسبت به روتین‌های عصرگاهی دارند. برای کارهای مهم‌تر روی صبح‌ها سرمایه‌گذاری کنید.'**
  String get morningLeadInsightMessage;

  /// No description provided for @fatigueWarningInsightTitle.
  ///
  /// In fa, this message translates to:
  /// **'بازه حساس خستگی ⚡'**
  String get fatigueWarningInsightTitle;

  /// No description provided for @fatigueWarningInsightMessage.
  ///
  /// In fa, this message translates to:
  /// **'بازه زمانی {window} شایع‌ترین دوره خستگی و از دست رفتن روتین‌های شماست. در این ساعات تسک‌های سبک‌تر قرار دهید.'**
  String fatigueWarningInsightMessage(String window);

  /// No description provided for @productiveWeekdayInsightTitle.
  ///
  /// In fa, this message translates to:
  /// **'روز درخشان شما 🌟'**
  String get productiveWeekdayInsightTitle;

  /// No description provided for @productiveWeekdayInsightMessage.
  ///
  /// In fa, this message translates to:
  /// **'روز «{weekday}» پربازده‌ترین روز هفته برای شماست. کارهای سنگین و پروژه‌های خود را در این روز برنامه‌ریزی کنید.'**
  String productiveWeekdayInsightMessage(String weekday);

  /// No description provided for @gatheringDataInsightTitle.
  ///
  /// In fa, this message translates to:
  /// **'در حال شناخت ریتم شما 🔍'**
  String get gatheringDataInsightTitle;

  /// No description provided for @gatheringDataInsightMessage.
  ///
  /// In fa, this message translates to:
  /// **'ریتمو برای ارائه تحلیل‌های معتبر نیاز به داده‌های بیشتری دارد. لطفاً به ثبت فعالیت‌های خود ادامه دهید.'**
  String get gatheringDataInsightMessage;

  /// No description provided for @contextExplanationRest.
  ///
  /// In fa, this message translates to:
  /// **'استراحت و بازیابی انرژی 🌿'**
  String get contextExplanationRest;

  /// No description provided for @contextExplanationEssential.
  ///
  /// In fa, this message translates to:
  /// **'سیستم زندگی «{title}» به دلیل اهمیت حیاتی، در اولویت بالاتر قرار گرفت.'**
  String contextExplanationEssential(String title);

  /// No description provided for @contextExplanationSick.
  ///
  /// In fa, this message translates to:
  /// **'به دلیل کسالت و بیماری، روتین‌های فیزیکی تعلیق شده و روتین «{title}» پیشنهاد می‌شود.'**
  String contextExplanationSick(String title);

  /// No description provided for @contextExplanationExam.
  ///
  /// In fa, this message translates to:
  /// **'با توجه به بازه امتحانات، روتین‌های یادگیری و مطالعه نظیر «{title}» تقویت شده‌اند.'**
  String contextExplanationExam(String title);

  /// No description provided for @contextExplanationBusy.
  ///
  /// In fa, this message translates to:
  /// **'به دلیل تراکم بالای برنامه‌های امروز، اقدام بهینه بعدی روتین «{title}» است.'**
  String contextExplanationBusy(String title);

  /// No description provided for @contextExplanationWorship.
  ///
  /// In fa, this message translates to:
  /// **'با توجه به فصل عبادی جاری ({season})، روتین «{title}» پیشنهاد می‌شود.'**
  String contextExplanationWorship(String season, String title);

  /// No description provided for @contextExplanationZone.
  ///
  /// In fa, this message translates to:
  /// **'با توجه به حضور در زون فعال، روتین «{title}» جهت همگامی با ریتم جاری پیشنهاد می‌شود.'**
  String contextExplanationZone(String title);

  /// No description provided for @contextExplanationLowEnergy.
  ///
  /// In fa, this message translates to:
  /// **'با توجه به سطح انرژی پایین، نسخه متناسب از روتین «{title}» پیشنهاد می‌شود.'**
  String contextExplanationLowEnergy(String title);

  /// No description provided for @contextExplanationDynamic.
  ///
  /// In fa, this message translates to:
  /// **'با تحلیل پویای ریتم روزانه، روتین «{title}» به عنوان بهترین اقدام بهینه بعدی پیشنهاد می‌شود.'**
  String contextExplanationDynamic(String title);

  /// No description provided for @hormonalMenstrualAdjustment1.
  ///
  /// In fa, this message translates to:
  /// **'فعالیت‌های سنگین را کاهش دهید'**
  String get hormonalMenstrualAdjustment1;

  /// No description provided for @hormonalMenstrualAdjustment2.
  ///
  /// In fa, this message translates to:
  /// **'بین کارها استراحت کوتاه اضافه کنید'**
  String get hormonalMenstrualAdjustment2;

  /// No description provided for @hormonalMenstrualAdjustment3.
  ///
  /// In fa, this message translates to:
  /// **'روی کارهای سبک و ضروری تمرکز کنید'**
  String get hormonalMenstrualAdjustment3;

  /// No description provided for @hormonalMenstrualAdjustment4.
  ///
  /// In fa, this message translates to:
  /// **'آب کافی بنوشید و استراحت کافی داشته باشید'**
  String get hormonalMenstrualAdjustment4;

  /// No description provided for @hormonalPreCycleAdjustment1.
  ///
  /// In fa, this message translates to:
  /// **'ممکن است خستگی بدنی یا نوسانات انرژی خفیف را تجربه کنید 🔋'**
  String get hormonalPreCycleAdjustment1;

  /// No description provided for @hormonalPreCycleAdjustment2.
  ///
  /// In fa, this message translates to:
  /// **'اولویت‌دهی به کارهای مهم در ساعات اولیه روز ⏰'**
  String get hormonalPreCycleAdjustment2;

  /// No description provided for @hormonalPreCycleAdjustment3.
  ///
  /// In fa, this message translates to:
  /// **'پیشنهاد می‌شود زمان خواب شبانه را افزایش دهید 🌙'**
  String get hormonalPreCycleAdjustment3;

  /// No description provided for @hormonalPostCycleAdjustment1.
  ///
  /// In fa, this message translates to:
  /// **'سطح انرژی و توانایی تمرکز در حال افزایش است 📈'**
  String get hormonalPostCycleAdjustment1;

  /// No description provided for @hormonalPostCycleAdjustment2.
  ///
  /// In fa, this message translates to:
  /// **'زمان عالی برای شروع برنامه‌ها یا یادگیری کارهای جدید 🎓'**
  String get hormonalPostCycleAdjustment2;

  /// No description provided for @hormonalContextMenstrual.
  ///
  /// In fa, this message translates to:
  /// **'به دلیل فاز قاعدگی فعال، پیشنهاد می‌شود فعالیت‌های بدنی سبک‌تری داشته باشید و زمان ریکاوری را افزایش دهید. 🌸'**
  String get hormonalContextMenstrual;

  /// No description provided for @hormonalContextPreCycle.
  ///
  /// In fa, this message translates to:
  /// **'در فاز پیش از قاعدگی (Pre-cycle)، احتمال خستگی یا حساسیت عاطفی ملایم وجود دارد. انعطاف‌پذیری برنامه به آسایش شما کمک می‌کند. 🧘'**
  String get hormonalContextPreCycle;

  /// No description provided for @hormonalContextPostCycle.
  ///
  /// In fa, this message translates to:
  /// **'در فاز پس از قاعدگی (Post-cycle)، سطح آمادگی ذهنی و انرژی بدنی رو به افزایش است. زمان خوبی برای چالش‌های جدید است. ⚡'**
  String get hormonalContextPostCycle;

  /// No description provided for @hormonalContextNormal.
  ///
  /// In fa, this message translates to:
  /// **'وضعیت بدنی در حالت عادی و متعادل قرار دارد. 🍃'**
  String get hormonalContextNormal;

  /// No description provided for @hormonalContextNoData.
  ///
  /// In fa, this message translates to:
  /// **'هنوز داده کافی برای پیش‌بینی دقیق وضعیت شما وجود ندارد.'**
  String get hormonalContextNoData;

  /// No description provided for @hormonalContextDisabled.
  ///
  /// In fa, this message translates to:
  /// **'ماژول چرخه بدنی فعال نیست.'**
  String get hormonalContextDisabled;

  /// No description provided for @medicineStockAlert.
  ///
  /// In fa, this message translates to:
  /// **'موجودی داروی «{title}» رو‌به‌اتمام است (موجودی فعلی: {count}).'**
  String medicineStockAlert(String title, int count);

  /// No description provided for @timeConflictAlert.
  ///
  /// In fa, this message translates to:
  /// **'تداخل زمانی بین روتین‌های «{title1}» و «{title2}» شناسایی شد.'**
  String timeConflictAlert(String title1, String title2);

  /// No description provided for @pulseCardMoodGood.
  ///
  /// In fa, this message translates to:
  /// **'امروز روز خوبی بوده 🌱'**
  String get pulseCardMoodGood;

  /// No description provided for @pulseCardMoodExcellent.
  ///
  /// In fa, this message translates to:
  /// **'ریتم زندگی شما عالی است! 🌟'**
  String get pulseCardMoodExcellent;

  /// No description provided for @pulseCardMoodRestore.
  ///
  /// In fa, this message translates to:
  /// **'بیا ریتم زندگی را بازیابی کنیم 🌿'**
  String get pulseCardMoodRestore;

  /// No description provided for @pulseCardTitle.
  ///
  /// In fa, this message translates to:
  /// **'نبض زندگی'**
  String get pulseCardTitle;

  /// No description provided for @pulseCardTrend.
  ///
  /// In fa, this message translates to:
  /// **'روند این هفته +۱۱٪'**
  String get pulseCardTrend;

  /// No description provided for @currentEnergyTitle.
  ///
  /// In fa, this message translates to:
  /// **'انرژی فعلی'**
  String get currentEnergyTitle;

  /// No description provided for @manageEnergy.
  ///
  /// In fa, this message translates to:
  /// **'مدیریت انرژی'**
  String get manageEnergy;

  /// No description provided for @currentRealmTitle.
  ///
  /// In fa, this message translates to:
  /// **'قلمرو فعلی'**
  String get currentRealmTitle;

  /// No description provided for @outOfRealm.
  ///
  /// In fa, this message translates to:
  /// **'خارج از قلمرو'**
  String get outOfRealm;

  /// No description provided for @noActiveSchedule.
  ///
  /// In fa, this message translates to:
  /// **'بدون زمان‌بندی فعال'**
  String get noActiveSchedule;

  /// No description provided for @logNewDailyRealm.
  ///
  /// In fa, this message translates to:
  /// **'ثبت قلمرو جدید روزانه'**
  String get logNewDailyRealm;

  /// No description provided for @routinesConnectedToRealm.
  ///
  /// In fa, this message translates to:
  /// **'{count} روتین متصل به این قلمرو'**
  String routinesConnectedToRealm(int count);

  /// No description provided for @addRealm.
  ///
  /// In fa, this message translates to:
  /// **'افزودن قلمرو ›'**
  String get addRealm;

  /// No description provided for @manageRealm.
  ///
  /// In fa, this message translates to:
  /// **'مدیریت قلمرو ›'**
  String get manageRealm;

  /// No description provided for @energyLevelHigh.
  ///
  /// In fa, this message translates to:
  /// **'بالا'**
  String get energyLevelHigh;

  /// No description provided for @energyLevelLow.
  ///
  /// In fa, this message translates to:
  /// **'پایین'**
  String get energyLevelLow;

  /// No description provided for @energyLevelMedium.
  ///
  /// In fa, this message translates to:
  /// **'متوسط'**
  String get energyLevelMedium;

  /// No description provided for @energyDescHigh.
  ///
  /// In fa, this message translates to:
  /// **'آماده برای کارهای عمیق و تمرکز سنگین'**
  String get energyDescHigh;

  /// No description provided for @energyDescLow.
  ///
  /// In fa, this message translates to:
  /// **'زمان مناسب برای استراحت و کار سبک'**
  String get energyDescLow;

  /// No description provided for @energyDescMedium.
  ///
  /// In fa, this message translates to:
  /// **'مناسب برای مطالعه، پروژه‌ها و روتین‌ها'**
  String get energyDescMedium;

  /// No description provided for @contextNormal.
  ///
  /// In fa, this message translates to:
  /// **'عادی 🍃'**
  String get contextNormal;

  /// No description provided for @contextSick.
  ///
  /// In fa, this message translates to:
  /// **'بیماری 🤒'**
  String get contextSick;

  /// No description provided for @contextTravel.
  ///
  /// In fa, this message translates to:
  /// **'سفر ✈️'**
  String get contextTravel;

  /// No description provided for @contextExam.
  ///
  /// In fa, this message translates to:
  /// **'امتحانات 📚'**
  String get contextExam;

  /// No description provided for @contextBusy.
  ///
  /// In fa, this message translates to:
  /// **'مشغله زیاد 🔥'**
  String get contextBusy;

  /// No description provided for @contextWorship.
  ///
  /// In fa, this message translates to:
  /// **'فصل عبادی'**
  String get contextWorship;

  /// No description provided for @energyLevelHighSymbol.
  ///
  /// In fa, this message translates to:
  /// **'بالا 🔥'**
  String get energyLevelHighSymbol;

  /// No description provided for @energyLevelLowSymbol.
  ///
  /// In fa, this message translates to:
  /// **'پایین 💤'**
  String get energyLevelLowSymbol;

  /// No description provided for @energyLevelMediumSymbol.
  ///
  /// In fa, this message translates to:
  /// **'متوسط ⚡'**
  String get energyLevelMediumSymbol;

  /// No description provided for @outOfRealmSymbol.
  ///
  /// In fa, this message translates to:
  /// **'خارج از قلمرو 🌐'**
  String get outOfRealmSymbol;

  /// No description provided for @resolveScheduleConflict.
  ///
  /// In fa, this message translates to:
  /// **'⚡ رفع تداخل برنامه'**
  String get resolveScheduleConflict;

  /// No description provided for @labelContext.
  ///
  /// In fa, this message translates to:
  /// **'بستر:'**
  String get labelContext;

  /// No description provided for @labelEnergy.
  ///
  /// In fa, this message translates to:
  /// **'انرژی:'**
  String get labelEnergy;

  /// No description provided for @labelRealm.
  ///
  /// In fa, this message translates to:
  /// **'حالت:'**
  String get labelRealm;

  /// No description provided for @quickSystemsTitle.
  ///
  /// In fa, this message translates to:
  /// **'سیستم‌های سریع'**
  String get quickSystemsTitle;

  /// No description provided for @systemWorships.
  ///
  /// In fa, this message translates to:
  /// **'عبادات'**
  String get systemWorships;

  /// No description provided for @systemHealth.
  ///
  /// In fa, this message translates to:
  /// **'سلامت'**
  String get systemHealth;

  /// No description provided for @systemGoals.
  ///
  /// In fa, this message translates to:
  /// **'اهداف'**
  String get systemGoals;

  /// No description provided for @systemEducation.
  ///
  /// In fa, this message translates to:
  /// **'آموزش'**
  String get systemEducation;

  /// No description provided for @worshipItemsToday.
  ///
  /// In fa, this message translates to:
  /// **'۳ مورد امروز'**
  String get worshipItemsToday;

  /// No description provided for @medicineToday.
  ///
  /// In fa, this message translates to:
  /// **'{count} دارو امروز'**
  String medicineToday(int count);

  /// No description provided for @goalsAndPlans.
  ///
  /// In fa, this message translates to:
  /// **'اهداف و برنامه‌ها'**
  String get goalsAndPlans;

  /// No description provided for @activeCourse.
  ///
  /// In fa, this message translates to:
  /// **'۱ دوره فعال'**
  String get activeCourse;

  /// No description provided for @disabled.
  ///
  /// In fa, this message translates to:
  /// **'غیرفعال'**
  String get disabled;

  /// No description provided for @moduleDisabled.
  ///
  /// In fa, this message translates to:
  /// **'ماژول غیرفعال است'**
  String get moduleDisabled;

  /// No description provided for @restAndRecovery.
  ///
  /// In fa, this message translates to:
  /// **'استراحت و بازیابی 🌿'**
  String get restAndRecovery;

  /// No description provided for @minutesLight.
  ///
  /// In fa, this message translates to:
  /// **'{minutes} دقیقه (سبک)'**
  String minutesLight(int minutes);

  /// No description provided for @minutes.
  ///
  /// In fa, this message translates to:
  /// **'{minutes} دقیقه'**
  String minutes(int minutes);

  /// No description provided for @freeTime.
  ///
  /// In fa, this message translates to:
  /// **'زمان آزاد'**
  String get freeTime;

  /// No description provided for @smartAssistantTitle.
  ///
  /// In fa, this message translates to:
  /// **'دستیار هوشمند ریتمو'**
  String get smartAssistantTitle;

  /// No description provided for @focusOnThisToday.
  ///
  /// In fa, this message translates to:
  /// **'امروز روی این تمرکز کن:'**
  String get focusOnThisToday;

  /// No description provided for @balanceAndImprovement.
  ///
  /// In fa, this message translates to:
  /// **'🎯 تعادل و بهبود مستمر'**
  String get balanceAndImprovement;

  /// No description provided for @bestNextAction.
  ///
  /// In fa, this message translates to:
  /// **'بهترین کار بعدی برای شما'**
  String get bestNextAction;

  /// No description provided for @reasonForSuggestion.
  ///
  /// In fa, this message translates to:
  /// **'دلیل پیشنهاد:'**
  String get reasonForSuggestion;

  /// No description provided for @reasonEssential.
  ///
  /// In fa, this message translates to:
  /// **'این روتین به دلیل اهمیت حیاتی در اولویت است 🎯'**
  String get reasonEssential;

  /// No description provided for @reasonActiveZone.
  ///
  /// In fa, this message translates to:
  /// **'شما در زون «{zone}» هستید 💼'**
  String reasonActiveZone(String zone);

  /// No description provided for @reasonEnergyLevel.
  ///
  /// In fa, this message translates to:
  /// **'سطح انرژی شما {energy} است ⚡'**
  String reasonEnergyLevel(String energy);

  /// No description provided for @reasonSick.
  ///
  /// In fa, this message translates to:
  /// **'به دلیل کسالت، برنامه به حالت بهینه سبک تغییر یافته 🤒'**
  String get reasonSick;

  /// No description provided for @reasonExam.
  ///
  /// In fa, this message translates to:
  /// **'با توجه به بازه امتحانات، اولویت یادگیری افزایش یافته 📚'**
  String get reasonExam;

  /// No description provided for @reasonBusy.
  ///
  /// In fa, this message translates to:
  /// **'به دلیل شلوغی برنامه امروز، این کار پیشنهاد بهینه است ⏳'**
  String get reasonBusy;

  /// No description provided for @reasonWorship.
  ///
  /// In fa, this message translates to:
  /// **'با توجه به فصل عبادی جاری ({season}) 🌙'**
  String reasonWorship(String season);

  /// No description provided for @reasonCompleted.
  ///
  /// In fa, this message translates to:
  /// **'کارهای امروز با موفقیت تکمیل شده‌اند ✨'**
  String get reasonCompleted;

  /// No description provided for @reasonRestTime.
  ///
  /// In fa, this message translates to:
  /// **'زمان استراحت و ریکاوری است 🍃'**
  String get reasonRestTime;

  /// No description provided for @start.
  ///
  /// In fa, this message translates to:
  /// **'شروع'**
  String get start;

  /// No description provided for @whyThisSuggestion.
  ///
  /// In fa, this message translates to:
  /// **'چرا این پیشنهاد؟'**
  String get whyThisSuggestion;

  /// No description provided for @todaysTasksTitle.
  ///
  /// In fa, this message translates to:
  /// **'کارهای امروز'**
  String get todaysTasksTitle;

  /// No description provided for @resolveConflictBtn.
  ///
  /// In fa, this message translates to:
  /// **'⚡ رفع تداخل'**
  String get resolveConflictBtn;

  /// No description provided for @viewAll.
  ///
  /// In fa, this message translates to:
  /// **'مشاهده همه'**
  String get viewAll;

  /// No description provided for @routineDoneMsg.
  ///
  /// In fa, this message translates to:
  /// **'روتین «{title}» انجام شد! 🌟'**
  String routineDoneMsg(String title);

  /// No description provided for @routineDoneLightMsg.
  ///
  /// In fa, this message translates to:
  /// **'روتین «{title}» به صورت سبک انجام شد! ⚡'**
  String routineDoneLightMsg(String title);

  /// No description provided for @routineDoneMinimalMsg.
  ///
  /// In fa, this message translates to:
  /// **'روتین «{title}» به صورت حداقلی انجام شد! 🌿'**
  String routineDoneMinimalMsg(String title);

  /// No description provided for @routineSkippedMsg.
  ///
  /// In fa, this message translates to:
  /// **'روتین «{title}» رد شد. ✕'**
  String routineSkippedMsg(String title);

  /// No description provided for @routinePostponedMsg.
  ///
  /// In fa, this message translates to:
  /// **'روتین «{title}» به تعویق افتاد. ⏳'**
  String routinePostponedMsg(String title);

  /// No description provided for @loggedAtTime.
  ///
  /// In fa, this message translates to:
  /// **'ثبت شده در {time} دقیقه پیش'**
  String loggedAtTime(int time);

  /// No description provided for @loggedAtTimeWithNote.
  ///
  /// In fa, this message translates to:
  /// **'ثبت شده در {time} دقیقه پیش ({note})'**
  String loggedAtTimeWithNote(int time, String note);

  /// No description provided for @basedOnCalculationsAndDefaults.
  ///
  /// In fa, this message translates to:
  /// **'بر اساس محاسبات و مقادیر پیش‌فرض'**
  String get basedOnCalculationsAndDefaults;

  /// No description provided for @basedOnDefaults.
  ///
  /// In fa, this message translates to:
  /// **'بر اساس پیش‌فرض'**
  String get basedOnDefaults;

  /// No description provided for @worshipDebt.
  ///
  /// In fa, this message translates to:
  /// **'بدهی عبادی'**
  String get worshipDebt;

  /// No description provided for @snoozeTimeMinutes.
  ///
  /// In fa, this message translates to:
  /// **'{count} دقیقه'**
  String snoozeTimeMinutes(int count);

  /// No description provided for @snoozeTimeHours.
  ///
  /// In fa, this message translates to:
  /// **'{count} ساعت'**
  String snoozeTimeHours(int count);

  /// No description provided for @welcomeUser.
  ///
  /// In fa, this message translates to:
  /// **'سلام {name}'**
  String welcomeUser(String name);

  /// No description provided for @noRoutinesToday.
  ///
  /// In fa, this message translates to:
  /// **'هیچ روتینی برای امروز باقی نمانده است. ✨'**
  String get noRoutinesToday;

  /// No description provided for @timeLabel.
  ///
  /// In fa, this message translates to:
  /// **'ساعت:'**
  String get timeLabel;

  /// No description provided for @checkinReminderTitle.
  ///
  /// In fa, this message translates to:
  /// **'ثبت وضعیت صبحگاهی (چک‌این) ☀️'**
  String get checkinReminderTitle;

  /// No description provided for @checkinReminderDesc.
  ///
  /// In fa, this message translates to:
  /// **'ثبت وضعیت به ریتمو کمک می‌کند برنامه‌تان را متناسب با سطح انرژی‌تان تنظیم کند.'**
  String get checkinReminderDesc;

  /// No description provided for @reflectionReminderTitle.
  ///
  /// In fa, this message translates to:
  /// **'ثبت تأمل و خودارزیابی روزانه 🌙'**
  String get reflectionReminderTitle;

  /// No description provided for @reflectionReminderDesc.
  ///
  /// In fa, this message translates to:
  /// **'زمانی را برای ارزیابی امروز و یادگیری‌های آن اختصاص دهید.'**
  String get reflectionReminderDesc;

  /// No description provided for @laterOrDismiss.
  ///
  /// In fa, this message translates to:
  /// **'بعداً / صرف‌نظر'**
  String get laterOrDismiss;

  /// No description provided for @yesRecord.
  ///
  /// In fa, this message translates to:
  /// **'بله، ثبت کنم'**
  String get yesRecord;

  /// No description provided for @criticalSystemAlerts.
  ///
  /// In fa, this message translates to:
  /// **'هشدارهای بحرانی سیستم ⚠️'**
  String get criticalSystemAlerts;

  /// No description provided for @worshipPrayer.
  ///
  /// In fa, this message translates to:
  /// **'نماز'**
  String get worshipPrayer;

  /// No description provided for @worshipFast.
  ///
  /// In fa, this message translates to:
  /// **'روزه'**
  String get worshipFast;

  /// No description provided for @totalDebtsLabel.
  ///
  /// In fa, this message translates to:
  /// **'تعداد کل قضاها'**
  String get totalDebtsLabel;

  /// No description provided for @dailyTargetLabel.
  ///
  /// In fa, this message translates to:
  /// **'هدف انجام روزانه'**
  String get dailyTargetLabel;

  /// No description provided for @cancelBtn.
  ///
  /// In fa, this message translates to:
  /// **'انصراف'**
  String get cancelBtn;

  /// No description provided for @registerDebtBtn.
  ///
  /// In fa, this message translates to:
  /// **'ثبت بدهی'**
  String get registerDebtBtn;

  /// No description provided for @timeConflictWarning.
  ///
  /// In fa, this message translates to:
  /// **'هشدار تداخل زمانی'**
  String get timeConflictWarning;

  /// No description provided for @medMinIntervalAlert.
  ///
  /// In fa, this message translates to:
  /// **'فاصله زمانی مجاز بین هر بار مصرف این دارو (حداقل {minInterval} ساعت) رعایت نشده است. آیا مایل به ثبت مصرف هستید؟'**
  String medMinIntervalAlert(double minInterval);

  /// No description provided for @overdoseDanger.
  ///
  /// In fa, this message translates to:
  /// **'خطر بیش‌مصرف (اوردوز)'**
  String get overdoseDanger;

  /// No description provided for @medMaxDosesAlert.
  ///
  /// In fa, this message translates to:
  /// **'تعداد دفعات مصرف مجاز روزانه این دارو ({maxDoses} بار در روز) به سقف خود رسیده است. مصرف بیشتر خطرناک است. آیا مطمئن به ثبت هستید؟'**
  String medMaxDosesAlert(int maxDoses);

  /// No description provided for @dosageUnit.
  ///
  /// In fa, this message translates to:
  /// **'1 عدد'**
  String get dosageUnit;

  /// No description provided for @medLoggedSuccess.
  ///
  /// In fa, this message translates to:
  /// **'مصرف داروی «{title}» با موفقیت ثبت شد.'**
  String medLoggedSuccess(String title);

  /// No description provided for @noCancel.
  ///
  /// In fa, this message translates to:
  /// **'خیر، لغو ثبت'**
  String get noCancel;

  /// No description provided for @yesLog.
  ///
  /// In fa, this message translates to:
  /// **'بله، ثبت مصرف'**
  String get yesLog;

  /// No description provided for @refillStockTitle.
  ///
  /// In fa, this message translates to:
  /// **'شارژ مجدد موجودی: {title}'**
  String refillStockTitle(String title);

  /// No description provided for @refillCountLabel.
  ///
  /// In fa, this message translates to:
  /// **'تعداد داروی اضافه شده'**
  String get refillCountLabel;

  /// No description provided for @refillStockBtn.
  ///
  /// In fa, this message translates to:
  /// **'شارژ موجودی'**
  String get refillStockBtn;

  /// No description provided for @niyyahTitle.
  ///
  /// In fa, this message translates to:
  /// **'آماده‌سازی و شروع: {title}'**
  String niyyahTitle(String title);

  /// No description provided for @completionModeFull.
  ///
  /// In fa, this message translates to:
  /// **'کامل 🎯'**
  String get completionModeFull;

  /// No description provided for @completionModeLight.
  ///
  /// In fa, this message translates to:
  /// **'سبک ⚡'**
  String get completionModeLight;

  /// No description provided for @completionModeMinimal.
  ///
  /// In fa, this message translates to:
  /// **'حداقلی 🌿'**
  String get completionModeMinimal;

  /// No description provided for @startFocusTimer.
  ///
  /// In fa, this message translates to:
  /// **'شروع تایمر تمرکز'**
  String get startFocusTimer;

  /// No description provided for @logWithoutTimer.
  ///
  /// In fa, this message translates to:
  /// **'ثبت فوری بدون تایمر'**
  String get logWithoutTimer;

  /// No description provided for @contextEngineExplanation.
  ///
  /// In fa, this message translates to:
  /// **'سیستم بر اساس موتور تحلیل بافت (Context Engine)، شرایط زمانی و انرژی فعلی شما را سنجیده است.'**
  String get contextEngineExplanation;

  /// No description provided for @ritmoSmartAnalysis.
  ///
  /// In fa, this message translates to:
  /// **'تحلیل هوشمند ریتمو ✨'**
  String get ritmoSmartAnalysis;

  /// No description provided for @understood.
  ///
  /// In fa, this message translates to:
  /// **'فهمیدم'**
  String get understood;

  /// No description provided for @energyManagementTitle.
  ///
  /// In fa, this message translates to:
  /// **'مدیریت و تحلیل انرژی ریتمو'**
  String get energyManagementTitle;

  /// No description provided for @currentDynamicEnergyLabel.
  ///
  /// In fa, this message translates to:
  /// **'درصد پویای انرژی فعلی شما: {label}'**
  String currentDynamicEnergyLabel(String label);

  /// No description provided for @whyThisNumberTitle.
  ///
  /// In fa, this message translates to:
  /// **'چرا این عدد؟ (فرمول محاسبه پویای انرژی)'**
  String get whyThisNumberTitle;

  /// No description provided for @calculating.
  ///
  /// In fa, this message translates to:
  /// **'در حال محاسبه...'**
  String get calculating;

  /// No description provided for @setBaseEnergyLabel.
  ///
  /// In fa, this message translates to:
  /// **'تنظیم سطح انرژی پایه ثبت دستی:'**
  String get setBaseEnergyLabel;

  /// No description provided for @factorsAffectingEnergyLabel.
  ///
  /// In fa, this message translates to:
  /// **'فاکتورهای مؤثر بر خستگی یا افت انرژی امروز:'**
  String get factorsAffectingEnergyLabel;

  /// No description provided for @factorPoorSleep.
  ///
  /// In fa, this message translates to:
  /// **'خواب ضعیف 🛌'**
  String get factorPoorSleep;

  /// No description provided for @factorHighStress.
  ///
  /// In fa, this message translates to:
  /// **'استرس بالا 🧠'**
  String get factorHighStress;

  /// No description provided for @factorPhysicalFatigue.
  ///
  /// In fa, this message translates to:
  /// **'خستگی جسمی 🏋️'**
  String get factorPhysicalFatigue;

  /// No description provided for @factorLackOfFocus.
  ///
  /// In fa, this message translates to:
  /// **'عدم تمرکز ذهنی 🎯'**
  String get factorLackOfFocus;

  /// No description provided for @moodNotesPlaceholder.
  ///
  /// In fa, this message translates to:
  /// **'توضیحات کوتاه یا خلق‌و‌خو (اختیاری)'**
  String get moodNotesPlaceholder;

  /// No description provided for @lackOfFocusStr.
  ///
  /// In fa, this message translates to:
  /// **'عدم تمرکز ذهنی'**
  String get lackOfFocusStr;

  /// No description provided for @energyUpdatedSuccess.
  ///
  /// In fa, this message translates to:
  /// **'سطح انرژی با موفقیت به روز شد.'**
  String get energyUpdatedSuccess;

  /// No description provided for @saveStatusBtn.
  ///
  /// In fa, this message translates to:
  /// **'ثبت و ذخیره‌سازی وضعیت'**
  String get saveStatusBtn;

  /// No description provided for @aiSmartAnalysisTitle.
  ///
  /// In fa, this message translates to:
  /// **'تحلیل هوشمند دستیار ریتمو (AI)'**
  String get aiSmartAnalysisTitle;

  /// No description provided for @dataSentToAiLabel.
  ///
  /// In fa, this message translates to:
  /// **'داده‌های ارسالی به هوش مصنوعی جهت تحلیل:'**
  String get dataSentToAiLabel;

  /// No description provided for @bulletCalculatedEnergy.
  ///
  /// In fa, this message translates to:
  /// **'• درصد پویای محاسبه شده فعلی: {percent}٪\n'**
  String bulletCalculatedEnergy(int percent);

  /// No description provided for @bulletReportedFactors.
  ///
  /// In fa, this message translates to:
  /// **'• عوامل موقت گزارش شده: {factors}\n'**
  String bulletReportedFactors(String factors);

  /// No description provided for @bulletBiologicalClock.
  ///
  /// In fa, this message translates to:
  /// **'• فاز ساعت زیستی بدن در ساعت فعلی روز\n'**
  String get bulletBiologicalClock;

  /// No description provided for @bulletSleepHistory.
  ///
  /// In fa, this message translates to:
  /// **'• تاریخچه خواب اخیر و وضعیت روتین‌های تکمیل‌شده'**
  String get bulletSleepHistory;

  /// No description provided for @agreeToSendData.
  ///
  /// In fa, this message translates to:
  /// **'با ارسال امن داده‌های فوق جهت تحلیل موافقم.'**
  String get agreeToSendData;

  /// No description provided for @noRecommendationFound.
  ///
  /// In fa, this message translates to:
  /// **'پیشنهادی یافت نشد.'**
  String get noRecommendationFound;

  /// No description provided for @networkErrorMsg.
  ///
  /// In fa, this message translates to:
  /// **'خطا در اتصال به شبکه یا دریافت پاسخ.'**
  String get networkErrorMsg;

  /// No description provided for @analyzeAndGetRecommendation.
  ///
  /// In fa, this message translates to:
  /// **'تحلیل و دریافت پیشنهاد ✨'**
  String get analyzeAndGetRecommendation;

  /// No description provided for @analyzingDataMsg.
  ///
  /// In fa, this message translates to:
  /// **'در حال تحلیل داده‌های خواب و روتین‌ها توسط هوش مصنوعی...'**
  String get analyzingDataMsg;

  /// No description provided for @reAnalyze.
  ///
  /// In fa, this message translates to:
  /// **'تحلیل مجدد 🔄'**
  String get reAnalyze;

  /// No description provided for @localEnergyEngineReport.
  ///
  /// In fa, this message translates to:
  /// **'گزارش آماری موتور تحلیل انرژی (محلی):'**
  String get localEnergyEngineReport;

  /// No description provided for @insufficientData.
  ///
  /// In fa, this message translates to:
  /// **'داده ناکافی'**
  String get insufficientData;

  /// No description provided for @goldenHourLabel.
  ///
  /// In fa, this message translates to:
  /// **'ساعت طلایی بازدهی:'**
  String get goldenHourLabel;

  /// No description provided for @fatigueWindowLabel.
  ///
  /// In fa, this message translates to:
  /// **'بازه بیشترین خستگی:'**
  String get fatigueWindowLabel;

  /// No description provided for @productiveDayLabel.
  ///
  /// In fa, this message translates to:
  /// **'پربازده‌ترین روز:'**
  String get productiveDayLabel;

  /// No description provided for @healthScreenTitle.
  ///
  /// In fa, this message translates to:
  /// **'سلامت'**
  String get healthScreenTitle;

  /// No description provided for @medicationsToday.
  ///
  /// In fa, this message translates to:
  /// **'داروهای امروز'**
  String get medicationsToday;

  /// No description provided for @doctorVisits.
  ///
  /// In fa, this message translates to:
  /// **'نوبت‌های پزشک'**
  String get doctorVisits;

  /// No description provided for @healthMonitoring.
  ///
  /// In fa, this message translates to:
  /// **'پایش سلامت'**
  String get healthMonitoring;

  /// No description provided for @medicalDocuments.
  ///
  /// In fa, this message translates to:
  /// **'مدارک پزشکی'**
  String get medicalDocuments;

  /// No description provided for @pregnancyTracker.
  ///
  /// In fa, this message translates to:
  /// **'بارداری'**
  String get pregnancyTracker;

  /// No description provided for @vaccinations.
  ///
  /// In fa, this message translates to:
  /// **'واکسن‌ها'**
  String get vaccinations;

  /// No description provided for @allergies.
  ///
  /// In fa, this message translates to:
  /// **'آلرژی‌ها'**
  String get allergies;

  /// No description provided for @medicalProfile.
  ///
  /// In fa, this message translates to:
  /// **'پرونده پزشکی'**
  String get medicalProfile;

  /// No description provided for @doctorVisitsTabUpcoming.
  ///
  /// In fa, this message translates to:
  /// **'پیش‌رو'**
  String get doctorVisitsTabUpcoming;

  /// No description provided for @doctorVisitsTabPast.
  ///
  /// In fa, this message translates to:
  /// **'گذشته'**
  String get doctorVisitsTabPast;

  /// No description provided for @doctorVisitsNoUpcoming.
  ///
  /// In fa, this message translates to:
  /// **'هیچ نوبت پیش‌رویی ثبت نشده است.'**
  String get doctorVisitsNoUpcoming;

  /// No description provided for @doctorVisitsNoPast.
  ///
  /// In fa, this message translates to:
  /// **'هیچ نوبت گذشته‌ای ثبت نشده است.'**
  String get doctorVisitsNoPast;

  /// No description provided for @doctorVisitsAddTitle.
  ///
  /// In fa, this message translates to:
  /// **'ثبت نوبت پزشک'**
  String get doctorVisitsAddTitle;

  /// No description provided for @doctorVisitsEditTitle.
  ///
  /// In fa, this message translates to:
  /// **'ویرایش نوبت پزشک'**
  String get doctorVisitsEditTitle;

  /// No description provided for @doctorVisitsDoctorName.
  ///
  /// In fa, this message translates to:
  /// **'نام پزشک'**
  String get doctorVisitsDoctorName;

  /// No description provided for @doctorVisitsSpecialty.
  ///
  /// In fa, this message translates to:
  /// **'تخصص (اختیاری)'**
  String get doctorVisitsSpecialty;

  /// No description provided for @doctorVisitsClinicName.
  ///
  /// In fa, this message translates to:
  /// **'نام کلینیک (اختیاری)'**
  String get doctorVisitsClinicName;

  /// No description provided for @doctorVisitsClinicAddress.
  ///
  /// In fa, this message translates to:
  /// **'آدرس (اختیاری)'**
  String get doctorVisitsClinicAddress;

  /// No description provided for @doctorVisitsClinicPhone.
  ///
  /// In fa, this message translates to:
  /// **'تلفن (اختیاری)'**
  String get doctorVisitsClinicPhone;

  /// No description provided for @doctorVisitsReason.
  ///
  /// In fa, this message translates to:
  /// **'علت مراجعه (اختیاری)'**
  String get doctorVisitsReason;

  /// No description provided for @doctorVisitsNotes.
  ///
  /// In fa, this message translates to:
  /// **'یادداشت‌ها (اختیاری)'**
  String get doctorVisitsNotes;

  /// No description provided for @doctorVisitsDateTime.
  ///
  /// In fa, this message translates to:
  /// **'تاریخ و ساعت نوبت'**
  String get doctorVisitsDateTime;

  /// No description provided for @doctorVisitsReminder.
  ///
  /// In fa, this message translates to:
  /// **'یادآوری قبل از نوبت'**
  String get doctorVisitsReminder;

  /// No description provided for @doctorVisitsType.
  ///
  /// In fa, this message translates to:
  /// **'نوع نوبت'**
  String get doctorVisitsType;

  /// No description provided for @doctorVisitsTypeInPerson.
  ///
  /// In fa, this message translates to:
  /// **'حضوری'**
  String get doctorVisitsTypeInPerson;

  /// No description provided for @doctorVisitsTypeOnline.
  ///
  /// In fa, this message translates to:
  /// **'آنلاین'**
  String get doctorVisitsTypeOnline;

  /// No description provided for @doctorVisitsTypeTelephone.
  ///
  /// In fa, this message translates to:
  /// **'تلفنی'**
  String get doctorVisitsTypeTelephone;

  /// No description provided for @doctorVisitsReminderNone.
  ///
  /// In fa, this message translates to:
  /// **'بدون یادآوری'**
  String get doctorVisitsReminderNone;

  /// No description provided for @doctorVisitsReminder15m.
  ///
  /// In fa, this message translates to:
  /// **'۱۵ دقیقه قبل'**
  String get doctorVisitsReminder15m;

  /// No description provided for @doctorVisitsReminder30m.
  ///
  /// In fa, this message translates to:
  /// **'۳۰ دقیقه قبل'**
  String get doctorVisitsReminder30m;

  /// No description provided for @doctorVisitsReminder1h.
  ///
  /// In fa, this message translates to:
  /// **'۱ ساعت قبل'**
  String get doctorVisitsReminder1h;

  /// No description provided for @doctorVisitsReminder2h.
  ///
  /// In fa, this message translates to:
  /// **'۲ ساعت قبل'**
  String get doctorVisitsReminder2h;

  /// No description provided for @doctorVisitsReminder1d.
  ///
  /// In fa, this message translates to:
  /// **'۱ روز قبل'**
  String get doctorVisitsReminder1d;

  /// No description provided for @doctorVisitsSave.
  ///
  /// In fa, this message translates to:
  /// **'ذخیره نوبت'**
  String get doctorVisitsSave;

  /// No description provided for @doctorVisitsDeleteConfirm.
  ///
  /// In fa, this message translates to:
  /// **'آیا مطمئن هستید که می‌خواهید این نوبت را حذف کنید؟'**
  String get doctorVisitsDeleteConfirm;

  /// No description provided for @doctorVisitsAddAttachment.
  ///
  /// In fa, this message translates to:
  /// **'افزودن نسخه یا مدرک'**
  String get doctorVisitsAddAttachment;

  /// No description provided for @doctorVisitsDelete.
  ///
  /// In fa, this message translates to:
  /// **'حذف نوبت'**
  String get doctorVisitsDelete;

  /// No description provided for @doctorVisitsCancel.
  ///
  /// In fa, this message translates to:
  /// **'انصراف'**
  String get doctorVisitsCancel;

  /// No description provided for @doctorVisitsConfirm.
  ///
  /// In fa, this message translates to:
  /// **'تایید'**
  String get doctorVisitsConfirm;

  /// No description provided for @bloodSugarTitle.
  ///
  /// In fa, this message translates to:
  /// **'قند خون'**
  String get bloodSugarTitle;

  /// No description provided for @bloodSugarValue.
  ///
  /// In fa, this message translates to:
  /// **'میزان قند خون (mg/dL)'**
  String get bloodSugarValue;

  /// No description provided for @bloodSugarFasting.
  ///
  /// In fa, this message translates to:
  /// **'ناشتا'**
  String get bloodSugarFasting;

  /// No description provided for @bloodSugarBeforeMeal.
  ///
  /// In fa, this message translates to:
  /// **'قبل از غذا'**
  String get bloodSugarBeforeMeal;

  /// No description provided for @bloodSugarAfterMeal.
  ///
  /// In fa, this message translates to:
  /// **'بعد از غذا'**
  String get bloodSugarAfterMeal;

  /// No description provided for @bloodSugarBedtime.
  ///
  /// In fa, this message translates to:
  /// **'قبل از خواب'**
  String get bloodSugarBedtime;

  /// No description provided for @bloodSugarRandom.
  ///
  /// In fa, this message translates to:
  /// **'تصادفی'**
  String get bloodSugarRandom;

  /// No description provided for @bloodSugarDiabeticFlag.
  ///
  /// In fa, this message translates to:
  /// **'کاربر مبتلا به دیابت است'**
  String get bloodSugarDiabeticFlag;

  /// No description provided for @bloodSugarInRange.
  ///
  /// In fa, this message translates to:
  /// **'در محدوده نرمال'**
  String get bloodSugarInRange;

  /// No description provided for @bloodSugarLow.
  ///
  /// In fa, this message translates to:
  /// **'پایین (افت قند)'**
  String get bloodSugarLow;

  /// No description provided for @bloodSugarHigh.
  ///
  /// In fa, this message translates to:
  /// **'بالا (قند خون بالا)'**
  String get bloodSugarHigh;

  /// No description provided for @bloodSugarSave.
  ///
  /// In fa, this message translates to:
  /// **'ثبت قند خون'**
  String get bloodSugarSave;

  /// No description provided for @bloodSugarHistory.
  ///
  /// In fa, this message translates to:
  /// **'تاریخچه سنجش‌ها'**
  String get bloodSugarHistory;

  /// No description provided for @bloodSugarEnterValue.
  ///
  /// In fa, this message translates to:
  /// **'لطفاً میزان قند خون را وارد کنید'**
  String get bloodSugarEnterValue;

  /// No description provided for @bloodSugarLastLog.
  ///
  /// In fa, this message translates to:
  /// **'آخرین سنجش: {value} {type}'**
  String bloodSugarLastLog(Object type, Object value);

  /// No description provided for @bloodPressureTitle.
  ///
  /// In fa, this message translates to:
  /// **'فشار خون'**
  String get bloodPressureTitle;

  /// No description provided for @bloodPressureSystolic.
  ///
  /// In fa, this message translates to:
  /// **'فشار سیستولیک (میلی‌متر جیوه)'**
  String get bloodPressureSystolic;

  /// No description provided for @bloodPressureDiastolic.
  ///
  /// In fa, this message translates to:
  /// **'فشار دیاستولیک (میلی‌متر جیوه)'**
  String get bloodPressureDiastolic;

  /// No description provided for @bloodPressurePulse.
  ///
  /// In fa, this message translates to:
  /// **'ضربان قلب (بار در دقیقه)'**
  String get bloodPressurePulse;

  /// No description provided for @bloodPressureArm.
  ///
  /// In fa, this message translates to:
  /// **'دست مورد استفاده'**
  String get bloodPressureArm;

  /// No description provided for @bloodPressureArmLeft.
  ///
  /// In fa, this message translates to:
  /// **'دست چپ'**
  String get bloodPressureArmLeft;

  /// No description provided for @bloodPressureArmRight.
  ///
  /// In fa, this message translates to:
  /// **'دست راست'**
  String get bloodPressureArmRight;

  /// No description provided for @bloodPressurePosition.
  ///
  /// In fa, this message translates to:
  /// **'وضعیت بدن'**
  String get bloodPressurePosition;

  /// No description provided for @bloodPressurePositionSitting.
  ///
  /// In fa, this message translates to:
  /// **'نشسته'**
  String get bloodPressurePositionSitting;

  /// No description provided for @bloodPressurePositionStanding.
  ///
  /// In fa, this message translates to:
  /// **'ایستاده'**
  String get bloodPressurePositionStanding;

  /// No description provided for @bloodPressurePositionLying.
  ///
  /// In fa, this message translates to:
  /// **'خوابیده'**
  String get bloodPressurePositionLying;

  /// No description provided for @bloodPressureSave.
  ///
  /// In fa, this message translates to:
  /// **'ثبت فشار خون'**
  String get bloodPressureSave;

  /// No description provided for @bloodPressureHistory.
  ///
  /// In fa, this message translates to:
  /// **'تاریخچه فشار خون'**
  String get bloodPressureHistory;

  /// No description provided for @bloodPressureLastLog.
  ///
  /// In fa, this message translates to:
  /// **'آخرین فشار: {systolic}/{diastolic}'**
  String bloodPressureLastLog(Object diastolic, Object systolic);

  /// No description provided for @vitalSignsTitle.
  ///
  /// In fa, this message translates to:
  /// **'علائم حیاتی'**
  String get vitalSignsTitle;

  /// No description provided for @vitalSignsWeight.
  ///
  /// In fa, this message translates to:
  /// **'وزن'**
  String get vitalSignsWeight;

  /// No description provided for @vitalSignsTemperature.
  ///
  /// In fa, this message translates to:
  /// **'دمای بدن'**
  String get vitalSignsTemperature;

  /// No description provided for @vitalSignsSpo2.
  ///
  /// In fa, this message translates to:
  /// **'اکسیژن خون'**
  String get vitalSignsSpo2;

  /// No description provided for @vitalSignsWaist.
  ///
  /// In fa, this message translates to:
  /// **'دور کمر'**
  String get vitalSignsWaist;

  /// No description provided for @vitalSignsHeight.
  ///
  /// In fa, this message translates to:
  /// **'قد (سانتی‌متر)'**
  String get vitalSignsHeight;

  /// No description provided for @vitalSignsSave.
  ///
  /// In fa, this message translates to:
  /// **'ثبت علامت حیاتی'**
  String get vitalSignsSave;

  /// No description provided for @vitalSignsValue.
  ///
  /// In fa, this message translates to:
  /// **'مقدار'**
  String get vitalSignsValue;

  /// No description provided for @vitalSignsHistory.
  ///
  /// In fa, this message translates to:
  /// **'سابقه علائم حیاتی'**
  String get vitalSignsHistory;

  /// No description provided for @vitalSignsLastWeight.
  ///
  /// In fa, this message translates to:
  /// **'آخرین وزن: {value} کیلوگرم'**
  String vitalSignsLastWeight(Object value);

  /// No description provided for @vitalSignsBmi.
  ///
  /// In fa, this message translates to:
  /// **'شاخص توده بدنی (BMI): {value} ({label})'**
  String vitalSignsBmi(Object label, Object value);

  /// No description provided for @vitalSignsBmiUnderweight.
  ///
  /// In fa, this message translates to:
  /// **'کمبود وزن'**
  String get vitalSignsBmiUnderweight;

  /// No description provided for @vitalSignsBmiNormal.
  ///
  /// In fa, this message translates to:
  /// **'نرمال'**
  String get vitalSignsBmiNormal;

  /// No description provided for @vitalSignsBmiOverweight.
  ///
  /// In fa, this message translates to:
  /// **'اضافه وزن'**
  String get vitalSignsBmiOverweight;

  /// No description provided for @vitalSignsBmiObese.
  ///
  /// In fa, this message translates to:
  /// **'چاقی'**
  String get vitalSignsBmiObese;

  /// No description provided for @medicalDocumentsTitle.
  ///
  /// In fa, this message translates to:
  /// **'مدارک پزشکی'**
  String get medicalDocumentsTitle;

  /// No description provided for @medicalDocumentsAddTitle.
  ///
  /// In fa, this message translates to:
  /// **'ثبت مدرک جدید'**
  String get medicalDocumentsAddTitle;

  /// No description provided for @medicalDocumentsEditTitle.
  ///
  /// In fa, this message translates to:
  /// **'ویرایش مدرک'**
  String get medicalDocumentsEditTitle;

  /// No description provided for @medicalDocumentsDocTitle.
  ///
  /// In fa, this message translates to:
  /// **'عنوان مدرک'**
  String get medicalDocumentsDocTitle;

  /// No description provided for @medicalDocumentsCategory.
  ///
  /// In fa, this message translates to:
  /// **'دسته‌بندی'**
  String get medicalDocumentsCategory;

  /// No description provided for @medicalDocumentsDate.
  ///
  /// In fa, this message translates to:
  /// **'تاریخ آزمایش / مدرک'**
  String get medicalDocumentsDate;

  /// No description provided for @medicalDocumentsLabName.
  ///
  /// In fa, this message translates to:
  /// **'نام آزمایشگاه / مرکز درمان'**
  String get medicalDocumentsLabName;

  /// No description provided for @medicalDocumentsSummary.
  ///
  /// In fa, this message translates to:
  /// **'خلاصه گزارش'**
  String get medicalDocumentsSummary;

  /// No description provided for @medicalDocumentsDoctorNotes.
  ///
  /// In fa, this message translates to:
  /// **'توصیه پزشک'**
  String get medicalDocumentsDoctorNotes;

  /// No description provided for @medicalDocumentsUserNotes.
  ///
  /// In fa, this message translates to:
  /// **'یادداشت کاربر'**
  String get medicalDocumentsUserNotes;

  /// No description provided for @medicalDocumentsSelectImages.
  ///
  /// In fa, this message translates to:
  /// **'انتخاب تصاویر مدارک'**
  String get medicalDocumentsSelectImages;

  /// No description provided for @medicalDocumentsHistory.
  ///
  /// In fa, this message translates to:
  /// **'آرشیو مدارک پزشکی'**
  String get medicalDocumentsHistory;

  /// No description provided for @medicalDocumentsNoDocs.
  ///
  /// In fa, this message translates to:
  /// **'هیچ مدرک یا آزمایشی ثبت نشده است.'**
  String get medicalDocumentsNoDocs;

  /// No description provided for @medicalDocumentsDeleteConfirm.
  ///
  /// In fa, this message translates to:
  /// **'آیا مطمئن هستید که می‌خواهید این مدرک و تمامی تصاویر آن را حذف کنید؟'**
  String get medicalDocumentsDeleteConfirm;

  /// No description provided for @medicalDocumentsSave.
  ///
  /// In fa, this message translates to:
  /// **'ذخیره مدرک'**
  String get medicalDocumentsSave;

  /// No description provided for @medicalDocumentsCount.
  ///
  /// In fa, this message translates to:
  /// **'{count} مدرک ثبت شده'**
  String medicalDocumentsCount(int count);

  /// No description provided for @vaccineName.
  ///
  /// In fa, this message translates to:
  /// **'نام واکسن'**
  String get vaccineName;

  /// No description provided for @vaccineDiseaseTarget.
  ///
  /// In fa, this message translates to:
  /// **'بیماری هدف'**
  String get vaccineDiseaseTarget;

  /// No description provided for @vaccineDoseNumber.
  ///
  /// In fa, this message translates to:
  /// **'شماره دوز'**
  String get vaccineDoseNumber;

  /// No description provided for @vaccineTotalDoses.
  ///
  /// In fa, this message translates to:
  /// **'تعداد کل دوزها'**
  String get vaccineTotalDoses;

  /// No description provided for @vaccineDateAdministered.
  ///
  /// In fa, this message translates to:
  /// **'تاریخ تزریق'**
  String get vaccineDateAdministered;

  /// No description provided for @vaccineNextDoseDue.
  ///
  /// In fa, this message translates to:
  /// **'تاریخ دوز بعدی'**
  String get vaccineNextDoseDue;

  /// No description provided for @vaccineBatchNumber.
  ///
  /// In fa, this message translates to:
  /// **'شماره سری (بچ)'**
  String get vaccineBatchNumber;

  /// No description provided for @vaccineClinicName.
  ///
  /// In fa, this message translates to:
  /// **'نام کلینیک / مرکز تزریق'**
  String get vaccineClinicName;

  /// No description provided for @vaccineNotes.
  ///
  /// In fa, this message translates to:
  /// **'یادداشت‌ها'**
  String get vaccineNotes;

  /// No description provided for @vaccineSave.
  ///
  /// In fa, this message translates to:
  /// **'ثبت واکسیناسیون'**
  String get vaccineSave;

  /// No description provided for @vaccineDaysUntilDue.
  ///
  /// In fa, this message translates to:
  /// **'{days} روز تا دوز بعدی'**
  String vaccineDaysUntilDue(int days);

  /// No description provided for @vaccineOverdue.
  ///
  /// In fa, this message translates to:
  /// **'⚠️ دوز بعدی تأخیر دارد ({days} روز تأخیر)'**
  String vaccineOverdue(int days);

  /// No description provided for @vaccineNoDoses.
  ///
  /// In fa, this message translates to:
  /// **'هیچ واکسنی ثبت نشده است.'**
  String get vaccineNoDoses;

  /// No description provided for @allergyName.
  ///
  /// In fa, this message translates to:
  /// **'ماده حساسیت‌زا (آلرژن)'**
  String get allergyName;

  /// No description provided for @allergyCategory.
  ///
  /// In fa, this message translates to:
  /// **'دسته‌بندی آلرژی'**
  String get allergyCategory;

  /// No description provided for @allergyCategoryFood.
  ///
  /// In fa, this message translates to:
  /// **'غذایی'**
  String get allergyCategoryFood;

  /// No description provided for @allergyCategoryDrug.
  ///
  /// In fa, this message translates to:
  /// **'دارویی'**
  String get allergyCategoryDrug;

  /// No description provided for @allergyCategoryEnvironment.
  ///
  /// In fa, this message translates to:
  /// **'محیطی'**
  String get allergyCategoryEnvironment;

  /// No description provided for @allergyCategoryOther.
  ///
  /// In fa, this message translates to:
  /// **'سایر'**
  String get allergyCategoryOther;

  /// No description provided for @allergyReaction.
  ///
  /// In fa, this message translates to:
  /// **'واکنش بدنی / علائم'**
  String get allergyReaction;

  /// No description provided for @allergySeverity.
  ///
  /// In fa, this message translates to:
  /// **'شدت حساسیت'**
  String get allergySeverity;

  /// No description provided for @allergySeverityMild.
  ///
  /// In fa, this message translates to:
  /// **'خفیف'**
  String get allergySeverityMild;

  /// No description provided for @allergySeverityModerate.
  ///
  /// In fa, this message translates to:
  /// **'متوسط'**
  String get allergySeverityModerate;

  /// No description provided for @allergySeveritySevere.
  ///
  /// In fa, this message translates to:
  /// **'شدید'**
  String get allergySeveritySevere;

  /// No description provided for @allergySeverityLifeThreatening.
  ///
  /// In fa, this message translates to:
  /// **'تهدیدکننده حیات ⚠️'**
  String get allergySeverityLifeThreatening;

  /// No description provided for @allergyDiagnosedDate.
  ///
  /// In fa, this message translates to:
  /// **'تاریخ تشخیص'**
  String get allergyDiagnosedDate;

  /// No description provided for @allergySave.
  ///
  /// In fa, this message translates to:
  /// **'ثبت آلرژی'**
  String get allergySave;

  /// No description provided for @allergyNoAllergies.
  ///
  /// In fa, this message translates to:
  /// **'هیچ آلرژی ثبت نشده است.'**
  String get allergyNoAllergies;

  /// No description provided for @allergyDeleteConfirm.
  ///
  /// In fa, this message translates to:
  /// **'آیا مطمئن هستید که می‌خواهید این آلرژی را حذف کنید؟'**
  String get allergyDeleteConfirm;

  /// No description provided for @pregnancyTitle.
  ///
  /// In fa, this message translates to:
  /// **'بارداری'**
  String get pregnancyTitle;

  /// No description provided for @pregnancyLmp.
  ///
  /// In fa, this message translates to:
  /// **'اولین روز آخرین قاعدگی (LMP)'**
  String get pregnancyLmp;

  /// No description provided for @pregnancyEdd.
  ///
  /// In fa, this message translates to:
  /// **'تاریخ تخمینی زایمان (EDD)'**
  String get pregnancyEdd;

  /// No description provided for @pregnancyStart.
  ///
  /// In fa, this message translates to:
  /// **'شروع پایش بارداری'**
  String get pregnancyStart;

  /// No description provided for @pregnancyEnd.
  ///
  /// In fa, this message translates to:
  /// **'غیرفعال‌سازی پایش'**
  String get pregnancyEnd;

  /// No description provided for @pregnancyWeek.
  ///
  /// In fa, this message translates to:
  /// **'هفته {week} بارداری (روز {day})'**
  String pregnancyWeek(int week, int day);

  /// No description provided for @pregnancyTrimester1.
  ///
  /// In fa, this message translates to:
  /// **'سه ماهه اول'**
  String get pregnancyTrimester1;

  /// No description provided for @pregnancyTrimester2.
  ///
  /// In fa, this message translates to:
  /// **'سه ماهه دوم'**
  String get pregnancyTrimester2;

  /// No description provided for @pregnancyTrimester3.
  ///
  /// In fa, this message translates to:
  /// **'سه ماهه سوم'**
  String get pregnancyTrimester3;

  /// No description provided for @pregnancyNoTracker.
  ///
  /// In fa, this message translates to:
  /// **'پایش فعال بارداری وجود ندارد.'**
  String get pregnancyNoTracker;

  /// No description provided for @cycleSosButton.
  ///
  /// In fa, this message translates to:
  /// **'کمک فوری تسکین درد'**
  String get cycleSosButton;

  /// No description provided for @cyclePregnancyActivate.
  ///
  /// In fa, this message translates to:
  /// **'🤰 فعال‌سازی حالت بارداری'**
  String get cyclePregnancyActivate;

  /// No description provided for @cyclePregnancyConfirmPrompt.
  ///
  /// In fa, this message translates to:
  /// **'آیا باردار هستید؟ با فعال‌سازی این حالت، پیگیری چرخه قاعدگی متوقف می‌شود و اطلاعات دوران بارداری نمایش داده می‌شود.'**
  String get cyclePregnancyConfirmPrompt;

  /// No description provided for @cyclePregnancyDeactivate.
  ///
  /// In fa, this message translates to:
  /// **'بازگشت به حالت عادی'**
  String get cyclePregnancyDeactivate;

  /// No description provided for @pregnancyMedicalDisclaimer.
  ///
  /// In fa, this message translates to:
  /// **'این برنامه یک ابزار پزشکی نیست و جایگزین نظر پزشک متخصص نمی‌شود. در هر وضعیت نگران‌کننده با پزشک یا ماما تماس بگیرید.'**
  String get pregnancyMedicalDisclaimer;

  /// No description provided for @medicationFormLabel.
  ///
  /// In fa, this message translates to:
  /// **'شکل دارویی'**
  String get medicationFormLabel;

  /// No description provided for @medicationRouteLabel.
  ///
  /// In fa, this message translates to:
  /// **'مسیر مصرف'**
  String get medicationRouteLabel;

  /// No description provided for @medicationDoseLabel.
  ///
  /// In fa, this message translates to:
  /// **'مقدار دوز مصرفی'**
  String get medicationDoseLabel;

  /// No description provided for @medicationUnitLabel.
  ///
  /// In fa, this message translates to:
  /// **'واحد دوز'**
  String get medicationUnitLabel;

  /// No description provided for @medicationFoodRelationLabel.
  ///
  /// In fa, this message translates to:
  /// **'ارتباط با غذا'**
  String get medicationFoodRelationLabel;

  /// No description provided for @medicationCourseLabel.
  ///
  /// In fa, this message translates to:
  /// **'دوره درمان'**
  String get medicationCourseLabel;

  /// No description provided for @medicationChronic.
  ///
  /// In fa, this message translates to:
  /// **'مزمن / دائمی'**
  String get medicationChronic;

  /// No description provided for @medicationLimitedCourse.
  ///
  /// In fa, this message translates to:
  /// **'دوره محدود'**
  String get medicationLimitedCourse;

  /// No description provided for @medicationStockTracking.
  ///
  /// In fa, this message translates to:
  /// **'پیگیری موجودی'**
  String get medicationStockTracking;

  /// No description provided for @medicationPackageSize.
  ///
  /// In fa, this message translates to:
  /// **'اندازه بسته'**
  String get medicationPackageSize;

  /// No description provided for @medicationRemainingStock.
  ///
  /// In fa, this message translates to:
  /// **'موجودی فعلی'**
  String get medicationRemainingStock;

  /// No description provided for @medicationRefillWarning.
  ///
  /// In fa, this message translates to:
  /// **'آستانه هشدار تمدید'**
  String get medicationRefillWarning;

  /// No description provided for @medicationPrescriber.
  ///
  /// In fa, this message translates to:
  /// **'پزشک تجویزکننده'**
  String get medicationPrescriber;

  /// No description provided for @medicationInstructions.
  ///
  /// In fa, this message translates to:
  /// **'دستور مصرف / توضیحات'**
  String get medicationInstructions;

  /// No description provided for @medicationCriticalityLabel.
  ///
  /// In fa, this message translates to:
  /// **'اهمیت بالینی'**
  String get medicationCriticalityLabel;

  /// No description provided for @medicationSiteRotation.
  ///
  /// In fa, this message translates to:
  /// **'چرخش محل تزریق'**
  String get medicationSiteRotation;

  /// No description provided for @medicationActiveIngredient.
  ///
  /// In fa, this message translates to:
  /// **'ماده موثره / ژنریک'**
  String get medicationActiveIngredient;

  /// No description provided for @medicationStrength.
  ///
  /// In fa, this message translates to:
  /// **'قدرت / غلظت دارو'**
  String get medicationStrength;

  /// No description provided for @medicationDisclaimers.
  ///
  /// In fa, this message translates to:
  /// **'همواره طبق تجویز و صلاحدید پزشک خود دارو را مصرف کنید.'**
  String get medicationDisclaimers;

  /// No description provided for @cycleCalendarGuide.
  ///
  /// In fa, this message translates to:
  /// **'راهنمای تقویم چرخه بدنی:'**
  String get cycleCalendarGuide;

  /// No description provided for @cyclePeriodRecorded.
  ///
  /// In fa, this message translates to:
  /// **'قاعدگی (ثبت‌شده)'**
  String get cyclePeriodRecorded;

  /// No description provided for @cyclePeriodPredicted.
  ///
  /// In fa, this message translates to:
  /// **'دوره پیش‌بینی‌شده'**
  String get cyclePeriodPredicted;

  /// No description provided for @cyclePredictionWindow.
  ///
  /// In fa, this message translates to:
  /// **'بازه احتمالی جابجایی'**
  String get cyclePredictionWindow;

  /// No description provided for @cycleLowConfidence.
  ///
  /// In fa, this message translates to:
  /// **'پیش‌بینی با اطمینان کم'**
  String get cycleLowConfidence;

  /// No description provided for @cyclePmsDays.
  ///
  /// In fa, this message translates to:
  /// **'روزهای پیش از عادت (PMS)'**
  String get cyclePmsDays;

  /// No description provided for @cycleOvulationDay.
  ///
  /// In fa, this message translates to:
  /// **'روز تخمک‌گذاری'**
  String get cycleOvulationDay;

  /// No description provided for @cycleFertileWindow.
  ///
  /// In fa, this message translates to:
  /// **'پنجره باروری (Fertile)'**
  String get cycleFertileWindow;

  /// No description provided for @cycleToday.
  ///
  /// In fa, this message translates to:
  /// **'امروز'**
  String get cycleToday;

  /// No description provided for @cycleLoggedSymptoms.
  ///
  /// In fa, this message translates to:
  /// **'علائم ثبت شده'**
  String get cycleLoggedSymptoms;

  /// No description provided for @cycleJumpToNext.
  ///
  /// In fa, this message translates to:
  /// **'پرش به دوره بعد'**
  String get cycleJumpToNext;

  /// No description provided for @cycleCurrentMonth.
  ///
  /// In fa, this message translates to:
  /// **'ماه جاری'**
  String get cycleCurrentMonth;

  /// No description provided for @cycleConfidenceHigh.
  ///
  /// In fa, this message translates to:
  /// **'اطمینان بالا'**
  String get cycleConfidenceHigh;

  /// No description provided for @cycleConfidenceMedium.
  ///
  /// In fa, this message translates to:
  /// **'اطمینان متوسط'**
  String get cycleConfidenceMedium;

  /// No description provided for @cycleConfidenceLow.
  ///
  /// In fa, this message translates to:
  /// **'اطمینان کم'**
  String get cycleConfidenceLow;

  /// No description provided for @bridgeAuthRequired.
  ///
  /// In fa, this message translates to:
  /// **'برای استفاده از مدل ChatGPT، لطفاً وارد حساب کاربری خود شوید.'**
  String get bridgeAuthRequired;

  /// No description provided for @bridgeAuthRequiredAction.
  ///
  /// In fa, this message translates to:
  /// **'ورود به حساب کاربری'**
  String get bridgeAuthRequiredAction;

  /// No description provided for @bridgeCloudflareChallenge.
  ///
  /// In fa, this message translates to:
  /// **'تایید امنیتی کلودفلر ضروری است.'**
  String get bridgeCloudflareChallenge;

  /// No description provided for @bridgeCloudflareChallengeAction.
  ///
  /// In fa, this message translates to:
  /// **'تکمیل تایید امنیتی'**
  String get bridgeCloudflareChallengeAction;

  /// No description provided for @bridgeVpnRequired.
  ///
  /// In fa, this message translates to:
  /// **'دسترسی به چت‌جی‌پی‌تی از این IP مسدود است (تحریم یا فیلترینگ). لطفاً فیلترشکن (VPN) یا تحریم‌شکن خود را فعال کرده و دوباره تلاش کنید.'**
  String get bridgeVpnRequired;

  /// No description provided for @bridgeVpnRequiredAction.
  ///
  /// In fa, this message translates to:
  /// **'فعال‌سازی فیلترشکن / تحریم‌شکن'**
  String get bridgeVpnRequiredAction;

  /// No description provided for @bridgeRateLimited.
  ///
  /// In fa, this message translates to:
  /// **'محدودیت درخواست چت‌جی‌پی‌تی (Rate Limit). لطفاً کمی صبر کرده و مجدداً تلاش کنید.'**
  String get bridgeRateLimited;

  /// No description provided for @bridgeRateLimitedAction.
  ///
  /// In fa, this message translates to:
  /// **'تلاش مجدد پس از چند دقیقه'**
  String get bridgeRateLimitedAction;

  /// No description provided for @bridgeServerError.
  ///
  /// In fa, this message translates to:
  /// **'خطای موقت در سرورهای ChatGPT. لطفاً لحظاتی دیگر مجدداً تلاش کنید.'**
  String get bridgeServerError;

  /// No description provided for @bridgeServerErrorAction.
  ///
  /// In fa, this message translates to:
  /// **'تلاش مجدد'**
  String get bridgeServerErrorAction;

  /// No description provided for @bridgeTimeout.
  ///
  /// In fa, this message translates to:
  /// **'زمان انتظار برای دریافت پاسخ از ChatGPT به پایان رسید.'**
  String get bridgeTimeout;

  /// No description provided for @bridgeTimeoutAction.
  ///
  /// In fa, this message translates to:
  /// **'تلاش مجدد'**
  String get bridgeTimeoutAction;

  /// No description provided for @bridgeNetworkError.
  ///
  /// In fa, this message translates to:
  /// **'عدم دسترسی به وب‌سایت ChatGPT. لطفاً اتصال اینترنت خود را بررسی کنید.'**
  String get bridgeNetworkError;

  /// No description provided for @bridgeNetworkErrorAction.
  ///
  /// In fa, this message translates to:
  /// **'بررسی اتصال اینترنت'**
  String get bridgeNetworkErrorAction;

  /// No description provided for @bridgeComposerNotFound.
  ///
  /// In fa, this message translates to:
  /// **'فیلد ورودی متن ChatGPT هنوز آماده یا در دسترس نیست.'**
  String get bridgeComposerNotFound;

  /// No description provided for @bridgeComposerNotFoundAction.
  ///
  /// In fa, this message translates to:
  /// **'بازنشانی گفتگو'**
  String get bridgeComposerNotFoundAction;

  /// No description provided for @bridgeNavigationLoop.
  ///
  /// In fa, this message translates to:
  /// **'صفحه چت مکرراً بازنشانی شد و امکان ادامه گفتگو وجود ندارد.'**
  String get bridgeNavigationLoop;

  /// No description provided for @bridgeNavigationLoopAction.
  ///
  /// In fa, this message translates to:
  /// **'بارگذاری مجدد مرورگر'**
  String get bridgeNavigationLoopAction;

  /// No description provided for @bridgeUnknownError.
  ///
  /// In fa, this message translates to:
  /// **'خطای ناشناخته در پل وب ChatGPT.'**
  String get bridgeUnknownError;

  /// No description provided for @bridgeUnknownErrorAction.
  ///
  /// In fa, this message translates to:
  /// **'تلاش مجدد'**
  String get bridgeUnknownErrorAction;

  /// No description provided for @bridgeDiagnosticsTitle.
  ///
  /// In fa, this message translates to:
  /// **'تشخیص پل هوش مصنوعی وب'**
  String get bridgeDiagnosticsTitle;

  /// No description provided for @bridgeDiagnosticsSubtitle.
  ///
  /// In fa, this message translates to:
  /// **'وضعیت اتصال، گزارش ردیاب و بازیابی دستی پاسخ'**
  String get bridgeDiagnosticsSubtitle;

  /// No description provided for @bridgeDiagnosticsSearchKeywords.
  ///
  /// In fa, this message translates to:
  /// **'دستیار هوشمند، پل وب، چت جی پی تی، عیب یابی، تشخیص، لاگ، پاسخ نمی‌آید'**
  String get bridgeDiagnosticsSearchKeywords;

  /// No description provided for @bridgeHarvestAction.
  ///
  /// In fa, this message translates to:
  /// **'بازیابی پاسخ از مرورگر'**
  String get bridgeHarvestAction;

  /// No description provided for @bridgeForceRebootAction.
  ///
  /// In fa, this message translates to:
  /// **'راه‌اندازی مجدد اجباری'**
  String get bridgeForceRebootAction;

  /// No description provided for @bridgeCopyLogAction.
  ///
  /// In fa, this message translates to:
  /// **'کپی گزارش'**
  String get bridgeCopyLogAction;

  /// No description provided for @bridgeLiveBrowser.
  ///
  /// In fa, this message translates to:
  /// **'مشاهدهٔ پنجرهٔ چت‌جی‌پی‌تی'**
  String get bridgeLiveBrowser;

  /// No description provided for @bridgePartialAnswerWarning.
  ///
  /// In fa, this message translates to:
  /// **'⚠️ این پاسخ کامل دریافت نشد. ارتباط با مرورگر پیش از پایان پاسخ قطع شد.'**
  String get bridgePartialAnswerWarning;

  /// No description provided for @bridgeChipLongPressHint.
  ///
  /// In fa, this message translates to:
  /// **'برای مشاهدهٔ جزئیات عیب‌یابی، نگه دارید'**
  String get bridgeChipLongPressHint;

  /// No description provided for @bridgeWhyAction.
  ///
  /// In fa, this message translates to:
  /// **'چرا؟'**
  String get bridgeWhyAction;

  /// No description provided for @cyclePregnancyBannerTitle.
  ///
  /// In fa, this message translates to:
  /// **'حالت بارداری فعال است'**
  String get cyclePregnancyBannerTitle;

  /// No description provided for @cyclePregnancyBannerDesc.
  ///
  /// In fa, this message translates to:
  /// **'پیش‌بینی دوره‌ها و پنجره‌های باروری در این حالت متوقف شده است.'**
  String get cyclePregnancyBannerDesc;

  /// No description provided for @cycleNoPeriodsBannerTitle.
  ///
  /// In fa, this message translates to:
  /// **'هنوز دوره‌ای ثبت نشده است'**
  String get cycleNoPeriodsBannerTitle;

  /// No description provided for @cycleNoPeriodsBannerDesc.
  ///
  /// In fa, this message translates to:
  /// **'برای دریافت پیش‌بینی‌های دقیق و شناسایی الگوهای بدنی، اولین دوره خود را ثبت کنید.'**
  String get cycleNoPeriodsBannerDesc;

  /// No description provided for @cycleRecordFirstPeriod.
  ///
  /// In fa, this message translates to:
  /// **'ثبت اولین دوره'**
  String get cycleRecordFirstPeriod;

  /// No description provided for @cycleEarlyDataBannerTitle.
  ///
  /// In fa, this message translates to:
  /// **'پیش‌بینی با داده‌های اولیه'**
  String get cycleEarlyDataBannerTitle;

  /// No description provided for @cycleEarlyDataBannerDesc.
  ///
  /// In fa, this message translates to:
  /// **'پیش‌بینی فعلی بر اساس تنظیمات اولیه است. با ثبت حداقل ۳ چرخه، الگوی شخصی شما فعال می‌شود.'**
  String get cycleEarlyDataBannerDesc;

  /// No description provided for @cycleBeyondHorizonBannerTitle.
  ///
  /// In fa, this message translates to:
  /// **'فراتر از افق پیش‌بینی'**
  String get cycleBeyondHorizonBannerTitle;

  /// No description provided for @cycleBeyondHorizonBannerDesc.
  ///
  /// In fa, this message translates to:
  /// **'پیش‌بینی چرخه‌ها تا حداکثر ۲۴ ماه آینده بر اساس ثبات چرخه‌های قبلی محاسبه می‌شود.'**
  String get cycleBeyondHorizonBannerDesc;

  /// No description provided for @cycleSemanticsToday.
  ///
  /// In fa, this message translates to:
  /// **'، امروز'**
  String get cycleSemanticsToday;

  /// No description provided for @cycleSemanticsRecordedPeriod.
  ///
  /// In fa, this message translates to:
  /// **'، قاعدگی ثبت شده'**
  String get cycleSemanticsRecordedPeriod;

  /// No description provided for @cycleSemanticsPredictedPeriod.
  ///
  /// In fa, this message translates to:
  /// **'، پیش‌بینی قاعدگی'**
  String get cycleSemanticsPredictedPeriod;

  /// No description provided for @cycleSemanticsLowConfidence.
  ///
  /// In fa, this message translates to:
  /// **' با اطمینان کم'**
  String get cycleSemanticsLowConfidence;

  /// No description provided for @cycleSemanticsHighConfidence.
  ///
  /// In fa, this message translates to:
  /// **' با اطمینان بالا'**
  String get cycleSemanticsHighConfidence;

  /// No description provided for @cycleSemanticsPredictionWindow.
  ///
  /// In fa, this message translates to:
  /// **'، بازه احتمالی جابجایی قاعدگی'**
  String get cycleSemanticsPredictionWindow;

  /// No description provided for @cycleSemanticsOvulation.
  ///
  /// In fa, this message translates to:
  /// **'، روز تخمک‌گذاری'**
  String get cycleSemanticsOvulation;

  /// No description provided for @cycleSemanticsFertileWindow.
  ///
  /// In fa, this message translates to:
  /// **'، پنجره باروری'**
  String get cycleSemanticsFertileWindow;

  /// No description provided for @cycleSemanticsPms.
  ///
  /// In fa, this message translates to:
  /// **'، روزهای پیش از عادت'**
  String get cycleSemanticsPms;

  /// No description provided for @cycleSemanticsHasLogs.
  ///
  /// In fa, this message translates to:
  /// **'، دارای علائم ثبت‌شده'**
  String get cycleSemanticsHasLogs;

  /// No description provided for @mv_kind_picker_title.
  ///
  /// In fa, this message translates to:
  /// **'انتخاب نوع ورزش'**
  String get mv_kind_picker_title;

  /// No description provided for @mv_kind_picker_search_hint.
  ///
  /// In fa, this message translates to:
  /// **'جستجوی ورزش...'**
  String get mv_kind_picker_search_hint;

  /// No description provided for @mv_kind_picker_recent.
  ///
  /// In fa, this message translates to:
  /// **'ورزش‌های اخیر'**
  String get mv_kind_picker_recent;

  /// No description provided for @mv_kind_picker_seasonal.
  ///
  /// In fa, this message translates to:
  /// **'ورزش‌های فصلی / پیشنهادی'**
  String get mv_kind_picker_seasonal;

  /// No description provided for @mv_kind_picker_all.
  ///
  /// In fa, this message translates to:
  /// **'همهٔ ورزش‌ها'**
  String get mv_kind_picker_all;

  /// No description provided for @mv_kind_picker_create_custom.
  ///
  /// In fa, this message translates to:
  /// **'ورزش جدید دلخواه'**
  String get mv_kind_picker_create_custom;

  /// No description provided for @mv_kind_picker_empty.
  ///
  /// In fa, this message translates to:
  /// **'ورزشی با این عنوان یافت نشد.'**
  String get mv_kind_picker_empty;

  /// No description provided for @mv_custom_kind_title.
  ///
  /// In fa, this message translates to:
  /// **'ساخت نوع ورزش سفارشی'**
  String get mv_custom_kind_title;

  /// No description provided for @mv_custom_kind_name.
  ///
  /// In fa, this message translates to:
  /// **'نام ورزش'**
  String get mv_custom_kind_name;

  /// No description provided for @mv_custom_kind_family.
  ///
  /// In fa, this message translates to:
  /// **'دسته‌بندی اصلی'**
  String get mv_custom_kind_family;

  /// No description provided for @mv_custom_kind_metric.
  ///
  /// In fa, this message translates to:
  /// **'متریک اصلی اندازه‌گیری'**
  String get mv_custom_kind_metric;

  /// No description provided for @mv_custom_kind_intensity.
  ///
  /// In fa, this message translates to:
  /// **'شدت پیش‌فرض (MET)'**
  String get mv_custom_kind_intensity;

  /// No description provided for @mv_custom_kind_saved.
  ///
  /// In fa, this message translates to:
  /// **'ورزش سفارشی با موفقیت ذخیره شد.'**
  String get mv_custom_kind_saved;

  /// No description provided for @mv_onboarding_anchor_title.
  ///
  /// In fa, this message translates to:
  /// **'ورزش‌های ثابت هفتگی (لنگر)'**
  String get mv_onboarding_anchor_title;

  /// No description provided for @mv_onboarding_anchor_add.
  ///
  /// In fa, this message translates to:
  /// **'افزودن زمان ثابت'**
  String get mv_onboarding_anchor_add;

  /// No description provided for @mv_onboarding_anchor_skip.
  ///
  /// In fa, this message translates to:
  /// **'بعداً اضافه می‌کنم'**
  String get mv_onboarding_anchor_skip;

  /// No description provided for @mv_commitment_saved.
  ///
  /// In fa, this message translates to:
  /// **'تعهد ثابت ثبت شد'**
  String get mv_commitment_saved;

  /// No description provided for @mv_commitment_repeat_weekly.
  ///
  /// In fa, this message translates to:
  /// **'تکرار هفتگی'**
  String get mv_commitment_repeat_weekly;

  /// No description provided for @mv_commitment_venue.
  ///
  /// In fa, this message translates to:
  /// **'محل یا سالن تمرین'**
  String get mv_commitment_venue;

  /// No description provided for @mv_commitment_partner.
  ///
  /// In fa, this message translates to:
  /// **'هم‌تمرینی / تیم'**
  String get mv_commitment_partner;

  /// No description provided for @mv_anchor_cancelled_this_week.
  ///
  /// In fa, this message translates to:
  /// **'این هفته لغو شد'**
  String get mv_anchor_cancelled_this_week;

  /// No description provided for @mv_anchor_suggest_deactivate.
  ///
  /// In fa, this message translates to:
  /// **'آیا می‌خواهید این تعهد به طور کامل غیرفعال شود؟'**
  String get mv_anchor_suggest_deactivate;

  /// No description provided for @mv_anchor_constraint_note.
  ///
  /// In fa, this message translates to:
  /// **'تمرین ثابت لنگر با توجه به محدودیت ثبت‌شده'**
  String get mv_anchor_constraint_note;

  /// No description provided for @mv_tomorrow_anchor_notice.
  ///
  /// In fa, this message translates to:
  /// **'یادآوری: فردا جلسهٔ ثابت لنگر دارید'**
  String get mv_tomorrow_anchor_notice;

  /// No description provided for @mv_conflict_back_to_back.
  ///
  /// In fa, this message translates to:
  /// **'هشدار: دو جلسهٔ سنگین متوالی برنامه‌ریزی شده است'**
  String get mv_conflict_back_to_back;

  /// No description provided for @mv_reason_anchor.
  ///
  /// In fa, this message translates to:
  /// **'جلسهٔ ثابت لنگر برنامه‌ریزی شده شما'**
  String get mv_reason_anchor;

  /// No description provided for @mv_reason_pre_anchor_taper.
  ///
  /// In fa, this message translates to:
  /// **'کاهش حجم تمرینی جهت حفظ توان برای جلسهٔ لنگر فردا'**
  String get mv_reason_pre_anchor_taper;

  /// No description provided for @mv_reason_post_anchor_recovery.
  ///
  /// In fa, this message translates to:
  /// **'ریکاوری و بازتوانی پس از جلسهٔ فشردهٔ لنگر دیروز'**
  String get mv_reason_post_anchor_recovery;

  /// No description provided for @mv_reason_complement.
  ///
  /// In fa, this message translates to:
  /// **'تمرین مکمل قدرتی جهت تعادل عضلانی و حمایت از ورزش اصلی'**
  String get mv_reason_complement;

  /// No description provided for @mv_reason_who_gap.
  ///
  /// In fa, this message translates to:
  /// **'جبران کسری فعالیت معادل متوسط جهت دستیابی به هدف ۱۵۰ دقیقه در هفته'**
  String get mv_reason_who_gap;

  /// No description provided for @mv_reason_strength_quota.
  ///
  /// In fa, this message translates to:
  /// **'تکمیل سهمیهٔ ۲ جلسه تمرین تقویتی عضلانی در هفته'**
  String get mv_reason_strength_quota;

  /// No description provided for @mv_reason_rest_guaranteed.
  ///
  /// In fa, this message translates to:
  /// **'روز استراحت ضروری جهت بازسازی فیزیولوژیک'**
  String get mv_reason_rest_guaranteed;

  /// No description provided for @mv_reason_readiness_low.
  ///
  /// In fa, this message translates to:
  /// **'تعدیل فشار تمرین به دلیل سطح آمادگی پایین امروز'**
  String get mv_reason_readiness_low;

  /// No description provided for @mv_reason_load_cap.
  ///
  /// In fa, this message translates to:
  /// **'کنترل سقف افزایش بار هفتگی برای پیشگیری از خستگی مفرط'**
  String get mv_reason_load_cap;

  /// No description provided for @mv_reason_fallback_minimum.
  ///
  /// In fa, this message translates to:
  /// **'حداقل فعالیت مؤثر ۱۰ دقیقه‌ای برای حفظ زنجیره'**
  String get mv_reason_fallback_minimum;

  /// No description provided for @mv_reason_season_fit.
  ///
  /// In fa, this message translates to:
  /// **'ورزش متناسب با فصل جاری'**
  String get mv_reason_season_fit;

  /// No description provided for @mv_reason_constraint_relaxed.
  ///
  /// In fa, this message translates to:
  /// **'تطبیق تمرین با شرایط و امکانات فعلی'**
  String get mv_reason_constraint_relaxed;

  /// No description provided for @mv_metric_distance.
  ///
  /// In fa, this message translates to:
  /// **'مسافت (کیلومتر)'**
  String get mv_metric_distance;

  /// No description provided for @mv_metric_elevation.
  ///
  /// In fa, this message translates to:
  /// **'ارتفاع (متر)'**
  String get mv_metric_elevation;

  /// No description provided for @mv_metric_laps.
  ///
  /// In fa, this message translates to:
  /// **'تعداد دور / طول'**
  String get mv_metric_laps;

  /// No description provided for @mv_metric_pack_weight.
  ///
  /// In fa, this message translates to:
  /// **'وزن کوله (کیلوگرم)'**
  String get mv_metric_pack_weight;

  /// No description provided for @mv_metric_duration.
  ///
  /// In fa, this message translates to:
  /// **'مدت زمان (دقیقه)'**
  String get mv_metric_duration;

  /// No description provided for @mv_effort_question.
  ///
  /// In fa, this message translates to:
  /// **'فشار این تمرین چطور بود؟'**
  String get mv_effort_question;

  /// No description provided for @mv_effort_easy.
  ///
  /// In fa, this message translates to:
  /// **'آسان'**
  String get mv_effort_easy;

  /// No description provided for @mv_effort_good.
  ///
  /// In fa, this message translates to:
  /// **'مناسب'**
  String get mv_effort_good;

  /// No description provided for @mv_effort_hard.
  ///
  /// In fa, this message translates to:
  /// **'سخت'**
  String get mv_effort_hard;

  /// No description provided for @mv_effort_refine.
  ///
  /// In fa, this message translates to:
  /// **'تنظیم دقیق با اسلایدر RPE'**
  String get mv_effort_refine;

  /// No description provided for @mv_new_personal_record.
  ///
  /// In fa, this message translates to:
  /// **'رکورد شخصی جدید! 🎉'**
  String get mv_new_personal_record;

  /// No description provided for @mv_load_band_low.
  ///
  /// In fa, this message translates to:
  /// **'بار سبک'**
  String get mv_load_band_low;

  /// No description provided for @mv_load_band_optimal.
  ///
  /// In fa, this message translates to:
  /// **'بار بهینه و سازنده'**
  String get mv_load_band_optimal;

  /// No description provided for @mv_load_band_watch.
  ///
  /// In fa, this message translates to:
  /// **'بار رو به افزایش'**
  String get mv_load_band_watch;

  /// No description provided for @mv_load_band_spike.
  ///
  /// In fa, this message translates to:
  /// **'جهش بار تمرینی (نیازمند احتیاط)'**
  String get mv_load_band_spike;

  /// No description provided for @mv_budget_moderate_minutes.
  ///
  /// In fa, this message translates to:
  /// **'دقیقه فعالیت معادل متوسط'**
  String get mv_budget_moderate_minutes;

  /// No description provided for @mv_budget_strength_days.
  ///
  /// In fa, this message translates to:
  /// **'روز تمرین قدرتی'**
  String get mv_budget_strength_days;

  /// No description provided for @mv_budget_remaining.
  ///
  /// In fa, this message translates to:
  /// **'باقیمانده تا هدف سلامت هفتگی'**
  String get mv_budget_remaining;

  /// No description provided for @mv_streak_insufficient.
  ///
  /// In fa, this message translates to:
  /// **'برای محاسبهٔ تداوم، حداقل ۲ هفته فعالیت لازم است'**
  String get mv_streak_insufficient;

  /// No description provided for @mv_readiness_no_checkin.
  ///
  /// In fa, this message translates to:
  /// **'سطح آمادگی امروز هنوز ثبت نشده است'**
  String get mv_readiness_no_checkin;

  /// No description provided for @mv_need_n_more_sessions.
  ///
  /// In fa, this message translates to:
  /// **'چند جلسهٔ دیگر برای ارزیابی دقیق مورد نیاز است'**
  String get mv_need_n_more_sessions;

  /// No description provided for @mv_insufficient_data_generic.
  ///
  /// In fa, this message translates to:
  /// **'دادهٔ کافی ثبت نشده است'**
  String get mv_insufficient_data_generic;

  /// No description provided for @mv_insight_best_day.
  ///
  /// In fa, this message translates to:
  /// **'روز طلایی تمرین'**
  String get mv_insight_best_day;

  /// No description provided for @mv_insight_anchor_adherence.
  ///
  /// In fa, this message translates to:
  /// **'پایبندی به لنگرها'**
  String get mv_insight_anchor_adherence;

  /// No description provided for @mv_insight_effort_drift.
  ///
  /// In fa, this message translates to:
  /// **'روند ادراک فشار'**
  String get mv_insight_effort_drift;

  /// No description provided for @mv_insight_kind_mix.
  ///
  /// In fa, this message translates to:
  /// **'تنوع ورزشی ماهانه'**
  String get mv_insight_kind_mix;

  /// No description provided for @mv_insight_route_progress.
  ///
  /// In fa, this message translates to:
  /// **'پیشرفت در مسیر تکراری'**
  String get mv_insight_route_progress;

  /// No description provided for @mv_campaign_title.
  ///
  /// In fa, this message translates to:
  /// **'دورهٔ هدف‌دار'**
  String get mv_campaign_title;

  /// No description provided for @mv_campaign_target_date.
  ///
  /// In fa, this message translates to:
  /// **'تاریخ رویداد هدف'**
  String get mv_campaign_target_date;

  /// No description provided for @mv_campaign_phase_base.
  ///
  /// In fa, this message translates to:
  /// **'مرحله پایه'**
  String get mv_campaign_phase_base;

  /// No description provided for @mv_campaign_phase_build.
  ///
  /// In fa, this message translates to:
  /// **'مرحله بارگذاری تدریجی'**
  String get mv_campaign_phase_build;

  /// No description provided for @mv_campaign_phase_taper.
  ///
  /// In fa, this message translates to:
  /// **'مرحله کاهش حجم و آماده‌سازی'**
  String get mv_campaign_phase_taper;

  /// No description provided for @mv_campaign_too_short.
  ///
  /// In fa, this message translates to:
  /// **'زمان باقیمانده تا رویداد کمتر از ۴ هفته است'**
  String get mv_campaign_too_short;

  /// No description provided for @mv_route_select.
  ///
  /// In fa, this message translates to:
  /// **'انتخاب مسیر'**
  String get mv_route_select;

  /// No description provided for @mv_route_new.
  ///
  /// In fa, this message translates to:
  /// **'ثبت مسیر جدید'**
  String get mv_route_new;

  /// No description provided for @mv_route_times_done.
  ///
  /// In fa, this message translates to:
  /// **'دفعات انجام: {count}'**
  String mv_route_times_done(int count);

  /// No description provided for @mv_route_best_time.
  ///
  /// In fa, this message translates to:
  /// **'بهترین زمان: {minutes} دقیقه'**
  String mv_route_best_time(int minutes);

  /// No description provided for @mv_day_plan_title.
  ///
  /// In fa, this message translates to:
  /// **'برنامهٔ روز'**
  String get mv_day_plan_title;

  /// No description provided for @mv_library_title.
  ///
  /// In fa, this message translates to:
  /// **'کتابخانهٔ حرکات و ورزش‌ها'**
  String get mv_library_title;

  /// No description provided for @mv_week_plan_title.
  ///
  /// In fa, this message translates to:
  /// **'برنامهٔ هفته'**
  String get mv_week_plan_title;

  /// No description provided for @mv_library_tab_kinds.
  ///
  /// In fa, this message translates to:
  /// **'ورزش‌ها'**
  String get mv_library_tab_kinds;

  /// No description provided for @mv_library_tab_exercises.
  ///
  /// In fa, this message translates to:
  /// **'حرکات'**
  String get mv_library_tab_exercises;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fa'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fa':
      return AppLocalizationsFa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
