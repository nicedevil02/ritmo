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

class _WorshipScreenState extends State<WorshipScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _headerMorphAnimCtrl;
  Animation<double>? _headerMorphAnim;

  WorshipDay? _worshipDay;
  bool _isLoading = true;
  bool _isNightPrayerEnabled = false;
  String _cityName = 'تهران';
  Timer? _debounceTimer;
  StreamSubscription<dynamic>? _eventSub;

  // Multi-Tab Scroll Synchronization Controllers & State
  final List<ScrollController> _tabScrollControllers = [
    ScrollController(),
    ScrollController(),
    ScrollController(),
  ];
  final List<double> _tabOffsets = [0.0, 0.0, 0.0];
  final List<bool> _tabExpanded = [true, true, true];

  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0.0);
  final ValueNotifier<bool> _isTabsExpanded = ValueNotifier<bool>(true);
  double _accumulatedUpScroll = 0.0;

  @override
  void initState() {
    super.initState();
    _headerMorphAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _headerMorphAnimCtrl.addListener(() {
      if (_headerMorphAnim != null) {
        _scrollOffset.value = _headerMorphAnim!.value;
      }
    });

    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging ||
          _tabController.animation?.value == _tabController.index.toDouble()) {
        _syncHeaderWithActiveTab(_tabController.index, animate: true);
        if (mounted) setState(() {});
      }
    });
    _tabController.animation?.addListener(() {
      final value = _tabController.animation?.value ?? 0.0;
      final roundIndex = value.round().clamp(0, 2);
      if ((value - roundIndex).abs() < 0.05 && _tabController.index == roundIndex) {
        _syncHeaderWithActiveTab(roundIndex, animate: true);
      }
    });

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
    _headerMorphAnimCtrl.dispose();
    for (final controller in _tabScrollControllers) {
      controller.dispose();
    }
    _tabController.dispose();
    _scrollOffset.dispose();
    _isTabsExpanded.dispose();
    super.dispose();
  }

  void _syncHeaderWithActiveTab(int activeIndex, {bool animate = true}) {
    if (activeIndex < 0 || activeIndex >= _tabOffsets.length) return;
    final controller = _tabScrollControllers[activeIndex];
    final targetOffset = controller.hasClients ? controller.offset : _tabOffsets[activeIndex];
    _tabOffsets[activeIndex] = targetOffset;

    final currentOffset = _scrollOffset.value;
    final isExpanded = targetOffset <= 75.0 || _tabExpanded[activeIndex];
    _isTabsExpanded.value = isExpanded;
    _accumulatedUpScroll = 0.0;

    if (animate && (targetOffset - currentOffset).abs() > 1.0) {
      _headerMorphAnimCtrl.stop();
      _headerMorphAnim = Tween<double>(
        begin: currentOffset,
        end: targetOffset,
      ).animate(
        CurvedAnimation(
          parent: _headerMorphAnimCtrl,
          curve: Curves.easeOutCubic,
        ),
      );
      _headerMorphAnimCtrl.forward(from: 0.0);
    } else {
      _headerMorphAnimCtrl.stop();
      _scrollOffset.value = targetOffset;
    }
  }

  void _onTabScroll(int tabIndex, ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return;
    final pixels = notification.metrics.pixels;
    _tabOffsets[tabIndex] = pixels;

    // Only update the active header if this scroll notification came from the currently visible tab
    if (_tabController.index == tabIndex) {
      if (_headerMorphAnimCtrl.isAnimating) {
        _headerMorphAnimCtrl.stop();
      }
      _scrollOffset.value = pixels;

      if (pixels <= 20) {
        _accumulatedUpScroll = 0.0;
        if (!_isTabsExpanded.value) {
          _isTabsExpanded.value = true;
          _tabExpanded[tabIndex] = true;
        }
      } else if (notification is ScrollUpdateNotification) {
        final delta = notification.scrollDelta ?? 0.0;
        if (delta > 1.0) {
          _accumulatedUpScroll = 0.0;
          if (pixels > 75 && _isTabsExpanded.value) {
            _isTabsExpanded.value = false;
            _tabExpanded[tabIndex] = false;
          }
        } else if (delta < -1.0) {
          _accumulatedUpScroll += -delta;
          if (_accumulatedUpScroll > 28.0 && !_isTabsExpanded.value) {
            _isTabsExpanded.value = true;
            _tabExpanded[tabIndex] = true;
          }
        }
      } else if (notification is ScrollEndNotification) {
        _accumulatedUpScroll = 0.0;
      }
    }
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
    final contentTopPadding = topPadding + 190.0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RitmoTheme.buildBackgroundContainer(
        context: context,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              // Layer 1: Body Content with Multi-Tab TabBarView
              Positioned.fill(
                child: (_isLoading && _worshipDay == null)
                    ? Padding(
                        padding: EdgeInsets.fromLTRB(10, contentTopPadding, 10, 100),
                        child: const RitmoSkeletonCard(height: 320),
                      )
                    : TabBarView(
                        controller: _tabController,
                        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                        children: [
                          // ─── TAB 0: امروز ───
                          _WorshipTabKeepAlive(
                            child: NotificationListener<ScrollNotification>(
                              onNotification: (n) {
                                _onTabScroll(0, n);
                                return false;
                              },
                              child: ListView(
                                controller: _tabScrollControllers[0],
                                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                                padding: EdgeInsets.fromLTRB(10, contentTopPadding, 10, 100),
                                children: [
                                  if (_worshipDay != null) ...[
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

                                    // 3. QURAN & DHIKR ("تلاوت و اذکار")
                                    QuranDhikrSection(
                                      onChanged: _onDataChanged,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),

                          // ─── TAB 1: گاه‌شمار و اعمال ───
                          _WorshipTabKeepAlive(
                            child: NotificationListener<ScrollNotification>(
                              onNotification: (n) {
                                _onTabScroll(1, n);
                                return false;
                              },
                              child: ListView(
                                controller: _tabScrollControllers[1],
                                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                                padding: EdgeInsets.fromLTRB(10, contentTopPadding, 10, 100),
                                children: [
                                  // 1. SOLAR / LUNAR INTEGRATED CALENDAR
                                  WorshipSolarCalendar(
                                    initialJalali: Jalali.now(),
                                    hijriOffset: WorshipEngine.instance.hijriOffset,
                                    qamariNightText: _getQamariNightText(),
                                    onChanged: _onDataChanged,
                                  ),
                                  const SizedBox(height: 16),

                                  // 2. SCHEDULED MUSTAHABAT ("مستحبات و اعمال هفتگی")
                                  MustahabSection(
                                    onChanged: _onDataChanged,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // ─── TAB 2: قضا و جبران ───
                          _WorshipTabKeepAlive(
                            child: NotificationListener<ScrollNotification>(
                              onNotification: (n) {
                                _onTabScroll(2, n);
                                return false;
                              },
                              child: ListView(
                                controller: _tabScrollControllers[2],
                                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                                padding: EdgeInsets.fromLTRB(10, contentTopPadding, 10, 100),
                                children: [
                                  // DEBTS ("سامانه قضای نماز و روزه")
                                  WorshipDebtsSection(
                                    onChanged: _onDataChanged,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
              ),

              // Layer 2: Apple Dynamic Large Title Morphing Glass Header with Quick-Return Liquid Tabs
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_scrollOffset, _isTabsExpanded]),
                  builder: (context, _) {
                    return RitmoAppleMorphingGlassHeader(
                      title: 'عبادت و معنویت',
                      subtitle: _worshipDay != null
                          ? '$_cityName • ${_worshipDay!.hijri.formatted}'
                          : 'اوقات شرعی، تقویم شمسی و قمری و اذکار',
                      scrollOffset: _scrollOffset.value,
                      collapseDistance: 55.0,
                      isTabsExpanded: _isTabsExpanded.value,
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
                      tabs: RitmoGlassSegmentedControl<int>(
                        items: const [
                          RitmoTabItem(
                            title: 'امروز',
                            icon: CupertinoIcons.sun_max_fill,
                            value: 0,
                          ),
                          RitmoTabItem(
                            title: 'گاه‌شمار و اعمال',
                            icon: CupertinoIcons.calendar,
                            value: 1,
                          ),
                          RitmoTabItem(
                            title: 'قضا و جبران',
                            icon: CupertinoIcons.check_mark_circled_solid,
                            value: 2,
                          ),
                        ],
                        selectedIndex: _tabController.index.clamp(0, 2),
                        onTabChanged: (index) {
                          _tabController.animateTo(index);
                          _syncHeaderWithActiveTab(index);
                          setState(() {});
                        },
                      ),
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

/// ویجت ایزوله‌سازی برای حفظ وضعیت تب‌ها و دستیابی به عملکرد ۱۲۰ فریم
class _WorshipTabKeepAlive extends StatefulWidget {
  const _WorshipTabKeepAlive({required this.child});
  final Widget child;

  @override
  State<_WorshipTabKeepAlive> createState() => _WorshipTabKeepAliveState();
}

class _WorshipTabKeepAliveState extends State<_WorshipTabKeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
