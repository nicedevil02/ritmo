import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/features/supplementary_sports/application/application.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import 'package:ritmo/l10n/app_localizations.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../components/components.dart';

/// Action Sheet: Full Taxonomy Movement Activity Picker (49 Sports - S1-T5 & ADR 0008).
///
/// Provides 250ms live debounced search, family categorization tabs with fixed order,
/// recently used shortcuts, and seasonal recommendations.
class MvKindPickerSheet extends StatefulWidget {
  final MvKindUseCase? useCase;
  final String? initialCode;
  final List<MvMovementKind>? initialKinds;

  const MvKindPickerSheet({
    super.key,
    this.useCase,
    this.initialCode,
    this.initialKinds,
  });

  static Future<MvMovementKind?> show({
    required BuildContext context,
    MvKindUseCase? useCase,
    String? initialCode,
    List<MvMovementKind>? initialKinds,
  }) {
    return MvSheetScaffold.show<MvMovementKind>(
      context: context,
      builder: (ctx) => MvKindPickerSheet(
        useCase: useCase,
        initialCode: initialCode,
        initialKinds: initialKinds,
      ),
    );
  }

  static Future<String?> showCode({
    required BuildContext context,
    MvKindUseCase? useCase,
    String? initialCode,
    List<MvMovementKind>? initialKinds,
  }) async {
    final kind = await show(
      context: context,
      useCase: useCase,
      initialCode: initialCode,
      initialKinds: initialKinds,
    );
    return kind?.code;
  }

  @override
  State<MvKindPickerSheet> createState() => _MvKindPickerSheetState();
}

class _MvKindPickerSheetState extends State<MvKindPickerSheet> {
  static const List<MovementFamily> _orderedFamilies = [
    MovementFamily.sport,
    MovementFamily.outdoor,
    MovementFamily.endurance,
    MovementFamily.strength,
    MovementFamily.martialSkill,
    MovementFamily.mindBody,
    MovementFamily.daily,
  ];

  late final MvKindUseCase _useCase;
  final _searchController = TextEditingController();
  Timer? _debounceTimer;

  bool _isLoading = true;
  List<MvMovementKind> _allKinds = [];
  List<MvMovementKind> _recentKinds = [];
  List<MvMovementKind> _seasonalKinds = [];
  List<MvMovementKind> _displayedKinds = [];
  MovementFamily? _selectedFamily; // null == all

