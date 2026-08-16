import 'package:shamsi_date/shamsi_date.dart';

/// بازه تاریخی حل‌شده از متن آزاد کاربر
class RitmoDateRange {
  final DateTime start;
  final DateTime end;
  final String labelFa;

  /// اگر true باشد، کاربر واقعا بازه خواسته (مثل «هفته بعد») نه یک روز.
  final bool isRange;

  /// اگر false باشد، متن هیچ نشانه تاریخی نداشت و امروز فرض شده است.
  final bool matched;

  const RitmoDateRange({
    required this.start,
    required this.end,
    required this.labelFa,
    this.isRange = false,
    this.matched = true,
  });

  int get dayCount => end.difference(start).inDays + 1;

  String get startIso => RitmoDateParser.iso(start);

  String get endIso => RitmoDateParser.iso(end);
}

/// پارسر تاریخ فارسی برای ایجنت (فاز ۴ · P4-1)
///
/// تفاوت با AgentDateResolver: آن فقط یک روز را برمی‌گرداند و تنها چند
/// کلیدواژه می‌فهمد؛ این‌جا بازه، نام ماه شمسی، نام روز هفته و عبارت‌های
/// «X روز آینده/گذشته» هم پشتیبانی می‌شود. هیچ وابستگی به لایه ابزار ندارد
/// تا مستقیما قابل تست واحد باشد.
class RitmoDateParser {
  const RitmoDateParser._();

  static const String _faDigits = '۰۱۲۳۴۵۶۷۸۹';
  static const String _arDigits = '٠١٢٣٤٥٦٧٨٩';

  static const List<String> monthsFa = <String>[
    'فروردین',
    'اردیبهشت',
    'خرداد',
    'تیر',
    'مرداد',
    'شهریور',
    'مهر',
    'آبان',
    'آذر',
    'دی',
    'بهمن',
    'اسفند',
  ];

  /// نام روز هفته → شماره روز در Dart (دوشنبه=1 … یکشنبه=7)
  static const Map<String, int> weekdaysFa = <String, int>{
    'شنبه': 6,
    'یکشنبه': 7,
    'دوشنبه': 1,
    'سهشنبه': 2,
    'چهارشنبه': 3,
    'پنجشنبه': 4,
    'پنجشنبهٔ': 4,
    'جمعه': 5,
  };

  static const List<String> _weekdayLabels = <String>[
    'دوشنبه',
    'سه‌شنبه',
    'چهارشنبه',
    'پنجشنبه',
    'جمعه',
    'شنبه',
    'یکشنبه',
  ];

  /// نرمال‌سازی: ارقام لاتین، حذف نیم‌فاصله، یکدست‌سازی ی/ک
  static String normalize(String input) {
    var out = input.trim().toLowerCase();
    for (var i = 0; i < 10; i++) {
      out = out.replaceAll(_faDigits[i], i.toString());
      out = out.replaceAll(_arDigits[i], i.toString());
    }
    return out
        .replaceAll('\u200c', '')
        .replaceAll('\u064a', '\u06cc')
        .replaceAll('\u0643', '\u06a9')
        .replaceAll('\u0654', '');
  }

