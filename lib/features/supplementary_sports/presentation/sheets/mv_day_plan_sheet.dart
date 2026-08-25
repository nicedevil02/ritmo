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
  final ValueChanged<MvSlot> onSave;

  const MvDayPlanSheet({
    super.key,
    required this.slot,
    this.kindUseCase,
    required this.onSave,
  });

  static Future<void> show({
    required BuildContext context,
    required MvSlot slot,
    MvKindUseCase? kindUseCase,
    required ValueChanged<MvSlot> onSave,
  }) {
    return MvSheetScaffold.show(
      context: context,
      builder: (ctx) => MvDayPlanSheet(
        slot: slot,
        kindUseCase: kindUseCase,
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
  String? _kindCode;
  String? _kindTitleFa;
  String? _kindEmoji;
  late int _minutes;
  late MvIntensityTier _intensity;
  late TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _kindUseCase = widget.kindUseCase ?? MvKindUseCase();
    _slotType = widget.slot.slotType;
    _kindCode = widget.slot.kindCode;
    _minutes = widget.slot.targetMinutes == 0 ? 30 : widget.slot.targetMinutes;
    _intensity = widget.slot.intensityTier;
    _titleController = TextEditingController(text: widget.slot.headlineFa);
    _loadKindDetails();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadKindDetails() async {
    final code = _kindCode;
    if (code != null && code.isNotEmpty) {
      try {
        final kind = await _kindUseCase.getByCode(code);
        if (kind != null && mounted) {
          setState(() {
            _kindTitleFa = kind.titleFa;
            _kindEmoji = kind.emoji;
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
        _kindCode = picked.code;
        _kindTitleFa = picked.titleFa;
        _kindEmoji = picked.emoji;
        if (_titleController.text.isEmpty ||
            _titleController.text == _slotType.titleFa) {
          _titleController.text = picked.titleFa;
        }
      });
    }
  }

  void _onSlotTypeChanged(MvSlotType type) {
    setState(() {
      _slotType = type;
      if (type == MvSlotType.rest) {
        _kindCode = null;
        _kindTitleFa = null;
        _kindEmoji = null;
        _titleController.text = 'استراحت';
      } else if (type == MvSlotType.strength) {
        if (_kindCode == null) {
          _titleController.text = 'تمرین قدرتی';
        }
      } else {
        // cardio, sport, outdoor: require a kindCode
        if (_kindCode == null) {
          if (type == MvSlotType.cardio) {
            _kindCode = 'RUNNING';
            _kindTitleFa = 'دویدن';
            _kindEmoji = '🏃';
          } else if (type == MvSlotType.sport) {
            _kindCode = 'FOOTBALL';
            _kindTitleFa = 'فوتبال';
            _kindEmoji = '⚽';
          } else if (type == MvSlotType.outdoor) {
            _kindCode = 'HIKING';
            _kindTitleFa = 'کوه‌نوردی';
            _kindEmoji = '🏔';
          }
          _titleController.text = _kindTitleFa ?? type.titleFa;
        }
      }
    });
  }

  void _handleSave() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final isRest = _slotType == MvSlotType.rest;

    // Ensure kindCode is present if required by MvSlotType
    String? finalKindCode = _kindCode;
    if (!isRest && _slotType != MvSlotType.strength && finalKindCode == null) {
      if (_slotType == MvSlotType.sport) {
        finalKindCode = 'FOOTBALL';
      } else if (_slotType == MvSlotType.outdoor) {
        finalKindCode = 'HIKING';
      } else if (_slotType == MvSlotType.cardio) {
        finalKindCode = 'RUNNING';
      }
    }

    final headline = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : (_kindTitleFa ?? _slotType.titleFa);

    final updated = widget.slot.copyWith(
      slotType: _slotType,
      kindCode: isRest ? null : finalKindCode,
      targetMinutes: isRest ? 0 : _minutes,
      intensityTier: isRest ? MvIntensityTier.light : _intensity,
      headlineFa: headline,
      updatedAt: now,
    );

    widget.onSave(updated);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.ritmoColors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;

    final isKindRequired =
        _slotType != MvSlotType.rest && _slotType != MvSlotType.strength;

    return MvSheetScaffold(
      title: 'برنامهٔ روز',
      subtitle: _formatDateSubtitle(widget.slot.dateIso),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ۱. عنوان روز و تاریخ جلالی در هدر آمده است.

            // ۲. نوع اسلات (۵ چیپ)
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

            // ۳. انتخاب نوع حرکت (اگر نوع != REST و != STRENGTH باشد الزامی است)
            if (isKindRequired) ...[
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
                        _kindEmoji ?? '🏃',
                        style: const TextStyle(fontSize: 24),
                      ),
                      SizedBox(width: metrics.spaceSm),
                      Expanded(
                        child: Text(
                          _kindTitleFa ?? 'انتخاب از ۴۹ ورزش...',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_left_rounded,
                        color: colors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: metrics.spaceMd),
            ],

            if (_slotType != MvSlotType.rest) ...[
              // ۴. مدت پیشنهادی (چیپ‌های ۱۵/۳۰/۴۵/۶۰ دقیقه)
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

              // ۵. شدت تمرین (۳ دکمه: سبک، متوسط، سنگین)
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

              // فیلد عنوان اختیاری
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
                  hintText: _kindTitleFa ?? _slotType.titleFa,
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
      // ۶. دکمهٔ ثبت / بستن
      bottomAction: MvPrimaryAction(
        key: const ValueKey('day_plan_save_action'),
        label: 'ثبت و ذخیره برنامه',
        icon: Icons.check_rounded,
        onPressed: _handleSave,
      ),
    );
  }
}
