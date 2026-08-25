import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/engines.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import '../components/components.dart';

/// Sheet 3: "جایگزینی حرکت" (Section 5.9, N-05, AC-05).
class MvExerciseSubstitutionSheet extends StatefulWidget {
  final MvExercise currentExercise;
  final List<MvExercise> similarCandidates;
  final List<MvExercise> fullPool;
  final bool neighborFriendly;
  final List<String> physicalLimitations;
  final ValueChanged<MvExercise> onExerciseSubstituted;

  const MvExerciseSubstitutionSheet({
    super.key,
    required this.currentExercise,
    required this.similarCandidates,
    this.fullPool = const [],
    this.neighborFriendly = false,
    this.physicalLimitations = const [],
    required this.onExerciseSubstituted,
  });

  static Future<void> show({
    required BuildContext context,
    required MvExercise currentExercise,
    required List<MvExercise> similarCandidates,
    List<MvExercise> fullPool = const [],
    bool neighborFriendly = false,
    List<String> physicalLimitations = const [],
    required ValueChanged<MvExercise> onExerciseSubstituted,
  }) {
    return MvSheetScaffold.show(
      context: context,
      builder: (ctx) => MvExerciseSubstitutionSheet(
        currentExercise: currentExercise,
        similarCandidates: similarCandidates,
        fullPool: fullPool,
        neighborFriendly: neighborFriendly,
        physicalLimitations: physicalLimitations,
        onExerciseSubstituted: (ex) {
          Navigator.pop(ctx);
          onExerciseSubstituted(ex);
        },
      ),
    );
  }

  @override
  State<MvExerciseSubstitutionSheet> createState() =>
      _MvExerciseSubstitutionSheetState();
}

class _MvExerciseSubstitutionSheetState
    extends State<MvExerciseSubstitutionSheet> {
  static const _engine = SubstitutionEngine();
  String _selectedReason = 'too_hard';
  late MvDecision<List<MvExercise>> _decision;

  final List<Map<String, String>> _reasons = const [
    {'code': 'too_hard', 'label': 'سخت است', 'emoji': '💪'},
    {'code': 'pain', 'label': 'احساس درد یا ناراحتی', 'emoji': '🩹'},
    {'code': 'no_equipment', 'label': 'وسیله ندارم', 'emoji': '🚫'},
    {'code': 'noise', 'label': 'سروصدا دارد', 'emoji': '🤫'},
  ];

  @override
  void initState() {
    super.initState();
    _computeSubstitutes();
  }

  void _computeSubstitutes() {
    _decision = _engine.suggestSubstitutes(
      currentExercise: widget.currentExercise,
      reason: _selectedReason,
      similarCandidates: widget.similarCandidates,
      fullPool: widget.fullPool,
      neighborFriendly: widget.neighborFriendly,
      limitations: widget.physicalLimitations,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.ritmoColors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;

    return MvSheetScaffold(
      title: 'جایگزینی حرکت',
      subtitle: 'علت جایگزینی «${widget.currentExercise.name}» را مشخص کن.',
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Reason Chips
            Wrap(
              spacing: metrics.spaceSm,
              runSpacing: metrics.spaceSm,
              children: _reasons.map((r) {
                final isSel = r['code'] == _selectedReason;
                return MvChip(
                  label: r['label']!,
                  icon: Text(r['emoji']!, style: const TextStyle(fontSize: 14)),
                  isSelected: isSel,
                  onTap: () {
                    setState(() {
                      _selectedReason = r['code']!;
                      _computeSubstitutes();
                    });
                  },
                );
              }).toList(),
            ),
            SizedBox(height: metrics.spaceLg),

            // 2. Reason Explanation
            Container(
              padding: EdgeInsets.all(metrics.spaceMd),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(metrics.radiusField),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: colors.primary,
                    size: metrics.iconMd,
                  ),
                  SizedBox(width: metrics.spaceSm),
                  Expanded(
                    child: Text(
                      _decision.reasonFa,
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: metrics.spaceLg),

            // 3. Suggested Substitutes
            Text(
              'حرکات پیشنهادی جایگزین',
              style: textTheme.titleSmall?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: metrics.spaceSm),

            if (_decision.value.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: metrics.spaceXl),
                child: Center(
                  child: Text(
                    'حرکت جایگزین دیگری با این شرایط یافت نشد.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              )
            else
              ...List.generate(_decision.value.length, (index) {
                final ex = _decision.value[index];
                return Padding(
                  padding: EdgeInsets.only(bottom: metrics.spaceSm),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => widget.onExerciseSubstituted(ex),
                      borderRadius: BorderRadius.circular(metrics.radiusCard),
                      child: Container(
                        padding: EdgeInsets.all(metrics.spaceMd),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(
                            metrics.radiusCard,
                          ),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: colors.surfaceElevated,
                                borderRadius: BorderRadius.circular(
                                  metrics.radiusField,
                                ),
                              ),
                              child: Icon(
                                Icons.fitness_center_rounded,
                                color: colors.primary,
                              ),
                            ),
                            SizedBox(width: metrics.spaceMd),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ex.name,
                                    style: textTheme.bodyLarge?.copyWith(
                                      color: colors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: metrics.spaceXs),
                                  Text(
                                    ex.category,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            MvPrimaryAction(
                              label: 'انتخاب',
                              onPressed: () => widget.onExerciseSubstituted(ex),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            SizedBox(height: metrics.spaceLg),
          ],
        ),
      ),
    );
  }
}
