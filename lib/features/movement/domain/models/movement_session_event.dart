import 'dart:convert';

/// نوع رویداد جلسهٔ زنده
enum MovementSessionEventType {
  start,
  pause,
  resume,
  lap,
  count,
  distance,
  intensity,
  note,
  goalChange,
  finish,
  abandon;

  static MovementSessionEventType fromString(String val) {
    return MovementSessionEventType.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => MovementSessionEventType.note,
    );
  }
}

/// مدل داده‌ای رویداد ثبت‌شدهٔ جلسهٔ زنده
class MovementSessionEvent {
  const MovementSessionEvent({
    required this.id,
    required this.sessionId,
    required this.type,
    this.payloadJson,
    required this.at,
  });

  final String id;
  final String sessionId;
  final MovementSessionEventType type;
  final String? payloadJson;
  final DateTime at;

  Map<String, dynamic>? get payloadMap {
    if (payloadJson == null || payloadJson!.isEmpty) return null;
    try {
      return jsonDecode(payloadJson!) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  MovementSessionEvent copyWith({
    String? id,
    String? sessionId,
    MovementSessionEventType? type,
    String? payloadJson,
    DateTime? at,
  }) {
    return MovementSessionEvent(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      type: type ?? this.type,
      payloadJson: payloadJson ?? this.payloadJson,
      at: at ?? this.at,
    );
  }

  factory MovementSessionEvent.fromMap(Map<String, dynamic> map) {
    return MovementSessionEvent(
      id: map['id'] as String,
      sessionId: map['sessionId'] as String,
      type: MovementSessionEventType.fromString(
        map['type'] as String? ?? 'note',
      ),
      payloadJson: map['payloadJson'] as String?,
      at: DateTime.tryParse(map['at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sessionId': sessionId,
      'type': type.name,
      'payloadJson': payloadJson,
      'at': at.toUtc().toIso8601String(),
    };
  }
}
