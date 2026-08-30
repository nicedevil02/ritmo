import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/features/goals/logic/planning_repository.dart';
import 'package:ritmo/features/goals/logic/planning_review_calculator.dart';
import 'package:ritmo/features/goals/logic/planning_review_repository.dart';
import 'package:ritmo/features/goals/models/planning_models.dart';

/// شیت مرور پایان هفته (V-02)
/// قانون متنی مطلق (V-07): تحلیل برنامه، نه قضاوت کاربر.
class WeekReviewSheet extends StatefulWidget {
  const WeekReviewSheet({
    super.key,
    required this.cycle,
    required this.allocations,
    required this.commitments,
    required this.onClosed,
  });

  final PlanningCycle cycle;
  final List<PlanningAllocation> allocations;
  final List<PlanningCommitment> commitments;
  final VoidCallback onClosed;

  static void show(
    BuildContext context, {
    required PlanningCycle cycle,
    required List<PlanningAllocation> allocations,
    required List<PlanningCommitment> commitments,
    required VoidCallback onClosed,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.94,
        minChildSize: 0.0,
        maxChildSize: 0.94,
        snap: true,
        snapSizes: const [0.0, 0.94],
        expand: false,
        builder: (context, scrollController) => WeekReviewSheet(
          cycle: cycle,
          allocations: allocations,
          commitments: commitments,
          onClosed: onClosed,
        ),
      ),
    );
  }

  @override
  State<WeekReviewSheet> createState() => _WeekReviewSheetState();
}

class _WeekReviewSheetState extends State<WeekReviewSheet> {
  final TextEditingController _q1Controller = TextEditingController();
  final TextEditingController _q2Controller = TextEditingController();
  final TextEditingController _q3Controller = TextEditingController();
  bool _isSaving = false;

  late final CycleReviewStats _stats;
  late final List<String> _frequentlyMovedTitles;

  @override
  void initState() {
    super.initState();
    _calculateStats();
  }

  @override
  void dispose() {
    _q1Controller.dispose();
    _q2Controller.dispose();
    _q3Controller.dispose();
    super.dispose();
  }

