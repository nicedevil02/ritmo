import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/worship/models/worship_models.dart';
import 'package:ritmo/features/worship/presentation/widgets/fullscreen_tasbih_sheet.dart';
import 'package:ritmo/features/routines/presentation/widgets/confetti_widget.dart';

class QuranDhikrSection extends StatefulWidget {

  const QuranDhikrSection({
    super.key,
    required this.onChanged,
  });
  final VoidCallback onChanged;

  @override
  State<QuranDhikrSection> createState() => _QuranDhikrSectionState();
}

class _QuranDhikrSectionState extends State<QuranDhikrSection> {
  bool _isLoading = true;
  String _todayStr = '';

  // Quran practice
  WorshipPractice? _quranPractice;
  Map<String, int> _weeklyQuranCounts = {};
  bool _showQuranCelebration = false;
  Timer? _celebrationTimer;

  // Dhikrs list & selected Dhikr
  List<WorshipPractice> _dhikrs = [];
  String? _selectedDhikrId;

  // Hazrat Zahra Tasbih Active State (Local)
  // Step: 0 = Allahu Akbar (34), 1 = Al-Hamdulillah (33), 2 = Subhan Allah (33)
  int _zahraStep = 0;
  int _zahraCount = 0;

  final List<String> _zahraPhrases = ['الله اکبر', 'الحمدلله', 'سبحان الله'];
  final List<int> _zahraTargets = [34, 33, 33];

  @override
  void initState() {
    super.initState();
    _todayStr = DateTime.now().toIso8601String().substring(0, 10);
    _loadData();
  }

  @override
  void dispose() {
    _celebrationTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(QuranDhikrSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final now = DateTime.now();

      // 1. Check & Initialize Defaults if missing
      await db.transaction((txn) async {
        // Quran
        final quranCheck = await txn.query('worship_practices', where: "id = 'wp_quran'", limit: 1);
        if (quranCheck.isEmpty) {
          await txn.insert('worship_practices', {
            'id': 'wp_quran',
            'practiceType': 'QURAN',
            'subType': 'PAGE',
            'title': 'قرائت قرآن کریم',
            'dailyTarget': 4,
            'dailyDone': 0,
            'isActive': 1,
            'dailyDoneDate': _todayStr,
            'createdAt': nowMs,
            'updatedAt': nowMs,
          });
        }

        // Hazrat Zahra
        final zahraCheck = await txn.query('worship_practices', where: "id = 'wp_dhikr_zahra'", limit: 1);
        if (zahraCheck.isEmpty) {
          await txn.insert('worship_practices', {
            'id': 'wp_dhikr_zahra',
            'practiceType': 'DHIKR',
            'subType': 'TASBIH',
            'title': 'تسبیحات حضرت زهرا',
            'dailyTarget': 1,
            'dailyDone': 0,
            'isActive': 1,
            'dailyDoneDate': _todayStr,
            'createdAt': nowMs,
            'updatedAt': nowMs,
          });
        }

        // Salawat
        final salawatCheck = await txn.query('worship_practices', where: "id = 'wp_dhikr_salawat'", limit: 1);
        if (salawatCheck.isEmpty) {
          await txn.insert('worship_practices', {
            'id': 'wp_dhikr_salawat',
            'practiceType': 'DHIKR',
            'subType': 'SALAWAT',
            'title': 'صلوات',
            'dailyTarget': 100,
            'dailyDone': 0,
            'isActive': 1,
            'dailyDoneDate': _todayStr,
            'createdAt': nowMs,
            'updatedAt': nowMs,
          });
        }

        // Esteghfar
        final esteghfarCheck = await txn.query('worship_practices', where: "id = 'wp_dhikr_esteghfar'", limit: 1);
        if (esteghfarCheck.isEmpty) {
          await txn.insert('worship_practices', {
            'id': 'wp_dhikr_esteghfar',
            'practiceType': 'DHIKR',
            'subType': 'ESTEGHFAR',
            'title': 'استغفار',
            'dailyTarget': 100,
            'dailyDone': 0,
            'isActive': 1,
            'dailyDoneDate': _todayStr,
            'createdAt': nowMs,
            'updatedAt': nowMs,
          });
        }
      });

      // 2. Fetch Practices (Load QURAN regardless of isActive, but DHIKR only if isActive = 1)
      final allWorship = await db.query(
        'worship_practices',
        where: "practiceType = 'QURAN' OR (practiceType = 'DHIKR' AND isActive = 1)",
        orderBy: 'createdAt ASC',
      );

      final list = allWorship.map(WorshipPractice.fromMap).toList();

      // Extract Quran and Dhikrs list
      WorshipPractice? quranP;
      final dhikrsList = <WorshipPractice>[];

      for (final p in list) {
        if (p.practiceType == 'QURAN') {
          quranP = p;
        } else if (p.practiceType == 'DHIKR') {
          dhikrsList.add(p);
        }
      }

      // 3. Load Real Weekly Quran History from worship_completions
      int daysSinceSaturday;
      switch (now.weekday) {
        case DateTime.saturday:
          daysSinceSaturday = 0;
          break;
        case DateTime.sunday:
          daysSinceSaturday = 1;
          break;
        case DateTime.monday:
          daysSinceSaturday = 2;
          break;
        case DateTime.tuesday:
          daysSinceSaturday = 3;
          break;
        case DateTime.wednesday:
          daysSinceSaturday = 4;
          break;
        case DateTime.thursday:
          daysSinceSaturday = 5;
          break;
        case DateTime.friday:
          daysSinceSaturday = 6;
          break;
        default:
          daysSinceSaturday = 0;
      }

      final saturday = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysSinceSaturday));
      final weekDateStrings = List.generate(7, (i) {
        final d = saturday.add(Duration(days: i));
        return d.toIso8601String().substring(0, 10);
      });

      final inClause = weekDateStrings.map((s) => "'$s'").join(',');
      final rows = await db.query(
        'worship_completions',
        where: "practiceId = 'wp_quran' AND dateStr IN ($inClause)",
      );

      final Map<String, int> weekCounts = {};
      for (final r in rows) {
        final dateStr = r['dateStr'] as String;
        final count = (r['countDone'] as num?)?.toInt() ?? 0;
        weekCounts[dateStr] = count;
      }

