import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/app_mode/app_mode_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';

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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          // ─── حالت ساده (سمت راست در RTL) ───
          Expanded(
            child: GestureDetector(
              onTap: () async {
                if (_isSimpleMode) return;
                RitmoHapticsPolicy.selection();
                await AppModeService.instance.set(AppMode.simple);
                setState(() => _isSimpleMode = true);
                widget.onModeChanged(true);
                if (mounted) RitmoToast.show(context, 'حالت اپلیکیشن به «حالت ساده» تغییر یافت.');
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  color: _isSimpleMode ? colors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _isSimpleMode
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.leaf_arrow_circlepath,
                      size: 13,
                      color: _isSimpleMode ? colors.primary : colors.textTertiary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'حالت ساده',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _isSimpleMode ? FontWeight.w800 : FontWeight.w500,
                        color: _isSimpleMode ? colors.primary : colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── حالت کامل (سمت چپ در RTL) ───
          Expanded(
            child: GestureDetector(
              onTap: () async {
                if (!_isSimpleMode) return;
                RitmoHapticsPolicy.selection();
                await AppModeService.instance.set(AppMode.full);
                setState(() => _isSimpleMode = false);
                widget.onModeChanged(false);
                if (mounted) RitmoToast.show(context, 'حالت اپلیکیشن به «حالت کامل» تغییر یافت.');
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  color: !_isSimpleMode ? colors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: !_isSimpleMode
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.sparkles,
                      size: 13,
                      color: !_isSimpleMode ? colors.primary : colors.textTertiary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'حالت کامل',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: !_isSimpleMode ? FontWeight.w800 : FontWeight.w500,
                        color: !_isSimpleMode ? colors.primary : colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
