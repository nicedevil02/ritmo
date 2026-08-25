import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/supplementary_sports/application/application.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../components/components.dart';
import 'mv_kind_picker_sheet.dart';

/// Sheet: "برنامهٔ روز" (ساخت و ویرایش برنامهٔ روز — Section 5.9, S1-T7 & N-01).
class MvDayPlanSheet extends StatefulWidget {
  final MvSlot slot;
  final MvKindUseCase? kindUseCase;
  final MvSaveCommitmentUseCase? saveCommitmentUseCase;
  final ValueChanged<MvSlot> onSave;

  const MvDayPlanSheet({
    super.key,
    required this.slot,
    this.kindUseCase,
    this.saveCommitmentUseCase,
    required this.onSave,
  });

  static Future<void> show({
    required BuildContext context,
    required MvSlot slot,
    MvKindUseCase? kindUseCase,
    MvSaveCommitmentUseCase? saveCommitmentUseCase,
    required ValueChanged<MvSlot> onSave,
  }) {
    return MvSheetScaffold.show(
      context: context,
      builder: (ctx) => MvDayPlanSheet(
        slot: slot,
        kindUseCase: kindUseCase,
        saveCommitmentUseCase: saveCommitmentUseCase,
        onSave: (s) {
          Navigator.pop(ctx);
          onSave(s);
        },
      ),
    );
  }

  @override
  State<MvDayPlanSheet> createState() => _MvDayPlanSheetState();
}

class _MvDayPlanSheetState extends State<MvDayPlanSheet> {
  static const List<MvSlotType> _allowedSlotTypes = [
    MvSlotType.strength,
    MvSlotType.cardio,
    MvSlotType.sport,
    MvSlotType.outdoor,
    MvSlotType.rest,
  ];

  static const List<int> _durationOptions = [15, 30, 45, 60];

  late final MvKindUseCase _kindUseCase;
  late MvSlotType _slotType;
  MvMovementKind? _kind;
  String? _kindCode;
  late int _minutes;
  late MvIntensityTier _intensity;
  late TextEditingController _titleController;
  late TextEditingController _venueController;
  TimeOfDay? _plannedTime;
  final List<String> _focusCodes = [];
  bool _repeatWeekly = false;

