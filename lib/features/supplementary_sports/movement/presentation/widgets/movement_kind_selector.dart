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

  /// فقط وقتی صدا زده می‌شود که کاربر خودش یک نوع را انتخاب کند.
  /// (پیش‌از‌این هنگام لود شدن هم خودبه‌خود صدا می‌شد و یک ورزش
  /// انتخاب‌نشده را جا می‌انداخت.)
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

    if (!mounted) return;
    setState(() {
      _recentKinds = recents;
      _displayKinds = kinds;
      _isLoadingKinds = false;
    });
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
    final accent = context.modules.sports;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── پرکاربردها و انتخاب‌های اخیر ──
        if (_recentKinds.isNotEmpty) ...[
          Text(
            'پرکاربرد و اخیر',
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: RitmoSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _recentKinds.map((k) {
                final isSelected = widget.selectedKind?.code == k.code;
                return Padding(
                  padding: const EdgeInsets.only(left: RitmoSpacing.sm),
                  child: _KindChip(
                    label: '${k.emoji} ${k.titleFa}',
                    isSelected: isSelected,
                    accent: accent,
                    onTap: () => widget.onKindSelected(k),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: RitmoSpacing.lg),
        ],

        // ── جست‌وجو و نوع دلخواه ──
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: TextStyle(fontFamily: 'Vazirmatn', color: colors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'جست‌وجوی نوع ورزش...',
                  hintStyle: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 13,
                    color: colors.textTertiary,
                  ),
                  prefixIcon: Icon(CupertinoIcons.search, size: 20, color: colors.textSecondary),
                  filled: true,
                  fillColor: colors.surfaceSunken,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: RitmoSpacing.md,
                    vertical: RitmoSpacing.md,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(RitmoRadius.field),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(RitmoRadius.field),
                    borderSide: BorderSide(color: accent, width: 1.5),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(RitmoRadius.field),
                  ),
                ),
              ),
            ),
            const SizedBox(width: RitmoSpacing.sm),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _openCustomKindSheet,
                icon: Icon(CupertinoIcons.add, size: 18, color: accent),
                label: Text(
                  'دلخواه',
                  style: TextStyle(
                    fontFamily: 'Vazirmatn',
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: accent.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(RitmoRadius.field),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.md),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: RitmoSpacing.md),

        // ── دسته‌بندی خانوادگی ──
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: MovementFamily.values.map((f) {
              final isSelected = f == _selectedFamilyTab;
              return Padding(
                padding: const EdgeInsets.only(left: RitmoSpacing.xs + 2),
                child: _KindChip(
                  label: '${f.emoji} ${f.titleFa}',
                  isSelected: isSelected,
                  accent: accent,
                  fontSize: 12,
                  onTap: () => _selectFamilyTab(f),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: RitmoSpacing.md),

        // ── نتیجهٔ فهرست ──
        if (_isLoadingKinds)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(RitmoSpacing.lg),
              child: CupertinoActivityIndicator(),
            ),
          )
        else if (_displayKinds.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: RitmoSpacing.md),
            child: Text(
              'ورزشی در این دسته پیدا نشد. می‌توانی با دکمهٔ «دلخواه» خودت بسازی.',
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 12.5,
                color: colors.textSecondary,
              ),
            ),
          )
        else
          Wrap(
            spacing: RitmoSpacing.sm,
            runSpacing: RitmoSpacing.sm,
            children: _displayKinds.map((k) {
              final isSelected = widget.selectedKind?.code == k.code;
              return _KindChip(
                label: '${k.emoji} ${k.titleFa}',
                isSelected: isSelected,
                accent: accent,
                onTap: () => widget.onKindSelected(k),
              );
            }).toList(),
          ),
      ],
    );
  }
}

/// چیپ یکدست برای هر سه ردیف (اخیر، خانواده، نتایج) — پیش‌از‌این سه سبک متفاوت داشتند.
class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.label,
    required this.isSelected,
    required this.accent,
    required this.onTap,
    this.fontSize = 13,
  });

  final String label;
  final bool isSelected;
  final Color accent;
  final VoidCallback onTap;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(RitmoRadius.chip),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: 40),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(
            horizontal: RitmoSpacing.md,
            vertical: RitmoSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isSelected ? accent.withValues(alpha: 0.18) : colors.surfaceSunken,
            borderRadius: BorderRadius.circular(RitmoRadius.chip),
            border: Border.all(
              color: isSelected ? accent : colors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontSize: fontSize,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? accent : colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
