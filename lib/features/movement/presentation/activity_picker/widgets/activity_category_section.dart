import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';
import 'package:ritmo/features/movement/presentation/activity_picker/widgets/activity_kind_tile.dart';

/// بخش دسته‌بندی در صفحهٔ انتخاب فعالیت همراه با سربرگ و شبکهٔ ۲ ستونه
class ActivityCategorySection extends StatelessWidget {
  const ActivityCategorySection({
    super.key,
    required this.title,
    required this.kinds,
    required this.onKindSelected,
    this.onFavoriteToggle,
  });

  final String title;
  final List<MovementActivityKind> kinds;
  final ValueChanged<MovementActivityKind> onKindSelected;
  final ValueChanged<MovementActivityKind>? onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    if (kinds.isEmpty) return const SizedBox.shrink();

    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // سربرگ دسته‌بندی با تعداد آیتم‌ها
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: RitmoSpacing.lg,
            vertical: RitmoSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: RitmoTextStyles.sectionHeadline(colors.textPrimary),
              ),
              Text(
                '${toPersianDigits(kinds.length)} فعالیت',
                style: RitmoTextStyles.caption(colors.textSecondary),
              ),
            ],
          ),
        ),

        // فهرست ۲ ستونه
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.lg),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 600;
              final crossAxisCount = isWide ? 3 : (constraints.maxWidth > 340 ? 2 : 1);

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: RitmoSpacing.sm,
                  crossAxisSpacing: RitmoSpacing.sm,
                  mainAxisExtent: 76,
                ),
                itemCount: kinds.length,
                itemBuilder: (context, index) {
                  final kind = kinds[index];
                  return ActivityKindTile(
                    activityKind: kind,
                    onTap: () => onKindSelected(kind),
                    onFavoriteToggle: onFavoriteToggle != null
                        ? () => onFavoriteToggle!(kind)
                        : null,
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: RitmoSpacing.md),
      ],
    );
  }
}