      if (mounted) {
        setState(() {
          _quranPractice = quranP;
          _weeklyQuranCounts = weekCounts;
          _dhikrs = dhikrsList;
          if (_selectedDhikrId == null || !dhikrsList.any((d) => d.id == _selectedDhikrId)) {
            if (dhikrsList.any((d) => d.id == 'wp_dhikr_zahra')) {
              _selectedDhikrId = 'wp_dhikr_zahra';
            } else if (dhikrsList.isNotEmpty) {
              _selectedDhikrId = dhikrsList.first.id;
            }
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading Quran/Dhikr data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- QURAN ACTIONS ---
  Future<void> _updateQuranPages(int delta) async {
    if (_quranPractice == null) return;
    unawaited(HapticFeedback.lightImpact());

    final currentDone = _quranPractice!.dailyDone;
    final target = _quranPractice!.dailyTarget;
    final newDone = (currentDone + delta).clamp(0, 999);
    final justCompleted = currentDone < target && newDone >= target && target > 0;

    try {
      final db = await DatabaseHelper.instance.database;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);

      final updated = _quranPractice!.copyWith(
        dailyDone: newDone,
        dailyDoneDate: todayStr,
        updatedAt: nowMs,
      );

      await db.update(
        'worship_practices',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [updated.id],
      );

      // Record in real history table
      await db.insert(
        'worship_completions',
        {
          'id': 'comp_quran_$todayStr',
          'practiceId': 'wp_quran',
          'dateStr': todayStr,
          'practiceType': 'QURAN',
          'resultType': newDone >= updated.dailyTarget ? 'DONE' : 'PARTIAL',
          'countDone': newDone,
          'countTarget': updated.dailyTarget,
          'loggedAt': nowMs,
          'createdAt': nowMs,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (justCompleted) {
        unawaited(HapticFeedback.heavyImpact());
        Future.delayed(const Duration(milliseconds: 160), () {
          unawaited(HapticFeedback.mediumImpact());
        });
        _celebrationTimer?.cancel();
        _showQuranCelebration = true;
        _celebrationTimer = Timer(const Duration(milliseconds: 2800), () {
          if (mounted) {
            setState(() {
              _showQuranCelebration = false;
            });
          }
        });

        if (mounted) {
          final colors = context.colors;
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: colors.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              content: const Row(
                children: [
                  Icon(CupertinoIcons.checkmark_seal_fill, color: Colors.amber, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'قبول حق! هدف تلاوت قرآن امروز با موفقیت تکمیل شد 🌟',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }

      setState(() {
        _quranPractice = updated;
        _weeklyQuranCounts[todayStr] = newDone;
      });
      widget.onChanged();
    } catch (e) {
      debugPrint('Error updating Quran pages: $e');
    }
  }


  void _showQuranSettingsSheet() {
    if (_quranPractice == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _QuranSettingsSheet(
          practice: _quranPractice!,
          onSaved: () {
            _loadData();
            widget.onChanged();
          },
        );
      },
    );
  }

  // --- HAZRAT ZAHRA TASBIH ACTIONS ---
  Future<void> _tapZahraCounter() async {
    unawaited(HapticFeedback.lightImpact());
    setState(() {
      _zahraCount++;
    });

    final target = _zahraTargets[_zahraStep];
    if (_zahraCount >= target) {
      unawaited(HapticFeedback.mediumImpact());
      if (_zahraStep < 2) {
        // Next Phrase
        setState(() {
          _zahraStep++;
          _zahraCount = 0;
        });
      } else {
        // Finished a full round!
        _zahraStep = 0;
        _zahraCount = 0;

        final activePractice = _dhikrs.firstWhere((p) => p.id == 'wp_dhikr_zahra');
        final db = await DatabaseHelper.instance.database;
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final todayStr = DateTime.now().toIso8601String().substring(0, 10);
        final newDone = activePractice.dailyDone + 1;
        final updated = activePractice.copyWith(
          dailyDone: newDone,
          dailyDoneDate: todayStr,
          updatedAt: nowMs,
        );

        await db.update(
          'worship_practices',
          updated.toMap(),
          where: 'id = ?',
          whereArgs: [updated.id],
        );

        // Record in worship_completions
        await db.insert(
          'worship_completions',
          {
            'id': 'comp_${updated.id}_$todayStr',
            'practiceId': updated.id,
            'dateStr': todayStr,
            'practiceType': 'DHIKR',
            'resultType': 'DONE',
            'countDone': newDone,
            'countTarget': updated.dailyTarget,
            'loggedAt': nowMs,
            'createdAt': nowMs,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        await _loadData();
        widget.onChanged();

        if (mounted) {
          final colors = context.colors;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('تسبیحات حضرت زهرا (س) به پایان رسید. قبول باشد ✨', style: TextStyle()),
              backgroundColor: colors.primary,
            ),
          );
        }
      }
    }
  }

  void _resetZahraCounter() {
    unawaited(HapticFeedback.mediumImpact());
    setState(() {
      _zahraStep = 0;
      _zahraCount = 0;
    });
  }

  Future<void> _openFullscreenTasbih() async {
    if (_dhikrs.isEmpty) return;

    final activePractice = _dhikrs.firstWhere(
      (p) => p.id == _selectedDhikrId,
      orElse: () => _dhikrs.first,
    );
    final isZahra = activePractice.id == 'wp_dhikr_zahra';

    final res = await FullscreenTasbihSheet.present(
      context,
      practices: _dhikrs,
      initialPracticeId: activePractice.id,
      initialStep: _zahraStep,
      initialCount: isZahra ? _zahraCount : activePractice.dailyDone,
    );

    if (res != null) {
      final pid = res['practiceId'] as String? ?? activePractice.id;
      final step = res['step'] as int? ?? 0;
      final count = res['count'] as int? ?? 0;

      setState(() {
        _selectedDhikrId = pid;
        if (pid == 'wp_dhikr_zahra') {
          _zahraStep = step;
          _zahraCount = count;
        }
      });
    }

    await _loadData();
    widget.onChanged();
  }

  // --- OTHER DHIKRS ACTIONS ---
  Future<void> _incrementDhikr(WorshipPractice practice, int amount) async {
    unawaited(HapticFeedback.lightImpact());
    final newDone = (practice.dailyDone + amount).clamp(0, 99999);

    try {
      final db = await DatabaseHelper.instance.database;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);

      final updated = practice.copyWith(
        dailyDone: newDone,
        dailyDoneDate: todayStr,
        updatedAt: nowMs,
      );

      await db.update(
        'worship_practices',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [practice.id],
      );

      // Record in worship_completions
      await db.insert(
        'worship_completions',
        {
          'id': 'comp_${updated.id}_$todayStr',
          'practiceId': updated.id,
          'dateStr': todayStr,
          'practiceType': 'DHIKR',
          'resultType': newDone >= updated.dailyTarget ? 'DONE' : 'PARTIAL',
          'countDone': newDone,
          'countTarget': updated.dailyTarget,
          'loggedAt': nowMs,
          'createdAt': nowMs,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await _loadData();
      widget.onChanged();
    } catch (e) {
      debugPrint('Error incrementing dhikr: $e');
    }
  }

  Future<void> _resetDhikr(WorshipPractice practice) async {
    unawaited(HapticFeedback.mediumImpact());
    try {
      final db = await DatabaseHelper.instance.database;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);

      final updated = practice.copyWith(
        dailyDone: 0,
        dailyDoneDate: todayStr,
        updatedAt: nowMs,
      );

      await db.update(
        'worship_practices',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [practice.id],
      );

      await db.delete(
        'worship_completions',
        where: 'practiceId = ? AND dateStr = ?',
        whereArgs: [practice.id, todayStr],
      );

      await _loadData();
      widget.onChanged();
    } catch (e) {
      debugPrint('Error resetting dhikr: $e');
    }
  }


  Future<void> _manuallySetDhikrCount(WorshipPractice practice) async {
    final colors = context.colors;
    final controller = TextEditingController(text: practice.dailyDone.toString());
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: colors.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'ثبت دستی تعداد ${practice.title}',
              style: TextStyle(color: colors.textPrimary, fontSize: 15.5, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'تعداد انجام شده امروز را وارد کنید:',
                  style: TextStyle(color: colors.textSecondary, fontSize: 13.5),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: colors.textPrimary),
                  decoration: InputDecoration(
                    fillColor: colors.inputBackground,
                    filled: true,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.glassBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.accent),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('انصراف', style: TextStyle(color: colors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text('ذخیره', style: TextStyle(color: colors.onPrimary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );

    if (result ?? false) {
      final value = int.tryParse(controller.text) ?? 0;
      unawaited(HapticFeedback.mediumImpact());
      try {
        final db = await DatabaseHelper.instance.database;
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final todayStr = DateTime.now().toIso8601String().substring(0, 10);

        await db.update(
          'worship_practices',
          {
            'dailyDone': value,
            'dailyDoneDate': todayStr,
            'updatedAt': nowMs,
          },
          where: 'id = ?',
          whereArgs: [practice.id],
        );

        if (value > 0) {
          await db.insert(
            'worship_completions',
            {
              'id': 'comp_${practice.id}_$todayStr',
              'practiceId': practice.id,
              'dateStr': todayStr,
              'practiceType': 'DHIKR',
              'resultType': value >= practice.dailyTarget ? 'DONE' : 'PARTIAL',
              'countDone': value,
              'countTarget': practice.dailyTarget,
              'loggedAt': nowMs,
              'createdAt': nowMs,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        } else {
          await db.delete(
            'worship_completions',
            where: 'practiceId = ? AND dateStr = ?',
            whereArgs: [practice.id, todayStr],
          );
        }

        if (practice.id == 'wp_dhikr_zahra') {
          setState(() {
            _zahraStep = 0;
            _zahraCount = 0;
          });
        }

        await _loadData();
        widget.onChanged();
      } catch (e) {
        debugPrint('Error manually setting dhikr count: $e');
      }
    }
  }

  void _showAddDhikrSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _AddDhikrSheet(
          onSaved: () {
            _loadData();
            widget.onChanged();
          },
        );
      },
    );
  }

  void _showDhikrSettingsSheet(WorshipPractice practice) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _DhikrSettingsSheet(
          practice: practice,
          onSaved: () {
            _loadData();
            widget.onChanged();
          },
          onDeleted: () {
            setState(() {
              _selectedDhikrId = 'wp_dhikr_zahra';
              _zahraStep = 0;
              _zahraCount = 0;
            });
            _loadData();
            widget.onChanged();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (_isLoading) {
      return SizedBox(
        height: 150,
        child: Center(child: CircularProgressIndicator(color: colors.textPrimary)),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. QURAN CARD
          if (_quranPractice != null) _buildQuranCard(colors),
          const SizedBox(height: 16),

          // 2. MERGED DHIKRS & TASBIHAT CARD
          _buildDhikrCard(colors),
        ],
      ),
    );
  }

  Widget _buildQuranCard(RitmoColors colors) {
    final done = _quranPractice!.dailyDone;
    final target = _quranPractice!.dailyTarget;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isGoalMet = target > 0 && done >= target;

    // Persian days: شنبه (ش), یکشنبه (ی), دوشنبه (د), سه‌شنبه (س), چهارشنبه (چ), پنج‌شنبه (پ), جمعه (ج)
    final days = <String>['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];

    int todayIndex;
    switch (DateTime.now().weekday) {
      case DateTime.saturday:
        todayIndex = 0;
        break;
      case DateTime.sunday:
        todayIndex = 1;
        break;
      case DateTime.monday:
        todayIndex = 2;
        break;
      case DateTime.tuesday:
        todayIndex = 3;
        break;
      case DateTime.wednesday:
        todayIndex = 4;
        break;
      case DateTime.thursday:
        todayIndex = 5;
        break;
      case DateTime.friday:
        todayIndex = 6;
        break;
      default:
        todayIndex = 0;
    }

    // Real weekly values queried from SQLite database (worship_completions)
    final saturday = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).subtract(Duration(days: todayIndex));
    final weeklyValues = List.generate(7, (idx) {
      if (idx == todayIndex) {
        return done;
      }
      final date = saturday.add(Duration(days: idx));
      final dateStr = date.toIso8601String().substring(0, 10);
      return _weeklyQuranCounts[dateStr] ?? 0;
    });

    final maxCount = weeklyValues.fold<int>(1, (prev, elem) => elem > prev ? elem : prev);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: isDark ? colors.surface : colors.surface,
        border: Border.all(
          color: isGoalMet
              ? colors.success.withValues(alpha: isDark ? 0.5 : 0.6)
              : (isDark ? colors.border : colors.border),
          width: isGoalMet ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isGoalMet
                ? colors.success.withValues(alpha: isDark ? 0.22 : 0.15)
                : (isDark
                    ? Colors.black.withValues(alpha: 0.28)
                    : colors.shadow.withValues(alpha: 0.08)),
            blurRadius: isGoalMet ? 38 : 35,
            spreadRadius: isGoalMet ? 1 : 0,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            // Ambient celebratory background halo when goal is met
            if (isGoalMet)
              Positioned(
                right: -25,
                top: 40,
                child: IgnorePointer(
                  child: Container(
                    width: 190,
                    height: 190,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          colors.success.withValues(alpha: isDark ? 0.12 : 0.08),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. TOP HEADER: Title + Subtitle + Settings Target Pill
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Right: Book Icon + Quran Title
                      Row(
                        children: [
                          GestureDetector(
                            onTap: _showQuranSettingsSheet,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isGoalMet
                                      ? [colors.success, colors.primary]
                                      : [colors.primary, colors.primaryPressed],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: (isGoalMet ? colors.success : colors.primary)
                                        .withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  isGoalMet
                                      ? CupertinoIcons.checkmark_seal_fill
                                      : CupertinoIcons.book_fill,
                                  color: colors.accent,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'قرآن کریم',
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'تلاوت و انس روزانه با کلام الله',
                                style: TextStyle(
                                  color: colors.textSecondary.withValues(alpha: 0.75),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Left: Settings & Target Badge Pill (linked to settings)
                      InkWell(
                        onTap: () {
                          unawaited(HapticFeedback.selectionClick());
                          _showQuranSettingsSheet();
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                          decoration: BoxDecoration(
                            color: isGoalMet
                                ? colors.success.withValues(alpha: isDark ? 0.18 : 0.12)
                                : colors.surfaceSunken,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isGoalMet
                                  ? colors.success.withValues(alpha: 0.45)
                                  : colors.border,
                              width: isGoalMet ? 1.2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isGoalMet
                                    ? CupertinoIcons.checkmark_seal_fill
                                    : CupertinoIcons.slider_horizontal_3,
                                size: isGoalMet ? 14 : 13,
                                color: isGoalMet
                                    ? colors.success
                                    : (isDark ? colors.primary : colors.primary),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isGoalMet
                                    ? 'هدف محقق شد 🎉'
                                    : 'هدف: ${toPersianDigits('$target')} صفحه',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isGoalMet ? FontWeight.w900 : FontWeight.bold,
                                  color: isGoalMet
                                      ? colors.success
                                      : (isDark ? colors.primary : colors.primary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // 2. MIDDLE HERO SECTION: 3D Art (Right) + Big Count (Left)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Right Side: Artwork of Holy Quran (Transparent PNG with full fidelity, larger display + halo)
                      GestureDetector(
                        onTap: _showQuranSettingsSheet,
                        child: SizedBox(
                          width: 195,
                          height: 180,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Divine aura behind Quran when completed
                              if (isGoalMet)
                                Container(
                                  width: 160,
                                  height: 160,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        colors.success.withValues(alpha: isDark ? 0.35 : 0.25),
                                        Colors.amber.withValues(alpha: isDark ? 0.20 : 0.12),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),

                              Image.asset(
                                'assets/images/quran_icon.png',
                                width: 195,
                                height: 180,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  width: 160,
                                  height: 160,
                                  decoration: BoxDecoration(
                                    color: (isGoalMet ? colors.success : colors.primary)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      CupertinoIcons.book_fill,
                                      color: isGoalMet ? colors.success : colors.primary,
                                      size: 64,
                                    ),
                                  ),
                                ),
                              ),

                              if (isGoalMet)
                                Positioned(
                                  top: 6,
                                  left: 6,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: colors.success,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: colors.success.withValues(alpha: 0.45),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      CupertinoIcons.check_mark,
                                      size: 13,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Left Side: Big Number + Title + Today Tag + +/- Controls
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 250),
                                  style: TextStyle(
                                    fontSize: 52,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'Dana',
                                    color: isGoalMet
                                        ? colors.success
                                        : (isDark ? colors.primary : colors.primary),
                                    height: 1.0,
                                  ),
                                  child: Text(
                                    toPersianDigits('$done'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  children: [
                                    InkWell(
                                      onTap: () => _updateQuranPages(1),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                          color: isGoalMet
                                              ? colors.success.withValues(alpha: isDark ? 0.2 : 0.15)
                                              : (isDark
                                                  ? colors.surfaceSunken
                                                  : colors.primary.withValues(alpha: 0.12)),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          CupertinoIcons.plus,
                                          size: 14,
                                          color: isGoalMet
                                              ? colors.success
                                              : (isDark ? colors.primary : colors.primary),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    InkWell(
                                      onTap: () => _updateQuranPages(-1),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? colors.surfaceSunken
                                              : colors.border.withValues(alpha: 0.3),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          CupertinoIcons.minus,
                                          size: 14,
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isGoalMet ? 'صفحه خوانده شده (تکمیل)' : 'صفحه خوانده شده',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: isGoalMet ? colors.success : colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: colors.success,
                                    boxShadow: isGoalMet
                                        ? [
                                            BoxShadow(
                                              color: colors.success.withValues(alpha: 0.6),
                                              blurRadius: 6,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  isGoalMet ? 'امروز ✓' : 'امروز',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: isGoalMet
                                        ? colors.success
                                        : colors.textSecondary.withValues(alpha: 0.75),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // 3. WEEKLY BAR CHART (Real historical data from SQLite)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top Numbers & Bars
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(7, (idx) {
                          final isToday = idx == todayIndex;
                          final countVal = weeklyValues[idx];
                          final ratio = (countVal / maxCount).clamp(0.12, 1.0);
                          final barHeight = 38.0 * ratio;
                          final isBarCompleted = countVal >= target && target > 0;

                          return Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  toPersianDigits('$countVal'),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                                    color: isToday
                                        ? (isBarCompleted
                                            ? colors.success
                                            : (isDark ? colors.primary : colors.primary))
                                        : (countVal > 0 ? colors.textSecondary : colors.textTertiary),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  width: 12,
                                  height: countVal > 0 ? barHeight : 6,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(7),
                                    gradient: isToday
                                        ? LinearGradient(
                                            colors: isBarCompleted
                                                ? [colors.success, Colors.amber]
                                                : [colors.primary, colors.success],
                                            begin: Alignment.bottomCenter,
                                            end: Alignment.topCenter,
                                          )
                                        : null,
                                    color: isToday
                                        ? null
                                        : (countVal > 0
                                            ? (isDark ? colors.primaryContainer : colors.primaryContainer)
                                            : (isDark ? colors.surfaceSunken : colors.surfaceSunken)),
                                    boxShadow: isToday
                                        ? [
                                            BoxShadow(
                                              color: (isBarCompleted ? colors.success : colors.success)
                                                  .withValues(alpha: 0.55),
                                              blurRadius: 10,
                                              spreadRadius: 1,
                                              offset: const Offset(0, 0),
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 8),

                      // Divider Line
                      Container(
                        height: 1,
                        color: colors.border.withValues(alpha: isDark ? 0.3 : 0.4),
                      ),
                      const SizedBox(height: 6),

                      // Day of Week Labels (ش, ی, د, ...)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(7, (idx) {
                          final isToday = idx == todayIndex;
                          return Expanded(
                            child: Center(
                              child: Text(
                                days[idx],
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                                  color: isToday
                                      ? (isGoalMet
                                          ? colors.success
                                          : (isDark ? colors.primary : colors.primary))
                                      : colors.textSecondary.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Confetti Particle Explosion overlay upon goal completion
            if (_showQuranCelebration)
              const Positioned.fill(
                child: IgnorePointer(
                  child: ConfettiWidget(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDhikrCard(RitmoColors colors) {
    if (_dhikrs.isEmpty) return const SizedBox();

    final activePractice = _dhikrs.firstWhere(
      (p) => p.id == _selectedDhikrId,
      orElse: () => _dhikrs.first,
    );

    final done = activePractice.dailyDone;
    final target = activePractice.dailyTarget;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isZahra = activePractice.id == 'wp_dhikr_zahra';

    final currentCount = isZahra ? _zahraCount : done;
    final currentTarget = isZahra ? _zahraTargets[_zahraStep] : target;

    final progress = currentTarget <= 0
        ? 0.0
        : (currentCount / currentTarget).clamp(0.0, 1.0);

    final phrase =
        isZahra ? _zahraPhrases[_zahraStep] : activePractice.title;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: isDark
            ? colors.surface
            : colors.surface,
        border: Border.all(
          color: isDark
              ? colors.border
              : colors.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.28)
                : colors.shadow.withValues(alpha: 0.08),
            blurRadius: 35,
            spreadRadius: 0,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            // ============================================================
            // BACKGROUND DECORATION
            // ============================================================

            Positioned(
              left: -55,
              bottom: -45,
              child: IgnorePointer(
                child: Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        colors.primary
                            .withValues(alpha: isDark ? 0.06 : 0.055),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            Positioned(
              right: -55,
              top: 80,
              child: IgnorePointer(
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        colors.accent
                            .withValues(alpha: isDark ? 0.07 : 0.055),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // subtle decorative line
            Positioned(
              top: 112,
              left: 26,
              right: 26,
              child: IgnorePointer(
                child: Container(
                  height: 1,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.035)
                      : colors.border.withValues(alpha: 0.42),
                ),
              ),
            ),

            // ============================================================
            // CONTENT
            // ============================================================

            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                children: [
                  // --------------------------------------------------------
                  // HEADER
                  // --------------------------------------------------------

                  Row(
                    children: [
                      // right side: icon + dropdown title selector
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: isDark
                                      ? [
                                          colors.primary,
                                          colors.primaryPressed,
                                        ]
                                      : [
                                          colors.surface,
                                          colors.surfaceSunken,
                                        ],
                                ),
                                border: Border.all(
                                  color: isDark
                                      ? colors.border
                                      : colors.border,
                                ),
                              ),
                              child: Icon(
                                CupertinoIcons.sparkles,
                                size: 20,
                                color: isDark
                                    ? colors.accent
                                    : colors.accent,
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: activePractice.id,
                                      dropdownColor: colors.surfaceElevated,
                                      borderRadius: BorderRadius.circular(20),
                                      icon: Padding(
                                        padding: const EdgeInsets.only(right: 6),
                                        child: Icon(
                                          CupertinoIcons.chevron_down,
                                          color: isDark ? colors.accent : colors.accent,
                                          size: 15,
                                        ),
                                      ),
                                      isDense: true,
                                      style: TextStyle(
                                        fontSize: 16.5,
                                        fontWeight: FontWeight.w800,
                                        color: colors.textPrimary,
                                      ),
                                      items: _dhikrs.map((d) {
                                        return DropdownMenuItem<String>(
                                          value: d.id,
                                          child: Text(
                                            d.id == 'wp_dhikr_zahra' ? 'تسبیحات حضرت زهرا' : d.title,
                                            style: TextStyle(
                                              fontSize: 15.5,
                                              fontWeight: FontWeight.w800,
                                              color: colors.textPrimary,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          unawaited(HapticFeedback.selectionClick());
                                          setState(() {
                                            _selectedDhikrId = val;
                                            if (val == 'wp_dhikr_zahra') {
                                              _zahraStep = 0;
                                              _zahraCount = 0;
                                            }
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isZahra
                                        ? 'ذکر کوتاه و آرام برای امروز'
                                        : 'ذکر روزانه',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: colors.textSecondary
                                          .withValues(alpha: 0.62),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 10),

                      // Settings button for active dhikr
                      InkWell(
                        onTap: () => _showDhikrSettingsSheet(activePractice),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colors.surfaceSunken,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colors.primary.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Icon(
                            CupertinoIcons.slider_horizontal_3,
                            size: 15,
                            color: colors.primary,
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Add button
                      InkWell(
                        onTap: _showAddDhikrSheet,
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surfaceSunken,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: colors.primary.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.add,
                                size: 14,
                                color: colors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'افزودن',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: colors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // --------------------------------------------------------
                  // TASBIH INTERACTION AREA (With generous spacing)
                  // --------------------------------------------------------

                  ScaleOnTap(
                    onTap: isZahra
                        ? _tapZahraCounter
                        : () => _incrementDhikr(activePractice, 1),
                    child: Container(
                      height: 318,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        color: colors.surface,
                        border: Border.all(
                          color: colors.border,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // soft inner glow
                          Positioned.fill(
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(30),
                                  gradient: RadialGradient(
                                    center: Alignment.center,
                                    radius: 0.75,
                                    colors: [
                                      colors.primary.withValues(
                                        alpha: isDark ? 0.06 : 0.035,
                                      ),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Circular progress
                          Positioned(
                            top: 14,
                            child: SizedBox(
                              width: 200,
                              height: 200,
                              child: TweenAnimationBuilder<double>(
                                tween: Tween<double>(
                                  begin: 0,
                                  end: progress,
                                ),
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeOutCubic,
                                builder: (context, animatedValue, _) {
                                  return CustomPaint(
                                    painter: _TasbihProgressPainter(
                                      progress: animatedValue,
                                      isDark: isDark,
                                      colors: colors,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                          // center content (Precisely centered inside the circle)
                          Positioned(
                            top: 14,
                            child: SizedBox(
                              width: 200,
                              height: 200,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    phrase,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: isDark
                                          ? colors.accent
                                          : colors.primaryPressed,
                                      height: 1.15,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TweenAnimationBuilder<double>(
                                    tween: Tween<double>(
                                      begin: 0,
                                      end: currentCount.toDouble(),
                                    ),
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, value, _) {
                                      return Text(
                                        toPersianDigits(
                                          value.round().toString(),
                                        ),
                                        style: TextStyle(
                                          fontSize: 52,
                                          height: 0.95,
                                          fontWeight: FontWeight.w300,
                                          color: colors.textPrimary,
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'از ${toPersianDigits(currentTarget.toString())}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: colors.textSecondary
                                          .withValues(alpha: 0.55),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // progress percentage
                          Positioned(
                            top: 22,
                            left: 24,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : Colors.white.withValues(alpha: 0.62),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : colors.border,
                                ),
                              ),
                              child: Text(
                                '${toPersianDigits((progress * 100).round().toString())}٪',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? colors.primary
                                      : colors.primaryPressed,
                                ),
                              ),
                            ),
                          ),

                          // Main CTA
                          Positioned(
                            bottom: 16,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: isZahra
                                    ? _tapZahraCounter
                                    : () => _incrementDhikr(
                                          activePractice,
                                          1,
                                        ),
                                borderRadius: BorderRadius.circular(30),
                                child: Container(
                                  width: 184,
                                  height: 50,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(26),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        colors.primary,
                                        colors.primaryPressed,
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: colors.primary
                                            .withValues(alpha: 0.28),
                                        blurRadius: 18,
                                        offset: const Offset(0, 7),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        CupertinoIcons.add,
                                        color: colors.onPrimary,
                                        size: 19,
                                      ),
                                      const SizedBox(width: 7),
                                      Text(
                                        'یک ذکر',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: colors.onPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // --------------------------------------------------------
                  // THREE STEP PROGRESS
                  // --------------------------------------------------------

                  if (isZahra) ...[
                    const SizedBox(height: 16),

                    Row(
                      children: List.generate(3, (index) {
                        final passed = index < _zahraStep;
                        final active = index == _zahraStep;

                        return Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            height: active ? 5 : 4,
                            margin: EdgeInsets.only(
                              left: index == 2 ? 0 : 6,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: passed
                                  ? LinearGradient(
                                      colors: [
                                        colors.primaryPressed,
                                        colors.primary,
                                      ],
                                    )
                                  : active
                                      ? LinearGradient(
                                          colors: [
                                            colors.accent,
                                            colors.accentContainer,
                                          ],
                                        )
                                      : null,
                              color: passed || active
                                  ? null
                                  : (isDark
                                      ? colors.border
                                      : colors.border),
                            ),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 9),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'الله اکبر',
                          style: _stepLabelStyle(
                            isActive: _zahraStep == 0,
                            colors: colors,
                            isDark: isDark,
                          ),
                        ),
                        Text(
                          'الحمدلله',
                          style: _stepLabelStyle(
                            isActive: _zahraStep == 1,
                            colors: colors,
                            isDark: isDark,
                          ),
                        ),
                        Text(
                          'سبحان الله',
                          style: _stepLabelStyle(
                            isActive: _zahraStep == 2,
                            colors: colors,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // --------------------------------------------------------
                  // COMPLETED ROUNDS
                  // --------------------------------------------------------

                  if (isZahra && done > 0) ...[
                    const SizedBox(height: 14),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? colors.surfaceSunken
                            : colors.surfaceSunken,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: colors.accent
                              .withValues(alpha: 0.22),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.checkmark_seal_fill,
                            size: 16,
                            color: colors.accent,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'امروز ${toPersianDigits(done.toString())} دور کامل',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? colors.accentContainer
                                  : colors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                // --------------------------------------------------------
                // ACTION BAR
                // --------------------------------------------------------

                const SizedBox(height: 18),

                Container(
                  height: 72,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colors.surfaceSunken
                        : colors.surfaceSunken,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : colors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildActionBarItem(
                          colors,
                          icon: CupertinoIcons.fullscreen,
                          label: 'تمام‌صفحه',
                          color: colors.primary,
                          onTap: _openFullscreenTasbih,
                        ),
                      ),

                      _actionDivider(colors, isDark),

                      Expanded(
                        child: _buildActionBarItem(
                          colors,
                          icon: CupertinoIcons.refresh,
                          label: 'بازنشانی',
                          color: colors.textSecondary,
                          onTap: isZahra
                              ? _resetZahraCounter
                              : () => _resetDhikr(activePractice),
                        ),
                      ),

                      _actionDivider(colors, isDark),

                      Expanded(
                        child: _buildActionBarItem(
                          colors,
                          icon: CupertinoIcons.slider_horizontal_3,
                          label: 'تنظیم دستی',
                          color: colors.textSecondary,
                          onTap: () =>
                              _manuallySetDhikrCount(activePractice),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

TextStyle _stepLabelStyle({
  required bool isActive,
  required RitmoColors colors,
  required bool isDark,
}) {
  return TextStyle(
    fontSize: 10.5,
    fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
    color: isActive
        ? (isDark
            ? colors.primary
            : colors.primaryPressed)
        : colors.textSecondary.withValues(alpha: 0.48),
  );
}

Widget _actionDivider(
  RitmoColors colors,
  bool isDark,
) {
  return Container(
    width: 1,
    height: 28,
    color: isDark
        ? Colors.white.withValues(alpha: 0.06)
        : colors.border.withValues(alpha: 0.45),
  );
}

  Widget _buildActionBarItem(
    RitmoColors colors, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuranSettingsSheet extends StatefulWidget {

  const _QuranSettingsSheet({
    required this.practice,
    required this.onSaved,
  });
  final WorshipPractice practice;
  final VoidCallback onSaved;

  @override
  State<_QuranSettingsSheet> createState() => _QuranSettingsSheetState();
}

class _QuranSettingsSheetState extends State<_QuranSettingsSheet> {
  late int _targetPages;
  late bool _showInCalendar;

  @override
  void initState() {
    super.initState();
    _targetPages = widget.practice.dailyTarget;
    _showInCalendar = widget.practice.showInCalendar;
  }

  Future<void> _save() async {
    unawaited(HapticFeedback.mediumImpact());
    try {
      final db = await DatabaseHelper.instance.database;
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      await db.update(
        'worship_practices',
        {
          'dailyTarget': _targetPages,
          'showInCalendar': _showInCalendar ? 1 : 0,
          'updatedAt': nowMs,
        },
        where: 'id = ?',
        whereArgs: [widget.practice.id],
      );

      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving Quran target: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final presets = [1, 2, 4, 5, 10, 20];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: colors.border.withValues(alpha: isDark ? 0.3 : 0.4),
            width: 1,
          ),
        ),
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
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

            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(CupertinoIcons.book_fill, color: colors.primary, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'تنظیمات قرائت قرآن',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                        ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(CupertinoIcons.xmark_circle_fill, color: colors.textTertiary, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Target Stepper Pod
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceSunken.withValues(alpha: isDark ? 0.4 : 0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colors.border.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'هدف روزانه تلاوت:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                          ),
                      ),
                      Text(
                        toPersianDigits('$_targetPages صفحه در روز'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? colors.primary : colors.primary,
                          ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      InkWell(
                        onTap: () {
                          if (_targetPages > 1) {
                            unawaited(HapticFeedback.selectionClick());
                            setState(() => _targetPages--);
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.border.withValues(alpha: 0.3)),
                          ),
                          child: Icon(CupertinoIcons.minus, color: colors.textPrimary, size: 18),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          toPersianDigits('$_targetPages'),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: colors.textPrimary,
                            ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          if (_targetPages < 604) {
                            unawaited(HapticFeedback.selectionClick());
                            setState(() => _targetPages++);
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(CupertinoIcons.plus, color: colors.onPrimary, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Quick Presets Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: presets.map((p) {
                      final isSelected = _targetPages == p;
                      return GestureDetector(
                        onTap: () {
                          unawaited(HapticFeedback.selectionClick());
                          setState(() => _targetPages = p);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? colors.primary : colors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? colors.primary : colors.border.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            p == 20 ? '۲۰ (یک جزء)' : '${toPersianDigits('$p')} صفحه',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? colors.onPrimary : colors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Calendar Toggle Switch
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colors.surfaceSunken.withValues(alpha: isDark ? 0.4 : 0.6),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: colors.border.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'نمایش در تقویم و برنامه روزانه',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                            ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'قرائت قرآن به عنوان تسک روزانه در تقویم ظاهر شود',
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textSecondary.withValues(alpha: 0.8),
                            ),
                        ),
                      ],
                    ),
                  ),
                  CupertinoSwitch(
                    value: _showInCalendar,
                    activeTrackColor: colors.primary,
                    onChanged: (val) {
                      setState(() {
                        _showInCalendar = val;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Save Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: _save,
              child: Text(
                'ذخیره تنظیمات',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.onPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddDhikrSheet extends StatefulWidget {

  const _AddDhikrSheet({required this.onSaved});
  final VoidCallback onSaved;

  @override
  State<_AddDhikrSheet> createState() => _AddDhikrSheetState();
}

class _AddDhikrSheetState extends State<_AddDhikrSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _targetController = TextEditingController(text: '100');
  bool _showInCalendar = false;

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final target = int.tryParse(_targetController.text) ?? 100;
    if (title.isEmpty) return;

    unawaited(HapticFeedback.mediumImpact());
    try {
      final db = await DatabaseHelper.instance.database;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final id = 'wp_dhikr_custom_$nowMs';

      await db.insert(
        'worship_practices',
        {
          'id': id,
          'practiceType': 'DHIKR',
          'subType': 'CUSTOM',
          'title': title,
          'dailyTarget': target,
          'dailyDone': 0,
          'reminderEnabled': 0,
          'isActive': 1,
          'showInCalendar': _showInCalendar ? 1 : 0,
          'dailyDoneDate': todayStr,
          'createdAt': nowMs,
          'updatedAt': nowMs,
        },
      );

      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving custom dhikr: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RitmoTheme.glassCardLight(
        borderRadius: 28,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'افزودن ذکر سفارشی جدید',
                    style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: colors.textPrimary),
                  ),
                  IconButton(
                    icon: Icon(CupertinoIcons.xmark, color: colors.textSecondary, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Title
              TextField(
                controller: _titleController,
                style: TextStyle(color: colors.textPrimary, fontSize: 14.5),
                decoration: InputDecoration(
                  hintText: 'نام ذکر (مثلا: لا اله الا الله)',
                  hintStyle: TextStyle(color: colors.textSecondary.withValues(alpha: 0.5), fontSize: 13.5),
                  fillColor: colors.inputBackground,
                  filled: true,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colors.glassBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colors.accent),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Target count
              TextField(
                controller: _targetController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: colors.textPrimary, fontSize: 14.5),
                decoration: InputDecoration(
                  hintText: 'هدف روزانه (تعداد مرتبه)',
                  hintStyle: TextStyle(color: colors.textSecondary.withValues(alpha: 0.5), fontSize: 13.5),
                  fillColor: colors.inputBackground,
                  filled: true,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colors.glassBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colors.accent),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Calendar Toggle Switch
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: colors.inputBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.glassBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'نمایش در تقویم و برنامه روزانه',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: colors.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'این ذکر در لیست کارهای روزانه تقویم ظاهر شود',
                            style: TextStyle(fontSize: 11, color: colors.textSecondary.withValues(alpha: 0.8)),
                          ),
                        ],
                      ),
                    ),
                    CupertinoSwitch(
                      value: _showInCalendar,
                      activeTrackColor: colors.primary,
                      onChanged: (val) {
                        setState(() {
                          _showInCalendar = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  foregroundColor: colors.onPrimary,
                  backgroundColor: colors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _save,
                child: Text('ثبت و افزودن ذکر', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.onPrimary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DhikrSettingsSheet extends StatefulWidget {
  const _DhikrSettingsSheet({
    required this.practice,
    required this.onSaved,
    required this.onDeleted,
  });

  final WorshipPractice practice;
  final VoidCallback onSaved;
  final VoidCallback onDeleted;

  @override
  State<_DhikrSettingsSheet> createState() => _DhikrSettingsSheetState();
}

class _DhikrSettingsSheetState extends State<_DhikrSettingsSheet> {
  late TextEditingController _targetController;
  late bool _showInCalendar;

  @override
  void initState() {
    super.initState();
    _targetController = TextEditingController(text: widget.practice.dailyTarget.toString());
    _showInCalendar = widget.practice.showInCalendar;
  }

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final target = int.tryParse(_targetController.text) ?? widget.practice.dailyTarget;
    unawaited(HapticFeedback.mediumImpact());
    try {
      final db = await DatabaseHelper.instance.database;
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      await db.update(
        'worship_practices',
        {
          'dailyTarget': target > 0 ? target : 1,
          'showInCalendar': _showInCalendar ? 1 : 0,
          'updatedAt': nowMs,
        },
        where: 'id = ?',
        whereArgs: [widget.practice.id],
      );

      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Error saving dhikr settings: $e');
    }
  }

  Future<void> _delete() async {
    final colors = context.colors;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: colors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('حذف ذکر', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
          content: Text('آیا از حذف «${widget.practice.title}» اطمینان دارید؟', style: TextStyle(color: colors.textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('انصراف', style: TextStyle(color: colors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: colors.error, elevation: 0),
              onPressed: () => Navigator.pop(context, true),
              child: Text('حذف', style: TextStyle(color: colors.textOnColor, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      try {
        final db = await DatabaseHelper.instance.database;
        await db.delete('worship_practices', where: 'id = ?', whereArgs: [widget.practice.id]);
        if (mounted) Navigator.pop(context);
        widget.onDeleted();
      } catch (e) {
        debugPrint('Error deleting dhikr: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isZahra = widget.practice.id == 'wp_dhikr_zahra';
    final isCustom = widget.practice.subType == 'CUSTOM';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: colors.border.withValues(alpha: isDark ? 0.3 : 0.4),
            width: 1,
          ),
        ),
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
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

            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(CupertinoIcons.slider_horizontal_3, color: isDark ? colors.accent : colors.accent, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'تنظیمات ${isZahra ? 'تسبیحات حضرت زهرا (س)' : widget.practice.title}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                        ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(CupertinoIcons.xmark_circle_fill, color: colors.textTertiary, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Target Count Field (if not Zahra)
            if (!isZahra) ...[
              Text(
                'هدف روزانه (تعداد مرتبه):',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                  ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _targetController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: colors.textPrimary, fontSize: 14.5),
                decoration: InputDecoration(
                  fillColor: colors.inputBackground,
                  filled: true,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colors.border.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colors.accent),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Calendar Toggle Switch
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colors.surfaceSunken.withValues(alpha: isDark ? 0.4 : 0.6),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: colors.border.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'نمایش در تقویم و برنامه روزانه',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                            ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'این ذکر در تسک‌های تقویم نمایش داده شود',
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textSecondary.withValues(alpha: 0.8),
                            ),
                        ),
                      ],
                    ),
                  ),
                  CupertinoSwitch(
                    value: _showInCalendar,
                    activeTrackColor: colors.primary,
                    onChanged: (val) {
                      setState(() {
                        _showInCalendar = val;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Save and Delete Buttons
            Row(
              children: [
                if (isCustom) ...[
                  IconButton(
                    onPressed: _delete,
                    icon: Icon(CupertinoIcons.trash, color: colors.error),
                    tooltip: 'حذف ذکر',
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: _save,
                    child: Text(
                      'ذخیره تنظیمات',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.onPrimary),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ScaleOnTap extends StatefulWidget {

  const ScaleOnTap({super.key, required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  State<ScaleOnTap> createState() => _ScaleOnTapState();
}

class _ScaleOnTapState extends State<ScaleOnTap> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 70),
    );
    _scale = Tween<double>(begin: 1, end: 0.94).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) async {
        await _controller.forward();
        unawaited(_controller.reverse());
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}

class _TasbihProgressPainter extends CustomPainter {
  final double progress;
  final bool isDark;
  final RitmoColors colors;

  _TasbihProgressPainter({
    required this.progress,
    required this.isDark,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 16;

    // ------------------------------------------------------------
    // BACKGROUND TRACK RING
    // ------------------------------------------------------------

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = isDark
          ? colors.border
          : colors.border;

    canvas.drawCircle(center, radius, trackPaint);

    // ------------------------------------------------------------
    // MAIN PROGRESS
    // ------------------------------------------------------------

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [
          colors.primaryPressed,
          colors.primary,
        ],
      ).createShader(
        Rect.fromCircle(
          center: center,
          radius: radius,
        ),
      );

    const startAngle = -math.pi / 2;
    final sweepAngle = math.pi * 2 * progress;

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(
          center: center,
          radius: radius,
        ),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }

    // ------------------------------------------------------------
    // GOLD GLOW & DOT
    // ------------------------------------------------------------

    if (progress > 0) {
      final endAngle = startAngle + sweepAngle;

      final endPoint = Offset(
        center.dx + radius * math.cos(endAngle),
        center.dy + radius * math.sin(endAngle),
      );

      final glowPaint = Paint()
        ..color = colors.accent.withValues(alpha: 0.20)
        ..maskFilter = const MaskFilter.blur(
          BlurStyle.normal,
          10,
        );

      canvas.drawCircle(
        endPoint,
        8,
        glowPaint,
      );

      final dotPaint = Paint()
        ..color = colors.accent;

      canvas.drawCircle(
        endPoint,
        6,
        dotPaint,
      );

      final innerDotPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.65);

      canvas.drawCircle(
        endPoint,
        2,
        innerDotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TasbihProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isDark != isDark;
  }
}
