import 'dart:convert';
import 'package:ritmo/core/analytics/wellbeing_engine.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/util/ritmo_date.dart';
import 'package:sqflite/sqflite.dart';

/// مدل سطر تاریخچهٔ روزانهٔ شاخص حال و تعادل
class WellbeingDailyRecord {
  const WellbeingDailyRecord({
    required this.date,
    this.indexValue,
    this.confidence = 0.0,
    this.sleepScore,
    this.energyScore,
    this.moodScore,
    this.reflectionScore,
    this.contributionsJson,
    required this.computedAt,
  });

  factory WellbeingDailyRecord.fromMap(Map<String, dynamic> map) {
    return WellbeingDailyRecord(
      date: map['date'] as String,
      indexValue: (map['indexValue'] as num?)?.toDouble(),
      confidence: ((map['confidence'] as num?) ?? 0.0).toDouble(),
      sleepScore: (map['sleepScore'] as num?)?.toDouble(),
      energyScore: (map['energyScore'] as num?)?.toDouble(),
      moodScore: (map['moodScore'] as num?)?.toDouble(),
      reflectionScore: (map['reflectionScore'] as num?)?.toDouble(),
      contributionsJson: map['contributionsJson'] as String?,
      computedAt: (map['computedAt'] as num?)?.toInt() ?? 0,
    );
  }

  final String date;
  final double? indexValue;
  final double confidence;
  final double? sleepScore;
  final double? energyScore;
  final double? moodScore;
  final double? reflectionScore;
  final String? contributionsJson;
  final int computedAt;

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'indexValue': indexValue,
      'confidence': confidence,
      'sleepScore': sleepScore,
      'energyScore': energyScore,
      'moodScore': moodScore,
      'reflectionScore': reflectionScore,
      'contributionsJson': contributionsJson,
      'computedAt': computedAt,
    };
  }
}

/// مخزن دادهٔ تاریخچهٔ شاخص حال و تعادل (`wellbeing_daily`)
class WellbeingDailyRepository {
  WellbeingDailyRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _dbHelper;

  /// ذخیره یا به‌روزرسانی شاخص امروز در جدول `wellbeing_daily`
  Future<void> upsertToday(WellbeingIndex index, {DateTime? now}) async {
    if (!index.hasValue) return;

    final targetDate = now ?? DateTime.now();
    final dateStr = RitmoDate.dayKey(targetDate);

    double? sleepScore;
    double? energyScore;
    double? moodScore;
    double? reflectionScore;

    for (final c in index.contributions) {
      switch (c.signal) {
        case WellbeingSignal.sleep:
          sleepScore = c.score;
          break;
        case WellbeingSignal.energy:
          energyScore = c.score;
          break;
        case WellbeingSignal.mood:
          moodScore = c.score;
          break;
        case WellbeingSignal.reflection:
          reflectionScore = c.score;
          break;
      }
    }

    final contributionsMap = [
      for (final c in index.contributions)
        {
          'signal': c.signal.name,
          'score': c.score,
          'weight': c.weight,
          'confidence': c.confidence,
        }
    ];

    final record = WellbeingDailyRecord(
      date: dateStr,
      indexValue: index.value,
      confidence: index.confidence,
      sleepScore: sleepScore,
      energyScore: energyScore,
      moodScore: moodScore,
      reflectionScore: reflectionScore,
      contributionsJson: jsonEncode(contributionsMap),
      computedAt: targetDate.millisecondsSinceEpoch,
    );

    try {
      final db = await _dbHelper.database;
      await db.insert(
        'wellbeing_daily',
        record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e, st) {
      RitmoLog.error('WellbeingDaily', 'خطا در ذخیره سطر روزانه شاخص', e, st);
    }
  }

  /// بارگذاری بازه‌ای از سطور تاریخچهٔ شاخص
  Future<List<WellbeingDailyRecord>> loadRange(DateTime from, DateTime to) async {
    final fromStr = RitmoDate.dayKey(from);
    final toStr = RitmoDate.dayKey(to);

    try {
      final db = await _dbHelper.database;
      final rows = await db.query(
        'wellbeing_daily',
        where: 'date >= ? AND date <= ?',
        whereArgs: [fromStr, toStr],
        orderBy: 'date ASC',
      );

      return rows.map((r) => WellbeingDailyRecord.fromMap(r)).toList();
    } catch (e, st) {
      RitmoLog.error('WellbeingDaily', 'خطا در خواندن بازه تاریخچه شاخص', e, st);
      return [];
    }
  }

  /// بارگذاری سطور تاریخچهٔ اخیر بر حسب تعداد روز
  Future<List<WellbeingDailyRecord>> loadRecent(int days, {DateTime? now}) async {
    final end = now ?? DateTime.now();
    final start = end.subtract(Duration(days: days - 1));
    return loadRange(start, end);
  }
}
