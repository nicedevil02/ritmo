import 'package:ritmo/core/time/ritmo_clock.dart';
import 'package:ritmo/features/notes/data/experience_repository.dart';
import 'package:ritmo/features/notes/data/notes_repository.dart';
import 'package:ritmo/features/notes/domain/note_models.dart';
import 'package:shamsi_date/shamsi_date.dart';

class ResurfacingCandidate {
  final Experience experience;
  final Note note;
  final double score;

  const ResurfacingCandidate({
    required this.experience,
    required this.note,
    required this.score,
  });
}

class ResurfacingEngine {
  ResurfacingEngine._();
  static final ResurfacingEngine instance = ResurfacingEngine._();

  /// Scores active experiences and picks the top candidate for today (R-02, X-01).
  Future<ResurfacingCandidate?> pickTodayExperienceCandidate({String? activeCategory}) async {
    final activeExps = await ExperienceRepository.instance.listActive();
    if (activeExps.isEmpty) return null;

    final clock = SystemClock();
    final todayDayKey = clock.today().value;
    final nowJalali = Jalali.fromDateTime(clock.now());

    ResurfacingCandidate? bestCandidate;

    for (final exp in activeExps) {
      final note = await NotesRepository.instance.getById(exp.noteId);
      if (note == null || note.status != NoteStatus.active) continue;

      int daysSinceShown = 30;
      if (exp.lastShownAtDayKey != null) {
        try {
          final parts = exp.lastShownAtDayKey!.split('-');
          if (parts.length == 3) {
            final jShown = Jalali(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
            daysSinceShown = nowJalali.toDateTime().difference(jShown.toDateTime()).inDays;
          }
        } catch (_) {}
      }

      double categoryMatchBonus = 0.0;
      if (activeCategory != null && exp.category.code.toUpperCase() == activeCategory.toUpperCase()) {
        categoryMatchBonus = 5.0;
      }

      // Scoring formula: (importance * 3) + (daysSinceShown * 0.5) - (showCount * 1.5) + categoryMatchBonus
      final score = (exp.importance * 3.0) + (daysSinceShown * 0.5) - (exp.showCount * 1.5) + categoryMatchBonus;

      if (bestCandidate == null || score > bestCandidate.score) {
        bestCandidate = ResurfacingCandidate(
          experience: exp,
          note: note,
          score: score,
        );
      }
    }

    if (bestCandidate != null) {
      await ExperienceRepository.instance.recordShown(bestCandidate.experience.noteId, todayDayKey);
    }

    return bestCandidate;
  }
}
