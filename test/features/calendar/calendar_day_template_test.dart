import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_action_handler.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/agenda_load_status.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/domain/agenda/occurrence_override_repository.dart';
import 'package:ritmo/core/domain/commands/command_stack.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/features/calendar/data/day_template_repository.dart';
import 'package:ritmo/features/calendar/presentation/journey_controller.dart';

class StubTemplateAgendaService implements DayAgendaService {
  StubTemplateAgendaService(this.items);
  List<AgendaItem> items;

  @override
  AgendaLoadStatus get lastLoadStatus => const AgendaLoadStatus.ok();

  @override
  Future<Map<String, DayAgenda>> agendaForRange(DateTime start, DateTime end, {AgendaQueryOptions? options}) async {
    return {
      '2026-08-18': DayAgenda(dateStr: '2026-08-18', items: items),
    };
  }

  @override
  void invalidateDate(String dateStr) {}
  @override
  void invalidateAll() {}

  @override
  Future<int> countOverdueBefore(DateTime cutoff) async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class StubActionHandler extends AgendaActionHandler {
  StubActionHandler() : super.test();

  final Map<String, ({String? time, int? duration})> itemUpdates = {};

  @override
  Future<void> updateAgendaItemTimeAndDuration({
    required AgendaItem item,
    String? newTimeOfDay,
    int? newDurationMinutes,
  }) async {
    itemUpdates[item.id] = (time: newTimeOfDay, duration: newDurationMinutes);
  }
}

class InMemoryOverrideRepo implements OccurrenceOverrideRepository {
  final Map<String, OccurrenceOverride> _map = {};

  @override
  Future<OccurrenceOverride?> readOne(String sourceType, String sourceId, String dateStr) async {
    return _map['${sourceType.toLowerCase()}:$sourceId:$dateStr'];
  }

  @override
  Future<void> upsert(OccurrenceOverride override) async {
    _map['${override.sourceType.toLowerCase()}:${override.sourceId}:${override.dateStr}'] = override;
  }

  @override
  Future<void> remove(String sourceType, String sourceId, String dateStr) async {
    _map.remove('${sourceType.toLowerCase()}:$sourceId:$dateStr');
  }

  @override
  Future<List<OccurrenceOverride>> readAllFuture(String sourceType, String sourceId, String fromDateStr, {String? untilDateStr}) async => [];

  @override
  Future<void> removeAllFuture(String sourceType, String sourceId, String fromDateStr, {String? untilDateStr}) async {}

  @override
  Future<void> restoreAll(List<OccurrenceOverride> overrides) async {
    for (final o in overrides) {
      _map['${o.sourceType.toLowerCase()}:${o.sourceId}:${o.dateStr}'] = o;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class InMemoryDayTemplateRepository extends DayTemplateRepository {
  final Map<String, DayTemplate> _templates = {};

  @override
  Future<void> saveTemplate(DayTemplate template) async {
    _templates[template.id] = template;
  }

  @override
  Future<List<DayTemplate>> getAllTemplates() async {
    return _templates.values.toList();
  }

  @override
  Future<void> deleteTemplate(String id) async {
    _templates.remove(id);
  }
}

AgendaItem _createItem({
  required String id,
  required String sourceId,
  required String title,
  required String timeOfDay,
  required int durationMinutes,
}) {
  return AgendaItem(
    id: id,
    sourceId: sourceId,
    title: title,
    domain: AgendaDomain.routine,
    kind: AgendaItemKind.routine,
    category: Category.fitness,
    deepLink: AgendaDeepLink(domain: AgendaDomain.routine, targetId: sourceId),
    timeOfDay: timeOfDay,
    durationMinutes: durationMinutes,
    dateStr: '2026-08-18',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CAL-46: Day Template Save, Apply, and Undo', () {
    setUp(() {
      CommandStack.instance.clear();
    });

    test('saveCurrentDayAsTemplate extracts timed items and saves to repository', () async {
      final items = [
        _createItem(id: 'r1', sourceId: '1', title: 'ورزش صبحگاهی', timeOfDay: '07:00', durationMinutes: 45),
        _createItem(id: 'r2', sourceId: '2', title: 'مطالعه', timeOfDay: '10:00', durationMinutes: 90),
      ];

      final service = StubTemplateAgendaService(items);
      final overrideRepo = InMemoryOverrideRepo();
      final actionHandler = StubActionHandler();
      final templateRepo = InMemoryDayTemplateRepository();

      final controller = JourneyController(
        agendaService: service,
        actionHandler: actionHandler,
        overrideRepo: overrideRepo,
      );

      controller.selectDate(DateTime(2026, 8, 18), scaleToSet: JourneyScale.day);
      await controller.loadForActiveScale();

      final saved = await controller.saveCurrentDayAsTemplate('قالب کاری', templateRepo: templateRepo);
      expect(saved, isNotNull);
      expect(saved!.name, equals('قالب کاری'));
      expect(saved.slots.length, equals(2));
      expect(saved.slots[0].title, equals('ورزش صبحگاهی'));
      expect(saved.slots[0].timeOfDay, equals('07:00'));

      final allSaved = await templateRepo.getAllTemplates();
      expect(allSaved.length, equals(1));
    });

    test('applyTemplate applies times and can be completely undone', () async {
      final template = DayTemplate(
        id: 't1',
        name: 'قالب فشرده',
        slots: const [
          DayTemplateSlot(title: 'ورزش صبحگاهی', sourceId: '1', timeOfDay: '06:30', durationMinutes: 30),
          DayTemplateSlot(title: 'مطالعه', sourceId: '2', timeOfDay: '11:00', durationMinutes: 60),
        ],
        createdAt: DateTime.now(),
      );

      final items = [
        _createItem(id: 'r1', sourceId: '1', title: 'ورزش صبحگاهی', timeOfDay: '08:00', durationMinutes: 45),
        _createItem(id: 'r2', sourceId: '2', title: 'مطالعه', timeOfDay: '09:30', durationMinutes: 90),
      ];

      final service = StubTemplateAgendaService(items);
      final overrideRepo = InMemoryOverrideRepo();
      final actionHandler = StubActionHandler();

      final controller = JourneyController(
        agendaService: service,
        actionHandler: actionHandler,
        overrideRepo: overrideRepo,
      );

      controller.selectDate(DateTime(2026, 8, 18), scaleToSet: JourneyScale.day);
      await controller.loadForActiveScale();

      final applied = await controller.applyTemplate(template);
      expect(applied, isTrue);

      // Check overrides created in overrideRepo
      final o1 = await overrideRepo.readOne('routine', '1', '2026-08-18');
      expect(o1, isNotNull);
      expect(o1!.timeOfDay, equals('06:30'));
      expect(o1.durationMinutes, equals(30));

      final o2 = await overrideRepo.readOne('routine', '2', '2026-08-18');
      expect(o2, isNotNull);
      expect(o2!.timeOfDay, equals('11:00'));
      expect(o2.durationMinutes, equals(60));

      // Undo the template apply
      final undone = await controller.undoLastAction();
      expect(undone, isTrue);

      // Verify overrides were removed on undo
      final o1After = await overrideRepo.readOne('routine', '1', '2026-08-18');
      expect(o1After, isNull);
      final o2After = await overrideRepo.readOne('routine', '2', '2026-08-18');
      expect(o2After, isNull);
    });
  });
}
