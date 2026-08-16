import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/domain/models/movement_change_scope.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// تنها شیت انتخاب دامنهٔ تغییرات برنامه در سراسر ماژول حرکت
class ScopePickerSheet extends StatefulWidget {
  const ScopePickerSheet({
    super.key,
    this.initialScope = MovementChangeScope.onlyThis,
    required this.onScopeSelected,
  });

  final MovementChangeScope initialScope;
  final ValueChanged<MovementChangeScope> onScopeSelected;

  static Future<MovementChangeScope?> show(
    BuildContext context, {
    MovementChangeScope initialScope = MovementChangeScope.onlyThis,
  }) {
    return showModalBottomSheet<MovementChangeScope>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ScopePickerSheet(
        initialScope: initialScope,
        onScopeSelected: (scope) => Navigator.of(ctx).pop(scope),
      ),
    );
  }

  @override
  State<ScopePickerSheet> createState() => _ScopePickerSheetState();
}

class _ScopePickerSheetState extends State<ScopePickerSheet> {
  late MovementChangeScope _selectedScope;

  @override
  void initState() {
    super.initState();
    _selectedScope = widget.initialScope;
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

          // عنوان شیت
          Text(
            MovementStrings.scopeTitle,
            style: RitmoTextStyles.sectionHeadline(colors.textPrimary),
          ),
          const SizedBox(height: RitmoSpacing.lg),

          // ۳ گزینهٔ دامنه
          _buildScopeOption(
            context,
            scope: MovementChangeScope.onlyThis,
            title: MovementStrings.scopeOnlyThis,
            description: MovementStrings.scopeOnlyThisDesc,
            colors: colors,
            sportsColor: sportsColor,
          ),
          const SizedBox(height: RitmoSpacing.sm),
          _buildScopeOption(
            context,
            scope: MovementChangeScope.thisAndFuture,
            title: MovementStrings.scopeThisAndFuture,
            description: MovementStrings.scopeThisAndFutureDesc,
            colors: colors,
            sportsColor: sportsColor,
          ),
          const SizedBox(height: RitmoSpacing.sm),
          _buildScopeOption(
            context,
            scope: MovementChangeScope.wholePlan,
            title: MovementStrings.scopeWholePlan,
            description: MovementStrings.scopeWholePlanDesc,
            colors: colors,
            sportsColor: sportsColor,
          ),
          const SizedBox(height: RitmoSpacing.xl),

          // دکمهٔ تأیید دامنه
          SizedBox(
            width: double.infinity,
            height: MovementLayout.kFieldMinHeight,
            child: ElevatedButton(
              onPressed: () => widget.onScopeSelected(_selectedScope),
              style: ElevatedButton.styleFrom(
                backgroundColor: sportsColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(RitmoRadius.field),
                ),
              ),
              child: Text(
                MovementStrings.commonConfirm,
                style: RitmoTextStyles.label(Colors.white),
              ),
            ),
          ),
          const SizedBox(height: RitmoSpacing.lg),
        ],
      ),
    );
  }

  Widget _buildScopeOption(
    BuildContext context, {
    required MovementChangeScope scope,
    required String title,
    required String description,
    required dynamic colors,
    required Color sportsColor,
  }) {
    final isSelected = _selectedScope == scope;

    return Semantics(
      label: '$title، $description${isSelected ? '، انتخاب‌شده' : ''}',
      button: true,
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(RitmoRadius.card),
        child: InkWell(
          onTap: () => setState(() => _selectedScope = scope),
          borderRadius: BorderRadius.circular(RitmoRadius.card),
          child: Container(
            padding: const EdgeInsets.all(RitmoSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(RitmoRadius.card),
              border: Border.all(
                color: isSelected ? sportsColor : colors.border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? sportsColor : colors.border,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: sportsColor,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: RitmoSpacing.md),
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
                        description,
                        style: RitmoTextStyles.caption(colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
