import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/ritmo_execution_kernel.dart';
import 'package:ritmo/core/domain/agenda/action_router.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/ritmo_toast.dart';
import 'package:ritmo/core/utils/time_of_day_minutes.dart';
import 'package:ritmo/core/ux/ritmo_haptics.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_card.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_empty_state.dart';
import 'package:ritmo/features/registry/domain/registry_entry.dart';
import 'package:ritmo/features/registry/domain/registry_health_issue.dart';
import 'package:ritmo/features/registry/domain/registry_query.dart';
import 'package:ritmo/features/registry/logic/registry_health_audit.dart';
import 'package:ritmo/features/registry/logic/registry_index.dart';
import 'package:ritmo/features/registry/logic/registry_service.dart';
import 'package:ritmo/features/registry/presentation/widgets/registry_bulk_bar.dart';
import 'package:ritmo/features/registry/presentation/widgets/registry_health_card.dart';
import 'package:ritmo/features/registry/presentation/widgets/registry_row.dart';
import 'package:ritmo/features/registry/presentation/widgets/registry_skeleton.dart';
import 'package:ritmo/features/routines/presentation/universal_planner_sheet.dart';

enum PlanSortMode { displayOrder, closestDue, time, duration, alphabetical }

class AllPlansScreen extends StatefulWidget {
  const AllPlansScreen({super.key});

  @override
  State<AllPlansScreen> createState() => _AllPlansScreenState();
}

class _AllPlansScreenState extends State<AllPlansScreen> {
  final RegistryService _service = RegistryService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  RegistryQuery _query = const RegistryQuery();
  List<RegistryEntry> _entries = [];
  List<RegistryHealthIssue> _healthIssues = [];
  Map<String, String> _settingsMap = {};

  bool _isLoading = true;
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  PlanSortMode _sortMode = PlanSortMode.displayOrder;

