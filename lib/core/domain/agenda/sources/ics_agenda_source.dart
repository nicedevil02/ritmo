import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/domain/models/duration_bounds.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/features/calendar/presentation/utils/calendar_defaults.dart';
import 'package:sqflite/sqflite.dart';

class IcsEvent {
  const IcsEvent({
    required this.uid,
    required this.summary,
    required this.dateStr,
    this.startTime,
    this.endTime,
    required this.durationMinutes,
    this.description,
    this.location,
    this.hasRRule = false,
  });

  final String uid;
  final String summary;
  final String dateStr;
  final String? startTime;
  final String? endTime;
  final int durationMinutes;
  final String? description;
  final String? location;
  final bool hasRRule;
}

class IcsParser {
  const IcsParser._();

  /// Parses an RFC 5545 iCalendar content string into a list of [IcsEvent]s.
  /// Ignores recurring rule (RRULE) expansions per CAL-52 spec.
  static List<IcsEvent> parse(String icsContent) {
    final events = <IcsEvent>[];
    final lines = icsContent.split(RegExp(r'\r?\n'));

    bool insideVEvent = false;
    String? uid;
    String? summary;
    String? dtStartRaw;
    String? dtEndRaw;
    String? description;
    String? location;
    bool hasRRule = false;

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      if (line == 'BEGIN:VEVENT') {
        insideVEvent = true;
        uid = null;
        summary = null;
        dtStartRaw = null;
        dtEndRaw = null;
        description = null;
        location = null;
        hasRRule = false;
        continue;
      }

      if (line == 'END:VEVENT') {
        if (insideVEvent && (summary != null || uid != null)) {
          final parsed = _createEvent(
            uid: uid ?? DateTime.now().millisecondsSinceEpoch.toString(),
            summary: summary ?? 'بدون عنوان',
            dtStartRaw: dtStartRaw,
            dtEndRaw: dtEndRaw,
            description: description,
            location: location,
            hasRRule: hasRRule,
          );
          if (parsed != null) {
            events.add(parsed);
          }
        }
        insideVEvent = false;
        continue;
      }

      if (!insideVEvent) continue;

      if (line.startsWith('UID:')) {
        uid = line.substring(4).trim();
      } else if (line.startsWith('SUMMARY:')) {
        summary = _unescapeIcs(line.substring(8).trim());
      } else if (line.startsWith('DTSTART')) {
        dtStartRaw = line.substring(line.indexOf(':') + 1).trim();
      } else if (line.startsWith('DTEND')) {
        dtEndRaw = line.substring(line.indexOf(':') + 1).trim();
      } else if (line.startsWith('DESCRIPTION:')) {
        description = _unescapeIcs(line.substring(12).trim());
      } else if (line.startsWith('LOCATION:')) {
        location = _unescapeIcs(line.substring(9).trim());
      } else if (line.startsWith('RRULE:')) {
        hasRRule = true;
      }
    }

