// Unit tests for CyclePeriod (C-12, C-14, C-16)
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/cycle/logic/cycle_period_repository.dart';

void main() {
  group('CyclePeriod Model', () {
    test('isOpen returns true when endDate is null', () {
      final period = CyclePeriod(
        id: 1,
        startDate: DateTime(2026, 5, 1),
        endDate: null,
        createdAt: 1000,
        updatedAt: 1000,
      );
      expect(period.isOpen, true);
    });

    test('isOpen returns false when endDate is provided', () {
      final period = CyclePeriod(
        id: 1,
        startDate: DateTime(2026, 5, 1),
        endDate: DateTime(2026, 5, 6),
        createdAt: 1000,
        updatedAt: 1000,
      );
      expect(period.isOpen, false);
    });

    test('toMap and fromMap serialize and deserialize accurately with DayKey format', () {
      final original = CyclePeriod(
        id: 42,
        startDate: DateTime(2026, 5, 1),
        endDate: DateTime(2026, 5, 7),
        cycleLength: 28,
        periodDuration: 7,
        notes: 'تست دوره',
        suppressedPrayer: true,
        fastDebtCreated: false,
        createdAt: 1700000000,
        updatedAt: 1700005000,
      );

      final map = original.toMap();
      expect(map['id'], 42);
      expect(map['startDate'], '2026-05-01');
      expect(map['endDate'], '2026-05-07');
      expect(map['periodDuration'], 7);
      expect(map['suppressedPrayer'], 1);
      expect(map['fastDebtCreated'], 0);

      final restored = CyclePeriod.fromMap(map);
      expect(restored.id, 42);
      expect(restored.startDate.year, 2026);
      expect(restored.startDate.month, 5);
      expect(restored.startDate.day, 1);
      expect(restored.endDate!.year, 2026);
      expect(restored.endDate!.month, 5);
      expect(restored.endDate!.day, 7);
      expect(restored.periodDuration, 7);
      expect(restored.suppressedPrayer, true);
      expect(restored.fastDebtCreated, false);
      expect(restored.notes, 'تست دوره');
    });

    test('fromMap gracefully maps legacy cycleStartDate/cycleEndDate keys', () {
      final legacyMap = {
        'id': 10,
        'cycleStartDate': '2026-04-10',
        'cycleEndDate': '2026-04-15',
        'suppressedPrayer': 1,
        'fastDebtCreated': 1,
        'createdAt': 1000,
        'updatedAt': 1000,
      };

      final period = CyclePeriod.fromMap(legacyMap);
      expect(period.id, 10);
      expect(period.startDate.year, 2026);
      expect(period.startDate.month, 4);
      expect(period.startDate.day, 10);
      expect(period.endDate!.year, 2026);
      expect(period.endDate!.month, 4);
      expect(period.endDate!.day, 15);
      expect(period.fastDebtCreated, true);
    });
  });
}
