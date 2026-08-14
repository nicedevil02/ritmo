import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/cycle_engine.dart';
import 'package:ritmo/core/domain/personas/persona_registry.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/assistant/presentation/widgets/unified_assistant_sheet.dart';
import 'package:ritmo/features/cycle/presentation/widgets/kick_session_tracker.dart';
import 'package:ritmo/features/cycle/presentation/widgets/labor_mode_screen.dart';
import 'package:ritmo/features/cycle/presentation/widgets/pregnancy_today_card.dart';
import 'package:ritmo/features/cycle/presentation/widgets/weekly_share_card.dart';
import 'package:ritmo/features/health/data/pregnancy_helpers.dart';
import 'package:ritmo/features/health/data/pregnancy_repository.dart';
import 'package:ritmo/features/health/data/pregnancy_week_data.dart';
import 'package:ritmo/features/health/presentation/widgets/pregnancy_report.dart';

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

class _CyclePregnancyModeViewState extends State<CyclePregnancyModeView> with TickerProviderStateMixin, WidgetsBindingObserver {
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

  // UX-04 KickSessionTracker
  KickSessionTracker _kickTracker = KickSessionTracker();
  double? _personalBaselineSecs;
  String? _baselineFeedback;

  // UX-10 Hospital Bag items
  List<Map<String, dynamic>> _hospitalBagItems = [];

  // Logs state
  List<String> _selectedSymptoms = [];
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

      // Restore active kick session
      final restored = await KickSessionTracker.restoreFromSettings(DateTime.now());
      if (restored != null) {
        _kickTracker = restored;
      }

      // Load kick baseline
      final active = await PregnancyRepository.instance.getActiveTracker();
      final trackerId = active?['id'] as String? ?? 'preg_default';
      _personalBaselineSecs = await KickSessionTracker.getPersonalBaselineDurationSecs(pregnancyId: trackerId);

      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _loadHospitalBag() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('app_settings', where: 'key = ?', whereArgs: ['preg_hospital_bag'], limit: 1);
      if (rows.isNotEmpty) {
        final jsonStr = rows.first['value'] as String?;
        if (jsonStr != null && jsonStr.isNotEmpty) {
          final decoded = jsonDecode(jsonStr) as List;
          _hospitalBagItems = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
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
    } catch (_) {}
  }

  Future<void> _saveHospitalBag() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final jsonStr = jsonEncode(_hospitalBagItems);
      await db.insert('app_settings', {'key': 'preg_hospital_bag', 'value': jsonStr},
          conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {}
  }

  void _calculateValues() {
    _startDate = DateTime.tryParse(widget.pregnancyStartDate) ?? DateTime.now();
    _dueDate = DateTime.tryParse(widget.pregnancyDueDate) ?? _startDate.add(const Duration(days: 280));
    final today = DateTime.now();
    final todayTruncated = DateTime(today.year, today.month, today.day);
    final startTruncated = DateTime(_startDate.year, _startDate.month, _startDate.day);

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
    final persona = PersonaRegistry.instance.getPersona('cycle') ?? PersonaRegistry.instance.getPersona('global');
    if (persona == null || !context.mounted) return;

    unawaited(AssistantSheet.show(
      context,
      persona: persona,
      initialQuery: 'سلام! من در هفته ${toPersianDigits(_currentWeek)} بارداری هستم. چه نکات تغذیه‌ای و خودمراقبتی مهمی را باید برای امروز رعایت کنم؟',
    ));
  }

