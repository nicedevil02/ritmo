import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/realm/active_realm_resolver.dart';
import 'package:ritmo/features/today/presentation/widgets/dashboard/zone_ritual_sheet.dart';

void main() {
  const workRealmWithExitRitual = RealmData(
    id: 'work_zone',
    name: 'قلمرو کار',
    colorHex: '#3B82F6',
    icon: '💼',
    mode: RealmMode.focus,
    ritualOnExit: ZoneRitualConfig(
      isEnabled: true,
      reviewPendingTasks: true,
      promptNoteForTomorrow: true,
      isDismissible: true,
    ),
  );

  const familyRealmWithEnterRitual = RealmData(
    id: 'family_zone',
    name: 'قلمرو خانواده',
    colorHex: '#10B981',
    icon: '👨‍👩‍👧',
    mode: RealmMode.normal,
    ritualOnEnter: ZoneRitualConfig(
      isEnabled: true,
      reviewPendingTasks: false,
      promptNoteForTomorrow: false,
      isDismissible: true,
    ),
  );

  const plainRealm = RealmData(
    id: 'study_zone',
    name: 'قلمرو مطالعه',
    colorHex: '#8B5CF6',
    icon: '📚',
    mode: RealmMode.focus,
  );

  group('Zone Rituals Domain & Service Tests (F-14)', () {
    test('1. ZoneRitualConfig JSON serialization and RealmData integration', () {
      const config = ZoneRitualConfig(
        isEnabled: true,
        reviewPendingTasks: true,
        promptNoteForTomorrow: false,
        isDismissible: true,
        checklistItems: ['بستن تب‌های مرورگر', 'نوشتن گزارش روزانه'],
      );

      final jsonStr = config.toJson();
      final decoded = ZoneRitualConfig.fromJson(jsonStr);

      expect(decoded, isNotNull);
      expect(decoded!.isEnabled, isTrue);
      expect(decoded.reviewPendingTasks, isTrue);
      expect(decoded.promptNoteForTomorrow, isFalse);
      expect(decoded.checklistItems.length, 2);
      expect(decoded.checklistItems.first, 'بستن تب‌های مرورگر');

      // Test RealmData serialization
      final map = workRealmWithExitRitual.toMap();
      final restored = RealmData.fromMap(map);
      expect(restored.ritualOnExit, isNotNull);
      expect(restored.ritualOnExit!.reviewPendingTasks, isTrue);
    });

    test('2. ZoneRitualService triggers exit ritual on leaving work realm', () {
      const service = ZoneRitualService();

      final pending = service.getPendingRitual(
        previousRealm: workRealmWithExitRitual,
        nextRealm: familyRealmWithEnterRitual,
      );

      expect(pending, isNotNull);
      expect(pending!.isExit, isTrue);
      expect(pending.realm.id, 'work_zone');
      expect(pending.ritual.reviewPendingTasks, isTrue);
    });

    test('3. ZoneRitualService triggers enter ritual if no exit ritual present', () {
      const service = ZoneRitualService();

      final pending = service.getPendingRitual(
        previousRealm: plainRealm,
        nextRealm: familyRealmWithEnterRitual,
      );

      expect(pending, isNotNull);
      expect(pending!.isExit, isFalse);
      expect(pending.realm.id, 'family_zone');
    });

    test('4. ZoneRitualService returns null for transition between plain realms', () {
      const service = ZoneRitualService();

      final pending = service.getPendingRitual(
        previousRealm: plainRealm,
        nextRealm: const RealmData(
          id: 'sport_zone',
          name: 'ورزش',
          colorHex: '#EF4444',
          icon: '🏋️',
          mode: RealmMode.normal,
        ),
      );

      expect(pending, isNull);
    });
  });

  group('ZoneRitualSheet UI Widget Tests (F-14)', () {
    testWidgets('5. Renders Persian title, tasks, and handles skip/complete', (tester) async {
      String? completedNote;
      List<String>? completedDeferredTasks;
      bool wasSkipped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZoneRitualSheet(
              realm: workRealmWithExitRitual,
              ritual: workRealmWithExitRitual.ritualOnExit!,
              isExit: true,
              pendingTasks: const ['ارسال ایمیل به تیم فنی', 'بررسی لاگ سرور'],
              onComplete: (note, deferred) {
                completedNote = note;
                completedDeferredTasks = deferred;
              },
              onSkip: () {
                wasSkipped = true;
              },
            ),
          ),
        ),
      );

      // Verify header and Persian strings
      expect(find.text('آیین پایان «قلمرو کار»'), findsOneWidget);
      expect(find.text('ارسال ایمیل به تیم فنی'), findsOneWidget);
      expect(find.text('بررسی لاگ سرور'), findsOneWidget);
      expect(find.text('رد کردن'), findsOneWidget);
      expect(find.text('پایان گذار'), findsOneWidget);

      // Defer first task to tomorrow
      await tester.tap(find.text('انتقال به فردا').first);
      await tester.pumpAndSettle();

      // Enter a note for tomorrow
      await tester.enterText(
        find.byType(TextField),
        'فردا صبح اول از همه جلسه با مدیر محصول داریم.',
      );
      await tester.pumpAndSettle();

      // Tap Complete Ritual
      await tester.tap(find.text('پایان گذار'));
      await tester.pumpAndSettle();

      expect(completedNote, 'فردا صبح اول از همه جلسه با مدیر محصول داریم.');
      expect(completedDeferredTasks, contains('ارسال ایمیل به تیم فنی'));
      expect(wasSkipped, isFalse);
    });
  });
}
