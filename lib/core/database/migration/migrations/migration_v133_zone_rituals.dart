import 'package:ritmo/core/database/migration/migration_interface.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:sqflite/sqflite.dart';

/// Migration V133: Transition Rituals for Realms (F-14).
class MigrationV133ZoneRituals extends Migration {
  MigrationV133ZoneRituals();

  @override
  int get version => 133;

  @override
  Future<void> up(DatabaseExecutor db) async {
    RitmoLog.info('MigrationV133', 'Starting Migration V133 Zone Rituals...');

    // Add ritualOnEnter and ritualOnExit columns to zones table
    await safeAddColumn(db, 'zones', 'ritualOnEnter', 'TEXT');
    await safeAddColumn(db, 'zones', 'ritualOnExit', 'TEXT');

    RitmoLog.info('MigrationV133', 'Migration V133 applied successfully');
  }

  @override
  Future<void> down(DatabaseExecutor db) async {
    RitmoLog.info('MigrationV133', 'Rolling back Migration V133...');
  }
}
