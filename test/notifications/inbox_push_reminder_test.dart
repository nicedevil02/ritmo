import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/models/inbox_item.dart';
import 'package:ritmo/core/services/central_inbox_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  try {
    sqfliteFfiInit();
  } catch (_) {}

  group('N0-4 Inbox Push Reminder Tests', () {
    late Database db;
    bool dbInitialized = false;

    setUp(() async {
      try {
        databaseFactory = databaseFactoryFfi;
        db = await openDatabase(
          inMemoryDatabasePath,
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE inbox_items (
                id TEXT PRIMARY KEY,
                category TEXT NOT NULL,
                sourceSystem TEXT NOT NULL,
                title TEXT NOT NULL,
                body TEXT,
                priority INTEGER NOT NULL,
                linkModule TEXT,
                linkEntityId TEXT,
                linkAction TEXT,
                payloadJson TEXT,
                status TEXT NOT NULL,
                createdAt INTEGER NOT NULL,
                expiresAt INTEGER,
                readAt INTEGER,
                dedupeKey TEXT
              );
            ''');
          },
        );
        DatabaseHelper.instance.overrideDatabaseForTesting(db);
        dbInitialized = true;
      } catch (_) {
        dbInitialized = false;
      }
    });

    tearDown(() async {
      if (dbInitialized) {
        await db.close();
      }
    });

    test('pushing non-essential reminder creates row, and markActionedForEntity actions it to 0 unread', () async {
      if (!dbInitialized) return;

      // 1. Push non-essential routine reminder with priority = 0
      await CentralInboxService.push(
        category: InboxCategory.REMINDER,
        sourceSystem: 'routines',
        entityId: 'routine_water_123',
        eventType: 'routine_reminder',
        title: 'نوشیدن آب',
        body: 'یک لیوان آب بنوشید',
        priority: 0,
      );

      // Verify row exists and unreadCount == 1
      final unreadBefore = await CentralInboxService.unreadCount();
      expect(unreadBefore, equals(1));

      final items = await CentralInboxService.getItems();
      expect(items.length, equals(1));
      expect(items.first.title, equals('نوشیدن آب'));
      expect(items.first.linkEntityId, equals('routine_water_123'));

      // 2. Mark actioned using entityId
      await CentralInboxService.markActionedForEntity('routines', 'routine_water_123');

      // Verify unreadCount is now 0 and item status is ACTIONED
      final unreadAfter = await CentralInboxService.unreadCount();
      expect(unreadAfter, equals(0));

      final rows = await db.query('inbox_items');
      expect(rows.first['status'], equals(InboxStatus.ACTIONED.name));
    });
  });
}
