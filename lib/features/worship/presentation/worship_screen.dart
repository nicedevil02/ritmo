import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0.0);

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
    _scrollOffset.dispose();
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
    final contentTopPadding = topPadding + 130.0;

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
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.axis == Axis.vertical) {
                      _scrollOffset.value = notification.metrics.pixels;
                    }
                    return false;
                  },
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
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

              // Layer 2: Apple Dynamic Large Title Morphing Glass Header (Unified Single Capsule)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: _scrollOffset,
                  builder: (context, _) {
                    return RitmoAppleMorphingGlassHeader(
                      title: 'عبادت و معنویت',
                      subtitle: _worshipDay != null ? '$_cityName • ${_worshipDay!.hijri.formatted}' : 'اوقات شرعی، تقویم شمسی و قمری و اذکار',
                      scrollOffset: _scrollOffset.value,
                      collapseDistance: 55.0,
                      onBack: () => Navigator.maybePop(context),
                      actions: [
                        RitmoVibrancyActionButton(
                          icon: CupertinoIcons.sparkles,
                          iconColor: colors.primary,
                          isAiButton: true,
                          accentColor: colors.primary,
                          tooltip: 'دستیار معنوی هوشمند',
                          onTap: _openAiAssistantSheet,
                        ),
                        const SizedBox(width: 8),
                        RitmoVibrancyActionButton(
                          icon: CupertinoIcons.compass,
                          iconColor: colors.accent,
                          tooltip: 'قبله‌نما',
                          onTap: _openQiblaCompass,
                        ),
                        const SizedBox(width: 8),
                        RitmoVibrancyActionButton(
                          icon: CupertinoIcons.settings,
                          iconColor: isDark ? const Color(0xFF9096A2) : const Color(0xFF6B7280),
                          tooltip: 'تنظیمات عبادات',
                          onTap: _openWorshipSettings,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
