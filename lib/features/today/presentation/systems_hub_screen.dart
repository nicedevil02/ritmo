import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/systems_hub_logic.dart';
import 'package:ritmo/core/localization/locale_repository.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/theme/theme_repository.dart';
import 'package:ritmo/core/utils/cycle_privacy_guard.dart';
import 'package:ritmo/core/widgets/ritmo_adaptive_grid.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/services/feature_limits.dart';
import 'package:ritmo/core/services/module_management_service.dart';
import 'package:ritmo/features/premium/presentation/premium_upgrade_sheet.dart';
import 'package:ritmo/features/assistant/presentation/assistant_screen.dart';
import 'package:ritmo/features/courses/presentation/courses_screen.dart';
import 'package:ritmo/features/cycle/presentation/cycle_screen.dart';
import 'package:ritmo/features/goals/presentation/goals_screen.dart';
import 'package:ritmo/features/health/presentation/health_screen.dart';
import 'package:ritmo/features/study/study_module_entry.dart';
import 'package:ritmo/features/settings/presentation/groups/modules_group_screen.dart';
import 'package:ritmo/features/settings/presentation/settings_screen.dart';
import 'package:ritmo/features/notes/presentation/screens/notebook_screen.dart';
import 'package:ritmo/features/today/presentation/insights_screen.dart';

import 'package:ritmo/features/supplementary_sports/supplementary_sports.dart';
import 'package:ritmo/features/wellbeing/presentation/wellbeing_screen.dart';
import 'package:ritmo/features/worship/presentation/worship_screen.dart';

class SystemsHubScreen extends StatefulWidget {
  const SystemsHubScreen({
    super.key,
    required this.onLogout,
    required this.themeRepository,
    required this.localeRepository,
  });
  final VoidCallback onLogout;
  final ThemeRepository themeRepository;
  final LocaleRepository localeRepository;

  @override
  State<SystemsHubScreen> createState() => _SystemsHubScreenState();
}

