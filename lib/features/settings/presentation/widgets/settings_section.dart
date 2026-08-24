import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/settings/presentation/widgets/setting_field_builder.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
    this.footer,
  });

  factory SettingsSection.fromKeys({
    Key? key,
    required String title,
    required List<String> keys,
    String? footer,
    String? highlightKey,
  }) {
    return SettingsSection(
      key: key,
      title: title,
      footer: footer,
      children: keys
          .map((k) => SettingField(k, highlight: k == highlightKey))
          .toList(growable: false),
    );
  }

  final String title;
  final List<Widget> children;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: colors.primary,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(18),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (int i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 0.7,
                      color: colors.divider.withValues(alpha: 0.5),
                      indent: 16,
                      endIndent: 16,
                    ),
                  children[i],
                ],
              ],
            ),
          ),
          if (footer != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                footer!,
                style: TextStyle(
                  fontSize: 11.5,
                  color: colors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
