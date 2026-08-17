import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/agent/agent_tool.dart';

class _TestTool extends AgentTool {
  const _TestTool()
      : super(
          name: 'sample_tool',
          categoryFa: 'تست',
          titleFa: 'ابزار تست',
          descriptionFa: 'ابزاری برای تست ساختار JSON Schema',
          policy: ToolPolicy.actionDirect,
          parameters: const [
            ToolParameter(
              name: 'title',
              descriptionFa: 'عنوان',
              type: 'string',
              isRequired: true,
            ),
            ToolParameter(
              name: 'count',
              descriptionFa: 'تعداد',
              type: 'int',
              defaultValue: 1,
            ),
            ToolParameter(
              name: 'category',
              descriptionFa: 'دسته',
              type: 'string',
              allowedValues: ['A', 'B'],
            ),
          ],
        );

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    return AgentToolResult.success(toolName: name, data: null, summaryFa: 'تست موفق');
  }
}

class _EmptyParamTool extends AgentTool {
  const _EmptyParamTool()
      : super(
          name: 'empty_tool',
          categoryFa: 'تست',
          titleFa: 'ابزار بدون پارامتر',
          descriptionFa: 'ابزاری بدون پارامتر',
        );

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    return AgentToolResult.success(toolName: name, data: null, summaryFa: 'موفق');
  }
}

void main() {
  group('AgentTool & ToolParameter JSON Schema Tests (T17)', () {
    test('ToolParameter.toSchema produces valid JSON schema property', () {
      const param = ToolParameter(
        name: 'mode',
        descriptionFa: 'حالت اجرا',
        type: 'string',
        defaultValue: 'fast',
        allowedValues: ['fast', 'accurate'],
      );

      final schema = param.toSchema();
      expect(schema['type'], 'string');
      expect(schema['description'], 'حالت اجرا');
      expect(schema['default'], 'fast');
      expect(schema['enum'], ['fast', 'accurate']);
      expect(schema.containsKey('required'), isFalse);
    });

    test('AgentTool.toJsonSchema produces valid OpenAI/Claude function tool schema', () {
      const tool = _TestTool();
      final schema = tool.toJsonSchema();

      expect(schema['type'], 'function');
      final function = schema['function'] as Map<String, dynamic>;
      expect(function['name'], 'sample_tool');
      expect(function['description'], 'ابزاری برای تست ساختار JSON Schema');

      final parameters = function['parameters'] as Map<String, dynamic>;
      expect(parameters['type'], 'object');
      expect(parameters['required'], ['title']);

      final properties = parameters['properties'] as Map<String, dynamic>;
      expect(properties.containsKey('title'), isTrue);
      expect(properties.containsKey('count'), isTrue);
      expect(properties.containsKey('category'), isTrue);

      expect(properties['title']['type'], 'string');
      expect(properties['count']['default'], 1);
      expect(properties['category']['enum'], ['A', 'B']);
    });

    test('AgentTool.toJsonSchema works cleanly for tools without parameters', () {
      const tool = _EmptyParamTool();
      final schema = tool.toJsonSchema();

      expect(schema['type'], 'function');
      final function = schema['function'] as Map<String, dynamic>;
      expect(function['name'], 'empty_tool');
      final parameters = function['parameters'] as Map<String, dynamic>;
      expect(parameters['type'], 'object');
      expect(parameters['properties'], isEmpty);
      expect(parameters.containsKey('required'), isFalse);
    });
  });
}
