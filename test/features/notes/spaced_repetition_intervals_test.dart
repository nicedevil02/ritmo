import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/notes/logic/spaced_repetition_engine.dart';

void main() {
  test('spaced_repetition_intervals_test (V-05)', () {
    final engine = SpacedRepetitionEngine.instance;

    final s1 = engine.calculateNextReview(0, ReviewFeedback.good);
    expect(s1['nextStage'], equals(1));

    final s2 = engine.calculateNextReview(1, ReviewFeedback.good);
    expect(s2['nextStage'], equals(2));

    final s3 = engine.calculateNextReview(2, ReviewFeedback.good);
    expect(s3['nextStage'], equals(3));
  });
}
