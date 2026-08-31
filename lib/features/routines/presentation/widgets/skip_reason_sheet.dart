import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/services/motivation_diagnosis_service.dart';

class SkipReasonSheet extends StatelessWidget {
  const SkipReasonSheet({
    super.key,
    required this.routineId,
    required this.completionId,
    required this.dateStr,
  });

  final String routineId;
  final String completionId;
  final String dateStr;

  static Future<void> show(
    BuildContext context, {
    required String routineId,
    required String completionId,
    required String dateStr,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SkipReasonSheet(
        routineId: routineId,
        completionId: completionId,
        dateStr: dateStr,
      ),
    );
  }

  Future<void> _selectReason(BuildContext context, SkipReasonType reason) async {
    await MotivationDiagnosisService.instance.recordSkipReason(
      completionId: completionId,
      routineId: routineId,
      reason: reason,
      dateStr: dateStr,
    );

    if (!context.mounted) return;
    Navigator.pop(context);

    final action = MotivationDiagnosisService.instance.getActionForReason(reason);
    final title = action['title'] as String?;
    final desc = action['description'] as String?;

    if (title != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$title: $desc', style: const TextStyle(fontSize: 12)),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final options = [
      {'label': 'خسته بودم', 'reason': SkipReasonType.tired, 'icon': Icons.battery_charging_full_rounded},
      {'label': 'نمی‌دانستم از کجا شروع کنم', 'reason': SkipReasonType.noStartPoint, 'icon': Icons.help_outline_rounded},
      {'label': 'خیلی بزرگ بود', 'reason': SkipReasonType.tooBig, 'icon': Icons.fitness_center_rounded},
      {'label': 'حوصله نداشتم', 'reason': SkipReasonType.notInMood, 'icon': Icons.sentiment_dissatisfied_rounded},
      {'label': 'یادم رفت', 'reason': SkipReasonType.forgot, 'icon': Icons.notifications_paused_rounded},
      {'label': 'بیرونی بود (مهمان، سفر، کار)', 'reason': SkipReasonType.external, 'icon': Icons.flight_takeoff_rounded},
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RitmoGlassSheet(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4.5,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: colors.textSecondary.withValues(alpha: isDark ? 0.30 : 0.22),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('علت انجام نشدن؟', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: colors.textPrimary)),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('فعلاً نه', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...options.map((opt) {
              final reason = opt['reason'] as SkipReasonType;
              final label = opt['label'] as String;
              final icon = opt['icon'] as IconData;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: colors.card.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.border.withValues(alpha: 0.25)),
                ),
                child: ListTile(
                  leading: Icon(icon, color: colors.primary, size: 22),
                  title: Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: colors.textPrimary)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  onTap: () => _selectReason(context, reason),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
