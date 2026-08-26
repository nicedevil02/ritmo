import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/domain/realm/active_realm_resolver.dart';
import 'package:ritmo/core/domain/realm/presets/realm_presets.dart';
import 'package:ritmo/core/repositories/realm_repository.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/ritmo_color.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/widgets/ritmo_adaptive_row.dart';
import 'package:ritmo/core/widgets/ritmo_energy_dial.dart';
import 'package:ritmo/features/today/presentation/widgets/dashboard/realm_countdown_widget.dart';
import 'package:ritmo/features/today/presentation/widgets/realm_management_sheet.dart';
import 'package:ritmo/l10n/app_localizations.dart';

class ZoneCard extends StatelessWidget {

  // G-9: [currentEnergyPercent] از نوع nullable است؛ null یعنی «انرژی ثبت نشده».
  const ZoneCard({
    super.key,
    required this.isDarkMode,
    required this.currentEnergyPercent,
    required this.currentEnergyLabel,
    required this.currentEnergyDesc,
    required this.realmState,
    required this.activeZone,
    required this.activeZoneName,
    required this.activeZoneIcon,
    required this.activeZoneColorHex,
    required this.activeZoneRoutinesCount,
    required this.activeZoneTimeRange,
    required this.onEnergyTap,
    required this.onRealmChanged,
  });
  final bool isDarkMode;
  final double? currentEnergyPercent;
  final String currentEnergyLabel;
  final String currentEnergyDesc;
  final ActiveRealmState realmState;
  final Map<String, dynamic>? activeZone;
  final String? activeZoneName;
  final String? activeZoneIcon;
  final String? activeZoneColorHex;
  final int activeZoneRoutinesCount;
  final String? activeZoneTimeRange;
  final VoidCallback onEnergyTap;
  final VoidCallback onRealmChanged;

