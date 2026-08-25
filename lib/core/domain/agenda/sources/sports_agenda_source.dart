import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/sources/agenda_source.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/modules/module_gate.dart';
import 'package:sqflite/sqflite.dart';

/// AgendaSource for the unified Sports & Movement domain.
class SportsAgendaSource implements AgendaSource {
  SportsAgendaSource({
    required this.prescriptionsByDate,
    required this.sportsEnabled,
    required this.db,
  });

  final Map<String, Map<String, dynamic>> prescriptionsByDate;
  final bool sportsEnabled;
  final Database db;

  @override
  Set<AgendaDomain> get domains => {AgendaDomain.sport};

  @override
  bool get isEnabled => sportsEnabled;

  /// Returns an empty, disabled source (fallback when module is off or load fails).
  static SportsAgendaSource disabled(Database db) => SportsAgendaSource(
    prescriptionsByDate: const {},
    sportsEnabled: false,
    db: db,
  );

  static Future<SportsAgendaSource> load(
    Database db,
    Map<String, String> settingsMap,
  ) async {
    final sportsEnabled =
        ModuleGate.instance.isEnabledFrom(
          settingsMap,
          'module_sports_enabled',
        ) ||
        ModuleGate.instance.isEnabledFrom(
          settingsMap,
          'module_supplementary_sports_enabled',
        );

    if (!sportsEnabled) {
      return SportsAgendaSource(
        prescriptionsByDate: const {},
        sportsEnabled: false,
        db: db,
      );
    }

    final prescriptionsByDate = <String, Map<String, dynamic>>{};

    try {
      final rows = await db.query('ss_session_prescription');
      for (final row in rows) {
        final dateIso = row['dateIso']?.toString();
        if (dateIso != null && dateIso.isNotEmpty) {
          prescriptionsByDate[dateIso] = Map<String, dynamic>.from(row);
        }
      }
    } catch (e, st) {
      RitmoLog.error('SportsAgendaSource', 'prescription load failed', e, st);
    }

    return SportsAgendaSource(
      prescriptionsByDate: prescriptionsByDate,
      sportsEnabled: sportsEnabled,
      db: db,
    );
  }

  @override
  List<AgendaItem> itemsForDate(AgendaDayContext ctx) {
    if (!ctx.options.wants(AgendaDomain.sport)) return const [];
    if (!sportsEnabled) return const [];

    final dateStr = ctx.dateStr;
    final prescription = prescriptionsByDate[dateStr];
    if (prescription != null) {
      return _itemsForPrescription(prescription, dateStr);
    }

    return const [];
  }

  List<AgendaItem> _itemsForPrescription(
    Map<String, dynamic> prescription,
    String dateStr,
  ) {
    final slotType =
        prescription['slotType']?.toString().toUpperCase() ?? 'REST';
    if (slotType == 'REST') return const [];

    final id = prescription['id']?.toString() ?? 'ss_prescription_$dateStr';
    final title =
        prescription['headlineFa']?.toString().trim().isNotEmpty == true
        ? prescription['headlineFa'].toString()
        : 'تمرین ورزشی';
    final duration = prescription['targetMinutes'] as int? ?? 45;
    final status =
        prescription['status']?.toString().toUpperCase() ?? 'PLANNED';

    return [
      AgendaItem(
        id: buildAgendaItemId(AgendaDomain.sport, id, dateStr),
        sourceId: id,
        domain: AgendaDomain.sport,
        itemType: AgendaItemType.flexible,
        title: title,
        subtitle: prescription['coachNoteFa'] as String?,
        dateStr: dateStr,
        durationMinutes: duration,
        category: Category.fitness,
        deepLink: AgendaDeepLink(domain: AgendaDomain.sport, targetId: id),
        completion: _completionFor(status),
        meta: {'prescription': prescription},
      ),
    ];
  }



  AgendaCompletion _completionFor(String status) {
    return switch (status) {
      'DONE' => AgendaCompletion.done,
      'PARTIAL' => AgendaCompletion.partial,
      'SKIPPED' => AgendaCompletion.skipped,
      'MOVED' => AgendaCompletion.none,
      _ => AgendaCompletion.pending,
    };
  }
}
