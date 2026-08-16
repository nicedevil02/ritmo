import 'package:flutter/material.dart';
import 'package:ritmo/features/movement/application/movement_occurrence_service.dart';
import 'package:ritmo/features/movement/application/movement_planning_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';
import 'package:ritmo/features/movement/domain/models/movement_change_scope.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';
import 'package:ritmo/features/movement/domain/models/movement_plan_schedule.dart';

/// وضعیت‌های ماشین حالت ذخیره‌سازی برنامه
enum PlanEditorState {
  editing,
  validating,
  saving,
  saved,
  failed,
}

/// کنترلر صفحهٔ برنامه‌ریز حرکت (ActivityPlanEditorController)
class ActivityPlanEditorController extends ChangeNotifier {
  ActivityPlanEditorController({
    MovementPlanningService? planningService,
    MovementOccurrenceService? occurrenceService,
    this.initialActivityKindId,
    this.existingTemplateId,
    this.initialDate,
  })  : _planningService = planningService ?? MovementPlanningService(),
        _occurrenceService = occurrenceService ?? MovementOccurrenceService();

  final MovementPlanningService _planningService;
  final MovementOccurrenceService _occurrenceService;

  final String? initialActivityKindId;
  final String? existingTemplateId;
  final DateTime? initialDate;

  PlanEditorState _state = PlanEditorState.editing;
  PlanEditorState get state => _state;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isDirty = false;
  bool get isDirty => _isDirty;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  MovementActivityKind? _activityKind;
  MovementActivityKind? get activityKind => _activityKind;

  String _sessionType = 'repeating';
  String get sessionType => _sessionType;

  String _goalType = 'duration';
  String get goalType => _goalType;

  double _goalValue = 30.0;
  double get goalValue => _goalValue;

  String _goalUnit = 'دقیقه';
  String get goalUnit => _goalUnit;

  List<MovementPlanSchedule> _schedules = [];
  List<MovementPlanSchedule> get schedules => List.unmodifiable(_schedules);

  String _reminderType = 'none';
  String get reminderType => _reminderType;

  int? _reminderOffsetMin;
  int? get reminderOffsetMin => _reminderOffsetMin;

  List<MovementOccurrence> _conflicts = [];
  List<MovementOccurrence> get conflicts => List.unmodifiable(_conflicts);

  bool get isValid {
    return _activityKind != null &&
        _goalValue > 0 &&
        _schedules.isNotEmpty &&
        _schedules.every((s) => s.timeOfDay.isNotEmpty);
  }

  String? get disabledReason {
    if (_activityKind == null) return 'نوع فعالیت ورزشی مشخص نشده است';
    if (_goalValue <= 0) return 'مقدار هدف باید بزرگ‌تر از صفر باشد';
    if (_schedules.isEmpty) return 'حداقل یک روز باید انتخاب شود';
    return null;
  }

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (initialActivityKindId != null) {
        _activityKind = await _occurrenceService.getActivityKind(initialActivityKindId!);
      }

      if (_activityKind == null) {
        final all = await _occurrenceService.getAllActivityKinds();
        if (all.isNotEmpty) {
          _activityKind = all.first;
        }
      }

      // بارگذاری قالب موجود در صورت وجود
      if (existingTemplateId != null) {
        final tpl = await _planningService.getTemplate(existingTemplateId!);
        if (tpl != null) {
          _activityKind = tpl.activityKind ?? _activityKind;
          _sessionType = tpl.sessionType;
          _reminderType = tpl.reminderType;
          _reminderOffsetMin = tpl.reminderOffsetMin;
          if (tpl.parsedGoal != null) {
            _goalType = tpl.parsedGoal!['type'] as String? ?? 'duration';
            _goalValue = (tpl.parsedGoal!['value'] as num?)?.toDouble() ?? 30.0;
            _goalUnit = tpl.parsedGoal!['unit'] as String? ?? 'دقیقه';
          }
          _schedules = await _planningService.getSchedules(existingTemplateId!);
        }
      }

