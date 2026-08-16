import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/application/movement_analytics_service.dart';
import 'package:ritmo/features/movement/application/strength_program_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_strength_day.dart';
import 'package:ritmo/features/movement/domain/models/movement_strength_program.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_screen_shell.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';
import 'package:ritmo/features/movement/presentation/movement_routes.dart';
import 'package:ritmo/features/movement/presentation/strength/widgets/why_this_program_block.dart';

/// صفحهٔ پیش‌نمایش و فعال‌سازی برنامهٔ قدرتی (StrengthProgramPreviewScreen)
class StrengthProgramPreviewScreen extends StatefulWidget {
  const StrengthProgramPreviewScreen({
    super.key,
    required this.program,
    required this.days,
    this.strengthService,
  });

  final MovementStrengthProgram program;
  final List<MovementStrengthDay> days;
  final StrengthProgramService? strengthService;

  @override
  State<StrengthProgramPreviewScreen> createState() => _StrengthProgramPreviewScreenState();
}

class _StrengthProgramPreviewScreenState extends State<StrengthProgramPreviewScreen> {
  late final StrengthProgramService _service;
  bool _isActivating = false;
  bool _isSampleExpanded = false;

  @override
  void initState() {
    super.initState();
    _service = widget.strengthService ?? StrengthProgramService();
  }

