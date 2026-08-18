import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/calendar/presentation/journey_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JourneyController _selectedDate Midnight Normalization (CAL-08 / CAL-56)', () {
    test('Initial selectedDate is normalized to midnight', () {
      final controller = JourneyController();
      expect(controller.selectedDate.hour, equals(0));
      expect(controller.selectedDate.minute, equals(0));
      expect(controller.selectedDate.second, equals(0));
      expect(controller.selectedDate.millisecond, equals(0));
      expect(controller.selectedDate.microsecond, equals(0));
      controller.dispose();
    });

    test('selectDate strips any time components and normalizes to midnight', () {
      final controller = JourneyController();
      controller.selectDate(DateTime(2026, 8, 18, 15, 45, 30, 123));

      expect(controller.selectedDate, equals(DateTime(2026, 8, 18, 0, 0, 0)));
      expect(controller.selectedDate.hour, equals(0));
      expect(controller.selectedDate.minute, equals(0));
      expect(controller.selectedDate.second, equals(0));
      controller.dispose();
    });

    test('navigatePeriod keeps midnight across all 5 scales', () {
      final controller = JourneyController();
      controller.selectDate(DateTime(2026, 8, 18, 12, 0, 0));

      for (final scale in JourneyScale.values) {
        controller.setScale(scale);
        controller.navigatePeriod(1);
        expect(controller.selectedDate.hour, equals(0), reason: 'Failed for forward on $scale');
        expect(controller.selectedDate.minute, equals(0), reason: 'Failed for forward on $scale');
        expect(controller.selectedDate.second, equals(0), reason: 'Failed for forward on $scale');

        controller.navigatePeriod(-2);
        expect(controller.selectedDate.hour, equals(0), reason: 'Failed for backward on $scale');
        expect(controller.selectedDate.minute, equals(0), reason: 'Failed for backward on $scale');
        expect(controller.selectedDate.second, equals(0), reason: 'Failed for backward on $scale');
      }

      controller.dispose();
    });
  });
}
