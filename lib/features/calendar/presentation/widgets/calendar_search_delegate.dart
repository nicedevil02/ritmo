import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/core/domain/agenda/action_router.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/utils/persian_digits.dart';
import 'package:ritmo/core/utils/persian_text.dart';
import 'package:ritmo/features/calendar/data/calendar_search_repository.dart';
import 'package:ritmo/features/calendar/presentation/utils/domain_palette.dart';

/// K36 + K37 — Global Calendar Search Delegate
/// Grouped into: "امروز", "این هفته", "سایر تاریخ‌ها"
/// Searches across current day items + global database via CalendarSearchRepository.
class CalendarSearchDelegate extends SearchDelegate<AgendaItem?> {
  CalendarSearchDelegate({
    required this.items,
    this.onItemSelected,
  });

  final List<AgendaItem> items;
  final ValueChanged<AgendaItem>? onItemSelected;

  @override
  String get searchFieldLabel => 'جستجوی سراسری رویدادها و کاره…';

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
              child: Text(
                'هیچ نتیجه‌ای یافت نشد.',
                style: TextStyle(),
              ),
            ),
          );
        }

        final todayStr = DateTime.now().toIso8601String().substring(0, 10);
        final todayHits = hits.where((h) => h.dateStr == todayStr).toList();
        final recurringHits = hits.where((h) => h.isRecurring).toList();
        final otherHits = hits.where((h) => !h.isRecurring && h.dateStr != todayStr).toList();

        return Directionality(
          textDirection: TextDirection.rtl,
          child: ListView(
            padding: const EdgeInsets.all(RitmoSpacing.md),
            children: [
              if (todayHits.isNotEmpty) ...[
                _SearchSectionHeader(
                  title: 'امروز (${toPersianDigits(todayHits.length)})',
                ),
                ...todayHits.map((h) => _HitTile(hit: h, onSelected: close)),
                const SizedBox(height: 12),
              ],
              if (recurringHits.isNotEmpty) ...[
                _SearchSectionHeader(
                  title: 'برنامه‌های تکرارشونده (${toPersianDigits(recurringHits.length)})',
                ),
                ...recurringHits.map((h) => _HitTile(hit: h, onSelected: close)),
                const SizedBox(height: 12),
              ],
              if (otherHits.isNotEmpty) ...[
                _SearchSectionHeader(
                  title: 'سایر تاریخ‌ها (${toPersianDigits(otherHits.length)})',
                ),
                ...otherHits.map((h) => _HitTile(hit: h, onSelected: close)),
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
            .where((i) =>
                normalizeFa(i.title).contains(q) ||
                (i.subtitle != null && normalizeFa(i.subtitle!).contains(q)))
            .toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView(
        padding: const EdgeInsets.all(RitmoSpacing.md),
        children: [
          _SearchSectionHeader(
            title: 'برنامه‌های امروز (${toPersianDigits(todayResults.length)})',
          ),
          ...todayResults.map((item) {
            final color = domainColor(context, item.domain);
            final icon = domainIcon(item.domain);
            return ListTile(
              leading: Icon(icon, color: color),
              title: Text(item.title, style: const TextStyle()),
              subtitle: item.subtitle != null
                  ? Text(item.subtitle!, style: const TextStyle())
                  : null,
              onTap: () {
                onItemSelected?.call(item);
                close(context, item);
              },
            );
          }),
        ],
      ),
    );
  }
}

class _SearchSectionHeader extends StatelessWidget {
  const _SearchSectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13.0,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
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

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        hit.title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        hit.isRecurring
            ? 'تکرارشونده${hit.subtitle != null ? ' · ${hit.subtitle}' : ''}'
            : '${hit.dateStr != null ? toPersianDigits(hit.dateStr) : 'بدون تاریخ'}${hit.subtitle != null ? ' · ${hit.subtitle}' : ''}',
        style: const TextStyle(fontSize: 12),
      ),
      onTap: () {
        // Construct target item for router
        final item = AgendaItem(
          id: hit.id,
          domain: hit.domain,
          sourceId: hit.sourceId,
          title: hit.title,
          dateStr: hit.dateStr ?? DateTime.now().toIso8601String().substring(0, 10),
          category: Category.personal,
          deepLink: AgendaDeepLink(domain: hit.domain, targetId: hit.sourceId),
        );
        ActionRouter.open(context, item: item);
        onSelected(context, item);
      },
    );
  }
}
