import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_js_injector.dart';
import 'package:ritmo/core/ai/web_bridge/web_bridge_event.dart';

void main() {
  group('DET-24: Fallback to Active RequestId on Empty Resume Payload', () {
    test(
      'setupBridgeScript contains safe requestId extraction and fallback to window.__ritmo_active_req_id',
      () {
        final script = ChatGptJsInjector.setupBridgeScript;

        expect(
          script.contains("typeof payload.requestId === 'string'"),
          isTrue,
        );
        expect(script.contains('window.__ritmo_active_req_id'), isTrue);
        expect(
          script.contains('if (!reqId && window.__ritmo_active_req_id)'),
          isTrue,
        );
      },
    );

    test(
      'WebBridgeEvent parses resumed and chunk events even when requestId is omitted or null',
      () {
        final resumedEvent = WebBridgeEvent.parse('''{
        "type": "resumed",
        "stage": "streaming",
        "recoveredLength": 12,
        "source": "dom"
      }''');
        expect(resumedEvent, isA<BridgeResumedEvent>());
        final r = resumedEvent as BridgeResumedEvent;
        expect(r.requestId, isNull);
        expect(r.recoveredLength, equals(12));

        final chunkEvent = WebBridgeEvent.parse('''{
        "type": "chunk",
        "delta": "hello",
        "source": "dom"
      }''');
        expect(chunkEvent, isA<BridgeChunkEvent>());
        final c = chunkEvent as BridgeChunkEvent;
        expect(c.requestId, isNull);
        expect(c.delta, equals('hello'));
      },
    );
  });
}
