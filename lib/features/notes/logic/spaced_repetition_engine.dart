import 'package:ritmo/core/time/ritmo_clock.dart';
import 'package:ritmo/features/notes/data/notes_repository.dart';
import 'package:ritmo/features/notes/domain/note_models.dart';

enum ReviewFeedback { forgotten, hard, good, easy }

class SpacedRepetitionEngine {
  SpacedRepetitionEngine._();
  static final SpacedRepetitionEngine instance = SpacedRepetitionEngine._();

  static const List<int> _stageIntervalDays = [0, 1, 3, 7, 14, 30, 60, 120];

  /// Calculates next review stage and target DateTime (R-01).
  Map<String, dynamic> calculateNextReview(
    int currentStage,
    ReviewFeedback feedback,
  ) {
    int nextStage = currentStage;
    int daysAdd = 1;

    switch (feedback) {
      case ReviewFeedback.forgotten:
        nextStage = 1;
        daysAdd = 1;
        break;
      case ReviewFeedback.hard:
        nextStage = currentStage;
        final base =
            _stageIntervalDays[currentStage.clamp(
              0,
              _stageIntervalDays.length - 1,
            )];
        daysAdd = (base * 0.8).round().clamp(1, 120);
        break;
      case ReviewFeedback.good:
        nextStage = (currentStage + 1).clamp(1, _stageIntervalDays.length - 1);
        daysAdd = _stageIntervalDays[nextStage];
        break;
      case ReviewFeedback.easy:
        nextStage = (currentStage + 2).clamp(1, _stageIntervalDays.length - 1);
        daysAdd = _stageIntervalDays[nextStage];
        break;
    }

    final nextReviewDt = SystemClock().now().add(Duration(days: daysAdd));
    return {
      'nextStage': nextStage,
      'nextReviewMs': nextReviewDt.millisecondsSinceEpoch,
    };
  }

  Future<void> scheduleNextReview(
    String noteId,
    ReviewFeedback feedback,
  ) async {
    final note = await NotesRepository.instance.getById(noteId);
    if (note == null) return;

    final calc = calculateNextReview(note.reviewStage, feedback);
    await NotesRepository.instance.setReview(
      noteId,
      calc['nextStage'] as int,
      calc['nextReviewMs'] as int,
    );
  }

  Future<List<Note>> listDueReviews() async {
    final nowMs = SystemClock().now().millisecondsSinceEpoch;
    return NotesRepository.instance.listReviewDue(nowMs);
  }
}
