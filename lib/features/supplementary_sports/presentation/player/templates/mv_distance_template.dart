import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/l10n/app_localizations.dart';

/// قالب پلیر برای ورزش‌های مسافت‌محور (دویدن، دوچرخه، پیاده‌روی تند) (S4-T3)
class MvDistanceTemplate extends StatefulWidget {
  final MvSession session;
  final MvMovementKind? kind;
  final void Function(int elapsedSeconds, double distanceM, int rpe1To10)?
  onFinish;

  const MvDistanceTemplate({
    super.key,
    required this.session,
    this.kind,
    this.onFinish,
  });

  @override
  State<MvDistanceTemplate> createState() => _MvDistanceTemplateState();
}

class _MvDistanceTemplateState extends State<MvDistanceTemplate> {
  late int _seconds;
  late double _distanceKm;
  int _rpe = 7;
  bool _isPaused = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _seconds = widget.session.elapsedSeconds;
    _distanceKm = (widget.session.distanceMeters ?? 3000.0) / 1000.0;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused && mounted) {
        setState(() {
          _seconds++;
        });
      }
    });
  }

  String _formatDuration(int totalSec) {
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = context.ritmoColors;
    final metrics = context.metrics;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(metrics.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                widget.kind?.titleFa ?? (l10n?.mv_template_distance_title ?? 'Distance Session'),
                style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: metrics.spaceMd),
              // Distance hero display
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    toPersianDigits(_distanceKm.toStringAsFixed(2)),
                    style: textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(width: metrics.spaceSm),
                  Text(
                    l10n?.mv_unit_km ?? 'km',
                    style: textTheme.titleMedium?.copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
              // Stopwatch
              Text(
                toPersianDigits(_formatDuration(_seconds)),
                style: textTheme.headlineMedium?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: metrics.spaceLg),
              // Distance adjuster (+ / -)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.outlined(
                    icon: Icon(Icons.remove, size: metrics.iconMd),
                    onPressed: () {
                      if (_distanceKm > 0.5) {
                        RitmoHaptics.tap();
                        setState(() => _distanceKm = (_distanceKm - 0.5));
                      }
                    },
                  ),
                  SizedBox(width: metrics.spaceLg),
                  Text(
                    l10n?.mv_template_distance_adjust ?? 'Adjust Distance',
                    style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(width: metrics.spaceLg),
                  IconButton.outlined(
                    icon: Icon(Icons.add, size: metrics.iconMd),
                    onPressed: () {
                      RitmoHaptics.tap();
                      setState(() => _distanceKm = (_distanceKm + 0.5));
                    },
                  ),
                ],
              ),
              SizedBox(height: metrics.spaceXl),
              // Effort slider
              Text(
                l10n?.mv_template_rpe_label(toPersianDigits(_rpe.toString())) ?? 'Effort (RPE: $_rpe)',
                style: textTheme.bodyMedium,
              ),
              Slider(
                value: _rpe.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                label: _rpe.toString(),
                onChanged: (val) => setState(() => _rpe = val.round()),
              ),
              SizedBox(height: metrics.spaceXl),
              // Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    iconSize: metrics.iconXl,
                    icon: Icon(
                      _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    ),
                    onPressed: () {
                      RitmoHaptics.tap();
                      setState(() => _isPaused = !_isPaused);
                    },
                  ),
                  SizedBox(width: metrics.spaceXl),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: metrics.spaceXl,
                        vertical: metrics.spaceMd,
                      ),
                    ),
                    icon: Icon(Icons.check_circle_rounded, size: metrics.iconMd),
                    label: Text(l10n?.mv_template_finish ?? 'Finish Session'),
                    onPressed: () {
                      RitmoHaptics.success();
                      final distanceMeters = _distanceKm * 1000.0;
                      widget.onFinish?.call(_seconds, distanceMeters, _rpe);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
