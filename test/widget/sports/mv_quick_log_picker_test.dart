import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/application/application.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/mv_kind_repository.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/seed/movement_kinds_seed.dart';
import 'package:ritmo/features/supplementary_sports/presentation/sheets/mv_quick_log_sheet.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ritmo/l10n/app_localizations.dart';

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

  group('MvQuickLogSheet & MvKindPickerSheet Integration Tests (S1-T6)', () {
    testWidgets(
      'Quick log renders 4 chips + بیشتر, opens picker, updates selection, and saves',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        String? savedKindCode;
        int? savedDuration;

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('fa'),
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    MvQuickLogSheet.show(
                      context: context,
                      kindUseCase: kindUseCase,
                      onSave: (kindCode, duration, feeling, note) async {
                        savedKindCode = kindCode;
                        savedDuration = duration;
                      },
                    );
                  },
                  child: const Text('Open Quick Log'),
                ),
              ),
            ),
          ),
        );

        // 1. Open quick log sheet
        await tester.tap(find.text('Open Quick Log'));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();

        expect(find.text('ثبت سریع فعالیت'), findsOneWidget);

        // Verify the 4 default chips and the 5th "بیشتر..." chip
        expect(find.byKey(const ValueKey('kind_chip_WALKING')), findsOneWidget);
        expect(find.byKey(const ValueKey('kind_chip_RUNNING')), findsOneWidget);
        expect(find.byKey(const ValueKey('kind_chip_CYCLING')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('kind_chip_SWIMMING')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('quick_log_more_kinds')),
          findsOneWidget,
        );

        // 2. Click "بیشتر..." -> opens MvKindPickerSheet
        await tester.ensureVisible(
          find.byKey(const ValueKey('quick_log_more_kinds')),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.byKey(const ValueKey('quick_log_more_kinds')));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 200)),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('انتخاب نوع ورزش و فعالیت'), findsOneWidget);

        // 3. Search and select FOOTBALL in MvKindPickerSheet
        await tester.enterText(find.byType(TextField).last, 'فوتبال');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 200)),
        );
        await tester.pump(const Duration(milliseconds: 100));

        await tester.ensureVisible(find.byKey(const ValueKey('kind_FOOTBALL')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('kind_FOOTBALL')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 200));

        // Picker sheet is closed, back on Quick Log sheet
        expect(find.text('انتخاب نوع ورزش و فعالیت'), findsNothing);
        expect(find.text('ثبت سریع فعالیت'), findsOneWidget);

        // 4. Select 45 minutes duration
        await tester.ensureVisible(find.byKey(const ValueKey('duration_45')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('duration_45')));
        await tester.pump();

        // 5. Tap save button
        await tester.ensureVisible(
          find.byKey(const ValueKey('quick_log_save_action')),
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('quick_log_save_action')));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();

        // Verify callback received FOOTBALL and 45
        expect(savedKindCode, equals('FOOTBALL'));
        expect(savedDuration, equals(45));
      },
    );
  });
}
