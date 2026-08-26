import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/util/ritmo_date.dart';
import 'package:ritmo/core/util/ritmo_number.dart';
import 'package:ritmo/features/study/data/study_settings_repository.dart';
import 'package:ritmo/features/study/domain/study_models.dart';
import 'package:ritmo/features/study/domain/study_review_policy.dart';
import 'package:ritmo/features/study/logic/study_timer_service.dart';

enum TimerModeType { stopwatch, pomodoro25, pomodoro50 }

class SessionTimerSheet extends StatefulWidget {
  const SessionTimerSheet({super.key, required this.subject, this.topic});

  final StudySubject subject;
  final StudyTopic? topic;

  static Future<void> show(BuildContext context, {required StudySubject subject, StudyTopic? topic}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (_) => SessionTimerSheet(subject: subject, topic: topic),
    );
  }

  @override
  State<SessionTimerSheet> createState() => _SessionTimerSheetState();
}

class _SessionTimerSheetState extends State<SessionTimerSheet> {
  StreamSubscription? _sub;
  ActiveStudySessionState? _state;
  SessionFeedback _feedback = SessionFeedback.understood;
  TimerModeType _timerMode = TimerModeType.stopwatch;
  int? _lastRemainingSec;

  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _testsTotalController = TextEditingController();
  final TextEditingController _testsCorrectController = TextEditingController();
  final TextEditingController _testsWrongController = TextEditingController();
  bool _includeTests = false;

  @override
  void initState() {
    super.initState();
    _testsTotalController.addListener(_onTestInputChanged);
    _testsCorrectController.addListener(_onTestInputChanged);
    _testsWrongController.addListener(_onTestInputChanged);

    _sub = StudyTimerService.instance.stream.listen((state) {
      if (mounted) {
        setState(() {
          _state = state;
          if (state != null && state.isPomodoro) {
            final nowMs = DateTime.now().millisecondsSinceEpoch;
            final rem = state.remainingSeconds(nowMs);
            if (_lastRemainingSec != null && _lastRemainingSec! > 0 && rem <= 0) {
              RitmoHapticsPolicy.success();
              HapticFeedback.vibrate();
            }
            _lastRemainingSec = rem;

            if (state.targetSeconds == 1500 || state.targetSeconds == 300) {
              _timerMode = TimerModeType.pomodoro25;
            } else if (state.targetSeconds >= 2400 || state.targetSeconds == 600) {
              _timerMode = TimerModeType.pomodoro50;
            } else if (state.targetSeconds > 0) {
              _timerMode = state.targetSeconds > 1800 ? TimerModeType.pomodoro50 : TimerModeType.pomodoro25;
            }
          } else if (state != null && !state.isPomodoro) {
            _timerMode = TimerModeType.stopwatch;
          }
        });
      }
    });

    if (!StudyTimerService.instance.hasActiveSession) {
      StudyTimerService.instance.startSession(
        subjectId: widget.subject.id,
        topicId: widget.topic?.id,
        pomodoroPhase: 'FOCUS',
        pomodoroCycle: 1,
        targetSeconds: 0, // 0 = Stopwatch free mode by default
      ).catchError((Object _) {});
    }
  }

  void _onTestInputChanged() {
    if (mounted) setState(() {});
  }

  int? get _calculatedAccuracy {
    final total = int.tryParse(RitmoNumber.toEn(_testsTotalController.text.trim())) ?? 0;
    final correct = int.tryParse(RitmoNumber.toEn(_testsCorrectController.text.trim())) ?? 0;
    final wrong = int.tryParse(RitmoNumber.toEn(_testsWrongController.text.trim())) ?? 0;
    if (total <= 0) return null;
    final score = ((3 * correct - wrong) / (3 * total) * 100).round();
    return score;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _testsTotalController.removeListener(_onTestInputChanged);
    _testsCorrectController.removeListener(_onTestInputChanged);
    _testsWrongController.removeListener(_onTestInputChanged);
    _noteController.dispose();
    _testsTotalController.dispose();
    _testsCorrectController.dispose();
    _testsWrongController.dispose();
    super.dispose();
  }

  void _onTimerModeChanged(TimerModeType mode) async {
    RitmoHapticsPolicy.selection();
    setState(() => _timerMode = mode);
    int targetSec = 0;
    if (mode == TimerModeType.pomodoro25) {
      targetSec = 1500; // 25 min
    } else if (mode == TimerModeType.pomodoro50) {
      final settings = await StudySettingsRepository.instance.load();
      final focusMins = settings.focusBlockMinutes > 0 ? settings.focusBlockMinutes : 50;
      targetSec = focusMins * 60;
    }

    await StudyTimerService.instance.switchPomodoroPhase(
      phase: 'FOCUS',
      nextCycle: 1,
      targetSeconds: targetSec,
    );
  }

