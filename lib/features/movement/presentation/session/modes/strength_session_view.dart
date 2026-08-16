import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/application/strength_program_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_set_log.dart';
import 'package:ritmo/features/movement/domain/models/movement_strength_day.dart';
import 'package:ritmo/features/movement/domain/models/movement_strength_exercise.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';
import 'package:ritmo/features/movement/presentation/strength/sheets/swap_exercise_sheet.dart';
import 'package:ritmo/features/movement/presentation/strength/widgets/current_exercise_card.dart';
import 'package:ritmo/features/movement/presentation/strength/widgets/rest_timer_bar.dart';
import 'package:ritmo/features/movement/presentation/strength/widgets/rir_picker.dart';
import 'package:ritmo/features/movement/presentation/strength/widgets/set_table.dart';

/// مد تمرین قدرتی داخل SessionShell (StrengthSessionView)
class StrengthSessionView extends StatefulWidget {
  const StrengthSessionView({
    super.key,
    required this.day,
    required this.sessionId,
    this.strengthService,
    required this.onFinishSession,
  });

  final MovementStrengthDay day;
  final String sessionId;
  final StrengthProgramService? strengthService;
  final VoidCallback onFinishSession;

  @override
  State<StrengthSessionView> createState() => _StrengthSessionViewState();
}

class _StrengthSessionViewState extends State<StrengthSessionView> {
  late final StrengthProgramService _service;
  late List<MovementStrengthExercise> _exercises;
  int _currentExerciseIndex = 0;

  // لاگ‌های ست‌ها بر اساس exerciseId
  final Map<String, List<MovementSetLog>> _setLogsByExercise = {};
  final Map<String, List<MovementSetLog>> _hintLogsByExercise = {};

  double? _currentRir;
  bool _isResting = false;
  int _restDurationSec = 60;

  @override
  void initState() {
    super.initState();
    _service = widget.strengthService ?? StrengthProgramService();
    _exercises = List.from(widget.day.exercises);
    if (_exercises.isEmpty) {
      // تمرین نمونه اگر خالی باشد
      _exercises = [
        MovementStrengthExercise(
          id: '${widget.day.id}_default1',
          dayId: widget.day.id,
          orderIndex: 0,
          nameFa: 'شنا سوئدی استاندارد',
          muscleGroup: 'سینه و پشت‌بازو',
          sets: 3,
          repsMin: 8,
          repsMax: 12,
          restSec: 60,
          formTips: const ['بدن در یک خط مستقیم باشد.', 'آرنج‌ها زاویه ۴۵ درجه داشته باشند.'],
          alternatives: const ['شنا روی زانو', 'شنا با تکیه به دیوار', 'پرس سینه با کش'],
        ),
      ];
    }
    _loadPreviousHints();
  }

  MovementStrengthExercise get _currentExercise => _exercises[_currentExerciseIndex];

  List<MovementSetLog> get _currentSetLogs =>
      _setLogsByExercise[_currentExercise.id] ?? [];

  List<MovementSetLog> get _currentHintLogs =>
      _hintLogsByExercise[_currentExercise.nameFa] ?? [];

