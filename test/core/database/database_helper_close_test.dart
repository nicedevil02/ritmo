import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:sqflite/sqflite.dart';

class FakeDatabase implements Database {
  bool _open = true;

  @override
  bool get isOpen => _open;

  @override
  Future<void> close() async {
    _open = false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('P0-02: Closing database helper clears database reference and allows subsequent setup', () async {
    final fakeDb = FakeDatabase();
    DatabaseHelper.databaseInstance = fakeDb;

    final db1 = await DatabaseHelper.instance.database;
    expect(db1, same(fakeDb));
    expect(db1.isOpen, isTrue);

    await DatabaseHelper.instance.close();

    expect(fakeDb.isOpen, isFalse);
    expect(DatabaseHelper.rawDatabase, isNull);
  });
}
