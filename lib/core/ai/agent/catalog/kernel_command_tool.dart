import 'package:flutter/foundation.dart';
import 'package:ritmo/core/ai/agent/agent_tool.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/domain/commands/command_plan.dart';
import 'package:ritmo/core/domain/commands/ritmo_command.dart';
import 'package:ritmo/core/domain/commands/ritmo_command_bus.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:shamsi_date/shamsi_date.dart';

/// خطای ورودی ابزار.
///
/// پیام این خطا مستقیماً و بدون تغییر به مدل برگردانده می‌شود تا بتواند خودش را
/// اصلاح کند (مثلاً ساعت را با فرمت درست دوباره بفرستد). پس پیام باید فارسی،
/// دقیق و «قابل عمل» باشد، نه یک متن عمومی مثل «خطا رخ داد».
class ToolArgumentError implements Exception {
  const ToolArgumentError(this.messageFa);

  final String messageFa;

  @override
  String toString() => 'ToolArgumentError: $messageFa';
}

/// کلاس پایهٔ همهٔ ابزارهای «نوشتنی» ایجنت.
///
/// قانون معماری (اصل ۱ سند ارتقا): ایجنت هیچ‌وقت مستقیم در دیتابیس نمی‌نویسد.
/// هر تغییر داده باید از [RitmoCommandBus] عبور کند، چون تنها آن مسیر این‌ها را
/// یکجا تضمین می‌کند:
///
///  ۱. اعتبارسنجی پارامترها با ParamSpec (پیام خطای فارسی)
///  ۲. کنترل دسترسی با PersonaGate (ماژول خاموش = نوشتن ممنوع)
///  ۳. تراکنش اتمیک برای همهٔ استپ‌های یک پلن
///  ۴. ثبت در assistant_audit_log + امکان undo
///  ۵. همگام‌سازی snapshot ویجت/اعلان‌ها بعد از commit
///
/// و دو تضمین صداقت که در فاز ۰ نبود:
///  - هیچ `catch (_) {}` ای وجود ندارد؛ شکست همیشه به `AgentToolResult.failure`
///    تبدیل می‌شود تا مدل نتواند به کاربر بگوید «انجام شد».
///  - بعد از نوشتن روی دامنهٔ روتین/هدف، کش اجندا باطل و UI ریفرش می‌شود.
///    (چون RitmoExecutionKernel وقتی داخل تراکنشِ باس صدا زده می‌شود عمداً
///    رویدادی fire نمی‌کند، تقویم بدون این کار می‌توانست کهنه بماند.)
abstract class KernelCommandTool extends AgentTool {
  const KernelCommandTool({
    required String name,
    required String categoryFa,
    required String titleFa,
    required String descriptionFa,
    required this.commandId,
    ToolPolicy policy = ToolPolicy.actionDirect,
    List<ToolParameter> parameters = const [],
    this.personaId = 'global',
  }) : super(
          name: name,
          categoryFa: categoryFa,
          titleFa: titleFa,
          descriptionFa: descriptionFa,
          policy: policy,
          parameters: parameters,
        );

  /// شناسهٔ فرمان اصلی روی باس (مثل `routine.create`).
  final String commandId;

  /// پرسونای اجرا. `global` تنها پرسونایی است که همهٔ فرمان‌های ثبت‌شده را دارد،
  /// پس ابزارهای سراسری ایجنت با آن اجرا می‌شوند. توجه: خودِ `global` هم به
  /// دامنه‌های cycle و medical دسترسی نوشتن ندارد و PersonaGate جلوی آن را
  /// می‌گیرد — این عمدی است و نباید دور زده شود.
  final String personaId;

  /// ساخت استپ‌های پلن از ورودی مدل.
  ///
  /// برای ورودی نامعتبر [ToolArgumentError] پرتاب کن؛ پیامش عیناً به مدل
  /// برمی‌گردد. هرگز ورودی نامعتبر را «حدس نزن و بنویس».
  Future<List<PlanStep>> buildSteps(Map<String, dynamic> args);

