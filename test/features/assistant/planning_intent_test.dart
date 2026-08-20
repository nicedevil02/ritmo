import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/assistant/logic/planning_intent_parser.dart';

void main() {
  group('PlanningIntentParser (I-12 Golden AI Tests)', () {
    const parser = PlanningIntentParser();

    test('1. Valid JSON PLAN_WEEK parses accurately into overrides', () {
      const jsonResponse = '''
      {
        "intent": "PLAN_WEEK",
        "focusTitles": ["پروژه ریتمو", "مطالعه زبان"],
        "constraints": [{"day": "THU", "load": "LIGHT"}],
        "budgetOverrides": [{"title": "پروژه ریتمو", "effortMinutes": 180}],
        "importanceOverrides": [{"title": "گزارش مالی", "importance": "MUST"}],
        "splitSuggestions": [{"title": "مطالعه زبان", "parts": 3}],
        "questions": ["آیا روز پنجشنبه تمایل به کار سبک دارید؟"]
      }
      ''';

      final result = parser.parse(
        jsonResponse,
        existingCommitmentTitles: ['پروژه ریتمو', 'مطالعه زبان', 'گزارش مالی'],
      );

      expect(result.isValid, isTrue);
      expect(result.intent, equals(ParsedPlanningIntent.planWeek));
      expect(result.focusTitles, contains('پروژه ریتمو'));
      expect(result.constraints.first.day, equals(ParsedDayOfWeek.thu));
      expect(result.constraints.first.load, equals(ParsedDayLoad.light));
      expect(result.budgetOverrides.first.effortMinutes, equals(180));
      expect(result.importanceOverrides.first.importance, equals('MUST'));
      expect(result.splitSuggestions.first.parts, equals(3));
    });

    test(
      '2. Response with forbidden exact time keys (startTime/hour) is rejected',
      () {
        const invalidResponse = '''
      {
        "intent": "PLAN_WEEK",
        "focusTitles": ["ورزش"],
        "startTime": "08:00",
        "constraints": []
      }
      ''';

        final result = parser.parse(invalidResponse);
        expect(result.isValid, isFalse);
        expect(result.validationError, contains('غیرمجاز'));
      },
    );

    test(
      '3. Override with nonexistent title is discarded and mentioned in questions',
      () {
        const jsonResponse = '''
      {
        "intent": "PLAN_WEEK",
        "focusTitles": ["تمرین پیانو"],
        "budgetOverrides": [{"title": "کلاس نقاشی ناشناخته", "effortMinutes": 60}],
        "constraints": [],
        "questions": []
      }
      ''';

        final result = parser.parse(
          jsonResponse,
          existingCommitmentTitles: ['تمرین پیانو', 'ورزش'],
        );

        expect(result.isValid, isTrue);
        expect(result.budgetOverrides, isEmpty);
        expect(
          result.questions.any((q) => q.contains('کلاس نقاشی ناشناخته')),
          isTrue,
        );
      },
    );

    test('4. Robust JSON extraction with surrounding free-text / markdown', () {
      const wrappedResponse = '''
      درود بر شما، برنامه این هفته شما به صورت زیر پیشنهاد می‌شود:
      ```json
      {
        "intent": "PLAN_WEEK",
        "focusTitles": ["توسعه نرم‌افزار"],
        "constraints": [],
        "questions": []
      }
      ```
      امیدوارم هفته پرباری داشته باشید!
      ''';

      final result = parser.parse(wrappedResponse);
      expect(result.isValid, isTrue);
      expect(result.intent, equals(ParsedPlanningIntent.planWeek));
      expect(result.focusTitles, contains('توسعه نرم‌افزار'));
    });

    test('5. Trade-off scenario fixture verification', () {
      const tradeOffResponse = '''
      {
        "intent": "PLAN_WEEK",
        "focusTitles": ["پروژه فشرده"],
        "budgetOverrides": [{"title": "پروژه فشرده", "effortMinutes": 240}],
        "questions": [
          "مجموع تعهدات ۶۰۰ دقیقه است در حالی که ظرفیت ۳۰۰ دقیقه می‌باشد.",
          "گزینه ۱: ۶۰ دقیقه از «زبان» کم شود.",
          "گزینه ۲: چهارشنبه فشرده‌تر شود (ذخیره از ۲۵٪ به ۱۰٪)."
        ]
      }
      ''';

      final result = parser.parse(
        tradeOffResponse,
        existingCommitmentTitles: ['پروژه فشرده', 'زبان'],
      );

      expect(result.isValid, isTrue);
      expect(result.questions.length, greaterThanOrEqualTo(2));
      // Must contain numerical options
      expect(
        result.questions.any(
          (q) => q.contains('۶۰') || q.contains('۲۵٪') || q.contains('۶۰۰'),
        ),
        isTrue,
      );
    });

    test(
      '6. Architecture boundary: planning_intent_parser does NOT import sqflite',
      () {
        final file = File(
          'lib/features/assistant/logic/planning_intent_parser.dart',
        );
        final content = file.readAsStringSync();
        expect(content.contains('sqflite'), isFalse);
      },
    );
  });
}
