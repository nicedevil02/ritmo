import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/supplementary_sports/application/application.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import '../components/components.dart';

/// Sheet: "ورزش سفارشی جدید" (S1-T8 & Section 5.9).
class MvCustomKindSheet extends StatefulWidget {
  final MvKindUseCase? useCase;
  final ValueChanged<MvMovementKind>? onSaved;

  const MvCustomKindSheet({
    super.key,
    this.useCase,
    this.onSaved,
  });

  static Future<MvMovementKind?> show({
    required BuildContext context,
    MvKindUseCase? useCase,
    ValueChanged<MvMovementKind>? onSaved,
  }) {
    return MvSheetScaffold.show<MvMovementKind>(
      context: context,
      builder: (ctx) => MvCustomKindSheet(
        useCase: useCase,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<MvCustomKindSheet> createState() => _MvCustomKindSheetState();
}

class _MvCustomKindSheetState extends State<MvCustomKindSheet> {
  late final MvKindUseCase _useCase;
  final _titleController = TextEditingController();

  static const List<String> _emojiOptions = [
    '⚽', '🏀', '🏐', '🎾', '🏸', '🏓', '🥊', '🥋',
    '🏋️', '🧘', '🧗', '⛷️', '🛹', '🚣', '🏊', '🚴',
    '🏃', '🚶', '🏇', '🎯',
  ];

  static const List<MovementFamily> _allowedFamilies = [
    MovementFamily.sport,
    MovementFamily.outdoor,
    MovementFamily.endurance,
    MovementFamily.strength,
    MovementFamily.martialSkill,
    MovementFamily.mindBody,
  ];

  static const List<MovementMetric> _metricOptions = [
    MovementMetric.duration,
    MovementMetric.distance,
    MovementMetric.sets,
    MovementMetric.laps,
  ];

  String _selectedEmoji = '⚽';
  MovementFamily _selectedFamily = MovementFamily.sport;
  double _baseMet = 6.0;
  MovementMetric _selectedMetric = MovementMetric.duration;
  bool _needsVenue = false;
  bool _isOutdoor = false;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _useCase = widget.useCase ?? MvKindUseCase();
    _updateDefaultMetForFamily(_selectedFamily);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _updateDefaultMetForFamily(MovementFamily family) {
    switch (family) {
      case MovementFamily.sport:
        _baseMet = 6.0;
        break;
      case MovementFamily.outdoor:
        _baseMet = 5.0;
        break;
      case MovementFamily.endurance:
        _baseMet = 7.0;
        break;
      case MovementFamily.strength:
        _baseMet = 4.5;
        break;
      case MovementFamily.martialSkill:
        _baseMet = 6.5;
        break;
      case MovementFamily.mindBody:
        _baseMet = 3.0;
        break;
      case MovementFamily.daily:
        _baseMet = 2.5;
        break;
    }
  }

  String _formatMetricTitle(MovementMetric metric) {
    switch (metric) {
      case MovementMetric.duration:
        return 'فقط زمان (دقیقه)';
      case MovementMetric.distance:
        return 'مسافت (کیلومتر)';
      case MovementMetric.sets:
        return 'ست و تکرار';
      case MovementMetric.laps:
        return 'دور / طول';
      default:
        return metric.unitFa;
    }
  }

  Future<void> _handleSave() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _errorMessage = 'لطفاً نام ورزش را وارد کنید');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isSaving = true;
    });

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final code = 'CUSTOM_${now.toString().substring(6)}';

      final kind = MvMovementKind(
        code: code,
        titleFa: title,
        emoji: _selectedEmoji,
        family: _selectedFamily,
        baseMet: _baseMet,
        metLow: (_baseMet * 0.8).clamp(1.0, 20.0),
        metHigh: (_baseMet * 1.2).clamp(1.0, 20.0),
        primaryMetric: _selectedMetric,
        isOutdoor: _isOutdoor,
        isSocial: false,
        needsVenue: _needsVenue,
        jointImpact: 1,
        isCustom: true,
        isEnabled: true,
        usageCount: 0,
        sortOrder: 999,
      );

      await _useCase.saveCustomKind(kind);
      widget.onSaved?.call(kind);

