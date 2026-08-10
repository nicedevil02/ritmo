import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/migration/migration_runner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('DB-02: migration registry is sane, unique, sorted, and complete', () {
    final versions = MigrationRunner.debugMigrations.map((m) => m.version).toList();
    expect(versions.toSet().length, versions.length, reason: 'نسخهٔ تکراری در مهاجرت‌ها وجود دارد');

    final sorted = [...versions]..sort();
    expect(versions, sorted, reason: 'ترتیب اعلان مهاجرت‌ها مرتب نیست');

    expect(sorted.first, 2, reason: 'شروع مهاجرت‌ها باید نسخه ۲ باشد');
    expect(sorted.last, DatabaseHelper.dbVersionForTest, reason: 'آخرین نسخه مهاجرت با dbVersion مطابقت ندارد');

    for (var v = 2; v <= sorted.last; v++) {
      expect(sorted.contains(v), isTrue, reason: 'مهاجرت نسخهٔ $v گم شده است');
    }
  });
}
