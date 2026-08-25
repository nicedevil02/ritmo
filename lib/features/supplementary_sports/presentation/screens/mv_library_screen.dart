import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/supplementary_sports/application/application.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import '../components/components.dart';
import '../sheets/mv_custom_kind_sheet.dart';

/// Screen: "کتابخانهٔ حرکات، برنامه‌ها و انواع ورزش" (Section 5.4 & S1-T8).
class MvLibraryScreen extends StatefulWidget {
  final List<MvExercise> allExercises;
  final ValueChanged<MvExercise>? onExerciseStart;
  final MvKindUseCase? kindUseCase;
  final List<MvMovementKind>? initialKinds;

  const MvLibraryScreen({
    super.key,
    required this.allExercises,
    this.onExerciseStart,
    this.kindUseCase,
    this.initialKinds,
  });

  @override
  State<MvLibraryScreen> createState() => _MvLibraryScreenState();
}

class _MvLibraryScreenState extends State<MvLibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final MvKindUseCase _kindUseCase;

  // Exercises Tab State
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'ALL';
  bool _onlyApartmentFriendly = false;
  bool _onlyNoEquipment = false;

  // Movement Kinds Tab State
  final TextEditingController _kindsSearchController = TextEditingController();
  List<MvMovementKind> _allKinds = [];
  bool _isLoadingKinds = true;

  final List<Map<String, String>> _categories = [
    const {'code': 'ALL', 'title': 'همه'},
    ...MvMuscleGroup.all.map((m) => {'code': m.code, 'title': m.titleFa}),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _kindUseCase = widget.kindUseCase ?? MvKindUseCase();
    if (widget.initialKinds != null) {
      _allKinds = List.from(widget.initialKinds!);
      _isLoadingKinds = false;
    } else {
      _loadKinds();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _kindsSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadKinds() async {
    try {
      final kinds = await _kindUseCase.getAllKinds();
      if (mounted) {
        setState(() {
          _allKinds = kinds;
          _isLoadingKinds = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingKinds = false);
    }
  }

  List<MvExercise> get _filteredExercises {
    final query = _searchController.text.trim().toLowerCase();

    return widget.allExercises.where((ex) {
      if (query.isNotEmpty) {
        final matchesName = ex.name.toLowerCase().contains(query);
        final matchesCat = ex.category.toLowerCase().contains(query);
        if (!matchesName && !matchesCat) return false;
      }
      if (_selectedCategory != 'ALL') {
        if (!ex.category.toUpperCase().contains(_selectedCategory)) {
          return false;
        }
      }
      if (_onlyApartmentFriendly) {
        if (ex.noisy || ex.impact > 1) return false;
      }
      if (_onlyNoEquipment) {
        if (ex.toolsRequired.isNotEmpty && !ex.toolsRequired.contains('none')) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  List<MvMovementKind> get _filteredKinds {
    final query = _kindsSearchController.text.trim().toLowerCase();
    if (query.isEmpty) return _allKinds;
    return _allKinds.where((k) {
      final matchesTitle = k.titleFa.toLowerCase().contains(query);
      final matchesCode = k.code.toLowerCase().contains(query);
      final matchesAliases =
          k.aliasList.any((a) => a.toLowerCase().contains(query));
      return matchesTitle || matchesCode || matchesAliases;
    }).toList();
  }

  Future<void> _openCreateCustomKind() async {
    final newKind = await MvCustomKindSheet.show(
      context: context,
      useCase: _kindUseCase,
    );
    if (newKind != null && mounted) {
      setState(() {
        _allKinds = [newKind, ..._allKinds.where((k) => k.code != newKind.code)];
      });
      await _loadKinds();
    }
  }

  void _showExerciseDetail(MvExercise ex) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.metrics.radiusSheet),
        ),
      ),
      builder: (ctx) {
        final metrics = context.metrics;
        final colors = context.ritmoColors;
        final textTheme = Theme.of(context).textTheme;

        return MvSheetScaffold(
          title: ex.name,
          subtitle: ex.category,
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MvAnimationStage(
                height: 200,
                exerciseId: ex.id,
                animationAsset: ex.animationAsset,
              ),
              SizedBox(height: metrics.spaceMd),
              if (ex.descriptionFa != null && ex.descriptionFa!.isNotEmpty)
                Text(
                  ex.descriptionFa!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              SizedBox(height: metrics.spaceMd),
              Row(
                children: [
                  _buildTag('مهارت: سطح ${ex.skillRequired}', colors.primary),
                  SizedBox(width: metrics.spaceSm),
                  _buildTag(
                    ex.noisy ? 'پرصدا' : 'بی‌صدا / آپارتمانی',
                    ex.noisy ? colors.warning : colors.success,
                  ),
                  if (ex.impact <= 1) ...[
                    SizedBox(width: metrics.spaceSm),
                    _buildTag('کم‌ضربه', colors.success),
                  ],
                ],
              ),
              SizedBox(height: metrics.spaceLg),
            ],
          ),
          bottomAction: MvPrimaryAction(
            label: 'شروع آنی این حرکت',
            icon: Icons.play_arrow_rounded,
            onPressed: () {
              Navigator.pop(ctx);
              widget.onExerciseStart?.call(ex);
            },
          ),
        );
      },
    );
  }

  Widget _buildTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(RitmoRadius.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.ritmoColors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('کتابخانهٔ ورزشی'),
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colors.primary,
          labelColor: colors.primary,
          unselectedLabelColor: colors.textSecondary,
          tabs: const [
            Tab(text: 'تمرین‌ها'),
            Tab(text: 'برنامه‌ها'),
            Tab(key: ValueKey('library_tab_kinds'), text: 'انواع ورزش'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // تب ۱: تمرین‌ها
          _buildExercisesTab(colors, metrics, textTheme),
          // تب ۲: برنامه‌ها
          _buildProgramsTab(colors, metrics, textTheme),
          // تب ۳: انواع ورزش (S1-T8)
          _buildKindsTab(colors, metrics, textTheme),
        ],
      ),
    );
  }

  Widget _buildExercisesTab(
    dynamic colors,
    dynamic metrics,
    TextTheme textTheme,
  ) {
    final filtered = _filteredExercises;

    return Column(
      children: [
        // Search & Filter Header
        Padding(
          padding: EdgeInsets.all(metrics.spaceLg),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'جستجوی حرکت (مثلاً شنا، اسکات، پلانک)...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () =>
                              setState(() => _searchController.clear()),
                        )
                      : null,
                  filled: true,
                  fillColor: colors.surfaceElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(metrics.radiusField),
                    borderSide: BorderSide(color: colors.border),
                  ),
                ),
              ),
              SizedBox(height: metrics.spaceSm),

              // Category Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((c) {
                    final isSel = c['code'] == _selectedCategory;
                    return Padding(
                      padding: EdgeInsets.only(left: metrics.spaceSm),
                      child: MvChip(
                        label: c['title']!,
                        isSelected: isSel,
                        onTap: () =>
                            setState(() => _selectedCategory = c['code']!),
                      ),
                    );
                  }).toList(),
                ),
              ),
              SizedBox(height: metrics.spaceSm),

              // Quick Filter Toggles
              Row(
                children: [
                  FilterChip(
                    label: const Text('بی‌صدا (آپارتمانی)'),
                    selected: _onlyApartmentFriendly,
                    onSelected: (v) =>
                        setState(() => _onlyApartmentFriendly = v),
                  ),
                  SizedBox(width: metrics.spaceSm),
                  FilterChip(
                    label: const Text('بدون وسیله'),
                    selected: _onlyNoEquipment,
                    onSelected: (v) => setState(() => _onlyNoEquipment = v),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Exercise List
        Expanded(
          child: filtered.isEmpty
              ? const MvEmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'حرکتی پیدا نشد',
                  description:
                      'فیلترها را تغییر بده یا عبارت دیگری را جستجو کن.',
                )
              : ListView.separated(
                  padding: EdgeInsets.symmetric(
                    horizontal: metrics.spaceLg,
                    vertical: metrics.spaceSm,
                  ),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => SizedBox(height: metrics.spaceSm),
                  itemBuilder: (context, index) {
                    final ex = filtered[index];
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showExerciseDetail(ex),
                        borderRadius: BorderRadius.circular(
                          metrics.radiusCard,
                        ),
                        child: Container(
                          padding: EdgeInsets.all(metrics.spaceMd),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(
                              metrics.radiusCard,
                            ),
                            border: Border.all(color: colors.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: colors.surfaceElevated,
                                  borderRadius: BorderRadius.circular(
                                    metrics.radiusField,
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.fitness_center_rounded,
                                    color: colors.primary,
                                    size: metrics.iconMd,
                                  ),
                                ),
                              ),
                              SizedBox(width: metrics.spaceMd),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ex.name,
                                      style: textTheme.bodyLarge?.copyWith(
                                        color: colors.textPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(height: metrics.spaceXs),
                                    Text(
                                      '${ex.category} · سطح ${ex.skillRequired}',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_left_rounded,
                                color: colors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildProgramsTab(
    dynamic colors,
    dynamic metrics,
    TextTheme textTheme,
  ) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(metrics.spaceLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_month_rounded, size: 48, color: colors.primary),
            SizedBox(height: metrics.spaceMd),
            Text(
              'برنامه‌های تمرینی ۴ هفته‌ای',
              style: textTheme.titleMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: metrics.spaceSm),
            Text(
              'برنامه‌ها بر اساس سطح و اهداف شما از تب هفته قابل تنظیم و بازتولید هستند.',
              style: textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKindsTab(dynamic colors, dynamic metrics, TextTheme textTheme) {
    final kinds = _filteredKinds;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(metrics.spaceLg),
          child: Column(
            children: [
              // Search Field
              TextField(
                key: const ValueKey('kinds_tab_search_field'),
                controller: _kindsSearchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'جستجوی ورزش و فعالیت (مثلاً فوتبال، شنا، پدل)...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _kindsSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () =>
                              setState(() => _kindsSearchController.clear()),
                        )
                      : null,
                  filled: true,
                  fillColor: colors.surfaceElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(metrics.radiusField),
                    borderSide: BorderSide(color: colors.border),
                  ),
                ),
              ),
              SizedBox(height: metrics.spaceMd),

              // Button to create custom kind
              MvPrimaryAction(
                key: const ValueKey('library_create_custom_kind_button'),
                label: 'ورزش سفارشی جدید',
                icon: Icons.add_rounded,
                onPressed: _openCreateCustomKind,
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingKinds
              ? const Center(child: CircularProgressIndicator())
              : kinds.isEmpty
                  ? const MvEmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'ورزشی پیدا نشد',
                      description: 'می‌توانی ورزش جدیدی به لیست اضافه کنی.',
                    )
                  : ListView.separated(
                      padding: EdgeInsets.symmetric(
                        horizontal: metrics.spaceLg,
                        vertical: metrics.spaceSm,
                      ),
                      itemCount: kinds.length,
                      separatorBuilder: (_, _) =>
                          SizedBox(height: metrics.spaceSm),
                      itemBuilder: (context, index) {
                        final kind = kinds[index];
                        return Container(
                          key: ValueKey('library_kind_${kind.code}'),
                          padding: EdgeInsets.all(metrics.spaceMd),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(
                              metrics.radiusCard,
                            ),
                            border: Border.all(color: colors.border),
                          ),
                          child: Row(
                            children: [
                              Text(kind.emoji, style: textTheme.headlineSmall),
                              SizedBox(width: metrics.spaceMd),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          kind.titleFa,
                                          style: textTheme.bodyLarge?.copyWith(
                                            color: colors.textPrimary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        if (kind.isCustom) ...[
                                          SizedBox(width: metrics.spaceSm),
                                          _buildTag('سفارشی', colors.primary),
                                        ],
                                      ],
                                    ),
                                    SizedBox(height: metrics.spaceXs),
                                    Text(
                                      '${kind.family.titleFa} · شدت انرژی: ${toPersianDigits(kind.baseMet.toStringAsFixed(1))} MET',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
