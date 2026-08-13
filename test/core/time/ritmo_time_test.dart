import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/time/ritmo_time.dart';

void main() {
  group('RitmoTime.signedMinuteDiff', () {
    test('same time is zero', () {
      expect(RitmoTime.signedMinuteDiff(600, 600), 0);
    });

    test('simple positive and negative diffs', () {
      expect(RitmoTime.signedMinuteDiff(660, 600), 60);
      expect(RitmoTime.signedMinuteDiff(540, 600), -60);
    });

    test('crosses midnight forward', () {
      // 00:30 در برابر 23:30 ⇒ ۶۰ دقیقه دیرتر، نه ۱۳۸۰ دقیقه زودتر
      expect(RitmoTime.signedMinuteDiff(30, 1410), 60);
    });

    test('crosses midnight backward', () {
      expect(RitmoTime.signedMinuteDiff(1410, 30), -60);
    });

    test('boundary at +/-720', () {
      expect(RitmoTime.signedMinuteDiff(720, 0), 720);
      expect(RitmoTime.signedMinuteDiff(0, 720), -720);
    });
  });

  group('RitmoTime.absMinuteDiff', () {
    test('matches legacy deviationMinutes semantics', () {
      expect(RitmoTime.absMinuteDiff(30, 1410), 60);
      expect(RitmoTime.absMinuteDiff(1410, 30), 60);
      expect(RitmoTime.absMinuteDiff(0, 720), 720);
      expect(RitmoTime.absMinuteDiff(600, 600), 0);
    });
  });
}
