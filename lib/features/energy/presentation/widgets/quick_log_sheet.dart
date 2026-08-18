import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/util/ritmo_number.dart';
import 'package:ritmo/features/energy/models/energy_mood_models.dart';
import 'package:ritmo/features/wellbeing/logic/wellbeing_log_gateway.dart';

class QuickLogSheet extends StatefulWidget {
  const QuickLogSheet({super.key, required this.onSaved});
  final VoidCallback onSaved;

  @override
  State<QuickLogSheet> createState() => _QuickLogSheetState();
}

class _QuickLogSheetState extends State<QuickLogSheet> {
  EnergyLevel? _selectedEnergy;
  Mood? _selectedMood;
  double _valence = 3;
  final TextEditingController _noteController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveLogs() async {
    if (_selectedEnergy == null && _selectedMood == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'لطفاً حداقل یکی از موارد (انرژی یا حال روحی) را انتخاب کنید.',
            style: TextStyle(),
          ),
          backgroundColor: context.colors.cautionAccent,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final noteText = _noteController.text.trim();
      final now = DateTime.now();

      // ۱. ثبت انرژی از طریق درگاه یکپارچه
      if (_selectedEnergy != null) {
        await WellbeingLogGateway.instance.logEnergy(
          level: _selectedEnergy!,
          source: 'quick_sheet',
          now: now,
        );
      }

      // ۲. ثبت حال روحی از طریق درگاه یکپارچه
      if (_selectedMood != null) {
        await WellbeingLogGateway.instance.logMood(
          score: _valence.toInt(),
          note: noteText.isNotEmpty ? noteText : null,
          source: 'quick_sheet',
          now: now,
        );
      }

      await HapticFeedback.mediumImpact();
      widget.onSaved();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'وضعیت انرژی و حال شما با موفقیت ثبت شد ⚡',
              style: TextStyle(),
            ),
            backgroundColor: context.colors.primary,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving logs: $e');
    }

    if (mounted) {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Energy Level
        Text(
          '⚡ سطح انرژی فیزیکی بدنی شما:',
          style: RitmoTextStyles.titleMedium(colors.textPrimary),
        ),
        const SizedBox(height: 8),
        Row(
          children: EnergyLevel.values.map((level) {
            final isSelected = _selectedEnergy == level;
            Color activeColor;
            String emoji;
            if (level == EnergyLevel.low) {
              activeColor = colors.cautionAccent;
              emoji = '🥱';
            } else if (level == EnergyLevel.medium) {
              activeColor = colors.primary;
              emoji = '🔋';
            } else {
              activeColor = colors.success;
              emoji = '⚡';
            }

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (_selectedEnergy == level) {
                      _selectedEnergy = null;
                    } else {
                      _selectedEnergy = level;
                    }
                  });
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? activeColor.withValues(alpha: 0.15)
                        : colors.surface,
                    borderRadius: BorderRadius.circular(RitmoRadius.card),
                    border: Border.all(
                      color: isSelected ? activeColor : colors.border,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(height: 4),
                      Text(
                        level.label,
                        style: RitmoTextStyles.caption(
                          isSelected ? activeColor : colors.textSecondary,
                        ).copyWith(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: RitmoSpacing.lg),

        // 2. Mood Grid
        Text(
          '🎭 احساس و حال روحی:',
          style: RitmoTextStyles.titleMedium(colors.textPrimary),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 1.1,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
          ),
          itemCount: Mood.values.length,
          itemBuilder: (context, index) {
            final mood = Mood.values[index];
            final isSelected = _selectedMood == mood;

            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  if (_selectedMood == mood) {
                    _selectedMood = null;
                  } else {
                    _selectedMood = mood;
                    _valence = mood.defaultValence.toDouble();
                  }
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.reflectionAccent.withValues(alpha: 0.15)
                      : colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? colors.reflectionAccent : colors.border,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(mood.emoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(height: 4),
                    Text(
                      mood.label,
                      style: RitmoTextStyles.caption(
                        isSelected ? colors.reflectionAccent : colors.textSecondary,
                      ).copyWith(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: RitmoSpacing.lg),

        // 3. Valence Slider
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'میزان خوشایی (رضایت ذهنی):',
              style: RitmoTextStyles.titleMedium(colors.textPrimary),
            ),
            Text(
              '${RitmoNumber.faInt(_valence.toInt())} از ۵',
              style: RitmoTextStyles.label(colors.reflectionAccent),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Slider(
          value: _valence,
          min: 1,
          max: 5,
          divisions: 4,
          activeColor: colors.reflectionAccent,
          inactiveColor: colors.border,
          onChanged: (v) {
            setState(() {
              _valence = v;
            });
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('خیلی ناخوشایند 😞', style: RitmoTextStyles.caption(colors.textSecondary)),
            Text('خنثی 😐', style: RitmoTextStyles.caption(colors.textSecondary)),
            Text('خیلی خوشایند 🥰', style: RitmoTextStyles.caption(colors.textSecondary)),
          ],
        ),
        const SizedBox(height: RitmoSpacing.lg),

        // 4. Note
        TextField(
          controller: _noteController,
          style: RitmoTextStyles.body(colors.textPrimary),
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'توضیحات بیشتر یا علت این حس و حال (اختیاری)...',
            hintStyle: RitmoTextStyles.caption(colors.textSecondary.withValues(alpha: 0.5)),
            fillColor: colors.surface,
            filled: true,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(RitmoRadius.card),
              borderSide: BorderSide(color: colors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(RitmoRadius.card),
              borderSide: BorderSide(color: colors.primary),
            ),
          ),
        ),
        const SizedBox(height: RitmoSpacing.xl),

        // Save button
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: colors.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(RitmoRadius.card),
            ),
          ),
          onPressed: _isSaving ? null : _saveLogs,
          child: _isSaving
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: colors.onPrimary,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  'ثبت و ذخیره وضعیت کنونی',
                  style: RitmoTextStyles.label(colors.onPrimary),
                ),
        ),
      ],
    );
  }
}
