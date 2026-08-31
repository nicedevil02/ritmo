import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/settings/ai_settings_guard.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:shamsi_date/shamsi_date.dart';

class AiWriteHistorySheet extends StatefulWidget {
  const AiWriteHistorySheet({
    super.key,
    this.initialRecords,
  });

  final List<AiSettingHistoryRecord>? initialRecords;

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
    if (widget.initialRecords != null) {
      _records = widget.initialRecords!;
      _loading = false;
    } else {
      _loadRecords();
    }
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
    final isDark = context.isDark;
    final isGlass = context.isGlassEnabled;
    final blur = context.glassBlurSigma.clamp(0.0, 50.0);
    const sheetRadius = BorderRadius.vertical(top: Radius.circular(28));

    final content = Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 16,
        left: 16,
        right: 16,
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
                color: colors.textSecondary.withValues(alpha: 0.2),
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
                separatorBuilder: (context, index) => Divider(color: colors.border, height: 1),
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
    );

    final sheetBody = Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        type: MaterialType.transparency,
        child: content,
      ),
    );

    if (!isGlass) {
      return Container(
        constraints: BoxConstraints(
          maxHeight: RitmoBreakpoints.sheetMaxHeight(context, factor: 0.75),
        ),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: sheetRadius,
          border: Border.all(
            color: isDark ? colors.border : colors.divider,
            width: 1.0,
          ),
        ),
        child: sheetBody,
      );
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: RitmoBreakpoints.sheetMaxHeight(context, factor: 0.75),
      ),
      child: ClipRRect(
        borderRadius: sheetRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.glassTint,
              borderRadius: sheetRadius,
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.70),
                width: 1.0,
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: sheetRadius,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: isDark ? 0.08 : 0.20),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.45],
                ),
              ),
              child: sheetBody,
            ),
          ),
        ),
      ),
    );
  }
}