    return events;
  }

  /// Converts parsed ICS events into normalized read-only [AgendaItem]s.
  static List<AgendaItem> parseToAgendaItems(String icsContent) {
    final parsedEvents = parse(icsContent);
    return parsedEvents.map((e) {
      return AgendaItem(
        id: 'ics_${e.uid}_${e.dateStr}',
        sourceId: e.uid,
        title: e.summary,
        domain: AgendaDomain.event,
        kind: AgendaItemKind.event,
        category: Category.personal,
        timeOfDay: e.startTime,
        durationMinutes: e.durationMinutes,
        dateStr: e.dateStr,
        deepLink: AgendaDeepLink(domain: AgendaDomain.event, targetId: e.uid),
      );
    }).toList();
  }

  static IcsEvent? _createEvent({
    required String uid,
    required String summary,
    required String? dtStartRaw,
    required String? dtEndRaw,
    String? description,
    String? location,
    required bool hasRRule,
  }) {
    if (dtStartRaw == null || dtStartRaw.isEmpty) return null;

    final startParsed = _parseIcsDateTime(dtStartRaw);
    if (startParsed == null) return null;

    final dateStr = '${startParsed.date.year}-${startParsed.date.month.toString().padLeft(2, '0')}-${startParsed.date.day.toString().padLeft(2, '0')}';
    final startTime = startParsed.hasTime
        ? '${startParsed.date.hour.toString().padLeft(2, '0')}:${startParsed.date.minute.toString().padLeft(2, '0')}'
        : null;

    int duration = CalendarDefaults.fallbackDurationMinutes;
    String? endTime;

    if (dtEndRaw != null && dtEndRaw.isNotEmpty) {
      final endParsed = _parseIcsDateTime(dtEndRaw);
      if (endParsed != null) {
        if (endParsed.hasTime) {
          endTime = '${endParsed.date.hour.toString().padLeft(2, '0')}:${endParsed.date.minute.toString().padLeft(2, '0')}';
        }
        final diffMins = endParsed.date.difference(startParsed.date).inMinutes;
        if (diffMins > 0) {
          duration = DurationBounds.sanitize(diffMins);
        }
      }
    }

    return IcsEvent(
      uid: uid,
      summary: summary,
      dateStr: dateStr,
      startTime: startTime,
      endTime: endTime,
      durationMinutes: duration,
      description: description,
      location: location,
      hasRRule: hasRRule,
    );
  }

  static _ParsedIcsDate? _parseIcsDateTime(String raw) {
    try {
      // Formats: 20260818T093000Z, 20260818T093000, 20260818
      final clean = raw.replaceAll('Z', '');
      if (clean.contains('T')) {
        final parts = clean.split('T');
        final dStr = parts[0];
        final tStr = parts[1];

        final y = int.parse(dStr.substring(0, 4));
        final m = int.parse(dStr.substring(4, 6));
        final d = int.parse(dStr.substring(6, 8));

        final hh = int.parse(tStr.substring(0, 2));
        final mm = int.parse(tStr.substring(2, 4));
        final ss = tStr.length >= 6 ? int.parse(tStr.substring(4, 6)) : 0;

        return _ParsedIcsDate(
          date: DateTime(y, m, d, hh, mm, ss),
          hasTime: true,
        );
      } else if (clean.length >= 8) {
        final y = int.parse(clean.substring(0, 4));
        final m = int.parse(clean.substring(4, 6));
        final d = int.parse(clean.substring(6, 8));

        return _ParsedIcsDate(
          date: DateTime(y, m, d),
          hasTime: false,
        );
      }
      return null;
    } catch (e, st) {
      RitmoLog.warning('IcsParser', 'Invalid datetime format: $raw', e, st);
      return null;
    }
  }

  static String _unescapeIcs(String text) {
    return text
        .replaceAll(r'\,', ',')
        .replaceAll(r'\;', ';')
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\N', '\n')
        .replaceAll(r'\\', r'\');
  }
}

class _ParsedIcsDate {
  const _ParsedIcsDate({required this.date, required this.hasTime});
  final DateTime date;
  final bool hasTime;
}

class IcsExporter {
  const IcsExporter._();

  /// Serializes a list of [AgendaItem]s to standard RFC 5545 iCalendar string.
  static String exportToIcs(
    List<AgendaItem> items, {
    String calName = 'Ritmo Calendar',
  }) {
    final buffer = StringBuffer();
    buffer.writeln('BEGIN:VCALENDAR');
    buffer.writeln('VERSION:2.0');
    buffer.writeln('PRODID:-//Ritmo//Calendar Export//FA');
    buffer.writeln('CALSCALE:GREGORIAN');
    buffer.writeln('X-WR-CALNAME:$calName');

    final nowUtc = DateTime.now().toUtc();
    final nowStamp = _formatIcsDateTime(nowUtc);

    for (final item in items) {
      final date = DateTime.tryParse(item.dateStr);
      if (date == null) continue;

      int startHour = 9;
      int startMin = 0;
      if (item.timeOfDay != null && item.timeOfDay!.contains(':')) {
        final parts = item.timeOfDay!.split(':');
        startHour = int.tryParse(parts[0]) ?? 9;
        startMin = int.tryParse(parts[1]) ?? 0;
      }

      final startDt = DateTime(date.year, date.month, date.day, startHour, startMin);
      final dur = item.durationMinutes ?? CalendarDefaults.fallbackDurationMinutes;
      final endDt = startDt.add(Duration(minutes: dur));

      buffer.writeln('BEGIN:VEVENT');
      buffer.writeln('UID:${item.id}@ritmo');
      buffer.writeln('DTSTAMP:$nowStamp');
      if (item.isTimed) {
        buffer.writeln('DTSTART:${_formatIcsDateTime(startDt)}');
        buffer.writeln('DTEND:${_formatIcsDateTime(endDt)}');
      } else {
        buffer.writeln('DTSTART;VALUE=DATE:${_formatIcsDate(date)}');
      }
      buffer.writeln('SUMMARY:${_escapeIcs(item.title)}');
      buffer.writeln('DESCRIPTION:${_escapeIcs('دسته: ${item.category.name} | حوزه: ${item.domain.name}')}');
      buffer.writeln('STATUS:CONFIRMED');
      buffer.writeln('END:VEVENT');
    }

    buffer.writeln('END:VCALENDAR');
    return buffer.toString();
  }

