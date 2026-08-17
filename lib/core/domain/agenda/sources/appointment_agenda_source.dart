import 'package:flutter/foundation.dart' hide Category;
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:sqflite/sqflite.dart';

/// Agenda source for health appointments (`doctor_visits`, `vaccinations`, `pregnancy_checkups`).
class AppointmentAgendaSource implements AgendaSource {
  const AppointmentAgendaSource({
    required this.appointmentsByDate,
    this.isEnabled = true,
  });

  factory AppointmentAgendaSource.disabled() =>
      const AppointmentAgendaSource(appointmentsByDate: {}, isEnabled: false);

  final Map<String, List<Map<String, dynamic>>> appointmentsByDate;

  @override
  final bool isEnabled;

  @override
  Set<AgendaDomain> get domains => {AgendaDomain.appointment};

  static Future<AppointmentAgendaSource> load({
    required Database db,
    required DateTime start,
    required DateTime end,
    bool pregnancyEnabled = false,
  }) async {
    final startMs = DateTime(
      start.year,
      start.month,
      start.day,
      0,
      0,
      0,
    ).millisecondsSinceEpoch;
    final endMs = DateTime(
      end.year,
      end.month,
      end.day,
      23,
      59,
      59,
      999,
    ).millisecondsSinceEpoch;
    final appointmentsByDate = <String, List<Map<String, dynamic>>>{};

    // 1. Doctor Visits
    try {
      final visits = await db.rawQuery(
        '''
        SELECT id, doctorName, specialty, clinicName, clinicAddress, visitDateTime,
               visitType, status, reason, doctorNotes, userNotes
        FROM doctor_visits
        WHERE visitDateTime >= ? AND visitDateTime <= ?
        ORDER BY visitDateTime ASC
      ''',
        [startMs, endMs],
      );

      for (final row in visits) {
        final ts = row['visitDateTime'] as int?;
        if (ts != null) {
          final dt = DateTime.fromMillisecondsSinceEpoch(ts);
          final dateStr =
              '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
          final timeStr =
              '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

          appointmentsByDate.putIfAbsent(dateStr, () => []).add({
            'id': row['id'],
            'type': 'doctor_visit',
            'title': _buildDoctorVisitTitle(
              row['doctorName']?.toString(),
              row['specialty']?.toString(),
            ),
            'subtitle':
                row['clinicName']?.toString() ?? row['reason']?.toString(),
            'timeOfDay': timeStr,
            'status': row['status']?.toString() ?? 'UPCOMING',
            'raw': row,
          });
        }
      }
    } catch (e, st) {
      debugPrint('[AppointmentAgendaSource] doctor_visits load error: $e\n$st');
    }

    // 2. Vaccinations
    try {
      final vacs = await db.rawQuery(
        '''
        SELECT id, vaccineName, diseaseTarget, doseNumber, totalDoses,
               dateAdministered, nextDoseDue, clinicName, notes
        FROM vaccinations
        WHERE (nextDoseDue >= ? AND nextDoseDue <= ?)
           OR (dateAdministered >= ? AND dateAdministered <= ?)
        ORDER BY COALESCE(nextDoseDue, dateAdministered) ASC
      ''',
        [startMs, endMs, startMs, endMs],
      );

      for (final row in vacs) {
        final nextDue = row['nextDoseDue'] as int?;
        final administered = row['dateAdministered'] as int?;
        final targetTs = nextDue ?? administered;
        if (targetTs != null) {
          final dt = DateTime.fromMillisecondsSinceEpoch(targetTs);
          final dateStr =
              '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
          final doseNum = row['doseNumber'] as int?;
          final vacName = row['vaccineName']?.toString() ?? 'واکسن';
          final title = doseNum != null && doseNum > 0
              ? 'واکسن $vacName (دوز $doseNum)'
              : 'واکسن $vacName';

          appointmentsByDate.putIfAbsent(dateStr, () => []).add({
            'id': row['id'],
            'type': 'vaccination',
            'title': title,
            'subtitle':
                row['diseaseTarget']?.toString() ??
                row['clinicName']?.toString(),
            'timeOfDay': null,
            'isDone': administered != null,
            'raw': row,
          });
        }
      }
    } catch (e, st) {
      debugPrint('[AppointmentAgendaSource] vaccinations load error: $e\n$st');
    }

    // 3. Pregnancy Checkups (if enabled)
    if (pregnancyEnabled) {
      try {
        final checkups = await db.rawQuery(
          '''
          SELECT id, pregnancyId, title, scheduledDate, actualDate, type, result, isCompleted
          FROM pregnancy_checkups
          WHERE (scheduledDate >= ? AND scheduledDate <= ?)
             OR (actualDate >= ? AND actualDate <= ?)
          ORDER BY COALESCE(scheduledDate, actualDate) ASC
        ''',
          [startMs, endMs, startMs, endMs],
        );

        for (final row in checkups) {
          final sched = row['scheduledDate'] as int?;
          final actual = row['actualDate'] as int?;
          final targetTs = sched ?? actual;
          if (targetTs != null) {
            final dt = DateTime.fromMillisecondsSinceEpoch(targetTs);
            final dateStr =
                '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
            final timeStr =
                '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

            appointmentsByDate.putIfAbsent(dateStr, () => []).add({
              'id': row['id'],
              'type': 'pregnancy_checkup',
              'title': row['title']?.toString() ?? 'چکاپ بارداری',
              'subtitle': row['type']?.toString(),
              'timeOfDay': timeStr != '00:00' ? timeStr : null,
              'isDone': (row['isCompleted'] as int? ?? 0) == 1,
              'raw': row,
            });
          }
        }
      } catch (e, st) {
        debugPrint(
          '[AppointmentAgendaSource] pregnancy_checkups load error: $e\n$st',
        );
      }
    }

    return AppointmentAgendaSource(appointmentsByDate: appointmentsByDate);
  }

