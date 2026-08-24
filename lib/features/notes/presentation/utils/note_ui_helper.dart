import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/notes/domain/note_models.dart';
import 'package:shamsi_date/shamsi_date.dart';

class NoteKindStyle {
  final Color accentColor;
  final Color bgTint;
  final IconData icon;
  final String labelFa;
  final String emoji;

  const NoteKindStyle({
    required this.accentColor,
    required this.bgTint,
    required this.icon,
    required this.labelFa,
    required this.emoji,
  });
}

class NoteUiHelper {
  NoteUiHelper._();

  static NoteKindStyle getKindStyle(BuildContext context, NoteKind kind) {
    final modules = context.modules;
    final colors = context.colors;

    final Color accent;
    final IconData icon;
    final String labelFa;
    final String emoji;

    switch (kind) {
      case NoteKind.experience:
        accent = modules.insights;
        icon = Icons.lightbulb_rounded;
        labelFa = 'درس زندگی';
        emoji = '💡';
        break;
      case NoteKind.idea:
        accent = modules.study;
        icon = Icons.bolt_rounded;
        labelFa = 'ایده نو';
        emoji = '⚡';
        break;
      case NoteKind.decision:
        accent = modules.goals;
        icon = Icons.check_circle_rounded;
        labelFa = 'تصمیم قطعی';
        emoji = '🎯';
        break;
      case NoteKind.daily:
        accent = modules.health;
        icon = Icons.auto_stories_rounded;
        labelFa = 'ژورنال روزانه';
        emoji = '📅';
        break;
      case NoteKind.gratitude:
        accent = const Color(0xffEC4899);
        icon = Icons.favorite_rounded;
        labelFa = 'شکرگزاری';
        emoji = '💖';
        break;
      case NoteKind.note:
        accent = colors.primary;
        icon = Icons.description_rounded;
        labelFa = 'یادداشت';
        emoji = '📓';
        break;
    }

    final bgTint = accent.withValues(alpha: context.isDark ? 0.16 : 0.10);

    return NoteKindStyle(
      accentColor: accent,
      bgTint: bgTint,
      icon: icon,
      labelFa: labelFa,
      emoji: emoji,
    );
  }

  static String formatRelativeDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) {
      return 'همین الان';
    } else if (diff.inMinutes < 60) {
      return '${PersianDigits.convert(diff.inMinutes.toString())} دقیقه پیش';
    } else if (diff.inHours < 24 && dt.day == now.day) {
      final hour = PersianDigits.convert(dt.hour.toString().padLeft(2, '0'));
      final min = PersianDigits.convert(dt.minute.toString().padLeft(2, '0'));
      return 'امروز، $hour:$min';
    } else if (diff.inDays < 2 ||
        (diff.inHours < 48 &&
            dt.day == now.subtract(const Duration(days: 1)).day)) {
      final hour = PersianDigits.convert(dt.hour.toString().padLeft(2, '0'));
      final min = PersianDigits.convert(dt.minute.toString().padLeft(2, '0'));
      return 'دیروز، $hour:$min';
    } else if (diff.inDays < 7) {
      return '${PersianDigits.convert(diff.inDays.toString())} روز پیش';
    } else {
      final j = Jalali.fromDateTime(dt);
      final monthNames = [
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
      final day = PersianDigits.convert(j.day.toString());
      final month = monthNames[j.month - 1];
      if (j.year == Jalali.now().year) {
        return '$day $month';
      } else {
        return '$day $month ${PersianDigits.convert(j.year.toString())}';
      }
    }
  }

  static String timeOfDayLabelFa(String? tod) {
    if (tod == null) return 'روز';
    switch (tod.trim().toUpperCase()) {
      case 'MORNING':
        return 'صبح';
      case 'AFTERNOON':
        return 'ظهر';
      case 'EVENING':
        return 'عصر';
      case 'NIGHT':
        return 'شب';
      default:
        return 'روز';
    }
  }

  static String monthName(int month) {
    const names = [
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
    if (month >= 1 && month <= 12) return names[month - 1];
    return '';
  }

  static String calculateReadingTime(int wordCount) {
    if (wordCount <= 0) return 'زمان مطالعه: ۱ دقیقه';
    final minutes = (wordCount / 180).ceil();
    if (minutes <= 1) {
      return 'مطالعه کمتر از ۱ دقیقه';
    }
    return '${PersianDigits.convert(minutes.toString())} دقیقه مطالعه';
  }

  static List<TextSpan> buildHighlightedTextSpans({
    required String text,
    required String query,
    required TextStyle baseStyle,
    required Color highlightBg,
    required Color highlightColor,
  }) {
    if (query.trim().isEmpty || text.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    final spans = <TextSpan>[];
    final q = query.trim().toLowerCase();
    final lowerText = text.toLowerCase();

    int start = 0;
    int index = lowerText.indexOf(q, start);

    while (index != -1) {
      if (index > start) {
        spans.add(
          TextSpan(text: text.substring(start, index), style: baseStyle),
        );
      }

      final matchText = text.substring(index, index + q.length);
      spans.add(
        TextSpan(
          text: matchText,
          style: baseStyle.copyWith(
            backgroundColor: highlightBg,
            color: highlightColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      start = index + q.length;
      index = lowerText.indexOf(q, start);
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: baseStyle));
    }

    return spans;
  }
}
