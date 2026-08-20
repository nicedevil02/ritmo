import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/agent/catalog/planning_agent_tools.dart';

void main() {
  group('ExecutePlanTool Tests (T34)', () {
    const tool = ExecutePlanTool();

    test('fails when steps argument is missing or empty', () async {
      final res1 = await tool.execute({});
      expect(res1.isSuccess, isFalse);
      expect(res1.errorMessage, contains('الزامی'));

      final res2 = await tool.execute({'steps': []});
      expect(res2.isSuccess, isFalse);
      expect(res2.errorMessage, contains('الزامی'));
    });

    test('fails when steps contain no valid commandId', () async {
      final res = await tool.execute({
        'title': 'برنامه تست',
        'steps': [
          {'invalid': 'value'},
        ],
      });
      expect(res.isSuccess, isFalse);
      expect(res.errorMessage, contains('معتبری'));
    });
  });
}
