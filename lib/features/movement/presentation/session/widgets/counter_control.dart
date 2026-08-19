import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

/// کنترل شمارندهٔ تکرار/ست با دکمه‌های سریع، ورودی دستی، ضد تپ و قابلیت بازگردانی
class CounterControl extends StatefulWidget {
  const CounterControl({
    super.key,
    required this.currentCount,
    required this.targetCount,
    required this.onCountChanged,
    this.currentSet = 1,
    this.totalSets,
    this.onNextSet,
  });

  final int currentCount;
  final int? targetCount;
  final ValueChanged<int> onCountChanged;
  final int currentSet;
  final int? totalSets;
  final VoidCallback? onNextSet;

  @override
  State<CounterControl> createState() => _CounterControlState();
}

class _CounterControlState extends State<CounterControl> {
  DateTime _lastTapTime = DateTime.now().subtract(const Duration(seconds: 1));
  final List<int> _history = [];

  void _add(int delta) {
    final now = DateTime.now();
    if (now.difference(_lastTapTime).inMilliseconds < 120) return;
    _lastTapTime = now;

    RitmoHapticsPolicy.tap();
    _history.add(widget.currentCount);
    widget.onCountChanged(widget.currentCount + delta);
  }

  void _undo() {
    if (_history.isNotEmpty) {
      RitmoHapticsPolicy.selection();
      final prev = _history.removeLast();
      widget.onCountChanged(prev);
    }
  }

  void _showManualDialog() async {
    final controller = TextEditingController(
      text: widget.currentCount.toString(),
    );
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) {
        final colors = ctx.colors;
        return AlertDialog(
          backgroundColor: colors.surfaceElevated,
          title: Text(
            'ورود تعداد تکرار',
            style: RitmoTextStyles.cardTitle(colors.textPrimary),
          ),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            style: RitmoTextStyles.body(colors.textPrimary),
            decoration: InputDecoration(
              hintText: 'تعداد تکرار انجام‌شده',
              filled: true,
              fillColor: colors.surfaceSunken,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(MovementStrings.commonCancel),
            ),
            ElevatedButton(
              onPressed: () {
                final val = int.tryParse(controller.text.trim());
                Navigator.of(ctx).pop(val);
              },
              child: const Text(MovementStrings.commonConfirm),
            ),
          ],
        );
      },
    );

    if (result != null && result >= 0) {
      _history.add(widget.currentCount);
      widget.onCountChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // نمایش ست (در صورت وجود)
        if (widget.totalSets != null && widget.totalSets! > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: sportsColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(RitmoRadius.pill),
            ),
            child: Text(
              'ست ${toPersianDigits(widget.currentSet)} از ${toPersianDigits(widget.totalSets)}',
              style: RitmoTextStyles.label(sportsColor),
            ),
          ),
          const SizedBox(height: RitmoSpacing.md),
        ],

        // شمارنده بزرگ مرکزی
        GestureDetector(
          onTap: () => _add(1),
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: colors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: sportsColor, width: 3),
              boxShadow: [
                BoxShadow(
                  color: sportsColor.withValues(alpha: 0.15),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  toPersianDigits(widget.currentCount),
                  style: RitmoTextStyles.heroNumber(colors.textPrimary),
                ),
                if (widget.targetCount != null) ...[
                  Text(
                    'از ${toPersianDigits(widget.targetCount)}',
                    style: RitmoTextStyles.caption(colors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: RitmoSpacing.lg),

        // دکمه‌های افزایش سریع
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildQuickBtn('+۱', () => _add(1), sportsColor),
            const SizedBox(width: RitmoSpacing.sm),
            _buildQuickBtn('+۵', () => _add(5), sportsColor),
            const SizedBox(width: RitmoSpacing.sm),
            _buildQuickBtn('+۱۰', () => _add(10), sportsColor),
          ],
        ),
        const SizedBox(height: RitmoSpacing.md),

        // اکشن‌های ثانویه (Undo و ورود دستی)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_history.isNotEmpty)
              TextButton.icon(
                onPressed: _undo,
                icon: const Icon(Icons.undo_rounded, size: 16),
                label: const Text(MovementStrings.commonUndo),
                style: TextButton.styleFrom(foregroundColor: colors.warning),
              ),
            TextButton.icon(
              onPressed: _showManualDialog,
              icon: const Icon(Icons.edit_rounded, size: 16),
              label: const Text('ورود دستی'),
              style: TextButton.styleFrom(
                foregroundColor: colors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickBtn(String text, VoidCallback onTap, Color color) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RitmoRadius.field),
        ),
      ),
      child: Text(
        toPersianDigits(text),
        style: RitmoTextStyles.label(color).copyWith(fontSize: 16),
      ),
    );
  }
}
