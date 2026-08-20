import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_js_injector.dart';

void main() {
  group('DET-18: Standalone SSE Reader in Early Hook Script', () {
    test(
      'earlyHookScript defines complete parseSSELine and readSSEStream independently',
      () {
        final script = ChatGptJsInjector.earlyHookScript;

        expect(
          script.contains('function parseSSELine(line, state, reqId)'),
          isTrue,
        );
        expect(
          script.contains('function readSSEStream(reader, reqId)'),
          isTrue,
        );
        expect(
          script.contains('window.__ritmo_parseSSELine = parseSSELine;'),
          isTrue,
        );
        expect(
          script.contains('window.__ritmo_readSSEStream = readSSEStream;'),
          isTrue,
        );
        expect(script.contains('json.o === \'patch\''), isTrue);
        expect(script.contains('json.o === \'append\''), isTrue);
        expect(script.contains('json.o === \'replace\''), isTrue);
      },
    );
  });
}
