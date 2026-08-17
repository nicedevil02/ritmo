import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ritmo/core/ai/agent/agent_journal.dart';
import 'package:ritmo/core/ai/agent/agent_tool.dart';
import 'package:ritmo/core/ai/agent/agent_tool_registry.dart';

/// نتیجه داوری گیت برای یک فراخوانی ابزار
enum AgentGateOutcome { allow, needsConfirmation, deny }

class AgentGateDecision {
  const AgentGateDecision._({
    required this.outcome,
    required this.isWrite,
    this.reasonFa,
    this.previewFa,
  });

  final AgentGateOutcome outcome;
  final bool isWrite;
  final String? reasonFa;
  final String? previewFa;

  factory AgentGateDecision.allow({required bool isWrite}) =>
      AgentGateDecision._(outcome: AgentGateOutcome.allow, isWrite: isWrite);

  factory AgentGateDecision.needsConfirmation(String previewFa) =>
      AgentGateDecision._(
        outcome: AgentGateOutcome.needsConfirmation,
        isWrite: true,
        previewFa: previewFa,
      );

  factory AgentGateDecision.deny(String reasonFa, {bool isWrite = true}) =>
      AgentGateDecision._(
        outcome: AgentGateOutcome.deny,
        isWrite: isWrite,
        reasonFa: reasonFa,
      );

  bool get isAllowed => outcome == AgentGateOutcome.allow;
  bool get isDenied => outcome == AgentGateOutcome.deny;
  bool get needsUserConfirmation =>
      outcome == AgentGateOutcome.needsConfirmation;
}

/// درخواست تاییدی که حلقه ایجنت به UI می‌دهد و منتظر پاسخ می‌ماند
class AgentConfirmationRequest {
  const AgentConfirmationRequest({
    required this.id,
    required this.toolName,
    required this.titleFa,
    required this.previewFa,
    required this.parameters,
  });

  final String id;
  final String toolName;
  final String titleFa;
  final String previewFa;
  final Map<String, dynamic> parameters;
}

class AgentConfirmationResponse {
  const AgentConfirmationResponse._({
    required this.approved,
    this.editedArgs,
    this.reasonFa,
    this.timedOut = false,
  });

  final bool approved;

  /// اگر کاربر پیش از تایید مقداری را ویرایش کرده باشد
  final Map<String, dynamic>? editedArgs;
  final String? reasonFa;
  final bool timedOut;

  factory AgentConfirmationResponse.approve(
          {Map<String, dynamic>? editedArgs}) =>
      AgentConfirmationResponse._(approved: true, editedArgs: editedArgs);

  factory AgentConfirmationResponse.reject({String? reasonFa}) =>
      AgentConfirmationResponse._(approved: false, reasonFa: reasonFa);

  static const AgentConfirmationResponse expired = AgentConfirmationResponse._(
    approved: false,
    timedOut: true,
    reasonFa: 'منتظر تایید ماندم اما پاسخی نگرفتم',
  );
}

/// پل میان حلقه ایجنت و کارت تایید در UI.
///
/// حلقه روی Future منتظر می‌ماند، UI با respond آن را آزاد می‌کند. بدون این
/// لایه، actionInteractive یا بی‌تایید اجرا می‌شد یا مطلقا اجرا نمی‌شد (رفتار فاز ۱).
class AgentConfirmationBroker {
  AgentConfirmationBroker._();

  static final AgentConfirmationBroker instance = AgentConfirmationBroker._();

  final Map<String, Completer<AgentConfirmationResponse>> _pending = {};

  /// UI با ValueListenableBuilder روی این مقدار کارت تایید را نشان می‌دهد
  final ValueNotifier<AgentConfirmationRequest?> pending =
      ValueNotifier<AgentConfirmationRequest?>(null);

  bool get hasPending => pending.value != null;

