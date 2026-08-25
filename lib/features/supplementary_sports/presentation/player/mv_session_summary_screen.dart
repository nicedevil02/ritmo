import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import '../components/components.dart';

/// Unified Post-Workout Summary Screen (Section 6.5 & S4-T5).
class MvSessionSummaryScreen extends StatefulWidget {
  final MvSession session;
  final MvMovementKind? kind;
  final List<MvSetLog> setLogs;
  final List<MvPersonalRecord> newPrs;
  final int weeklyGoalMinutes;
  final int currentWeekMinutesBefore;
  final Future<void> Function({
    required MvSessionFeeling feeling,
    required int rpe1To10,
    required String effortSource,
    String? note,
  })
  onFinish;

  const MvSessionSummaryScreen({
    super.key,
    required this.session,
    this.kind,
    this.setLogs = const [],
    this.newPrs = const [],
    this.weeklyGoalMinutes = 150,
    this.currentWeekMinutesBefore = 60,
    required this.onFinish,
  });

  @override
  State<MvSessionSummaryScreen> createState() => _MvSessionSummaryScreenState();
}

class _MvSessionSummaryScreenState extends State<MvSessionSummaryScreen> {
  int _rpe = 6;
  bool _effortSelectedByUser = false;
  final TextEditingController _noteController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.session.rpe1To10 != null) {
      _rpe = widget.session.rpe1To10!;
      _effortSelectedByUser = true;
    }
    if (widget.session.note != null) {
      _noteController.text = widget.session.note!;
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  MvSessionFeeling get _feeling {
    if (_rpe <= 4) return MvSessionFeeling.easy;
    if (_rpe <= 7) return MvSessionFeeling.good;
    return MvSessionFeeling.hard;
  }

  Future<void> _handleSave() async {
    setState(() => _isLoading = true);
    final note = _noteController.text.trim().isEmpty
        ? null
        : _noteController.text.trim();
    final effortSource = _effortSelectedByUser ? 'user' : 'estimated';
    await widget.onFinish(
      feeling: _feeling,
      rpe1To10: _rpe,
      effortSource: effortSource,
      note: note,
    );
  }

  String _formatPace(double? paceSec) {
    if (paceSec == null || paceSec <= 0) return '—';
    final min = (paceSec / 60).floor();
    final sec = (paceSec % 60).round();
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.ritmoColors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;

    final durationMin = widget.session.elapsedMinutes > 0
        ? widget.session.elapsedMinutes
        : 1;
    final earnedEquivMin = durationMin;
    final weekTotalAfter = widget.currentWeekMinutesBefore + earnedEquivMin;
    final remainingToGoal = (widget.weeklyGoalMinutes - weekTotalAfter).clamp(
      0,
      9999,
    );

    final title = widget.kind?.titleFa ?? 'ورزش و فعالیت';
    final emoji = widget.kind?.emoji ?? '🏃‍♂️';

    return Scaffold(
      appBar: AppBar(
        title: const Text('خلاصهٔ جلسه'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: EdgeInsets.all(metrics.spaceLg),
        children: [
          // 1. Sport Title + Emoji + Duration
          Container(
            padding: EdgeInsets.all(metrics.spaceXl),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colors.primary,
                  colors.primary.withValues(alpha: 0.85),
                ],
              ),
              borderRadius: BorderRadius.circular(metrics.radiusHero),
            ),
            child: Column(
              children: [
                Text(emoji, style: textTheme.displayMedium),
                SizedBox(height: metrics.spaceXs),
                Text(
                  title,
                  style: textTheme.headlineSmall?.copyWith(
                    color: colors.onPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: metrics.spaceXs),
                Text(
                  '${toPersianDigits(durationMin.toString())} دقیقه تمرین ثبت شد',
                  style: textTheme.bodyLarge?.copyWith(
                    color: colors.onPrimary.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: metrics.spaceLg),

          // 2. Metrics Card (Mode-specific according to S4-T3 table)
          _buildModeMetricsCard(context),
          SizedBox(height: metrics.spaceLg),

          // 3. Effort Question (3 buttons: Easy (3), Good (6), Hard (8))
          Text(
            'میزان تلاش این جلسه چطور بود؟',
            style: textTheme.titleSmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: metrics.spaceSm),
          Row(
            children: [
              _buildEffortButton(
                key: const Key('mv_effort_easy'),
                targetRpe: 3,
                emoji: '😊',
                label: 'راحت و آسان',
              ),
              SizedBox(width: metrics.spaceSm),
              _buildEffortButton(
                key: const Key('mv_effort_good'),
                targetRpe: 6,
                emoji: '💪',
                label: 'خوب و متناسب',
              ),
              SizedBox(width: metrics.spaceSm),
              _buildEffortButton(
                key: const Key('mv_effort_hard'),
                targetRpe: 8,
                emoji: '🥵',
                label: 'سخت و چالشی',
              ),
            ],
          ),
          SizedBox(height: metrics.spaceMd),

          // 4. Optional Fine-tune Slider (1..10)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'دقیق‌ترش کنم (RPE)',
                style: textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              Text(
                toPersianDigits(_rpe.toString()),
                style: textTheme.titleSmall?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Slider(
            value: _rpe.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            label: _rpe.toString(),
            onChanged: (val) {
              RitmoHaptics.subtle();
              setState(() {
                _rpe = val.round();
                _effortSelectedByUser = true;
              });
            },
          ),
          SizedBox(height: metrics.spaceMd),

          // 5. Free Note Field
          Text(
            'یادداشت آزاد اختیاری',
            style: textTheme.titleSmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: metrics.spaceXs),
          TextField(
            controller: _noteController,
            decoration: InputDecoration(
              hintText:
                  'مثلاً هوا عالی بود، شیب تند بود، یا حس پیشرفت داشتم...',
              filled: true,
              fillColor: colors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(metrics.radiusField),
                borderSide: BorderSide(color: colors.border),
              ),
            ),
            maxLines: 2,
          ),
          SizedBox(height: metrics.spaceLg),

          // 6. PR Celebration Banner if any
          if (widget.newPrs.isNotEmpty) ...[
            Container(
              key: const Key('mv_new_personal_record'),
              padding: EdgeInsets.all(metrics.spaceMd),
              decoration: BoxDecoration(
                color: colors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(metrics.radiusCard),
                border: Border.all(
                  color: colors.warning.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.stars_rounded,
                    color: colors.warning,
                    size: metrics.iconLg,
                  ),
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
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: metrics.spaceLg),
          ],

          // 7. Two-line Week Impact
          Container(
            padding: EdgeInsets.all(metrics.spaceMd),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(metrics.radiusCard),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.bolt_rounded, color: colors.primary, size: metrics.iconMd),
                    SizedBox(width: metrics.spaceSm),
                    Text(
                      '+${toPersianDigits(earnedEquivMin.toString())} دقیقه فعالیت معادل به این هفته اضافه شد',
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      remainingToGoal == 0
                          ? Icons.check_circle
                          : Icons.flag_rounded,
                      color: remainingToGoal == 0
                          ? Colors.green
                          : colors.textSecondary,
                      size: metrics.iconMd,
                    ),
                    SizedBox(width: metrics.spaceSm),
                    Text(
                      remainingToGoal == 0
                          ? 'هدف هفتگی ۱۵۰ دقیقه با موفقیت کامل شد! 🎯'
                          : '${toPersianDigits(remainingToGoal.toString())} دقیقه تا دستیابی به هدف هفتگی مانده',
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: metrics.spaceXl),

          // Submit CTA
          MvPrimaryAction(
            label: 'ثبت جلسه و ذخیره',
            icon: Icons.check_circle_rounded,
            isLoading: _isLoading,
            onPressed: _handleSave,
          ),
          SizedBox(height: metrics.spaceXxl),
        ],
      ),
    );
  }

  Widget _buildModeMetricsCard(BuildContext context) {
    final mode = widget.session.sessionMode;
    final distM = widget.session.distanceM;
    final elevM = widget.session.elevationGainM;
    final laps = widget.session.laps;
    final packKg = widget.session.packWeightKg;
    final durationMin = widget.session.elapsedMinutes > 0
        ? widget.session.elapsedMinutes
        : 1;

    switch (mode) {
      case MvSessionMode.route:
        return Row(
          children: [
            if (distM != null)
              Expanded(
                child: MvStatTile(
                  title: 'مسافت',
                  value: toPersianDigits((distM / 1000.0).toStringAsFixed(1)),
                  unit: 'کیلومتر',
                  icon: Icons.route_rounded,
                ),
              ),
            if (distM != null) const SizedBox(width: 8),
            if (elevM != null)
              Expanded(
                child: MvStatTile(
                  title: 'ارتفاع صعود',
                  value: toPersianDigits(elevM.round().toString()),
                  unit: 'متر',
                  icon: Icons.terrain_rounded,
                ),
              ),
            if (elevM != null) const SizedBox(width: 8),
            if (packKg != null)
              Expanded(
                child: MvStatTile(
                  title: 'وزن کوله',
                  value: toPersianDigits(packKg.toStringAsFixed(1)),
                  unit: 'کیلوگرم',
                  icon: Icons.backpack_rounded,
                ),
              ),
          ],
        );

      case MvSessionMode.distance:
        return Row(
          children: [
            Expanded(
              child: MvStatTile(
                title: 'مسافت',
                value: distM != null
                    ? toPersianDigits((distM / 1000.0).toStringAsFixed(2))
                    : '—',
                unit: 'کیلومتر',
                icon: Icons.directions_run_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MvStatTile(
                title: 'تمپو',
                value: toPersianDigits(
                  _formatPace(widget.session.paceSecPerKm),
                ),
                unit: 'دق/کم',
                icon: Icons.speed_rounded,
              ),
            ),
          ],
        );

      case MvSessionMode.laps:
        return Row(
          children: [
            Expanded(
              child: MvStatTile(
                title: 'تعداد دور',
                value: laps != null ? toPersianDigits(laps.toString()) : '۰',
                unit: 'دور',
                icon: Icons.pool_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MvStatTile(
                title: 'مدت‌زمان',
                value: toPersianDigits(durationMin.toString()),
                unit: 'دقیقه',
                icon: Icons.timer_rounded,
              ),
            ),
          ],
        );

      case MvSessionMode.match:
        return Row(
          children: [
            Expanded(
              child: MvStatTile(
                title: 'مدت مسابقه',
                value: toPersianDigits(durationMin.toString()),
                unit: 'دقیقه',
                icon: Icons.sports_soccer_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MvStatTile(
                title: 'بار جلسه',
                value: widget.session.sessionLoad != null
                    ? toPersianDigits(widget.session.sessionLoad.toString())
                    : '—',
                unit: 'sRPE',
                icon: Icons.bar_chart_rounded,
              ),
            ),
          ],
        );

      case MvSessionMode.guided:
      case MvSessionMode.structured:
      default:
        return Row(
          children: [
            Expanded(
              child: MvStatTile(
                title: 'مدت‌زمان',
                value: toPersianDigits(durationMin.toString()),
                unit: 'دقیقه',
                icon: Icons.timer_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MvStatTile(
                title: 'ست‌های ثبت‌شده',
                value: toPersianDigits(widget.setLogs.length.toString()),
                unit: 'ست',
                icon: Icons.repeat_rounded,
              ),
            ),
          ],
        );
    }
  }

  Widget _buildEffortButton({
    required Key key,
    required int targetRpe,
    required String emoji,
    required String label,
  }) {
    final colors = context.ritmoColors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;

    final isSelected = _effortSelectedByUser && _rpe == targetRpe;

    return Expanded(
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(metrics.radiusCard),
        child: InkWell(
          key: key,
          onTap: () {
            RitmoHaptics.confirm();
            setState(() {
              _rpe = targetRpe;
              _effortSelectedByUser = true;
            });
          },
          borderRadius: BorderRadius.circular(metrics.radiusCard),
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: metrics.spaceMd,
              horizontal: 4,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? colors.primary.withValues(alpha: 0.12)
                  : colors.surface,
              borderRadius: BorderRadius.circular(metrics.radiusCard),
              border: Border.all(
                color: isSelected ? colors.primary : colors.border,
                width: isSelected ? 2.0 : 1.0,
              ),
            ),
            child: Column(
              children: [
                Text(emoji, style: textTheme.headlineSmall),
                SizedBox(height: metrics.spaceXs),
                Text(
                  label,
                  style: textTheme.labelSmall?.copyWith(
                    color: isSelected ? colors.primary : colors.textSecondary,
                    fontWeight: isSelected
                        ? FontWeight.w800
                        : FontWeight.normal,
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
