class ReflectionEntry {
  ReflectionEntry({
    required this.date,
    required this.moodScore,
    this.reflectionText,
    this.learnings,
    this.gratitude,
    this.wins,
    this.challenges,
    this.tomorrowFocus,
    this.isPrivate = 0,
    required this.createdAt,
  });

  factory ReflectionEntry.fromMap(Map<String, dynamic> map) {
    return ReflectionEntry(
      date: map['date'] as String,
      moodScore: map['mood_score'] as int? ?? 3,
      reflectionText:
          map['reflection_text'] as String? ?? map['reflectionNote'] as String?,
      learnings: map['learnings'] as String?,
      gratitude: map['gratitude'] as String?,
      wins: map['wins'] as String? ?? map['goodThing'] as String?,
      challenges: map['challenges'] as String?,
      tomorrowFocus: map['tomorrowFocus'] as String?,
      isPrivate: map['isPrivate'] as int? ?? 0,
      createdAt:
          map['createdAt'] as int? ??
          map['timestamp'] as int? ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }
  final String date; // yyyy-MM-dd
  final int moodScore; // 1..5
  final String? reflectionText;
  final String? learnings;
  final String? gratitude;
  final String? wins;
  final String? challenges;
  final String? tomorrowFocus;
  final int isPrivate;
  final int createdAt;

  String? get goodThing => wins ?? gratitude ?? reflectionText;

  Map<String, dynamic> toMap() {
    return {
      'id': date,
      'date': date,
      'mood_score': moodScore,
      'reflection_text': reflectionText,
      // DEPRECATED — do not write: 'reflectionNote'
      'learnings': learnings,
      'gratitude': gratitude,
      'wins': wins,
      // DEPRECATED — do not write: 'goodThing'
      'challenges': challenges,
      'tomorrowFocus': tomorrowFocus,
      // DEPRECATED — do not write: 'timestamp'
      'isPrivate': isPrivate,
      'createdAt': createdAt,
    };
  }
}

class CheckinEntry {
  CheckinEntry({required this.date, required this.mood, this.note});

  factory CheckinEntry.fromMap(Map<String, dynamic> map) {
    return CheckinEntry(
      date: map['date'] as String,
      mood: map['mood'] as String? ?? 'NEUTRAL',
      note: map['note'] as String?,
    );
  }
  final String date; // yyyy-MM-dd
  final String mood; // e.g., 'GOOD', 'BAD', etc.
  final String? note;
}