  Future<void> _registerKickTap() async {
    final now = DateTime.now();
    final reached10 = _kickTracker.registerTap(now);
    await _kickTracker.saveToSettings();
    unawaited(HapticFeedback.lightImpact());

    if (reached10) {
      final active = await PregnancyRepository.instance.getActiveTracker();
      final trackerId = active?['id'] as String? ?? 'preg_default';
      await _kickTracker.saveRecordToDb(pregnancyId: trackerId);

      final durSecs = (now.difference(_kickTracker.start!).inMilliseconds) / 1000.0;
      _baselineFeedback = KickSessionTracker.evaluatePersonalBaseline(
        currentDurationSecs: durSecs,
        baselineSecs: _personalBaselineSecs,
      );

      _kickTracker = KickSessionTracker();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _baselineFeedback ?? '۱۰ حرکت کامل شد و جلسه با موفقیت ثبت گردید 🎉',
              style: const TextStyle(),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else if (_kickTracker.isExpired(now)) {
      final active = await PregnancyRepository.instance.getActiveTracker();
      final trackerId = active?['id'] as String? ?? 'preg_default';
      await _kickTracker.saveRecordToDb(pregnancyId: trackerId);
      _kickTracker = KickSessionTracker();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'اگر پس از ۲ ساعت به ۱۰ حرکت نرسیدید، امروز با پزشک خود تماس بگیرید.',
              style: TextStyle(),
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
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E2C),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'پایان دوره بارداری',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.all(14)),
                icon: const Icon(CupertinoIcons.heart_fill),
                label: const Text('تولد نوزاد 🎉', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.of(sheetCtx).pop();
                  _handleBirthPath();
                },
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade800, foregroundColor: Colors.white, padding: const EdgeInsets.all(14)),
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
                child: const Text('اشتباه ثبت شده بود', style: TextStyle(color: Colors.white70)),
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
      unawaited(showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('تبریک! این سفر به زیباترین مقصد رسید. 🌸', style: TextStyle()),
          content: const Text('می‌خواهید ردیابی چرخه دوباره فعال شود؟', style: TextStyle()),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                widget.onDeactivated();
              },
              child: const Text('بلافاصله', style: TextStyle()),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                final db = await DatabaseHelper.instance.database;
                final remindMs = DateTime.now().add(const Duration(days: 40)).millisecondsSinceEpoch;
                await db.insert('app_settings', {'key': 'preg_cycle_resume_reminder', 'value': remindMs.toString()},
                    conflictAlgorithm: ConflictAlgorithm.replace);
                widget.onDeactivated();
              },
              child: const Text('بعداً یادآوری کن (۴۰ روز بعد)', style: TextStyle()),
            ),
          ],
        ),
      ));
    }
  }

  Future<void> _handleLossPath() async {
    unawaited(showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('متأسفیم که این سفر به این شکل به پایان رسید.', style: TextStyle()),
        content: const Text('هر وقت آماده بودید، این بخش دوباره در کنار شماست.', style: TextStyle()),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final db = await DatabaseHelper.instance.database;
              await db.insert('app_settings', {'key': 'preg_section_hidden', 'value': 'true'},
                  conflictAlgorithm: ConflictAlgorithm.replace);
              widget.onDeactivated();
            },
            child: const Text('پنهان کردن کامل این بخش', style: TextStyle()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _purgeAllPregnancyTables();
              widget.onDeactivated();
            },
            child: const Text('حذف کامل داده‌های این دوره', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ));
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
    } catch (_) {}
  }

  // UX-15 Privacy Badge Sheet
  void _showPrivacyBadgeSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.lock_shield_fill, size: 36, color: Colors.green),
            const SizedBox(height: 12),
            const Text(
              'اطلاعات بارداری شما فقط روی همین گوشی ذخیره می‌شود.',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(sheetCtx).pop(),
              child: const Text('متوجه شدم', style: TextStyle()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.22 : 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: isDark ? 0.35 : 0.2),
              width: 1,
            ),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }

  Widget _buildUnifiedHeader(BuildContext context, RitmoColors colors, bool isDark, GestationalAge ga) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFF2A1B35).withValues(alpha: 0.85),
                  const Color(0xFF1E1B2E).withValues(alpha: 0.95),
                ]
              : [
                  Colors.white.withValues(alpha: 0.95),
                  const Color(0xFFFFF0F5).withValues(alpha: 0.85),
                ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.purple.withValues(alpha: 0.25) : Colors.pink.withValues(alpha: 0.18),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withValues(alpha: isDark ? 0.12 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Row: Title + Action Cluster
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Title & Tone
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.pink.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Text('👶', style: TextStyle(fontSize: 15)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _pregTone == 'neutral' ? 'بارداری شما' : 'دوران شیرین بارداری 🎀',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),

              // Glass Action Cluster
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: 'گزارش ویژه پزشک زنان',
                    child: _buildHeaderActionButton(
                      icon: CupertinoIcons.doc_text_fill,
                      color: const Color(0xFF6366F1),
                      tooltip: 'گزارش پزشک',
                      onTap: () async {
                        await PregnancyReportScreen.show(
                          context,
                          pregnancyId: 'preg_default',
                          lmpDate: _startDate,
                        );
                      },
                      isDark: isDark,
                    ),
                  ),
                  Tooltip(
                    message: 'اشتراک‌گذاری کارت رشد',
                    child: _buildHeaderActionButton(
                      icon: CupertinoIcons.share,
                      color: const Color(0xFFEC4899),
                      tooltip: 'اشتراک‌گذاری',
                      onTap: () async => await WeeklyShareCardScreen.show(context, gestationalAge: ga),
                      isDark: isDark,
                    ),
                  ),
                  Tooltip(
                    message: 'تنظیمات و گزینه‌ها',
                    child: _buildHeaderActionButton(
                      icon: CupertinoIcons.ellipsis_vertical,
                      color: const Color(0xFF8B5CF6),
                      tooltip: 'تنظیمات بارداری',
                      onTap: _showEndPregnancySheet,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Sub Row: Status Badges (Privacy + EDD Source) & Human Countdown Summary
          Row(
            children: [
              // UX-15 Privacy Badge
              InkWell(
                onTap: _showPrivacyBadgeSheet,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3), width: 0.8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.lock_fill, size: 11, color: Colors.green),
                      SizedBox(width: 4),
                      Text(
                        'اطلاعات فقط روی گوشی',
                        style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

              if (_eddSource == 'ultrasound') ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3), width: 0.8),
                  ),
                  child: const Text(
                    'سونوگرافی 🩺',
                    style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold),
                  ),
                ),
              ],

              const Spacer(),

              // Human Countdown Summary Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.pink.withValues(alpha: isDark ? 0.2 : 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'هفته ${toPersianDigits(_currentWeek)} + ${toPersianDigits(_currentDayInWeek)} روز',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.pink.shade200 : Colors.pink.shade700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '• ${PregnancyHelpers.formatHumanCountdown(_remainingDays)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.purple.shade200 : Colors.purple.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ga = GestationalAge.fromDays(_diffDays);

    return Column(
      children: [
        // Unified Glass Header Card
        _buildUnifiedHeader(context, colors, isDark, ga),

        // 5 Main Tabs
            TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: colors.primary,
              unselectedLabelColor: colors.textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                  _buildTabProgress(context),

                  // Tab 1: Checkups Timeline (UX-06)
                  _buildTabCheckups(),

                  // Tab 2: Kick Counter (UX-04)
                  _buildTabKicks(),

                  // Tab 3: Contractions & Labor Mode Launcher (UX-05)
                  _buildTabContractions(),

                  // Tab 4: Symptoms Log
                  _buildTabSymptoms(),
                ],
              ),
            ),
          ],
        );
  }

  /// Tab 0: Rich Dynamic Dashboard with Hero Ring, Fetus Growth, AI Assistant & Quick Actions
  Widget _buildTabProgress(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ga = GestationalAge.fromDays(_diffDays);
    final weekInfo = pregnancyWeekData[_currentWeek.clamp(1, 40)];

    final babySize = weekInfo?.babySizeFa ?? weekInfo?.size ?? 'میوه کوچک';
    final babyWeight = weekInfo?.babyWeightFa ?? '';
    final developmentText = weekInfo?.development ?? 'اندام‌های جنین در حال تکمیل و رشد هستند.';
    final tipText = weekInfo?.tip ?? 'تغذیه سالم، نوشیدن آب کافی و استراحت روزانه را در اولویت قرار دهید.';

    final trimesterNum = ga.trimester;
    final trimesterTitle = 'راهنمای سه ماهه ${trimesterNum == 1 ? "اول" : (trimesterNum == 2 ? "دوم" : "سوم")}';
    final trimesterTips = trimesterNum == 1
        ? 'مصرف منظم فولیک اسید، استراحت در صورت خستگی و مدیریت تهوع صبحگاهی با وعده‌های کوچک.'
        : (trimesterNum == 2
            ? 'بهترین زمان برای انجام سونوگرافی آنومالی، خوابیدن به پهلوی چپ و ثبت اولین لگدها.'
            : 'شروع شمارش منظم لگد جنین، آماده‌سازی ساک بیمارستان و آشنایی با نشانه‌های زایمان.');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // UX-01 Pregnancy Today Card Banner
          PregnancyTodayCard(
            gestationalAge: ga,
            hasSupplementToday: _selectedSymptoms.any((s) => s.startsWith('SUPP_')),
            hasKicksLogged: _kickTracker.count > 0,
            onNavigateTab: (idx) => _tabController.animateTo(idx),
            onOpenWeightLog: () {},
            onOpenLaborMode: () => LaborModeScreen.show(context, pregnancyId: 'preg_default'),
            onOpenHospitalBag: () => _tabController.animateTo(0),
          ),

          const SizedBox(height: 16),

          // UX-02 Hero Progress Ring & Journey Map (Large 200px)
          Center(
            child: SizedBox(
              width: 210,
              height: 210,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: _PregnancyRingPainter(
                      percentage: _progressPercent,
                      colors: const [Color(0xffEC4899), Color(0xff8B5CF6)],
                    ),
                  ),

                  // UX-02 Milestones interactive tap targets (12, 20, 24, 28, 36)
                  ...[12, 20, 24, 28, 36].map((week) {
                    final angleDeg = PregnancyHelpers.milestoneAngle(week);
                    final rad = (angleDeg - 90) * math.pi / 180;
                    const r = 86.0;
                    final x = 105.0 + r * math.cos(rad) - 24.0;
                    final y = 105.0 + r * math.sin(rad) - 24.0;

                    return Positioned(
                      left: x,
                      top: y,
                      child: Semantics(
                        button: true,
                        label: 'مراقبت هفته $week',
                        child: InkWell(
                          onTap: () => _tabController.animateTo(1),
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                            child: CircleAvatar(
                              radius: _currentWeek >= week ? 9 : 6,
                              backgroundColor: _currentWeek >= week ? const Color(0xffEC4899) : Colors.grey.shade400,
                              child: _currentWeek >= week
                                  ? const Icon(CupertinoIcons.checkmark, size: 10, color: Colors.white)
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),

                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'هفته ${toPersianDigits(_currentWeek)}',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '+ ${toPersianDigits(_currentDayInWeek)} روز',
                          style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black54),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xffEC4899).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${toPersianDigits((_progressPercent * 100).toInt())}% کل مسیر',
                            style: const TextStyle(fontSize: 11, color: Color(0xffEC4899), fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Weekly Fetus Growth & Fruit Size Card
          RitmoTheme.glassCard(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xff8B5CF6).withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xffEC4899).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(CupertinoIcons.heart_circle_fill, color: Color(0xffEC4899), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'جنین هفته ${toPersianDigits(_currentWeek)}: $babySize',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                            if (babyWeight.isNotEmpty)
                              Text(
                                'وزن تقریبی: $babyWeight',
                                style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : colors.textSecondary),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    developmentText,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white.withValues(alpha: 0.87) : colors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                  const Divider(height: 20),
                  Row(
                    children: [
                      const Icon(CupertinoIcons.lightbulb_fill, size: 16, color: Colors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'نکته هفته: $tipText',
                          style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white70 : colors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Smart AI Pregnancy Assistant Card
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                colors: [Color(0xffEC4899), Color(0xff8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xffEC4899).withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => _showPregnancyAssistant(context),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(CupertinoIcons.sparkles, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'دستیار هوشمند بارداری ریتمو 🤖',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'مشاوره تغذیه، علائم و خودمراقبتی هفته ${toPersianDigits(_currentWeek)} بارداری',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(CupertinoIcons.chevron_left, color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Trimester Care Advice Card
          RitmoTheme.glassCard(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xff8B5CF6).withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trimesterTitle,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    trimesterTips,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : colors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Quick Actions Grid Hub
          Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  icon: CupertinoIcons.sparkles,
                  color: Colors.pinkAccent,
                  label: 'شروع لگدشماری',
                  onTap: () => _tabController.animateTo(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildQuickActionButton(
                  icon: CupertinoIcons.timer,
                  color: Colors.indigoAccent,
                  label: 'حالت زایمان',
                  onTap: () => LaborModeScreen.show(context, pregnancyId: 'preg_default'),
                ),
              ),
            ],
          ),

          // UX-10 Hospital Bag checklist if week >= 32
          if (_currentWeek >= 32) ...[
            const SizedBox(height: 20),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: colors.primary.withValues(alpha: 0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🎒 چک‌لیست ساک بیمارستان (هفته ۳۲ به بعد)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    ..._hospitalBagItems.map((item) {
                      return CheckboxListTile(
                        dense: true,
                        title: Text(item['title'] as String, style: const TextStyle(fontSize: 12)),
                        value: item['done'] as bool,
                        onChanged: (val) {
                          setState(() {
                            item['done'] = val ?? false;
                          });
                          _saveHospitalBag();
                        },
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabCheckups() {
    final checkupWindows = [
      {'id': 'chk_1', 'title': 'مراقبت اول (هفته ۶ تا ۱۰)', 'start': 6, 'end': 10},
      {'id': 'chk_2', 'title': 'مراقبت دوم (غربالگری اول)', 'start': 11, 'end': 13},
      {'id': 'chk_3', 'title': 'مراقبت سوم (آنومالی هفته ۱۸ تا ۲۰)', 'start': 18, 'end': 20},
      {'id': 'chk_4', 'title': 'مراقبت چهارم (تست قند هفته ۲۴ تا ۲۸)', 'start': 24, 'end': 28},
      {'id': 'chk_5', 'title': 'مراقبت پنجم (هفته ۳۰ تا ۳۴)', 'start': 30, 'end': 34},
      {'id': 'chk_6', 'title': 'مراقبت ششم (هفته ۳۵ تا ۳۷)', 'start': 35, 'end': 37},
      {'id': 'chk_7', 'title': 'مراقبت هفتم (هفته ۳۸ تا ۴۰)', 'start': 38, 'end': 40},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: checkupWindows.length,
      itemBuilder: (ctx, idx) {
        final item = checkupWindows[idx];
        final start = item['start'] as int;
        final end = item['end'] as int;
        final statusText = PregnancyHelpers.checkupWindowStatus(
          currentWeek: _currentWeek,
          windowStartWeek: start,
          windowEndWeek: end,
          isCompleted: false,
        );

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            title: Text(item['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text(statusText, style: const TextStyle(fontSize: 12, color: Colors.purple)),
            trailing: _currentWeek >= start && _currentWeek <= end
                ? TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('یادآوری مراقبت ثبت شد ⏰', style: TextStyle())),
                      );
                    },
                    child: const Text('یادآوری', style: TextStyle(fontSize: 12)),
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildTabKicks() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('جلسه واقعی «شمارش تا ۱۰» حرکات جنین', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(
            'تعداد حرکات ثبت شده: ${toPersianDigits(_kickTracker.count)} / ۱۰',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.pinkAccent),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _registerKickTap,
            child: Container(
              width: 140,
              height: 140,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.pinkAccent),
              child: const Center(
                child: Text('ثبت حرکت 🦶', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContractions() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('انقباض‌سنج و حالت زایمان', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16), backgroundColor: Colors.indigoAccent),
            icon: const Icon(CupertinoIcons.fullscreen, color: Colors.white),
            label: const Text('ورود به حالت زایمان (تمام‌صفحه)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            onPressed: () => LaborModeScreen.show(context, pregnancyId: 'preg_default'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSymptoms() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text('ثبت علائم و حالت امروز', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'یادداشت یا توضیحات امروز...',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PregnancyRingPainter extends CustomPainter {
  _PregnancyRingPainter({required this.percentage, required this.colors});

  final double percentage;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 10.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final paintBg = Paint()
      ..color = colors.first.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, paintBg);

    final gradient = SweepGradient(
      colors: colors,
      startAngle: -math.pi / 2,
      endAngle: 3 * math.pi / 2,
    );

    final paintFg = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * percentage;
    canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, paintFg);
  }

  @override
  bool shouldRepaint(covariant _PregnancyRingPainter oldDelegate) {
    return oldDelegate.percentage != percentage || oldDelegate.colors != colors;
  }
}
