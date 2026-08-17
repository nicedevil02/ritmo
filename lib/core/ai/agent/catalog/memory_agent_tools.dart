import 'package:flutter/foundation.dart';
import 'package:ritmo/core/ai/agent/agent_tool.dart';
import 'package:ritmo/core/ai/agent/catalog/kernel_command_tool.dart';
import 'package:ritmo/core/ai/memory/ai_memory_service.dart';
import 'package:ritmo/core/ai/memory/memory_models.dart';

/// دامنه‌های مجاز حافطه (همان لیستی که pruneMemories مدیریت می‌کند).
/// دامنه خارج از این لیست به core تبدیل می‌شود؛ وگرنه رکورد در هیچ سقفی
/// شمرده نمی‌شود و برای همیشه می‌ماند.
const List<String> kMemoryDomains = <String>[
  'core',
  'health',
  'cycle',
  'worship',
  'wellbeing',
  'goals',
  'konkur',
  'courses',
  'sports',
];

/// دامنه‌هایی که محتوایشان اجبارا حساس علامت می‌خورد، پس در گفتگوی
/// دامنه‌های دیگر بازخوانی نمی‌شود.
const Set<String> _sensitiveDomains = <String>{'cycle', 'health'};

String _normalizeDomain(dynamic value) {
  final raw = KernelCommandTool.optionalString(value);
  if (raw == null) return 'core';
  final lower = raw.toLowerCase();
  return kMemoryDomains.contains(lower) ? lower : 'core';
}

/// ثبت یک واقعیت درباره کاربر (فاز ۵ · P5-2)
///
/// چرا این ابزار جایگزین تگ `<memory_ops>` است: آن تگ متنی بود که مدل
/// می‌نوشت و امید داشت یک پارسر جایی آن را بگیرد؛ اگر فرمت خراب می‌شد
/// داده بی‌صدا گم می‌شد و مدل باز می‌گفت «یادم موند». این‌جا نوشتن واقعی
/// انجام و بعد از نوشتن بازخوانی تأییدی می‌شود؛ اگر رکورد دیده نشود، نتیجه
/// failure است و مدل نمی‌تواند به کاربر بگوید ذخیره شد.
class RememberFactTool extends AgentTool {
  const RememberFactTool()
      : super(
          name: 'remember_fact',
          categoryFa: 'حافطه دستیار',
          titleFa: 'به خاطر سپردن یک واقعیت',
          descriptionFa:
              'یک واقعیت پایدار درباره کاربر را در حافطه بلندمدت ثبت می‌کند. '
              'فقط وقتی استفاده کن که کاربر صریحا خواسته چیزی را یادت بماند یا '
              'واقعیتی را گفته که در گفتگوهای بعدی هم معنا دارد (مثل محدودیت، '
              'علاقه، ساعت کاری ثابت). برای داده یک‌بارمصرف یا محتوای گفتگو '
              'استفاده نکن. متن را جمله کوتاه سوم‌شخص فارسی بنویس.',
          policy: ToolPolicy.actionDirect,
          parameters: const <ToolParameter>[
            ToolParameter(
              name: 'content',
              descriptionFa:
                  'متن واقعیت؛ جمله کوتاه سوم‌شخص فارسی (حداکثر ۳۰۰ نویسه).',
              type: 'string',
              isRequired: true,
            ),
            ToolParameter(
              name: 'type',
              descriptionFa:
                  'جنس واقعیت. پیش‌فرض preference است.',
              type: 'string',
              defaultValue: 'preference',
              allowedValues: <String>[
                'identity',
                'preference',
                'constraint',
                'goal',
                'episode',
                'insight',
              ],
            ),
            ToolParameter(
              name: 'domain',
              descriptionFa:
                  'حوزه مربوطه. پیش‌فرض core (عمومی) است.',
              type: 'string',
              defaultValue: 'core',
              allowedValues: kMemoryDomains,
            ),
            ToolParameter(
              name: 'importance',
              descriptionFa:
                  'اهمیت ۱ تا ۱۰. عدد ۱۰ رکورد را پین می‌کند و از فراموشی خودکار در می‌آورد؛ پس فقط وقتی کاربر صریحا تاکید کرده از ۱۰ استفاده کن.',
              type: 'int',
              defaultValue: 8,
            ),
          ],
        );

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    final raw = KernelCommandTool.optionalString(args['content']);
    if (raw == null) {
      return AgentToolResult.failure(
        toolName: name,
        errorMessage:
            '«content» الزامی است و متنی برای ذخیره فرستاده نشد؛ هیچ چیزی ذخیره نشد.',
      );
    }

    // همان پاکسازی‌ای که applyOperations انجام می‌دهد، تا بتوانیم بعد از نوشتن
    // دقیقا همین متن را دنبال کنیم.
    final stripped = raw.replaceAll(RegExp('<[^>]*>'), '').trim();
    final content =
        stripped.length > 300 ? stripped.substring(0, 300) : stripped;
    if (content.isEmpty) {
      return AgentToolResult.failure(
        toolName: name,
        errorMessage:
            'متن واقعیت بعد از پاکسازی خالی شد، پس چیزی ذخیره نشد.',
      );
    }

    final service = AiMemoryService.instance;

    final enabled = await service.isMemoryEnabled();
    if (!enabled) {
      return AgentToolResult.failure(
        toolName: name,
        errorMessage:
            'حافطه دستیار در تنطیمات خاموش است، پس چیزی ذخیره نشد. به کاربر بگو اول از تنطیمات حافطه را روشن کند.',
      );
    }

