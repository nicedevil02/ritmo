import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/models/day_agenda_snapshot.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/konkur_agenda_source.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/calendar/data/calendar_search_repository.dart';
import 'package:ritmo/features/calendar/presentation/widgets/journey_agenda_view.dart';
import 'package:ritmo/features/konkur/models/konkur_models.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Widget createTestApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('fa'),
    theme: RitmoTheme.build(
      palette: RitmoPalette.jadeNoir,
      brightness: Brightness.dark,
    ),
    home: Scaffold(
      body: SizedBox(
        height: 800,
        width: 500,
        child: child,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);

    await db.execute('''
      CREATE TABLE IF NOT EXISTS konkur_subjects (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        field TEXT NOT NULL,
        colorHex TEXT,
        coefficient REAL DEFAULT 1.0,
        isArchived INTEGER DEFAULT 0,
        isPreset INTEGER DEFAULT 0,
        origin TEXT DEFAULT 'KONKUR_PRESET'
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS konkur_topics (
        id TEXT PRIMARY KEY,
        subjectId TEXT NOT NULL,
        name TEXT NOT NULL,
        orderIndex INTEGER DEFAULT 0,
        masteryLevel TEXT DEFAULT 'NOT_STARTED',
        targetStudyMinutes INTEGER DEFAULT 0,
        origin TEXT DEFAULT 'KONKUR_PRESET',
        createdAt INTEGER DEFAULT 0,
        updatedAt INTEGER DEFAULT 0
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS konkur_plan_items (
        id TEXT PRIMARY KEY,
        dateIso TEXT NOT NULL,
        subjectId TEXT,
        topicId TEXT,
        plannedMinutes INTEGER DEFAULT 0,
        status TEXT DEFAULT 'PENDING',
        plannedMode TEXT,
        priorityScore REAL,
        planningReason TEXT,
        isLocked INTEGER DEFAULT 0,
        isUserEdited INTEGER DEFAULT 0,
        carryOverCount INTEGER DEFAULT 0,
        sourceType TEXT DEFAULT 'AUTO',
        createdAt INTEGER DEFAULT 0,
        recommendedEnergy TEXT,
        energyNote TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS simple_tasks (
        id TEXT PRIMARY KEY,
        title TEXT,
        note TEXT,
        dueDate TEXT,
        dueTime TEXT,
        isDone INTEGER DEFAULT 0,
        titleNormalized TEXT,
        noteNormalized TEXT,
        createdAt INTEGER DEFAULT 0
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS routines (
        id TEXT PRIMARY KEY,
        title TEXT,
        category TEXT,
        timeOfDay TEXT,
        isArchived INTEGER DEFAULT 0
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS events (
        id TEXT PRIMARY KEY,
        title TEXT,
        note TEXT,
        dateStr TEXT,
        timeStr TEXT,
        isArchived INTEGER DEFAULT 0
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS courses (
        id TEXT PRIMARY KEY,
        title TEXT,
        preferredTime TEXT,
        isArchived INTEGER DEFAULT 0
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS course_sessions (
        id TEXT PRIMARY KEY,
        courseId TEXT,
        sessionTitle TEXT,
        sessionNumber INTEGER,
        plannedDate TEXT,
        plannedStartTime TEXT,
        estimatedDurationMinutes INTEGER,
        completionStatus TEXT,
        isCompleted INTEGER DEFAULT 0
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS worship_practices (
        id TEXT PRIMARY KEY,
        title TEXT,
        practiceType TEXT,
        isArchived INTEGER DEFAULT 0
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS goals (
        id TEXT PRIMARY KEY,
        title TEXT,
        isArchived INTEGER DEFAULT 0
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS goal_steps (
        id TEXT PRIMARY KEY,
        goalId TEXT,
        title TEXT,
        scheduledDate TEXT,
        isDone INTEGER DEFAULT 0
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS worship_debts (
        id TEXT PRIMARY KEY,
        title TEXT,
        debtType TEXT,
        remainingCount INTEGER DEFAULT 0,
        isArchived INTEGER DEFAULT 0
      );
    ''');

    DatabaseHelper.instance.overrideDatabaseForTesting(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Konkur Agenda Topic Display Tests', () {
    test('KonkurAgendaSource formats topic as title and subject + duration + mode as subtitle', () {
      final item = KonkurPlanItem(
        id: 'plan_1',
        dateIso: '2026-09-01',
        subjectId: 'sub_math',
        topicId: 'top_hesaban',
        plannedMinutes: 30,
        plannedMode: 'STUDY',
        createdAt: 1000,
      );

      final source = KonkurAgendaSource(
        konkurByDate: {
          '2026-09-01': [item],
        },
        konkurSubjectNames: {
          'sub_math': 'ریاضیات (دیفرانسیل، هندسه و گسسته)',
        },
        konkurTopicNames: {
          'top_hesaban': 'حسابان و ریاضی پایه',
        },
        konkurEnabled: true,
      );

      final ctx = AgendaDayContext(
        date: DateTime.parse('2026-09-01'),
        dateStr: '2026-09-01',
        isToday: false,
        prayerTimes: const {},
        options: const AgendaQueryOptions(
          domains: {AgendaDomain.konkur},
        ),
      );

      final items = source.itemsForDate(ctx);
      expect(items.length, equals(1));

      final agendaItem = items.first;
      // Title must be the specific topic
      expect(agendaItem.title, equals('حسابان و ریاضی پایه'));
      // Subtitle must combine subject name, duration, and study mode
      expect(
        agendaItem.subtitle,
        equals('ریاضیات (دیفرانسیل، هندسه و گسسته) · 30 دقیقه · مطالعه'),
      );
      // Meta must store topicId and subjectId for deep linking
      expect(agendaItem.meta['topicId'], equals('top_hesaban'));
      expect(agendaItem.meta['subjectId'], equals('sub_math'));
      expect(agendaItem.meta['plannedMode'], equals('STUDY'));
    });

    test('KonkurAgendaSource handles TEST and REVIEW modes correctly', () {
      final itemTest = KonkurPlanItem(
        id: 'plan_test',
        dateIso: '2026-09-01',
        subjectId: 'sub_phys',
        topicId: 'top_elec',
        plannedMinutes: 45,
        plannedMode: 'TEST',
        createdAt: 1000,
      );
      final itemReview = KonkurPlanItem(
        id: 'plan_rev',
        dateIso: '2026-09-01',
        subjectId: 'sub_chem',
        topicId: 'top_chem1',
        plannedMinutes: 20,
        plannedMode: 'REVIEW',
        createdAt: 1000,
      );

      final source = KonkurAgendaSource(
        konkurByDate: {
          '2026-09-01': [itemTest, itemReview],
        },
        konkurSubjectNames: {
          'sub_phys': 'فیزیک',
          'sub_chem': 'شیمی',
        },
        konkurTopicNames: {
          'top_elec': 'الکتریسیته و مغناطیس',
          'top_chem1': 'شیمی پایه (دهم و یازدهم)',
        },
        konkurEnabled: true,
      );

      final ctx = AgendaDayContext(
        date: DateTime.parse('2026-09-01'),
        dateStr: '2026-09-01',
        isToday: false,
        prayerTimes: const {},
        options: const AgendaQueryOptions(
          domains: {AgendaDomain.konkur},
        ),
      );

      final items = source.itemsForDate(ctx);
      expect(items.length, equals(2));

      expect(items[0].title, equals('الکتریسیته و مغناطیس'));
      expect(items[0].subtitle, equals('فیزیک · 45 دقیقه · تست'));

      expect(items[1].title, equals('شیمی پایه (دهم و یازدهم)'));
      expect(items[1].subtitle, equals('شیمی · 20 دقیقه · مرور'));
    });

    test('KonkurAgendaSource falls back gracefully when topicId is missing', () {
      final itemNoTopic = KonkurPlanItem(
        id: 'plan_no_topic',
        dateIso: '2026-09-01',
        subjectId: 'sub_bio',
        topicId: null,
        plannedMinutes: 60,
        plannedMode: null,
        createdAt: 1000,
      );

      final source = KonkurAgendaSource(
        konkurByDate: {
          '2026-09-01': [itemNoTopic],
        },
        konkurSubjectNames: {
          'sub_bio': 'زیست‌شناسی',
        },
        konkurTopicNames: {},
        konkurEnabled: true,
      );

      final ctx = AgendaDayContext(
        date: DateTime.parse('2026-09-01'),
        dateStr: '2026-09-01',
        isToday: false,
        prayerTimes: const {},
        options: const AgendaQueryOptions(
          domains: {AgendaDomain.konkur},
        ),
      );

      final items = source.itemsForDate(ctx);
      expect(items.length, equals(1));
      expect(items.first.title, equals('زیست‌شناسی'));
      expect(items.first.subtitle, equals('60 دقیقه'));
    });

    testWidgets('JourneyAgendaView renders topic headline and subject subtitle for konkur item', (
      tester,
    ) async {
      const dateIso = '2026-09-01';
      final item = AgendaItem(
        id: 'konkur:plan_1:$dateIso',
        domain: AgendaDomain.konkur,
        sourceId: 'plan_1',
        title: 'حسابان و ریاضی پایه',
        subtitle: 'ریاضیات (دیفرانسیل، هندسه و گسسته) · ۳۰ دقیقه · مطالعه',
        dateStr: dateIso,
        durationMinutes: 30,
        category: Category.konkur,
        completion: AgendaCompletion.pending,
        priority: 1.2,
        deepLink: const AgendaDeepLink(
          domain: AgendaDomain.konkur,
          targetId: 'plan_1',
        ),
      );

      final dayAgenda = DayAgenda(
        dateStr: dateIso,
        items: [item],
      );

      final snapshot = DayAgendaSnapshot(
        dayAgenda: dayAgenda,
        completedCount: 0,
        remainingCount: 1,
        freeGaps: const [],
        conflicts: const [],
        overloadScore: 0.0,
        suggestions: const [],
      );

      await tester.pumpWidget(
        createTestApp(
          JourneyAgendaView(
            rangeSnapshots: {dateIso: snapshot},
            now: DateTime.parse(dateIso),
            onItemTap: (_) {},
            onAddTap: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Topic title must be visible in the view
      expect(find.text('حسابان و ریاضی پایه'), findsAtLeastNWidgets(1));
      // Subtitle with subject, duration, and study mode must be visible
      expect(
        find.textContaining('ریاضیات (دیفرانسیل، هندسه و گسسته)'),
        findsOneWidget,
      );
      expect(find.textContaining('۳۰ دقیقه'), findsOneWidget);
      expect(find.textContaining('مطالعه'), findsOneWidget);
    });

    test('CalendarSearchRepository finds konkur items by topic name', () async {
      await db.insert('konkur_subjects', {
        'id': 'sub_1',
        'name': 'فیزیک',
        'field': 'RIYAZI',
      });
      await db.insert('konkur_topics', {
        'id': 'top_1',
        'subjectId': 'sub_1',
        'name': 'الکتریسیته ساکن',
      });
      await db.insert('konkur_plan_items', {
        'id': 'plan_item_1',
        'dateIso': '2026-09-01',
        'subjectId': 'sub_1',
        'topicId': 'top_1',
        'plannedMinutes': 40,
      });

      final repo = CalendarSearchRepository.instance;
      final hits = await repo.search('الکتریسیته');

      expect(hits.length, equals(1));
      expect(hits.first.title, equals('الکتریسیته ساکن'));
      expect(hits.first.subtitle, contains('فیزیک'));
      expect(hits.first.subtitle, contains('40 دقیقه'));
    });
  });
}
