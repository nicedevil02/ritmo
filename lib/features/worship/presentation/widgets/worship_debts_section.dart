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

class WorshipDebtsSection extends StatefulWidget {
  const WorshipDebtsSection({
    super.key,
    required this.onChanged,
  });

  final VoidCallback onChanged;

  @override
  State<WorshipDebtsSection> createState() => _WorshipDebtsSectionState();
}

class _WorshipDebtsSectionState extends State<WorshipDebtsSection> {
  bool _isLoading = true;
  List<WorshipDebt> _activeDebts = [];
  List<WorshipDebt> _archivedDebts = [];
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    _loadDebts();
  }

  @override
  void didUpdateWidget(WorshipDebtsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadDebts();
  }

  Future<void> _loadDebts() async {
    try {
      final db = await DatabaseHelper.instance.database;

      final results = await db.query('worship_debts');
      final list = results.map(WorshipDebt.fromMap).toList();

      final active = <WorshipDebt>[];
      final archived = <WorshipDebt>[];

      for (final d in list) {
        if (d.remainingCount <= 0 || d.isArchived) {
          archived.add(d);
        } else {
          active.add(d);
        }
      }

      if (mounted) {
        setState(() {
          _activeDebts = active;
          _archivedDebts = archived;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading worship debts: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _logBatchCompletion(WorshipDebt debt, int delta) async {
    if (delta <= 0) return;
    final colors = context.colors;
    unawaited(HapticFeedback.mediumImpact());
    final actualDelta = delta.clamp(1, debt.remainingCount);

    try {
      final db = await DatabaseHelper.instance.database;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final newRemaining = (debt.remainingCount - actualDelta).clamp(0, 999999);
      final isNowArchived = newRemaining == 0;

      await db.update(
        'worship_debts',
        {
          'remainingCount': newRemaining,
          'isArchived': isNowArchived ? 1 : 0,
          'updatedAt': nowMs,
        },
        where: 'id = ?',
        whereArgs: [debt.id],
      );

      // Record in worship_completions
      await db.insert(
        'worship_completions',
        {
          'id': 'comp_${debt.id}_$todayStr',
          'practiceId': debt.id,
          'dateStr': todayStr,
          'practiceType': 'QADA_${debt.debtType}',
          'resultType': isNowArchived ? 'DONE' : 'PARTIAL',
          'countDone': actualDelta,
          'countTarget': debt.dailyTarget,
          'loggedAt': nowMs,
          'createdAt': nowMs,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Fasting debt sync if cycle fast
      if (debt.id.startsWith('debt_cycle_fast_')) {
        final cycleDebtId = debt.id.replaceFirst('debt_cycle_fast_', '');
        await db.update(
          'fasting_debt',
          {
            'isResolved': isNowArchived ? 1 : 0,
            'updatedAt': nowMs,
          },
          where: 'id = ?',
          whereArgs: [cycleDebtId],
        );
      }

      await _loadDebts();
      widget.onChanged();

      if (mounted) {
        RitmoToast.show(
          context,
          isNowArchived
              ? 'تمام قضای "${debt.title}" با موفقیت ادا شد'
              : '$actualDelta مورد از قضای "${debt.title}" ثبت شد',
          icon: Icons.check_circle_rounded,
          iconColor: colors.success,
        );
      }
    } catch (e) {
      debugPrint('Error logging batch completion: $e');
    }
  }

  Future<void> _showCustomCountDialog(WorshipDebt debt) async {
    final controller = TextEditingController(text: '1');
    final count = await showDialog<int>(
      context: context,
      builder: (context) {
        final colors = context.colors;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: colors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: Text(
              'ثبت چندتایی قضای ${debt.title}',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'تعداد ادای امروز (حداکثر ${toPersianDigits(debt.remainingCount.toString())} مورد):',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                  decoration: InputDecoration(
                    fillColor: isDark ? colors.surfaceSunken : colors.surfaceSunken,
                    filled: true,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: colors.border.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: colors.primary, width: 1.8),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Quick Increment Chips
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [1, 2, 3, 5, 10].map((n) {
                    return InkWell(
                      onTap: () {
                        unawaited(HapticFeedback.selectionClick());
                        controller.text = '$n';
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colors.primary.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          toPersianDigits('+$n'),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: Text('انصراف', style: TextStyle(color: colors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  elevation: 0,
                ),
                onPressed: () {
                  final val = int.tryParse(controller.text) ?? 0;
                  if (val > 0) {
                    Navigator.pop(context, val);
                  }
                },
                child: Text('ثبت ادا', style: TextStyle(fontWeight: FontWeight.bold, color: colors.onPrimary)),
              ),
            ],
          ),
        );
      },
    );

    if (count != null && count > 0) {
      await _logBatchCompletion(debt, count);
    }
  }

  Future<void> _changeDailyTarget(WorshipDebt debt, int delta) async {
    unawaited(HapticFeedback.selectionClick());
    final newTarget = (debt.dailyTarget + delta).clamp(1, 100);

    try {
      final db = await DatabaseHelper.instance.database;
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      await db.update(
        'worship_debts',
        {
          'dailyTarget': newTarget,
          'updatedAt': nowMs,
        },
        where: 'id = ?',
        whereArgs: [debt.id],
      );

      await _loadDebts();
    } catch (e) {
      debugPrint('Error updating debt target: $e');
    }
  }

  Future<void> _deleteDebt(WorshipDebt debt) async {
    final colors = context.colors;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = context.colors;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: colors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: Text(
              'حذف مورد قضای عبادات',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            content: Text(
              'آیا از حذف "${debt.title}" اطمینان دارید؟ تمام سوابق مربوط به این بدهی پاک خواهد شد.',
              style: TextStyle(fontSize: 13.5, color: colors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('انصراف', style: TextStyle(color: colors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.error,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text('حذف دائم', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );

    if (confirm == true) {
      try {
        final db = await DatabaseHelper.instance.database;
        await db.delete('worship_debts', where: 'id = ?', whereArgs: [debt.id]);
        await db.delete('worship_completions', where: 'practiceId = ?', whereArgs: [debt.id]);
        await _loadDebts();
        widget.onChanged();
        if (mounted) {
          RitmoToast.show(
            context,
            'مورد "${debt.title}" حذف شد',
            icon: Icons.delete_outline_rounded,
            iconColor: colors.error,
          );
        }
      } catch (e) {
        debugPrint('Error deleting debt: $e');
      }
    }
  }

  Future<void> _restoreDebt(WorshipDebt debt) async {
    final colors = context.colors;
    try {
      final db = await DatabaseHelper.instance.database;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await db.update(
        'worship_debts',
        {
          'isArchived': 0,
          'remainingCount': debt.remainingCount > 0 ? debt.remainingCount : 1,
          'updatedAt': nowMs,
        },
        where: 'id = ?',
        whereArgs: [debt.id],
      );
      await _loadDebts();
      widget.onChanged();
      if (mounted) {
        RitmoToast.show(
          context,
          'مورد "${debt.title}" به لیست فعال بازگردانده شد',
          icon: Icons.restore_rounded,
          iconColor: colors.success,
        );
      }
    } catch (e) {
      debugPrint('Error restoring debt: $e');
    }
  }

  void _showAddDebtSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _AddDebtSheet(
          onSaved: () {
            _loadDebts();
            widget.onChanged();
          },
        );
      },
    );
  }

  void _showEditDebtSheet(WorshipDebt debt) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _EditDebtSheet(
          debt: debt,
          onSaved: () {
            _loadDebts();
            widget.onChanged();
          },
          onDeleted: () {
            _deleteDebt(debt);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator(color: colors.primary)),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
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
          child: Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Integrated Header Inside Card
                Row(
                  children: [
                    // right side: icon + title + subtitle
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
                                        colors.primaryContainer,
                                        colors.surface,
                                      ]
                                    : [
                                        colors.surface,
                                        colors.surfaceSunken,
                                      ],
                              ),
                              border: Border.all(
                                color: isDark
                                    ? colors.primary
                                    : colors.primaryContainer,
                              ),
                            ),
                            child: Icon(
                              Icons.balance_rounded,
                              size: 20,
                              color: colors.success,
                            ),
                          ),
                          SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'جبران و قضای عبادات',
                                  style: TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'پیگیری و جبران نماز و روزه قضا',
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

                    SizedBox(width: 10),

                    // Add Debt Button
                    InkWell(
                      onTap: _showAddDebtSheet,
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 9,
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
                              size: 15,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'افزودن مورد جبرانی',
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

                SizedBox(height: 20),

                // Card Content (Zero-State or Debts List)
                if (_activeDebts.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 24, horizontal: 12),
                    child: Center(
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      colors.success.withValues(alpha: 0.15),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: colors.surface,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: colors.success.withValues(alpha: 0.15),
                                      blurRadius: 20,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Icon(
                                    CupertinoIcons.checkmark_seal_fill,
                                    color: colors.success,
                                    size: 30,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20),
                          Text(
                            'کاروان عبادات تسویه و به‌روز است ✨',
                            style: TextStyle(
                              color: isDark ? colors.success : colors.success,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'هیچ بدهی یا قضای ثبت‌شده‌ای در انتظار نداری. با آرامش و سبک‌بالی به مسیرت ادامه بده.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colors.textSecondary.withValues(alpha: 0.8),
                              fontSize: 13,
                              height: 1.55,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  ListView.separated(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: _activeDebts.length,
                    separatorBuilder: (context, index) => SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final debt = _activeDebts[index];
                      final remaining = debt.remainingCount;
                      final total = debt.totalCount;
                      final completed = total - remaining;
                      final progress = debt.progressPercent / 100.0;
                      final daysLeft = debt.daysToFinish;

                      var typeEmoji = '📿';
                      if (debt.debtType == 'FAST') {
                        typeEmoji = '🌙';
                      } else if (debt.debtType == 'ATONEMENT') {
                        typeEmoji = '⚖️';
                      }

                      return Container(
                        padding: EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: isDark ? colors.surfaceSunken : colors.surfaceSunken,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? colors.border
                                : colors.border,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Text(typeEmoji, style: TextStyle(fontSize: 16)),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    debt.title,
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      ),
                                  ),
                                ),
                                // Edit/Settings Icon
                                InkWell(
                                  onTap: () => _showEditDebtSheet(debt),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(
                                      CupertinoIcons.ellipsis_vertical,
                                      size: 16,
                                      color: colors.textSecondary.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: colors.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    toPersianDigits('$completed از $total ادا شده'),
                                    style: TextStyle(
                                      color: colors.primary,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Progress bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: colors.surfaceSunken,
                                valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                                minHeight: 7,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Prediction Note
                            if (debt.dailyTarget > 0)
                              Text(
                                toPersianDigits('🎯 با روزی ${debt.dailyTarget} عدد، ظرف $daysLeft روز به پایان می‌رسد.'),
                                style: TextStyle(
                                  color: colors.textSecondary.withValues(alpha: 0.75),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            const SizedBox(height: 12),

                            // Actions Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Stepper for Daily Target
                                Row(
                                  children: [
                                    Text(
                                      'هدف روزانه: ',
                                      style: TextStyle(color: colors.textSecondary, fontSize: 11.5),
                                    ),
                                    InkWell(
                                      onTap: () => _changeDailyTarget(debt, -1),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: colors.surfaceSunken,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Icon(CupertinoIcons.minus, size: 12, color: colors.textSecondary),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      child: Text(
                                        toPersianDigits('${debt.dailyTarget}'),
                                        style: TextStyle(color: colors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => _changeDailyTarget(debt, 1),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: colors.surfaceSunken,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Icon(CupertinoIcons.plus, size: 12, color: colors.textSecondary),
                                      ),
                                    ),
                                  ],
                                ),

                                // Pay Buttons (Batch + Single)
                                Row(
                                  children: [
                                    // Custom/Batch button
                                    InkWell(
                                      onTap: () => _showCustomCountDialog(debt),
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                        decoration: BoxDecoration(
                                          color: colors.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: colors.primary.withValues(alpha: 0.25)),
                                        ),
                                        child: Text(
                                          'ثبت چندتایی',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: colors.primary,
                                            ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Quick +1 button
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: colors.primary,
                                        foregroundColor: colors.onPrimary,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: () => _logBatchCompletion(debt, 1),
                                      icon: Icon(CupertinoIcons.checkmark_alt, size: 14, color: colors.onPrimary),
                                      label: Text('ثبت ۱ ادا', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: colors.onPrimary)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Archived Section Toggle
                  if (_archivedDebts.isNotEmpty) ...[
                    Divider(color: colors.border.withValues(alpha: 0.3), height: 28),
                    GestureDetector(
                      onTap: () {
                        unawaited(HapticFeedback.selectionClick());
                        setState(() {
                          _showArchived = !_showArchived;
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _showArchived ? '🔻 بستن بایگانی' : '🔺 نمایش بدهی‌های پایان‌یافته (${toPersianDigits(_archivedDebts.length.toString())})',
                              style: TextStyle(
                                color: isDark ? colors.success : colors.success,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showArchived) ...[
                      SizedBox(height: 12),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: _archivedDebts.length,
                        itemBuilder: (context, index) {
                          final debt = _archivedDebts[index];
                          return Container(
                            margin: EdgeInsets.symmetric(vertical: 4),
                            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                            decoration: BoxDecoration(
                              color: isDark ? colors.surfaceSunken : colors.surfaceSunken,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: colors.border.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              children: [
                                Icon(CupertinoIcons.checkmark_seal_fill, color: colors.success, size: 18),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    debt.title,
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: 13.5,
                                      decoration: TextDecoration.lineThrough,
                                      ),
                                  ),
                                ),
                                // Restore Button
                                InkWell(
                                  onTap: () => _restoreDebt(debt),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: colors.success.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(CupertinoIcons.arrow_counterclockwise, size: 12, color: colors.success),
                                        SizedBox(width: 4),
                                        Text('بازگردانی', style: TextStyle(fontSize: 11, color: colors.success, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                // Delete Permanently
                                InkWell(
                                  onTap: () => _deleteDebt(debt),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(CupertinoIcons.trash, size: 15, color: colors.textSecondary.withValues(alpha: 0.6)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// ADD DEBT SHEET (With Presets & Emerald Luxury Theme)
// -----------------------------------------------------------------------------
class _AddDebtSheet extends StatefulWidget {
  const _AddDebtSheet({required this.onSaved});
  final VoidCallback onSaved;

  @override
  State<_AddDebtSheet> createState() => _AddDebtSheetState();
}

class _AddDebtSheetState extends State<_AddDebtSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _countController = TextEditingController();
  final TextEditingController _targetController = TextEditingController(text: '1');
  String _debtType = 'PRAYER'; // PRAYER, FAST, ATONEMENT

  final List<String> _prayerPresets = [
    'نماز صبح',
    'نماز ظهر و عصر',
    'نماز مغرب و عشا',
    'یک شبانه‌روز کامل (۱۷ رکعت)',
    'نماز آیات',
  ];

  final List<String> _fastPresets = const [
    'روزه ماه رمضان',
    'روزه نذر',
    'روزه اعتکاف',
  ];

  final List<String> _atonementPresets = const [
    'کفاره عمد روزه (۶۰ روز)',
    'فدیه / کفاره عذر',
    'کفاره شکستن عهد یا قسم',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _countController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final colors = context.colors;
    final title = _titleController.text.trim();
    final count = int.tryParse(_countController.text) ?? 0;
    final target = int.tryParse(_targetController.text) ?? 1;

    if (title.isEmpty || count <= 0) {
      RitmoToast.show(
        context,
        'لطفاً عنوان و تعداد کل معتبر وارد کنید',
        icon: Icons.info_outline_rounded,
        iconColor: colors.warning,
      );
      return;
    }

    unawaited(HapticFeedback.mediumImpact());
    try {
      final db = await DatabaseHelper.instance.database;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final id = 'debt_custom_$nowMs';

      await db.insert(
        'worship_debts',
        {
          'id': id,
          'debtType': _debtType,
          'title': title,
          'totalCount': count,
          'remainingCount': count,
          'dailyTarget': target.clamp(1, 100),
          'autoCreated': 0,
          'isArchived': 0,
          'createdAt': nowMs,
          'updatedAt': nowMs,
        },
      );

      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        RitmoToast.show(
          context,
          'بدهی "$title" با موفقیت ثبت شد',
          icon: Icons.check_circle_rounded,
          iconColor: colors.success,
        );
      }
    } catch (e) {
      debugPrint('Error saving custom debt: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final presets = _debtType == 'PRAYER'
        ? _prayerPresets
        : (_debtType == 'FAST' ? _fastPresets : _atonementPresets);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: colors.border,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.balance_rounded, size: 20, color: colors.primary),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'ثبت بدهی (قضای) جدید',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                        ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(CupertinoIcons.xmark_circle_fill, color: colors.textSecondary.withValues(alpha: 0.5), size: 24),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Debt Type Picker
            Row(
              children: [
                _buildTypeOption('PRAYER', 'نماز قضا', '📿'),
                const SizedBox(width: 8),
                _buildTypeOption('FAST', 'روزه قضا', '🌙'),
                const SizedBox(width: 8),
                _buildTypeOption('ATONEMENT', 'کفاره / سایر', '⚖️'),
              ],
            ),
            const SizedBox(height: 14),

            // Presets Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: presets.map((p) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: InkWell(
                      onTap: () {
                        unawaited(HapticFeedback.selectionClick());
                        setState(() {
                          _titleController.text = p;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          p,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            // Title Field
            TextField(
              controller: _titleController,
              style: TextStyle(color: colors.textPrimary, fontSize: 14.5, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'عنوان بدهی (مثلاً: نماز قضای صبح)',
                hintStyle: TextStyle(color: colors.textSecondary.withValues(alpha: 0.5), fontSize: 13.5),
                fillColor: colors.surfaceSunken,
                filled: true,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: colors.border.withValues(alpha: 0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: colors.primary, width: 1.8),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Total count & Target Count Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _countController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: colors.textPrimary, fontSize: 14.5, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: 'تعداد کل قضاها',
                      hintStyle: TextStyle(color: colors.textSecondary.withValues(alpha: 0.5), fontSize: 13),
                      fillColor: colors.surfaceSunken,
                      filled: true,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: colors.border.withValues(alpha: 0.5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: colors.primary, width: 1.8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _targetController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: colors.textPrimary, fontSize: 14.5, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: 'هدف انجام در روز',
                      hintStyle: TextStyle(color: colors.textSecondary.withValues(alpha: 0.5), fontSize: 13),
                      fillColor: colors.surfaceSunken,
                      filled: true,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: colors.border.withValues(alpha: 0.5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: colors.primary, width: 1.8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              onPressed: _save,
              child: Text('ثبت بدهی جدید', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.onPrimary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeOption(String value, String label, String emoji) {
    final colors = context.colors;
    final isSelected = _debtType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          unawaited(HapticFeedback.selectionClick());
          setState(() {
            _debtType = value;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? colors.primary.withValues(alpha: 0.15)
                : colors.surfaceSunken,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? colors.primary : colors.border.withValues(alpha: 0.4),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  color: isSelected
                      ? colors.primary
                      : colors.textSecondary,
                  ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// EDIT DEBT SHEET
// -----------------------------------------------------------------------------
class _EditDebtSheet extends StatefulWidget {
  const _EditDebtSheet({
    required this.debt,
    required this.onSaved,
    required this.onDeleted,
  });

  final WorshipDebt debt;
  final VoidCallback onSaved;
  final VoidCallback onDeleted;

  @override
  State<_EditDebtSheet> createState() => _EditDebtSheetState();
}

class _EditDebtSheetState extends State<_EditDebtSheet> {
  late TextEditingController _titleController;
  late TextEditingController _totalController;
  late TextEditingController _remainingController;
  late TextEditingController _targetController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.debt.title);
    _totalController = TextEditingController(text: widget.debt.totalCount.toString());
    _remainingController = TextEditingController(text: widget.debt.remainingCount.toString());
    _targetController = TextEditingController(text: widget.debt.dailyTarget.toString());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _totalController.dispose();
    _remainingController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _update() async {
    final colors = context.colors;
    final title = _titleController.text.trim();
    final total = int.tryParse(_totalController.text) ?? widget.debt.totalCount;
    final remaining = int.tryParse(_remainingController.text) ?? widget.debt.remainingCount;
    final target = int.tryParse(_targetController.text) ?? widget.debt.dailyTarget;

    if (title.isEmpty || total <= 0) return;

    unawaited(HapticFeedback.mediumImpact());
    try {
      final db = await DatabaseHelper.instance.database;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final isArchived = remaining <= 0;

      await db.update(
        'worship_debts',
        {
          'title': title,
          'totalCount': total,
          'remainingCount': remaining.clamp(0, total),
          'dailyTarget': target.clamp(1, 100),
          'isArchived': isArchived ? 1 : 0,
          'updatedAt': nowMs,
        },
        where: 'id = ?',
        whereArgs: [widget.debt.id],
      );

      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        RitmoToast.show(
          context,
          'تغییرات "$title" با موفقیت ذخیره شد',
          icon: Icons.check_circle_rounded,
          iconColor: colors.success,
        );
      }
    } catch (e) {
      debugPrint('Error updating debt: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: colors.border,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ویرایش و مدیریت بدهی',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                    ),
                ),
                IconButton(
                  icon: Icon(CupertinoIcons.xmark_circle_fill, color: colors.textSecondary.withValues(alpha: 0.5), size: 24),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Title
            TextField(
              controller: _titleController,
              style: TextStyle(color: colors.textPrimary, fontSize: 14.5, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                labelText: 'عنوان',
                labelStyle: TextStyle(color: colors.textSecondary),
                fillColor: colors.surfaceSunken,
                filled: true,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: colors.border.withValues(alpha: 0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: colors.primary, width: 1.8),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Total & Remaining
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _totalController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: colors.textPrimary, fontSize: 14.5, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'تعداد کل',
                      labelStyle: TextStyle(color: colors.textSecondary),
                      fillColor: colors.surfaceSunken,
                      filled: true,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: colors.border.withValues(alpha: 0.5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: colors.primary, width: 1.8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _remainingController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: colors.textPrimary, fontSize: 14.5, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'باقیمانده',
                      labelStyle: TextStyle(color: colors.textSecondary),
                      fillColor: colors.surfaceSunken,
                      filled: true,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: colors.border.withValues(alpha: 0.5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: colors.primary, width: 1.8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Daily Target
            TextField(
              controller: _targetController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: colors.textPrimary, fontSize: 14.5, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'هدف روزانه',
                labelStyle: TextStyle(color: colors.textSecondary),
                fillColor: colors.surfaceSunken,
                filled: true,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: colors.border.withValues(alpha: 0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: colors.primary, width: 1.8),
                ),
              ),
            ),
            const SizedBox(height: 22),

            Row(
              children: [
                // Delete Button
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    widget.onDeleted();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.error.withValues(alpha: 0.3)),
                    ),
                    child: Icon(CupertinoIcons.trash, color: colors.error, size: 20),
                  ),
                ),
                const SizedBox(width: 12),

                // Save Button
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: _update,
                    child: Text('ذخیره تغییرات', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colors.onPrimary)),
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
