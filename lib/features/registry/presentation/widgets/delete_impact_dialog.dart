// lib/features/registry/presentation/widgets/delete_impact_dialog.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_button.dart';
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
    final isDark = context.isDark;
    final isGlass = context.isGlassEnabled;
    final highContrast = MediaQuery.maybeOf(context)?.highContrast ?? false;
    final materialSpec = context.materials.regular;
    final isOpaque = !isGlass || highContrast;

    final dialogContent = Container(
      constraints: const BoxConstraints(maxWidth: 380),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isOpaque
            ? colors.surfaceElevated
            : (isDark
                ? const Color(0xFF131722).withValues(alpha: 0.88)
                : Colors.white.withValues(alpha: 0.90)),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isOpaque
              ? (isDark ? colors.border : colors.divider)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.95)),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.60 : 0.18),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: colors.error.withValues(alpha: isDark ? 0.12 : 0.08),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.delete_outline_rounded, size: 20, color: colors.error),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'حذف «${entry.title}»؟',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: colors.textPrimary,
                    fontFamily: 'Vazirmatn',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 20),
          Row(
            children: [
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
          ),
        ],
      ),
    );

    final Widget renderedDialog = isOpaque
        ? dialogContent
        : ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: materialSpec.sigma,
                sigmaY: materialSpec.sigma,
              ),
              child: dialogContent,
            ),
          );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Material(
            color: Colors.transparent,
            child: renderedDialog,
          ),
        ),
      ),
    );
  }
}
