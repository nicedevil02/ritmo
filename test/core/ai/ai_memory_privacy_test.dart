import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/ai_context_builder.dart';
import 'package:ritmo/core/ai/memory/ai_memory_service.dart';
import 'package:ritmo/core/ai/memory/memory_models.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/commands/ritmo_command.dart';
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

  group('C-3: AI Memory Privacy & Sensitivity Filtering Acceptance Tests', () {
    test('T1: sensitive cycle memory in domain "core" is NOT returned when allowHealth=true and allowCycle=false', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('ai_memory', {
        'id': 'mem_cycle_1',
        'content': 'پریود من ۵ روز طول می‌کشد',
        'type': MemoryType.preference.name,
        'domain': 'core',
        'source': MemorySource.explicit.name,
        'importance': 8,
        'pinned': 0,
        'sensitive': 1,
        'status': MemoryStatus.active.name,
        'createdAt': now,
        'updatedAt': now,
        'lastAccessedAt': now,
        'accessCount': 0,
      });

      const consent = ConsentProfile(
        readableDomains: {
          DataDomain.routines,
          DataDomain.medical,
        },
      );

      expect(consent.allowHealth, isTrue);
      expect(consent.allowCycle, isFalse);

      final result = await AiMemoryService.instance.retrieve(
        domain: 'core',
        query: 'وضعیت',
        consent: consent,
      );

      expect(result, isEmpty, reason: 'Sensitive cycle memory in domain "core" must NOT leak when allowCycle is false');
    });

    test('T2: sensitive cycle memory in domain "core" IS returned when allowCycle=true', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('ai_memory', {
        'id': 'mem_cycle_2',
        'content': 'پریود من ۵ روز طول می‌کشد',
        'type': MemoryType.preference.name,
        'domain': 'core',
        'source': MemorySource.explicit.name,
        'importance': 8,
        'pinned': 0,
        'sensitive': 1,
        'status': MemoryStatus.active.name,
        'createdAt': now,
        'updatedAt': now,
        'lastAccessedAt': now,
        'accessCount': 0,
      });

      const consent = ConsentProfile(
        readableDomains: {
          DataDomain.routines,
          DataDomain.cycle,
        },
      );

      final result = await AiMemoryService.instance.retrieve(
        domain: 'core',
        query: 'وضعیت',
        consent: consent,
      );

      expect(result, isNotEmpty);
      expect(result.first.id, equals('mem_cycle_2'));
    });

    test('T3: sensitive medication/health memory in domain "core" is NOT returned with denySensitive()', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('ai_memory', {
        'id': 'mem_health_1',
        'content': 'من روزی یک عدد قرص متفورمین برای دیابت مصرف می‌کنم',
        'type': MemoryType.preference.name,
        'domain': 'core',
        'source': MemorySource.explicit.name,
        'importance': 8,
        'pinned': 0,
        'sensitive': 1,
        'status': MemoryStatus.active.name,
        'createdAt': now,
        'updatedAt': now,
        'lastAccessedAt': now,
        'accessCount': 0,
      });

      const consent = ConsentProfile.denySensitive();

      final result = await AiMemoryService.instance.retrieve(
        domain: 'core',
        query: 'دارو',
        consent: consent,
      );

      expect(result, isEmpty, reason: 'Health memory must not leak under denySensitive()');
    });

    test('T4: sensitive memory with unclassifiable content requires BOTH health and cycle consent (fail-closed)', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('ai_memory', {
        'id': 'mem_unknown_sensitive',
        'content': 'راز شخصی محرمانه کاربر',
        'type': MemoryType.preference.name,
        'domain': 'core',
        'source': MemorySource.explicit.name,
        'importance': 8,
        'pinned': 0,
        'sensitive': 1,
        'status': MemoryStatus.active.name,
        'createdAt': now,
        'updatedAt': now,
        'lastAccessedAt': now,
        'accessCount': 0,
      });

      // Partial consent: health only
      const consentHealthOnly = ConsentProfile(
        readableDomains: {
          DataDomain.medical,
        },
      );
      final result1 = await AiMemoryService.instance.retrieve(
        domain: 'core',
        query: 'راز',
        consent: consentHealthOnly,
      );
      expect(result1, isEmpty, reason: 'Unclassified sensitive memory must fail-closed if only allowHealth is true');

      // Both consents present
      const consentBoth = ConsentProfile(
        readableDomains: {
          DataDomain.medical,
          DataDomain.cycle,
        },
      );
      final result2 = await AiMemoryService.instance.retrieve(
        domain: 'core',
        query: 'راز',
        consent: consentBoth,
      );
      expect(result2, isNotEmpty, reason: 'Unclassified sensitive memory is accessible only when both consents are granted');
    });

    test('T5: non-sensitive memory IS returned even with denySensitive()', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('ai_memory', {
        'id': 'mem_public_1',
        'content': 'هدف من یادگیری فلاتر در ۶ ماه است',
        'type': MemoryType.goal.name,
        'domain': 'core',
        'source': MemorySource.explicit.name,
        'importance': 8,
        'pinned': 0,
        'sensitive': 0,
        'status': MemoryStatus.active.name,
        'createdAt': now,
        'updatedAt': now,
        'lastAccessedAt': now,
        'accessCount': 0,
      });

      const consent = ConsentProfile.denySensitive();

      final result = await AiMemoryService.instance.retrieve(
        domain: 'core',
        query: 'فلاتر',
        consent: consent,
      );

      expect(result, isNotEmpty);
      expect(result.first.id, equals('mem_public_1'));
    });
  });
}
