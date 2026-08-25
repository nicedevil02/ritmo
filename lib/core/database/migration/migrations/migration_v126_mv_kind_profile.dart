import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:ritmo/core/database/schema/schema_manager.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/seed/mv_kind_profile_seed.dart';
import 'package:sqflite/sqflite.dart';

/// مایگریشن نسخهٔ ۱۲۶: جدول پروفایل انواع ورزش (mv_kind_profile) و seed قطعی
class MigrationV126MvKindProfile extends Migration {
  @override
  int get version => 126;

  @override
  Future<void> down(covariant DatabaseExecutor db) async {
    await db.execute('DROP TABLE IF EXISTS mv_kind_profile');
  }

  @override
  Future<void> up(covariant DatabaseExecutor db) async {
    RitmoLog.info('MigrationV126MvKindProfile', 'Starting mv_kind_profile migration v126...');
    try {
      await MvKindProfileSeed.ensureSchema(db);
      await MvKindProfileSeed.ensureSeed(db);
      await SchemaManager.safeAddColumn(db, 'ss_session_prescription', 'reasonKey', 'TEXT');
      await SchemaManager.safeAddColumn(db, 'ss_session_prescription', 'reasonParams', 'TEXT');
      RitmoLog.info('MigrationV126MvKindProfile', 'Migration v126 completed successfully.');
    } catch (e) {
      RitmoLog.warning('MigrationV126MvKindProfile', 'Error applying migration v126: $e');
      rethrow;
    }
  }
}