  /// خلاصهٔ فارسی موفقیت. `output` خروجی ادغام‌شدهٔ همهٔ استپ‌ها است.
  String buildSummaryFa(Map<String, dynamic> args, Map<String, dynamic> output);

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    final bus = RitmoCommandBus.instance;

    List<PlanStep> steps;
    try {
      steps = await buildSteps(args);
    } on ToolArgumentError catch (e) {
      return AgentToolResult.failure(
        toolName: name,
        errorMessage: e.messageFa,
        summaryFa: 'انجام نشد: ${e.messageFa}',
      );
    } catch (e, st) {
      RitmoLog.error('AgentKernelTool', 'buildSteps failed for $name', e, st);
      return AgentToolResult.failure(
        toolName: name,
        errorMessage:
            'ورودی این ابزار قابل پردازش نبود و هیچ داده‌ای ذخیره نشد ($e).',
      );
    }

    if (steps.isEmpty) {
      return AgentToolResult.failure(
        toolName: name,
        errorMessage:
            'از ورودی داده‌شده هیچ عملیات اجرایی ساخته نشد، پس هیچ چیزی ذخیره نشد.',
      );
    }

    // فرمان ثبت‌نشده = خطای برنامه‌نویسی، نه خطای کاربر. صریح گزارش می‌شود.
    for (final step in steps) {
      if (bus.getCommand(step.commandId) == null) {
        RitmoLog.error(
          'AgentKernelTool',
          'command "${step.commandId}" is not registered on the bus',
          StateError('unregistered command'),
        );
        return AgentToolResult.failure(
          toolName: name,
          errorMessage:
              'فرمان «${step.commandId}» در این نسخهٔ برنامه ثبت نشده است، پس هیچ تغییری اعمال نشد.',
        );
      }
    }

    final plan = CommandPlan(
      id: 'agent_${DateTime.now().microsecondsSinceEpoch}',
      titleFa: titleFa,
      steps: steps,
    );

    PlanResult result;
    try {
      result = await bus.execute(
        plan,
        personaId: personaId,
        source: CommandSource.assistant,
      );
    } catch (e, st) {
      RitmoLog.error('AgentKernelTool', 'bus.execute threw for $commandId', e, st);
      return AgentToolResult.failure(
        toolName: name,
        errorMessage:
            'اجرای «$titleFa» با خطای غیرمنتظره متوقف شد و تراکنش برگشت خورد: $e',
      );
    }

    if (!result.success) {
      debugPrint('[AgentKernelTool] $name ($commandId) -> FAILED: ${result.errorMessage}');
      return AgentToolResult.failure(
        toolName: name,
        errorMessage:
            'انجام نشد و هیچ داده‌ای ذخیره نشد. دلیل: ${result.errorMessage ?? 'نامشخص'}',
      );
    }

    final output = <String, dynamic>{};
    for (final r in result.results) {
      final data = r.outputData;
      if (data.isNotEmpty) output.addAll(data);
    }

    _refreshAffectedSurfaces(steps.map((s) => s.commandId));

    debugPrint(
      '[AgentKernelTool] $name ($commandId) -> ok | plan=${result.planId} | steps=${steps.length}',
    );

