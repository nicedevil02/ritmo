import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/cycle_consent_bridge.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_card.dart';
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
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RitmoCard.neumorphic(
          borderRadius: BorderRadius.circular(24),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const RitmoCardHeader(
                title: 'دفترچه قضای روزه‌های واجب',
                subtitle: 'مدیریت و تسویه روزه‌های به تعویق افتاده',
                icon: CupertinoIcons.bookmark_solid,
              ),
              const SizedBox(height: 10),
              Text(
                'روزه‌های از دست رفته به علت عذر شرعی در این دفترچه ثبت می‌شوند تا بتوانید به مرور زمان قضای آن‌ها را به جا آورید.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: colors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              // محفظه فرورفته سوئیچ اتصال به بخش عبادت
              RitmoNeuSurface(
                sunken: true,
                radius: 14,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ارسال بدهی‌ها به بخش عبادت',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    CupertinoSwitch(
                      value: settings['cycle_send_fasting_debt_to_worship'] == 'true',
                      activeTrackColor: colors.primary,
                      onChanged: (val) async {
                        await HapticFeedback.selectionClick();
                        await onToggleSync(val);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (fastingDebts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.primary.withValues(alpha: isDark ? 0.16 : 0.09),
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.25),
                        width: 0.8,
                      ),
                    ),
                    child: Icon(
                      CupertinoIcons.checkmark_seal_fill,
                      size: 24,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'هیچ بدهی قضای روزه‌ای ثبت نشده است 🌸',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'روزه‌های قضا با ثبت دوره‌های مقارن با ماه مبارک رمضان در اینجا نمایش داده خواهند شد.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
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
                padding: const EdgeInsets.only(bottom: 10),
                child: RitmoNeuSurface(
                  sunken: true,
                  radius: 16,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  PersianDigits.toFa(
                                    'بدهی روزه: ${debt.daysOwed} روز',
                                  ),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                if (debt.isResolved) ...[
                                  const SizedBox(width: 8),
                                  RitmoCardBadge(
                                    label: 'تسویه شده',
                                    color: colors.success,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'شروع دوره: $dateStr • ${debt.reason ?? "عذر شرعی"}',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      RitmoNeuButton(
                        height: 34,
                        radius: 12,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        onTap: () async {
                          await HapticFeedback.mediumImpact();
                          await CycleConsentBridge.resolveFastingDebt(
                            debt.id,
                            !debt.isResolved,
                          );
                          onReloadData();
                        },
                        child: Text(
                          debt.isResolved ? 'لغو تسویه' : 'ثبت تسویه',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: debt.isResolved
                                ? colors.textSecondary
                                : colors.primary,
                          ),
                        ),
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
