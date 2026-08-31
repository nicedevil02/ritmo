import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/konkur/data/konkur_curriculum.dart';
import 'package:ritmo/features/konkur/models/konkur_models.dart';

class KonkurFieldPickerSheet extends StatelessWidget {
  const KonkurFieldPickerSheet({super.key});

  static Future<KonkurField?> show(BuildContext context) {
    return showModalBottomSheet<KonkurField>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const KonkurFieldPickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: RitmoBreakpoints.sheetMaxHeight(context, factor: 0.94),
        ),
        child: RitmoGlassSheet(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: colors.border.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

            // Symmetrical Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Leading (Right in RTL): Circular Tactile Close (X) Button
                  GestureDetector(
                    onTap: () {
                      RitmoHapticsPolicy.tap();
                      Navigator.pop(context, null);
                    },
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: isDark
                            ? colors.surfaceElevated.withValues(alpha: 0.85)
                            : colors.textPrimary.withValues(alpha: 0.07),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? colors.border.withValues(alpha: 0.35)
                              : colors.border.withValues(alpha: 0.15),
                          width: 0.85,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        CupertinoIcons.xmark,
                        size: 15,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),

                  // Center: Title & Subtitle
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'بارگذاری سرفصل‌های کنکور',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'رشته تحصیلی خود را انتخاب کنید',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Trailing (Left in RTL): Symmetrical Spacer
                  const SizedBox(width: 34, height: 34),
                ],
              ),
            ),
            const Divider(height: 1),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...KonkurField.values.map((field) => _buildFieldCard(context, field, colors)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildFieldCard(BuildContext context, KonkurField field, RitmoColors colors) {
    final curriculum = KonkurCurriculum.byField[field] ?? [];
    final subjectCount = curriculum.length;
    int topicCount = 0;
    for (final s in curriculum) {
      topicCount += s.topics.length;
    }

    final (icon, colorHex) = switch (field) {
      KonkurField.riyazi  => ('📐', const Color(0xFF3B82F6)),
      KonkurField.tajrobi => ('🧬', const Color(0xFF10B981)),
      KonkurField.ensani  => ('📚', const Color(0xFFF59E0B)),
      KonkurField.honar   => ('🎨', const Color(0xFFEC4899)),
      KonkurField.zaban   => ('🗣️', const Color(0xFF8B5CF6)),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.pop(context, field),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colorHex.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorHex.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        field.label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$subjectCount درس · $topicCount مبحث',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: colorHex,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
