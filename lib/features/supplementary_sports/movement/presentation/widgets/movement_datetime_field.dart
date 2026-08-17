// lib/features/supplementary_sports/movement/presentation/widgets/movement_datetime_field.dart
//
// انتخاب «زمان انجام فعالیت» در مرکز حرکت.
//
// تا پیش از این، شیت ثبت فعالیت هیچ کنترلی برای تغییر زمان نداشت و
// دکمهٔ «ثبت فعالیت انجام‌شده» عملاً فقط «همین الان» را ذخیره می‌کرد؛
// یعنی کاربر نمی‌توانست تمرین دیشب یا صبح امروز را ثبت کند.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_date_picker.dart';
import 'package:shamsi_date/shamsi_date.dart';

/// نام ماه‌های شمسی برای ساخت برچسب‌های خوانا.
const List<String> kJalaliMonthNames = <String>[
  'فروردین',
  'اردیبهشت',
  'خرداد',
  'تیر',
  'مرداد',
  'شهریور',
  'مهر',
  'آبان',
  'آذر',
  'دی',
  'بهمن',
  'اسفند',
];

/// روز را به‌صورت «امروز»، «دیروز» یا «۱۲ مرداد» برمی‌گرداند.
String movementRelativeDayLabel(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(dt.year, dt.month, dt.day);
  final diff = target.difference(today).inDays;
  if (diff == 0) return 'امروز';
  if (diff == -1) return 'دیروز';
  if (diff == -2) return 'پریروز';
  if (diff == 1) return 'فردا';
  final j = Jalali.fromDateTime(target);
  return '${j.day.toPersianDigits()} ${kJalaliMonthNames[j.month - 1]}';
}

/// ساعت دو رقمی با اعداد فارسی، مثل «۱۸:۳۰».
String movementClockLabel(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m'.toPersianDigits();
}

/// برچسب کامل، مثل «امروز · ۱۸:۳۰».
String movementDateTimeLabel(DateTime dt) =>
    '${movementRelativeDayLabel(dt)} · ${movementClockLabel(dt)}';

/// فیلد انتخاب زمان فعالیت: میان‌برهای سریع + تاریخ شمسی + ساعت.
class MovementDateTimeField extends StatelessWidget {
  const MovementDateTimeField({
    super.key,
    required this.value,
    required this.onChanged,
    this.accent,
  });

  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final Color? accent;

  /// چند دقیقه اختلاف با «الان» را آینده حساب نکن (تا لرزش ساعت آزاردهنده نشود).
  static const Duration _futureTolerance = Duration(minutes: 2);

  bool get isFuture => value.isAfter(DateTime.now().add(_futureTolerance));

  DateTime _combine(DateTime date, DateTime time) =>
      DateTime(date.year, date.month, date.day, time.hour, time.minute);

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await RitmoDatePicker.show(
      context: context,
      initialDate: value.isAfter(now) ? now : value,
      firstDate: now.subtract(const Duration(days: 400)),
      lastDate: now,
    );
    if (picked == null) return;
    onChanged(_combine(picked, value));
  }

  Future<void> _pickTime(BuildContext context) async {
    final colors = context.colors;
    var temp = value;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(RitmoRadius.sheet),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    RitmoSpacing.lg,
                    RitmoSpacing.md,
                    RitmoSpacing.lg,
                    0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ساعت انجام فعالیت',
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: colors.textPrimary,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text(
                          'تأیید',
                          style: TextStyle(
                            fontFamily: 'Vazirmatn',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // ترتیب ساعت:دقیقه در RTL جابه‌جا می‌شود؛ چرخ را LTR نگه می‌داریم.
                SizedBox(
                  height: 190,
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.time,
                      initialDateTime: value,
                      use24hFormat: true,
                      onDateTimeChanged: (d) => temp = d,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true) onChanged(_combine(value, temp));
  }

  void _apply(DateTime next) {
    HapticFeedback.selectionClick();
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accentColor = accent ?? context.modules.sports;
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'چه زمانی انجام شد؟',
          style: TextStyle(
            fontFamily: 'Vazirmatn',
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: RitmoSpacing.sm),

        // میان‌برهای پرکاربرد: بیشتر ثبت‌ها یکی از همین چهار حالت است.
        Wrap(
          spacing: RitmoSpacing.sm,
          runSpacing: RitmoSpacing.sm,
          children: [
            _QuickChip(
              label: 'الان',
              accent: accentColor,
              isSelected: now.difference(value).abs() < const Duration(minutes: 3),
              onTap: () => _apply(DateTime.now()),
            ),
            _QuickChip(
              label: 'نیم ساعت پیش',
              accent: accentColor,
              isSelected: false,
              onTap: () => _apply(
                DateTime.now().subtract(const Duration(minutes: 30)),
              ),
            ),
            _QuickChip(
              label: '۲ ساعت پیش',
              accent: accentColor,
              isSelected: false,
              onTap: () => _apply(
                DateTime.now().subtract(const Duration(hours: 2)),
              ),
            ),
            _QuickChip(
              label: 'دیروز، همین ساعت',
              accent: accentColor,
              isSelected: false,
              onTap: () => _apply(
                DateTime.now().subtract(const Duration(days: 1)),
              ),
            ),
          ],
        ),
        const SizedBox(height: RitmoSpacing.md),

        // انتخاب دقیق: تاریخ و ساعت، هر کدام یک هدف لمسی مستقل.
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _PickerTile(
                icon: CupertinoIcons.calendar,
                label: movementRelativeDayLabel(value),
                accent: accentColor,
                onTap: () => _pickDate(context),
              ),
            ),
            const SizedBox(width: RitmoSpacing.sm),
            Expanded(
              flex: 2,
              child: _PickerTile(
                icon: CupertinoIcons.clock,
                label: movementClockLabel(value),
                accent: accentColor,
                onTap: () => _pickTime(context),
              ),
            ),
          ],
        ),

        if (isFuture) ...[
          const SizedBox(height: RitmoSpacing.sm),
          Row(
            children: [
              Icon(
                CupertinoIcons.exclamationmark_triangle_fill,
                size: 14,
                color: colors.warning,
              ),
              const SizedBox(width: RitmoSpacing.xs),
              Expanded(
                child: Text(
                  'این زمان در آینده است. برای برنامه‌ریزی از «افزودن به برنامه» استفاده کن.',
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 12,
                    color: colors.warning,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.accent,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final Color accent;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(RitmoRadius.pill),
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(
            horizontal: RitmoSpacing.md,
            vertical: RitmoSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? accent.withValues(alpha: 0.16)
                : colors.surfaceSunken,
            borderRadius: BorderRadius.circular(RitmoRadius.pill),
            border: Border.all(
              color: isSelected ? accent : colors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? accent : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(RitmoRadius.field),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.md),
          decoration: BoxDecoration(
            color: colors.surfaceSunken,
            borderRadius: BorderRadius.circular(RitmoRadius.field),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: RitmoSpacing.sm),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
