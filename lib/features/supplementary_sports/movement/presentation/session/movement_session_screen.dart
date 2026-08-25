// lib/features/supplementary_sports/movement/presentation/session/movement_session_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_kind.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/session_mode.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_session.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/movement_session_repository.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/session/movement_session_notifier.dart';
import 'package:ritmo/features/supplementary_sports/domain/sports_detail_mode.dart';
import 'package:ritmo/features/supplementary_sports/presentation/ss_workout_session_screen.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/features/supplementary_sports/presentation/widgets/shared/ss_screen_awake.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/session/session_surface.dart';

class MovementSessionScreen extends StatefulWidget {
  const MovementSessionScreen({
    super.key,
    required this.session,
    required this.kind,
  });

  final MovementSession session;
  final MovementKind kind;

  @override
  State<MovementSessionScreen> createState() => _MovementSessionScreenState();
}

class _SSWorkoutSessionEmbed extends StatelessWidget {
  const _SSWorkoutSessionEmbed({required this.planId, required this.prescriptionId});
  final String planId;
  final String? prescriptionId;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      child: SSWorkoutSessionScreen(
        planId: planId,
        prescriptionId: prescriptionId,
        dayName: 'تمرین قدرتی ریتمو',
      ),
    );
  }
}

class _MovementSessionScreenState extends State<MovementSessionScreen> {
  late final MovementSessionNotifier _notifier;
  late final SessionMode _mode;
  String? _structuredPlanId;
  bool _isLoadingPlan = false;

  @override
  void initState() {
    super.initState();
    SsScreenAwake.enable();
    _notifier = MovementSessionNotifier(widget.session);
    _mode = effectiveMode(widget.kind);
    _notifier.addListener(_onSessionUpdated);
    
    // Load setting initially
    SportsDetailMode.isEnabled();

    if (_mode == SessionMode.structured) {
      _loadWorkoutPlan();
    }
  }

  Future<void> _loadWorkoutPlan() async {
    setState(() => _isLoadingPlan = true);
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('ss_workout_plan', limit: 1);
      if (rows.isNotEmpty) {
        setState(() {
          _structuredPlanId = rows.first['id'] as String;
        });
      }
    } catch (e) { debugPrint('[ss] movement_session_screen.dart: $e'); }
    setState(() => _isLoadingPlan = false);
  }

  void _onSessionUpdated() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    SsScreenAwake.disable();
    _notifier.removeListener(_onSessionUpdated);
    _notifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_mode == SessionMode.structured && _structuredPlanId != null) {
      return _SSWorkoutSessionEmbed(
        planId: _structuredPlanId!,
        prescriptionId: widget.session.prescriptionId,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoadingPlan
          ? const Center(child: CircularProgressIndicator())
          : MovementSessionSurface(
              notifier: _notifier,
              kind: widget.kind,
              mode: _mode,
            ),
    );
  }
}

class MovementSessionScaffold extends StatefulWidget {
  const MovementSessionScaffold({
    super.key,
    required this.notifier,
    required this.kind,
    required this.mode,
  });

  final MovementSessionNotifier notifier;
  final MovementKind kind;
  final SessionMode mode;

  @override
  State<MovementSessionScaffold> createState() => _MovementSessionScaffoldState();
}

class _MovementSessionScaffoldState extends State<MovementSessionScaffold> {
  int _lastLapTimestamp = 0;
  List<Map<String, dynamic>> _laps = [];

  @override
  void initState() {
    super.initState();
    _lastLapTimestamp = widget.notifier.session.startedAt;
    _loadLaps();
  }

  Future<void> _loadLaps() async {
    final events = await MovementSessionRepository.instance.getSessionEvents(widget.notifier.session.id);
    final lapEvents = events.where((e) => e['type'] == 'LAP').toList();
    if (mounted) {
      setState(() {
        _laps = lapEvents;
        if (lapEvents.isNotEmpty) {
          _lastLapTimestamp = lapEvents.last['at'] as int;
        }
      });
    }
  }

