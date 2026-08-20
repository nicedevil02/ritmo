import 'package:ritmo/core/ai/brief/domain_brief.dart';
import 'package:ritmo/core/ai/brief/briefs/sleep_brief.dart';
import 'package:ritmo/core/ai/brief/briefs/goals_brief.dart';
import 'package:ritmo/core/ai/brief/briefs/worship_brief.dart';
import 'package:ritmo/core/ai/brief/briefs/wellbeing_brief.dart';

/// Single-source definition of a Persona Skill.
class PersonaSkillDef {
  const PersonaSkillDef({
    required this.id,
    required this.personaId,
    required this.labelFa,
    required this.queryPrompt,
    this.priority = 0,
    this.requiredCommandIds = const {},
    this.requiredBriefFields = const {},
    this.isRelevant,
  });

  /// Stable skill ID matching the identifier in the assistant's charter.
  final String id;

  /// Owner persona ID.
  final String personaId;

  /// Farsi label for UI chips.
  final String labelFa;

  /// Query prompt sent to the model when the user taps this skill chip.
  final String queryPrompt;

  /// Priority score (higher values appear first in UI).
  final int priority;

  /// Command IDs required for execution (empty set for pure analysis skills).
  final Set<String> requiredCommandIds;

  /// Brief field paths required for this skill to be meaningful.
  final Set<String> requiredBriefFields;

  /// Optional relevancy checker given a DomainBrief. If null, considered always relevant.
  final bool Function(DomainBrief? brief)? isRelevant;
}

/// Single-source registry of all Persona skills across Ritmo.
class PersonaSkillRegistry {
  PersonaSkillRegistry._();

