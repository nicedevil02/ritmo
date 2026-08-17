import 'package:ritmo/core/ai/agent/agent_tool.dart';
import 'package:ritmo/core/ai/agent/agent_tool_scope.dart';
import 'package:ritmo/core/ai/agent/catalog/kernel_command_tool.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/domain/commands/command_plan.dart';
import 'package:ritmo/core/domain/commands/ritmo_command_bus.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';

/// نام فارسی هر دامنهٔ اجندا برای گزارش به مدل.
const Map<AgendaDomain, String> _domainFa = <AgendaDomain, String>{
  AgendaDomain.routine: 'روتین',
  AgendaDomain.prayer: 'نماز',
  AgendaDomain.mustahab: 'مستحبات',
  AgendaDomain.course: 'دروس',
  AgendaDomain.goalStep: 'گام هدف',
  AgendaDomain.konkur: 'کنکور',
  AgendaDomain.cycle: 'چرخه',
  AgendaDomain.worshipDebt: 'قضای عبادات',
  AgendaDomain.sport: 'ورزش',
  AgendaDomain.medicine: 'دارو',
  AgendaDomain.event: 'رویداد',
  AgendaDomain.task: 'کار',
  AgendaDomain.commitment: 'تعهد',
  AgendaDomain.appointment: 'نوبت',
};

/// نام فارسی وضعیت انجام.
const Map<AgendaCompletion, String> _completionFa = <AgendaCompletion, String>{
  AgendaCompletion.none: 'بدون وضعیت ثبت‌شده',
  AgendaCompletion.pending: 'انجام‌نشده',
  AgendaCompletion.done: 'انجام‌شده',
  AgendaCompletion.partial: 'نیمه‌انجام',
  AgendaCompletion.skipped: 'ردشده',
  AgendaCompletion.overdue: 'عقب‌افتاده',
  AgendaCompletion.missed: 'ازدست‌رفته',
};

/// ۱. ابزار دریافت برنامهٔ یک روز — فاز ۲ (P2-3)
///
/// منبع داده دیگر یک کوئری خام روی routine_occurrences نیست، بلکه دقیقاً
/// همان [DayAgendaService] است که خانه و تقویم از آن می‌خوانند. چرا مهم است:
///
///  - مدل دیگر نماز، جلسات ورزشی، دارو، دروس، کنکور، کارها و رویدادها را
///    از قلم نمی‌اندازد (قبلاً فقط روتین‌ها را می‌دید).
///  - گیت‌های ماژول، رضایت چرخه، اووررایدهای روز و روزهای استراحت/سفر
///    در همان جایی اعمال می‌شوند که UI اعمال می‌کند، پس جواب دستیار با آنچه
///    کاربر می‌بیند تفاوت ندارد.
///  - منطق تاریخ، مرتب‌سازی و وضعیت انجام دو جا تکرار نمی‌شود (D15).
class GetDayAgendaTool extends AgentTool {
  const GetDayAgendaTool()
      : super(
          name: 'get_day_agenda',
          categoryFa: 'برنامه‌ریزی روز',
          titleFa: 'دریافت برنامهٔ یک روز',
          descriptionFa:
              'برنامهٔ کامل یک روز را عیناً مطابق آنچه در خانه و تقویم برنامه دیده می‌شود بازمی‌گرداند: روتین‌ها، رویدادها، کارها، نماز، ورزش، دارو، دروس و گام‌های اهداف با ساعت و وضعیت انجام. برای هر پرسش دربارهٔ برنامهٔ امروز/فردا همین را صدا بزن.',
          policy: ToolPolicy.readOnly,
          parameters: const [
            ToolParameter(
              name: 'targetDate',
              descriptionFa:
                  'تاریخ مورد نظر: امروز، فردا، دیروز، پس‌فردا، یا تاریخ شمسی مانند 1405/05/26 یا میلادی مانند 2026-08-16',
              type: 'string',
              defaultValue: 'امروز',
            ),
            ToolParameter(
              name: 'onlyPending',
              descriptionFa:
                  'اگر true باشد فقط موارد انجام‌نشده برگردانده می‌شوند (مناسب برای «چه مانده؟»)',
              type: 'bool',
              defaultValue: false,
            ),
          ],
        );

  /// سقف تعداد آیتم در خروجی؛ برای محافظت از بودجهٔ پرامپت لازم است.
  static const int _maxItems = 40;

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    final rawTarget = args['targetDate']?.toString() ?? 'امروز';
    final resolved = AgentDateResolver.resolve(rawTarget);
    final iso = AgentDateResolver.iso(resolved);
    final label = AgentDateResolver.label(resolved);
    final onlyPending = KernelCommandTool.optionalBool(args['onlyPending']) ?? false;

