import 'package:flutter/foundation.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/medical_engine.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/domain/engines/ritmo_execution_kernel.dart';
import 'package:ritmo/core/domain/medication/medication_identity.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/notifications/notification_gateway.dart';
import 'package:ritmo/core/services/snapshot_sync_service.dart';
import 'package:ritmo/features/health/models/medication_models.dart';
import 'package:sqflite/sqflite.dart';

/// مخزن داده اصلی و جامع برای مدیریت داروها و پروفایل‌های دارویی
class MedicationRepository {
  MedicationRepository._();
  static final MedicationRepository instance = MedicationRepository._();

  /// دریافت یک دارو بر اساس شناسه روتین
  Future<Medication?> getByRoutineId(String routineId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final routineRows = await db.query(
        'routines',
        where: 'id = ?',
        whereArgs: [routineId],
        limit: 1,
      );
      if (routineRows.isEmpty) return null;
      final routine = routineRows.first;

      final profileRows = await db.query(
        'medication_profiles',
        where: 'routineId = ?',
        whereArgs: [routineId],
        limit: 1,
      );
      final profileMap = profileRows.isNotEmpty ? profileRows.first : null;

      final scheduleRows = await db.query(
        'routine_schedules',
        where: 'routineId = ?',
        whereArgs: [routineId],
        limit: 1,
      );
      final scheduleMap = scheduleRows.isNotEmpty ? scheduleRows.first : null;

      return Medication.fromRoutineAndProfile(
        routine,
        profileMap,
        scheduleMap: scheduleMap,
      );
    } catch (e, st) {
      debugPrint('[MedicationRepository] getByRoutineId error: $e\n$st');
      return null;
    }
  }

  /// دریافت لیست تمام داروهای فعال (آرشیو نشده)
  Future<List<Medication>> listActive() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final routineRows = await db.query(
        'routines',
        where: 'isArchived = 0 AND ${MedicationIdentity.sqlPredicate}',
        orderBy: 'createdAt DESC',
      );
      if (routineRows.isEmpty) return const [];

      final profiles = await db.query('medication_profiles');
      final profileMap = {
        for (final p in profiles) p['routineId'] as String: p,
      };

      final schedules = await db.query('routine_schedules');
      final scheduleMap = {
        for (final s in schedules) (s['routineId'] ?? s['routine_id']) as String: s,
      };

      return routineRows.map((r) {
        final id = r['id'] as String;
        return Medication.fromRoutineAndProfile(
          r,
          profileMap[id],
          scheduleMap: scheduleMap[id],
        );
      }).toList();
    } catch (e, st) {
      debugPrint('[MedicationRepository] listActive error: $e\n$st');
      return const [];
    }
  }

  /// دریافت لیست داروهای آرشیو شده
  Future<List<Medication>> listArchived() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final routineRows = await db.query(
        'routines',
        where: 'isArchived = 1 AND ${MedicationIdentity.sqlPredicate}',
        orderBy: 'updatedAt DESC',
      );
      if (routineRows.isEmpty) return const [];

      final profiles = await db.query('medication_profiles');
      final profileMap = {
        for (final p in profiles) p['routineId'] as String: p,
      };

      final schedules = await db.query('routine_schedules');
      final scheduleMap = {
        for (final s in schedules) (s['routineId'] ?? s['routine_id']) as String: s,
      };

      return routineRows.map((r) {
        final id = r['id'] as String;
        return Medication.fromRoutineAndProfile(
          r,
          profileMap[id],
          scheduleMap: scheduleMap[id],
        );
      }).toList();
    } catch (e, st) {
      debugPrint('[MedicationRepository] listArchived error: $e\n$st');
      return const [];
    }
  }

  /// ایجاد یا ویرایش دارو همراه با پروفایل تخصصی و زمان‌بندی
  Future<String> saveMedication({
    required Medication medication,
    required Map<String, dynamic> scheduleData,
    bool isEdit = false,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final routineId = isEdit ? medication.id : (medication.id.isNotEmpty ? medication.id : 'routine_med_$now');

    final routineData = <String, dynamic>{
      'id': routineId,
      'title': medication.name,
      'description': medication.profile.instructions ?? medication.description,
      'category': 'medical',
      'routineType': medication.routineType,
      'notificationLevel': 'normal',
      'isEssential': 1,
      'isEssentialLocked': 0,
      'energyRule': 'NONE',
      'priority': 2.0,
      'medStockCount': medication.profile.remainingAmount?.toInt() ?? 0,
      'medRefillThreshold': medication.profile.refillThresholdAmount?.toInt() ?? 0,
      'minIntervalHours': medication.isPrn ? medication.minIntervalHours : 0,
      'maxDosesPerDay': medication.isPrn ? medication.maxDosesPerDay : 0,
      'isArchived': medication.isArchived ? 1 : 0,
      'isPrivate': 0,
      'displayOrder': 1,
      'createdAt': isEdit ? medication.createdAt : now,
      'updatedAt': now,
      'itemType': MedicationIdentity.itemType,
    };

    if (isEdit) {
      await RitmoExecutionKernel.instance.execute(
        EditRoutineCommand(
          routineId: routineId,
          routineData: routineData,
          scheduleData: scheduleData,
          applyToAll: true,
        ),
      );
    } else {
      await RitmoExecutionKernel.instance.execute(
        CreateRoutineCommand(
          routineData: routineData,
          scheduleData: scheduleData,
        ),
      );
    }

    // ذخیره یا به‌روزرسانی پروفایل در جدول medication_profiles
    final db = await DatabaseHelper.instance.database;
    final profileData = medication.profile.copyWith(routineId: routineId).toMap();
    await db.insert(
      'medication_profiles',
      profileData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return routineId;
  }

  /// به‌روزرسانی موجودی دارو
  Future<void> updateStock(String routineId, double remainingAmount) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'medication_profiles',
        {'remainingAmount': remainingAmount},
        where: 'routineId = ?',
        whereArgs: [routineId],
      );
      await db.update(
        'routines',
        {
          'medStockCount': remainingAmount.toInt(),
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [routineId],
      );
    } catch (e, st) {
      debugPrint('[MedicationRepository] updateStock error: $e\n$st');
    }
  }

  /// شارژ موجودی دارو / تمدید نسخه
  Future<void> refillStock(String routineId, double addedAmount) async {
    try {
      final medication = await getByRoutineId(routineId);
      if (medication == null) return;
      final current = medication.profile.remainingAmount ?? 0.0;
      final updated = current + addedAmount;
      await updateStock(routineId, updated);
    } catch (e, st) {
      debugPrint('[MedicationRepository] refillStock error: $e\n$st');
    }
  }

  /// آرشیو کردن دارو
  Future<void> archive(String routineId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'routines',
        {
          'isArchived': 1,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [routineId],
      );
    } catch (e, st) {
      debugPrint('[MedicationRepository] archive error: $e\n$st');
    }
  }

  /// خروج از آرشیو
  Future<void> unarchive(String routineId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'routines',
        {
          'isArchived': 0,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [routineId],
      );
    } catch (e, st) {
      debugPrint('[MedicationRepository] unarchive error: $e\n$st');
    }
  }

  /// حذف نرم/کامل دارو
  Future<void> delete(String routineId) async {
    try {
      await RitmoExecutionKernel.instance.execute(
        DeleteRoutineCommand(
          routineId: routineId,
        ),
      );
      final db = await DatabaseHelper.instance.database;
      await db.delete(
        'medication_profiles',
        where: 'routineId = ?',
        whereArgs: [routineId],
      );
    } catch (e, st) {
      debugPrint('[MedicationRepository] delete error: $e\n$st');
    }
  }

  /// بررسی ایمنی مصرف دارو (جلوگیری از دوز تکراری یا اوردوز بر اساس فاصله زمانی و سقف روزانه)
  Future<MedicationSafetyResult> checkSafety({
    required String routineId,
    int? scheduledTime,
    int? nowMs,
  }) async {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final db = await DatabaseHelper.instance.database;

    final med = await getByRoutineId(routineId);
    if (med == null) {
      return const MedicationSafetyResult(isSafe: true);
    }

    // 1. بررسی دوز تکراری در بازه زمانی اخیر (Duplicate Check)
    if (scheduledTime != null) {
      final existingScheduled = await db.query(
        'medication_logs',
        where: 'routineId = ? AND scheduledTime = ? AND status = ?',
        whereArgs: [routineId, scheduledTime, 'TAKEN'],
      );
      if (existingScheduled.isNotEmpty) {
        return const MedicationSafetyResult(
          isSafe: false,
          isDuplicate: true,
          warningMessage: 'این دوز دارو قبلاً ثبت شده است. جهت پیشگیری از مسمومیت دارویی از مصرف مجدد خودداری فرمایید.',
        );
      }
    } else {
      // PRN recent check: if taken within the last 10 minutes
      final recentLogs = await db.query(
        'medication_logs',
        where: 'routineId = ? AND status = ? AND createdAt >= ?',
        whereArgs: [routineId, 'TAKEN', now - 10 * 60 * 1000],
      );
      if (recentLogs.isNotEmpty) {
        return const MedicationSafetyResult(
          isSafe: false,
          isDuplicate: true,
          warningMessage: 'شما در ۱۰ دقیقه گذشته یک دوز از این دارو ثبت کرده‌اید. آیا از مصرف مجدد اطمینان دارید؟',
        );
      }
    }

    // 2. بررسی فاصله زمانی و سقف روزانه داروهای موردی (PRN)
    if (med.isPrn) {
      final oneDayAgo = now - 24 * 60 * 60 * 1000;
      final prnLogs = await db.query(
        'medication_logs',
        where: 'routineId = ? AND status = ? AND createdAt >= ?',
        whereArgs: [routineId, 'TAKEN', oneDayAgo],
      );
      final prnLegacy = await db.query(
        'prn_logs',
        where: 'routineId = ? AND takenAt >= ?',
        whereArgs: [routineId, oneDayAgo],
      );

      final timestamps = <int>{
        for (final l in prnLogs) (l['takenTime'] as int? ?? l['createdAt'] as int),
        for (final l in prnLegacy) l['takenAt'] as int,
      }.toList();

      final overdose = MedicalEngine.checkOverdoseStatus(
        now: now,
        prnLogs24h: timestamps,
        minIntervalHours: med.minIntervalHours,
        maxDosesPerDay: med.maxDosesPerDay,
      );

      if (overdose == OverdoseResult.warningUnderInterval) {
        final lastTaken = timestamps.fold<int>(0, (max, val) => val > max ? val : max);
        final elapsedMinutes = (now - lastTaken) / (60 * 1000);
        final requiredMinutes = med.minIntervalHours * 60;
        final remainingMinutes = (requiredMinutes - elapsedMinutes).ceil().clamp(1, requiredMinutes);
        return MedicationSafetyResult(
          isSafe: false,
          overdoseResult: overdose,
          remainingMinutesUntilSafe: remainingMinutes,
          warningMessage: 'فاصله زمانی مجاز بین دوزها رعایت نشده است. حداقل $remainingMinutes دقیقه دیگر برای مصرف مجدد صبر کنید.',
        );
      } else if (overdose == OverdoseResult.warningMaxLimitExceeded) {
        return MedicationSafetyResult(
          isSafe: false,
          overdoseResult: overdose,
          warningMessage: 'حداکثر تعداد دوز مجاز در ۲۴ ساعت (${med.maxDosesPerDay} دوز) به پایان رسیده است.',
        );
      }
    }

    return const MedicationSafetyResult(isSafe: true);
  }

  /// ثبت دقیق مصرف یا پرش یک دوز دارو (با کسر خودکار موجودی و همگام‌سازی وضعیت آلارم)
  Future<String> recordIntake({
    required String routineId,
    required String status, // 'TAKEN', 'SKIPPED', 'SNOOZED'
    int? scheduledTime,
    int? takenTime,
    double? doseAmount,
    String? doseUnit,
    String? site,
    String? notes,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final logId = 'medlog_${routineId}_$now';
    final db = await DatabaseHelper.instance.database;

    final med = await getByRoutineId(routineId);
    final effectiveDose = doseAmount ?? med?.profile.doseAmount ?? 1.0;
    final effectiveUnit = doseUnit ?? med?.profile.doseUnit?.name ?? 'pill';

    // 1. درج لاگ در جدول medication_logs
    await db.insert(
      'medication_logs',
      {
        'id': logId,
        'routineId': routineId,
        'scheduledTime': scheduledTime,
        'takenTime': status == 'TAKEN' ? (takenTime ?? now) : null,
        'status': status,
        'note': notes,
        'createdAt': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // اگر موردی بود و لاگ legacy هم نیاز بود
    if (med?.isPrn == true && status == 'TAKEN') {
      try {
        await db.insert('prn_logs', {
          'id': 'prn_${routineId}_$now',
          'routineId': routineId,
          'takenAt': takenTime ?? now,
          'dosage': '$effectiveDose $effectiveUnit',
          'createdAt': now,
        });
      } catch (_) {}
    }

    // 2. کسر موجودی دارو در صورت مصرف (TAKEN)
    if (status == 'TAKEN' && med != null) {
      final currentStock = med.profile.remainingAmount ?? 0.0;
      final newStock = (currentStock - effectiveDose).clamp(0.0, double.infinity);
      await updateStock(routineId, newStock);
    }

    // 3. لغو آلارم‌های مرتبط با این دوز
    if (scheduledTime != null) {
      final scheduledDate = DateTime.fromMillisecondsSinceEpoch(scheduledTime);
      final dateStr = scheduledDate.toIso8601String().substring(0, 10);
      final timeStr = '${scheduledDate.hour.toString().padLeft(2, '0')}${scheduledDate.minute.toString().padLeft(2, '0')}';

      // Update pending_reminders state to completed
      await db.update(
        'pending_reminders',
        {
          'state': status == 'TAKEN' ? 'completed' : 'skipped',
          'updatedAt': now,
        },
        where: 'routineId = ? AND (originalTime = ? OR scheduledTime = ?)',
        whereArgs: [routineId, scheduledTime, scheduledTime],
      );

      final matchingReminders = await db.query(
        'pending_reminders',
        where: 'routineId = ? AND id LIKE ?',
        whereArgs: [routineId, '%$dateStr%$timeStr%'],
      );
      for (final rem in matchingReminders) {
        final rId = rem['id'] as String;
        await NotificationGateway.cancel(rId);
      }
    }

    // 4. ثبت نتیجه در هسته اجرای ریتمو برای نمایش در نمودارهای روزانه
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    try {
      await RitmoExecutionKernel.instance.execute(
        CompleteOccurrenceCommand(
          routineId: routineId,
          dateStr: todayStr,
          resultType: status == 'TAKEN' ? 'FULL' : 'SKIPPED',
          durationMinutes: 5,
        ),
      );
    } catch (_) {}

    // 5. اطلاع‌رسانی به سیستم رویدادها و همگام‌سازی اسنپ‌شات
    RitmoEventBus().fire(RitmoEvent(
      type: status == 'TAKEN' ? 'medication_consumed' : 'medication_skipped',
      timestamp: DateTime.now(),
      payload: {
        'routineId': routineId,
        'takenAt': takenTime ?? now,
        'status': status,
        'doseAmount': effectiveDose,
        'doseUnit': effectiveUnit,
        'site': site,
      },
    ));
    RitmoEvents.notifyRoutineChanged();
    await SnapshotSyncService.syncAll();

    return logId;
  }
}

/// نتیجه اعتبارسنجی ایمنی مصرف دارو
class MedicationSafetyResult {
  final bool isSafe;
  final String? warningMessage;
  final OverdoseResult overdoseResult;
  final int? remainingMinutesUntilSafe;
  final bool isDuplicate;

  const MedicationSafetyResult({
    required this.isSafe,
    this.warningMessage,
    this.overdoseResult = OverdoseResult.safe,
    this.remainingMinutesUntilSafe,
    this.isDuplicate = false,
  });
}
