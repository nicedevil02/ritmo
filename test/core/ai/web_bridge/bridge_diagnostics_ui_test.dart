import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/web_bridge/bridge_status_chip.dart';
import 'package:ritmo/core/ai/web_bridge/chatgpt_web_bridge_manager.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/profile/presentation/web_bridge_diagnostics_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrapWithTheme(Widget child) {
    return MaterialApp(
      theme: ThemeData(extensions: const [RitmoColors.light]),
      home: child,
    );
  }

  group('A-94..A-98: Web Bridge Diagnostics UI Tests', () {
    testWidgets(
      'WebBridgeDiagnosticsScreen renders title, status card, and action buttons',
      (tester) async {
        await tester.pumpWidget(
          wrapWithTheme(const WebBridgeDiagnosticsScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('تشخیص پل هوش مصنوعی وب'), findsOneWidget);
        expect(find.text('وضعیت فعلی پل ارتباطی'), findsOneWidget);
        expect(find.text('بازیابی پاسخ از مرورگر'), findsOneWidget);
        expect(find.text('راه‌اندازی مجدد اجباری'), findsOneWidget);
        expect(find.text('ردیاب رویدادهای زنده (Trace Log)'), findsOneWidget);
      },
    );

    testWidgets(
      'BridgeStatusChip opens WebBridgeDiagnosticsScreen on long-press',
      (tester) async {
        ChatGptWebBridgeManager.instance.setTestState(
          status: ChatGptBridgeStatus.ready,
        );

        await tester.pumpWidget(
          wrapWithTheme(
            const Scaffold(
              body: Center(child: BridgeStatusChip(forceVisible: true)),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(BridgeStatusChip), findsOneWidget);

        // Trigger long press
        await tester.longPress(find.byType(BridgeStatusChip));
        await tester.pumpAndSettle();

        // Diagnostics screen should now be visible on navigator stack
        expect(find.byType(WebBridgeDiagnosticsScreen), findsOneWidget);
      },
    );
  });
}
