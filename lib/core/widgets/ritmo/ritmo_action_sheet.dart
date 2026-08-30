import 'package:flutter/cupertino.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

/// مدل اکشن‌های اکشن‌شیت رسمی اکوسیستم اپل (Apple HIG Action Sheet Item)
class RitmoActionSheetItem {
  const RitmoActionSheetItem({
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
    this.isDefault = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isDestructive;
  final bool isDefault;
}

/// اکشن‌شیت رسمی اکوسیستم اپل (Apple HIG Action Sheet / Confirmation Dialog)
///
/// پیاده‌سازی ۱۰۰٪ نیتیو مطابق با دستورالعمل رسمی اپل (Apple Human Interface Guidelines):
/// - ارائه از طریق `showCupertinoModalPopup` با انیمیشن فنری فیزیکی اپل.
/// - ساختار دو کپسولی شناور با انحنای پیوسته (Continuous Smooth Corners).
/// - بدون آیکون در دکمه‌ها (صرفاً تایپوگرافی تمیز و متمرکز مطابق با استاندارد iOS).
/// - دکمه قرمز تخریبی (`Destructive`) در کپسول بالا و دکمه پیش‌فرض بولد در کپسول مستقل پایین.
class RitmoGlassActionSheet extends StatelessWidget {
  const RitmoGlassActionSheet({
    super.key,
    this.title,
    this.message,
    required this.actions,
    this.cancelLabel = 'انصراف',
    this.onCancel,
  });

  final String? title;
  final String? message;
  final List<RitmoActionSheetItem> actions;
  final String cancelLabel;
  final VoidCallback? onCancel;

  /// نمایش شیت تایید خروج و دور انداختن تغییرات ذخیره‌نشده (Discard Changes Action Sheet)
  static Future<bool?> showDiscard({
    required BuildContext context,
    String title = 'تغییرات ذخیره نشده‌اند',
    String message = 'آیا از خروج و حذف تغییرات اطمینان دارید؟',
    String discardLabel = 'حذف تغییرات',
    String continueEditingLabel = 'ادامه ویرایش',
  }) {
    RitmoHaptics.warning();
    return showCupertinoModalPopup<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: CupertinoActionSheet(
          title: title.isNotEmpty
              ? Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : null,
          message: message.isNotEmpty
              ? Text(
                  message,
                  style: const TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                )
              : null,
          actions: [
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                RitmoHaptics.tap();
                Navigator.of(ctx).pop(true);
              },
              child: Text(
                discardLabel,
                style: const TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () {
              RitmoHaptics.tap();
              Navigator.of(ctx).pop(false);
            },
            child: Text(
              continueEditingLabel,
              style: const TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// متد عمومی باز کردن اکشن‌شیت رسمی اپل
  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    String? message,
    required List<RitmoActionSheetItem> actions,
    String cancelLabel = 'انصراف',
  }) {
    RitmoHaptics.tap();
    return showCupertinoModalPopup<T>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: CupertinoActionSheet(
          title: title != null
              ? Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : null,
          message: message != null
              ? Text(
                  message,
                  style: const TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                )
              : null,
          actions: actions
              .map(
                (act) => CupertinoActionSheetAction(
                  isDestructiveAction: act.isDestructive,
                  isDefaultAction: act.isDefault,
                  onPressed: () {
                    RitmoHaptics.tap();
                    act.onPressed();
                  },
                  child: Text(
                    act.label,
                    style: const TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
              .toList(),
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () {
              RitmoHaptics.tap();
              Navigator.of(ctx).pop();
            },
            child: Text(
              cancelLabel,
              style: const TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: CupertinoActionSheet(
        title: title != null
            ? Text(
                title!,
                style: const TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              )
            : null,
        message: message != null
            ? Text(
                message!,
                style: const TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 12.5,
                  height: 1.4,
                ),
              )
            : null,
        actions: actions
            .map(
              (act) => CupertinoActionSheetAction(
                isDestructiveAction: act.isDestructive,
                isDefaultAction: act.isDefault,
                onPressed: act.onPressed,
                child: Text(
                  act.label,
                  style: const TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: onCancel ?? () => Navigator.of(context).pop(),
          child: Text(
            cancelLabel,
            style: const TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
