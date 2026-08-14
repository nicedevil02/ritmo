import 'package:flutter/foundation.dart';

class _Unset {
  const _Unset();
}
const Object _unset = _Unset();

enum NoteKind {
  note('NOTE'),
  daily('DAILY'),
  experience('EXPERIENCE'),
  idea('IDEA'),
  decision('DECISION');

  final String value;
  const NoteKind(this.value);

  static NoteKind parse(String? val) {
    if (val == null) return NoteKind.note;
    return NoteKind.values.firstWhere(
      (e) => e.value.toUpperCase() == val.toUpperCase(),
      orElse: () => NoteKind.note,
    );
  }
}

enum NoteStatus {
  active('ACTIVE'),
  archived('ARCHIVED'),
  trashed('TRASHED');

  final String value;
  const NoteStatus(this.value);

  static NoteStatus parse(String? val) {
    if (val == null) return NoteStatus.active;
    return NoteStatus.values.firstWhere(
      (e) => e.value.toUpperCase() == val.toUpperCase(),
      orElse: () => NoteStatus.active,
    );
  }
}

enum ExperienceCategory {
  general('GENERAL', 'عمومی', '🌐'),
  work('WORK', 'کار', '💼'),
  study('STUDY', 'درس و مطالعه', '📚'),
  health('HEALTH', 'سلامت', '🏥'),
  relation('RELATION', 'روابط', '🤝'),
  money('MONEY', 'مالی', '💰'),
  faith('FAITH', 'ایمان و معنویت', '🌙'),
  self('SELF', 'خودشناسی', '🧘');

  final String code;
  final String labelFa;
  final String emoji;
  const ExperienceCategory(this.code, this.labelFa, this.emoji);

  static ExperienceCategory parse(String? val) {
    if (val == null) return ExperienceCategory.general;
    return ExperienceCategory.values.firstWhere(
      (e) => e.code.toUpperCase() == val.toUpperCase(),
      orElse: () => ExperienceCategory.general,
    );
  }
}

@immutable
class Note {
  final String id;
  final String? title;
  final String body;
  final String titleNormalized;
  final String bodyNormalized;
  final NoteKind kind;
  final NoteStatus status;
  final bool isPrivate;
  final bool isPinned;
  final String? dayKey;
  final String? sourceModule;
  final String? sourceEntityId;
  final String? captureContextJson;
  final int wordCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? openedAt;
  final int openCount;
  final DateTime? reviewAt;
  final int reviewStage;
  final DateTime? trashedAt;

  const Note({
    required this.id,
    this.title,
    required this.body,
    required this.titleNormalized,
    required this.bodyNormalized,
    this.kind = NoteKind.note,
    this.status = NoteStatus.active,
    this.isPrivate = false,
    this.isPinned = false,
    this.dayKey,
    this.sourceModule,
    this.sourceEntityId,
    this.captureContextJson,
    required this.wordCount,
    required this.createdAt,
    required this.updatedAt,
    this.openedAt,
    this.openCount = 0,
    this.reviewAt,
    this.reviewStage = 0,
    this.trashedAt,
  });

