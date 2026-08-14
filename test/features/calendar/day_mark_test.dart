import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/calendar/data/day_mark_repository.dart';

void main() {
  group('DayMark Model and Parsing Tests', () {
    test('Correctly maps DayMarkKind to code and parses back', () {
      expect(DayMark.codeOf(DayMarkKind.rest), 'REST');
      expect(DayMark.codeOf(DayMarkKind.travel), 'TRAVEL');
      expect(DayMark.codeOf(DayMarkKind.special), 'SPECIAL');
      expect(DayMark.codeOf(DayMarkKind.normal), 'NORMAL');

      expect(DayMark.parseKind('REST'), DayMarkKind.rest);
      expect(DayMark.parseKind('rest'), DayMarkKind.rest);
      expect(DayMark.parseKind('TRAVEL'), DayMarkKind.travel);
      expect(DayMark.parseKind('travel'), DayMarkKind.travel);
      expect(DayMark.parseKind('SPECIAL'), DayMarkKind.special);
      expect(DayMark.parseKind('special'), DayMarkKind.special);
      expect(DayMark.parseKind('NORMAL'), DayMarkKind.normal);
      expect(DayMark.parseKind(null), DayMarkKind.normal);
      expect(DayMark.parseKind('unknown_value'), DayMarkKind.normal);
    });

    test('DayMark holds dateStr, kind, and optional note', () {
      const mark = DayMark(
        dateStr: '2026-08-14',
        kind: DayMarkKind.rest,
        note: 'سفر به شمال',
      );

      expect(mark.dateStr, '2026-08-14');
      expect(mark.kind, DayMarkKind.rest);
      expect(mark.note, 'سفر به شمال');
    });
  });
}
