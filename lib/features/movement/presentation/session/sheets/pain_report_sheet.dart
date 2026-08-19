import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

class PainReportData {
  const PainReportData({
    required this.severity,
    required this.location,
    required this.shouldStopSession,
  });

  final int severity;
  final String location;
  final bool shouldStopSession;
}

/// شیت گزارش درد ورزشی بدون هرگونه ادعای پزشکی/تشخیصی با تمرکز بر مدیریت فوری فشار
class PainReportSheet extends StatefulWidget {
  const PainReportSheet({super.key, required this.onSubmitReport});

  final ValueChanged<PainReportData> onSubmitReport;

  static Future<PainReportData?> show(BuildContext context) {
    return showModalBottomSheet<PainReportData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PainReportSheet(
        onSubmitReport: (data) => Navigator.of(ctx).pop(data),
      ),
    );
  }

  @override
  State<PainReportSheet> createState() => _PainReportSheetState();
}

class _PainReportSheetState extends State<PainReportSheet> {
  int _severity = 3;
  String _selectedLocation = 'زانوی راست';

  static const List<String> _locations = [
    'زانوی راست',
    'زانوی چپ',
    'مچ پا / ساق',
    'پایین کمر',
    'شانه و کتف',
    'گردن',
    'مچ دست',
    'عضلات ران',
    'سایر نواحی',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isHighSeverity = _severity >= 4;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(RitmoRadius.sheet),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: RitmoSpacing.lg,
        vertical: RitmoSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: MovementLayout.kSheetHandleSize.width,
              height: MovementLayout.kSheetHandleSize.height,
              decoration: BoxDecoration(
                color: colors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: RitmoSpacing.lg),

          Row(
            children: [
              Icon(Icons.healing_rounded, color: colors.warning, size: 24),
              const SizedBox(width: RitmoSpacing.sm),
              Text(
                MovementStrings.sessionPainTitle,
                style: RitmoTextStyles.sectionHeadline(colors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'حرکت را فعلاً متوقف کن تا از سلامت مفاصل و عضلاتت اطمینان حاصل کنیم.',
            style: RitmoTextStyles.caption(colors.textSecondary),
          ),
          const SizedBox(height: RitmoSpacing.lg),

          // شدت درد ۱ تا ۵
          Text(
            '${MovementStrings.painReportSeverity}: ${toPersianDigits(_severity)} از ۵',
            style: RitmoTextStyles.body(
              colors.textPrimary,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: RitmoSpacing.sm),
          Row(
            children: List.generate(5, (i) {
              final level = i + 1;
              final isSel = _severity == level;
              final color = level >= 4 ? colors.error : colors.warning;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: ElevatedButton(
                    onPressed: () => setState(() => _severity = level),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSel ? color : colors.surfaceSunken,
                      foregroundColor: isSel
                          ? Colors.white
                          : colors.textPrimary,
                      elevation: 0,
                      side: BorderSide(color: isSel ? color : colors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(RitmoRadius.field),
                      ),
                    ),
                    child: Text(
                      toPersianDigits(level),
                      style: RitmoTextStyles.label(
                        isSel ? Colors.white : colors.textPrimary,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: RitmoSpacing.lg),

          // محل تقریبی درد
          Text(
            MovementStrings.painReportLocation,
            style: RitmoTextStyles.body(
              colors.textPrimary,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: RitmoSpacing.sm),
          Wrap(
            spacing: RitmoSpacing.xs,
            runSpacing: RitmoSpacing.xs,
            children: _locations.map((loc) {
              final isSel = _selectedLocation == loc;
              return ChoiceChip(
                label: Text(loc),
                selected: isSel,
                onSelected: (sel) {
                  if (sel) setState(() => _selectedLocation = loc);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: RitmoSpacing.lg),

          // کادر توصیه سازگار
          Container(
            padding: const EdgeInsets.all(RitmoSpacing.md),
            decoration: BoxDecoration(
              color: (isHighSeverity ? colors.error : colors.warning)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(RitmoRadius.card),
              border: Border.all(
                color: (isHighSeverity ? colors.error : colors.warning)
                    .withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              isHighSeverity
                  ? MovementStrings.painReportFinishAdvice
                  : MovementStrings.painReportLowAdvice,
              style: RitmoTextStyles.body(colors.textPrimary),
            ),
          ),
          const SizedBox(height: RitmoSpacing.xl),

          // دکمهٔ ثبت گزارش
          SizedBox(
            width: double.infinity,
            height: MovementLayout.kFieldMinHeight,
            child: ElevatedButton(
              onPressed: () {
                widget.onSubmitReport(
                  PainReportData(
                    severity: _severity,
                    location: _selectedLocation,
                    shouldStopSession: isHighSeverity,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isHighSeverity ? colors.error : colors.warning,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(RitmoRadius.field),
                ),
              ),
              child: Text(
                isHighSeverity
                    ? 'پایان تمرین و ثبت گزارش'
                    : MovementStrings.painReportSubmit,
                style: RitmoTextStyles.label(Colors.white),
              ),
            ),
          ),
          const SizedBox(height: RitmoSpacing.lg),
        ],
      ),
    );
  }
}
