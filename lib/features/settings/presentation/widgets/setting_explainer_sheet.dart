import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/settings/settings_registry.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';

class SettingExplainerSheet extends StatelessWidget {
  const SettingExplainerSheet({
    super.key,
    required this.descriptor,
  });

  final SettingDescriptor descriptor;

  static Future<void> show(BuildContext context, SettingDescriptor descriptor) {
    RitmoHaptics.sheetOpen();
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SettingExplainerSheet(descriptor: descriptor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final why = descriptor.whyExplanationFa ?? descriptor.descriptionFa ?? 'اطلاعات بیشتری برای این تنظیم ثبت نشده است.';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          top: 16,
          left: 20,
          right: 20,
        ),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(CupertinoIcons.question_circle_fill, color: colors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        descriptor.labelFa,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'راهنمای رفتاری و علمی تنظیم',
                        style: TextStyle(fontSize: 12, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(CupertinoIcons.lightbulb_fill, color: colors.primary, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'چرا این تنظیم وجود دارد؟',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    why,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (descriptor.affectsAgenda) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(CupertinoIcons.checkmark_seal_fill, color: colors.secondary, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'این تنظیم مستقیماً روی چیدمان هوشمند بلوک‌های تقویم و کارهای روزانه اثر می‌گذارد.',
                      style: TextStyle(fontSize: 11, color: colors.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const ValueKey('explainer_sheet_close_button'),
                onPressed: () {
                  RitmoHaptics.selection();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'متوجه شدم',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
