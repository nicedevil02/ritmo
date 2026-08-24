import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/app_mode/app_mode_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';

/// سگمنت کنترل دو گزینه‌ای انتخاب حالت اپلیکیشن (ساده / کامل) در هدر هویت
class IdentityAppModeToggle extends StatefulWidget {
  const IdentityAppModeToggle({
    super.key,
    required this.isSimpleMode,
    required this.onModeChanged,
  });

  final bool isSimpleMode;
  final ValueChanged<bool> onModeChanged;

  @override
  State<IdentityAppModeToggle> createState() => _IdentityAppModeToggleState();
}

class _IdentityAppModeToggleState extends State<IdentityAppModeToggle> {
  late bool _isSimpleMode;

  @override
  void initState() {
    super.initState();
    _isSimpleMode = widget.isSimpleMode;
  }

  @override
  void didUpdateWidget(covariant IdentityAppModeToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSimpleMode != widget.isSimpleMode) {
      _isSimpleMode = widget.isSimpleMode;
    }
  }

  Future<void> _switchToSimple() async {
    RitmoHapticsPolicy.selection();
    await AppModeService.instance.set(AppMode.simple);
    if (!mounted) return;
    setState(() => _isSimpleMode = true);
    widget.onModeChanged(true);
    RitmoToast.show(context, 'حالت اپلیکیشن به «حالت ساده» تغییر یافت.');
  }

  Future<void> _switchToFull() async {
    RitmoHapticsPolicy.selection();
    await AppModeService.instance.set(AppMode.full);
    if (!mounted) return;
    setState(() => _isSimpleMode = false);
    widget.onModeChanged(false);
    RitmoToast.show(context, 'حالت اپلیکیشن به «حالت کامل» تغییر یافت.');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: isDark
              ? colors.surface.withValues(alpha: 0.5)
              : colors.border.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colors.border.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(3),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth / 2;

            return Stack(
              children: [
                // ─── اسلایدر شناور متحرک (Sliding Thumb Pill) ───
                AnimatedAlign(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.fastOutSlowIn,
                  alignment: _isSimpleMode ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: itemWidth,
                    height: constraints.maxHeight,
                    decoration: BoxDecoration(
                      color: isDark ? colors.card : colors.surface,
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(
                        color: isDark
                            ? colors.border.withValues(alpha: 0.18)
                            : colors.border.withValues(alpha: 0.1),
                        width: 0.75,
                      ),
                    ),
                  ),
                ),

                // ─── محتوای گزینه‌ها و لمس ───
                Row(
                  children: [
                    // حالت ساده (سمت راست در RTL)
                    Expanded(
                      child: GestureDetector(
                        key: const ValueKey('mode_switch_simple'),
                        behavior: HitTestBehavior.opaque,
                        onTap: _switchToSimple,
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontSize: 12,
                              fontWeight: _isSimpleMode ? FontWeight.bold : FontWeight.w500,
                              color: _isSimpleMode
                                  ? colors.primary
                                  : colors.textSecondary.withValues(alpha: 0.75),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.leaf_arrow_circlepath,
                                  size: 14,
                                  color: _isSimpleMode
                                      ? colors.primary
                                      : colors.textSecondary.withValues(alpha: 0.6),
                                ),
                                const SizedBox(width: 6),
                                const Text('حالت ساده'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // حالت کامل (سمت چپ در RTL)
                    Expanded(
                      child: GestureDetector(
                        key: const ValueKey('mode_switch_advanced'),
                        behavior: HitTestBehavior.opaque,
                        onTap: _switchToFull,
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontFamily: 'Vazirmatn',
                              fontSize: 12,
                              fontWeight: !_isSimpleMode ? FontWeight.bold : FontWeight.w500,
                              color: !_isSimpleMode
                                  ? colors.primary
                                  : colors.textSecondary.withValues(alpha: 0.75),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.sparkles,
                                  size: 14,
                                  color: !_isSimpleMode
                                      ? colors.primary
                                      : colors.textSecondary.withValues(alpha: 0.6),
                                ),
                                const SizedBox(width: 6),
                                const Text('حالت کامل'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
