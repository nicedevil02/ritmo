import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/settings/settings_registry.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/features/settings/presentation/widgets/settings_tile.dart';

/// ویجت اعلامی جامع برای رندر هر نوع تنظیم از روی توصیفگر رجیستری
class SettingField extends StatelessWidget {
  SettingField(
    this.settingKey, {
    super.key,
    this.highlighted = false,
    this.customSubtitle,
    SettingDescriptor? descriptor,
  }) : descriptor = descriptor ?? SettingsRegistry.find(settingKey) {
    if (this.descriptor == null) {
      RitmoLog.error('Settings', 'SettingDescriptor for key "$settingKey" not found in SettingsRegistry');
    }
  }

  SettingField.withDescriptor(
    this.descriptor, {
    super.key,
    this.highlighted = false,
    this.customSubtitle,
  }) : settingKey = descriptor?.key ?? '';

  final String settingKey;
  final SettingDescriptor? descriptor;
  final bool highlighted;
  final String? customSubtitle;

  static Future<bool> executeWrite(
    BuildContext context,
    String key,
    Object value,
  ) async {
    final result = await SettingsService.instance.setChecked(key, value);
    if (result is SettingWriteOk) {
      RitmoHaptics.confirm();
      return true;
    } else {
      RitmoHaptics.error();
      if (context.mounted) {
        final reason = switch (result) {
          SettingWriteRejected(:final reasonFa) => reasonFa,
          SettingWriteFailed(:final reasonFa) => reasonFa,
          _ => 'خطا در ذخیره‌سازی تنظیمات',
        };
        RitmoToast.show(context, reason);
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final desc = descriptor;
    if (desc == null || desc.visibility == SettingVisibility.internal) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: SettingsService.instance.revision,
      builder: (context, _) {
        // بررسی وابستگی شرطی
        bool isEnabled = true;
        String? dependencyHint;

        if (desc.dependsOn != null) {
          final parentKey = desc.dependsOn!.key;
          final parentVal = SettingsService.instance.get<Object?>(parentKey);
          if (!desc.dependsOn!.isSatisfied(parentVal)) {
            isEnabled = false;
            final parentDesc = SettingsRegistry.find(parentKey);
            dependencyHint = 'وابسته به «${parentDesc?.labelFa ?? parentKey}»';
          }
        }

        final subtitleText = customSubtitle ??
            (dependencyHint != null
                ? '$dependencyHint\n${desc.descriptionFa ?? ''}'
                : desc.descriptionFa);

        final child = switch (desc.type) {
          SettingType.boolean => _buildBooleanTile(context, desc, isEnabled, subtitleText),
          SettingType.enumeration => _buildEnumTile(context, desc, isEnabled, subtitleText),
          SettingType.integer => _buildIntegerTile(context, desc, isEnabled, subtitleText),
          SettingType.text => _buildTextTile(context, desc, isEnabled, subtitleText),
          SettingType.time => _buildTimeTile(context, desc, isEnabled, subtitleText),
        };

        if (!isEnabled) {
          return Opacity(
            opacity: 0.45,
            child: IgnorePointer(child: child),
          );
        }

        return child;
      },
    );
  }

  Widget _buildBooleanTile(
    BuildContext context,
    SettingDescriptor desc,
    bool isEnabled,
    String? subtitle,
  ) {
    final colors = context.colors;
    final value = SettingsService.instance.get<bool>(desc.key);

    return SettingsTile(
      title: desc.labelFa,
      subtitle: subtitle,
      leading: desc.icon != null
          ? Icon(desc.icon, color: colors.primary, size: 22)
          : null,
      highlighted: highlighted,
      trailing: CupertinoSwitch(
        value: value,
        activeTrackColor: colors.primary,
        onChanged: isEnabled
            ? (newVal) async {
                await executeWrite(context, desc.key, newVal);
              }
            : null,
      ),
      onTap: isEnabled
          ? () async {
              await executeWrite(context, desc.key, !value);
            }
          : null,
    );
  }

  Widget _buildEnumTile(
    BuildContext context,
    SettingDescriptor desc,
    bool isEnabled,
    String? subtitle,
  ) {
    final colors = context.colors;
    final currentVal = SettingsService.instance.get<String>(desc.key);
    final allowed = desc.allowed ?? const [];

    String displayVal = currentVal;
    if (desc.optionLabelsFa != null && desc.optionLabelsFa!.containsKey(currentVal)) {
      displayVal = desc.optionLabelsFa![currentVal]!;
    }

    return SettingsTile(
      title: desc.labelFa,
      subtitle: subtitle,
      leading: desc.icon != null
          ? Icon(desc.icon, color: colors.primary, size: 22)
          : null,
      highlighted: highlighted,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            displayVal,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 6),
          Icon(CupertinoIcons.chevron_back, size: 14, color: colors.textTertiary),
        ],
      ),
      onTap: isEnabled
          ? () async {
              RitmoHaptics.tap();
              final selected = await showCupertinoModalPopup<String>(
                context: context,
                builder: (modalCtx) => CupertinoActionSheet(
                  title: Text(
                    desc.labelFa,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  message: desc.descriptionFa != null ? Text(desc.descriptionFa!) : null,
                  actions: allowed.map((opt) {
                    final label = desc.optionLabelsFa?[opt] ?? opt;
                    final isCurrent = opt == currentVal;
                    return CupertinoActionSheetAction(
                      isDefaultAction: isCurrent,
                      onPressed: () => Navigator.pop(modalCtx, opt),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isCurrent ? colors.primary : colors.textPrimary,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                  cancelButton: CupertinoActionSheetAction(
                    isDestructiveAction: true,
                    onPressed: () => Navigator.pop(modalCtx),
                    child: const Text('انصراف'),
                  ),
                ),
              );

              if (selected != null && selected != currentVal && context.mounted) {
                await executeWrite(context, desc.key, selected);
              }
            }
          : null,
    );
  }

  Widget _buildIntegerTile(
    BuildContext context,
    SettingDescriptor desc,
    bool isEnabled,
    String? subtitle,
  ) {
    final colors = context.colors;
    final value = SettingsService.instance.get<int>(desc.key);
    final min = desc.min ?? 0;
    final max = desc.max ?? 100;
    final unit = desc.unitFa != null ? ' ${desc.unitFa}' : '';

    return SettingsTile(
      title: desc.labelFa,
      subtitle: subtitle,
      leading: desc.icon != null
          ? Icon(desc.icon, color: colors.primary, size: 22)
          : null,
      highlighted: highlighted,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(CupertinoIcons.minus_circle, size: 22),
            color: value > min ? colors.primary : colors.textTertiary,
            onPressed: isEnabled && value > min
                ? () async {
                    await executeWrite(context, desc.key, value - 1);
                  }
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '${toPersianDigits(value)}$unit',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.plus_circle, size: 22),
            color: value < max ? colors.primary : colors.textTertiary,
            onPressed: isEnabled && value < max
                ? () async {
                    await executeWrite(context, desc.key, value + 1);
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildTextTile(
    BuildContext context,
    SettingDescriptor desc,
    bool isEnabled,
    String? subtitle,
  ) {
    final colors = context.colors;
    final value = SettingsService.instance.get<String>(desc.key);

    return SettingsTile(
      title: desc.labelFa,
      subtitle: subtitle,
      leading: desc.icon != null
          ? Icon(desc.icon, color: colors.primary, size: 22)
          : null,
      highlighted: highlighted,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              value.isEmpty ? 'تنظیم نشده' : value,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: value.isEmpty ? colors.textTertiary : colors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Icon(CupertinoIcons.chevron_back, size: 14, color: colors.textTertiary),
        ],
      ),
      onTap: isEnabled
          ? () async {
              RitmoHaptics.tap();
              final controller = TextEditingController(text: value);
              final updatedText = await showDialog<String>(
                context: context,
                builder: (modalCtx) => AlertDialog(
                  backgroundColor: colors.card,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Text(
                    desc.labelFa,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary),
                  ),
                  content: CupertinoTextField(
                    controller: controller,
                    autofocus: true,
                    placeholder: desc.labelFa,
                    style: TextStyle(color: colors.textPrimary),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(modalCtx),
                      child: Text('انصراف', style: TextStyle(color: colors.textSecondary)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(modalCtx, controller.text.trim()),
                      child: Text('ذخیره', style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );

              if (updatedText != null && updatedText != value && context.mounted) {
                await executeWrite(context, desc.key, updatedText);
              }
            }
          : null,
    );
  }

  Widget _buildTimeTile(
    BuildContext context,
    SettingDescriptor desc,
    bool isEnabled,
    String? subtitle,
  ) {
    final colors = context.colors;
    final value = SettingsService.instance.get<String>(desc.key);
    final parts = value.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

    return SettingsTile(
      title: desc.labelFa,
      subtitle: subtitle,
      leading: desc.icon != null
          ? Icon(desc.icon, color: colors.primary, size: 22)
          : null,
      highlighted: highlighted,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            toPersianDigits(value),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 6),
          Icon(CupertinoIcons.chevron_back, size: 14, color: colors.textTertiary),
        ],
      ),
      onTap: isEnabled
          ? () async {
              RitmoHaptics.tap();
              Duration selectedDuration = Duration(hours: hour, minutes: minute);

              final picked = await showCupertinoModalPopup<String>(
                context: context,
                builder: (modalCtx) => Container(
                  height: 280,
                  padding: const EdgeInsets.only(top: 6.0),
                  margin: EdgeInsets.only(
                    bottom: MediaQuery.of(modalCtx).viewInsets.bottom,
                  ),
                  color: CupertinoColors.systemBackground.resolveFrom(modalCtx),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            CupertinoButton(
                              child: const Text('انصراف'),
                              onPressed: () => Navigator.pop(modalCtx),
                            ),
                            CupertinoButton(
                              child: const Text('تایید'),
                              onPressed: () {
                                final h = selectedDuration.inHours.toString().padLeft(2, '0');
                                final m = (selectedDuration.inMinutes % 60).toString().padLeft(2, '0');
                                Navigator.pop(modalCtx, '$h:$m');
                              },
                            ),
                          ],
                        ),
                        Expanded(
                          child: CupertinoTimerPicker(
                            mode: CupertinoTimerPickerMode.hm,
                            initialTimerDuration: selectedDuration,
                            onTimerDurationChanged: (newDuration) {
                              selectedDuration = newDuration;
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );

              if (picked != null && picked != value && context.mounted) {
                await executeWrite(context, desc.key, picked);
              }
            }
          : null,
    );
  }
}
