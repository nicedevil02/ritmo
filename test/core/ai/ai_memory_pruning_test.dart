import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/memory/ai_memory_service.dart';
import 'package:ritmo/core/ai/memory/memory_models.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    DatabaseHelper.instance.overrideDatabaseForTesting(db);

    await db.execute('''
      CREATE TABLE ai_memory (
        id TEXT PRIMARY KEY,
        content TEXT NOT NULL,
        type TEXT NOT NULL,
        domain TEXT NOT NULL,
        source TEXT NOT NULL,
        importance INTEGER NOT NULL,
        pinned INTEGER NOT NULL DEFAULT 0,
        sensitive INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL,
        sessionId TEXT,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        lastAccessedAt INTEGER NOT NULL,
        accessCount INTEGER NOT NULL DEFAULT 0,
        expiresAt INTEGER
      );
    ''');
    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT,
        updatedAt INTEGER
      );
    ''');
  });

  tearDown(() async {
    await db.close();
  });

  group('H-7: AI Memory Pruning & Retention Logic Acceptance Tests', () {
    test('P1: 50 records importance <= 4 with createdAt = 90 days ago are archived after prune', () async {
      final ninetyDaysAgoMs = DateTime.now().millisecondsSinceEpoch - (90 * 24 * 3600 * 1000);
      final batch = db.batch();
      for (var i = 0; i < 50; i++) {
        batch.insert('ai_memory', {
          'id': 'mem_old_$i',
          'content': 'خاطره قدیمی شماره $i',
          'type': MemoryType.preference.name,
          'domain': 'core',
          'source': MemorySource.implicit.name,
          'importance': 3,
          'pinned': 0,
          'sensitive': 0,
          'status': MemoryStatus.active.name,
          'createdAt': ninetyDaysAgoMs,
          'updatedAt': ninetyDaysAgoMs,
          'lastAccessedAt': ninetyDaysAgoMs,
          'accessCount': 0,
        });
      }
      await batch.commit(noResult: true);

      await AiMemoryService.instance.pruneMemories();

      final activeRows = await db.query(
        'ai_memory',
        where: "status = 'active' AND id LIKE 'mem_old_%'",
      );
      expect(activeRows, isEmpty, reason: 'Memories with importance <= 4 older than 60 days must be archived');

      final archivedRows = await db.query(
        'ai_memory',
        where: "status = 'archived' AND id LIKE 'mem_old_%'",
      );
      expect(archivedRows.length, equals(50));
    });

    test('P2: old low-importance record with pinned=1 is unpinned when cap of 10 is exceeded, then archived', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final ninetyDaysAgoMs = now - (90 * 24 * 3600 * 1000);

      // Insert 10 high-importance pinned records
      for (var i = 0; i < 10; i++) {
        await db.insert('ai_memory', {
          'id': 'mem_pinned_high_$i',
          'content': 'فکت هویتی مهم $i',
          'type': MemoryType.identity.name,
          'domain': 'core',
          'source': MemorySource.explicit.name,
          'importance': 10,
          'pinned': 1,
          'sensitive': 0,
          'status': MemoryStatus.active.name,
          'createdAt': now,
          'updatedAt': now,
          'lastAccessedAt': now,
          'accessCount': 0,
        });
      }

      // Insert 1 11th low-importance pinned record that is 90 days old
      await db.insert('ai_memory', {
        'id': 'mem_pinned_excess_old',
        'content': 'فکت پین شده کم اهمیت قدیمی',
        'type': MemoryType.preference.name,
        'domain': 'core',
        'source': MemorySource.explicit.name,
        'importance': 2,
        'pinned': 1,
        'sensitive': 0,
        'status': MemoryStatus.active.name,
        'createdAt': ninetyDaysAgoMs,
        'updatedAt': ninetyDaysAgoMs,
        'lastAccessedAt': ninetyDaysAgoMs,
        'accessCount': 0,
      });

      // First prune: unpins excess pinned memories (mem_pinned_excess_old becomes pinned=0)
      // and subsequent prune or age check archives it
      await AiMemoryService.instance.pruneMemories();
      await AiMemoryService.instance.pruneMemories();

      final row = await db.query('ai_memory', where: "id = 'mem_pinned_excess_old'");
      expect(row.first['pinned'], equals(0), reason: 'Excess pinned memory must be unpinned');
      expect(row.first['status'], equals(MemoryStatus.archived.name), reason: 'Unpinned old low-importance memory must be archived');
    });

    test('P3: 40 active unpinned records in core domain are capped at max 30 after prune', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final batch = db.batch();
      for (var i = 0; i < 40; i++) {
        batch.insert('ai_memory', {
          'id': 'mem_core_$i',
          'content': 'فکت فعال $i',
          'type': MemoryType.preference.name,
          'domain': 'core',
          'source': MemorySource.implicit.name,
          'importance': 6,
          'pinned': 0,
          'sensitive': 0,
          'status': MemoryStatus.active.name,
          'createdAt': now + i,
          'updatedAt': now + i,
          'lastAccessedAt': now + i,
          'accessCount': 0,
        });
      }
      await batch.commit(noResult: true);

      await AiMemoryService.instance.pruneMemories();

      final activeRows = await db.query(
        'ai_memory',
        where: "status = 'active' AND domain = 'core' AND pinned = 0",
      );
      expect(activeRows.length, equals(30), reason: 'Core domain active unpinned memory count must not exceed 30');
    });

    test('P4: record with importance=10 and createdAt=today is preserved active', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('ai_memory', {
        'id': 'mem_identity_today',
        'content': 'نام کاربر بهمن است',
        'type': MemoryType.identity.name,
        'domain': 'core',
        'source': MemorySource.explicit.name,
        'importance': 10,
        'pinned': 1,
        'sensitive': 0,
        'status': MemoryStatus.active.name,
        'createdAt': now,
        'updatedAt': now,
        'lastAccessedAt': now,
        'accessCount': 0,
      });

      await AiMemoryService.instance.pruneMemories();

      final row = await db.query('ai_memory', where: "id = 'mem_identity_today'");
      expect(row, isNotEmpty);
      expect(row.first['status'], equals(MemoryStatus.active.name));
      expect(row.first['pinned'], equals(1));
    });

    test('P5: applyOperations with op.pin=false and importance=10 produces pinned == 0 in database', () async {
      final op = MemoryOp(
        op: 'ADD',
        content: 'کاربر هدف بلندمدت دارد',
        type: MemoryType.goal,
        domain: 'core',
        importance: 10,
        sensitive: false,
        pin: false,
      );

      await AiMemoryService.instance.applyOperations([op]);

      final rows = await db.query('ai_memory', where: "content = 'کاربر هدف بلندمدت دارد'");
      expect(rows, isNotEmpty);
      expect(rows.first['pinned'], equals(0), reason: 'When op.pin is false, pinned must be 0 regardless of importance');
      expect(rows.first['importance'], equals(10));
    });
  });
}
