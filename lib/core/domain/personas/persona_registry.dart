import 'package:ritmo/core/domain/commands/ritmo_command.dart';
import 'package:ritmo/core/domain/commands/ritmo_command_bus.dart';
import 'package:ritmo/core/domain/commands/commands_registry.dart';
import 'package:ritmo/core/domain/personas/assistant_persona.dart';

class PersonaRegistry {
  PersonaRegistry._();
  static final PersonaRegistry instance = PersonaRegistry._();

  final Map<String, AssistantPersona> _personas = {};

  void register(AssistantPersona persona) {
    // Privacy Enforcer: Only cycle, health & pregnancy personas read cycle/medical domains
    if (persona.reads.contains(DataDomain.cycle) && persona.id != 'cycle' && persona.id != 'pregnancy') {
      throw SecurityError('فقط پرسونای سیکل و بارداری مجاز به خواندن DataDomain.cycle هستند.');
    }
    if (persona.reads.contains(DataDomain.medical) && persona.id != 'health' && persona.id != 'pregnancy') {
      throw SecurityError('فقط پرسونای سلامت و بارداری مجاز به خواندن DataDomain.medical هستند.');
    }

    const exemptCommands = {'assistant.handoff', 'app.openPage', 'setting.update'};
    final safeCommandIds = <String>{};

    for (final cmdId in persona.commandIds) {
      if (exemptCommands.contains(cmdId)) {
        safeCommandIds.add(cmdId);
        continue;
      }
      final cmd = RitmoCommandBus.instance.getCommand(cmdId);
      if (cmd != null) {
        // Medical / Cycle protection
        if (cmd.touches.contains(DataDomain.medical) && persona.id != 'health' && persona.id != 'pregnancy') {
          continue;
        }
        if (cmd.touches.contains(DataDomain.cycle) && persona.id != 'cycle' && persona.id != 'pregnancy') {
          continue;
        }
        // General domain touch check
        if (!cmd.touches.every(persona.reads.contains)) {
          continue;
        }
      }
      safeCommandIds.add(cmdId);
    }

    _personas[persona.id] = AssistantPersona(
      id: persona.id,
      displayName: persona.displayName,
      systemPromptKey: persona.systemPromptKey,
      reads: persona.reads,
      commandIds: safeCommandIds,
      handoffHint: persona.handoffHint,
    );
  }

  AssistantPersona? getPersona(String id) => _personas[id];

  List<AssistantPersona> get allPersonas => _personas.values.toList();

