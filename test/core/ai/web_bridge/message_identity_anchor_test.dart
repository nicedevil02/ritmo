import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_js_injector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WEB-18: Message Identity Anchor & Unseen Prioritization', () {
    test(
      'setupBridgeScript anchors existing elements with data-ritmo-seen',
      () {
        final script = ChatGptJsInjector.setupBridgeScript;

        expect(
          script.contains("el.setAttribute('data-ritmo-seen', 'true')"),
          isTrue,
        );
      },
    );

    test(
      'setupBridgeScript prioritizes unseen elements with :not([data-ritmo-seen="true"])',
      () {
        final script = ChatGptJsInjector.setupBridgeScript;

        expect(
          script.contains(
            '[data-message-author-role="assistant"]:not([data-ritmo-seen="true"])',
          ),
          isTrue,
        );
        expect(
          script.contains('div.markdown:not([data-ritmo-seen="true"])'),
          isTrue,
        );
        expect(
          script.contains('article:not([data-ritmo-seen="true"])'),
          isTrue,
        );
      },
    );

    test(
      'setupBridgeScript preserves fallback to general elements if no unseen matches exist',
      () {
        final script = ChatGptJsInjector.setupBridgeScript;

        expect(
          script.contains('queryAllSafe(RITMO_SELECTORS.assistantMessage)'),
          isTrue,
        );
      },
    );
  });
}
