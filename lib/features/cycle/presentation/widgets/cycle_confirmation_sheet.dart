import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
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
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => CycleConfirmationSheet(
            request: request,
            onAnswered: onAnswered,
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

  String _formatJalali(DateTime dt) {
    final j = Jalali.fromDateTime(dt);
    return '${PersianDigits.toFa(j.year.toString())}/${PersianDigits.toFa(j.month.toString().padLeft(2, '0'))}/${PersianDigits.toFa(j.day.toString().padLeft(2, '0'))}';
  }

  Future<void> _submitAnswer(
    CycleConfirmationAnswer answer, {
    DateTime? resolvedDate,
  }) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    await CycleConfirmationService.instance.recordAnswer(
      requestId: widget.request.id,
      answer: answer,
      resolvedDate: resolvedDate,
    );

    if (mounted) {
      Navigator.pop(context);
      widget.onAnswered();
    }
  }

  Future<void> _pickCustomDate() async {
    final now = CycleClock.now;

    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now,
      helpText: _isStartKind ? 'انتخاب تاریخ شروع' : 'انتخاب تاریخ پایان',
      confirmText: 'تأیید',
      cancelText: 'انصراف',
    );

    if (picked != null) {
      await _submitAnswer(
        _isStartKind
            ? CycleConfirmationAnswer.startedOnOtherDate
            : CycleConfirmationAnswer.endedOnOtherDate,
        resolvedDate: picked,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final title =
        _isStartKind ? 'بازبینی موعد ریتم بدنی' : 'بررسی وضعیت پایان دوره';

    final description =
        _isStartKind
            ? 'بر اساس میانگین و پیش‌بینی‌ها، موعد ریتم بدنی شما رسیده است. آیا دورهٔ شما آغاز شده است؟'
            : 'بر اساس میانگین روزهای خونریزی، احتمالاً دورهٔ شما به پایان رسیده است. آیا خونریزی متوقف شده است؟';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: colors.border),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isStartKind
                        ? CupertinoIcons.sparkles
                        : CupertinoIcons.check_mark_circled,
                    color: colors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'موعد تخمینی: ${_formatJalali(widget.request.targetDate)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(CupertinoIcons.xmark, color: colors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Description
            Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: colors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            if (_isStartKind) ...[
              _buildActionButton(
                label: 'بله، امروز شروع شد',
                icon: CupertinoIcons.check_mark,
                isPrimary: true,
                onTap: () => _submitAnswer(CycleConfirmationAnswer.startedToday),
              ),
              const SizedBox(height: 10),
              _buildActionButton(
                label: 'از تاریخ دیگری شروع شده',
                icon: CupertinoIcons.calendar,
                isPrimary: false,
                onTap: _pickCustomDate,
              ),
              const SizedBox(height: 10),
              _buildActionButton(
                label: 'هنوز شروع نشده',
                icon: CupertinoIcons.xmark_circle,
                isPrimary: false,
                onTap: () => _submitAnswer(CycleConfirmationAnswer.notStartedYet),
              ),
              const SizedBox(height: 10),
              _buildActionButton(
                label: 'یادآوری فردا',
                icon: CupertinoIcons.clock,
                isPrimary: false,
                onTap: () => _submitAnswer(CycleConfirmationAnswer.snoozed),
              ),
            ] else ...[
              _buildActionButton(
                label: 'بله، امروز تمام شد',
                icon: CupertinoIcons.check_mark,
                isPrimary: true,
                onTap: () => _submitAnswer(CycleConfirmationAnswer.endedToday),
              ),
              const SizedBox(height: 10),
              _buildActionButton(
                label: 'در تاریخ دیگری تمام شده',
                icon: CupertinoIcons.calendar,
                isPrimary: false,
                onTap: _pickCustomDate,
              ),
              const SizedBox(height: 10),
              _buildActionButton(
                label: 'هنوز ادامه دارد',
                icon: CupertinoIcons.arrow_clockwise,
                isPrimary: false,
                onTap: () => _submitAnswer(CycleConfirmationAnswer.stillOngoing),
              ),
              const SizedBox(height: 10),
              _buildActionButton(
                label: 'یادآوری فردا',
                icon: CupertinoIcons.clock,
                isPrimary: false,
                onTap: () => _submitAnswer(CycleConfirmationAnswer.snoozed),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;

    if (isPrimary) {
      return ElevatedButton.icon(
        onPressed: _isSubmitting ? null : onTap,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: _isSubmitting ? null : onTap,
      icon: Icon(icon, size: 18, color: colors.textPrimary),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: colors.border),
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