  void _calculateStats() {
    int plannedMin = 0;
    int completedMin = 0;
    int movedMin = 0;
    int droppedMin = 0;

    final movedCountPerCommitment = <String, int>{};

    for (final a in widget.allocations) {
      plannedMin += a.plannedMinutes;
      if (a.status == AllocationStatus.done) {
        completedMin += a.plannedMinutes;
      } else if (a.status == AllocationStatus.moved) {
        movedMin += a.plannedMinutes;
        movedCountPerCommitment[a.commitmentId] = (movedCountPerCommitment[a.commitmentId] ?? 0) + 1;
      } else if (a.status == AllocationStatus.dropped) {
        droppedMin += a.plannedMinutes;
      }
    }

    const calc = PlanningReviewCalculator();
    _stats = calc.compute(
      plannedMinutes: plannedMin,
      completedMinutes: completedMin,
      movedMinutes: movedMin,
      droppedMinutes: droppedMin,
    );

    _frequentlyMovedTitles = [];
    for (final entry in movedCountPerCommitment.entries) {
      if (entry.value >= 2) {
        final c = widget.commitments.firstWhere(
          (item) => item.id == entry.key,
          orElse: () => const PlanningCommitment(
            id: '',
            cycleId: '',
            title: 'تعهد',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
        if (c.title.isNotEmpty) {
          _frequentlyMovedTitles.add(c.title);
        }
      }
    }
  }

  Future<void> _submitReview() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final nowMs = now.millisecondsSinceEpoch;

      final answers = {
        'whatWentWell': _q1Controller.text.trim(),
        'whatWasLeft': _q2Controller.text.trim(),
        'nextWeekSmallChange': _q3Controller.text.trim(),
      };

      final review = PlanningReviewItem(
        id: 'review_${widget.cycle.id}_$nowMs',
        cycleId: widget.cycle.id,
        reviewType: 'END_CYCLE',
        plannedMinutes: _stats.plannedMinutes,
        completedMinutes: _stats.completedMinutes,
        movedMinutes: _stats.movedMinutes,
        droppedMinutes: _stats.droppedMinutes,
        unplannedCompletedMinutes: 0,
        calibrationScore: _stats.calibrationScore,
        answersJson: jsonEncode(answers),
        createdAt: nowMs,
      );

      await PlanningReviewRepository.instance.saveReview(review);
      await PlanningRepository.instance.closeCycle(widget.cycle.id, nowMs: nowMs);

      if (!mounted) return;
      Navigator.pop(context);
      widget.onClosed();
      RitmoToast.show(context, 'مرور هفته ثبت و چرخه با موفقیت بسته شد 🌱');
    } catch (e) {
      debugPrint('[WeekReviewSheet] error: $e');
      if (mounted) {
        RitmoToast.show(context, 'خطا در ثبت مرور هفته ❌');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const sheetRadius = BorderRadius.vertical(top: Radius.circular(28));

    final content = Column(
      children: [
        // Handle
        Center(
          child: Container(
            width: 38,
            height: 4.5,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: colors.textSecondary.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),

        // Canonical Header Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Leading (Right in RTL): Circular Tactile Close (X) Button
              GestureDetector(
                onTap: () {
                  RitmoHaptics.tap();
                  Navigator.of(context).pop();
                },
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? colors.surfaceElevated.withValues(alpha: 0.85)
                        : colors.textPrimary.withValues(alpha: 0.07),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
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

              // Center: Title + Subtitle
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'مرور و بازتاب پایان هفته 🌿',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'تحلیل و تنظیم ظرفیت هفته‌های آینده',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Trailing (Left in RTL): 34x34 spacer
              const SizedBox(width: 34, height: 34),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Numerical Summary
                RitmoCard.neumorphicSunken(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'انجام‌شده:',
                            style: TextStyle(
                              fontSize: 13,
                              fontFamily: 'Vazirmatn',
                              color: colors.textSecondary,
                            ),
                          ),
                          Text(
                            '${toPersianDigits(_stats.completedMinutes.toString())} از ${toPersianDigits(_stats.plannedMinutes.toString())} دقیقه',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Vazirmatn',
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      if (_stats.calibrationScore != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'دقت تخمین برنامه‌ریزی:',
                              style: TextStyle(
                                fontSize: 13,
                                fontFamily: 'Vazirmatn',
                                color: colors.textSecondary,
                              ),
                            ),
                            RitmoCardBadge(
                              label: '${toPersianDigits((_stats.calibrationScore! * 100).round().toString())}٪',
                              color: colors.primary,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                if (_frequentlyMovedTitles.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  RitmoCard.neumorphicSunken(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تعهدات با بیش از دو بار جابه‌جایی:',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'Vazirmatn',
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ..._frequentlyMovedTitles.map((t) => Text(
                              '• $t (نیاز به بازنگری در اندازه یا زمان‌بندی)',
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'Vazirmatn',
                                color: colors.textSecondary,
                              ),
                            )),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // 2. Qualitative Reflection Questions
                _buildQuestionField(
                  'چی خوب پیش رفت؟',
                  _q1Controller,
                  'مثلاً: شروع اول صبح، تمرکز روی درس...',
                  colors,
                ),
                const SizedBox(height: 16),
                _buildQuestionField(
                  'چی جا موند؟',
                  _q2Controller,
                  'مثلاً: روز سه‌شنبه خستگی زیاد شد...',
                  colors,
                ),
                const SizedBox(height: 16),
                _buildQuestionField(
                  'هفتهٔ بعد یک تغییر کوچک؟',
                  _q3Controller,
                  'مثلاً: رزرو ۳۰ دقیقه بافر بین جلسات...',
                  colors,
                ),
              ],
            ),
          ),
        ),

        // CTA Footer
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _isSaving ? null : _submitReview,
                child: _isSaving
                    ? const CupertinoActivityIndicator(color: Colors.white)
                    : const Text(
                        'ثبت مرور و بستن هفته',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: RitmoBreakpoints.sheetMaxHeight(context, factor: 0.9),
          ),
          child: RitmoGlassSheet(
            borderRadius: sheetRadius,
            padding: EdgeInsets.zero,
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionField(
    String question,
    TextEditingController controller,
    String hint,
    RitmoColors colors,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: 2,
          style: TextStyle(
            fontSize: 13,
            color: colors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 12,
              color: colors.textSecondary.withValues(alpha: 0.6),
            ),
            filled: true,
            fillColor: colors.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.border.withValues(alpha: 0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.border.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colors.primary),
            ),
          ),
        ),
      ],
    );
  }
}
