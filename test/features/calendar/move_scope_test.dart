import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/calendar/presentation/journey_controller.dart';

void main() {
  group('P0-2 & P0-3: Move and Resize Scope Tests', () {
    test('CalendarEditScope enum contains thisDayOnly and allFutureDays', () {
      expect(CalendarEditScope.values, contains(CalendarEditScope.thisDayOnly));
      expect(CalendarEditScope.values, contains(CalendarEditScope.allFutureDays));
    });
  });
}
