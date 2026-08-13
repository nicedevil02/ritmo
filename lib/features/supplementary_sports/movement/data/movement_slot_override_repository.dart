// lib/features/supplementary_sports/movement/data/movement_slot_override_repository.dart

import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/utils/ritmo_id_factory.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_slot_override.dart';
import 'package:sqflite/sqflite.dart';

class MovementSlotOverrideRepository {
  MovementSlotOverrideRepository._();
  static final MovementSlotOverrideRepository instance = MovementSlotOverrideRepository._();

  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<List<MovementSlotOverride>> forDateRange(String startIso, String endIso) async {
    final db = await _db;
    final rows = await db.query(
      'movement_slot_overrides',
      where: '(dateIso >= ? AND dateIso <= ?) OR (newDateIso >= ? AND newDateIso <= ?)',
      whereArgs: <Object>[startIso, endIso, startIso, endIso],
      orderBy: 'createdAt ASC',
    );
    return rows.map(MovementSlotOverride.fromMap).toList();
  }

  Future<void> upsert(MovementSlotOverride override) async {
    final db = await _db;
    await db.delete(
      'movement_slot_overrides',
      where: 'routineId = ? AND dateIso = ?',
      whereArgs: <Object>[override.routineId, override.dateIso],
    );
    await db.insert('movement_slot_overrides', override.toMap());
  }

  Future<void> skip({
    required String routineId,
    required String dateIso,
  }) {
    return upsert(
      MovementSlotOverride(
        id: RitmoIdFactory.movementSlotOverride(),
        routineId: routineId,
        dateIso: dateIso,
        action: MovementSlotAction.skip,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> move({
    required String routineId,
    required String dateIso,
    required String newDateIso,
    String? newTime,
  }) {
    return upsert(
      MovementSlotOverride(
        id: RitmoIdFactory.movementSlotOverride(),
        routineId: routineId,
        dateIso: dateIso,
        action: MovementSlotAction.move,
        newDateIso: newDateIso,
        newTime: newTime,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> retime({
    required String routineId,
    required String dateIso,
    required String newTime,
  }) {
    return upsert(
      MovementSlotOverride(
        id: RitmoIdFactory.movementSlotOverride(),
        routineId: routineId,
        dateIso: dateIso,
        action: MovementSlotAction.retime,
        newTime: newTime,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> light({
    required String routineId,
    required String dateIso,
  }) {
    return upsert(
      MovementSlotOverride(
        id: RitmoIdFactory.movementSlotOverride(),
        routineId: routineId,
        dateIso: dateIso,
        action: MovementSlotAction.light,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}