  Future<AgentConfirmationResponse> ask(
    AgentConfirmationRequest request, {
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final completer = Completer<AgentConfirmationResponse>();
    _pending[request.id] = completer;
    pending.value = request;
    debugPrint('[Agent] awaiting confirmation | ${request.toolName}');
    try {
      return await completer.future.timeout(
        timeout,
        onTimeout: () => AgentConfirmationResponse.expired,
      );
    } finally {
      _pending.remove(request.id);
      if (pending.value?.id == request.id) pending.value = null;
    }
  }

  bool respond(String requestId, AgentConfirmationResponse response) {
    final completer = _pending.remove(requestId);
    if (pending.value?.id == requestId) pending.value = null;
    if (completer == null || completer.isCompleted) return false;
    completer.complete(response);
    return true;
  }

  bool approve(String requestId, {Map<String, dynamic>? editedArgs}) => respond(
        requestId,
        AgentConfirmationResponse.approve(editedArgs: editedArgs),
      );

  bool reject(String requestId, {String? reasonFa}) => respond(
        requestId,
        AgentConfirmationResponse.reject(reasonFa: reasonFa),
      );

  /// بستن شیت گفت‌وگو باید همه درخواست‌های معلق را لغو کند، وگرنه حلقه تا تایم‌اوت می‌ماند
  void cancelAll({String? reasonFa}) {
    final entries = _pending.entries.toList();
    _pending.clear();
    pending.value = null;
    for (final entry in entries) {
      if (!entry.value.isCompleted) {
        entry.value.complete(AgentConfirmationResponse.reject(
          reasonFa: reasonFa ?? 'گفت‌وگو بسته شد',
        ));
      }
    }
  }
}

/// درخواست پرسش از کاربر توسط ابزار ask_user
class AgentQuestionRequest {
  const AgentQuestionRequest({
    required this.id,
    required this.sessionId,
    required this.question,
    this.options = const [],
  });

  final String id;
  final String sessionId;
  final String question;
  final List<String> options;
}

/// پاسخ کاربر به پرسش دستیار
class AgentQuestionResponse {
  const AgentQuestionResponse({
    required this.answered,
    this.answer,
    this.reasonFa,
  });

  final bool answered;
  final String? answer;
  final String? reasonFa;

  static const AgentQuestionResponse expired = AgentQuestionResponse(
    answered: false,
    reasonFa: 'مهلت پاسخ به پایان رسید',
  );

  static AgentQuestionResponse answerValue(String answer) =>
      AgentQuestionResponse(answered: true, answer: answer);

  static AgentQuestionResponse cancel({String? reasonFa}) =>
      AgentQuestionResponse(answered: false, reasonFa: reasonFa ?? 'لغو شد');
}

/// کارگزار پرسش تعاملی از کاربر با مدیریت چرخه حیات و جلوگیری از نشت حافظه
class AgentQuestionBroker {
  AgentQuestionBroker._();

  static final AgentQuestionBroker instance = AgentQuestionBroker._();

  final Map<String, Completer<AgentQuestionResponse>> _pending = {};
  final ValueNotifier<AgentQuestionRequest?> pending =
      ValueNotifier<AgentQuestionRequest?>(null);

  bool get hasPending => pending.value != null;

  Future<AgentQuestionResponse> ask(
    AgentQuestionRequest request, {
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final completer = Completer<AgentQuestionResponse>();
    _pending[request.id] = completer;
    pending.value = request;
    try {
      return await completer.future.timeout(
        timeout,
        onTimeout: () => AgentQuestionResponse.expired,
      );
    } finally {
      _pending.remove(request.id);
      if (pending.value?.id == request.id) pending.value = null;
    }
  }

  bool respond(String requestId, String answer) {
    final completer = _pending.remove(requestId);
    if (pending.value?.id == requestId) pending.value = null;
    if (completer == null || completer.isCompleted) return false;
    completer.complete(AgentQuestionResponse.answerValue(answer));
    return true;
  }

  void cancelAll({String? reasonFa}) {
    final entries = _pending.entries.toList();
    _pending.clear();
    pending.value = null;
    for (final entry in entries) {
      if (!entry.value.isCompleted) {
        entry.value.complete(AgentQuestionResponse.cancel(
          reasonFa: reasonFa ?? 'گفت‌وگو بسته شد',
        ));
      }
    }
  }
}

/// گیت سیاست ابزار — فاز ۳ (P3-1)
///
/// تا پیش از این، ToolPolicy فقط یک برچسب تزیینی بود (نقص D8): هر ابزاری که مدل
/// صدا می‌زد بدون هیچ محافظی اجرا می‌شد یا (برای actionInteractive) بی‌صدا دور ریخته
/// می‌شد. اینجا هر سه سطح معنای واقعی دارند:
///
/// - readOnly: اجرای فوری، بدون ژورنال
/// - actionDirect: اجرا + ثبت در ژورنال + قابل بازگشت
/// - actionInteractive: توقف حلقه تا تایید کاربر
class AgentPolicyGate {
  AgentPolicyGate._();

