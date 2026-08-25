// lib/features/supplementary_sports/movement/presentation/widgets/movement_session_recovery.dart
//
// دیالوگ بازیابی جلسهٔ ناتمام + شیت انتخاب نوع ورزش

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_kind.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/widgets/movement_kind_selector.dart';

enum MovementRecoveryChoice { resume, finish, discard }

// ─── دیالوگ بازیابی ──────────────────────────────────────────────────────────────────────────────────────

/// نسخهٔ قبلی با `barrierDismissible: false` و بدون گزینهٔ بعداً، کاربر را مجبور به
/// حذف یا پایان می‌کرد. حالا `null` برمی‌گرداند و برنامه ادامه می‌یابد.
Future<MovementRecoveryChoice?> showMovementSessionRecoveryDialog(
  BuildContext context, {
  String? kindTitle,
}) {
  return showDialog<MovementRecoveryChoice>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: _RecoveryDialog(kindTitle: kindTitle),
    ),
  );
}

class _RecoveryDialog extends StatelessWidget {
  const _RecoveryDialog({this.kindTitle});
  final String? kindTitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = context.modules.sports;

    final title = kindTitle != null
        ? 'جلسهٔ «$kindTitle» ناتمام است'
        : 'جلسهٔ ناتمام پیدا شد';

    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RitmoRadius.sheet),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'Vazirmatn',
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: colors.textPrimary,
        ),
      ),
      // دکمه‌ها در content (نه actions) — برای کنترل کامل ارتفاع و ترتیب
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'می‌خواهی با این جلسه چه کار کنی؟',
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 14,
              height: 1.5,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),

          // ۱. ادامهٔ جلسه — اول و پرکنتراست
          SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(RitmoRadius.field),
                ),
              ),
              onPressed: () =>
                  Navigator.of(context).pop(MovementRecoveryChoice.resume),
              child: const Text(
                'ادامهٔ جلسه',
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ۲. پایان و ذخیره — خنثی
          SizedBox(
            height: 48,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.textPrimary,
                side: BorderSide(color: colors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(RitmoRadius.field),
                ),
              ),
              onPressed: () =>
                  Navigator.of(context).pop(MovementRecoveryChoice.finish),
              child: const Text(
                'پایان و ذخیره',
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ۳. حذف جلسه — آخر، مخرب، با تأیید تودرتو
          SizedBox(
            height: 48,
            child: TextButton(
              style: TextButton.styleFrom(foregroundColor: colors.error),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (confirmCtx) => Directionality(
                    textDirection: TextDirection.rtl,
                    child: AlertDialog(
                      backgroundColor: colors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(RitmoRadius.card),
                      ),
                      title: Text(
                        'حذف جلسه؟',
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      content: Text(
                        'این جلسه برای همیشه حذف می‌شود و قابل بازگشت نیست.',
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 13,
                          color: colors.textSecondary,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(confirmCtx).pop(false),
                          child: Text(
                            'انصراف',
                            style: TextStyle(
                              fontFamily: 'Vazirmatn',
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(confirmCtx).pop(true),
                          child: Text(
                            'بله، حذف شود',
                            style: TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontWeight: FontWeight.bold,
                              color: colors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
                if ((confirmed ?? false) && context.mounted) {
                  Navigator.of(context).pop(MovementRecoveryChoice.discard);
                }
              },
              child: const Text(
                'حذف جلسه',
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),

          // بعداً — برای شفافیت، بازگشت null
          Center(
            child: TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(120, 44),
                foregroundColor: colors.textTertiary,
              ),
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text(
                'بعداً تصمیم می‌گیرم',
                style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── شیت انتخاب نوع ورزش ──────────────────────────────────────────────────────────────────────────────

Future<MovementKind?> showMovementKindPickerSheet(BuildContext context) async {
  MovementKind? result;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) {
          final colors = ctx.colors;
          return Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(RitmoRadius.sheet),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: RitmoSpacing.sm),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: RitmoSpacing.md),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: RitmoSpacing.lg,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'شروع جلسهٔ جدید: انتخاب ورزش',
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: colors.textPrimary,
                        ),
                      ),
                      IconButton(
                        tooltip: 'بستن',
                        icon: Icon(
                          CupertinoIcons.xmark_circle_fill,
                          color: colors.textSecondary,
                        ),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: colors.divider),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(RitmoSpacing.lg),
                    child: MovementKindSelector(
                      selectedKind: null,
                      onKindSelected: (kind) {
                        result = kind;
                        Navigator.of(ctx).pop();
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
  return result;
}
