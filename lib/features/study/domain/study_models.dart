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

enum StudyOrigin { user, konkurPreset, konkurCustom }

extension StudyOriginExtension on StudyOrigin {
  String get dbValue {
    switch (this) {
      case StudyOrigin.konkurPreset:
        return 'KONKUR_PRESET';
      case StudyOrigin.konkurCustom:
        return 'KONKUR_CUSTOM';
      case StudyOrigin.user:
        return 'USER';
    }
  }

  static StudyOrigin fromDbValue(String? val) {
    switch (val?.toUpperCase()) {
      case 'KONKUR_PRESET':
      case 'PRESET':
      case 'KONKUR':
        return StudyOrigin.konkurPreset;
      case 'KONKUR_CUSTOM':
        return StudyOrigin.konkurCustom;
      case 'USER':
      default:
        return StudyOrigin.user;
    }
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

  Map<String, dynamic> toMap({int? nowMsOverride}) {
    final nowMs = nowMsOverride ?? DateTime.now().millisecondsSinceEpoch;
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
      'updatedAt': nowMs,
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

  Map<String, dynamic> toMap({int? nowMsOverride}) {
    final nowMs = nowMsOverride ?? DateTime.now().millisecondsSinceEpoch;
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
      'updatedAt': nowMs,
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

enum DeadlineType { exam, assignment, project, quiz }

extension DeadlineTypeExtension on DeadlineType {
  String get dbValue {
    switch (this) {
      case DeadlineType.exam:
        return 'EXAM';
      case DeadlineType.assignment:
        return 'ASSIGNMENT';
      case DeadlineType.project:
        return 'PROJECT';
      case DeadlineType.quiz:
        return 'QUIZ';
    }
  }

  String get labelFa {
    switch (this) {
      case DeadlineType.exam:
        return 'امتحان';
      case DeadlineType.assignment:
        return 'تکلیف / تمرین';
      case DeadlineType.project:
        return 'پروژه تحویلی';
      case DeadlineType.quiz:
        return 'کوییز / پرسش';
    }
  }

  static DeadlineType fromDbValue(String? val) {
    switch (val?.toUpperCase()) {
      case 'ASSIGNMENT':
      case 'HOMEWORK':
        return DeadlineType.assignment;
      case 'PROJECT':
        return DeadlineType.project;
      case 'QUIZ':
        return DeadlineType.quiz;
      case 'EXAM':
      default:
        return DeadlineType.exam;
    }
  }
}

enum DeadlinePriority { high, medium, low }

extension DeadlinePriorityExtension on DeadlinePriority {
  String get dbValue {
    switch (this) {
      case DeadlinePriority.high:
        return 'HIGH';
      case DeadlinePriority.medium:
        return 'MEDIUM';
      case DeadlinePriority.low:
        return 'LOW';
    }
  }

  String get labelFa {
    switch (this) {
      case DeadlinePriority.high:
        return 'مهم و فوری';
      case DeadlinePriority.medium:
        return 'عادی';
      case DeadlinePriority.low:
        return 'کم‌اهمیت';
    }
  }

  static DeadlinePriority fromDbValue(String? val) {
    switch (val?.toUpperCase()) {
      case 'HIGH':
        return DeadlinePriority.high;
      case 'LOW':
        return DeadlinePriority.low;
      case 'MEDIUM':
      default:
        return DeadlinePriority.medium;
    }
  }
}

class StudyDeadline {
  const StudyDeadline({
    required this.id,
    this.subjectId,
    required this.title,
    this.deadlineType = DeadlineType.exam,
    required this.dueDateIso,
    this.dueTime,
    this.priority = DeadlinePriority.medium,
    this.isCompleted = false,
    this.weight = 1.0,
    this.note,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  final String id;
  final String? subjectId;
  final String title;
  final DeadlineType deadlineType;
  final String dueDateIso; // 'YYYY-MM-DD'
  final String? dueTime;   // 'HH:mm'
  final DeadlinePriority priority;
  final bool isCompleted;
  final double weight;
  final String? note;
  final int createdAtMs;
  final int updatedAtMs;

  int daysRemaining(DateTime today) {
    try {
      final parts = dueDateIso.split('-');
      final due = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      final current = DateTime(today.year, today.month, today.day);
      return due.difference(current).inDays;
    } catch (_) {
      return 0;
    }
  }

  bool isOverdue(DateTime today) => daysRemaining(today) < 0 && !isCompleted;
  bool isToday(DateTime today) => daysRemaining(today) == 0 && !isCompleted;
  bool isUpcoming(DateTime today, {int days = 14}) {
    final diff = daysRemaining(today);
    return diff >= 0 && diff <= days && !isCompleted;
  }

  factory StudyDeadline.fromMap(Map<String, dynamic> map) {
    return StudyDeadline(
      id: map['id'] as String,
      subjectId: map['subjectId'] as String?,
      title: map['title'] as String? ?? 'بدون عنوان',
      deadlineType: DeadlineTypeExtension.fromDbValue(map['deadlineType'] as String?),
      dueDateIso: map['dueDateIso'] as String? ?? '',
      dueTime: map['dueTime'] as String?,
      priority: DeadlinePriorityExtension.fromDbValue(map['priority'] as String?),
      isCompleted: (map['isCompleted'] as int? ?? 0) == 1,
      weight: (map['weight'] as num?)?.toDouble() ?? 1.0,
      note: map['note'] as String?,
      createdAtMs: map['createdAt'] as int? ?? 0,
      updatedAtMs: map['updatedAt'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap({int? nowMsOverride}) {
    final nowMs = nowMsOverride ?? DateTime.now().millisecondsSinceEpoch;
    return {
      'id': id,
      'subjectId': subjectId,
      'title': title,
      'deadlineType': deadlineType.dbValue,
      'dueDateIso': dueDateIso,
      'dueTime': dueTime,
      'priority': priority.dbValue,
      'isCompleted': isCompleted ? 1 : 0,
      'weight': weight,
      'note': note,
      'createdAt': createdAtMs > 0 ? createdAtMs : nowMs,
      'updatedAt': nowMs,
    };
  }

  StudyDeadline copyWith({
    String? id,
    String? subjectId,
    String? title,
    DeadlineType? deadlineType,
    String? dueDateIso,
    String? dueTime,
    DeadlinePriority? priority,
    bool? isCompleted,
    double? weight,
    String? note,
    int? createdAtMs,
    int? updatedAtMs,
  }) {
    return StudyDeadline(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      title: title ?? this.title,
      deadlineType: deadlineType ?? this.deadlineType,
      dueDateIso: dueDateIso ?? this.dueDateIso,
      dueTime: dueTime ?? this.dueTime,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      weight: weight ?? this.weight,
      note: note ?? this.note,
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
    this.testsTotal = 0,
    this.testsCorrect = 0,
    this.testsWrong = 0,
    this.testsEmpty = 0,
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
  final int testsTotal;
  final int testsCorrect;
  final int testsWrong;
  final int testsEmpty;
  final int createdAtMs;

  bool get hasTestResults => testsTotal > 0;

  double get accuracyPercentage {
    if (testsTotal <= 0) return 0.0;
    return (testsCorrect / testsTotal) * 100.0;
  }

  double get konkurPercentage {
    if (testsTotal <= 0) return 0.0;
    return ((testsCorrect * 3 - testsWrong) / (testsTotal * 3)) * 100.0;
  }

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
      testsTotal: map['testsTotal'] as int? ?? 0,
      testsCorrect: map['testsCorrect'] as int? ?? 0,
      testsWrong: map['testsWrong'] as int? ?? 0,
      testsEmpty: map['testsEmpty'] as int? ?? 0,
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
      'testsTotal': testsTotal,
      'testsCorrect': testsCorrect,
      'testsWrong': testsWrong,
      'testsEmpty': testsEmpty,
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
    int? testsTotal,
    int? testsCorrect,
    int? testsWrong,
    int? testsEmpty,
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
      testsTotal: testsTotal ?? this.testsTotal,
      testsCorrect: testsCorrect ?? this.testsCorrect,
      testsWrong: testsWrong ?? this.testsWrong,
      testsEmpty: testsEmpty ?? this.testsEmpty,
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
    this.pomodoroPhase = 'FOCUS',
    this.pomodoroCycle = 1,
    this.targetSeconds = 1500,
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
  final String pomodoroPhase; // 'FOCUS' or 'BREAK'
  final int pomodoroCycle;
  final int targetSeconds;
  final int createdAtMs;

  bool get isPomodoro => targetSeconds > 0;
  bool get isBreak => pomodoroPhase == 'BREAK';

  int elapsedSeconds(int nowMs) {
    if (isPaused) {
      return accumulatedSeconds;
    }
    final runSec = ((nowMs - startedAtMs) / 1000).floor();
    return accumulatedSeconds + (runSec > 0 ? runSec : 0);
  }

  int phaseElapsedSeconds(int nowMs) {
    if (isPaused) {
      return 0;
    }
    final runSec = ((nowMs - startedAtMs) / 1000).floor();
    return runSec > 0 ? runSec : 0;
  }

  int remainingSeconds(int nowMs) {
    if (targetSeconds <= 0) return 0;
    final phaseElapsed = phaseElapsedSeconds(nowMs);
    final rem = targetSeconds - phaseElapsed;
    return rem > 0 ? rem : 0;
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
      pomodoroPhase: map['pomodoroPhase'] as String? ?? 'FOCUS',
      pomodoroCycle: map['pomodoroCycle'] as int? ?? 1,
      targetSeconds: map['targetSeconds'] as int? ?? 1500,
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
      'pomodoroPhase': pomodoroPhase,
      'pomodoroCycle': pomodoroCycle,
      'targetSeconds': targetSeconds,
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
    String? pomodoroPhase,
    int? pomodoroCycle,
    int? targetSeconds,
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
      pomodoroPhase: pomodoroPhase ?? this.pomodoroPhase,
      pomodoroCycle: pomodoroCycle ?? this.pomodoroCycle,
      targetSeconds: targetSeconds ?? this.targetSeconds,
      createdAtMs: createdAtMs ?? this.createdAtMs,
    );
  }
}
