import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// شیت فرمان مرکزی افزودن و شروع فعالیت در مرکز حرکت
class AddCommandSheet extends StatelessWidget {
  const AddCommandSheet({
    super.key,
    required this.onStartNow,
    required this.onAddToPlan,
    required this.onRetroLog,
    this.onResumeLiveSession,
    this.onUseTemplate,
    this.onStrengthHome,
    this.hasActiveLiveSession = false,
    this.hasTemplates = false,
    this.hasActiveStrengthProgram = false,
  });

  final VoidCallback onStartNow;
  final VoidCallback onAddToPlan;
  final VoidCallback onRetroLog;
  final VoidCallback? onResumeLiveSession;
  final VoidCallback? onUseTemplate;
  final VoidCallback? onStrengthHome;
  final bool hasActiveLiveSession;
  final bool hasTemplates;
  final bool hasActiveStrengthProgram;

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onStartNow,
    required VoidCallback onAddToPlan,
    required VoidCallback onRetroLog,
    VoidCallback? onResumeLiveSession,
    VoidCallback? onUseTemplate,
    VoidCallback? onStrengthHome,
    bool hasActiveLiveSession = false,
    bool hasTemplates = false,
    bool hasActiveStrengthProgram = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddCommandSheet(
        onStartNow: () {
          Navigator.of(ctx).pop();
          onStartNow();
        },
        onAddToPlan: () {
          Navigator.of(ctx).pop();
          onAddToPlan();
        },
        onRetroLog: () {
          Navigator.of(ctx).pop();
          onRetroLog();
        },
        onResumeLiveSession: onResumeLiveSession != null
            ? () {
                Navigator.of(ctx).pop();
                onResumeLiveSession();
              }
            : null,
        onUseTemplate: onUseTemplate != null
            ? () {
                Navigator.of(ctx).pop();
                onUseTemplate();
              }
            : null,
        onStrengthHome: onStrengthHome != null
            ? () {
                Navigator.of(ctx).pop();
                onStrengthHome();
              }
            : null,
        hasActiveLiveSession: hasActiveLiveSession,
        hasTemplates: hasTemplates,
        hasActiveStrengthProgram: hasActiveStrengthProgram,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(RitmoRadius.sheet)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: RitmoSpacing.lg,
        vertical: RitmoSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // دستگیره شیت
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

          // سربرگ شیت
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                MovementStrings.addQuestion,
                style: RitmoTextStyles.sectionHeadline(colors.textPrimary),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded, color: colors.textSecondary),
                iconSize: 22,
                tooltip: 'بستن',
              ),
            ],
          ),
          const SizedBox(height: RitmoSpacing.md),

          // ۳ ردیف اصلی
          _buildRow(
            context,
            icon: Icons.play_arrow_rounded,
            iconColor: sportsColor,
            title: MovementStrings.addStartNow,
            subtitle: MovementStrings.addStartNowDesc,
            onTap: onStartNow,
            colors: colors,
          ),
          _buildRow(
            context,
            icon: Icons.calendar_today_rounded,
            iconColor: sportsColor,
            title: MovementStrings.addToPlan,
            subtitle: MovementStrings.addToPlanDesc,
            onTap: onAddToPlan,
            colors: colors,
          ),
          _buildRow(
            context,
            icon: Icons.history_rounded,
            iconColor: sportsColor,
            title: MovementStrings.addRetroLog,
            subtitle: MovementStrings.addRetroLogDesc,
            onTap: onRetroLog,
            colors: colors,
          ),

          // ردیف‌های شرطی (حداکثر تا ۶ ردیف در کل)
          if (hasActiveLiveSession || hasTemplates || !hasActiveStrengthProgram) ...[
            const SizedBox(height: RitmoSpacing.sm),
            const Divider(height: 1),
            const SizedBox(height: RitmoSpacing.sm),
          ],

          if (hasActiveLiveSession && onResumeLiveSession != null)
            _buildRow(
              context,
              icon: Icons.timer_rounded,
              iconColor: const Color(0xFFFFB800),
              title: MovementStrings.addResumeLive,
              subtitle: 'جلسهٔ در حال اجرای شما متوقف شده است',
              onTap: onResumeLiveSession!,
              colors: colors,
            ),

          if (hasTemplates && onUseTemplate != null)
            _buildRow(
              context,
              icon: Icons.bookmark_outline_rounded,
              iconColor: sportsColor,
              title: MovementStrings.addUseTemplate,
              subtitle: 'استفاده از برنامه‌های ذخیره‌شدهٔ قبلی',
              onTap: onUseTemplate!,
              colors: colors,
            ),

          if (!hasActiveStrengthProgram && onStrengthHome != null)
            _buildRow(
              context,
              icon: Icons.fitness_center_rounded,
              iconColor: sportsColor,
              title: MovementStrings.addStrengthHome,
              subtitle: 'ساخت برنامهٔ تمرین قدرتی اختصاصی',
              onTap: onStrengthHome!,
              colors: colors,
            ),

          const SizedBox(height: RitmoSpacing.lg),
        ],
      ),
    );
  }

  Widget _buildRow(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required dynamic colors,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: RitmoSpacing.sm),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(RitmoRadius.card),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(
              horizontal: RitmoSpacing.md,
              vertical: RitmoSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(RitmoRadius.card),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(RitmoRadius.iconButton),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: RitmoSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: RitmoTextStyles.cardTitle(colors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: RitmoTextStyles.caption(colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: colors.textSecondary.withValues(alpha: 0.4),
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