  String _formatDuration(int ms) {
    final sec = (ms / 1000).floor();
    final minutes = (sec / 60).floor();
    final seconds = sec % 60;
    final hours = (minutes / 60).floor();
    
    if (hours > 0) {
      final remMin = minutes % 60;
      return '${hours.toString().padLeft(2, '0')}:${remMin.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _getPaceString(int ms, double distanceMeters) {
    if (distanceMeters <= 0) return '--:--';
    final distanceKm = distanceMeters / 1000.0;
    final min = (ms / 60000.0) / distanceKm;
    final minutes = min.floor();
    final seconds = ((min - minutes) * 60).round();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  double _getPercentOfTarget() {
    final targetJson = widget.notifier.session.targetJson;
    if (targetJson == null) return 0.0;
    try {
      final target = jsonDecode(targetJson) as Map<String, dynamic>;
      if (widget.mode == SessionMode.timed && target.containsKey('minutes')) {
        final targetMs = (target['minutes'] as num).toDouble() * 60 * 1000;
        return (widget.notifier.elapsedMs / targetMs).clamp(0.0, 1.0);
      }
      final live = jsonDecode(widget.notifier.session.liveJson ?? '{}') as Map<String, dynamic>;
      if (widget.mode == SessionMode.distance && target.containsKey('distanceMeters')) {
        final currentDist = (live['manualDistanceMeters'] as num? ?? 0).toDouble();
        final targetDist = (target['distanceMeters'] as num).toDouble();
        return (currentDist / targetDist).clamp(0.0, 1.0);
      }
      if (widget.mode == SessionMode.route && target.containsKey('elevationMeters')) {
        final currentElev = (live['manualElevationMeters'] as num? ?? 0).toDouble();
        final targetElev = (target['elevationMeters'] as num).toDouble();
        return (currentElev / targetElev).clamp(0.0, 1.0);
      }
    } catch (e) { debugPrint('[ss] movement_session_screen.dart: $e'); }
    return 0.0;
  }

  Future<void> _updateLiveValue(String key, double value) async {
    final db = await DatabaseHelper.instance.database;
    final live = jsonDecode(widget.notifier.session.liveJson ?? '{}') as Map<String, dynamic>;
    live[key] = value;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'movement_sessions',
      {
        'liveJson': jsonEncode(live),
        'updatedAt': now,
      },
      where: 'id = ?',
      whereArgs: [widget.notifier.session.id],
    );
    final updated = await MovementSessionRepository.instance.getActiveSession();
    if (updated != null && mounted) {
      setState(() {
        widget.notifier.session = updated;
      });
      widget.notifier.notifyListeners();
    }
  }

  void _showMetricSliderDialog(String title, String key, double min, double max, String unit, double current) {
    double tempVal = current;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${toPersianDigits(tempVal.round().toString())} $unit',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Slider(
                  value: tempVal.clamp(min, max),
                  min: min,
                  max: max,
                  activeColor: const Color(0xFF10B981),
                  onChanged: (val) {
                    setDlgState(() => tempVal = val);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('لغو', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await _updateLiveValue(key, tempVal);
                },
                child: const Text('ثبت', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _recordLap() async {
    RitmoHaptics.confirm();
    final now = DateTime.now().millisecondsSinceEpoch;
    final lapTime = now - _lastLapTimestamp;
    _lastLapTimestamp = now;

    final lapNum = _laps.length + 1;
    await MovementSessionRepository.instance.logSessionEvent(
      widget.notifier.session.id,
      SessionEventType.lap,
      {'lapNumber': lapNum, 'durationMs': lapTime},
    );

    // Save lap count to liveJson
    final live = jsonDecode(widget.notifier.session.liveJson ?? '{}') as Map<String, dynamic>;
    live['laps'] = lapNum;
    await _updateLiveValue('laps', lapNum.toDouble());

    await _loadLaps();
  }

  Future<void> _recordSummit() async {
    RitmoHaptics.success();
    final now = DateTime.now().millisecondsSinceEpoch;
    await MovementSessionRepository.instance.logSessionEvent(
      widget.notifier.session.id,
      SessionEventType.note,
      {'note': 'رسیدم به قله', 'at': now},
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('رویداد رسیدن به قله ثبت شد 🎉', style: TextStyle()),
      ),
    );
  }

  void _finishSessionFlow() {
    RitmoHaptics.success();
    String noteText = '';
    String selectedFeeling = 'EXCELLENT';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('ثبت و پایان تمرین', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('خسته نباشید! حس خودتان بعد از تمرین چطور است؟', style: TextStyle()),
              const SizedBox(height: 16),
              StatefulBuilder(
                builder: (context, setDlgState) => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    IconButton(
                      tooltip: 'حال عالی',
                      icon: Text('🤩', style: TextStyle(fontSize: selectedFeeling == 'EXCELLENT' ? 36 : 24)),
                      onPressed: () => setDlgState(() => selectedFeeling = 'EXCELLENT'),
                    ),
                    IconButton(
                      tooltip: 'حال خوب',
                      icon: Text('🙂', style: TextStyle(fontSize: selectedFeeling == 'GOOD' ? 36 : 24)),
                      onPressed: () => setDlgState(() => selectedFeeling = 'GOOD'),
                    ),
                    IconButton(
                      tooltip: 'حال معمولی',
                      icon: Text('😐', style: TextStyle(fontSize: selectedFeeling == 'NORMAL' ? 36 : 24)),
                      onPressed: () => setDlgState(() => selectedFeeling = 'NORMAL'),
                    ),
                    IconButton(
                      tooltip: 'خسته',
                      icon: Text('😫', style: TextStyle(fontSize: selectedFeeling == 'EXHAUSTED' ? 36 : 24)),
                      onPressed: () => setDlgState(() => selectedFeeling = 'EXHAUSTED'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'یادداشت تمرین (اختیاری)',
                  labelStyle: TextStyle(fontSize: 13),
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontSize: 13),
                onChanged: (val) => noteText = val,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('بازگشت', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
              onPressed: () async {
                Navigator.of(ctx).pop(); // dialog
                Navigator.of(context).pop(); // screen
                await widget.notifier.finish(feeling: selectedFeeling, note: noteText);
              },
              child: const Text('ذخیره', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final targetPercent = _getPercentOfTarget();
    final live = jsonDecode(widget.notifier.session.liveJson ?? '{}') as Map<String, dynamic>;

    return SafeArea(
      child: ValueListenableBuilder<bool>(
        valueListenable: SportsDetailMode.notifier,
        builder: (context, isDetail, _) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Target Progress Bar
                if (widget.notifier.session.targetJson != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'پیشرفت هدف',
                              style: TextStyle(color: colors.textSecondary, fontSize: 11),
                            ),
                            Text(
                              '${toPersianDigits((targetPercent * 100).round().toString())}٪',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: targetPercent,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Header Info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(widget.kind.emoji, style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 8),
                          Text(
                            widget.kind.titleFa,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      // Mode Selector (Simplified / Detailed) Trigger
                      GestureDetector(
                        onTap: () {
                          RitmoHaptics.tap();
                          SportsDetailMode.setEnabled(!isDetail);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isDetail ? 'حالت حرفه‌ای' : 'حالت ساده',
                            style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // 2. Hero Center Stat Display
                Center(
                  child: _buildHeroStat(live),
                ),

                const Spacer(),

                // 3. Pro Mode Extra Lists and Secondary Metrics
                if (isDetail) ...[
                  // Secondary stats grid
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildSecondaryStats(live),
                  ),
                  const SizedBox(height: 20),
                  // Laps list for Lap mode
                  if (widget.mode == SessionMode.laps && _laps.isNotEmpty)
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        itemCount: _laps.length,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        reverse: true,
                        itemBuilder: (ctx, index) {
                          final lap = _laps[index];
                          final data = jsonDecode(lap['dataJson'].toString()) as Map;
                          final durationMs = data['durationMs'] as int;
                          final lapNumber = data['lapNumber'] as int;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('دور $lapNumber', style: const TextStyle(color: Colors.white60)),
                                Text(_formatDuration(durationMs), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 20),
                ],

                // 4. Summit Reached / Lap Complete buttons
                if (widget.notifier.session.status == MovementSessionStatus.active) ...[
                  if (widget.mode == SessionMode.route)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigoAccent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        onPressed: _recordSummit,
                        icon: const Icon(Icons.terrain, color: Colors.white),
                        label: const Text('رسیدم به قله 🏔️', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  if (widget.mode == SessionMode.laps)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 24), // very large and easy to press
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _recordLap,
                        icon: const Icon(Icons.timer, color: Colors.white, size: 28),
                        label: const Text('ثبت دور جدید', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                      ),
                    ),
                ],

                // 5. Main Controls (Start/Pause/Resume/Stop)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                  child: widget.notifier.session.status == MovementSessionStatus.active
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FloatingActionButton.large(
                              heroTag: 'pause',
                              backgroundColor: Colors.amber,
                              onPressed: () {
                                RitmoHaptics.tap();
                                widget.notifier.pause();
                              },
                              child: const Icon(Icons.pause, size: 36, color: Colors.black),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            FloatingActionButton.large(
                              heroTag: 'resume',
                              backgroundColor: const Color(0xFF10B981),
                              onPressed: () {
                                RitmoHaptics.tap();
                                widget.notifier.resume();
                              },
                              child: const Icon(Icons.play_arrow, size: 40, color: Colors.white),
                            ),
                            FloatingActionButton.large(
                              heroTag: 'stop',
                              backgroundColor: Colors.red,
                              onPressed: _finishSessionFlow,
                              child: const Icon(Icons.stop, size: 40, color: Colors.white),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroStat(Map<String, dynamic> live) {
    if (widget.mode == SessionMode.distance) {
      final meters = (live['manualDistanceMeters'] as num? ?? 0.0).toDouble();
      final km = meters / 1000.0;
      return Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                toPersianDigits(km.toStringAsFixed(2)),
                style: const TextStyle(color: Colors.white, fontSize: 72, fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 8),
              const Text(
                'کیلومتر',
                style: TextStyle(color: Colors.white60, fontSize: 24),
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: 'ویرایش',
                icon: const Icon(Icons.edit, color: Colors.white54),
                onPressed: () {
                  RitmoHaptics.tap();
                  _showMetricSliderDialog('ثبت مسافت دستی', 'manualDistanceMeters', 0, 20000, 'متر', meters);
                },
              ),
            ],
          ),
          Text(
            '${toPersianDigits(_formatDuration(widget.notifier.elapsedMs))} | تمپو: ${toPersianDigits(_getPaceString(widget.notifier.elapsedMs, meters))}',
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      );
    }

    if (widget.mode == SessionMode.route) {
      final meters = (live['manualElevationMeters'] as num? ?? 0.0).toDouble();
      return Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                toPersianDigits(meters.round().toString()),
                style: const TextStyle(color: Colors.white, fontSize: 72, fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 8),
              const Text(
                'متر صعود',
                style: TextStyle(color: Colors.white60, fontSize: 24),
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: 'ویرایش',
                icon: const Icon(Icons.edit, color: Colors.white54),
                onPressed: () {
                  RitmoHaptics.tap();
                  _showMetricSliderDialog('ثبت ارتفاع صعود', 'manualElevationMeters', 0, 3000, 'متر', meters);
                },
              ),
            ],
          ),
          Text(
            toPersianDigits(_formatDuration(widget.notifier.elapsedMs)),
            style: const TextStyle(color: Colors.white70, fontSize: 18),
          ),
        ],
      );
    }

    if (widget.mode == SessionMode.laps) {
      final lapCount = _laps.length;
      return Column(
        children: [
          Text(
            toPersianDigits('$lapCount دور'),
            style: const TextStyle(color: Colors.white, fontSize: 72, fontWeight: FontWeight.w900),
          ),
          Text(
            toPersianDigits(_formatDuration(widget.notifier.elapsedMs)),
            style: const TextStyle(color: Colors.white70, fontSize: 18),
          ),
        ],
      );
    }

    if (widget.mode == SessionMode.match) {
      final hostScore = (live['hostScore'] as num? ?? 0).toInt();
      final guestScore = (live['guestScore'] as num? ?? 0).toInt();
      return Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'افزودن',
                icon: const Icon(Icons.add_circle_outline, color: Colors.white70, size: 36),
                onPressed: () => _updateLiveValue('hostScore', (hostScore + 1).toDouble()),
              ),
              Text(
                toPersianDigits('$hostScore - $guestScore'),
                style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.w900),
              ),
              IconButton(
                tooltip: 'افزودن',
                icon: const Icon(Icons.add_circle_outline, color: Colors.white70, size: 36),
                onPressed: () => _updateLiveValue('guestScore', (guestScore + 1).toDouble()),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            toPersianDigits(_formatDuration(widget.notifier.elapsedMs)),
            style: const TextStyle(color: Colors.white70, fontSize: 18),
          ),
        ],
      );
    }

    // Default: timed mode
    return Text(
      toPersianDigits(_formatDuration(widget.notifier.elapsedMs)),
      style: const TextStyle(color: Colors.white, fontSize: 80, fontWeight: FontWeight.w200),
    );
  }

  Widget _buildSecondaryStats(Map<String, dynamic> live) {
    final calories = (widget.notifier.elapsedMs / 60000.0) * (widget.kind.baseMet) * 1.2;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatCard('مدت زمان', _formatDuration(widget.notifier.elapsedMs)),
        _buildStatCard('کالری تقریبی', '${calories.round()} کیلوکالری'),
        if (widget.mode == SessionMode.distance)
          _buildStatCard('سرعت متوسط', '${((live['manualDistanceMeters'] as num? ?? 0) / 1000.0 / (widget.notifier.elapsedMs / 3600000.0)).toStringAsFixed(1)} کیلومتر/ساعت'),
        if (widget.mode == SessionMode.route)
          _buildStatCard('سرعت صعود', '${((live['manualElevationMeters'] as num? ?? 0) / (widget.notifier.elapsedMs / 3600000.0)).round()} متر/ساعت'),
      ],
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 4),
          Text(toPersianDigits(value), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}
