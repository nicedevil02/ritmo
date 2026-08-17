import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/agent/catalog/memory_agent_tools.dart';

void main() {
  group('Memory Agent Tools Tests (T37)', () {
    const rememberTool = RememberFactTool();
    const recallTool = RecallFactsTool();

    test('RememberFactTool fails on empty content', () async {
      final res = await rememberTool.execute({});
      expect(res.isSuccess, isFalse);
      expect(res.errorMessage, contains('content'));
    });

    test('RecallFactsTool fails on empty query', () async {
      final res = await recallTool.execute({});
      expect(res.isSuccess, isFalse);
      expect(res.errorMessage, contains('query'));
    });
  });
}
