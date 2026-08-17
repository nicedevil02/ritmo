import 'package:ritmo/core/ai/agent/agent_journal.dart';
import 'package:ritmo/core/ai/agent/agent_tool.dart';
import 'package:ritmo/core/ai/agent/catalog/kernel_command_tool.dart';
import 'package:ritmo/core/domain/commands/command_plan.dart';
import 'package:ritmo/core/settings/settings_service.dart';

/// مسیرهای واقعی و تعریف‌شده در RitmoRouter به همراه نام فارسی بخش.
///
/// نسخهٔ قبلی این ابزار مقادیری مانند 'sports' یا 'settings' را مجاز می‌دانست که
/// هیچ‌کدام مسیر واقعی روتر نبودند؛ پس حتی وقتی فاز ۳ ناوبری واقعی را وصل کند،
/// مقصد پیدا نمی‌شد. فقط مسیرهایی اینجا هستند که در ritmo_router.dart تأیید شده‌اند.
const Map<String, String> _appRoutes = <String, String>{
  '/today': 'امروز (خانه)',
  '/calendar': 'تقویم',
  '/routines': 'مخزن روتین‌ها',
  '/insights': 'بینش‌ها و تحلیل‌ها',
  '/systems': 'سیستم‌ها و ماژول‌ها',
  '/goals': 'اهداف',
  '/sports': 'ورزش و تحرک',
  '/health': 'سلامت',
  '/worship': 'عبادت‌ها',
  '/sleep': 'خواب',
  '/study': 'مطالعه و کنکور',
};

/// معادل‌های رایجی که مدل ممکن است بفرستد.
const Map<String, String> _routeAliases = <String, String>{
  'today': '/today',
  'home': '/today',
  'امروز': '/today',
  'خانه': '/today',
  'calendar': '/calendar',
  'تقویم': '/calendar',
  'routine': '/routines',
  'routines': '/routines',
  'روتین': '/routines',
  'روتین‌ها': '/routines',
  'insights': '/insights',
  'بینش': '/insights',
  'systems': '/systems',
  'سیستم‌ها': '/systems',
  'goals': '/goals',
  'اهداف': '/goals',
  'sports': '/sports',
  'ورزش': '/sports',
  'health': '/health',
  'سلامت': '/health',
  'worship': '/worship',
  'عبادت': '/worship',
  'sleep': '/sleep',
  'خواب': '/sleep',
  'study': '/study',
  'konkur': '/study',
  'مطالعه': '/study',
  'کنکور': '/study',
};

/// ۱. ابزار تشخیص مسیر بخش‌های اپلیکیشن
///
/// مهم: این ابزار «کاربر را جابجا نمی‌کند». هنوز هیچ مصرف‌کننده‌ای در UI برای
/// خروجی آن وجود ندارد (کارت تعاملی فاز ۳). پس خروجی فقط «مسیر رسمی بخش»
/// است تا مدل بتواند درست راهنمایی کند، و در خروجی صریحاً قید شده که ناوبری
/// خودکار انجام نشده — تا مدل به کاربر نگوید «تو را منتقل کردم».
class NavigateToAppScreenTool extends AgentTool {
  const NavigateToAppScreenTool()
      : super(
          name: 'navigate_to_app_screen',
          categoryFa: 'سیستم و ناوبری',
          titleFa: 'پیدا کردن مسیر بخش مورد نظر',
          descriptionFa:
              'مسیر رسمی و نام دقیق یک بخش از برنامه را برمی‌گرداند تا کاربر را درست راهنمایی کنی. توجه: خودش کاربر را جابجا نمی‌کند؛ پس نگو «تو را منتقل کردم»، بگو «از کدام بخش وارد شو».',
          policy: ToolPolicy.readOnly,
          parameters: const [
            ToolParameter(
              name: 'route',
              descriptionFa:
                  'بخش مقصد. یکی از مسیرهای رسمی یا نام فارسی آن (مثل تقویم، خواب، ورزش)',
              type: 'string',
              isRequired: true,
              allowedValues: [
                '/today',
                '/calendar',
                '/routines',
                '/insights',
                '/systems',
                '/goals',
                '/sports',
                '/health',
                '/worship',
                '/sleep',
                '/study',
              ],
            ),
          ],
        );

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    final raw = args['route']?.toString().trim() ?? '';
    if (raw.isEmpty) {
      return AgentToolResult.failure(
        toolName: name,
        errorMessage:
            'بخش مقصد مشخص نشد. یکی از این مسیرها را بفرست: ${_appRoutes.keys.join(', ')}',
      );
    }

    final normalized = raw.toLowerCase();
    final route = _appRoutes.containsKey(normalized)
        ? normalized
        : _routeAliases[normalized] ?? _routeAliases[raw];

