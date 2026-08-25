import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import '../components/components.dart';

/// Screen 4: "کتابخانهٔ حرکات و تمرین‌ها" (Section 5.4).
class MvLibraryScreen extends StatefulWidget {
  final List<MvExercise> allExercises;
  final ValueChanged<MvExercise>? onExerciseStart;

  const MvLibraryScreen({
    super.key,
    required this.allExercises,
    this.onExerciseStart,
  });

  @override
  State<MvLibraryScreen> createState() => _MvLibraryScreenState();
}

class _MvLibraryScreenState extends State<MvLibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'ALL';
  bool _onlyApartmentFriendly = false;
  bool _onlyNoEquipment = false;

  final List<Map<String, String>> _categories = [
    const {'code': 'ALL', 'title': 'همه'},
    ...MvMuscleGroup.all.map((m) => {'code': m.code, 'title': m.titleFa}),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MvExercise> get _filteredExercises {
    final query = _searchController.text.trim().toLowerCase();

    return widget.allExercises.where((ex) {
      // 1. Search query
      if (query.isNotEmpty) {
        final matchesName = ex.name.toLowerCase().contains(query);
        final matchesCat = ex.category.toLowerCase().contains(query);
        if (!matchesName && !matchesCat) return false;
      }

      // 2. Category
      if (_selectedCategory != 'ALL') {
        if (!ex.category.toUpperCase().contains(_selectedCategory)) return false;
      }

      // 3. Apartment mode (N-04)
      if (_onlyApartmentFriendly) {
        if (ex.noisy || ex.impact > 1) return false;
      }

      // 4. Equipment
      if (_onlyNoEquipment) {
        if (ex.toolsRequired.isNotEmpty && !ex.toolsRequired.contains('none')) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  void _showExerciseDetail(MvExercise ex) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(context.metrics.radiusSheet)),
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
                  style: textTheme.bodyMedium?.copyWith(color: colors.textPrimary),
                ),
              SizedBox(height: metrics.spaceMd),
              Row(
                children: [
                  _buildTag('مهارت: سطح ${ex.skillRequired}', colors.primary),
                  SizedBox(width: metrics.spaceSm),
                  _buildTag(ex.noisy ? 'پرصدا' : 'بی‌صدا / آپارتمانی', ex.noisy ? colors.warning : colors.success),
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
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.ritmoColors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;

    final filtered = _filteredExercises;

    return Scaffold(
      appBar: AppBar(
        title: const Text('کتابخانهٔ حرکات'),
        centerTitle: false,
      ),
      body: Column(
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
                            onPressed: () => setState(() => _searchController.clear()),
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
                          onTap: () => setState(() => _selectedCategory = c['code']!),
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
                      onSelected: (v) => setState(() => _onlyApartmentFriendly = v),
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
                    description: 'فیلترها را تغییر بده یا عبارت دیگری را جستجو کن.',
                  )
                : ListView.separated(
                    padding: EdgeInsets.symmetric(horizontal: metrics.spaceLg, vertical: metrics.spaceSm),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => SizedBox(height: metrics.spaceSm),
                    itemBuilder: (context, index) {
                      final ex = filtered[index];
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showExerciseDetail(ex),
                          borderRadius: BorderRadius.circular(metrics.radiusCard),
                          child: Container(
                            padding: EdgeInsets.all(metrics.spaceMd),
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(metrics.radiusCard),
                              border: Border.all(color: colors.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: colors.surfaceElevated,
                                    borderRadius: BorderRadius.circular(metrics.radiusField),
                                  ),
                                  child: Center(
                                    child: Icon(Icons.fitness_center_rounded, color: colors.primary, size: metrics.iconMd),
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
                                Icon(Icons.chevron_left_rounded, color: colors.textSecondary),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
