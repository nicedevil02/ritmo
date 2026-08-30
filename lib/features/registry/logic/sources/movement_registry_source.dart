import 'package:sqflite/sqflite.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/features/registry/domain/registry_entry.dart';
import 'package:ritmo/features/registry/logic/sources/registry_source.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/mv_kind_repository.dart';

class MovementRegistrySource implements RegistrySource {
  @override
  RegistryDomain get domain => RegistryDomain.movementKind;

  @override
  String get moduleSettingsKey => 'module_supplementary_sports_enabled';

  @override
  Future<int> count({bool includeArchived = false}) async {
    final db = await DatabaseHelper.instance.database;
    final res = await db.rawQuery('SELECT COUNT(*) as cnt FROM movement_kinds WHERE isCustom = 1');
    return Sqflite.firstIntValue(res) ?? 0;
  }

  @override
  Future<List<RegistryEntry>> fetch({
    required int limit,
    required int offset,
    bool includeArchived = false,
  }) async {
    final kinds = await MvKindRepository().getAll();
    final customKinds = kinds.where((k) => k.isCustom).toList();
    final todayStr = DateTime.now().toIso8601String().split('T').first;

    final sliced = customKinds.skip(offset).take(limit).toList();

    return sliced.map((k) {
      const caps = RegistryCapabilities();

      return RegistryEntry(
        id: 'movementKind:${k.code}',
        domain: RegistryDomain.movementKind,
        sourceId: k.code,
        title: k.titleFa,
        subtitle: '${k.family.titleFa} · ${k.primaryMetric.unitFa}',
        scheduleSummary: k.isCustom ? 'حرکت سفارشی' : 'حرکت پیش‌فرض',
        status: RegistryStatus.active,
        caps: caps,
        agendaProxy: AgendaItem(
          id: 'sport:${k.code}',
          domain: AgendaDomain.sport,
          sourceId: k.code,
          title: k.titleFa,
          dateStr: todayStr,
          category: Category.fitness,
          deepLink: AgendaDeepLink(
            domain: AgendaDomain.sport,
            targetId: k.code,
          ),
        ),
      );
    }).toList();
  }
}
