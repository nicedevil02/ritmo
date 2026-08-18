import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/features/calendar/presentation/logic/timeline_layout_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CAL-31: Safe Height Calculation and Truncation Semantics', () {
    test('Item at 23:55 (5 mins) does not throw clamp exception and produces safe positive height', () {
      const engine = TimelineLayoutEngine();

      final item = AgendaItem(
        id: 'late_item',
        domain: AgendaDomain.routine,
        kind: AgendaItemKind.routine,
        sourceId: 'late_item',
        title: 'Midnight Near Routine',
        category: Category.fitness,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: 'late_item'),
        dateStr: '2026-08-18',
        timeOfDay: '23:55',
        durationMinutes: 5,
      );

      final result = engine.calculateLayout([item]);

      expect(result.length, equals(1));
      expect(result[0].height, isPositive);
      expect(result[0].top + result[0].height, lessThanOrEqualTo(engine.totalTimelineHeight));
    });

    test('isTruncated is true only when duration exceeds renderable duration', () {
      const engine = TimelineLayoutEngine(rangeStartMinutes: 480, rangeEndMinutes: 720); // 08:00 - 12:00 (240 mins)

      final longItem = AgendaItem(
        id: 'long_item',
        domain: AgendaDomain.routine,
        kind: AgendaItemKind.routine,
        sourceId: 'long_item',
        title: 'Long Routine',
        category: Category.work,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: 'long_item'),
        dateStr: '2026-08-18',
        timeOfDay: '08:00',
        durationMinutes: 300, // > 240 visible range
      );

      final normalItem = AgendaItem(
        id: 'normal_item',
        domain: AgendaDomain.routine,
        kind: AgendaItemKind.routine,
        sourceId: 'normal_item',
        title: 'Normal Routine',
        category: Category.work,
        deepLink: const AgendaDeepLink(domain: AgendaDomain.routine, targetId: 'normal_item'),
        dateStr: '2026-08-18',
        timeOfDay: '09:00',
        durationMinutes: 60,
      );

      final result = engine.calculateLayout([longItem, normalItem]);

      final longLayout = result.firstWhere((r) => r.item.id == 'long_item');
      final normalLayout = result.firstWhere((r) => r.item.id == 'normal_item');

      expect(longLayout.isTruncated, isTrue);
      expect(longLayout.renderDurationMinutes, equals(240));

      expect(normalLayout.isTruncated, isFalse);
      expect(normalLayout.renderDurationMinutes, equals(60));
    });
  });
}
