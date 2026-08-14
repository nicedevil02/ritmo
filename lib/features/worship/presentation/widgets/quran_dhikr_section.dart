import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/worship/models/worship_models.dart';
import 'package:ritmo/features/worship/presentation/widgets/fullscreen_tasbih_sheet.dart';

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
  void didUpdateWidget(QuranDhikrSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final nowMs = DateTime.now().millisecondsSinceEpoch;

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

      // Daily reset is handled centrally in EndOfDaySweep

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

      if (mounted) {
        setState(() {
          _quranPractice = quranP;
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
    final newDone = (currentDone + delta).clamp(0, 999);

    try {
      final db = await DatabaseHelper.instance.database;
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      final updated = _quranPractice!.copyWith(
        dailyDone: newDone,
        updatedAt: nowMs,
      );

      await db.update(
        'worship_practices',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [updated.id],
      );

      setState(() {
        _quranPractice = updated;
      });
      widget.onChanged();
    } catch (e) {
      debugPrint('Error updating Quran pages: $e');
    }
  }

  Future<void> _toggleQuranActive(bool isActive) async {
    if (_quranPractice == null) return;
    unawaited(HapticFeedback.lightImpact());
    try {
      final db = await DatabaseHelper.instance.database;
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      final updated = _quranPractice!.copyWith(
        isActive: isActive,
        updatedAt: nowMs,
      );

      await db.update(
        'worship_practices',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [updated.id],
      );

      setState(() {
        _quranPractice = updated;
      });
      widget.onChanged();
    } catch (e) {
      debugPrint('Error toggling Quran active: $e');
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
        final updated = activePractice.copyWith(
          dailyDone: activePractice.dailyDone + 1,
          updatedAt: nowMs,
        );

        await db.update(
          'worship_practices',
          updated.toMap(),
          where: 'id = ?',
          whereArgs: [updated.id],
        );

        await _loadData();
        widget.onChanged();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تسبیحات حضرت زهرا (س) به پایان رسید. قبول باشد ✨', style: TextStyle(fontFamily: 'Vazirmatn')),
              backgroundColor: Color(0xffD4A843),
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

  void _openFullscreenTasbih({String? title, int target = 100, bool isFatima = false}) {
    FullscreenTasbihSheet.present(
      context,
      initialDhikrTitle: title ?? 'تسبیحات حضرت زهرا (س)',
      targetCount: target,
      isFatimaTasbih: isFatima,
    ).then((_) {
      _loadData();
      widget.onChanged();
    });
  }

  // --- OTHER DHIKRS ACTIONS ---
  Future<void> _incrementDhikr(WorshipPractice practice, int amount) async {
    unawaited(HapticFeedback.lightImpact());
    final newDone = (practice.dailyDone + amount).clamp(0, 99999);

    try {
      final db = await DatabaseHelper.instance.database;
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      final updated = practice.copyWith(
        dailyDone: newDone,
        updatedAt: nowMs,
      );

      await db.update(
        'worship_practices',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [practice.id],
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

      final updated = practice.copyWith(
        dailyDone: 0,
        updatedAt: nowMs,
      );

      await db.update(
        'worship_practices',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [practice.id],
      );

      await _loadData();
      widget.onChanged();
    } catch (e) {
      debugPrint('Error resetting dhikr: $e');
    }
  }

  Future<void> _deleteCustomDhikr(WorshipPractice practice) async {
    unawaited(HapticFeedback.vibrate());
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete(
        'worship_practices',
        where: 'id = ?',
        whereArgs: [practice.id],
      );
      if (_selectedDhikrId == practice.id) {
        _selectedDhikrId = 'wp_dhikr_zahra';
      }
      await _loadData();
      widget.onChanged();
    } catch (e) {
      debugPrint('Error deleting custom dhikr: $e');
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
              style: TextStyle(color: colors.textPrimary, fontFamily: 'Vazirmatn', fontSize: 15.5, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'تعداد انجام شده امروز را وارد کنید:',
                  style: TextStyle(color: colors.textSecondary, fontFamily: 'Vazirmatn', fontSize: 13.5),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: colors.textPrimary, fontFamily: 'Vazirmatn'),
                  decoration: InputDecoration(
                    fillColor: colors.inputBackground,
                    filled: true,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.glassBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xffD4A843)),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('انصراف', style: TextStyle(color: colors.textSecondary, fontFamily: 'Vazirmatn')),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xffD4A843),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text('ذخیره', style: TextStyle(color: colors.textPrimary, fontFamily: 'Vazirmatn')),
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

        await db.update(
          'worship_practices',
          {
            'dailyDone': value,
            'updatedAt': nowMs,
          },
          where: 'id = ?',
          whereArgs: [practice.id],
        );

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
          // Section Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'قرآن و اذکار',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                  fontFamily: 'Vazirmatn',
                ),
              ),
              IconButton(
                icon: Icon(CupertinoIcons.settings, color: colors.textSecondary, size: 20),
                onPressed: _showQuranSettingsSheet,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 10),

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

    final weeklyValues = <int>[14, 11, 16, 9, 12, 10, 8];
    if (done > 0) {
      weeklyValues[todayIndex] = done;
    }
    final maxCount = weeklyValues.fold<int>(1, (prev, elem) => elem > prev ? elem : prev);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0E1312) : const Color(0xFFFAF8F5),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isDark
              ? const Color(0xFF1E3A32).withValues(alpha: 0.5)
              : const Color(0xFFE6EAE7).withValues(alpha: 0.8),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.35)
                : const Color(0xFF0C6253).withValues(alpha: 0.04),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Padding(
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
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0C6253), Color(0xFF08453A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0C6253).withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              CupertinoIcons.book_fill,
                              color: Color(0xFFF3E5AB),
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
                              fontFamily: 'Vazirmatn',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'تلاوت و انس روزانه با کلام الله',
                            style: TextStyle(
                              color: colors.textSecondary.withValues(alpha: 0.75),
                              fontSize: 11.5,
                              fontFamily: 'Vazirmatn',
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
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF14241F) : const Color(0xFFE8F1EC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF1E3A32) : const Color(0xFFD0E2D9),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.slider_horizontal_3,
                            size: 13,
                            color: isDark ? const Color(0xFF34D399) : const Color(0xFF0C6253),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'هدف: ${toPersianDigits('$target')} صفحه',
                            style: TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFF34D399) : const Color(0xFF0C6253),
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
                  // Right Side: 3D Artwork of Holy Quran (With seamless feathered fade)
                  GestureDetector(
                    onTap: _showQuranSettingsSheet,
                    child: SizedBox(
                      width: 145,
                      height: 135,
                      child: ShaderMask(
                        shaderCallback: (bounds) => const RadialGradient(
                          center: Alignment.center,
                          radius: 0.75,
                          colors: [Colors.white, Colors.white, Colors.transparent],
                          stops: [0.0, 0.72, 1.0],
                        ).createShader(bounds),
                        blendMode: BlendMode.dstIn,
                        child: Image.asset(
                          isDark
                              ? 'assets/images/quran_card_dark.png'
                              : 'assets/images/quran_card_light.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF0C6253).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Center(
                              child: Icon(
                                CupertinoIcons.book_fill,
                                color: Color(0xFF0C6253),
                                size: 48,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Left Side: Big Number + Title + Today Tag + +/- Controls
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              toPersianDigits('$done'),
                              style: TextStyle(
                                fontSize: 50,
                                fontWeight: FontWeight.w900,
                                color: isDark ? const Color(0xFF34D399) : const Color(0xFF0C6253),
                                fontFamily: 'Vazirmatn',
                                height: 1.0,
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
                                      color: isDark
                                          ? const Color(0xFF132A22)
                                          : const Color(0xFF0C6253).withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      CupertinoIcons.plus,
                                      size: 14,
                                      color: isDark ? const Color(0xFF34D399) : const Color(0xFF0C6253),
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
                                          ? const Color(0xFF1E2026)
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
                          'صفحه خوانده شده',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                            fontFamily: 'Vazirmatn',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF10B981),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'امروز',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: colors.textSecondary.withValues(alpha: 0.75),
                                fontFamily: 'Vazirmatn',
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

              // 3. WEEKLY BAR CHART
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
                      final ratio = (countVal / maxCount).clamp(0.2, 1.0);
                      final barHeight = 38.0 * ratio;

                      return Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              toPersianDigits('$countVal'),
                              style: TextStyle(
                                fontFamily: 'Vazirmatn',
                                fontSize: 11.5,
                                fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                                color: isToday
                                    ? (isDark ? const Color(0xFF34D399) : const Color(0xFF0C6253))
                                    : colors.textTertiary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: 12,
                              height: barHeight,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(7),
                                gradient: isToday
                                    ? const LinearGradient(
                                        colors: [Color(0xFF0C6253), Color(0xFF10B981)],
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                      )
                                    : null,
                                color: isToday
                                    ? null
                                    : (isDark
                                        ? const Color(0xFF1B322A)
                                        : const Color(0xFFCDE2D9)),
                                boxShadow: isToday
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF10B981).withValues(alpha: 0.55),
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
                    color: isDark
                        ? const Color(0xFF1E3A32).withValues(alpha: 0.6)
                        : const Color(0xFFD6E4DE),
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
                              fontFamily: 'Vazirmatn',
                              fontSize: 12,
                              fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                              color: isToday
                                  ? (isDark ? const Color(0xFF34D399) : const Color(0xFF0C6253))
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131418) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.3) : const Color(0xFFD4A843).withValues(alpha: 0.04),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: Elegant & Minimal
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(CupertinoIcons.sparkles, color: Color(0xFFC48A1A), size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: activePractice.id,
                        dropdownColor: isDark ? const Color(0xFF1E1F24) : Colors.white,
                        icon: const Icon(CupertinoIcons.chevron_down, color: Color(0xFFC48A1A), size: 16),
                        isDense: true,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Vazirmatn',
                        ),
                        items: _dhikrs.map((d) {
                          return DropdownMenuItem<String>(
                            value: d.id,
                            child: Text(d.title),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
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
                  ),
                  InkWell(
                    onTap: _showAddDhikrSheet,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4A843).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'افزودن',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFFC48A1A),
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Vazirmatn',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Interactive Tactile Canvas (Seamless)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ScaleOnTap(
                onTap: isZahra ? _tapZahraCounter : () => _incrementDhikr(activePractice, 1),
                child: Container(
                  height: 190,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF1A1B21), const Color(0xFF131418)]
                          : [const Color(0xFFFDFBF7), const Color(0xFFF7F4EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        top: -40,
                        right: -40,
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFFD4A843).withValues(alpha: isDark ? 0.05 : 0.08),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isZahra ? _zahraPhrases[_zahraStep] : activePractice.title,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: isDark ? const Color(0xFFE8D090) : const Color(0xFFB47F15),
                              fontFamily: 'Vazirmatn',
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                isZahra
                                    ? toPersianDigits('$_zahraCount')
                                    : toPersianDigits('$done'),
                                style: TextStyle(
                                  fontSize: 56,
                                  fontWeight: FontWeight.w300,
                                  color: colors.textPrimary,
                                  fontFamily: 'Vazirmatn',
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isZahra
                                    ? toPersianDigits('/ ${_zahraTargets[_zahraStep]}')
                                    : toPersianDigits('/ $target'),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                  color: colors.textSecondary.withValues(alpha: 0.5),
                                  fontFamily: 'Vazirmatn',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // For Zahra: 3 Distinct Progress Segments (Modernized)
            if (isZahra)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: List.generate(3, (idx) {
                    final isPassed = _zahraStep > idx;
                    final isActive = _zahraStep == idx;
                    
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: EdgeInsets.only(left: idx < 2 ? 6 : 0),
                        decoration: BoxDecoration(
                          color: isPassed
                              ? const Color(0xFF10B981)
                              : (isActive
                                  ? const Color(0xFFC48A1A)
                                  : (isDark ? const Color(0xFF2A2B31) : const Color(0xFFE5E7EB))),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ),

            if (isZahra && done > 0)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Center(
                  child: Text(
                    toPersianDigits('امروز $done دور کامل انجام شده ✨'),
                    style: const TextStyle(
                      color: Color(0xFFC48A1A),
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Vazirmatn',
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // Sleek Action Bar
            Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1F24) : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionBarItem(
                    colors,
                    icon: CupertinoIcons.fullscreen,
                    label: 'تمام‌صفحه',
                    color: const Color(0xFFC48A1A),
                    onTap: () => _openFullscreenTasbih(
                      title: isZahra ? 'تسبیحات حضرت زهرا (س)' : activePractice.title,
                      target: isZahra ? 100 : activePractice.dailyTarget,
                      isFatima: isZahra,
                    ),
                  ),
                  Container(width: 1, height: 32, color: colors.border.withValues(alpha: 0.3)),
                  _buildActionBarItem(
                    colors,
                    icon: CupertinoIcons.refresh,
                    label: 'بازنشانی',
                    color: colors.textSecondary,
                    onTap: isZahra ? _resetZahraCounter : () => _resetDhikr(activePractice),
                  ),
                  Container(width: 1, height: 32, color: colors.border.withValues(alpha: 0.3)),
                  _buildActionBarItem(
                    colors,
                    icon: CupertinoIcons.pencil,
                    label: 'تنظیم دستی',
                    color: colors.textSecondary,
                    onTap: () => _manuallySetDhikrCount(activePractice),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
                fontFamily: 'Vazirmatn',
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

  @override
  void initState() {
    super.initState();
    _targetPages = widget.practice.dailyTarget;
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
                    'تنظیمات قرائت قرآن',
                    style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: colors.textPrimary, fontFamily: 'Vazirmatn'),
                  ),
                  IconButton(
                    icon: Icon(CupertinoIcons.xmark, color: colors.textSecondary, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'هدف روزانه (تعداد صفحه در روز):',
                    style: TextStyle(fontSize: 14.5, color: colors.textPrimary, fontFamily: 'Vazirmatn'),
                  ),
                  Text(
                    toPersianDigits('$_targetPages صفحه'),
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: Color(0xffD4A843), fontFamily: 'Vazirmatn'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      if (_targetPages > 1) {
                        setState(() {
                          _targetPages--;
                        });
                      }
                    },
                    icon: Icon(CupertinoIcons.minus_circle, color: colors.textSecondary, size: 24),
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    onPressed: () {
                      if (_targetPages < 604) {
                        setState(() {
                          _targetPages++;
                        });
                      }
                    },
                    icon: const Icon(CupertinoIcons.plus_circle, color: Color(0xffD4A843), size: 24),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // No reminder details area
              const SizedBox(height: 30),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xffD4A843),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _save,
                child: const Text('ثبت تنظیمات قرائت', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Vazirmatn')),
              ),
            ],
          ),
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
                    style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: colors.textPrimary, fontFamily: 'Vazirmatn'),
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
                style: TextStyle(color: colors.textPrimary, fontSize: 14.5, fontFamily: 'Vazirmatn'),
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
                    borderSide: const BorderSide(color: Color(0xffD4A843)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Target count
              TextField(
                controller: _targetController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: colors.textPrimary, fontSize: 14.5, fontFamily: 'Vazirmatn'),
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
                    borderSide: const BorderSide(color: Color(0xffD4A843)),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xffD4A843),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _save,
                child: const Text('ثبت و افزودن ذکر', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Vazirmatn')),
              ),
            ],
          ),
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
