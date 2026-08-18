import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';

/// ردیف نمایش گروه تنظیمات به سبک اختصاصی iOS 26
class SettingsGroupTile extends StatefulWidget {
  const SettingsGroupTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.count,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final int count;
  final VoidCallback onTap;

  @override
  State<SettingsGroupTile> createState() => _SettingsGroupTileState();
}

class _SettingsGroupTileState extends State<SettingsGroupTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      label: '${widget.title}، ${widget.subtitle}',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          RitmoHaptics.tap();
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _isPressed
                ? colors.primary.withValues(alpha: 0.07)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              // ─── آیکن سه‌بعدی با هاله‌ی گرادیانی ───
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  gradient: LinearGradient(
                    colors: widget.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.gradient.first.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  widget.icon,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),

              // ─── متن عنوان و زیرعنوان ───
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: colors.textSecondary,
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // ─── بج تعداد تنظیمات و شورون ───
              Container(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.gradient.first.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: widget.gradient.first.withValues(alpha: 0.16),
                    width: 1,
                  ),
                ),
                child: Text(
                  '${toPersianDigits(widget.count)} تنظیم',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: widget.gradient.first,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                CupertinoIcons.chevron_back, // RTL forward navigation chevron pointing left
                size: 16,
                color: colors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
