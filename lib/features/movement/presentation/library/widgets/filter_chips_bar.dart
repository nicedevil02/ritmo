import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// نوار فیلترهای چندگانهٔ کتابخانهٔ فعالیت‌ها (FilterChipsBar)
/// امکان انتخاب چندگانه، نمایش تعداد فیلترهای فعال و دکمهٔ پاکسازی.
class FilterChipsBar extends StatelessWidget {
  const FilterChipsBar({
    super.key,
    required this.selectedFamilies,
    required this.onFamilyToggled,
    required this.onClearAll,
  });

  final Set<String> selectedFamilies;
  final ValueChanged<String> onFamilyToggled;
  final VoidCallback onClearAll;

  static const Map<String, String> familyLabels = {
    'walking': 'پیاده‌روی',
    'running': 'دویدن',
    'cycling': 'دوچرخه',
    'strength': 'قدرتی',
    'swimming': 'شنا',
    'yoga_mobility': 'یوگا و کشش',
    'hiking': 'طبیعت‌گردی',
    'team_sports': 'ورزش‌های تیمی',
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    final activeCount = selectedFamilies.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (activeCount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: RitmoSpacing.xs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${toPersianDigits(activeCount)} فیلتر فعال',
                  style: RitmoTextStyles.caption(
                    sportsColor,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: onClearAll,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(48, 36),
                  ),
                  child: Text(
                    MovementStrings.libraryClearFilters,
                    style: RitmoTextStyles.caption(colors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: familyLabels.entries.map((entry) {
              final isSelected = selectedFamilies.contains(entry.key);

              return Padding(
                padding: const EdgeInsets.only(left: RitmoSpacing.xs),
                child: FilterChip(
                  label: Text(entry.value),
                  selected: isSelected,
                  onSelected: (_) => onFamilyToggled(entry.key),
                  selectedColor: sportsColor.withValues(alpha: 0.2),
                  checkmarkColor: sportsColor,
                  labelStyle:
                      RitmoTextStyles.caption(
                        isSelected ? sportsColor : colors.textPrimary,
                      ).copyWith(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                  backgroundColor: colors.surfaceSunken,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(RitmoRadius.pill),
                    side: BorderSide(
                      color: isSelected ? sportsColor : colors.border,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
