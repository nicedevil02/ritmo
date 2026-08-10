import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/time/ritmo_clock.dart';
import 'package:ritmo/core/utils/cycle_privacy_guard.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_date_picker.dart';
import 'package:ritmo/features/health/data/pregnancy_repository.dart';
import 'package:sqflite/sqflite.dart';

class PregnancySection extends StatefulWidget {
  const PregnancySection({
    super.key,
  });

  @override
  State<PregnancySection> createState() => _PregnancySectionState();
}

class _PregnancySectionState extends State<PregnancySection> with TickerProviderStateMixin {
  late TabController _tabController;

  // Configuration flags
  bool _isVisible = false;
  bool _isLoading = true;
  bool _isStarting = false;
  bool _hasSelectedLmp = false;

  // Active tracker details
  Map<String, dynamic>? _activeTracker;
  List<Map<String, dynamic>> _checkups = [];
  List<Map<String, dynamic>> _kickLogs = [];
  List<Map<String, dynamic>> _contractionLogs = [];

  // Form selections
  DateTime _selectedLmp = DateTime.now().subtract(const Duration(days: 30));

  // Kick Counter State
  bool _isCountingKicks = false;
  int _currentKickCount = 0;
  int? _kickSessionStart;
  Timer? _kickTimer;
  int _kickElapsedSeconds = 0;
  int _lastKickMs = 0;

  // Contraction State
  bool _isTimingContraction = false;
  int? _contractionStart;
  int _currentContractionDuration = 0;
  Timer? _contractionTimer;

  // Symptoms Selection
  final Map<String, bool> _selectedSymptoms = {
    'NAUSEA': false,
    'HEADACHE': false,
    'SWELLING': false,
    'HEARTBURN': false,
    'BACKACHE': false,
    'FATIGUE': false,
  };
  String _symptomSeverity = 'MILD';
  final Map<String, bool> _selectedSupplements = {
    'IRON': false,
    'FOLIC_ACID': false,
    'VITAMIN_D': false,
    'CALCIUM': false,
    'MULTIVITAMIN': false,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _checkVisibilityAndLoad();
    _restoreActiveSessions();
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _kickTimer?.cancel();
    _contractionTimer?.cancel();
    super.dispose();
  }

