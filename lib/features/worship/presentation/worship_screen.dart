import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/domain/personas/persona_registry.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

import 'package:ritmo/core/ux/ritmo_skeleton.dart';
import 'package:ritmo/features/assistant/presentation/widgets/unified_assistant_sheet.dart';
import 'package:ritmo/features/worship/domain/prayer_target.dart';
import 'package:ritmo/features/worship/logic/worship_engine.dart';
import 'package:ritmo/features/worship/models/worship_models.dart';
import 'package:ritmo/features/worship/presentation/widgets/mustahab_section.dart';
import 'package:ritmo/features/worship/presentation/widgets/night_prayer_card.dart';
import 'package:ritmo/features/worship/presentation/widgets/prayer_arc_hero.dart';
import 'package:ritmo/features/worship/presentation/widgets/prayer_city_picker.dart';
import 'package:ritmo/features/worship/presentation/widgets/prayer_sheet.dart';
import 'package:ritmo/features/worship/presentation/widgets/qibla_compass_sheet.dart';
import 'package:ritmo/features/worship/presentation/widgets/quran_dhikr_section.dart';
import 'package:ritmo/features/worship/presentation/widgets/worship_debts_section.dart';
import 'package:ritmo/features/worship/presentation/widgets/worship_settings_sheet.dart';
import 'package:ritmo/features/worship/presentation/widgets/worship_solar_calendar.dart';
import 'package:shamsi_date/shamsi_date.dart';

class WorshipScreen extends StatefulWidget {
  const WorshipScreen({super.key});

  @override
  State<WorshipScreen> createState() => _WorshipScreenState();
}

class _WorshipScreenState extends State<WorshipScreen> {
  WorshipDay? _worshipDay;
  bool _isLoading = true;
  bool _isNightPrayerEnabled = false;
  String _cityName = 'تهران';
  Timer? _debounceTimer;
  StreamSubscription<dynamic>? _eventSub;

