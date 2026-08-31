import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_date.dart';
import 'package:ritmo/features/goals/logic/goal_planning_quick_parser.dart';
import 'package:ritmo/features/goals/logic/planning_controller.dart';
import 'package:ritmo/features/goals/logic/planning_repository.dart';
import 'package:ritmo/features/goals/models/planning_models.dart';
import 'package:shamsi_date/shamsi_date.dart';

/// نوار ثبت سریع متنی برای برنامه‌ریزی هفته با موتور تجزیه آفلاین زبان فارسی
class QuickCapturePlanningBar extends StatefulWidget {
  const QuickCapturePlanningBar({
    super.key,
    required this.controller,
    required this.colors,
    required this.isDark,
    this.onCommitted,
  });

  final PlanningController controller;
  final RitmoColors colors;
  final bool isDark;
  final VoidCallback? onCommitted;

  @override
  State<QuickCapturePlanningBar> createState() => _QuickCapturePlanningBarState();
}

class _QuickCapturePlanningBarState extends State<QuickCapturePlanningBar> {
  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final GoalPlanningQuickParser _parser = const GoalPlanningQuickParser();

  QuickPlanningParseResult? _parseResult;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _textCtrl.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textCtrl.removeListener(_onTextChanged);
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      if (_parseResult != null) {
        setState(() => _parseResult = null);
      }
      return;
    }

    final res = _parser.parse(
      text,
      defaultDayKey: widget.controller.capacities.isNotEmpty
          ? widget.controller.capacities.first.dayKey
          : null,
    );
    setState(() => _parseResult = res);
  }

  Future<void> _submit() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    final cycle = widget.controller.activeCycle;
    if (cycle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ابتدا برنامهٔ این هفته را فعال یا ایجاد کنید ⚠️'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    await HapticFeedback.mediumImpact();

    try {
      final parsed = _parseResult ?? _parser.parse(text);
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final commId = 'comm_${nowMs}_${DateTime.now().microsecondsSinceEpoch}';

      final commitment = PlanningCommitment(
        id: commId,
        cycleId: cycle.id,
        title: parsed.cleanTitle,
        sourceType: CommitmentSourceType.manual,
        importance: parsed.importance,
        flexibility: CommitmentFlexibility.flexible,
        effortMinutes: parsed.durationMinutes,
        workKind: parsed.durationMinutes >= 45 ? WorkKind.deep : WorkKind.light,
        status: CommitmentStatus.accepted,
        origin: 'USER',
        createdAt: nowMs,
        updatedAt: nowMs,
      );

      await PlanningRepository.instance.upsertCommitment(commitment);

      final allocId = 'alloc_${nowMs}_${DateTime.now().microsecondsSinceEpoch}';
      final allocation = PlanningAllocation(
        id: allocId,
        commitmentId: commId,
        dayKey: parsed.dayKey,
        plannedMinutes: parsed.durationMinutes,
        status: AllocationStatus.planned,
        idempotencyKey: 'quick_alloc_$commId|${parsed.dayKey}',
        createdAt: nowMs,
        updatedAt: nowMs,
      );

      await PlanningRepository.instance.insertAllocation(allocation);

      RitmoEventBus().fire(RitmoEvent(
        type: 'commitmentChanged',
        timestamp: DateTime.now(),
        payload: {'cycleId': cycle.id, 'commitmentId': commId},
      ));

      _textCtrl.clear();
      _focusNode.unfocus();
      setState(() {
        _parseResult = null;
        _isSubmitting = false;
      });

      widget.onCommitted?.call();

      if (mounted) {
        final dt = RitmoDate.tryParseDayKey(parsed.dayKey) ?? DateTime.now();
        final j = Jalali.fromDateTime(dt);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('«${parsed.cleanTitle}» برای روز ${j.day} ${_persianMonthName(j.month)} ثبت شد ✅'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در ثبت: $e')),
        );
      }
    }
  }

  static String _persianMonthName(int m) {
    const names = [
      'فروردین', 'اردیبهشت', 'خرداد',
      'تیر', 'مرداد', 'شهریور',
      'مهر', 'آبان', 'آذر',
      'دی', 'بهمن', 'اسفند'
    ];
    if (m >= 1 && m <= 12) return names[m - 1];
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final parsed = _parseResult;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(RitmoRadius.card),
          border: Border.all(
            color: colors.border.withValues(alpha: 0.25),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: widget.isDark ? 0.2 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Preview chips if parsed
            if (parsed != null && _textCtrl.text.trim().isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  // Day chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'روز: ${parsed.matchedDayLabel ?? parsed.dayKey}',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: colors.primary),
                    ),
                  ),

                  // Duration chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: colors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'مدت: ${PersianDigits.toPersian(parsed.durationMinutes.toString())} دقیقه',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: colors.success),
                    ),
                  ),

                  // Importance chip
                  if (parsed.importance == CommitmentImportance.must)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: colors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'اولویت فوری',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: colors.error),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Input Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    focusNode: _focusNode,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    style: TextStyle(fontSize: 13, color: colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'ثبت سریع: مثلاً مطالعه فصل ۲ فردا ۱ ساعت…',
                      hintStyle: TextStyle(fontSize: 12, color: colors.textSecondary.withValues(alpha: 0.7)),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                _isSubmitting
                    ? const CupertinoActivityIndicator(radius: 10)
                    : InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _submit,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _textCtrl.text.trim().isNotEmpty
                                ? colors.primary
                                : colors.textSecondary.withValues(alpha: 0.15),
                          ),
                          child: Icon(
                            CupertinoIcons.arrow_up,
                            size: 16,
                            color: _textCtrl.text.trim().isNotEmpty
                                ? Colors.white
                                : colors.textSecondary,
                          ),
                        ),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
