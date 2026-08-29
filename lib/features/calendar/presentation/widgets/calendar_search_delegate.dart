import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/domain/agenda/action_router.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/utils/date_key.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/persian_text.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_card.dart';
import 'package:ritmo/core/widgets/ritmo/ritmo_empty_state.dart';
import 'package:ritmo/features/calendar/data/calendar_search_repository.dart';
import 'package:ritmo/features/calendar/presentation/utils/domain_palette.dart';

/// K36 + K37 — Global Calendar Search Delegate
/// Grouped into: "امروز", "این هفته", "سایر تاریخ‌ها"
/// Upgraded to Ritmo Neumorphic Soft UI 2.0 with 3D sunken wells and 5-domain glowing palette.
class CalendarSearchDelegate extends SearchDelegate<AgendaItem?> {
  CalendarSearchDelegate({required this.items, this.onItemSelected});

  final List<AgendaItem> items;
  final ValueChanged<AgendaItem>? onItemSelected;

  @override
  String get searchFieldLabel => 'جستجوی سراسری رویدادها و کارها…';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;

    return theme.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(
          fontFamily: 'Vazirmatn',
          fontSize: 14.0,
          color: colors.textTertiary,
        ),
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear_rounded),
          onPressed: () {
            query = '';
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildAsyncSearchList(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildAsyncSearchList(context);
  }

  Widget _buildAsyncSearchList(BuildContext context) {
    final q = normalizeFa(query.trim());

    if (q.isEmpty) {
      return _buildTodayList(context, q);
    }

    return FutureBuilder<List<CalendarSearchHit>>(
      future: CalendarSearchRepository.instance.search(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        final hits = snapshot.data ?? [];
        if (hits.isEmpty) {
          return const Directionality(
            textDirection: TextDirection.rtl,
            child: Center(
              child: RitmoEmptyState(
                icon: CupertinoIcons.search,
                title: 'نتیجه‌ای یافت نشد',
                description: 'هیچ برنامه یا رویدادی مطابق با عبارت جستجو پیدا نشد.',
              ),
            ),
          );
        }

        final todayStr = DateKey.today();
        final todayHits = hits.where((h) => h.dateStr == todayStr).toList();
        final recurringHits = hits.where((h) => h.isRecurring).toList();
        final otherHits = hits
            .where((h) => !h.isRecurring && h.dateStr != todayStr)
            .toList();

        return Directionality(
          textDirection: TextDirection.rtl,
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: RitmoSpacing.md,
              vertical: RitmoSpacing.sm,
            ),
            children: [
              if (todayHits.isNotEmpty) ...[
                _SearchGroupCard(
                  title: 'امروز',
                  badgeCount: todayHits.length,
                  children: todayHits
                      .map((h) => _HitTile(hit: h, onSelected: close))
                      .toList(),
                ),
                const SizedBox(height: 12),
              ],
              if (recurringHits.isNotEmpty) ...[
                _SearchGroupCard(
                  title: 'برنامه‌های تکرارشونده',
                  badgeCount: recurringHits.length,
                  children: recurringHits
                      .map((h) => _HitTile(hit: h, onSelected: close))
                      .toList(),
                ),
                const SizedBox(height: 12),
              ],
              if (otherHits.isNotEmpty) ...[
                _SearchGroupCard(
                  title: 'سایر تاریخ‌ها',
                  badgeCount: otherHits.length,
                  children: otherHits
                      .map((h) => _HitTile(hit: h, onSelected: close))
                      .toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildTodayList(BuildContext context, String q) {
    final todayResults = q.isEmpty
        ? items
        : items
              .where(
                (i) =>
                    normalizeFa(i.title).contains(q) ||
                    (i.subtitle != null &&
                        normalizeFa(i.subtitle!).contains(q)),
              )
              .toList();

    if (todayResults.isEmpty) {
      return const Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: RitmoEmptyState(
            icon: CupertinoIcons.search,
            title: 'برنامه‌ای برای امروز یافت نشد',
            description: 'هیچ رویداد یا کاری برای این روز ثبت نشده است.',
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: RitmoSpacing.md,
          vertical: RitmoSpacing.sm,
        ),
        children: [
          _SearchGroupCard(
            title: 'برنامه‌های امروز',
            badgeCount: todayResults.length,
            children: todayResults.map((item) {
              final color = itemColor(context, item);
              final icon = itemIcon(item);

              return _SearchItemTile(
                title: item.title,
                subtitle: item.subtitle,
                timeOfDay: item.timeOfDay,
                color: color,
                icon: icon,
                onTap: () {
                  RitmoHapticsPolicy.tap();
                  onItemSelected?.call(item);
                  close(context, item);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _SearchGroupCard extends StatelessWidget {
  const _SearchGroupCard({
    required this.title,
    required this.badgeCount,
    required this.children,
  });

  final String title;
  final int badgeCount;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RitmoCard.neumorphic(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enableSpring: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row with title & count badge
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Vazirmatn',
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: isDark ? 0.20 : 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: isDark ? 0.35 : 0.22),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  toPersianDigits('$badgeCount'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Vazirmatn',
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const RitmoCardDivider(margin: EdgeInsets.symmetric(vertical: 4)),
          // Items list
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: children.length,
            separatorBuilder: (_, _) =>
                const RitmoCardDivider(margin: EdgeInsets.symmetric(vertical: 2)),
            itemBuilder: (_, index) => children[index],
          ),
        ],
      ),
    );
  }
}

class _SearchItemTile extends StatelessWidget {
  const _SearchItemTile({
    required this.title,
    this.subtitle,
    this.timeOfDay,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final String? timeOfDay;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sub = subtitle;
    final tod = timeOfDay;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
        child: Row(
          children: [
            // 3D Sunken Icon Well
            RitmoNeuSurface(
              height: 38,
              width: 38,
              radius: 19,
              sunken: true,
              padding: EdgeInsets.zero,
              glowColor: color.withValues(alpha: 0.38),
              child: Center(
                child: Icon(icon, size: 18, color: color),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    toPersianDigits(title),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Vazirmatn',
                      color: colors.textPrimary,
                    ),
                  ),
                  if (sub != null && sub.isNotEmpty)
                    Text(
                      toPersianDigits(sub),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.0,
                        fontFamily: 'Vazirmatn',
                        color: colors.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
            if (tod != null && tod.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(
                    alpha: isDark ? 0.08 : 0.05,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                    width: 0.7,
                  ),
                ),
                child: Text(
                  toPersianDigits(tod),
                  style: TextStyle(
                    fontSize: 11.0,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Vazirmatn',
                    color: colors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HitTile extends StatelessWidget {
  const _HitTile({required this.hit, required this.onSelected});
  final CalendarSearchHit hit;
  final void Function(BuildContext, AgendaItem?) onSelected;

  @override
  Widget build(BuildContext context) {
    final color = domainColor(context, hit.domain);
    final icon = domainIcon(hit.domain);

    final trailingBadge = hit.isRecurring ? 'تکرارشونده' : hit.dateStr;

    return _SearchItemTile(
      title: hit.title,
      subtitle: hit.subtitle,
      timeOfDay: trailingBadge,
      color: color,
      icon: icon,
      onTap: () {
        RitmoHapticsPolicy.tap();
        final item = AgendaItem(
          id: hit.id,
          domain: hit.domain,
          sourceId: hit.sourceId,
          title: hit.title,
          dateStr: hit.dateStr ?? DateKey.today(),
          category: Category.personal,
          deepLink: AgendaDeepLink(domain: hit.domain, targetId: hit.sourceId),
        );
        ActionRouter.open(context, item: item);
        onSelected(context, item);
      },
    );
  }
}
