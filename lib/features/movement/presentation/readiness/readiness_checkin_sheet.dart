import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/application/movement_analytics_service.dart';
import 'package:ritmo/features/movement/application/movement_readiness_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_readiness_checkin.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';
import 'package:ritmo/features/movement/presentation/readiness/widgets/scale_selector.dart';

/// شیت چک‌این آمادگی روزانه (ReadinessCheckinSheet)
/// ۵ فیلد اختیاری، بدون ایجاد بن‌بست و با دکمهٔ همیشگی «رد کردن».
class ReadinessCheckinSheet extends StatefulWidget {
  const ReadinessCheckinSheet({
    super.key,
    required this.readinessService,
    this.trigger = 'manual',
    this.initialCheckin,
  });

  final MovementReadinessService readinessService;
  final String trigger; // manual, pre_heavy_session, after_consecutive_missed
  final MovementReadinessCheckin? initialCheckin;

  static Future<MovementReadinessCheckin?> show(
    BuildContext context, {
    required MovementReadinessService readinessService,
    String trigger = 'manual',
    MovementReadinessCheckin? initialCheckin,
  }) {
    return showModalBottomSheet<MovementReadinessCheckin>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReadinessCheckinSheet(
        readinessService: readinessService,
        trigger: trigger,
        initialCheckin: initialCheckin,
      ),
    );
  }

  @override
  State<ReadinessCheckinSheet> createState() => _ReadinessCheckinSheetState();
}

class _ReadinessCheckinSheetState extends State<ReadinessCheckinSheet> {
  int? _sleep;
  int? _energy;
  int? _soreness;
  int? _stress;
  int? _availableMinutes;

  @override
  void initState() {
    super.initState();
    if (widget.initialCheckin != null) {
      _sleep = widget.initialCheckin!.sleep;
      _energy = widget.initialCheckin!.energy;
      _soreness = widget.initialCheckin!.soreness;
      _stress = widget.initialCheckin!.stress;
      _availableMinutes = widget.initialCheckin!.availableMinutes;
    }
  }

  static String _formatIso(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _handleSubmit() async {
    final now = DateTime.now();
    final checkin = MovementReadinessCheckin(
      id: 'chk_${now.millisecondsSinceEpoch}',
      dateIso: _formatIso(now),
      sleep: _sleep,
      energy: _energy,
      soreness: _soreness,
      stress: _stress,
      availableMinutes: _availableMinutes,
      createdAt: now,
    );

    await widget.readinessService.recordCheckin(checkin);

    MovementAnalyticsService.instance.logReadinessSubmitted(
      filledFieldsCount: checkin.filledFieldsCount,
      trigger: widget.trigger,
    );

    if (mounted) {
      Navigator.of(context).pop(checkin);
    }
  }

  void _handleSkip() {
    Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return Material(
      color: colors.surface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(RitmoRadius.sheet),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: RitmoSpacing.lg,
            right: RitmoSpacing.lg,
            top: RitmoSpacing.md,
            bottom: MediaQuery.of(context).viewInsets.bottom + RitmoSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // نوار درگ بالای شیت
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: RitmoSpacing.md),
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(RitmoRadius.pill),
                  ),
                ),
              ),

              // عنوان و دکمهٔ رد کردن
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    MovementStrings.readinessCheckinTitle,
                    style: RitmoTextStyles.cardTitle(colors.textPrimary),
                  ),
                  TextButton(
                    onPressed: _handleSkip,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    child: Text(
                      MovementStrings.readinessSkip,
                      style: RitmoTextStyles.caption(colors.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: RitmoSpacing.xs),
              Text(
                MovementStrings.readinessSubtitle,
                style: RitmoTextStyles.caption(colors.textTertiary),
              ),
              const SizedBox(height: RitmoSpacing.lg),

              // فیلدهای پنج‌گانه
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      ScaleSelector(
                        title: MovementStrings.readinessSleepLabel,
                        selectedValue: _sleep,
                        onChanged: (val) => setState(() => _sleep = val),
                        semanticsGroup: 'ارزیابی خواب',
                      ),
                      const SizedBox(height: RitmoSpacing.lg),
                      ScaleSelector(
                        title: MovementStrings.readinessEnergyLabel,
                        selectedValue: _energy,
                        onChanged: (val) => setState(() => _energy = val),
                        semanticsGroup: 'ارزیابی انرژی',
                      ),
                      const SizedBox(height: RitmoSpacing.lg),
                      ScaleSelector(
                        title: MovementStrings.readinessSorenessLabel,
                        selectedValue: _soreness,
                        onChanged: (val) => setState(() => _soreness = val),
                        labels: const [
                          'هیچ',
                          'بسیار کم',
                          'متوسط',
                          'زیاد',
                          'شدید',
                        ],
                        semanticsGroup: 'ارزیابی درد عضلانی',
                      ),
                      const SizedBox(height: RitmoSpacing.lg),
                      ScaleSelector(
                        title: MovementStrings.readinessStressLabel,
                        selectedValue: _stress,
                        onChanged: (val) => setState(() => _stress = val),
                        labels: const [
                          'آرام',
                          'کم',
                          'متوسط',
                          'زیاد',
                          'بسیار زیاد',
                        ],
                        semanticsGroup: 'ارزیابی استرس',
                      ),
                      const SizedBox(height: RitmoSpacing.lg),

                      // زمان در دسترس
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            MovementStrings.readinessAvailableMinutesLabel,
                            style: RitmoTextStyles.label(colors.textPrimary),
                          ),
                          const SizedBox(height: RitmoSpacing.sm),
                          Wrap(
                            spacing: RitmoSpacing.sm,
                            runSpacing: RitmoSpacing.xs,
                            children: [15, 20, 30, 45, 60].map((mins) {
                              final isSelected = _availableMinutes == mins;
                              return ChoiceChip(
                                label: Text('${toPersianDigits(mins)} دقیقه'),
                                selected: isSelected,
                                onSelected: (sel) => setState(
                                  () => _availableMinutes = sel ? mins : null,
                                ),
                                selectedColor: sportsColor.withValues(
                                  alpha: 0.2,
                                ),
                                labelStyle: RitmoTextStyles.caption(
                                  isSelected ? sportsColor : colors.textPrimary,
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                      const SizedBox(height: RitmoSpacing.xl),
                    ],
                  ),
                ),
              ),

              // دکمهٔ ثبت
              ElevatedButton(
                onPressed: _handleSubmit,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(
                    double.infinity,
                    MovementLayout.kPrimaryButtonHeight,
                  ),
                  backgroundColor: sportsColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(RitmoRadius.field),
                  ),
                ),
                child: Text(
                  MovementStrings.readinessSubmit,
                  style: RitmoTextStyles.label(Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
