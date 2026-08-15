import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/agenda_source_registry.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeItemSource implements AgendaSource {
  const _FakeItemSource(this._items);
  final List<AgendaItem> _items;

  @override
  Set<AgendaDomain> get domains => {AgendaDomain.event};

  @override
  bool get isEnabled => true;

  @override
  List<AgendaItem> itemsForDate(AgendaDayContext ctx) => _items;
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    if (!Platform.isWindows) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  });

  group('AgendaSourceRegistry (W0-3)', () {
    setUp(() {
      AgendaSourceRegistry.instance.reset();
    });

    tearDown(() {
      AgendaSourceRegistry.instance.reset();
    });

    test('default registry contains 12 built-in source entries in order', () {
      final entries = AgendaSourceRegistry.instance.entries;
      expect(entries.length, equals(12));
      expect(entries.map((e) => e.id).toList(), equals([
        'routine',
        'worship',
        'sports',
        'medicine',
        'goalSteps',
        'task',
        'course',
        'konkur',
        'cycle',
        'event',
        'commitment',
        'appointment',
      ]));
    });

    test('can register a custom source that provides items', () async {
      final fakeItem = AgendaItem(
        id: 'fake:1:2026-08-14',
        domain: AgendaDomain.event,
        sourceId: '1',
        title: 'Fake Item',
        dateStr: '2026-08-14',
        category: Category.custom,
        completion: AgendaCompletion.none,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.event, targetId: '1'),
      );

      AgendaSourceRegistry.instance.setEntries([
        AgendaSourceEntry(
          id: 'fake_source',
          domains: {AgendaDomain.event},
          loader: (ctx) async => _FakeItemSource([fakeItem]),
        ),
      ]);

      final failures = <String>[];
      final dummyDb = _MockDatabase();
      final loadCtx = AgendaSourceLoadContext(
        db: dummyDb,
        settingsMap: const {},
        start: DateTime(2026, 8, 14),
        end: DateTime(2026, 8, 14),
        startStr: '2026-08-14',
        endStr: '2026-08-14',
        todayStr: '2026-08-14',
        options: const AgendaQueryOptions(),
        failures: failures,
      );

      final sources = await AgendaSourceRegistry.instance.loadSources(loadCtx);
      expect(sources.containsKey('fake_source'), isTrue);
      expect(failures, isEmpty);

      final fakeSource = sources['fake_source']!;
      final items = fakeSource.itemsForDate(AgendaDayContext(
        date: DateTime(2026, 8, 14),
        dateStr: '2026-08-14',
        isToday: true,
        prayerTimes: const {},
        options: const AgendaQueryOptions(),
      ));

      expect(items, hasLength(1));
      expect(items.first.title, equals('Fake Item'));
    });

    test('custom source throwing an exception is isolated and recorded in failures', () async {
      AgendaSourceRegistry.instance.setEntries([
        AgendaSourceEntry(
          id: 'failing_source',
          domains: {AgendaDomain.event},
          loader: (ctx) async {
            throw Exception('Simulated crash in custom source loader');
          },
        ),
      ]);

      final failures = <String>[];
      final dummyDb = _MockDatabase();
      final loadCtx = AgendaSourceLoadContext(
        db: dummyDb,
        settingsMap: const {},
        start: DateTime(2026, 8, 14),
        end: DateTime(2026, 8, 14),
        startStr: '2026-08-14',
        endStr: '2026-08-14',
        todayStr: '2026-08-14',
        options: const AgendaQueryOptions(),
        failures: failures,
      );

      final sources = await AgendaSourceRegistry.instance.loadSources(loadCtx);
      expect(sources.containsKey('failing_source'), isFalse);
      expect(failures, contains('failing_source'));
    });
  });
}

class _MockDatabase implements Database {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
