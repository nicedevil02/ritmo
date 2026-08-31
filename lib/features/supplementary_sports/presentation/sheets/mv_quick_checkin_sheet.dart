import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import '../components/components.dart';

/// Sheet 5: "چک‌این کوتاه" (Section 5.9 & D-07).
/// Fast 1-tap 3-smiley readiness assessment with optional deep sliders.
class MvQuickCheckinSheet extends StatefulWidget {
  final String dateIso;
  final ValueChanged<MvDailyCheckin> onSave;

  const MvQuickCheckinSheet({
    super.key,
    required this.dateIso,
    required this.onSave,
  });

  static Future<void> show({
    required BuildContext context,
    required String dateIso,
    required ValueChanged<MvDailyCheckin> onSave,
  }) {
    return MvSheetScaffold.show(
      context: context,
      builder: (ctx) => MvQuickCheckinSheet(
        dateIso: dateIso,
        onSave: (c) {
          Navigator.pop(ctx);
          onSave(c);
        },
      ),
    );
  }

  @override
  State<MvQuickCheckinSheet> createState() => _MvQuickCheckinSheetState();
}

class _MvQuickCheckinSheetState extends State<MvQuickCheckinSheet> {
  int _energy = 4;
  int _soreness = 1;
  int _fatigue = 2;
  int _pain = 0;
  bool _showDetails = false;

  void _handleQuickOption(int energy, int soreness, int fatigue) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final checkin = MvDailyCheckin(
      dateIso: widget.dateIso,
      energy: energy,
      soreness: soreness,
      fatigue: fatigue,
      painLevel: _pain,
      createdAt: now,
      updatedAt: now,
    );
    widget.onSave(checkin);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    return MvSheetScaffold(
      title: l10n?.mv_checkin_title ?? 'How is your readiness today?',
      subtitle: l10n?.mv_checkin_subtitle ?? 'One tap adapts today plan to your energy level.',
      body: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 3 Big 1-Tap Smiley Options
            Row(
              children: [
                _buildQuickCard(
                  emoji: '⚡',
                  title: l10n?.mv_checkin_great_title ?? 'Great & High Energy',
                  desc: l10n?.mv_checkin_great_desc ?? 'Ready for full load',
                  color: colors.success,
                  onTap: () => _handleQuickOption(5, 1, 1),
                ),
                const SizedBox(width: 8),
                _buildQuickCard(
                  emoji: '🌤️',
                  title: l10n?.mv_checkin_good_title ?? 'Good & Moderate',
                  desc: l10n?.mv_checkin_good_desc ?? 'Moderate energy',
                  color: colors.accent,
                  onTap: () => _handleQuickOption(3, 2, 3),
                ),
                const SizedBox(width: 8),
                _buildQuickCard(
                  emoji: '🛋️',
                  title: l10n?.mv_checkin_tired_title ?? 'Tired / Heavy Legs',
                  desc: l10n?.mv_checkin_tired_desc ?? 'Minimal or stretch',
                  color: colors.warning,
                  onTap: () => _handleQuickOption(1, 4, 4),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Expand Deep Check-in Toggle
            TextButton.icon(
              onPressed: () => setState(() => _showDetails = !_showDetails),
              icon: Icon(
                _showDetails
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.tune_rounded,
                size: metrics.iconSm,
                color: colors.textSecondary,
              ),
              label: Text(
                _showDetails
                    ? (l10n?.mv_checkin_close_details ?? 'Close fine details')
                    : (l10n?.mv_checkin_open_details ?? 'More details (soreness, fatigue, pain)...'),
                style: textTheme.labelMedium?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),

            if (_showDetails) ...[
              const SizedBox(height: 12),
              _buildSliderRow(
                l10n?.mv_checkin_energy_label ?? 'Energy level (1 to 5):',
                _energy.toDouble(),
                1,
                5,
                (v) => setState(() => _energy = v.round()),
              ),
              _buildSliderRow(
                l10n?.mv_checkin_soreness_label ?? 'Muscle soreness (1 to 5):',
                _soreness.toDouble(),
                1,
                5,
                (v) => setState(() => _soreness = v.round()),
              ),
              _buildSliderRow(
                l10n?.mv_checkin_fatigue_label ?? 'General fatigue (1 to 5):',
                _fatigue.toDouble(),
                1,
                5,
                (v) => setState(() => _fatigue = v.round()),
              ),
              _buildSliderRow(
                l10n?.mv_checkin_pain_label ?? 'Local pain level (0 to 10):',
                _pain.toDouble(),
                0,
                10,
                (v) => setState(() => _pain = v.round()),
              ),
              const SizedBox(height: 16),
              MvPrimaryAction(
                label: l10n?.mv_checkin_submit_details ?? 'Save detailed check-in',
                onPressed: () =>
                    _handleQuickOption(_energy, _soreness, _fatigue),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickCard({
    required String emoji,
    required String title,
    required String desc,
    required Color color,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Expanded(
      child: RitmoCard.neumorphic(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Text(emoji, style: textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              title,
              style: textTheme.labelMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              style: textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderRow(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              toPersianDigits(value.round().toString()),
              style: textTheme.labelMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: (max - min).round(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