  Future<void> _loadPreviousHints() async {
    try {
      for (final ex in _exercises) {
        final hints = await _service.getPreviousSessionSetLogs(ex.nameFa);
        _hintLogsByExercise[ex.nameFa] = hints;
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _onSetWeightChanged(int setIndex, double? weight) {
    final list = List<MovementSetLog>.from(_currentSetLogs);
    final idx = list.indexWhere((l) => l.setIndex == setIndex);
    if (idx >= 0) {
      list[idx] = list[idx].copyWith(weightKg: weight);
    } else {
      list.add(MovementSetLog(
        id: '${widget.sessionId}_${_currentExercise.id}_$setIndex',
        sessionId: widget.sessionId,
        exerciseId: _currentExercise.id,
        setIndex: setIndex,
        weightKg: weight,
        at: DateTime.now(),
      ));
    }
    _setLogsByExercise[_currentExercise.id] = list;
    setState(() {});
    unawaited(_persistLog(list.firstWhere((l) => l.setIndex == setIndex)));
  }

  void _onSetRepsChanged(int setIndex, int? reps) {
    final list = List<MovementSetLog>.from(_currentSetLogs);
    final idx = list.indexWhere((l) => l.setIndex == setIndex);
    if (idx >= 0) {
      list[idx] = list[idx].copyWith(reps: reps);
    } else {
      list.add(MovementSetLog(
        id: '${widget.sessionId}_${_currentExercise.id}_$setIndex',
        sessionId: widget.sessionId,
        exerciseId: _currentExercise.id,
        setIndex: setIndex,
        reps: reps,
        at: DateTime.now(),
      ));
    }
    _setLogsByExercise[_currentExercise.id] = list;
    setState(() {});
    unawaited(_persistLog(list.firstWhere((l) => l.setIndex == setIndex)));
  }

  void _onToggleCompleted(int setIndex) {
    final list = List<MovementSetLog>.from(_currentSetLogs);
    final idx = list.indexWhere((l) => l.setIndex == setIndex);
    late MovementSetLog target;

    if (idx >= 0) {
      target = list[idx].copyWith(
        completed: !list[idx].completed,
        rir: _currentRir,
        at: DateTime.now(),
      );
      list[idx] = target;
    } else {
      target = MovementSetLog(
        id: '${widget.sessionId}_${_currentExercise.id}_$setIndex',
        sessionId: widget.sessionId,
        exerciseId: _currentExercise.id,
        setIndex: setIndex,
        reps: _currentExercise.repsMin,
        completed: true,
        rir: _currentRir,
        at: DateTime.now(),
      );
      list.add(target);
    }

    _setLogsByExercise[_currentExercise.id] = list;

    if (target.completed) {
      // هپتیک تأیید ثبت ست
      unawaited(HapticFeedback.mediumImpact());
      // شروع خودکار تایمر استراحت
      _restDurationSec = _currentExercise.restSec;
      _isResting = true;
    }

    setState(() {});
    unawaited(_persistLog(target));
  }

  void _onAddSet() {
    final list = List<MovementSetLog>.from(_currentSetLogs);
    final newSetIndex = (list.map((e) => e.setIndex).fold<int>(0, (a, b) => a > b ? a : b)) + 1;
    final targetSets = newSetIndex > _currentExercise.sets ? newSetIndex : _currentExercise.sets + 1;

    final updatedExercise = _currentExercise.copyWith(sets: targetSets);
    _exercises[_currentExerciseIndex] = updatedExercise;
    setState(() {});
  }

  Future<void> _persistLog(MovementSetLog log) async {
    try {
      await _service.recordSetLog(log);
    } catch (_) {}
  }

  Future<void> _openSwapSheet() async {
    final res = await SwapExerciseSheet.show(
      context,
      currentExercise: _currentExercise,
    );

    if (res != null) {
      if (res.shouldSkip) {
        _goToNextExercise();
      } else {
        final updated = _currentExercise.copyWith(
          nameFa: res.newExerciseNameFa,
          muscleGroup: res.newMuscleGroup,
        );
        _exercises[_currentExerciseIndex] = updated;
        setState(() {});

        unawaited(_service.swapExercise(
          exerciseId: _currentExercise.id,
          newExerciseNameFa: res.newExerciseNameFa,
          newMuscleGroup: res.newMuscleGroup,
          scope: res.scope,
          dayId: widget.day.id,
          programId: widget.day.programId,
        ));
      }
    }
  }

  void _goToNextExercise() {
    _isResting = false;
    if (_currentExerciseIndex < _exercises.length - 1) {
      setState(() => _currentExerciseIndex++);
    } else {
      widget.onFinishSession();
    }
  }

  void _handlePrimaryCta() {
    final uncompleted = _currentExercise.sets - _currentSetLogs.where((l) => l.completed).length;
    if (uncompleted > 0) {
      // تکمیل اولین ست باز
      final completedIndices = _currentSetLogs.where((l) => l.completed).map((l) => l.setIndex).toSet();
      for (int i = 1; i <= _currentExercise.sets; i++) {
        if (!completedIndices.contains(i)) {
          _onToggleCompleted(i);
          break;
        }
      }
    } else if (_currentExerciseIndex < _exercises.length - 1) {
      _goToNextExercise();
    } else {
      widget.onFinishSession();
    }
  }

  String _getPrimaryCtaLabel() {
    final uncompleted = _currentExercise.sets - _currentSetLogs.where((l) => l.completed).length;
    if (uncompleted > 0) {
      return MovementStrings.strengthRecordSet;
    }
    if (_currentExerciseIndex < _exercises.length - 1) {
      return MovementStrings.strengthNextExercise;
    }
    return MovementStrings.strengthFinishSession;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.md, vertical: RitmoSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // پیشرفت حرکت‌ها
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                MovementStrings.strengthExerciseProgress(_currentExerciseIndex + 1, _exercises.length),
                style: RitmoTextStyles.label(sportsColor).copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                widget.day.name,
                style: RitmoTextStyles.caption(colors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: RitmoSpacing.sm),

          // کارت حرکت جاری
          CurrentExerciseCard(
            exercise: _currentExercise,
            onSwapPressed: _openSwapSheet,
          ),
          const SizedBox(height: RitmoSpacing.md),

          // جدول ست‌ها
          SetTable(
            exercise: _currentExercise,
            setLogs: _currentSetLogs,
            hintLogs: _currentHintLogs,
            onSetWeightChanged: _onSetWeightChanged,
            onSetRepsChanged: _onSetRepsChanged,
            onToggleCompleted: _onToggleCompleted,
            onAddSet: _onAddSet,
          ),
          const SizedBox(height: RitmoSpacing.sm),

          // انتخاب‌گر RIR
          RirPicker(
            selectedRir: _currentRir,
            onRirSelected: (rir) => setState(() => _currentRir = rir),
          ),
          const SizedBox(height: RitmoSpacing.md),

          // نوار تایمر استراحت (در حین استراحت)
          if (_isResting)
            RestTimerBar(
              initialSeconds: _restDurationSec,
              onFinish: () => setState(() => _isResting = false),
              onSkip: () => setState(() => _isResting = false),
            ),
          const SizedBox(height: RitmoSpacing.sm),

          // دکمهٔ اکشن اصلی منفرد
          ElevatedButton(
            onPressed: _handlePrimaryCta,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, MovementLayout.kPrimaryButtonHeight),
              backgroundColor: sportsColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RitmoRadius.field)),
            ),
            child: Text(
              _getPrimaryCtaLabel(),
              style: RitmoTextStyles.label(Colors.white),
            ),
          ),
          const SizedBox(height: RitmoSpacing.lg),
        ],
      ),
    );
  }
}