    if (route == null) {
      return AgentToolResult.failure(
        toolName: name,
        errorMessage:
            'بخشی به نام «$raw» در برنامه وجود ندارد. مسیرهای موجود: ${_appRoutes.keys.join(', ')}',
      );
    }

    final sectionFa = _appRoutes[route] ?? route;

    return AgentToolResult.success(
      toolName: name,
      data: {
        'targetRoute': route,
        'sectionFa': sectionFa,
        'interactiveAction': {
          'type': 'navigation',
          'route': route,
          'labelFa': sectionFa,
        },
      },
      summaryFa:
          'بخش مورد نظر «$sectionFa» است (مسیر: $route). کارت انتقال برای هدایت به این بخش در اختیار کاربر قرار گرفت.',
    );
  }
}

/// قاعدهٔ اعتبارسنجی هر کلید مجاز تنطیمات.
class _PrefRule {
  const _PrefRule(this.kind, this.labelFa, {this.min, this.max});

  /// bool | int | time | text
  final String kind;
  final String labelFa;
  final int? min;
  final int? max;
}

/// اجازه‌نامهٔ صریح تنطیمات قابل تغییر توسط دستیار.
///
/// قاعده: deny-by-default. هر کلیدی که اینجا نباشد قابل تغییر نیست.
/// مخصوصاً کلیدهای module_* (خاموش/روشن کردن کلِ بخش‌های برنامه)، ai_* و
/// کلیدهای رضایت/جنسیت هرگز نباید توسط مدل دستکاری شوند؛ این تصمیم‌ها مال کاربرند.
/// (اگر این لیست را تغییر دادی، allowedValues پارامتر key را هم همگام کن.)
const Map<String, _PrefRule> _allowedPrefs = <String, _PrefRule>{
  'sleep_target_bedtime': _PrefRule('time', 'ساعت هدف خواب'),
  'calendar_show_events': _PrefRule('bool', 'نمایش رویدادها در تقویم'),
  'calendar_show_tasks': _PrefRule('bool', 'نمایش کارها در تقویم'),
  'calendar_show_commitments': _PrefRule('bool', 'نمایش تعهدها در تقویم'),
  'calendar_show_worship_obligatory':
      _PrefRule('bool', 'نمایش عبادات واجب در تقویم'),
  'calendar_show_worship_mustahab':
      _PrefRule('bool', 'نمایش مستحبات در تقویم'),
  'hijri_offset': _PrefRule('int', 'تصحیح تاریخ قمری', min: -3, max: 3),
  'snooze_max_quota': _PrefRule('int', 'سقف تعویق روزانه', min: 0, max: 10),
  'coalescing_window_minutes':
      _PrefRule('int', 'پنجرهٔ تجمیع اعلان‌ها (دقیقه)', min: 0, max: 240),
  'max_non_essential_per_hour':
      _PrefRule('int', 'سقف اعلان غیرضروری در ساعت', min: 0, max: 60),
  'digest_mode': _PrefRule('text', 'حالت خلاصهٔ اعلان‌ها'),
  'user_name': _PrefRule('text', 'نام کاربر'),
};

/// ۲. ابزار تغییر ترجیحات کاربری — فاز ۲
class UpdateAppPreferenceTool extends AgentTool {
  const UpdateAppPreferenceTool()
      : super(
          name: 'update_app_preference',
          categoryFa: 'سیستم و ناوبری',
          titleFa: 'تغییر ترجیحات برنامه',
          descriptionFa:
              'یک ترجیح بی‌خطر کاربری را تغییر می‌دهد (ساعت هدف خواب، نمایش رویداد/کار در تقویم، تنطیمات اعلان، تصحیح تقویم قمری، نام کاربر). خاموش/روشن کردن ماژول‌ها، تنطیمات هوش مصنوعی و رضایت‌ها عمداً ممنوع است و باید خود کاربر از تنطیمات انجام دهد.',
          policy: ToolPolicy.actionDirect,
          parameters: const [
            ToolParameter(
              name: 'key',
              descriptionFa: 'کلید تنطیمات از فهرست مجاز',
              type: 'string',
              isRequired: true,
              allowedValues: [
                'sleep_target_bedtime',
                'calendar_show_events',
                'calendar_show_tasks',
                'calendar_show_commitments',
                'calendar_show_worship_obligatory',
                'calendar_show_worship_mustahab',
                'hijri_offset',
                'snooze_max_quota',
                'coalescing_window_minutes',
                'max_non_essential_per_hour',
                'digest_mode',
                'user_name',
              ],
            ),
            ToolParameter(
              name: 'value',
              descriptionFa:
                  'مقدار جدید. برای کلیدهای بله/خیر فقط true یا false؛ برای ساعت فرمت HH:MM؛ برای عدد، عدد صحیح.',
              type: 'string',
              isRequired: true,
            ),
          ],
        );

