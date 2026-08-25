import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/application/application.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/mv_kind_repository.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/seed/movement_kinds_seed.dart';
import 'package:ritmo/features/supplementary_sports/presentation/sheets/mv_kind_picker_sheet.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late MvKindRepository repo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await MovementKindsSeed.seed(db);
    repo = MvKindRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('MvKindPickerSheet Widget Verification (S1-T5)', () {
    testWidgets('Full render, search filtering for شنا, and selection pop', (tester) async {
      MvMovementKind? pickedKind;
      late List<MvMovementKind> allKinds;
      await tester.runAsync(() async {
        allKinds = await repo.getAll();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  pickedKind = await MvKindPickerSheet.show(
                    context: context,
                    useCase: MvKindUseCase(repo),
                    initialKinds: allKinds,
                  );
                },
                child: const Text('Open Picker'),
              ),
            ),
          ),
        ),
      );

      // Tap button to open sheet
      await tester.tap(find.text('Open Picker'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      // 1. Full render with initial list and title
      expect(find.text('انتخاب نوع ورزش و فعالیت'), findsOneWidget);
      expect(find.text('بدمینتون'), findsWidgets);

      // 2. Type "شنا" in search bar and wait for debounce
      await tester.enterText(find.byType(TextField), 'شنا');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      // Verify that swimming is shown
      expect(find.text('شنا'), findsWidgets);
      expect(find.text('بدمینتون'), findsNothing);

      // 3. Tap on "شنا" list item to select it
      await tester.ensureVisible(find.byKey(const ValueKey('kind_SWIMMING')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('kind_SWIMMING')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      // Verify sheet is closed and pickedKind is SWIMMING
      expect(find.text('انتخاب نوع ورزش و فعالیت'), findsNothing);
      expect(pickedKind, isNotNull);
      expect(pickedKind!.code, equals('SWIMMING'));
      expect(pickedKind!.titleFa, equals('شنا'));
    });
  });
}
