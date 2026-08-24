import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/features/worship/models/worship_models.dart' hide toPersianDigits;
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

class _FullscreenTasbihSheetState extends State<FullscreenTasbihSheet> {
  late List<WorshipPractice> _dhikrs;
  late String _selectedPracticeId;
  late int _currentCount;
  late int _stageIndex; // For Zahra Tasbih (0, 1, 2)
  bool _hapticEnabled = true;
  bool _showRemaining = false;
  final FocusNode _focusNode = FocusNode();

  List<_TasbihStage> _getFatimaStages(RitmoColors colors) => [
    _TasbihStage('اللهُ أَکْبَرُ', 'الله اکبر', 34, colors.primary),
    _TasbihStage('الْحَمْدُ لِلَّهِ', 'الحمد لله', 33, colors.primaryPressed),
    _TasbihStage('سُبْحَانَ اللَّهِ', 'سبحان الله', 33, colors.accent),
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
          _showCompletionDialog();
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
        _showCompletionDialog();
      }
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

  void _showCompletionDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('قبول باشد 🤲', style: TextStyle()),
        content: const Text('ذکر به پایان رسید. ان‌شاءالله قبول حق باشد ✨', style: TextStyle()),
        actions: [
          CupertinoDialogAction(
            child: const Text('تکرار مجدد', style: TextStyle()),
            onPressed: () {
              Navigator.pop(context);
              _reset();
            },
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('پایان و بستن', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(context);
              _onPop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fatimaStages = _getFatimaStages(colors);

    final active = _activePractice;
    final stage = _isZahra ? fatimaStages[_stageIndex] : null;
    final activeColor = stage?.accentColor ?? colors.primary;
    final dhikrArabic = stage?.arabicText ?? active.title;
    final dhikrTitle = stage?.titleFa ?? 'ذکر روزانه';
    final target = stage?.target ?? active.dailyTarget;
    final progress = (target > 0) ? (_currentCount / target).clamp(0.0, 1.0) : 0.0;
    final remaining = (target - _currentCount).clamp(0, 99999);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _onPop();
        }
      },
      child: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.audioVolumeUp ||
                event.logicalKey == LogicalKeyboardKey.audioVolumeDown ||
                event.logicalKey == LogicalKeyboardKey.space ||
                event.logicalKey == LogicalKeyboardKey.arrowUp) {
              _onTap();
            }
          }
        },
        child: Scaffold(
          backgroundColor: colors.background,
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onTap,
            child: SafeArea(
              child: Stack(
                children: [
                  // ── Ambient Background Glow ──
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        width: 320,
                        height: 320,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              activeColor.withValues(alpha: isDark ? 0.08 : 0.07),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Central Counter & Interaction Area ──
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Stage indicator pills (for Fatima Tasbih)
                        if (_isZahra) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(fatimaStages.length, (i) {
                              final st = fatimaStages[i];
                              final isActive = i == _stageIndex;
                              final isDone = i < _stageIndex;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 280),
                                margin: const EdgeInsets.symmetric(horizontal: 5),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? (isDark
                                          ? st.accentColor.withValues(alpha: 0.22)
                                          : colors.primaryContainer)
                                      : isDone
                                          ? (isDark
                                              ? colors.surfaceSunken
                                              : colors.surfaceSunken)
                                          : (isDark
                                              ? colors.surfaceSunken
                                              : colors.surfaceSunken),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: isActive
                                        ? st.accentColor
                                        : isDone
                                            ? colors.textSecondary.withValues(alpha: 0.3)
                                            : colors.border.withValues(alpha: 0.3),
                                    width: isActive ? 1.8 : 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: st.accentColor.withValues(alpha: isActive ? 0.18 : 0.0),
                                      blurRadius: isActive ? 12 : 0,
                                      offset: isActive ? const Offset(0, 3) : Offset.zero,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  st.titleFa,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
                                    color: isActive
                                        ? (st.accentColor)
                                        : isDone
                                            ? colors.textSecondary
                                            : colors.textSecondary.withValues(alpha: 0.45),
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 32),
                        ],

                        // Arabic / Main Dhikr Phrase (Majestic & Large)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            dhikrArabic,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              color: colors.textPrimary,
                              height: 1.3,
                              letterSpacing: -0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        Text(
                          _isZahra
                              ? dhikrTitle
                              : (active.subType != null && active.subType!.isNotEmpty)
                                  ? active.subType!
                                  : 'تعداد دور انجام‌شده: ${toPersianDigits(active.dailyDone.toString())}',
                          style: TextStyle(
                            fontSize: 15,
                            color: isDark
                                ? colors.accent
                                : colors.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 44),

                        // Large Counter Circle Progress Ring (260x260)
                        GestureDetector(
                          onTap: () {
                            unawaited(HapticFeedback.selectionClick());
                            setState(() {
                              _showRemaining = !_showRemaining;
                            });
                          },
                          child: Container(
                            width: 260,
                            height: 260,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark
                                  ? colors.surface
                                  : colors.surface,
                              border: Border.all(
                                color: isDark
                                    ? colors.border
                                    : colors.border,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isDark
                                      ? Colors.black.withValues(alpha: 0.35)
                                      : colors.shadow.withValues(alpha: 0.12),
                                  blurRadius: 36,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Progress Ring
                                SizedBox(
                                  width: 246,
                                  height: 246,
                                  child: CircularProgressIndicator(
                                    value: progress,
                                    strokeWidth: 12,
                                    backgroundColor: isDark
                                        ? Colors.white.withValues(alpha: 0.06)
                                        : colors.border,
                                    valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                                    strokeCap: StrokeCap.round,
                                  ),
                                ),

                                // Count Number & Subtitle
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      toPersianDigits(_showRemaining ? '$remaining' : '$_currentCount'),
                                      style: TextStyle(
                                        fontSize: 76,
                                        fontWeight: FontWeight.w900,
                                        color: colors.textPrimary,
                                        height: 1.05,
                                        letterSpacing: -1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: activeColor.withValues(alpha: isDark ? 0.18 : 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _showRemaining
                                            ? 'باقیمانده تا هدف'
                                            : toPersianDigits('از $target'),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: activeColor,
                                          ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 42),

                        // Touch Hint Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                          decoration: BoxDecoration(
                            color: isDark
                                ? colors.surfaceSunken
                                : colors.surfaceSunken,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isDark
                                  ? colors.border
                                  : colors.border,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.touch_app_rounded,
                                size: 18,
                                color: colors.accent,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'برای افزایش شمارش، هر جای صفحه را لمس کنید یا کلید ولوم را بزنید',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Top Bar: Premium Luxury Actions ──
                  Positioned(
                    top: 14,
                    right: 18,
                    left: 18,
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Close Button (Premium Badge)
                          _buildTopActionBadge(
                            isDark: isDark,
                            colors: colors,
                            icon: Icons.close_rounded,
                            iconColor: colors.textPrimary,
                            size: 22,
                            onTap: _onPop,
                          ),

                          // In-Screen Dhikr Switcher Dropdown
                          if (_dhikrs.length > 1)
                            Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: colors.surfaceElevated,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: colors.border,
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                                    blurRadius: 14,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedPracticeId,
                                  dropdownColor: colors.surfaceElevated,
                                  borderRadius: BorderRadius.circular(18),
                                  icon: Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 18,
                                      color: activeColor,
                                    ),
                                  ),
                                  isDense: true,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: colors.textPrimary,
                                  ),
                                  items: _dhikrs.map((d) {
                                    return DropdownMenuItem<String>(
                                      value: d.id,
                                      child: Text(
                                        d.id == 'wp_dhikr_zahra' ? 'تسبیحات حضرت زهرا' : d.title,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
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
                            ),

                          // Top Left: Haptic Toggle & Reset Badges
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Vibration Toggle Badge
                              _buildTopActionBadge(
                                isDark: isDark,
                                colors: colors,
                                icon: _hapticEnabled
                                    ? Icons.vibration_rounded
                                    : Icons.mobile_off_rounded,
                                iconColor: _hapticEnabled
                                    ? (colors.accent)
                                    : colors.textSecondary.withValues(alpha: 0.4),
                                size: 21,
                                tooltip: _hapticEnabled ? 'ویبره هر لمس روشن است' : 'ویبره هر لمس خاموش است',
                                onTap: () {
                                  unawaited(HapticFeedback.mediumImpact());
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

                              // Reset Badge
                              _buildTopActionBadge(
                                isDark: isDark,
                                colors: colors,
                                icon: Icons.refresh_rounded,
                                iconColor: colors.textSecondary,
                                size: 22,
                                tooltip: 'بازنشانی شمارنده',
                                onTap: _reset,
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

  Widget _buildTopActionBadge({
    required bool isDark,
    required dynamic colors,
    required IconData icon,
    required Color iconColor,
    required double size,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.surfaceElevated,
            border: Border.all(
              color: colors.border,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Icon(icon, size: size, color: iconColor),
          ),
        ),
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
