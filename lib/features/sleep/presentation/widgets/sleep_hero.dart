import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/widgets/ritmo_sheet_scaffold.dart';
import 'package:ritmo/features/sleep/models/sleep_models.dart';
import 'package:ritmo/features/sleep/presentation/widgets/sleep_log_sheet.dart';

class SleepHero extends StatefulWidget {

  const SleepHero({
    super.key,
    this.lastNight,
    required this.target,
    required this.onRefresh,
  });
  final SleepLog? lastNight;
  final SleepTarget target;
  final VoidCallback onRefresh;

  @override
  State<SleepHero> createState() => _SleepHeroState();
}

class _SleepHeroState extends State<SleepHero> with WidgetsBindingObserver {
  Timer? _timer;
  String _countdownText = '';
  bool _isWinddownActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTimer();
    } else if (state == AppLifecycleState.paused) {
      _stopTimer();
    }
  }

  void _startTimer() {
    _stopTimer();
    _updateCountdown();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _updateCountdown();
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTimer();
    super.dispose();
  }

  void _updateCountdown() {
    if (!mounted) return;
    
    final now = DateTime.now();
    var bedtime = DateTime(now.year, now.month, now.day, widget.target.bedtimeHour, widget.target.bedtimeMinute);
    
    if (now.isAfter(bedtime)) {
      bedtime = bedtime.add(const Duration(days: 1));
    }

    final diff = bedtime.difference(now);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;

    // Standard wind-down trigger is 30 minutes before bedtime
    final totalDiffMin = diff.inMinutes;
    final isWinddown = totalDiffMin <= 30;

    setState(() {
      _isWinddownActive = isWinddown;
      if (isWinddown) {
        _countdownText = '🌙 وقتشه آروم آروم آماده‌ی خواب بشی (حدود ${totalDiffMin.abs()} د دیگه)';
      } else {
        _countdownText = '$hours ساعت و $minutes دقیقه تا زمان خواب هدف شما 😴';
      }
    });
  }

  void _showLogSheet() {
    RitmoSheetScaffold.present(
      context: context,
      title: 'ثبت خواب دیشب',
      builder: (ctx) => SleepLogSheet(
        target: widget.target,
        onSaved: widget.onRefresh,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final m = context.metrics;
    final lastLog = widget.lastNight;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: m.spaceLg, vertical: m.spaceMd),
      child: RitmoTheme.glassCardLight(
        border: Border.all(
          color: _isWinddownActive
              ? colors.accent.withValues(alpha: 0.5)
              : colors.glassBorder,
          width: _isWinddownActive ? 2.0 : 1.0,
        ),
        child: Padding(
          padding: EdgeInsets.all(m.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title / Top Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'وضعیت خواب اخیر شما',
                    style: RitmoTextStyles.badge(
                      colors.cardSubtitle,
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (lastLog != null)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: m.spaceSm, vertical: m.spaceXs),
                      decoration: BoxDecoration(
                        color: colors.cardFill,
                        borderRadius: BorderRadius.circular(m.radiusCard),
                      ),
                      child: Row(
                        children: [
                          Text(lastLog.quality.emoji, style: RitmoTextStyles.label(colors.cardTitle)),
                          SizedBox(width: m.spaceXs),
                          Text(
                            lastLog.quality.label,
                            style: RitmoTextStyles.badge(
                              colors.cardTitle,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              SizedBox(height: m.spaceLg),

              // Main content - Duration
              if (lastLog != null) ...[
                // Sleep registered
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${lastLog.durationMinutes ~/ 60}',
                        style: RitmoTextStyles.displayLarge(
                          colors.cardTitle,
                        ).copyWith(fontWeight: FontWeight.w900),
                      ),
                      SizedBox(width: m.spaceXs),
                      Text(
                        'ساعت',
                        style: RitmoTextStyles.badge(
                          colors.cardSubtitle,
                        ),
                      ),
                      SizedBox(width: m.spaceSm),
                      Text(
                        '${lastLog.durationMinutes % 60}',
                        style: RitmoTextStyles.displayLarge(
                          colors.cardTitle,
                        ).copyWith(fontWeight: FontWeight.w900),
                      ),
                      SizedBox(width: m.spaceXs),
                      Text(
                        'دقیقه',
                        style: RitmoTextStyles.badge(
                          colors.cardSubtitle,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: m.spaceSm),
                Row(
                  children: [
                    _buildTargetStatusChip(lastLog),
                  ],
                ),
              ] else ...[
                // Sleep not registered
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'خواب دیشب ثبت نشده 🌙',
                      style: RitmoTextStyles.titleMedium(
                        colors.cardTitle,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'برای سنجش بدهی خواب و تأثیر آن روی انرژی، وضعیت خواب خود را ثبت کنید.',
                      style: RitmoTextStyles.caption(
                        colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],

              SizedBox(height: m.spaceLg),
              Divider(color: colors.glassBorder),
              SizedBox(height: m.spaceMd),

              // Bedtime Countdown
              Container(
                padding: EdgeInsets.all(m.spaceMd),
                decoration: BoxDecoration(
                  color: _isWinddownActive
                      ? colors.accent.withValues(alpha: 0.1)
                      : colors.cardFill,
                  borderRadius: BorderRadius.circular(m.radiusCard),
                  border: Border.all(
                    color: _isWinddownActive
                        ? colors.accent.withValues(alpha: 0.2)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isWinddownActive ? CupertinoIcons.bell : CupertinoIcons.time,
                      color: _isWinddownActive ? colors.accent : colors.textSecondary,
                      size: m.iconSm,
                    ),
                    SizedBox(width: m.spaceSm),
                    Expanded(
                      child: Text(
                        _countdownText,
                        style: RitmoTextStyles.caption(
                          _isWinddownActive ? colors.cardTitle : colors.textSecondary,
                        ).copyWith(
                          fontWeight: _isWinddownActive ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: m.spaceLg),

              // Action button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: m.spaceMd),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(m.radiusCard),
                  ),
                  elevation: 0,
                ),
                onPressed: _showLogSheet,
                child: Text(
                  lastLog != null ? 'ثبت مجدد خواب دیشب' : 'ثبت خواب دیشب',
                  style: RitmoTextStyles.badge(
                    Colors.white,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTargetStatusChip(SleepLog log) {
    final colors = context.colors;
    final m = context.metrics;
    final diff = log.durationMinutes - widget.target.durationMinutes;
    final isOk = diff >= 0;
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: m.spaceSm, vertical: m.spaceXs),
      decoration: BoxDecoration(
        color: isOk ? colors.success.withValues(alpha: 0.1) : colors.medicalRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(m.radiusCard),
        border: Border.all(
          color: isOk ? colors.success.withValues(alpha: 0.2) : colors.medicalRed.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOk ? CupertinoIcons.checkmark_alt_circle_fill : CupertinoIcons.exclamationmark_circle_fill,
            color: isOk ? colors.success : colors.medicalRed,
            size: m.iconSm * 0.8,
          ),
          SizedBox(width: m.spaceXs),
          Text(
            isOk ? 'به هدف خواب رسیدی' : '${diff.abs()} دقیقه کمتر از هدف',
            style: RitmoTextStyles.badge(
              isOk ? colors.success : colors.medicalRed,
            ).copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
