import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_animated_background.dart';

class PregnancySettingsSheet extends StatelessWidget {
  const PregnancySettingsSheet({
    super.key,
    this.onDataReloadNeeded,
    this.onEndPregnancy,
  });

  final VoidCallback? onDataReloadNeeded;
  final VoidCallback? onEndPregnancy;

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onDataReloadNeeded,
    VoidCallback? onEndPregnancy,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RitmoSheetGlassCard(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            top: 16,
          ),
          child: PregnancySettingsSheet(
            onDataReloadNeeded: onDataReloadNeeded,
            onEndPregnancy: onEndPregnancy,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: colors.textPrimary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: colors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'تنظیمات بارداری',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(CupertinoIcons.xmark_circle_fill),
                color: colors.textSecondary.withValues(alpha: 0.6),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: colors.border),
          const SizedBox(height: 12),

          // Section 1: تاریخ و سن بارداری
          _buildSectionHeader(context, 'تاریخ و سن بارداری'),
          const SizedBox(height: 8),
          Divider(height: 16, color: colors.border),

          // Section 2: لحن و نمایش
          _buildSectionHeader(context, 'لحن و نمایش'),
          const SizedBox(height: 8),
          Divider(height: 16, color: colors.border),

          // Section 3: مراقبت‌ها و یادآوری‌ها
          _buildSectionHeader(context, 'مراقبت‌ها و یادآوری‌ها'),
          const SizedBox(height: 8),
          Divider(height: 16, color: colors.border),

          // Section 4: لگدشماری
          _buildSectionHeader(context, 'لگدشماری'),
          const SizedBox(height: 8),
          Divider(height: 16, color: colors.border),

          // Section 5: حریم خصوصی
          _buildSectionHeader(context, 'حریم خصوصی'),
          const SizedBox(height: 8),
          Divider(height: 16, color: colors.border),

          // Section 6: ناحیهٔ خطر
          _buildSectionHeader(context, 'ناحیهٔ خطر'),
          if (onEndPregnancy != null) ...[
            const SizedBox(height: 4),
            InkWell(
              onTap: () {
                Navigator.of(context).pop();
                onEndPregnancy!();
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.exclamationmark_triangle_fill,
                          color: colors.error,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'پایان دوره بارداری و بازگشت به چرخه',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: colors.error,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      CupertinoIcons.chevron_left,
                      color: colors.error,
                      size: 14,
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