  static Color _parseColorSafe(String? colorStr, Color fallback) {
    return RitmoColor.fromHex(colorStr, fallback: fallback);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;

    final bool isOutOfZone = switch (realmState) {
      FreeRealmState() => true,
      ScheduledRealmState(:final isDefaultFallback, :final realm) =>
        isDefaultFallback && realm.id.isEmpty,
      ManualRealmState() => false,
      TriggeredRealmState() => false,
      RealmErrorState() => true,
    };
    final String realmName = isOutOfZone
        ? l10n.outOfRealm
        : (realmState.realmOrNull?.name ?? l10n.outOfRealm);
    final String realmTimeRange = switch (realmState) {
      ScheduledRealmState(:final schedule) =>
        toPersianDigits('${schedule.startTime} - ${schedule.endTime}'),
      ManualRealmState(:final remaining) =>
        toPersianDigits('فعال‌سازی دستی (${remaining.inMinutes} دقیقه)'),
      TriggeredRealmState(:final explanation) => explanation,
      FreeRealmState() => l10n.noActiveSchedule,
      RealmErrorState() => l10n.noActiveSchedule,
    };

    final Color energyColor;
    final IconData energyIcon;

    final isHigh = currentEnergyLabel == 'بالا' || currentEnergyLabel == 'High';
    final isLow = currentEnergyLabel == 'پایین' || currentEnergyLabel == 'Low';

    if (isHigh) {
      energyColor = colors.success;
      energyIcon = CupertinoIcons.flame_fill;
    } else if (isLow) {
      energyColor = colors.medicalRed;
      energyIcon = CupertinoIcons.moon_fill;
    } else {
      energyColor = colors.energyAccent;
      energyIcon = CupertinoIcons.bolt_fill;
    }

    final energyLabel = isHigh
        ? l10n.energyLevelHigh
        : isLow
            ? l10n.energyLevelLow
            : l10n.energyLevelMedium;

    final energyDesc = isHigh
        ? l10n.energyDescHigh
        : isLow
            ? l10n.energyDescLow
            : l10n.energyDescMedium;

    final m = context.metrics;

    final energyCard = RitmoTheme.glassCardLight(
      color: colors.card.withValues(alpha: 0.65),
      child: InkWell(
        onTap: onEnergyTap,
        borderRadius: BorderRadius.circular(m.radiusHero),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(m.radiusHero),
            gradient: RadialGradient(
              center: Alignment.topLeft,
              radius: 1.3,
              colors: [
                energyColor.withValues(alpha: 0.08),
                Colors.transparent,
              ],
            ),
          ),
          padding: EdgeInsets.all(m.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.currentEnergyTitle,
                    style: RitmoTextStyles.badge(
                      colors.textSecondary,
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: EdgeInsets.all(m.spaceXs),
                    decoration: BoxDecoration(
                      color: energyColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      energyIcon,
                      size: m.iconSm,
                      color: energyColor,
                    ),
                  ),
                ],
              ),
              SizedBox(height: m.spaceMd),
              Row(
                children: [
                  // Modern Thermostat-Style Energy Dial
                  RitmoEnergyDial(
                    percentage: currentEnergyPercent,
                    isDarkMode: isDarkMode,
                    size: 78.0 * m.densityFactor,
                    activeColor: energyColor,
                  ),
                  SizedBox(width: m.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          energyLabel,
                          style: RitmoTextStyles.titleMedium(
                            energyColor,
                          ).copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          energyDesc,
                          style: RitmoTextStyles.badge(
                            colors.textSecondary,
                          ).copyWith(height: 1.3),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: m.spaceMd),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: m.spaceSm,
                      vertical: m.spaceXs,
                    ),
                    decoration: BoxDecoration(
                      color: colors.textSecondary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(m.radiusCard),
                      border: Border.all(
                        color: colors.border.withValues(alpha: 0.5),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.manageEnergy,
                          style: RitmoTextStyles.badge(
                            colors.textPrimary,
                          ).copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          CupertinoIcons.chevron_left,
                          size: m.iconSm * 0.75,
                          color: colors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    final realmCard = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(m.radiusHero),
        gradient: !isOutOfZone
            ? RadialGradient(
                center: const Alignment(0.8, -0.6),
                radius: 1.2,
                colors: [
                  _parseColorSafe(activeZoneColorHex, colors.primary).withValues(alpha: 0.25),
                  colors.card.withValues(alpha: 0.65),
                ],
              )
            : null,
        color: isOutOfZone
            ? colors.card.withValues(alpha: 0.65)
            : null,
        border: Border.all(
          color: !isOutOfZone
              ? _parseColorSafe(activeZoneColorHex, colors.primary).withValues(alpha: 0.4)
              : colors.border.withValues(alpha: 0.5),
          width: !isOutOfZone
              ? 1.5
              : 1.0,
        ),
        boxShadow: !isOutOfZone
            ? [
                BoxShadow(
                  color: _parseColorSafe(activeZoneColorHex, colors.primary).withValues(alpha: 0.1),
                  blurRadius: 10,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(m.radiusHero),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (context) => RealmManagementSheet(
                  isDarkMode: isDarkMode,
                  onChanged: onRealmChanged,
                ),
              );
            },
            borderRadius: BorderRadius.circular(m.radiusHero),
            child: Padding(
              padding: EdgeInsets.all(m.spaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.currentRealmTitle,
                        style: RitmoTextStyles.badge(
                          colors.textSecondary,
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (activeZoneIcon != null)
                        Text(activeZoneIcon!, style: RitmoTextStyles.label(colors.textPrimary))
                      else
                        Icon(
                          CupertinoIcons.briefcase_fill,
                          size: m.iconSm,
                          color: _parseColorSafe(activeZoneColorHex, colors.primary),
                        ),
                    ],
                  ),
                  SizedBox(height: m.spaceMd),
                  Text(
                    realmName,
                    style: RitmoTextStyles.cardTitle(
                      colors.textPrimary,
                    ).copyWith(fontWeight: FontWeight.w900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    realmTimeRange,
                    style: RitmoTextStyles.caption(
                      colors.textSecondary,
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: m.spaceXs),
                  if (activeZone != null && !isOutOfZone)
                    Padding(
                      padding: EdgeInsets.only(bottom: m.spaceXs),
                      child: RealmCountdownWidget(
                        activeZone: activeZone!,
                        style: RitmoTextStyles.badge(
                          _parseColorSafe(
                            activeZoneColorHex,
                            colors.primary,
                          ),
                        ),
                      ),
                    ),
                  Text(
                    isOutOfZone
                        ? l10n.logNewDailyRealm
                        : l10n.routinesConnectedToRealm(
                          activeZoneRoutinesCount,
                        ),
                    style: RitmoTextStyles.badge(
                      _parseColorSafe(
                        activeZoneColorHex,
                        colors.primary,
                      ),
                    ),
                  ),
                  if (isOutOfZone) ...[
                    SizedBox(height: m.spaceSm),
                    _buildPresetChips(context, colors, m),
                  ],
                  SizedBox(height: m.spaceMd),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: m.spaceSm,
                      vertical: m.spaceXs,
                    ),
                    decoration: BoxDecoration(
                      color: colors.textSecondary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(m.radiusCard),
                      border: Border.all(
                        color: colors.border.withValues(alpha: 0.5),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isOutOfZone ? l10n.addRealm : l10n.manageRealm,
                          style: RitmoTextStyles.badge(
                            colors.textPrimary,
                          ).copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          CupertinoIcons.chevron_left,
                          size: m.iconSm * 0.75,
                          color: colors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // F-04: realmCard is now PRIMARY to give time realms prominent visual hierarchy
    return RitmoAdaptiveRow(
      primary: realmCard,
      secondary: energyCard,
      spacing: m.spaceMd,
      minWidthForRow: 280.0,
      crossAxisAlignment: CrossAxisAlignment.start,
      expandSecondary: true,
    );
  }

  Widget _buildPresetChips(BuildContext context, RitmoColors colors, RitmoMetrics m) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: RealmPreset.standardPresets.map((preset) {
          final presetColor = _parseColorSafe(preset.colorHex, colors.primary);
          return Padding(
            padding: const EdgeInsets.only(left: 6),
            child: InkWell(
              onTap: () async {
                await RealmRepository().createFromPreset(preset);
                onRealmChanged();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('قلمرو «${preset.name}» با موفقیت فعال شد'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              borderRadius: BorderRadius.circular(m.radiusCard),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: m.spaceSm,
                  vertical: m.spaceXs,
                ),
                decoration: BoxDecoration(
                  color: presetColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(m.radiusCard),
                  border: Border.all(
                    color: presetColor.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(preset.icon, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(
                      preset.name.split(' ').first,
                      style: RitmoTextStyles.badge(
                        presetColor,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
