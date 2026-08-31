import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/util/ritmo_number.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/features/worship/models/worship_models.dart';
import 'package:sqflite/sqflite.dart';

class FullscreenTasbihSheet extends StatefulWidget {
  const FullscreenTasbihSheet({
    super.key,
    required this.practices,
    required this.initialPracticeId,
    this.initialStep = 0,
    this.initialCount = 0,
  });

  final List<WorshipPractice> practices;
  final String initialPracticeId;
  final int initialStep;
  final int initialCount;

  static Future<Map<String, dynamic>?> present(
    BuildContext context, {
    List<WorshipPractice>? practices,
    String? initialPracticeId,
    String? initialDhikrTitle,
    String? dhikrSubtitle,
    int? targetCount,
    bool isFatimaTasbih = false,
    int initialStep = 0,
    int initialCount = 0,
  }) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    List<WorshipPractice> effectivePractices =
        practices != null ? List.from(practices) : [];
    String effectiveId = initialPracticeId ?? '';

    if (effectivePractices.isEmpty) {
      if (isFatimaTasbih) {
        effectiveId = 'wp_dhikr_zahra';
        effectivePractices = [
          WorshipPractice(
            id: 'wp_dhikr_zahra',
            practiceType: 'DHIKR',
            title: 'تسبیحات حضرت زهرا (س)',
            dailyTarget: 100,
            createdAt: nowMs,
            updatedAt: nowMs,
          ),
        ];
      } else {
        effectiveId = 'wp_dhikr_custom_$nowMs';
        effectivePractices = [
          WorshipPractice(
            id: effectiveId,
            practiceType: 'DHIKR',
            title: initialDhikrTitle ?? 'ذکر روز',
            subType: dhikrSubtitle,
            dailyTarget: targetCount ?? 100,
            createdAt: nowMs,
            updatedAt: nowMs,
          ),
        ];
      }
    } else if (effectiveId.isEmpty) {
      effectiveId = effectivePractices.first.id;
    }

