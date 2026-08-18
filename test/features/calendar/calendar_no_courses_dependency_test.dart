import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/utils/date_key.dart';
import 'package:ritmo/core/utils/shamsi_week.dart';
import 'package:ritmo/features/courses/logic/course_scheduler.dart';
import 'package:shamsi_date/shamsi_date.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CAL-41: Core ShamsiWeek and Decoupling from Courses Feature', () {
    test('ShamsiWeek.saturdayOf and fridayOf calculate correct week boundaries', () {
      // 1405-05-27 Jalali is Mordad 27, 1405 (a Monday = day 3 of week)
      final d = DateTime(2026, 8, 18);
      final sat = ShamsiWeek.saturdayOf(d);
      final fri = ShamsiWeek.fridayOf(d);

      final satJ = Jalali.fromDateTime(sat);
      final friJ = Jalali.fromDateTime(fri);

      expect(satJ.weekDay, equals(1), reason: 'Saturday must have Jalali weekDay 1');
      expect(friJ.weekDay, equals(7), reason: 'Friday must have Jalali weekDay 7');
      expect(fri.difference(sat).inDays, equals(6));
    });

    test('Deprecated CourseScheduler.getSaturdayOfWeek delegates identically to ShamsiWeek.saturdayOf', () {
      for (int i = 0; i < 30; i++) {
        final d = DateKey.addDays(DateTime(2026, 8, 1), i);
        // ignore: deprecated_member_use_from_same_package
        expect(CourseScheduler.getSaturdayOfWeek(d), equals(ShamsiWeek.saturdayOf(d)));
      }
    });

    test('Calendar feature files do not import course_scheduler.dart', () {
      final controllerFile = File('lib/features/calendar/presentation/journey_controller.dart');
      final bucketingFile = File('lib/features/calendar/presentation/logic/agenda_bucketing.dart');
      final monthViewFile = File('lib/features/calendar/presentation/widgets/journey_month_view.dart');
      final weekViewFile = File('lib/features/calendar/presentation/widgets/journey_week_view.dart');

      expect(controllerFile.readAsStringSync().contains('course_scheduler.dart'), isFalse);
      expect(bucketingFile.readAsStringSync().contains('course_scheduler.dart'), isFalse);
      expect(monthViewFile.readAsStringSync().contains('course_scheduler.dart'), isFalse);
      expect(weekViewFile.readAsStringSync().contains('course_scheduler.dart'), isFalse);
    });
  });
}
