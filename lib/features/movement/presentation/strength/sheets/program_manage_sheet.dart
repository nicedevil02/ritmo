import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/domain/models/movement_strength_program.dart';
import 'package:ritmo/features/movement/presentation/common/diff_list.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// شیت مدیریت برنامهٔ قدرتی با نمایش DiffList قبل از اعمال تغییرات
class ProgramManageSheet extends StatefulWidget {
  const ProgramManageSheet({
    super.key,
    required this.program,
    required this.onPauseToggle,
    required this.onFinishProgram,
    required this.onStartNewCycle,
    required this.onUpdateSettings,
  });

  final MovementStrengthProgram program;
  final VoidCallback onPauseToggle;
  final VoidCallback onFinishProgram;
  final VoidCallback onStartNewCycle;
  final Future<void> Function({required int newDays, required int newDuration}) onUpdateSettings;

  static Future<void> show(
    BuildContext context, {
    required MovementStrengthProgram program,
    required VoidCallback onPauseToggle,
    required VoidCallback onFinishProgram,
    required VoidCallback onStartNewCycle,
    required Future<void> Function({required int newDays, required int newDuration}) onUpdateSettings,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProgramManageSheet(
        program: program,
        onPauseToggle: onPauseToggle,
        onFinishProgram: onFinishProgram,
        onStartNewCycle: onStartNewCycle,
        onUpdateSettings: onUpdateSettings,
      ),
    );
  }

  @override
  State<ProgramManageSheet> createState() => _ProgramManageSheetState();
}

class _ProgramManageSheetState extends State<ProgramManageSheet> {
  late int _selectedDays;
  late int _selectedDuration;
  bool _showDiff = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedDays = widget.program.daysPerWeek;
    _selectedDuration = widget.program.sessionMinutes;
  }

  bool get _hasChanges =>
      _selectedDays != widget.program.daysPerWeek ||
      _selectedDuration != widget.program.sessionMinutes;

  List<MovementDiffItem> _computeDiffs() {
    final diffs = <MovementDiffItem>[];
    if (_selectedDays != widget.program.daysPerWeek) {
      diffs.add(const MovementDiffItem(
        id: 'days_diff',
        kind: MovementDiffKind.replaced,
        beforeText: 'تعداد روزهای تمرین در هفته',
        afterText: 'روزهای جدید بر اساس زمان در دسترس',
        reason: 'تنظیم تعداد روزهای تمرین در هفته',
      ));
    }
    if (_selectedDuration != widget.program.sessionMinutes) {
      diffs.add(const MovementDiffItem(
        id: 'duration_diff',
        kind: MovementDiffKind.shortened,
        beforeText: 'مدت زمان جلسه',
        afterText: 'مدت جدید هر جلسه',
        reason: 'تغییر حجم و مدت زمان تمرین',
      ));
    }
    return diffs;
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    try {
      await widget.onUpdateSettings(
        newDays: _selectedDays,
        newDuration: _selectedDuration,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return Material(
      color: colors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(RitmoRadius.sheet)),
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + RitmoSpacing.lg,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              const SizedBox(height: RitmoSpacing.md),
              Center(
                child: Container(
                  width: MovementLayout.kSheetHandleSize.width,
                  height: MovementLayout.kSheetHandleSize.height,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(RitmoRadius.pill),
                  ),
                ),
              ),
              const SizedBox(height: RitmoSpacing.lg),

              Text(
                MovementStrings.strengthManageTitle,
                style: RitmoTextStyles.sectionHeadline(colors.textPrimary),
              ),
              const SizedBox(height: RitmoSpacing.xs),
              Text(
                MovementStrings.strengthManageNoDeleteNotice,
                style: RitmoTextStyles.caption(colors.textSecondary),
              ),
              const SizedBox(height: RitmoSpacing.lg),

              if (!_showDiff) ...[
                // تنظیم روزهای هفته
                Text('تعداد روزهای تمرین در هفته:', style: RitmoTextStyles.label(colors.textPrimary)),
                const SizedBox(height: RitmoSpacing.xs),
                Row(
                  children: [2, 3, 4, 5].map((d) {
                    final isSel = _selectedDays == d;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Center(child: Text('$d روز')),
                          selected: isSel,
                          selectedColor: sportsColor.withValues(alpha: 0.2),
                          onSelected: (_) => setState(() => _selectedDays = d),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: RitmoSpacing.md),

                // تنظیم مدت هر جلسه
                Text('مدت هر جلسه:', style: RitmoTextStyles.label(colors.textPrimary)),
                const SizedBox(height: RitmoSpacing.xs),
                Row(
                  children: [20, 30, 45, 60].map((dur) {
                    final isSel = _selectedDuration == dur;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Center(child: Text('$dur د')),
                          selected: isSel,
                          selectedColor: sportsColor.withValues(alpha: 0.2),
                          onSelected: (_) => setState(() => _selectedDuration = dur),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: RitmoSpacing.lg),

                if (_hasChanges)
                  ElevatedButton(
                    onPressed: () => setState(() => _showDiff = true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: sportsColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, MovementLayout.kPrimaryButtonHeight),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RitmoRadius.field)),
                    ),
                    child: const Text('مشاهدهٔ پیش‌نمایش تغییرات'),
                  ),

                const Divider(height: RitmoSpacing.xl),

                // اکشن‌های وضعیت برنامه
                ListTile(
                  leading: Icon(
                    widget.program.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    color: colors.warning,
                  ),
                  title: Text(
                    widget.program.isPaused ? MovementStrings.strengthHubResume : MovementStrings.strengthManagePause,
                    style: RitmoTextStyles.label(colors.textPrimary),
                  ),
                  onTap: () {
                    widget.onPauseToggle();
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.refresh_rounded, color: sportsColor),
                  title: const Text(MovementStrings.strengthHubNewCycle),
                  onTap: () {
                    widget.onStartNewCycle();
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.stop_circle_outlined, color: colors.error),
                  title: Text(
                    MovementStrings.strengthManageFinish,
                    style: TextStyle(color: colors.error),
                  ),
                  onTap: () {
                    widget.onFinishProgram();
                    Navigator.of(context).pop();
                  },
                ),
              ] else ...[
                // نمایش DiffList قبل از ذخیره
                Text('پیش‌نمایش تغییرات:', style: RitmoTextStyles.cardTitle(colors.textPrimary)),
                const SizedBox(height: RitmoSpacing.sm),
                DiffList(items: _computeDiffs()),
                const SizedBox(height: RitmoSpacing.lg),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _showDiff = false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, MovementLayout.kPrimaryButtonHeight),
                          side: BorderSide(color: colors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RitmoRadius.field)),
                        ),
                        child: const Text('بازگشت'),
                      ),
                    ),
                    const SizedBox(width: RitmoSpacing.md),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(48, MovementLayout.kPrimaryButtonHeight),
                          backgroundColor: sportsColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RitmoRadius.field)),
                        ),
                        child: _isSaving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('تأیید و اعمال تغییرات'),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: RitmoSpacing.md),
            ],
          ),
        ),
      ),
    ));
  }
}
