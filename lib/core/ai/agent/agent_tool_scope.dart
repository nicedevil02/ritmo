import 'package:flutter/foundation.dart';
import 'package:ritmo/core/ai/agent/agent_tool.dart';
import 'package:ritmo/core/ai/agent/agent_tool_registry.dart';
import 'package:ritmo/core/domain/commands/ritmo_command.dart';
import 'package:ritmo/core/domain/personas/assistant_persona.dart';
import 'package:ritmo/core/domain/personas/persona_registry.dart';

/// شرط مجاز بودن یک ابزار برای یک پرسونا
class ToolScopeRequirement {
  const ToolScopeRequirement.command(this.commandId)
      : readDomain = null,
        isUniversal = false;

  const ToolScopeRequirement.read(this.readDomain)
      : commandId = null,
        isUniversal = false;

  const ToolScopeRequirement.universal()
      : commandId = null,
        readDomain = null,
        isUniversal = true;

  /// ابزار نوشتنی: فقط وقتی مجاز است که این فرمان در commandIds پرسونا باشد
  final String? commandId;

  /// ابزار خواندنی: فقط وقتی مجاز است که این دامنه در reads پرسونا باشد
  final DataDomain? readDomain;

  /// ابزار زیرساختی (برای همه پرسوناها مجاز)
  final bool isUniversal;
}

/// محدوده اختیارات ابزار بر اساس پرسونا (فاز ۵ · P5-1)
///
/// مسئله‌ای که حل می‌کند: تا امروز همه ـ ۲۳ ـ ابزار به هر دستیاری تزریق
/// می‌شد؛ پس دستیار خواب هم فهرست ابزار ورزشی را می‌دید و وقتی مدل
/// وسوسه می‌شد و صدایش می‌زد، PersonaGate در لایه فرمان با خطای خشک
/// رد می‌کرد. این‌جا همان مرز یک پله جلوتر می‌آید: ابزار غیرمجاز از اول
/// در پرامپت نمی‌آید و اگر مدل باز هم صدایش زد، حلقه با پیام فارسی روشن
/// رد می‌کند (نه با خطای فنی).
///
/// منبع حقیقت: خود `AssistantPersona` ـ `reads` و `commandIds` ـ نه یک لیست موازی.
/// پس اگر پرسونایی فردا فرمان جدیدی بگیرد، ابزارش هم خودکار باز می‌شود.
class AgentToolScope {
  AgentToolScope._();

  static final AgentToolScope instance = AgentToolScope._();

  /// پرسونای فعال این گفتگو. حلقه ایجنت قبل از شروع آن را تنطیم می‌کند
  /// تا لایه‌هایی مثل پیش‌واکشی هم بدون تغییر امضای توابع بدانند محدوده کدام است.
  String activePersonaId = 'global';

  void setActivePersona(String personaId) {
    activePersonaId = personaId.trim().isEmpty ? 'global' : personaId.trim();
  }