  Future<void> _restoreActiveSessions() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'app_settings',
        where: "key IN ('preg_kick_session_start', 'preg_kick_session_count', 'preg_contraction_start')",
      );
      final map = {for (final r in rows) r['key'] as String: r['value'] as String};

      if (map.containsKey('preg_kick_session_start')) {
        final startMs = int.tryParse(map['preg_kick_session_start'] ?? '');
        final count = int.tryParse(map['preg_kick_session_count'] ?? '') ?? 0;
        if (startMs != null && startMs > 0) {
          _kickSessionStart = startMs;
          _currentKickCount = count;
          _isCountingKicks = true;
          _kickTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
            if (mounted && _kickSessionStart != null) {
              setState(() {
                _kickElapsedSeconds = (DateTime.now().millisecondsSinceEpoch - _kickSessionStart!) ~/ 1000;
              });
            }
          });
        }
      }

      if (map.containsKey('preg_contraction_start')) {
        final startMs = int.tryParse(map['preg_contraction_start'] ?? '');
        if (startMs != null && startMs > 0) {
          _contractionStart = startMs;
          _isTimingContraction = true;
          _contractionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
            if (mounted && _contractionStart != null) {
              setState(() {
                _currentContractionDuration = (DateTime.now().millisecondsSinceEpoch - _contractionStart!) ~/ 1000;
              });
            }
          });
        }
      }
    } catch (_) {}
  }

  String _formatJalaliDate(int epochMs) {
    if (epochMs <= 0) return 'تاریخ ثبت نشده';
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMs);
    final j = Jalali.fromDateTime(dt);
    final monthStr = j.month.toString().padLeft(2, '0');
    final dayStr = j.day.toString().padLeft(2, '0');
    return toPersianDigits('${j.year}/$monthStr/$dayStr');
  }

  Future<void> _checkVisibilityAndLoad() async {
    try {
      final db = await DatabaseHelper.instance.database;

      final settings = await db.query('app_settings');
      final settingsMap = {for (final s in settings) s['key']! as String: s['value']! as String};

      final pregnancyEnabled = ModuleGate.instance.isEnabledFrom(settingsMap, 'module_pregnancy_enabled');
      final isFemale = CyclePrivacyGuard.isVisible(settingsMap);
      final shouldShow = isFemale && pregnancyEnabled;

      if (!mounted) return;

      if (!shouldShow) {
        setState(() {
          _isVisible = false;
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _isVisible = true;
      });

      // Query active tracker via PregnancyRepository single source of truth (PREG-01, PREG-07)
      final tracker = await PregnancyRepository.instance.getActiveTracker();

      if (tracker != null) {
        final trackerId = tracker['id'] as String;

        final lmpStr = (tracker['lmpDate'] as String?) ?? '';
        final lmpDate = DateTime.tryParse(lmpStr) ?? DateTime.now();
        final diffDays = DateTime.now().difference(lmpDate).inDays;

        // Use standard ACOG GestationalAge calculation (PREG-03)
        final ga = GestationalAge.fromDays(diffDays);

        // Fetch checkups (with ASC ordering - PREG-28), kick counts, and contraction logs
        final checkupsRes = await db.query(
          'pregnancy_checkups',
          where: 'pregnancyId = ?',
          whereArgs: [trackerId],
          orderBy: 'scheduledDate ASC',
        );
        final kickRes = await db.query(
          'kick_counts',
          where: 'pregnancyId = ?',
          whereArgs: [trackerId],
          orderBy: 'loggedAt DESC',
        );
        final contractionRes = await db.query(
          'contraction_timer',
          where: 'pregnancyId = ?',
          whereArgs: [trackerId],
          orderBy: 'loggedAt DESC',
        );

        if (mounted) {
          setState(() {
            _activeTracker = {
              ...tracker,
              'currentWeek': ga.weeks,
              'currentTrimester': ga.trimester,
            };
            _checkups = checkupsRes;
            _kickLogs = kickRes;
            _contractionLogs = contractionRes;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _activeTracker = null;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading pregnancy tracker: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _startTracker() async {
    if (_isStarting) return;

    if (!_hasSelectedLmp) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً ابتدا تاریخ LMP را انتخاب کنید')),
      );
      return;
    }

    setState(() {
      _isStarting = true;
    });

    try {
      // Read cycle length from settings (PREG-16)
      final db = await DatabaseHelper.instance.database;
      final settings = await db.query('app_settings', where: "key IN ('cycle_avg_length', 'cycle_length_days')");
      int cycleLen = 28;
      if (settings.isNotEmpty) {
        cycleLen = int.tryParse(settings.first['value'] as String? ?? '28') ?? 28;
      }

      await PregnancyRepository.instance.startTracker(
        lmp: _selectedLmp,
        cycleLen: cycleLen,
      );

      await _checkVisibilityAndLoad();
    } catch (e) {
      debugPrint('Error starting pregnancy tracker: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isStarting = false;
        });
      }
    }
  }

  Future<void> _endTracker() async {
    if (_activeTracker == null) return;
    final trackerId = _activeTracker!['id'] as String;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: context.colors.card,
          title: const Text('پایان دوره بارداری', style: TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.bold)),
          content: const Text(
            'آیا مطمئن هستید که می‌خواهید پایش دوره بارداری فعلی را پایان دهید؟ اطلاعات این دوره حفظ می‌شود اما دیگر در این صفحه نمایش داده نمی‌شود.',
            style: TextStyle(fontFamily: 'Vazirmatn'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('انصراف', style: TextStyle(fontFamily: 'Vazirmatn')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: context.colors.medicalRed),
              child: const Text('تایید و پایان', style: TextStyle(fontFamily: 'Vazirmatn', color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      await PregnancyRepository.instance.endTracker(trackerId, 'USER_ENDED');
      await _checkVisibilityAndLoad();
    } catch (e) {
      debugPrint('Error ending pregnancy tracker: $e');
    }
  }

  Future<void> _toggleCheckup(String id, bool completed) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await db.update(
        'pregnancy_checkups',
        {
          'isCompleted': completed ? 1 : 0,
          'actualDate': completed ? nowMs : null,
          'updatedAt': nowMs,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await _checkVisibilityAndLoad();
    } catch (e) {
      debugPrint('Error toggling checkup: $e');
    }
  }

  // Kick Counter functions (PREG-09, PREG-10, PREG-11)
  Future<void> _startKickSession() async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _isCountingKicks = true;
      _currentKickCount = 0;
      _kickSessionStart = nowMs;
      _kickElapsedSeconds = 0;
    });

    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert('app_settings', {'key': 'preg_kick_session_start', 'value': nowMs.toString()}, conflictAlgorithm: ConflictAlgorithm.replace);
      await db.insert('app_settings', {'key': 'preg_kick_session_count', 'value': '0'}, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {}

    _kickTimer?.cancel();
    _kickTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _kickSessionStart != null) {
        setState(() {
          _kickElapsedSeconds = (DateTime.now().millisecondsSinceEpoch - _kickSessionStart!) ~/ 1000;
        });
      }
    });
  }

  void _recordKick() {
    if (!_isCountingKicks) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastKickMs < 400) return; // 400ms debounce (PREG-11)
    _lastKickMs = now;

    HapticFeedback.selectionClick();
    setState(() {
      _currentKickCount++;
    });

    DatabaseHelper.instance.database.then((db) {
      db.insert('app_settings', {'key': 'preg_kick_session_count', 'value': _currentKickCount.toString()}, conflictAlgorithm: ConflictAlgorithm.replace);
    }).catchError((_) {});
  }

  Future<void> _saveKickSession() async {
    _kickTimer?.cancel();
    if (_activeTracker == null || _kickSessionStart == null) {
      setState(() {
        _isCountingKicks = false;
      });
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final trackerId = _activeTracker!['id'] as String;
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);

    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert('kick_counts', {
        'id': 'kick_$now',
        'pregnancyId': trackerId,
        'startTime': _kickSessionStart,
        'endTime': now,
        'kickCount': _currentKickCount,
        'sessionDate': todayStr,
        'loggedAt': now,
        'createdAt': now,
      });

      await db.delete('app_settings', where: "key IN ('preg_kick_session_start', 'preg_kick_session_count')");

      await _checkVisibilityAndLoad();
    } catch (e) {
      debugPrint('Error saving kick session: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCountingKicks = false;
          _kickSessionStart = null;
        });
      }
    }
  }

  // Contraction Timer functions (PREG-13)
  void _toggleContractionTimer() {
    if (!_isTimingContraction) {
      final now = DateTime.now().millisecondsSinceEpoch;
      setState(() {
        _isTimingContraction = true;
        _contractionStart = now;
        _currentContractionDuration = 0;
      });

      DatabaseHelper.instance.database.then((db) {
        db.insert('app_settings', {'key': 'preg_contraction_start', 'value': now.toString()}, conflictAlgorithm: ConflictAlgorithm.replace);
      }).catchError((_) {});

      _contractionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted && _contractionStart != null) {
          setState(() {
            _currentContractionDuration = (DateTime.now().millisecondsSinceEpoch - _contractionStart!) ~/ 1000;
          });
        }
      });
    } else {
      _contractionTimer?.cancel();
      _saveContraction();
    }
  }

  Future<void> _saveContraction() async {
    if (_activeTracker == null || _contractionStart == null) {
      setState(() {
        _isTimingContraction = false;
      });
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final durationSecs = (now - _contractionStart!) ~/ 1000;

    // Ignore contractions less than 10 seconds (PREG-13)
    if (durationSecs < 10) {
      setState(() {
        _isTimingContraction = false;
        _contractionStart = null;
      });
      DatabaseHelper.instance.database.then((db) {
        db.delete('app_settings', where: "key = 'preg_contraction_start'");
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('انقباض زیر ۱۰ ثانیه ذخیره نشد')),
      );
      return;
    }

    var intervalSecs = 0;
    if (_contractionLogs.isNotEmpty) {
      final prevStart = (_contractionLogs.first['startTime'] as int?) ?? 0;
      if (prevStart > 0) {
        intervalSecs = (_contractionStart! - prevStart) ~/ 1000;
      }
    }

    try {
      final db = await DatabaseHelper.instance.database;
      final trackerId = _activeTracker!['id'] as String;

      await db.insert('contraction_timer', {
        'id': 'contract_$now',
        'pregnancyId': trackerId,
        'startTime': _contractionStart,
        'endTime': now,
        'durationSeconds': durationSecs,
        'intervalFromPrevious': intervalSecs,
        'loggedAt': now,
      });

      await db.delete('app_settings', where: "key = 'preg_contraction_start'");

      await _checkVisibilityAndLoad();
    } catch (e) {
      debugPrint('Error saving contraction: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isTimingContraction = false;
          _contractionStart = null;
        });
      }
    }
  }

  bool _check511LaborAlert() {
    if (_contractionLogs.length < 3) return false;

    final now = DateTime.now().millisecondsSinceEpoch;
    final oneHourAgo = now - 3600000;
    final recent = _contractionLogs.where((c) {
      final logged = (c['loggedAt'] as int?) ?? 0;
      return logged >= oneHourAgo;
    }).toList();

    if (recent.length < 3) return false;

    // Check duration span between oldest and newest in 1-hour window (PREG-13)
    final newestTime = (recent.first['loggedAt'] as int?) ?? 0;
    final oldestTime = (recent.last['loggedAt'] as int?) ?? 0;
    if (newestTime - oldestTime < 3600000) return false;

    // Require majority (>=80%) of contractions to satisfy 5-1-1 conditions
    int matchesCount = 0;
    for (var i = 0; i < recent.length; i++) {
      final duration = (recent[i]['durationSeconds'] as int?) ?? 0;
      final interval = (recent[i]['intervalFromPrevious'] as int?) ?? 0;

      final validDuration = duration >= 60;
      final validInterval = (i == recent.length - 1) || (interval > 0 && interval <= 300);

      if (validDuration && validInterval) {
        matchesCount++;
      }
    }

    return (matchesCount / recent.length) >= 0.8;
  }

  // Daily Symptoms and Supplements Logging (PREG-05)
  Future<void> _saveSymptomsAndSupplements() async {
    if (_activeTracker == null) return;
    final trackerId = _activeTracker!['id'] as String;
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);

    final activeSymptoms = <String>[];
    _selectedSymptoms.forEach((k, v) {
      if (v) activeSymptoms.add(k);
    });

    final activeSupps = <String>[];
    _selectedSupplements.forEach((k, v) {
      if (v) activeSupps.add(k);
    });

    // Check if both collections are empty (PREG-05)
    if (activeSymptoms.isEmpty && activeSupps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('موردی انتخاب نشده است')),
      );
      return;
    }

    try {
      final db = await DatabaseHelper.instance.database;

      await db.transaction((txn) async {
        // Log symptoms as clean independent rows
        for (final sym in activeSymptoms) {
          final symId = 'sym_${trackerId}_${todayStr}_$sym';
          await txn.insert(
            'pregnancy_symptoms',
            {
              'id': symId,
              'pregnancyId': trackerId,
              'date': todayStr,
              'symptom': sym,
              'severity': _symptomSeverity,
              'note': '',
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        // Log supplements as independent rows with SUPP_ code prefix (PREG-05)
        for (final supp in activeSupps) {
          final suppId = 'sym_${trackerId}_${todayStr}_SUPP_$supp';
          await txn.insert(
            'pregnancy_symptoms',
            {
              'id': suppId,
              'pregnancyId': trackerId,
              'date': todayStr,
              'symptom': 'SUPP_$supp',
              'severity': 'MILD',
              'note': '',
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });

      setState(() {
        _selectedSymptoms.updateAll((k, v) => false);
        _selectedSupplements.updateAll((k, v) => false);
        _symptomSeverity = 'MILD';
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('علائم و مکمل‌های روز با موفقیت ثبت شدند.', style: TextStyle(fontFamily: 'Vazirmatn'))),
      );

      await _checkVisibilityAndLoad();
    } catch (e) {
      debugPrint('Error saving symptoms: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) {
      return const SizedBox.shrink();
    }

    final colors = context.colors;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: colors.primary));
    }

    final is511Labor = _check511LaborAlert();

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'مراقبت بارداری',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary),
              ),
              if (_activeTracker != null)
                TextButton.icon(
                  onPressed: _endTracker,
                  icon: Icon(Icons.power_settings_new, color: colors.medicalRed, size: 16),
                  label: Text('پایان بارداری', style: TextStyle(color: colors.medicalRed, fontSize: 12, fontFamily: 'Vazirmatn')),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Main 5-1-1 Emergency Alert Banner across ALL tabs (PREG-13)
          if (is511Labor) ...[
            Semantics(
              liveRegion: true,
              child: Card(
                color: colors.medicalRed.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colors.medicalRed, width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning, color: colors.medicalRed, size: 28),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '⚠️ هشدار ۵-۱-۱: انقباضات شما منظم شده و هر ۵ دقیقه یا کمتر تکرار می‌شوند. فاز زایمان فعال است! لطفاً سریعاً با پزشک خود یا بیمارستان تماس بگیرید.',
                              style: TextStyle(
                                color: colors.medicalRed,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Vazirmatn',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'این برنامه یک ابزار پزشکی نیست و جایگزین نظر پزشک متخصص نمی‌شود.',
                        style: TextStyle(color: colors.textSecondary, fontSize: 10, fontFamily: 'Vazirmatn'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (_activeTracker == null)
            _buildSetupView()
          else ...[
            TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: colors.primary,
              labelColor: colors.textPrimary,
              unselectedLabelColor: colors.textSecondary,
              tabs: const [
                Tab(text: 'هفته‌شمار'),
                Tab(text: 'معاینات کشوری'),
                Tab(text: 'حرکات جنین'),
                Tab(text: 'انقباضات'),
                Tab(text: 'علائم روزانه'),
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: 380,
                maxHeight: 520 * MediaQuery.textScalerOf(context).scale(1.0),
              ),
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildWeekTrackerTab(),
                  _buildCheckupsTab(),
                  _buildKickCounterTab(),
                  _buildContractionTimerTab(),
                  _buildSymptomsTab(),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          // Medical Disclaimer (PREG-29)
          Text(
            'این برنامه یک ابزار پزشکی نیست و جایگزین نظر پزشک متخصص نمی‌شود. در هر وضعیت نگران‌کننده با پزشک یا ماما تماس بگیرید.',
            style: TextStyle(fontSize: 10, color: colors.textSecondary, fontFamily: 'Vazirmatn'),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSetupView() {
    final colors = context.colors;
    final jalaliLmp = Jalali.fromDateTime(_selectedLmp);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'پایش و مدیریت بارداری فعال نیست. برای شروع، لطفاً تاریخ اولین روز آخرین قاعدگی خود (LMP) را انتخاب کنید:',
              style: TextStyle(fontSize: 13, color: colors.textPrimary),
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await RitmoDatePicker.showJalali(
                  context: context,
                  initialDate: Jalali.fromDateTime(_selectedLmp),
                  firstDate: Jalali.fromDateTime(DateTime.now().subtract(const Duration(days: 310))), // PREG-15
                  lastDate: Jalali.fromDateTime(DateTime.now()),
                );
                if (picked != null) {
                  setState(() {
                    _selectedLmp = picked.toDateTime();
                    _hasSelectedLmp = true;
                  });
                }
              },
              icon: Icon(Icons.calendar_month, color: colors.primary),
              label: Text(
                _hasSelectedLmp
                    ? toPersianDigits('LMP: ${jalaliLmp.year}/${jalaliLmp.month.toString().padLeft(2, "0")}/${jalaliLmp.day.toString().padLeft(2, "0")}')
                    : 'انتخاب تاریخ LMP',
                style: TextStyle(color: colors.textPrimary, fontFamily: 'Vazirmatn'),
              ),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: (_isStarting || !_hasSelectedLmp) ? null : _startTracker,
              style: ElevatedButton.styleFrom(backgroundColor: colors.primary),
              child: _isStarting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('شروع پایش بارداری', style: TextStyle(color: Colors.white, fontFamily: 'Vazirmatn')),
            ),
          ],
        ),
      ),
    );
  }

  // Sub-tab 1: Week Tracker
  Widget _buildWeekTrackerTab() {
    final colors = context.colors;
    final week = (_activeTracker!['currentWeek'] as int?) ?? 1;
    final eddStr = (_activeTracker!['estimatedDueDate'] as String?) ?? (_activeTracker!['expectedDueDate'] as String?) ?? '';
    final eddDate = DateTime.tryParse(eddStr) ?? DateTime.now();
    final lmpStr = (_activeTracker!['lmpDate'] as String?) ?? '';
    final lmpDate = DateTime.tryParse(lmpStr) ?? DateTime.now();
    final diffDays = DateTime.now().difference(lmpDate).inDays;

    final ga = GestationalAge.fromDays(diffDays);
    final progress = (diffDays / 280.0).clamp(0.0, 1.0);
    final eddJalali = Jalali.fromDateTime(eddDate);
    final eddStrJalali = toPersianDigits('${eddJalali.year}/${eddJalali.month.toString().padLeft(2, "0")}/${eddJalali.day.toString().padLeft(2, "0")}');

    var trimesterText = 'سه ماهه اول';
    if (ga.trimester == 2) trimesterText = 'سه ماهه دوم';
    if (ga.trimester == 3) trimesterText = 'سه ماهه سوم';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  toPersianDigits('هفته $week بارداری (روز ${ga.days})'),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    trimesterText,
                    style: TextStyle(color: colors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            LinearProgressIndicator(
              value: progress,
              color: colors.primary,
              backgroundColor: colors.border,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('پیشرفت بارداری:', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                Text(toPersianDigits('${(progress * 100).toStringAsFixed(0)}٪'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.primary)),
              ],
            ),
            const Divider(height: 32),
            Row(
              children: [
                Icon(Icons.event, color: colors.primary),
                const SizedBox(width: 10),
                Text('تاریخ تخمینی زایمان (EDD):', style: TextStyle(fontSize: 13, color: colors.textSecondary)),
                const SizedBox(width: 8),
                Text(eddStrJalali, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, color: colors.textSecondary),
                const SizedBox(width: 10),
                Text('تاریخ آخرین قاعدگی (LMP):', style: TextStyle(fontSize: 13, color: colors.textSecondary)),
                const SizedBox(width: 8),
                Text(_formatJalaliDate(lmpDate.millisecondsSinceEpoch), style: TextStyle(fontSize: 14, color: colors.textPrimary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Sub-tab 2: Checkups (PREG-28, PREG-29)
  Widget _buildCheckupsTab() {
    final colors = context.colors;

    if (_checkups.isEmpty) {
      return Center(
        child: Text('هیچ مراقبتی تعریف نشده است.', style: TextStyle(color: colors.textSecondary)),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            'دستورالعمل کشوری مراقبت‌های دوران بارداری',
            style: TextStyle(fontSize: 11, color: colors.textSecondary, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _checkups.length,
            itemBuilder: (context, index) {
              final chk = _checkups[index];
              final completed = (chk['isCompleted'] as int?) == 1 || (chk['isDone'] as int?) == 1;
              final scheduledDateMs = (chk['scheduledDate'] as int?) ?? 0;
              final actualDateMs = (chk['actualDate'] as int?) ?? 0;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: CheckboxListTile(
                  title: Text(
                    (chk['title'] as String?) ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: completed ? FontWeight.normal : FontWeight.bold,
                      color: completed ? colors.textSecondary : colors.textPrimary,
                      decoration: completed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  subtitle: completed
                      ? Text('انجام شده در: ${_formatJalaliDate(actualDateMs)}', style: TextStyle(fontSize: 11, color: colors.textSecondary))
                      : Text('تاریخ تقریبی سررسید: ${_formatJalaliDate(scheduledDateMs)}', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                  value: completed,
                  activeColor: colors.success,
                  onChanged: (val) {
                    if (val != null) {
                      _toggleCheckup(chk['id'] as String, val);
                    }
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Sub-tab 3: Kick Counter (PREG-09, PREG-10, PREG-11)
  Widget _buildKickCounterTab() {
    final colors = context.colors;
    final mins = _kickElapsedSeconds ~/ 60;
    final secs = _kickElapsedSeconds % 60;

    return SingleChildScrollView(
      child: Column(
        children: [
          Card(
            color: _isCountingKicks ? colors.primary.withValues(alpha: 0.08) : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (!_isCountingKicks) ...[
                    Text('پایش حرکات جنین به مدت ۱ ساعت به ارزیابی سلامت جنین کمک می‌کند.', style: TextStyle(fontSize: 12, color: colors.textPrimary)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _startKickSession,
                      style: ElevatedButton.styleFrom(backgroundColor: colors.primary),
                      child: const Text('شروع شمارش حرکات جنین', style: TextStyle(color: Colors.white, fontFamily: 'Vazirmatn')),
                    ),
                  ] else ...[
                    Text(
                      toPersianDigits('${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}'),
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colors.primary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      toPersianDigits('حرکات شمرده شده: $_currentKickCount'),
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Semantics(
                          button: true,
                          label: 'ثبت حرکت جنین',
                          child: ElevatedButton.icon(
                            onPressed: _recordKick,
                            icon: const Icon(Icons.add, color: Colors.white),
                            label: const Text('ثبت حرکت / لگد', style: TextStyle(color: Colors.white, fontFamily: 'Vazirmatn')),
                            style: ElevatedButton.styleFrom(backgroundColor: colors.success),
                          ),
                        ),
                        OutlinedButton(
                          onPressed: _saveKickSession,
                          child: const Text('پایان و ذخیره', style: TextStyle(fontFamily: 'Vazirmatn')),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Text('سوابق شمارش حرکات جنین:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.textPrimary)),
          ),
          const SizedBox(height: 8),
          if (_kickLogs.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('سابقه‌ای ثبت نشده است.', style: TextStyle(color: colors.textSecondary)),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _kickLogs.length.clamp(0, 3),
              itemBuilder: (context, index) {
                final log = _kickLogs[index];
                final count = (log['kickCount'] as int?) ?? 0;
                final loggedAtMs = (log['loggedAt'] as int?) ?? 0;
                final startMs = (log['startTime'] as int?) ?? loggedAtMs;
                final endMs = (log['endTime'] as int?) ?? loggedAtMs;
                final date = _formatJalaliDate(loggedAtMs);
                final durationSecs = (endMs - startMs) ~/ 1000;
                final durationMins = durationSecs ~/ 60;

                // 4-State Kick Evaluation Table (PREG-11)
                Color statusColor = colors.success;
                IconData statusIcon = Icons.check_circle_outline;
                String statusLabel = 'وضعیت طبیعی است';

                if (count >= 10 && durationMins <= 120) {
                  statusColor = colors.success;
                  statusIcon = Icons.check_circle_outline;
                  statusLabel = 'وضعیت طبیعی است';
                } else if (count >= 10 && durationMins > 120) {
                  statusColor = colors.textSecondary;
                  statusIcon = Icons.info_outline;
                  statusLabel = 'شمارش کامل شد اما بیش از حد معمول طول کشید';
                } else if (count < 10 && durationMins >= 120) {
                  statusColor = colors.warning;
                  statusIcon = Icons.warning_amber_rounded;
                  statusLabel = 'حرکات کمتر از حد انتظار بود؛ با پزشک خود تماس بگیرید';
                } else {
                  statusColor = colors.textSecondary;
                  statusIcon = Icons.timelapse;
                  statusLabel = 'جلسه کوتاه بود؛ برای نتیجه معتبر ادامه دهید';
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    leading: Icon(statusIcon, color: statusColor),
                    title: Text(
                      toPersianDigits('$count حرکت در $durationMins دقیقه'),
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: colors.textPrimary),
                    ),
                    subtitle: Text('$statusLabel · تاریخ ثبت: $date', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // Sub-tab 4: Contraction Timer (PREG-13)
  Widget _buildContractionTimerTab() {
    final colors = context.colors;

    return SingleChildScrollView(
      child: Column(
        children: [
          Card(
            color: _isTimingContraction ? colors.medicalRed.withValues(alpha: 0.08) : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_isTimingContraction) ...[
                    Text(
                      toPersianDigits('مدت انقباض: $_currentContractionDuration ثانیه'),
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colors.medicalRed),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Semantics(
                    button: true,
                    label: _isTimingContraction ? 'پایان ثبت انقباض' : 'شروع ثبت انقباض',
                    child: ElevatedButton(
                      onPressed: _toggleContractionTimer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isTimingContraction ? colors.medicalRed : colors.primary,
                      ),
                      child: Text(
                        _isTimingContraction ? 'پایان انقباض' : 'شروع انقباض',
                        style: const TextStyle(color: Colors.white, fontFamily: 'Vazirmatn'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Text('آخرین انقباضات ثبت شده:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.textPrimary)),
          ),
          const SizedBox(height: 8),
          if (_contractionLogs.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('انقباضی ثبت نشده است.', style: TextStyle(color: colors.textSecondary)),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _contractionLogs.length.clamp(0, 3),
              itemBuilder: (context, index) {
                final log = _contractionLogs[index];
                final duration = (log['durationSeconds'] as int?) ?? 0;
                final interval = (log['intervalFromPrevious'] as int?) ?? 0;
                final loggedAtMs = (log['loggedAt'] as int?) ?? 0;
                final date = _formatJalaliDate(loggedAtMs);

                final intervalStr = interval > 0 ? 'فاصله از قبلی: ${interval ~/ 60} دقیقه' : 'اولین انقباض';

                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    leading: Icon(Icons.timer_outlined, color: colors.medicalRed),
                    title: Text(
                      toPersianDigits('مدت: $duration ثانیه · $intervalStr'),
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: colors.textPrimary),
                    ),
                    subtitle: Text('ثبت: $date', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // Sub-tab 5: Symptoms and Supplements Log (PREG-05)
  Widget _buildSymptomsTab() {
    final colors = context.colors;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('علائم امروز:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.textPrimary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildSymptomChip('NAUSEA', 'تهوع'),
              _buildSymptomChip('HEADACHE', 'سردرد'),
              _buildSymptomChip('SWELLING', 'تورم بدن'),
              _buildSymptomChip('HEARTBURN', 'سوزش معده'),
              _buildSymptomChip('BACKACHE', 'کمردرد'),
              _buildSymptomChip('FATIGUE', 'خستگی شدید'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('شدت علائم: ', style: TextStyle(fontSize: 13, color: colors.textPrimary)),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _symptomSeverity,
                dropdownColor: colors.card,
                items: const [
                  DropdownMenuItem(value: 'MILD', child: Text('خفیف', style: TextStyle(fontFamily: 'Vazirmatn'))),
                  DropdownMenuItem(value: 'MODERATE', child: Text('متوسط', style: TextStyle(fontFamily: 'Vazirmatn'))),
                  DropdownMenuItem(value: 'SEVERE', child: Text('شدید', style: TextStyle(fontFamily: 'Vazirmatn'))),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _symptomSeverity = val;
                    });
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('مکمل‌های مصرفی امروز:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.textPrimary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildSupplementChip('IRON', 'آهن'),
              _buildSupplementChip('FOLIC_ACID', 'اسید فولیک'),
              _buildSupplementChip('VITAMIN_D', 'ویتامین D'),
              _buildSupplementChip('CALCIUM', 'کلسیم'),
              _buildSupplementChip('MULTIVITAMIN', 'مولتی‌ویتامین'),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _saveSymptomsAndSupplements,
            style: ElevatedButton.styleFrom(backgroundColor: colors.primary),
            child: const Text('ثبت علائم و مکمل‌های امروز', style: TextStyle(color: Colors.white, fontFamily: 'Vazirmatn')),
          ),
        ],
      ),
    );
  }

  Widget _buildSymptomChip(String key, String label) {
    final colors = context.colors;
    final isSelected = _selectedSymptoms[key] ?? false;

    return FilterChip(
      label: Text(label, style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, color: isSelected ? Colors.white : colors.textPrimary)),
      selected: isSelected,
      selectedColor: colors.primary,
      backgroundColor: colors.card,
      onSelected: (val) {
        setState(() {
          _selectedSymptoms[key] = val;
        });
      },
    );
  }

  Widget _buildSupplementChip(String key, String label) {
    final colors = context.colors;
    final isSelected = _selectedSupplements[key] ?? false;

    return FilterChip(
      label: Text(label, style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12, color: isSelected ? Colors.white : colors.textPrimary)),
      selected: isSelected,
      selectedColor: colors.success,
      backgroundColor: colors.card,
      onSelected: (val) {
        setState(() {
          _selectedSupplements[key] = val;
        });
      },
    );
  }
}
