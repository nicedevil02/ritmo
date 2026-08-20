import 'package:ritmo/core/ai/brief/domain_brief.dart';
import 'package:ritmo/core/ai/brief/briefs/sleep_brief.dart';
import 'package:ritmo/core/ai/brief/briefs/goals_brief.dart';
import 'package:ritmo/core/ai/brief/briefs/worship_brief.dart';
import 'package:ritmo/core/ai/brief/briefs/wellbeing_brief.dart';

class PersonaSkill {
  const PersonaSkill({
    required this.id,
    required this.labelFa,
    required this.queryPrompt,
    required this.isRelevant,
    this.priority = 0,
  });

  final String id;
  final String labelFa;
  final String queryPrompt;
  final bool Function(DomainBrief? brief) isRelevant;
  final int priority;

  static Set<String> get catalogPersonaIds => _skillsCatalog.keys.toSet();

  static List<PersonaSkill> getSkillsForPersona(String personaId, DomainBrief? brief) {
    final allSkills = _skillsCatalog[personaId] ?? [];
    final relevant = allSkills.where((s) => s.isRelevant(brief)).toList();
    relevant.sort((a, b) => b.priority.compareTo(a.priority));
    return relevant.isNotEmpty ? relevant : allSkills.take(3).toList();
  }

  static final Map<String, List<PersonaSkill>> _skillsCatalog = {
    'sleep': [
      PersonaSkill(
        id: 'consistency_coach',
        labelFa: 'تثبیت ساعت بیداری',
        queryPrompt: 'چطور ساعت بیداری خودم را تثبیت کنم؟',
        isRelevant: (brief) {
          if (brief is SleepBrief) {
            return (brief.consistencyScore ?? 100) < 60;
          }
          return true;
        },
        priority: 10,
      ),
      PersonaSkill(
        id: 'golden_window',
        labelFa: 'پنجره طلایی خواب',
        queryPrompt: 'پنجره طلایی مناسب‌ترین زمان خواب من چیست؟',
        isRelevant: (brief) => true,
        priority: 5,
      ),
      PersonaSkill(
        id: 'debt_report',
        labelFa: 'گزارش کسری خواب',
        queryPrompt: 'وضعیت کسری خواب من در شب‌های اخیر چطور است؟',
        isRelevant: (brief) {
          if (brief is SleepBrief) {
            return brief.sleepDebtMinutes > 60;
          }
          return false;
        },
        priority: 8,
      ),
    ],
    'global': [
      PersonaSkill(
        id: 'daily_briefing',
        labelFa: 'خلاصه وضعیت امروز',
        queryPrompt: 'خلاصه وضعیت امروز من را بگویید.',
        isRelevant: (_) => true,
        priority: 10,
      ),
      PersonaSkill(
        id: 'next_best_action',
        labelFa: 'اقدام بعدی پیشنهادی',
        queryPrompt: 'مهم‌ترین اقدام بعدی من چیست؟',
        isRelevant: (_) => true,
        priority: 8,
      ),
    ],
    'wellbeing': [
      PersonaSkill(
        id: 'energy_audit',
        labelFa: 'تحلیل سطح انرژی',
        queryPrompt: 'سطح انرژی من در طول روزهای اخیر چگونه بوده؟',
        isRelevant: (_) => true,
        priority: 10,
      ),
      PersonaSkill(
        id: 'stress_check',
        labelFa: 'کاهش استرس و تعادل',
        queryPrompt: 'راهکارهای کاهش استرس برای امروز چیست؟',
        isRelevant: (brief) {
          if (brief is WellbeingBrief) {
            return (brief.stressLevel ?? 0) > 0.5;
          }
          return true;
        },
        priority: 9,
      ),
    ],
    'goals': [
      PersonaSkill(
        id: 'decompose_goal',
        labelFa: 'خرد کردن هدف',
        queryPrompt: 'چطور هدف اصلی من به گام‌های کوچک‌تر خرد شود؟',
        isRelevant: (brief) {
          if (brief is GoalsBrief) {
            return brief.activeGoalsCount > 0;
          }
          return true;
        },
        priority: 10,
      ),
      PersonaSkill(
        id: 'overdue_cleanup',
        labelFa: 'مدیریت گام‌های معوق',
        queryPrompt: 'گام‌های معوق من را چطور سامان‌دهی کنم؟',
        isRelevant: (brief) {
          if (brief is GoalsBrief) {
            return brief.overdueStepsCount > 0;
          }
          return false;
        },
        priority: 9,
      ),
    ],
    'konkur': [
      PersonaSkill(
        id: 'priority_matrix',
        labelFa: 'ماتریس اولویت دروس',
        queryPrompt: 'کدام درس در حال حاضر بیشترین اولویت مطالعه را دارد؟',
        isRelevant: (_) => true,
        priority: 10,
      ),
      PersonaSkill(
        id: 'mock_exam_analysis',
        labelFa: 'تحلیل آزمون آزمایشی',
        queryPrompt: 'نقاط ضعف من در آزمون‌های اخیر چیست؟',
        isRelevant: (_) => true,
        priority: 8,
      ),
    ],
    'courses': [
      PersonaSkill(
        id: 'eta_calculator',
        labelFa: 'محاسبه زمان پایان دوره',
        queryPrompt: 'با ریتم فعلی، دوره‌ها کی تمام می‌شوند؟',
        isRelevant: (_) => true,
        priority: 10,
      ),
      PersonaSkill(
        id: 'resplit_sessions',
        labelFa: 'بازتوزیع جلسات هفته',
        queryPrompt: 'جلسات این هفته دوره را چطور توزیع کنم؟',
        isRelevant: (_) => true,
        priority: 7,
      ),
    ],
    'sports': [
      PersonaSkill(
        id: 'recovery_check',
        labelFa: 'بررسی وضعیت ریکاوری',
        queryPrompt: 'آیا بدن من برای تمرین امروز آماده است؟',
        isRelevant: (_) => true,
        priority: 10,
      ),
      PersonaSkill(
        id: 'workout_adjust',
        labelFa: 'تنظیم شدت تمرین',
        queryPrompt: 'شدت تمرین امروز را چطور تنظیم کنم؟',
        isRelevant: (_) => true,
        priority: 8,
      ),
    ],
    'worship': [
      PersonaSkill(
        id: 'qaza_plan',
        labelFa: 'برنامه قضای عبادات',
        queryPrompt: 'یک برنامه منظم برای ادا کردن نمازها و روزه‌های قضا بدهید.',
        isRelevant: (brief) {
          if (brief is WorshipBrief) {
            return brief.totalDebtsCount > 0;
          }
          return true;
        },
        priority: 10,
      ),
      PersonaSkill(
        id: 'habit_streak',
        labelFa: 'تثبیت روتین عبادی',
        queryPrompt: 'چطور استمرار روتین عبادی روزانه را حفظ کنم؟',
        isRelevant: (_) => true,
        priority: 7,
      ),
    ],
    'reflection': [
      PersonaSkill(
        id: 'daily_reflection_prompt',
        labelFa: 'راهنمای ثبت بازتاب روز',
        queryPrompt: 'امروز چه سؤالاتی برای ثبت بازتاب از خودم بپرسم؟',
        isRelevant: (_) => true,
        priority: 10,
      ),
    ],
    'notes': [
      PersonaSkill(
        id: 'search_notes',
        labelFa: 'جست‌وجوی هوشمند یادداشت‌ها',
        queryPrompt: 'تجربه‌ها و یادداشت‌های مرتبط من را خلاصه‌سازی کن.',
        isRelevant: (_) => true,
        priority: 10,
      ),
    ],
    'cycle': [
      PersonaSkill(
        id: 'symptom_logger',
        labelFa: 'ثبت علائم روزانه',
        queryPrompt: 'چه علائمی را امروز باید ثبت کنم؟',
        isRelevant: (_) => true,
        priority: 10,
      ),
    ],
    'health': [
      PersonaSkill(
        id: 'adherence_check',
        labelFa: 'گزارش پایبندی دارویی',
        queryPrompt: 'وضعیت پایبندی من به داروهایم در هفته گذشته چطور بوده است؟',
        isRelevant: (_) => true,
        priority: 10,
      ),
    ],
  };
}