  @override
  void initState() {
    super.initState();
    _loadSettingsAndData();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSettingsAndData() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('app_settings');
      final map = <String, String>{};
      for (final r in rows) {
        map[r['key'] as String] = r['value'] as String? ?? '';
      }
      _settingsMap = map;
      await _refreshData();
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  int _getRemainingMinutes(RegistryEntry entry) {
    final timeStr = entry.agendaProxy.timeOfDay?.trim();
    final targetMins = TimeOfDayMinutes.tryParse(timeStr);
    if (targetMins == null) return 99999;

    final now = DateTime.now();
    final nowMins = now.hour * 60 + now.minute;
    final diff = targetMins - nowMins;
    return diff < -45 ? 99990 : diff;
  }

  void _applySort() {
    switch (_sortMode) {
      case PlanSortMode.closestDue:
        _entries.sort(
          (a, b) => _getRemainingMinutes(a).compareTo(_getRemainingMinutes(b)),
        );
        break;
      case PlanSortMode.time:
        _entries.sort((a, b) {
          final timeA = a.agendaProxy.timeOfDay ?? '23:59';
          final timeB = b.agendaProxy.timeOfDay ?? '23:59';
          return timeA.compareTo(timeB);
        });
        break;
      case PlanSortMode.duration:
        _entries.sort(
          (a, b) => (b.agendaProxy.durationMinutes ?? 0).compareTo(
            a.agendaProxy.durationMinutes ?? 0,
          ),
        );
        break;
      case PlanSortMode.alphabetical:
        _entries.sort((a, b) => a.title.compareTo(b.title));
        break;
      case PlanSortMode.displayOrder:
        break;
    }
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      RegistryIndex.instance.invalidate();
      final items = await _service.query(_query, _settingsMap);
      List<RegistryHealthIssue> health = [];
      try {
        health = await RegistryHealthAudit().inspectAll(_settingsMap);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _entries = items;
          _healthIssues = health;
          _applySort();
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String text) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      setState(() {
        _query = _query.copyWith(searchText: text);
      });
      _refreshData();
    });
  }

  Future<void> _archiveEntry(RegistryEntry entry) async {
    await RitmoExecutionKernel.instance.execute(
      ArchiveRoutineCommand(routineId: entry.sourceId),
    );

    RegistryIndex.instance.invalidate();
    await _refreshData();

    if (mounted) {
      RitmoToast.show(
        context,
        '«${entry.title}» بایگانی شد',
        onUndo: () async {
          await RitmoExecutionKernel.instance.execute(
            UnarchiveRoutineCommand(routineId: entry.sourceId),
          );
          RegistryIndex.instance.invalidate();
          await _refreshData();
        },
      );
    }
  }

  int get _activeFilterCount {
    int count = 0;
    if (_query.domainFilter.isNotEmpty) count += _query.domainFilter.length;
    if (_sortMode != PlanSortMode.displayOrder) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: context.colors.background,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Custom Header ───
              _buildHeader(theme),

              // ─── Search Bar (integrated filter) ───
              _buildSearchBar(theme, isDark),

              const SizedBox(height: 12),

              // ─── Level 1: Lens Switcher ───
              _buildLensSwitcher(theme, isDark),

              const SizedBox(height: 10),

              // ─── Level 2: Domain Chips (only for items lens) ───
              if (_query.lens == RegistryLens.items)
                _buildDomainFilterChips(theme, isDark),

              if (_query.lens == RegistryLens.items) const SizedBox(height: 8),

              // ─── Main Content ───
              Expanded(
                child: _isLoading
                    ? const RegistrySkeleton()
                    : _query.lens == RegistryLens.health
                    ? _buildHealthLensList()
                    : _buildItemsList(theme, isDark),
              ),

              // ─── Bulk Action Bar ───
              if (_isSelectionMode)
                RegistryBulkBar(
                  selectedCount: _selectedIds.length,
                  onCancel: () {
                    setState(() {
                      _isSelectionMode = false;
                      _selectedIds.clear();
                    });
                  },
                  onArchiveSelected: () async {
                    for (final id in _selectedIds) {
                      final srcId = id.split(':').last;
                      await RitmoExecutionKernel.instance.execute(
                        ArchiveRoutineCommand(routineId: srcId),
                      );
                    }
                    if (mounted) {
                      setState(() {
                        _isSelectionMode = false;
                        _selectedIds.clear();
                      });
                    }
                    RegistryIndex.instance.invalidate();
                    await _refreshData();
                  },
                  onDeleteSelected: () async {
                    for (final id in _selectedIds) {
                      final srcId = id.split(':').last;
                      await RitmoExecutionKernel.instance.execute(
                        DeleteRoutineCommand(routineId: srcId),
                      );
                    }
                    if (mounted) {
                      setState(() {
                        _isSelectionMode = false;
                        _selectedIds.clear();
                      });
                    }
                    RegistryIndex.instance.invalidate();
                    await _refreshData();
                  },
                ),
            ],
          ),
        ),

        // ─── Floating Action Button ───
        floatingActionButton: _query.lens == RegistryLens.items
            ? Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () {
                    RitmoHapticsPolicy.tap();
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) =>
                          UniversalPlannerSheet(onSaved: () => setState(() {})),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2430) : const Color(0xFF222834),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : const Color(0xFF3B4454),
                        width: 0.9,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.50)
                              : const Color(0xFF1E2430).withValues(alpha: 0.40),
                          offset: const Offset(0, 4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.add, size: 19, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'افزودن برنامه',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Vazirmatn',
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ──────────── HEADER ──────────────────────
  // ═══════════════════════════════════════════

  Widget _buildHeader(ThemeData theme) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        RitmoSpacing.lg,
        RitmoSpacing.md,
        RitmoSpacing.lg,
        RitmoSpacing.sm,
      ),
      child: Row(
        children: [
          // 3D Tactile Back Button
          GestureDetector(
            onTap: () {
              RitmoHapticsPolicy.tap();
              Navigator.of(context).pop();
            },
            child: RitmoNeuSurface(
              height: 36,
              width: 36,
              radius: 18,
              sunken: false,
              padding: EdgeInsets.zero,
              child: Center(
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 20,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Title + Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مخزن روتین‌ها',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Vazirmatn',
                    color: colors.textPrimary,
                  ),
                ),
                if (!_isLoading)
                  Text(
                    '${toPersianDigits(_entries.length.toString())} برنامه فعال',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontFamily: 'Vazirmatn',
                      color: colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),

          // Selection mode close
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                setState(() {
                  _isSelectionMode = false;
                  _selectedIds.clear();
                });
              },
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ──────────── SEARCH BAR ──────────────────
  // ═══════════════════════════════════════════

  Widget _buildSearchBar(ThemeData theme, bool isDark) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.lg),
      child: RitmoCard.neumorphicSunken(
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: SizedBox(
          height: 42,
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                size: 20,
                color: colors.textTertiary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontFamily: 'Vazirmatn',
                    color: colors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'جست‌وجو در برنامه‌ها',
                    hintStyle: TextStyle(
                      fontSize: 13.5,
                      fontFamily: 'Vazirmatn',
                      color: colors.textTertiary,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: Icon(
                    Icons.clear_rounded,
                    size: 18,
                    color: colors.textTertiary,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                ),
              // Sort / Filter icon inside search bar
              Stack(
                children: [
                  PopupMenuButton<PlanSortMode>(
                    icon: Icon(
                      Icons.tune_rounded,
                      size: 20,
                      color: _sortMode != PlanSortMode.displayOrder
                          ? colors.primary
                          : colors.textTertiary,
                    ),
                    tooltip: 'مرتب‌سازی',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    onSelected: (mode) {
                      setState(() {
                        _sortMode = mode;
                        _applySort();
                      });
                    },
                    itemBuilder: _buildSortMenuItems,
                  ),
                  if (_activeFilterCount > 0)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        width: 15,
                        height: 15,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          toPersianDigits(_activeFilterCount.toString()),
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Vazirmatn',
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<PopupMenuEntry<PlanSortMode>> _buildSortMenuItems(BuildContext ctx) {
    final colors = ctx.colors;
    PopupMenuEntry<PlanSortMode> item(
      PlanSortMode mode,
      IconData icon,
      String label,
    ) {
      final isActive = _sortMode == mode;
      return PopupMenuItem(
        value: mode,
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? colors.primary : null,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'Vazirmatn',
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      );
    }

    return [
      item(PlanSortMode.displayOrder, Icons.dashboard_rounded, 'ترتیب پیش‌فرض'),
      item(
        PlanSortMode.closestDue,
        Icons.hourglass_top_rounded,
        'نزدیک‌ترین موعد',
      ),
      item(PlanSortMode.time, Icons.schedule_rounded, 'زمان اجرا (صبح تا شب)'),
      item(
        PlanSortMode.duration,
        Icons.timer_rounded,
        'مدت زمان (بلند به کوتاه)',
      ),
      item(
        PlanSortMode.alphabetical,
        Icons.sort_by_alpha_rounded,
        'حروف الفبا',
      ),
    ];
  }

  // ═══════════════════════════════════════════
  // ──────────── LENS SWITCHER ───────────────
  // ═══════════════════════════════════════════

  Widget _buildLensSwitcher(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.lg),
      child: Container(
        height: 38.0 * context.metrics.densityFactor,
        padding: const EdgeInsets.all(3.5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131720) : const Color(0xFFE2E7EE),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : const Color(0xFFCAD2DC).withValues(alpha: 0.9),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.45)
                  : const Color(0xFFB8C2CF).withValues(alpha: 0.55),
              offset: const Offset(0, 1.5),
              blurRadius: 3,
            ),
            if (!isDark)
              const BoxShadow(
                color: Colors.white,
                offset: Offset(0, -1),
                blurRadius: 1.5,
              ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildLensTab(
                theme,
                isDark,
                RegistryLens.items,
                'برنامه‌ها',
                badgeText: _isLoading
                    ? null
                    : toPersianDigits(_entries.length.toString()),
              ),
            ),
            Expanded(
              child: _buildLensTab(
                theme,
                isDark,
                RegistryLens.reminders,
                'یادآورها',
              ),
            ),
            Expanded(
              child: _buildLensTab(
                theme,
                isDark,
                RegistryLens.health,
                'سلامت',
                showWarningDot: _healthIssues.isNotEmpty,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLensTab(
    ThemeData theme,
    bool isDark,
    RegistryLens lens,
    String label, {
    String? badgeText,
    bool showWarningDot = false,
  }) {
    final isActive = _query.lens == lens;
    final activeTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final inactiveTextColor = isDark ? const Color(0xFF8E9BAE) : const Color(0xFF64748B);

    final fullLabel = badgeText != null ? '$label $badgeText' : label;

    return GestureDetector(
      onTap: () {
        RitmoHaptics.selection();
        setState(() {
          _query = _query.copyWith(lens: lens);
        });
        _refreshData();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [
                          const Color(0xFF2E3544),
                          const Color(0xFF232936),
                        ]
                      : [
                          Colors.white,
                          const Color(0xFFF7F9FC),
                        ],
                )
              : null,
          color: isActive ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(12.5),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.white,
                    offset: const Offset(-1, -1),
                    blurRadius: 3,
                  ),
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.5)
                        : const Color(0xFFAEB8C6).withValues(alpha: 0.65),
                    offset: const Offset(1.5, 2.5),
                    blurRadius: 4.5,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showWarningDot) ...[
              Container(
                width: 5.5,
                height: 5.5,
                margin: const EdgeInsets.only(left: 4),
                decoration: const BoxDecoration(
                  color: Color(0xFFF59E0B),
                  shape: BoxShape.circle,
                ),
              ),
            ],
            Text(
              fullLabel,
              style: TextStyle(
                fontSize: 12.5,
                fontFamily: 'Vazirmatn',
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: isActive ? activeTextColor : inactiveTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ──────────── DOMAIN FILTER CHIPS ─────────
  // ═══════════════════════════════════════════

  Widget _buildDomainFilterChips(ThemeData theme, bool isDark) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.lg),
        children: [
          _buildFilterChip(
            theme,
            isDark,
            label: 'همه',
            isSelected: _query.domainFilter.isEmpty,
            onTap: () {
              setState(() {
                _query = _query.copyWith(domainFilter: {});
              });
              _refreshData();
            },
          ),
          const SizedBox(width: 8),
          for (final d in RegistryDomain.values)
            if (d.settingsKey.isEmpty || _settingsMap[d.settingsKey] == 'true')
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _buildFilterChip(
                  theme,
                  isDark,
                  label: d.faLabel,
                  isSelected: _query.domainFilter.contains(d),
                  onTap: () {
                    final nextFilter = Set<RegistryDomain>.from(
                      _query.domainFilter,
                    );
                    if (_query.domainFilter.contains(d)) {
                      nextFilter.remove(d);
                    } else {
                      nextFilter.add(d);
                    }
                    setState(() {
                      _query = _query.copyWith(domainFilter: nextFilter);
                    });
                    _refreshData();
                  },
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    ThemeData theme,
    bool isDark, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;

    return GestureDetector(
      onTap: () {
        RitmoHaptics.selection();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary.withValues(alpha: isDark ? 0.20 : 0.12)
              : (isDark ? const Color(0xFF1B202B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? colors.primary.withValues(alpha: isDark ? 0.60 : 0.40)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : const Color(0xFFCBD5E1).withValues(alpha: 0.6)),
            width: isSelected ? 1.2 : 0.8,
          ),
          boxShadow: [
            if (!isSelected)
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.25)
                    : const Color(0xFFCBD5E1).withValues(alpha: 0.4),
                offset: const Offset(0, 1),
                blurRadius: 2,
              ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontFamily: 'Vazirmatn',
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected
                  ? colors.primary
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ──────────── ITEMS LIST ──────────────────
  // ═══════════════════════════════════════════

  Widget _buildItemsList(ThemeData theme, bool isDark) {
    if (_entries.isEmpty) {
      return Center(
        child: RitmoEmptyState(
          icon: CupertinoIcons.tray,
          title: _query.searchText.isNotEmpty
              ? 'نتیجه‌ای یافت نشد'
              : 'هنوز برنامه‌ای ثبت نشده',
          description: _query.searchText.isNotEmpty
              ? 'هیچ برنامه‌ای مطابق عبارت جستجو پیدا نشد.'
              : 'با دکمه «افزودن برنامه» روتین‌های روزانه خود را اضافه کنید.',
        ),
      );
    }

    return ListView.builder(
      itemCount: _entries.length,
      padding: const EdgeInsets.only(bottom: 88, top: 4),
      itemBuilder: (context, index) {
        final entry = _entries[index];
        return RepaintBoundary(
          child: RegistryRow(
            entry: entry,
            isSelected: _selectedIds.contains(entry.id),
            isSelectionMode: _isSelectionMode,
            onTap: () {
              if (_isSelectionMode) {
                setState(() {
                  if (_selectedIds.contains(entry.id)) {
                    _selectedIds.remove(entry.id);
                    if (_selectedIds.isEmpty) {
                      _isSelectionMode = false;
                    }
                  } else {
                    _selectedIds.add(entry.id);
                  }
                });
              } else {
                ActionRouter.open(context, item: entry.agendaProxy);
              }
            },
            onLongPress: () {
              setState(() {
                _isSelectionMode = true;
                _selectedIds.add(entry.id);
              });
            },
            onArchive: () => _archiveEntry(entry),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════
  // ──────────── HEALTH LENS ─────────────────
  // ═══════════════════════════════════════════

  Widget _buildHealthLensList() {
    if (_healthIssues.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.verified_rounded,
              color: Color(0xFF10B981),
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text(
              'همه چیز مرتب است',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'هیچ ناهنجاری یا مشکلی در دیتابیس برنامه‌ها یافت نشد.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _healthIssues.length,
      padding: const EdgeInsets.only(bottom: 40),
      itemBuilder: (context, index) {
        final issue = _healthIssues[index];
        return RegistryHealthCard(issue: issue, onFixed: () => _refreshData());
      },
    );
  }
}
