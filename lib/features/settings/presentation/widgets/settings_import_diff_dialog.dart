import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/settings/settings_transfer_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';

class SettingsImportDiffDialog extends StatefulWidget {
  const SettingsImportDiffDialog({
    super.key,
    required this.diff,
  });

  final SettingsDiffPreview diff;

  static Future<int?> show(BuildContext context, SettingsDiffPreview diff) {
    return showDialog<int>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => SettingsImportDiffDialog(diff: diff),
    );
  }

  @override
  State<SettingsImportDiffDialog> createState() => _SettingsImportDiffDialogState();
}

class _SettingsImportDiffDialogState extends State<SettingsImportDiffDialog> {
  late Set<String> _selectedKeys;

  @override
  void initState() {
    super.initState();
    _selectedKeys = widget.diff.changed.map((c) => c.key).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return RitmoCustomDialog(
      title: 'پیش‌نمای واردسازی تنظیمات',
      icon: CupertinoIcons.arrow_down_doc_fill,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${toPersianDigits(widget.diff.changed.length)} تغییر نسبت به تنظیمات فعلی شناسایی شد:',
            style: TextStyle(fontSize: 13, color: colors.textSecondary),
          ),
          const SizedBox(height: 16),
          if (widget.diff.changed.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: Text(
                'تمام تنظیمات موجود در فایل با تنظیمات فعلی یکسان هستند.',
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.diff.changed.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = widget.diff.changed[index];
                  final isChecked = _selectedKeys.contains(item.key);

                  return CheckboxListTile(
                    value: isChecked,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedKeys.add(item.key);
                        } else {
                          _selectedKeys.remove(item.key);
                        }
                      });
                    },
                    title: Text(
                      item.labelFa,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${toPersianDigits(item.currentValue.toString())} ← ${toPersianDigits(item.newValue.toString())}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    contentPadding: EdgeInsets.zero,
                    activeColor: colors.primary,
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                },
              ),
            ),
        ],
      ),
      actions: [
        Expanded(
          child: RitmoSecondaryButton(
            label: 'انصراف',
            onPressed: () => Navigator.pop(context, null),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RitmoPrimaryButton(
            label: 'اعمال (${toPersianDigits(_selectedKeys.length)})',
            onPressed: _selectedKeys.isEmpty
                ? null
                : () async {
                    RitmoHaptics.confirm();
                    final count = await SettingsTransferService.instance.applyImport(
                      widget.diff,
                      selectedKeys: _selectedKeys.toList(),
                    );
                    if (context.mounted) {
                      RitmoToast.show(
                        context,
                        '${toPersianDigits(count)} تنظیم با موفقیت به‌روزرسانی شد',
                      );
                      Navigator.pop(context, count);
                    }
                  },
          ),
        ),
      ],
    );
  }
}
