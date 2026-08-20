import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/util/ritmo_number.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_date_picker.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/pregnancy_engine.dart';
import 'package:ritmo/features/cycle/logic/pregnancy_settings.dart';
import 'package:ritmo/features/cycle/models/pregnancy_models.dart';
import 'package:ritmo/features/cycle/presentation/widgets/cycle_animated_background.dart';

class PregnancySettingsSheet extends StatefulWidget {
  const PregnancySettingsSheet({
    super.key,
    this.onDataReloadNeeded,
    this.onEndPregnancy,
    this.initialProfile,
  });

  final VoidCallback? onDataReloadNeeded;
  final VoidCallback? onEndPregnancy;
  final PregnancyProfile? initialProfile;

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onDataReloadNeeded,
    VoidCallback? onEndPregnancy,
    PregnancyProfile? initialProfile,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RitmoSheetGlassCard(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            top: 16,
          ),
          child: PregnancySettingsSheet(
            onDataReloadNeeded: onDataReloadNeeded,
            onEndPregnancy: onEndPregnancy,
            initialProfile: initialProfile,
          ),
        ),
      ),
    );
  }

  @override
  State<PregnancySettingsSheet> createState() => _PregnancySettingsSheetState();
}

class _PregnancySettingsSheetState extends State<PregnancySettingsSheet> {
  late PregnancyProfile _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialProfile != null) {
      _profile = widget.initialProfile!;
      _isLoading = false;
    } else {
      _profile = PregnancyProfile.fromMap(const {});
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('app_settings');
      final map = <String, dynamic>{};
      for (final r in rows) {
        map[r['key'] as String] = r['value'];
      }
      if (mounted) {
        setState(() {
          _profile = PregnancySettings.loadProfile(map);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatJalaliDate(DateTime dt) {
    final j = Jalali.fromDateTime(dt);
    final dayStr = RitmoNumber.fa(j.day.toString());
    final yearStr = RitmoNumber.fa(j.year.toString());
    return '$dayStr ${_monthNameFa(j.month)} $yearStr';
  }

  String _monthNameFa(int m) {
    const months = [
      'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
      'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'
    ];
    if (m >= 1 && m <= 12) return months[m - 1];
    return '';
  }

  String _formatEddSourceLabel(PregnancyEddSource source) {
    switch (source) {
      case PregnancyEddSource.lmp:
        return 'اولین روز آخرین پریود (LMP)';
      case PregnancyEddSource.doctorEdd:
        return 'تاریخ اعلامی پزشک';
      case PregnancyEddSource.ultrasound:
        return 'سونوگرافی';
    }
  }

  Future<void> _handleDateChange({
    required DateTime newLmp,
    required DateTime newDue,
    required PregnancyEddSource newSource,
  }) async {
    final shift = PregnancyDateEngine.dayShiftBetween(_profile.lmpDate, newLmp);
    if (shift != 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('تغییر تاریخ زایمان'),
          content: Text(
            'با این تغییر، سن بارداری و تمام یادآوری‌های بعدی ${PersianDigits.toFa(shift.abs().toString())} روز جابه‌جا می‌شوند. داده‌های ثبت‌شدهٔ گذشته حذف نمی‌شوند.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('انصراف'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('تأیید و به‌روزرسانی'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    final updated = _profile.copyWith(
      lmpDate: newLmp,
      dueDate: newDue,
      eddSource: newSource,
    );

    await PregnancySettings.saveProfile(updated);
    if (mounted) {
      setState(() => _profile = updated);
    }
    widget.onDataReloadNeeded?.call();
  }

  Future<void> _openEddEditDialog() async {
    final colors = context.colors;
    final now = CycleClock.now;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => RitmoSheetGlassCard(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
            top: 16,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colors.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'ویرایش تاریخ بارداری',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: Icon(CupertinoIcons.calendar_today, color: colors.primary),
                  title: const Text('بر اساس تاریخ آخرین پریود (LMP)'),
                  onTap: () async {
                    Navigator.of(sheetCtx).pop();
                    final picked = await RitmoDatePicker.show(
                      context: context,
                      initialDate: _profile.lmpDate,
                      firstDate: now.subtract(const Duration(days: 300)),
                      lastDate: now,
                    );
                    if (picked != null) {
                      final cleanLmp = CycleDateContract.cleanDate(picked);
                      final cleanDue = PregnancyDateEngine.calculateEddFromLmp(cleanLmp);
                      await _handleDateChange(
                        newLmp: cleanLmp,
                        newDue: cleanDue,
                        newSource: PregnancyEddSource.lmp,
                      );
                    }
                  },
                ),
              ),
              Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: Icon(CupertinoIcons.person_crop_circle_badge_checkmark, color: colors.primary),
                  title: const Text('بر اساس تاریخ اعلامی پزشک (EDD)'),
                  onTap: () async {
                    Navigator.of(sheetCtx).pop();
                    final picked = await RitmoDatePicker.show(
                      context: context,
                      initialDate: _profile.dueDate,
                      firstDate: now,
                      lastDate: now.add(const Duration(days: 300)),
                    );
                    if (picked != null) {
                      final cleanDue = CycleDateContract.cleanDate(picked);
                      final cleanLmp = PregnancyDateEngine.calculateLmpFromEdd(cleanDue);
                      await _handleDateChange(
                        newLmp: cleanLmp,
                        newDue: cleanDue,
                        newSource: PregnancyEddSource.doctorEdd,
                      );
                    }
                  },
                ),
              ),
              Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: Icon(CupertinoIcons.waveform_path_ecg, color: colors.primary),
                  title: const Text('بر اساس جواب سونوگرافی'),
                  onTap: () async {
                    Navigator.of(sheetCtx).pop();
                    final picked = await RitmoDatePicker.show(
                      context: context,
                      initialDate: now,
                      firstDate: now.subtract(const Duration(days: 300)),
                      lastDate: now,
                    );
                    if (picked != null) {
                      final cleanLmp = CycleDateContract.cleanDate(picked.subtract(const Duration(days: 70)));
                      final cleanDue = PregnancyDateEngine.calculateEddFromLmp(cleanLmp);
                      await _handleDateChange(
                        newLmp: cleanLmp,
                        newDue: cleanDue,
                        newSource: PregnancyEddSource.ultrasound,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: colors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildReadonlyRow(
    BuildContext context, {
    required String title,
    required String value,
  }) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 14, color: colors.textPrimary),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParameterRow(
    BuildContext context, {
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 14, color: colors.textPrimary),
              ),
            ),
            Row(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(CupertinoIcons.pencil, color: colors.primary, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CupertinoActivityIndicator(),
        ),
      );
    }

    final age = PregnancyDateEngine.calculateCurrentGestation(
      lmp: _profile.lmpDate,
      now: CycleClock.now,
    );
    final formattedAge = PregnancyDateEngine.formatGestationalAgeFa(
      age,
      unit: _profile.ageUnit,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: colors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'تنظیمات بارداری',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(CupertinoIcons.xmark_circle_fill),
                color: colors.textSecondary.withValues(alpha: 0.6),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: colors.border),
          const SizedBox(height: 12),

          // Section 1: تاریخ و سن بارداری
          _buildSectionHeader(context, 'تاریخ و سن بارداری'),
          _buildReadonlyRow(
            context,
            title: 'سن بارداری امروز',
            value: formattedAge,
          ),
          _buildParameterRow(
            context,
            title: 'تاریخ تقریبی زایمان',
            value: _formatJalaliDate(_profile.dueDate),
            onTap: _openEddEditDialog,
          ),
          _buildReadonlyRow(
            context,
            title: 'مبنای محاسبه',
            value: _formatEddSourceLabel(_profile.eddSource),
          ),
          const SizedBox(height: 8),
          Divider(height: 16, color: colors.border),

          // Section 2: لحن و نمایش
          _buildSectionHeader(context, 'لحن و نمایش'),
          const SizedBox(height: 8),
          Divider(height: 16, color: colors.border),

          // Section 3: مراقبت‌ها و یادآوری‌ها
          _buildSectionHeader(context, 'مراقبت‌ها و یادآوری‌ها'),
          const SizedBox(height: 8),
          Divider(height: 16, color: colors.border),

          // Section 4: لگدشماری
          _buildSectionHeader(context, 'لگدشماری'),
          const SizedBox(height: 8),
          Divider(height: 16, color: colors.border),

          // Section 5: حریم خصوصی
          _buildSectionHeader(context, 'حریم خصوصی'),
          const SizedBox(height: 8),
          Divider(height: 16, color: colors.border),

          // Section 6: ناحیهٔ خطر
          _buildSectionHeader(context, 'ناحیهٔ خطر'),
          if (widget.onEndPregnancy != null) ...[
            const SizedBox(height: 4),
            InkWell(
              onTap: () {
                Navigator.of(context).pop();
                widget.onEndPregnancy!();
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.exclamationmark_triangle_fill,
                          color: colors.error,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'پایان دوره بارداری و بازگشت به چرخه',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: colors.error,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      CupertinoIcons.chevron_left,
                      color: colors.error,
                      size: 14,
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
