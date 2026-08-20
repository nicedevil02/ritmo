import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/observability/ritmo_logger.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/pregnancy_engine.dart';
import 'package:ritmo/features/cycle/models/pregnancy_models.dart';
import 'package:ritmo/features/cycle/presentation/onboarding/pregnancy_onboarding_controller.dart';
import 'package:shamsi_date/shamsi_date.dart';

class PregnancyOnboardingShell extends StatefulWidget {
  const PregnancyOnboardingShell({
    super.key,
    required this.onCompleted,
    this.onCancel,
  });

  final VoidCallback onCompleted;
  final VoidCallback? onCancel;

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onCompleted,
    VoidCallback? onCancel,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PregnancyOnboardingShell(
        onCompleted: onCompleted,
        onCancel: onCancel ?? () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  State<PregnancyOnboardingShell> createState() => _PregnancyOnboardingShellState();
}

class _PregnancyOnboardingShellState extends State<PregnancyOnboardingShell> {
  late final PregnancyOnboardingController _controller;
  bool _isSaving = false;
  int _crlMm = 45;
  DateTime _selectedUltrasoundDate = CycleClock.now.subtract(const Duration(days: 14));

  @override
  void initState() {
    super.initState();
    _controller = PregnancyOnboardingController();
    // Set a sensible default LMP (e.g., 8 weeks ago) so initial state is valid
    final defaultLmp = CycleClock.now.subtract(const Duration(days: 56));
    _controller.setLmpDate(defaultLmp);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await _controller.save();
      if (mounted) {
        widget.onCompleted();
      }
    } catch (e, st) {
      RitmoLogger.error(
        '[PregnancyOnboardingShell] Error saving pregnancy profile',
        error: e,
        stack: st,
      );
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطا در ذخیره‌سازی اطلاعات. لطفاً دوباره تلاش کنید.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final viewInsets = MediaQuery.of(context).viewInsets;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            margin: EdgeInsets.only(bottom: viewInsets.bottom),
            decoration: BoxDecoration(
              color: colors.surfaceElevated,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(CupertinoIcons.xmark),
                        color: colors.textSecondary,
                        onPressed: widget.onCancel ?? () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Text(
                          'راه‌اندازی همراهی بارداری',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 48), // Balance for close button
                    ],
                  ),
                ),

