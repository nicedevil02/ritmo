import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import '../components/components.dart';

/// Unified Post-Workout Summary Screen (Section 6.5).
class MvSessionSummaryScreen extends StatefulWidget {
  final MvSession session;
  final List<MvSetLog> setLogs;
  final List<MvPersonalRecord> newPrs;
  final Future<void> Function(MvSessionFeeling feeling, String? note) onFinish;

  const MvSessionSummaryScreen({
    super.key,
    required this.session,
    required this.setLogs,
    this.newPrs = const [],
    required this.onFinish,
  });

  @override
  State<MvSessionSummaryScreen> createState() => _MvSessionSummaryScreenState();
}

class _MvSessionSummaryScreenState extends State<MvSessionSummaryScreen> {
  MvSessionFeeling _feeling = MvSessionFeeling.good;
  final TextEditingController _noteController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() => _isLoading = true);
    final note = _noteController.text.trim().isEmpty ? null : _noteController.text.trim();
    await widget.onFinish(_feeling, note);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.ritmoColors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;

    final durationMin = widget.session.elapsedMinutes > 0 ? widget.session.elapsedMinutes : 1;
    final metEarned = (durationMin * 5.0).round();

    return Scaffold(
      appBar: AppBar(
        title: const Text('خلاصهٔ تمرین'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: EdgeInsets.all(metrics.spaceLg),
        children: [
          // Celebration Card
          Container(
            padding: EdgeInsets.all(metrics.spaceXl),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colors.primary,
                  colors.primary.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(metrics.radiusHero),
            ),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(metrics.spaceMd),
                  decoration: BoxDecoration(
                    color: colors.onPrimary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.emoji_events_rounded, size: metrics.iconXl, color: colors.onPrimary),
                ),
                SizedBox(height: metrics.spaceMd),
                Text(
                  'خسته نباشی! جلسه به پایان رسید',
                  style: textTheme.titleMedium?.copyWith(
                    color: colors.onPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: metrics.spaceXs),
                Text(
                  '+$metEarned امتیاز فعالیت (MET-min) ثبت شد',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.onPrimary.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: metrics.spaceLg),

          // PR Celebration if any
          if (widget.newPrs.isNotEmpty) ...[
            Container(
              padding: EdgeInsets.all(metrics.spaceMd),
              decoration: BoxDecoration(
                color: colors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(metrics.radiusCard),
                border: Border.all(color: colors.warning.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.stars_rounded, color: colors.warning, size: metrics.iconLg),
                  SizedBox(width: metrics.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'رکورد شخصی جدید (PR)! 🎉',
                          style: textTheme.labelLarge?.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'در حرکت ${widget.newPrs.first.exerciseId} به رکورد ${widget.newPrs.first.formattedValue} رسیدی.',
                          style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: metrics.spaceLg),
          ],

          // Stats Grid
          Row(
            children: [
              Expanded(
                child: MvStatTile(
                  title: 'مدت‌زمان',
                  value: durationMin.toString(),
                  unit: 'دقیقه',
                  icon: Icons.timer_rounded,
                ),
              ),
              SizedBox(width: metrics.spaceMd),
              Expanded(
                child: MvStatTile(
                  title: 'ست‌های ثبت‌شده',
                  value: widget.setLogs.length.toString(),
                  unit: 'ست',
                  icon: Icons.repeat_rounded,
                ),
              ),
            ],
          ),
          SizedBox(height: metrics.spaceLg),

          // Feeling Assessment (ProgressionEngine Input)
          Text(
            'شدت تمرین امروز برایت چطور بود؟',
            style: textTheme.titleSmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: metrics.spaceSm),
          Row(
            children: [
              _buildFeelingChip(MvSessionFeeling.easy, '😊', 'راحت / جا داشتم'),
              SizedBox(width: metrics.spaceSm),
              _buildFeelingChip(MvSessionFeeling.good, '💪', 'خوب و متناسب'),
              SizedBox(width: metrics.spaceSm),
              _buildFeelingChip(MvSessionFeeling.hard, '🥵', 'سخت و چالشی'),
            ],
          ),
          SizedBox(height: metrics.spaceLg),

          // Optional Note
          Text(
            'یادداشت اختیاری',
            style: textTheme.titleSmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: metrics.spaceXs),
          TextField(
            controller: _noteController,
            decoration: InputDecoration(
              hintText: 'مثلاً درد در شانه یا حس عالی در ست آخر...',
              filled: true,
              fillColor: colors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(metrics.radiusField),
                borderSide: BorderSide(color: colors.border),
              ),
            ),
            maxLines: 2,
          ),
          SizedBox(height: metrics.spaceXl),

          // Submit CTA
          MvPrimaryAction(
            label: 'ثبت و بازگشت به هاب',
            icon: Icons.check_circle_rounded,
            isLoading: _isLoading,
            onPressed: _handleSave,
          ),
          SizedBox(height: metrics.spaceXxl),
        ],
      ),
    );
  }

  Widget _buildFeelingChip(MvSessionFeeling feeling, String emoji, String label) {
    final colors = context.ritmoColors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;

    final isSelected = _feeling == feeling;

    return Expanded(
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(metrics.radiusCard),
        child: InkWell(
          onTap: () => setState(() => _feeling = feeling),
          borderRadius: BorderRadius.circular(metrics.radiusCard),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: metrics.spaceMd, horizontal: 4),
            decoration: BoxDecoration(
              color: isSelected ? colors.primary.withValues(alpha: 0.12) : colors.surface,
              borderRadius: BorderRadius.circular(metrics.radiusCard),
              border: Border.all(
                color: isSelected ? colors.primary : colors.border,
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 22)),
                SizedBox(height: metrics.spaceXs),
                Text(
                  label,
                  style: textTheme.labelSmall?.copyWith(
                    color: isSelected ? colors.primary : colors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
