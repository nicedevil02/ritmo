import 'package:ritmo/core/ai/agent/agent_tool.dart';
import 'package:ritmo/core/ai/agent/catalog/kernel_command_tool.dart';
import 'package:ritmo/core/domain/commands/command_plan.dart';
import 'package:ritmo/core/domain/commands/param_spec.dart';
import 'package:ritmo/core/domain/commands/ritmo_command.dart';

/// پل‌زن خودکار برای ساخت ابزار ایجنت (AgentTool) از روی یک فرمان رجیسترشده (RitmoCommand)
class CommandToolBridge extends KernelCommandTool {
  CommandToolBridge({
    required super.name,
    required super.categoryFa,
    required super.titleFa,
    required super.descriptionFa,
    required super.commandId,
    super.policy = ToolPolicy.actionDirect,
    super.parameters = const [],
    super.personaId = 'global',
  });

  /// ساخت خودکار ابزار ایجنت از روی تعریف فرمان
  factory CommandToolBridge.fromCommand(
    RitmoCommand command, {
    String? customToolName,
    String? categoryFa,
    String personaId = 'global',
  }) {
    final toolName = customToolName ?? _toToolName(command.id);
    final params = <ToolParameter>[];

    command.params.forEach((name, spec) {
      params.add(ToolParameter(
        name: name,
        descriptionFa: spec.labelFa,
        type: _mapParamType(spec.type),
        isRequired: spec.required,
        allowedValues: spec.allowed,
      ));
    });

    final policy = (command.sensitivity == Sensitivity.confirm ||
            command.sensitivity == Sensitivity.sensitive)
        ? ToolPolicy.actionDirect
        : ToolPolicy.actionDirect;

    final cat = categoryFa ?? _domainToCategoryFa(command.touches.firstOrNull);

    return CommandToolBridge(
      name: toolName,
      categoryFa: cat,
      titleFa: command.humanTitle,
      descriptionFa: command.humanDescriptionFa,
      commandId: command.id,
      policy: policy,
      parameters: params,
      personaId: personaId,
    );
  }

  static String _toToolName(String commandId) {
    return commandId.replaceAll('.', '_');
  }

  static String _mapParamType(ParamType type) {
    switch (type) {
      case ParamType.text:
      case ParamType.isoDate:
      case ParamType.isoDateTime:
      case ParamType.timeOfDay:
      case ParamType.idRef:
      case ParamType.enumeration:
        return 'string';
      case ParamType.integer:
        return 'int';
      case ParamType.decimal:
        return 'double';
      case ParamType.boolean:
        return 'bool';
      case ParamType.list:
        return 'list';
    }
  }

  static String _domainToCategoryFa(DataDomain? domain) {
    if (domain == null) return 'سیستم و مدیریت';
    switch (domain) {
      case DataDomain.routines:
        return 'روتین‌ها و عادات';
      case DataDomain.goals:
        return 'اهداف و برنامه‌ها';
      case DataDomain.worship:
        return 'عبادات و معنویت';
      case DataDomain.konkur:
      case DataDomain.courses:
        return 'یادگیری و دروس';
      case DataDomain.sleep:
      case DataDomain.energy:
      case DataDomain.reflection:
        return 'خواب و انرژی';
      case DataDomain.sports:
        return 'ورزش و تحرک';
      case DataDomain.notes:
        return 'یادداشت‌ها';
      case DataDomain.cycle:
      case DataDomain.medical:
        return 'سلامت فردی';
    }
  }

  @override
  Future<List<PlanStep>> buildSteps(Map<String, dynamic> args) async {
    return [
      PlanStep(
        commandId: commandId,
        payload: Map<String, dynamic>.from(args),
      ),
    ];
  }

  @override
  String buildSummaryFa(Map<String, dynamic> args, Map<String, dynamic> output) {
    return '$titleFa با موفقیت انجام شد.';
  }
}