  @override
  void initState() {
    super.initState();
    _kindUseCase = widget.kindUseCase ?? MvKindUseCase();
    _slotType = widget.slot.slotType;
    _kindCode = widget.slot.kindCode;
    _minutes = widget.slot.targetMinutes == 0 ? 30 : widget.slot.targetMinutes;
    _intensity = widget.slot.intensityTier;
    _focusCodes.addAll(widget.slot.focusCodes);
    _titleController = TextEditingController(text: widget.slot.headlineFa);
    _venueController = TextEditingController();
    if (widget.slot.plannedTime != null &&
        widget.slot.plannedTime!.contains(':')) {
      final parts = widget.slot.plannedTime!.split(':');
      _plannedTime = TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 18,
        minute: int.tryParse(parts[1]) ?? 0,
      );
    }
    _loadKindDetails();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _venueController.dispose();
    super.dispose();
  }

  Future<void> _loadKindDetails() async {
    final code = _kindCode;
    if (code != null && code.isNotEmpty) {
      try {
        final kind = await _kindUseCase.getByCode(code);
        if (kind != null && mounted) {
          setState(() {
            _kind = kind;
          });
        }
      } catch (_) {}
    }
  }

  String _formatDateSubtitle(String dateIso) {
    try {
      final dt = DateTime.parse(dateIso);
      final j = Jalali.fromDateTime(dt);
      final weekdayName = _persianWeekdayName(dt.weekday);
      return '$weekdayName، ${toPersianDigits(j.day.toString())} ${j.formatter.mN} ${toPersianDigits(j.year.toString())}';
    } catch (_) {
      return dateIso;
    }
  }

  String _persianWeekdayName(int weekday) {
    switch (weekday) {
      case DateTime.saturday:
        return 'شنبه';
      case DateTime.sunday:
        return 'یک‌شنبه';
      case DateTime.monday:
        return 'دوشنبه';
      case DateTime.tuesday:
        return 'سه‌شنبه';
      case DateTime.wednesday:
        return 'چهارشنبه';
      case DateTime.thursday:
        return 'پنج‌شنبه';
      case DateTime.friday:
        return 'جمعه';
      default:
        return '';
    }
  }

  Future<void> _openKindPicker() async {
    List<MvMovementKind>? allKinds;
    try {
      allKinds = await _kindUseCase.getAllKinds();
    } catch (_) {}

    if (!mounted) return;

    final picked = await MvKindPickerSheet.show(
      context: context,
      useCase: _kindUseCase,
      initialCode: _kindCode,
      initialKinds: allKinds,
    );

    if (picked != null && mounted) {
      setState(() {
        _kind = picked;
        _kindCode = picked.code;
        if (picked.family == MovementFamily.sport) {
          _slotType = MvSlotType.sport;
        } else if (picked.family == MovementFamily.endurance) {
          _slotType = MvSlotType.cardio;
        } else if (picked.family == MovementFamily.outdoor) {
          _slotType = MvSlotType.outdoor;
        } else if (picked.family == MovementFamily.strength) {
          _slotType = MvSlotType.strength;
        } else if (picked.family == MovementFamily.mindBody) {
          _slotType = MvSlotType.mobility;
        }
        _titleController.text = picked.titleFa;
      });
    }
  }

  void _onSlotTypeChanged(MvSlotType type) {
    setState(() {
      _slotType = type;
      if (type == MvSlotType.rest) {
        _kind = null;
        _kindCode = null;
        _titleController.text = 'استراحت';
      } else if (type == MvSlotType.strength) {
        if (_kindCode == null) {
          _titleController.text = 'تمرین قدرتی';
        }
      } else {
        if (_kindCode == null) {
          if (type == MvSlotType.cardio) {
            _kindCode = MvKindCodes.running;
          } else if (type == MvSlotType.sport) {
            _kindCode = MvKindCodes.football;
          } else if (type == MvSlotType.outdoor) {
            _kindCode = MvKindCodes.hiking;
          }
          _loadKindDetails();
          _titleController.text = _kind?.titleFa ?? type.titleFa;
        }
      }
    });
  }

  Future<void> _handleSave() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final isRest = _slotType == MvSlotType.rest;

    String? finalKindCode = _kindCode;
    if (!isRest && _slotType != MvSlotType.strength && finalKindCode == null) {
      if (_slotType == MvSlotType.sport) {
        finalKindCode = MvKindCodes.football;
      } else if (_slotType == MvSlotType.outdoor) {
        finalKindCode = MvKindCodes.hiking;
      } else if (_slotType == MvSlotType.cardio) {
        finalKindCode = MvKindCodes.running;
      }
    }

    final headline = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : (_kind?.titleFa ?? _slotType.titleFa);

    final timeStr = _plannedTime != null
        ? '${_plannedTime!.hour.toString().padLeft(2, '0')}:${_plannedTime!.minute.toString().padLeft(2, '0')}'
        : null;

    final updated = widget.slot.copyWith(
      slotType: _slotType,
      kindCode: isRest ? null : finalKindCode,
      targetMinutes: isRest ? 0 : _minutes,
      plannedTime: isRest ? null : timeStr,
      intensityTier: isRest ? MvIntensityTier.light : _intensity,
      focusCodes: _focusCodes,
      headlineFa: headline,
      updatedAt: now,
    );

    if (_repeatWeekly && timeStr != null && !isRest) {
      final saveUseCase =
          widget.saveCommitmentUseCase ?? MvSaveCommitmentUseCase();
      final result = await saveUseCase.execute(
        slot: updated,
        repeatWeekly: true,
        venueNote: _venueController.text.trim().isNotEmpty
            ? _venueController.text.trim()
            : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.userMessageFa, textAlign: TextAlign.right),
          ),
        );
      }
      widget.onSave(result.savedSlot);
    } else {
      widget.onSave(updated.copyWith(isLocked: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.ritmoColors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;

    final isRest = _slotType == MvSlotType.rest;
    final isSport =
        _slotType == MvSlotType.sport ||
        (_kind != null && _kind!.family == MovementFamily.sport);
    final isStrength =
        _slotType == MvSlotType.strength ||
        (_kind != null && _kind!.family == MovementFamily.strength);
    final needsVenue = _kind?.needsVenue == true;

    return MvSheetScaffold(
      title: 'برنامهٔ روز',
      subtitle: _formatDateSubtitle(widget.slot.dateIso),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // نوع اسلات (۵ چیپ)
            Text(
              'نوع برنامه',
              style: textTheme.labelLarge?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: metrics.spaceSm),
            Wrap(
              spacing: metrics.spaceSm,
              runSpacing: metrics.spaceSm,
              children: _allowedSlotTypes.map((type) {
                return MvChip(
                  key: ValueKey('slot_type_${type.code}'),
                  label: type.titleFa,
                  isSelected: _slotType == type,
                  onTap: () => _onSlotTypeChanged(type),
                );
              }).toList(),
            ),
            SizedBox(height: metrics.spaceMd),

            // ۱. انتخاب نوع ورزش (برای تمام حالت‌های غیر استراحت)
            if (!isRest) ...[
              Text(
                'نوع ورزش / فعالیت',
                style: textTheme.labelLarge?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: metrics.spaceSm),
              InkWell(
                key: const ValueKey('day_plan_kind_picker_tile'),
                onTap: _openKindPicker,
                borderRadius: BorderRadius.circular(metrics.radiusCard),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: metrics.spaceMd,
                    vertical: metrics.spaceSm,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(metrics.radiusCard),
                    border: Border.all(color: colors.primary),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _kind?.emoji ?? '🏃',
                        style: textTheme.headlineSmall,
                      ),
                      SizedBox(width: metrics.spaceSm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _kind?.titleFa ?? 'انتخاب نوع حرکت...',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (_kind != null)
                              Text(
                                'ضریب MET: ${_kind!.baseMet}',
                                style: textTheme.labelSmall?.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        key: const ValueKey('mv_change_kind_btn'),
                        onPressed: _openKindPicker,
                        icon: Icon(
                          Icons.swap_horiz_rounded,
                          size: metrics.iconSm,
                          color: colors.accent,
                        ),
                        label: Text(
                          'تغییر',
                          style: textTheme.labelMedium?.copyWith(
                            color: colors.accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: metrics.spaceMd),
            ],

            // کارت توضیحات ورزش تخصصی (S8-T6)
            if (isSport && _kind != null) ...[
              Container(
                key: const ValueKey('mv_sport_kind_info_card'),
                padding: EdgeInsets.all(metrics.spaceMd),
                decoration: BoxDecoration(
                  color: colors.surfaceElevated,
                  borderRadius: BorderRadius.circular(metrics.radiusCard),
                  border: Border.all(
                    color: colors.border.withValues(alpha: 0.6),
                  ),
                ),
                child: Row(
                  children: [
                    Text(_kind!.emoji, style: textTheme.titleLarge),
                    SizedBox(width: metrics.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ورزش تخصصی ${_kind!.titleFa}',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                          SizedBox(height: metrics.spaceXs),
                          Text(
                            'ورزش توپی/تخصصی — کالری‌سوزی و ردیابی زمان جلسه بر اساس ضریب مت (${_kind!.baseMet} MET)',
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: metrics.spaceMd),
            ],

            if (_slotType != MvSlotType.rest) ...[
              // ۲. مدت پیشنهادی (چیپ‌های ۱۵/۳۰/۴۵/۶۰ دقیقه)
              Text(
                'مدت هدف (دقیقه)',
                style: textTheme.labelLarge?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: metrics.spaceSm),
              Wrap(
                spacing: metrics.spaceSm,
                runSpacing: metrics.spaceSm,
                children: _durationOptions.map((d) {
                  return MvChip(
                    key: ValueKey('day_plan_duration_$d'),
                    label: '$d دقیقه',
                    isSelected: _minutes == d,
                    onTap: () => setState(() => _minutes = d),
                  );
                }).toList(),
              ),
              SizedBox(height: metrics.spaceMd),

              // ۳. ساعت شروع (plannedTime) اختیاری
              Text(
                'ساعت شروع (اختیاری)',
                style: textTheme.labelLarge?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: metrics.spaceSm),
              InkWell(
                key: const ValueKey('day_plan_time_picker'),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime:
                        _plannedTime ?? const TimeOfDay(hour: 18, minute: 0),
                  );
                  if (picked != null) {
                    setState(() => _plannedTime = picked);
                  }
                },
                borderRadius: BorderRadius.circular(metrics.radiusField),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: metrics.spaceMd,
                    vertical: metrics.spaceSm,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(metrics.radiusField),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        color: colors.textSecondary,
                        size: metrics.iconSm,
                      ),
                      SizedBox(width: metrics.spaceSm),
                      Text(
                        _plannedTime != null
                            ? '${toPersianDigits(_plannedTime!.hour.toString().padLeft(2, '0'))}:${toPersianDigits(_plannedTime!.minute.toString().padLeft(2, '0'))}'
                            : 'مشخص نشده',
                        style: textTheme.bodyMedium?.copyWith(
                          color: _plannedTime != null
                              ? colors.textPrimary
                              : colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: metrics.spaceMd),

              // ۴. مکان (venueNote) — فقط اگر kind.needsVenue == true
              if (needsVenue) ...[
                Text(
                  'مکان یا سالن (اختیاری)',
                  style: textTheme.labelLarge?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: metrics.spaceXs),
                TextField(
                  key: const ValueKey('day_plan_venue_field'),
                  controller: _venueController,
                  decoration: InputDecoration(
                    hintText: 'مثلاً سالن شهدای غواص، زمین چمن آزادی',
                    filled: true,
                    fillColor: colors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(metrics.radiusField),
                      borderSide: BorderSide(color: colors.border),
                    ),
                  ),
                ),
                SizedBox(height: metrics.spaceMd),
              ],

              // ۵. شدت تمرین (۳ گزینهٔ MvIntensityTier)
              Text(
                'شدت تمرین',
                style: textTheme.labelLarge?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: metrics.spaceSm),
              Wrap(
                spacing: metrics.spaceSm,
                runSpacing: metrics.spaceSm,
                children: MvIntensityTier.values.map((tier) {
                  return MvChip(
                    key: ValueKey('day_plan_intensity_${tier.name}'),
                    label: tier.titleFa,
                    isSelected: _intensity == tier,
                    onTap: () => setState(() => _intensity = tier),
                  );
                }).toList(),
              ),
              SizedBox(height: metrics.spaceMd),

              // ۶. تمرکز عضلانی — فقط اگر family == STRENGTH
              if (isStrength) ...[
                Text(
                  'تمرکز عضلانی',
                  style: textTheme.labelLarge?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: metrics.spaceSm),
                Wrap(
                  key: const ValueKey('day_plan_muscle_focus'),
                  spacing: metrics.spaceSm,
                  runSpacing: metrics.spaceSm,
                  children: MvMuscleGroup.all.take(6).map((mg) {
                    final isSel = _focusCodes.contains(mg.code);
                    return MvChip(
                      label: mg.titleFa,
                      icon: Text(mg.emoji, style: textTheme.labelSmall),
                      isSelected: isSel,
                      onTap: () {
                        setState(() {
                          if (isSel) {
                            _focusCodes.remove(mg.code);
                          } else {
                            _focusCodes.add(mg.code);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                SizedBox(height: metrics.spaceMd),
              ],

              // ۷. «هر هفته تکرار شود»
              SwitchListTile.adaptive(
                key: const ValueKey('day_plan_repeat_weekly_switch'),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'هر هفته تکرار شود',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'این فعالیت در هفته‌های بعد در همین روز قرار می‌گیرد',
                  style: textTheme.labelSmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                value: _repeatWeekly,
                onChanged: (val) => setState(() => _repeatWeekly = val),
              ),
              SizedBox(height: metrics.spaceMd),

              // فیلد عنوان دلخواه
              Text(
                'عنوان دلخواه (اختیاری)',
                style: textTheme.labelLarge?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: metrics.spaceXs),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: _kind?.titleFa ?? _slotType.titleFa,
                  filled: true,
                  fillColor: colors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(metrics.radiusField),
                    borderSide: BorderSide(color: colors.border),
                  ),
                ),
              ),
            ],
            SizedBox(height: metrics.spaceLg),
          ],
        ),
      ),
      bottomAction: MvPrimaryAction(
        key: const ValueKey('day_plan_save_action'),
        label: 'ثبت و ذخیره برنامه',
        icon: Icons.check_rounded,
        onPressed: _handleSave,
      ),
    );
  }
}
