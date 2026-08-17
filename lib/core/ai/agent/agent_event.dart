import 'package:ritmo/core/ai/agent/agent_policy_gate.dart';

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

/// نوبت جدید حلقه ReAct شروع شد (برای تایم‌لاین فاز ۶)
class AgentTurnStartedEvent extends AgentEvent {
  final int turn;
  final int maxTurns;

  const AgentTurnStartedEvent({required this.turn, required this.maxTurns});
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

/// حلقه متوقف شده و منتظر تایید کاربر است (فاز ۳ · P3-2)
///
/// مصرف‌کننده باید کارت تایید را نشان دهد و پاسخ کاربر را با
/// AgentConfirmationBroker.instance.approve/reject برگرداند؛ وگرنه حلقه تا
/// تایم‌اوت معلق می‌ماند و عملیات انجام نمی‌شود.
class AgentAwaitingConfirmationEvent extends AgentEvent {
  final AgentConfirmationRequest request;
  const AgentAwaitingConfirmationEvent(this.request);
}

/// کاربر تایید یا رد کرد و حلقه ادامه یافت
class AgentConfirmationResolvedEvent extends AgentEvent {
  final String requestId;
  final String toolName;
  final bool approved;
  final String? reasonFa;

  const AgentConfirmationResolvedEvent({
    required this.requestId,
    required this.toolName,
    required this.approved,
    this.reasonFa,
  });
}

/// مهلت تایید به پایان رسید و اقدامی انجام نشد
class AgentConfirmationTimedOutEvent extends AgentEvent {
  final String requestId;
  final String toolName;
  final String messageFa;

  const AgentConfirmationTimedOutEvent({
    required this.requestId,
    required this.toolName,
    this.messageFa = 'زمان تایید تمام شد، اقدام انجام نشد. اگر می‌خواهی، دوباره درخواست بده.',
  });
}

/// یک چانک متنی استریم شد
class AgentTokenStreamEvent extends AgentEvent {
  final String delta;
  final String accumulated;
  const AgentTokenStreamEvent({required this.delta, required this.accumulated});
}

/// اتمام کامل فرآیند ایجنت
class AgentCompletedEvent extends AgentEvent {
  /// متن نمایشی و پاک‌سازی‌شده برای کاربر
  final String finalAnswer;

  /// متن خام و فیلترنشده مدل، شامل تگ‌های <tool_call> و <actions> و <memory_ops>.
  /// مصرف‌کننده‌های پایین‌دستی (مانند ChatActionParser و AiMemoryService) باید از
  /// این متن استفاده کنند، نه از finalAnswer که تگ‌ها از آن حذف شده است.
  final String rawAnswer;

  final List<AgentStep> steps;
  final Map<String, dynamic>? interactiveAction;

  /// شناسه این اجرا در ژورنال (برای پیدا کردن عملیات قابل بازگشت همین پیام)
  final String sessionId;

  const AgentCompletedEvent({
    required this.finalAnswer,
    this.rawAnswer = '',
    required this.steps,
    this.interactiveAction,
    this.sessionId = '',
  });
}

/// وقوع خطا در اجرای ایجنت
class AgentErrorEvent extends AgentEvent {
  final String errorMessageFa;
  const AgentErrorEvent(this.errorMessageFa);
}
