import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/agent/agent_tool.dart';
import 'package:ritmo/core/ai/agent/agent_tool_protocol.dart';

class _DummyTool extends AgentTool {
  const _DummyTool()
      : super(
          name: 'get_daily_summary',
          categoryFa: 'گزارش',
          titleFa: 'دریافت گزارش روزانه',
          descriptionFa: 'دریافت خلاصه فعالیت‌های روز',
          parameters: const [
            ToolParameter(
              name: 'date',
              descriptionFa: 'تاریخ مورد نظر',
              type: 'string',
              isRequired: true,
            ),
          ],
        );

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    return AgentToolResult.success(
      toolName: name,
      data: {'status': 'ok'},
      summaryFa: 'گزارش روزانه دریافت شد',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WEB-30: Web Bridge Tool Prompt Instructions', () {
    test('buildWebBridgeToolPrompt produces correct XML tag structure and guidelines', () {
      final prompt = AgentToolProtocol.buildWebBridgeToolPrompt([const _DummyTool()]);

      expect(prompt, contains('=== [راهنمای فراخوانی ابزارهای ریتمو در پل وب] ==='));
      expect(prompt, contains('<tool_call>'));
      expect(prompt, contains('</tool_call>'));
      expect(prompt, contains('`get_daily_summary`'));
      expect(prompt, contains('date*'));
      expect(prompt, contains('پس از بستن تگ </tool_call> متن اضافی دیگری ننویس'));
    });

    test('buildWebBridgeToolPrompt handles empty tool list safely', () {
      final prompt = AgentToolProtocol.buildWebBridgeToolPrompt([]);

      expect(prompt, contains('<tool_call>'));
      expect(prompt, contains('فهرست ابزارهای مجاز:'));
    });
  });
}