    return AgentToolResult.success(
      toolName: name,
      data: <String, dynamic>{
        ...output,
        'planId': result.planId,
        'commands': steps.map((s) => s.commandId).toList(),
        'isUndoable': true,
      },
      summaryFa: buildSummaryFa(args, output),
    );
  }

  /// باطل‌سازی کش اجندا و ریفرش UI بعد از یک نوشتن موفق.
  ///
  /// چرا لازم است: `RitmoExecutionKernel.execute(cmd, txn: txn)` وقتی داخل
  /// تراکنش باس اجرا می‌شود، PostCommitPipeline و رویدادهای دامنه را اجرا
  /// نمی‌کند؛ و خودِ فرمان‌های روتین چیزی در `invalidates` ندارند. پس بدون این
  /// دو خط، روتینِ تازه‌ساخته در دیتابیس هست ولی تقویم می‌تواند نسخهٔ کش‌شدهٔ
  /// همان روز را نشان بدهد. این دقیقاً همان کلاس باگ «ساخته شد ولی دیده نمی‌شود»
  /// است و اینجا بسته می‌شود.
  ///
  /// نکتهٔ ایمنی: `notifyRoutineChanged()` عمداً فقط از اینجا (یک اکشن کاربر)
  /// صدا زده می‌شود، نه از داخل callback رویدادها — آن حلقه قبلاً باعث فریز و
  /// OOM شده بود.
  void _refreshAffectedSurfaces(Iterable<String> commandIds) {
    final bus = RitmoCommandBus.instance;
    var touchesAgenda = false;
    for (final id in commandIds) {
      final cmd = bus.getCommand(id);
      if (cmd == null) continue;
      if (cmd.touches.contains(DataDomain.routines) ||
          cmd.touches.contains(DataDomain.goals)) {
        touchesAgenda = true;
      }
    }

    try {
      DayAgendaService.instance.invalidateAll();
      if (touchesAgenda) {
        RitmoEvents.notifyRoutineChanged();
      }
    } catch (e, st) {
      // نوشتن موفق بوده؛ شکست ریفرش نباید نتیجه را دروغ کند، فقط لاگ می‌شود.
      RitmoLog.error('AgentKernelTool', 'post-write UI refresh failed', e, st);
    }
  }

  // ---------------------------------------------------------------------------
  // ابزارهای کمکی مشترک برای نرمال‌سازی ورودی مدل
  // ---------------------------------------------------------------------------

  static const String _faDigits = '۰۱۲۳۴۵۶۷۸۹';
  static const String _arDigits = '٠١٢٣٤٥٦٧٨٩';

  /// تبدیل ارقام فارسی/عربی به لاتین. مدل مرتب «۰۷:۳۰» می‌فرستد.
  static String toEnglishDigits(String input) {
    var out = input;
    for (var i = 0; i < 10; i++) {
      out = out.replaceAll(_faDigits[i], i.toString());
      out = out.replaceAll(_arDigits[i], i.toString());
    }
    return out;
  }

  static String? optionalString(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

  static String requiredString(dynamic value, String labelFa) {
    final s = optionalString(value);
    if (s == null) {
      throw ToolArgumentError('«$labelFa» الزامی است و مقداری برای آن فرستاده نشد.');
    }
    return s;
  }

  static int? optionalInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is bool) return value ? 1 : 0;
    return int.tryParse(toEnglishDigits(value.toString().trim()));
  }

  /// عدد صحیح با کف/سقف. خروجی همیشه `int` است (نه `num`) چون فرمان‌های باس
  /// مقدار را با `as int?` می‌خوانند و یک `double` باعث خطای cast می‌شود.
  static int clampedInt(dynamic value, int fallback, int min, int max) {
    final parsed = optionalInt(value) ?? fallback;
    if (parsed < min) return min;
    if (parsed > max) return max;
    return parsed;
  }

  static bool? optionalBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    final s = toEnglishDigits(value.toString().trim().toLowerCase());
    if (s == 'true' || s == '1' || s == 'yes' || s == 'بله' || s == 'روشن') {
      return true;
    }
    if (s == 'false' || s == '0' || s == 'no' || s == 'خیر' || s == 'خاموش') {
      return false;
    }
    return null;
  }

  /// نرمال‌سازی ساعت به `HH:mm` (تنها فرمتی که ParamSpec.timeOfDay می‌پذیرد).
  static String? normalizeTimeOfDay(dynamic value) {
    final raw = optionalString(value);
    if (raw == null) return null;
    final cleaned = toEnglishDigits(raw)
        .replaceAll('.', ':')
        .replaceAll('،', ':')
        .replaceAll(' ', '');
    final match = RegExp(r'^(\d{1,2}):(\d{1,2})$').firstMatch(cleaned);
    if (match == null) return null;
    final h = int.tryParse(match.group(1)!);
    final m = int.tryParse(match.group(2)!);
    if (h == null || m == null) return null;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  static String requiredTimeOfDay(dynamic value, String labelFa) {
    final raw = optionalString(value);
    if (raw == null) {
      throw ToolArgumentError(
        '«$labelFa» الزامی است؛ ساعت را با فرمت ۲۴ساعتیِ HH:MM بفرست (مثال: 07:30).',
      );
    }
    final normalized = normalizeTimeOfDay(raw);
    if (normalized == null) {
      throw ToolArgumentError(
        'ساعت «$raw» معتبر نیست. فقط فرمت ۲۴ساعتی HH:MM پذیرفته می‌شود (مثال: 07:30 یا 21:00).',
      );
    }
    return normalized;
  }
}

