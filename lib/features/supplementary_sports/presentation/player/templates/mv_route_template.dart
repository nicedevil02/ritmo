import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/l10n/app_localizations.dart';

/// قالب پلیر برای ورزش‌های مسیرمحور / کوهنوردی / تریل (S4-T3)
class MvRouteTemplate extends StatefulWidget {
  final MvSession session;
  final MvMovementKind? kind;
  final void Function({
    required int elapsedSeconds,
    required double distanceM,
    required double elevationGainM,
    required double packWeightKg,
    required int rpe1To10,
    int? routeId,
  })?
  onFinish;

  const MvRouteTemplate({
    super.key,
    required this.session,
    this.kind,
    this.onFinish,
  });

  @override
  State<MvRouteTemplate> createState() => _MvRouteTemplateState();
}

class _MvRouteTemplateState extends State<MvRouteTemplate> {
  late int _seconds;
  bool _isPaused = false;
  Timer? _timer;

  double _distanceKm = 5.0;
  double _elevationGainM = 400.0;
  double _packWeightKg = 4.0;
  int _rpe = 7;
  int? _selectedRouteId;

  @override
  void initState() {
    super.initState();
    _seconds = widget.session.elapsedSeconds;
    _distanceKm = (widget.session.distanceMeters ?? 5000.0) / 1000.0;
    _elevationGainM = widget.session.elevationGainMeters ?? 400.0;
    _packWeightKg = widget.session.packWeightKg ?? 4.0;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!_isPaused && mounted) {
        setState(() => _seconds++);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
                widget.kind?.titleFa ?? (l10n?.mv_template_route_title ?? 'Route & Mountain Session'),
                style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: metrics.spaceSm),
              // Stopwatch
              Text(
                toPersianDigits(_formatDuration(_seconds)),
                style: textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: metrics.spaceLg),
              // Metrics grid
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      title: l10n?.mv_stat_distance ?? 'Distance',
                      value:
                          '${toPersianDigits(_distanceKm.toStringAsFixed(1))} ${l10n?.mv_unit_km ?? 'km'}',
                      onAdd: () => setState(() => _distanceKm += 0.5),
                      onSub: () {
                        if (_distanceKm > 0.5) setState(() => _distanceKm -= 0.5);
                      },
                    ),
                  ),
                  SizedBox(width: metrics.spaceSm),
                  Expanded(
                    child: _MetricCard(
                      title: l10n?.mv_stat_elevation ?? 'Elevation',
                      value:
                          '${toPersianDigits(_elevationGainM.toInt().toString())} ${l10n?.mv_unit_m ?? 'm'}',
                      onAdd: () => setState(() => _elevationGainM += 50.0),
                      onSub: () {
                        if (_elevationGainM > 50) {
                          setState(() => _elevationGainM -= 50.0);
                        }
                      },
                    ),
                  ),
                  SizedBox(width: metrics.spaceSm),
                  Expanded(
                    child: _MetricCard(
                      title: l10n?.mv_stat_pack_weight ?? 'Pack Weight',
                      value:
                          '${toPersianDigits(_packWeightKg.toStringAsFixed(1))} ${l10n?.mv_unit_kg ?? 'kg'}',
                      onAdd: () => setState(() => _packWeightKg += 0.5),
                      onSub: () {
                        if (_packWeightKg > 0.5) {
                          setState(() => _packWeightKg -= 0.5);
                        }
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: metrics.spaceLg),
              // Route selector
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: metrics.spaceMd,
                        vertical: metrics.spaceSm,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceElevated,
                        borderRadius: BorderRadius.circular(metrics.radiusField),
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n?.mv_template_route_label ?? 'Route',
                            style: textTheme.labelSmall?.copyWith(color: colors.textSecondary),
                          ),
                          DropdownButton<int?>(
                            value: _selectedRouteId,
                            isExpanded: true,
                            underline: const SizedBox.shrink(),
                            items: [
                              DropdownMenuItem(
                                value: null,
                                child: Text(l10n?.mv_template_route_free ?? 'Free Route'),
                              ),
                              DropdownMenuItem(
                                value: 1,
                                child: Text(l10n?.mv_template_route_tochal ?? 'Tochal - Shirpala'),
                              ),
                              DropdownMenuItem(
                                value: 2,
                                child: Text(l10n?.mv_template_route_darakeh ?? 'Darakeh - Palangchal'),
                              ),
                            ],
                            onChanged: (id) {
                              setState(() => _selectedRouteId = id);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: metrics.spaceLg),
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
              SizedBox(height: metrics.spaceLg),
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
                      widget.onFinish?.call(
                        elapsedSeconds: _seconds,
                        distanceM: _distanceKm * 1000.0,
                        elevationGainM: _elevationGainM,
                        packWeightKg: _packWeightKg,
                        rpe1To10: _rpe,
                        routeId: _selectedRouteId,
                      );
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

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback onAdd;
  final VoidCallback onSub;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.onAdd,
    required this.onSub,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = context.ritmoColors;
    final metrics = context.metrics;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: metrics.spaceSm, vertical: metrics.spaceSm),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(metrics.radiusCard),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Text(title, style: textTheme.labelSmall?.copyWith(color: colors.textSecondary)),
          SizedBox(height: metrics.spaceXs),
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: metrics.spaceXs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              InkWell(
                onTap: () {
                  RitmoHaptics.tap();
                  onSub();
                },
                child: Padding(
                  padding: EdgeInsets.all(metrics.spaceXs),
                  child: Icon(Icons.remove, size: metrics.iconSm),
                ),
              ),
              SizedBox(width: metrics.spaceSm),
              InkWell(
                onTap: () {
                  RitmoHaptics.tap();
                  onAdd();
                },
                child: Padding(
                  padding: EdgeInsets.all(metrics.spaceXs),
                  child: Icon(Icons.add, size: metrics.iconSm),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
