import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_js_injector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 3 Bridge Hardening Tests (A-27..A-38)', () {
    test(
      'A-27: RITMO_SELECTORS has modern non-fruitjuice selectors for all critical controls',
      () {
        final script = ChatGptJsInjector.setupBridgeScript;

        expect(script.contains('button[data-testid="send-button"]'), isTrue);
        expect(script.contains('button[aria-label*="Send" i]'), isTrue);
        expect(script.contains('button[aria-label*="ارسال"]'), isTrue);
        expect(script.contains('button[data-testid="stop-button"]'), isTrue);
        expect(script.contains('button[aria-label*="Stop" i]'), isTrue);
        expect(script.contains('button[aria-label*="توقف"]'), isTrue);
        expect(
          script.contains('[data-message-author-role="assistant"]'),
          isTrue,
        );
      },
    );

    test(
      'A-28: Selector health self-test is executed at boot and posted via selector_health',
      () {
        final script = ChatGptJsInjector.setupBridgeScript;

        expect(script.contains('function runSelectorSelfTest()'), isTrue);
        expect(script.contains("notifyFlutter('selector_health'"), isTrue);
        expect(script.contains('report: selfTestReport'), isTrue);
      },
    );

    test('A-29: RITMO_ANCHORABLE aligns with all unseen selectors', () {
      final script = ChatGptJsInjector.setupBridgeScript;

      expect(script.contains('var RITMO_ANCHORABLE = ['), isTrue);
      expect(script.contains('queryAllSafe(RITMO_ANCHORABLE).forEach'), isTrue);
      expect(script.contains("'div.markdown'"), isTrue);
      expect(script.contains("'div.prose'"), isTrue);
      expect(script.contains("'[data-message-author-role]'"), isTrue);
      expect(script.contains("'[data-testid*=\"assistant\"]'"), isTrue);
      expect(script.contains("'div.agent-turn'"), isTrue);
    });

    test(
      'A-30: findLatestAssistantText prioritizes turn count & author role sequence',
      () {
        final script = ChatGptJsInjector.setupBridgeScript;

        expect(script.contains('window.__ritmo_turn_count_at_send'), isTrue);
        expect(
          script.contains('Strategy 1: ID/Turn-count based anchor'),
          isTrue,
        );
        expect(
          script.contains(
            'Strategy 2: Last assistant message after the last user message',
          ),
          isTrue,
        );
        expect(script.contains('Strategy 3: data-ritmo-seen'), isTrue);
      },
    );

    test(
      'A-31: parseSSELine supports JSON patch, append, and replace formats',
      () {
        final script = ChatGptJsInjector.setupBridgeScript;

        expect(
          script.contains("json.o === 'patch' && Array.isArray(json.v)"),
          isTrue,
        );
        expect(script.contains("json.o === 'append'"), isTrue);
        expect(script.contains("json.o === 'replace'"), isTrue);
        expect(
          script.contains("op.p.indexOf('/message/content/parts/') === 0"),
          isTrue,
        );
      },
    );

    test(
      'A-33: extractCleanText strips reasoning/thinking elements using RITMO_STRIP on cloned DOM',
      () {
        final script = ChatGptJsInjector.setupBridgeScript;

        expect(script.contains('var RITMO_STRIP = ['), isTrue);
        expect(script.contains('el.cloneNode(true)'), isTrue);
        expect(script.contains('[data-testid*="thinking"]'), isTrue);
        expect(script.contains('[data-testid*="reasoning"]'), isTrue);
        expect(script.contains('details[data-testid*="thought"]'), isTrue);
        expect(
          script.contains("!stripEl.closest('pre')"),
          isTrue,
          reason:
              'Must preserve pre/code blocks when stripping buttons and UI junk',
        );
      },
    );

    test('A-34: fetch hook protects against missing response.body.tee', () {
      final script = ChatGptJsInjector.setupBridgeScript;
      final earlyScript = ChatGptJsInjector.earlyHookScript;

      expect(
        script.contains(
          'response.body.tee unavailable, falling back to DOM watcher only',
        ),
        isTrue,
      );
      expect(
        earlyScript.contains("typeof response.body.tee !== 'function'"),
        isTrue,
      );
    });

    test(
      'A-35: XMLHttpRequest and EventSource early hooks are defined with idempotency guards',
      () {
        final earlyScript = ChatGptJsInjector.earlyHookScript;

        expect(earlyScript.contains('window.__ritmo_xhr_hooked'), isTrue);
        expect(earlyScript.contains('window.__ritmo_es_hooked'), isTrue);
        expect(
          earlyScript.contains('window.XMLHttpRequest.prototype.open'),
          isTrue,
        );
        expect(earlyScript.contains('window.EventSource = function'), isTrue);
      },
    );

    test(
      'A-36: earlyHookScript is exported as static getter for onPageStarted injection',
      () {
        final earlyScript = ChatGptJsInjector.earlyHookScript;

        expect(earlyScript.isNotEmpty, isTrue);
        expect(
          earlyScript.contains('window.__ritmo_early_hooks_injected'),
          isTrue,
        );
      },
    );

    test(
      'A-37: DOM watcher emits delta on extensions and fullText on periodic sync or rewrite',
      () {
        final script = ChatGptJsInjector.setupBridgeScript;

        expect(
          script.contains(
            'var isPeriodicSync = (tickCount % 10 === 0) || forceFull === true;',
          ),
          isTrue,
        );
        expect(
          script.contains(
            "notifyFlutter('chunk', { delta: delta, requestId: reqId, source: 'dom' });",
          ),
          isTrue,
        );
        expect(
          script.contains(
            "notifyFlutter('chunk', { delta: delta, fullText: currentText, requestId: reqId, source: 'dom' });",
          ),
          isTrue,
        );
      },
    );

    test(
      'A-38: autoDismissCookiesAndModals aborts during active generation and scopes to modals',
      () {
        final script = ChatGptJsInjector.setupBridgeScript;

        expect(
          script.contains('if (window.__ritmo_active_req_id) return;'),
          isTrue,
        );
        expect(script.contains('var modalContainers = queryAllSafe'), isTrue);
        expect(
          script.contains(
            "btn.closest('form') || btn.closest('main') || btn.closest('article')",
          ),
          isTrue,
          reason:
              'Must exclude buttons in form, main, or articles from modal dismissal',
        );
        expect(script.contains("notifyFlutter('auto_dismiss'"), isTrue);
      },
    );
  });
}
