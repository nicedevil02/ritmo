import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/widgets/ritmo_adaptive_grid.dart';
import 'package:ritmo/core/util/ritmo_number.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_button.dart';
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
        RitmoToast.show(
          context,
          'وضعیت انرژی و حال شما با موفقیت ثبت شد ⚡',
          icon: Icons.bolt_rounded,
          iconColor: const Color(0xffD4A843),
        );
        Navigator.pop(context);
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
        RitmoAdaptiveGrid(
          minTileWidth: 80,
          spacing: 8,
          maxColumns: 3,
          children: EnergyLevel.values.map((level) {
            final isSelected = _selectedEnergy == level;
            final Color activeColor;
            final String emoji;

            if (level == EnergyLevel.low) {
              activeColor = colors.cautionAccent;
              emoji = '🪫';
            } else if (level == EnergyLevel.medium) {
              activeColor = colors.primary;
              emoji = '🔋';
            } else {
              activeColor = colors.success;
              emoji = '⚡';
            }

            return RitmoCard.neumorphic(
              isSelected: isSelected,
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
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 4),
                  Text(
                    level.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: RitmoTextStyles.caption(
                      isSelected ? activeColor : colors.textSecondary,
                    ).copyWith(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
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
        RitmoAdaptiveGrid(
          minTileWidth: 70,
          spacing: 8,
          maxColumns: 4,
          children: [
            for (final mood in Mood.values) ...[
              () {
                final isSelected = _selectedMood == mood;
                return RitmoCard.neumorphic(
                  isSelected: isSelected,
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
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(mood.emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(height: 4),
                      Text(
                        mood.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: RitmoTextStyles.caption(
                          isSelected ? colors.reflectionAccent : colors.textSecondary,
                        ).copyWith(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              }(),
            ],
          ],
        ),
        const SizedBox(height: RitmoSpacing.lg),

        // 3. Valence Slider
        RitmoCard.neumorphic(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'میزان خوشایی (رضایت ذهنی):',
                      style: RitmoTextStyles.titleMedium(colors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 8),
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
            ],
          ),
        ),
        const SizedBox(height: RitmoSpacing.lg),

        // 4. Note
        RitmoCard.neumorphicSunken(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: TextField(
            controller: _noteController,
            style: RitmoTextStyles.body(colors.textPrimary),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'توضیحات بیشتر یا علت این حس و حال (اختیاری)...',
              hintStyle: RitmoTextStyles.caption(colors.textSecondary.withValues(alpha: 0.5)),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: RitmoSpacing.xl),

        // Save button
        RitmoPrimaryButton(
          label: 'ثبت و ذخیره وضعیت کنونی',
          isLoading: _isSaving,
          onPressed: _isSaving ? null : _saveLogs,
        ),
      ],
    );
  }
}