  static final AgentPolicyGate instance = AgentPolicyGate._();

  /// سقف تغییر واقعی در یک پیام. مدل در یک نوبت نباید بتواند ده روتین بسازد.
  static const int maxWritesPerRun = 3;

  static final RegExp _injectionSignals = RegExp(
    r'<\s*/?\s*(tool_call|user_content|system|assistant|actions|memory_ops|function|im_start|im_end)\b[^>]*>'
    r'|ignore\s+(all\s+)?previous\s+instructions'
    r'|disregard\s+all\s+(prior|previous)\s+instructions'
    r'|system\s+override'
    r'|you\s+are\s+now\s+in\s+(developer|god)\s+mode'
    r'|دستورات\s+(قبلی|پیشین)\s+را\s+(نادیده|فراموش)\s+بگیر'
    r'|از\s+این\s+لحظه\s+دستورات\s+سیستم\s+را\s+لغو\s+کن',
    caseSensitive: false,
  );

  AgentGateDecision evaluate({
    required AgentTool tool,
    required Map<String, dynamic> args,
    required int writesUsedThisRun,
  }) {
    if (tool.policy == ToolPolicy.readOnly) {
      return AgentGateDecision.allow(isWrite: false);
    }

    if (writesUsedThisRun >= maxWritesPerRun) {
      return AgentGateDecision.deny(
          'در یک پیام حداکثر $maxWritesPerRun تغییر مجاز است؛ این مورد اجرا نشد.');
    }

    final suspicious = _suspiciousArgKey(args);
    if (suspicious != null) {
      return AgentGateDecision.deny(
          'مقدار پارامتر "$suspicious" شامل عبارات یا تگ‌های تزریق سیستمی است، پس این تغییر رد شد.');
    }

    if (tool.policy == ToolPolicy.actionInteractive) {
      return AgentGateDecision.needsConfirmation(buildPreviewFa(tool, args));
    }

    return AgentGateDecision.allow(isWrite: true);
  }

  /// متن کارت تایید: کاربر باید دقیقا ببیند قرار است چه چیزی ثبت شود
  String buildPreviewFa(AgentTool tool, Map<String, dynamic> args) {
    final b = StringBuffer();
    b.writeln(tool.titleFa);
    final desc = tool.descriptionFa.trim();
    if (desc.isNotEmpty) b.writeln(desc);

    final declared = <String>{};
    for (final p in tool.parameters) {
      declared.add(p.name);
      final value = args[p.name];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isEmpty) continue;
      final label =
          p.descriptionFa.trim().isEmpty ? p.name : p.descriptionFa.trim();
      b.writeln('• $label: $text');
    }

    for (final entry in args.entries) {
      if (declared.contains(entry.key)) continue;
      final text = entry.value?.toString().trim() ?? '';
      if (text.isEmpty) continue;
      b.writeln('• ${entry.key}: $text');
    }

    return b.toString().trim();
  }

  /// اجرای ابزار از مسیر رجیستری همراه ثبت ژورنال برای ابزارهای تغییردهنده
  Future<AgentToolResult> execute({
    required AgentTool tool,
    required Map<String, dynamic> args,
    required String sessionId,
  }) async {
    final result = await AgentToolRegistry.instance.executeTool(tool.name, args);
    if (tool.policy != ToolPolicy.readOnly) {
      await AgentJournal.instance.record(
        sessionId: sessionId,
        tool: tool,
        args: args,
        result: result,
      );
    }
    debugPrint('[Agent] gate ${tool.name} (${tool.policy.name}) -> '
        '${result.isSuccess ? 'ok' : 'failed'}');
    return result;
  }

  AgentToolResult refusalResult(AgentTool tool, String reasonFa) =>
      AgentToolResult.failure(
        toolName: tool.name,
        errorMessage: reasonFa,
        summaryFa: reasonFa,
      );

  bool _isSuspicious(dynamic value) {
    if (value is String) {
      return _injectionSignals.hasMatch(value);
    }
    if (value is Map) {
      return value.values.any(_isSuspicious);
    }
    if (value is List) {
      return value.any(_isSuspicious);
    }
    return false;
  }

  String? _suspiciousArgKey(Map<String, dynamic> args) {
    for (final entry in args.entries) {
      if (_isSuspicious(entry.value)) {
        return entry.key;
      }
    }
    return null;
  }
}
