import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_js_injector.dart';

void main() {
  group('DET-27: Rich Baseline with Turn Count and Node Counts', () {
    test(
      'setupBridgeScript constructs rich baseline object and sets window.__ritmo_turn_baseline_obj',
      () {
        final script = ChatGptJsInjector.setupBridgeScript;

        expect(script.contains('var baseline = {'), isTrue);
        expect(script.contains('text: latestAssistant'), isTrue);
        expect(script.contains('length: latestAssistant.length'), isTrue);
        expect(
          script.contains(
            'turnCount: queryAllSafe(RITMO_SELECTORS.conversationTurns).length',
          ),
          isTrue,
        );
        expect(
          script.contains(
            'assistantNodes: queryAllSafe(RITMO_SELECTORS.assistantMessage).length',
          ),
          isTrue,
        );
        expect(
          script.contains('window.__ritmo_turn_baseline_obj = baseline;'),
          isTrue,
        );
      },
    );

    test(
      'startStreamingWatcher supports both object and string baselines and checks hasNewNode',
      () {
        final script = ChatGptJsInjector.setupBridgeScript;

        expect(
          script.contains(
            'window.__ritmo_startStreamingWatcher = function(baselineOrText, reqId)',
          ),
          isTrue,
        );
        expect(
          script.contains(
            "baselineOrText && typeof baselineOrText === 'object'",
          ),
          isTrue,
        );
        expect(script.contains("typeof baselineOrText === 'string'"), isTrue);
        expect(
          script.contains(
            'var hasNewNode = (baseline.assistantNodes > 0 && currentAssistantNodes > baseline.assistantNodes) ||',
          ),
          isTrue,
        );
        expect(
          script.contains(
            '(currentText === previousBaselineText && !hasNewNode)',
          ),
          isTrue,
        );
      },
    );
  });
}