  /// نگاشت ابزار → شرط دسترسی.
  ///
  /// هر ابزار جدیدی که اضافه می‌شود باید همین‌جا هم ثبت شود؛ وگرنه فقط
  /// برای پرسونای global باز می‌ماند و یک هشدار در لاگ ثبت می‌شود.
  static const Map<String, ToolScopeRequirement> requirements =
      <String, ToolScopeRequirement>{
    // ورزش
    'get_sports_history': ToolScopeRequirement.read(DataDomain.sports),
    'get_sports_plan': ToolScopeRequirement.read(DataDomain.sports),
    'log_sports_session': ToolScopeRequirement.command('sports.logSession'),

    // روتین
    'get_routines_overview': ToolScopeRequirement.read(DataDomain.routines),
    'get_routine_streak_stats': ToolScopeRequirement.read(DataDomain.routines),
    'create_new_routine': ToolScopeRequirement.command('routine.create'),
    'complete_routine': ToolScopeRequirement.command('routine.complete'),

    // برنامه روز
    'get_day_agenda': ToolScopeRequirement.read(DataDomain.routines),

    // خواب و انرژی
    'get_sleep_diagnostics': ToolScopeRequirement.read(DataDomain.sleep),
    'get_energy_trends': ToolScopeRequirement.read(DataDomain.energy),
    'log_energy_mood_level': ToolScopeRequirement.command('energy.log'),

    // اهداف
    'get_active_goals_summary': ToolScopeRequirement.read(DataDomain.goals),
    'create_goal_with_milestones': ToolScopeRequirement.command('goal.create'),

    // یادداشت
    'search_user_notes': ToolScopeRequirement.read(DataDomain.notes),
    'create_quick_note': ToolScopeRequirement.command('note.create'),

    // مطالعه و عبادت
    'get_study_progress_summary': ToolScopeRequirement.read(DataDomain.konkur),
    'get_worship_practices': ToolScopeRequirement.read(DataDomain.worship),
    'create_worship_practice': ToolScopeRequirement.read(DataDomain.worship),

    // سیستم
    'navigate_to_app_screen': ToolScopeRequirement.command('app.openPage'),
    'update_app_preference': ToolScopeRequirement.command('setting.update'),

    // زیرساخت: برای همه پرسوناها لازم است
    'verify_state': ToolScopeRequirement.universal(),
    'ask_user': ToolScopeRequirement.universal(),
    'remember_fact': ToolScopeRequirement.universal(),
    'recall_facts': ToolScopeRequirement.universal(),
    'undo_last_action': ToolScopeRequirement.universal(),
  };

  AssistantPersona? _persona(String personaId) {
    final id = personaId.trim().isEmpty ? 'global' : personaId.trim();
    return PersonaRegistry.instance.getPersona(id);
  }

  /// نام ابزارهای مجاز این پرسونا.
  ///
  /// راهبرد fail-open عمدی: اگر پرسونا ثبت نشده باشد (مثلا رجیستری
  /// هنوز مقداردهی نشده)، همه ابزارها باز می‌مانند و فقط هشدار لاگ می‌شود.
  /// بستن همه ابزارها در این حالت، دستیار را بی‌صدا فلج می‌کرد. در عوض
  /// مرز واقعی نوشتن همچنان در PersonaGate و AgentPolicyGate پابرجاست.
  Set<String> allowedToolNames(String personaId) {
    final all = AgentToolRegistry.instance.allTools;
    final persona = _persona(personaId);
    if (persona == null) {
      debugPrint(
          '[AgentScope] persona "$personaId" is not registered -> fail-open (${all.length} tools)');
      return all.map((t) => t.name).toSet();
    }

    final allowed = <String>{};
    for (final tool in all) {
      if (_isToolAllowed(tool, persona)) allowed.add(tool.name);
    }
    return allowed;
  }

  /// ابزارهای مجاز (شیء‌های کامل، برای ساخت پرامپت)
  List<AgentTool> allowedTools(String personaId) {
    final persona = _persona(personaId);
    final all = AgentToolRegistry.instance.allTools;
    if (persona == null) return all;
    return all.where((t) => _isToolAllowed(t, persona)).toList();
  }

  bool hasRequirement(String toolName) => requirements.containsKey(toolName);

  bool isAllowed(String personaId, String toolName) {
    final persona = _persona(personaId);
    if (persona == null) return true;
    final tool = AgentToolRegistry.instance.getTool(toolName);
    if (tool == null) return false;
    return _isToolAllowed(tool, persona);
  }

  bool _isToolAllowed(AgentTool tool, AssistantPersona persona) {
    final requirement = requirements[tool.name];
    if (requirement == null) {
      // ابزار ناشناخته برای نقشه: فقط پرسونای سراسری.
      if (persona.id != 'global') {
        debugPrint(
            '[AgentScope] tool "${tool.name}" has no scope mapping -> hidden from persona "${persona.id}"');
      }
      return persona.id == 'global';
    }

    if (requirement.isUniversal) return true;

    final commandId = requirement.commandId;
    if (commandId != null) {
      return persona.commandIds.contains(commandId);
    }

    final domain = requirement.readDomain;
    if (domain != null) {
      return persona.reads.contains(domain);
    }

    return false;
  }