  Future<void> _handleActivate() async {
    setState(() => _isActivating = true);
    try {
      await _service.activateProgram(
        program: widget.program,
        days: widget.days,
      );

      MovementAnalyticsService.instance.logStrengthProgramActivated(
        totalWeeks: widget.program.totalWeeks,
        sessionsPerWeek: widget.program.daysPerWeek,
      );

      if (mounted) {
        unawaited(Navigator.of(context).pushNamedAndRemoveUntil(
          MovementRoutes.strengthHub,
          (route) => route.isFirst,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در فعال‌سازی برنامه: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isActivating = false);
      }
    }
  }

  String _getWeekdayName(int weekday) {
    const names = ['شنبه', '۱شنبه', '۲شنبه', '۳شنبه', '۴شنبه', '۵شنبه', 'جمعه'];
    if (weekday >= 1 && weekday <= 7) return names[weekday - 1];
    return 'روز $weekday';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    final week1Days = widget.days.where((d) => d.weekIndex == 1).toList();
    final sampleDay = week1Days.isNotEmpty ? week1Days.first : null;

    return MovementScreenShell(
      title: MovementStrings.strengthPreviewTitle,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: RitmoSpacing.md),

                    // ناحیهٔ ۱: عنوان و برچسب‌های مشخصات برنامه
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(RitmoSpacing.lg),
                      decoration: BoxDecoration(
                        color: sportsColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(RitmoRadius.card),
                        border: Border.all(color: sportsColor.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.program.name ?? 'برنامهٔ قدرت در خانه',
                            style: RitmoTextStyles.cardTitle(sportsColor).copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: RitmoSpacing.sm),
                          Wrap(
                            spacing: RitmoSpacing.sm,
                            runSpacing: RitmoSpacing.xs,
                            children: [
                              Chip(
                                label: Text('${toPersianDigits(widget.program.daysPerWeek)} روز در هفته'),
                                labelStyle: RitmoTextStyles.caption(colors.textPrimary),
                                backgroundColor: colors.surface,
                              ),
                              Chip(
                                label: Text('${toPersianDigits(widget.program.sessionMinutes)} دقیقه هر جلسه'),
                                labelStyle: RitmoTextStyles.caption(colors.textPrimary),
                                backgroundColor: colors.surface,
                              ),
                              Chip(
                                label: Text('دورهٔ ${toPersianDigits(widget.program.totalWeeks)} هفته‌ای'),
                                labelStyle: RitmoTextStyles.caption(colors.textPrimary),
                                backgroundColor: colors.surface,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: RitmoSpacing.lg),

                    // ناحیهٔ ۲: ۳ دلیل انطباق برنامه با مشخصات کاربر
                    WhyThisProgramBlock(program: widget.program),
                    const SizedBox(height: RitmoSpacing.lg),

                    // ناحیهٔ ۳: جدول زمان‌بندی هفتهٔ اول
                    Text(
                      'برنامهٔ هفتهٔ اول:',
                      style: RitmoTextStyles.sectionHeadline(colors.textPrimary),
                    ),
                    const SizedBox(height: RitmoSpacing.sm),
                    Material(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(RitmoRadius.card),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(RitmoRadius.card),
                          border: Border.all(color: colors.border),
                        ),
                        child: Column(
                          children: week1Days.map((day) {
                            return ListTile(
                              leading: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: sportsColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(RitmoRadius.pill),
                                ),
                                child: Text(
                                  _getWeekdayName(day.weekday),
                                  style: RitmoTextStyles.label(sportsColor),
                                ),
                              ),
                              title: Text(
                                day.name,
                                style: RitmoTextStyles.label(colors.textPrimary),
                              ),
                              subtitle: Text(
                                day.targetMuscles.join(' • '),
                                style: RitmoTextStyles.caption(colors.textSecondary),
                              ),
                              trailing: Text(
                                '${toPersianDigits(day.estimatedMinutes)} دقیقه',
                                style: RitmoTextStyles.caption(colors.textTertiary),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: RitmoSpacing.lg),

                    // ناحیهٔ ۴: نمونهٔ حرکات یک جلسه به صورت بازشونده
                    if (sampleDay != null) ...[
                      Material(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(RitmoRadius.card),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(RitmoRadius.card),
                            border: Border.all(color: colors.border),
                          ),
                          child: ExpansionTile(
                            initiallyExpanded: _isSampleExpanded,
                            onExpansionChanged: (exp) => setState(() => _isSampleExpanded = exp),
                            title: Text(
                              'نمونهٔ حرکات جلسهٔ اول (${sampleDay.name})',
                              style: RitmoTextStyles.label(colors.textPrimary),
                            ),
                            children: sampleDay.exercises.map((ex) {
                              return ListTile(
                                dense: true,
                                leading: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: colors.surfaceSunken,
                                  child: Text(
                                    toPersianDigits(ex.orderIndex + 1),
                                    style: RitmoTextStyles.caption(colors.textPrimary),
                                  ),
                                ),
                                title: Text(ex.nameFa, style: RitmoTextStyles.body(colors.textPrimary)),
                                subtitle: Text(
                                  '${toPersianDigits(ex.sets)} ست × ${toPersianDigits(ex.repsDisplay)} تکرار',
                                  style: RitmoTextStyles.caption(sportsColor),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: RitmoSpacing.lg),
                    ],

                    // ناحیهٔ ۵: منطق پیشرفت دوره به زبان ساده
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(RitmoSpacing.md),
                      decoration: BoxDecoration(
                        color: colors.surfaceSunken,
                        borderRadius: BorderRadius.circular(RitmoRadius.card),
                        border: Border.all(color: colors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            MovementStrings.strengthProgressionTitle,
                            style: RitmoTextStyles.label(colors.textPrimary).copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: RitmoSpacing.xs),
                          Text(
                            'در هفته‌های ۱ تا ۳ با حرکات آشنا می‌شوید و حجم تمرین تثبیت می‌شود. هفتهٔ ۴ هفتهٔ دِلود برای ریکاوری است و در هفته‌های ۵ و ۶ با افزایش تدریجی رکوردها به اوج آمادگی می‌رسید.',
                            style: RitmoTextStyles.caption(colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: RitmoSpacing.xl),
                  ],
                ),
              ),
            ),

            // ناحیهٔ ۶: دو CTA فعال‌سازی و تغییر پاسخ‌ها
            Padding(
              padding: const EdgeInsets.all(RitmoSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, MovementLayout.kPrimaryButtonHeight),
                        side: BorderSide(color: colors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(RitmoRadius.field),
                        ),
                      ),
                      child: Text(
                        MovementStrings.strengthPreviewChangeAnswers,
                        style: RitmoTextStyles.label(colors.textPrimary),
                      ),
                    ),
                  ),
                  const SizedBox(width: RitmoSpacing.md),
                  Expanded(
                    flex: 1,
                    child: ElevatedButton(
                      onPressed: _isActivating ? null : _handleActivate,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(48, MovementLayout.kPrimaryButtonHeight),
                        backgroundColor: sportsColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(RitmoRadius.field),
                        ),
                      ),
                      child: _isActivating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              MovementStrings.strengthPreviewActivate,
                              style: RitmoTextStyles.label(Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