      if (mounted) {
        Navigator.pop(context, kind);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'خطا در ذخیره‌سازی: $e';
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.ritmoColors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;

    return MvSheetScaffold(
      title: 'ورزش سفارشی جدید',
      subtitle: 'ورزش یا فعالیت دلخواهت را به کتابخانه اضافه کن',
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ۱. نام فارسی (اجباری)
            Text(
              'نام ورزش یا فعالیت',
              style: textTheme.labelLarge?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: metrics.spaceXs),
            TextField(
              key: const ValueKey('custom_kind_title_field'),
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'مثلاً پدل، اسکواش، تیراندازی...',
                errorText: _errorMessage,
                filled: true,
                fillColor: colors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(metrics.radiusField),
                  borderSide: BorderSide(color: colors.border),
                ),
              ),
            ),
            SizedBox(height: metrics.spaceMd),

            // ۲. انتخاب ایموجی
            Text(
              'انتخاب نماد (ایموجی)',
              style: textTheme.labelLarge?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: metrics.spaceSm),
            Wrap(
              spacing: metrics.spaceSm,
              runSpacing: metrics.spaceSm,
              children: _emojiOptions.map((em) {
                final isSel = em == _selectedEmoji;
                return InkWell(
                  key: ValueKey('emoji_$em'),
                  onTap: () => setState(() => _selectedEmoji = em),
                  borderRadius: BorderRadius.circular(metrics.radiusField),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSel ? colors.primary.withValues(alpha: 0.15) : colors.surface,
                      borderRadius: BorderRadius.circular(metrics.radiusField),
                      border: Border.all(
                        color: isSel ? colors.primary : colors.border,
                        width: isSel ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(em, style: textTheme.headlineSmall),
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: metrics.spaceMd),

            // ۳. خانواده ورزش
            Text(
              'دسته‌بندی (خانواده)',
              style: textTheme.labelLarge?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: metrics.spaceSm),
            Wrap(
              spacing: metrics.spaceSm,
              runSpacing: metrics.spaceSm,
              children: _allowedFamilies.map((fam) {
                final isSel = fam == _selectedFamily;
                return MvChip(
                  key: ValueKey('family_${fam.name}'),
                  label: fam.titleFa,
                  isSelected: isSel,
                  onTap: () {
                    setState(() {
                      _selectedFamily = fam;
                      _updateDefaultMetForFamily(fam);
                    });
                  },
                );
              }).toList(),
            ),
            SizedBox(height: metrics.spaceMd),

            // ۴. MET تقریبی
            Text(
              'شدت انرژی متابولیک (MET): ${toPersianDigits(_baseMet.toStringAsFixed(1))}',
              style: textTheme.labelLarge?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            Slider(
              key: const ValueKey('custom_kind_met_slider'),
              value: _baseMet,
              min: 1.5,
              max: 14.0,
              divisions: 25,
              label: toPersianDigits(_baseMet.toStringAsFixed(1)),
              onChanged: (val) => setState(() => _baseMet = val),
            ),
            SizedBox(height: metrics.spaceSm),

            // ۵. متریک اولیه
            Text(
              'متریک ثبت اصلی',
              style: textTheme.labelLarge?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: metrics.spaceSm),
            Wrap(
              spacing: metrics.spaceSm,
              runSpacing: metrics.spaceSm,
              children: _metricOptions.map((met) {
                final isSel = met == _selectedMetric;
                return MvChip(
                  key: ValueKey('metric_${met.name}'),
                  label: _formatMetricTitle(met),
                  isSelected: isSel,
                  onTap: () => setState(() => _selectedMetric = met),
                );
              }).toList(),
            ),
            SizedBox(height: metrics.spaceMd),

            // ۶. چک‌باکس‌ها
            SwitchListTile.adaptive(
              key: const ValueKey('custom_kind_needs_venue'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                'نیاز به سالن یا زمین اختصاصی دارد',
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              value: _needsVenue,
              onChanged: (val) => setState(() => _needsVenue = val),
            ),
            SwitchListTile.adaptive(
              key: const ValueKey('custom_kind_is_outdoor'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                'در فضای باز انجام می‌شود',
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              value: _isOutdoor,
              onChanged: (val) => setState(() => _isOutdoor = val),
            ),
            SizedBox(height: metrics.spaceLg),
          ],
        ),
      ),
      bottomAction: MvPrimaryAction(
        key: const ValueKey('custom_kind_save_action'),
        label: 'افزودن به ورزش‌ها',
        icon: Icons.add_circle_outline_rounded,
        isLoading: _isSaving,
        onPressed: _handleSave,
      ),
    );
  }
}
