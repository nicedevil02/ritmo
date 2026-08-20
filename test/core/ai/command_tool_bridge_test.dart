import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/agent/catalog/command_tool_bridge.dart';
import 'package:ritmo/core/domain/commands/param_spec.dart';
import 'package:ritmo/core/domain/commands/ritmo_command.dart';
import 'package:ritmo/core/domain/commands/command_plan.dart';

class _SampleDummyCommand extends RitmoCommand {
  const _SampleDummyCommand();

  @override
  String get id => 'dummy.createItem';

  @override
  String get humanTitle => 'ایجاد آیتم تستی';

  @override
  String get humanDescriptionFa => 'یک آیتم آزمایشی می‌سازد';

  @override
  Sensitivity get sensitivity => Sensitivity.safe;

  @override
  Set<DataDomain> get touches => {DataDomain.routines};

  @override
  Map<String, ParamSpec> get params => {
    'title': const ParamSpec(
      type: ParamType.text,
      labelFa: 'عنوان آیتم',
      required: true,
    ),
    'duration': const ParamSpec(
      type: ParamType.integer,
      labelFa: 'مدت زمان',
      required: false,
      min: 1,
    ),
    'type': const ParamSpec(
      type: ParamType.enumeration,
      labelFa: 'نوع آیتم',
      required: false,
      allowed: ['NORMAL', 'FAST'],
    ),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async =>
      const PlanDiff(kind: DiffKind.create, entityLabelFa: 'آیتم تستی');

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async =>
      CommandResult.ok(commandId: id);

  @override
  Future<CommandResult?> undo(
    AgentCommandContext ctx,
    Map<String, dynamic> inverseData,
  ) async => null;
}

void main() {
  group('CommandToolBridge Dynamic Tool Generation Tests (T26)', () {
    test(
      'creates valid AgentTool with mapped parameters from RitmoCommand',
      () {
        const cmd = _SampleDummyCommand();
        final tool = CommandToolBridge.fromCommand(cmd);

        expect(tool.name, 'dummy_createItem');
        expect(tool.titleFa, 'ایجاد آیتم تستی');
        expect(tool.descriptionFa, 'یک آیتم آزمایشی می‌سازد');
        expect(tool.categoryFa, 'روتین‌ها و عادات');
        expect(tool.parameters.length, 3);

        final titleParam = tool.parameters.firstWhere((p) => p.name == 'title');
        expect(titleParam.type, 'string');
        expect(titleParam.isRequired, isTrue);

        final durationParam = tool.parameters.firstWhere(
          (p) => p.name == 'duration',
        );
        expect(durationParam.type, 'int');
        expect(durationParam.isRequired, isFalse);

        final typeParam = tool.parameters.firstWhere((p) => p.name == 'type');
        expect(typeParam.type, 'string');
        expect(typeParam.allowedValues, ['NORMAL', 'FAST']);
      },
    );

    test('buildSteps generates correct PlanStep payload', () async {
      const cmd = _SampleDummyCommand();
      final tool = CommandToolBridge.fromCommand(cmd);

      final steps = await tool.buildSteps({
        'title': 'Morning Run',
        'duration': 30,
      });
      expect(steps.length, 1);
      expect(steps.first.commandId, 'dummy.createItem');
      expect(steps.first.payload['title'], 'Morning Run');
      expect(steps.first.payload['duration'], 30);
    });
  });
}
