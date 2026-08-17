import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/agent/agent_tool.dart';
import 'package:ritmo/core/ai/agent/agent_tool_argument_validator.dart';

class _ValidationTestTool extends AgentTool {
  const _ValidationTestTool()
      : super(
          name: 'val_tool',
          categoryFa: 'تست',
          titleFa: 'ابزار تست اعتبارسنجی',
          descriptionFa: 'توضیحات',
          parameters: const [
            ToolParameter(
              name: 'title',
              descriptionFa: 'عنوان',
              type: 'string',
              isRequired: true,
            ),
            ToolParameter(
              name: 'days',
              descriptionFa: 'تعداد روز',
              type: 'int',
              defaultValue: 7,
            ),
            ToolParameter(
              name: 'rating',
              descriptionFa: 'امتیاز',
              type: 'double',
            ),
            ToolParameter(
              name: 'active',
              descriptionFa: 'فعال بودن',
              type: 'bool',
              defaultValue: false,
            ),
            ToolParameter(
              name: 'priority',
              descriptionFa: 'اولویت',
              type: 'string',
              allowedValues: ['LOW', 'MEDIUM', 'HIGH'],
              defaultValue: 'MEDIUM',
            ),
          ],
        );

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    return AgentToolResult.success(toolName: name, data: null, summaryFa: 'ok');
  }
}

void main() {
  group('AgentToolArgumentValidator Tests (T18)', () {
    const tool = _ValidationTestTool();

    test('validates and applies type coercion for numbers and bools', () {
      final res = AgentToolArgumentValidator.validate(tool, {
        'title': 'Test Item',
        'days': '14', // string to int
        'rating': '4.5', // string to double
        'active': 'true', // string to bool
        'priority': 'high', // case-insensitive match
      });

      expect(res.isValid, isTrue);
      expect(res.sanitizedArgs['title'], 'Test Item');
      expect(res.sanitizedArgs['days'], 14);
      expect(res.sanitizedArgs['rating'], 4.5);
      expect(res.sanitizedArgs['active'], true);
      expect(res.sanitizedArgs['priority'], 'HIGH');
    });

    test('applies default values when optional parameters are omitted', () {
      final res = AgentToolArgumentValidator.validate(tool, {
        'title': 'Simple Item',
      });

      expect(res.isValid, isTrue);
      expect(res.sanitizedArgs['days'], 7);
      expect(res.sanitizedArgs['active'], false);
      expect(res.sanitizedArgs['priority'], 'MEDIUM');
      expect(res.sanitizedArgs.containsKey('rating'), isFalse);
    });

    test('rejects when required parameter is missing', () {
      final res = AgentToolArgumentValidator.validate(tool, {
        'days': 5,
      });

      expect(res.isValid, isFalse);
      expect(res.errorMessageFa, contains('title'));
    });

    test('rejects when required string parameter is empty', () {
      final res = AgentToolArgumentValidator.validate(tool, {
        'title': '   ',
      });

      expect(res.isValid, isFalse);
      expect(res.errorMessageFa, contains('نمی‌تواند متن خالی باشد'));
    });

    test('rejects invalid allowed values', () {
      final res = AgentToolArgumentValidator.validate(tool, {
        'title': 'Item',
        'priority': 'SUPER_HIGH',
      });

      expect(res.isValid, isFalse);
      expect(res.errorMessageFa, contains('نامعتبر'));
      expect(res.errorMessageFa, contains('LOW، MEDIUM، HIGH'));
    });
  });
}
