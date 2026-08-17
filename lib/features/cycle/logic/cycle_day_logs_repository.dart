// C-20: CycleDayLogsRepository & Model
// Manages daily symptom, flow, mood, energy, and notes tracking for Cycle module.
import 'dart:convert';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:sqflite/sqflite.dart';

class CycleDayLog {
  final String id;
  final DateTime logDate;
  final String? flowLevel; // 'NONE', 'LIGHT', 'MEDIUM', 'HEAVY', 'SPOTTING'
  final List<String> symptoms;
  final String? mood; // 'HAPPY', 'CALM', 'ANXIOUS', 'IRRITABLE', 'SAD', 'TIRED'
  final String? energyTag; // 'HIGH', 'NORMAL', 'LOW', 'EXHAUSTED'
  final String? note;
  final int createdAt;
  final int updatedAt;

  const CycleDayLog({
    required this.id,
    required this.logDate,
    this.flowLevel,
    this.symptoms = const [],
    this.mood,
    this.energyTag,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'logDate': CycleDateContract.toDayKey(logDate),
      'flowLevel': flowLevel,
      'symptomsJson': jsonEncode(symptoms),
      'mood': mood,
      'energyTag': energyTag,
      'note': note,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory CycleDayLog.fromMap(Map<String, dynamic> map) {
    List<String> parsedSymptoms = [];
    final rawSymptoms = map['symptomsJson'] ?? map['symptoms'];
    if (rawSymptoms is String && rawSymptoms.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawSymptoms);
        if (decoded is List) {
          parsedSymptoms = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        parsedSymptoms = [];
      }
    } else if (rawSymptoms is List) {
      parsedSymptoms = rawSymptoms.map((e) => e.toString()).toList();
    }

    final dateStr = map['logDate']?.toString() ?? map['date']?.toString();
    final parsedDate = CycleDateContract.parseDayKey(dateStr) ?? DateTime.now();

    return CycleDayLog(
      id: map['id']?.toString() ?? 'cdl_${parsedDate.millisecondsSinceEpoch}',
      logDate: parsedDate,
      flowLevel: map['flowLevel']?.toString(),
      symptoms: parsedSymptoms,
      mood: map['mood']?.toString(),
      energyTag: map['energyTag']?.toString(),
      note: map['note']?.toString(),
      createdAt: map['createdAt'] as int? ?? 0,
      updatedAt: map['updatedAt'] as int? ?? 0,
    );
  }

  CycleDayLog copyWith({
    String? id,
    DateTime? logDate,
    String? flowLevel,
    List<String>? symptoms,
    String? mood,
    String? energyTag,
    String? note,
    int? createdAt,
    int? updatedAt,
  }) {
    return CycleDayLog(
      id: id ?? this.id,
      logDate: logDate ?? this.logDate,
      flowLevel: flowLevel ?? this.flowLevel,
      symptoms: symptoms ?? this.symptoms,
      mood: mood ?? this.mood,
      energyTag: energyTag ?? this.energyTag,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class CycleDayLogsRepository {
  CycleDayLogsRepository._();
  static final CycleDayLogsRepository instance = CycleDayLogsRepository._();

  // Canonical Symptom taxonomy with Persian labels
  static const Map<String, String> symptomTaxonomy = {
    'cramps': 'دل‌پیچه و درد شکمی',
    'headache': 'سردرد',
    'backache': 'کمردرد',
    'breast_tenderness': 'حساسیت سینه‌ها',
    'acne': 'جوش و آکنه',
    'bloating': 'نفخ و ورم',
    'fatigue': 'خستگی و بی‌حالی',
    'nausea': 'تهوع',
    'cravings': 'تمایل شدید به غذا / شیرینی',
    'insomnia': 'بی‌خوابی',
    'mood_swings': 'نوسانات خلقی',
    'joint_pain': 'درد مفاصل و عضلات',
  };

  /// Gets log for a specific calendar date.
  Future<CycleDayLog?> getLogForDate(DateTime date, [DatabaseExecutor? dbExecutor]) async {
    try {
      final db = dbExecutor ?? await DatabaseHelper.instance.database;
      final dayKey = CycleDateContract.toDayKey(date);
      final rows = await db.query(
        'cycle_day_logs',
        where: 'logDate = ?',
        whereArgs: [dayKey],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return CycleDayLog.fromMap(rows.first);
    } catch (e, st) {
      RitmoLogger.error('[CycleDayLogsRepository] getLogForDate error', error: e, stack: st);
      return null;
    }
  }

  /// Gets all logs within [from] and [to] inclusive.
  Future<List<CycleDayLog>> getLogsForRange(DateTime from, DateTime to, [DatabaseExecutor? dbExecutor]) async {
    try {
      final db = dbExecutor ?? await DatabaseHelper.instance.database;
      final fromKey = CycleDateContract.toDayKey(from);
      final toKey = CycleDateContract.toDayKey(to);

      final rows = await db.query(
        'cycle_day_logs',
        where: 'logDate >= ? AND logDate <= ?',
        whereArgs: [fromKey, toKey],
        orderBy: 'logDate ASC',
      );
      return rows.map((r) => CycleDayLog.fromMap(r)).toList();
    } catch (e, st) {
      RitmoLogger.error('[CycleDayLogsRepository] getLogsForRange error', error: e, stack: st);
      return [];
    }
  }

  /// Saves or updates a daily log idempotently.
  Future<void> saveLog(CycleDayLog log, [DatabaseExecutor? dbExecutor]) async {
    try {
      final db = dbExecutor ?? await DatabaseHelper.instance.database;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final map = log.toMap();
      if (map['createdAt'] == 0) {
        map['createdAt'] = nowMs;
      }
      map['updatedAt'] = nowMs;

      await db.insert(
        'cycle_day_logs',
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e, st) {
      RitmoLogger.error('[CycleDayLogsRepository] saveLog error', error: e, stack: st);
    }
  }

  /// Deletes log for a given calendar date.
  Future<void> deleteLogForDate(DateTime date, [DatabaseExecutor? dbExecutor]) async {
    try {
      final db = dbExecutor ?? await DatabaseHelper.instance.database;
      final dayKey = CycleDateContract.toDayKey(date);
      await db.delete(
        'cycle_day_logs',
        where: 'logDate = ?',
        whereArgs: [dayKey],
      );
    } catch (e, st) {
      RitmoLogger.error('[CycleDayLogsRepository] deleteLogForDate error', error: e, stack: st);
    }
  }
}
