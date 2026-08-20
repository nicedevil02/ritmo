import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/simple_tasks/logic/share_target_handler.dart';

void main() {
  group('Phase 5: Quick Entry and Share Target Tests (T-34)', () {
    test('1. Simple input text parses title with no date or time', () {
      final data = ShareTargetHandler.processSharedText('خرید کتاب برنامه نویسی');
      expect(data, isNotNull);
      expect(data!.parsedTitle, equals('خرید کتاب برنامه نویسی'));
      expect(data.daysOffset, isNull);
      expect(data.timeStr, isNull);
      expect(data.note, isNull);
    });

    test('2. Text with "فردا ساعت ۱۰" parses daysOffset = 1 and timeStr = "10:00"', () {
      final data = ShareTargetHandler.processSharedText('فردا ساعت ۱۰ جلسه تیمی');
      expect(data, isNotNull);
      expect(data!.daysOffset, equals(1));
      expect(data.timeStr, equals('10:00'));
      expect(data.parsedTitle, contains('جلسه تیمی'));
    });

    test('3. Text > 200 chars parses first 100 chars as title and full text in note', () {
      final longText = 'این یک متن طولانی برای تست اشتراک گذاری متن طولانی سیستم عامل است که کاربر از مرورگر یا پیام رسان ارسال کرده است. ' * 3;
      expect(longText.length, greaterThan(200));

      final data = ShareTargetHandler.processSharedText(longText);
      expect(data, isNotNull);
      expect(data!.parsedTitle.length, lessThanOrEqualTo(100));
      expect(data.parsedTitle, equals(longText.substring(0, 100).trim()));
      expect(data.note, equals(longText.trim()));
    });

    test('4. Empty text or whitespace produces null (no task created)', () {
      expect(ShareTargetHandler.processSharedText(''), isNull);
      expect(ShareTargetHandler.processSharedText('   '), isNull);
      expect(ShareTargetHandler.processSharedText(null), isNull);
    });
  });
}
