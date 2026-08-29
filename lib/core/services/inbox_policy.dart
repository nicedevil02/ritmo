import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/models/inbox_item.dart';
import 'package:sqflite/sqflite.dart';

class InboxPolicy {
  static bool shouldPush({
    required InboxCategory category,
    required InboxPriority priority,
    required String sourceSystem,
  }) {
    switch (category) {
      case InboxCategory.REMINDER:
        // Background prayer / worship alarms should never pollute the central inbox
        if (sourceSystem == 'worship') return false;
        return priority.index >= 0;
      case InboxCategory.INSIGHT:
        return true;
      case InboxCategory.SUGGESTION:
        return true;
      case InboxCategory.ALERT:
      case InboxCategory.MILESTONE:
      case InboxCategory.CHECKIN:
      case InboxCategory.REVIEW:
        return true;
    }
  }

  static Future<bool> withinRateLimit(
    InboxCategory category, {
    DatabaseExecutor? executor,
  }) async {
    try {
      final db = executor ?? await DatabaseHelper.instance.database;
      final startOfDay = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      ).millisecondsSinceEpoch;

      final countRes = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM inbox_items WHERE category = ? AND createdAt >= ?',
        [category.name, startOfDay],
      );

      final count = countRes.isNotEmpty
          ? (countRes.first['cnt'] as int? ?? 0)
          : 0;

      switch (category) {
        case InboxCategory.INSIGHT:
          return count < 5;
        case InboxCategory.SUGGESTION:
          return count < 5;
        case InboxCategory.REMINDER:
          return count < 10;
        default:
          return true; // No rate limit for critical items
      }
    } catch (_) {
      return true;
    }
  }

  static String buildDedupeKey({
    required String sourceSystem,
    required String entityId,
    required String eventType,
    String? dateBucket,
  }) {
    final bucket =
        dateBucket ?? DateTime.now().toIso8601String().substring(0, 10);
    return '$sourceSystem|$entityId|$eventType|$bucket';
  }

  static int defaultTtlDays(InboxCategory category) {
    switch (category) {
      case InboxCategory.REMINDER:
        return 2;
      case InboxCategory.INSIGHT:
        return 7;
      case InboxCategory.SUGGESTION:
        return 3;
      case InboxCategory.ALERT:
        return 1;
      case InboxCategory.MILESTONE:
        return 30;
      case InboxCategory.CHECKIN:
        return 1;
      case InboxCategory.REVIEW:
        return 2;
    }
  }
}