    return Navigator.push<Map<String, dynamic>>(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (context, animation, secondaryAnimation) =>
            FullscreenTasbihSheet(
          practices: effectivePractices,
          initialPracticeId: effectiveId,
          initialStep: initialStep,
          initialCount: initialCount,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.90, end: 1.0).animate(curved),
              alignment: Alignment.center,
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  State<FullscreenTasbihSheet> createState() => _FullscreenTasbihSheetState();
}

class _FullscreenTasbihSheetState extends State<FullscreenTasbihSheet>
    with SingleTickerProviderStateMixin {
  late List<WorshipPractice> _dhikrs;
  late String _selectedPracticeId;
  late int _currentCount;
  late int _stageIndex; // 0, 1, 2 for Fatima's Tasbih
  bool _hapticEnabled = true;
  bool _showRemaining = false;
  bool _isTapped = false;
  final FocusNode _focusNode = FocusNode();

  List<_TasbihStage> _getFatimaStages(RitmoColors colors) => const [
        _TasbihStage('اللَّهُ أَکْبَرُ', 'الله اکبر', 34, Color(0xff6366F1)),
        _TasbihStage('الْحَمْدُ لِلَّهِ', 'الحمد لله', 33, Color(0xff0EA5E9)),
        _TasbihStage('سُبْحَانَ اللَّهِ', 'سبحان الله', 33, Color(0xff10B981)),
      ];

  @override
  void initState() {
    super.initState();
    _dhikrs = List.from(widget.practices);
    _selectedPracticeId = widget.initialPracticeId;
    _stageIndex = widget.initialStep;
    _currentCount = widget.initialCount;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  WorshipPractice get _activePractice {
    return _dhikrs.firstWhere(
      (p) => p.id == _selectedPracticeId,
      orElse: () => _dhikrs.isNotEmpty ? _dhikrs.first : _defaultPractice,
    );
  }

  bool get _isZahra => _selectedPracticeId == 'wp_dhikr_zahra';

  WorshipPractice get _defaultPractice {
    return WorshipPractice(
      id: 'wp_dhikr_zahra',
      practiceType: 'DHIKR',
      title: 'تسبیحات حضرت زهرا (س)',
      dailyTarget: 100,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  void _onPop() {
    Navigator.pop(context, {
      'practiceId': _selectedPracticeId,
      'step': _stageIndex,
      'count': _currentCount,
    });
  }

  Future<void> _onTap() async {
    setState(() {
      _isTapped = true;
    });
    Future.delayed(const Duration(milliseconds: 90), () {
      if (mounted) {
        setState(() {
          _isTapped = false;
        });
      }
    });

    // 1. Per-tap haptic (if enabled)
    if (_hapticEnabled) {
      unawaited(HapticFeedback.lightImpact());
    }

    if (_isZahra) {
      final colors = Theme.of(context).extension<RitmoColors>() ?? RitmoColors.dark;
      final fatimaStages = _getFatimaStages(colors);
      final target = fatimaStages[_stageIndex].target;
      setState(() {
        _currentCount++;
      });

      if (_currentCount >= target) {
        // Milestone Haptic: Always on (double heavy pulse)
        unawaited(HapticFeedback.heavyImpact());
        Future.delayed(const Duration(milliseconds: 120), () {
          HapticFeedback.vibrate();
        });

        if (_stageIndex < fatimaStages.length - 1) {
          setState(() {
            _stageIndex++;
            _currentCount = 0;
          });
        } else {
          // Completed full 100!
          setState(() {
            _stageIndex = 0;
            _currentCount = 0;
          });
          await _saveZahraFullRound();
          await _showCompletionDialog();
        }
      }
    } else {
      final active = _activePractice;
      final newDone = _currentCount + 1;
      setState(() {
        _currentCount = newDone;
      });

      if (newDone % 33 == 0 || newDone >= active.dailyTarget) {
        // Milestone Haptic: Always on
        unawaited(HapticFeedback.heavyImpact());
      }

      await _saveOtherDhikr(active, newDone);

      if (newDone == active.dailyTarget) {
        await _showCompletionDialog();
      }
    }
  }

  Future<void> _onDecrement() async {
    if (_currentCount <= 0) {
      if (_isZahra && _stageIndex > 0) {
        final colors = Theme.of(context).extension<RitmoColors>() ?? RitmoColors.dark;
        final fatimaStages = _getFatimaStages(colors);
        setState(() {
          _stageIndex--;
          _currentCount = fatimaStages[_stageIndex].target - 1;
        });
        unawaited(HapticFeedback.lightImpact());
      } else {
        RitmoHaptics.warning();
      }
      return;
    }

    unawaited(HapticFeedback.lightImpact());
    setState(() {
      _currentCount--;
    });

    if (!_isZahra) {
      final active = _activePractice;
      await _saveOtherDhikr(active, _currentCount);
    }
  }

  Future<void> _saveZahraFullRound() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final active = _activePractice;
      final newDone = active.dailyDone + 1;

      final updated = active.copyWith(
        dailyDone: newDone,
        dailyDoneDate: todayStr,
        updatedAt: nowMs,
      );

      final index = _dhikrs.indexWhere((p) => p.id == active.id);
      if (index >= 0) {
        _dhikrs[index] = updated;
      }

      await db.update(
        'worship_practices',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [updated.id],
      );

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
    } catch (e) {
      debugPrint('Error saving Zahra round in fullscreen: $e');
    }
  }

  Future<void> _saveOtherDhikr(WorshipPractice practice, int newDone) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);

      final updated = practice.copyWith(
        dailyDone: newDone,
        dailyDoneDate: todayStr,
        updatedAt: nowMs,
      );

      final index = _dhikrs.indexWhere((p) => p.id == practice.id);
      if (index >= 0) {
        _dhikrs[index] = updated;
      }

      await db.update(
        'worship_practices',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [practice.id],
      );

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
    } catch (e) {
      debugPrint('Error saving dhikr in fullscreen: $e');
    }
  }

  Future<void> _reset() async {
    unawaited(HapticFeedback.mediumImpact());
    setState(() {
      _currentCount = 0;
      if (_isZahra) {
        _stageIndex = 0;
      }
    });

    if (!_isZahra) {
      try {
        final db = await DatabaseHelper.instance.database;
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final todayStr = DateTime.now().toIso8601String().substring(0, 10);
        final active = _activePractice;

        final updated = active.copyWith(
          dailyDone: 0,
          dailyDoneDate: todayStr,
          updatedAt: nowMs,
        );

        final index = _dhikrs.indexWhere((p) => p.id == active.id);
        if (index >= 0) {
          _dhikrs[index] = updated;
        }

        await db.update(
          'worship_practices',
          updated.toMap(),
          where: 'id = ?',
          whereArgs: [active.id],
        );

        await db.delete(
          'worship_completions',
          where: 'practiceId = ? AND dateStr = ?',
          whereArgs: [active.id, todayStr],
        );
      } catch (e) {
        debugPrint('Error resetting dhikr in fullscreen: $e');
      }
    }
  }

  void _switchDhikr(String newId) {
    if (newId == _selectedPracticeId) return;
    unawaited(HapticFeedback.selectionClick());

    setState(() {
      _selectedPracticeId = newId;
      if (newId == 'wp_dhikr_zahra') {
        _stageIndex = 0;
        _currentCount = 0;
      } else {
        final active = _dhikrs.firstWhere(
          (p) => p.id == newId,
          orElse: () => _defaultPractice,
        );
        _currentCount = active.dailyDone;
      }
    });
  }

  Future<void> _showCompletionDialog() async {
    final repeat = await RitmoDialog.show(
      context,
      title: 'قبول باشد 🤲',
      content: 'ذکر به پایان رسید. ان‌شاءالله قبول حق باشد ✨',
      confirmLabel: 'تکرار مجدد',
      cancelLabel: 'پایان و بستن',
    );
    if (repeat == true) {
      await _reset();
    } else {
      _onPop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final isGlass = context.isGlassEnabled;
    final fatimaStages = _getFatimaStages(colors);

    final active = _activePractice;
    final stage = _isZahra ? fatimaStages[_stageIndex] : null;
    final activeColor = stage?.accentColor ?? colors.primary;
    final dhikrArabic = stage?.arabicText ?? active.title;
    final dhikrTitle = stage?.titleFa ?? 'ذکر روزانه';
    final target = stage?.target ?? active.dailyTarget;
    final progress = (target > 0) ? (_currentCount / target).clamp(0.0, 1.0) : 0.0;
    final remaining = (target - _currentCount).clamp(0, 99999);

    final blurSigma = context.glassBlurSigma.clamp(0.0, 50.0);
    final opacityAlpha = (context.glassOpacityPercent / 100.0).clamp(0.12, 0.95);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _onPop();
        }
      },
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.audioVolumeUp ||
                event.logicalKey == LogicalKeyboardKey.audioVolumeDown ||
                event.logicalKey == LogicalKeyboardKey.space ||
                event.logicalKey == LogicalKeyboardKey.arrowUp) {
              _onTap();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              _onDecrement();
              return KeyEventResult.handled;
            }
          } else if (event is KeyUpEvent || event is KeyRepeatEvent) {
            if (event.logicalKey == LogicalKeyboardKey.audioVolumeUp ||
                event.logicalKey == LogicalKeyboardKey.audioVolumeDown) {
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Scaffold(
          backgroundColor: colors.background,
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onTap,
            child: SafeArea(
              child: Stack(
                children: [
                  // ── Ambient Background Glow matching active stage ──
                  Positioned.fill(
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.easeOutCubic,
                        width: 340,
                        height: 340,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              activeColor.withValues(alpha: isDark ? 0.14 : 0.10),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Main Content Area ──
                  Column(
                    children: [
                      const SizedBox(height: 60), // Space for top glass bar

                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // ── سوییچ شیشه‌ای فازهای تسبیحات حضرت زهرا (Section 12/13 Reference) ──
                            if (_isZahra) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: RitmoGlassSegmentedControl<int>(
                                  selectedIndex: _stageIndex,
                                  accentColor: activeColor,
                                  onTabChanged: (val) {
                                    RitmoHaptics.selection();
                                    setState(() {
                                      _stageIndex = val;
                                      _currentCount = 0;
                                    });
                                  },
                                  items: const [
                                    RitmoTabItem(
                                      title: 'الله اکبر (۳۴)',
                                      icon: Icons.flare_rounded,
                                      value: 0,
                                    ),
                                    RitmoTabItem(
                                      title: 'الحمد لله (۳۳)',
                                      icon: Icons.favorite_rounded,
                                      value: 1,
                                    ),
                                    RitmoTabItem(
                                      title: 'سبحان الله (۳۳)',
                                      icon: Icons.auto_awesome_rounded,
                                      value: 2,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 28),
                            ],

                            // ── عبارت عربی ذکر با تایپوگرافی فاخر ──
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 320),
                                child: Text(
                                  dhikrArabic,
                                  key: ValueKey(dhikrArabic),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 38,
                                    fontWeight: FontWeight.w900,
                                    color: colors.textPrimary,
                                    fontFamily: 'Vazirmatn',
                                    height: 1.25,
                                    letterSpacing: -0.6,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),

                            // زیرعنوان و نام فارسی ذکر
                            Text(
                              _isZahra
                                  ? dhikrTitle
                                  : (active.subType != null && active.subType!.isNotEmpty)
                                      ? active.subType!
                                      : 'تعداد دور انجام‌شده: ${RitmoNumber.toFa(active.dailyDone.toString())}',
                              style: TextStyle(
                                fontSize: 14.5,
                                color: activeColor,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Vazirmatn',
                              ),
                            ),
                            const SizedBox(height: 20),

                            // ── دکمه ظریف ۱- برای کاهش شمارش و اصلاح خطا ──
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _onDecrement,
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isGlass
                                        ? (isDark
                                            ? const Color(0xFF131722).withValues(alpha: opacityAlpha)
                                            : Colors.white.withValues(alpha: opacityAlpha))
                                        : colors.surfaceElevated,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isGlass
                                          ? (isDark
                                              ? Colors.white.withValues(alpha: 0.12)
                                              : Colors.black.withValues(alpha: 0.06))
                                          : colors.border.withValues(alpha: 0.4),
                                      width: 0.8,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      '۱-',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        fontFamily: 'Vazirmatn',
                                        color: colors.textSecondary.withValues(alpha: _currentCount > 0 ? 0.95 : 0.35),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // ── دیسک لمسی نیومورفیک-شیشه‌ای شمارنده (Section 1 & 14 Reference) ──
                            AnimatedScale(
                              scale: _isTapped ? 0.94 : 1.0,
                              duration: const Duration(milliseconds: 110),
                              curve: Curves.easeOutBack,
                              child: Container(
                                width: 250,
                                height: 250,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isGlass
                                      ? (isDark
                                          ? const Color(0xFF161B26).withValues(alpha: opacityAlpha)
                                          : Colors.white.withValues(alpha: opacityAlpha))
                                      : (isDark ? colors.surfaceElevated : colors.surfaceElevated),
                                  border: Border.all(
                                    color: isGlass
                                        ? (isDark
                                            ? Colors.white.withValues(alpha: 0.15)
                                            : Colors.black.withValues(alpha: 0.08))
                                        : colors.border.withValues(alpha: 0.5),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.09),
                                      blurRadius: 36,
                                      offset: const Offset(0, 12),
                                    ),
                                    BoxShadow(
                                      color: activeColor.withValues(alpha: isDark ? 0.22 : 0.14),
                                      blurRadius: 28,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // رینگ پیشرفت نئونی دورانی
                                      SizedBox(
                                        width: 236,
                                        height: 236,
                                        child: CircularProgressIndicator(
                                          value: progress,
                                          strokeWidth: 11,
                                          backgroundColor: activeColor.withValues(alpha: 0.12),
                                          valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                                          strokeCap: StrokeCap.round,
                                        ),
                                      ),

                                      // عدد بزرگ شمارنده و کپسول هدف
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          AnimatedSwitcher(
                                            duration: const Duration(milliseconds: 180),
                                            transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                                            child: Text(
                                              RitmoNumber.toFa(_showRemaining ? '$remaining' : '$_currentCount'),
                                              key: ValueKey('$_currentCount-$_showRemaining'),
                                              style: TextStyle(
                                                fontSize: 74,
                                                fontWeight: FontWeight.w900,
                                                color: colors.textPrimary,
                                                fontFamily: 'Vazirmatn',
                                                height: 1.05,
                                                letterSpacing: -1.5,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),

                                          // بج وضعیت هدف / باقیمانده
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: activeColor.withValues(alpha: 0.14),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: activeColor.withValues(alpha: 0.35),
                                                width: 0.8,
                                              ),
                                            ),
                                            child: Text(
                                              _showRemaining
                                                  ? 'مانده از ${RitmoNumber.toFa(target.toString())}'
                                                  : 'از ${RitmoNumber.toFa(target.toString())}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                color: activeColor,
                                                fontFamily: 'Vazirmatn',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // ── کپسول راهنمای لمس (رفع کامل خطای سرریز چیدمان با Flexible) ──
                      Container(
                        margin: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isGlass
                              ? (isDark
                                  ? const Color(0xFF131722).withValues(alpha: opacityAlpha)
                                  : Colors.white.withValues(alpha: opacityAlpha))
                              : colors.surfaceSunken,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isGlass
                                ? (isDark
                                    ? Colors.white.withValues(alpha: 0.10)
                                    : Colors.black.withValues(alpha: 0.06))
                                : colors.border.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.touch_app_rounded,
                              size: 17,
                              color: activeColor,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'برای افزایش شمارش، هر جای صفحه را لمس کنید یا کلید ولوم را بزنید',
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Vazirmatn',
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // ── هدر شیشه‌ای لوکس و اکشن‌های بالا ──
                  Positioned(
                    top: 10,
                    right: 14,
                    left: 14,
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // دکمه بازگشت و خروج
                          _buildGlassActionButton(
                            context: context,
                            colors: colors,
                            isDark: isDark,
                            isGlass: isGlass,
                            blurSigma: blurSigma,
                            opacityAlpha: opacityAlpha,
                            icon: Icons.close_rounded,
                            iconColor: colors.textPrimary,
                            onTap: _onPop,
                            tooltip: 'بستن',
                          ),

                          // دراپ‌داون شیشه‌ای تغییر ذکر
                          if (_dhikrs.length > 1)
                            _buildDhikrDropdown(
                              context: context,
                              colors: colors,
                              isDark: isDark,
                              isGlass: isGlass,
                              blurSigma: blurSigma,
                              opacityAlpha: opacityAlpha,
                              activeColor: activeColor,
                            ),

                          // دکمه‌های سوییچ حالت، ویبره و بازنشانی
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // دکمه سوییچ حالت شمارش (صعودی / باقیمانده)
                              _buildGlassActionButton(
                                context: context,
                                colors: colors,
                                isDark: isDark,
                                isGlass: isGlass,
                                blurSigma: blurSigma,
                                opacityAlpha: opacityAlpha,
                                icon: _showRemaining
                                    ? Icons.hourglass_bottom_rounded
                                    : Icons.plus_one_rounded,
                                iconColor: _showRemaining
                                    ? activeColor
                                    : colors.textSecondary,
                                tooltip: _showRemaining
                                    ? 'حالت نمایش: باقیمانده تا هدف'
                                    : 'حالت نمایش: شمارش صعودی',
                                onTap: () {
                                  RitmoHaptics.selection();
                                  setState(() {
                                    _showRemaining = !_showRemaining;
                                  });
                                  RitmoToast.show(
                                    context,
                                    _showRemaining
                                        ? 'حالت نمایش: باقیمانده تا پایان ذکر'
                                        : 'حالت نمایش: شمارش صعودی',
                                    icon: _showRemaining
                                        ? Icons.hourglass_bottom_rounded
                                        : Icons.plus_one_rounded,
                                    iconColor: activeColor,
                                  );
                                },
                              ),
                              const SizedBox(width: 8),

                              _buildGlassActionButton(
                                context: context,
                                colors: colors,
                                isDark: isDark,
                                isGlass: isGlass,
                                blurSigma: blurSigma,
                                opacityAlpha: opacityAlpha,
                                icon: _hapticEnabled
                                    ? Icons.vibration_rounded
                                    : Icons.mobile_off_rounded,
                                iconColor: _hapticEnabled
                                    ? activeColor
                                    : colors.textSecondary.withValues(alpha: 0.4),
                                tooltip: _hapticEnabled ? 'ویبره لمس روشن' : 'ویبره لمس خاموش',
                                onTap: () {
                                  RitmoHaptics.selection();
                                  setState(() {
                                    _hapticEnabled = !_hapticEnabled;
                                  });
                                  RitmoToast.show(
                                    context,
                                    _hapticEnabled
                                        ? 'ویبره هر لمس فعال شد'
                                        : 'ویبره هر لمس غیرفعال شد',
                                    icon: _hapticEnabled
                                        ? Icons.vibration_rounded
                                        : Icons.mobile_off_rounded,
                                    iconColor: _hapticEnabled
                                        ? colors.success
                                        : colors.warning,
                                  );
                                },
                              ),
                              const SizedBox(width: 8),

                              _buildGlassActionButton(
                                context: context,
                                colors: colors,
                                isDark: isDark,
                                isGlass: isGlass,
                                blurSigma: blurSigma,
                                opacityAlpha: opacityAlpha,
                                icon: Icons.refresh_rounded,
                                iconColor: colors.textSecondary,
                                tooltip: 'بازنشانی شمارنده',
                                onTap: () {
                                  RitmoHaptics.warning();
                                  _reset();
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassActionButton({
    required BuildContext context,
    required RitmoColors colors,
    required bool isDark,
    required bool isGlass,
    required double blurSigma,
    required double opacityAlpha,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    final buttonContent = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          RitmoHaptics.tap();
          onTap();
        },
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isGlass
                ? (isDark
                    ? const Color(0xFF131722).withValues(alpha: opacityAlpha)
                    : Colors.white.withValues(alpha: opacityAlpha))
                : colors.surfaceElevated,
            border: Border.all(
              color: isGlass
                  ? (isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.08))
                  : colors.border.withValues(alpha: 0.5),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Icon(icon, size: 21, color: iconColor),
          ),
        ),
      ),
    );

    if (!isGlass) return buttonContent;

    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: buttonContent,
      ),
    );
  }

  Widget _buildDhikrDropdown({
    required BuildContext context,
    required RitmoColors colors,
    required bool isDark,
    required bool isGlass,
    required double blurSigma,
    required double opacityAlpha,
    required Color activeColor,
  }) {
    final dropdownContent = Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: isGlass
            ? (isDark
                ? const Color(0xFF131722).withValues(alpha: opacityAlpha)
                : Colors.white.withValues(alpha: opacityAlpha))
            : colors.surfaceElevated,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isGlass
              ? (isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.08))
              : colors.border.withValues(alpha: 0.5),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedPracticeId,
          dropdownColor: isDark ? colors.surfaceElevated : colors.surfaceElevated,
          borderRadius: BorderRadius.circular(18),
          icon: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: activeColor,
            ),
          ),
          isDense: true,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            fontFamily: 'Vazirmatn',
            color: colors.textPrimary,
          ),
          items: _dhikrs.map((d) {
            return DropdownMenuItem<String>(
              value: d.id,
              child: Text(
                d.id == 'wp_dhikr_zahra' ? 'تسبیحات حضرت زهرا' : d.title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Vazirmatn',
                  color: colors.textPrimary,
                ),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) _switchDhikr(val);
          },
        ),
      ),
    );

    if (!isGlass) return dropdownContent;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: dropdownContent,
      ),
    );
  }
}

class _TasbihStage {
  const _TasbihStage(this.arabicText, this.titleFa, this.target, this.accentColor);
  final String arabicText;
  final String titleFa;
  final int target;
  final Color accentColor;
}
