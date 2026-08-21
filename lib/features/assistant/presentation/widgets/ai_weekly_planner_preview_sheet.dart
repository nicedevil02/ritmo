// lib/features/assistant/presentation/widgets/ai_weekly_planner_preview_sheet.dart

import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/commands/command_plan.dart';
import 'package:ritmo/core/domain/commands/ritmo_command.dart';
import 'package:ritmo/core/domain/commands/ritmo_command_bus.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/features/assistant/logic/day_plan_validator.dart';
import 'package:ritmo/features/assistant/models/day_plan_models.dart';
import 'package:ritmo/features/assistant/presentation/widgets/ai_day_planner_preview_sheet.dart';
import 'package:shamsi_date/shamsi_date.dart';

class AiWeeklyPlannerPreviewSheet extends StatefulWidget {
  const AiWeeklyPlannerPreviewSheet({
    super.key,
    required this.initialDrafts,
    required this.onSaved,
  });
  final List<DayPlanDraft> initialDrafts;
  final VoidCallback onSaved;

  static void show(
    BuildContext context, {
    required List<DayPlanDraft> initialDrafts,
    required VoidCallback onSaved,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AiWeeklyPlannerPreviewSheet(
        initialDrafts: initialDrafts,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<AiWeeklyPlannerPreviewSheet> createState() =>
      _AiWeeklyPlannerPreviewSheetState();
}

class _AiWeeklyPlannerPreviewSheetState
    extends State<AiWeeklyPlannerPreviewSheet> {
  late List<DayPlanDraft> _drafts;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _drafts = List.from(widget.initialDrafts);
    _reValidateAll();
  }

  Future<void> _reValidateAll() async {
    final validated = <DayPlanDraft>[];
    for (final draft in _drafts) {
      final enriched = await DayPlanValidator.validateAndEnrich(draft: draft);
      validated.add(enriched);
    }
    if (mounted) {
      setState(() {
        _drafts = validated;
      });
    }
  }

  String _getFarsiDate(String planDate) {
    final dt = DateTime.tryParse(planDate) ?? DateTime.now();
    final j = Jalali.fromDateTime(dt);
    return '${j.day} ${j.formatter.mN}';
  }

  String _getDayName(String planDate) {
    final dt = DateTime.tryParse(planDate) ?? DateTime.now();
    final j = Jalali.fromDateTime(dt);
    switch (j.weekDay) {
      case 1:
        return 'شنبه';
      case 2:
        return 'یکشنبه';
      case 3:
        return 'دوشنبه';
      case 4:
        return 'سه‌شنبه';
      case 5:
        return 'چهارشنبه';
      case 6:
        return 'پنجشنبه';
      case 7:
        return 'جمعه';
      default:
        return '';
    }
  }

  Future<void> _saveWeeklyPlan() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final bus = RitmoCommandBus.instance;
      final plan = CommandPlan(
        id: 'plan_apply_week_${DateTime.now().millisecondsSinceEpoch}',
        titleFa: 'ثبت برنامهٔ هفتگی',
        steps: [
          PlanStep(
            commandId: 'planning.applyWeek',
            payload: {'drafts': _drafts.map((d) => d.toJson()).toList()},
          ),
        ],
      );

      final preview = await bus.preview(plan, personaId: 'goals');
      if (!mounted) return;
      if (preview.blockers.isNotEmpty) {
        RitmoToast.show(
          context,
          preview.blockers.first,
          icon: Icons.error_outline,
          iconColor: Colors.red,
        );
        return;
      }

      final result = await bus.execute(
        plan,
        personaId: 'goals',
        source: CommandSource.user,
      );
      if (!mounted) return;

      if (result.success) {
        Navigator.pop(context);
        widget.onSaved();
      } else {
        RitmoToast.show(
          context,
          result.errorMessage ?? 'خطا در ثبت برنامه هفتگی ❌',
          icon: Icons.error_outline,
          iconColor: Colors.red,
        );
      }
    } catch (e, st) {
      debugPrint('[WeeklyPlan] save failed: $e\n$st');
      if (mounted) {
        RitmoToast.show(
          context,
          'خطا در ذخیره‌سازی برنامه هفتگی ❌',
          icon: Icons.error_outline,
          iconColor: Colors.red,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: RitmoBreakpoints.sheetMaxHeight(context, factor: 0.9),
        ),
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handlebar
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.textSecondary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'پیش‌نمایش برنامه هفتگی',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_drafts.length} روز',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // List of days
                Expanded(
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _drafts.length,
                      itemBuilder: (context, index) {
                        final draft = _drafts[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: colors.card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : colors.border.withValues(alpha: 0.3),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: InkWell(
                              onTap: () async {
                                final edited =
                                    await AiDayPlannerPreviewSheet.showForResult(
                                      context,
                                      initialDraft: draft,
                                      mode: DayPlannerMode.draftOnly,
                                    );
                                if (edited != null && mounted) {
                                  setState(() => _drafts[index] = edited);
                                  await _reValidateAll();
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    // Date Block
                                    Container(
                                      width: 60,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.bg,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            _getDayName(draft.planDate),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: colors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _getFarsiDate(draft.planDate),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: colors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(width: 16),

                                    // Micro items summary
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (draft.items.isEmpty)
                                            Text(
                                              'برنامه‌ای ثبت نشده است',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: colors.textSecondary,
                                              ),
                                            )
                                          else
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 6,
                                              children: draft.items.map((item) {
                                                return Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: colors.bg,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    border: Border.all(
                                                      color: colors.border
                                                          .withValues(
                                                            alpha: 0.1,
                                                          ),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    '${item.title} (${item.resolvedTime ?? ''})',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: colors.textPrimary,
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                        ],
                                      ),
                                    ),

                                    Icon(
                                      Icons.arrow_forward_ios,
                                      color: colors.textSecondary,
                                      size: 14,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Footer Action
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  side: BorderSide(color: colors.border),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  'انصراف',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colors.primary,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: _isSaving ? null : _saveWeeklyPlan,
                                child: _isSaving
                                    ? const CupertinoActivityIndicator(
                                        color: Colors.white,
                                      )
                                    : const Text(
                                        'تأیید و ثبت برنامه‌ها',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'برنامهٔ هفته یک‌جا ثبت می‌شود؛ اگر مشکلی پیش بیاید هیچ روزی نیمه‌کاره ثبت نمی‌ماند.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
