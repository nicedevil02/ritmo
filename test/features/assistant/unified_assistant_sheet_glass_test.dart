import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/personas/assistant_persona.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/assistant/presentation/widgets/unified_assistant_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testPersona = AssistantPersona(
    id: 'sleep',
    displayName: 'دستیار خواب و استراحت',
    systemPromptKey: 'system_prompt_sleep',
    reads: {},
    commandIds: {},
  );

  group('AssistantSheet Glassmorphism Tests', () {
    testWidgets('AssistantSheet renders BackdropFilter when glass is enabled', (tester) async {
      final glassTheme = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        reduceTransparency: false,
        glassBlurSigma: 20.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: glassTheme,
          home: const Scaffold(
            body: AssistantSheet(
              persona: testPersona,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.text('دستیار خواب و استراحت'), findsOneWidget);
    });

    testWidgets('AssistantSheet bypasses BackdropFilter when glass is disabled (reduceTransparency = true)', (tester) async {
      final opaqueTheme = RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
        reduceTransparency: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: opaqueTheme,
          home: const Scaffold(
            body: AssistantSheet(
              persona: testPersona,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('دستیار خواب و استراحت'), findsOneWidget);
    });
  });
}