  static String _formatIcsDateTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return '$y$m${d}T$hh$mm$ss';
  }

  static String _formatIcsDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  static String _escapeIcs(String text) {
    return text
        .replaceAll(r'\', r'\\')
        .replaceAll(';', r'\;')
        .replaceAll(',', r'\,')
        .replaceAll('\n', r'\n');
  }
}

/// Read-only Agenda Source for ICS imported calendar events.
class IcsAgendaSource implements AgendaSource {
  const IcsAgendaSource({
    required this.events,
    this.isEnabled = true,
  });

  factory IcsAgendaSource.disabled() =>
      const IcsAgendaSource(events: [], isEnabled: false);

  final List<AgendaItem> events;

  @override
  final bool isEnabled;

  @override
  Set<AgendaDomain> get domains => {AgendaDomain.event};

  /// Loads imported ICS events from database or memory.
  static Future<IcsAgendaSource> load({
    Database? db,
    String? startStr,
    String? endStr,
    bool isEnabled = true,
  }) async {
    if (!isEnabled) return IcsAgendaSource.disabled();

    try {
      if (db != null && startStr != null && endStr != null) {
        // Ensure table exists
        await db.execute('''
          CREATE TABLE IF NOT EXISTS ics_events (
              id TEXT PRIMARY KEY,
              uid TEXT NOT NULL,
              title TEXT NOT NULL,
              date TEXT NOT NULL,
              startTime TEXT,
              endTime TEXT,
              durationMinutes INTEGER NOT NULL,
              description TEXT,
              location TEXT,
              createdAt INTEGER NOT NULL
          );
        ''');

        final rows = await db.query(
          'ics_events',
          where: 'date >= ? AND date <= ?',
          whereArgs: [startStr, endStr],
          orderBy: 'startTime ASC',
        );

        final items = rows.map((r) {
          final uid = r['uid']?.toString() ?? r['id']?.toString() ?? '';
          final date = r['date']?.toString() ?? '';
          return AgendaItem(
            id: 'ics_${uid}_$date',
            sourceId: uid,
            title: r['title']?.toString() ?? '',
            domain: AgendaDomain.event,
            kind: AgendaItemKind.event,
            category: Category.personal,
            timeOfDay: r['startTime']?.toString(),
            durationMinutes: r['durationMinutes'] is int
                ? r['durationMinutes'] as int
                : int.tryParse(r['durationMinutes']?.toString() ?? '') ?? CalendarDefaults.fallbackDurationMinutes,
            dateStr: date,
            deepLink: AgendaDeepLink(domain: AgendaDomain.event, targetId: uid),
          );
        }).toList();

        return IcsAgendaSource(events: items, isEnabled: true);
      }
    } catch (e, st) {
      RitmoLog.error('IcsAgendaSource', 'Failed to load ICS events', e, st);
    }

    return const IcsAgendaSource(events: [], isEnabled: true);
  }

  @override
  List<AgendaItem> itemsForDate(AgendaDayContext ctx) {
    if (!isEnabled) return const [];
    return events.where((i) => i.dateStr == ctx.dateStr).toList();
  }
}
