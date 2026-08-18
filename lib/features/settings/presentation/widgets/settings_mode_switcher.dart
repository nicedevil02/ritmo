import 'package:flutter/material.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

/// سوئیچ تعاملی بین حالت ساده و پیشرفته تنظیمات
class SettingsModeSwitcher extends StatelessWidget {
  const SettingsModeSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AnimatedBuilder(
      animation: SettingsService.instance.revision,
      builder: (context, _) {
        final showAdvanced = SettingsService.instance.get<bool>('show_advanced_settings');

        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  key: const ValueKey('mode_switch_simple'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    if (showAdvanced) {
                      await SettingsService.instance.set('show_advanced_settings', false);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: !showAdvanced ? colors.primary.withValues(alpha: 0.12) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: !showAdvanced ? Border.all(color: colors.primary.withValues(alpha: 0.3)) : null,
                    ),
                    child: Center(
                      child: Text(
                        'حالت ساده',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: !showAdvanced ? FontWeight.bold : FontWeight.w500,
                          color: !showAdvanced ? colors.primary : colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: GestureDetector(
                  key: const ValueKey('mode_switch_advanced'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    if (!showAdvanced) {
                      await SettingsService.instance.set('show_advanced_settings', true);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: showAdvanced ? colors.primary.withValues(alpha: 0.12) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: showAdvanced ? Border.all(color: colors.primary.withValues(alpha: 0.3)) : null,
                    ),
                    child: Center(
                      child: Text(
                        'حالت پیشرفته',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: showAdvanced ? FontWeight.bold : FontWeight.w500,
                          color: showAdvanced ? colors.primary : colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