class _SystemsHubScreenState extends State<SystemsHubScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late AnimationController _controller;
  late List<Animation<double>> _fadeAnimations;
  late List<Animation<Offset>> _slideAnimations;

  bool _isLoading = false;
  bool _isFirstLoad = false;
  bool _precacheDone = false;
  bool _avatarFileExists = false;
  Map<String, String> _settingsMap = {};

  bool _isSearching = false;
  String _searchQuery = '';

  @override
  bool get wantKeepAlive => true;

  bool _matchesSearch(String title, String description) {
    if (_searchQuery.isEmpty) return true;
    final query = _searchQuery.toLowerCase();
    if (title == 'حال و تعادل') {
      const combinedTags =
          'انرژی و حالت روحی خواب و بیداری خودارزیابی و بازتاب حال و تعادل';
      return title.toLowerCase().contains(query) ||
          description.toLowerCase().contains(query) ||
          combinedTags.contains(query);
    }
    return title.toLowerCase().contains(query) ||
        description.toLowerCase().contains(query);
  }

  // Enabled flags
  bool _religionEnabled = false;
  bool _medicineEnabled = false;
  bool _cycleEnabled = false;
  bool _coursesEnabled = false;
  bool _konkurEnabled = false;
  bool _goalsEnabled = false;
  bool _assistantEnabled = false;
  bool _sportsEnabled = false;
  bool _supplementarySportsEnabled = false;
  bool _notesEnabled = false;

  // Grouping & custom order state
  bool _groupingEnabled = true;
  bool _showCustomOrderBanner = true;
  List<String> _customModuleOrder = const [
    'goals',
    'notes',
    'courses',
    'konkur',
    'religion',
    'assistant',
    'insights',
    'wellbeing',
    'sports',
    'medicine',
    'cycle',
  ];

  // Status flags resolved from db state
  ModuleStatus _konkurStatus = ModuleStatus.inactive;
  ModuleStatus _goalsStatus = ModuleStatus.inactive;
  ModuleStatus _assistantStatus = ModuleStatus.inactive;
  ModuleStatus _notesStatus = ModuleStatus.inactive;

  @override
  void initState() {
    super.initState();
    _initFromCache();
    RitmoEvents.routineChanges.addListener(_onRoutineChanges);
    _loadAllData(showLoading: false);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    const itemsCount = 12;

    _fadeAnimations = List.generate(itemsCount, (i) {
      final start = i * 0.05;
      final end = (start + 0.45).clamp(0.0, 1.0);

      return CurvedAnimation(
        parent: _controller,
        curve: Interval(start, end, curve: Curves.easeOut),
      );
    });

    _slideAnimations = List.generate(itemsCount, (i) {
      final start = i * 0.05;
      final end = (start + 0.5).clamp(0.0, 1.0);

      return Tween<Offset>(
        begin: const Offset(0, 0.15),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ),
      );
    });

    _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precacheDone) {
      _precacheDone = true;
      const cardAssets = [
        'assets/images/goals_card_top.png',
        'assets/images/konkur_card_top.png',
        'assets/images/medicine_card_top.png',
        'assets/images/courses_card_top.png',
        'assets/images/worship_card_top.png',
        'assets/images/sports_card_top.png',
        'assets/images/assistant_card_top.png',
        'assets/images/energy_card_top.png',
        'assets/images/notes_card_top.png',
        'assets/images/reflection_card_top.png',
        'assets/images/insights_card_top.png',
        'assets/images/cycle_card_top.png',
      ];
      for (final asset in cardAssets) {
        precacheImage(AssetImage(asset), context);
      }
    }
  }

  void _initFromCache() {
    final cached = SettingsService.instance.cachedEntries;
    _settingsMap = <String, String>{
      for (final e in cached.entries) e.key: e.value.toString(),
    };
    _religionEnabled = ModuleGate.instance.isEnabledFrom(
      _settingsMap,
      'module_religion_enabled',
    );
    _medicineEnabled = ModuleGate.instance.isEnabledFrom(
      _settingsMap,
      'module_medicine_enabled',
    );
    _cycleEnabled = ModuleGate.instance.isEnabledFrom(
      _settingsMap,
      'module_cycle_enabled',
    );
    _coursesEnabled = ModuleGate.instance.isEnabledFrom(
      _settingsMap,
      'module_courses_enabled',
    );
    _konkurEnabled = ModuleGate.instance.isEnabledFrom(
      _settingsMap,
      'module_study_enabled',
    );
    _goalsEnabled = ModuleGate.instance.isEnabledFrom(
      _settingsMap,
      'module_goals_enabled',
    );
    _assistantEnabled = ModuleGate.instance.isEnabledFrom(
      _settingsMap,
      'module_assistant_enabled',
    );
    _sportsEnabled = ModuleGate.instance.isEnabledFrom(
      _settingsMap,
      'module_sports_enabled',
    );
    _supplementarySportsEnabled = ModuleGate.instance.isEnabledFrom(
      _settingsMap,
      'module_supplementary_sports_enabled',
    );
    _notesEnabled = ModuleGate.instance.isEnabledFrom(
      _settingsMap,
      'module_notes_enabled',
    );
    _groupingEnabled = _settingsMap['systems_grouping_enabled'] != 'false';

    final customOrderRaw = _settingsMap['systems_custom_order'];
    if (customOrderRaw != null && customOrderRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(customOrderRaw);
        if (decoded is List) {
          final parsed = decoded.map((e) => e.toString()).toList();
          const allStandardKeys = [
            'goals',
            'notes',
            'courses',
            'konkur',
            'religion',
            'assistant',
            'wellbeing',
            'sports',
            'medicine',
            'cycle',
          ];
          for (final k in allStandardKeys) {
            if (!parsed.contains(k)) {
              parsed.add(k);
            }
          }
          _customModuleOrder = parsed;
        }
      } catch (_) {}
    }

    _konkurStatus = SystemsHubLogic.determineGenericStatus(_konkurEnabled);
    _goalsStatus = SystemsHubLogic.determineGenericStatus(_goalsEnabled);
    _assistantStatus = SystemsHubLogic.determineGenericStatus(_assistantEnabled);
    _notesStatus = SystemsHubLogic.determineGenericStatus(_notesEnabled);
  }

  void _onRoutineChanges() {
    if (mounted) {
      _loadAllData();
    }
  }

  @override
  void dispose() {
    RitmoEvents.routineChanges.removeListener(_onRoutineChanges);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadAllData({bool showLoading = false}) async {
    if (!mounted) return;
    if (showLoading || _isFirstLoad) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final db = await DatabaseHelper.instance.database;

      // 1. Load app_settings
      final settings = await db.query('app_settings');
      _settingsMap = <String, String>{
        for (final s in settings) s['key']! as String: s['value']! as String,
      };

      // 2. Map module enable flags
      _religionEnabled = ModuleGate.instance.isEnabledFrom(
        _settingsMap,
        'module_religion_enabled',
      );
      _medicineEnabled = ModuleGate.instance.isEnabledFrom(
        _settingsMap,
        'module_medicine_enabled',
      );
      _cycleEnabled = ModuleGate.instance.isEnabledFrom(
        _settingsMap,
        'module_cycle_enabled',
      );
      _coursesEnabled = ModuleGate.instance.isEnabledFrom(
        _settingsMap,
        'module_courses_enabled',
      );
      _konkurEnabled = ModuleGate.instance.isEnabledFrom(
        _settingsMap,
        'module_study_enabled',
      );
      _goalsEnabled = ModuleGate.instance.isEnabledFrom(
        _settingsMap,
        'module_goals_enabled',
      );
      _assistantEnabled = ModuleGate.instance.isEnabledFrom(
        _settingsMap,
        'module_assistant_enabled',
      );
      _sportsEnabled = ModuleGate.instance.isEnabledFrom(
        _settingsMap,
        'module_sports_enabled',
      );
      _supplementarySportsEnabled = ModuleGate.instance.isEnabledFrom(
        _settingsMap,
        'module_supplementary_sports_enabled',
      );
      _notesEnabled = ModuleGate.instance.isEnabledFrom(
        _settingsMap,
        'module_notes_enabled',
      );

      // 3. Load konkur subjects to determine status (active vs setupRequired)
      final subjects = await db.query(
        'konkur_subjects',
        where: "isArchived = 0 AND (origin = 'KONKUR_PRESET' OR origin = 'KONKUR_CUSTOM' OR origin = 'KONKUR' OR isPreset = 1)",
      );
      final hasSubjects = subjects.isNotEmpty;
      _konkurStatus = SystemsHubLogic.determineKonkurStatus(
        _konkurEnabled,
        hasSubjects,
      );

      // 3b. Load goals to determine status
      final goals = await db.query('goals');
      final hasGoals = goals.isNotEmpty;
      _goalsStatus = SystemsHubLogic.determineKonkurStatus(
        _goalsEnabled,
        hasGoals,
      );

      // 4. Load assistant and notes status
      _assistantStatus = SystemsHubLogic.determineGenericStatus(
        _assistantEnabled,
      );
      _notesStatus = SystemsHubLogic.determineGenericStatus(_notesEnabled);

      // 4.5. Grouping & Custom Order Settings
      _groupingEnabled = _settingsMap['systems_grouping_enabled'] != 'false';
      final customOrderRaw = _settingsMap['systems_custom_order'];
      if (customOrderRaw != null && customOrderRaw.isNotEmpty) {
        try {
          final decoded = jsonDecode(customOrderRaw);
          if (decoded is List) {
            final parsed = decoded.map((e) => e.toString()).toList();
            const allStandardKeys = [
              'goals',
              'notes',
              'courses',
              'konkur',
              'religion',
              'assistant',
              'wellbeing',
              'sports',
              'medicine',
              'cycle',
            ];
            for (final k in allStandardKeys) {
              if (!parsed.contains(k)) {
                parsed.add(k);
              }
            }
            _customModuleOrder = parsed;
          }
        } catch (_) {}
      }
      final prefs = await SharedPreferences.getInstance();
      final isDismissedInPrefs = prefs.getBool('systems_custom_order_banner_dismissed') ?? false;
      final isDismissedInDb = _settingsMap['systems_custom_order_banner_dismissed'] == 'true';
      _showCustomOrderBanner = !isDismissedInPrefs && !isDismissedInDb;

      // 5. Check user avatar existence asynchronously
      final avatarPath = _settingsMap['user_avatar_path'];
      if (avatarPath != null && avatarPath.isNotEmpty) {
        if (avatarPath.startsWith('http://') ||
            avatarPath.startsWith('https://') ||
            avatarPath.startsWith('blob:') ||
            avatarPath.startsWith('data:')) {
          _avatarFileExists = true;
        } else {
          try {
            _avatarFileExists = await File(avatarPath).exists();
          } catch (_) {
            _avatarFileExists = false;
          }
        }
      } else {
        _avatarFileExists = false;
      }
    } catch (e) {
      debugPrint('Error loading Systems Hub data: $e');
    }

    if (mounted) {
      setState(() {
        _isFirstLoad = false;
        _isLoading = false;
      });
    }
  }

  bool get _isFemale => CyclePrivacyGuard.isVisible(_settingsMap);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = context.colors;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final avatarPath = _settingsMap['user_avatar_path'];
    final userName = _settingsMap['user_name'] ?? '';
    final hasAvatarFile =
        _avatarFileExists && avatarPath != null && avatarPath.isNotEmpty;

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RitmoSingleMorphingScaffold(
        title: 'سیستم‌ها',
        subtitle: 'تمام سیستم‌های فعال و قابل مدیریت زندگی شما',
        leading: _buildAvatarLeading(
          colors,
          hasAvatarFile,
          avatarPath,
          userName,
        ),
        actions: [
          RitmoVibrancyActionButton(
            icon: _isSearching ? CupertinoIcons.xmark : CupertinoIcons.search,
            tooltip: _isSearching ? 'بستن جستجو' : 'جستجو در سیستم‌ها',
            onTap: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) _searchQuery = '';
              });
            },
          ),
          const SizedBox(width: 6),
          RitmoVibrancyActionButton(
            icon: CupertinoIcons.square_grid_2x2,
            tooltip: 'مدیریت ماژول‌ها و بخش‌ها',
            isAiButton: true,
            accentColor: colors.primary,
            onTap: _showModulesManagementSheet,
          ),
        ],
        bodyBuilder: (context, scrollController, topPadding) {
          return SingleChildScrollView(
            controller: scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(14, topPadding, 14, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isSearching) ...[
                  _buildSearchBar(colors),
                  const SizedBox(height: 14),
                ],
                _buildModulesGrid(colors, isDarkMode),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvatarLeading(
    RitmoColors colors,
    bool hasAvatarFile,
    String? avatarPath,
    String userName,
  ) {
    return Semantics(
      button: true,
      label: 'پروفایل و تنظیمات',
      child: GestureDetector(
        onTap: () {
          RitmoHapticsPolicy.tap();
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (_) => SettingsScreen(
                onFactoryReset: widget.onLogout,
                themeRepository: widget.themeRepository,
                localeRepository: widget.localeRepository,
              ),
            ),
          ).then((_) {
            if (mounted) _loadAllData();
          });
        },
        child: Container(
          height: 38,
          width: 38,
          padding: const EdgeInsets.all(1.8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: colors.energyGradient),
            boxShadow: [
              BoxShadow(
                color: colors.energyGradient.first.withValues(
                  alpha: 0.28,
                ),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.bg,
              image: hasAvatarFile && avatarPath != null
                  ? DecorationImage(
                      image: ResizeImage(
                        FileImage(File(avatarPath)),
                        width: 120,
                        height: 120,
                      ),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: hasAvatarFile
                ? null
                : Center(
                    child: Text(
                      userName.isNotEmpty ? userName[0] : '؟',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: colors.primary,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(RitmoColors colors) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: colors.card.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(CupertinoIcons.search, color: colors.textSecondary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              autofocus: true,
              style: TextStyle(color: colors.textPrimary, fontSize: 13.5),
              decoration: const InputDecoration(
                hintText: 'جستجو در سیستم‌ها...',
                hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                border: InputBorder.none,
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                });
              },
            ),
          ),
          IconButton(
            icon: Icon(
              CupertinoIcons.xmark,
              color: colors.textSecondary,
              size: 18,
            ),
            onPressed: () {
              setState(() {
                _isSearching = false;
                _searchQuery = '';
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(
    String title,
    Color accentColor,
    RitmoColors colors,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 3.5,
          height: 14,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.4),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySection({
    required String title,
    required Color accentColor,
    required List<Widget> cards,
    required RitmoColors colors,
  }) {
    if (cards.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCategoryHeader(title, accentColor, colors),
        const SizedBox(height: 8),
        RitmoAdaptiveGrid(
          minTileWidth: 140,
          spacing: 10,
          maxColumns: 2,
          children: cards
              .map((card) => AspectRatio(aspectRatio: 1.05, child: card))
              .toList(),
        ),
      ],
    );
  }

  Future<void> _handleCardLongPressInGroupedMode() async {
    await HapticFeedback.mediumImpact();
    final confirmed = await _showDisableGroupingConfirmationDialog();
    if (confirmed == true && mounted) {
      await _setGroupingEnabled(false);
    }
  }

  Future<bool> _showDisableGroupingConfirmationDialog() async {
    final colors = context.ritmoColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xff1E1E2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xff3B82F6).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(CupertinoIcons.square_grid_2x2, color: Color(0xff3B82F6), size: 22),
            ),
            const SizedBox(width: 10),
            const Text(
              'تغییر چیدمان کارت‌ها',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'با جابجایی دستی کارت‌ها، گروه‌بندی خودکار سیستم‌ها (رشد، سلامت، معنویت) غیرفعال می‌شود و کارت‌ها بر اساس ترتیب دلخواه شما قرار می‌گیرند.\n\nآیا مایل به ادامه هستید؟',
          style: TextStyle(
            fontSize: 13.5,
            height: 1.6,
            color: colors.textSecondary,
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('انصراف', style: TextStyle(color: colors.textTertiary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff3B82F6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تایید و جابجایی', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _setGroupingEnabled(bool enabled) async {
    await HapticFeedback.mediumImpact();
    setState(() {
      _groupingEnabled = enabled;
    });

    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('app_settings', {
        'key': 'systems_grouping_enabled',
        'value': enabled ? 'true' : 'false',
        'updatedAt': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await SettingsService.instance.set('systems_grouping_enabled', enabled);
    } catch (_) {}

    if (mounted) {
      RitmoToast.show(
        context,
        enabled
            ? 'گروه‌بندی خودکار فعال شد.'
            : 'حالت چیدمان آزاد فعال شد.',
        icon: Icons.check_circle_outline,
      );
    }
  }

  Future<void> _saveCustomOrder(List<String> order) async {
    final jsonStr = jsonEncode(order);
    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('app_settings', {
        'key': 'systems_custom_order',
        'value': jsonStr,
        'updatedAt': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await SettingsService.instance.set('systems_custom_order', jsonStr);
    } catch (_) {}
  }

  void _onReorderModules(String fromKey, String toKey) {
    if (fromKey == toKey) return;
    unawaited(HapticFeedback.lightImpact());

    final newOrder = List<String>.from(_customModuleOrder);
    final fromIndex = newOrder.indexOf(fromKey);
    final toIndex = newOrder.indexOf(toKey);

    if (fromIndex != -1 && toIndex != -1) {
      newOrder.removeAt(fromIndex);
      newOrder.insert(toIndex, fromKey);
      setState(() {
        _customModuleOrder = newOrder;
      });
      unawaited(_saveCustomOrder(newOrder));
    }
  }

  Widget _buildModuleItemWidget(
    int index,
    _SystemModuleItem item,
    RitmoColors colors,
    bool isDarkMode,
  ) {
    return _buildAnimatedModuleCard(
      index: index,
      child: PressableGlassCard(
        onTap: item.onTap,
        onLongPress: () => _handleCardLongPressInGroupedMode(),
        child: _buildModuleCard(
          icon: item.icon,
          iconColor: item.iconColor,
          title: item.title,
          description: item.description,
          status: item.status,
          onTap: item.onTap,
          colors: colors,
          isDarkMode: isDarkMode,
          illustrationAsset: item.illustrationAsset,
          overlayText: item.overlayText,
        ),
      ),
    );
  }

  Widget _buildReorderableCustomGrid({
    required List<_SystemModuleItem> items,
    required RitmoColors colors,
    required bool isDarkMode,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Custom order notification banner
        if (_showCustomOrderBanner) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(CupertinoIcons.hand_draw, color: colors.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'کارت‌ها در حالت چیدمان آزاد هستند. برای جابجایی، انگشت خود را روی کارت نگه دارید و بکشید.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: colors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    backgroundColor: colors.primary.withValues(alpha: 0.12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _setGroupingEnabled(true),
                  child: Text(
                    'گروه‌بندی خودکار',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: colors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      setState(() {
                        _showCustomOrderBanner = false;
                      });
                      try {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('systems_custom_order_banner_dismissed', true);
                        final db = await DatabaseHelper.instance.database;
                        final now = DateTime.now().millisecondsSinceEpoch;
                        await db.insert('app_settings', {
                          'key': 'systems_custom_order_banner_dismissed',
                          'value': 'true',
                          'updatedAt': now,
                        }, conflictAlgorithm: ConflictAlgorithm.replace);
                      } catch (_) {}
                    },
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      CupertinoIcons.xmark,
                      size: 16,
                      color: colors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // 2-Column Reorderable Grid
        RitmoAdaptiveGrid(
          minTileWidth: 140,
          spacing: 10,
          maxColumns: 2,
          children: items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;

            return AspectRatio(
              aspectRatio: 1.05,
              child: DragTarget<String>(
                onWillAcceptWithDetails: (details) => details.data != item.key,
                onAcceptWithDetails: (details) => _onReorderModules(details.data, item.key),
                builder: (context, candidateData, rejectedData) {
                  final isHovered = candidateData.isNotEmpty;

                  return LongPressDraggable<String>(
                    data: item.key,
                    feedback: Material(
                      color: Colors.transparent,
                      child: Transform.scale(
                        scale: 1.06,
                        child: SizedBox(
                          width: 170,
                          height: 160,
                          child: _buildModuleCard(
                            icon: item.icon,
                            iconColor: item.iconColor,
                            title: item.title,
                            description: item.description,
                            status: item.status,
                            onTap: () {},
                            colors: colors,
                            isDarkMode: isDarkMode,
                            illustrationAsset: item.illustrationAsset,
                            overlayText: item.overlayText,
                          ),
                        ),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.3,
                      child: _buildModuleCard(
                        icon: item.icon,
                        iconColor: item.iconColor,
                        title: item.title,
                        description: item.description,
                        status: item.status,
                        onTap: () {},
                        colors: colors,
                        isDarkMode: isDarkMode,
                        illustrationAsset: item.illustrationAsset,
                        overlayText: item.overlayText,
                      ),
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        border: isHovered
                            ? Border.all(color: colors.primary, width: 2.2)
                            : null,
                      ),
                      child: _buildAnimatedModuleCard(
                        index: index,
                        child: PressableGlassCard(
                          onTap: item.onTap,
                          child: _buildModuleCard(
                            icon: item.icon,
                            iconColor: item.iconColor,
                            title: item.title,
                            description: item.description,
                            status: item.status,
                            onTap: item.onTap,
                            colors: colors,
                            isDarkMode: isDarkMode,
                            illustrationAsset: item.illustrationAsset,
                            overlayText: item.overlayText,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildModulesGrid(RitmoColors colors, bool isDarkMode) {
    final allItemsMap = <String, _SystemModuleItem>{};

    // 1. Cycle Module (Female Only)
    if (_isFemale && _matchesSearch('چرخه بدن', 'سلامت بانوان')) {
      allItemsMap['cycle'] = _SystemModuleItem(
        key: 'cycle',
        icon: CupertinoIcons.heart_fill,
        iconColor: const Color(0xffEC4899),
        title: 'چرخه بدن',
        description: 'سلامت بانوان',
        status: _cycleEnabled ? ModuleStatus.active : ModuleStatus.inactive,
        illustrationAsset: 'assets/images/cycle_card_top.png',
        onTap: () => _handleCycleTap(colors),
        overlayText: true,
      );
    }

    // 2. Medicine Module
    if (_matchesSearch('دارو', 'مراقبت سلامتی باش')) {
      allItemsMap['medicine'] = _SystemModuleItem(
        key: 'medicine',
        icon: CupertinoIcons.bandage_fill,
        iconColor: const Color(0xffEF4444),
        title: 'دارو و سلامت',
        description: 'مراقبت سلامتی باش',
        status: _medicineEnabled ? ModuleStatus.active : ModuleStatus.inactive,
        illustrationAsset: 'assets/images/medicine_card_top.png',
        onTap: () => _handleMedicineTap(colors),
      );
    }

    // 3. Wellbeing Module (Combined Energy, Sleep, and Reflection)
    if (_matchesSearch('حال و تعادل', 'انرژی، خواب و بازتاب در یک نگاه')) {
      allItemsMap['wellbeing'] = _SystemModuleItem(
        key: 'wellbeing',
        icon: CupertinoIcons.waveform_path_ecg,
        iconColor: const Color(0xff8B5CF6),
        title: 'حال و تعادل',
        description: 'انرژی، خواب و بازتاب در یک نگاه',
        status: ModuleStatus.active,
        illustrationAsset: 'assets/images/energy_card_top.png',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const WellbeingScreen()),
          ).then((_) => _loadAllData());
        },
      );
    }

    // 4. Supplementary Sports Module
    if (_matchesSearch('ورزش تکمیلی', 'برنامه تمرین هوشمند فیتنس') ||
        _matchesSearch('ورزش', 'قدرت امروز، سلامتی فردا')) {
      allItemsMap['sports'] = _SystemModuleItem(
        key: 'sports',
        icon: Icons.fitness_center,
        iconColor: const Color(0xff10B981),
        title: 'ورزش تکمیلی',
        description: 'برنامه تمرین هوشمند و بودجهٔ حرکت هفتگی',
        status: (_sportsEnabled || _supplementarySportsEnabled)
            ? ModuleStatus.active
            : ModuleStatus.inactive,
        illustrationAsset: 'assets/images/sports_card_top.png',
        onTap: () => _handleSupplementarySportsTap(colors),
      );
    }

    // 5. Goals Module
    if (_matchesSearch('اهداف و دستاوردها', 'برنامه‌ریزی برای بهترین خود') ||
        _matchesSearch('اهداف', 'برنامه‌ریزی برای بهترین خود')) {
      allItemsMap['goals'] = _SystemModuleItem(
        key: 'goals',
        icon: CupertinoIcons.flag_fill,
        iconColor: const Color(0xffF59E0B),
        title: 'اهداف و دستاوردها',
        description: 'برنامه‌ریزی برای بهترین خود',
        status: _goalsStatus,
        illustrationAsset: 'assets/images/konkur_card_top.png',
        onTap: () => _handleGoalsTap(colors),
      );
    }

    // 6. Notebook & Experiences Module (R-08)
    if (_matchesSearch('دفترچه و تجربه‌ها', 'یادداشت‌ها و درس‌های زندگی')) {
      allItemsMap['notes'] = _SystemModuleItem(
        key: 'notes',
        icon: CupertinoIcons.doc_text_fill,
        iconColor: colors.warning,
        title: 'دفترچه و تجربه‌ها',
        description: 'یادداشت‌ها و درس‌های زندگی',
        status: _notesStatus,
        illustrationAsset: 'assets/images/notes_card_top.png',
        onTap: () => _handleNotesTap(colors),
      );
    }

    // 7. Courses Module
    if (_matchesSearch('دوره‌های آموزشی', 'یادگیری مداوم، رشد بی‌پایان')) {
      allItemsMap['courses'] = _SystemModuleItem(
        key: 'courses',
        icon: CupertinoIcons.book_fill,
        iconColor: const Color(0xff3B82F6),
        title: 'دوره‌های آموزشی',
        description: 'یادگیری مداوم، رشد بی‌پایان',
        status: _coursesEnabled ? ModuleStatus.active : ModuleStatus.inactive,
        illustrationAsset: 'assets/images/courses_card_top.png',
        onTap: () => _handleCoursesTap(colors),
      );
    }

    // 8. Study Module (formerly Konkur)
    if (_matchesSearch('درس و مطالعه', 'برنامه‌ریزی دروس و سرفصل‌ها')) {
      allItemsMap['konkur'] = _SystemModuleItem(
        key: 'konkur',
        icon: CupertinoIcons.book_fill,
        iconColor: const Color(0xff8B5CF6),
        title: 'درس و مطالعه',
        description: 'برنامه‌ریزی دروس و سرفصل‌ها',
        status: _konkurStatus,
        illustrationAsset: 'assets/images/goals_card_top.png',
        onTap: () => _handleStudyTap(colors),
      );
    }

    // 9. Religion Module
    if (_matchesSearch('عبادت و معنویت', 'رشد روح، آرامش قلب') ||
        _matchesSearch('عبادت', 'رشد روح، آرامش قلب')) {
      allItemsMap['religion'] = _SystemModuleItem(
        key: 'religion',
        icon: CupertinoIcons.circle_grid_hex,
        iconColor: const Color(0xffFBBF24),
        title: 'عبادت و معنویت',
        description: 'رشد روح، آرامش قلب',
        status: SystemsHubLogic.determineReligionStatus(
          _religionEnabled,
          _settingsMap['religion_city_id'],
        ),
        illustrationAsset: 'assets/images/worship_card_top.png',
        onTap: () => _handleReligionTap(colors),
      );
    }

    // 10. AI Assistant Module
    if (_matchesSearch('دستیار هوشمند', 'همراه هوشمند ریتمو')) {
      allItemsMap['assistant'] = _SystemModuleItem(
        key: 'assistant',
        icon: CupertinoIcons.sparkles,
        iconColor: const Color(0xff06B6D4),
        title: 'دستیار هوشمند',
        description: 'همراه هوشمند ریتمو',
        status: _assistantStatus,
        illustrationAsset: 'assets/images/assistant_card_top.png',
        onTap: () => _handleAssistantTap(colors),
      );
    }

    // 11. Insights & Analytics Module
    if (_matchesSearch('بینش‌ها و تحلیل', 'نمودارها و تحلیل روند پیشرفت، خواب و عادات') ||
        _matchesSearch('بینش‌ها', 'گزارش و آمار هوشمند ریتمو')) {
      allItemsMap['insights'] = _SystemModuleItem(
        key: 'insights',
        icon: CupertinoIcons.chart_bar_alt_fill,
        iconColor: const Color(0xff187A56),
        title: 'بینش‌ها و تحلیل',
        description: 'نمودارها و تحلیل روند پیشرفت، خواب و عادات',
        status: ModuleStatus.active,
        illustrationAsset: 'assets/images/insights_card_top.png',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const InsightsScreen()),
          );
        },
      );
    }

    // --- CASE A: Ungrouped Custom Drag-and-Drop View ---
    if (!_groupingEnabled && _searchQuery.isEmpty) {
      final orderedItems = <_SystemModuleItem>[];
      for (final key in _customModuleOrder) {
        if (allItemsMap.containsKey(key)) {
          orderedItems.add(allItemsMap[key]!);
        }
      }
      for (final entry in allItemsMap.entries) {
        if (!orderedItems.any((it) => it.key == entry.key)) {
          orderedItems.add(entry.value);
        }
      }

      return _buildReorderableCustomGrid(
        items: orderedItems,
        colors: colors,
        isDarkMode: isDarkMode,
      );
    }

    // --- CASE B: Grouped Hierarchy View ---
    final growthCards = <Widget>[];
    final intelligenceCards = <Widget>[];
    final spiritualityCards = <Widget>[];
    final healthCards = <Widget>[];
    var cardIndex = 0;

    // Growth & Planning: Goals -> Notes -> Courses -> Konkur
    if (allItemsMap.containsKey('goals')) {
      growthCards.add(_buildModuleItemWidget(cardIndex++, allItemsMap['goals']!, colors, isDarkMode));
    }
    if (allItemsMap.containsKey('notes')) {
      growthCards.add(_buildModuleItemWidget(cardIndex++, allItemsMap['notes']!, colors, isDarkMode));
    }
    if (allItemsMap.containsKey('courses')) {
      growthCards.add(_buildModuleItemWidget(cardIndex++, allItemsMap['courses']!, colors, isDarkMode));
    }
    if (allItemsMap.containsKey('konkur')) {
      growthCards.add(_buildModuleItemWidget(cardIndex++, allItemsMap['konkur']!, colors, isDarkMode));
    }

    // Intelligence & Analytics: Assistant -> Insights
    if (allItemsMap.containsKey('assistant')) {
      intelligenceCards.add(_buildModuleItemWidget(cardIndex++, allItemsMap['assistant']!, colors, isDarkMode));
    }
    if (allItemsMap.containsKey('insights')) {
      intelligenceCards.add(_buildModuleItemWidget(cardIndex++, allItemsMap['insights']!, colors, isDarkMode));
    }

    // Spirituality: Religion
    if (allItemsMap.containsKey('religion')) {
      spiritualityCards.add(_buildModuleItemWidget(cardIndex++, allItemsMap['religion']!, colors, isDarkMode));
    }

    // Health & Biology: Wellbeing -> Sports -> Medicine -> Cycle
    if (allItemsMap.containsKey('wellbeing')) {
      healthCards.add(_buildModuleItemWidget(cardIndex++, allItemsMap['wellbeing']!, colors, isDarkMode));
    }
    if (allItemsMap.containsKey('sports')) {
      healthCards.add(_buildModuleItemWidget(cardIndex++, allItemsMap['sports']!, colors, isDarkMode));
    }
    if (allItemsMap.containsKey('medicine')) {
      healthCards.add(_buildModuleItemWidget(cardIndex++, allItemsMap['medicine']!, colors, isDarkMode));
    }
    if (allItemsMap.containsKey('cycle')) {
      healthCards.add(_buildModuleItemWidget(cardIndex++, allItemsMap['cycle']!, colors, isDarkMode));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. رشد و برنامه‌ریزی
        _buildCategorySection(
          title: 'رشد و برنامه‌ریزی',
          accentColor: const Color(0xff3B82F6),
          cards: growthCards,
          colors: colors,
        ),
        const SizedBox(height: 14),

        // 2. هوشمندی و تحلیل
        _buildCategorySection(
          title: 'هوشمندی و تحلیل',
          accentColor: const Color(0xff06B6D4),
          cards: intelligenceCards,
          colors: colors,
        ),
        const SizedBox(height: 14),

        // 3. توازن و معنویت
        _buildCategorySection(
          title: 'توازن و معنویت',
          accentColor: const Color(0xffF59E0B),
          cards: spiritualityCards,
          colors: colors,
        ),
        const SizedBox(height: 14),

        // 4. سلامت و بیولوژی
        _buildCategorySection(
          title: 'سلامت و بیولوژی',
          accentColor: const Color(0xff10B981),
          cards: healthCards,
          colors: colors,
        ),
      ],
    );
  }

  Widget _buildAnimatedModuleCard({required int index, required Widget child}) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return FadeTransition(
          opacity: _fadeAnimations[index],
          child: SlideTransition(
            position: _slideAnimations[index],
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildModuleCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required ModuleStatus status,
    required VoidCallback onTap,
    required RitmoColors colors,
    required bool isDarkMode,
    required String illustrationAsset,
    bool overlayText = false,
  }) {
    // Use the specific illustration if it's one of the new high-quality card backgrounds.
    // Otherwise, fallback to cycle_card_top.png as requested by the user.
    final String imageAsset;
    if (illustrationAsset.contains('goals_card_top.png') ||
        illustrationAsset.contains('konkur_card_top.png') ||
        illustrationAsset.contains('medicine_card_top.png') ||
        illustrationAsset.contains('courses_card_top.png') ||
        illustrationAsset.contains('worship_card_top.png') ||
        illustrationAsset.contains('sports_card_top.png') ||
        illustrationAsset.contains('assistant_card_top.png') ||
        illustrationAsset.contains('energy_card_top.png') ||
        illustrationAsset.contains('notes_card_top.png') ||
        illustrationAsset.contains('reflection_card_top.png') ||
        illustrationAsset.contains('insights_card_top.png') ||
        illustrationAsset.contains('cycle_card_top.png')) {
      imageAsset = illustrationAsset;
    } else {
      imageAsset = 'assets/images/cycle_card_top.png';
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.06),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.25 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19.2),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 🎨 Full Card Image
            Image.asset(imageAsset, cacheWidth: 360, fit: BoxFit.cover),

            // Subtle gradient overlay (iOS depth feel)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.15),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.35),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),

            // Floating Status Pill (Top-Left corner)
            Positioned(
              top: 8,
              left: 8,
              child: _buildStatusPill(status, isDarkMode),
            ),

            // Floating Icon Badge (Top-Right corner)
            Positioned(
              top: 8,
              right: 8,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (isDarkMode ? Colors.black : Colors.white)
                          .withValues(alpha: 0.65),
                      border: Border.all(
                        color: iconColor.withValues(alpha: 0.3),
                        width: 0.75,
                      ),
                    ),
                    child: Icon(icon, size: 13, color: iconColor),
                  ),
                ),
              ),
            ),

            // 🌫 Frosted Glass overlay on the bottom part of the card
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(19.2),
                  bottomRight: Radius.circular(19.2),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.black.withValues(alpha: 0.48)
                          : Colors.white.withValues(alpha: 0.6),
                      border: Border(
                        top: BorderSide(
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.white.withValues(alpha: 0.4),
                          width: 0.75,
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // TITLE
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: isDarkMode
                                ? Colors.white
                                : const Color(0xFF1C1C1E),
                          ),
                        ),
                        const SizedBox(height: 1),
                        // DESCRIPTION
                        Text(
                          description,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w500,
                            color: isDarkMode
                                ? Colors.white.withValues(alpha: 0.75)
                                : Colors.black.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(ModuleStatus status, bool isDarkMode) {
    Color color;
    String text;

    switch (status) {
      case ModuleStatus.active:
        color = const Color(0xFF10B981); // Emerald green
        text = 'فعال';
      case ModuleStatus.inactive:
        color = const Color(0xFF9CA3AF);
        text = 'غیرفعال';
      case ModuleStatus.setupRequired:
        color = const Color(0xFFF59E0B);
        text = 'توجه';
      case ModuleStatus.locked:
        color = const Color(0xFFEF4444);
        text = 'قفل';
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: (isDarkMode ? Colors.black : Colors.white).withValues(
              alpha: 0.65,
            ),
            border: Border.all(
              color: color.withValues(alpha: 0.45),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5.5,
                height: 5.5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.6),
                      blurRadius: 3,
                      spreadRadius: 0.5,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4.5),
              if (status == ModuleStatus.locked) ...[
                Icon(CupertinoIcons.lock_fill, size: 9, color: color),
                const SizedBox(width: 3),
              ],
              Text(
                text,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleCycleTap(RitmoColors colors) {
    if (_cycleEnabled) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CycleScreen()),
      ).then((_) => _loadAllData());
    } else {
      _showActivationSheet(
        title: 'فعال‌سازی سیستم چرخه بدن',
        description:
            'با فعال‌سازی این سیستم، می‌توانید فازهای چرخه زیستی، پیش‌بینی هوشمند و نوسانات هورمونی خود را پایش کرده و بینش‌های سلامتی اختصاصی دریافت کنید.',
        icon: CupertinoIcons.heart_fill,
        iconColor: const Color(0xffEC4899),
        settingKey: 'module_cycle_enabled',
        onActivated: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CycleScreen()),
          ).then((_) => _loadAllData());
        },
        colors: colors,
      );
    }
  }

  void _handleMedicineTap(RitmoColors colors) {
    if (_medicineEnabled) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const HealthScreen()),
      ).then((_) => _loadAllData());
    } else {
      _showActivationSheet(
        title: 'فعال‌سازی سیستم دارو و سلامت',
        description:
            'با فعال‌سازی این سیستم، می‌توانید برنامه‌ی داروها، نوبت‌های پزشک، قند خون، فشار خون، علائم حیاتی، مدارک پزشکی، واکسیناسیون و آلرژی‌های خود را ثبت و پیگیری کنید.',
        icon: CupertinoIcons.bandage_fill,
        iconColor: const Color(0xffEF4444),
        settingKey: 'module_medicine_enabled',
        onActivated: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const HealthScreen()),
          ).then((_) => _loadAllData());
        },
        colors: colors,
      );
    }
  }

  void _handleCoursesTap(RitmoColors colors) {
    // can() always returns true — no paywall
    if (_coursesEnabled) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CoursesScreen()),
      ).then((_) => _loadAllData());
    } else {
      _showActivationSheet(
        title: 'فعال‌سازی سیستم دوره‌های آموزشی',
        description:
            'با فعال‌سازی این سیستم، می‌توانید دوره‌های ویدیویی، کتاب‌ها و دوره‌های دلخواه خود را زمان‌بندی ریتمیک کرده، ساعت مطالعه را ثبت و استریک‌های پیشرفت خود را پیگیری کنید.',
        icon: CupertinoIcons.book_fill,
        iconColor: const Color(0xff3B82F6),
        settingKey: 'module_courses_enabled',
        onActivated: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CoursesScreen()),
          ).then((_) => _loadAllData());
        },
        colors: colors,
      );
    }
  }

  void _handleStudyTap(RitmoColors colors) {
    if (_konkurEnabled) {
      StudyModuleEntry.open(context).then((_) => _loadAllData());
    } else {
      _showActivationSheet(
        title: 'فعال‌سازی ماژول درس و مطالعه',
        description:
            'با فعال‌سازی این سیستم، می‌توانید دروس، سرفصل‌ها و جلسات مطالعه را مدیریت کنید. (شامل حالت اختیاری برای داوطلبان کنکور)',
        icon: CupertinoIcons.book_fill,
        iconColor: const Color(0xff8B5CF6),
        settingKey: 'module_study_enabled',
        onActivated: () {
          StudyModuleEntry.open(context).then((_) => _loadAllData());
        },
        colors: colors,
      );
    }
  }

  void _handleGoalsTap(RitmoColors colors) {
    if (_goalsEnabled) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const GoalsScreen()),
      ).then((_) => _loadAllData());
    } else {
      _showActivationSheet(
        title: 'فعال‌سازی سیستم اهداف و برنامه‌ها',
        description:
            'با فعال‌سازی این سیستم، می‌توانید درختواره اهداف زندگی خود را تعریف کرده، آن‌ها را با کمک هوش مصنوعی خرد کنید، و برنامه‌های زمانی خود را پیگیری کنید.',
        icon: CupertinoIcons.flag_fill,
        iconColor: const Color(0xffF59E0B),
        settingKey: 'module_goals_enabled',
        onActivated: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const GoalsScreen()),
          ).then((_) => _loadAllData());
        },
        colors: colors,
      );
    }
  }

  void _handleNotesTap(RitmoColors colors) {
    if (_notesEnabled) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const NotebookScreen()),
      ).then((_) => _loadAllData());
    } else {
      _showActivationSheet(
        title: 'فعال‌سازی سیستم دفترچه و تجربه‌ها',
        description:
            'با فعال‌سازی این ماژول، می‌توانید یادداشت‌های آزاد، ایده‌ها و درس‌های زندگی خود را ثبت و در زمان‌های طلایی بازخوانی کنید.',
        icon: CupertinoIcons.doc_text_fill,
        iconColor: colors.warning,
        settingKey: 'module_notes_enabled',
        onActivated: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NotebookScreen()),
          ).then((_) => _loadAllData());
        },
        colors: colors,
      );
    }
  }

  Future<void> _handleSupplementarySportsTap(RitmoColors colors) async {
    final isSportsActive = _sportsEnabled || _supplementarySportsEnabled;
    if (isSportsActive) {
      final db = await DatabaseHelper.instance.database;
      final profileResult = await db.query(
        'ss_user_profile',
        where: 'id = ?',
        whereArgs: ['default'],
      );
      final hasCompletedOnboarding =
          profileResult.isNotEmpty &&
          (profileResult.first['onboardingCompleted'] as int? ?? 0) == 1;

      if (mounted) {
        unawaited(
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => hasCompletedOnboarding
                  ? const MvHubScreen()
                  : MvOnboardingScreen(onComplete: (_) async => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MvHubScreen()))),
            ),
          ).then((_) => _loadAllData()),
        );
      }
    } else {
      _showActivationSheet(
        title: 'فعال‌سازی سیستم ورزش تکمیلی',
        description:
            'با فعال‌سازی این سیستم، می‌توانید برنامه تمرین هوشمند بر اساس سطح و اهداف خود دریافت کنید، حرکات را با بازخورد کیفی ثبت کنید و روند تداوم خود را دنبال کنید.',
        icon: Icons.fitness_center,
        iconColor: const Color(0xff10B981),
        settingKey: 'module_sports_enabled',
        onActivated: () async {
          await ModuleManagementService.instance.setModuleEnabled(
            'module_sports_enabled',
            true,
          );
          await ModuleManagementService.instance.setModuleEnabled(
            'module_supplementary_sports_enabled',
            true,
          );
          final db = await DatabaseHelper.instance.database;
          final profileResult = await db.query(
            'ss_user_profile',
            where: 'id = ?',
            whereArgs: ['default'],
          );
          final hasCompletedOnboarding =
              profileResult.isNotEmpty &&
              (profileResult.first['onboardingCompleted'] as int? ?? 0) == 1;

          if (mounted) {
            unawaited(
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => hasCompletedOnboarding
                      ? const MvHubScreen()
                      : MvOnboardingScreen(onComplete: (_) async => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MvHubScreen()))),
                ),
              ).then((_) => _loadAllData()),
            );
          }
        },
        colors: colors,
      );
    }
  }

  void _handleAssistantTap(RitmoColors colors) {
    if (_assistantEnabled) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AssistantScreen()),
      ).then((_) => _loadAllData());
    } else {
      _showActivationSheet(
        title: 'فعال‌سازی دستیار هوشمند ریتمو',
        description:
            'دستیار هوشمند با پایش کاملاً امن و محلی روتین‌ها، اهداف، انرژی، خواب و برنامه‌ریزی، به صورت متنی به شما توصیه‌های کاربردی و بینش‌های عملی ارائه می‌دهد.',
        icon: CupertinoIcons.sparkles,
        iconColor: const Color(0xff06B6D4),
        settingKey: 'module_assistant_enabled',
        onActivated: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AssistantScreen()),
          ).then((_) => _loadAllData());
        },
        colors: colors,
      );
    }
  }

  void _handleReligionTap(RitmoColors colors) {
    if (_religionEnabled) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const WorshipScreen()),
      ).then((_) => _loadAllData());
    } else {
      _showActivationSheet(
        title: 'فعال‌سازی سیستم عبادی ریتمو',
        description:
            'سیستم عبادی به شما کمک می‌کند با ثبت مناسبت‌های خاص (مانند ماه مبارک رمضان، ایام اعتکاف، یا چله‌های مذهبی شخصی) وزن و اولویت روتین‌های عبادی خود را به طور هوشمند و بدون مزاحمت مدیریت کنید.',
        icon: CupertinoIcons.circle_grid_hex,
        iconColor: const Color(0xffFBBF24),
        settingKey: 'module_religion_enabled',
        onActivated: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const WorshipScreen()),
          ).then((_) => _loadAllData());
        },
        colors: colors,
      );
    }
  }

  void _showActivationSheet({
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    required String settingKey,
    required VoidCallback onActivated,
    required RitmoColors colors,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final isDark = sheetContext.isDark;
        final isGlass = sheetContext.isGlassEnabled;
        final blur = sheetContext.glassBlurSigma.clamp(0.0, 50.0);
        const sheetRadius = BorderRadius.vertical(top: Radius.circular(30));

        final content = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: colors.textSecondary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withValues(alpha: 0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(icon, color: iconColor, size: 38),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: colors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: TextButton(
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    final result = await ModuleManagementService.instance.setModuleEnabled(
                      settingKey,
                      true,
                    );
                    if (!mounted) return;
                    if (result == ModuleToggleResult.limitReached) {
                      final limit = FeatureLimits.current.maxActiveModules;
                      RitmoToast.show(
                        context,
                        'سقف $limit ماژول فعال همزمان پر شده. ابتدا یک ماژول را خاموش کنید یا به ریتمو پلاس ارتقا دهید.',
                        icon: Icons.lock_outline,
                      );
                      unawaited(PremiumUpgradeSheet.show(context));
                      return;
                    } else if (result == ModuleToggleResult.error) {
                      RitmoToast.show(
                        context,
                        'خطا در فعال‌سازی سیستم. لطفاً دوباره تلاش کنید.',
                        icon: Icons.error_outline,
                      );
                      return;
                    }
                    await _loadAllData();
                    onActivated();
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: colors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'فعال‌سازی سیستم',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

        final sheetBody = Directionality(
          textDirection: TextDirection.rtl,
          child: Material(
            type: MaterialType.transparency,
            child: content,
          ),
        );

        if (!isGlass) {
          return Container(
            decoration: BoxDecoration(
              color: colors.surfaceElevated,
              borderRadius: sheetRadius,
              border: Border.all(
                color: isDark ? colors.border : colors.divider,
                width: 1.0,
              ),
            ),
            child: sheetBody,
          );
        }

        return ClipRRect(
          borderRadius: sheetRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.glassTint,
                borderRadius: sheetRadius,
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.70),
                  width: 1.0,
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: sheetRadius,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: isDark ? 0.08 : 0.20),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.45],
                  ),
                ),
                child: sheetBody,
              ),
            ),
          ),
        );
      },
    );
  }

  void _showModulesManagementSheet() {
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => const ModulesGroupScreen()),
    ).then((_) => _loadAllData());
  }
}

