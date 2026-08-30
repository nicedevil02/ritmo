import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/courses/logic/course_timer_service.dart';
import 'package:ritmo/features/courses/models/course_models.dart';
import 'package:ritmo/features/courses/presentation/widgets/course_formatters.dart';
import 'package:ritmo/features/courses/presentation/widgets/session_debrief_sheet.dart';

class StudyTimerSheet extends StatefulWidget {
  const StudyTimerSheet({
    super.key,
    required this.course,
    required this.session,
    required this.onTimerFinished,
  });

  final Course course;
  final CourseSession session;
  final VoidCallback onTimerFinished;

  @override
  State<StudyTimerSheet> createState() => _StudyTimerSheetState();
}

class _StudyTimerSheetState extends State<StudyTimerSheet> with TickerProviderStateMixin {
  late Timer _timer;
  int _secondsElapsed = 0;
  bool _isRunning = true;
  final TextEditingController _noteController = TextEditingController();

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    final activeTimer = CourseTimerService.instance.activeTimer;
    if (activeTimer != null && activeTimer.sessionId == widget.session.id) {
      _secondsElapsed = CourseTimerService.instance.currentElapsedSeconds;
      _isRunning = !activeTimer.isPaused;
    } else if (activeTimer != null) {
      // A timer for a DIFFERENT session is running — never silently discard it.
      _secondsElapsed = 0;
      _isRunning = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _promptActiveTimerConflict();
      });
    } else {
      CourseTimerService.instance.startTimer(widget.course.id, widget.session.id).catchError((Object e, StackTrace st) {
        RitmoLogger.warning(
          'StudyTimerSheet: Failed to start timer for session ${widget.session.id}: $e',
          error: e,
          stack: st,
        );
      });
      _secondsElapsed = 0;
      _isRunning = true;
    }

    if (_isRunning) {
      _pulseController.repeat(reverse: true);
    }

    _startTimer();
  }

  Future<void> _promptActiveTimerConflict() async {
    final startNew = await RitmoDialog.show(
      context,
      title: 'تایمر جلسه دیگری در حال اجراست',
      content: 'یک تایمر مطالعه برای جلسه دیگری فعال است. با شروع این جلسه، تایمر قبلی پاک می‌شود. ادامه می‌دهید؟',
      confirmLabel: 'شروع این جلسه',
      cancelLabel: 'انصراف',
    );

    if (!mounted) return;
    if (startNew == true) {
      await CourseTimerService.instance.startTimer(widget.course.id, widget.session.id);
      setState(() {
        _secondsElapsed = 0;
        _isRunning = true;
      });
      unawaited(_pulseController.repeat(reverse: true));
    } else {
      Navigator.pop(context);
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_isRunning) {
        setState(() {
          _secondsElapsed = CourseTimerService.instance.currentElapsedSeconds;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulseController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    final hrs = totalSeconds ~/ 3600;
    final mins = (totalSeconds % 3600) ~/ 60;
    final secs = totalSeconds % 60;

    final hrsStr = hrs.toString().padLeft(2, '0');
    final minsStr = mins.toString().padLeft(2, '0');
    final secsStr = secs.toString().padLeft(2, '0');

    if (hrs > 0) {
      return '$hrsStr:$minsStr:$secsStr';
    }
    return '$minsStr:$secsStr';
  }

  void _togglePlayPause() {
    setState(() {
      _isRunning = !_isRunning;
      if (_isRunning) {
        CourseTimerService.instance.resumeTimer();
        _pulseController.repeat(reverse: true);
      } else {
        CourseTimerService.instance.pauseTimer(_secondsElapsed);
        _pulseController.stop();
      }
    });
  }

  Future<void> _finishSession() async {
    // Check for short session (<30 seconds) to avoid polluting analytics (Fixes M10)
    if (_secondsElapsed < 30) {
      final confirmShort = await RitmoDialog.show(
        context,
        title: 'جلسه بسیار کوتاه',
        content: 'مدت زمان مطالعه شما کمتر از ۳۰ ثانیه است (${toPersianDigits(_secondsElapsed.toString())} ثانیه). آیا مایل به ثبت این جلسه هستید؟',
        confirmLabel: 'ثبت جلسه',
        cancelLabel: 'ادامه تایمر',
      );
      if (confirmShort != true || !mounted) return;
    }

    final roundedMinutes = CourseDurationFormat.minutesFromSeconds(_secondsElapsed);
    final actualDuration = roundedMinutes > 0 ? roundedMinutes : 1;

    await CourseTimerService.instance.stopTimer();
    if (!mounted) return;
    Navigator.pop(context);
    widget.onTimerFinished();

    unawaited(
      SessionDebriefSheet.show(
        context,
        session: widget.session,
        actualDurationMinutes: actualDuration,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final isGlass = context.isGlassEnabled;
    final blur = context.glassBlurSigma.clamp(0.0, 50.0);
    const sheetRadius = BorderRadius.vertical(top: Radius.circular(30));

    final content = Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: RitmoBreakpoints.sheetMaxHeight(context, factor: 0.6),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Canonical Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Leading (Right in RTL): Circular Tactile Close (X) Button
                GestureDetector(
                  onTap: () {
                    RitmoHapticsPolicy.tap();
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: isDark
                          ? colors.surfaceElevated.withValues(alpha: 0.85)
                          : colors.textPrimary.withValues(alpha: 0.07),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? colors.border.withValues(alpha: 0.35)
                            : colors.border.withValues(alpha: 0.15),
                        width: 0.85,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      CupertinoIcons.xmark,
                      size: 15,
                      color: colors.textSecondary,
                    ),
                  ),
                ),

                // Center: Course Title & Unit Number
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.course.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.course.unitLabelResolved} ${widget.session.sessionNumber}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Trailing (Left in RTL): Symmetrical Spacer
                const SizedBox(width: 34, height: 34),
              ],
            ),

            // Timer Display
            RepaintBoundary(
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.98, end: 1.02).animate(_pulseController),
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        colors.primary.withValues(alpha: 0.2),
                        colors.primary.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: _isRunning ? 0.6 : 0.2),
                      width: 3,
                    ),
                    boxShadow: [
                      if (_isRunning)
                        BoxShadow(
                          color: colors.primary.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        toPersianDigits(_formatTime(_secondsElapsed)),
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isRunning ? 'در حال مطالعه...' : 'متوقف شده',
                        style: TextStyle(
                          fontSize: 12,
                          color: _isRunning ? colors.success : colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Control Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _togglePlayPause,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRunning ? Colors.amber.shade700 : colors.primary,
                    foregroundColor: colors.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: Icon(_isRunning ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill, size: 20, color: colors.onPrimary),
                  label: Text(
                    _isRunning ? 'مکس' : 'ادامه',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.onPrimary),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _finishSession,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.success,
                    foregroundColor: colors.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: Icon(CupertinoIcons.checkmark_alt, size: 20, color: colors.onPrimary),
                  label: Text(
                    'اتمام جلسه',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.onPrimary),
                  ),
                ),
              ],
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

    if (!isGlass) {
      return Container(
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
    }

    return ClipRRect(
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
}
