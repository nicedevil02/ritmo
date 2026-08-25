import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';

enum CycleConfirmationKind { startDue, startOverdue, endDue, bleedingProlonged }

enum CycleConfirmationAnswer {
  startedToday,
  startedOnOtherDate,
  notStartedYet,
  endedToday,
  endedOnOtherDate,
  stillOngoing,
  snoozed,
  dismissed,
}

class CycleConfirmationRequest {
  const CycleConfirmationRequest({
    required this.id,
    required this.kind,
    required this.targetDate,
    required this.askCount,
    this.answer,
    this.answeredAt,
    this.lastAskedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final CycleConfirmationKind kind;
  final DateTime targetDate;
  final int askCount;
  final CycleConfirmationAnswer? answer;
  final DateTime? answeredAt;
  final DateTime? lastAskedAt;
  final int? createdAt;
  final int? updatedAt;

  bool get isAnswered => answer != null;

  static String buildId(CycleConfirmationKind kind, DateTime targetDate) =>
      '${kind.name}_${CycleDateContract.toDayKey(targetDate)}';

  Map<String, dynamic> toMap() {
    final nowMs = CycleClock.nowMillisecondsSinceEpoch;
    return {
      'id': id,
      'kind': kind.name,
      'targetDate': CycleDateContract.toDayKey(targetDate),
      'answer': answer?.name,
      'answeredAt': answeredAt?.millisecondsSinceEpoch,
      'askCount': askCount,
      'lastAskedAt': lastAskedAt?.millisecondsSinceEpoch,
      'createdAt': createdAt ?? nowMs,
      'updatedAt': updatedAt ?? nowMs,
    };
  }

  factory CycleConfirmationRequest.fromMap(Map<String, dynamic> map) {
    final kindStr = map['kind']?.toString() ?? 'startDue';
    final kind = CycleConfirmationKind.values.firstWhere(
      (k) => k.name == kindStr,
      orElse: () => CycleConfirmationKind.startDue,
    );

    final answerStr = map['answer']?.toString();
    final answer = answerStr != null
        ? CycleConfirmationAnswer.values.firstWhere(
            (a) => a.name == answerStr,
            orElse: () => CycleConfirmationAnswer.dismissed,
          )
        : null;

    final targetRaw = map['targetDate']?.toString();
    final targetDate =
        CycleDateContract.parseDayKey(targetRaw) ?? CycleClock.now;

    final answeredAtMs = map['answeredAt'] is int
        ? map['answeredAt'] as int
        : int.tryParse(map['answeredAt']?.toString() ?? '');
    final lastAskedAtMs = map['lastAskedAt'] is int
        ? map['lastAskedAt'] as int
        : int.tryParse(map['lastAskedAt']?.toString() ?? '');
    final createdAtMs = map['createdAt'] is int
        ? map['createdAt'] as int
        : int.tryParse(map['createdAt']?.toString() ?? '');
    final updatedAtMs = map['updatedAt'] is int
        ? map['updatedAt'] as int
        : int.tryParse(map['updatedAt']?.toString() ?? '');

    return CycleConfirmationRequest(
      id: map['id']?.toString() ?? buildId(kind, targetDate),
      kind: kind,
      targetDate: targetDate,
      askCount:
          (map['askCount'] is int
              ? map['askCount'] as int
              : int.tryParse(map['askCount']?.toString() ?? '')) ??
          0,
      answer: answer,
      answeredAt: answeredAtMs != null
          ? DateTime.fromMillisecondsSinceEpoch(answeredAtMs)
          : null,
      lastAskedAt: lastAskedAtMs != null
          ? DateTime.fromMillisecondsSinceEpoch(lastAskedAtMs)
          : null,
      createdAt: createdAtMs,
      updatedAt: updatedAtMs,
    );
  }
}