    DayAgenda agenda;
    try {
      agenda = await DayAgendaService.instance.agendaForDate(
        resolved,
        options: AgendaQueryOptions(includeCompleted: !onlyPending),
      );
    } catch (e, st) {
      RitmoLog.error('GetDayAgendaTool', 'agendaForDate failed for $iso', e, st);
      return AgentToolResult.failure(
        toolName: name,
        errorMessage:
            'خواندن برنامهٔ $label با خطا متوقف شد، پس هیچ لیستی در دست نیست. حدس نزن که روز خالی است: $e',
      );
    }

    final all = agenda.items;
    final capped = all.length > _maxItems ? all.sublist(0, _maxItems) : all;

    final items = capped
        .map((i) => <String, dynamic>{
              'title': i.title,
              if (i.subtitle != null && i.subtitle!.trim().isNotEmpty)
                'subtitle': i.subtitle,
              'time': i.timeOfDay ?? 'ساعت مشخص ندارد',
              'durationMinutes': i.durationMinutes,
              'status': _completionFa[i.completion] ?? i.completion.name,
              'statusCode': i.completion.name,
              'section': _domainFa[i.domain] ?? i.domain.name,
              'kind': i.kind.name,
              'isEssential': i.isEssential,
              'sourceId': i.sourceId,
            })
        .toList();

    final doneCount = all.where((i) => i.isCompleted).length;
    final skippedCount =
        all.where((i) => i.completion == AgendaCompletion.skipped).length;
    final pendingCount = all.length - doneCount - skippedCount;

    final disabledSections = <String>[];
    agenda.enabledDomains.forEach((domain, isEnabled) {
      if (!isEnabled) {
        disabledSections.add(_domainFa[domain] ?? domain.name);
      }
    });

    final degradedSections = agenda.degradedSources
        .map((domain) => _domainFa[domain] ?? domain.name)
        .toList();

    final summary = StringBuffer();
    if (all.isEmpty) {
      summary.write('برای $label هیچ موردی در برنامه نیست');
      if (disabledSections.isNotEmpty) {
        summary.write(' (بخش‌های خاموش: ${disabledSections.join('، ')})');
      }
      summary.write('.');
    } else {
      summary.write(
        'برنامهٔ $label: ${all.length} مورد؛ $doneCount انجام‌شده، $pendingCount باقی‌مانده',
      );
      if (skippedCount > 0) summary.write('، $skippedCount ردشده');
      summary.write('.');
    }
    if (degradedSections.isNotEmpty) {
      summary.write(
        ' هشدار: منابع ${degradedSections.join('، ')} امروز درست بار نشدند، پس لیست ممکن است ناقص باشد.',
      );
    }

    return AgentToolResult.success(
      toolName: name,
      data: {
        'requestedTarget': rawTarget,
        'date': iso,
        'dateLabelFa': label,
        'itemCount': all.length,
        'doneCount': doneCount,
        'pendingCount': pendingCount,
        'skippedCount': skippedCount,
        'truncated': all.length > capped.length,
        'items': items,
        'disabledSections': disabledSections,
        'degradedSections': degradedSections,
        'source': 'DayAgendaService',
      },
      summaryFa: summary.toString(),
    );
  }
}

/// ۲. ابزار مادی‌سازی تخصیص‌های برنامه‌ریزی یک روز — جایگزین ApplySmartDayPlanTool
///
/// نسخهٔ قدیمی (`apply_smart_day_plan`) در جدولی می‌نوشت که در دسترسش نبود،
/// خطا را در `catch (_) {}` می‌بلعید و بعد به کاربر می‌گفت برنامه ذخیره شد.
/// این نسخه روی فرمان واقعی `planning.materializeDay` سوار است: تخصیص‌های
/// PLANNED همان روز را به کار واقعی تبدیل می‌کند — هیچ برنامه‌ای از خود
/// اختراع نمی‌کند.
///
/// عمداً در رجیستری ثبت نمی‌شود: این فرمان به دامنهٔ goals دست می‌زند و
/// تا وقتی ماژول اهداف و چرخهٔ برنامه‌ریزی در عمل استفاده نشوند، افزودنش فقط
/// به پرامپت نویز اضافه می‌کند (انضباط تعداد ابزار — D3).
class MaterializeDayPlanTool extends KernelCommandTool {
  const MaterializeDayPlanTool()
      : super(
          name: 'materialize_day_plan',
          categoryFa: 'برنامه‌ریزی روز',
          titleFa: 'تبدیل تخصیص‌های برنامه به کار روز',
          descriptionFa:
              'تخصیص‌های برنامه‌ریزی‌شدهٔ یک روز را به کارهای واقعی همان روز تبدیل می‌کند. هیچ برنامهٔ جدیدی نمی‌سازد.',
          commandId: 'planning.materializeDay',
          policy: ToolPolicy.actionDirect,
          parameters: const [
            ToolParameter(
              name: 'date',
              descriptionFa: 'تاریخ روز مقصد (پیش‌فرض امروز)',
              type: 'string',
              defaultValue: 'امروز',
            ),
          ],
        );

