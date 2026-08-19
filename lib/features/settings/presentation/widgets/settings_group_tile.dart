import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';

/// ردیف نمایش گروه تنظیمات به سبک مدرن و اختصاصی iOS 26
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
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          RitmoHaptics.selection();
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.985 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsetsDirectional.fromSTEB(14, 13, 14, 13),
            decoration: BoxDecoration(
              color: _isPressed
                  ? colors.primary.withValues(alpha: 0.06)
                  : Colors.transparent,
            ),
            child: Row(
              children: [
                // ─── آیکن مدرن iOS 26 با های‌لایت و گرادیان سه‌بعدی ───
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    gradient: LinearGradient(
                      colors: widget.gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.gradient.first.withValues(alpha: 0.32),
                        blurRadius: 10,
                        offset: const Offset(0, 3.5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      widget.icon,
                      color: Colors.white,
                      size: 21,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // ─── عنوان و توضیح مختصر ───
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                          letterSpacing: -0.2,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // ─── کپسول شمارنده تعداد تنظیمات ───
                if (widget.count > 0)
                  Container(
                    padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: widget.gradient.first.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: widget.gradient.first.withValues(alpha: 0.18),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      '${toPersianDigits(widget.count)} مورد',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: widget.gradient.first,
                      ),
                    ),
                  ),
                const SizedBox(width: 6),

                // ─── نشانگر ناوبری iOS ───
                Icon(
                  CupertinoIcons.chevron_back, // جهت صحیح در زبان فارسی و RTL
                  size: 15,
                  color: colors.textTertiary.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