  @override
  void initState() {
    super.initState();
    _useCase = widget.useCase ?? MvKindUseCase();
    if (widget.initialKinds != null && widget.initialKinds!.isNotEmpty) {
      _allKinds = widget.initialKinds!;
      _displayedKinds = widget.initialKinds!;
      _isLoading = false;
    } else {
      _loadInitialData();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final currentMonth = Jalali.now().month;
      final all = await _useCase.getAllKinds();
      final recent = await _useCase.getRecentKinds(limit: 6);
      final seasonal = await _useCase.getSeasonalKinds(currentMonth);
      if (mounted) {
        setState(() {
          _allKinds = all;
          _recentKinds = recent;
          _seasonalKinds = seasonal.take(6).toList();
          _displayedKinds = all;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () async {
      final clean = query.trim();
      if (clean.isEmpty) {
        _applyFamilyFilter();
        return;
      }
      List<MvMovementKind> results;
      if (_allKinds.isNotEmpty) {
        final lower = clean.toLowerCase();
        results = _allKinds.where((k) {
          final matchTitle = k.titleFa.toLowerCase().contains(lower);
          final matchAlias =
              k.aliasesFa?.toLowerCase().contains(lower) ?? false;
          return matchTitle || matchAlias;
        }).toList();
      } else {
        results = await _useCase.searchKinds(clean);
      }
      if (mounted) {
        setState(() {
          if (_selectedFamily != null) {
            _displayedKinds = results
                .where((k) => k.family == _selectedFamily)
                .toList();
          } else {
            _displayedKinds = results;
          }
        });
      }
    });
  }

  void _onFamilySelected(MovementFamily? family) {
    setState(() {
      _selectedFamily = family;
      _applyFamilyFilter();
    });
  }

  void _applyFamilyFilter() {
    final query = _searchController.text.trim();
    var list = _allKinds;
    if (_selectedFamily != null) {
      list = list.where((k) => k.family == _selectedFamily).toList();
    }
    if (query.isNotEmpty) {
      final lower = query.toLowerCase();
      list = list.where((k) {
        final matchTitle = k.titleFa.toLowerCase().contains(lower);
        final matchAlias = k.aliasesFa?.toLowerCase().contains(lower) ?? false;
        return matchTitle || matchAlias;
      }).toList();
    }
    setState(() {
      _displayedKinds = list;
    });
  }

  void _selectKind(MvMovementKind kind) {
    Navigator.of(context).pop(kind);
  }

  Future<void> _openCreateCustomDialog() async {
    final l10n = AppLocalizations.of(context);
    final titleController = TextEditingController();
    final customKind = await showDialog<MvMovementKind>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n?.mv_kind_picker_create_new ?? 'New Activity'),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n?.mv_day_plan_custom_title ?? 'Activity Name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n?.cancel ?? 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final title = titleController.text.trim();
              if (title.isEmpty) return;
              final code = 'CUSTOM_${DateTime.now().millisecondsSinceEpoch}';
              final newKind = MvMovementKind(
                code: code,
                titleFa: title,
                emoji: '⚡',
                family: MovementFamily.daily,
                baseMet: 4.0,
                metLow: 3.0,
                metHigh: 5.0,
                primaryMetric: MovementMetric.duration,
                isOutdoor: false,
                isSocial: false,
                needsVenue: false,
                jointImpact: 1,
                isCustom: true,
                isEnabled: true,
                usageCount: 1,
                sortOrder: 999,
              );
              Navigator.of(ctx).pop(newKind);
            },
            child: Text(l10n?.mv_action_save ?? 'Save'),
          ),
        ],
      ),
    );

    if (customKind != null && mounted) {
      final saved = await _useCase.saveCustomKind(customKind);
      if (mounted) {
        Navigator.of(context).pop(saved);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    return MvSheetScaffold(
      title: l10n?.mv_kind_picker_title ?? 'Select Activity',
      subtitle: l10n?.mv_kind_picker_subtitle ?? 'From diverse sport activities',
      body: _isLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Search Bar
                  TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: l10n?.mv_kind_picker_search_hint ?? 'Search sports...',
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: colors.textSecondary,
                      ),
                      filled: true,
                      fillColor: colors.surface,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: metrics.spaceMd,
                        vertical: metrics.spaceSm,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          metrics.radiusField,
                        ),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          metrics.radiusField,
                        ),
                        borderSide: BorderSide(color: colors.border),
                      ),
                    ),
                  ),
                  SizedBox(height: metrics.spaceMd),

                  // 2. Family Filter Chips (7 ordered families)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Padding(
                          padding: EdgeInsets.only(left: metrics.spaceSm),
                          child: FilterChip(
                            label: Text(l10n?.mv_kind_picker_tab_all ?? 'All'),
                            selected: _selectedFamily == null,
                            onSelected: (_) => _onFamilySelected(null),
                          ),
                        ),
                        ..._orderedFamilies.map((family) {
                          return Padding(
                            padding: EdgeInsets.only(left: metrics.spaceSm),
                            child: FilterChip(
                              avatar: Text(family.emoji),
                              label: Text(family.titleFa),
                              selected: _selectedFamily == family,
                              onSelected: (_) => _onFamilySelected(family),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  SizedBox(height: metrics.spaceMd),

                  // 3. Recently Used Section (when no search query)
                  if (_searchController.text.isEmpty &&
                      _recentKinds.isNotEmpty &&
                      _selectedFamily == null) ...[
                    Text(
                      l10n?.mv_kind_picker_recent ?? 'Recently Used',
                      style: textTheme.labelMedium?.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: metrics.spaceSm),
                    Wrap(
                      spacing: metrics.spaceSm,
                      runSpacing: metrics.spaceSm,
                      children: _recentKinds.map((k) {
                        return ActionChip(
                          avatar: Text(k.emoji),
                          label: Text(k.titleFa),
                          onPressed: () => _selectKind(k),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: metrics.spaceMd),
                  ],

                  // 4. Seasonal Section (when no search query)
                  if (_searchController.text.isEmpty &&
                      _seasonalKinds.isNotEmpty &&
                      _selectedFamily == null) ...[
                    Text(
                      l10n?.mv_kind_picker_seasonal ?? 'Seasonal',
                      style: textTheme.labelMedium?.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: metrics.spaceSm),
                    Wrap(
                      spacing: metrics.spaceSm,
                      runSpacing: metrics.spaceSm,
                      children: _seasonalKinds.map((k) {
                        return ActionChip(
                          avatar: Text(k.emoji),
                          label: Text(k.titleFa),
                          onPressed: () => _selectKind(k),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: metrics.spaceMd),
                    const Divider(),
                    SizedBox(height: metrics.spaceSm),
                  ],

                  // 5. Kinds List
                  if (_displayedKinds.isEmpty)
                    Padding(
                      padding: EdgeInsets.all(metrics.spaceXl),
                      child: Center(
                        child: Text(
                          l10n?.mv_kind_picker_empty ?? 'No sports found.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _displayedKinds.length,
                      separatorBuilder: (context, index) =>
                          SizedBox(height: metrics.spaceSm),
                      itemBuilder: (context, index) {
                        final kind = _displayedKinds[index];
                        final isSelected = kind.code == widget.initialCode;

                        return RitmoCard.neumorphic(
                          key: ValueKey('kind_${kind.code}'),
                          onTap: () => _selectKind(kind),
                          isSelected: isSelected,
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Text(
                                kind.emoji,
                                style: textTheme.headlineMedium,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      kind.titleFa,
                                      style: textTheme.bodyLarge?.copyWith(
                                        color: colors.textPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        RitmoCardBadge(
                                          label: kind.family.titleFa,
                                          color: colors.primary,
                                        ),
                                        if (kind.isOutdoor)
                                          RitmoCardBadge(
                                            label: l10n?.mv_kind_picker_outdoor ?? 'Outdoor 🌿',
                                            color: colors.accent,
                                          ),
                                        if (kind.needsVenue)
                                          RitmoCardBadge(
                                            label: l10n?.mv_kind_picker_hall ?? 'Indoor Hall 🏟',
                                            color: colors.textSecondary,
                                          ),
                                        if (kind.jointImpact > 0)
                                          Text(
                                            l10n?.mv_kind_picker_impact(toPersianDigits(kind.jointImpact.toString())) ??
                                                'Impact: ${kind.jointImpact}/3',
                                            style: textTheme.labelSmall
                                                ?.copyWith(
                                                  color: colors.textSecondary,
                                                ),
                                          ),
                                          if (kind
                                              .primaryMetric
                                              .unitFa
                                              .isNotEmpty)
                                            Text(
                                              l10n?.mv_kind_picker_unit(kind.primaryMetric.unitFa) ??
                                                  'Unit: ${kind.primaryMetric.unitFa}',
                                              style: textTheme.labelSmall
                                                  ?.copyWith(
                                                    color: colors.textSecondary,
                                                  ),
                                            ),
                                        ],
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
                          );
                        },
                      ),
                  SizedBox(height: metrics.spaceLg),

                  // 6. Create Custom Sport Button
                  OutlinedButton.icon(
                    key: const ValueKey('mv_kind_picker_create_custom'),
                    onPressed: _openCreateCustomDialog,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(l10n?.mv_kind_picker_create_new ?? 'Create New Sport'),
                  ),
                  SizedBox(height: metrics.spaceXl),
                ],
              ),
            ),
    );
  }
}
