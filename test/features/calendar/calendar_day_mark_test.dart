import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_action_handler.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/agenda_load_status.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/domain/agenda/occurrence_override_repository.dart';
import 'package:ritmo/core/domain/commands/command_stack.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/features/calendar/data/day_mark_repository.dart';
import 'package:ritmo/features/calendar/presentation/journey_controller.dart';

class StubMarkAgendaService implements DayAgendaService {
  StubMarkAgendaService(this.items, this.dayMarkRepo);
  List<AgendaItem> items;
  final DayMarkRepository dayMarkRepo;

  @override
  AgendaLoadStatus get lastLoadStatus => const AgendaLoadStatus.ok();

  @override
  Future<Map<String, DayAgenda>> agendaForRange(DateTime start, DateTime end, {AgendaQueryOptions? options}) async {
    final mark = await dayMarkRepo.getMark('2026-08-18');
    final isRestOrTravel = mark != null && (mark.kind == DayMarkKind.rest || mark.kind == DayMarkKind.travel);

    final finalItems = items.map((item) {
      if (isRestOrTravel && !item.isEssential && item.completion == AgendaCompletion.none) {
        return item.copyWith(completion: AgendaCompletion.skipped);
      }
      return item;
    }).toList();

    return {
      '2026-08-18': DayAgenda(dateStr: '2026-08-18', items: finalItems),
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

class InMemoryDayMarkRepository extends DayMarkRepository {
  InMemoryDayMarkRepository() : super();
  final Map<String, DayMark> _marks = {};

  @override
  Future<DayMark?> getMark(String dateStr) async {
    return _marks[dateStr];
  }

  @override
  Future<bool> setMark(String dateStr, DayMarkKind kind, {String? note}) async {
    if (kind == DayMarkKind.normal) {
      _marks.remove(dateStr);
    } else {
      _marks[dateStr] = DayMark(dateStr: dateStr, kind: kind, note: note);
    }
    return true;
  }
}

class StubActionHandler extends AgendaActionHandler {
  StubActionHandler() : super.test();
}

class InMemoryOverrideRepo implements OccurrenceOverrideRepository {
  @override
  Future<OccurrenceOverride?> readOne(String sourceType, String sourceId, String dateStr) async => null;
  @override
  Future<void> upsert(OccurrenceOverride override) async {}
  @override
  Future<void> remove(String sourceType, String sourceId, String dateStr) async {}
  @override
  Future<List<OccurrenceOverride>> readAllFuture(String sourceType, String sourceId, String fromDateStr, {String? untilDateStr}) async => [];
  @override
  Future<void> removeAllFuture(String sourceType, String sourceId, String fromDateStr, {String? untilDateStr}) async {}
  @override
  Future<void> restoreAll(List<OccurrenceOverride> overrides) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CAL-49: Day Mark Quick Toggle & Rest/Travel Effect', () {
    setUp(() {
      CommandStack.instance.clear();
    });

    test('setDayMark(REST) skips non-essential items, preserves essential items, and undo restores them', () async {
      final essentialItem = AgendaItem(
        id: '1',
        sourceId: '1',
        title: 'داروی ضروری',
        domain: AgendaDomain.medicine,
        kind: AgendaItemKind.dose,
        category: Category.medical,
        isEssential: true,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.medicine, targetId: '1'),
        dateStr: '2026-08-18',
      );

      final nonEssentialItem = AgendaItem(
        id: '2',
        sourceId: '2',
        title: 'تمرین فوتبال',
        domain: AgendaDomain.sport,
        kind: AgendaItemKind.session,
        category: Category.fitness,
        isEssential: false,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.sport, targetId: '2'),
        dateStr: '2026-08-18',
      );

      final dayMarkRepo = InMemoryDayMarkRepository();
      final service = StubMarkAgendaService([essentialItem, nonEssentialItem], dayMarkRepo);
      final overrideRepo = InMemoryOverrideRepo();
      final actionHandler = StubActionHandler();

      final controller = JourneyController(
        agendaService: service,
        actionHandler: actionHandler,
        overrideRepo: overrideRepo,
        dayMarkRepo: dayMarkRepo,
      );

      controller.selectDate(DateTime(2026, 8, 18), scaleToSet: JourneyScale.day);
      await controller.loadForActiveScale();

      expect(controller.snapshot!.items.length, equals(2));
      expect(controller.snapshot!.items[0].completion, equals(AgendaCompletion.none));
      expect(controller.snapshot!.items[1].completion, equals(AgendaCompletion.none));

      // Mark day as REST
      await controller.setDayMark(DayMarkKind.rest, dayMarkRepo: dayMarkRepo);

      expect(controller.currentDayMark, equals(DayMarkKind.rest));
      expect(controller.snapshot!.items[0].isEssential, isTrue);
      expect(controller.snapshot!.items[0].completion, equals(AgendaCompletion.none));
      expect(controller.snapshot!.items[1].isEssential, isFalse);
      expect(controller.snapshot!.items[1].completion, equals(AgendaCompletion.skipped));

      // Undo the REST mark
      final undone = await controller.undoLastAction();
      expect(undone, isTrue);

      final markAfterUndo = await dayMarkRepo.getMark('2026-08-18');
      expect(markAfterUndo, isNull);
    });
  });
}