  @override
  void initState() {
    super.initState();
    _loadData();
    _eventSub = RitmoEventBus().onEvents.listen((event) {
      if (event.type == 'WorshipUpdated' ||
          event.type == 'WorshipPracticeChanged' ||
          event.type == RitmoEventType.completionRecorded.code) {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 300), () {
          if (mounted) {
            _loadData();
          }
        });
      }
    });
  }


  @override
  void dispose() {
    _debounceTimer?.cancel();
    _eventSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final now = DateTime.now();
      final day = await WorshipEngine.instance.loadDay(now);
      final name = await WorshipEngine.instance.getCityName();
      final nightEnabled = await WorshipEngine.instance.isNightPrayerEnabled();

      if (mounted) {
        setState(() {
          _cityName = name;
          _worshipDay = day;
          _isNightPrayerEnabled = nightEnabled;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading worship screen data: $e');
      await Future.delayed(const Duration(milliseconds: 500));
      try {
        final now = DateTime.now();
        final day = await WorshipEngine.instance.loadDay(now);
        final name = await WorshipEngine.instance.getCityName();
        final nightEnabled = await WorshipEngine.instance.isNightPrayerEnabled();
        if (mounted) {
          setState(() {
            _cityName = name;
            _worshipDay = day;
            _isNightPrayerEnabled = nightEnabled;
            _isLoading = false;
          });
        }
      } catch (e2) {
        debugPrint('Retry error loading worship screen data: $e2');
        if (mounted) {
          final now = DateTime.now();
          final fallbackTimes = await WorshipEngine.instance.prayerTimes(now);
          final nightEnabled = await WorshipEngine.instance.isNightPrayerEnabled();
          setState(() {
            _worshipDay = WorshipDay(
              date: now,
              hijri: WorshipEngine.instance.hijriFor(now),
              times: fallbackTimes,
              practices: [],
              seasons: [],
              context: WorshipDayContext(date: now),
              occasions: [],
            );
            _isNightPrayerEnabled = nightEnabled;
            _isLoading = false;
          });
        }
      }
    }
  }

  void _onDataChanged() {
    _loadData();
  }

  Future<void> _refresh() async {
    unawaited(HapticFeedback.mediumImpact());
    try {
      await WorshipEngine.instance.refreshPrayerTimes(date: _worshipDay?.date);
      _onDataChanged();
    } catch (e) {
      debugPrint('Error refreshing worship screen: $e');
    }
  }


  void _openCityPicker(int tabIndex) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return PrayerCityPicker(
          initialTab: tabIndex,
          onChanged: _onDataChanged,
        );
      },
    );
  }

  void _openAiAssistantSheet() {
    final persona = PersonaRegistry.instance.getPersona('worship') ?? PersonaRegistry.instance.getPersona('global');
    if (persona != null) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => AssistantSheet(persona: persona),
      );
    }
  }

  void _openQiblaCompass() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return QiblaCompassSheet(
          cityName: _cityName,
        );
      },
    );
  }

  void _openWorshipSettings() {
    WorshipSettingsSheet.present(
      context,
      onChanged: _onDataChanged,
    );
  }

  String? _getQamariNightText() {
    if (_worshipDay == null) return null;
    final now = DateTime.now();
    final maghribTime = _worshipDay!.times.maghrib;
    if (now.isAfter(maghribTime)) {
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      final tomorrowHijri = WorshipEngine.instance.hijriFor(tomorrow);
      return 'امشب: شب ${toPersianDigits(tomorrowHijri.day.toString())} ${tomorrowHijri.monthName}';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.paddingOf(context).top;
    final contentTopPadding = topPadding + 76.0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RitmoTheme.buildBackgroundContainer(
        context: context,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              // Layer 1: Body Content
              Positioned.fill(
                child: RefreshIndicator(
                  color: colors.primary,
                  backgroundColor: colors.surface,
                  onRefresh: _refresh,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(16, contentTopPadding, 16, 100),
                    child: Column(
                      children: [
                        if (_isLoading && _worshipDay == null) ...[
                          const RitmoSkeletonCard(height: 320),
                          const SizedBox(height: 16),
                        ] else if (_worshipDay != null) ...[
                          // 1. PRAYER ARC HERO
                          PrayerArcHero(
                            day: _worshipDay!,
                            onPracticeToggle: (practiceId, isDone) async {
                              final dayDate = _worshipDay!.date;
                              String group = 'FAJR';
                              if (practiceId.contains('dhuhr') || practiceId.contains('asr')) group = 'DHUHR_ASR';
                              if (practiceId.contains('maghrib') || practiceId.contains('isha')) group = 'MAGHRIB_ISHA';

                              if (isDone) {
                                final target = await PrayerTarget.fromGroupKey(group, dayDate);
                                if (!context.mounted) return;
                                final res = await PrayerSheet.show(context, target);
                                if (res == true) {
                                  _onDataChanged();
                                }
                              } else {
                                final target = await PrayerTarget.fromGroupKey(group, dayDate);
                                for (final pId in target.practiceIds) {
                                  await WorshipEngine.instance.clearLog(practiceId: pId, date: dayDate);
                                }
                                _onDataChanged();
                              }
                            },
                            onTravellerToggle: (isTraveller) async {
                              final currentCtx = _worshipDay?.context;
                              final dayDate = _worshipDay?.date ?? DateTime.now();
                              final ctx = WorshipDayContext(
                                date: currentCtx?.date ?? dayDate,
                                isTraveller: isTraveller,
                                prayerExempt: currentCtx?.prayerExempt ?? false,
                                fastingExempt: isTraveller || (currentCtx?.fastingExempt ?? false),
                                reason: isTraveller ? 'TRAVEL' : currentCtx?.reason,
                              );
                              await WorshipEngine.instance.setDayContext(ctx);
                              _onDataChanged();
                            },
                            onOpenCityPicker: () => _openCityPicker(0),
                          ),
                          const SizedBox(height: 16),

                          // 2. NIGHT PRAYER RITUAL CARD
                          if (_isNightPrayerEnabled) ...[
                            NightPrayerCard(
                              day: _worshipDay!,
                              onComplete: _onDataChanged,
                            ),
                            const SizedBox(height: 16),
                          ],

                          // 3. SOLAR / LUNAR INTEGRATED CALENDAR
                          WorshipSolarCalendar(
                            initialJalali: Jalali.now(),
                            hijriOffset: WorshipEngine.instance.hijriOffset,
                            qamariNightText: _getQamariNightText(),
                            onChanged: _onDataChanged,
                          ),
                          const SizedBox(height: 16),

                          // 4. QURAN & DHIKR ("تلاوت و اذکار")
                          QuranDhikrSection(
                            onChanged: _onDataChanged,
                          ),
                          const SizedBox(height: 16),

                          // 5. SCHEDULED MUSTAHABAT ("مستحبات برنامه‌ریزی‌شده")
                          MustahabSection(
                            onChanged: _onDataChanged,
                          ),
                          const SizedBox(height: 16),

                          // 6. DEBTS ("جبران")
                          WorshipDebtsSection(
                            onChanged: _onDataChanged,
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // Layer 2: Floating Capsule Header Island
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                    child: _buildCapsuleHeader(context, isDark, colors),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCapsuleHeader(
    BuildContext context,
    bool isDark,
    RitmoColors colors,
  ) {
    final capsuleBgColor = isDark
        ? const Color(0xFF1E222A).withValues(alpha: 0.86)
        : Colors.white.withValues(alpha: 0.88);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.90);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.50)
                : const Color(0xFFCBD5E1).withValues(alpha: 0.65),
            offset: const Offset(0, 5),
            blurRadius: 14,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.90),
            offset: const Offset(0, -1),
            blurRadius: 3,
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: capsuleBgColor,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: borderColor,
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                if (Navigator.canPop(context))
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 38,
                      minHeight: 38,
                    ),
                    icon: Icon(
                      CupertinoIcons.arrow_right,
                      color: isDark ? Colors.white : const Color(0xFF1D2129),
                      size: 20,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                  )
                else
                  const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'عبادت و معنویت',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16.5,
                          letterSpacing: -0.4,
                          color: isDark ? Colors.white : const Color(0xFF1D2129),
                        ),
                      ),
                      if (_worshipDay != null)
                        Text(
                          '$_cityName • ${_worshipDay!.hijri.formatted}',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? const Color(0xFF8E95A3) : const Color(0xFF6B7280),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                _buildHeaderActionButton(
                  icon: CupertinoIcons.sparkles,
                  iconColor: colors.primary,
                  isAiButton: true,
                  isDark: isDark,
                  tooltip: 'دستیار معنوی هوشمند',
                  onTap: _openAiAssistantSheet,
                ),
                _buildHeaderActionButton(
                  icon: CupertinoIcons.compass,
                  iconColor: colors.accent,
                  isDark: isDark,
                  tooltip: 'قبله‌نما',
                  onTap: _openQiblaCompass,
                ),
                _buildHeaderActionButton(
                  icon: CupertinoIcons.settings,
                  iconColor: isDark ? const Color(0xFF9096A2) : const Color(0xFF6B7280),
                  isDark: isDark,
                  tooltip: 'تنظیمات عبادات',
                  onTap: _openWorshipSettings,
                ),
                const SizedBox(width: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderActionButton({
    required IconData icon,
    required Color iconColor,
    required bool isDark,
    required VoidCallback onTap,
    String? tooltip,
    bool isAiButton = false,
  }) {
    final button = GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: _buildHeaderActionButtonContent(
        icon: icon,
        iconColor: iconColor,
        isDark: isDark,
        isAiButton: isAiButton,
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: button);
    }
    return button;
  }

  Widget _buildHeaderActionButtonContent({
    required IconData icon,
    required Color iconColor,
    required bool isDark,
    bool isAiButton = false,
  }) {
    return Container(
      width: 36,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark
            ? (isAiButton
                ? iconColor.withValues(alpha: 0.18)
                : const Color(0xFF22262E))
            : (isAiButton
                ? iconColor.withValues(alpha: 0.12)
                : const Color(0xFFF3F5F8)),
        border: Border.all(
          color: isDark
              ? (isAiButton
                  ? iconColor.withValues(alpha: 0.40)
                  : Colors.white.withValues(alpha: 0.08))
              : (isAiButton
                  ? iconColor.withValues(alpha: 0.30)
                  : Colors.white.withValues(alpha: 0.90)),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.white.withValues(alpha: 0.95),
            offset: const Offset(-2, -2),
            blurRadius: 4,
          ),
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.55)
                : const Color(0xFFB5C0CD).withValues(alpha: 0.65),
            offset: const Offset(2, 2),
            blurRadius: 4,
          ),
          if (isAiButton)
            BoxShadow(
              color: iconColor.withValues(alpha: isDark ? 0.35 : 0.22),
              blurRadius: 10,
              spreadRadius: 1.0,
            ),
        ],
      ),
      child: Center(
        child: Icon(
          icon,
          size: 18,
          color: isAiButton
              ? iconColor
              : (isDark ? const Color(0xFF9096A2) : const Color(0xFF6B7280)),
        ),
      ),
    );
  }
}
