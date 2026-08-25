import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import '../components/components.dart';

/// Sheet 4: "برنامهٔ روز" (ساخت و ویرایش برنامهٔ روز — Section 5.9).
class MvDayPlanSheet extends StatefulWidget {
  final MvSlot slot;
  final ValueChanged<MvSlot> onSave;

  const MvDayPlanSheet({
    super.key,
    required this.slot,
    required this.onSave,
  });

  static Future<void> show({
    required BuildContext context,
    required MvSlot slot,
    required ValueChanged<MvSlot> onSave,
  }) {
    return MvSheetScaffold.show(
      context: context,
      builder: (ctx) => MvDayPlanSheet(
        slot: slot,
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
  late MvSlotType _slotType;
  late int _minutes;
  late MvIntensityTier _intensity;
  late List<String> _focusCodes;
  late TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _slotType = widget.slot.slotType;
    _minutes = widget.slot.targetMinutes;
    _intensity = widget.slot.intensityTier;
    _focusCodes = List.from(widget.slot.focusCodes);
    _titleController = TextEditingController(text: widget.slot.headlineFa);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _handleSave() {
    final updated = widget.slot.copyWith(
      slotType: _slotType,
      targetMinutes: _minutes,
      intensityTier: _intensity,
      focusCodes: _focusCodes,
      headlineFa: _titleController.text.trim().isEmpty
          ? _slotType.titleFa
          : _titleController.text.trim(),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    widget.onSave(updated);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.ritmoColors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;

    return MvSheetScaffold(
      title: 'تنظیم برنامهٔ روز',
      subtitle: 'ویرایش مشخصات تمرین برای ${widget.slot.dateIso}',
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title Input
            Text('عنوان برنامه', style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
            SizedBox(height: metrics.spaceXs),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'مثلاً قدرت بالاتنه',
                filled: true,
                fillColor: colors.surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(metrics.radiusField),
                  borderSide: BorderSide(color: colors.border),
                ),
              ),
            ),
            SizedBox(height: metrics.spaceMd),

            // Slot Type
            Text('نوع برنامه', style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
            SizedBox(height: metrics.spaceXs),
            Wrap(
              spacing: metrics.spaceSm,
              runSpacing: metrics.spaceSm,
              children: MvSlotType.values.map((type) {
                return MvChip(
                  label: type.titleFa,
                  isSelected: _slotType == type,
                  onTap: () => setState(() => _slotType = type),
                );
              }).toList(),
            ),
            SizedBox(height: metrics.spaceMd),

            // Duration
            if (_slotType != MvSlotType.rest) ...[
              Text('مدت هدف (دقیقه)', style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
              SizedBox(height: metrics.spaceXs),
              Wrap(
                spacing: metrics.spaceSm,
                runSpacing: metrics.spaceSm,
                children: [15, 20, 30, 45, 60].map((d) {
                  return MvChip(
                    label: '$d دقیقه',
                    isSelected: _minutes == d,
                    onTap: () => setState(() => _minutes = d),
                  );
                }).toList(),
              ),
              SizedBox(height: metrics.spaceMd),

              // Intensity Tier
              Text('شدت تمرین', style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
              SizedBox(height: metrics.spaceXs),
              Wrap(
                spacing: metrics.spaceSm,
                runSpacing: metrics.spaceSm,
                children: MvIntensityTier.values.map((tier) {
                  return MvChip(
                    label: tier.titleFa,
                    isSelected: _intensity == tier,
                    onTap: () => setState(() => _intensity = tier),
                  );
                }).toList(),
              ),
              SizedBox(height: metrics.spaceMd),

              // Focus Muscle Groups
              Text('تمرکز عضلانی', style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
              SizedBox(height: metrics.spaceXs),
              Wrap(
                spacing: metrics.spaceSm,
                runSpacing: metrics.spaceSm,
                children: MvMuscleGroup.all.take(6).map((mg) {
                  final isSel = _focusCodes.contains(mg.code);
                  return MvChip(
                    label: mg.titleFa,
                    icon: Text(mg.emoji, style: const TextStyle(fontSize: 13)),
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
            ],
            SizedBox(height: metrics.spaceLg),
          ],
        ),
      ),
      bottomAction: MvPrimaryAction(
        label: 'ذخیره تغییرات',
        icon: Icons.check_rounded,
        onPressed: _handleSave,
      ),
    );
  }
}
