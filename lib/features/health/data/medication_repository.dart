import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/engines/medical_engine.dart';
import 'package:ritmo/core/domain/engines/ritmo_event_bus.dart';
import 'package:ritmo/core/domain/engines/ritmo_execution_kernel.dart';
import 'package:ritmo/core/domain/execution/kernel_mutation_result.dart';
import 'package:ritmo/core/domain/execution/post_commit_pipeline.dart';
import 'package:ritmo/core/domain/medication/medication_identity.dart';
import 'package:ritmo/core/domain/models.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';
import 'package:ritmo/core/notifications/notification_gateway.dart';
import 'package:ritmo/core/services/snapshot_sync_service.dart';
import 'package:ritmo/core/time/ritmo_clock.dart';
import 'package:ritmo/features/health/models/medication_models.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

/// مخزن داده اصلی، جامع و اتمیک برای مدیریت داروها، پروفایل‌های بالینی و ثبت دوزها
class MedicationRepository {
  MedicationRepository._();
  static final MedicationRepository instance = MedicationRepository._();

  /// محاسبه هوشمند تعداد واحدهای کسر شونده از موجودی بر مبنای دوز و شکل دارو
  ///
  /// C-01: اگر دوز بر حسب میلی‌گرم (mg) باشد ولی شکل دارو قرص یا کپسول باشد،
  /// مقدار میلی‌گرم مستقیماً از تعداد قرص‌های بسته کم نمی‌شود؛ بلکه بر اساس
  /// قدرت دارو (strength) به تعداد واحد مصرفی تبدیل می‌شود.
  static double calculateDeductionUnits({
    required MedicationProfile profile,
    double? doseAmount,
    String? doseUnit,
  }) {
    final effectiveAmount = doseAmount ?? profile.doseAmount ?? 1.0;
    final rawUnit = (doseUnit ?? profile.doseUnit?.name ?? '').toUpperCase().trim();

    final isMassUnit = rawUnit == 'MG' || rawUnit == 'MCG' || rawUnit == 'G';
    final isCountableForm = profile.form == MedicationForm.TABLET ||
        profile.form == MedicationForm.CAPSULE ||
        profile.form == MedicationForm.PATCH ||
        profile.form == MedicationForm.SACHET ||
        profile.form == MedicationForm.SUPPOSITORY;

    if (isMassUnit && isCountableForm) {
      if (profile.strength != null && profile.strength!.isNotEmpty) {
        // Handle combination drugs or standard strength (RITF-013)
        final strengthStr = profile.strength!.split('/')[0];
        final match = RegExp(r'(\d+(\.\d+)?)').firstMatch(strengthStr);
        if (match != null) {
          final strengthNum = double.tryParse(match.group(1)!);
          if (strengthNum != null && strengthNum > 0) {
            final units = effectiveAmount / strengthNum;
            return units.clamp(0.1, 100.0);
          }
        }
      }
      // اگر قدرت قرص در پروفایل ثبت نشده بود، ۱ عدد قرص کسر می‌شود (نه مثلاً ۵۰۰ عدد!)
      return 1.0;
    }

    final isLiquidForm = profile.form == MedicationForm.DROPS ||
        profile.form == MedicationForm.SYRUP;

    if (isMassUnit && isLiquidForm) {
      // RITF-012: Handle liquid forms with mass dose (mg per ml or concentration)
      if (profile.strength != null && profile.strength!.isNotEmpty) {
        final match = RegExp(r'(\d+(\.\d+)?)\s*(?:mg)?\s*/\s*(\d+(\.\d+)?)\s*ml', caseSensitive: false)
            .firstMatch(profile.strength!);
        if (match != null) {
          final mg = double.tryParse(match.group(1)!) ?? 1.0;
          final ml = double.tryParse(match.group(3)!) ?? 1.0;
          if (mg > 0 && ml > 0) {
            final mgPerMl = mg / ml;
            return (effectiveAmount / mgPerMl).clamp(0.1, 1000.0);
          }
        }
        final singleMatch = RegExp(r'(\d+(\.\d+)?)').firstMatch(profile.strength!);
        if (singleMatch != null) {
          final strengthNum = double.tryParse(singleMatch.group(1)!);
          if (strengthNum != null && strengthNum > 0) {
            return (effectiveAmount / strengthNum).clamp(0.1, 1000.0);
          }
        }
      }
      // If strength is not provided for liquid, fallback to doseAmount as ml or 1.0 unit
      return (doseAmount ?? 1.0).clamp(0.1, 100.0);
    }

    return effectiveAmount.clamp(0.0, double.infinity);
  }

