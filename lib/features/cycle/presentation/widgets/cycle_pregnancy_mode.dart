// C-43, C-44: CyclePregnancyModeView
// Decomposed into modular widgets, clean theme tokens, Persian digits, and < 800 lines.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/domain/personas/persona_registry.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/assistant/presentation/widgets/unified_assistant_sheet.dart';
import 'package:ritmo/features/cycle/logic/cycle_clock.dart';
import 'package:ritmo/features/cycle/logic/pregnancy_settings.dart';
import 'package:ritmo/features/cycle/presentation/widgets/kick_session_tracker.dart';
import 'package:ritmo/features/cycle/presentation/widgets/pregnancy/pregnancy_header.dart';
import 'package:ritmo/features/cycle/presentation/widgets/pregnancy/pregnancy_progress_tab.dart';
import 'package:ritmo/features/cycle/presentation/widgets/pregnancy/pregnancy_settings_sheet.dart';
import 'package:ritmo/features/cycle/presentation/widgets/pregnancy/pregnancy_tabs.dart';
import 'package:ritmo/features/health/data/pregnancy_repository.dart';

class CyclePregnancyModeView extends StatefulWidget {
  const CyclePregnancyModeView({
    super.key,
    required this.pregnancyStartDate,
    required this.pregnancyDueDate,
    required this.onDeactivated,
    required this.settings,
    required this.dayLogs,
    this.engineOutput,
  });

  final String pregnancyStartDate;
  final String pregnancyDueDate;
  final VoidCallback onDeactivated;
  final Map<String, String> settings;
  final List<Map<String, dynamic>> dayLogs;
  final CycleEngineOutput? engineOutput;

  @override
  State<CyclePregnancyModeView> createState() => _CyclePregnancyModeViewState();
}

