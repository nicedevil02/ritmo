import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:shamsi_date/shamsi_date.dart';

class CycleHistoryList extends StatelessWidget {
  const CycleHistoryList({
    super.key,
    required this.periods,
    required this.onAddNewPeriod,
    required this.onEditPeriod,
    required this.onDeletePeriod,
  });

  final List<Map<String, dynamic>> periods;
  final VoidCallback onAddNewPeriod;
  final ValueChanged<Map<String, dynamic>> onEditPeriod;
  final ValueChanged<String> onDeletePeriod;

  String _formatIsoToJalali(String iso) {
    final dt = CycleDateContract.parseDayKey(iso);
    if (dt == null) return iso;
    final jal = Jalali.fromDateTime(dt);
    return '${PersianDigits.toFa(jal.year.toString())}/${PersianDigits.toFa(jal.month.toString().padLeft(2, '0'))}/${PersianDigits.toFa(jal.day.toString().padLeft(2, '0'))}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'تاریخچه دوره‌های قبلی',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              TextButton.icon(
                onPressed: onAddNewPeriod,
                icon: Icon(
                  CupertinoIcons.plus,
                  size: 16,
                  color: colors.primary,
                ),
                label: Text(
                  'افزودن دوره قبلی',
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (periods.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'هیچ دوره‌ای ثبت نشده است.',
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: periods.length,
            itemBuilder: (context, index) {
              final p = periods[index];
              final startStr = p['startDate'] as String;
              final endStr = p['endDate'] as String?;

              var subtitle = 'شروع: ${_formatIsoToJalali(startStr)}';
              if (endStr != null) {
                subtitle += ' | پایان: ${_formatIsoToJalali(endStr)}';
              } else {
                subtitle += ' (در حال جریان)';
              }

              return Card(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.02)
                    : Colors.black.withValues(alpha: 0.02),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colors.border),
                ),
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  title: Text(
                    endStr != null ? 'دوره تکمیل‌شده' : 'دوره فعال بدنی',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          CupertinoIcons.pencil,
                          color: colors.primary,
                          size: 18,
                        ),
                        onPressed: () => onEditPeriod(p),
                      ),
                      IconButton(
                        icon: Icon(
                          CupertinoIcons.trash_fill,
                          color: colors.textTertiary,
                          size: 18,
                        ),
                        onPressed: () => onDeletePeriod(p['id'] as String),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
