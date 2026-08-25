import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/application/application.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/mv_kind_repository.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/seed/movement_kinds_seed.dart';
import 'package:ritmo/features/supplementary_sports/presentation/screens/mv_library_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Widget createTestApp(Widget child) {
  return MaterialApp(
    theme: ThemeData.light(),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  late Database db;
  late MvKindRepository kindRepo;
  late MvKindUseCase kindUseCase;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await MovementKindsSeed.seed(db);
    kindRepo = MvKindRepository(db);
    kindUseCase = MvKindUseCase(kindRepo);
  });

  tearDown(() async {
    await db.close();
  });

  group('MvLibraryScreen Kinds Tab & Custom Sport Tests (S1-T8)', () {
    testWidgets(
      'Switch to Kinds tab, create custom sport پدل, verify saved in DB and rendered in list',
      (tester) async {
        List<MvMovementKind> allInitial = [];
        await tester.runAsync(() async {
          allInitial = await kindRepo.getAll();
        });

        await tester.pumpWidget(
          createTestApp(
            MvLibraryScreen(
              allExercises: const [],
              kindUseCase: kindUseCase,
              initialKinds: allInitial,
            ),
          ),
        );
        await tester.pump();

        // 1. Switch to 3rd tab "انواع ورزش"
        expect(find.byKey(const ValueKey('library_tab_kinds')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('library_tab_kinds')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(
          find.byKey(const ValueKey('kinds_tab_search_field')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('library_create_custom_kind_button')),
          findsOneWidget,
        );

        // 2. Open Custom Kind Sheet
        await tester.tap(
          find.byKey(const ValueKey('library_create_custom_kind_button')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(
          find.byKey(const ValueKey('custom_kind_title_field')),
          findsOneWidget,
        );

        // 3. Enter Title "پدل"
        await tester.enterText(
          find.byKey(const ValueKey('custom_kind_title_field')),
          'پدل',
        );
        await tester.pump();

        // 4. Select SPORT family
        await tester.ensureVisible(find.byKey(const ValueKey('family_sport')));
        await tester.tap(find.byKey(const ValueKey('family_sport')));
        await tester.pump();

        // 5. Toggle needsVenue switch
        await tester.ensureVisible(
          find.byKey(const ValueKey('custom_kind_needs_venue')),
        );
        await tester.tap(find.byKey(const ValueKey('custom_kind_needs_venue')));
        await tester.pump();

        // 6. Tap Save Button
        await tester.ensureVisible(
          find.byKey(const ValueKey('custom_kind_save_action')),
        );
        await tester.tap(find.byKey(const ValueKey('custom_kind_save_action')));
        await tester.pump();
        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 300));
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // 7. Verify DB contains پدل
        MvMovementKind? padel;
        await tester.runAsync(() async {
          final all = await kindRepo.getAll();
          padel = all.firstWhere((k) => k.titleFa == 'پدل');
        });
        expect(padel, isNotNull);
        expect(padel!.isCustom, isTrue);
        expect(padel!.family, equals(MovementFamily.sport));
        expect(padel!.needsVenue, isTrue);

        // 8. Verify list in Library screen displays پدل
        expect(find.text('پدل'), findsOneWidget);
      },
    );
  });
}
