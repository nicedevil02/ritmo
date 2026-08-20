import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/theme/palettes/jade_noir.dart';
import 'package:ritmo/features/cycle/presentation/widgets/pregnancy/pregnancy_end_sheet.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../test_helpers/cycle_test_db.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    theme: ThemeData.light().copyWith(extensions: [kJadeNoirLight]),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('fa'),
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;

  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    db = await openCycleTestDb();
    DatabaseHelper.instance.overrideDatabaseForTesting(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Pregnancy Exit Dialog Copy Tests (PRG-43)', () {
    testWidgets(
      'PregnancyEndSheet renders all 3 paths with clear data fate copy',
      (tester) async {
        bool birthTapped = false;
        bool lossTapped = false;
        bool mistakeTapped = false;

        await tester.pumpWidget(
          _buildTestApp(
            PregnancyEndSheet(
              onBirth: () => birthTapped = true,
              onLoss: () => lossTapped = true,
              onMistake: () => mistakeTapped = true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify Path 1: Birth
        expect(find.text('تولد نوزاد 🎉'), findsOneWidget);
        expect(
          find.text(
            'داده‌های بارداری نگه داشته می‌شوند و حالت بارداری بسته می‌شود.',
          ),
          findsOneWidget,
        );

        // Verify Path 2: Loss
        expect(find.text('پایان زودهنگام یا از دست رفتن 🤍'), findsOneWidget);
        expect(
          find.text(
            'حالت بارداری بسته می‌شود. می‌توانی انتخاب کنی داده‌ها بمانند یا پاک شوند.',
          ),
          findsOneWidget,
        );

        // Verify Path 3: Mistake / Simple Exit
        expect(find.text('ثبت اشتباهی یا خروج ساده 🔄'), findsOneWidget);
        expect(
          find.text('همهٔ داده‌های بارداری پاک می‌شوند و چرخه برمی‌گردد.'),
          findsOneWidget,
        );

        // Tap Path 1
        await tester.tap(find.text('تولد نوزاد 🎉'));
        expect(birthTapped, isTrue);

        // Tap Path 2
        await tester.tap(find.text('پایان زودهنگام یا از دست رفتن 🤍'));
        expect(lossTapped, isTrue);

        // Tap Path 3
        await tester.tap(find.text('ثبت اشتباهی یا خروج ساده 🔄'));
        expect(mistakeTapped, isTrue);
      },
    );

    testWidgets('PregnancyEndSheet.show opens bottom sheet with all 3 paths', (
      tester,
    ) async {
      bool birthCalled = false;

      await tester.pumpWidget(
        _buildTestApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => PregnancyEndSheet.show(
                context,
                onBirth: () => birthCalled = true,
                onLoss: () {},
                onMistake: () {},
              ),
              child: const Text('باز کردن شیت پایان'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('باز کردن شیت پایان'));
      await tester.pumpAndSettle();

      expect(find.text('تولد نوزاد 🎉'), findsOneWidget);
      expect(find.text('پایان زودهنگام یا از دست رفتن 🤍'), findsOneWidget);
      expect(find.text('ثبت اشتباهی یا خروج ساده 🔄'), findsOneWidget);

      await tester.tap(find.text('تولد نوزاد 🎉'));
      await tester.pumpAndSettle();

      expect(birthCalled, isTrue);
    });
  });
}
