import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/cycle_consent_bridge.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/cycle/logic/cycle_date_contract.dart';
import 'package:ritmo/features/cycle/models/cycle_models.dart';
import 'package:shamsi_date/shamsi_date.dart';

class CycleFastingDebtView extends StatelessWidget {
  const CycleFastingDebtView({
    super.key,
    required this.fastingDebts,
    required this.settings,
    required this.onToggleSync,
    required this.onReloadData,
  });

  final List<FastingDebt> fastingDebts;
  final Map<String, String> settings;
  final Future<void> Function(bool enabled) onToggleSync;
  final VoidCallback onReloadData;

  String _formatIsoToJalali(String iso) {
    final dt = CycleDateContract.parseDayKey(iso);
    if (dt == null) return iso;
    final jal = Jalali.fromDateTime(dt);
    return '${PersianDigits.toFa(jal.year.toString())}/${PersianDigits.toFa(jal.month.toString())}/${PersianDigits.toFa(jal.day.toString())}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RitmoTheme.glassCardLight(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.bookmark_solid,
                      color: colors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'دفترچه قضای روزه‌های واجب',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'بر اساس فقه اسلامی و رضایت عبادی شما، روزهای روزه واجب که به علت عذر شرعی بدنی از دست رفته‌اند در این دفترچه ثبت می‌شوند تا بتوانید به مرور زمان قضای آن‌ها را به جا آورید.',
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Divider(color: colors.border, height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ارسال بدهی‌ها به بخش عبادت',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    CupertinoSwitch(
                      value:
                          settings['cycle_send_fasting_debt_to_worship'] ==
                          'true',
                      activeTrackColor: colors.primary,
                      onChanged: (val) async {
                        await HapticFeedback.selectionClick();
                        await onToggleSync(val);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (fastingDebts.isEmpty)
          RitmoTheme.glassCardLight(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'هیچ بدهی قضای روزه‌ای ثبت نشده است 🌸',
                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                ),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: fastingDebts.length,
            itemBuilder: (context, index) {
              final debt = fastingDebts[index];
              final dateStr = _formatIsoToJalali(debt.dateIso);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: RitmoTheme.glassCardLight(
                  child: ListTile(
                    title: Text(
                      PersianDigits.toFa('بدهی روزه: ${debt.daysOwed} روز'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'شروع دوره: $dateStr • ${debt.reason ?? "عذر شرعی"}',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                    trailing: CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      color: debt.isResolved ? colors.border : colors.primary,
                      borderRadius: BorderRadius.circular(12),
                      onPressed: () async {
                        await HapticFeedback.mediumImpact();
                        await CycleConsentBridge.resolveFastingDebt(
                          debt.id,
                          !debt.isResolved,
                        );
                        onReloadData();
                      },
                      child: Text(
                        debt.isResolved ? 'تسویه شده' : 'ثبت تسویه',
                        style: TextStyle(
                          fontSize: 12,
                          color: debt.isResolved
                              ? colors.textSecondary
                              : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
