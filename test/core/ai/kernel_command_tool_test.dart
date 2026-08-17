import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/agent/catalog/kernel_command_tool.dart';
import 'package:ritmo/core/domain/commands/command_plan.dart';
import 'package:ritmo/core/domain/commands/param_spec.dart';
import 'package:ritmo/core/domain/commands/ritmo_command.dart';
import 'package:ritmo/core/domain/commands/ritmo_command_bus.dart';

class _DummyEchoCommand extends RitmoCommand {
  const _DummyEchoCommand();

  @override
  String get id => 'test.echo';

  @override
  String get humanTitle => 'فرمان آزمایشی اکو';

  @override
  String get humanDescriptionFa => 'برای آزمایش باس';

  @override
  Sensitivity get sensitivity => Sensitivity.safe;

  @override
  Set<DataDomain> get touches => {DataDomain.notes};

  @override
  Map<String, ParamSpec> get params => {
        'message': const ParamSpec(
          type: ParamType.text,
          labelFa: 'پیام',
          required: true,
        ),
      };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async =>
      const PlanDiff(kind: DiffKind.noop, entityLabelFa: 'تست');

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    return CommandResult.ok(
      commandId: id,
      outputData: {'echo': ctx.payload['message']},
    );
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    return CommandResult.ok(commandId: id);
  }
}

class _DummyEchoKernelTool extends KernelCommandTool {
  const _DummyEchoKernelTool()
      : super(
          name: 'test_echo_tool',
          categoryFa: 'تست',
          titleFa: 'ابزار تست کرنل',
          descriptionFa: 'ابزار برای تست اتصال به باس فرمان',
          commandId: 'test.echo',
        );

  @override
  Future<List<PlanStep>> buildSteps(Map<String, dynamic> args) async {
    final msg = KernelCommandTool.optionalString(args['message']);
    if (msg == null || msg.isEmpty) {
      throw const ToolArgumentError('پیام الزامی است');
    }
    return [
      PlanStep(
        commandId: commandId,
        payload: {'message': msg},
      )
    ];
  }

  @override
  String buildSummaryFa(Map<String, dynamic> args, Map<String, dynamic> output) {
    return 'نتیجه: ${output['echo']}';
  }
}

void main() {
  group('KernelCommandTool Tests (T48)', () {
    setUpAll(() {
      RitmoCommandBus.instance.register(const _DummyEchoCommand());
    });

    const tool = _DummyEchoKernelTool();

    test('parses arguments with static helpers correctly', () {
      expect(KernelCommandTool.optionalString('  سلام  '), 'سلام');
      expect(KernelCommandTool.optionalString('   '), isNull);
      expect(KernelCommandTool.optionalString(null), isNull);

      expect(KernelCommandTool.clampedInt(15, 10, 1, 20), 15);
      expect(KernelCommandTool.clampedInt(0, 10, 1, 20), 1);
      expect(KernelCommandTool.clampedInt(50, 10, 1, 20), 20);
      expect(KernelCommandTool.clampedInt('invalid', 10, 1, 20), 10);
    });

    test('throws ToolArgumentError and returns failure on invalid input', () async {
      final res = await tool.execute({'message': ''});
      expect(res.isSuccess, isFalse);
      expect(res.errorMessage, contains('پیام الزامی است'));
    });
  });
}
