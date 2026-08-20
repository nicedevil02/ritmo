import 'package:ritmo/core/utils/persian_text.dart';
import 'package:ritmo/core/utils/ritmo_id_factory.dart';

/// SimpleTask represents a lightweight task.
/// Note: Recurrence belongs to routines; no repeat rules exist in simple tasks.
class SimpleTask {
  final String id;
  final String title;
  final String? note;
  final bool isDone;
  final DateTime? doneAt;
  final String? dueDate; // 'YYYY-MM-DD'
  final String? dueTime; // 'HH:mm'
  final int? reminderAtMs;
  final String? reminderId;
  final String? linkedRoutineId;
  final int orderIndex;
  final String origin; // 'SIMPLE' or 'PROMOTED'
  final bool isImportant;
  final DateTime? importantAt;
  final DateTime? addedToMyDayAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SimpleTask({
    required this.id,
    required this.title,
    this.note,
    this.isDone = false,
    this.doneAt,
    this.dueDate,
    this.dueTime,
    this.reminderAtMs,
    this.reminderId,
    this.linkedRoutineId,
    this.orderIndex = 0,
    this.origin = 'SIMPLE',
    this.isImportant = false,
    this.importantAt,
    this.addedToMyDayAt,
    required this.createdAt,
    required this.updatedAt,
  });

  static String generateId() => RitmoIdFactory.task();

  bool get isSomeday => dueDate == null;
  bool get isInMyDay => addedToMyDayAt != null;

  factory SimpleTask.fromMap(Map<String, dynamic> m) {
    return SimpleTask(
      id: m['id'] as String,
      title: m['title'] as String,
      note: m['note'] as String?,
      isDone: (m['isDone'] as int? ?? 0) == 1,
      doneAt: m['doneAt'] != null ? DateTime.fromMillisecondsSinceEpoch(m['doneAt'] as int) : null,
      dueDate: m['dueDate'] as String?,
      dueTime: m['dueTime'] as String?,
      reminderAtMs: m['reminderAtMs'] as int?,
      reminderId: m['reminderId'] as String?,
      linkedRoutineId: m['linkedRoutineId'] as String?,
      orderIndex: m['orderIndex'] as int? ?? 0,
      origin: m['origin'] as String? ?? 'SIMPLE',
      isImportant: (m['isImportant'] as int? ?? 0) == 1,
      importantAt: m['importantAt'] != null ? DateTime.fromMillisecondsSinceEpoch(m['importantAt'] as int) : null,
      addedToMyDayAt: m['addedToMyDayAt'] != null ? DateTime.fromMillisecondsSinceEpoch(m['addedToMyDayAt'] as int) : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(m['updatedAt'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'titleNormalized': normalizeFa(title),
      'note': note,
      'isDone': isDone ? 1 : 0,
      'doneAt': doneAt?.millisecondsSinceEpoch,
      'dueDate': dueDate,
      'dueTime': dueTime,
      'reminderAtMs': reminderAtMs,
      'reminderId': reminderId,
      'linkedRoutineId': linkedRoutineId,
      'orderIndex': orderIndex,
      'origin': origin,
      'isImportant': isImportant ? 1 : 0,
      'importantAt': importantAt?.millisecondsSinceEpoch,
      'addedToMyDayAt': addedToMyDayAt?.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  SimpleTask copyWith({
    String? id,
    String? title,
    Object? note = _unset,
    bool? isDone,
    Object? doneAt = _unset,
    Object? dueDate = _unset,
    Object? dueTime = _unset,
    Object? reminderAtMs = _unset,
    Object? reminderId = _unset,
    Object? linkedRoutineId = _unset,
    int? orderIndex,
    String? origin,
    bool? isImportant,
    bool clearImportantAt = false,
    Object? importantAt = _unset,
    bool clearAddedToMyDayAt = false,
    Object? addedToMyDayAt = _unset,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SimpleTask(
      id: id ?? this.id,
      title: title ?? this.title,
      note: identical(note, _unset) ? this.note : note as String?,
      isDone: isDone ?? this.isDone,
      doneAt: identical(doneAt, _unset) ? this.doneAt : doneAt as DateTime?,
      dueDate: identical(dueDate, _unset) ? this.dueDate : dueDate as String?,
      dueTime: identical(dueTime, _unset) ? this.dueTime : dueTime as String?,
      reminderAtMs: identical(reminderAtMs, _unset) ? this.reminderAtMs : reminderAtMs as int?,
      reminderId: identical(reminderId, _unset) ? this.reminderId : reminderId as String?,
      linkedRoutineId: identical(linkedRoutineId, _unset) ? this.linkedRoutineId : linkedRoutineId as String?,
      orderIndex: orderIndex ?? this.orderIndex,
      origin: origin ?? this.origin,
      isImportant: isImportant ?? this.isImportant,
      importantAt: clearImportantAt
          ? null
          : (identical(importantAt, _unset) ? this.importantAt : importantAt as DateTime?),
      addedToMyDayAt: clearAddedToMyDayAt
          ? null
          : (identical(addedToMyDayAt, _unset) ? this.addedToMyDayAt : addedToMyDayAt as DateTime?),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class _Unset {
  const _Unset();
}

const Object _unset = _Unset();
