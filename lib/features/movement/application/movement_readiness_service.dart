import 'dart:async';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/schema/tables/movement_tables.dart';
import 'package:ritmo/features/movement/domain/models/movement_readiness_checkin.dart';
import 'package:sqflite/sqflite.dart';

/// سطوح آمادگی بدنی روزانه (P-05)
enum ReadinessTier { rest, minimal, light, full }

/// وضعیت‌های چرخهٔ فیزیولوژیک جهت تنظیم سقف آمادگی (P-05)
enum MovementCycleStatus { none, menstruation, pms, fertile, pregnancy, other }

/// کلاس پایهٔ نتایج ارزیابی آمادگی (P-05)
sealed class ReadinessResult {
  const ReadinessResult();
}

class ReadinessReady extends ReadinessResult {
  const ReadinessReady({
    required this.tier,
    required this.score,
    required this.suggestionFa,
    required this.isEstimated,
  });

  final ReadinessTier tier; // rest | minimal | light | full
  final int score; // 0-100
  final String suggestionFa; // یک جمله، فارسی
  final bool isEstimated; // true اگر هر داده‌ای null بود
}

class ReadinessNoData extends ReadinessResult {
  const ReadinessNoData();
}

/// مدل نتیجهٔ ارزیابی آمادگی جهت نمایش در کارت‌های توصیفی
class ReadinessEvaluationResult {
  const ReadinessEvaluationResult({
    required this.statusHeadline,
    required this.reasonSummary,
    required this.suggestions,
  });

  final String statusHeadline;
  final String reasonSummary;
  final List<String> suggestions;
}

/// مدل پیشنهاد مربی هوشمند (سه لایه: پیشنهاد + دلیل + اکشن‌ها)
class CoachSuggestion {
  const CoachSuggestion({
    required this.id,
    required this.text,
    required this.reason,
    this.reasonIcon,
    this.primaryActionLabel = 'پذیرش پیشنهاد',
    this.secondaryActionLabel = 'تغییر',
    this.dismissActionLabel = 'رد کردن',
  });

  final String id;
  final String text;
  final String reason;
  final String? reasonIcon;
  final String primaryActionLabel;
  final String secondaryActionLabel;
  final String dismissActionLabel;
}

/// سرویس مدیریت و ارزیابی آمادگی واقعی بر اساس وضعیت ۲۴ ساعت گذشته و سقف فیزیولوژیک (P-05 / P-06)
class MovementReadinessService {
  MovementReadinessService({this.db});

  final Database? db;

  Future<Database> get _database async =>
      db ?? await DatabaseHelper.instance.database;

