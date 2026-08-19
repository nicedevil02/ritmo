import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';

/// ردیف عملیات حساس و پاکسازی داده‌ها (SettingsDangerRow)
class SettingsDangerRow extends StatelessWidget {
  const SettingsDangerRow({
    super.key,
    required this.title,
    required this.explanation,
    required this.buttonLabel,
    required this.onTap,
  });

  final String title;
  final String explanation;
  final String buttonLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      constraints: const BoxConstraints(
        minHeight: MovementLayout.kFieldMinHeight,
      ),
      padding: const EdgeInsets.all(RitmoSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: colors.accent, size: 20),
              const SizedBox(width: RitmoSpacing.xs),
              Text(
                title,
                style: RitmoTextStyles.body(
                  colors.accent,
                ).copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            explanation,
            style: RitmoTextStyles.caption(colors.textTertiary),
          ),
          const SizedBox(height: RitmoSpacing.md),
          OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              side: BorderSide(color: colors.accent),
              foregroundColor: colors.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(RitmoRadius.field),
              ),
            ),
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}
