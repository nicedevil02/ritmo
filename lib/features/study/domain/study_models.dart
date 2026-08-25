enum StudyMastery { notStarted, learning, review, mastered }

extension StudyMasteryExtension on StudyMastery {
  String get dbValue {
    switch (this) {
      case StudyMastery.learning:
        return 'LEARNING';
      case StudyMastery.review:
        return 'NEEDS_REVIEW';
      case StudyMastery.mastered:
        return 'MASTERED';
      case StudyMastery.notStarted:
        return 'NOT_STARTED';
    }
  }

  static StudyMastery fromDbValue(String? val) {
    switch (val?.toUpperCase()) {
      case 'LEARNING':
        return StudyMastery.learning;
      case 'NEEDS_REVIEW':
      case 'REVIEW':
        return StudyMastery.review;
      case 'MASTERED':
        return StudyMastery.mastered;
      case 'NOT_STARTED':
      default:
        return StudyMastery.notStarted;
    }
  }
}

enum StudyMode { learn, practice, review }

extension StudyModeExtension on StudyMode {
  String get dbValue {
    switch (this) {
      case StudyMode.practice:
        return 'PRACTICE';
      case StudyMode.review:
        return 'REVIEW';
      case StudyMode.learn:
        return 'LEARN';
    }
  }

  String get labelFa {
    switch (this) {
      case StudyMode.practice:
        return 'تمرین و تست';
      case StudyMode.review:
        return 'مرور مبحث';
      case StudyMode.learn:
        return 'یادگیری';
    }
  }

  static StudyMode fromDbValue(String? val) {
    switch (val?.toUpperCase()) {
      case 'PRACTICE':
      case 'TEST':
        return StudyMode.practice;
      case 'REVIEW':
        return StudyMode.review;
      case 'LEARN':
      default:
        return StudyMode.learn;
    }
  }
}

enum StudyOrigin { user, konkurPreset }

extension StudyOriginExtension on StudyOrigin {
  String get dbValue {
    switch (this) {
      case StudyOrigin.konkurPreset:
        return 'KONKUR_PRESET';
      case StudyOrigin.user:
        return 'USER';
    }
  }

  static StudyOrigin fromDbValue(String? val) {
    return val?.toUpperCase() == 'KONKUR_PRESET'
        ? StudyOrigin.konkurPreset
        : StudyOrigin.user;
  }
}

class StudySubject {
  const StudySubject({
    required this.id,
    required this.name,
    this.emoji,
    this.colorHex,
    this.weeklyTargetMinutes = 0,
    this.origin = StudyOrigin.user,
    this.isArchived = false,
    this.orderIndex = 0,
    this.importanceFactor = 1.0,
    this.examQuestionCount = 0,
    this.subjectGroup = 'GENERAL',
    this.createdAtMs,
    this.updatedAtMs,
  });

  final String id;
  final String name;
  final String? emoji;
  final String? colorHex;
  final int weeklyTargetMinutes;
  final StudyOrigin origin;
  final bool isArchived;
  final int orderIndex;

  final double importanceFactor;
  final int examQuestionCount;
  final String subjectGroup;
  final int? createdAtMs;
  final int? updatedAtMs;

