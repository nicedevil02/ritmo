import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/localization/locale_repository.dart';
import 'package:ritmo/core/settings/settings_registry.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/theme/theme_repository.dart';
import 'package:ritmo/core/utils/persian_text.dart';

class SettingsSearchDelegate extends SearchDelegate<SettingDescriptor?> {
  SettingsSearchDelegate({
    required this.themeRepository,
    required this.localeRepository,
  });

  final ThemeRepository themeRepository;
  final LocaleRepository localeRepository;

  @override
  String? get searchFieldLabel => 'جست‌وجوی تنظیمات...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    return theme.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: colors.card,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: colors.textTertiary, fontSize: 15),
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(CupertinoIcons.clear),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(CupertinoIcons.back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final colors = context.colors;

    final showAdvanced = SettingsService.instance.get<bool>('show_advanced_settings');

    final results = SettingsRegistry.all.where((desc) {
      if (desc.visibility == SettingVisibility.internal) return false;
      if (desc.visibility == SettingVisibility.advanced && !showAdvanced) return false;

      if (query.trim().isEmpty) return true;
      if (searchMatchFa(desc.labelFa, query)) return true;
      if (desc.descriptionFa != null && searchMatchFa(desc.descriptionFa!, query)) return true;
      for (final t in desc.searchTerms) {
        if (searchMatchFa(t, query)) return true;
      }
      return false;
    }).toList();

    if (results.isEmpty) {
      return Center(
        child: Text(
          'موردی برای «$query» یافت نشد.',
          style: TextStyle(color: colors.textSecondary, fontSize: 14),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      separatorBuilder: (context, index) => Divider(color: colors.border),
      itemBuilder: (context, index) {
        final desc = results[index];
        return ListTile(
          title: Text(
            desc.labelFa,
            style: TextStyle(fontWeight: FontWeight.w600, color: colors.textPrimary),
          ),
          subtitle: desc.descriptionFa != null
              ? Text(desc.descriptionFa!, style: TextStyle(fontSize: 12, color: colors.textSecondary))
              : null,
          trailing: Text(
            desc.group.labelFa,
            style: TextStyle(fontSize: 11, color: colors.primary, fontWeight: FontWeight.bold),
          ),
          onTap: () {
            close(context, desc);
          },
        );
      },
    );
  }
}