  /// دریافت یک دارو بر اساس شناسه روتین (درون تراکنش)
  Future<Medication?> _getByRoutineIdTxn(Transaction txn, String routineId) async {
    try {
      final routineRows = await txn.query(
        'routines',
        where: 'id = ?',
        whereArgs: [routineId],
        limit: 1,
      );
      if (routineRows.isEmpty) return null;
      final routine = routineRows.first;

      final profileRows = await txn.query(
        'medication_profiles',
        where: 'routineId = ?',
        whereArgs: [routineId],
        limit: 1,
      );
      final profileMap = profileRows.isNotEmpty ? profileRows.first : null;

      final scheduleRows = await txn.query(
        'routine_schedules',
        where: 'routineId = ?',
        whereArgs: [routineId],
        orderBy: 'id ASC',
        limit: 1,
      );
      final scheduleMap = scheduleRows.isNotEmpty ? scheduleRows.first : null;

      return Medication.fromRoutineAndProfile(
        routine,
        profileMap,
        scheduleMap: scheduleMap,
      );
    } catch (e, st) {
      debugPrint('[MedicationRepository] _getByRoutineIdTxn error: $e\n$st');
      return null;
    }
  }

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
        orderBy: 'id ASC',
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
      final profileMap = <String, Map<String, dynamic>>{};
      for (final p in profiles) {
        final rId = p['routineId'] as String?;
        if (rId != null) profileMap[rId] = p;
      }

      final schedules = await db.query('routine_schedules', orderBy: 'id ASC');
      final scheduleMap = <String, Map<String, dynamic>>{};
      for (final s in schedules) {
        final rId = (s['routineId'] ?? s['routine_id']) as String?;
        if (rId != null && !scheduleMap.containsKey(rId)) {
          scheduleMap[rId] = s;
        }
      }

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
      final profileMap = <String, Map<String, dynamic>>{};
      for (final p in profiles) {
        final rId = p['routineId'] as String?;
        if (rId != null) profileMap[rId] = p;
      }

      final schedules = await db.query('routine_schedules', orderBy: 'id ASC');
      final scheduleMap = <String, Map<String, dynamic>>{};
      for (final s in schedules) {
        final rId = (s['routineId'] ?? s['routine_id']) as String?;
        if (rId != null && !scheduleMap.containsKey(rId)) {
          scheduleMap[rId] = s;
        }
      }

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