      // اگر زمان‌بندی خالی بود، یک روز پیش‌فرض بر اساس تاریخ امروز یا شنبه می‌گذاریم
      if (_schedules.isEmpty) {
        final today = initialDate ?? DateTime.now();
        final weekday = MovementPlanningService.getRitmoWeekday(today);
        _schedules = [
          MovementPlanSchedule(
            id: '',
            templateId: '',
            weekday: weekday,
            timeOfDay: '18:30',
            recurrence: 'weekly',
            startDateIso: MovementPlanningService.formatIso(today),
            createdAt: DateTime.now(),
          ),
        ];
      }

      await checkConflicts();
      _isLoading = false;
      _isDirty = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void setActivityKind(MovementActivityKind kind) {
    _activityKind = kind;
    _isDirty = true;
    notifyListeners();
    checkConflicts();
  }

  void setSessionType(String type) {
    _sessionType = type;
    _isDirty = true;
    notifyListeners();
  }

  void setGoal(String type, double value, String unit) {
    _goalType = type;
    _goalValue = value;
    _goalUnit = unit;
    _isDirty = true;
    notifyListeners();
  }

  void setSchedules(List<MovementPlanSchedule> schedules) {
    _schedules = schedules;
    _isDirty = true;
    notifyListeners();
    checkConflicts();
  }

  void setReminder(String type, int? offsetMin) {
    _reminderType = type;
    _reminderOffsetMin = offsetMin;
    _isDirty = true;
    notifyListeners();
  }

  Future<void> checkConflicts() async {
    if (_schedules.isEmpty) {
      _conflicts = [];
      notifyListeners();
      return;
    }

    final today = initialDate ?? DateTime.now();
    final todayIso = MovementPlanningService.formatIso(today);
    final firstTime = _schedules.first.timeOfDay;

    final conflicts = await _planningService.checkConflicts(
      dateIso: todayIso,
      timeOfDay: firstTime,
    );

    _conflicts = conflicts;
    notifyListeners();
  }

  /// ذخیرهٔ نهایی برنامه در یک تراکنش اتمیک
  Future<int> savePlan({MovementChangeScope scope = MovementChangeScope.wholePlan}) async {
    if (!isValid) return 0;

    _state = PlanEditorState.validating;
    notifyListeners();

    _state = PlanEditorState.saving;
    notifyListeners();

    try {
      final goalMap = {
        'type': _goalType,
        'value': _goalValue,
        'unit': _goalUnit,
      };

      if (existingTemplateId == null) {
        // ایجاد برنامه جدید
        await _planningService.createPlan(
          activityKindId: _activityKind!.id,
          sessionType: _sessionType,
          goal: goalMap,
          reminderType: _reminderType,
          reminderOffsetMin: _reminderOffsetMin,
          schedules: _schedules,
          horizonWeeks: 4,
        );
      } else {
        // به‌روزرسانی برنامه موجود با دامنه
        final todayIso = MovementPlanningService.formatIso(initialDate ?? DateTime.now());
        await _planningService.updatePlanWithScope(
          templateId: existingTemplateId!,
          occurrenceId: '',
          focalDateIso: todayIso,
          scope: scope,
          newGoal: goalMap,
          newStartTime: _schedules.isNotEmpty ? _schedules.first.timeOfDay : null,
          newReminderType: _reminderType,
          newReminderOffsetMin: _reminderOffsetMin,
        );
      }

      _state = PlanEditorState.saved;
      _isDirty = false;
      notifyListeners();

      // محاسبهٔ تقریبی تعداد رخدادهای تولید شده
      final weeks = _schedules.firstOrNull?.recurrence == 'once'
          ? 1
          : (_schedules.firstOrNull?.weeksCount ?? 4);
      return _schedules.length * weeks;
    } catch (e) {
      _errorMessage = e.toString();
      _state = PlanEditorState.failed;
      notifyListeners();
      return 0;
    }
  }
}
