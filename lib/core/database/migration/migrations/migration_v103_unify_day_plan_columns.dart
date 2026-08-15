import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:sqflite/sqflite.dart';

/// Migration v103: Unify day_plan_templates & day_plan_commits columns to canonical camelCase (Phase M2-D / P6).
///
/// Backfills canonical columns by reading both camelCase and snake_case / alternate columns,
/// and choosing the non-null/non-empty value without blindly overwriting.
class MigrationV103UnifyDayPlanColumns extends Migration {
  @override
  int get version => 103;

  @override
  String get name => 'migration_v103_unify_day_plan_columns';

  @override
  bool get requiresTransaction => true;

  @override
  Future<void> up(DatabaseExecutor db) async {
    // 1. Backfill day_plan_templates
    try {
      final templates = await db.query('day_plan_templates');
      for (final row in templates) {
        final id = row['id'] as String?;
        if (id == null) continue;

        final nameVal = (row['name'] as String?)?.trim();
        final titleVal = (row['title'] as String?)?.trim();
        final canonicalName = (nameVal != null && nameVal.isNotEmpty)
            ? nameVal
            : (titleVal ?? '');

        final itemsJsonVal = (row['itemsJson'] as String?)?.trim();
        final planJsonVal = (row['plan_json'] as String?)?.trim();
        final canonicalItemsJson = (itemsJsonVal != null && itemsJsonVal.isNotEmpty && itemsJsonVal != '[]')
            ? itemsJsonVal
            : (planJsonVal ?? '[]');

        final createdAtVal = (row['createdAt'] as num?)?.toInt() ?? 0;
        final createdAtSnake = (row['created_at'] as num?)?.toInt() ?? 0;
        final canonicalCreatedAt = createdAtVal > 0 ? createdAtVal : createdAtSnake;

        final updatedAtVal = (row['updatedAt'] as num?)?.toInt() ?? 0;
        final updatedAtSnake = (row['updated_at'] as num?)?.toInt() ?? 0;
        final canonicalUpdatedAt = updatedAtVal > 0 ? updatedAtVal : updatedAtSnake;

        await db.update(
          'day_plan_templates',
          {
            'name': canonicalName,
            'itemsJson': canonicalItemsJson,
            'createdAt': canonicalCreatedAt,
            'updatedAt': canonicalUpdatedAt,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    } catch (_) {}

    // 2. Backfill day_plan_commits
    try {
      final commits = await db.query('day_plan_commits');
      for (final row in commits) {
        final id = row['id'] as String?;
        if (id == null) continue;

        final dateIsoVal = (row['dateIso'] as String?)?.trim();
        final dateIsoSnake = (row['date_iso'] as String?)?.trim();
        final canonicalDateIso = (dateIsoVal != null && dateIsoVal.isNotEmpty)
            ? dateIsoVal
            : (dateIsoSnake ?? '');

        final createdAtVal = (row['createdAt'] as num?)?.toInt() ?? 0;
        final createdAtSnake = (row['created_at'] as num?)?.toInt() ?? 0;
        final canonicalCreatedAt = createdAtVal > 0 ? createdAtVal : createdAtSnake;

        final updatedAtVal = (row['updatedAt'] as num?)?.toInt() ?? 0;
        final updatedAtSnake = (row['updated_at'] as num?)?.toInt() ?? 0;
        final canonicalUpdatedAt = updatedAtVal > 0 ? updatedAtVal : updatedAtSnake;

        await db.update(
          'day_plan_commits',
          {
            'dateIso': canonicalDateIso,
            'createdAt': canonicalCreatedAt,
            'updatedAt': canonicalUpdatedAt,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    } catch (_) {}
  }

  @override
  Future<void> down(DatabaseExecutor db) async {}
}
