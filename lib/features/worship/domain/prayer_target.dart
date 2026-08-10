import 'package:flutter/foundation.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';

@immutable
class PrayerTarget {
  final List<String> practiceIds;
  final String groupKey;
  final DateTime date;
  final String titleFa;

  const PrayerTarget({
    required this.practiceIds,
    required this.groupKey,
    required this.date,
    required this.titleFa,
  });

  factory PrayerTarget.fromAgendaItem(AgendaItem item) {
    // AgendaItem ids usually look like prayer:wp_dhuhr:dhuhr_asr
    // But sourceId is usually the representative ID.
    // The groupKey needs to be derived.
    String groupKey = 'FAJR';
    List<String> practiceIds = [item.sourceId];

    if (item.id.contains(':dhuhr_asr')) {
      groupKey = 'DHUHR_ASR';
      practiceIds = ['wp_dhuhr', 'wp_asr'];
    } else if (item.id.contains(':maghrib_isha')) {
      groupKey = 'MAGHRIB_ISHA';
      practiceIds = ['wp_maghrib', 'wp_isha'];
    } else if (item.id.contains(':dhuhr')) {
      groupKey = 'DHUHR';
      practiceIds = [item.sourceId];
    } else if (item.id.contains(':asr')) {
      groupKey = 'ASR';
      practiceIds = [item.sourceId];
    } else if (item.id.contains(':maghrib')) {
      groupKey = 'MAGHRIB';
      practiceIds = [item.sourceId];
    } else if (item.id.contains(':isha')) {
      groupKey = 'ISHA';
      practiceIds = [item.sourceId];
    } else {
      // Try to infer from title or sourceId for fajr
      if (item.sourceId.contains('fajr') || item.id.contains('fajr')) groupKey = 'FAJR';
    }

    final date = DateTime.tryParse(item.dateStr) ?? DateTime.now();

    return PrayerTarget(
      practiceIds: practiceIds,
      groupKey: groupKey,
      date: date,
      titleFa: item.title,
    );
  }

  static Future<PrayerTarget> fromGroupKey(String groupKey, DateTime date, {String? titleFa}) async {
    final db = await DatabaseHelper.instance.database;
    List<String> practiceIds = [];
    String title = titleFa ?? 'نماز';

    if (groupKey == 'RAMADAN_FAST') {
      final rows = await db.query(
        'worship_practices',
        columns: ['id'],
        where: "id = 'wp_fasting_ramadan' OR subType = 'RAMADAN' OR practiceType = 'FASTING'",
      );
      if (rows.isNotEmpty) {
        practiceIds = rows.map((r) => r['id']! as String).toList();
      } else {
        practiceIds = ['wp_fasting_ramadan'];
      }
      title = titleFa ?? 'روزه ماه مبارک رمضان';
    } else {
      const subTypesByGroup = {
        'FAJR': ['FAJR'],
        'DHUHR_ASR': ['DHUHR', 'ASR'],
        'MAGHRIB_ISHA': ['MAGHRIB', 'ISHA'],
        'DHUHR': ['DHUHR'],
        'ASR': ['ASR'],
        'MAGHRIB': ['MAGHRIB'],
        'ISHA': ['ISHA'],
      };

      final subTypes = subTypesByGroup[groupKey] ?? const <String>[];
      if (subTypes.isNotEmpty) {
        final rows = await db.query(
          'worship_practices',
          columns: ['id'],
          where: 'subType IN (${List.filled(subTypes.length, '?').join(',')})',
          whereArgs: subTypes,
        );
        if (rows.isNotEmpty) {
          practiceIds = rows.map((r) => r['id']! as String).toList();
        } else {
          if (groupKey == 'FAJR') practiceIds = ['wp_fajr'];
          if (groupKey == 'DHUHR_ASR') practiceIds = ['wp_dhuhr', 'wp_asr'];
          if (groupKey == 'MAGHRIB_ISHA') practiceIds = ['wp_maghrib', 'wp_isha'];
          if (groupKey == 'DHUHR') practiceIds = ['wp_dhuhr'];
          if (groupKey == 'ASR') practiceIds = ['wp_asr'];
          if (groupKey == 'MAGHRIB') practiceIds = ['wp_maghrib'];
          if (groupKey == 'ISHA') practiceIds = ['wp_isha'];
        }
      }
    }

    return PrayerTarget(
      practiceIds: practiceIds,
      groupKey: groupKey,
      date: date,
      titleFa: title,
    );
  }
}
