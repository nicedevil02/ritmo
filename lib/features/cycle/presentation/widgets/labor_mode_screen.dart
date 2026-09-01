import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/upsert_helper.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';

/// UX-05 Fullscreen Labor Mode Screen with wakelock_plus, big central pulse button (>=200px),
/// mm:ss timer, 5-1-1 3-light indicator, contraction_timer DB persistence, and hospital call trigger.
class LaborModeScreen extends StatefulWidget {
  const LaborModeScreen({super.key, required this.pregnancyId});

  final String pregnancyId;

  static Future<void> show(
    BuildContext context, {
    required String pregnancyId,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => LaborModeScreen(pregnancyId: pregnancyId),
      ),
    );
  }

  @override
  State<LaborModeScreen> createState() => _LaborModeScreenState();
}

class _LaborModeScreenState extends State<LaborModeScreen> {
  bool _isContracting = false;
  DateTime? _contractionStart;
  Timer? _timer;
  final ValueNotifier<int> _elapsedSecondsNotifier = ValueNotifier<int>(0);

  final List<Map<String, dynamic>> _contractions = [];
  String? _hospitalPhone;

  @override
  void initState() {
    super.initState();
    _enableWakelock();
    _loadHospitalPhone();
    _loadRecentContractions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _elapsedSecondsNotifier.dispose();
    _disableWakelock();
    super.dispose();
  }

  Future<void> _enableWakelock() async {
    try {
      await WakelockPlus.enable();
    } catch (e, st) {
      RitmoLog.error('LaborModeScreen', 'Failed to enable wakelock: $e', e, st);
    }
  }

  Future<void> _disableWakelock() async {
    try {
      await WakelockPlus.disable();
    } catch (e, st) {
      RitmoLog.error(
        'LaborModeScreen',
        'Failed to disable wakelock: $e',
        e,
        st,
      );
    }
  }

