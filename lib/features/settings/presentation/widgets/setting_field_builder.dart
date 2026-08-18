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
class SettingField extends StatefulWidget {
  SettingField(
    this.settingKey, {
    super.key,
    bool? highlight,
    bool highlighted = false,
    this.customSubtitle,
    SettingDescriptor? descriptor,
  })  : highlighted = highlight ?? highlighted,
        descriptor = descriptor ?? SettingsRegistry.find(settingKey) {
    if (this.descriptor == null) {
      RitmoLog.error('Settings', 'SettingDescriptor for key "$settingKey" not found in SettingsRegistry');
    }
  }

  SettingField.withDescriptor(
    this.descriptor, {
    super.key,
    bool? highlight,
    bool highlighted = false,
    this.customSubtitle,
  })  : highlighted = highlight ?? highlighted,
        settingKey = descriptor?.key ?? '';

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
  State<SettingField> createState() => _SettingFieldState();
}

class _SettingFieldState extends State<SettingField> with SingleTickerProviderStateMixin {
  AnimationController? _highlightController;
  Animation<double>? _pulseAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.highlighted) {
      _initHighlightAnimation();
    }
  }

  void _initHighlightAnimation() {
    _highlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = CurvedAnimation(
      parent: _highlightController!,
      curve: Curves.easeOutCubic,
    );
    _highlightController!.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
          alignment: 0.3,
        );
      }
    });
  }

  @override
  void dispose() {
    _highlightController?.dispose();
    super.dispose();
  }

  void _showResetSheet(BuildContext context, SettingDescriptor desc) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (modalCtx) => CupertinoActionSheet(
        title: const Text(
          'بازنشانی به مقدار پیش‌فرض',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        message: Text('آیا می‌خواهید «${desc.labelFa}» به مقدار پیش‌فرض بازگردد؟'),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(modalCtx);
              await SettingsService.instance.resetToDefault(desc.key);
              if (context.mounted) {
                RitmoToast.show(context, 'تنظیم به حالت پیش‌فرض بازگشت');
              }
            },
            child: const Text('بازنشانی به پیش‌فرض'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(modalCtx),
          child: const Text('انصراف'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final desc = widget.descriptor;
    if (desc == null || desc.visibility == SettingVisibility.internal) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: SettingsService.instance.revision,
      builder: (context, _) {
        final showAdvanced = SettingsService.instance.get<bool>('show_advanced_settings');
        if (desc.visibility == SettingVisibility.advanced && !showAdvanced) {
          return const SizedBox.shrink();
        }

        // بررسی وابستگی شرطی و وضعیت بارگذاری
        bool isEnabled = true;
        String? dependencyHint;

        if (SettingsService.instance.isDegraded) {
          isEnabled = false;
          dependencyHint = 'به دلیل خطای بارگذاری، تنظیمات موقتاً غیرفعال است';
        } else {
          if (desc.dependsOn != null) {
            final parentKey = desc.dependsOn!.key;
            final parentVal = SettingsService.instance.get<Object?>(parentKey);
            if (!desc.dependsOn!.isSatisfied(parentVal)) {
              isEnabled = false;
              final parentDesc = SettingsRegistry.find(parentKey);
              dependencyHint = 'نیاز به روشن بودن «${parentDesc?.labelFa ?? parentKey}»';
            }
          }

          if (isEnabled && desc.group == SettingsGroup.notifications && desc.key != 'notif_master_enabled') {
            final masterEnabled = SettingsService.instance.get<bool>('notif_master_enabled');
            if (!masterEnabled) {
              isEnabled = false;
              final masterDesc = SettingsRegistry.find('notif_master_enabled');
              dependencyHint = 'نیاز به روشن بودن «${masterDesc?.labelFa ?? "اعلان‌های کلی"}»';
            }
          }
        }

        final subtitleText = widget.customSubtitle ??
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

        Widget finalChild = child;
        if (!isEnabled) {
          finalChild = Opacity(
            opacity: 0.45,
            child: IgnorePointer(child: child),
          );
        }

        if (widget.highlighted && _highlightController != null && _pulseAnimation != null) {
          return AnimatedBuilder(
            animation: _pulseAnimation!,
            builder: (context, _) {
              final alpha = (1.0 - _pulseAnimation!.value) * 0.25;
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: alpha),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: finalChild,
              );
            },
          );
        }

        return finalChild;
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
    final isModified = SettingsService.instance.isModifiedFromDefault(desc.key);

    return SettingsTile(
      title: desc.labelFa,
      subtitle: subtitle,
      leading: desc.icon != null
          ? Icon(desc.icon, color: colors.primary, size: 22)
          : null,
      highlighted: widget.highlighted,
      isModified: isModified,
      onLongPress: isModified && isEnabled ? () => _showResetSheet(context, desc) : null,
      trailing: CupertinoSwitch(
        value: value,
        activeTrackColor: colors.primary,
        onChanged: isEnabled
            ? (newVal) async {
                await SettingField.executeWrite(context, desc.key, newVal);
              }
            : null,
      ),
      onTap: isEnabled
          ? () async {
              await SettingField.executeWrite(context, desc.key, !value);
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
    final isModified = SettingsService.instance.isModifiedFromDefault(desc.key);

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
      highlighted: widget.highlighted,
      isModified: isModified,
      onLongPress: isModified && isEnabled ? () => _showResetSheet(context, desc) : null,
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
                await SettingField.executeWrite(context, desc.key, selected);
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
    final isModified = SettingsService.instance.isModifiedFromDefault(desc.key);

    return SettingsTile(
      title: desc.labelFa,
      subtitle: subtitle,
      leading: desc.icon != null
          ? Icon(desc.icon, color: colors.primary, size: 22)
          : null,
      highlighted: widget.highlighted,
      isModified: isModified,
      onLongPress: isModified && isEnabled ? () => _showResetSheet(context, desc) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(CupertinoIcons.minus_circle, size: 22),
            color: value > min ? colors.primary : colors.textTertiary,
            onPressed: isEnabled && value > min
                ? () async {
                    await SettingField.executeWrite(context, desc.key, value - 1);
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
                    await SettingField.executeWrite(context, desc.key, value + 1);
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
    final isModified = SettingsService.instance.isModifiedFromDefault(desc.key);

    return SettingsTile(
      title: desc.labelFa,
      subtitle: subtitle,
      leading: desc.icon != null
          ? Icon(desc.icon, color: colors.primary, size: 22)
          : null,
      highlighted: widget.highlighted,
      isModified: isModified,
      onLongPress: isModified && isEnabled ? () => _showResetSheet(context, desc) : null,
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
                await SettingField.executeWrite(context, desc.key, updatedText);
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
    final isModified = SettingsService.instance.isModifiedFromDefault(desc.key);

    return SettingsTile(
      title: desc.labelFa,
      subtitle: subtitle,
      leading: desc.icon != null
          ? Icon(desc.icon, color: colors.primary, size: 22)
          : null,
      highlighted: widget.highlighted,
      isModified: isModified,
      onLongPress: isModified && isEnabled ? () => _showResetSheet(context, desc) : null,
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
                await SettingField.executeWrite(context, desc.key, picked);
              }
            }
          : null,
    );
  }
}