  Note copyWith({
    String? id,
    Object? title = _unset,
    String? body,
    String? titleNormalized,
    String? bodyNormalized,
    NoteKind? kind,
    NoteStatus? status,
    bool? isPrivate,
    bool? isPinned,
    Object? dayKey = _unset,
    Object? sourceModule = _unset,
    Object? sourceEntityId = _unset,
    Object? captureContextJson = _unset,
    int? wordCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? openedAt = _unset,
    int? openCount,
    Object? reviewAt = _unset,
    int? reviewStage,
    Object? trashedAt = _unset,
  }) {
    return Note(
      id: id ?? this.id,
      title: identical(title, _unset) ? this.title : title as String?,
      body: body ?? this.body,
      titleNormalized: titleNormalized ?? this.titleNormalized,
      bodyNormalized: bodyNormalized ?? this.bodyNormalized,
      kind: kind ?? this.kind,
      status: status ?? this.status,
      isPrivate: isPrivate ?? this.isPrivate,
      isPinned: isPinned ?? this.isPinned,
      dayKey: identical(dayKey, _unset) ? this.dayKey : dayKey as String?,
      sourceModule: identical(sourceModule, _unset) ? this.sourceModule : sourceModule as String?,
      sourceEntityId: identical(sourceEntityId, _unset) ? this.sourceEntityId : sourceEntityId as String?,
      captureContextJson: identical(captureContextJson, _unset) ? this.captureContextJson : captureContextJson as String?,
      wordCount: wordCount ?? this.wordCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      openedAt: identical(openedAt, _unset) ? this.openedAt : openedAt as DateTime?,
      openCount: openCount ?? this.openCount,
      reviewAt: identical(reviewAt, _unset) ? this.reviewAt : reviewAt as DateTime?,
      reviewStage: reviewStage ?? this.reviewStage,
      trashedAt: identical(trashedAt, _unset) ? this.trashedAt : trashedAt as DateTime?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'titleNormalized': titleNormalized,
      'bodyNormalized': bodyNormalized,
      'kind': kind.value,
      'status': status.value,
      'isPrivate': isPrivate ? 1 : 0,
      'isPinned': isPinned ? 1 : 0,
      'dayKey': dayKey,
      'sourceModule': sourceModule,
      'sourceEntityId': sourceEntityId,
      'captureContextJson': captureContextJson,
      'wordCount': wordCount,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'openedAt': openedAt?.millisecondsSinceEpoch,
      'openCount': openCount,
      'reviewAt': reviewAt?.millisecondsSinceEpoch,
      'reviewStage': reviewStage,
      'trashedAt': trashedAt?.millisecondsSinceEpoch,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as String,
      title: map['title'] as String?,
      body: (map['body'] as String?) ?? '',
      titleNormalized: (map['titleNormalized'] as String?) ?? '',
      bodyNormalized: (map['bodyNormalized'] as String?) ?? '',
      kind: NoteKind.parse(map['kind'] as String?),
      status: NoteStatus.parse(map['status'] as String?),
      isPrivate: (map['isPrivate'] as int? ?? 0) == 1,
      isPinned: (map['isPinned'] as int? ?? 0) == 1,
      dayKey: map['dayKey'] as String?,
      sourceModule: map['sourceModule'] as String?,
      sourceEntityId: map['sourceEntityId'] as String?,
      captureContextJson: map['captureContextJson'] as String?,
      wordCount: (map['wordCount'] as int?) ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
      openedAt: map['openedAt'] != null ? DateTime.fromMillisecondsSinceEpoch(map['openedAt'] as int) : null,
      openCount: (map['openCount'] as int?) ?? 0,
      reviewAt: map['reviewAt'] != null ? DateTime.fromMillisecondsSinceEpoch(map['reviewAt'] as int) : null,
      reviewStage: (map['reviewStage'] as int?) ?? 0,
      trashedAt: map['trashedAt'] != null ? DateTime.fromMillisecondsSinceEpoch(map['trashedAt'] as int) : null,
    );
  }
}

@immutable
class NoteLink {
  final String id;
  final String noteId;
  final String linkModule;
  final String linkEntityId;
  final String? linkAction;
  final String relation; // MENTIONS | ABOUT | SPAWNED
  final DateTime createdAt;

