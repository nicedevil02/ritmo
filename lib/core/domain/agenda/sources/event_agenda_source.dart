import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:sqflite/sqflite.dart';

/// Read-only Agenda source for temporary events (`temporary_events` table).
///
/// Converts temporary events into normalized [AgendaItem]s tagged with [AgendaDomain.event].
class EventAgendaSource implements AgendaSource {
  const EventAgendaSource({required this.events, this.isEnabled = true});

  factory EventAgendaSource.disabled() =>
      const EventAgendaSource(events: [], isEnabled: false);

  final List<Map<String, dynamic>> events;

  @override
  final bool isEnabled;

  @override
  Set<AgendaDomain> get domains => {AgendaDomain.event};

  /// Loads all temporary event rows matching the date range [startStr]..[endStr].
  static Future<EventAgendaSource> load(
    Database db,
    String startStr,
    String endStr,
  ) async {
    final rows = await db.query(
      'temporary_events',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startStr, endStr],
      orderBy: 'startTime ASC, createdAt ASC',
    );
    return EventAgendaSource(events: rows);
  }

  @override
  List<AgendaItem> itemsForDate(AgendaDayContext ctx) {
    if (!isEnabled) return const [];

    final result = <AgendaItem>[];
    for (final row in events) {
      final date = row['date']?.toString() ?? '';
      if (date != ctx.dateStr) continue;

      final id = row['id']?.toString() ?? '';
      final title = row['title']?.toString() ?? '';
      final startTime = row['startTime']?.toString();
      final endTime = row['endTime']?.toString();
      final duration = row['durationMinutes'] is int
          ? row['durationMinutes'] as int
          : int.tryParse(row['durationMinutes']?.toString() ?? '');
      final isLocked = (row['isLocked'] == 1 || row['isLocked'] == '1');

      final startDt = _parseWindowTime(date, startTime);
      final endDt = _parseWindowTime(date, endTime);

      result.add(
        AgendaItem(
          id: buildAgendaItemId(AgendaDomain.event, id, date),
          domain: AgendaDomain.event,
          kind: AgendaItemKind.event,
          sourceId: id,
          title: title,
          dateStr: date,
          timeOfDay: startTime,
          durationMinutes: duration,
          windowStart: startDt,
          windowEnd: endDt,
          category: Category.custom,
          itemType: isLocked ? AgendaItemType.fixed : AgendaItemType.flexible,
          isEssential: false,
          completion: AgendaCompletion.none,
          // The target used to be an empty string, which made the deep link
          // unroutable: nothing could navigate back to the row this item came
          // from. `sourceId` and the deep-link target are the same thing here.
          deepLink: AgendaDeepLink(domain: AgendaDomain.event, targetId: id),
        ),
      );
    }
    return result;
  }

  static DateTime? _parseWindowTime(String date, String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return null;
    final parts = timeStr.trim().split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    final d = DateTime.tryParse(date);
    if (d == null) return null;
    return DateTime(d.year, d.month, d.day, h, m);
  }
}
