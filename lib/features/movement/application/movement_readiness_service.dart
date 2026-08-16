import 'dart:async';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/schema/tables/movement_tables.dart';
import 'package:ritmo/features/movement/domain/models/movement_readiness_checkin.dart';
import 'package:sqflite/sqflite.dart';

/// مدل نتیجهٔ ارزیابی آمادگی (صرفاً وصفی و بدون عدد/درصد)
class ReadinessEvaluationResult {
  const ReadinessEvaluationResult({
    required this.statusHeadline,
    required this.reasonSummary,
    required this.suggestions,
  });

  final String statusHeadline;
  final String reasonSummary;
  final List<String> suggestions; // حداکثر ۳ پیشنهاد
}

/// مدل پیشنهاد مربی (سه لایه: پیشنهاد + دلیل + اکشن‌ها)
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

/// سرویس مدیریت آمادگی، چک‌این و پیشنهادات مربی (Gate 5)
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

  /// بررسی لزوم نمایش خودکار چک‌این (حداکثر ۱ بار در روز)
  Future<bool> shouldShowAutoCheckin([DateTime? date]) async {
    final existing = await getTodayCheckin(date);
    return existing == null;
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

  /// ارزیابی آمادگی بر اساس چک‌این (بدون عدد از ۱۰۰ یا درصد ریکاوری)
  ReadinessEvaluationResult computeReadinessResult(MovementReadinessCheckin checkin) {
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

  /// دریافت پیشنهاد مربی هوشمند (حداکثر ۱ پیشنهاد بر اساس وضعیت، بدون اعمال خودکار)
  Future<CoachSuggestion?> getCoachSuggestion({
    required MovementReadinessCheckin? checkin,
    required List<String> dismissedSuggestionIds,
  }) async {
    if (checkin == null) {
      if (!dismissedSuggestionIds.contains('sug_general_consistency')) {
        return const CoachSuggestion(
          id: 'sug_general_consistency',
          text: 'ثبت منظم وضعیت آمادگی به تنظیم دقیق‌تر حجم و فشار تمرینات کمک می‌کند.',
          reason: 'پیوستگی تمرینی',
          reasonIcon: 'fitness_center',
          primaryActionLabel: 'ثبت آمادگی امروز',
          secondaryActionLabel: 'یادآوری بعداً',
          dismissActionLabel: 'رد کردن',
        );
      }
      return null;
    }

    final eval = computeReadinessResult(checkin);

    if (eval.suggestions.any((s) => s.contains('Plan B'))) {
      if (!dismissedSuggestionIds.contains('sug_plan_b_recovery')) {
        return const CoachSuggestion(
          id: 'sug_plan_b_recovery',
          text: 'پیشنهاد می‌شود امروز از نسخهٔ سبک‌تر جلسه (Plan B) با ۲۰٪ شدت کمتر استفاده کنید.',
          reason: 'ریکاوری هوشمند',
          reasonIcon: 'auto_mode',
          primaryActionLabel: 'انتخاب Plan B',
          secondaryActionLabel: 'مشاهدهٔ گزینه‌ها',
          dismissActionLabel: 'رد پیشنهاد',
        );
      }
    }

    if (eval.statusHeadline.contains('بسیار مناسب')) {
      if (!dismissedSuggestionIds.contains('sug_high_energy_focus')) {
        return const CoachSuggestion(
          id: 'sug_high_energy_focus',
          text: 'آمادگی بالای امروز فرصت مناسبی برای تمرکز روی تمپو و کیفیت اجرای حرکات است.',
          reason: 'کیفیت حرکت',
          reasonIcon: 'verified',
          primaryActionLabel: 'شروع جلسه',
          secondaryActionLabel: 'تنظیم اهداف',
          dismissActionLabel: 'رد پیشنهاد',
        );
      }
    }

    return null;
  }
}
