import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/engines/ritmo_break_mobility_engine.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/util/ritmo_number.dart';

/// Modal bottom sheet providing an authentic, guided 2-minute desk mobility stretching session.
class StudyBreakMobilityPlayerSheet extends StatefulWidget {
  final List<BreakMobilityExercise> exercises;

  const StudyBreakMobilityPlayerSheet({
    super.key,
    required this.exercises,
  });

  static Future<void> show(
    BuildContext context, {
    required List<BreakMobilityExercise> exercises,
  }) {
    if (exercises.isEmpty) return Future.value();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StudyBreakMobilityPlayerSheet(exercises: exercises),
    );
  }

  @override
  State<StudyBreakMobilityPlayerSheet> createState() =>
      _StudyBreakMobilityPlayerSheetState();
}

class _StudyBreakMobilityPlayerSheetState
    extends State<StudyBreakMobilityPlayerSheet> {
  int _currentIndex = 0;
  late int _remainingSeconds;
  bool _isPaused = false;
  Timer? _timer;
  bool _isFinished = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.exercises.isNotEmpty
        ? widget.exercises[0].durationSeconds
        : 30;
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isPaused || _isFinished) return;
      if (_remainingSeconds > 1) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _nextExercise();
      }
    });
  }

  void _nextExercise() {
    RitmoHapticsPolicy.selection();
    if (_currentIndex < widget.exercises.length - 1) {
      setState(() {
        _currentIndex++;
        _remainingSeconds = widget.exercises[_currentIndex].durationSeconds;
      });
    } else {
      _finishAll();
    }
  }

  void _previousExercise() {
    if (_currentIndex > 0) {
      RitmoHapticsPolicy.selection();
      setState(() {
        _currentIndex--;
        _remainingSeconds = widget.exercises[_currentIndex].durationSeconds;
      });
    }
  }

  void _finishAll() {
    _timer?.cancel();
    RitmoHapticsPolicy.success();
    setState(() {
      _isFinished = true;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final currentEx = widget.exercises.isNotEmpty
        ? widget.exercises[_currentIndex]
        : const BreakMobilityExercise(
            id: 'default',
            nameFa: 'کشش ملایم',
            descriptionFa: 'چند نفس عمیق بکشید و عضلات را شل کنید.',
            targetArea: 'گردن و شانه',
          );

    final totalEx = widget.exercises.length;
    final progress = currentEx.durationSeconds > 0
        ? 1.0 - (_remainingSeconds / currentEx.durationSeconds)
        : 1.0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: RitmoBreakpoints.sheetMaxHeight(context, factor: 0.85),
        ),
        child: RitmoGlassSheet(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Top Drag Handle
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),

              // 2. Symmetrical Header Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Close (X)
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
                            color: colors.border.withValues(alpha: 0.35),
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

                    // Title
                    Text(
                      _isFinished
                          ? 'پایان کشش استراحت ✨'
                          : 'کشش رفع خستگی مطالعه',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),

                    // Counter badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _isFinished
                            ? 'انجام شد'
                            : '${RitmoNumber.faInt(_currentIndex + 1)} از ${RitmoNumber.faInt(totalEx)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Divider(color: colors.border.withValues(alpha: 0.3), height: 1),

              // 3. Main Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: _isFinished
                      ? _buildFinishedView(context)
                      : _buildActiveExerciseView(
                          context,
                          currentEx,
                          progress,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveExerciseView(
    BuildContext context,
    BreakMobilityExercise ex,
    double progress,
  ) {
    final colors = context.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Target Area Chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(ex.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                ex.targetArea,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Countdown Dial with Circular Progress
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 140,
              height: 140,
              child: CircularProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                strokeWidth: 8,
                backgroundColor: colors.border.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                strokeCap: StrokeCap.round,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  RitmoNumber.faInt(_remainingSeconds),
                  style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  'ثانیه',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Exercise Name
        Text(
          ex.nameFa,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),

        // Instructions
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surfaceElevated.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border.withValues(alpha: 0.3)),
          ),
          child: Text(
            ex.descriptionFa,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: colors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Playback Controls Row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Previous button
            IconButton.filledTonal(
              icon: const Icon(Icons.skip_previous_rounded),
              iconSize: 24,
              tooltip: 'حرکت قبلی',
              onPressed: _currentIndex > 0 ? _previousExercise : null,
            ),
            const SizedBox(width: 16),

            // Play / Pause button
            IconButton.filled(
              icon: Icon(
                _isPaused
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
              ),
              iconSize: 32,
              style: IconButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
              ),
              onPressed: () {
                RitmoHapticsPolicy.tap();
                setState(() {
                  _isPaused = !_isPaused;
                });
              },
            ),
            const SizedBox(width: 16),

            // Next / Skip button
            IconButton.filledTonal(
              icon: const Icon(Icons.skip_next_rounded),
              iconSize: 24,
              tooltip: 'حرکت بعدی',
              onPressed: _nextExercise,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFinishedView(BuildContext context) {
    final colors = context.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Text('🌿', style: TextStyle(fontSize: 36)),
        ),
        const SizedBox(height: 18),
        Text(
          'خداقوت! بدن و ذهن آماده شد ✨',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'گردن و ستون فقرات آزادسازی شد. اکنون می‌توانید با تمرکز بالاتر به دور بعدی پومودورو ادامه دهید.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.6,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 28),
        RitmoNeuButton(
          onTap: () {
            RitmoHapticsPolicy.tap();
            Navigator.pop(context);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            child: Text(
              'بازگشت به تایمر مطالعه',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
