import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/util/ritmo_date.dart';
import 'package:ritmo/core/util/ritmo_number.dart';
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
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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

  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _testsTotalController = TextEditingController();
  final TextEditingController _testsCorrectController = TextEditingController();
  final TextEditingController _testsWrongController = TextEditingController();
  bool _includeTests = false;

  @override
  void initState() {
    super.initState();
    _sub = StudyTimerService.instance.stream.listen((state) {
      if (mounted) {
        setState(() {
          _state = state;
          if (state != null && state.isPomodoro) {
            if (state.targetSeconds == 1500 || state.targetSeconds == 300) {
              _timerMode = TimerModeType.pomodoro25;
            } else if (state.targetSeconds == 3000 || state.targetSeconds == 600) {
              _timerMode = TimerModeType.pomodoro50;
            }
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
      );
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _noteController.dispose();
    _testsTotalController.dispose();
    _testsCorrectController.dispose();
    _testsWrongController.dispose();
    super.dispose();
  }

  void _onTimerModeChanged(TimerModeType mode) {
    setState(() => _timerMode = mode);
    int targetSec = 0;
    if (mode == TimerModeType.pomodoro25) {
      targetSec = 1500; // 25 min
    } else if (mode == TimerModeType.pomodoro50) {
      targetSec = 3000; // 50 min
    }

    StudyTimerService.instance.switchPomodoroPhase(
      phase: 'FOCUS',
      nextCycle: 1,
      targetSeconds: targetSec,
    );
  }

  void _togglePomodoroPhase() {
    final cur = _state;
    if (cur == null) return;

    if (cur.pomodoroPhase == 'FOCUS') {
      final breakSec = _timerMode == TimerModeType.pomodoro50 ? 600 : 300;
      StudyTimerService.instance.switchPomodoroPhase(
        phase: 'BREAK',
        nextCycle: cur.pomodoroCycle,
        targetSeconds: breakSec,
      );
    } else {
      final focusSec = _timerMode == TimerModeType.pomodoro50 ? 3000 : 1500;
      final nextCycle = cur.pomodoroCycle < 4 ? cur.pomodoroCycle + 1 : 1;
      StudyTimerService.instance.switchPomodoroPhase(
        phase: 'FOCUS',
        nextCycle: nextCycle,
        targetSeconds: focusSec,
      );
    }
  }

  Future<void> _finishSession() async {
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

    String? nextReviewDateIso;
    if (reviewRes != null) {
      final nextDt = DateTime.now().add(Duration(days: reviewRes.nextReviewDays));
      nextReviewDateIso = RitmoDate.dayKey(nextDt);
    }

    int total = 0;
    int correct = 0;
    int wrong = 0;
    int empty = 0;
    if (_includeTests) {
      total = int.tryParse(_testsTotalController.text.trim()) ?? 0;
      correct = int.tryParse(_testsCorrectController.text.trim()) ?? 0;
      wrong = int.tryParse(_testsWrongController.text.trim()) ?? 0;
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

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final elapsedSec = _state?.elapsedSeconds(nowMs) ?? 0;
    final isPaused = _state?.isPaused ?? false;
    final isPomodoro = _timerMode != TimerModeType.stopwatch;
    final isBreak = _state?.pomodoroPhase == 'BREAK';
    final targetSec = _state?.targetSeconds ?? 0;

    int displaySeconds;
    if (isPomodoro && targetSec > 0) {
      final rem = targetSec - elapsedSec;
      displaySeconds = rem > 0 ? rem : 0;
    } else {
      displaySeconds = elapsedSec;
    }

    final minutes = displaySeconds ~/ 60;
    final seconds = displaySeconds % 60;
    final timeStr = '${RitmoNumber.faInt(minutes)}:${seconds.toString().padLeft(2, '0')}';

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
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
                  icon: const Icon(Icons.close),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('لغو مطالعه', style: TextStyle(fontWeight: FontWeight.bold)),
                        content: const Text('آیا می‌خواهید این جلسه مطالعه را بدون ذخیره لغو کنید؟'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('خیر')),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            child: const Text('بله، لغو شود', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await StudyTimerService.instance.cancelSession();
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Timer Mode Switcher
            SegmentedButton<TimerModeType>(
              segments: const [
                ButtonSegment(value: TimerModeType.stopwatch, label: Text('کرونومتر آزاد', style: TextStyle(fontSize: 11))),
                ButtonSegment(value: TimerModeType.pomodoro25, label: Text('پومودورو ۲۵/۵', style: TextStyle(fontSize: 11))),
                ButtonSegment(value: TimerModeType.pomodoro50, label: Text('پومودورو ۵۰/۱۰', style: TextStyle(fontSize: 11))),
              ],
              selected: {_timerMode},
              onSelectionChanged: (set) => _onTimerModeChanged(set.first),
            ),
            const SizedBox(height: 16),
            if (isPomodoro) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isBreak ? Colors.green.withValues(alpha: 0.15) : colors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isBreak ? Icons.coffee_rounded : Icons.psychology_rounded,
                      size: 16,
                      color: isBreak ? Colors.green : colors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isBreak
                          ? 'فاز استراحت'
                          : 'فاز تمرکز (دور ${RitmoNumber.faInt(_state?.pomodoroCycle ?? 1)} از ۴)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isBreak ? Colors.green : colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            // Timer Circle Display
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isBreak
                    ? Colors.green.withValues(alpha: 0.1)
                    : colors.primary.withValues(alpha: 0.1),
                border: Border.all(
                  color: isBreak ? Colors.green : colors.primary,
                  width: 4,
                ),
              ),
              child: Center(
                child: Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: isBreak ? Colors.green : colors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Controls Row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  iconSize: 44,
                  icon: Icon(
                    isPaused ? Icons.play_circle_fill : Icons.pause_circle_filled,
                    color: isBreak ? Colors.green : colors.primary,
                  ),
                  onPressed: () {
                    if (isPaused) {
                      StudyTimerService.instance.resumeSession();
                    } else {
                      StudyTimerService.instance.pauseSession();
                    }
                  },
                ),
                if (isPomodoro) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    iconSize: 36,
                    tooltip: isBreak ? 'شروع تمرکز بعدی' : 'شروع استراحت',
                    icon: Icon(Icons.skip_next_rounded, color: colors.textSecondary),
                    onPressed: _togglePomodoroPhase,
                  ),
                ],
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _finishSession,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.success,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                  label: const Text('پایان جلسه', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // In-Session Scratchpad
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'یادداشت سریع حین مطالعه (نکات، سوالات و صفحات)',
                hintText: 'مثلاً: حل تست‌های مبحث کار و انرژی، نیاز به مرور فرمول پتانسیل',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),
            // Test Performance Tracking Collapsible
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Row(
                  children: [
                    Icon(Icons.checklist_rounded, size: 18, color: _includeTests ? colors.primary : colors.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      'ثبت عملکرد تستی (اختیاری)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _includeTests ? colors.primary : colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                trailing: Switch(
                  value: _includeTests,
                  onChanged: (val) => setState(() => _includeTests = val),
                  activeTrackColor: colors.primary.withValues(alpha: 0.5),
                ),
                children: [
                  if (_includeTests) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _testsTotalController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'تعداد کل تست',
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
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Feedback Options
            Text('میزان تسلط و کیفیت یادگیری:', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
            const SizedBox(height: 6),
            SegmentedButton<SessionFeedback>(
              segments: const [
                ButtonSegment(value: SessionFeedback.understood, label: Text('فهمیدم', style: TextStyle(fontSize: 11))),
                ButtonSegment(value: SessionFeedback.partial, label: Text('نصفه‌نیمه', style: TextStyle(fontSize: 11))),
                ButtonSegment(value: SessionFeedback.needAgain, label: Text('دوباره', style: TextStyle(fontSize: 11))),
              ],
              selected: {_feedback},
              onSelectionChanged: (set) => setState(() => _feedback = set.first),
            ),
          ],
        ),
      ),
    );
  }
}
