import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/util/ritmo_number.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_date_picker.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_button.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/logic/pregnancy_engine.dart';
import 'package:ritmo/features/cycle/logic/pregnancy_settings.dart';
import 'package:ritmo/features/cycle/models/pregnancy_models.dart';

class PregnancySettingsSheet extends StatefulWidget {
  const PregnancySettingsSheet({
    super.key,
    this.onDataReloadNeeded,
    this.onEndPregnancy,
    this.onExitPregnancy,
    this.onOpenGeneralSettings,
    this.initialProfile,
  });

  final VoidCallback? onDataReloadNeeded;
  final VoidCallback? onEndPregnancy;
  final VoidCallback? onExitPregnancy;
  final VoidCallback? onOpenGeneralSettings;
  final PregnancyProfile? initialProfile;

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onDataReloadNeeded,
    VoidCallback? onEndPregnancy,
    VoidCallback? onExitPregnancy,
    VoidCallback? onOpenGeneralSettings,
    PregnancyProfile? initialProfile,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.60,
        minChildSize: 0.40,
        maxChildSize: 0.94,
        snap: true,
        snapSizes: const [0.60, 0.94],
        expand: false,
        builder: (context, scrollController) => RitmoGlassSheet(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            top: 12,
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: PregnancySettingsSheet(
              onDataReloadNeeded: onDataReloadNeeded,
              onEndPregnancy: onEndPregnancy,
              onExitPregnancy: onExitPregnancy,
              onOpenGeneralSettings: onOpenGeneralSettings,
              initialProfile: initialProfile,
            ),
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
      'فروردین',
      'اردیبهشت',
      'خرداد',
      'تیر',
      'مرداد',
      'شهریور',
      'مهر',
      'آبان',
      'آذر',
      'دی',
      'بهمن',
      'اسفند',
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
      final confirmed = await RitmoDialog.show(
        context,
        title: 'تغییر تاریخ زایمان',
        content:
            'با این تغییر، سن بارداری و تمام یادآوری‌های بعدی ${PersianDigits.toFa(shift.abs().toString())} روز جابه‌جا می‌شوند. داده‌های ثبت‌شدهٔ گذشته حذف نمی‌شوند.',
        confirmLabel: 'تأیید و به‌روزرسانی',
        cancelLabel: 'انصراف',
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
      builder: (sheetCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: RitmoGlassSheet(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
                const SizedBox(height: 14),
                Text(
                  'ویرایش تاریخ بارداری',
                  style: RitmoTextStyles.cardTitle(colors.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                RitmoCard.neumorphic(
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
                      final cleanDue = PregnancyDateEngine.calculateEddFromLmp(
                        cleanLmp,
                      );
                      await _handleDateChange(
                        newLmp: cleanLmp,
                        newDue: cleanDue,
                        newSource: PregnancyEddSource.lmp,
                      );
                    }
                  },
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(CupertinoIcons.calendar_today, color: colors.primary, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'بر اساس تاریخ آخرین پریود (LMP)',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      Icon(CupertinoIcons.chevron_left, color: colors.textSecondary, size: 14),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                RitmoCard.neumorphic(
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
                      final cleanLmp = PregnancyDateEngine.calculateLmpFromEdd(
                        cleanDue,
                      );
                      await _handleDateChange(
                        newLmp: cleanLmp,
                        newDue: cleanDue,
                        newSource: PregnancyEddSource.doctorEdd,
                      );
                    }
                  },
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(CupertinoIcons.person_crop_circle_badge_checkmark, color: colors.primary, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'بر اساس تاریخ اعلامی پزشک (EDD)',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      Icon(CupertinoIcons.chevron_left, color: colors.textSecondary, size: 14),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                RitmoCard.neumorphic(
                  onTap: () async {
                    Navigator.of(sheetCtx).pop();
                    final picked = await RitmoDatePicker.show(
                      context: context,
                      initialDate: now,
                      firstDate: now.subtract(const Duration(days: 300)),
                      lastDate: now,
                    );
                    if (picked != null) {
                      final cleanLmp = CycleDateContract.cleanDate(
                        picked.subtract(const Duration(days: 70)),
                      );
                      final cleanDue = PregnancyDateEngine.calculateEddFromLmp(
                        cleanLmp,
                      );
                      await _handleDateChange(
                        newLmp: cleanLmp,
                        newDue: cleanDue,
                        newSource: PregnancyEddSource.ultrasound,
                      );
                    }
                  },
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(CupertinoIcons.waveform_path_ecg, color: colors.primary, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'بر اساس جواب سونوگرافی',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      Icon(CupertinoIcons.chevron_left, color: colors.textSecondary, size: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openTonePicker() async {
    final colors = context.colors;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: RitmoGlassSheet(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
                const SizedBox(height: 14),
                Text(
                  'انتخاب لحن همراهی',
                  style: RitmoTextStyles.cardTitle(colors.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                RitmoCard.neumorphic(
                  isSelected: _profile.tone == PregnancyTone.warm,
                  onTap: () async {
                    Navigator.of(sheetCtx).pop();
                    final updated = _profile.copyWith(tone: PregnancyTone.warm);
                    await PregnancySettings.saveProfile(updated);
                    if (mounted) setState(() => _profile = updated);
                    widget.onDataReloadNeeded?.call();
                  },
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.heart_fill,
                        color: _profile.tone == PregnancyTone.warm ? colors.primary : colors.textSecondary,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'گرما و صمیمانه',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'با عبارات دلگرم‌کننده و پیام‌های محبت‌آمیز',
                              style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      if (_profile.tone == PregnancyTone.warm)
                        Icon(CupertinoIcons.checkmark_alt, color: colors.primary, size: 18),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                RitmoCard.neumorphic(
                  isSelected: _profile.tone == PregnancyTone.neutral,
                  onTap: () async {
                    Navigator.of(sheetCtx).pop();
                    final updated = _profile.copyWith(tone: PregnancyTone.neutral);
                    await PregnancySettings.saveProfile(updated);
                    if (mounted) setState(() => _profile = updated);
                    widget.onDataReloadNeeded?.call();
                  },
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.doc_text_fill,
                        color: _profile.tone == PregnancyTone.neutral ? colors.primary : colors.textSecondary,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'آرام و علمی',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'اطلاعات دقیق، مختصر و بدون اغراق',
                              style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      if (_profile.tone == PregnancyTone.neutral)
                        Icon(CupertinoIcons.checkmark_alt, color: colors.primary, size: 18),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openAgeUnitPicker() async {
    final colors = context.colors;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: RitmoGlassSheet(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
                const SizedBox(height: 14),
                Text(
                  'واحد نمایش سن بارداری',
                  style: RitmoTextStyles.cardTitle(colors.textPrimary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                RitmoCard.neumorphic(
                  isSelected: _profile.ageUnit == PregnancyAgeUnit.weeks,
                  onTap: () async {
                    Navigator.of(sheetCtx).pop();
                    final updated = _profile.copyWith(
                      ageUnit: PregnancyAgeUnit.weeks,
                    );
                    await PregnancySettings.saveProfile(updated);
                    if (mounted) setState(() => _profile = updated);
                    widget.onDataReloadNeeded?.call();
                  },
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.calendar,
                        color: _profile.ageUnit == PregnancyAgeUnit.weeks ? colors.primary : colors.textSecondary,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'هفته و روز',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'مثال: هفتهٔ ۲۴ و ۳ روز',
                              style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      if (_profile.ageUnit == PregnancyAgeUnit.weeks)
                        Icon(CupertinoIcons.checkmark_alt, color: colors.primary, size: 18),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                RitmoCard.neumorphic(
                  isSelected: _profile.ageUnit == PregnancyAgeUnit.months,
                  onTap: () async {
                    Navigator.of(sheetCtx).pop();
                    final updated = _profile.copyWith(
                      ageUnit: PregnancyAgeUnit.months,
                    );
                    await PregnancySettings.saveProfile(updated);
                    if (mounted) setState(() => _profile = updated);
                    widget.onDataReloadNeeded?.call();
                  },
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.calendar_badge_plus,
                        color: _profile.ageUnit == PregnancyAgeUnit.months ? colors.primary : colors.textSecondary,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ماه و هفته',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'مثال: ماه ۶، هفتهٔ ۲',
                              style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      if (_profile.ageUnit == PregnancyAgeUnit.months)
                        Icon(CupertinoIcons.checkmark_alt, color: colors.primary, size: 18),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openLeadDaysPicker() async {
    final colors = context.colors;
    int selected = _profile.visitReminderLeadDays;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
            ),
            child: RitmoGlassSheet(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
                  const SizedBox(height: 14),
                  Text(
                    'فاصلهٔ یادآوری ویزیت مامایی',
                    style: RitmoTextStyles.cardTitle(colors.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      RitmoNeuButton(
                        padding: const EdgeInsets.all(10),
                        radius: 20,
                        onTap: () {
                          if (selected > 1) {
                            setModalState(() => selected--);
                          }
                        },
                        child: Icon(
                          CupertinoIcons.minus,
                          size: 20,
                          color: selected > 1 ? colors.primary : colors.textSecondary.withValues(alpha: 0.3),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Text(
                        '${RitmoNumber.faInt(selected)} روز قبل',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(width: 24),
                      RitmoNeuButton(
                        padding: const EdgeInsets.all(10),
                        radius: 20,
                        onTap: () {
                          if (selected < 7) {
                            setModalState(() => selected++);
                          }
                        },
                        child: Icon(
                          CupertinoIcons.plus,
                          size: 20,
                          color: selected < 7 ? colors.primary : colors.textSecondary.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  RitmoPrimaryButton(
                    label: 'تأیید و ذخیره',
                    onPressed: () async {
                      Navigator.of(sheetCtx).pop();
                      final updated = _profile.copyWith(
                        visitReminderLeadDays: selected,
                      );
                      await PregnancySettings.saveProfile(updated);
                      if (mounted) setState(() => _profile = updated);
                      widget.onDataReloadNeeded?.call();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openReminderHourPicker() async {
    final colors = context.colors;
    int selected = _profile.reminderHour;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
            ),
            child: RitmoGlassSheet(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
                  const SizedBox(height: 14),
                  Text(
                    'ساعت ارسال یادآوری‌های بارداری',
                    style: RitmoTextStyles.cardTitle(colors.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      RitmoNeuButton(
                        padding: const EdgeInsets.all(10),
                        radius: 20,
                        onTap: () {
                          if (selected > 6) {
                            setModalState(() => selected--);
                          }
                        },
                        child: Icon(
                          CupertinoIcons.minus,
                          size: 20,
                          color: selected > 6 ? colors.primary : colors.textSecondary.withValues(alpha: 0.3),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Text(
                        'ساعت ${RitmoNumber.faInt(selected)}:۰۰',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(width: 24),
                      RitmoNeuButton(
                        padding: const EdgeInsets.all(10),
                        radius: 20,
                        onTap: () {
                          if (selected < 22) {
                            setModalState(() => selected++);
                          }
                        },
                        child: Icon(
                          CupertinoIcons.plus,
                          size: 20,
                          color: selected < 22 ? colors.primary : colors.textSecondary.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  RitmoPrimaryButton(
                    label: 'تأیید و ذخیره',
                    onPressed: () async {
                      Navigator.of(sheetCtx).pop();
                      final updated = _profile.copyWith(reminderHour: selected);
                      await PregnancySettings.saveProfile(updated);
                      if (mounted) setState(() => _profile = updated);
                      widget.onDataReloadNeeded?.call();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openKickTargetPicker() async {
    final colors = context.colors;
    int selected = _profile.kickTargetCount;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
            ),
            child: RitmoGlassSheet(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
                  const SizedBox(height: 14),
                  Text(
                    'تعداد هدف لگد',
                    style: RitmoTextStyles.cardTitle(colors.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      RitmoNeuButton(
                        padding: const EdgeInsets.all(10),
                        radius: 20,
                        onTap: () {
                          if (selected > 5) {
                            setModalState(() => selected--);
                          }
                        },
                        child: Icon(
                          CupertinoIcons.minus,
                          size: 20,
                          color: selected > 5 ? colors.primary : colors.textSecondary.withValues(alpha: 0.3),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Text(
                        '${RitmoNumber.faInt(selected)} حرکت',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(width: 24),
                      RitmoNeuButton(
                        padding: const EdgeInsets.all(10),
                        radius: 20,
                        onTap: () {
                          if (selected < 20) {
                            setModalState(() => selected++);
                          }
                        },
                        child: Icon(
                          CupertinoIcons.plus,
                          size: 20,
                          color: selected < 20 ? colors.primary : colors.textSecondary.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  RitmoPrimaryButton(
                    label: 'تأیید و ذخیره',
                    onPressed: () async {
                      Navigator.of(sheetCtx).pop();
                      final updated = _profile.copyWith(
                        kickTargetCount: selected,
                      );
                      await PregnancySettings.saveProfile(updated);
                      if (mounted) setState(() => _profile = updated);
                      widget.onDataReloadNeeded?.call();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openKickWindowPicker() async {
    final colors = context.colors;
    int selected = _profile.kickWindowMinutes;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setModalState) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
            ),
            child: RitmoGlassSheet(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
                  const SizedBox(height: 14),
                  Text(
                    'مدت پنجرهٔ شمارش لگد',
                    style: RitmoTextStyles.cardTitle(colors.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      RitmoNeuButton(
                        padding: const EdgeInsets.all(10),
                        radius: 20,
                        onTap: () {
                          if (selected > 30) {
                            setModalState(
                              () => selected = (selected - 15).clamp(30, 300),
                            );
                          }
                        },
                        child: Icon(
                          CupertinoIcons.minus,
                          size: 20,
                          color: selected > 30 ? colors.primary : colors.textSecondary.withValues(alpha: 0.3),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Text(
                        '${RitmoNumber.faInt(selected)} دقیقه',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(width: 24),
                      RitmoNeuButton(
                        padding: const EdgeInsets.all(10),
                        radius: 20,
                        onTap: () {
                          if (selected < 300) {
                            setModalState(
                              () => selected = (selected + 15).clamp(30, 300),
                            );
                          }
                        },
                        child: Icon(
                          CupertinoIcons.plus,
                          size: 20,
                          color: selected < 300 ? colors.primary : colors.textSecondary.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  RitmoPrimaryButton(
                    label: 'تأیید و ذخیره',
                    onPressed: () async {
                      Navigator.of(sheetCtx).pop();
                      final updated = _profile.copyWith(
                        kickWindowMinutes: selected,
                      );
                      await PregnancySettings.saveProfile(updated);
                      if (mounted) setState(() => _profile = updated);
                      widget.onDataReloadNeeded?.call();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleRow(
    BuildContext context, {
    required String title,
    String? subtitle,
    required bool value,
    ValueChanged<bool>? onChanged,
  }) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: onChanged != null
                        ? colors.textPrimary
                        : colors.textSecondary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: colors.textSecondary.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            activeTrackColor: colors.primary,
            onChanged: onChanged,
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
          _buildParameterRow(
            context,
            title: 'لحن همراهی و متن‌ها',
            value: _profile.tone == PregnancyTone.warm
                ? 'گرما و صمیمانه'
                : 'آرام و علمی',
            onTap: _openTonePicker,
          ),
          _buildToggleRow(
            context,
            title: 'نمایش شمارش معکوس تا زایمان',
            value: _profile.showCountdown,
            onChanged: (val) async {
              final updated = _profile.copyWith(showCountdown: val);
              await PregnancySettings.saveProfile(updated);
              if (mounted) setState(() => _profile = updated);
              widget.onDataReloadNeeded?.call();
            },
          ),
          _buildParameterRow(
            context,
            title: 'واحد نمایش سن بارداری',
            value: _profile.ageUnit == PregnancyAgeUnit.weeks
                ? 'هفته و روز'
                : 'ماه و هفته',
            onTap: _openAgeUnitPicker,
          ),
          const SizedBox(height: 8),
          Divider(height: 16, color: colors.border),

          // Section 3: مراقبت‌ها و یادآوری‌ها
          _buildSectionHeader(context, 'مراقبت‌ها و یادآوری‌ها'),
          _buildParameterRow(
            context,
            title: 'یادآوری ویزیت مامایی',
            value:
                '${PersianDigits.toFa(_profile.visitReminderLeadDays.toString())} روز قبل',
            onTap: _openLeadDaysPicker,
          ),
          _buildParameterRow(
            context,
            title: 'ساعت یادآوری‌های بارداری',
            value:
                'ساعت ${PersianDigits.toFa(_profile.reminderHour.toString())}:۰۰',
            onTap: _openReminderHourPicker,
          ),
          _buildToggleRow(
            context,
            title: 'یادآوری مکمل‌ها و ویتامین‌ها',
            value: _profile.supplementReminder,
            onChanged: (val) async {
              final updated = _profile.copyWith(supplementReminder: val);
              await PregnancySettings.saveProfile(updated);
              if (mounted) setState(() => _profile = updated);
              widget.onDataReloadNeeded?.call();
            },
          ),
          _buildToggleRow(
            context,
            title: 'یادآوری لگدشماری از هفتهٔ ۲۸',
            subtitle: age.weeks < 28 ? 'از هفتهٔ ۲۸ به بعد فعال می‌شود.' : null,
            value: age.weeks >= 28 ? _profile.kickReminder : false,
            onChanged: age.weeks >= 28
                ? (val) async {
                    final updated = _profile.copyWith(kickReminder: val);
                    await PregnancySettings.saveProfile(updated);
                    if (mounted) setState(() => _profile = updated);
                    widget.onDataReloadNeeded?.call();
                  }
                : null,
          ),
          const SizedBox(height: 8),
          Divider(height: 16, color: colors.border),

          // Section 4: لگدشماری
          _buildSectionHeader(context, 'لگدشماری'),
          _buildParameterRow(
            context,
            title: 'تعداد هدف لگد',
            value:
                '${PersianDigits.toFa(_profile.kickTargetCount.toString())} حرکت',
            onTap: _openKickTargetPicker,
          ),
          _buildParameterRow(
            context,
            title: 'مدت پنجرهٔ شمارش',
            value:
                '${PersianDigits.toFa(_profile.kickWindowMinutes.toString())} دقیقه',
            onTap: _openKickWindowPicker,
          ),
          _buildToggleRow(
            context,
            title: 'مقایسه با الگوی شخصی خودم',
            value: _profile.kickBaselineComparison,
            onChanged: (val) async {
              final updated = _profile.copyWith(kickBaselineComparison: val);
              await PregnancySettings.saveProfile(updated);
              if (mounted) setState(() => _profile = updated);
              widget.onDataReloadNeeded?.call();
            },
          ),
          const SizedBox(height: 8),
          Divider(height: 16, color: colors.border),

          // Section 5: حریم خصوصی
          _buildSectionHeader(context, 'حریم خصوصی'),
          _buildToggleRow(
            context,
            title: 'پوشش اعلان‌ها (پیام محرمانه)',
            subtitle: 'متن اعلان‌ها بدون اشاره به بارداری نمایش داده می‌شود.',
            value: _profile.maskNotifications,
            onChanged: (val) async {
              final updated = _profile.copyWith(maskNotifications: val);
              await PregnancySettings.saveProfile(updated);
              if (mounted) setState(() => _profile = updated);
              widget.onDataReloadNeeded?.call();
            },
          ),
          _buildToggleRow(
            context,
            title: 'قفل اختصاصی بخش بارداری',
            subtitle: 'ورود به این بخش نیازمند تأیید هویت خواهد بود.',
            value: _profile.lockEnabled,
            onChanged: (val) async {
              final updated = _profile.copyWith(lockEnabled: val);
              await PregnancySettings.saveProfile(updated);
              if (mounted) setState(() => _profile = updated);
              widget.onDataReloadNeeded?.call();
            },
          ),
          _buildToggleRow(
            context,
            title: 'پنهان‌سازی بخش بارداری',
            subtitle: 'بخش بارداری از صفحهٔ اصلی چرخه موقتاً پنهان می‌شود.',
            value: _profile.sectionHidden,
            onChanged: (val) async {
              final updated = _profile.copyWith(sectionHidden: val);
              await PregnancySettings.saveProfile(updated);
              if (mounted) setState(() => _profile = updated);
              widget.onDataReloadNeeded?.call();
            },
          ),
          const SizedBox(height: 8),
          Divider(height: 16, color: colors.border),

          // Section 6: ناحیهٔ خطر
          _buildSectionHeader(context, 'ناحیهٔ خطر'),
          const SizedBox(height: 4),
          InkWell(
            onTap: _confirmExitPregnancy,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.arrow_right_circle,
                        color: colors.warning,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'خروج از حالت بارداری',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colors.warning,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    CupertinoIcons.chevron_left,
                    color: colors.warning,
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
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
                          'پایان دوره بارداری',
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
          if (widget.onOpenGeneralSettings != null) ...[
            const SizedBox(height: 4),
            InkWell(
              onTap: () {
                Navigator.of(context).pop();
                widget.onOpenGeneralSettings!();
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
                          CupertinoIcons.settings,
                          color: colors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'تنظیمات عمومی چرخه',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      CupertinoIcons.chevron_left,
                      color: colors.primary,
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

  Future<void> _confirmExitPregnancy() async {
    final confirmed = await RitmoDialog.show(
      context,
      title: 'خروج از حالت بارداری',
      content:
          'آیا مطمئن هستید که می‌خواهید حالت بارداری را غیرفعال کنید و به چرخهٔ عادی بازگردید؟',
      confirmLabel: 'بله، بازگشت به چرخه',
      cancelLabel: 'انصراف',
      isDestructive: true,
    );

    if (confirmed == true && mounted) {
      final db = await DatabaseHelper.instance.database;
      await PregnancySettings.setPregnancyActive(false, db: db);
      if (mounted) {
        widget.onExitPregnancy?.call();
        widget.onDataReloadNeeded?.call();
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
      }
    }
  }
}
