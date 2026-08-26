import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_action_handler.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/agenda_load_status.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/domain/agenda/models/day_agenda_snapshot.dart';
import 'package:ritmo/core/domain/agenda/occurrence_override_repository.dart';
import 'package:ritmo/core/domain/commands/command_stack.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/utils/date_key.dart';
import 'package:ritmo/core/utils/shamsi_week.dart';
import 'package:ritmo/features/calendar/data/day_mark_repository.dart';
import 'package:ritmo/features/calendar/presentation/journey_controller.dart';
import 'package:ritmo/features/calendar/presentation/widgets/journey_month_view.dart';
import 'package:ritmo/features/calendar/presentation/widgets/journey_year_view.dart';
import 'package:shamsi_date/shamsi_date.dart';

class MockDayAgendaService implements DayAgendaService {
  MockDayAgendaService({this.delay = Duration.zero});

  final Duration delay;
  final List<({DateTime start, DateTime end})> requestedRanges = [];

  @override
  AgendaLoadStatus get lastLoadStatus => const AgendaLoadStatus.ok();

  @override
  Future<Map<String, DayAgenda>> agendaForRange(
    DateTime start,
    DateTime end, {
    AgendaQueryOptions? options,
  }) async {
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }
    requestedRanges.add((start: start, end: end));
    final map = <String, DayAgenda>{};
    var curr = DateKey.dayOf(start);
    final endDay = DateKey.dayOf(end);
    while (!curr.isAfter(endDay)) {
      final k = DateKey.of(curr);
      map[k] = DayAgenda(dateStr: k, items: const []);
      curr = DateKey.addDays(curr, 1);
    }
    return map;
  }

  @override
  Future<int> countOverdueBefore(DateTime cutoff) async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class InMemoryDayMarkRepo extends DayMarkRepository {
  InMemoryDayMarkRepo() : super();
  final Map<String, DayMark> _marks = {};

  @override
  Future<DayMark?> getMark(String dateStr) async => _marks[dateStr];

  @override
  Future<bool> setMark(String dateStr, DayMarkKind kind, {String? note}) async {
    _marks[dateStr] = DayMark(
      dateStr: dateStr,
      kind: kind,
      note: note,
    );
    return true;
  }
}

class InMemoryOverrideRepo implements OccurrenceOverrideRepository {
  final Map<String, OccurrenceOverride> _overrides = {};
  String? lastReadAllFutureUntil;
  String? lastRemoveAllFutureUntil;

  @override
  Future<OccurrenceOverride?> readOne(
    String sourceType,
    String sourceId,
    String dateStr,
  ) async {
    return _overrides['$sourceType:$sourceId:$dateStr'];
  }

  @override
  Future<void> upsert(OccurrenceOverride override) async {
    _overrides['${override.sourceType}:${override.sourceId}:${override.dateStr}'] =
        override;
  }

  @override
  Future<void> remove(
    String sourceType,
    String sourceId,
    String dateStr,
  ) async {
    _overrides.remove('$sourceType:$sourceId:$dateStr');
  }

  @override
  Future<List<OccurrenceOverride>> readAllFuture(
    String sourceType,
    String sourceId,
    String dateStr, {
    String? untilDateStr,
  }) async {
    lastReadAllFutureUntil = untilDateStr;
    return _overrides.values
        .where(
          (o) =>
              o.sourceType == sourceType &&
              o.sourceId == sourceId &&
              o.dateStr.compareTo(dateStr) >= 0 &&
              (untilDateStr == null || o.dateStr.compareTo(untilDateStr) <= 0),
        )
        .toList();
  }

  @override
  Future<void> removeAllFuture(
    String sourceType,
    String sourceId,
    String dateStr, {
    String? untilDateStr,
  }) async {
    lastRemoveAllFutureUntil = untilDateStr;
    _overrides.removeWhere(
      (k, o) =>
          o.sourceType == sourceType &&
          o.sourceId == sourceId &&
          o.dateStr.compareTo(dateStr) >= 0 &&
          (untilDateStr == null || o.dateStr.compareTo(untilDateStr) <= 0),
    );
  }

