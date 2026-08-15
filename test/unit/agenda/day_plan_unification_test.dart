import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/assistant/models/day_plan_models.dart';

void main() {
  group('Phase M2-D: Day Plan Unification & History Freeze (P6 / M2-8..M2-9)', () {
    test('M2-8: DayPlanTemplate.fromMap gracefully parses legacy snake_case and alternate columns', () {
      final legacyMap = {
        'id': 'tpl_legacy_1',
        'title': 'الگوی روزهای پرمشغله',
        'plan_json': jsonEncode([
          {
            'title': 'تمرین صبحگاهی',
            'targetModule': 'sports',
            'start': {'kind': 'clock', 'time': '07:00'},
            'durationSource': 'none',
            'recurrence': 'oneOff',
            'category': 'sports',
          }
        ]),
        'created_at': 1700000000000,
        'updated_at': 1700000500000,
        'last_used_at': 1700001000000,
        'use_count': 5,
      };

      final template = DayPlanTemplate.fromMap(legacyMap);
      expect(template.id, equals('tpl_legacy_1'));
      expect(template.name, equals('الگوی روزهای پرمشغله'));
      expect(template.items, hasLength(1));
      expect(template.items.first.title, equals('تمرین صبحگاهی'));
      expect(template.createdAt, equals(1700000000000));
      expect(template.updatedAt, equals(1700000500000));
      expect(template.lastUsedAt, equals(1700001000000));
      expect(template.useCount, equals(5));
    });

    test('M2-8: DayPlanTemplate.fromMap prioritizes canonical camelCase columns when both exist', () {
      final mixedMap = {
        'id': 'tpl_mixed_1',
        'name': 'نام استاندارد',
        'title': 'عنوان مهجور',
        'itemsJson': jsonEncode([
          {
            'title': 'مطالعه',
            'targetModule': 'routine',
            'start': {'kind': 'clock', 'time': '21:00'},
            'durationSource': 'none',
            'recurrence': 'oneOff',
            'category': 'personal',
          }
        ]),
        'plan_json': '[]',
        'createdAt': 1800000000000,
        'created_at': 1700000000000,
        'updatedAt': 1800000500000,
        'updated_at': 1700000500000,
        'lastUsedAt': 1800001000000,
        'useCount': 10,
      };

      final template = DayPlanTemplate.fromMap(mixedMap);
      expect(template.name, equals('نام استاندارد'));
      expect(template.items, hasLength(1));
      expect(template.items.first.title, equals('مطالعه'));
      expect(template.createdAt, equals(1800000000000));
      expect(template.updatedAt, equals(1800000500000));
      expect(template.lastUsedAt, equals(1800001000000));
      expect(template.useCount, equals(10));
    });

    test('M2-8: DayPlanTemplate.toMap writes ONLY canonical camelCase columns and forbids legacy keys', () {
      final template = DayPlanTemplate(
        id: 'tpl_write_1',
        name: 'برنامه کاری',
        icon: 'briefcase',
        items: [
          DayPlanItemDraft(
            title: 'جلسه بازبینی',
            targetModule: 'task',
            startKind: 'clock',
            startTime: '10:00',
            durationSource: 'none',
            recurrence: 'oneOff',
            category: 'work',
          ),
        ],
        createdAt: 1900000000000,
        updatedAt: 1900000500000,
        lastUsedAt: 1900001000000,
        useCount: 3,
      );

      final map = template.toMap();

      // Canonical columns MUST exist
      expect(map.containsKey('id'), isTrue);
      expect(map.containsKey('name'), isTrue);
      expect(map.containsKey('icon'), isTrue);
      expect(map.containsKey('itemsJson'), isTrue);
      expect(map.containsKey('createdAt'), isTrue);
      expect(map.containsKey('updatedAt'), isTrue);
      expect(map.containsKey('lastUsedAt'), isTrue);
      expect(map.containsKey('useCount'), isTrue);

      // Deprecated / legacy columns MUST NOT be written
      expect(map.containsKey('title'), isFalse, reason: 'Writing to deprecated title column is forbidden');
      expect(map.containsKey('plan_json'), isFalse, reason: 'Writing to deprecated plan_json column is forbidden');
      expect(map.containsKey('created_at'), isFalse, reason: 'Writing to deprecated created_at column is forbidden');
      expect(map.containsKey('updated_at'), isFalse, reason: 'Writing to deprecated updated_at column is forbidden');
      expect(map.containsKey('last_used_at'), isFalse, reason: 'Writing to deprecated last_used_at column is forbidden');
      expect(map.containsKey('use_count'), isFalse, reason: 'Writing to deprecated use_count column is forbidden');
    });
  });
}