  void initStandardPersonas() {
    if (RitmoCommandBus.instance.registeredCommandIds.isEmpty) {
      registerAllRitmoCommands();
    }
    final allCmdIds = RitmoCommandBus.instance.registeredCommandIds;

    register(AssistantPersona(
      id: 'global',
      displayName: 'دستیار سراسری ریتمو',
      systemPromptKey: 'system_prompt_global',
      reads: {
        DataDomain.routines,
        DataDomain.goals,
        DataDomain.worship,
        DataDomain.konkur,
        DataDomain.sleep,
        DataDomain.energy,
        DataDomain.reflection,
        DataDomain.sports,
        DataDomain.courses,
        DataDomain.notes,
      },
      commandIds: {...allCmdIds, 'assistant.handoff', 'app.openPage'},
    ));

    register(AssistantPersona(
      id: 'general',
      displayName: 'دستیار گفتگوی عمومی',
      systemPromptKey: 'system_prompt_general',
      reads: const {},
      commandIds: {'assistant.handoff', 'app.openPage'},
      handoffHint: 'برای کارهای تخصصی ریتمو، به دستیار تخصصی منتقل شوید.',
    ));


    register(AssistantPersona(
      id: 'worship',
      displayName: 'دستیار معنوی و عبادات',
      systemPromptKey: 'system_prompt_worship',
      reads: {DataDomain.worship, DataDomain.routines},
      commandIds: {'worship.create', 'worship.delete', 'app.openPage', 'setting.update', 'assistant.handoff'},
      handoffHint: 'جهت تنظیم خواب یا اهداف می‌توانید به دستیار خواب یا اهداف منتقل شوید.',
    ));

    register(AssistantPersona(
      id: 'konkur',
      displayName: 'دستیار برنامه‌ریزی کنکور',
      systemPromptKey: 'system_prompt_konkur',
      reads: {DataDomain.konkur, DataDomain.routines},
      commandIds: {'konkur.createTopic', 'app.openPage', 'assistant.handoff', 'study.addTopic', 'study.setSubjectPriority', 'study.planSession', 'study.logSession', 'study.logMockResult', 'study.generateWeeklyPlan', 'study.setExamDate', 'study.setDailyBudget'},
    ));

    register(AssistantPersona(
      id: 'courses',
      displayName: 'دستیار دوره‌ها و دروس',
      systemPromptKey: 'system_prompt_courses',
      reads: {DataDomain.courses, DataDomain.routines},
      commandIds: {'course.create', 'app.openPage', 'assistant.handoff', 'course.setWeeklyTarget', 'course.logSession', 'course.resplitSessions', 'course.archive'},
    ));

    register(AssistantPersona(
      id: 'sports',
      displayName: 'مربی هوشمند ورزشی',
      systemPromptKey: 'system_prompt_sports',
      reads: {DataDomain.sports, DataDomain.energy, DataDomain.routines},
      commandIds: {'app.openPage', 'assistant.handoff', 'sports.setTrainingDays', 'sports.setSessionMinutes', 'sports.setFocus', 'sports.setRestDay', 'sports.lockDay', 'sports.swapExercise', 'sports.adjustIntensity', 'sports.logSession', 'sports.generateProgram', 'sports.setQuietMode'},
    ));

    register(AssistantPersona(
      id: 'wellbeing',
      displayName: 'دستیار حال و تعادل',
      systemPromptKey: 'system_prompt_wellbeing',
      reads: {DataDomain.energy, DataDomain.sleep, DataDomain.reflection, DataDomain.routines},
      commandIds: {'energy.log', 'sleep.log', 'reflection.log', 'app.openPage', 'assistant.handoff'},
    ));

    register(AssistantPersona(
      id: 'goals',
      displayName: 'دستیار اهداف و برنامه‌ها',
      systemPromptKey: 'system_prompt_goals',
      reads: {DataDomain.goals, DataDomain.routines},
      commandIds: {
        'goal.create',
        'goal.edit',
        'goal.completeStep',
        'app.openPage',
        'assistant.handoff',
        'goal.decompose',
        'goal.archive',
      },
    ));

    register(AssistantPersona(
      id: 'planning',
      displayName: 'دستیار برنامه‌ریزی هوشمند',
      systemPromptKey: 'system_prompt_planning',
      reads: {DataDomain.routines, DataDomain.goals, DataDomain.courses, DataDomain.sports, DataDomain.worship, DataDomain.konkur},
      commandIds: {
        'app.openPage',
        'assistant.handoff',
        'setting.update',
        'planning.applyWeek',
        'planning.createCycle',
        'planning.closeCycle',
        'planning.addCommitment',
        'planning.dropCommitment',
        'planning.moveAllocation',
        'planning.splitCommitment',
        'planning.lockAllocation',
        'planning.setDayLight',
        'planning.materializeDay',
      },
      handoffHint: 'برنامهٔ هفته، برنامهٔ ماه، تعهد، ظرفیت، «هفته‌م رو بچین»',
    ));

    register(AssistantPersona(
      id: 'sleep',
      displayName: 'دستیار تنظیم خواب',
      systemPromptKey: 'system_prompt_sleep',
      reads: {DataDomain.sleep, DataDomain.energy},
      commandIds: {'sleep.log', 'app.openPage', 'assistant.handoff', 'sleep.setTargetWindow', 'sleep.logDiagnostic'},
    ));

    register(AssistantPersona(
      id: 'reflection',
      displayName: 'دستیار خودارزیابی و بازتاب',
      systemPromptKey: 'system_prompt_reflection',
      reads: {DataDomain.reflection, DataDomain.energy},
      commandIds: {'reflection.log', 'app.openPage', 'assistant.handoff'},
    ));

    register(AssistantPersona(
      id: 'cycle',
      displayName: 'دستیار بهداشت چرخه بدنی',
      systemPromptKey: 'system_prompt_cycle',
      reads: {DataDomain.cycle, DataDomain.energy, DataDomain.routines},
      commandIds: {'app.openPage', 'energy.log', 'assistant.handoff'},
    ));

    register(AssistantPersona(
      id: 'health',
      displayName: 'دستیار هوشمند سلامت',
      systemPromptKey: 'system_prompt_health',
      reads: {DataDomain.medical, DataDomain.energy, DataDomain.routines},
      commandIds: {'app.openPage', 'setting.update', 'assistant.handoff', 'health.logAdherence', 'health.logVital', 'health.scheduleTest'},
    ));

    register(AssistantPersona(
      id: 'notes',
      displayName: 'دفترچه و تجربه‌ها',
      systemPromptKey: 'system_prompt_notes',
      reads: {DataDomain.notes},
      commandIds: {
        'note.create', 'note.append', 'note.edit', 'note.retitle', 'note.tag', 'note.untag',
        'note.link', 'note.unlink', 'note.pin', 'note.unpin', 'note.archive', 'note.restore',
        'note.delete', 'note.scheduleReview', 'note.extractActions', 'note.summarize',
        'notes.search', 'notes.dailyNote',
        'experience.create', 'experience.edit', 'experience.setActive', 'experience.setImportance',
        'assistant.handoff', 'app.openPage', 'setting.update',
      },
      handoffHint: 'یادداشت، ایده، تجربه، درس زندگی، «قبلاً نوشته بودم»، جست‌وجو در نوشته‌ها',
    ));

    register(AssistantPersona(
      id: 'pregnancy',
      displayName: 'دستیار دوران بارداری',
      systemPromptKey: 'system_prompt_pregnancy',
      reads: {DataDomain.cycle, DataDomain.energy, DataDomain.medical, DataDomain.routines},
      commandIds: {'app.openPage', 'assistant.handoff', 'setting.update', 'energy.log'},
      handoffHint: 'وضعیت جنین، هفته‌های بارداری، مراقبت‌های مادر',
    ));
  }

}

class SecurityError extends Error {
  SecurityError(this.message);
  final String message;

  @override
  String toString() => 'SecurityError: $message';
}
