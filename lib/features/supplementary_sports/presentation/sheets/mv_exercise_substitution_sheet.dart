import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/supplementary_sports/domain/engines/engines.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/l10n/app_localizations.dart';
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
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    final reasons = [
      {'code': 'too_hard', 'label': l10n?.mv_substitute_too_hard ?? 'Too Hard', 'emoji': '💪'},
      {'code': 'pain', 'label': l10n?.mv_substitute_pain ?? 'Pain or Discomfort', 'emoji': '🩹'},
      {'code': 'no_equipment', 'label': l10n?.mv_substitute_no_equipment ?? 'No Equipment', 'emoji': '🚫'},
      {'code': 'noise', 'label': l10n?.mv_substitute_noise ?? 'Too Noisy', 'emoji': '🤫'},
    ];

    return MvSheetScaffold(
      title: l10n?.mv_substitute_title ?? 'Substitute Exercise',
      subtitle: l10n?.mv_substitute_reason_prompt(widget.currentExercise.name) ??
          'Why do you want to substitute ${widget.currentExercise.name}?',
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Reason Chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: reasons.map((r) {
                final isSel = r['code'] == _selectedReason;
                return MvChip(
                  label: r['label']!,
                  icon: Text(r['emoji']!, style: textTheme.bodyMedium),
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
            const SizedBox(height: 16),

            // 2. Reason Explanation
            RitmoCard.neumorphic(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: colors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
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
            const SizedBox(height: 16),

            // 3. Suggested Substitutes
            Text(
              l10n?.mv_substitute_suggestions ?? 'Suggested Substitutes',
              style: textTheme.titleSmall?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),

            if (_decision.value.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    l10n?.mv_substitute_empty ?? 'No matching substitute found.',
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
                  padding: const EdgeInsets.only(bottom: 8),
                  child: RitmoCard.neumorphic(
                    onTap: () => widget.onExerciseSubstituted(ex),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        RitmoNeuSurface(
                          width: 48,
                          height: 48,
                          radius: 12,
                          padding: EdgeInsets.zero,
                          child: Center(
                            child: Icon(
                              Icons.fitness_center_rounded,
                              color: colors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
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
                              const SizedBox(height: 4),
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
                          label: l10n?.mv_substitute_select ?? 'Select',
                          onPressed: () => widget.onExerciseSubstituted(ex),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