  const NoteLink({
    required this.id,
    required this.noteId,
    required this.linkModule,
    required this.linkEntityId,
    this.linkAction,
    this.relation = 'MENTIONS',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'noteId': noteId,
    'linkModule': linkModule,
    'linkEntityId': linkEntityId,
    'linkAction': linkAction,
    'relation': relation,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory NoteLink.fromMap(Map<String, dynamic> map) => NoteLink(
    id: map['id'] as String,
    noteId: map['noteId'] as String,
    linkModule: map['linkModule'] as String,
    linkEntityId: map['linkEntityId'] as String,
    linkAction: map['linkAction'] as String?,
    relation: (map['relation'] as String?) ?? 'MENTIONS',
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
  );
}

@immutable
class NoteTag {
  final String noteId;
  final String tag;
  final String tagNormalized;
  final String source; // USER | AI
  final DateTime createdAt;

  const NoteTag({
    required this.noteId,
    required this.tag,
    required this.tagNormalized,
    this.source = 'USER',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'noteId': noteId,
    'tag': tag,
    'tagNormalized': tagNormalized,
    'source': source,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory NoteTag.fromMap(Map<String, dynamic> map) => NoteTag(
    noteId: map['noteId'] as String,
    tag: map['tag'] as String,
    tagNormalized: map['tagNormalized'] as String,
    source: (map['source'] as String?) ?? 'USER',
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
  );
}

@immutable
class NoteAttachment {
  final String id;
  final String noteId;
  final String kind; // IMAGE | FILE
  final String fileName;
  final String relativePath;
  final int fileSizeBytes;
  final String? mimeType;
  final String? caption;
  final DateTime createdAt;

  const NoteAttachment({
    required this.id,
    required this.noteId,
    this.kind = 'IMAGE',
    required this.fileName,
    required this.relativePath,
    required this.fileSizeBytes,
    this.mimeType,
    this.caption,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'noteId': noteId,
    'kind': kind,
    'fileName': fileName,
    'relativePath': relativePath,
    'fileSizeBytes': fileSizeBytes,
    'mimeType': mimeType,
    'caption': caption,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory NoteAttachment.fromMap(Map<String, dynamic> map) => NoteAttachment(
    id: map['id'] as String,
    noteId: map['noteId'] as String,
    kind: (map['kind'] as String?) ?? 'IMAGE',
    fileName: map['fileName'] as String,
    relativePath: map['relativePath'] as String,
    fileSizeBytes: (map['fileSizeBytes'] as int?) ?? 0,
    mimeType: map['mimeType'] as String?,
    caption: map['caption'] as String?,
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
  );
}

@immutable
class NoteRevision {
  final String id;
  final String noteId;
  final String body;
  final int wordCount;
  final String reason; // AUTOSAVE | AI_EDIT | RESTORE | PRE_DELETE
  final DateTime createdAt;

  const NoteRevision({
    required this.id,
    required this.noteId,
    required this.body,
    required this.wordCount,
    this.reason = 'AUTOSAVE',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'noteId': noteId,
    'body': body,
    'wordCount': wordCount,
    'reason': reason,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory NoteRevision.fromMap(Map<String, dynamic> map) => NoteRevision(
    id: map['id'] as String,
    noteId: map['noteId'] as String,
    body: map['body'] as String,
    wordCount: (map['wordCount'] as int?) ?? 0,
    reason: (map['reason'] as String?) ?? 'AUTOSAVE',
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
  );
}

@immutable
class Experience {
  final String noteId;
  final String lesson;
  final String? contextText;
  final ExperienceCategory category;
  final int importance; // 1..5
  final String? occurredOnDayKey;
  final bool isActive;
  final int showCount;
  final String? lastShownAtDayKey;
  final int acknowledgedCount;

  const Experience({
    required this.noteId,
    required this.lesson,
    this.contextText,
    this.category = ExperienceCategory.general,
    this.importance = 3,
    this.occurredOnDayKey,
    this.isActive = true,
    this.showCount = 0,
    this.lastShownAtDayKey,
    this.acknowledgedCount = 0,
  });

  Experience copyWith({
    String? noteId,
    String? lesson,
    Object? contextText = _unset,
    ExperienceCategory? category,
    int? importance,
    Object? occurredOnDayKey = _unset,
    bool? isActive,
    int? showCount,
    Object? lastShownAtDayKey = _unset,
    int? acknowledgedCount,
  }) {
    return Experience(
      noteId: noteId ?? this.noteId,
      lesson: lesson ?? this.lesson,
      contextText: identical(contextText, _unset) ? this.contextText : contextText as String?,
      category: category ?? this.category,
      importance: importance ?? this.importance,
      occurredOnDayKey: identical(occurredOnDayKey, _unset) ? this.occurredOnDayKey : occurredOnDayKey as String?,
      isActive: isActive ?? this.isActive,
      showCount: showCount ?? this.showCount,
      lastShownAtDayKey: identical(lastShownAtDayKey, _unset) ? this.lastShownAtDayKey : lastShownAtDayKey as String?,
      acknowledgedCount: acknowledgedCount ?? this.acknowledgedCount,
    );
  }

  Map<String, dynamic> toMap() => {
    'noteId': noteId,
    'lesson': lesson,
    'contextText': contextText,
    'category': category.code,
    'importance': importance,
    'occurredOnDayKey': occurredOnDayKey,
    'isActive': isActive ? 1 : 0,
    'showCount': showCount,
    'lastShownAtDayKey': lastShownAtDayKey,
    'acknowledgedCount': acknowledgedCount,
  };

  factory Experience.fromMap(Map<String, dynamic> map) => Experience(
    noteId: map['noteId'] as String,
    lesson: map['lesson'] as String,
    contextText: map['contextText'] as String?,
    category: ExperienceCategory.parse(map['category'] as String?),
    importance: (map['importance'] as int?) ?? 3,
    occurredOnDayKey: map['occurredOnDayKey'] as String?,
    isActive: (map['isActive'] as int? ?? 1) == 1,
    showCount: (map['showCount'] as int?) ?? 0,
    lastShownAtDayKey: map['lastShownAtDayKey'] as String?,
    acknowledgedCount: (map['acknowledgedCount'] as int?) ?? 0,
  );
}