  /// بلوک راهنمای ابزارها فقط با ابزارهای مجاز این پرسونا
  String promptFor(String personaId) {
    final persona = _persona(personaId);
    final tools = allowedTools(personaId);
    if (persona == null ||
        tools.length == AgentToolRegistry.instance.count) {
      return AgentToolRegistry.instance.generateSystemToolsPrompt();
    }

    final buffer = StringBuffer();
    buffer.writeln('=== [ابزارهای عملیاتی در دسترس این دستیار] ===');
    buffer.writeln(
        'نقش فعال: ${persona.displayName}. فقط ابزارهای زیر برای این نقش مجازند؛ نام دیگری وجود ندارد و اگر صدایش بزنی رد می‌شود.');
    buffer.writeln('برای فراخوانی هر ابزار، از فرمت زیر استفاده کن:');
    buffer.writeln('<tool_call>');
    buffer.writeln('{"tool": "نام_ابزار", "parameters": {"پارامتر۱": "مقدار"}}');
    buffer.writeln('</tool_call>');

    if (tools.isEmpty) {
      buffer.writeln(
          '\nدر این نقش هیچ ابزاری فعال نیست؛ پس فقط با داده‌هایی که در متن داری پاسخ بده و عدد نساز.');
      return buffer.toString();
    }

    buffer.writeln('\nلیست ابزارهای مجاز:');
    final grouped = <String, List<AgentTool>>{};
    for (final tool in tools) {
      grouped.putIfAbsent(tool.categoryFa, () => <AgentTool>[]).add(tool);
    }
    grouped.forEach((category, list) {
      buffer.writeln('\nدسته: $category');
      for (final tool in list) {
        buffer.writeln(tool.toPromptDescription());
      }
    });

    return buffer.toString();
  }

  /// راهنمای فشرده و بهینه ابزارهای مجاز پرسونا برای صرفه‌جویی در توکن‌ها
  String compactPromptFor(String personaId, {bool isNativeToolsActive = false}) {
    final persona = _persona(personaId);
    final tools = allowedTools(personaId);
    final roleName = persona?.displayName ?? 'دستیار سراسری';

    if (isNativeToolsActive) {
      return 'نقش فعال: $roleName. ابزارهای مجاز به صورت ساخت‌یافته (Function Calling) تعریف شده‌اند.';
    }

    final buffer = StringBuffer();
    buffer.writeln('=== [ابزارهای مجاز نقش $roleName] ===');
    buffer.writeln(
        'برای فراخوانی هر ابزار، از فرمت <tool_call>{"tool": "نام", "parameters": {...}}</tool_call> استفاده کن.');

    if (tools.isEmpty) {
      buffer.writeln('\nدر این نقش هیچ ابزاری فعال نیست؛ پاسخ را با داده‌های موجود بده.');
      return buffer.toString();
    }

    buffer.writeln('\nفهرست ابزارها (* = پارامتر اجباری):');
    for (final tool in tools) {
      buffer.writeln(tool.toCompactPromptDescription());
    }

    return buffer.toString();
  }

  /// پیام رد فارسی وقتی مدل ابزار خارج از محدوده را صدا می‌زند
  String refusalReasonFa(String personaId, AgentTool tool) {
    final persona = _persona(personaId);
    final roleName = persona?.displayName ?? 'این دستیار';
    return 'ابزار «${tool.titleFa}» در محدوده اختیارات «$roleName» نیست، پس اجرا نشد و هیچ داده‌ای تغییر نکرد. اگر کاربر واقعا این را می‌خواهد، به او بگو از دستیار مربوطه استفاده کند؛ از خودت نتیجه نساز.';
  }
}
