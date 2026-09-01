// lib/features/today/presentation/widgets/dashboard/ai_day_planner_launcher.dart

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/features/assistant/logic/day_plan_composer.dart';
import 'package:ritmo/features/assistant/logic/day_plan_template_service.dart';
import 'package:ritmo/features/assistant/models/day_plan_models.dart';
import 'package:ritmo/features/assistant/presentation/widgets/ai_day_planner_preview_sheet.dart';

/// میان‌بر «برنامه‌ریز هوشمند» صفحهٔ خانه.
///
/// کاربر روزش را در یک‌دو جمله تعریف می‌کند؛ ریتمو با درنظرگرفتن برنامه‌های
/// موجود پیش‌نویسی می‌سازد و همان پیش‌نمایش قابل‌ویرایش دستیار باز می‌شود.
/// اگر کاربر به یکی از قالب‌های ذخیره‌شده‌اش اشاره کند («مثل روز کاری‌م باشه»)،
/// همان قالب روی روز هدف می‌نشیند.
class AiDayPlannerLauncher {
  const AiDayPlannerLauncher._();

  static Future<void> open(
    BuildContext context, {
    required VoidCallback onSaved,
  }) async {
    final narration = await _askNarration(context);
    if (narration == null || narration.isEmpty || !context.mounted) return;

    final progress = ValueNotifier<String>('در حال آماده‌سازی…');
    BuildContext? progressCtx;

    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        progressCtx = ctx;
        return _ProgressDialog(progress: progress);
      },
    ).whenComplete(progress.dispose));

    DayPlanComposeResult? result;
    try {
      final composing = DayPlanComposer.compose(
        query: narration,
        targetDateStr: DateTime.now().toIso8601String().substring(0, 10),
        onProgress: (step) => progress.value = step,
      );
      // مکث کوتاه تا دیالوگ پیشرفت حتماً ساخته شود؛ وگرنه خطای فوری می‌تواند
      // دیالوگی را جا بگذارد که هنوز مرجعی برای بستنش نداریم.
      await Future<void>.delayed(const Duration(milliseconds: 150));
      result = await composing;
    } catch (e) {
      debugPrint('[AI_PLANNER] compose failed: $e');
    }

    final dialogCtx = progressCtx;
    if (dialogCtx != null && dialogCtx.mounted) {
      Navigator.pop(dialogCtx);
    }
    if (!context.mounted) return;

    if (result == null) {
      RitmoToast.show(
        context,
        'چیدن برنامه انجام نشد؛ چند لحظه بعد دوباره تلاش کن.',
        icon: Icons.error_outline_rounded,
        iconColor: context.colors.error,
      );
      return;
    }

    var draft = result.singleDraft;
    final multiDay = result.multiDayDrafts;
    if (draft == null && multiDay != null && multiDay.isNotEmpty) {
      draft = multiDay.first;
    }

    // اشاره به قالب ذخیره‌شده — همان آیتم‌ها روی روز هدف می‌نشینند.
    if (draft == null && result.isTemplateApply) {
      final name = result.applyTemplateName;
      if (name != null) {
        final template =
            await DayPlanTemplateService.instance.getTemplateByName(name);
        if (template != null) {
          draft = DayPlanDraft(
            planDate: result.applyTemplateDate ??
                DateTime.now().toIso8601String().substring(0, 10),
            items: template.items,
            questions: const [],
            suggestions: const [],
          );
          unawaited(
            DayPlanTemplateService.instance.recordTemplateUsage(template.id),
          );
        }
      }
    }

    if (!context.mounted) return;

    final finalDraft = draft;
    if (finalDraft == null) {
      RitmoToast.show(context, 'برنامه‌ای ساخته نشد؛ کمی دقیق‌تر توضیح بده.');
      return;
    }

    AiDayPlannerPreviewSheet.show(
      context,
      initialDraft: finalDraft,
      onSaved: onSaved,
    );
  }

  static Future<String?> _askNarration(BuildContext context) {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (ctx) {
        final colors = ctx.colors;

        return RitmoCustomDialog(
          title: 'برنامه‌ریز هوشمند',
          icon: CupertinoIcons.sparkles,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'روزت را در چند جمله تعریف کن؛ ریتمو با توجه به برنامه‌های موجود، چیدمان پیشنهادی را می‌سازد.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.6,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: RitmoSpacing.md),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 3,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  color: colors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'مثلاً: تا ۲ سرکارم، بعدش باشگاه، شب دو ساعت مطالعه',
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: colors.textTertiary,
                  ),
                  filled: true,
                  fillColor: colors.surfaceSunken,
                  contentPadding: const EdgeInsets.all(RitmoSpacing.md),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(RitmoRadius.field),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(RitmoRadius.field),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(RitmoRadius.field),
                    borderSide: BorderSide(color: colors.primary),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            RitmoSecondaryButton(
              label: 'انصراف',
              onPressed: () => Navigator.pop(ctx),
            ),
            const SizedBox(width: 10),
            RitmoPrimaryButton(
              label: 'بچین',
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            ),
          ],
        );
      },
    );
  }
}

/// دیالوگ پیشرفت — متنش را خود DayPlanComposer مرحله‌به‌مرحله به‌روز می‌کند.
class _ProgressDialog extends StatelessWidget {
  const _ProgressDialog({required this.progress});

  final ValueNotifier<String> progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return PopScope(
      canPop: false,
      child: RitmoCustomDialog(
        title: 'در حال پردازش هوشمند...',
        icon: CupertinoIcons.sparkles,
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoActivityIndicator(color: colors.textSecondary),
            const SizedBox(width: RitmoSpacing.md),
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: progress,
                builder: (_, value, _) => Text(
                  value,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.6,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
