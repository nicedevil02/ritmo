import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/appointment_agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/commitment_agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/course_agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/event_agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/goal_steps_agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/routine_agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/task_agenda_source.dart';
import 'package:ritmo/core/domain/agenda/sources/worship_agenda_source.dart';
import 'package:ritmo/features/courses/models/course_models.dart';
import 'package:sqflite/sqflite.dart';

class _FakeDatabase implements Database {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Phase M3-C: Agenda Creation Visibility Test (P13 / M3-4)', () {
    const targetDateStr = '2026-08-15';
    final targetDate = DateTime(2026, 8, 15);
    final ctx = AgendaDayContext(
      date: targetDate,
      dateStr: targetDateStr,
      isToday: true,
      prayerTimes: const {
        'fajr': '04:30',
        'sunrise': '06:00',
        'dhuhr': '12:10',
        'maghrib': '19:15',
        'midnightShari': '23:45'
      },
      options: const AgendaQueryOptions(),
    );

    test('M3-4: Created simple task is visible in TaskAgendaSource for target date', () {
      final source = TaskAgendaSource(
        tasksByDate: {
          targetDateStr: [
            {
              'id': 'task_001',
              'title': 'خرید کتاب',
              'dueDate': targetDateStr,
              'status': 'PENDING',
              'durationMinutes': 30,
            }
          ]
        },
        overdueTasks: const [],
        datelessTasks: const [],
        totalOverdueCount: 0,
        stepCounts: const {},
      );

      final items = source.itemsForDate(ctx);
      expect(items, hasLength(1));
      expect(items.first.title, equals('خرید کتاب'));
      expect(items.first.domain, equals(AgendaDomain.task));
    });

    test('M3-4: Created temporary event is visible in EventAgendaSource for target date', () {
      const source = EventAgendaSource(
        events: [
          {
            'id': 'evt_001',
            'title': 'جلسه با تیم',
            'date': targetDateStr,
            'startTime': '10:00',
            'durationMinutes': 60,
            'category': 'WORK',
          }
        ],
        isEnabled: true,
      );

      final items = source.itemsForDate(ctx);
      expect(items, hasLength(1));
      expect(items.first.title, equals('جلسه با تیم'));
      expect(items.first.domain, equals(AgendaDomain.event));
    });

    test('M3-4: Created routine is visible in RoutineAgendaSource for target date', () {
      const source = RoutineAgendaSource(
        routines: [
          {
            'id': 'rtn_001',
            'title': 'ورزش صبحگاهی',
            'itemType': 'ROUTINE',
            'recurrenceType': 'DAILY',
            'status': 'ACTIVE',
            'targetTime': '07:00',
            'targetDurationMinutes': 20,
            'daysOfWeek': '[1,2,3,4,5,6,7]',
          }
        ],
        schedules: [
          {
            'routineId': 'rtn_001',
            'timeOfDay': '07:00',
            'daysOfWeek': '1,2,3,4,5,6,7',
          }
        ],
        occurrences: [],
        avgDurations: {},
        categoryAvgDurations: {},
        completionsByDate: {},
        activeModules: {'module_today_routines': true},
      );

      final items = source.itemsForDate(ctx);
      expect(items, hasLength(1));
      expect(items.first.title, equals('ورزش صبحگاهی'));
      expect(items.first.domain, equals(AgendaDomain.routine));
    });

    test('M3-4: Created course session is visible in CourseAgendaSource for target date', () {
      final session = CourseSession(
        id: 'sess_001',
        courseId: 'course_101',
        sessionNumber: 5,
        plannedDate: targetDateStr,
        plannedStartTime: '16:00',
        estimatedDurationMinutes: 90,
        createdAt: 1770000000000,
        updatedAt: 1770000000000,
      );

      final course = Course(
        id: 'course_101',
        title: 'برنامه‌نویسی دارت',
        totalSessions: 10,
        sessionDurationMinutes: 90,
        courseType: CourseType.video,
        preferredDays: const [1, 2, 3, 4, 5, 6, 7],
        createdAt: 1770000000000,
        updatedAt: 1770000000000,
      );

      final source = CourseAgendaSource(
        courseTitles: {'course_101': 'برنامه‌نویسی دارت'},
        coursesMap: {'course_101': course},
        sessionsByDate: {
          targetDateStr: [session]
        },
        coursesEnabled: true,
      );

      final items = source.itemsForDate(ctx);
      expect(items, hasLength(1));
      expect(items.first.subtitle, contains('برنامه‌نویسی دارت'));
      expect(items.first.domain, equals(AgendaDomain.course));
    });

