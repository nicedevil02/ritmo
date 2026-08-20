import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/personas/validator_lexicon.dart';
import 'package:ritmo/core/domain/personas/persona_registry.dart';
import 'package:ritmo/core/domain/commands/commands_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerAllRitmoCommands();
    PersonaRegistry.instance.initStandardPersonas();
  });

  group('Causal Lexicon Tests (PSN-22)', () {
    test('Boundary-aware detection: "همچون" is not matched as "چون"', () {
      const text = 'خواب شما همچون گذشته منظم است.';
      expect(
        ValidatorLexicon.containsPhrase(text, ValidatorLexicon.causalPhrases),
        isFalse,
      );
    });

    test('Catches "به‌خاطر" and "به خاطر"', () {
      const text1 = 'به‌خاطر دیر خوابیدن، انرژی شما افت کرد.';
      const text2 = 'به خاطر بی نظمی، روتین انجام نشد.';
      expect(
        ValidatorLexicon.containsPhrase(text1, ValidatorLexicon.causalPhrases),
        isTrue,
      );
      expect(
        ValidatorLexicon.containsPhrase(text2, ValidatorLexicon.causalPhrases),
        isTrue,
      );
    });

    test('Catches "در نتیجه" and "باعث می‌شود"', () {
      const text1 = 'در نتیجه خستگی شما بیشتر شده است.';
      const text2 = 'این کار باعث می‌شود خواب شما به هم بریزد.';
      expect(
        ValidatorLexicon.containsPhrase(text1, ValidatorLexicon.causalPhrases),
        isTrue,
      );
      expect(
        ValidatorLexicon.containsPhrase(text2, ValidatorLexicon.causalPhrases),
        isTrue,
      );
    });

    test(
      'Quote exemption: causal phrases inside Persian or double quotes are ignored',
      () {
        const text =
            'شما نوشتید: «کمبود خواب باعث شد خسته شوم». اما ما فقط همبستگی را بررسی می‌کنیم.';
        expect(
          ValidatorLexicon.containsPhrase(
            text,
            ValidatorLexicon.causalPhrases,
            exemptQuotes: true,
          ),
          isFalse,
        );
      },
    );
  });
}