                // Step progress indicators
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    children: List.generate(5, (index) {
                      final isActive = index <= _controller.currentStep;
                      final isCurrent = index == _controller.currentStep;
                      return Expanded(
                        child: Container(
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? colors.primary
                                : (isActive ? colors.primary.withValues(alpha: 0.5) : colors.border),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                // Step Body
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: _buildStepContent(context),
                  ),
                ),

                // Validation error banner
                if (_controller.validationErrorFa != null)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.exclamationmark_circle, color: colors.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _controller.validationErrorFa!,
                            style: TextStyle(color: colors.error, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Bottom Buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: Row(
                    children: [
                      if (_controller.currentStep > 0) ...[
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _controller.previousStep,
                          child: const Text('مرحله قبل'),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _isSaving
                              ? null
                              : () {
                                  if (_controller.currentStep < 4) {
                                    _controller.nextStep();
                                  } else {
                                    _handleSave();
                                  }
                                },
                          child: _isSaving
                              ? const CupertinoActivityIndicator(color: Colors.white)
                              : Text(
                                  _controller.currentStep == 4
                                      ? 'شروع همراهی بارداری 🌸'
                                      : 'مرحله بعد',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStepContent(BuildContext context) {
    switch (_controller.currentStep) {
      case 0:
        return _buildStep0MethodSelection(context);
      case 1:
        return _buildStep1DateSelection(context);
      case 2:
        return _buildStep2MedicalInfo(context);
      case 3:
        return _buildStep3ToneAndUnits(context);
      case 4:
      default:
        return _buildStep4SummaryAndReminders(context);
    }
  }

  Widget _buildStep0MethodSelection(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'محاسبه تاریخ زایمان و سن بارداری',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          'کدام اطلاعات را برای محاسبه در اختیار دارید؟',
          style: TextStyle(fontSize: 14, color: colors.textSecondary),
        ),
        const SizedBox(height: 20),
        _buildMethodCard(
          title: 'اولین روز آخرین قاعدگی (LMP)',
          subtitle: 'روش استاندارد و مرسوم برای تعیین سن بارداری',
          icon: CupertinoIcons.calendar,
          source: PregnancyEddSource.lmp,
        ),
        const SizedBox(height: 12),
        _buildMethodCard(
          title: 'سونوگرافی غربالگری (CRL)',
          subtitle: 'محاسبه دقیق بر اساس اندازه جنین در سونوگرافی',
          icon: CupertinoIcons.waveform_path_ecg,
          source: PregnancyEddSource.ultrasound,
        ),
        const SizedBox(height: 12),
        _buildMethodCard(
          title: 'تاریخ تخمینی اعلام‌شده توسط پزشک',
          subtitle: 'اگر تاریخ زایمان را مستقیماً از پزشک خود می‌دانید',
          icon: CupertinoIcons.person_crop_circle_badge_checkmark,
          source: PregnancyEddSource.doctorEdd,
        ),
      ],
    );
  }

  Widget _buildMethodCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required PregnancyEddSource source,
  }) {
    final colors = context.colors;
    final isSelected = _controller.eddSource == source;

    return InkWell(
      onTap: () => _controller.setEddSource(source),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary.withValues(alpha: 0.1) : colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? colors.primary : colors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? colors.primary : colors.surfaceElevated,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isSelected ? Colors.white : colors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
              color: isSelected ? colors.primary : colors.textTertiary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1DateSelection(BuildContext context) {
    final colors = context.colors;
    final source = _controller.eddSource;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          source == PregnancyEddSource.lmp
              ? 'تاریخ اولین روز آخرین قاعدگی'
              : source == PregnancyEddSource.doctorEdd
                  ? 'تاریخ تخمینی زایمان (اعلام پزشک)'
                  : 'اطلاعات سونوگرافی',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          source == PregnancyEddSource.lmp
              ? 'تاریخ شروع آخرین خونریزی قاعدگی خود را انتخاب کنید.'
              : source == PregnancyEddSource.doctorEdd
                  ? 'تاریخ پایان بارداری (۴۰ هفته) که پزشک به شما اعلام کرده است.'
                  : 'تاریخ انجام سونوگرافی و اندازه CRL (میلی‌متر) را وارد کنید.',
          style: TextStyle(fontSize: 14, color: colors.textSecondary),
        ),
        const SizedBox(height: 20),

        if (source == PregnancyEddSource.lmp) ...[
          _buildDatePickerTile(
            label: 'تاریخ شروع قاعدگی (LMP)',
            date: _controller.lmpDate ?? CycleClock.now.subtract(const Duration(days: 56)),
            onChanged: (d) => _controller.setLmpDate(d),
          ),
        ] else if (source == PregnancyEddSource.doctorEdd) ...[
          _buildDatePickerTile(
            label: 'تاریخ تقریبی زایمان (EDD)',
            date: _controller.dueDate ?? CycleClock.now.add(const Duration(days: 224)),
            onChanged: (d) => _controller.setDueDate(d),
          ),
        ] else ...[
          _buildDatePickerTile(
            label: 'تاریخ انجام سونوگرافی',
            date: _selectedUltrasoundDate,
            onChanged: (d) {
              setState(() => _selectedUltrasoundDate = d);
              _controller.setUltrasound(date: d, crlMm: _crlMm);
            },
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('اندازه جنین (CRL)', style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary)),
                    Text(
                      '${PersianDigits.toFa(_crlMm.toString())} میلی‌متر',
                      style: TextStyle(fontWeight: FontWeight.bold, color: colors.primary),
                    ),
                  ],
                ),
                Slider(
                  value: _crlMm.toDouble(),
                  min: 10,
                  max: 84,
                  divisions: 74,
                  activeColor: colors.primary,
                  onChanged: (v) {
                    setState(() => _crlMm = v.round());
                    _controller.setUltrasound(date: _selectedUltrasoundDate, crlMm: _crlMm);
                  },
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),
        if (_controller.lmpDate != null && _controller.dueDate != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('سن بارداری کنونی:', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                    Text(
                      PregnancyDateEngine.formatGestationalAgeFa(
                        PregnancyDateEngine.calculateCurrentGestation(lmp: _controller.lmpDate!),
                      ),
                      style: TextStyle(fontWeight: FontWeight.bold, color: colors.primary, fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('تاریخ تخمینی زایمان:', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                    Text(
                      _formatJalaliDate(_controller.dueDate!),
                      style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary, fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDatePickerTile({
    required String label,
    required DateTime date,
    required ValueChanged<DateTime> onChanged,
  }) {
    final colors = context.colors;
    final j = Jalali.fromDateTime(date);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: colors.textSecondary)),
              const SizedBox(height: 4),
              Text(
                '${PersianDigits.toFa(j.year.toString())}/${PersianDigits.toFa(j.month.toString().padLeft(2, '0'))}/${PersianDigits.toFa(j.day.toString().padLeft(2, '0'))}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary),
              ),
            ],
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.surfaceElevated,
              foregroundColor: colors.textPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: colors.border),
              ),
            ),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: CycleClock.now.subtract(const Duration(days: 300)),
                lastDate: CycleClock.now.add(const Duration(days: 300)),
              );
              if (picked != null) {
                onChanged(picked);
              }
            },
            child: const Text('تغییر تاریخ'),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2MedicalInfo(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'اطلاعات پایه پزشکی',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          'این اطلاعات به تنظیم هشدارهای متناسب و مراقبت‌های هوشمند کمک می‌کند.',
          style: TextStyle(fontSize: 14, color: colors.textSecondary),
        ),
        const SizedBox(height: 20),
        Material(
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colors.border),
          ),
          child: SwitchListTile.adaptive(
            value: _controller.isMultiple,
            onChanged: _controller.setMultiple,
            title: Text(
              'بارداری دوقلو یا چندقلو',
              style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary),
            ),
            subtitle: Text(
              'تنظیم بازه‌های مراقبت و وزن‌گیری مخصوص چندقلوها',
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
            activeTrackColor: colors.primary,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          ),
        ),
        const SizedBox(height: 12),
        Material(
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colors.border),
          ),
          child: SwitchListTile.adaptive(
            value: _controller.isHighRisk,
            onChanged: _controller.setHighRisk,
            title: Text(
              'بارداری پرخطر / نیازمند مراقبت ویژه',
              style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary),
            ),
            subtitle: Text(
              'افزایش حساسیت هشدارهای تریاژ علائم و یادآوری ویزیت‌ها',
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
            activeTrackColor: colors.primary,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          ),
        ),
      ],
    );
  }

  Widget _buildStep3ToneAndUnits(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'سفارشی‌سازی نمایش و لحن',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          'نحوه نمایش سن بارداری و لحن پیام‌ها را به دلخواه خود انتخاب کنید.',
          style: TextStyle(fontSize: 14, color: colors.textSecondary),
        ),
        const SizedBox(height: 20),
        Text('واحد نمایش سن بارداری:', style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildChoiceChip(
                label: 'هفته و روز (پیش‌فرض)',
                isSelected: _controller.ageUnit == PregnancyAgeUnit.weeks,
                onTap: () => _controller.setAgeUnit(PregnancyAgeUnit.weeks),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildChoiceChip(
                label: 'ماه بارداری',
                isSelected: _controller.ageUnit == PregnancyAgeUnit.months,
                onTap: () => _controller.setAgeUnit(PregnancyAgeUnit.months),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('لحن پیام‌ها و نکات خودمراقبتی:', style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildChoiceChip(
                label: 'صمیمی و پرانرژی 🌸',
                isSelected: _controller.tone == PregnancyTone.warm,
                onTap: () => _controller.setTone(PregnancyTone.warm),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildChoiceChip(
                label: 'رسمی و علمی 🩺',
                isSelected: _controller.tone == PregnancyTone.neutral,
                onTap: () => _controller.setTone(PregnancyTone.neutral),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary.withValues(alpha: 0.12) : colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? colors.primary : colors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? colors.primary : colors.textPrimary,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildStep4SummaryAndReminders(BuildContext context) {
    final colors = context.colors;
    final ga = _controller.lmpDate != null
        ? PregnancyDateEngine.calculateCurrentGestation(lmp: _controller.lmpDate!)
        : const GestationalAge(weeks: 0, days: 0, totalDays: 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'یادآورها و تأیید نهایی',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          'زمان یادآوری‌ها را تنظیم کنید و خلاصه اطلاعات را بررسی نمایید.',
          style: TextStyle(fontSize: 14, color: colors.textSecondary),
        ),
        const SizedBox(height: 20),

        // Reminder Hour
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('ساعت یادآوری روزانه:', style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary)),
                  Text(
                    'ساعت ${PersianDigits.toFa(_controller.reminderHour.toString())}:۰۰',
                    style: TextStyle(fontWeight: FontWeight.bold, color: colors.primary),
                  ),
                ],
              ),
              Slider(
                value: _controller.reminderHour.toDouble(),
                min: 6,
                max: 22,
                divisions: 16,
                activeColor: colors.primary,
                onChanged: (v) => _controller.setReminderHour(v.round()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Lead days for checkups
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('پیش‌اطلاع ویزیت‌های پزشکی:', style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary)),
                  Text(
                    '${PersianDigits.toFa(_controller.visitLeadDays.toString())} روز قبل',
                    style: TextStyle(fontWeight: FontWeight.bold, color: colors.primary),
                  ),
                ],
              ),
              Slider(
                value: _controller.visitLeadDays.toDouble(),
                min: 1,
                max: 7,
                divisions: 6,
                activeColor: colors.primary,
                onChanged: (v) => _controller.setVisitLeadDays(v.round()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Summary Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('سن بارداری امروز:', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                  Text(
                    PregnancyDateEngine.formatGestationalAgeFa(ga, unit: _controller.ageUnit),
                    style: TextStyle(fontWeight: FontWeight.bold, color: colors.primary, fontSize: 15),
                  ),
                ],
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('تاریخ تخمینی زایمان:', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                  Text(
                    _controller.dueDate != null ? _formatJalaliDate(_controller.dueDate!) : '—',
                    style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('لحن همراهی:', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                  Text(
                    _controller.tone == PregnancyTone.warm ? 'صمیمی و پرانرژی 🌸' : 'رسمی و علمی 🩺',
                    style: TextStyle(color: colors.textPrimary, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatJalaliDate(DateTime dt) {
    final j = Jalali.fromDateTime(dt);
    final monthNames = [
      'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
      'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'
    ];
    return '${PersianDigits.toFa(j.day.toString())} ${monthNames[j.month - 1]} ${PersianDigits.toFa(j.year.toString())}';
  }
}
