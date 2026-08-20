import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/agent/agent_tool.dart';

class _DummyValidatedTool extends AgentTool {
  const _DummyValidatedTool()
    : super(
        name: 'dummy_validated',
        categoryFa: 'تست',
        titleFa: 'ابزار تست اعتبارسنجی',
        descriptionFa: 'ابزار برای بررسی اعتبارسنجی پارامترها',
        parameters: const [
          ToolParameter(
            name: 'requiredField',
            descriptionFa: 'فیلد اجباری',
            type: 'string',
            isRequired: true,
          ),
          ToolParameter(
            name: 'withDefault',
            descriptionFa: 'فیلد با مقدار پیش‌فرض',
            type: 'int',
            defaultValue: 42,
          ),
          ToolParameter(
            name: 'withAllowed',
            descriptionFa: 'فیلد با مقادیر مجاز',
            type: 'string',
            allowedValues: ['optionA', 'optionB'],
          ),
        ],
      );

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    return AgentToolResult.success(
      toolName: name,
      data: args,
      summaryFa: 'موفق',
    );
  }
}

void main() {
  group('AgentToolValidator Tests (T46)', () {
    const tool = _DummyValidatedTool();

    test('fails when required parameter is missing or empty', () {
      final res1 = tool.validateArgs({});
      expect(res1.isValid, isFalse);
      expect(res1.errorMessageFa, contains('requiredField'));

      final res2 = tool.validateArgs({'requiredField': '   '});
      expect(res2.isValid, isFalse);
      expect(res2.errorMessageFa, contains('requiredField'));
    });

    test('applies default value when optional parameter is omitted', () {
      final res = tool.validateArgs({'requiredField': 'valid'});
      expect(res.isValid, isTrue);
      expect(res.validatedArgs['withDefault'], 42);
    });

    test('validates allowed values correctly', () {
      final validRes = tool.validateArgs({
        'requiredField': 'valid',
        'withAllowed': 'optionA',
      });
      expect(validRes.isValid, isTrue);

      final invalidRes = tool.validateArgs({
        'requiredField': 'valid',
        'withAllowed': 'optionC',
      });
      expect(invalidRes.isValid, isFalse);
      expect(invalidRes.errorMessageFa, contains('optionC'));
    });
  });
}
