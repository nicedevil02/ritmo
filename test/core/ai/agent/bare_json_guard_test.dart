import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/agent/agent_tool_call_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('A-93: Bare JSON Guard and Normal Code Block Integrity', () {
    test(
      'standard markdown json block with code example is NOT treated as tool call',
      () {
        const codeExample = '''
در اینجا نمونه‌ای از کانفیگ JSON آورده شده است:
```json
{
  "name": "example_config",
  "version": "1.0.0",
  "settings": {
    "theme": "dark"
  }
}
```
می‌توانید از آن در پروژه استفاده کنید.
''';

        final scan = AgentToolCallParser.scan(codeExample);
        expect(scan.hasCalls, isFalse);
        expect(scan.cleanText, contains('نمونه‌ای از کانفیگ JSON'));
        expect(scan.cleanText, contains('"theme": "dark"'));
      },
    );

    test(
      'bare json with unknown tool name is ignored when knownToolNames is provided',
      () {
        const bareJson =
            '{"tool": "unregistered_tool_xyz", "parameters": {"a": 1}}';
        final scan = AgentToolCallParser.scan(
          bareJson,
          knownToolNames: {'get_routines', 'create_goal'},
        );

        expect(scan.hasCalls, isFalse);
      },
    );

    test(
      'bare json without knownToolNames is never treated as a tool call (conservative fail-open)',
      () {
        const bareJson = '{"tool": "get_routines", "parameters": {}}';
        final scan = AgentToolCallParser.scan(bareJson);

        expect(scan.hasCalls, isFalse);
      },
    );
  });
}
