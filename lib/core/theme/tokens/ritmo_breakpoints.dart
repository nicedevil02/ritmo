import 'package:flutter/widgets.dart';

/// کلاس عرض دستگاه. مرزها بر پایهٔ عرض منطقی (logical pixels) هستند.
enum RitmoWidthClass {
  /// تا ۳۵۹ — گوشی‌های کوچک و قدیمی (iPhone SE، اندرویدهای ارزان)
  compact,

  /// ۳۶۰ تا ۴۰۹ — حالت مرجع طراحی
  regular,

  /// ۴۱۰ تا ۵۹۹ — گوشی‌های بزرگ و پلاس
  large,

  /// ۶۰۰ و بالاتر — تبلت و حالت افقی
  expanded,
}

/// کلاس ارتفاع دستگاه — بر پایهٔ ارتفاع قابل استفاده، نه ارتفاع نمایشگر.
enum RitmoHeightClass {
  /// تا ۶۳۹ — گوشی کوتاه یا صفحه‌کلید باز
  short,

  /// ۶۴۰ تا ۸۴۳
  regular,

  /// ۸۴۴ و بالاتر
  tall,
}

/// تنها منبع حقیقت برای هندسه و ابعاد پاسخ‌گوی رابط کاربری ریتمو (R-01).
abstract final class RitmoBreakpoints {
  // مرزهای عرض
  static const double compactMaxWidth = 359.0;
  static const double regularMaxWidth = 409.0;
  static const double largeMaxWidth = 599.0;

  // مرزهای ارتفاع قابل استفاده
  static const double shortMaxHeight = 639.0;
  static const double regularMaxHeight = 843.0;

  // کمینهٔ عرض خانه‌ها — جانشین قانونی crossAxisCount ثابت
  static const double tileMinWidthCompact = 140.0;
  static const double tileMinWidthRegular = 160.0;
  static const double tileMinWidthWide = 190.0;

  // هدف لمس — راهنمای دسترس‌پذیری
  static const double minTouchTarget = 48.0;

  // سقف مقیاس متن که برنامه رسماً پشتیبانی می‌کند (R-08: مرحلهٔ ۱ روی ۱.۳، مرحلهٔ ۲ در فاز ۵ روی ۱.۶)
  static const double supportedMaxTextScale = 1.3;
  static const double supportedMinTextScale = 0.9;

  // حداکثر عرض حباب چت نسبت به عرض در دسترس (R-17)
  static const double chatBubbleMaxWidthFactor = 0.76;

  static RitmoWidthClass widthClassOf(double width) {
    if (width <= compactMaxWidth) return RitmoWidthClass.compact;
    if (width <= regularMaxWidth) return RitmoWidthClass.regular;
    if (width <= largeMaxWidth) return RitmoWidthClass.large;
    return RitmoWidthClass.expanded;
  }

  static RitmoHeightClass heightClassOf(double usableHeight) {
    if (usableHeight <= shortMaxHeight) return RitmoHeightClass.short;
    if (usableHeight <= regularMaxHeight) return RitmoHeightClass.regular;
    return RitmoHeightClass.tall;
  }

  /// ارتفاع واقعاً قابل استفاده: ارتفاع نمایشگر منهای نوارهای سیستمی و صفحه‌کلید.
  /// این تنها فرمول مجاز محاسبهٔ ارتفاع در کل برنامه است.
  static double usableHeight(BuildContext context) {
    final mq = MediaQuery.of(context);
    return mq.size.height -
        mq.padding.top -
        mq.padding.bottom -
        mq.viewInsets.bottom;
  }

  /// سقف ارتفاع یک شیت. هرگز مقدار قطعی نیست — فقط سقف.
  static double sheetMaxHeight(BuildContext context, {double factor = 0.9}) {
    return usableHeight(context) * factor;
  }

  /// شمار ستون محاسبه‌شده از عرض موجود و کمینهٔ عرض خانه.
  /// همیشه دست‌کم ۱ برمی‌گرداند و هرگز صفر یا منفی نمی‌شود.
  static int columnsFor({
    required double availableWidth,
    required double minTileWidth,
    required double spacing,
    int maxColumns = 4,
  }) {
    if (availableWidth <= 0 || minTileWidth <= 0) return 1;
    final maxCols = maxColumns < 1 ? 1 : maxColumns;

    int cols = 1;
    for (int c = maxCols; c >= 1; c--) {
      final totalNeeded = (c * minTileWidth) + ((c - 1) * spacing);
      if (availableWidth >= totalNeeded) {
        cols = c;
        break;
      }
    }
    return cols < 1 ? 1 : cols;
  }
}

/// اکستنشن دسترسی به کلاس‌های هندسه و اندازه در BuildContext (R-02).
extension RitmoScreenX on BuildContext {
  RitmoWidthClass get widthClass =>
      RitmoBreakpoints.widthClassOf(MediaQuery.sizeOf(this).width);

  RitmoHeightClass get heightClass =>
      RitmoBreakpoints.heightClassOf(RitmoBreakpoints.usableHeight(this));

  bool get isCompactWidth => widthClass == RitmoWidthClass.compact;
  bool get isShortHeight => heightClass == RitmoHeightClass.short;

  /// مقیاس متن فعلی به‌صورت عدد.
  double get textScale => MediaQuery.textScalerOf(this).scale(1.0);

  /// مقیاس متن بزرگ — مرز تصمیم‌گیری برای چیدمان جایگزین.
  bool get isLargeTextScale => textScale > 1.2;

  /// صفحه‌کلید باز است.
  bool get isKeyboardOpen => MediaQuery.viewInsetsOf(this).bottom > 0;
}
