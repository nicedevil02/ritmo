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

  // پس از انتخاب، انتخابگر جمع می‌شود و خلاصه نشان می‌دهد.
  // دکمهٔ «تغییر» دوباره بازش می‌کند.
  bool _forceExpand = false;

  bool get _isCollapsed =>
      widget.selectedKind != null && !_forceExpand;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void didUpdateWidget(MovementKindSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    // وقتی والد selectedKind را null کرد (یعنی خودش reset کرد)
    // حالت forceExpand را ریست کن تا انتخابگر دوباره باز شود.
    if (widget.selectedKind == null && oldWidget.selectedKind != null) {
      _forceExpand = false;
    }
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
        // auto-select حذف شد — انتخاب همیشه صریح است.
      });
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _runSearch(query),
    );
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
      setState(() => _recentKinds.insert(0, created));
      widget.onKindSelected(created);
    }
  }

  void _selectKind(MovementKind k) {
    setState(() => _forceExpand = false);
    widget.onKindSelected(k);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = context.modules.sports;

    // ── حالت جمع‌شده: خلاصه + دکمهٔ تغییر ────────────────────────────────────
    if (_isCollapsed) {
      final k = widget.selectedKind!;
      return Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: RitmoSpacing.md),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(RitmoRadius.card),
          border: Border.all(color: accent.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Text(k.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: RitmoSpacing.sm),
            Expanded(
              child: Text(
                k.titleFa,
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: colors.textPrimary,
                ),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(64, 44),
                foregroundColor: accent,
              ),
              onPressed: () => setState(() => _forceExpand = true),
              child: const Text(
                'تغییر',
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── حالت باز: جست‌وجو + تب + شبکه ───────────────────────────────────────
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // اخیراً استفاده‌شده
        if (_recentKinds.isNotEmpty) ...[
          Text(
            'انواع اخیر:',
            style: TextStyle(
              fontFamily: 'Vazirmatn',
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: RitmoSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _recentKinds.map((k) {
                return Padding(
                  padding: const EdgeInsetsDirectional.only(end: RitmoSpacing.sm),
                  child: _KindChip(
                    kind: k,
                    isSelected: widget.selectedKind?.code == k.code,
                    accent: accent,
                    colors: colors,
                    onTap: () => _selectKind(k),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: RitmoSpacing.lg),
        ],

        // جست‌وجو + نوع دلخواه
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontFamily: 'Vazirmatn',
                  ),
                  decoration: InputDecoration(
                    hintText: 'جست‌وجوی نوع ورزش...',
                    hintStyle: TextStyle(
                      color: colors.textTertiary,
                      fontFamily: 'Vazirmatn',
                    ),
                    prefixIcon: const Icon(CupertinoIcons.search, size: 20),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(RitmoRadius.field),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(RitmoRadius.field),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(RitmoRadius.field),
                      borderSide: BorderSide(color: accent),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: RitmoSpacing.sm),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _openCustomKindSheet,
                icon: const Icon(CupertinoIcons.add, size: 18),
                label: const Text(
                  'نوع دلخواه',
                  style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.textSecondary,
                  side: BorderSide(color: colors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(RitmoRadius.field),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: RitmoSpacing.md),

        // تب‌های خانواده
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: MovementFamily.values.map((f) {
              final isSelected = f == _selectedFamilyTab;
              return Padding(
                padding: const EdgeInsetsDirectional.only(end: RitmoSpacing.sm),
                child: GestureDetector(
                  onTap: () => _selectFamilyTab(f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? accent.withValues(alpha: 0.15)
                          : colors.surfaceSunken,
                      borderRadius: BorderRadius.circular(RitmoRadius.pill),
                      border: Border.all(
                        color: isSelected ? accent : colors.border,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${f.emoji} ${f.titleFa}',
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isSelected ? accent : colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: RitmoSpacing.md),

        // شبکهٔ انواع
        if (_isLoadingKinds)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CupertinoActivityIndicator(),
            ),
          )
        else if (_displayKinds.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'ورزشی در این دسته یافت نشد. می‌توانید با «نوع دلخواه» اضافه کنید.',
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontSize: 12,
                color: colors.textSecondary,
              ),
            ),
          )
        else
          Wrap(
            spacing: RitmoSpacing.sm,
            runSpacing: RitmoSpacing.sm,
            children: _displayKinds.map((k) {
              return _KindChip(
                kind: k,
                isSelected: widget.selectedKind?.code == k.code,
                accent: accent,
                colors: colors,
                onTap: () => _selectKind(k),
              );
            }).toList(),
          ),
      ],
    );
  }
}

// ─── چیپ یکدست ≥ ۴۴ پیکسل ───────────────────────────────────────────────────────────────────────────────

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.kind,
    required this.isSelected,
    required this.accent,
    required this.colors,
    required this.onTap,
  });

  final MovementKind kind;
  final bool isSelected;
  final Color accent;
  final RitmoColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(RitmoRadius.chip),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? accent.withValues(alpha: 0.18)
                : colors.surfaceSunken,
            borderRadius: BorderRadius.circular(RitmoRadius.chip),
            border: Border.all(
              color: isSelected ? accent : colors.border,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(kind.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                kind.titleFa,
                style: TextStyle(
                  fontFamily: 'Vazirmatn',
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? accent : colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
