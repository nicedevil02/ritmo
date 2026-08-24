import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/ai_connection_models.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/ux/ritmo_skeleton.dart';
import 'package:ritmo/features/profile/presentation/ai_connection_screen.dart';
import 'package:ritmo/features/profile/presentation/widgets/ai_provider_grid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory tempDir;
  Database? db;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ai_screen_test_');

    SharedPreferences.setMockInitialValues({
      'assistant_cloud_consent': true,
      'ai_connection_mode': 'ritmo_server',
    });

    FlutterSecureStorage.setMockInitialValues({});

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (methodCall) async => tempDir.path,
    );

    databaseFactory = databaseFactoryFfi;
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE app_settings (key TEXT PRIMARY KEY, value TEXT, updatedAt INTEGER);');
      },
    );
    DatabaseHelper.instance.overrideDatabaseForTesting(db!);
  });

  tearDown(() async {
    if (db != null && db!.isOpen) {
      await db!.close();
    }
    try {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  Widget buildHarness() {
    return MaterialApp(
      theme: RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
      ),
      home: const AiConnectionScreen(),
    );
  }

  Future<void> pumpLoaded(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(() async {
      await tester.pumpWidget(buildHarness());
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
  }

  group('AiProviderGrid Tests', () {
    testWidgets('renders all provider presets with titles and badges', (tester) async {
      String? selectedId;

      await tester.pumpWidget(
        MaterialApp(
          theme: RitmoTheme.build(
            palette: RitmoPalette.jadeNoir,
            brightness: Brightness.dark,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: AiProviderGrid(
                presets: kAiProviderPresets,
                selectedPresetId: 'zhipu',
                onSelect: (preset) {
                  selectedId = preset.id;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('OpenCode (پیش‌فرض)'), findsOneWidget);
      expect(find.text('ژیپو (智谱)'), findsOneWidget);
      expect(find.text('OpenRouter'), findsOneWidget);
      expect(find.text('Groq'), findsOneWidget);

      await tester.tap(find.text('OpenRouter'));
      await tester.pump();

      expect(selectedId, equals('openrouter'));
    });
  });

  group('AiConnectionScreen Redesign Tests', () {
    testWidgets('renders initial hero status and dual mode cards', (tester) async {
      await pumpLoaded(tester);

      expect(find.byType(RitmoSkeletonCard), findsNothing);
      expect(find.text('اتصال هوش مصنوعی'), findsOneWidget);
      expect(find.text('سرور ریتمو'), findsWidgets);
      expect(find.text('کلید شخصی'), findsWidgets);
      expect(find.text('اتصال ابری امن ریتمو (۳ لایه خودکار)'), findsOneWidget);
    });

    testWidgets('switches to Personal Key mode and reveals Provider Grid and Credentials', (tester) async {
      await pumpLoaded(tester);

      await tester.runAsync(() async {
        await tester.tap(find.text('کلید شخصی').first);
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      expect(find.text('انتخاب سرویس‌دهنده هوش مصنوعی'), findsOneWidget);
      expect(find.byType(AiProviderGrid), findsOneWidget);
      expect(find.text('کلید دسترسی (API Key)'), findsOneWidget);
    });

    testWidgets('expands advanced settings accordion to reveal endpoint and timeout', (tester) async {
      await pumpLoaded(tester);

      expect(find.text('تنظیمات پیشرفته و سفارشی‌سازی'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.text('تنظیمات پیشرفته و سفارشی‌سازی'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      expect(find.text('آدرس سرویس‌دهنده (Base URL / Endpoint)'), findsOneWidget);
      expect(find.text('مهلت پاسخ سرویس‌دهنده (Timeout)'), findsOneWidget);
      expect(find.text('کلید پشتیبان (Failover Key)'), findsOneWidget);
    });
  });
}