  factory StudySubject.fromMap(Map<String, dynamic> map) {
    return StudySubject(
      id: map['id'] as String,
      name: map['name'] as String,
      emoji: map['emoji'] as String?,
      colorHex: map['colorHex'] as String?,
      weeklyTargetMinutes: map['weeklyTargetMinutes'] as int? ?? 0,
      origin: StudyOriginExtension.fromDbValue(map['origin'] as String?),
      isArchived: (map['isArchived'] as int? ?? 0) == 1,
      orderIndex: map['orderIndex'] as int? ?? 0,
      importanceFactor: (map['importanceFactor'] as num?)?.toDouble() ?? 1.0,
      examQuestionCount: map['examQuestionCount'] as int? ?? 0,
      subjectGroup: map['subjectGroup'] as String? ?? 'GENERAL',
      createdAtMs: map['createdAt'] as int?,
      updatedAtMs: map['updatedAt'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'colorHex': colorHex,
      'weeklyTargetMinutes': weeklyTargetMinutes,
      'origin': origin.dbValue,
      'isArchived': isArchived ? 1 : 0,
      'orderIndex': orderIndex,
      'importanceFactor': importanceFactor,
      'examQuestionCount': examQuestionCount,
      'subjectGroup': subjectGroup,
      'createdAt': createdAtMs ?? nowMs,
      'updatedAt': updatedAtMs ?? nowMs,
    };
  }

  StudySubject copyWith({
    String? id,
    String? name,
    String? emoji,
    String? colorHex,
    int? weeklyTargetMinutes,
    StudyOrigin? origin,
    bool? isArchived,
    int? orderIndex,
    double? importanceFactor,
    int? examQuestionCount,
    String? subjectGroup,
    int? createdAtMs,
    int? updatedAtMs,
  }) {
    return StudySubject(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      colorHex: colorHex ?? this.colorHex,
      weeklyTargetMinutes: weeklyTargetMinutes ?? this.weeklyTargetMinutes,
      origin: origin ?? this.origin,
      isArchived: isArchived ?? this.isArchived,
      orderIndex: orderIndex ?? this.orderIndex,
      importanceFactor: importanceFactor ?? this.importanceFactor,
      examQuestionCount: examQuestionCount ?? this.examQuestionCount,
      subjectGroup: subjectGroup ?? this.subjectGroup,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }
}

class StudyTopic {
  const StudyTopic({
    required this.id,
    required this.subjectId,
    this.parentTopicId,
    required this.name,
    this.mastery = StudyMastery.notStarted,
    this.studyCompletedMinutes = 0,
    this.lastStudiedAtMs,
    this.nextReviewDateIso,
    this.plannedDateIso,
    this.orderIndex = 0,
    this.origin = StudyOrigin.user,
    this.chapter,
    this.reviewCount = 0,
    this.createdAtMs,
    this.updatedAtMs,
  });

  final String id;
  final String subjectId;
  final String? parentTopicId;
  final String name;
  final StudyMastery mastery;
  final int studyCompletedMinutes;
  final int? lastStudiedAtMs;
  final String? nextReviewDateIso;
  final String? plannedDateIso;
  final int orderIndex;
  final StudyOrigin origin;
  final String? chapter;
  final int reviewCount;
  final int? createdAtMs;
  final int? updatedAtMs;

  factory StudyTopic.fromMap(Map<String, dynamic> map) {
    return StudyTopic(
      id: map['id'] as String,
      subjectId: map['subjectId'] as String,
      parentTopicId: map['parentTopicId'] as String?,
      name: map['name'] as String,
      mastery: StudyMasteryExtension.fromDbValue(map['masteryLevel'] as String?),
      studyCompletedMinutes: map['studyCompletedMinutes'] as int? ?? 0,
      lastStudiedAtMs: map['lastStudiedAt'] as int?,
      nextReviewDateIso: map['nextReviewDate'] as String?,
      plannedDateIso: map['plannedDate'] as String?,
      orderIndex: map['orderIndex'] as int? ?? 0,
      origin: StudyOriginExtension.fromDbValue(map['origin'] as String?),
      chapter: map['chapter'] as String?,
      reviewCount: map['reviewCount'] as int? ?? 0,
      createdAtMs: map['createdAt'] as int?,
      updatedAtMs: map['updatedAt'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return {
      'id': id,
      'subjectId': subjectId,
      'parentTopicId': parentTopicId,
      'name': name,
      'masteryLevel': mastery.dbValue,
      'studyCompletedMinutes': studyCompletedMinutes,
      'lastStudiedAt': lastStudiedAtMs,
      'nextReviewDate': nextReviewDateIso,
      'plannedDate': plannedDateIso,
      'orderIndex': orderIndex,
      'origin': origin.dbValue,
      'chapter': chapter,
      'reviewCount': reviewCount,
      'createdAt': createdAtMs ?? nowMs,
      'updatedAt': updatedAtMs ?? nowMs,
    };
  }

  StudyTopic copyWith({
    String? id,
    String? subjectId,
    String? parentTopicId,
    String? name,
    StudyMastery? mastery,
    int? studyCompletedMinutes,
    int? lastStudiedAtMs,
    String? nextReviewDateIso,
    String? plannedDateIso,
    int? orderIndex,
    StudyOrigin? origin,
    String? chapter,
    int? reviewCount,
    int? createdAtMs,
    int? updatedAtMs,
  }) {
    return StudyTopic(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      parentTopicId: parentTopicId ?? this.parentTopicId,
      name: name ?? this.name,
      mastery: mastery ?? this.mastery,
      studyCompletedMinutes: studyCompletedMinutes ?? this.studyCompletedMinutes,
      lastStudiedAtMs: lastStudiedAtMs ?? this.lastStudiedAtMs,
      nextReviewDateIso: nextReviewDateIso ?? this.nextReviewDateIso,
      plannedDateIso: plannedDateIso ?? this.plannedDateIso,
      orderIndex: orderIndex ?? this.orderIndex,
      origin: origin ?? this.origin,
      chapter: chapter ?? this.chapter,
      reviewCount: reviewCount ?? this.reviewCount,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }
}

class StudySession {
  const StudySession({
    required this.id,
    required this.subjectId,
    this.topicId,
    required this.durationMinutes,
    required this.dateIso,
    this.mode = StudyMode.learn,
    this.source = 'MANUAL',
    this.startedAtMs,
    this.endedAtMs,
    this.quality,
    this.note,
    required this.createdAtMs,
  });

  final String id;
  final String subjectId;
  final String? topicId;
  final int durationMinutes;
  final String dateIso;
  final StudyMode mode;
  final String source;
  final int? startedAtMs;
  final int? endedAtMs;
  final int? quality;
  final String? note;
  final int createdAtMs;

  factory StudySession.fromMap(Map<String, dynamic> map) {
    return StudySession(
      id: map['id'] as String,
      subjectId: map['subjectId'] as String? ?? '',
      topicId: map['topicId'] as String?,
      durationMinutes: map['durationMinutes'] as int? ?? 0,
      dateIso: map['dateIso'] as String? ?? '',
      mode: StudyModeExtension.fromDbValue(map['mode'] as String?),
      source: map['source'] as String? ?? 'MANUAL',
      startedAtMs: map['startedAtMs'] as int?,
      endedAtMs: map['endedAtMs'] as int?,
      quality: map['quality'] as int?,
      note: map['note'] as String?,
      createdAtMs: map['createdAt'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subjectId': subjectId,
      'topicId': topicId,
      'durationMinutes': durationMinutes,
      'dateIso': dateIso,
      'mode': mode.dbValue,
      'source': source,
      'startedAtMs': startedAtMs,
      'endedAtMs': endedAtMs,
      'quality': quality,
      'note': note,
      'createdAt': createdAtMs,
    };
  }

  StudySession copyWith({
    String? id,
    String? subjectId,
    String? topicId,
    int? durationMinutes,
    String? dateIso,
    StudyMode? mode,
    String? source,
    int? startedAtMs,
    int? endedAtMs,
    int? quality,
    String? note,
    int? createdAtMs,
  }) {
    return StudySession(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      topicId: topicId ?? this.topicId,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      dateIso: dateIso ?? this.dateIso,
      mode: mode ?? this.mode,
      source: source ?? this.source,
      startedAtMs: startedAtMs ?? this.startedAtMs,
      endedAtMs: endedAtMs ?? this.endedAtMs,
      quality: quality ?? this.quality,
      note: note ?? this.note,
      createdAtMs: createdAtMs ?? this.createdAtMs,
    );
  }
}

class ActiveStudySessionState {
  const ActiveStudySessionState({
    required this.id,
    this.subjectId,
    this.topicId,
    this.mode = StudyMode.learn,
    required this.startedAtMs,
    this.accumulatedSeconds = 0,
    this.isPaused = false,
    this.plannedMinutes,
    required this.createdAtMs,
  });

  final String id;
  final String? subjectId;
  final String? topicId;
  final StudyMode mode;
  final int startedAtMs;
  final int accumulatedSeconds;
  final bool isPaused;
  final int? plannedMinutes;
  final int createdAtMs;

  int elapsedSeconds(int nowMs) {
    if (isPaused) {
      return accumulatedSeconds;
    }
    final runSec = ((nowMs - startedAtMs) / 1000).floor();
    return accumulatedSeconds + (runSec > 0 ? runSec : 0);
  }

  factory ActiveStudySessionState.fromMap(Map<String, dynamic> map) {
    return ActiveStudySessionState(
      id: map['id'] as String? ?? 'singleton',
      subjectId: map['subjectId'] as String?,
      topicId: map['topicId'] as String?,
      mode: StudyModeExtension.fromDbValue(map['mode'] as String?),
      startedAtMs: map['startedAtMs'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      accumulatedSeconds: map['accumulatedSeconds'] as int? ?? 0,
      isPaused: (map['isPaused'] as int? ?? 0) == 1,
      plannedMinutes: map['plannedMinutes'] as int?,
      createdAtMs: map['createdAt'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subjectId': subjectId,
      'topicId': topicId,
      'mode': mode.dbValue,
      'startedAtMs': startedAtMs,
      'accumulatedSeconds': accumulatedSeconds,
      'isPaused': isPaused ? 1 : 0,
      'plannedMinutes': plannedMinutes,
      'createdAt': createdAtMs,
    };
  }

  ActiveStudySessionState copyWith({
    String? id,
    String? subjectId,
    String? topicId,
    StudyMode? mode,
    int? startedAtMs,
    int? accumulatedSeconds,
    bool? isPaused,
    int? plannedMinutes,
    int? createdAtMs,
  }) {
    return ActiveStudySessionState(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      topicId: topicId ?? this.topicId,
      mode: mode ?? this.mode,
      startedAtMs: startedAtMs ?? this.startedAtMs,
      accumulatedSeconds: accumulatedSeconds ?? this.accumulatedSeconds,
      isPaused: isPaused ?? this.isPaused,
      plannedMinutes: plannedMinutes ?? this.plannedMinutes,
      createdAtMs: createdAtMs ?? this.createdAtMs,
    );
  }
}
