import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/engines/ritmo_cross_module_engine.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/supplementary_sports/application/application.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:ritmo/core/widgets/sheet/ritmo_picker_sheet.dart';
import '../components/components.dart';
import 'mv_kind_picker_sheet.dart';

/// Sheet: "برنامهٔ روز" (ساخت و ویرایش برنامهٔ روز — Section 5.9, S1-T7 & N-01).
class MvDayPlanSheet extends StatefulWidget {
  final MvSlot slot;
  final MvKindUseCase? kindUseCase;
  final MvSaveCommitmentUseCase? saveCommitmentUseCase;
  final ValueChanged<MvSlot> onSave;
  final void Function(MvSlot slot, bool deleteRecurring)? onDelete;

  const MvDayPlanSheet({
    super.key,
    required this.slot,
    this.kindUseCase,
    this.saveCommitmentUseCase,
    required this.onSave,
    this.onDelete,
  });

  static Future<void> show({
    required BuildContext context,
    required MvSlot slot,
    MvKindUseCase? kindUseCase,
    MvSaveCommitmentUseCase? saveCommitmentUseCase,
    required ValueChanged<MvSlot> onSave,
    void Function(MvSlot slot, bool deleteRecurring)? onDelete,
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
        onDelete: onDelete != null
            ? (s, delRec) {
                Navigator.pop(ctx);
                onDelete(s, delRec);
              }
            : null,
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
  RitmoCrossModuleSnapshot? _crossModuleSnapshot;

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
    _loadCrossModuleContext();
  }

  Future<void> _loadCrossModuleContext() async {
    try {
      final dt = DateTime.tryParse(widget.slot.dateIso);
      final snapshot =
          await RitmoCrossModuleEngine.instance.getSnapshot(date: dt);
      if (mounted) {
        setState(() {
          _crossModuleSnapshot = snapshot;
        });
      }
    } catch (_) {}
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
      final sat0 = MvCalendar.dateTimeToSat0(dt);
      final j = Jalali.fromDateTime(dt);
      return '${MvCalendar.persianWeekdayName(sat0)} ${toPersianDigits(j.day.toString())} ${j.formatter.mN}';
    } catch (_) {
      return dateIso;
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
    final l10n = AppLocalizations.of(context);
    setState(() {
      _slotType = type;
      if (type == MvSlotType.rest) {
        _kind = null;
        _kindCode = null;
        _titleController.text = l10n?.mv_plan_rest ?? 'Rest';
      } else if (type == MvSlotType.strength) {
        if (_kindCode == null) {
          _titleController.text = l10n?.mv_plan_strength ?? 'Strength Workout';
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

  Future<void> _handleDelete() async {
    final l10n = AppLocalizations.of(context);
    final isLocked = widget.slot.isLocked;

    if (isLocked) {
      final selected = await RitmoPickerSheet.show<bool>(
        context: context,
        title: l10n?.mv_plan_delete_recurring_prompt ?? 'نحوهٔ حذف ورزش تکرارشونده',
        options: [
          PickerOption(
            label: l10n?.mv_plan_delete_this_week_only ?? 'فقط برای این هفته لغو شود',
            subtitle: 'تعهد هفتگی حفظ شده و این روز به استراحت تبدیل می‌شود.',
            icon: Icons.event_busy_rounded,
            value: false,
          ),
          PickerOption(
            label: l10n?.mv_plan_delete_all_weeks ?? 'حذف دائمی از برنامهٔ هفتگی',
            subtitle: 'کل تعهد هفتگی برای همیشه پاک می‌شود.',
            icon: Icons.delete_forever_rounded,
            value: true,
          ),
        ],
      );

      if (selected == null || !mounted) return;

      if (widget.onDelete != null) {
        widget.onDelete!(widget.slot, selected);
      } else {
        final now = DateTime.now().millisecondsSinceEpoch;
        final restSlot = widget.slot.copyWith(
          slotType: MvSlotType.rest,
          kindCode: null,
          targetMinutes: 0,
          plannedTime: null,
          headlineFa: 'روز استراحت و ریکاوری',
          isLocked: true,
          updatedAt: now,
        );
        widget.onSave(restSlot);
      }
    } else {
      final confirmed = await RitmoDialog.show(
        context,
        title: l10n?.mv_plan_delete_confirm_title ?? 'حذف برنامهٔ ورزشی',
        content: l10n?.mv_plan_delete_confirm_desc ??
            'آیا از حذف برنامهٔ ورزشی این روز مطمئن هستید؟ این روز به عنوان استراحت ثبت خواهد شد.',
        confirmLabel: l10n?.mv_plan_delete_confirm ?? 'حذف برنامه',
        cancelLabel: l10n?.cancel ?? 'انصراف',
        icon: Icons.delete_outline_rounded,
        isDestructive: true,
      );

      if (confirmed != true || !mounted) return;

      if (widget.onDelete != null) {
        widget.onDelete!(widget.slot, false);
      } else {
        final now = DateTime.now().millisecondsSinceEpoch;
        final restSlot = widget.slot.copyWith(
          slotType: MvSlotType.rest,
          kindCode: null,
          targetMinutes: 0,
          plannedTime: null,
          headlineFa: 'روز استراحت و ریکاوری',
          isLocked: true,
          updatedAt: now,
        );
        widget.onSave(restSlot);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    final isRest = _slotType == MvSlotType.rest;
    final isSport =
        _slotType == MvSlotType.sport ||
        (_kind != null && _kind!.family == MovementFamily.sport);
    final isStrength =
        _slotType == MvSlotType.strength ||
        (_kind != null && _kind!.family == MovementFamily.strength);
    final needsVenue = _kind?.needsVenue == true;

    return MvSheetScaffold(
      title: l10n?.mv_day_plan_title ?? 'Day Plan',
      subtitle: _formatDateSubtitle(widget.slot.dateIso),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // نوع اسلات (۵ چیپ)
            Text(
              l10n?.mv_day_plan_type ?? 'Plan Type',
              style: textTheme.labelLarge?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allowedSlotTypes.map((type) {
                return MvChip(
                  key: ValueKey('slot_type_${type.code}'),
                  label: type.titleFa,
                  isSelected: _slotType == type,
                  onTap: () => _onSlotTypeChanged(type),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // ۱. انتخاب نوع ورزش (برای تمام حالت‌های غیر استراحت)
            if (!isRest) ...[
              Text(
                l10n?.mv_day_plan_kind_select ?? 'Activity Kind',
                style: textTheme.labelLarge?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              RitmoCard.neumorphic(
                key: const ValueKey('day_plan_kind_picker_tile'),
                onTap: _openKindPicker,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Text(
                      _kind?.emoji ?? '🏃',
                      style: textTheme.headlineSmall,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _kind?.titleFa ?? (l10n?.mv_day_plan_kind_picker_prompt ?? 'Select activity kind...'),
                            style: textTheme.bodyMedium?.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (_kind != null)
                            Text(
                              l10n?.mv_day_plan_met_factor(toPersianDigits(_kind!.baseMet.toString())) ?? 'MET Factor: ${_kind!.baseMet}',
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
                        size: 18,
                        color: colors.accent,
                      ),
                      label: Text(
                        l10n?.mv_day_plan_change ?? 'Change',
                        style: textTheme.labelMedium?.copyWith(
                          color: colors.accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // کارت توضیحات ورزش تخصصی (S8-T6)
            if (isSport && _kind != null) ...[
              RitmoCard.neumorphic(
                key: const ValueKey('mv_sport_kind_info_card'),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Text(_kind!.emoji, style: textTheme.titleLarge),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n?.mv_day_plan_custom_header(_kind!.titleFa) ?? 'Custom Sport ${_kind!.titleFa}',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n?.mv_day_plan_custom_desc(toPersianDigits(_kind!.baseMet.toString())) ??
                                'Specialized Sport (${_kind!.baseMet} MET)',
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
              const SizedBox(height: 16),
            ],

            if (_slotType != MvSlotType.rest) ...[
              // ۲. مدت پیشنهادی (چیپ‌های ۱۵/۳۰/۴۵/۶۰ دقیقه)
              Text(
                l10n?.mv_day_plan_target_minutes ?? 'Target Duration (min)',
                style: textTheme.labelLarge?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _durationOptions.map((d) {
                  return MvChip(
                    key: ValueKey('day_plan_duration_$d'),
                    label: '${toPersianDigits(d.toString())} ${l10n?.mv_unit_min ?? 'min'}',
                    isSelected: _minutes == d,
                    onTap: () => setState(() => _minutes = d),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // ۳. ساعت شروع (plannedTime) اختیاری
              Text(
                l10n?.mv_day_plan_start_time ?? 'Start Time (Optional)',
                style: textTheme.labelLarge?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              RitmoNeuSurface(
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      color: colors.textSecondary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _plannedTime != null
                          ? '${toPersianDigits(_plannedTime!.hour.toString().padLeft(2, '0'))}:${toPersianDigits(_plannedTime!.minute.toString().padLeft(2, '0'))}'
                          : (l10n?.mv_day_plan_not_set ?? 'Not Set'),
                      style: textTheme.bodyMedium?.copyWith(
                        color: _plannedTime != null
                            ? colors.textPrimary
                            : colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Fasting Quick Preset Chips
              if (_crossModuleSnapshot != null &&
                  _crossModuleSnapshot!.isFasting &&
                  _crossModuleSnapshot!.maghribTime != null) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (_crossModuleSnapshot!.goldenPreIftarWindow != null)
                      MvChip(
                        key: const ValueKey('fasting_chip_pre_iftar'),
                        icon: const Text('🌙', style: TextStyle(fontSize: 13)),
                        label:
                            'پیش از افطار (${_crossModuleSnapshot!.goldenPreIftarWindow})',
                        isSelected: _plannedTime != null &&
                            _intensity == MvIntensityTier.light,
                        onTap: () {
                          final parts =
                              _crossModuleSnapshot!.maghribTime!.split(':');
                          final h = int.tryParse(parts[0]) ?? 19;
                          final m = int.tryParse(parts[1]) ?? 0;
                          final maghribDt = DateTime(2026, 1, 1, h, m)
                              .subtract(const Duration(minutes: 45));
                          setState(() {
                            _plannedTime = TimeOfDay(
                              hour: maghribDt.hour,
                              minute: maghribDt.minute,
                            );
                            _intensity = MvIntensityTier.light;
                          });
                        },
                      ),
                    if (_crossModuleSnapshot!.goldenPostIftarWindow != null)
                      MvChip(
                        key: const ValueKey('fasting_chip_post_iftar'),
                        icon: const Text('✨', style: TextStyle(fontSize: 13)),
                        label:
                            'بعد از افطار (${_crossModuleSnapshot!.goldenPostIftarWindow})',
                        isSelected: _plannedTime != null &&
                            _intensity == MvIntensityTier.moderate,
                        onTap: () {
                          final parts =
                              _crossModuleSnapshot!.maghribTime!.split(':');
                          final h = int.tryParse(parts[0]) ?? 19;
                          final m = int.tryParse(parts[1]) ?? 0;
                          final postDt = DateTime(2026, 1, 1, h, m)
                              .add(const Duration(hours: 2));
                          setState(() {
                            _plannedTime = TimeOfDay(
                              hour: postDt.hour,
                              minute: postDt.minute,
                            );
                            _intensity = MvIntensityTier.moderate;
                          });
                        },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),

              // ۴. مکان (venueNote) — فقط اگر kind.needsVenue == true
              if (needsVenue) ...[
                Text(
                  l10n?.mv_day_plan_venue ?? 'Venue (Optional)',
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
                    hintText: l10n?.mv_day_plan_venue_hint ?? 'e.g. Sports Hall',
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
                l10n?.mv_day_plan_intensity ?? 'Workout Intensity',
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
                  l10n?.mv_day_plan_focus ?? 'Muscle Focus',
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
                  l10n?.mv_day_plan_repeat_weekly ?? 'Repeat Every Week',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  l10n?.mv_day_plan_repeat_weekly_desc ?? 'Repeat on this day weekly',
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
                l10n?.mv_day_plan_custom_title ?? 'Custom Title (Optional)',
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
      bottomAction: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MvPrimaryAction(
            key: const ValueKey('day_plan_save_action'),
            label: l10n?.mv_day_plan_save ?? 'Save Day Plan',
            icon: Icons.check_rounded,
            onPressed: _handleSave,
          ),
          if (!widget.slot.isRest) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              key: const ValueKey('day_plan_delete_action'),
              onPressed: _handleDelete,
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: colors.error,
              ),
              label: Text(
                l10n?.mv_plan_delete_action ?? 'حذف برنامهٔ این روز',
                style: textTheme.labelLarge?.copyWith(
                  color: colors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
