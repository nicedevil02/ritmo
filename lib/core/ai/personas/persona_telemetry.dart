import 'package:ritmo/core/logging/ritmo_logger.dart';

// TODO PSN-48: persist telemetry to a durable store once a retention policy is decided.

/// رکورد ثبت اطلاعات تله‌متری دور پاسخ پرسونا (PSN-48)
class PersonaTelemetryRecord {
  const PersonaTelemetryRecord({
    required this.timestamp,
    required this.personaId,
    this.selectedSkill,
    this.requestedConfidence,
    this.finalConfidence,
    this.validationSeverity,
    this.violatedRuleId,
    this.droppedCommandsCount = 0,
    this.promptMenuLength = 0,
    this.incompleteDomains = const [],
  });

  final DateTime timestamp;
  final String personaId;
  final String? selectedSkill;
  final String? requestedConfidence;
  final String? finalConfidence;
  final String? validationSeverity;
  final String? violatedRuleId;
  final int droppedCommandsCount;
  final int promptMenuLength;
  final List<String> incompleteDomains;

  Map<String, dynamic> toMap() => {
    'timestamp': timestamp.toIso8601String(),
    'personaId': personaId,
    'selectedSkill': selectedSkill,
    'requestedConfidence': requestedConfidence,
    'finalConfidence': finalConfidence,
    'validationSeverity': validationSeverity,
    'violatedRuleId': violatedRuleId,
    'droppedCommandsCount': droppedCommandsCount,
    'promptMenuLength': promptMenuLength,
    'incompleteDomains': incompleteDomains,
  };
}

/// جمع‌کنندهٔ درون‌حافظه تله‌متری پرسونا با بافر حلقوی ۲۰۰ رکورد (PSN-48)
class PersonaTelemetryCollector {
  PersonaTelemetryCollector._();
  static final PersonaTelemetryCollector instance =
      PersonaTelemetryCollector._();

  static const int maxCapacity = 200;
  final List<PersonaTelemetryRecord> _records = [];

  List<PersonaTelemetryRecord> get records => List.unmodifiable(_records);

  int get length => _records.length;

  void record(PersonaTelemetryRecord record) {
    if (_records.length >= maxCapacity) {
      _records.removeAt(0); // Remove oldest
    }
    _records.add(record);

    RitmoLog.info(
      'PersonaTelemetry',
      'Recorded turn for persona=${record.personaId} skill=${record.selectedSkill} conf=${record.finalConfidence} severity=${record.validationSeverity}',
    );
  }

  void clear() {
    _records.clear();
  }
}