  static String _formatIso(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// دریافت چک‌این امروز کاربر در صورت وجود
  Future<MovementReadinessCheckin?> getTodayCheckin([DateTime? date]) async {
    final targetDate = date ?? DateTime.now();
    final dateIso = _formatIso(targetDate);
    final dbExec = await _database;

    final rows = await dbExec.query(
      MovementTables.tableReadinessCheckins,
      where: 'dateIso = ?',
      whereArgs: [dateIso],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return MovementReadinessCheckin.fromMap(rows.first);
  }

  /// ثبت یا به‌روزرسانی چک‌این روزانه
  Future<void> recordCheckin(MovementReadinessCheckin checkin) async {
    final dbExec = await _database;
    await dbExec.insert(
      MovementTables.tableReadinessCheckins,
      checkin.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// ارزیابی آمادگی بر اساس چک‌این و وضعیت فیزیولوژیک (P-05)
  ReadinessResult evaluateReadiness({
    required MovementReadinessCheckin? checkin,
    MovementCycleStatus cycleStatus = MovementCycleStatus.none,
  }) {
    if (checkin == null) {
      return const ReadinessNoData();
    }

    // بررسی سقف وضعیت فیزیولوژیک (P-05)
    ReadinessTier ceilTier = ReadinessTier.full;
    int ceilScore = 100;

    switch (cycleStatus) {
      case MovementCycleStatus.menstruation:
        ceilTier = ReadinessTier.minimal;
        ceilScore = 40;
        break;
      case MovementCycleStatus.pms:
        ceilTier = ReadinessTier.light;
        ceilScore = 65;
        break;
      case MovementCycleStatus.fertile:
        ceilTier = ReadinessTier.full;
        ceilScore = 100;
        break;
      case MovementCycleStatus.pregnancy:
        ceilTier = ReadinessTier.rest;
        ceilScore = 20;
        break;
      case MovementCycleStatus.none:
      case MovementCycleStatus.other:
        ceilTier = ReadinessTier.full;
        ceilScore = 100;
        break;
    }

    final bool isEstimated = (checkin.sleep == null ||
        checkin.energy == null ||
        checkin.soreness == null ||
        checkin.stress == null);

    // محاسبه خام امتیاز (0-100)
    final sleep = (checkin.sleep ?? 3).clamp(1, 5);
    final energy = (checkin.energy ?? 3).clamp(1, 5);
    final soreness = (checkin.soreness ?? 1).clamp(1, 5);
    final stress = (checkin.stress ?? 1).clamp(1, 5);

    final sleepScore = ((sleep - 1) / 4.0) * 30.0;
    final energyScore = ((energy - 1) / 4.0) * 35.0;
    final sorenessScore = ((5 - soreness) / 4.0) * 20.0;
    final stressScore = ((5 - stress) / 4.0) * 15.0;

    final rawScore =
        (sleepScore + energyScore + sorenessScore + stressScore).round().clamp(0, 100);

    // اعمال سقف
    final finalScore = rawScore > ceilScore ? ceilScore : rawScore;

    // تعیین تیر نهایی با احترام به سقف
    ReadinessTier finalTier;
    if (finalScore <= 25 || ceilTier == ReadinessTier.rest) {
      finalTier = ReadinessTier.rest;
    } else if (finalScore <= 45 || ceilTier == ReadinessTier.minimal) {
      finalTier = ReadinessTier.minimal;
    } else if (finalScore <= 70 || ceilTier == ReadinessTier.light) {
      finalTier = ReadinessTier.light;
    } else {
      finalTier = ReadinessTier.full;
    }

    // تولید جملهٔ پیشنهاد بر اساس الگوی استاندارد بدون ذکر چرخه (P-06)
    final String suggestionFa;
    switch (finalTier) {
      case ReadinessTier.rest:
        suggestionFa = 'امروز استراحت کردن هم یه انتخاب خوبه.';
        break;
      case ReadinessTier.minimal:
        suggestionFa = 'با توجه به وضعیت امروزت، ۱۵ دقیقه تمرین سبک بهت میاد.';
        break;
      case ReadinessTier.light:
        suggestionFa = 'با توجه به وضعیت امروزت، ۳۰ دقیقه بهت میاد.';
        break;
      case ReadinessTier.full:
        suggestionFa = 'با توجه به وضعیت امروزت، ۴۵ دقیقه بهت میاد.';
        break;
    }

    return ReadinessReady(
      tier: finalTier,
      score: finalScore,
      suggestionFa: suggestionFa,
      isEstimated: isEstimated,
    );
  }

  /// دریافت نتیجه آمادگی روزانه با بازیابی از دیتابیس
  Future<ReadinessResult> getTodayReadinessResult({
    DateTime? date,
    MovementCycleStatus cycleStatus = MovementCycleStatus.none,
  }) async {
    final checkin = await getTodayCheckin(date);
    return evaluateReadiness(checkin: checkin, cycleStatus: cycleStatus);
  }

  /// ارزیابی آمادگی بر اساس چک‌این (جهت ویجت‌های نمایشی)
  ReadinessEvaluationResult computeReadinessResult(
    MovementReadinessCheckin checkin,
  ) {
    final sleep = checkin.sleep ?? 3;
    final energy = checkin.energy ?? 3;
    final soreness = checkin.soreness ?? 1;
    final stress = checkin.stress ?? 1;

    if (sleep >= 4 && energy >= 4 && soreness <= 2 && stress <= 2) {
      return const ReadinessEvaluationResult(
        statusHeadline: 'آمادگی بسیار مناسب برای اجرای تمرین',
        reasonSummary: 'کیفیت استراحت بالا و سطح انرژی بسیار مطلوب',
        suggestions: [
          'ادامهٔ تمرین طبق برنامهٔ اصلی',
          'امکان انجام ست‌های با تمرکز بیشتر یا ثبت رکورد ملایم',
        ],
      );
    }

    if (sleep <= 2 || soreness >= 4 || stress >= 4) {
      return const ReadinessEvaluationResult(
        statusHeadline: 'نیاز به تمرکز بر ریکاوری و کاهش فشار',
        reasonSummary: 'احساس کوفتگی عضلانی، خواب ناکافی یا استرس روزمره',
        suggestions: [
          'اجرای نسخهٔ سبک‌تر جلسه (Plan B)',
          'ریکاوری فعال، کشش ملایم یا پیاده‌روی کوتاه',
          'جابه‌جایی جلسه به روز بعد در صورت نیاز به استراحت کامل',
        ],
      );
    }

    return const ReadinessEvaluationResult(
      statusHeadline: 'آمادگی پایدار و مناسب برای تمرین',
      reasonSummary: 'وضعیت عمومی متعادل برای فعالیت روزانه',
      suggestions: [
        'ادامه طبق برنامهٔ پیش‌بینی‌شده',
        'گرم‌کردن دقیق‌تر پیش از ست‌ها یا حرکات اصلی',
      ],
    );
  }

  /// دریافت پیشنهاد مربی هوشمند
  Future<CoachSuggestion?> getCoachSuggestion({
    required MovementReadinessCheckin? checkin,
    required List<String> dismissedSuggestionIds,
  }) async {
    if (checkin == null) return null;
    final eval = computeReadinessResult(checkin);

    if (eval.statusHeadline.contains('ریکاوری')) {
      const id = 'sug_recovery';
      if (dismissedSuggestionIds.contains(id)) return null;
      return const CoachSuggestion(
        id: id,
        text: 'امروز تمرکز روی حرکات سبک و ریکاوری به بدنت کمک می‌کنه.',
        reason: 'ریکاوری',
        primaryActionLabel: 'ثبت تمرین سبک',
      );
    }

    final energy = checkin.energy ?? 3;
    final sleep = checkin.sleep ?? 3;
    if (energy >= 4 && sleep >= 4) {
      const id = 'sug_high_energy_focus';
      if (dismissedSuggestionIds.contains(id)) return null;
      return const CoachSuggestion(
        id: id,
        text: 'انرژی و کیفیت خوابت عالیه! امروز بهترین فرصت برای یک تمرین پرقدرته.',
        reason: 'انرژی بالا',
        primaryActionLabel: 'شروع تمرین اصلی',
      );
    }

    const id = 'sug_normal_flow';
    if (dismissedSuggestionIds.contains(id)) return null;
    return const CoachSuggestion(
      id: id,
      text: 'پیوستگی رمز موفقیته؛ طبق برنامه حرکت کن و از ریتمت لذت ببر.',
      reason: 'حفظ ریتم',
      primaryActionLabel: 'ادامه برنامه',
    );
  }
}
