import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/settings/settings_transfer_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';

class SettingsImportDiffDialog extends StatefulWidget {
  const SettingsImportDiffDialog({
    super.key,
    required this.diff,
  });

  final SettingsDiffPreview diff;

  static Future<int?> show(BuildContext context, SettingsDiffPreview diff) {
    return showDialog<int>(
      context: context,
      builder: (_) => SettingsImportDiffDialog(diff: diff),
    );
  }

  @override
  State<SettingsImportDiffDialog> createState() => _SettingsImportDiffDialogState();
}

class _SettingsImportDiffDialogState extends State<SettingsImportDiffDialog> {
  late final Set<String> _selectedKeys;

  @override
  void initState() {
    super.initState();
    _selectedKeys = widget.diff.changed.map((c) => c.key).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(CupertinoIcons.arrow_down_doc_fill, color: colors.primary, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'پیش‌نمای واردسازی تنظیمات',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
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
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: widget.diff.changed.length,
                    separatorBuilder: (context, index) => Divider(color: colors.border, height: 1),
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
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: Text('انصراف', style: TextStyle(color: colors.textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    key: const ValueKey('confirm_import_button'),
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: Text('اعمال (${toPersianDigits(_selectedKeys.length)})'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
