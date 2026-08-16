import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/routines/presentation/quick_add_parser.dart';

void main() {
  group('QuickAddParser P0-D/P1-F Tests', () {
    test('15 Cases P0-D', () {
      final cases = [
        ('کارگاه سفال فردا', 'کارگاه سفال', 1, null),
        ('عصرانه با مریم', 'عصرانه با مریم', 0, null),
        ('تنظیم شبکه', 'تنظیم شبکه', 0, null),
        ('خرید ۲ کیلو سیب', 'خرید 2 کیلو سیب', 0, null),
        ('جلسه فردا ساعت ۵ عصر', 'جلسه', 1, const TimeOfDay(hour: 17, minute: 0)),
        ('جلسه ۹:۳۰', 'جلسه', 0, const TimeOfDay(hour: 9, minute: 30)),
        ('جلسه ۰۹:۳۰', 'جلسه', 0, const TimeOfDay(hour: 9, minute: 30)),
        ('قرص ۲ شب', 'قرص', 0, const TimeOfDay(hour: 2, minute: 0)),
        ('دویدن ۹ صبح', 'دویدن', 0, const TimeOfDay(hour: 9, minute: 0)),
        ('گزارش هفته بعد', 'گزارش هفته بعد', 0, null),
        ('زنگ به ۵ نفر', 'زنگ به 5 نفر', 0, null),
        ('ورزش ساعت ۶', 'ورزش', 0, const TimeOfDay(hour: 6, minute: 0)),
        ('شام ۸ شب فردا', 'شام', 1, const TimeOfDay(hour: 20, minute: 0)),
        ('خرید', 'خرید', 0, null),
        ('۱۰ دقیقه مدیتیشن', 'مدیتیشن', 0, null),
        ('ساعت ۸:۳۰ صبح ورزش', 'ورزش', 0, const TimeOfDay(hour: 8, minute: 30)),
        ('عصر ساعت ۵:۴۵ جلسه', 'جلسه', 0, const TimeOfDay(hour: 17, minute: 45)),
        ('ساعت ۱۰:۳۰ شب فیلم', 'فیلم', 0, const TimeOfDay(hour: 22, minute: 30)),
      ];

      for (final c in cases) {
        final res = QuickAddParser.parse(c.$1);
        expect(res.title, c.$2, reason: 'Failed title on: ${c.$1}');
        expect(res.daysOffset ?? 0, c.$3 ?? 0, reason: 'Failed daysOffset on: ${c.$1}');
        expect(res.timeOfDay, c.$4, reason: 'Failed timeOfDay on: ${c.$1}');
      }
    });
  });
}
