import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_auth_modal.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    ChatGptWebBridgeManager.instance.disposeWebView();
  });

  group('WEB-26: ChatGptAuthModal UI & Manager Integration', () {
    test('ChatGptWebBridgeManager provides reloadPage and clearSessionCookies methods', () async {
      final manager = ChatGptWebBridgeManager.instance;

      expect(manager.reloadPage, isA<Function>());
      expect(manager.clearSessionCookies, isA<Function>());
    });

    testWidgets('ChatGptAuthModal renders title, description and action buttons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatGptAuthModal(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('ورود به حساب کاربری ChatGPT'), findsOneWidget);
      expect(find.text('پس از ورود، این پنجره به‌طور خودکار بسته خواهد شد.'), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('ChatGptAuthModal close button pops the modal', (tester) async {
      bool? authResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  authResult = await ChatGptAuthModal.show(ctx);
                },
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('ورود به حساب کاربری ChatGPT'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('ورود به حساب کاربری ChatGPT'), findsNothing);
      expect(authResult, isNotNull);
    });
  });
}
