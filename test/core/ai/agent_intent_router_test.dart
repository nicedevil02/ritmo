import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/agent/intent/agent_intent_router.dart';
import 'package:ritmo/core/ai/agent/intent/ritmo_date_parser.dart';

void main() {
  group('AgentIntentRouter & RitmoDateParser Tests (T13)', () {
    test('tokenize normalizes persian characters and digits', () {
      final tokens = AgentIntentRouter.tokenize(
        'برنامه روز ۱۲ اردیبهشت من چیه؟',
      );
      expect(tokens, contains('برنامه'));
      expect(tokens, contains('روز'));
      expect(tokens, contains('12'));
      expect(tokens, contains('اردیبهشت'));
    });

    test(
      'extractNoteQuery strips stop words without destroying query meaning',
      () {
        final query = AgentIntentRouter.extractNoteQuery(
          'لطفاً در یادداشت‌های من درباره خرید کتاب جستجو کن',
        );
        expect(query, contains('خرید'));
        expect(query, contains('کتاب'));
        expect(query, isNot(contains('یادداشت')));
      },
    );

    test(
      'RitmoDateParser parses relative weekdays correctly to ISO format',
      () {
        final parsed = RitmoDateParser.parse('برنامه‌ی شنبه آینده چیه؟');
        expect(parsed.matched, isTrue);
        expect(parsed.startIso, matches(r'^\d{4}-\d{2}-\d{2}$'));
        expect(parsed.startIso, isNot('today'));
      },
    );

    test('token-level intent avoids substring false positives', () {
      // "مودم" should not trigger energy/mood keywords
      final tokens = AgentIntentRouter.tokenize('مودم وای‌فای قطع شده است');
      expect(tokens, contains('مودم'));
      expect(tokens, isNot(contains('مود')));
    });
  });
}
