import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/supplementary_sports/domain/prescription/session_prescription.dart';
import 'package:ritmo/features/supplementary_sports/domain/ss_session_completion_gateway.dart';
import 'package:ritmo/features/supplementary_sports/presentation/widgets/shared/primary_button.dart';

class SsLogSessionSheet extends StatefulWidget {
  const SsLogSessionSheet({
    super.key,
    required this.prescription,
  });

  final SessionPrescription prescription;

  @override
  State<SsLogSessionSheet> createState() => _SsLogSessionSheetState();
}

class _SsLogSessionSheetState extends State<SsLogSessionSheet> {
  late int _minutes;
  late int _rpe; // 3 to 9
  String _location = 'خانه';
  final _noteController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _minutes = widget.prescription.targetMinutes > 0 ? widget.prescription.targetMinutes : 45;
    _rpe = widget.prescription.intensityTier.targetRpe;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await SsSessionCompletionGateway.completeSession(
        dateIso: widget.prescription.dateIso,
        actualMinutes: _minutes,
        actualRpe: _rpe,
        location: _location,
        customNote: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
      );
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildFaceRpe(int rpeValue, String emoji, String labelFa, BuildContext context) {
    final colors = context.colors;
    final isSelected = _rpe == rpeValue;

    return GestureDetector(
      onTap: () => setState(() => _rpe = rpeValue),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colors.primary : colors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text(
              labelFa,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? colors.textPrimary : colors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsAccent = context.modules.sports;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ثبت تمرین امروز',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.prescription.headlineFa,
                style: TextStyle(
                  fontSize: 14,
                  color: sportsAccent,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Minutes Slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('مدت زمان', style: TextStyle(color: colors.textPrimary)),
                  Text(toPersianDigits('$_minutes دقیقه'), style: TextStyle(fontWeight: FontWeight.bold, color: sportsAccent)),
                ],
              ),
              Slider(
                value: _minutes.toDouble(),
                min: 5,
                max: 180,
                divisions: 35,
                activeColor: sportsAccent,
                inactiveColor: colors.border,
                onChanged: (val) => setState(() => _minutes = val.toInt()),
              ),
              const SizedBox(height: 24),

              // RPE Faces
              Text('چقدر سخت بود؟', style: TextStyle(color: colors.textPrimary)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildFaceRpe(3, '😌', 'خیلی سبک', context),
                  _buildFaceRpe(5, '🙂', 'سبک', context),
                  _buildFaceRpe(7, '😅', 'متوسط', context),
                  _buildFaceRpe(8, '🥵', 'سنگین', context),
                  _buildFaceRpe(9, '💀', 'خیلی سنگین', context),
                ],
              ),
              const SizedBox(height: 24),

              // Location
              Text('کجا تمرین کردی؟', style: TextStyle(color: colors.textPrimary)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: ['خانه', 'باشگاه', 'فضای باز', 'سایر'].map((loc) {
                  final isSelected = _location == loc;
                  return ChoiceChip(
                    label: Text(loc, style: const TextStyle()),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) setState(() => _location = loc);
                    },
                    selectedColor: sportsAccent.withValues(alpha: 0.2),
                    backgroundColor: colors.surfaceSunken,
                    labelStyle: TextStyle(color: isSelected ? sportsAccent : colors.textSecondary),
                    showCheckmark: false,
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Note
              TextField(
                controller: _noteController,
                decoration: InputDecoration(
                  hintText: 'یادداشت (اختیاری)',
                  hintStyle: TextStyle(color: colors.textSecondary),
                  filled: true,
                  fillColor: colors.surfaceSunken,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: TextStyle(color: colors.textPrimary),
              ),
              const SizedBox(height: 32),

              PrimaryButton(
                label: 'ثبت تمرین',
                isLoading: _isSaving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
