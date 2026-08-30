import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/study/data/study_settings_repository.dart';

class StudySettingsSheet extends StatefulWidget {
  const StudySettingsSheet({super.key, required this.settings});

  final StudySettings settings;

  static Future<bool?> show(BuildContext context, {required StudySettings settings}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StudySettingsSheet(settings: settings),
    );
  }

  @override
  State<StudySettingsSheet> createState() => _StudySettingsSheetState();
}

class _StudySettingsSheetState extends State<StudySettingsSheet> {
  late bool _konkurMode;
  late bool _reviewEnabled;
  late bool _showInDashboard;

  @override
  void initState() {
    super.initState();
    _konkurMode = widget.settings.konkurMode;
    _reviewEnabled = widget.settings.reviewEnabled;
    _showInDashboard = widget.settings.showInDashboard;
  }

  Future<void> _toggleKonkurMode(bool val) async {
    if (val == _konkurMode) return;

    if (!val) {
      final confirm = await RitmoDialog.show(
        context,
        title: 'خروج از حالت کنکور',
        content: 'سرفصل‌ها، آزمون‌ها و روزشمار کنکورت پاک نمی‌شن؛ فقط پنهان می‌شن و هر وقت خواستی برمی‌گردن.',
        confirmLabel: 'خروج از کنکور',
        cancelLabel: 'انصراف',
      );
      if (confirm != true) return;
    }

    setState(() => _konkurMode = val);
    if (!mounted) return;
    Navigator.of(context).pop(val); // Dismiss bottom sheet and return new mode
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final isGlass = context.isGlassEnabled;
    final blur = context.glassBlurSigma.clamp(0.0, 50.0);
    const sheetRadius = BorderRadius.vertical(top: Radius.circular(28));

    final content = Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Symmetrical Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Leading (Right in RTL): Circular Tactile Close (X) Button
              GestureDetector(
                onTap: () {
                  RitmoHapticsPolicy.tap();
                  Navigator.pop(context);
                },
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isDark
                        ? colors.surfaceElevated.withValues(alpha: 0.85)
                        : colors.textPrimary.withValues(alpha: 0.07),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? colors.border.withValues(alpha: 0.35)
                          : colors.border.withValues(alpha: 0.15),
                      width: 0.85,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    CupertinoIcons.xmark,
                    size: 15,
                    color: colors.textSecondary,
                  ),
                ),
              ),

              // Center: Title
              Expanded(
                child: Text(
                  'تنظیمات درس و مطالعه',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ),

              // Trailing (Left in RTL): Symmetrical Spacer
              const SizedBox(width: 34, height: 34),
            ],
          ),
          Divider(color: colors.divider, height: 16),
          const SizedBox(height: 8),

          Material(
            color: colors.surfaceSunken,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colors.border.withValues(alpha: 0.3)),
            ),
            child: SwitchListTile(
              title: Text('حالت کنکور', style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary)),
              subtitle: Text('فعال‌سازی روزشمار، ضرایب دروس و آزمون‌های آزمایشی', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
              value: _konkurMode,
              activeTrackColor: colors.primary,
              onChanged: _toggleKonkurMode,
            ),
          ),
          const SizedBox(height: 8),

          Material(
            color: colors.surfaceSunken,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colors.border.withValues(alpha: 0.3)),
            ),
            child: SwitchListTile(
              title: Text('مرور فاصله‌دار (Spaced Repetition)', style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary)),
              subtitle: Text('یادآوری مباحث در فواصل زمانی علمی', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
              value: _reviewEnabled,
              activeTrackColor: colors.primary,
              onChanged: (val) async {
                setState(() => _reviewEnabled = val);
                await StudySettingsRepository.instance.updateSetting('study_review_enabled', val.toString());
              },
            ),
          ),
          const SizedBox(height: 8),

          Material(
            color: colors.surfaceSunken,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colors.border.withValues(alpha: 0.3)),
            ),
            child: SwitchListTile(
              title: Text('نمایش در داشبورد امروز', style: TextStyle(fontWeight: FontWeight.bold, color: colors.textPrimary)),
              value: _showInDashboard,
              activeTrackColor: colors.primary,
              onChanged: (val) async {
                setState(() => _showInDashboard = val);
                await StudySettingsRepository.instance.updateSetting('study_show_in_dashboard', val.toString());
              },
            ),
          ),
        ],
      ),
    );

    final sheetBody = Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        type: MaterialType.transparency,
        child: content,
      ),
    );

    if (!isGlass) {
      return Container(
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: sheetRadius,
          border: Border.all(
            color: isDark ? colors.border : colors.divider,
            width: 1.0,
          ),
        ),
        child: sheetBody,
      );
    }

    return ClipRRect(
      borderRadius: sheetRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.glassTint,
            borderRadius: sheetRadius,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.70),
              width: 1.0,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: sheetRadius,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: isDark ? 0.08 : 0.20),
                  Colors.white.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.45],
              ),
            ),
            child: sheetBody,
          ),
        ),
      ),
    );
  }
}
