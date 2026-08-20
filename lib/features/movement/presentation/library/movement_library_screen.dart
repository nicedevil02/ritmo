import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/application/movement_occurrence_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_screen_shell.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';
import 'package:ritmo/features/movement/presentation/common/skeletons.dart';
import 'package:ritmo/features/movement/presentation/library/sheets/activity_details_sheet.dart';
import 'package:ritmo/features/movement/presentation/library/widgets/filter_chips_bar.dart';
import 'package:ritmo/features/movement/presentation/library/widgets/library_activity_card.dart';

/// صفحهٔ کتابخانهٔ جامع فعالیت‌های حرکتی (MovementLibraryScreen)
class MovementLibraryScreen extends StatefulWidget {
  const MovementLibraryScreen({super.key, this.occurrenceService});

  final MovementOccurrenceService? occurrenceService;

  @override
  State<MovementLibraryScreen> createState() => _MovementLibraryScreenState();
}

class _MovementLibraryScreenState extends State<MovementLibraryScreen> {
  late final MovementOccurrenceService _occurrenceService;
  final TextEditingController _searchController = TextEditingController();

  List<MovementActivityKind> _allKinds = [];
  final Set<String> _selectedFamilies = {};
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _occurrenceService =
        widget.occurrenceService ?? MovementOccurrenceService();
    _searchController.addListener(_onSearchChanged);
    _loadActivityKinds();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() => _searchQuery = _searchController.text.trim());
  }

  Future<void> _loadActivityKinds() async {
    setState(() => _isLoading = true);
    try {
      final kinds = await _occurrenceService.getAllActivityKinds();
      if (mounted) {
        setState(() {
          _allKinds = kinds.where((k) => k.archivedAt == null).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _toggleFamily(String family) {
    setState(() {
      if (_selectedFamilies.contains(family)) {
        _selectedFamilies.remove(family);
      } else {
        _selectedFamilies.add(family);
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedFamilies.clear();
      _searchController.clear();
      _searchQuery = '';
    });
  }

  Future<void> _toggleFavorite(MovementActivityKind kind) async {
    await _occurrenceService.toggleFavoriteActivityKind(
      kind.id,
      !kind.isFavorite,
    );
    unawaited(_loadActivityKinds());
  }

  void _showActivityDetails(MovementActivityKind kind) {
    ActivityDetailsSheet.show(
      context,
      activityKind: kind,
      occurrenceService: _occurrenceService,
    ).then((_) => _loadActivityKinds());
  }

  Future<void> _showCreateCustomActivityDialog() async {
    final nameFaController = TextEditingController();
    const selectedFamily = 'walking';
    var selectedMetric = 'duration';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = ctx.colors;
        final sportsColor = ctx.modules.sports;

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(RitmoRadius.card),
              ),
              title: Text(
                MovementStrings.libraryCreateCustom,
                style: RitmoTextStyles.cardTitle(colors.textPrimary),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameFaController,
                      decoration: InputDecoration(
                        labelText: 'نام فعالیت (فارسی)',
                        hintText: 'مثال: بدمینتون، کاراته...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            RitmoRadius.field,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: RitmoSpacing.md),
                    Text(
                      'شاخص اصلی اندازه‌گیری:',
                      style: RitmoTextStyles.label(colors.textPrimary),
                    ),
                    const SizedBox(height: RitmoSpacing.xs),
                    DropdownButtonFormField<String>(
                      initialValue: selectedMetric,
                      items: const [
                        DropdownMenuItem(
                          value: 'duration',
                          child: Text('مدت زمان (دقیقه)'),
                        ),
                        DropdownMenuItem(
                          value: 'distance',
                          child: Text('مسافت (کیلومتر)'),
                        ),
                        DropdownMenuItem(
                          value: 'count',
                          child: Text('تعداد / شمارش'),
                        ),
                        DropdownMenuItem(
                          value: 'free',
                          child: Text('زمان آزاد'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null)
                          setDialogState(() => selectedMetric = val);
                      },
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            RitmoRadius.field,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(
                    'انصراف',
                    style: RitmoTextStyles.caption(colors.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameFaController.text.trim().isNotEmpty) {
                      Navigator.of(ctx).pop(true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: sportsColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('ایجاد'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && nameFaController.text.trim().isNotEmpty) {
      await _occurrenceService.createCustomActivityKind(
        nameFa: nameFaController.text.trim(),
        family: selectedFamily,
        icon: 'sports',
        primaryMetric: selectedMetric,
      );
      unawaited(_loadActivityKinds());
    }
  }

  List<MovementActivityKind> _getFilteredKinds() {
    return _allKinds.where((kind) {
      if (_selectedFamilies.isNotEmpty &&
          !_selectedFamilies.contains(kind.family)) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchFa = kind.nameFa.toLowerCase().contains(q);
        final matchEn = kind.nameEn?.toLowerCase().contains(q) ?? false;
        final matchAliases = kind.aliases.any(
          (a) => a.toLowerCase().contains(q),
        );
        if (!matchFa && !matchEn && !matchAliases) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sportsColor = context.modules.sports;

    final filteredKinds = _getFilteredKinds();
    final customKinds = filteredKinds.where((k) => k.isCustom).toList();
    final standardKinds = filteredKinds.where((k) => !k.isCustom).toList();

    return MovementScreenShell(
      title: MovementStrings.libraryScreenTitle,
      body: _isLoading
          ? const Column(
              children: [
                ListRowSkeleton(),
                SizedBox(height: MovementLayout.kCardSpacing),
                ListRowSkeleton(),
                SizedBox(height: MovementLayout.kCardSpacing),
                ListRowSkeleton(),
              ],
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: MovementLayout.kScreenPadding,
                vertical: RitmoSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ۱. نوار جستجو
                  Container(
                    height: MovementLayout.kFieldMinHeight,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(RitmoRadius.field),
                      border: Border.all(color: colors.border),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: RitmoTextStyles.body(colors.textPrimary),
                      decoration: InputDecoration(
                        hintText: MovementStrings.librarySearchPlaceholder,
                        hintStyle: RitmoTextStyles.body(colors.textTertiary),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: colors.textTertiary,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: colors.textTertiary,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: RitmoSpacing.md,
                          vertical: RitmoSpacing.sm,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: MovementLayout.kCardSpacing),

                  // ۲. نوار فیلتر دسته‌ها
                  FilterChipsBar(
                    selectedFamilies: _selectedFamilies,
                    onFamilyToggled: _toggleFamily,
                    onClearAll: _clearFilters,
                  ),
                  const SizedBox(height: MovementLayout.kCardSpacing),

                  // دکمهٔ ساخت فعالیت سفارشی
                  InkWell(
                    onTap: _showCreateCustomActivityDialog,
                    borderRadius: BorderRadius.circular(RitmoRadius.card),
                    child: Container(
                      padding: const EdgeInsets.all(RitmoSpacing.md),
                      decoration: BoxDecoration(
                        color: sportsColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(RitmoRadius.card),
                        border: Border.all(
                          color: sportsColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.add_circle_outline_rounded,
                            color: sportsColor,
                          ),
                          const SizedBox(width: RitmoSpacing.sm),
                          Text(
                            MovementStrings.libraryCreateCustom,
                            style: RitmoTextStyles.label(
                              sportsColor,
                            ).copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: MovementLayout.kCardSpacing),

                  if (filteredKinds.isEmpty) ...[
                    // حالت بدون نتیجه
                    Container(
                      padding: const EdgeInsets.all(RitmoSpacing.xxl),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 48,
                            color: colors.textTertiary,
                          ),
                          const SizedBox(height: RitmoSpacing.md),
                          Text(
                            MovementStrings.libraryNoResult,
                            style: RitmoTextStyles.cardTitle(
                              colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: RitmoSpacing.sm),
                          TextButton(
                            onPressed: _clearFilters,
                            child: const Text(
                              MovementStrings.libraryClearFilters,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // ۳. فعالیت‌های استاندارد
                    ...standardKinds.map((kind) {
                      return LibraryActivityCard(
                        activityKind: kind,
                        onTap: () => _showActivityDetails(kind),
                        onToggleFavorite: () => _toggleFavorite(kind),
                      );
                    }),

                    // ۴. فعالیت‌های سفارشی من
                    if (customKinds.isNotEmpty) ...[
                      const SizedBox(height: RitmoSpacing.md),
                      Text(
                        MovementStrings.libraryCustomActivities,
                        style: RitmoTextStyles.sectionHeadline(
                          colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: RitmoSpacing.sm),
                      ...customKinds.map((kind) {
                        return LibraryActivityCard(
                          activityKind: kind,
                          onTap: () => _showActivityDetails(kind),
                          onToggleFavorite: () => _toggleFavorite(kind),
                        );
                      }),
                    ],
                  ],

                  const SizedBox(height: RitmoSpacing.xxl),
                ],
              ),
            ),
    );
  }
}
