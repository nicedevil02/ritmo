import 'package:ritmo/core/ai/brief/domain_brief.dart';
import 'package:ritmo/core/analytics/notes_engine.dart';

/// SQL visibility filter clause ensuring cycle notes and private notes never leak to AI briefs (§0.2, A-09).
const String kNotesAiVisibilityClause = "(sourceModule IS NULL OR sourceModule != 'cycle') AND isPrivate = 0";

class NotesBrief implements DomainBrief {
  NotesBrief({
    required this.sampleSize,
    required this.computedAt,
    required this.totalActive,
    required this.createdThisWeek,
    required this.writingDayStreak,
    required this.topTags,
    required this.orphanCount,
    required this.reviewDueCount,
    required this.experienceCount,
    required this.experienceActiveCount,
    this.experienceOfTheDayLesson,
    this.recentTitles = const [],
    this.resurfacedCandidate,
  });

  @override
  final String domainId = 'notes';

  @override
  final int sampleSize;

  @override
  final DateTime computedAt;

  final int totalActive;
  final int createdThisWeek;
  final int writingDayStreak;
  final List<String> topTags;
  final int orphanCount;
  final int reviewDueCount;
  final int experienceCount;
  final int experienceActiveCount;
  final String? experienceOfTheDayLesson;
  final List<String> recentTitles;
  final String? resurfacedCandidate;

  @override
  BriefConfidence get confidence {
    if (sampleSize < 3) return BriefConfidence.none;
    if (sampleSize < 7) return BriefConfidence.low;
    if (sampleSize < 20) return BriefConfidence.medium;
    return BriefConfidence.high;
  }

  @override
  List<String> get fieldNames => [
    'notes.totalActive',
    'notes.createdThisWeek',
    'notes.writingDayStreak',
    'notes.topTags',
    'notes.orphanCount',
    'notes.reviewDueCount',
    'notes.experienceCount',
    'notes.experienceActiveCount',
    'notes.experienceOfTheDayLesson',
    'notes.recentTitles',
    'notes.resurfacedCandidate',
  ];

  @override
  Map<String, Object?> toPromptJson() {
    return {
      'totalActive': totalActive,
      'createdThisWeek': createdThisWeek,
      'writingDayStreak': writingDayStreak,
      'topTags': topTags,
      'orphanCount': orphanCount,
      'reviewDueCount': reviewDueCount,
      'experienceCount': experienceCount,
      'experienceActiveCount': experienceActiveCount,
      'experienceOfTheDayLesson': experienceOfTheDayLesson,
      'recentTitles': recentTitles,
      'resurfacedCandidate': resurfacedCandidate,
      'confidence': confidence.name,
    }..removeWhere((key, value) => value == null);
  }

  factory NotesBrief.fromEngine(NotesEngineOutput out, {
    String? experienceOfTheDayLesson,
    List<String> recentTitles = const [],
  }) {
    return NotesBrief(
      sampleSize: out.sampleSize,
      computedAt: DateTime.now(),
      totalActive: out.totalActive,
      createdThisWeek: out.createdThisWeek,
      writingDayStreak: out.writingDayStreak,
      topTags: out.topTags,
      orphanCount: out.orphanCount,
      reviewDueCount: out.reviewDueCount,
      experienceCount: out.experienceCount,
      experienceActiveCount: out.experienceActiveCount,
      experienceOfTheDayLesson: experienceOfTheDayLesson,
      recentTitles: recentTitles,
      resurfacedCandidate: out.resurfacedToday,
    );
  }
}
