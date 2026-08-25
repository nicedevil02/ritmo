import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
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
  int _fatigue = 1;
  int _pain = 0;
  bool _showDeepSliders = false;

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
    final colors = context.ritmoColors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;

    return MvSheetScaffold(
      title: 'آمادگی امروزت چطوره؟',
      subtitle: 'با یک لمس، برنامهٔ امروز متناسب با انرژی بدنت تنظیم می‌شود.',
      body: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 3 Quick Smiley Options
            Row(
              children: [
                _buildQuickCard(
                  emoji: '⚡',
                  title: 'عالی و پرانرژی',
                  desc: 'آماده برای جلسهٔ کامل',
                  color: colors.success,
                  onTap: () => _handleQuickOption(5, 1, 1),
                ),
                SizedBox(width: metrics.spaceSm),
                _buildQuickCard(
                  emoji: '🌤️',
                  title: 'خوب و معمولی',
                  desc: 'انرژی متناسب',
                  color: colors.primary,
                  onTap: () => _handleQuickOption(3, 2, 2),
                ),
                SizedBox(width: metrics.spaceSm),
                _buildQuickCard(
                  emoji: '😴',
                  title: 'خسته یا کوفته',
                  desc: 'پیشنهاد جلسه سبک',
                  color: colors.warning,
                  onTap: () => _handleQuickOption(2, 4, 4),
                ),
              ],
            ),
            SizedBox(height: metrics.spaceLg),

            // Toggle for Deep Sliders
            InkWell(
              onTap: () => setState(() => _showDeepSliders = !_showDeepSliders),
              borderRadius: BorderRadius.circular(metrics.radiusField),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: metrics.spaceSm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _showDeepSliders ? 'بستن جزئیات دقیق‌تر' : 'ثبت دقیق‌تر (درد، کوفتگی و خستگی)...',
                      style: textTheme.labelMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      _showDeepSliders ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: colors.primary,
                      size: metrics.iconSm,
                    ),
                  ],
                ),
              ),
            ),

            if (_showDeepSliders) ...[
              SizedBox(height: metrics.spaceMd),
              _buildSliderRow('سطح انرژی (۱ تا ۵):', _energy.toDouble(), 1, 5, (v) => setState(() => _energy = v.round())),
              _buildSliderRow('کوفتگی عضلانی (۱ تا ۵):', _soreness.toDouble(), 1, 5, (v) => setState(() => _soreness = v.round())),
              _buildSliderRow('خستگی عمومی (۱ تا ۵):', _fatigue.toDouble(), 1, 5, (v) => setState(() => _fatigue = v.round())),
              _buildSliderRow('میزان درد موضعی (۰ تا ۱۰):', _pain.toDouble(), 0, 10, (v) => setState(() => _pain = v.round())),
              SizedBox(height: metrics.spaceLg),
              MvPrimaryAction(
                label: 'ثبت جزئیات دقیق',
                onPressed: () => _handleQuickOption(_energy, _soreness, _fatigue),
              ),
            ],
            SizedBox(height: metrics.spaceMd),
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
    final colors = context.ritmoColors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(metrics.radiusCard),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: metrics.spaceLg, horizontal: metrics.spaceXs),
            decoration: BoxDecoration(
              color: colors.surfaceElevated,
              borderRadius: BorderRadius.circular(metrics.radiusCard),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 28)),
                SizedBox(height: metrics.spaceSm),
                Text(
                  title,
                  style: textTheme.labelMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: metrics.spaceXs),
                Text(
                  desc,
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSliderRow(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    final textTheme = Theme.of(context).textTheme;
    final colors = context.ritmoColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: textTheme.bodySmall?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600)),
            Text(value.round().toString(), style: textTheme.labelMedium?.copyWith(color: colors.primary, fontWeight: FontWeight.w700)),
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
