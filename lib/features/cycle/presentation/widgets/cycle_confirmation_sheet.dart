import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/util/ritmo_number.dart';
import 'package:ritmo/core/utils/ritmo_date_picker.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/cycle_confirmation_service.dart';
import 'package:ritmo/features/cycle/models/cycle_confirmation_models.dart';
import 'package:shamsi_date/shamsi_date.dart';

class CycleConfirmationSheet extends StatefulWidget {
  const CycleConfirmationSheet({
    super.key,
    required this.request,
    required this.onAnswered,
  });

  final CycleConfirmationRequest request;
  final VoidCallback onAnswered;

  static Future<void> show({
    required BuildContext context,
    required CycleConfirmationRequest request,
    required VoidCallback onAnswered,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: RitmoBreakpoints.sheetMaxHeight(context, factor: 0.94),
            ),
            child: CycleConfirmationSheet(
              request: request,
              onAnswered: onAnswered,
            ),
          ),
        ),
      ),
    );
  }

  @override
  State<CycleConfirmationSheet> createState() => _CycleConfirmationSheetState();
}

class _CycleConfirmationSheetState extends State<CycleConfirmationSheet> {
  bool _isSubmitting = false;

  bool get _isStartKind =>
      widget.request.kind == CycleConfirmationKind.startDue ||
      widget.request.kind == CycleConfirmationKind.startOverdue;

  bool get _isBleedingProlonged =>
      widget.request.kind == CycleConfirmationKind.bleedingProlonged;

  String _formatJalali(DateTime dt) {
    final j = Jalali.fromDateTime(dt);
    return '${RitmoNumber.faInt(j.year)}/${RitmoNumber.faInt(j.month).padLeft(2, '۰')}/${RitmoNumber.faInt(j.day).padLeft(2, '۰')}';
  }

  Future<void> _submitAnswer(
    CycleConfirmationAnswer answer, {
    DateTime? resolvedDate,
  }) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      await CycleConfirmationService.instance.recordAnswer(
        requestId: widget.request.id,
        answer: answer,
        resolvedDate: resolvedDate,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onAnswered();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _pickCustomDate() async {
    final now = CycleClock.now;

    final picked = await RitmoDatePicker.showJalali(
      context: context,
      initialDate: Jalali.fromDateTime(now),
      firstDate: Jalali.fromDateTime(now.subtract(const Duration(days: 30))),
      lastDate: Jalali.fromDateTime(now),
    );

    if (picked != null) {
      await _submitAnswer(
        _isStartKind
            ? CycleConfirmationAnswer.startedOnOtherDate
            : CycleConfirmationAnswer.endedOnOtherDate,
        resolvedDate: picked.toDateTime(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final title = _isStartKind
        ? 'بازبینی موعد ریتم بدنی'
        : (_isBleedingProlonged
              ? 'بررسی تداوم خونریزی'
              : 'بررسی وضعیت پایان دوره');

    final description = _isStartKind
        ? 'بر اساس میانگین و پیش‌بینی‌ها، موعد ریتم بدنی شما رسیده است. آیا دورهٔ شما آغاز شده است؟'
        : (_isBleedingProlonged
              ? 'مدت خونریزی بیش از میانگین معمول طول کشیده است. آیا خونریزی شما پایان یافته است؟'
              : 'بر اساس میانگین روزهای خونریزی، احتمالاً دورهٔ شما به پایان رسیده است. آیا خونریزی متوقف شده است؟');

    return RitmoGlassSheet(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
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
            const SizedBox(height: 14),

            // Header Row
            Row(
              children: [
                RitmoNeuButton(
                  padding: const EdgeInsets.all(8),
                  radius: 10,
                  onTap: () => Navigator.pop(context),
                  child: Icon(
                    CupertinoIcons.xmark,
                    size: 16,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: RitmoTextStyles.cardTitle(colors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'موعد تخمینی: ${_formatJalali(widget.request.targetDate)}',
                        style: RitmoTextStyles.caption(colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isStartKind
                        ? CupertinoIcons.sparkles
                        : CupertinoIcons.check_mark_circled,
                    color: colors.primary,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Description in sunken well
            RitmoCard.neumorphicSunken(
              padding: const EdgeInsets.all(RitmoSpacing.md),
              child: Text(
                description,
                style: RitmoTextStyles.caption(colors.textPrimary).copyWith(height: 1.55),
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons
            if (_isStartKind) ...[
              RitmoPrimaryButton(
                label: 'بله، امروز شروع شد',
                icon: CupertinoIcons.check_mark,
                onPressed: _isSubmitting
                    ? null
                    : () => _submitAnswer(CycleConfirmationAnswer.startedToday),
              ),
              const SizedBox(height: 10),
              RitmoCard.neumorphic(
                onTap: _isSubmitting ? null : _pickCustomDate,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.calendar, size: 18, color: colors.primary),
                    const SizedBox(width: 10),
                    Text(
                      'از تاریخ دیگری شروع شده',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              RitmoCard.neumorphic(
                onTap: _isSubmitting
                    ? null
                    : () => _submitAnswer(CycleConfirmationAnswer.notStartedYet),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.xmark_circle, size: 18, color: colors.textSecondary),
                    const SizedBox(width: 10),
                    Text(
                      'هنوز شروع نشده',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              RitmoCard.neumorphic(
                onTap: _isSubmitting
                    ? null
                    : () => _submitAnswer(CycleConfirmationAnswer.snoozed),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.clock, size: 18, color: colors.textSecondary),
                    const SizedBox(width: 10),
                    Text(
                      'یادآوری فردا',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              RitmoPrimaryButton(
                label: 'بله، امروز تمام شد',
                icon: CupertinoIcons.check_mark,
                onPressed: _isSubmitting
                    ? null
                    : () => _submitAnswer(CycleConfirmationAnswer.endedToday),
              ),
              const SizedBox(height: 10),
              RitmoCard.neumorphic(
                onTap: _isSubmitting ? null : _pickCustomDate,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.calendar, size: 18, color: colors.primary),
                    const SizedBox(width: 10),
                    Text(
                      'در تاریخ دیگری تمام شده',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              RitmoCard.neumorphic(
                onTap: _isSubmitting
                    ? null
                    : () => _submitAnswer(CycleConfirmationAnswer.stillOngoing),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.arrow_clockwise, size: 18, color: colors.textSecondary),
                    const SizedBox(width: 10),
                    Text(
                      'هنوز ادامه دارد',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              RitmoCard.neumorphic(
                onTap: _isSubmitting
                    ? null
                    : () => _submitAnswer(CycleConfirmationAnswer.snoozed),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.clock, size: 18, color: colors.textSecondary),
                    const SizedBox(width: 10),
                    Text(
                      'یادآوری فردا',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
