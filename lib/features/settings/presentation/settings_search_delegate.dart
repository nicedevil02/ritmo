import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/localization/locale_repository.dart';
import 'package:ritmo/core/settings/settings_registry.dart';
import 'package:ritmo/core/settings/settings_service.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/theme/theme_repository.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/persian_text.dart';

class SettingsSearchDelegate extends SearchDelegate<SettingDescriptor?> {
  SettingsSearchDelegate({
    required this.themeRepository,
    required this.localeRepository,
  });

  final ThemeRepository themeRepository;
  final LocaleRepository localeRepository;

  static const List<String> _suggestedKeys = [
    'app_theme',
    'notif_master_enabled',
    'daily_planning_nudge_enabled',
    'app_lock_enabled',
    'auto_backup_enabled',
    'calendar_show_hijri',
  ];

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
  Widget buildResults(BuildContext context) => _buildSearchResults(context);

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.trim().isEmpty) {
      return _buildEmptyStateSuggestions(context);
    }
    return _buildSearchResults(context);
  }

  Widget _buildEmptyStateSuggestions(BuildContext context) {
    final colors = context.colors;
    final suggestedDescriptors = _suggestedKeys
        .map((k) => SettingsRegistry.find(k))
        .whereType<SettingDescriptor>()
        .toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 4, bottom: 12),
          child: Text(
            'تنظیمات پرکاربرد و پیشنهادی',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: colors.primary,
            ),
          ),
        ),
        Material(
          color: colors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: colors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (int i = 0; i < suggestedDescriptors.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: colors.border.withValues(alpha: 0.6),
                    indent: 16,
                    endIndent: 16,
                  ),
                _buildTile(context, suggestedDescriptors[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults(BuildContext context) {
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
      separatorBuilder: (context, index) => Divider(color: colors.border.withValues(alpha: 0.6)),
      itemBuilder: (context, index) => _buildTile(context, results[index]),
    );
  }

  Widget _buildTile(BuildContext context, SettingDescriptor desc) {
    final colors = context.colors;
    final formattedValue = _formatCurrentValue(desc);

    return ListTile(
      title: Text(
        desc.labelFa,
        style: TextStyle(fontWeight: FontWeight.w600, color: colors.textPrimary),
      ),
      subtitle: desc.descriptionFa != null
          ? Text(
              desc.descriptionFa!,
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.border.withValues(alpha: 0.5)),
            ),
            child: Text(
              formattedValue,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            desc.group.labelFa,
            style: TextStyle(
              fontSize: 11,
              color: colors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      onTap: () {
        close(context, desc);
      },
    );
  }

  String _formatCurrentValue(SettingDescriptor desc) {
    if (desc.scope == SettingScope.secure) {
      final val = SettingsService.instance.get<String>(desc.key);
      return val.isEmpty ? 'تنظیم نشده' : '••••';
    }

    switch (desc.type) {
      case SettingType.boolean:
        final val = SettingsService.instance.get<bool>(desc.key);
        return val ? 'روشن' : 'خاموش';
      case SettingType.time:
        final val = SettingsService.instance.get<String>(desc.key);
        return toPersianDigits(val);
      case SettingType.integer:
        final val = SettingsService.instance.get<int>(desc.key);
        final unit = desc.unitFa != null ? ' ${desc.unitFa}' : '';
        return '${toPersianDigits(val)}$unit';
      case SettingType.enumeration:
        final val = SettingsService.instance.get<String>(desc.key);
        return desc.optionLabelsFa?[val] ?? val;
      case SettingType.text:
        final val = SettingsService.instance.get<String>(desc.key);
        return val.isEmpty ? 'تنظیم نشده' : val;
    }
  }
}