  Future<void> _loadHospitalPhone() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: ['preg_hospital_phone'],
        limit: 1,
      );
      if (rows.isNotEmpty && mounted) {
        setState(() {
          _hospitalPhone = rows.first['value'] as String?;
        });
      }
    } catch (e, st) {
      RitmoLog.error(
        'LaborModeScreen',
        'Failed to load hospital phone: $e',
        e,
        st,
      );
    }
  }

  Future<void> _loadRecentContractions() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'contraction_timer',
        where: 'pregnancyId = ?',
        whereArgs: [widget.pregnancyId],
        orderBy: 'startTime DESC',
        limit: 20,
      );
      if (mounted) {
        setState(() {
          _contractions.clear();
          _contractions.addAll(rows);
        });
      }
    } catch (e, st) {
      RitmoLog.error(
        'LaborModeScreen',
        'Failed to load contractions: $e',
        e,
        st,
      );
    }
  }

  void _toggleContraction() {
    HapticFeedback.mediumImpact();
    final now = CycleClock.now;

    if (!_isContracting) {
      // Start contraction
      setState(() {
        _isContracting = true;
        _contractionStart = now;
      });
      _elapsedSecondsNotifier.value = 0;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_contractionStart != null) {
          _elapsedSecondsNotifier.value =
              CycleClock.now.difference(_contractionStart!).inSeconds;
        }
      });
    } else {
      // End contraction
      _timer?.cancel();
      final start = _contractionStart ?? now;
      final durationSecs = now.difference(start).inSeconds;

      if (durationSecs >= 10) {
        _saveContraction(start, now, durationSecs);
      }

      setState(() {
        _isContracting = false;
        _contractionStart = null;
      });
      _elapsedSecondsNotifier.value = 0;
    }
  }

  Future<void> _saveContraction(
    DateTime start,
    DateTime end,
    int durationSecs,
  ) async {
    int intervalFromPrevSecs = 0;
    if (_contractions.isNotEmpty) {
      final prevStartMs =
          (_contractions.first['startTime'] as int?) ??
          start.millisecondsSinceEpoch;
      intervalFromPrevSecs =
          (start.millisecondsSinceEpoch - prevStartMs) ~/ 1000;
    }

    final nowMs = CycleClock.nowMillisecondsSinceEpoch;
    final row = {
      'id': 'cnt_${CycleClock.now.microsecondsSinceEpoch}',
      'pregnancyId': widget.pregnancyId,
      'startTime': start.millisecondsSinceEpoch,
      'endTime': end.millisecondsSinceEpoch,
      'durationSeconds': durationSecs,
      'intervalFromPrevious': intervalFromPrevSecs,
      'createdAt': nowMs,
    };

    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert('contraction_timer', row);
      await _loadRecentContractions();
    } catch (e, st) {
      RitmoLog.error(
        'LaborModeScreen',
        'Failed to insert contraction: $e',
        e,
        st,
      );
    }
  }

  String _formatMmSs(int totalSeconds) {
    final mins = totalSeconds ~/ 60;
    final secs = totalSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Calculates 5-1-1 rule lights (Duration >= 60s, Interval <= 300s, Span >= 3600s).
  Map<String, bool> _evaluate511Status() {
    if (_contractions.length < 3) {
      return {'durOk': false, 'intOk': false, 'spanOk': false, 'all511': false};
    }

    // Filter recent contractions within last 1 hour
    final nowMs = CycleClock.nowMillisecondsSinceEpoch;
    final oneHourAgoMs = nowMs - (3600 * 1000);
    final recent = _contractions
        .where((c) => (c['startTime'] as int) >= oneHourAgoMs)
        .toList();

    if (recent.length < 3) {
      return {'durOk': false, 'intOk': false, 'spanOk': false, 'all511': false};
    }

    // 1. Duration check: avg duration >= 60s
    final avgDur =
        recent
            .map((c) => (c['durationSeconds'] as int))
            .reduce((a, b) => a + b) /
        recent.length;
    final durOk = avgDur >= 60;

    // 2. Interval check: avg interval <= 300s
    final intervals = recent
        .map((c) => (c['intervalFromPrevious'] as int))
        .where((i) => i > 0)
        .toList();
    final avgInt = intervals.isNotEmpty
        ? (intervals.reduce((a, b) => a + b) / intervals.length)
        : 999.0;
    final intOk = avgInt <= 300;

    // 3. Continuity check: span between oldest and newest >= 3600s (or at least 50 mins)
    final oldest = recent.last['startTime'] as int;
    final newest = recent.first['startTime'] as int;
    final spanOk = (newest - oldest) >= (50 * 60 * 1000);

    final all511 = durOk && intOk && spanOk;
    return {'durOk': durOk, 'intOk': intOk, 'spanOk': spanOk, 'all511': all511};
  }

  Future<void> _handleHospitalCall() async {
    if (_hospitalPhone == null || _hospitalPhone!.trim().isEmpty) {
      final input = await _showPhoneInputDialog();
      if (input == null || input.trim().isEmpty) return;
      _hospitalPhone = input.trim();
      try {
        final db = await DatabaseHelper.instance.database;
        final now = CycleClock.nowMillisecondsSinceEpoch;
        await UpsertHelper.upsert(
          db,
          'app_settings',
          {
            'key': 'preg_hospital_phone',
            'value': _hospitalPhone,
            'updatedAt': now,
          },
          conflictColumns: const ['key'],
        );
      } catch (e, st) {
        RitmoLog.error(
          'LaborModeScreen',
          'Failed to save hospital phone: $e',
          e,
          st,
        );
      }
    }

    final url = Uri.parse('tel:${_hospitalPhone!}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<String?> _showPhoneInputDialog() {
    final controller = TextEditingController();
    final colors = context.colors;

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: RitmoGlassSheet(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.border.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'شماره تماس بیمارستان یا پزشک',
                  style: RitmoTextStyles.cardTitle(colors.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                RitmoCard.neumorphicSunken(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(color: colors.textPrimary, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'مثلاً ۰۲۱۱۲۳۴۵۶۷۸',
                      hintStyle: TextStyle(color: colors.textTertiary),
                      border: InputBorder.none,
                      prefixIcon: Icon(CupertinoIcons.phone, color: colors.primary, size: 20),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: RitmoNeuButton(
                        onTap: () => Navigator.of(ctx).pop(),
                        child: Text(
                          'لغو',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: RitmoPrimaryButton(
                        label: 'ذخیره و تماس',
                        onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    final res = await RitmoDialog.show(
      context,
      title: 'خروج از حالت زایمان؟',
      content:
          'آیا از خروج از حالت ثبت انقباض اطمینان دارید؟ داده‌های ثبت شده محفوظ می‌مانند.',
      confirmLabel: 'خروج',
      cancelLabel: 'انصراف',
      isDestructive: true,
    );
    return res ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final status = _evaluate511Status();
    final all511 = status['all511'] == true;
    final colors = context.colors;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final canPop = await _onWillPop();
        if (canPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: colors.surface,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: RitmoGlassHeader(
                  borderRadius: BorderRadius.circular(22),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(CupertinoIcons.xmark, color: colors.textPrimary, size: 20),
                        onPressed: () async {
                          final canPop = await _onWillPop();
                          if (canPop && context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                      Text(
                        'حالت زایمان (سنجش انقباضات)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 44),
                    ],
                  ),
                ),
              ),
              // 5-1-1 Banner alert
              if (all511)
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        CupertinoIcons.exclamationmark_triangle_fill,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'الگوی ۵-۱-۱ کامل شد — با بیمارستان تماس بگیرید.',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.red.shade900,
                        ),
                        icon: const Icon(CupertinoIcons.phone_fill, size: 16),
                        label: const Text(
                          'تماس',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: _handleHospitalCall,
                      ),
                    ],
                  ),
                ),

              // 3-Light Status Indicator
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatusLight('طول ≥ ۱ دقیقه', status['durOk'] == true),
                    _buildStatusLight(
                      'فاصله ≤ ۵ دقیقه',
                      status['intOk'] == true,
                    ),
                    _buildStatusLight(
                      'تداوم ≥ ۱ ساعت',
                      status['spanOk'] == true,
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Timer Display (mm:ss)
              ValueListenableBuilder<int>(
                valueListenable: _elapsedSecondsNotifier,
                builder: (context, elapsed, _) {
                  return Text(
                    _formatMmSs(elapsed),
                    style: TextStyle(
                      fontSize: 54,
                      fontWeight: FontWeight.bold,
                      color: _isContracting ? colors.primary : colors.textSecondary,
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              // Big Central Pulse Button (Diameter >= 200 logical pixels)
              Semantics(
                button: true,
                label: _isContracting ? 'انقباض تمام شد' : 'انقباض شروع شد',
                child: GestureDetector(
                  onTap: _toggleContraction,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isContracting
                          ? colors.primary
                          : colors.surfaceElevated,
                      boxShadow: [
                        BoxShadow(
                          color: _isContracting
                              ? colors.primary.withValues(alpha: 0.5)
                              : Colors.black26,
                          blurRadius: _isContracting ? 30 : 10,
                          spreadRadius: _isContracting ? 8 : 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isContracting
                                ? CupertinoIcons.square_fill
                                : CupertinoIcons.play_fill,
                            size: 48,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _isContracting
                                ? 'انقباض تمام شد'
                                : 'انقباض شروع شد',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // Contractions History List
              Container(
                height: 160,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceElevated,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تاریخچه انقباضات اخیر',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _contractions.isEmpty
                          ? const Center(
                              child: Text(
                                'هنوز انقباضی ثبت نشده است',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _contractions.length,
                              itemBuilder: (ctx, idx) {
                                final item = _contractions[idx];
                                final dur = _formatMmSs(
                                  item['durationSeconds'] as int,
                                );
                                final interval =
                                    item['intervalFromPrevious'] as int;
                                final intervalText = interval > 0
                                    ? '${interval ~/ 60} دقیقه فاصله'
                                    : 'اولین انقباض';

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'انقباض #${_contractions.length - idx}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        'مدت: $dur',
                                        style: const TextStyle(
                                          color: Colors.pinkAccent,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        intervalText,
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusLight(String label, bool isActive) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? Colors.greenAccent : Colors.grey.shade800,
            boxShadow: isActive
                ? [
                    const BoxShadow(
                      color: Colors.greenAccent,
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isActive ? Colors.white : Colors.white38,
          ),
        ),
      ],
    );
  }
}
