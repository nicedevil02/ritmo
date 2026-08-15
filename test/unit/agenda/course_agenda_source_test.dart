import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/course_agenda_source.dart';
import 'package:ritmo/features/courses/models/course_models.dart';

void main() {
  group('Phase M1-D: Real Course Session Time (P9 / M1-11)', () {
    final activeCourse = Course(
      id: 'course_flutter',
      title: 'آموزش جامع فلاتر',
      totalSessions: 20,
      sessionDurationMinutes: 45,
      createdAt: 1000,
      updatedAt: 1000,
      courseType: CourseType.video,
      preferredDays: [0, 2, 4],
      preferredTime: '18:00',
      status: CourseStatus.active,
    );

    final pausedCourse = Course(
      id: 'course_paused',
      title: 'دوره متوقف‌شده',
      totalSessions: 10,
      sessionDurationMinutes: 60,
      createdAt: 1000,
      updatedAt: 1000,
      courseType: CourseType.book,
      preferredDays: [1, 3],
      preferredTime: '20:00',
      status: CourseStatus.paused,
    );

    test('Session plannedStartTime and estimatedDurationMinutes take precedence over course defaults', () {
      final session1 = CourseSession(
        id: 's_custom_time',
        courseId: 'course_flutter',
        sessionNumber: 1,
        sessionTitle: 'آشنایی با ویجت‌ها',
        plannedDate: '2026-08-15',
        plannedStartTime: '14:30', // custom time
        estimatedDurationMinutes: 75, // custom duration
        createdAt: 1000,
        updatedAt: 1000,
      );

      final session2 = CourseSession(
        id: 's_default_time',
        courseId: 'course_flutter',
        sessionNumber: 2,
        sessionTitle: 'مدیریت وضعیت',
        plannedDate: '2026-08-15',
        plannedStartTime: null, // fallback to course preferredTime (18:00)
        estimatedDurationMinutes: null, // fallback to course sessionDurationMinutes (45)
        createdAt: 1000,
        updatedAt: 1000,
      );

      final source = CourseAgendaSource(
        courseTitles: {'course_flutter': 'آموزش جامع فلاتر'},
        coursesMap: {'course_flutter': activeCourse},
        sessionsByDate: {'2026-08-15': [session1, session2]},
        coursesEnabled: true,
      );

      final ctx = AgendaDayContext(
        date: DateTime(2026, 8, 15),
        dateStr: '2026-08-15',
        isToday: true,
        prayerTimes: const {},
        options: const AgendaQueryOptions(),
      );

      final items = source.itemsForDate(ctx);
      expect(items, hasLength(2));

      // Session 1: custom time & duration
      expect(items[0].id, equals('course:s_custom_time:2026-08-15'));
      expect(items[0].timeOfDay, equals('14:30'));
      expect(items[0].durationMinutes, equals(75));
      expect(items[0].itemType, equals(AgendaItemType.fixed));

      // Session 2: fallback to course values
      expect(items[1].id, equals('course:s_default_time:2026-08-15'));
      expect(items[1].timeOfDay, equals('18:00'));
      expect(items[1].durationMinutes, equals(45));
      expect(items[1].itemType, equals(AgendaItemType.fixed));
    });

    test('Skipped course sessions map to AgendaCompletion.skipped', () {
      final skippedSession = CourseSession(
        id: 's_skipped',
        courseId: 'course_flutter',
        sessionNumber: 3,
        plannedDate: '2026-08-15',
        completionStatus: SessionStatus.skipped,
        createdAt: 1000,
        updatedAt: 1000,
      );

      final source = CourseAgendaSource(
        courseTitles: {'course_flutter': 'آموزش جامع فلاتر'},
        coursesMap: {'course_flutter': activeCourse},
        sessionsByDate: {'2026-08-15': [skippedSession]},
        coursesEnabled: true,
      );

      final ctx = AgendaDayContext(
        date: DateTime(2026, 8, 15),
        dateStr: '2026-08-15',
        isToday: true,
        prayerTimes: const {},
        options: const AgendaQueryOptions(),
      );

      final items = source.itemsForDate(ctx);
      expect(items, hasLength(1));
      expect(items.first.completion, equals(AgendaCompletion.skipped));
    });

    test('Paused courses sessions are excluded from agenda items', () {
      final pausedSession = CourseSession(
        id: 's_paused',
        courseId: 'course_paused',
        sessionNumber: 1,
        plannedDate: '2026-08-15',
        createdAt: 1000,
        updatedAt: 1000,
      );

      final source = CourseAgendaSource(
        courseTitles: {'course_paused': 'دوره متوقف‌شده'},
        coursesMap: {'course_paused': pausedCourse},
        sessionsByDate: {'2026-08-15': [pausedSession]},
        coursesEnabled: true,
      );

      final ctx = AgendaDayContext(
        date: DateTime(2026, 8, 15),
        dateStr: '2026-08-15',
        isToday: true,
        prayerTimes: const {},
        options: const AgendaQueryOptions(),
      );

      final items = source.itemsForDate(ctx);
      expect(items, isEmpty);
    });
  });
}
