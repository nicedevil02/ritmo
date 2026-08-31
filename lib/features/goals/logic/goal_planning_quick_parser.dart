import 'package:ritmo/core/utils/ritmo_date.dart';
import 'package:ritmo/features/goals/logic/planning_week.dart';
import 'package:ritmo/features/goals/models/planning_models.dart';

/// نتیجهٔ تجزیهٔ سریع متن فارسی
class QuickPlanningParseResult {
  const QuickPlanningParseResult({
    required this.rawText,
    required this.cleanTitle,
    required this.dayKey,
    required this.durationMinutes,
    required this.importance,
    this.matchedDayLabel,
  });

  final String rawText;
  final String cleanTitle;
  final String dayKey;
  final int durationMinutes;
  final CommitmentImportance importance;
  final String? matchedDayLabel;
}

/// موتور هوشمند و آفلاین تجزیه زبان طبیعی برای ثبت برنامه‌ها به زبان فارسی
class GoalPlanningQuickParser {
  const GoalPlanningQuickParser();

  /// تبدیل ارقام فارسی و عربی به انگلیسی
  static String normalizePersianDigits(String input) {
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var res = input;
    for (var i = 0; i < 10; i++) {
      res = res.replaceAll(persian[i], i.toString());
      res = res.replaceAll(arabic[i], i.toString());
    }
    return res;
  }

  /// تجزیه متن و استخراج عنوان، روز و زمان
  QuickPlanningParseResult parse(String raw, {DateTime? now, String? defaultDayKey}) {
    final baseNow = now ?? DateTime.now();
    var text = normalizePersianDigits(raw.trim());

    var durationMinutes = 30;
    var importance = CommitmentImportance.should;
    String? matchedDayLabel;
    String? targetDayKey;

    // ۱. استخراج اهمیت (بدون وابستگی به \b غیر یونیکد)
    final mustRegex = RegExp(r'(^|\s+)(فوری|حیاتی|خیلی مهم|الزامی|ضروری)($|\s+)');
    if (mustRegex.hasMatch(text)) {
      importance = CommitmentImportance.must;
      text = text.replaceAll(mustRegex, ' ');
    } else {
      final couldRegex = RegExp(r'(^|\s+)(اختیاری|اگه شد|سر فرصت)($|\s+)');
      if (couldRegex.hasMatch(text)) {
        importance = CommitmentImportance.could;
        text = text.replaceAll(couldRegex, ' ');
      }
    }

    // ۲. استخراج مدت زمان
    // الگوهای ساعت: «X ساعت»، «نیم ساعت»، «یک ربع»، «X.۵ ساعت»
    if (RegExp(r'(نیم\s*ساعت|۳۰\s*دقیقه)').hasMatch(text)) {
      durationMinutes = 30;
      text = text.replaceAll(RegExp(r'(نیم\s*ساعت|۳۰\s*دقیقه)'), ' ');
    } else if (RegExp(r'(یک\s*ربع|۱۵\s*دقیقه)').hasMatch(text)) {
      durationMinutes = 15;
      text = text.replaceAll(RegExp(r'(یک\s*ربع|۱۵\s*دقیقه)'), ' ');
    } else {
      final hourMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:ساعت|س)').firstMatch(text);
      if (hourMatch != null) {
        final hVal = double.tryParse(hourMatch.group(1)!) ?? 1.0;
        durationMinutes = (hVal * 60).round();
        text = text.replaceAll(hourMatch.group(0)!, ' ');
      } else {
        final minMatch = RegExp(r'(\d+)\s*(?:دقیقه|د)').firstMatch(text);
        if (minMatch != null) {
          durationMinutes = int.tryParse(minMatch.group(1)!) ?? 30;
          text = text.replaceAll(minMatch.group(0)!, ' ');
        }
      }
    }

    // ۳. استخراج روز هفته یا روزهای نسبی (امروز، فردا، پس‌فردا)
    // ترتیب از طولانی‌ترین عبارت به کوتاه‌ترین تا "دوشنبه" با "شنبه" اشتباه نشود!
    final weekDayKeys = PlanningWeek.dayKeysOfWeekContaining(baseNow);

    if (text.contains('پس‌فردا') || text.contains('پس فردا')) {
      matchedDayLabel = 'پس‌فردا';
      targetDayKey = RitmoDate.dayKey(baseNow.add(const Duration(days: 2)));
      text = text.replaceAll(RegExp(r'پس\s*فردا'), ' ');
    } else if (text.contains('فردا')) {
      matchedDayLabel = 'فردا';
      targetDayKey = RitmoDate.dayKey(baseNow.add(const Duration(days: 1)));
      text = text.replaceAll('فردا', ' ');
    } else if (text.contains('امروز')) {
      matchedDayLabel = 'امروز';
      targetDayKey = RitmoDate.dayKey(baseNow);
      text = text.replaceAll('امروز', ' ');
    } else {
      // روزهای مشخص هفته به ترتیب اولویت طول
      final dayMap = {
        'چهارشنبه': 5,
        '4شنبه': 5,
        'پنج‌شنبه': 6,
        'پنج شنبه': 6,
        '5شنبه': 6,
        'سه‌شنبه': 4,
        'سه شنبه': 4,
        '3شنبه': 4,
        'یکشنبه': 2,
        '1شنبه': 2,
        'دوشنبه': 3,
        '2شنبه': 3,
        'شنبه': 1,
        'جمعه': 7,
      };

      for (final entry in dayMap.entries) {
        if (text.contains(entry.key)) {
          matchedDayLabel = entry.key;
          final targetIndex = entry.value - 1; // 0..6
          if (targetIndex >= 0 && targetIndex < weekDayKeys.length) {
            targetDayKey = weekDayKeys[targetIndex];
          }
          text = text.replaceAll(entry.key, ' ');
          break;
        }
      }
    }

    // اگر روز مشخصی پیدا نشد، از defaultDayKey یا امروز استفاده می‌شود
    targetDayKey ??= defaultDayKey ?? RitmoDate.dayKey(baseNow);

    // تمیز کردن عنوان نهایی
    var cleanTitle = text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[،,؛;\s]+|[،,؛;\s]+$'), '')
        .trim();

    if (cleanTitle.isEmpty) {
      cleanTitle = raw.trim();
    }

    return QuickPlanningParseResult(
      rawText: raw,
      cleanTitle: cleanTitle,
      dayKey: targetDayKey,
      durationMinutes: durationMinutes.clamp(5, 480),
      importance: importance,
      matchedDayLabel: matchedDayLabel,
    );
  }
}