    final domain = _normalizeDomain(args['domain']);
    final typeName =
        KernelCommandTool.optionalString(args['type'])?.toLowerCase() ??
            'preference';
    final type = MemoryType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => MemoryType.preference,
    );
    final importance = KernelCommandTool.clampedInt(args['importance'], 8, 1, 10);
    final sensitive = _sensitiveDomains.contains(domain);

    try {
      await service.applyOperations(<MemoryOp>[
        MemoryOp(
          op: 'ADD',
          content: content,
          type: type,
          domain: domain,
          importance: importance,
          sensitive: sensitive,
        ),
      ]);
    } catch (e) {
      return AgentToolResult.failure(
        toolName: name,
        errorMessage: 'ذخیره در حافطه با خطا متوقف شد: $e',
      );
    }

    // تأیید بعد از نوشتن. applyOperations خطاها را درون خودش فرو می‌دهد، پس
    // تنها راه مطمئن شدن، خواندن دوباره است.
    var verified = false;
    try {
      final probe = content.length > 40 ? content.substring(0, 40) : content;
      final entries = await service.retrieve(domain: domain, query: probe);
      verified = entries.any((m) => m.content == content);
    } catch (e) {
      debugPrint('[MemoryTool] verification read failed: $e');
    }

    if (!verified) {
      return AgentToolResult.failure(
        toolName: name,
        errorMessage:
            'رکورد حافطه نوشته شد ولی در بازخوانی تأییدی دیده نشد؛ به کاربر نگو که ذخیره شد.',
      );
    }

    debugPrint(
        '[MemoryTool] remember_fact -> ok | domain=$domain | type=${type.name} | importance=$importance');

    final pinnedNote = importance >= 10 ? ' (پین‌شده)' : '';
    return AgentToolResult.success(
      toolName: name,
      data: <String, dynamic>{
        'content': content,
        'domain': domain,
        'type': type.name,
        'importance': importance,
        'sensitive': sensitive,
        'pinned': importance >= 10,
        'isUndoable': false,
      },
      summaryFa:
          'در حافطه ثبت شد$pinnedNote: «$content» — حوزه: $domain. کاربر می‌تواند از تنطیمات حافطه آن را حذف کند.',
    );
  }
}

/// بازخوانی واقعیت‌های قبلی درباره کاربر (فاز ۵ · P5-2)
class RecallFactsTool extends AgentTool {
  const RecallFactsTool()
      : super(
          name: 'recall_facts',
          categoryFa: 'حافطه دستیار',
          titleFa: 'بازخوانی حافطه',
          descriptionFa:
              'واقعیت‌های ذخیره‌شده درباره کاربر را براساس یک عبارت جستجو برمی‌گرداند. '
              'وقتی استفاده کن که مطمئن نیستی قبلا درباره موضوعی چه می‌دانی یا '
              'کاربر پرسید «چی از من یادت هست؟». هرگز حافطه را حدس نزن.',
          policy: ToolPolicy.readOnly,
          parameters: const <ToolParameter>[
            ToolParameter(
              name: 'query',
              descriptionFa:
                  'عبارت یا موضوع مورد جستجو (مثلا: خواب، ورزش، محدودیت غذایی).',
              type: 'string',
              isRequired: true,
            ),
            ToolParameter(
              name: 'domain',
              descriptionFa:
                  'حوزه جستجو. پیش‌فرض core است که همه حوزه‌ها را می‌بیند.',
              type: 'string',
              defaultValue: 'core',
              allowedValues: kMemoryDomains,
            ),
            ToolParameter(
              name: 'limit',
              descriptionFa: 'حداکثر تعداد رکورد خروجی (۱ تا ۱۵، پیش‌فرض ۵).',
              type: 'int',
              defaultValue: 5,
            ),
          ],
        );

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    final query = KernelCommandTool.optionalString(args['query']);
    if (query == null) {
      return AgentToolResult.failure(
        toolName: name,
        errorMessage: '«query» الزامی است؛ موضوع جستجو را بفرست.',
      );
    }

    final service = AiMemoryService.instance;
    if (!await service.isMemoryEnabled()) {
      return AgentToolResult.failure(
        toolName: name,
        errorMessage:
            'حافطه دستیار خاموش است، پس هیچ حافطه‌ای در دسترس نیست. چیزی از حافطه نقل نکن.',
      );
    }

    final domain = _normalizeDomain(args['domain']);
    final limit = KernelCommandTool.clampedInt(args['limit'], 5, 1, 15);

    List<MemoryEntry> entries;
    try {
      entries = await service.retrieve(domain: domain, query: query);
    } catch (e) {
      return AgentToolResult.failure(
        toolName: name,
        errorMessage: 'خواندن حافطه با خطا مواجه شد: $e',
      );
    }

    final selected = entries.take(limit).toList();

    debugPrint(
        '[MemoryTool] recall_facts -> ${selected.length}/${entries.length} | domain=$domain');

    if (selected.isEmpty) {
      return AgentToolResult.success(
        toolName: name,
        data: <String, dynamic>{'facts': <Map<String, dynamic>>[], 'total': 0},
        summaryFa:
            'درباره «$query» هیچ واقعیتی در حافطه نیست. چیزی از خودت نساز؛ اگر لازم است از کاربر بپرس.',
      );
    }

    final facts = selected
        .map((m) => <String, dynamic>{
              'content': m.content,
              'type': m.type.name,
              'domain': m.domain,
              'importance': m.importance,
              'pinned': m.pinned,
            })
        .toList();

    final preview = selected.take(3).map((m) => '«${m.content}»').join('، ');
    return AgentToolResult.success(
      toolName: name,
      data: <String, dynamic>{'facts': facts, 'total': entries.length},
      summaryFa:
          '${selected.length} واقعیت مرتبط با «$query» پیدا شد: $preview',
    );
  }
}
