import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/supplementary_sports/application/application.dart';
import 'package:ritmo/features/supplementary_sports/domain/models/models.dart';
import '../components/components.dart';

/// Action Sheet: Full Taxonomy Movement Activity Picker (49 Sports - Sprint 1 & ADR 0008).
///
/// Provides live debounced search, family categorization tabs, and recently used shortcuts.
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

  @override
  State<MvKindPickerSheet> createState() => _MvKindPickerSheetState();
}

class _MvKindPickerSheetState extends State<MvKindPickerSheet> {
  late final MvKindUseCase _useCase;
  final _searchController = TextEditingController();
  Timer? _debounceTimer;

  bool _isLoading = true;
  List<MvMovementKind> _allKinds = [];
  List<MvMovementKind> _recentKinds = [];
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
      final all = await _useCase.getAllKinds();
      final recent = await _useCase.getRecentKinds(limit: 6);
      if (mounted) {
        setState(() {
          _allKinds = all;
          _recentKinds = recent;
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
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
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
          final matchAlias = k.aliasesFa?.toLowerCase().contains(lower) ?? false;
          return matchTitle || matchAlias;
        }).toList();
      } else {
        results = await _useCase.searchKinds(clean);
      }
      if (mounted) {
        setState(() {
          if (_selectedFamily != null) {
            _displayedKinds = results.where((k) => k.family == _selectedFamily).toList();
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

  @override
  Widget build(BuildContext context) {
    final colors = context.ritmoColors;
    final metrics = context.metrics;
    final textTheme = Theme.of(context).textTheme;

    return MvSheetScaffold(
      title: 'انتخاب نوع ورزش و فعالیت',
      subtitle: 'از میان بیش از ۴۰ نوع فعالیت ورزشی و حرکتی',
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
                    hintText: 'جستجوی ورزش (مثلاً فوتبال، شنا، کوه...)',
                    prefixIcon: Icon(Icons.search_rounded, color: colors.textSecondary),
                    filled: true,
                    fillColor: colors.surface,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: metrics.spaceMd,
                      vertical: metrics.spaceSm,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(metrics.radiusField),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(metrics.radiusField),
                      borderSide: BorderSide(color: colors.border),
                    ),
                  ),
                ),
                SizedBox(height: metrics.spaceMd),

                // 2. Family Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Padding(
                        padding: EdgeInsets.only(left: metrics.spaceSm),
                        child: FilterChip(
                          label: const Text('همه'),
                          selected: _selectedFamily == null,
                          onSelected: (_) => _onFamilySelected(null),
                        ),
                      ),
                      ...MovementFamily.values.map((family) {
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
                if (_searchController.text.isEmpty && _recentKinds.isNotEmpty && _selectedFamily == null) ...[
                  Text(
                    'اخیراً استفاده‌شده',
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
                  const Divider(),
                  SizedBox(height: metrics.spaceSm),
                ],

                // 4. Kinds List
                if (_displayedKinds.isEmpty)
                  Padding(
                    padding: EdgeInsets.all(metrics.spaceXl),
                    child: Center(
                      child: Text(
                        'هیچ ورزشی با این مشخصات یافت نشد.',
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
                    separatorBuilder: (context, index) => SizedBox(height: metrics.spaceSm),
                    itemBuilder: (context, index) {
                      final kind = _displayedKinds[index];
                      final isSelected = kind.code == widget.initialCode;

                      return InkWell(
                        key: ValueKey('kind_${kind.code}'),
                        onTap: () => _selectKind(kind),
                        borderRadius: BorderRadius.circular(metrics.radiusCard),
                        child: Container(
                          padding: EdgeInsets.all(metrics.spaceMd),
                          decoration: BoxDecoration(
                            color: isSelected ? colors.primary.withValues(alpha: 0.1) : colors.surface,
                            borderRadius: BorderRadius.circular(metrics.radiusCard),
                            border: Border.all(
                              color: isSelected ? colors.primary : colors.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                kind.emoji,
                                style: const TextStyle(fontSize: 28),
                              ),
                              SizedBox(width: metrics.spaceMd),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      kind.titleFa,
                                      style: textTheme.bodyLarge?.copyWith(
                                        color: colors.textPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(height: metrics.spaceXs),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: colors.surfaceElevated,
                                            borderRadius: BorderRadius.circular(metrics.radiusCard),
                                          ),
                                          child: Text(
                                            kind.family.titleFa,
                                            style: textTheme.labelSmall?.copyWith(
                                              color: colors.textSecondary,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: metrics.spaceSm),
                                        if (kind.jointImpact > 0) ...[
                                          Text(
                                            'ضربه: ${kind.jointImpact}/3',
                                            style: textTheme.labelSmall?.copyWith(
                                              color: colors.textSecondary,
                                            ),
                                          ),
                                          SizedBox(width: metrics.spaceSm),
                                        ],
                                        if (kind.primaryMetric.unitFa.isNotEmpty)
                                          Text(
                                            'واحد: ${kind.primaryMetric.unitFa}',
                                            style: textTheme.labelSmall?.copyWith(
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
                        ),
                      );
                    },
                  ),
                  SizedBox(height: metrics.spaceXl),
                ],
              ),
            ),
    );
  }
}
