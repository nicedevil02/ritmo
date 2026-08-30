import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/ux/ritmo_sheet_scaffold.dart';

class PickerOption<T> {
  final String label;
  final String? subtitle;
  final IconData? icon;
  final T value;

  const PickerOption({
    required this.label,
    this.subtitle,
    this.icon,
    required this.value,
  });
}

/// Generic item selector sheet.
///
/// IRON RULE: A picker NEVER writes to the database or gateway directly.
/// It only allows selection and returns the chosen item or null.
class RitmoPickerSheet<T> extends StatefulWidget {
  final String title;
  final List<PickerOption<T>> options;
  final T? initialValue;
  final bool enableSearch;

  const RitmoPickerSheet({
    super.key,
    required this.title,
    required this.options,
    this.initialValue,
    this.enableSearch = false,
  });

  /// Present picker and return selected value or null.
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required List<PickerOption<T>> options,
    T? initialValue,
    bool enableSearch = false,
  }) {
    return RitmoSheetScaffold.present<T>(
      context: context,
      semanticsLabel: 'انتخابگر $title',
      builder: (context) => RitmoPickerSheet<T>(
        title: title,
        options: options,
        initialValue: initialValue,
        enableSearch: enableSearch,
      ),
    );
  }

  @override
  State<RitmoPickerSheet<T>> createState() => _RitmoPickerSheetState<T>();
}

class _RitmoPickerSheetState<T> extends State<RitmoPickerSheet<T>> {
  late List<PickerOption<T>> _filteredOptions;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredOptions = widget.options;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredOptions = widget.options;
      } else {
        _filteredOptions = widget.options
            .where(
              (opt) =>
                  opt.label.toLowerCase().contains(query) ||
                  (opt.subtitle != null &&
                      opt.subtitle!.toLowerCase().contains(query)),
            )
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Navigation Bar (Apple HIG Sheet Header)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () {
                RitmoHaptics.tap();
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'انصراف',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Vazirmatn',
                  color: colors.textSecondary,
                ),
              ),
            ),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                fontFamily: 'Vazirmatn',
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(width: 44),
          ],
        ),

        if (widget.enableSearch) ...[
          const SizedBox(height: 12),
          RitmoCard.neumorphicSunken(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            borderRadius: BorderRadius.circular(14),
            child: TextField(
              controller: _searchController,
              style: TextStyle(fontSize: 13, color: colors.textPrimary, fontFamily: 'Vazirmatn'),
              decoration: InputDecoration(
                hintText: 'جست‌وجو...',
                hintStyle: TextStyle(fontSize: 13, color: colors.textSecondary, fontFamily: 'Vazirmatn'),
                prefixIcon: Icon(CupertinoIcons.search, size: 16, color: colors.textSecondary),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],

        const SizedBox(height: 14),

        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _filteredOptions.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final opt = _filteredOptions[index];
              final isSelected = widget.initialValue == opt.value;

              return RitmoCard.neumorphic(
                isSelected: isSelected,
                onTap: () {
                  RitmoHaptics.selection();
                  Navigator.pop(context, opt.value);
                },
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                borderRadius: BorderRadius.circular(14),
                child: Row(
                  children: [
                    if (opt.icon != null) ...[
                      Icon(
                        opt.icon,
                        color: isSelected ? colors.primary : colors.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            opt.label,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                              fontFamily: 'Vazirmatn',
                              color: isSelected ? colors.primary : colors.textPrimary,
                            ),
                          ),
                          if (opt.subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              opt.subtitle!,
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'Vazirmatn',
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        CupertinoIcons.checkmark_alt_circle_fill,
                        color: colors.primary,
                        size: 18,
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