  @override
  List<AgendaItem> itemsForDate(AgendaDayContext ctx) {
    if (!isEnabled || !ctx.options.wants(AgendaDomain.appointment)) {
      return const [];
    }

    final rows = appointmentsByDate[ctx.dateStr] ?? const [];
    if (rows.isEmpty) return const [];

    final items = <AgendaItem>[];
    for (final row in rows) {
      final id = row['id']?.toString() ?? '';
      final type = row['type']?.toString() ?? 'appointment';
      final title = row['title']?.toString() ?? 'نوبت سلامت';
      final subtitle = row['subtitle']?.toString();
      final timeOfDay = row['timeOfDay']?.toString();
      final isDone = row['isDone'] == true || row['status'] == 'COMPLETED';
      final isCancelled = row['status'] == 'CANCELLED';

      AgendaCompletion completion = AgendaCompletion.pending;
      if (isDone) {
        completion = AgendaCompletion.done;
      } else if (isCancelled) {
        completion = AgendaCompletion.skipped;
      }

      items.add(
        AgendaItem(
          id: buildAgendaItemId(
            AgendaDomain.appointment,
            '${type}_$id',
            ctx.dateStr,
          ),
          domain: AgendaDomain.appointment,
          sourceId: id,
          title: title,
          subtitle: subtitle,
          dateStr: ctx.dateStr,
          timeOfDay: timeOfDay,
          durationMinutes: 45,
          category: Category.medical,
          priority: 2.0,
          isEssential: true,
          itemType: timeOfDay != null
              ? AgendaItemType.fixed
              : AgendaItemType.flexible,
          completion: completion,
          deepLink: AgendaDeepLink(
            domain: AgendaDomain.appointment,
            targetId: id,
          ),
          meta: {'appointment': row},
        ),
      );
    }

    return items;
  }

  static String _buildDoctorVisitTitle(String? doctorName, String? specialty) {
    final doc = doctorName?.trim() ?? 'پزشک';
    if (specialty != null && specialty.trim().isNotEmpty) {
      return 'ویزیت $doc ($specialty)';
    }
    return 'ویزیت $doc';
  }
}
