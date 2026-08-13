import 'package:ritmo/core/time/ritmo_clock.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/notes/data/experience_repository.dart';
import 'package:ritmo/features/notes/domain/note_models.dart';
import 'package:shamsi_date/shamsi_date.dart';

class ResurfacingCandidate {
  final Experience experience;
  final Note note;
  final double score;
  final String reasonFa;

  const ResurfacingCandidate({
    required this.experience,
    required this.note,
    required this.score,
    required this.reasonFa,
  });
}

class ResurfacingEngine {
  ResurfacingEngine._();
  static final ResurfacingEngine instance = ResurfacingEngine._();

  /// Scores active experiences and picks the top candidate for today in a single query (R-02, X-01).
  Future<ResurfacingCandidate?> pickTodayExperienceCandidate({String? activeCategory}) async {
    final activePairs = await ExperienceRepository.instance.listActiveWithNotes();
    if (activePairs.isEmpty) return null;

    final clock = SystemClock();
    final todayDayKey = clock.today().value;
    final nowJalali = Jalali.fromDateTime(clock.now());

    ResurfacingCandidate? bestCandidate;

    for (final pair in activePairs) {
      final exp = pair.experience;
      final note = pair.note;

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

      // Positive boost for acknowledged count (proves usefulness)
      final ackBonus = (exp.acknowledgedCount * 0.5).clamp(0.0, 3.0);

      // Scoring formula: (importance * 3) + (daysSinceShown * 0.5) - (showCount * 1.5) + categoryMatchBonus + ackBonus
      final score = (exp.importance * 3.0) + (daysSinceShown * 0.5) - (exp.showCount * 1.5) + categoryMatchBonus + ackBonus;

      final reasonParts = <String>[
        'اهمیت ${PersianDigits.convert(exp.importance.toString())} ستاره',
        if (daysSinceShown >= 30) 'مدت‌هاست مرور نشده' else '${PersianDigits.convert(daysSinceShown.toString())} روز از آخرین نمایش',
        if (categoryMatchBonus > 0) 'متناسب با زمینه فعلی (${exp.category.labelFa})',
      ];

      if (bestCandidate == null || score > bestCandidate.score) {
        bestCandidate = ResurfacingCandidate(
          experience: exp,
          note: note,
          score: score,
          reasonFa: reasonParts.join(' • '),
        );
      }
    }

    if (bestCandidate != null) {
      await ExperienceRepository.instance.recordShown(bestCandidate.experience.noteId, todayDayKey);
    }

    return bestCandidate;
  }
}
