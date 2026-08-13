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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (kind) {
      case NoteKind.experience:
        return NoteKindStyle(
          accentColor: const Color(0xFFE5A00D), // Warm Amber Gold
          bgTint: isDark ? const Color(0xFF261E08) : const Color(0xFFFFFBF0),
          icon: Icons.lightbulb_rounded,
          labelFa: 'درس زندگی',
          emoji: '💡',
        );
      case NoteKind.idea:
        return NoteKindStyle(
          accentColor: const Color(0xFF00B4D8), // Vibrant Cyan/Electric
          bgTint: isDark ? const Color(0xFF06202A) : const Color(0xFFF0FAFD),
          icon: Icons.bolt_rounded,
          labelFa: 'ایده نو',
          emoji: '⚡',
        );
      case NoteKind.decision:
        return NoteKindStyle(
          accentColor: const Color(0xFF10B981), // Emerald Green
          bgTint: isDark ? const Color(0xFF062419) : const Color(0xFFF0FDF4),
          icon: Icons.check_circle_rounded,
          labelFa: 'تصمیم قطعی',
          emoji: '🎯',
        );
      case NoteKind.daily:
        return NoteKindStyle(
          accentColor: const Color(0xFFEC4899), // Soft Rose / Journal
          bgTint: isDark ? const Color(0xFF280B1B) : const Color(0xFFFDF2F8),
          icon: Icons.auto_stories_rounded,
          labelFa: 'ژورنال روزانه',
          emoji: '📅',
        );
      case NoteKind.note:
      default:
        final primary = context.colors.primary;
        return NoteKindStyle(
          accentColor: primary,
          bgTint: isDark ? primary.withValues(alpha: 0.08) : primary.withValues(alpha: 0.04),
          icon: Icons.description_rounded,
          labelFa: 'یادداشت',
          emoji: '📓',
        );
    }
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
    } else if (diff.inDays < 2 || (diff.inHours < 48 && dt.day == now.subtract(const Duration(days: 1)).day)) {
      final hour = PersianDigits.convert(dt.hour.toString().padLeft(2, '0'));
      final min = PersianDigits.convert(dt.minute.toString().padLeft(2, '0'));
      return 'دیروز، $hour:$min';
    } else if (diff.inDays < 7) {
      return '${PersianDigits.convert(diff.inDays.toString())} روز پیش';
    } else {
      final j = Jalali.fromDateTime(dt);
      final monthNames = [
        'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
        'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'
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

  static String calculateReadingTime(int wordCount) {
    if (wordCount <= 0) return 'زمان مطالعه: ۱ دقیقه';
    final minutes = (wordCount / 180).ceil();
    if (minutes <= 1) {
      return 'مطالعه کمتر از ۱ دقیقه';
    }
    return '${PersianDigits.convert(minutes.toString())} دقیقه مطالعه';
  }
}
