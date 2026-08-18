import 'package:ritmo/core/ai/agent/agent_event.dart';
import 'package:ritmo/core/ai/agent/agent_policy_gate.dart';

/// ماشین حالت نمایش مشترک بین همهٔ مصرف‌کنندگان جریان ایجنت (A-21).
///
/// این کلاس هیچ وابستگی به ویجت‌های فلاتر ندارد و می‌تواند به صورت خالص تست شود.
class AgentStreamPresenter {
  String _visibleText = '';
  bool _isWorking = false;
  bool _isSuppressed = false;
  AgentQuestionRequest? _pendingQuestion;
  AgentConfirmationRequest? _pendingConfirmation;
  String? _errorFa;
  String _statusTextFa = '';
  String? _currentToolName;
  final List<AgentStep> _steps = [];
  int _currentTurn = 1;
  int _maxTurns = 10;

  String get visibleText => _visibleText;
  bool get isWorking => _isWorking;
  bool get isSuppressed => _isSuppressed;
  AgentQuestionRequest? get pendingQuestion => _pendingQuestion;
  AgentConfirmationRequest? get pendingConfirmation => _pendingConfirmation;
  String? get errorFa => _errorFa;
  String get statusTextFa => _statusTextFa;
  String? get currentToolName => _currentToolName;
  List<AgentStep> get steps => List.unmodifiable(_steps);
  int get currentTurn => _currentTurn;
  int get maxTurns => _maxTurns;

  /// تنها نقطهٔ ورود. هر رویداد ایجنت از اینجا رد می‌شود.
  void apply(AgentEvent event) {
    switch (event) {
      case AgentStatusChangedEvent(:final statusTextFa, :final isWorking, :final currentToolName):
        _statusTextFa = statusTextFa;
        _isWorking = isWorking;
        _currentToolName = currentToolName;

      case AgentTurnStartedEvent(:final turn, :final maxTurns):
        _currentTurn = turn;
        _maxTurns = maxTurns;
        // در شروع هر نوبت جدید، متن خام نوبت قبل نگه داشته نمی‌شود
        // مگر اینکه نوبت پاسخ نهایی باشد.

      case AgentStepStartedEvent(:final step):
        _isWorking = true;
        final idx = _steps.indexWhere((s) => s.id == step.id);
        if (idx != -1) {
          _steps[idx] = step;
        } else {
          _steps.add(step);
        }

      case AgentStepCompletedEvent(:final step):
        final idx = _steps.indexWhere((s) => s.id == step.id);
        if (idx != -1) {
          _steps[idx] = step;
        } else {
          _steps.add(step);
        }

      case AgentAwaitingConfirmationEvent(:final request):
        _pendingConfirmation = request;

      case AgentConfirmationResolvedEvent():
      case AgentConfirmationTimedOutEvent():
        _pendingConfirmation = null;

      case AgentAwaitingQuestionEvent(:final request):
        _pendingQuestion = request;

      case AgentQuestionResolvedEvent():
        _pendingQuestion = null;

      case AgentTokenStreamEvent(:final accumulated):
        if (!_isSuppressed) {
          _visibleText = accumulated;
        }

      case AgentDisplayResetEvent(:final turnKind):
        if (turnKind == AgentTurnKind.toolCallTurn) {
          _isSuppressed = true;
          _visibleText = '';
          _isWorking = true;
          _statusTextFa = 'در حال تحلیل نتیجه ابزارها...';
        } else {
          _isSuppressed = false;
          _statusTextFa = 'در حال نگارش پاسخ نهایی...';
        }

      case AgentCompletedEvent(:final finalAnswer, :final steps):
        _visibleText = finalAnswer.isNotEmpty ? finalAnswer : _visibleText;
        _isWorking = false;
        _isSuppressed = false;
        _pendingQuestion = null;
        _pendingConfirmation = null;
        if (steps.isNotEmpty) {
          _steps
            ..clear()
            ..addAll(steps);
        }

      case AgentErrorEvent(:final errorMessageFa):
        _errorFa = errorMessageFa;
        _isWorking = false;
        _isSuppressed = false;
    }
  }

  /// بازنشانی کامل وضعیت ماشین حالت
  void reset() {
    _visibleText = '';
    _isWorking = false;
    _isSuppressed = false;
    _pendingQuestion = null;
    _pendingConfirmation = null;
    _errorFa = null;
    _statusTextFa = '';
    _currentToolName = null;
    _steps.clear();
    _currentTurn = 1;
    _maxTurns = 10;
  }
}