  /// ایجاد یا ویرایش دارو همراه با پروفایل تخصصی و زمان‌بندی درون تراکنش اتمیک
  Future<String> saveMedication({
    required Medication medication,
    required Map<String, dynamic> scheduleData,
    bool isEdit = false,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final routineId = isEdit
        ? medication.id
        : (medication.id.isNotEmpty ? medication.id : 'routine_med_${const Uuid().v4()}');

    // C-03: اتصال سطح حساسیت دارو به سطح آگاه‌سازی و اولویت
    String notifLevel = 'normal';
    double priority = 2.0;
    int isEssential = medication.isEssential ? 1 : 0;
    int isEssentialLocked = 0;

    switch (medication.profile.criticality) {
      case MedicationCriticality.LIFE_CRITICAL:
        notifLevel = 'alarm';
        priority = 3.0;
        isEssential = 1;
        isEssentialLocked = 1;
        break;
      case MedicationCriticality.HIGH:
        notifLevel = 'important';
        priority = 2.5;
        isEssential = 1;
        break;
      case MedicationCriticality.NORMAL:
        notifLevel = 'normal';
        priority = medication.isEssential ? 2.0 : 1.0;
        break;
    }

    final routineData = <String, dynamic>{
      'id': routineId,
      'title': medication.name,
      'description': medication.profile.instructions ?? medication.description,
      'category': medication.category.isNotEmpty ? medication.category : 'medical',
      'routineType': medication.routineType,
      'notificationLevel': notifLevel,
      'isEssential': isEssential,
      'isEssentialLocked': isEssentialLocked,
      'energyRule': 'NONE',
      'priority': priority,
      'medStockCount': medication.profile.remainingAmount?.round() ?? 0,
      'medRefillThreshold': medication.profile.refillThresholdAmount?.round() ?? 0,
      'minIntervalHours': medication.isPrn ? medication.minIntervalHours : 0,
      'maxDosesPerDay': medication.isPrn ? medication.maxDosesPerDay : 0,
      'isArchived': medication.isArchived ? 1 : 0,
      'isPrivate': medication.isPrivate ? 1 : 0,
      'displayOrder': 1,
      'createdAt': isEdit ? medication.createdAt : now,
      'updatedAt': now,
      'itemType': MedicationIdentity.itemType,
    };

    final db = await DatabaseHelper.instance.database;
    final postCommitTasks = <Future<void> Function()>[];
    final domainEvents = <RitmoEvent>[];

    // H-12: اجرای ذخیره دستورات روتین و پروفایل دارویی در یک تراکنش اتمیک
    await db.transaction((txn) async {
      KernelMutationResult kernelRes;
      if (isEdit) {
        kernelRes = await RitmoExecutionKernel.instance.execute(
          EditRoutineCommand(
            routineId: routineId,
            routineData: routineData,
            scheduleData: scheduleData,
            applyToAll: true,
          ),
          txn: txn,
        );
      } else {
        kernelRes = await RitmoExecutionKernel.instance.execute(
          CreateRoutineCommand(
            routineData: routineData,
            scheduleData: scheduleData,
          ),
          txn: txn,
        );
      }

      postCommitTasks.addAll(kernelRes.postCommitTasks);
      domainEvents.addAll(kernelRes.domainEvents);

      final profileData = medication.profile.copyWith(routineId: routineId).toMap();
      await txn.insert(
        'medication_profiles',
        profileData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });

    // اجرای کارهای پس از کامیت و انتشار رویدادها خارج از تراکنش
    await PostCommitPipeline.run(postCommitTasks);
    for (final event in domainEvents) {
      RitmoEventBus().fire(event);
    }

    return routineId;
  }

  /// به‌روزرسانی موجودی دارو به صورت اتمیک (پشتیبانی کامل از اعشار)
  Future<bool> updateStock(String routineId, double remainingAmount) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now().millisecondsSinceEpoch;

      await db.transaction((txn) async {
        await txn.update(
          'medication_profiles',
          {'remainingAmount': remainingAmount},
          where: 'routineId = ?',
          whereArgs: [routineId],
        );
        await txn.update(
          'routines',
          {
            'medStockCount': remainingAmount.round(),
            'updatedAt': now,
          },
          where: 'id = ?',
          whereArgs: [routineId],
        );
      });
      return true;
    } catch (e, st) {
      RitmoLog.error('MedicationRepository', 'updateStock error', e, st);
      return false;
    }
  }

