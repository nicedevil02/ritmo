import 'package:flutter/foundation.dart';

/// وضعیت مرحله در تایم‌لاین ایجنت
enum AgentStepStatus {
  pending,
  running,
  success,
  failed,
  cancelled,
}

/// مدل یک گام یا فعالیت در تایم‌لاین ایجنت
class AgentStep {
  final String id;
  final String titleFa;
  final String? descriptionFa;
  final String? toolName;
  final AgentStepStatus status;
  final DateTime startTime;
  final DateTime? endTime;
  final dynamic resultData;
  final String? errorMessage;

  const AgentStep({
    required this.id,
    required this.titleFa,
    this.descriptionFa,
    this.toolName,
    this.status = AgentStepStatus.pending,
    required this.startTime,
    this.endTime,
    this.resultData,
    this.errorMessage,
  });

  AgentStep copyWith({
    String? titleFa,
    String? descriptionFa,
    AgentStepStatus? status,
    DateTime? endTime,
    dynamic resultData,
    String? errorMessage,
  }) {
    return AgentStep(
      id: id,
      titleFa: titleFa ?? this.titleFa,
      descriptionFa: descriptionFa ?? this.descriptionFa,
      toolName: toolName,
      status: status ?? this.status,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      resultData: resultData ?? this.resultData,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// رویدادهای زنده ساطع‌شده از چرخه اجرای ایجنت
abstract class AgentEvent {
  const AgentEvent();
}

/// وضعیت کلی ایجنت تغییر کرده است
class AgentStatusChangedEvent extends AgentEvent {
  final String statusTextFa;
  final bool isWorking;
  final String? currentToolName;

  const AgentStatusChangedEvent({
    required this.statusTextFa,
    required this.isWorking,
    this.currentToolName,
  });
}

/// یک گام جدید شروع شد
class AgentStepStartedEvent extends AgentEvent {
  final AgentStep step;
  const AgentStepStartedEvent(this.step);
}

/// یک گام به اتمام رسید
class AgentStepCompletedEvent extends AgentEvent {
  final AgentStep step;
  const AgentStepCompletedEvent(this.step);
}

/// یک چانک متنی استریم شد
class AgentTokenStreamEvent extends AgentEvent {
  final String delta;
  final String accumulated;
  const AgentTokenStreamEvent({required this.delta, required this.accumulated});
}

/// اتمام کامل فرآیند ایجنت
class AgentCompletedEvent extends AgentEvent {
  final String finalAnswer;
  final List<AgentStep> steps;
  final Map<String, dynamic>? interactiveAction;

  const AgentCompletedEvent({
    required this.finalAnswer,
    required this.steps,
    this.interactiveAction,
  });
}

/// وقوع خطا در اجرای ایجنت
class AgentErrorEvent extends AgentEvent {
  final String errorMessageFa;
  const AgentErrorEvent(this.errorMessageFa);
}