  void _togglePomodoroPhase() async {
    final cur = _state;
    if (cur == null) return;
    RitmoHapticsPolicy.selection();

    final settings = await StudySettingsRepository.instance.load();
    final focusMins = settings.focusBlockMinutes > 0 ? settings.focusBlockMinutes : 50;

    if (cur.pomodoroPhase == 'FOCUS') {
      final breakSec = _timerMode == TimerModeType.pomodoro50 ? (focusMins >= 45 ? 600 : 300) : 300;
      await StudyTimerService.instance.switchPomodoroPhase(
        phase: 'BREAK',
        nextCycle: cur.pomodoroCycle,
        targetSeconds: breakSec,
      );
    } else {
      final focusSec = _timerMode == TimerModeType.pomodoro50 ? (focusMins * 60) : 1500;
      final nextCycle = cur.pomodoroCycle < 4 ? cur.pomodoroCycle + 1 : 1;
      await StudyTimerService.instance.switchPomodoroPhase(
        phase: 'FOCUS',
        nextCycle: nextCycle,
        targetSeconds: focusSec,
      );
    }
  }

  Future<bool?> _showCancelConfirmDialog(BuildContext context) async {
    RitmoHapticsPolicy.warning();
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? colors.surfaceElevated : colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: colors.error, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'لغو مطالعه',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'آیا می‌خواهید این جلسه مطالعه را بدون ذخیره لغو کنید؟',
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      RitmoHapticsPolicy.tap();
                      Navigator.pop(ctx, false);
                    },
                    child: Text('ادامه مطالعه', style: TextStyle(color: colors.textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      RitmoHapticsPolicy.warning();
                      Navigator.pop(ctx, true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.error,
                      foregroundColor: colors.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('بله، لغو شود', style: TextStyle(color: colors.onPrimary)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _finishSession() async {
    RitmoHapticsPolicy.tap();
    final curTopic = widget.topic;
    ReviewResult? reviewRes;
    int? newReviewCount;
    if (curTopic != null) {
      reviewRes = StudyReviewPolicy.evaluate(
        feedback: _feedback,
        currentMastery: curTopic.mastery,
        reviewCount: curTopic.reviewCount,
      );
      if (_feedback == SessionFeedback.understood) {
        newReviewCount = curTopic.reviewCount + 1;
      } else if (_feedback == SessionFeedback.needAgain) {
        newReviewCount = 0;
      } else {
        newReviewCount = curTopic.reviewCount;
      }
    }

    final settings = await StudySettingsRepository.instance.load();
    String? nextReviewDateIso;
    if (reviewRes != null && settings.reviewEnabled) {
      final nextDt = DateTime.now().add(Duration(days: reviewRes.nextReviewDays));
      nextReviewDateIso = RitmoDate.dayKey(nextDt);
    }

    int total = 0;
    int correct = 0;
    int wrong = 0;
    int empty = 0;
    if (_includeTests) {
      total = int.tryParse(RitmoNumber.toEn(_testsTotalController.text.trim())) ?? 0;
      correct = int.tryParse(RitmoNumber.toEn(_testsCorrectController.text.trim())) ?? 0;
      wrong = int.tryParse(RitmoNumber.toEn(_testsWrongController.text.trim())) ?? 0;
      if (correct + wrong > total) {
        total = correct + wrong;
      }
      empty = (total - correct - wrong) > 0 ? (total - correct - wrong) : 0;
    }

    await StudyTimerService.instance.stopAndSaveSession(
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      newMastery: reviewRes?.nextMastery,
      nextReviewDateIso: nextReviewDateIso,
      newReviewCount: newReviewCount,
      testsTotal: total,
      testsCorrect: correct,
      testsWrong: wrong,
      testsEmpty: empty,
    );

    RitmoHapticsPolicy.success();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final isGlass = context.isGlassEnabled;
    final blur = context.glassBlurSigma.clamp(0.0, 50.0);
    const sheetRadius = BorderRadius.vertical(top: Radius.circular(28));
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final elapsedSec = _state?.elapsedSeconds(nowMs) ?? 0;
    final isPaused = _state?.isPaused ?? false;
    final isPomodoro = _state?.isPomodoro ?? (_timerMode != TimerModeType.stopwatch);
    final isBreak = _state?.pomodoroPhase == 'BREAK';
    final targetSec = _state?.targetSeconds ?? 0;

    int displaySeconds;
    if (isPomodoro && targetSec > 0) {
      displaySeconds = _state?.remainingSeconds(nowMs) ?? 0;
    } else {
      displaySeconds = elapsedSec;
    }

    final hours = displaySeconds ~/ 3600;
    final minutes = (displaySeconds % 3600) ~/ 60;
    final seconds = displaySeconds % 60;
    final minStr = RitmoNumber.fa(minutes.toString().padLeft(2, '0'));
    final secStr = RitmoNumber.fa(seconds.toString().padLeft(2, '0'));
    final timeStr = hours > 0
        ? '${RitmoNumber.fa(hours.toString().padLeft(2, '0'))}:$minStr:$secStr'
        : '$minStr:$secStr';

    final content = Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.subject.name,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.topic != null)
                        Text(
                          widget.topic!.name,
                          style: TextStyle(fontSize: 12, color: colors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(CupertinoIcons.xmark_circle_fill, color: colors.textSecondary.withValues(alpha: 0.5), size: 24),
                  onPressed: () async {
                    final confirm = await _showCancelConfirmDialog(context);
                    if (confirm == true) {
                      await StudyTimerService.instance.cancelSession();
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<TimerModeType>(
              segments: const [
                ButtonSegment(value: TimerModeType.stopwatch, label: Text('کرنومتر', style: TextStyle(fontSize: 11))),
                ButtonSegment(value: TimerModeType.pomodoro25, label: Text('پومودورو ۲۵/۵', style: TextStyle(fontSize: 11))),
                ButtonSegment(value: TimerModeType.pomodoro50, label: Text('پومودورو ۵۰/۱۰', style: TextStyle(fontSize: 11))),
              ],
              selected: {_timerMode},
              onSelectionChanged: (set) => _onTimerModeChanged(set.first),
            ),
            const SizedBox(height: 16),
            if (isPomodoro) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: isBreak ? Colors.teal.withValues(alpha: 0.15) : colors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isBreak
                      ? '☕ استراحت (دور ${RitmoNumber.faInt(_state?.pomodoroCycle ?? 1)} از ۴)'
                      : '🎯 تمرکز و مطالعه (دور ${RitmoNumber.faInt(_state?.pomodoroCycle ?? 1)} از ۴)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isBreak ? Colors.teal : colors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              timeStr,
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: isBreak ? Colors.teal : colors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  icon: Icon(isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                  iconSize: 32,
                  tooltip: isPaused ? 'ادامه' : 'توقف موقت',
                  onPressed: () {
                    RitmoHapticsPolicy.tap();
                    if (isPaused) {
                      StudyTimerService.instance.resumeSession();
                    } else {
                      StudyTimerService.instance.pauseSession();
                    }
                  },
                ),
                if (isPomodoro) ...[
                  const SizedBox(width: 14),
                  IconButton.filledTonal(
                    iconSize: 28,
                    tooltip: isBreak ? 'شروع تمرکز بعدی' : 'شروع استراحت',
                    icon: Icon(Icons.skip_next_rounded, color: colors.textPrimary),
                    onPressed: _togglePomodoroPhase,
                  ),
                ],
                const SizedBox(width: 14),
                IconButton.filled(
                  icon: const Icon(Icons.stop_rounded),
                  iconSize: 32,
                  tooltip: 'پایان و ذخیره',
                  style: IconButton.styleFrom(backgroundColor: colors.primary, foregroundColor: colors.onPrimary),
                  onPressed: _finishSession,
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'یادداشت این جلسه (اختیاری)',
                prefixIcon: Icon(Icons.note_alt_outlined),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: colors.border.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ExpansionTile(
                title: Row(
                  children: [
                    const Text('ثبت تست‌های حل‌شده در این جلسه', style: TextStyle(fontSize: 12)),
                    const Spacer(),
                    if (_calculatedAccuracy != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (_calculatedAccuracy! >= 50 ? colors.primary : colors.error).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'تراز: ${RitmoNumber.faInt(_calculatedAccuracy!)}٪',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _calculatedAccuracy! >= 50 ? colors.primary : colors.error,
                          ),
                        ),
                      ),
                  ],
                ),
                leading: const Icon(Icons.check_circle_outline, size: 18),
                initiallyExpanded: _includeTests,
                onExpansionChanged: (val) {
                  RitmoHapticsPolicy.selection();
                  setState(() => _includeTests = val);
                },
                children: [
                  if (_includeTests) ...[
                    Row(
                      children: [
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _testsTotalController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'کل تست‌ها',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _testsCorrectController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'درست',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _testsWrongController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'غلط',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('میزان تسلط و کیفیت یادگیری:', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
            const SizedBox(height: 6),
            SegmentedButton<SessionFeedback>(
              segments: const [
                ButtonSegment(value: SessionFeedback.understood, label: Text('فهمیدم', style: TextStyle(fontSize: 11))),
                ButtonSegment(value: SessionFeedback.partial, label: Text('نصفه‌نیمه', style: TextStyle(fontSize: 11))),
                ButtonSegment(value: SessionFeedback.needAgain, label: Text('دوباره', style: TextStyle(fontSize: 11))),
              ],
              selected: {_feedback},
              onSelectionChanged: (set) {
                RitmoHapticsPolicy.selection();
                setState(() => _feedback = set.first);
              },
            ),
          ],
        ),
      ),
    );

    final sheetBody = Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        type: MaterialType.transparency,
        child: content,
      ),
    );

    Widget sheetContainer;
    if (!isGlass) {
      sheetContainer = Container(
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: sheetRadius,
          border: Border.all(
            color: isDark ? colors.border : colors.divider,
            width: 1.0,
          ),
        ),
        child: sheetBody,
      );
    } else {
      sheetContainer = ClipRRect(
        borderRadius: sheetRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.glassTint,
              borderRadius: sheetRadius,
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.70),
                width: 1.0,
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: sheetRadius,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: isDark ? 0.08 : 0.20),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.45],
                ),
              ),
              child: sheetBody,
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final confirm = await _showCancelConfirmDialog(context);
        if (confirm == true) {
          await StudyTimerService.instance.cancelSession();
          if (context.mounted) Navigator.pop(context);
        }
      },
      child: sheetContainer,
    );
  }
}
