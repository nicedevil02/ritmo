import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.onWhyTap,
    this.isDanger = false,
    this.highlighted = false,
    this.isModified = false,
    this.requiresRestart = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onWhyTap;
  final bool isDanger;
  final bool highlighted;
  final bool isModified;
  final bool requiresRestart;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final semanticsLabel = '$title${subtitle != null && subtitle!.isNotEmpty ? "، $subtitle" : ""}';

    return Semantics(
      container: true,
      label: semanticsLabel,
      hint: requiresRestart ? 'نیاز به راه‌اندازی مجدد' : null,
      button: onTap != null,
      enabled: true,
      excludeSemantics: trailing == null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          color: highlighted
              ? colors.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: isDanger ? colors.medicalRed : colors.textPrimary,
                                ),
                              ),
                            ),
                            if (onWhyTap != null) ...[
                              const SizedBox(width: 4),
                              Semantics(
                                label: 'راهنمای تنظیم $title',
                                button: true,
                                child: GestureDetector(
                                  key: const ValueKey('setting_why_button'),
                                  onTap: onWhyTap,
                                  behavior: HitTestBehavior.opaque,
                                  child: Container(
                                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.all(4.0),
                                    child: Icon(
                                      CupertinoIcons.question_circle,
                                      size: 18,
                                      color: colors.primary.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            if (requiresRestart) ...[
                              const SizedBox(width: 6),
                              Container(
                                key: const ValueKey('setting_restart_needed_chip'),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                                ),
                                child: const Text(
                                  'نیاز به راه‌اندازی مجدد',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFF59E0B),
                                  ),
                                ),
                              ),
                            ],
                            if (isModified) ...[
                              const SizedBox(width: 6),
                              Container(
                                key: const ValueKey('setting_modified_dot'),
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDanger
                                  ? colors.medicalRed.withValues(alpha: 0.8)
                                  : colors.textSecondary,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 12),
                    trailing!,
                  ] else if (onTap != null) ...[
                    const SizedBox(width: 8),
                    Icon(
                      CupertinoIcons.chevron_back, // RTL navigation back
                      size: 16,
                      color: colors.textTertiary,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