  /// Master list of all registered skill definitions across all 13 personas.
  static const List<PersonaSkillDef> all = [
    // ──────────────────────────────────────────────────────────── general ──
    PersonaSkillDef(
      id: 'general_chat',
      personaId: 'general',
      labelFa: 'گفتگوی آزاد',
      queryPrompt: 'می‌خواهم درباره یک موضوع صحبت کنیم.',
      priority: 10,
    ),
    PersonaSkillDef(
      id: 'brainstorm',
      personaId: 'general',
      labelFa: 'ایده‌پردازی و هم‌فکری',
      queryPrompt: 'برای این موضوع چند ایده جدید می‌خواهم.',
      priority: 8,
    ),
    PersonaSkillDef(
      id: 'writing_assistant',
      personaId: 'general',
      labelFa: 'نگارش و ویرایش متن',
      queryPrompt: 'این متن را برای من بازنویسی و بهتر کن.',
      priority: 6,
    ),

    // ───────────────────────────────────────────────────────────── global ──
    PersonaSkillDef(
      id: 'daily_briefing',
      personaId: 'global',
      labelFa: 'خلاصه وضعیت امروز',
      queryPrompt: 'خلاصه وضعیت امروز من را بگویید.',
      priority: 10,
    ),
    PersonaSkillDef(
      id: 'next_best_action',
      personaId: 'global',
      labelFa: 'اقدام بعدی پیشنهادی',
      queryPrompt: 'مهم‌ترین اقدام بعدی من چیست؟',
      priority: 8,
    ),
    PersonaSkillDef(
      id: 'conflict_resolve',
      personaId: 'global',
      labelFa: 'حل تعارض زمانی',
      queryPrompt: 'بین کارهای هم‌زمان چطور اولویت‌بندی کنم؟',
      priority: 6,
    ),
    PersonaSkillDef(
      id: 'route',
      personaId: 'global',
      labelFa: 'ارجاع به متخصص',
      queryPrompt: 'این درخواست به کدام بخش ریتمو مربوط می‌شود؟',
      priority: 4,
      requiredCommandIds: {'assistant.handoff'},
    ),

    // ────────────────────────────────────────────────────────────── sleep ──
    PersonaSkillDef(
      id: 'consistency_coach',
      personaId: 'sleep',
      labelFa: 'تثبیت ساعت بیداری',
      queryPrompt: 'چطور ساعت بیداری خودم را تثبیت کنم؟',
      priority: 10,
      isRelevant: _sleepConsistencyRelevant,
    ),
    PersonaSkillDef(
      id: 'debt_report',
      personaId: 'sleep',
      labelFa: 'گزارش کسری خواب',
      queryPrompt: 'وضعیت کسری خواب من در شب‌های اخیر چطور است؟',
      priority: 8,
      requiredBriefFields: {'sleep.sleepDebtMinutes'},
      isRelevant: _sleepDebtRelevant,
    ),
    PersonaSkillDef(
      id: 'recovery_plan',
      personaId: 'sleep',
      labelFa: 'برنامه ریکاوری پس از بی‌خوابی',
      queryPrompt: 'برنامه ریکاوری ۴۸ ساعته برای جبران شب‌بیداری چیست؟',
      priority: 7,
    ),
    PersonaSkillDef(
      id: 'early_wake_prep',
      personaId: 'sleep',
      labelFa: 'آمادگی سحرخیزی',
      queryPrompt: 'چطور ساعت بیداری را به صورت پلکانی جلو بکشم؟',
      priority: 6,
    ),
    PersonaSkillDef(
      id: 'golden_window',
      personaId: 'sleep',
      labelFa: 'پنجره طلایی خواب',
      queryPrompt: 'پنجره طلایی مناسب‌ترین زمان خواب من چیست؟',
      priority: 5,
    ),

    // ────────────────────────────────────────────────────────── wellbeing ──
    PersonaSkillDef(
      id: 'balance_snapshot',
      personaId: 'wellbeing',
      labelFa: 'نمای تعادل زندگی',
      queryPrompt: 'وضعیت تعادل ابعاد مختلف زندگی من چطور است؟',
      priority: 10,
    ),
    PersonaSkillDef(
      id: 'smallest_step',
      personaId: 'wellbeing',
      labelFa: 'کوچک‌ترین اقدام امروز',
      queryPrompt: 'کوچک‌ترین قدم عملی ۱۰ دقیقه‌ای برای بهبود حالم چیست؟',
      priority: 9,
    ),
    PersonaSkillDef(
      id: 'weakest_signal',
      personaId: 'wellbeing',
      labelFa: 'شناسایی ضعیف‌ترین سیگنال',
      queryPrompt: 'کدام سیگنال در حال حاضر بیشترین نیاز به توجه را دارد؟',
      priority: 8,
    ),
    PersonaSkillDef(
      id: 'burnout_watch',
      personaId: 'wellbeing',
      labelFa: 'پایش فرسودگی و خستگی',
      queryPrompt: 'آیا الگوی افت مداوم انرژی و فرسودگی دیده می‌شود؟',
      priority: 7,
    ),
    PersonaSkillDef(
      id: 'energy_audit',
      personaId: 'wellbeing',
      labelFa: 'تحلیل سطح انرژی',
      queryPrompt: 'سطح انرژی من در طول روزهای اخیر چگونه بوده؟',
      priority: 6,
    ),
    PersonaSkillDef(
      id: 'stress_check',
      personaId: 'wellbeing',
      labelFa: 'کاهش استرس و تعادل',
      queryPrompt: 'راهکارهای کاهش استرس برای امروز چیست؟',
      priority: 5,
      isRelevant: _wellbeingStressRelevant,
    ),

    // ───────────────────────────────────────────────────────── reflection ──
    PersonaSkillDef(
      id: 'dynamic_prompt',
      personaId: 'reflection',
      labelFa: 'پرسش تأملی روز',
      queryPrompt: 'امروز چه سؤالاتی برای ثبت بازتاب از خودم بپرسم؟',
      priority: 10,
    ),
    PersonaSkillDef(
      id: 'hidden_wins',
      personaId: 'reflection',
      labelFa: 'دستاوردهای پنهان هفته',
      queryPrompt: 'چه‌ بردهایی در این هفته داشته‌ام که ندیده‌ام؟',
      priority: 8,
    ),
    PersonaSkillDef(
      id: 'pattern_mirror',
      personaId: 'reflection',
      labelFa: 'آینه الگوهای فکری',
      queryPrompt: 'چه الگوها یا مفاهیم تکرارشونده‌ای در یادداشت‌هایم وجود دارد؟',
      priority: 7,
      requiredCommandIds: {'assistant.handoff', 'app.openPage'},
    ),
    PersonaSkillDef(
      id: 'close_loop',
      personaId: 'reflection',
      labelFa: 'تبدیل یادگیری به اقدام',
      queryPrompt: 'چطور این یادگیری را به یک اقدام عملی متصل کنم؟',
      priority: 6,
      requiredCommandIds: {'assistant.handoff', 'app.openPage'},
    ),

    // ────────────────────────────────────────────────────────────── goals ──
    PersonaSkillDef(
      id: 'smart_refine',
      personaId: 'goals',
      labelFa: 'تدقیق هوشمند هدف',
      queryPrompt: 'چطور هدفم را شفاف، کمی و قابل‌اندازه‌گیری کنم؟',
      priority: 10,
    ),
    PersonaSkillDef(
      id: 'decompose',
      personaId: 'goals',
      labelFa: 'خرد کردن هدف به گام‌ها',
      queryPrompt: 'چطور هدف اصلی من به گام‌های کوچک‌تر خرد شود؟',
      priority: 9,
      requiredCommandIds: {'goal.create', 'goal.edit'},
      isRelevant: _goalsActiveRelevant,
    ),
    PersonaSkillDef(
      id: 'premortem',
      personaId: 'goals',
      labelFa: 'پیش‌مرگ و پیش‌بینی ریسک',
      queryPrompt: 'چه موانع و ریسک‌هایی ممکن است مانع این هدف شوند؟',
      priority: 8,
    ),
    PersonaSkillDef(
      id: 'revive_or_retire',
      personaId: 'goals',
      labelFa: 'احیا یا بایگانی هدف معوق',
      queryPrompt: 'با اهدافی که مدت‌ها دست‌نخورده مانده‌اند چه کنم؟',
      priority: 7,
    ),
    PersonaSkillDef(
      id: 'capacity_fit',
      personaId: 'goals',
      labelFa: 'تطبیق بار با ظرفیت روزانه',
      queryPrompt: 'آیا مجموع گام‌های انتخابی در ظرفیت زمانی امروزم می‌گنجد؟',
      priority: 6,
    ),
    PersonaSkillDef(
      id: 'overdue_cleanup',
      personaId: 'goals',
      labelFa: 'مدیریت گام‌های معوق',
      queryPrompt: 'گام‌های معوق من را چطور سامان‌دهی کنم؟',
      priority: 5,
      isRelevant: _goalsOverdueRelevant,
    ),

    // ────────────────────────────────────────────────────────────── konkur ──
    PersonaSkillDef(
      id: 'priority_matrix',
      personaId: 'konkur',
      labelFa: 'ماتریس اولویت دروس',
      queryPrompt: 'کدام درس در حال حاضر بیشترین اولویت مطالعه را دارد؟',
      priority: 10,
    ),
    PersonaSkillDef(
      id: 'review_schedule',
      personaId: 'konkur',
      labelFa: 'زمان‌بندی مرور فاصله‌دار',
      queryPrompt: 'برنامه مرور منحنی یادگیری من برای روزهای آینده چیست؟',
      priority: 9,
    ),
    PersonaSkillDef(
      id: 'mock_analysis',
      personaId: 'konkur',
      labelFa: 'تحلیل آزمون آزمایشی',
      queryPrompt: 'نقاط ضعف من در آزمون‌های اخیر چیست؟',
      priority: 8,
    ),
    PersonaSkillDef(
      id: 'weekly_plan',
      personaId: 'konkur',
      labelFa: 'طرح مطالعاتی هفتگی',
      queryPrompt: 'یک طرح مطالعاتی برای هفته آینده تنظیم کن.',
      priority: 7,
      requiredCommandIds: {'assistant.handoff', 'app.openPage'},
    ),
    PersonaSkillDef(
      id: 'budget_reality_check',
      personaId: 'konkur',
      labelFa: 'سنجش واقع‌بینانه بودجه روزانه',
      queryPrompt: 'آیا زمان مطالعه درخواستی با میانگین واقعی من همخوانی دارد؟',
      priority: 6,
    ),

    // ──────────────────────────────────────────────────────────── courses ──
    PersonaSkillDef(
      id: 'pace_reality',
      personaId: 'courses',
      labelFa: 'سنجش سرعت واقعی دوره',
      queryPrompt: 'ریتم واقعی گذراندن دوره‌ها در مقایسه با هدف چقدر است؟',
      priority: 10,
    ),
    PersonaSkillDef(
      id: 'eta_forecast',
      personaId: 'courses',
      labelFa: 'تخمین زمان پایان دوره',
      queryPrompt: 'با ریتم فعلی، دوره‌ها کی تمام می‌شوند؟',
      priority: 9,
    ),
    PersonaSkillDef(
      id: 'abandoned_triage',
      personaId: 'courses',
      labelFa: 'ساماندهی دوره‌های متوقف',
      queryPrompt: 'با دوره‌هایی که بیش از ۲۱ روز پیشرفتی نداشته‌اند چه کنم؟',
      priority: 8,
    ),
    PersonaSkillDef(
      id: 'resplit',
      personaId: 'courses',
      labelFa: 'بازتوزیع جلسات هفته',
      queryPrompt: 'جلسات باقی‌مانده دوره را روی روزهای هفته توزیع کن.',
      priority: 7,
    ),
    PersonaSkillDef(
      id: 'load_balance',
      personaId: 'courses',
      labelFa: 'تعادل بار چند دوره',
      queryPrompt: 'مجموع بار هفتگی دوره‌های فعال من چقدر است؟',
      priority: 6,
    ),

    // ───────────────────────────────────────────────────────────── sports ──
    PersonaSkillDef(
      id: 'session_adapt',
      personaId: 'sports',
      labelFa: 'تطبیق شدت جلسه تمرین',
      queryPrompt: 'با توجه به خواب و انرژی، شدت تمرین امروز را چطور تنظیم کنم؟',
      priority: 10,
    ),
    PersonaSkillDef(
      id: 'swap_exercise',
      personaId: 'sports',
      labelFa: 'جایگزینی هوشمند حرکت',
      queryPrompt: 'چه حرکتی با همین گروه عضلانی و تجهیزات موجود جایگزین کنم؟',
      priority: 9,
    ),
    PersonaSkillDef(
      id: 'deload_check',
      personaId: 'sports',
      labelFa: 'بررسی نیاز به دیلود و ریکاوری',
      queryPrompt: 'آیا زمان استراحت و هفته دیلود فرا رسیده است؟',
      priority: 8,
    ),
    PersonaSkillDef(
      id: 'progressive_plan',
      personaId: 'sports',
      labelFa: 'طرح اضافه‌بار تدریجی',
      queryPrompt: 'چطور بار تمرینی را بدون آسیب ۱۰ درصد افزایش دهم؟',
      priority: 7,
    ),
    PersonaSkillDef(
      id: 'quiet_mode',
      personaId: 'sports',
      labelFa: 'نسخه تمرین آپارتمانی و بی‌صدا',
      queryPrompt: 'یک نسخه تمرین بی‌صدا و بدون پرش مناسب منزل بده.',
      priority: 6,
    ),
    PersonaSkillDef(
      id: 'recovery_check',
      personaId: 'sports',
      labelFa: 'بررسی وضعیت ریکاوری',
      queryPrompt: 'آیا بدن من برای تمرین امروز آماده است؟',
      priority: 5,
    ),

    // ──────────────────────────────────────────────────────────── worship ──
    PersonaSkillDef(
      id: 'debt_plan',
      personaId: 'worship',
      labelFa: 'برنامه ادای قضای عبادات',
      queryPrompt: 'یک برنامه تدریجی و منظم برای ادای عبادات قضا بدهید.',
      priority: 10,
      requiredBriefFields: {'worship.totalDebtsCount'},
      isRelevant: _worshipDebtsRelevant,
    ),
    PersonaSkillDef(
      id: 'chain_to_prayer',
      personaId: 'worship',
      labelFa: 'زنجیره‌سازی به وقت نماز',
      queryPrompt: 'چطور روتین‌هایم را به اوقات نماز زنجیره کنم؟',
      priority: 9,
      requiredCommandIds: {'worship.create', 'worship.delete'},
    ),
    PersonaSkillDef(
      id: 'occasion_hook',
      personaId: 'worship',
      labelFa: 'شروع با مناسبت‌های معنوی',
      queryPrompt: 'چه اعمال یا برنامه‌ای متناسب با مناسبت جاری وجود دارد؟',
      priority: 8,
      requiredCommandIds: {'worship.create'},
    ),
    PersonaSkillDef(
      id: 'gentle_restart',
      personaId: 'worship',
      labelFa: 'شروع آرام پس از وقفه',
      queryPrompt: 'چطور بعد از چند روز وقفه، دوباره روتین معنوی را از سر بگیرم؟',
      priority: 7,
    ),
    PersonaSkillDef(
      id: 'daily_dhikr',
      personaId: 'worship',
      labelFa: 'طراحی روتین ذکر روزانه',
      queryPrompt: 'یک روتین ذکر کوتاه و مستمر روزانه پیشنهاد بده.',
      priority: 6,
      requiredCommandIds: {'worship.create'},
    ),
    PersonaSkillDef(
      id: 'habit_streak',
      personaId: 'worship',
      labelFa: 'تثبیت استمرار عبادی',
      queryPrompt: 'چطور استمرار روتین عبادی روزانه را حفظ کنم؟',
      priority: 5,
    ),

    // ────────────────────────────────────────────────────────────── cycle ──
    PersonaSkillDef(
      id: 'comfort_tips',
      personaId: 'cycle',
      labelFa: 'توصیه‌های بهداشت و راحتی',
      queryPrompt: 'برای کاهش ناراحتی و علائم امروز چه نکات خودمراقبتی مناسب است؟',
      priority: 10,
    ),
    PersonaSkillDef(
      id: 'symptom_mirror',
      personaId: 'cycle',
      labelFa: 'انعکاس علائم ثبت‌شده',
      queryPrompt: 'چه علائمی در روزهای اخیر ثبت شده است؟',
      priority: 9,
    ),
    PersonaSkillDef(
      id: 'energy_bridge',
      personaId: 'cycle',
      labelFa: 'ارتباط علائم با سطح انرژی',
      queryPrompt: 'تغییرات انرژی در روزهای علامت‌دار چگونه بوده است؟',
      priority: 8,
    ),
    PersonaSkillDef(
      id: 'load_reduce',
      personaId: 'cycle',
      labelFa: 'کاهش بار روتین‌ها در روزهای علامت‌دار',
      queryPrompt: 'چطور روتین‌های سنگین را برای امروز سبک‌تر کنم؟',
      priority: 7,
      requiredCommandIds: {'assistant.handoff', 'app.openPage'},
    ),
    PersonaSkillDef(
      id: 'symptom_logger',
      personaId: 'cycle',
      labelFa: 'ثبت علائم روزانه',
      queryPrompt: 'چه علائمی را امروز باید ثبت کنم؟',
      priority: 6,
    ),

    // ───────────────────────────────────────────────────────────── health ──
    PersonaSkillDef(
      id: 'adherence_report',
      personaId: 'health',
      labelFa: 'گزارش نرخ پایبندی',
      queryPrompt: 'نرخ پایبندی من به ثبت یادآورها در روزهای اخیر چقدر بوده است؟',
      priority: 10,
    ),
    PersonaSkillDef(
      id: 'miss_pattern',
      personaId: 'health',
      labelFa: 'الگوی فراموشی زمانی',
      queryPrompt: 'آیا الگوی زمانی خاصی در فراموشی یادآورها دیده می‌شود؟',
      priority: 9,
    ),
    PersonaSkillDef(
      id: 'test_reminder',
      personaId: 'health',
      labelFa: 'یادآوری آزمایش‌های دوره‌ای',
      queryPrompt: 'آزمایش‌های دوره‌ای ثبت‌شده من در چه تاریخی هستند؟',
      priority: 8,
    ),
    PersonaSkillDef(
      id: 'log_vitals',
      personaId: 'health',
      labelFa: 'روند ثبت علائم حیاتی',
      queryPrompt: 'روند تغییرات عددی علائم حیاتی ثبت‌شده چطور بوده است؟',
      priority: 7,
    ),
    PersonaSkillDef(
      id: 'reminder_redesign',
      personaId: 'health',
      labelFa: 'بازطراحی ساختار یادآورها',
      queryPrompt: 'چطور زمان‌بندی یادآورها را متناسب با برنامه روزانه اصلاح کنم؟',
      priority: 6,
      requiredCommandIds: {'setting.update'},
    ),

    // ────────────────────────────────────────────────────────────── notes ──
    PersonaSkillDef(
      id: 'recall',
      personaId: 'notes',
      labelFa: 'بازیابی دقیق یادداشت‌ها',
      queryPrompt: 'یادداشت‌های مرتبط با این موضوع را با تاریخ برایم پیدا کن.',
      priority: 10,
    ),
    PersonaSkillDef(
      id: 'connect',
      personaId: 'notes',
      labelFa: 'ارتباط‌دهی یادداشت‌های مکمل',
      queryPrompt: 'کدام یادداشت‌ها و ایده‌های من به یکدیگر متصل هستند؟',
      priority: 9,
    ),
    PersonaSkillDef(
      id: 'distill',
      personaId: 'notes',
      labelFa: 'استخراج عصاره و درس تجربه',
      queryPrompt: 'عصاره و درس اصلی این یادداشت را در یک جمله بنویس.',
      priority: 8,
    ),
    PersonaSkillDef(
      id: 'extract_actions',
      personaId: 'notes',
      labelFa: 'استخراج اقدامات قابل‌اجرا',
      queryPrompt: 'از متن این یادداشت‌ها چه کارهای عملی می‌توان استخراج کرد؟',
      priority: 7,
      requiredCommandIds: {'note.extractActions'},
    ),
    PersonaSkillDef(
      id: 'weekly_digest',
      personaId: 'notes',
      labelFa: 'جمع‌بندی هفتگی یادداشت‌ها',
      queryPrompt: 'گزارش موضوعی یادداشت‌های نوشته‌شده در هفته اخیر چیست؟',
      priority: 6,
    ),
    PersonaSkillDef(
      id: 'resurface',
      personaId: 'notes',
      labelFa: 'بازخوانی یادداشت‌های ارزشمند',
      queryPrompt: 'یک یادداشت مهم از گذشته که امروز به کارم می‌آید نشان بده.',
      priority: 5,
    ),
    PersonaSkillDef(
      id: 'tidy',
      personaId: 'notes',
      labelFa: 'مرتب‌سازی و پیشنهاد تگ',
      queryPrompt: 'برای دسته‌بندی بهتر یادداشت‌ها چه تگ‌ها یا عناوینی پیشنهاد می‌کنی؟',
      priority: 4,
    ),
    PersonaSkillDef(
      id: 'experience_coach',
      personaId: 'notes',
      labelFa: 'تبدیل رویداد به تجربه ماندگار',
      queryPrompt: 'چطور این رویداد را به عنوان یک تجربه قابل اتکا ثبت کنم؟',
      priority: 3,
    ),
    PersonaSkillDef(
      id: 'search_notes',
      personaId: 'notes',
      labelFa: 'جست‌وجوی هوشمند یادداشت‌ها',
      queryPrompt: 'تجربه‌ها و یادداشت‌های مرتبط من را خلاصه‌سازی کن.',
      priority: 2,
    ),
  ];

