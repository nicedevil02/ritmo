import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/chat/chat_action_parser.dart';

void main() {
  group('ChatActionParser Clean Farsi Reply Extraction Tests', () {
    test('Extracts reply from raw structured JSON', () {
      const raw = '''
{
  "reply": "سلام. وقتت بخیر. هنوز داده‌ای از چرخه یا علائم ثبت نکرده‌ای، برای همین نمی‌توانم تحلیل یا پیشنهادی بدهم.",
  "skill": null,
  "confidence": "none",
  "usedFields": [],
  "commands": [],
  "handoff": null
}
''';
      final clean = ChatActionParser.extractCleanReplyText(raw);
      expect(clean, equals('سلام. وقتت بخیر. هنوز داده‌ای از چرخه یا علائم ثبت نکرده‌ای، برای همین نمی‌توانم تحلیل یا پیشنهادی بدهم.'));
    });

    test('Extracts reply from markdown code-blocked JSON', () {
      const raw = '''
```json
{
  "reply": "سلام عزیز دل! به بخش بارداری خوش آمدید."
}
```
''';
      final clean = ChatActionParser.extractCleanReplyText(raw);
      expect(clean, equals('سلام عزیز دل! به بخش بارداری خوش آمدید.'));
    });

    test('Extracts reply from streaming / unclosed JSON chunk', () {
      const raw = '''
{
  "reply": "سلام. وقتت بخیر. در حال بررسی وضعیت شما...
''';
      final clean = ChatActionParser.extractCleanReplyText(raw);
      expect(clean, contains('سلام. وقتت بخیر. در حال بررسی وضعیت شما...'));
    });

    test('Preserves normal Farsi text without JSON wrappers', () {
      const raw = 'سلام! روز زیبایی داشته باشید. چطور می‌توانم به شما کمک کنم؟';
      final clean = ChatActionParser.extractCleanReplyText(raw);
      expect(clean, equals(raw));
    });

    test('Extracts JSON commands into ChatAction list', () {
      const raw = '''
{
  "reply": "روتین جدید برای شما آماده شد.",
  "commands": [
    {
      "id": "routine.create",
      "labelFa": "ایجاد روتین تمرین",
      "payload": {"title": "ورزش صبحگاهی"}
    }
  ]
}
''';
      final parsed = ChatActionParser.parse(raw);
      expect(parsed.cleanText, equals('روتین جدید برای شما آماده شد.'));
      expect(parsed.actions.length, equals(1));
      expect(parsed.actions.first.type, equals('routine.create'));
      expect(parsed.actions.first.label, equals('ایجاد روتین تمرین'));
    });

    test('Handles legacy <actions> tags correctly', () {
      const raw = 'این پیام است.<actions>[{"type": "openPage", "label": "مشاهده"}]</actions>';
      final parsed = ChatActionParser.parse(raw);
      expect(parsed.cleanText, equals('این پیام است.'));
      expect(parsed.actions.length, equals(1));
      expect(parsed.actions.first.label, equals('مشاهده'));
    });
  });
}
