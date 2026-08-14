import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/personas/persona_registry.dart';
import 'package:ritmo/core/services/prayer_time_provider.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/ux/ritmo_skeleton.dart';
import 'package:ritmo/core/widgets/ritmo_module_app_bar.dart';
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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final now = DateTime.now();
      final day = await WorshipEngine.instance.loadDay(now);

      if (mounted) {
        setState(() {
          _worshipDay = day;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading worship screen data: $e');
      await Future.delayed(const Duration(milliseconds: 500));
      try {
        final day = await WorshipEngine.instance.loadDay(DateTime.now());
        if (mounted) {
          setState(() {
            _worshipDay = day;
            _isLoading = false;
          });
        }
      } catch (e2) {
        debugPrint('Retry error loading worship screen data: $e2');
        if (mounted) {
          final now = DateTime.now();
          final fallbackTimes = await WorshipEngine.instance.prayerTimes(now);
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
      final db = await DatabaseHelper.instance.database;
      final settings = await db.query('app_settings', where: 'key = ?', whereArgs: ['prayer_city_id'], limit: 1);
      final cityId = settings.isNotEmpty ? settings.first['value']! as String : 'TEHRAN_TEHRAN';
      
      await PrayerTimeProvider.instance.cachePrayerTimes(cityId: cityId, date: DateTime.now());
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
          cityName: _worshipDay?.times.cityId ?? 'تهران',
        );
      },
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RitmoTheme.buildBackgroundContainer(
        context: context,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: RefreshIndicator(
              color: const Color(0xffD4A843),
              backgroundColor: isDarkMode ? const Color(0xff2A2D3D) : Colors.white,
              onRefresh: _refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(
                  children: [
                    // 1. MODULE APP BAR WITH QUICK ACTIONS & STATUS BADGES
                    RitmoModuleAppBar(
                      title: 'عبادت و معنویت',
                      subtitle: _worshipDay != null
                          ? '${_worshipDay!.times.cityId} • ${_worshipDay!.hijri.formatted}'
                          : 'در حال بارگذاری...',
                      actions: [
                        IconButton(
                          icon: const Icon(CupertinoIcons.sparkles, color: Color(0xffD4A843)),
                          tooltip: 'دستیار معنوی هوشمند',
                          onPressed: _openAiAssistantSheet,
                        ),
                        IconButton(
                          icon: const Icon(CupertinoIcons.compass, color: Color(0xffC4953B)),
                          tooltip: 'قبله‌نما',
                          onPressed: _openQiblaCompass,
                        ),
                        IconButton(
                          icon: Icon(CupertinoIcons.settings, color: isDarkMode ? Colors.white70 : Colors.black87),
                          tooltip: 'تنظیمات محاسبه',
                          onPressed: () => _openCityPicker(1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_isLoading && _worshipDay == null) ...[
                      const RitmoSkeletonCard(height: 320),
                      const SizedBox(height: 16),
                    ] else if (_worshipDay != null) ...[
                      // 1. PRAYER ARC HERO
                      PrayerArcHero(
                        day: _worshipDay!,
                        onPracticeToggle: (practiceId, isDone) async {
                          String group = 'FAJR';
                          if (practiceId.contains('dhuhr') || practiceId.contains('asr')) group = 'DHUHR_ASR';
                          if (practiceId.contains('maghrib') || practiceId.contains('isha')) group = 'MAGHRIB_ISHA';

                          if (isDone) {
                            final target = await PrayerTarget.fromGroupKey(group, DateTime.now());
                            if (!context.mounted) return;
                            await PrayerSheet.show(context, target);
                          } else {
                            final target = await PrayerTarget.fromGroupKey(group, DateTime.now());
                            for (final pId in target.practiceIds) {
                              await WorshipEngine.instance.clearLog(practiceId: pId, date: DateTime.now());
                            }
                          }
                          _onDataChanged();
                        },
                        onTravellerToggle: (isTraveller) async {
                          final currentCtx = _worshipDay?.context;
                          final ctx = WorshipDayContext(
                            date: currentCtx?.date ?? DateTime.now(),
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
                      const SizedBox(height: 12),

                      // 2. NIGHT PRAYER RITUAL CARD (after Shari Midnight)
                      NightPrayerCard(
                        day: _worshipDay!,
                        onComplete: _onDataChanged,
                      ),
                      const SizedBox(height: 12),

                      // 3. PREMIUM SOLAR WORSHIP CALENDAR & REACTIVE DETAIL PANEL (INCLUDES OBLIGATORY PRAYERS & MUSTAHABS)
                      WorshipSolarCalendar(
                        initialJalali: Jalali.now(),
                        hijriOffset: WorshipEngine.instance.hijriOffset,
                        qamariNightText: _getQamariNightText(),
                        onChanged: _onDataChanged,
                      ),
                      const SizedBox(height: 16),

                      // 4. QURAN & DHIKR
                      QuranDhikrSection(
                        onChanged: _onDataChanged,
                      ),
                      const SizedBox(height: 24),

                      // 5. SCHEDULED MUSTAHABAT ("مستحبات برنامه‌ریزی‌شده")
                      MustahabSection(
                        onChanged: _onDataChanged,
                      ),
                      const SizedBox(height: 24),

                      // 6. DEBTS ("جبران")
                      WorshipDebtsSection(
                        onChanged: _onDataChanged,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