  static const String _faDigits = '۰۱۲۳۴۵۶۷۸۹';

  static String _toEnglishDigits(String input) {
    var out = input;
    for (var i = 0; i < 10; i++) {
      out = out.replaceAll(_faDigits[i], i.toString());
    }
    return out;
  }

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    final key = args['key']?.toString().trim() ?? '';
    final rawValue = args['value']?.toString().trim() ?? '';

    if (key.isEmpty || rawValue.isEmpty) {
      return AgentToolResult.failure(
        toolName: name,
        errorMessage:
            'هم key و هم value الزامی هستند و هیچ تنطیمی تغییر نکرد.',
      );
    }

    // دفاع لایه‌ای: پیام صریح برای کلیدهای حساس، حتی قبل از بررسی اجازه‌نامه.
    if (key.startsWith('module_') ||
        key.startsWith('ai_') ||
        key.contains('consent') ||
        key.contains('gender')) {
      return AgentToolResult.failure(
        toolName: name,
        errorMessage:
            'تغییر «$key» از طریق دستیار ممنوع است (روشن/خاموش کردن ماژول‌ها، تنطیمات هوش مصنوعی و رضایت‌ها فقط دست خود کاربر است). از کاربر بخواه خودش از بخش تنطیمات این کار را انجام دهد.',
      );
    }

    final rule = _allowedPrefs[key];
    if (rule == null) {
      return AgentToolResult.failure(
        toolName: name,
        errorMessage:
            'کلید «$key» در فهرست تنطیمات مجاز دستیار نیست و هیچ چیزی تغییر نکرد. کلیدهای مجاز: ${_allowedPrefs.keys.join(', ')}',
      );
    }

    // نرمال‌سازی مقدار بر اساس نوع کلید
    Object normalized;
    switch (rule.kind) {
      case 'bool':
        final v = _toEnglishDigits(rawValue.toLowerCase());
        if (v == 'true' || v == '1' || v == 'بله' || v == 'روشن' || v == 'yes') {
          normalized = true;
        } else if (v == 'false' ||
            v == '0' ||
            v == 'خیر' ||
            v == 'خاموش' ||
            v == 'no') {
          normalized = false;
        } else {
          return AgentToolResult.failure(
            toolName: name,
            errorMessage:
                'مقدار «$rawValue» برای «${rule.labelFa}» معتبر نیست؛ فقط true یا false قابل قبول است.',
          );
        }
        break;
      case 'int':
        final parsed = int.tryParse(_toEnglishDigits(rawValue));
        if (parsed == null) {
          return AgentToolResult.failure(
            toolName: name,
            errorMessage:
                'مقدار «$rawValue» برای «${rule.labelFa}» عدد نیست.',
          );
        }
        if ((rule.min != null && parsed < rule.min!) ||
            (rule.max != null && parsed > rule.max!)) {
          return AgentToolResult.failure(
            toolName: name,
            errorMessage:
                'مقدار «${rule.labelFa}» باید بین ${rule.min} تا ${rule.max} باشد؛ $parsed خارج از بازه است.',
          );
        }
        normalized = parsed;
        break;
      case 'time':
        final cleaned = _toEnglishDigits(rawValue).replaceAll('.', ':');
        final match = RegExp(r'^(\d{1,2}):(\d{1,2})$').firstMatch(cleaned);
        final h = match == null ? null : int.tryParse(match.group(1)!);
        final m = match == null ? null : int.tryParse(match.group(2)!);
        if (h == null || m == null || h > 23 || m > 59) {
          return AgentToolResult.failure(
            toolName: name,
            errorMessage:
                'ساعت «$rawValue» معتبر نیست؛ فرمت صحیح HH:MM است (مثال 23:30).',
          );
        }
        normalized =
            '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
        break;
      default:
        if (rawValue.length > 60) {
          return AgentToolResult.failure(
            toolName: name,
            errorMessage: 'مقدار «${rule.labelFa}» بیش از حد بلند است.',
          );
        }
        normalized = rawValue;
    }

    final service = SettingsService.instance;
    final oldValue = service.get<String>(key);