  static bool _sleepConsistencyRelevant(DomainBrief? brief) {
    if (brief == null || brief.confidence == BriefConfidence.none) return true;
    if (brief is SleepBrief) {
      final score = brief.consistencyScore;
      if (score == null) return true;
      return score < 60;
    }
    return true;
  }

  static bool _sleepDebtRelevant(DomainBrief? brief) {
    if (brief == null || brief.confidence == BriefConfidence.none) return true;
    if (brief is SleepBrief) {
      return brief.sleepDebtMinutes > 60;
    }
    return true;
  }

  static bool _wellbeingStressRelevant(DomainBrief? brief) {
    if (brief == null || brief.confidence == BriefConfidence.none) return true;
    if (brief is WellbeingBrief) {
      final stress = brief.stressLevel;
      if (stress == null) return true;
      return stress > 0.5;
    }
    return true;
  }

  static bool _goalsActiveRelevant(DomainBrief? brief) {
    if (brief == null || brief.confidence == BriefConfidence.none) return true;
    if (brief is GoalsBrief) {
      return brief.activeGoalsCount > 0;
    }
    return true;
  }

  static bool _goalsOverdueRelevant(DomainBrief? brief) {
    if (brief == null || brief.confidence == BriefConfidence.none) return true;
    if (brief is GoalsBrief) {
      return brief.overdueStepsCount > 0;
    }
    return true;
  }

  static bool _worshipDebtsRelevant(DomainBrief? brief) {
    if (brief == null || brief.confidence == BriefConfidence.none) return true;
    if (brief is WorshipBrief) {
      return brief.totalDebtsCount > 0;
    }
    return true;
  }

  /// Returns all skills defined for the specified persona.
  static List<PersonaSkillDef> forPersona(String personaId) {
    return all.where((s) => s.personaId == personaId).toList();
  }

  /// Finds a skill definition by its unique ID.
  static PersonaSkillDef? byId(String id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }
}