class PressableGlassCard extends StatefulWidget {
  const PressableGlassCard({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
  });
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  State<PressableGlassCard> createState() => _PressableGlassCardState();
}

class _PressableGlassCardState extends State<PressableGlassCard> {
  double scale = 1;
  double elevation = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: widget.onLongPress,
      onTapDown: (_) {
        setState(() {
          scale = 0.97;
          elevation = 10;
        });
      },
      onTapUp: (_) {
        setState(() {
          scale = 1.0;
          elevation = 0;
        });
        widget.onTap();
      },
      onTapCancel: () {
        setState(() {
          scale = 1.0;
          elevation = 0;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.diagonal3Values(scale, scale, 1),
        child: AnimatedPhysicalModel(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          elevation: elevation,
          color: Colors.transparent,
          shadowColor: Colors.black,
          borderRadius: BorderRadius.circular(28),
          child: widget.child,
        ),
      ),
    );
  }
}

class _SystemModuleItem {
  const _SystemModuleItem({
    required this.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.status,
    required this.onTap,
    required this.illustrationAsset,
    this.overlayText = false,
  });

  final String key;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final ModuleStatus status;
  final VoidCallback onTap;
  final String illustrationAsset;
  final bool overlayText;
}

class ParallaxImage extends StatelessWidget {
  const ParallaxImage({super.key, required this.asset});
  final String asset;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
          builder: (context, value, _) {
            return Transform.translate(
              offset: Offset(0, 6 * (1 - value)),
              child: Image.asset(asset, cacheWidth: 360, fit: BoxFit.cover),
            );
          },
        );
      },
    );
  }
}
