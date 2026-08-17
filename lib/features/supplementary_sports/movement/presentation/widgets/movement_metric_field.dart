// lib/features/supplementary_sports/movement/presentation/widgets/movement_metric_field.dart
//
// ورودی عددی مقادیر حرکت (مدت، مسافت، ارتفاع، گام، طول).
//
// مشکل قبلی: همهٔ مقادیر فقط با Slider گرفته می‌شدند؛ مدت زمان روی پله‌های
// ۵ دقیقه‌ای، مسافت روی پله‌های ~۰٫۵ کیلومتری و گام روی پله‌های ۵۰۰ تایی
// قفل بود. یعنی ثبت «۴۲ دقیقه» یا «۷٫۳ کیلومتر» ممکن نبود.
//
// ضمناً مقدارِ null اینجا معنا دارد: «کاربر وارد نکرده». برخلاف قبل که
// مقادیر ساختگی (۳ کیلومتر، ۱۰۰ متر، ۴۰۰۰ گام) از پیش نشسته بودند و
// ناخواسته ذخیره می‌شدند.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';

/// اعداد فارسی/عربی و جداکننده‌های اعشار محلی را به عدد قابل‌تجزیه تبدیل می‌کند.
double? parseFlexibleNumber(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;

  const persian = '۰۱۲۳۴۵۶۷۸۹';
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  for (var i = 0; i < 10; i++) {
    s = s.replaceAll(persian[i], '$i').replaceAll(arabic[i], '$i');
  }
  s = s.replaceAll('٫', '.').replaceAll('،', '.').replaceAll(',', '.');

  return double.tryParse(s);
}

/// عدد را بدون اعشار اضافی و با ارقام فارسی نمایش می‌دهد.
String formatMetricValue(double value, int decimals) {
  if (decimals == 0) return value.round().toPersianDigits();
  final fixed = value.toStringAsFixed(decimals);
  final trimmed = fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
  return trimmed.toPersianDigits();
}

class MovementMetricField extends StatefulWidget {
  const MovementMetricField({
    super.key,
    required this.label,
    required this.unit,
    required this.value,
    required this.onChanged,
    this.icon,
    this.step = 1,
    this.min = 0,
    this.max,
    this.decimals = 0,
    this.quickValues = const <double>[],
    this.helper,
    this.accent,
    this.isRequired = false,
  });

  final String label;
  final String unit;

  /// مقدار فعلی؛ null یعنی کاربر چیزی وارد نکرده است.
  final double? value;
  final ValueChanged<double?> onChanged;

  final IconData? icon;
  final double step;
  final double min;
  final double? max;
  final int decimals;

  /// مقادیر پرتکرار برای انتخاب یک‌ضربه‌ای.
  final List<double> quickValues;

  /// متن راهنما زیر فیلد (مثل سرعت متوسط محاسبه‌شده).
  final String? helper;

  final Color? accent;
  final bool isRequired;

  @override
  State<MovementMetricField> createState() => _MovementMetricFieldState();
}

