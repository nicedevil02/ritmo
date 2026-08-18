import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/settings/ai_settings_guard.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:shamsi_date/shamsi_date.dart';

class AiWriteHistorySheet extends StatefulWidget {
  const AiWriteHistorySheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AiWriteHistorySheet(),
    );
  }

  @override
  State<AiWriteHistorySheet> createState() => _AiWriteHistorySheetState();
}

class _AiWriteHistorySheetState extends State<AiWriteHistorySheet> {
  List<AiSettingHistoryRecord> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final list = await AiSettingsGuard.instance.getHistory();
    if (mounted) {
      setState(() {
        _records = list;
        _loading = false;
      });
    }
  }

  String _formatDateTime(DateTime dt) {
    final j = Jalali.fromDateTime(dt);
    final date = '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';
    final time = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '${toPersianDigits(date)} - ${toPersianDigits(time)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          top: 16,
          left: 16,
          right: 16,
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(CupertinoIcons.sparkles, color: colors.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'تاریخچه تغییرات دستیار هوشمند',
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
              'تغییراتی که دستیار برای هماهنگی برنامه‌ها روی تنظیمات اعمال کرده است:',
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CupertinoActivityIndicator(),
                ),
              )
            else if (_records.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'هنوز هیچ تغییری توسط دستیار ثبت نشده است.',
                    style: TextStyle(fontSize: 13, color: colors.textTertiary),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _records.length,
                  separatorBuilder: (_, __) => Divider(color: colors.border, height: 1),
                  itemBuilder: (context, index) {
                    final item = _records[index];

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.labelFa,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.reasonFa,
                                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${toPersianDigits(item.oldValue.toString())} ← ${toPersianDigits(item.newValue.toString())} (${_formatDateTime(item.timestamp)})',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colors.accent,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            key: ValueKey('rollback_btn_${item.id}'),
                            onPressed: () async {
                              RitmoHaptics.confirm();
                              final ok = await AiSettingsGuard.instance.rollbackChange(item.id);
                              if (ok && context.mounted) {
                                RitmoToast.show(context, 'تنظیم به مقدار قبلی بازگردانده شد');
                                await _loadRecords();
                              }
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: colors.medicalRed,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'بازگردانی',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
