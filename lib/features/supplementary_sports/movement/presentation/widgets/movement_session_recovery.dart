// lib/features/supplementary_sports/movement/presentation/widgets/movement_session_recovery.dart
//
// دیالوگ بازیابی جلسهٔ ناتمام و شیت انتخاب ورزش.
// قبلاً هر دو داخل ss_movement_tab_screen.dart بودند.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_kind.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/widgets/movement_kind_selector.dart';

/// تصمیم کاربر دربارهٔ جلسهٔ زندهٔ ناتمام. `null` یعنی «بعداً».
enum MovementRecoveryChoice { resume, finish, discard }

/// دیالوگ بازیابی. برخلاف قبل، راه خروج دارد و دکمهٔ مخرب اول نیست.
Future<MovementRecoveryChoice?> showMovementSessionRecoveryDialog(
  BuildContext context, {
  String? kindTitle,
}) {
  return showDialog<MovementRecoveryChoice>(
    context: context,
    // قبلاً false بود و هیچ گزینهٔ «بعداً» هم وجود نداشت؛ یعنی تله.
    barrierDismissible: true,
    builder: (ctx) {
      final colors = ctx.colors;
      final accent = ctx.modules.sports;

      return Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: colors.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RitmoRadius.hero),
          ),
          title: Text(
            'جلسهٔ ناتمام داری',
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: colors.textPrimary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                kindTitle == null
                    ? 'یک جلسهٔ ورزشی باز مانده است.'
                    : 'جلسهٔ «$kindTitle» باز مانده است.',
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 13.5,
                  height: 1.6,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: RitmoSpacing.lg),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(RitmoRadius.field),
                    ),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(MovementRecoveryChoice.resume),
                  icon: const Icon(CupertinoIcons.play_fill, size: 18),
                  label: const Text(
                    'ادامهٔ جلسه',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: RitmoSpacing.sm),
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
                  onPressed: () => Navigator.of(ctx).pop(MovementRecoveryChoice.finish),
                  child: const Text(
                    'همین قدر را ذخیره کن',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: RitmoSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 44),
                      foregroundColor: colors.textSecondary,
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text(
                      'بعداً',
                      style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 13),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 44),
                      foregroundColor: colors.error,
                    ),
                    onPressed: () async {
                      // حذف جلسه قابل بازگرداندن نیست، پس تأیید می‌خواهد.
                      final confirmed = await _confirmDiscard(ctx);
                      if (!confirmed) return;
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop(MovementRecoveryChoice.discard);
                    },
                    child: const Text(
                      'دور بریز',
                      style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<bool> _confirmDiscard(BuildContext context) async {
  final colors = context.colors;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: colors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RitmoRadius.hero),
        ),
        title: Text(
          'جلسه دور ریخته شود؟',
          style: TextStyle(
            fontFamily: 'Vazirmatn',
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: colors.textPrimary,
          ),
        ),
        content: Text(
          'هیچ چیزی از این جلسه ذخیره نمی‌شود و قابل بازگرداندن نیست.',
          style: TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 13,
            height: 1.6,
            color: colors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(64, 44),
              foregroundColor: colors.textSecondary,
            ),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'انصراف',
              style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 13.5),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(64, 44),
              foregroundColor: colors.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'دور بریز',
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}

/// شیت انتخاب ورزش برای شروع جلسهٔ جدید.
Future<MovementKind?> showMovementKindPickerSheet(BuildContext context) {
  final colors = context.colors;

  return showModalBottomSheet<MovementKind>(
    context: context,
    isScrollControlled: true,
    backgroundColor: colors.surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(RitmoRadius.sheet)),
    ),
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            const SizedBox(height: RitmoSpacing.md),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: RitmoSpacing.sm,
                vertical: RitmoSpacing.sm,
              ),
              child: Row(
                children: [
                  const SizedBox(width: RitmoSpacing.sm),
                  Expanded(
                    child: Text(
                      'چه ورزشی را شروع می‌کنی؟',
                      style: TextStyle(
                        fontFamily: 'Vazirmatn',
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  // قبلاً راهی برای بستن شیت بدون انتخاب وجود نداشت.
                  IconButton(
                    tooltip: 'بستن',
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: Icon(CupertinoIcons.xmark, size: 18, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            Expanded(
              child: MovementKindSelector(
                selectedKind: null,
                onKindSelected: (kind) => Navigator.of(ctx).pop(kind),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