class _MovementMetricFieldState extends State<MovementMetricField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _textFor(widget.value));
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(MovementMetricField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // وقتی مقدار از بیرون عوض شد (دکمهٔ +/- یا چیپ) متن را هم‌گام کن،
    // اما هنگام تایپ کاربر دست نگه دار تا مکان‌نما نپرد.
    if (widget.value != oldWidget.value && !_focusNode.hasFocus) {
      _controller.text = _textFor(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _textFor(double? value) {
    if (value == null) return '';
    if (widget.decimals == 0) return value.round().toString();
    final fixed = value.toStringAsFixed(widget.decimals);
    return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
  }

  double _clamp(double raw) {
    var v = raw;
    if (v < widget.min) v = widget.min;
    final max = widget.max;
    if (max != null && v > max) v = max;
    return v;
  }

  void _bump(double delta) {
    HapticFeedback.selectionClick();
    final base = widget.value ?? (delta > 0 ? widget.min : widget.min + widget.step);
    final next = _clamp(base + delta);
    _controller.text = _textFor(next);
    widget.onChanged(next);
  }

  void _onTextChanged(String raw) {
    if (raw.trim().isEmpty) {
      widget.onChanged(null);
      return;
    }
    final parsed = parseFlexibleNumber(raw);
    if (parsed == null) return;
    widget.onChanged(parsed);
  }

  void _onEditingDone() {
    final parsed = parseFlexibleNumber(_controller.text);
    if (parsed == null) {
      widget.onChanged(null);
      _controller.text = '';
      return;
    }
    final clamped = _clamp(parsed);
    _controller.text = _textFor(clamped);
    widget.onChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = widget.accent ?? context.modules.sports;
    final isEmpty = widget.value == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, size: 15, color: accent),
              const SizedBox(width: RitmoSpacing.xs),
            ],
            Text(
              widget.label,
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
                color: colors.textPrimary,
              ),
            ),
            if (!widget.isRequired) ...[
              const SizedBox(width: RitmoSpacing.xs),
              Text(
                '(اختیاری)',
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 11,
                  color: colors.textTertiary,
                ),
              ),
            ],
            const Spacer(),
            if (!isEmpty)
              InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _controller.clear();
                  widget.onChanged(null);
                },
                borderRadius: BorderRadius.circular(RitmoRadius.badge),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: RitmoSpacing.sm,
                    vertical: RitmoSpacing.xs,
                  ),
                  child: Text(
                    'پاک کردن',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 11.5,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: RitmoSpacing.sm),

        // ردیف ورودی: منها | عدد | بها
        Container(
          decoration: BoxDecoration(
            color: colors.surfaceSunken,
            borderRadius: BorderRadius.circular(RitmoRadius.field),
            border: Border.all(
              color: isEmpty ? colors.border : accent.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            children: [
              _StepperButton(
                icon: CupertinoIcons.minus,
                accent: accent,
                onTap: () => _bump(-widget.step),
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  textAlign: TextAlign.center,
                  keyboardType: widget.decimals > 0
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[0-9\u06F0-\u06F9\u0660-\u0669\u066B.,]'),
                    ),
                  ],
                  onChanged: _onTextChanged,
                  onEditingComplete: () {
                    _onEditingDone();
                    FocusScope.of(context).unfocus();
                  },
                  onTapOutside: (_) {
                    if (_focusNode.hasFocus) {
                      _onEditingDone();
                      _focusNode.unfocus();
                    }
                  },
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: '—',
                    hintStyle: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 18,
                      color: colors.textTertiary,
                    ),
                    suffixText: widget.unit.isEmpty ? null : widget.unit,
                    suffixStyle: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 12.5,
                      color: colors.textSecondary,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: RitmoSpacing.md,
                    ),
                  ),
                ),
              ),
              _StepperButton(
                icon: CupertinoIcons.plus,
                accent: accent,
                onTap: () => _bump(widget.step),
              ),
            ],
          ),
        ),

        if (widget.quickValues.isNotEmpty) ...[
          const SizedBox(height: RitmoSpacing.sm),
          Wrap(
            spacing: RitmoSpacing.sm,
            runSpacing: RitmoSpacing.xs,
            children: widget.quickValues.map((v) {
              final isSelected = widget.value != null &&
                  (widget.value! - v).abs() < 0.001;
              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _controller.text = _textFor(v);
                  widget.onChanged(v);
                },
                borderRadius: BorderRadius.circular(RitmoRadius.pill),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 36),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    horizontal: RitmoSpacing.md,
                    vertical: RitmoSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accent.withValues(alpha: 0.16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(RitmoRadius.pill),
                    border: Border.all(
                      color: isSelected ? accent : colors.border,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    formatMetricValue(v, widget.decimals),
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? accent : colors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],

        if (widget.helper != null) ...[
          const SizedBox(height: RitmoSpacing.xs),
          Text(
            widget.helper!,
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: 11.5,
              color: colors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(RitmoRadius.field),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: accent),
        ),
      ),
    );
  }
}
