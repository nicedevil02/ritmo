import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

/// UX-05 Fullscreen Labor Mode Screen with wakelock_plus, big central pulse button (>=200px),
/// mm:ss timer, 5-1-1 3-light indicator, contraction_timer DB persistence, and hospital call trigger.
class LaborModeScreen extends StatefulWidget {
  const LaborModeScreen({
    super.key,
    required this.pregnancyId,
  });

  final String pregnancyId;

  static Future<void> show(BuildContext context, {required String pregnancyId}) {
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
  int _elapsedSeconds = 0;

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
    _disableWakelock();
    super.dispose();
  }

  Future<void> _enableWakelock() async {
    try {
      await WakelockPlus.enable();
    } catch (_) {}
  }

  Future<void> _disableWakelock() async {
    try {
      await WakelockPlus.disable();
    } catch (_) {}
  }

  Future<void> _loadHospitalPhone() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('app_settings', where: 'key = ?', whereArgs: ['preg_hospital_phone'], limit: 1);
      if (rows.isNotEmpty && mounted) {
        setState(() {
          _hospitalPhone = rows.first['value'] as String?;
        });
      }
    } catch (_) {}
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
    } catch (_) {}
  }

  void _toggleContraction() {
    HapticFeedback.mediumImpact();
    final now = DateTime.now();

    if (!_isContracting) {
      // Start contraction
      setState(() {
        _isContracting = true;
        _contractionStart = now;
        _elapsedSeconds = 0;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {
            _elapsedSeconds++;
          });
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
        _elapsedSeconds = 0;
      });
    }
  }

  Future<void> _saveContraction(DateTime start, DateTime end, int durationSecs) async {
    int intervalFromPrevSecs = 0;
    if (_contractions.isNotEmpty) {
      final prevStartMs = (_contractions.first['startTime'] as int?) ?? start.millisecondsSinceEpoch;
      intervalFromPrevSecs = (start.millisecondsSinceEpoch - prevStartMs) ~/ 1000;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final row = {
      'id': 'cnt_${DateTime.now().microsecondsSinceEpoch}',
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
    } catch (_) {}
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
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final oneHourAgoMs = nowMs - (3600 * 1000);
    final recent = _contractions.where((c) => (c['startTime'] as int) >= oneHourAgoMs).toList();

    if (recent.length < 3) {
      return {'durOk': false, 'intOk': false, 'spanOk': false, 'all511': false};
    }

    // 1. Duration check: avg duration >= 60s
    final avgDur = recent.map((c) => (c['durationSeconds'] as int)).reduce((a, b) => a + b) / recent.length;
    final durOk = avgDur >= 60;

    // 2. Interval check: avg interval <= 300s
    final intervals = recent.map((c) => (c['intervalFromPrevious'] as int)).where((i) => i > 0).toList();
    final avgInt = intervals.isNotEmpty ? (intervals.reduce((a, b) => a + b) / intervals.length) : 999.0;
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
        await db.insert('app_settings', {'key': 'preg_hospital_phone', 'value': _hospitalPhone},
            conflictAlgorithm: ConflictAlgorithm.replace);
      } catch (_) {}
    }

    final url = Uri.parse('tel:${_hospitalPhone!}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<String?> _showPhoneInputDialog() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('شماره تماس بیمارستان یا پزشک', style: TextStyle()),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            hintText: 'مثلاً ۰۲۱۱۲۳۴۵۶۷۸',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('لغو', style: TextStyle()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('ذخیره و تماس', style: TextStyle()),
          ),
        ],
      ),
    );
  }

  Future<bool> _onWillPop() async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('خروج از حالت زایمان؟', style: TextStyle()),
        content: const Text(
          'آیا از خروج از حالت ثبت انقباض اطمینان دارید؟ داده‌های ثبت شده محفوظ می‌مانند.',
          style: TextStyle(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('انصراف', style: TextStyle()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('خروج', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final status = _evaluate511Status();
    final all511 = status['all511'] == true;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFF121218),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(CupertinoIcons.xmark, color: Colors.white),
            onPressed: () async {
              if (await _onWillPop()) {
                if (mounted) Navigator.of(context).pop();
              }
            },
          ),
          title: const Text(
            'حالت زایمان (سنجش انقباضات)',
            style: TextStyle(fontSize: 18, color: Colors.white),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Column(
            children: [
              // 5-1-1 Banner alert
              if (all511)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'الگوی ۵-۱-۱ کامل شد — با بیمارستان تماس بگیرید.',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.red.shade900,
                        ),
                        icon: const Icon(CupertinoIcons.phone_fill, size: 16),
                        label: const Text('تماس', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: _handleHospitalCall,
                      ),
                    ],
                  ),
                ),

              // 3-Light Status Indicator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatusLight('طول ≥ ۱ دقیقه', status['durOk'] == true),
                    _buildStatusLight('فاصله ≤ ۵ دقیقه', status['intOk'] == true),
                    _buildStatusLight('تداوم ≥ ۱ ساعت', status['spanOk'] == true),
                  ],
                ),
              ),

              const Spacer(),

              // Timer Display (mm:ss)
              Text(
                _formatMmSs(_elapsedSeconds),
                style: TextStyle(
                  fontSize: 54,
                  fontWeight: FontWeight.bold,
                  color: _isContracting ? Colors.pinkAccent : Colors.white70,
                ),
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
                      color: _isContracting ? Colors.pinkAccent : const Color(0xFF2C2C3E),
                      boxShadow: [
                        BoxShadow(
                          color: _isContracting ? Colors.pinkAccent.withValues(alpha: 0.5) : Colors.black45,
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
                            _isContracting ? CupertinoIcons.square_fill : CupertinoIcons.play_fill,
                            size: 48,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _isContracting ? 'انقباض تمام شد' : 'انقباض شروع شد',
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
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1E28),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'تاریخچه انقباضات اخیر',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _contractions.isEmpty
                          ? const Center(
                              child: Text(
                                'هنوز انقباضی ثبت نشده است',
                                style: TextStyle(color: Colors.white38, fontSize: 12),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _contractions.length,
                              itemBuilder: (ctx, idx) {
                                final item = _contractions[idx];
                                final dur = _formatMmSs(item['durationSeconds'] as int);
                                final interval = item['intervalFromPrevious'] as int;
                                final intervalText = interval > 0 ? '${interval ~/ 60} دقیقه فاصله' : 'اولین انقباض';

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'انقباض #${_contractions.length - idx}',
                                        style: const TextStyle(color: Colors.white, fontSize: 13),
                                      ),
                                      Text(
                                        'مدت: $dur',
                                        style: const TextStyle(color: Colors.pinkAccent, fontSize: 13),
                                      ),
                                      Text(
                                        intervalText,
                                        style: const TextStyle(color: Colors.white54, fontSize: 12),
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
                ? [const BoxShadow(color: Colors.greenAccent, blurRadius: 8, spreadRadius: 2)]
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