/// تبدیل تاریخِ آزادِ مدل به یک `DateTime` قطعی.
///
/// قبلاً هر ابزار نسخهٔ خودش را داشت؛ نتیجه‌اش این بود که یکی «فردا» را می‌فهمید
/// و دیگری نه. اینجا یک پیاده‌سازی مشترک است: کلیدواژه‌های فارسی/انگلیسی،
/// ارقام فارسی، و تشخیص خودکار شمسی از میلادی بر اساس سال.
class AgentDateResolver {
  const AgentDateResolver._();

  static const List<String> _weekdayFa = <String>[
    'دوشنبه',
    'سه‌شنبه',
    'چهارشنبه',
    'پنجشنبه',
    'جمعه',
    'شنبه',
    'یکشنبه',
  ];

  /// روزِ هدف. ورودی خالی یا ناشناخته = امروز (هیچ‌وقت خطا پرت نمی‌کند تا یک
  /// ابزار خواندنی صرفاً به‌خاطر تاریخ بد شکست نخورد).
  static DateTime resolve(dynamic input, {DateTime? now}) {
    final base = now ?? DateTime.now();
    final today = DateTime(base.year, base.month, base.day);

    final raw = KernelCommandTool.optionalString(input);
    if (raw == null) return today;

    final v = KernelCommandTool.toEnglishDigits(raw.trim().toLowerCase());

    if (v == 'today' || v == 'now' || v == 'امروز' || v == 'الان' || v == 'همین امروز') {
      return today;
    }
    if (v == 'tomorrow' || v == 'فردا') {
      return today.add(const Duration(days: 1));
    }
    if (v == 'yesterday' || v == 'دیروز') {
      return today.subtract(const Duration(days: 1));
    }
    if (v == 'پس‌فردا' || v == 'پسفردا' || v == 'day_after_tomorrow') {
      return today.add(const Duration(days: 2));
    }

    final parts = v
        .split(RegExp(r'[/\-.]'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length == 3) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y != null && m != null && d != null && m >= 1 && m <= 12 && d >= 1 && d <= 31) {
        // سال‌های ۱۲۰۰ تا ۱۶۹۹ شمسی‌اند، ۱۷۰۰ به بالا میلادی.
        if (y >= 1200 && y < 1700) {
          try {
            return Jalali(y, m, d).toGregorian().toDateTime();
          } catch (_) {
            return today;
          }
        }
        try {
          return DateTime(y, m, d);
        } catch (_) {
          return today;
        }
      }
    }

    return today;
  }

  static String iso(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static String todayIso() => iso(DateTime.now());

  /// برچسب خوانا برای مدل: «شنبه ۱۴۰۵/۰۵/۲۵ (2026-08-16)».
  static String label(DateTime date) {
    final weekday = _weekdayFa[(date.weekday - 1) % 7];
    try {
      final j = Jalali.fromDateTime(date);
      final jm = j.month.toString().padLeft(2, '0');
      final jd = j.day.toString().padLeft(2, '0');
      return '$weekday ${j.year}/$jm/$jd (${iso(date)})';
    } catch (_) {
      return '$weekday (${iso(date)})';
    }
  }
}