  @override
  Future<List<PlanStep>> buildSteps(Map<String, dynamic> args) async {
    final date = AgentDateResolver.resolve(args['date'] ?? args['dayKey']);
    return <PlanStep>[
      PlanStep(
        commandId: commandId,
        payload: <String, dynamic>{'dayKey': AgentDateResolver.iso(date)},
        note: 'اجراشده توسط دستیار ریتمو',
      ),
    ];
  }

  @override
  String buildSummaryFa(Map<String, dynamic> args, Map<String, dynamic> output) {
    final date = AgentDateResolver.resolve(args['date'] ?? args['dayKey']);
    final count = KernelCommandTool.optionalInt(output['count']) ?? 0;
    if (count == 0) {
      return 'برای ${AgentDateResolver.label(date)} هیچ تخصیص برنامه‌ریزی‌شده‌ای وجود نداشت، پس چیزی به کارهای روز اضافه نشد.';
    }
    return '$count تخصیص برنامه‌ریزی‌شدهٔ ${AgentDateResolver.label(date)} به کار واقعی تبدیل شد.';
  }
}

/// ابزار شبیه‌سازی و پیش‌نمایش طرح پیشنهادی بدون ذخیره در دیتابیس (T33)
class SimulatePlanTool extends AgentTool {
  const SimulatePlanTool()
      : super(
          name: 'simulate_plan',
          categoryFa: 'برنامه‌ریزی روز',
          titleFa: 'شبیه‌سازی و پیش‌نمایش طرح پیشنهادی',
          descriptionFa:
              'مجموعه‌ای از گام‌ها/فرمان‌های پیشنهادی را بدون دست زدن به دیتابیس شبیه‌سازی می‌کند تا تداخل‌ها، تغییرات و موانع اجرای آن مشخص شود (Dry Run).',
          policy: ToolPolicy.readOnly,
          parameters: const [
            ToolParameter(
              name: 'steps',
              descriptionFa:
                  'لیست مراحل پیشنهادی؛ هر مرحله شامل commandId و payload است',
              type: 'list',
              isRequired: true,
            ),
          ],
        );

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    final rawSteps = args['steps'];
    if (rawSteps is! List || rawSteps.isEmpty) {
      return AgentToolResult.failure(
        toolName: name,
        errorMessage: 'لیست مراحل پیشنهادی (steps) الزامی است و نباید خالی باشد.',
      );
    }

    final planSteps = <PlanStep>[];
    for (final s in rawSteps) {
      if (s is Map) {
        final commandId = s['commandId']?.toString() ?? '';
        final payloadRaw = s['payload'];
        final payload = payloadRaw is Map
            ? payloadRaw.cast<String, dynamic>()
            : <String, dynamic>{};
        if (commandId.isNotEmpty) {
          planSteps.add(PlanStep(
            commandId: commandId,
            payload: payload,
            note: 'شبیه‌سازی توسط ایجنت',
          ));
        }
      }
    }

    if (planSteps.isEmpty) {
      return AgentToolResult.failure(
        toolName: name,
        errorMessage: 'هیچ مرحلهٔ معتبری با commandId یافت نشد.',
      );
    }

    final plan = CommandPlan(
      id: 'sim_${DateTime.now().microsecondsSinceEpoch}',
      titleFa: 'پیش‌نمایش برنامه پیشنهادی',
      steps: planSteps,
    );

    try {
      final preview = await RitmoCommandBus.instance.preview(
        plan,
        personaId: AgentToolScope.instance.activePersonaId,
      );

      final diffSummaries = preview.diffs.map((d) => d.toJson()).toList();
      final canExecute = preview.blockers.isEmpty;
      final summaryFa = canExecute
          ? 'شبیه‌سازی با موفقیت انجام شد: ${preview.diffs.length} تغییر بدون مانع پیش‌بینی شد.'
          : 'شبیه‌سازی دارای موانع اجرایی است: ${preview.blockers.join('، ')}';

      return AgentToolResult.success(
        toolName: name,
        data: {
          'canExecute': canExecute,
          'blockers': preview.blockers,
          'needsBiometric': preview.needsBiometric,
          'diffs': diffSummaries,
        },
        summaryFa: summaryFa,
      );
    } catch (e, st) {
      RitmoLog.error('SimulatePlanTool', 'preview failed', e, st);
      return AgentToolResult.failure(
        toolName: name,
        errorMessage: 'خطا در اجرای شبیه‌سازی طرح: $e',
      );
    }
  }
}
