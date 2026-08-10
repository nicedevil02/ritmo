import 'dart:convert';

import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/features/supplementary_sports/data/repositories/ss_prescription_repository.dart';
import 'package:ritmo/features/supplementary_sports/domain/prescription/session_prescription.dart';
import 'package:ritmo/features/supplementary_sports/movement/data/movement_repository.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_event.dart';
import 'package:ritmo/features/supplementary_sports/movement/domain/movement_kind.dart';
import 'package:sqflite/sqflite.dart';

class SsSessionCompletionGateway {
  static const String sourceModule = 'ss_prescription';

  /// Completes a prescription session atomically and idempotently.
  static Future<String?> completeSession({
    required String dateIso,
    int? actualMinutes,
    int? actualRpe,
    String? location,
    String? customNote,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final repo = SsPrescriptionRepository.instance;
    final prescription = await repo.getPrescriptionForDate(dateIso);
    if (prescription == null) return null;

    _validateCompletion(prescription, actualMinutes, actualRpe);

    String? completedLogId;
    await db.transaction((txn) async {
      completedLogId = await completeDetailedSessionInTransaction(
        txn,
        prescriptionId: prescription.id,
        actualMinutes: actualMinutes,
        actualRpe: actualRpe,
        location: location,
        customNote: customNote,
      );
    });

    if (completedLogId != null) {
      RitmoEventBus().fire(RitmoEvent(
        type: RitmoEventType.workoutLogChanged.code,
        timestamp: DateTime.now(),
        payload: {
          'source': sourceModule,
          'id': completedLogId,
          'prescriptionId': prescription.id,
        },
      ));
    }
    return completedLogId;
  }

  /// Transaction-aware variant. Never fires events here; caller fires after commit.
  static Future<String?> completeDetailedSessionInTransaction(
    DatabaseExecutor txn, {
    required String? prescriptionId,
    String? sessionId,
    int? actualMinutes,
    int? actualRpe,
    String? location,
    String? customNote,
  }) async {
    if (prescriptionId == null || prescriptionId.isEmpty) return null;

    final rows = await txn.query(
      'ss_session_prescription',
      where: 'id = ?',
      whereArgs: [prescriptionId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('SS_PRESCRIPTION_NOT_FOUND: $prescriptionId');
    }

    final prescription = SessionPrescription.fromMap(rows.first);
    _validateCompletion(prescription, actualMinutes, actualRpe);

    if (prescription.status == PrescriptionStatus.done &&
        prescription.workoutLogId != null &&
        prescription.workoutLogId!.isNotEmpty) {
      return prescription.workoutLogId;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final logId = prescription.workoutLogId?.trim().isNotEmpty == true
        ? prescription.workoutLogId!
        : 'wlog_ss_${prescription.id}';

    final intensity = _intensityFromRpe(actualRpe);
    final event = MovementEvent(
      id: logId,
      kindCode: _kindForSlot(prescription.slotType),
      durationMinutes: actualMinutes ?? prescription.targetMinutes,
      intensity: intensity,
      loggedAt: nowMs,
      location: location,
      sourceModule: sourceModule,
      sourceEntityId: prescription.id,
      note: customNote ?? prescription.headlineFa,
      metricsJson: jsonEncode({
        'prescriptionId': prescription.id,
        'sessionId': sessionId,
        'slotType': prescription.slotType.code,
        'targetRpe': prescription.targetRpe,
        'actualRpe': actualRpe,
        'cycleWeek': prescription.cycleWeek,
      }),
    );

    await MovementRepository.instance.upsertEventInTransaction(txn, event);

    final updated = prescription.copyWith(
      status: PrescriptionStatus.done,
      workoutLogId: logId,
      actualRpe: actualRpe,
      updatedAt: nowMs,
    );
    await txn.insert(
      'ss_session_prescription',
      updated.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return logId;
  }

  static void _validateCompletion(
    SessionPrescription prescription,
    int? actualMinutes,
    int? actualRpe,
  ) {
    if (prescription.slotType == SlotType.rest) {
      throw ArgumentError('Cannot complete a REST prescription as a workout.');
    }
    if (actualMinutes != null && (actualMinutes <= 0 || actualMinutes > 240)) {
      throw ArgumentError('actualMinutes must be between 1 and 240.');
    }
    if (actualRpe != null && (actualRpe < 1 || actualRpe > 10)) {
      throw ArgumentError('actualRpe must be between 1 and 10.');
    }
  }

  static MovementIntensity _intensityFromRpe(int? actualRpe) {
    if (actualRpe == null) return MovementIntensity.medium;
    if (actualRpe <= 5) return MovementIntensity.low;
    if (actualRpe >= 8) return MovementIntensity.high;
    return MovementIntensity.medium;
  }

  static String _kindForSlot(SlotType slotType) {
    return switch (slotType) {
      SlotType.strength => 'SS_SESSION',
      SlotType.cardio => 'CARDIO_GENERIC',
      SlotType.mobility => 'YOGA',
      SlotType.activeRest => 'WALKING',
      SlotType.rest => 'OTHER',
    };
  }
}
