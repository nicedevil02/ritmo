import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import '../components/components.dart';
import 'mv_kind_picker_sheet.dart';

/// Sheet: "ساخت دورهٔ تمرینی هدف‌دار" (Section 5.3, 5.8 & S8-T7).
/// Connected to Ritmo canonical glass sheet scaffold, theme tokens, and Apple HIG detents.
class MvCreateCampaignSheet extends StatefulWidget {
  final ValueChanged<MvCampaign> onCreate;

  const MvCreateCampaignSheet({
    super.key,
    required this.onCreate,
  });

  static Future<void> show({
    required BuildContext context,
    required ValueChanged<MvCampaign> onCreate,
  }) {
    return MvSheetScaffold.show(
      context: context,
      builder: (ctx) => MvCreateCampaignSheet(onCreate: onCreate),
    );
  }

  @override
  State<MvCreateCampaignSheet> createState() => _MvCreateCampaignSheetState();
}

class _MvCreateCampaignSheetState extends State<MvCreateCampaignSheet> {
  DateTime _targetDate = DateTime.now().add(const Duration(days: 84)); // 12 weeks
  String _sportKindCode = MvKindCodes.hiking;
  String _sportKindTitleFa = 'کوهنوردی و پیمایش';
  String _sportKindEmoji = '🏔️';
  final TextEditingController _weightController = TextEditingController(text: '75');
  String? _errorMessage;

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _pickSportKind() async {
    final selectedKind = await MvKindPickerSheet.show(
      context: context,
      initialCode: _sportKindCode,
    );

    if (selectedKind != null && mounted) {
      setState(() {
        _sportKindCode = selectedKind.code;
        _sportKindTitleFa = selectedKind.titleFa;
        _sportKindEmoji = selectedKind.emoji;
      });
    }
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final days = _targetDate.difference(DateTime.now()).inDays;
    final weeks = (days / 7).round();

    if (weeks < 4) {
      setState(() {
        _errorMessage = l10n?.mv_campaign_too_short ??
            'Remaining time to event is less than 4 weeks';
      });
      return;
    }

    final now = DateTime.now();
    final campaign = MvCampaign(
      id: 'camp_${now.millisecondsSinceEpoch}',
      titleFa: l10n?.mv_campaign_hiking_title(_sportKindCode) ??
          'Goal Campaign: $_sportKindTitleFa',
      goalCode: _sportKindCode,
      startDate: MvCalendar.formatDateIso(now),
      weeks: weeks,
      status: 'ACTIVE',
      createdAt: now.millisecondsSinceEpoch,
      updatedAt: now.millisecondsSinceEpoch,
    );

    widget.onCreate(campaign);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    final remainingWeeks = _targetDate.difference(DateTime.now()).inDays ~/ 7;

    return MvSheetScaffold(
      title: l10n?.mv_campaign_create ?? 'Create Training Campaign',
      subtitle: 'برنامه‌ریزی معکوس و تمرین برای رویداد ورزشی',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. نوع ورزش هدف
          Text(
            l10n?.mv_campaign_target_sport ?? 'Target Sport:',
            style: textTheme.labelLarge?.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          RitmoNeuSurface(
            radius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            onTap: _pickSportKind,
            child: Row(
              children: [
                Text(_sportKindEmoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _sportKindTitleFa,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _sportKindCode,
                        style: textTheme.labelSmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_left_rounded,
                  color: colors.textSecondary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. تاریخ رویداد هدف
          Text(
            l10n?.mv_campaign_target_date ?? 'Target Event Date:',
            style: textTheme.labelLarge?.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          RitmoNeuSurface(
            radius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _targetDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() {
                  _targetDate = picked;
                  _errorMessage = null;
                });
              }
            },
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 20,
                  color: colors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n?.mv_campaign_weeks_later(
                          toPersianDigits(remainingWeeks.toString()),
                          toPersianDigits(MvCalendar.formatDateIso(_targetDate)),
                        ) ??
                        '$remainingWeeks weeks later (${MvCalendar.formatDateIso(_targetDate)})',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.edit_calendar_rounded,
                  size: 18,
                  color: colors.textSecondary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. وزن بدن (کیلوگرم)
          Text(
            l10n?.mv_campaign_body_weight ?? 'Body Weight (kg):',
            style: textTheme.labelLarge?.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          RitmoNeuSurface(
            sunken: true,
            radius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: TextField(
              key: const ValueKey('mv_campaign_weight_field'),
              controller: _weightController,
              keyboardType: TextInputType.number,
              style: textTheme.bodyLarge?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                hintText: '75',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: colors.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      key: const ValueKey('mv_campaign_error_text'),
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
      ),
      bottomAction: MvPrimaryAction(
        key: const ValueKey('mv_campaign_submit_btn'),
        label: l10n?.mv_campaign_submit ?? 'Create Campaign',
        icon: Icons.check_circle_outline_rounded,
        onPressed: _submit,
      ),
    );
  }
}