class _CyclePregnancyModeViewState extends State<CyclePregnancyModeView>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;

  late DateTime _startDate;
  late DateTime _dueDate;
  late int _diffDays;
  late int _currentWeek;
  late int _currentDayInWeek;
  late int _remainingDays;
  late double _progressPercent;

  // UX-12 Neutral tone setting
  String _pregTone = 'warm';

  // UX-13 EDD source
  String _eddSource = 'lmp';
  bool _showCountdown = true;

  // UX-04 KickSessionTracker
  int _kickTargetCount = 10;
  int _kickWindowMinutes = 120;
  KickSessionTracker _kickTracker = KickSessionTracker();
  double? _personalBaselineSecs;
  String? _baselineFeedback;

  // UX-10 Hospital Bag items
  List<Map<String, dynamic>> _hospitalBagItems = [];

  // Logs state
  final List<String> _selectedSymptoms = [];
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 5, vsync: this);
    _calculateValues();
    _loadSettingsAndSession();
    _loadHospitalBag();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadSettingsAndSession() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('app_settings');
      final map = <String, String>{};
      for (final r in rows) {
        map[r['key'] as String] = r['value'] as String;
      }

      _pregTone = map['preg_tone'] ?? 'warm';
      _eddSource = map['preg_edd_source'] ?? 'lmp';
      _showCountdown = map['preg_show_countdown'] != 'false';
      _kickTargetCount =
          int.tryParse(map['preg_kick_target_count'] ?? '') ?? 10;
      _kickWindowMinutes =
          int.tryParse(map['preg_kick_window_minutes'] ?? '') ?? 120;

      // Restore active kick session
      final restored = await KickSessionTracker.restoreFromSettings(
        CycleClock.now,
        target: _kickTargetCount,
        limit: Duration(minutes: _kickWindowMinutes),
      );
      if (restored != null) {
        _kickTracker = restored;
      } else {
        _kickTracker = KickSessionTracker(
          target: _kickTargetCount,
          limit: Duration(minutes: _kickWindowMinutes),
        );
      }

      // Load kick baseline
      final active = await PregnancyRepository.instance.getActiveTracker();
      final trackerId = active?['id'] as String? ?? 'preg_default';
      _personalBaselineSecs =
          await KickSessionTracker.getPersonalBaselineDurationSecs(
            pregnancyId: trackerId,
          );

      if (mounted) setState(() {});
    } catch (e, st) {
      RitmoLog.error(
        'CyclePregnancyMode',
        'Error restoring settings: $e',
        e,
        st,
      );
    }
  }

  Future<void> _loadHospitalBag() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: ['preg_hospital_bag'],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final jsonStr = rows.first['value'] as String?;
        if (jsonStr != null && jsonStr.isNotEmpty) {
          final decoded = jsonDecode(jsonStr) as List;
          _hospitalBagItems = decoded
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      }

      if (_hospitalBagItems.isEmpty) {
        _hospitalBagItems = [
          {'title': 'مدارک شناسایی و کارت بیمه', 'done': false},
          {'title': 'برگه‌های آزمایش و سونوگرافی', 'done': false},
          {'title': 'لباس راحتی برای مادر', 'done': false},
          {'title': 'لباس و پوشک نوزاد', 'done': false},
          {'title': 'شارژر و پاوربانک', 'done': false},
          {'title': 'وسایل بهداشتی شخصی', 'done': false},
          {'title': 'خوراکی سبک', 'done': false},
        ];
      }

      if (mounted) setState(() {});
    } catch (e, st) {
      RitmoLog.error(
        'CyclePregnancyMode',
        'Error loading hospital bag: $e',
        e,
        st,
      );
    }
  }

  Future<void> _saveHospitalBag() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final jsonStr = jsonEncode(_hospitalBagItems);
      await PregnancySettings.saveSetting(
        PregnancySettings.keyHospitalBag,
        jsonStr,
        db,
      );
    } catch (e, st) {
      RitmoLog.error(
        'CyclePregnancyMode',
        'Error saving hospital bag: $e',
        e,
        st,
      );
    }
  }

  void _calculateValues() {
    _startDate = DateTime.tryParse(widget.pregnancyStartDate) ?? CycleClock.now;
    _dueDate =
        DateTime.tryParse(widget.pregnancyDueDate) ??
        _startDate.add(const Duration(days: 280));
    final today = CycleClock.now;
    final todayTruncated = DateTime(today.year, today.month, today.day);
    final startTruncated = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
    );

    _diffDays = todayTruncated.difference(startTruncated).inDays;
    if (_diffDays < 0) _diffDays = 0;

    final ga = GestationalAge.fromDays(_diffDays);
    _currentWeek = ga.weeks;
    _currentDayInWeek = ga.days;

    _remainingDays = _dueDate.difference(todayTruncated).inDays;
    if (_remainingDays < 0) _remainingDays = 0;

    _progressPercent = (_diffDays / 280.0).clamp(0.0, 1.0);
  }

  Future<void> _showPregnancyAssistant(BuildContext context) async {
    final persona =
        PersonaRegistry.instance.getPersona('cycle') ??
        PersonaRegistry.instance.getPersona('global');
    if (persona == null || !context.mounted) return;

    unawaited(
      AssistantSheet.show(
        context,
        persona: persona,
        initialQuery:
            'سلام! من در هفته ${PersianDigits.toFa(_currentWeek.toString())} بارداری هستم. چه نکات تغذیه‌ای و خودمراقبتی مهمی را باید برای امروز رعایت کنم؟',
      ),
    );
  }

  Future<void> _registerKickTap() async {
    final now = CycleClock.now;
    final reached10 = _kickTracker.registerTap(now);
    await _kickTracker.saveToSettings();
    unawaited(HapticFeedback.lightImpact());

    if (reached10) {
      final active = await PregnancyRepository.instance.getActiveTracker();
      final trackerId = active?['id'] as String? ?? 'preg_default';
      await _kickTracker.saveRecordToDb(pregnancyId: trackerId);

      final durSecs =
          (now.difference(_kickTracker.start!).inMilliseconds) / 1000.0;
      _baselineFeedback = KickSessionTracker.evaluatePersonalBaseline(
        currentDurationSecs: durSecs,
        baselineSecs: _personalBaselineSecs,
      );

      _kickTracker = KickSessionTracker(
        target: _kickTargetCount,
        limit: Duration(minutes: _kickWindowMinutes),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _baselineFeedback ??
                  '${PersianDigits.toFa(_kickTargetCount.toString())} حرکت کامل شد و جلسه با موفقیت ثبت گردید 🎉',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else if (_kickTracker.isExpired(now)) {
      final active = await PregnancyRepository.instance.getActiveTracker();
      final trackerId = active?['id'] as String? ?? 'preg_default';
      await _kickTracker.saveRecordToDb(pregnancyId: trackerId);
      _kickTracker = KickSessionTracker(
        target: _kickTargetCount,
        limit: Duration(minutes: _kickWindowMinutes),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'اگر پس از ${PersianDigits.toFa((_kickWindowMinutes ~/ 60).toString())} ساعت به ${PersianDigits.toFa(_kickTargetCount.toString())} حرکت نرسیدید، امروز با پزشک خود تماس بگیرید.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    if (mounted) setState(() {});
  }

  // UX-11 Respectful 3-Path End of Pregnancy
  void _showEndPregnancySheet() {
    final colors = context.colors;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'پایان دوره بارداری',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(14),
                ),
                icon: const Icon(CupertinoIcons.heart_fill),
                label: const Text(
                  'تولد نوزاد 🎉',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  Navigator.of(sheetCtx).pop();
                  _handleBirthPath();
                },
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.surface,
                  foregroundColor: colors.textPrimary,
                  padding: const EdgeInsets.all(14),
                ),
                icon: const Icon(CupertinoIcons.heart),
                label: const Text('پایان بارداری', style: TextStyle()),
                onPressed: () {
                  Navigator.of(sheetCtx).pop();
                  _handleLossPath();
                },
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(sheetCtx).pop();
                  _handleMistakePath();
                },
                child: Text(
                  'اشتباه ثبت شده بود',
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleBirthPath() async {
    final active = await PregnancyRepository.instance.getActiveTracker();
    final trackerId = active?['id'] as String? ?? '';
    if (trackerId.isNotEmpty) {
      await PregnancyRepository.instance.deactivateTracker(trackerId);
    }

    if (mounted) {
      unawaited(
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('تبریک! این سفر به زیباترین مقصد رسید. 🌸'),
            content: const Text('می‌خواهید ردیابی چرخه دوباره فعال شود؟'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  widget.onDeactivated();
                },
                child: const Text('بلافاصله'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  final db = await DatabaseHelper.instance.database;
                  final remindMs = CycleClock.now
                      .add(const Duration(days: 40))
                      .millisecondsSinceEpoch;
                  await PregnancySettings.saveSetting(
                    PregnancySettings.keyCycleResumeReminder,
                    remindMs.toString(),
                    db,
                  );
                  widget.onDeactivated();
                },
                child: const Text('بعداً یادآوری کن (۴۰ روز بعد)'),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _handleLossPath() async {
    final colors = context.colors;
    unawaited(
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('متأسفیم که این سفر به این شکل به پایان رسید.'),
          content: const Text(
            'هر وقت آماده بودید، این بخش دوباره در کنار شماست.',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                final db = await DatabaseHelper.instance.database;
                await PregnancySettings.saveSetting(
                  PregnancySettings.keySectionHidden,
                  'true',
                  db,
                );
                widget.onDeactivated();
              },
              child: const Text('پنهان کردن کامل این بخش'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: colors.error),
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _purgeAllPregnancyTables();
                widget.onDeactivated();
              },
              child: const Text(
                'حذف کامل داده‌های این دوره',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleMistakePath() async {
    await _purgeAllPregnancyTables();
    widget.onDeactivated();
  }

  Future<void> _purgeAllPregnancyTables() async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('pregnancy_tracker');
      await db.delete('pregnancy_checkups');
      await db.delete('pregnancy_symptoms');
      await db.delete('kick_counts');
      await db.delete('contraction_timer');
      await KickSessionTracker.clearSettings();
    } catch (e, st) {
      RitmoLog.error(
        'CyclePregnancyMode',
        'Error purging pregnancy tables: $e',
        e,
        st,
      );
    }
  }

  // UX-15 Privacy Badge Sheet
  void _showPrivacyBadgeSheet() {
    final colors = context.colors;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surfaceElevated,
      builder: (sheetCtx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.lock_shield_fill,
              size: 36,
              color: colors.success,
            ),
            const SizedBox(height: 12),
            Text(
              'اطلاعات بارداری شما فقط روی همین گوشی ذخیره می‌شود.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: colors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(sheetCtx).pop(),
              child: const Text('متوجه شدم'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      children: [
        // Unified Glass Header Card
        PregnancyHeader(
          currentWeek: _currentWeek,
          currentDayInWeek: _currentDayInWeek,
          remainingDays: _remainingDays,
          pregTone: _pregTone,
          eddSource: _eddSource,
          startDate: _startDate,
          onShowPrivacy: _showPrivacyBadgeSheet,
          showCountdown: _showCountdown,
          onShowSettings: () => PregnancySettingsSheet.show(
            context,
            onDataReloadNeeded: _loadSettingsAndSession,
            onEndPregnancy: _showEndPregnancySheet,
          ),
        ),

        // 5 Main Tabs
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          labelPadding: const EdgeInsets.symmetric(horizontal: 12),
          indicatorColor: colors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: Colors.transparent,
          labelColor: colors.primary,
          unselectedLabelColor: colors.textSecondary,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'امروز و وضعیت'),
            Tab(text: 'مراقبت‌ها'),
            Tab(text: 'لگدشماری'),
            Tab(text: 'انقباض‌سنج'),
            Tab(text: 'علائم و یادداشت'),
          ],
        ),

        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Tab 0: Main Dynamic Rich Dashboard (Today & Progress)
              PregnancyProgressTab(
                diffDays: _diffDays,
                currentWeek: _currentWeek,
                currentDayInWeek: _currentDayInWeek,
                progressPercent: _progressPercent,
                selectedSymptoms: _selectedSymptoms,
                kickCount: _kickTracker.count,
                hospitalBagItems: _hospitalBagItems,
                onNavigateTab: (idx) => _tabController.animateTo(idx),
                onOpenAssistant: () => _showPregnancyAssistant(context),
                onToggleHospitalBagItem: (idx, done) {
                  setState(() {
                    _hospitalBagItems[idx]['done'] = done;
                  });
                  _saveHospitalBag();
                },
              ),

              // Tab 1: Checkups Timeline (UX-06)
              PregnancyCheckupsTab(currentWeek: _currentWeek),

              // Tab 2: Kick Counter (UX-04)
              PregnancyKicksTab(
                kickCount: _kickTracker.count,
                targetCount: _kickTargetCount,
                onKickTap: _registerKickTap,
              ),

              // Tab 3: Contractions & Labor Mode Launcher (UX-05)
              const PregnancyContractionsTab(),

              // Tab 4: Symptoms Log
              PregnancySymptomsTab(noteController: _noteController),
            ],
          ),
        ),
      ],
    );
  }
}
