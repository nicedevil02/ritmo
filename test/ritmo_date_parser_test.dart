import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/agent/intent/ritmo_date_parser.dart';

/// تست واحد پارسر تاریخ فارسی (فاز ۶)
///
/// تاریخ پایه همه تست‌ها: دوشنبه 2026-08-17 = ۲۶ مرداد ۱۴۰۵.
/// این پرونده هیچ وابستگی به دیتابیس یا پلاگین ندارد، پس با `flutter test`
/// مستقیما قابل اجراست.
void main() {
  final base = DateTime(2026, 8, 17);

  group('normalize', () {
    test('ارقام فارسی و عربی به لاتین تبدیل می‌شوند', () {
      expect(RitmoDateParser.normalize('۱۲۳'), '123');
      expect(RitmoDateParser.normalize('٤٥٦'), '456');
    });

    test('ی/ک عربی یکدست و نیم‌فاصله حذف می‌شود', () {
      expect(RitmoDateParser.normalize('\u0643\u064a'), '\u06a9\u06cc');
      expect(RitmoDateParser.normalize('پس\u200cفردا'), 'پسفردا');
    });
  });

  group('کلیدواژه‌های روز', () {
    test('فردا یک روز جلوتر است', () {
      final r = RitmoDateParser.parse('برنامه فردا چیه؟', now: base);
      expect(r.matched, isTrue);
      expect(r.isRange, isFalse);
      expect(r.startIso, '2026-08-18');
      expect(r.dayCount, 1);
    });

    test('پس‌فردا دو روز جلوتر است و بر فردا اولویت دارد', () {
      final r = RitmoDateParser.parse('پس\u200cفردا چی دارم؟', now: base);
      expect(r.startIso, '2026-08-19');
    });

    test('دیروز یک روز عقب‌تر است', () {
      final r = RitmoDateParser.parse('دیروز چند روتین زدم؟', now: base);
      expect(r.startIso, '2026-08-16');
    });

    test('امروز متطابق است و متن بی‌تاریخ متطابق نیست', () {
      expect(RitmoDateParser.parse('امروز', now: base).matched, isTrue);

      final none = RitmoDateParser.parse('سلام خوبی؟', now: base);
      expect(none.matched, isFalse);
      expect(none.startIso, '2026-08-17');
    });
  });

  group('بازه هفتگی (هفته ایرانی از شنبه)', () {
    test('شنبهٔ همین هفته درست محاسبه می‌شود', () {
      expect(RitmoDateParser.iso(RitmoDateParser.startOfPersianWeek(base)),
          '2026-08-15');
      // اگر خود روز شنبه باشد، همان روز برمی‌گردد
      expect(
          RitmoDateParser.iso(
              RitmoDateParser.startOfPersianWeek(DateTime(2026, 8, 15))),
          '2026-08-15');
    });

    test('این هفته ۷ روز از شنبه تا جمعه', () {
      final r = RitmoDateParser.parse('این هفته چی دارم؟', now: base);
      expect(r.isRange, isTrue);
      expect(r.startIso, '2026-08-15');
      expect(r.endIso, '2026-08-21');
      expect(r.dayCount, 7);
    });

    test('هفته بعد و هفته گذشته', () {
      final next = RitmoDateParser.parse('برنامه هفته بعد', now: base);
      expect(next.startIso, '2026-08-22');
      expect(next.endIso, '2026-08-28');

      final prev = RitmoDateParser.parse('هفته گذشته چطور بود؟', now: base);
      expect(prev.startIso, '2026-08-08');
      expect(prev.endIso, '2026-08-14');
    });
  });

  group('بازه X روز/هفته', () {
    test('۳ روز آینده از امروز شروع می‌شود', () {
      final r = RitmoDateParser.parse('۳ روز آینده رو بگو', now: base);
      expect(r.isRange, isTrue);
      expect(r.startIso, '2026-08-17');
      expect(r.endIso, '2026-08-19');
      expect(r.dayCount, 3);
    });

    test('۷ روز گذشته به امروز ختم می‌شود', () {
      final r = RitmoDateParser.parse('۷ روز گذشته خوابم چطور بود؟', now: base);
      expect(r.startIso, '2026-08-11');
      expect(r.endIso, '2026-08-17');
      expect(r.dayCount, 7);
    });

    test('۲ هفته آینده ۱۴ روز است', () {
      final r = RitmoDateParser.parse('۲ هفته آینده', now: base);
      expect(r.dayCount, 14);
      expect(r.startIso, '2026-08-17');
      expect(r.endIso, '2026-08-30');
    });
  });

  group('تاریخ عددی و نام ماه شمسی', () {
    test('تاریخ جلالی به میلادی ترجمه می‌شود', () {
      final r = RitmoDateParser.parse('1405/05/25', now: base);
      expect(r.startIso, '2026-08-16');
      expect(r.isRange, isFalse);
    });

    test('تاریخ میلادی دست‌نخورده می‌ماند', () {
      expect(RitmoDateParser.parse('2026-09-01', now: base).startIso,
          '2026-09-01');
    });

    test('«۲۰ مرداد ۱۴۰۵» یک روز مشخص است', () {
      final r = RitmoDateParser.parse('۲۰ مرداد ۱۴۰۵ چی داشتم؟', now: base);
      expect(r.startIso, '2026-08-11');
      expect(r.isRange, isFalse);
    });

    test('نام خالی ماه = کل همان ماه شمسی', () {
      final r = RitmoDateParser.parse('مرداد چطور گذشت؟', now: base);
      expect(r.isRange, isTrue);
      expect(r.startIso, '2026-07-23');
      expect(r.endIso, '2026-08-22');
      expect(r.dayCount, 31);
    });
  });

  group('نام روز هفته', () {
    test('جمعه = نزدیک‌ترین جمعه پیش‌رو', () {
      expect(RitmoDateParser.parse('جمعه برنامهم چیه؟', now: base).startIso,
          '2026-08-21');
    });

    test('جمعه گذشته = نزدیک‌ترین جمعه قبل', () {
      expect(
          RitmoDateParser.parse('جمعه گذشته چقدر خوابیدم؟', now: base)
              .startIso,
          '2026-08-14');
    });
  });

  group('hasDateHint و label', () {
    test('نشانه تاریخ درست تشخیص داده می‌شود', () {
      expect(RitmoDateParser.hasDateHint('برنامه فردا'), isTrue);
      expect(RitmoDateParser.hasDateHint('۲۰ مرداد'), isTrue);
      expect(RitmoDateParser.hasDateHint('سلام دستیار'), isFalse);
    });

    test('برچسب فارسی هم جلالی و هم میلادی دارد', () {
      final label = RitmoDateParser.label(DateTime(2026, 8, 16));
      expect(label.contains('1405/05/25'), isTrue);
      expect(label.contains('(2026-08-16)'), isTrue);
      expect(label.startsWith('یکشنبه'), isTrue);
    });
  });
}
