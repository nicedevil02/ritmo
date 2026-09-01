// lib/features/registry/presentation/widgets/delete_impact_dialog.dart

import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/registry/domain/delete_impact_report.dart';
import 'package:ritmo/features/registry/domain/registry_entry.dart';

class DeleteImpactDialog extends StatelessWidget {
  const DeleteImpactDialog({
    super.key,
    required this.entry,
    required this.report,
    required this.onArchive,
    required this.onDeletePermanent,
  });

  final RegistryEntry entry;
  final DeleteImpactReport report;
  final VoidCallback onArchive;
  final VoidCallback onDeletePermanent;

  static Future<void> show(
    BuildContext context, {
    required RegistryEntry entry,
    required DeleteImpactReport report,
    required VoidCallback onArchive,
    required VoidCallback onDeletePermanent,
  }) {
    RitmoHaptics.warning();
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      barrierDismissible: true,
      builder: (context) => DeleteImpactDialog(
        entry: entry,
        report: report,
        onArchive: onArchive,
        onDeletePermanent: onDeletePermanent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return RitmoCustomDialog(
      title: 'حذف «${entry.title}»؟',
      icon: Icons.delete_outline_rounded,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'با حذف کامل، این موارد از بین می‌روند:',
            style: TextStyle(
              fontSize: 13,
              color: colors.textSecondary,
              fontFamily: 'Vazirmatn',
            ),
          ),
          const SizedBox(height: 10),
          RitmoCard.neumorphicSunken(
            padding: const EdgeInsets.all(12),
            child: Text(
              report.toFaSentence(),
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                fontFamily: 'Vazirmatn',
                color: report.orphanedDependents.isNotEmpty
                    ? colors.error
                    : colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
      actions: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              RitmoHaptics.tap();
              Navigator.of(context).pop();
              onDeletePermanent();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.error,
              side: BorderSide(color: colors.error.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'حذف کامل',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RitmoPrimaryButton(
            label: 'بایگانی کن',
            fullWidth: true,
            onPressed: () {
              RitmoHaptics.tap();
              Navigator.of(context).pop();
              onArchive();
            },
          ),
        ),
      ],
    );
  }
}