  static String iso(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// برچسب خوانا برای مدل: «شنبه ۱۴۰۵/۰۵/۲۵ (2026-08-16)»
  static String label(DateTime date) {
    final weekday = _weekdayLabels[(date.weekday - 1) % 7];
    try {
      final j = Jalali.fromDateTime(date);
      final jm = j.month.toString().padLeft(2, '0');
      final jd = j.day.toString().padLeft(2, '0');
      return '$weekday ${j.year}/$jm/$jd (${iso(date)})';
    } catch (_) {
      return '$weekday (${iso(date)})';
    }
  }

  static DateTime _dayOf(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// شنبه همین هفته (هفته ایرانی از شنبه شروع می‌شود)
  static DateTime startOfPersianWeek(DateTime date) {
    final day = _dayOf(date);
    final offset = (day.weekday + 1) % 7;
    return day.subtract(Duration(days: offset));
  }

  static bool _has(String text, List<String> needles) {
    for (final needle in needles) {
      if (text.contains(normalize(needle))) return true;
    }
    return false;
  }

  /// آیا متن هیچ نشانه تاریخی دارد؟ (روتر نیت از این استفاده می‌کند)
  static bool hasDateHint(String input) {
    final text = normalize(input);
    if (_has(text, <String>[
      'امروز',
      'فردا',
      'دیروز',
      'پس فردا',
      'پسفردا',
      'هفته',
      'ماه',
      'تاریخ',
      'today',
      'tomorrow',
      'yesterday',
    ])) {
      return true;
    }
    for (final month in monthsFa) {
      if (text.contains(normalize(month))) return true;
    }
    for (final weekday in weekdaysFa.keys) {
      if (text.contains(normalize(weekday))) return true;
    }
    return RegExp(r'\d{4}-\d{1,2}-\d{1,2}').hasMatch(text) ||
        RegExp(r'\d{1,2}\s*(روز|هفته)').hasMatch(text);
  }

  /// حل کردن متن به بازه. ورودی ناشناخته = امروز با matched=false.
  static RitmoDateRange parse(String input, {DateTime? now}) {
    final base = _dayOf(now ?? DateTime.now());
    final text = normalize(input);

    RitmoDateRange single(DateTime date, {bool matched = true}) =>
        RitmoDateRange(
          start: date,
          end: date,
          labelFa: label(date),
          matched: matched,
        );

    RitmoDateRange range(DateTime start, DateTime end) => RitmoDateRange(
          start: start,
          end: end,
          labelFa: 'از ${label(start)} تا ${label(end)}',
          isRange: true,
        );

    // ۱. کلیدواژه‌های روز
    if (_has(text, <String>['پس فردا', 'پسفردا'])) {
      return single(base.add(const Duration(days: 2)));
    }
    if (_has(text, <String>['فردا', 'tomorrow'])) {
      return single(base.add(const Duration(days: 1)));
    }
    if (_has(text, <String>['دیروز', 'yesterday'])) {
      return single(base.subtract(const Duration(days: 1)));
    }

    // ۲. بازه‌های هفتگی
    final weekStart = startOfPersianWeek(base);
    if (_has(text, <String>['هفته بعد', 'هفته آینده', 'هفته دیگر', 'next week'])) {
      final start = weekStart.add(const Duration(days: 7));
      return range(start, start.add(const Duration(days: 6)));
    }
    if (_has(text, <String>['هفته قبل', 'هفته گذشته', 'last week'])) {
      final start = weekStart.subtract(const Duration(days: 7));
      return range(start, start.add(const Duration(days: 6)));
    }
    if (_has(text, <String>['این هفته', 'هفته جاری', 'this week'])) {
      return range(weekStart, weekStart.add(const Duration(days: 6)));
    }

    // ۳. بازه‌های ماهانه شمسی
    if (_has(text, <String>['ماه بعد', 'ماه آینده', 'next month'])) {
      return _jalaliMonthRange(base, 1, range);
    }
    if (_has(text, <String>['ماه قبل', 'ماه گذشته', 'last month'])) {
      return _jalaliMonthRange(base, -1, range);
    }
    if (_has(text, <String>['این ماه', 'ماه جاری', 'this month'])) {
      return _jalaliMonthRange(base, 0, range);
    }

    // ۴. «X روز آینده/گذشته» و «X هفته آینده»
    final spanMatch =
        RegExp(r'(\d{1,3})\s*(روز|هفته)\s*(آینده|بعد|آتی|گذشته|قبل|اخیر)')
            .firstMatch(text);
    if (spanMatch != null) {
      final rawCount = int.tryParse(spanMatch.group(1) ?? '') ?? 1;
      final unitDays = spanMatch.group(2) == 'هفته' ? 7 : 1;
      final total = (rawCount * unitDays).clamp(1, 366).toInt();
      final direction = spanMatch.group(3) ?? '';
      final isPast = direction == 'گذشته' ||
          direction == 'قبل' ||
          direction == 'اخیر';
      if (isPast) {
        return range(base.subtract(Duration(days: total - 1)), base);
      }
      return range(base, base.add(Duration(days: total - 1)));
    }

    // ۵. تاریخ عددی: 1405/05/26 یا 2026-08-17
    final numeric = RegExp(r'(\d{4})\s*[-/.]\s*(\d{1,2})\s*[-/.]\s*(\d{1,2})')
        .firstMatch(text);
    if (numeric != null) {
      final y = int.tryParse(numeric.group(1) ?? '');
      final m = int.tryParse(numeric.group(2) ?? '');
      final d = int.tryParse(numeric.group(3) ?? '');
      if (y != null && m != null && d != null && m >= 1 && m <= 12 && d >= 1 && d <= 31) {
        if (y >= 1200 && y < 1700) {
          try {
            return single(Jalali(y, m, d).toGregorian().toDateTime());
          } catch (_) {
            return single(base, matched: false);
          }
        }
        try {
          return single(DateTime(y, m, d));
        } catch (_) {
          return single(base, matched: false);
        }
      }
    }

    // ۶. «۲۰ مرداد» یا «۲۰ مرداد ۱۴۰۵» یا خود نام ماه
    for (var i = 0; i < monthsFa.length; i++) {
      final monthName = normalize(monthsFa[i]);
      if (!text.contains(monthName)) continue;

      final jToday = Jalali.fromDateTime(base);
      final dayMatch =
          RegExp('(\\d{1,2})\\s*$monthName(?:\\s*(\\d{4}))?').firstMatch(text);
      if (dayMatch != null) {
        final day = int.tryParse(dayMatch.group(1) ?? '') ?? 1;
        final year = int.tryParse(dayMatch.group(2) ?? '') ?? jToday.year;
        try {
          return single(
              Jalali(year, i + 1, day.clamp(1, 31)).toGregorian().toDateTime());
        } catch (_) {
          return single(base, matched: false);
        }
      }

      // فقط نام ماه: کل آن ماه شمسی
      try {
        final start = Jalali(jToday.year, i + 1, 1).toGregorian().toDateTime();
        final nextMonth = i + 1 >= 12
            ? Jalali(jToday.year + 1, 1, 1)
            : Jalali(jToday.year, i + 2, 1);
        final end = nextMonth
            .toGregorian()
            .toDateTime()
            .subtract(const Duration(days: 1));
        return range(start, end);
      } catch (_) {
        return single(base, matched: false);
      }
    }

    // ۷. نام روز هفته («شنبه آینده»، «جمعه گذشته»، «پنجشنبه»)
    for (final entry in weekdaysFa.entries) {
      final name = normalize(entry.key);
      if (name.isEmpty || !text.contains(name)) continue;
      final isPast = _has(text, <String>['گذشته', 'قبل', 'پیش']);
      return single(_nearestWeekday(base, entry.value, past: isPast));
    }

    if (_has(text, <String>['امروز', 'today', 'الان', 'همین امروز'])) {
      return single(base);
    }

    return single(base, matched: false);
  }

  static RitmoDateRange _jalaliMonthRange(
    DateTime base,
    int monthDelta,
    RitmoDateRange Function(DateTime, DateTime) range,
  ) {
    final j = Jalali.fromDateTime(base);
    var year = j.year;
    var month = j.month + monthDelta;
    while (month > 12) {
      month -= 12;
      year += 1;
    }
    while (month < 1) {
      month += 12;
      year -= 1;
    }
    try {
      final start = Jalali(year, month, 1).toGregorian().toDateTime();
      final next =
          month >= 12 ? Jalali(year + 1, 1, 1) : Jalali(year, month + 1, 1);
      final end =
          next.toGregorian().toDateTime().subtract(const Duration(days: 1));
      return range(start, end);
    } catch (_) {
      final day = _dayOf(base);
      return range(day, day);
    }
  }

  /// نزدیک‌ترین وقوع یک روز هفته (پیش‌رو یا گذشته). امروز شمرده نمی‌شود.
  static DateTime _nearestWeekday(DateTime base, int weekday,
      {bool past = false}) {
    final day = _dayOf(base);
    if (past) {
      var diff = day.weekday - weekday;
      if (diff <= 0) diff += 7;
      return day.subtract(Duration(days: diff));
    }
    var diff = weekday - day.weekday;
    if (diff <= 0) diff += 7;
    return day.add(Duration(days: diff));
  }
}
