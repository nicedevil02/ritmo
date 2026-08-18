import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_action_handler.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/agenda_load_status.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/domain/agenda/occurrence_override_repository.dart';
import 'package:ritmo/core/domain/commands/command_stack.dart';
import 'package:ritmo/core/domain/engines/ritmo_execution_kernel.dart';
import 'package:ritmo/core/domain/execution/kernel_mutation_result.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/features/calendar/data/day_mark_repository.dart';
import 'package:ritmo/features/calendar/presentation/journey_controller.dart';
import 'package:sqflite/sqflite.dart';

class StubFocusAgendaService implements DayAgendaService {
  StubFocusAgendaService(this.item);
  final AgendaItem item;

  @override
  AgendaLoadStatus get lastLoadStatus => const AgendaLoadStatus.ok();

  @override
  Future<Map<String, DayAgenda>> agendaForRange(DateTime start, DateTime end, {AgendaQueryOptions? options}) async {
    return {
      '2026-08-18': DayAgenda(dateStr: '2026-08-18', items: [item]),
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

class FakeExecutionKernel extends RitmoExecutionKernel {
  FakeExecutionKernel() : super.test();

  final List<dynamic> executedCommands = [];

  @override
  Future<KernelMutationResult> execute(KernelCommand command, {Transaction? txn}) async {
    executedCommands.add(command);
    return KernelMutationResult.empty;
  }
}

class StubActionHandler extends AgendaActionHandler {
  StubActionHandler() : super.test();
}

class InMemoryDayMarkRepo extends DayMarkRepository {
  InMemoryDayMarkRepo() : super();
  @override
  Future<DayMark?> getMark(String dateStr) async => null;
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

  group('CAL-50: Focus Block & Partial Completion', () {
    setUp(() {
      CommandStack.instance.clear();
    });

    test('completeItem with OccurrenceResultType.partial passes partial resultType and actual duration to kernel', () async {
      final routineItem = AgendaItem(
        id: 'r1',
        sourceId: 'routine-101',
        title: 'مطالعه عمیق ریاضی',
        domain: AgendaDomain.routine,
        kind: AgendaItemKind.routine,
        category: Category.learning,
        timeOfDay: '10:00',
        durationMinutes: 45,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: 'routine-101'),
        dateStr: '2026-08-18',
      );

      final service = StubFocusAgendaService(routineItem);
      final kernel = FakeExecutionKernel();
      final actionHandler = StubActionHandler();
      final dayMarkRepo = InMemoryDayMarkRepo();
      final overrideRepo = InMemoryOverrideRepo();

      final controller = JourneyController(
        agendaService: service,
        kernel: kernel,
        actionHandler: actionHandler,
        dayMarkRepo: dayMarkRepo,
        overrideRepo: overrideRepo,
      );

      controller.selectDate(DateTime(2026, 8, 18), scaleToSet: JourneyScale.day);
      await controller.loadForActiveScale();

      // Complete partially (e.g. focused for 20 minutes out of 45)
      await controller.completeItem(
        routineItem,
        resultType: OccurrenceResultType.partial,
        actualDurationMinutes: 20,
      );

      expect(kernel.executedCommands.length, equals(1));
      final cmd = kernel.executedCommands.first;
      expect(cmd, isA<CompleteOccurrenceCommand>());
      final completeCmd = cmd as CompleteOccurrenceCommand;
      expect(completeCmd.routineId, equals('routine-101'));
      expect(completeCmd.dateStr, equals('2026-08-18'));
      expect(completeCmd.resultType, equals(OccurrenceResultType.partial));
      expect(completeCmd.durationMinutes, equals(20));
    });

    test('completeItem with default params completes with full resultType and full durationMinutes', () async {
      final routineItem = AgendaItem(
        id: 'r2',
        sourceId: 'routine-102',
        title: 'ورزش صبحگاهی',
        domain: AgendaDomain.routine,
        kind: AgendaItemKind.routine,
        category: Category.fitness,
        timeOfDay: '07:00',
        durationMinutes: 30,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: 'routine-102'),
        dateStr: '2026-08-18',
      );

      final service = StubFocusAgendaService(routineItem);
      final kernel = FakeExecutionKernel();
      final actionHandler = StubActionHandler();
      final dayMarkRepo = InMemoryDayMarkRepo();
      final overrideRepo = InMemoryOverrideRepo();

      final controller = JourneyController(
        agendaService: service,
        kernel: kernel,
        actionHandler: actionHandler,
        dayMarkRepo: dayMarkRepo,
        overrideRepo: overrideRepo,
      );

      controller.selectDate(DateTime(2026, 8, 18), scaleToSet: JourneyScale.day);
      await controller.loadForActiveScale();

      await controller.completeItem(routineItem);

      expect(kernel.executedCommands.length, equals(1));
      final completeCmd = kernel.executedCommands.first as CompleteOccurrenceCommand;
      expect(completeCmd.routineId, equals('routine-102'));
      expect(completeCmd.resultType, equals(OccurrenceResultType.full));
      expect(completeCmd.durationMinutes, equals(30));
    });
  });
}
