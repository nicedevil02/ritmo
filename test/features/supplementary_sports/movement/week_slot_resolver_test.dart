import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_kind.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_reminder_defaults.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_slot_override.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/week_plan_item.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/week_slot_resolver.dart';

void main() {
  group('weekday conversion',
    () {
      test('DateTime.weekday maps onto Sat0',
        () {
          expect(dartWeekdayToSat0(DateTime.saturday), 0);
          expect(dartWeekdayToSat0(DateTime.sunday), 1);
          expect(dartWeekdayToSat0(DateTime.monday), 2);
          expect(dartWeekdayToSat0(DateTime.friday), 6);
        },
      );

      test('ss_workout_plan dayOfWeek maps onto Sat0',
        () {
          expect(ssDayOfWeekToSat0(1), 0);
          expect(ssDayOfWeekToSat0(7), 6);
        },
      );
    },
  );

  group('MovementReminderDefaults',
    () {
      MovementKind kind({
        bool social = false,
        bool outdoor = false,
        bool venue = false,
      }) {
        return MovementKind(
          code: 'TEST',
          titleFa: 'تست',
          emoji: '✅',
          family: MovementFamily.endurance,
          baseMet: 4,
          metLow: 3,
          metHigh: 6,
          primaryMetric: MovementMetric.duration,
          secondaryMetric: MovementMetric.none,
          isOutdoor: outdoor,
          isSocial: social,
          needsVenue: venue,
          jointImpact: 1,
          isCustom: false,
          isEnabled: true,
          usageCount: 0,
          sortOrder: 0,
        );
      }

      test('meetup / outdoor / gym / home',
        () {
          expect(MovementReminderDefaults.minutesFor(kind(social: true)), 60);
          expect(MovementReminderDefaults.minutesFor(kind(outdoor: true)), 90);
          expect(MovementReminderDefaults.minutesFor(kind(venue: true)), 30);
          expect(MovementReminderDefaults.minutesFor(kind()), 10);
        },
      );
    },
  );

  group('WeekSlotResolver',
    () {
      // Wednesday 12 Aug 2026 — week is Sat 8 … Fri 14.
      final now = DateTime(2026, 8, 12);
      const gymId = 'routine_gym';

      PlannedSlot satGym() => PlannedSlot(
            routineId: gymId,
            weekdaySat0: 0,
            dateIso: '2026-08-08',
            time: '18:30',
            title: 'باشگاه',
          );

      MovementSlotOverride ov({
        required MovementSlotAction action,
        String dateIso = '2026-08-08',
        String? newDateIso,
        String? newTime,
      }) {
        return MovementSlotOverride(
          id: 'ov1',
          routineId: gymId,
          dateIso: dateIso,
          action: action,
          newDateIso: newDateIso,
          newTime: newTime,
          createdAt: 1,
        );
      }

      test('SKIP removes the occurrence and keeps the template unused',
        () {
          final resolved = const WeekSlotResolver().resolve(
            templates: <PlannedSlot>[satGym()],
            overrides: <MovementSlotOverride>[ov(action: MovementSlotAction.skip)],
            now: now,
          );
          expect(resolved, isEmpty);
        },
      );

      test('RETIME changes only this week\'s clock',
        () {
          final resolved = const WeekSlotResolver().resolve(
            templates: <PlannedSlot>[satGym()],
            overrides: <MovementSlotOverride>[
              ov(action: MovementSlotAction.retime, newTime: '20:00'),
            ],
            now: now,
          );
          expect(resolved, hasLength(1));
          expect(resolved.single.time, '20:00');
          expect(resolved.single.dateIso, '2026-08-08');
          expect(resolved.single.isOverride, isTrue);
        },
      );

      test('MOVE lands on the destination day inside this week',
        () {
          final resolved = const WeekSlotResolver().resolve(
            templates: <PlannedSlot>[satGym()],
            overrides: <MovementSlotOverride>[
              ov(
                action: MovementSlotAction.move,
                newDateIso: '2026-08-11',
                newTime: '19:00',
              ),
            ],
            now: now,
          );
          expect(resolved, hasLength(1));
          expect(resolved.single.dateIso, '2026-08-11');
          expect(resolved.single.weekdaySat0, 3);
          expect(resolved.single.time, '19:00');
        },
      );

      test('MOVE outside this week disappears from the board',
        () {
          final resolved = const WeekSlotResolver().resolve(
            templates: <PlannedSlot>[satGym()],
            overrides: <MovementSlotOverride>[
              ov(action: MovementSlotAction.move, newDateIso: '2026-08-16'),
            ],
            now: now,
          );
          expect(resolved, isEmpty);
        },
      );

      test('LIGHT keeps the slot and marks it light',
        () {
          final resolved = const WeekSlotResolver().resolve(
            templates: <PlannedSlot>[satGym()],
            overrides: <MovementSlotOverride>[ov(action: MovementSlotAction.light)],
            now: now,
          );
          expect(resolved.single.isLight, isTrue);
          expect(resolved.single.time, '18:30');
        },
      );
    },
  );
}
