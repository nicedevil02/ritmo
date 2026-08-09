import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/features/notes/logic/spaced_repetition_engine.dart';

void main() {
  test('spaced_repetition_test (R-04)', () {
    final engine = SpacedRepetitionEngine.instance;

    // Stage 1 + GOOD -> Stage 2 (3 days)
    final goodResult = engine.calculateNextReview(1, ReviewFeedback.good);
    expect(goodResult['nextStage'], equals(2));

    // Stage 1 + EASY -> Stage 3 (7 days)
    final easyResult = engine.calculateNextReview(1, ReviewFeedback.easy);
    expect(easyResult['nextStage'], equals(3));

    // Stage 4 + FORGOTTEN -> Stage 1 (1 day)
    final forgottenResult = engine.calculateNextReview(4, ReviewFeedback.forgotten);
    expect(forgottenResult['nextStage'], equals(1));
  });
}
