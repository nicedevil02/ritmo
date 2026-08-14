// lib/features/supplementary_sports/movement/presentation/widgets/movement_kind_selector.dart

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/movement_repository.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_kind.dart';
import 'package:ritmo/features/supplementary_sports/movement/presentation/movement_custom_kind_sheet.dart';

class MovementKindSelector extends StatefulWidget {
  const MovementKindSelector({
    super.key,
    required this.selectedKind,
    required this.onKindSelected,
  });

  final MovementKind? selectedKind;
  final ValueChanged<MovementKind> onKindSelected;

  @override
  State<MovementKindSelector> createState() => _MovementKindSelectorState();
}

class _MovementKindSelectorState extends State<MovementKindSelector> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  int _searchRequestId = 0;

  List<MovementKind> _recentKinds = [];
  List<MovementKind> _displayKinds = [];
  MovementFamily _selectedFamilyTab = MovementFamily.endurance;
  bool _isLoadingKinds = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final recents = await MovementRepository.instance.recentKinds(limit: 6);
    final kinds = await MovementRepository.instance.getKinds(family: _selectedFamilyTab);

    if (mounted) {
      setState(() {
        _recentKinds = recents;
        _displayKinds = kinds;
        _isLoadingKinds = false;
        // If nothing is selected, default to first recent or first kind
        if (widget.selectedKind == null) {
          if (recents.isNotEmpty) {
            widget.onKindSelected(recents.first);
          } else if (kinds.isNotEmpty) {
            widget.onKindSelected(kinds.first);
          }
        }
      });
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () => _runSearch(query));
  }

  Future<void> _runSearch(String query) async {
    final requestId = ++_searchRequestId;
    final results = query.trim().isEmpty
        ? await MovementRepository.instance.getKinds(family: _selectedFamilyTab)
        : await MovementRepository.instance.searchKinds(query);

    if (!mounted || requestId != _searchRequestId) return;
    setState(() => _displayKinds = results);
  }

  Future<void> _selectFamilyTab(MovementFamily family) async {
    setState(() {
      _selectedFamilyTab = family;
      _isLoadingKinds = true;
    });
    _searchController.clear();
    final kinds = await MovementRepository.instance.getKinds(family: family);
    if (mounted) {
      setState(() {
        _displayKinds = kinds;
        _isLoadingKinds = false;
      });
    }
  }

  Future<void> _openCustomKindSheet() async {
    final created = await showMovementCustomKindSheet(context);
    if (created != null && mounted) {
      setState(() {
        _recentKinds.insert(0, created);
      });
      widget.onKindSelected(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- Recent Kinds ---
        if (_recentKinds.isNotEmpty) ...[
          const Text(
            'انواع اخیر:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _recentKinds.map((k) {
                final isSelected = widget.selectedKind?.code == k.code;
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ChoiceChip(
                    label: Text(
                      '${k.emoji} ${k.titleFa}',
                      style: TextStyle(
                        color: isSelected ? Colors.white : colors.onSurface,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: colors.primary,
                    onSelected: (val) {
                      if (val) widget.onKindSelected(k);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // --- Search & Custom Button ---
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: TextStyle(color: colors.onSurface),
                decoration: InputDecoration(
                  hintText: 'جست‌وجوی نوع ورزش...',
                  prefixIcon: const Icon(CupertinoIcons.search, size: 20),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _openCustomKindSheet,
              icon: const Icon(CupertinoIcons.add, size: 18),
              label: const Text(
                'نوع دلخواه',
                style: TextStyle(fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // --- Family Tabs ---
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: MovementFamily.values.map((f) {
              final isSelected = f == _selectedFamilyTab;
              return Padding(
                padding: const EdgeInsets.only(left: 6),
                child: ChoiceChip(
                  label: Text(
                    '${f.emoji} ${f.titleFa}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected ? Colors.white : colors.onSurface,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: colors.primary,
                  onSelected: (_) => _selectFamilyTab(f),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // --- Display Kinds Grid/List ---
        _isLoadingKinds
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CupertinoActivityIndicator(),
                ),
              )
            : (_displayKinds.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'ورزشی در این دسته یافت نشد. می‌توانید با «نوع دلخواه» اضافه کنید.',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _displayKinds.map((k) {
                      final isSelected = widget.selectedKind?.code == k.code;
                      return InkWell(
                        onTap: () => widget.onKindSelected(k),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF10B981).withValues(alpha: 0.22)
                                : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.30),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF10B981)
                                  : colors.outlineVariant.withValues(alpha: 0.20),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(k.emoji, style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 6),
                              Text(
                                k.titleFa,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? const Color(0xFF10B981) : colors.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  )),
      ],
    );
  }
}