  /// شارژ موجودی دارو / تمدید نسخه
  Future<bool> refillStock(String routineId, double addedAmount) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.transaction((txn) async {
        final profileRows = await txn.query(
          'medication_profiles',
          columns: ['remainingAmount'],
          where: 'routineId = ?',
          whereArgs: [routineId],
          limit: 1,
        );
        final current = profileRows.isNotEmpty
            ? (profileRows.first['remainingAmount'] as num?)?.toDouble() ?? 0.0
            : 0.0;
        final updated = current + addedAmount;

        final now = DateTime.now().millisecondsSinceEpoch;
        await txn.update(
          'medication_profiles',
          {'remainingAmount': updated},
          where: 'routineId = ?',
          whereArgs: [routineId],
        );
        await txn.update(
          'routines',
          {
            'medStockCount': updated.round(),
            'updatedAt': now,
          },
          where: 'id = ?',
          whereArgs: [routineId],
        );
      });
      return true;
    } catch (e, st) {
      RitmoLog.error('MedicationRepository', 'refillStock error', e, st);
      return false;
    }
  }

  /// آرشیو کردن دارو همراه با لغو فیزیکی آلارم‌ها و حذف یادآورهای آینده
  Future<bool> archive(String routineId) async {
    try {
      await RitmoExecutionKernel.instance.execute(
        ArchiveRoutineCommand(routineId: routineId),
      );
      return true;
    } catch (e, st) {
      RitmoLog.error('MedicationRepository', 'archive error', e, st);
      return false;
    }
  }

  /// خروج از آرشیو همراه با بازسازی یادآورها
  Future<bool> unarchive(String routineId) async {
    try {
      await RitmoExecutionKernel.instance.execute(
        UnarchiveRoutineCommand(routineId: routineId),
      );
      return true;
    } catch (e, st) {
      RitmoLog.error('MedicationRepository', 'unarchive error', e, st);
      return false;
    }
  }

  /// حذف دارو (به صورت پیش‌فرض آرشیو ایمن همراه با لغو کامل آلارم‌ها جهت حفظ سوابق بالینی)
  Future<bool> delete(String routineId, {bool hardDelete = false}) async {
    try {
      if (!hardDelete) {
        return await archive(routineId);
      }

      await RitmoExecutionKernel.instance.execute(
        DeleteRoutineCommand(
          routineId: routineId,
        ),
      );
      final db = await DatabaseHelper.instance.database;
      await db.transaction((txn) async {
        await txn.delete(
          'medication_profiles',
          where: 'routineId = ?',
          whereArgs: [routineId],
        );
        await txn.delete(
          'prn_logs',
          where: 'routineId = ?',
          whereArgs: [routineId],
        );
        await txn.delete(
          'medication_logs',
          where: 'routineId = ?',
          whereArgs: [routineId],
        );
      });
      return true;
    } catch (e, st) {
      RitmoLog.error('MedicationRepository', 'delete error', e, st);
      return false;
    }
  }

  /// بررسی ایمنی مصرف دارو (جلوگیری از دوز تکراری یا اوردوز بر اساس فاصله زمانی و سقف روزانه)
  Future<MedicationSafetyResult> checkSafety({
    required String routineId,
    int? scheduledTime,
    int? nowMs,
  }) async {
    try {
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
        // اگر زمان‌بندی صریح پاس داده نشد (داروی زمان‌دار یا موردی)
        final recentLogs = await db.query(
          'medication_logs',
          where: 'routineId = ? AND status = ? AND (takenTime >= ? OR createdAt >= ?)',
          whereArgs: [routineId, 'TAKEN', now - 15 * 60 * 1000, now - 15 * 60 * 1000],
        );
        if (recentLogs.isNotEmpty) {
          return const MedicationSafetyResult(
            isSafe: false,
            isDuplicate: true,
            warningMessage: 'شما در ۱۵ دقیقه گذشته یک دوز از این دارو ثبت کرده‌اید. آیا از مصرف مجدد اطمینان دارید؟',
          );
        }
      }

      // 2. بررسی فاصله زمانی و سقف روزانه داروهای موردی (PRN)
      if (med.isPrn) {
        final oneDayAgo = now - 24 * 60 * 60 * 1000;
        final prnLogs = await db.query(
          'medication_logs',
          where: 'routineId = ? AND status = ? AND COALESCE(takenTime, createdAt) >= ?',
          whereArgs: [routineId, 'TAKEN', oneDayAgo],
        );

        final timestamps = <int>[
          for (final l in prnLogs) ((l['takenTime'] as num?)?.toInt() ?? (l['createdAt'] as num?)?.toInt() ?? 0),
        ];

        final overdose = MedicalEngine.checkOverdoseStatus(
          now: now,
          prnLogs24h: timestamps,
          minIntervalHours: med.minIntervalHours,
          maxDosesPerDay: med.maxDosesPerDay,
        );

        if (overdose == OverdoseResult.warningBoth) {
          return MedicationSafetyResult(
            isSafe: false,
            overdoseResult: overdose,
            warningMessage: 'هشدار جدی: هم فاصله زمانی مجاز و هم سقف تعداد دوز در ۲۴ ساعت (${med.maxDosesPerDay} دوز) نقض شده است.',
          );
        } else if (overdose == OverdoseResult.warningUnderInterval) {
          final lastTaken = timestamps.fold<int>(0, (max, val) => val > max ? val : max);
          final elapsedMinutes = (now - lastTaken) / (60 * 1000);
          final requiredMinutes = med.minIntervalHours * 60;
          final remainingMinutes = (requiredMinutes - elapsedMinutes).ceil().clamp(1, math.max(1, requiredMinutes));
          return MedicationSafetyResult(
            isSafe: false,
            overdoseResult: overdose,
            remainingMinutesUntilSafe: remainingMinutes.toInt(),
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
    } catch (e, st) {
      RitmoLog.error('MedicationRepository', 'checkSafety error', e, st);
      return const MedicationSafetyResult(isSafe: true);
    }
  }

  /// ثبت دقیق مصرف یا پرش یک دوز دارو به صورت اتمیک و Idempotent
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
    // H-13: شناسه idempotent برای دوزهای زمان‌بندی‌شده
    final logId = scheduledTime != null
        ? 'medlog_${routineId}_$scheduledTime'
        : 'medlog_${routineId}_$now';

    final db = await DatabaseHelper.instance.database;
    final med = await getByRoutineId(routineId);

    final deductionUnits = med != null
        ? calculateDeductionUnits(
            profile: med.profile,
            doseAmount: doseAmount,
            doseUnit: doseUnit,
          )
        : (doseAmount ?? 1.0);

    final effectiveUnit = doseUnit ?? med?.profile.doseUnit?.name ?? 'TABLET';

    // C-05: محاسبه تاریخ دقیق وقوع بر مبنای ساعت زمان‌بندی‌شده یا زمان مصرف
    final eventMs = scheduledTime ?? takenTime ?? now;
    final targetDate = DateTime.fromMillisecondsSinceEpoch(eventMs);
    final targetDateStr = DayKey.from(targetDate).value;

    final alarmsToCancel = <String>[];
    bool wasDuplicate = false;

    await db.transaction((txn) async {
      // بررسی عدم ثبت دوباره دوز قبلاً ثبت‌شده (Idempotency - RITF-008)
      if (scheduledTime != null && status == 'TAKEN') {
        final existing = await txn.query(
          'medication_logs',
          where: 'routineId = ? AND scheduledTime = ? AND status = ?',
          whereArgs: [routineId, scheduledTime, 'TAKEN'],
        );
        if (existing.isNotEmpty) {
          wasDuplicate = true;
          return;
        }
      }

      // ۱. درج یا به‌روزرسانی لاگ در medication_logs همراه با دوز، واحد و محل تزریق (RITF-006)
      await txn.insert(
        'medication_logs',
        {
          'id': logId,
          'routineId': routineId,
          'scheduledTime': scheduledTime,
          'takenTime': status == 'TAKEN' ? (takenTime ?? now) : null,
          'status': status,
          'doseAmount': deductionUnits,
          'doseUnit': effectiveUnit,
          'site': site,
          'note': notes,
          'createdAt': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // درج در جدول prn_logs برای ثبت مصرف‌های موردی (PRN) جهت همگام‌سازی تایمرها و سوابق
      if (status == 'TAKEN' && (med?.isPrn == true || scheduledTime == null)) {
        final doseFormatted = '${deductionUnits == deductionUnits.toInt() ? deductionUnits.toInt() : deductionUnits} $effectiveUnit';
        await txn.insert(
          'prn_logs',
          {
            'id': 'prn_${routineId}_${takenTime ?? now}',
            'routineId': routineId,
            'takenAt': takenTime ?? now,
            'dosage': doseFormatted,
            'createdAt': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // ۲. کسر اتمیک موجودی دارو در دیتابیس بدون ریسک Lost Update (RITF-005)
      if (status == 'TAKEN' && med != null && med.profile.hasStockTracking) {
        await txn.rawUpdate('''
          UPDATE medication_profiles
             SET remainingAmount = MAX(0.0, remainingAmount - ?)
           WHERE routineId = ?
        ''', [deductionUnits, routineId]);

        final updatedProfile = await txn.query(
          'medication_profiles',
          columns: ['remainingAmount'],
          where: 'routineId = ?',
          whereArgs: [routineId],
          limit: 1,
        );
        if (updatedProfile.isNotEmpty) {
          final updatedStock = (updatedProfile.first['remainingAmount'] as num?)?.toDouble() ?? 0.0;
          await txn.update(
            'routines',
            {
              'medStockCount': updatedStock.round(),
              'updatedAt': now,
            },
            where: 'id = ?',
            whereArgs: [routineId],
          );
        }
      }

      // ۳. جمع‌آوری آلارم‌های مرتبط با این دوز جهت لغو خارج از تراکنش (RITF-014)
      if (scheduledTime != null) {
        await txn.update(
          'pending_reminders',
          {
            'state': status == 'TAKEN' ? 'completed' : 'skipped',
            'updatedAt': now,
          },
          where: 'routineId = ? AND (originalTime = ? OR scheduledTime = ?)',
          whereArgs: [routineId, scheduledTime, scheduledTime],
        );

        final matchingReminders = await txn.query(
          'pending_reminders',
          where: 'routineId = ? AND (originalTime = ? OR scheduledTime = ?)',
          whereArgs: [routineId, scheduledTime, scheduledTime],
        );
        for (final rem in matchingReminders) {
          final rId = rem['id'] as String;
          alarmsToCancel.add(rId);
        }
      } else {
        // M-21: لغو یادآورهای فعال نزدیک برای مصرف زودهنگام / موردی در ۲ ساعت آینده
        final upcomingWindow = now + (2 * 60 * 60 * 1000);
        final upcomingReminders = await txn.query(
          'pending_reminders',
          where: 'routineId = ? AND state = ? AND scheduledTime BETWEEN ? AND ?',
          whereArgs: [routineId, 'pending', now - (30 * 60 * 1000), upcomingWindow],
        );
        if (upcomingReminders.isNotEmpty) {
          await txn.update(
            'pending_reminders',
            {
              'state': status == 'TAKEN' ? 'completed' : 'skipped',
              'updatedAt': now,
            },
            where: 'routineId = ? AND state = ? AND scheduledTime BETWEEN ? AND ?',
            whereArgs: [routineId, 'pending', now - (30 * 60 * 1000), upcomingWindow],
          );
          for (final rem in upcomingReminders) {
            final rId = rem['id'] as String;
            alarmsToCancel.add(rId);
          }
        }
      }
    });

    // گارد کامل عدم اجرای side-effect ها در صورت تکراری بودن دوز (RITF-008)
    if (wasDuplicate) {
      return logId;
    }

    // لغو فیزیکی آلارم‌ها خارج از بلاک تراکنش SQL
    for (final remId in alarmsToCancel) {
      try {
        await NotificationGateway.cancel(remId);
      } catch (_) {}
    }

    // ۴. ثبت نتیجه در هسته اجرای ریتمو با تاریخ درست (RITF-018)
    try {
      await RitmoExecutionKernel.instance.execute(
        CompleteOccurrenceCommand(
          routineId: routineId,
          dateStr: targetDateStr,
          resultType: status == 'TAKEN' ? 'FULL' : 'SKIPPED',
          durationMinutes: 5,
        ),
      );
    } catch (_) {}

    // ۵. اطلاع‌رسانی به سیستم رویدادها و همگام‌سازی اسنپ‌شات
    RitmoEventBus().fire(RitmoEvent(
      type: status == 'TAKEN' ? 'medication_consumed' : 'medication_skipped',
      timestamp: DateTime.now(),
      payload: {
        'routineId': routineId,
        'takenAt': takenTime ?? now,
        'status': status,
        'doseAmount': deductionUnits,
        'doseUnit': effectiveUnit,
        'site': site,
      },
    ));
    RitmoEvents.notifyRoutineChanged();
    await SnapshotSyncService.syncAll();

    return logId;
  }

  /// لغو ثبت مصرف دارو و بازگردانی دقیق موجودی (Undo Intake - RITF-007)
  Future<void> undoIntake(String logId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now().millisecondsSinceEpoch;
      final postCommitTasks = <Future<void> Function()>[];
      final domainEvents = <RitmoEvent>[];

      await db.transaction((txn) async {
        final logs = await txn.query(
          'medication_logs',
          where: 'id = ?',
          whereArgs: [logId],
          limit: 1,
        );
        if (logs.isEmpty) return;

        final log = logs.first;
        final routineId = log['routineId'] as String?;
        final status = log['status'] as String?;
        final scheduledTime = (log['scheduledTime'] as num?)?.toInt();
        final takenTime = (log['takenTime'] as num?)?.toInt();

        if (routineId == null) return;

        // اگر دوز مصرف شده بود، موجودی واقعی ثبت‌شده در لاگ را پس بده (RITF-007)
        if (status == 'TAKEN') {
          final recordedDose = (log['doseAmount'] as num?)?.toDouble();
          final med = await _getByRoutineIdTxn(txn, routineId);
          final deductionUnits = recordedDose ??
              (med != null
                  ? calculateDeductionUnits(profile: med.profile)
                  : 1.0);

          final profileRows = await txn.query(
            'medication_profiles',
            columns: ['remainingAmount'],
            where: 'routineId = ?',
            whereArgs: [routineId],
            limit: 1,
          );
          if (profileRows.isNotEmpty) {
            final currentStock = (profileRows.first['remainingAmount'] as num?)?.toDouble() ?? 0.0;
            final restoredStock = currentStock + deductionUnits;
            await txn.update(
              'medication_profiles',
              {'remainingAmount': restoredStock},
              where: 'routineId = ?',
              whereArgs: [routineId],
            );
            await txn.update(
              'routines',
              {
                'medStockCount': restoredStock.round(),
                'updatedAt': now,
              },
              where: 'id = ?',
              whereArgs: [routineId],
            );
          }
        }

        // حذف لاگ از جدول medication_logs
        await txn.delete(
          'medication_logs',
          where: 'id = ?',
          whereArgs: [logId],
        );

        // در صورت PRN بودن، رکورد متناظر در prn_logs را نیز حذف کن
        if (scheduledTime == null) {
          final takenAtVal = takenTime ?? (log['takenTime'] as num?)?.toInt() ?? (log['createdAt'] as num?)?.toInt();
          if (takenAtVal != null) {
            await txn.delete(
              'prn_logs',
              where: 'routineId = ? AND takenAt = ?',
              whereArgs: [routineId, takenAtVal],
            );
          }
        }

        final eventMs = scheduledTime ?? takenTime ?? now;
        final dateStr = DayKey.from(DateTime.fromMillisecondsSinceEpoch(eventMs)).value;
        final kRes = await RitmoExecutionKernel.instance.execute(
          CompleteOccurrenceCommand(
            routineId: routineId,
            dateStr: dateStr,
            resultType: 'EMPTY',
            durationMinutes: 0,
          ),
          txn: txn,
        );
        postCommitTasks.addAll(kRes.postCommitTasks);
        domainEvents.addAll(kRes.domainEvents);
      });

      await PostCommitPipeline.run(postCommitTasks);
      for (final event in domainEvents) {
        RitmoEventBus().fire(event);
      }

      RitmoEventBus().fire(RitmoEvent(
        type: 'medication_intake_undone',
        timestamp: DateTime.now(),
        payload: {'logId': logId},
      ));
      RitmoEvents.notifyRoutineChanged();
      await SnapshotSyncService.syncAll();
    } catch (e, st) {
      RitmoLog.error('MedicationRepository', 'undoIntake error', e, st);
    }
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
