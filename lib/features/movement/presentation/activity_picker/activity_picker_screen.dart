import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/application/movement_occurrence_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';
import 'package:ritmo/features/movement/presentation/activity_picker/sheets/custom_activity_form_sheet.dart';
import 'package:ritmo/features/movement/presentation/activity_picker/widgets/activity_category_section.dart';
import 'package:ritmo/features/movement/presentation/activity_picker/widgets/activity_search_field.dart';
import 'package:ritmo/features/movement/presentation/common/empty_state_block.dart';
import 'package:ritmo/features/movement/presentation/common/error_block.dart';
import 'package:ritmo/features/movement/presentation/common/movement_layout.dart';
import 'package:ritmo/features/movement/presentation/common/movement_screen_shell.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';
import 'package:ritmo/features/movement/presentation/common/skeletons.dart';
import 'package:ritmo/features/movement/presentation/common/undo_toast.dart';

enum ActivityPickerIntent {
  startNow,
  addToPlan,
  retroLog,
}

/// صفحهٔ کامل انتخاب فعالیت ورزشی (ActivityPickerScreen)
class ActivityPickerScreen extends StatefulWidget {
  const ActivityPickerScreen({
    super.key,
    this.intent = ActivityPickerIntent.addToPlan,
    this.onSelected,
    this.occurrenceService,
  });

  final ActivityPickerIntent intent;
  final ValueChanged<MovementActivityKind>? onSelected;
  final MovementOccurrenceService? occurrenceService;

  @override
  State<ActivityPickerScreen> createState() => _ActivityPickerScreenState();
}

class _ActivityPickerScreenState extends State<ActivityPickerScreen> {
  late final MovementOccurrenceService _occurrenceService;
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  List<MovementActivityKind> _allKinds = [];

  final Map<String, String> _familyTitles = {
    'walking': 'پیاده‌روی و دویدن',
    'running': 'پیاده‌روی و دویدن',
    'cycling': 'دوچرخه‌سواری و رکاب‌زنی',
    'swimming': 'شنا و ورزش‌های آبی',
    'strength': 'تمرین قدرتی و بدنسازی',
    'mobility': 'کشش، یوگا و پیلاتس',
    'flexibility': 'کشش، یوگا و پیلاتس',
    'racket': 'ورزش‌های راکتی',
    'team': 'ورزش‌های تیمی',
    'martial': 'هنرهای رزمی',
    'combat': 'هنرهای رزمی',
    'hiking': 'کوهنوردی و طبیعت‌گردی',
    'other': 'سایر فعالیت‌ها',
  };