    test('M3-4: Created goal step is visible in GoalStepsAgendaSource for target date', () {
      const source = GoalStepsAgendaSource(
        goalStepsByDate: {
          targetDateStr: [
            {
              'id': 'gstep_001',
              'goalId': 'goal_101',
              'goalTitle': 'هدف رشد شغلی',
              'title': 'ارسال رزومه',
              'scheduledDate': targetDateStr,
              'isCompleted': 0,
            }
          ]
        },
        activeGoals: [],
        isEnabled: true,
      );

      final items = source.itemsForDate(ctx);
      expect(items, hasLength(1));
      expect(items.first.title, equals('ارسال رزومه'));
      expect(items.first.domain, equals(AgendaDomain.goalStep));
    });

    test('M3-4: Created appointment is visible in AppointmentAgendaSource for target date', () {
      const source = AppointmentAgendaSource(
        appointmentsByDate: {
          targetDateStr: [
            {
              'id': 'app_001',
              'title': 'ویزیت پزشک',
              'appointmentDate': targetDateStr,
              'appointmentTime': '11:00',
              'durationMinutes': 30,
              'type': 'DOCTOR',
            }
          ]
        },
        isEnabled: true,
      );

      final items = source.itemsForDate(ctx);
      expect(items, hasLength(1));
      expect(items.first.title, equals('ویزیت پزشک'));
      expect(items.first.domain, equals(AgendaDomain.appointment));
    });

    test('M3-4: Created worship practice is visible in WorshipAgendaSource for target date', () {
      final fakeDb = _FakeDatabase();
      final source = WorshipAgendaSource(
        prayerPractices: [
          {'id': 'fajr_01', 'subType': 'FAJR', 'title': 'نماز صبح'},
        ],
        mustahabPractices: const [],
        worshipDebts: const [],
        settingsMap: const {'module_religion_enabled': 'true'},
        religionEnabled: true,
        cachedHijriDates: const {},
        statusesByDate: const {},
        contextsByDate: const {},
        hasLunarMonthly: false,
        db: fakeDb,
      );

      final items = source.itemsForDate(ctx);
      expect(items, hasLength(1));
      expect(items.first.title, equals('نماز صبح'));
      expect(items.first.domain, equals(AgendaDomain.prayer));
    });

    test('M3-4: Created commitment allocation is visible in CommitmentAgendaSource for target date', () {
      const source = CommitmentAgendaSource(
        allocationsByDate: {
          targetDateStr: [
            {
              'id': 'alloc_001',
              'commitmentId': 'comm_01',
              'commTitle': 'تخصیص زمان مطالعه',
              'dateStr': targetDateStr,
              'plannedMinutes': 45,
              'materializedEntityType': 'ROUTINE',
            }
          ]
        },
        isEnabled: true,
      );

      final items = source.itemsForDate(ctx);
      expect(items, hasLength(1));
      expect(items.first.title, equals('تخصیص زمان مطالعه'));
      expect(items.first.domain, equals(AgendaDomain.commitment));
    });

    test('M3-4: Fail-fast check on date mismatch (Negative test check)', () {
      final otherCtx = AgendaDayContext(
        date: DateTime(2026, 8, 16),
        dateStr: '2026-08-16',
        isToday: false,
        prayerTimes: const {},
        options: const AgendaQueryOptions(),
      );

      final source = TaskAgendaSource(
        tasksByDate: {
          targetDateStr: [
            {
              'id': 'task_001',
              'title': 'خرید کتاب',
              'dueDate': targetDateStr,
              'status': 'PENDING',
              'durationMinutes': 30,
            }
          ]
        },
        overdueTasks: const [],
        datelessTasks: const [],
        totalOverdueCount: 0,
        stepCounts: const {},
      );

      expect(source.itemsForDate(otherCtx), isEmpty);
    });
  });
}
