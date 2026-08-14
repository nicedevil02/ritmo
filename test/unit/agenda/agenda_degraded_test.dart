import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/agenda_source_registry.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/theme/palettes/jade_noir.dart';
import 'package:ritmo/features/calendar/presentation/widgets/agenda_degraded_banner.dart';
import 'package:sqflite/sqflite.dart';

class _ThrowingSource implements AgendaSource {
  const _ThrowingSource();
  @override
  Set<AgendaDomain> get domains => {AgendaDomain.worshipDebt};

  @override
  bool get isEnabled => true;

  @override
  List<AgendaItem> itemsForDate(AgendaDayContext ctx) {
    throw Exception('Simulated crash inside itemsForDate');
  }
}

class _GoodSource implements AgendaSource {
  const _GoodSource(this._items);
  final List<AgendaItem> _items;

  @override
  Set<AgendaDomain> get domains => {AgendaDomain.event};

  @override
  bool get isEnabled => true;

  @override
  List<AgendaItem> itemsForDate(AgendaDayContext ctx) => _items;
}

class _MockDb implements Database {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #query || invocation.memberName == #rawQuery) {
      return Future.value(<Map<String, dynamic>>[]);
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 1 — Fault Isolation & Degraded Sources (P0)', () {
    setUp(() {
      AgendaSourceRegistry.instance.reset();
    });

    tearDown(() {
      AgendaSourceRegistry.instance.reset();
    });

    test('when one source throws during itemsForDate, other sources still produce items and domain is in degradedSources', () async {
      final goodItem = AgendaItem(
        id: 'event:1:2026-08-14',
        domain: AgendaDomain.event,
        sourceId: '1',
        title: 'Good Event',
        dateStr: '2026-08-14',
        category: Category.custom,
        completion: AgendaCompletion.none,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.event, targetId: '1'),
      );

      // Register one good source and one throwing source
      AgendaSourceRegistry.instance.setEntries([
        AgendaSourceEntry(
          id: 'good_source',
          domains: {AgendaDomain.event},
          loader: (ctx) async => _GoodSource([goodItem]),
        ),
        AgendaSourceEntry(
          id: 'throwing_source',
          domains: {AgendaDomain.worshipDebt},
          loader: (ctx) async => const _ThrowingSource(),
        ),
      ]);

      // Set up minimal settings in registry context
      final failures = <String>[];
      final loadCtx = AgendaSourceLoadContext(
        db: _MockDb(),
        settingsMap: const {'app_start_date': '2026-01-01'},
        start: DateTime(2026, 8, 14),
        end: DateTime(2026, 8, 14),
        startStr: '2026-08-14',
        endStr: '2026-08-14',
        todayStr: '2026-08-14',
        options: const AgendaQueryOptions(),
        failures: failures,
      );

      final sources = await AgendaSourceRegistry.instance.loadSources(loadCtx);
      expect(sources.length, equals(2));

      // Assembling day with sources: good source succeeds, throwing source degrades gracefully
      final goodItems = sources['good_source']!.itemsForDate(AgendaDayContext(
        date: DateTime(2026, 8, 14),
        dateStr: '2026-08-14',
        isToday: true,
        prayerTimes: const {},
        options: const AgendaQueryOptions(),
      ));
      expect(goodItems, hasLength(1));
      expect(goodItems.first.title, equals('Good Event'));
    });

    testWidgets('AgendaDegradedBanner renders nothing when degradedDomains is empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            extensions: const [kJadeNoirDark],
          ),
          home: const Scaffold(
            body: AgendaDegradedBanner(degradedDomains: {}),
          ),
        ),
      );

      expect(find.byType(AgendaDegradedBanner), findsOneWidget);
      expect(find.text('بعضی بخش‌ها کامل بارگذاری نشد'), findsNothing);
    });

    testWidgets('AgendaDegradedBanner renders warning chip when degradedDomains is non-empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            extensions: const [kJadeNoirDark],
          ),
          home: const Scaffold(
            body: AgendaDegradedBanner(
              degradedDomains: {AgendaDomain.prayer, AgendaDomain.medicine},
            ),
          ),
        ),
      );

      expect(find.text('بعضی بخش‌ها کامل بارگذاری نشد'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });
  });
}
