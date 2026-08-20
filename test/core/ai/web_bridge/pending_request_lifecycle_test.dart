import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChatGptWebBridgeManager manager;

  setUp(() {
    manager = ChatGptWebBridgeManager.instance;
  });

  tearDown(() {
    manager.disposeWebView();
  });

  group('WEB-08: Pending Request Model & Lifecycle', () {
    test(
      'promptPrefix truncates whitespace and limits length to at most 80 characters',
      () {
        const longPrompt =
            '   این یک متن تستی بسیار بسیار بسیار بسیار بسیار بسیار بسیار بسیار بسیار بسیار طولانی است که باید کوتاه شود.   ';
        final req = PendingWebBridgeRequest(
          requestId: 'req_123',
          promptHash: 'abc1',
          promptText: longPrompt,
          sentAt: DateTime.now(),
        );

        expect(req.promptPrefix.length, lessThanOrEqualTo(80));
        expect(req.promptPrefix.startsWith(' '), isFalse);
      },
    );

    test(
      'toJson contains promptPrefix instead of full promptText to keep injection payload lightweight',
      () {
        const longPrompt =
            'یک دو سه چهار پنج شش هفت هشت نه ده یازده دوازده سیزده چهارده پانزده شانزده هفده هجده نوزده بیست';
        final req = PendingWebBridgeRequest(
          requestId: 'req_123',
          promptHash: 'hash_abc',
          promptText: longPrompt,
          sentAt: DateTime.parse('2026-08-18T10:00:00.000Z'),
          stage: PendingRequestStage.streaming,
          receivedLength: 42,
        );

        final json = req.toJson();

        expect(json.containsKey('promptText'), isFalse);
        expect(json['promptPrefix'], equals(req.promptPrefix));
        expect(json['requestId'], equals('req_123'));
        expect(json['stage'], equals('streaming'));
        expect(json['receivedLength'], equals(42));
        expect(json['promptHash'], equals('hash_abc'));
      },
    );

    test('fromJson deserializes correctly', () {
      final json = {
        'requestId': 'req_456',
        'promptHash': 'hash_xyz',
        'promptPrefix': 'خلاصه پرامپت',
        'stage': 'awaitingFirstToken',
        'receivedLength': 10,
        'resendAttempts': 1,
        'sentAt': '2026-08-18T10:00:00.000Z',
      };

      final req = PendingWebBridgeRequest.fromJson(json);

      expect(req.requestId, equals('req_456'));
      expect(req.stage, equals(PendingRequestStage.awaitingFirstToken));
      expect(req.receivedLength, equals(10));
      expect(req.resendAttempts, equals(1));
    });

    test('cancelCurrentStream and disposeWebView clear pendingRequest', () {
      manager.setTestPendingRequest(
        PendingWebBridgeRequest(
          requestId: 'req_test',
          promptHash: 'h',
          promptText: 'p',
          sentAt: DateTime.now(),
        ),
      );
      expect(manager.pendingRequest, isNotNull);

      manager.cancelCurrentStream();
      expect(manager.pendingRequest, isNull);

      manager.setTestPendingRequest(
        PendingWebBridgeRequest(
          requestId: 'req_test2',
          promptHash: 'h2',
          promptText: 'p2',
          sentAt: DateTime.now(),
        ),
      );
      expect(manager.pendingRequest, isNotNull);

      manager.disposeWebView();
      expect(manager.pendingRequest, isNull);
    });
  });
}