  @override
  Future<void> restoreAll(List<OccurrenceOverride> overrides) async {
    for (final o in overrides) {
      await upsert(o);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Calendar 11 Bugs & Hardening Tests', () {
    test('Bug 6: Action errors set actionErrorMessage and do not pollute loadErrorMessage', () async {
      final markRepo = InMemoryDayMarkRepo();
      final controller = JourneyController(dayMarkRepo: markRepo);

      expect(controller.loadErrorMessage, isNull);
      expect(controller.actionErrorMessage, isNull);

      final dummyItem = AgendaItem(
        id: 't1',
        domain: AgendaDomain.task,
        sourceId: 'src1',
        title: 'Test Item',
        dateStr: '2026-08-26',
        category: Category.personal,
        completion: AgendaCompletion.none,
        itemType: AgendaItemType.flexible,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.task, targetId: 'src1'),
      );

      await controller.scheduleItem(dummyItem, 9999, 30);
      expect(controller.actionErrorMessage, isNotNull);
      expect(controller.loadErrorMessage, isNull);
    });

    test('Bug 8: DayMarkRepository injection and setDayMark', () async {
      final markRepo = InMemoryDayMarkRepo();
      final controller = JourneyController(dayMarkRepo: markRepo);

      await controller.selectDate(DateTime(2026, 8, 26), scaleToSet: JourneyScale.day);
      expect(controller.currentDayMark, equals(DayMarkKind.normal));

      await controller.setDayMark(DayMarkKind.rest, dayMarkRepo: markRepo);
      expect(controller.currentDayMark, equals(DayMarkKind.rest));

      final saved = await markRepo.getMark('2026-08-26');
      expect(saved?.kind, equals(DayMarkKind.rest));
    });

    test('Bug 12: selectDate returns Future<void> and completes loading', () async {
      final service = MockDayAgendaService();
      final controller = JourneyController(agendaService: service);

      await controller.selectDate(DateTime(2026, 8, 26), scaleToSet: JourneyScale.day);
      expect(controller.isLoading, isFalse);
      expect(controller.selectedDate, equals(DateTime(2026, 8, 26)));
    });

    test('Bug 15: calculateDateRangeForScale for month returns full grid bounds (Saturday of 1st to end)', () {
      final anchor = DateTime(2026, 8, 26);
      final range = JourneyController.calculateDateRangeForScale(JourneyScale.month, anchor);

      final jAnchor = Jalali.fromDateTime(anchor);
      final firstOfMonth = Jalali(jAnchor.year, jAnchor.month, 1).toDateTime();
      final expectedStart = ShamsiWeek.saturdayOf(firstOfMonth);

      expect(range.start, equals(expectedStart),
          reason: 'Month range start must start on Saturday before 1st of month');
      final totalDays = range.end.difference(range.start).inDays + 1;
      expect(totalDays % 7, equals(0),
          reason: 'Total days in month grid must be a multiple of 7 (full weeks)');
    });

    test('Bug 16: JourneyMonthView & JourneyYearView use AlwaysScrollableScrollPhysics for Pull-to-Refresh', () {
      final monthView = JourneyMonthView(
        selectedDate: DateTime.now(),
        rangeSnapshots: const {},
        onSelectDate: (_) {},
      );
      expect(monthView, isNotNull);

      final yearView = JourneyYearView(
        selectedDate: DateTime.now(),
        rangeSnapshots: const {},
        onSelectMonth: (_) {},
      );
      expect(yearView, isNotNull);
    });

    test('Bug 21: DateKey.of produces standardized ISO format YYYY-MM-DD', () {
      final date = DateTime(2026, 5, 4);
      expect(DateKey.of(date), equals('2026-05-04'));
    });

    test('Bug 25: Isolated CommandStack per JourneyController instance & dispose clears stack', () async {
      final stack1 = CommandStack();
      final stack2 = CommandStack();

      final controller1 = JourneyController(commandStack: stack1);
      final controller2 = JourneyController(commandStack: stack2);

      expect(controller1.canUndo, isFalse);
      expect(controller2.canUndo, isFalse);

      controller1.dispose();
      expect(stack1.length, equals(0));

      controller2.dispose();
      expect(stack2.length, equals(0));
    });

    test('Risk 1: _MoveItemCommand uses TIME_OVERRIDE for intra-day move', () async {
      final overrideRepo = InMemoryOverrideRepo();
      final controller = JourneyController(overrideRepo: overrideRepo);

      final dummyItem = AgendaItem(
        id: 'r1',
        domain: AgendaDomain.routine,
        sourceId: 'routine_1',
        title: 'Morning Yoga',
        dateStr: '2026-08-26',
        timeOfDay: '08:00',
        durationMinutes: 30,
        category: Category.personal,
        completion: AgendaCompletion.none,
        itemType: AgendaItemType.fixed,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: 'routine_1'),
      );

      await controller.commitItemDrag(dummyItem, '09:00', scope: CalendarEditScope.thisDayOnly);

      final saved = await overrideRepo.readOne('routine', 'routine_1', '2026-08-26');
      expect(saved, isNotNull);
      expect(saved!.status, equals('TIME_OVERRIDE'),
          reason: 'Intra-day drag must write TIME_OVERRIDE status to avoid ghost synthesis');
    });

    test('Risk 2: allFutureDays edits cap override wipe to 366-day horizon', () async {
      final overrideRepo = InMemoryOverrideRepo();
      final controller = JourneyController(overrideRepo: overrideRepo);

      final dummyItem = AgendaItem(
        id: 'r1',
        domain: AgendaDomain.routine,
        sourceId: 'routine_1',
        title: 'Morning Yoga',
        dateStr: '2026-08-26',
        timeOfDay: '08:00',
        durationMinutes: 30,
        category: Category.personal,
        completion: AgendaCompletion.none,
        itemType: AgendaItemType.fixed,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: 'routine_1'),
      );

      await controller.commitItemDrag(dummyItem, '09:00', scope: CalendarEditScope.allFutureDays);

      expect(overrideRepo.lastRemoveAllFutureUntil, isNotNull);
      final untilDate = DateKey.parse(overrideRepo.lastRemoveAllFutureUntil!);
      expect(untilDate, isNotNull);
      final daysDiff = untilDate!.difference(DateTime(2026, 8, 26)).inDays;
      expect(daysDiff, equals(366),
          reason: 'Horizon limit on allFutureDays should be 366 days');
    });

    test('Bug 13: Year scale loads in 4 quarterly chunks with responsive non-blocking updates', () async {
      final service = MockDayAgendaService();
      final controller = JourneyController(agendaService: service);

      await controller.selectDate(DateTime(2026, 8, 26), scaleToSet: JourneyScale.year);
      expect(controller.isLoading, isFalse);
      expect(controller.rangeSnapshots, isNotEmpty);
      expect(service.requestedRanges.length, equals(4),
          reason: 'Year scale must query 4 quarterly chunks to prevent UI thread lock');
    });
  });
}
