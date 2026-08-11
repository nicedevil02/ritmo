import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/features/worship/logic/worship_engine.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('worship_completions');
    await db.delete('worship_practices');
    WorshipEngine.instance.invalidate();
  });

  group('WorshipEngine Integration Day Isolation Tests', () {
    test('6, 7 & 8. Logging today does not leak to future or past unrecorded days', () async {
      final now = DateTime.now();
      final todayStr = now.toIso8601String().substring(0, 10);

      // Load today first to seed default practices
      await WorshipEngine.instance.loadDay(now);

      // Log done for Fajr today
      final logRes = await WorshipEngine.instance.logDone(
        practiceId: 'wp_fajr',
        date: now,
      );
      expect(logRes, isA<WorshipLogOk>());

      // Test 8: loadDay(today) after log -> wp_fajr isDone == true
      final todayDay = await WorshipEngine.instance.loadDay(now);
      final todayFajr = todayDay.practices.firstWhere((p) => p.practice.id == 'wp_fajr');
      expect(todayFajr.isDone, isTrue);

      // Test 6: loadDay(tomorrow) -> all practices isPending == true
      final tomorrow = now.add(const Duration(days: 1));
      final tomorrowDay = await WorshipEngine.instance.loadDay(tomorrow);
      for (final p in tomorrowDay.practices) {
        expect(p.isPending, isTrue, reason: '${p.practice.id} should be pending for tomorrow');
        expect(p.isDone, isFalse, reason: '${p.practice.id} should NOT be done for tomorrow');
      }

      // Test 7: loadDay(3 days ago) -> all practices isPending == true
      final past = now.subtract(const Duration(days: 3));
      final pastDay = await WorshipEngine.instance.loadDay(past);
      for (final p in pastDay.practices) {
        expect(p.isPending, isTrue, reason: '${p.practice.id} should be pending for 3 days ago');
        expect(p.isDone, isFalse, reason: '${p.practice.id} should NOT be done for 3 days ago');
      }
    });

    test('9. logDone for future date returns WorshipLogBlocked with NOT_YET_DUE', () async {
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));

      final logRes = await WorshipEngine.instance.logDone(
        practiceId: 'wp_fajr',
        date: tomorrow,
      );

      expect(logRes, isA<WorshipLogBlocked>());
      final blocked = logRes as WorshipLogBlocked;
      expect(blocked.reasonCode, equals('NOT_YET_DUE'));
      expect(blocked.userMessage, contains('ثبت عبادت برای روزهای آینده امکان‌پذیر نیست'));

      // Verify no record inserted in worship_completions
      final db = await DatabaseHelper.instance.database;
      final dateStr = tomorrow.toIso8601String().substring(0, 10);
      final rows = await db.query(
        'worship_completions',
        where: 'practiceId = ? AND dateStr = ?',
        whereArgs: ['wp_fajr', dateStr],
      );
      expect(rows, isEmpty);
    });
  });
}