    // از SettingsService عبور می‌کنیم (نه SQL خام و نه حتی فرمان setting.update):
    // تنها این مسیر اعتبارسنجی رجیستری، به‌روزرسانی کش درون‌حافظه، بالابردن
    // revision و ریفرش دیبانس‌شدهٔ اجندا را یکجا انجام می‌دهد. نوشتن مستقیم در
    // app_settings تنظیم را ذخیره می‌کرد ولی UI تا ریستارت مقدار قدیم را نشان می‌داد.
    bool ok;
    try {
      ok = await service.set(key, normalized);
    } catch (e) {
      return AgentToolResult.failure(
        toolName: name,
        errorMessage: 'ذخیرهٔ تنظیم «${rule.labelFa}» با خطا متوقف شد: $e',
      );
    }

    if (!ok) {
      return AgentToolResult.failure(
        toolName: name,
        errorMessage:
            'تنظیم «${rule.labelFa}» ذخیره نشد (مقدار توسط رجیستری تنظیمات رد شد یا این کلید در این نسخه وجود ندارد). مقدار قبلی دست‌نخورده ماند.',
      );
    }

    return AgentToolResult.success(
      toolName: name,
      data: {
        'key': key,
        'labelFa': rule.labelFa,
        'oldValue': oldValue,
        'newValue': normalized.toString(),
      },
      summaryFa:
          'تنظیم «${rule.labelFa}» از «$oldValue» به «${normalized.toString()}» تغییر کرد و اعمال شد.',
    );
  }
}

/// ۴. ابزار لغو و بازگردانی آخرین اقدام دستیار
class UndoLastActionTool extends AgentTool {
  const UndoLastActionTool()
      : super(
          name: 'undo_last_action',
          categoryFa: 'سیستم و مدیریت',
          titleFa: 'بازگردانی آخرین اقدام دستیار',
          descriptionFa:
              'آخرین تغییر ایجادشده توسط دستیار (مانند ساخت روتین، هدف، یادداشت یا تغییر تنظیمات) را لغو کرده و به حالت قبل برمی‌گرداند.',
          policy: ToolPolicy.actionDirect,
        );

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    final outcome = await AgentJournal.instance.undoLast();
    if (!outcome.success) {
      return AgentToolResult.failure(
        toolName: name,
        errorMessage: outcome.messageFa,
      );
    }
    return AgentToolResult.success(
      toolName: name,
      data: {'status': 'undone'},
      summaryFa: outcome.messageFa,
    );
  }
}

/// ۵. ابزار ارجاع و تحویل گفتگو به دستیار دیگر (T36)
class HandoffToPersonaTool extends KernelCommandTool {
  const HandoffToPersonaTool()
      : super(
          name: 'handoff_to_persona',
          categoryFa: 'سیستم و ناوبری',
          titleFa: 'ارجاع به دستیار متخصص دیگر',
          descriptionFa:
              'وقتی موضوع درخواست کاربر به تخصص یک دستیار دیگر (مانند خواب، ورزش، کنکور، دروس، اهداف، سلامت یا عبادات) مربوط می‌شود، گفتگو را به آن دستیار واگذار کن.',
          commandId: 'assistant.handoff',
          policy: ToolPolicy.readOnly,
          parameters: const [
            ToolParameter(
              name: 'personaId',
              descriptionFa:
                  'شناسه دستیار مقصد: global, worship, konkur, courses, sports, wellbeing, goals, sleep, reflection, cycle, health',
              type: 'string',
              isRequired: true,
              allowedValues: [
                'global',
                'worship',
                'konkur',
                'courses',
                'sports',
                'wellbeing',
                'goals',
                'sleep',
                'reflection',
                'cycle',
                'health',
              ],
            ),
            ToolParameter(
              name: 'reasonFa',
              descriptionFa: 'دلیل کوتاه ارجاع به فارسی',
              type: 'string',
            ),
          ],
        );

  @override
  Future<List<PlanStep>> buildSteps(Map<String, dynamic> args) async {
    final personaId =
        KernelCommandTool.optionalString(args['personaId']) ?? 'global';
    final reasonFa = KernelCommandTool.optionalString(args['reasonFa']) ??
        'تخصص بیشتر دستیار مقصد';

    return <PlanStep>[
      PlanStep(
        commandId: commandId,
        payload: <String, dynamic>{
          'personaId': personaId,
          'reasonFa': reasonFa,
          'carryHistory': true,
        },
        note: 'ارجاع خودکار توسط دستیار ریتمو',
      ),
    ];
  }

  @override
  String buildSummaryFa(Map<String, dynamic> args, Map<String, dynamic> output) {
    final personaId =
        KernelCommandTool.optionalString(args['personaId']) ?? 'global';
    final reasonFa = KernelCommandTool.optionalString(args['reasonFa']);
    final reasonSuffix =
        (reasonFa != null && reasonFa.isNotEmpty) ? ' (علت: $reasonFa)' : '';
    return 'گفتگو به دستیار «$personaId» ارجاع داده شد$reasonSuffix.';
  }
}