  @override
  void initState() {
    super.initState();
    _occurrenceService = widget.occurrenceService ?? MovementOccurrenceService();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    setState(() => _isLoading = true);
    try {
      final kinds = await _occurrenceService.getAllActivityKinds();
      if (mounted) {
        setState(() {
          _allKinds = kinds;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<MovementActivityKind> get _filteredKinds {
    if (_searchQuery.isEmpty) return _allKinds;
    return _allKinds.where((k) => k.matchesQuery(_searchQuery)).toList();
  }

  List<MovementActivityKind> get _favoriteKinds =>
      _filteredKinds.where((k) => k.isFavorite).toList();

  Map<String, List<MovementActivityKind>> get _groupedCategories {
    final map = <String, List<MovementActivityKind>>{};
    for (final kind in _filteredKinds) {
      map.putIfAbsent(kind.family, () => []).add(kind);
    }
    return map;
  }

  void _onActivitySelected(MovementActivityKind kind) {
    if (widget.onSelected != null) {
      widget.onSelected!(kind);
    } else {
      Navigator.of(context).pop(kind);
    }
  }

  Future<void> _toggleFavorite(MovementActivityKind kind) async {
    await _occurrenceService.toggleFavoriteActivityKind(kind.id);
    await _loadActivities();
  }

  Future<void> _openCustomActivitySheet() async {
    final existingNames = _allKinds.map((k) => k.nameFa).toList();
    final created = await CustomActivityFormSheet.show(
      context,
      existingNames: existingNames,
      onSubmit: ({
        required nameFa,
        required family,
        required primaryMetric,
        required icon,
      }) async {
        return await _occurrenceService.createCustomActivityKind(
          nameFa: nameFa,
          family: family,
          primaryMetric: primaryMetric,
          icon: icon,
        );
      },
    );

    if (created != null && mounted) {
      MovementUndoToast.show(
        context,
        message: MovementStrings.customActivityCreatedToast,
      );
      await _loadActivities();
      _onActivitySelected(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sportsColor = context.modules.sports;

    return MovementScreenShell(
      title: MovementStrings.pickerTitle,
      subtitle: widget.intent == ActivityPickerIntent.startNow
          ? MovementStrings.addStartNow
          : (widget.intent == ActivityPickerIntent.retroLog
              ? MovementStrings.addRetroLog
              : MovementStrings.addToPlan),
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(RitmoSpacing.lg),
              child: Column(
                children: [
                  CardSkeleton(height: 52),
                  SizedBox(height: RitmoSpacing.md),
                  CardSkeleton(height: 120),
                  SizedBox(height: RitmoSpacing.md),
                  CardSkeleton(height: 200),
                ],
              ),
            )
          : CustomScrollView(
              slivers: [
                // بنر خطا در صورت وجود
                if (_errorMessage != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.lg),
                      child: ErrorBlock(
                        title: 'خطا در بارگذاری فعالیت‌ها',
                        message: _errorMessage!,
                        isBannerMode: true,
                        onRetry: _loadActivities,
                      ),
                    ),
                  ),

                // فیلد جستجو
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: RitmoSpacing.lg,
                      vertical: RitmoSpacing.sm,
                    ),
                    child: ActivitySearchField(
                      onQueryChanged: (q) => setState(() => _searchQuery = q),
                    ),
                  ),
                ),

                // دکمهٔ ساخت فعالیت سفارشی
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: RitmoSpacing.lg,
                      vertical: RitmoSpacing.xs,
                    ),
                    child: OutlinedButton.icon(
                      onPressed: _openCustomActivitySheet,
                      icon: Icon(Icons.add_rounded, color: sportsColor, size: 20),
                      label: Text(
                        MovementStrings.customActivityNewButton,
                        style: RitmoTextStyles.label(sportsColor),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, MovementLayout.kFieldMinHeight),
                        side: BorderSide(color: sportsColor.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(RitmoRadius.field),
                        ),
                      ),
                    ),
                  ),
                ),

                // حالت جستجوی بدون نتیجه
                if (_filteredKinds.isEmpty)
                  SliverToBoxAdapter(
                    child: EmptyStateBlock(
                      kind: MovementEmptyKind.searchNoResult,
                      actionLabel: MovementStrings.customActivityNewButton,
                      onAction: _openCustomActivitySheet,
                    ),
                  )
                else ...[
                  // بخش برگزیده‌ها (اگر در جستجو نباشیم یا برگزیده فیلترشده داشته باشیم)
                  if (_favoriteKinds.isNotEmpty && _searchQuery.isEmpty)
                    SliverToBoxAdapter(
                      child: ActivityCategorySection(
                        title: MovementStrings.pickerFavorites,
                        kinds: _favoriteKinds,
                        onKindSelected: _onActivitySelected,
                        onFavoriteToggle: _toggleFavorite,
                      ),
                    ),

                  // گروه‌بندی ۹ دسته‌ای
                  ..._groupedCategories.entries.map((entry) {
                    final title = _familyTitles[entry.key] ?? entry.key;
                    return SliverToBoxAdapter(
                      child: ActivityCategorySection(
                        title: title,
                        kinds: entry.value,
                        onKindSelected: _onActivitySelected,
                        onFavoriteToggle: _toggleFavorite,
                      ),
                    );
                  }),
                ],

                const SliverToBoxAdapter(
                  child: SizedBox(height: RitmoSpacing.xxl),
                ),
              ],
            ),
    );
  }
}
