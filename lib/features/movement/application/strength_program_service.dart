import 'dart:async';
import 'dart:convert';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/database/schema/tables/movement_tables.dart';
import 'package:ritmo/features/movement/domain/models/movement_change_scope.dart';
import 'package:ritmo/features/movement/domain/models/movement_occurrence.dart';
import 'package:ritmo/features/movement/domain/models/movement_set_log.dart';
import 'package:ritmo/features/movement/domain/models/movement_strength_day.dart';
import 'package:ritmo/features/movement/domain/models/movement_strength_exercise.dart';
import 'package:ritmo/features/movement/domain/models/movement_strength_program.dart';
import 'package:sqflite/sqflite.dart';

/// سرویس جامع مدیریت برنامه‌های تمرین قدرتی در خانه (Gate 4)
class StrengthProgramService {
  StrengthProgramService({this.db});

  final Database? db;

  Future<Database> get _database async =>
      db ?? await DatabaseHelper.instance.database;

  // ---------------------------------------------------------------------------
  // خواندن و ذخیره برنامه و پیش‌نویس (Draft)
  // ---------------------------------------------------------------------------

  /// دریافت برنامهٔ جاری (فعال، استراحت دِلود، متوقف یا پیش‌نویس)
  Future<MovementStrengthProgram?> getCurrentProgram() async {
    final dbExec = await _database;
    final rows = await dbExec.query(
      MovementTables.tableStrengthPrograms,
      where: 'status != ?',
      whereArgs: [MovementStrengthProgramStatus.none.name],
      orderBy: 'updatedAt DESC',
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return MovementStrengthProgram.fromMap(rows.first);
  }

  /// دریافت برنامهٔ در وضعیت پیش‌نویس (Draft)
  Future<MovementStrengthProgram?> getDraftProgram() async {
    final dbExec = await _database;
    final rows = await dbExec.query(
      MovementTables.tableStrengthPrograms,
      where: 'status = ?',
      whereArgs: [MovementStrengthProgramStatus.draft.name],
      orderBy: 'updatedAt DESC',
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return MovementStrengthProgram.fromMap(rows.first);
  }

  /// ذخیرهٔ وضعیت پیش‌نویس آنبوردینگ پس از هر گام
  Future<void> saveDraft({
    required String programId,
    required int draftStep,
    String? goal,
    String? level,
    List<String>? sensitiveAreas,
    List<String>? equipment,
    int? daysPerWeek,
    int? sessionMinutes,
    List<int>? preferredDays,
    String? preferredTime,
    Map<String, dynamic>? extraDraftData,
  }) async {
    final dbExec = await _database;
    final now = DateTime.now().toUtc();

    final existing = await getCurrentProgram();

    final draft = MovementStrengthProgram(
      id: programId,
      name: 'برنامهٔ قدرت در خانه',
      goal: goal ?? existing?.goal ?? 'muscle',
      level: level ?? existing?.level ?? 'intermediate',
      sensitiveAreas: sensitiveAreas ?? existing?.sensitiveAreas ?? [],
      equipment: equipment ?? existing?.equipment ?? ['bodyweight'],
      daysPerWeek: daysPerWeek ?? existing?.daysPerWeek ?? 3,
      sessionMinutes: sessionMinutes ?? existing?.sessionMinutes ?? 30,
      preferredDays: preferredDays ?? existing?.preferredDays ?? [1, 3, 5],
      preferredTime: preferredTime ?? existing?.preferredTime ?? '08:00',
      status: MovementStrengthProgramStatus.draft,
      draftStep: draftStep,
      draftDataJson: extraDraftData != null
          ? jsonEncode(extraDraftData)
          : existing?.draftDataJson,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    await dbExec.insert(
      MovementTables.tableStrengthPrograms,
      draft.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---------------------------------------------------------------------------
  // موتور قطعی و Rule-Based تولید برنامهٔ قدرتی
  // ---------------------------------------------------------------------------

  /// تولید برنامهٔ قطعی، کاملاً ریاضی و بدون تصادف بر اساس مشخصات کاربر
  Map<String, dynamic> generateProgramPlan({
    required String goal,
    required String level,
    required List<String> sensitiveAreas,
    required List<String> equipment,
    required int daysPerWeek,
    required int sessionMinutes,
    required List<int> preferredDays,
    String? preferredTime,
  }) {
    // اعتبارسنجی محدودیت‌ها
    if (daysPerWeek < 1 || daysPerWeek > 7) {
      throw ArgumentError(
        'تعداد روزهای تمرین در هفته باید بین ۱ تا ۷ روز باشد.',
      );
    }
    if (preferredDays.isEmpty) {
      throw ArgumentError('حداقل یک روز ترجیحی برای تمرین باید انتخاب شود.');
    }

    final sanitizedDays = preferredDays.take(daysPerWeek).toList();
    if (sanitizedDays.length < daysPerWeek) {
      final allWeekdays = [1, 2, 3, 4, 5, 6, 7];
      for (final d in allWeekdays) {
        if (!sanitizedDays.contains(d) && sanitizedDays.length < daysPerWeek) {
          sanitizedDays.add(d);
        }
      }
    }
    sanitizedDays.sort();

    // پارامترهای ست، تکرار و استراحت متناسب با هدف
    int sets = 3;
    int repsMin = 8;
    int repsMax = 12;
    int restSec = 60;

    switch (goal) {
      case 'strength':
        sets = 4;
        repsMin = 4;
        repsMax = 6;
        restSec = 90;
        break;
      case 'muscle':
        sets = 3;
        repsMin = 8;
        repsMax = 12;
        restSec = 60;
        break;
      case 'endurance':
        sets = 3;
        repsMin = 12;
        repsMax = 18;
        restSec = 45;
        break;
      case 'rehab':
        sets = 2;
        repsMin = 10;
        repsMax = 12;
        restSec = 60;
        break;
      case 'health':
      default:
        sets = 3;
        repsMin = 10;
        repsMax = 15;
        restSec = 60;
        break;
    }

    if (level == 'beginner') {
      if (sets > 3) sets = 3;
      restSec += 15;
    } else if (level == 'advanced') {
      if (sets < 4 && goal != 'rehab') sets = 4;
    }

    final hasDumbbells = equipment.contains('dumbbells');
    final hasBands = equipment.contains('resistance_bands');
    final hasPullup = equipment.contains('pullup_bar');

    final avoidKnees = sensitiveAreas.contains('knees');
    final avoidLowerBack = sensitiveAreas.contains('lower_back');
    final avoidShoulders = sensitiveAreas.contains('shoulders');
    final avoidWrists = sensitiveAreas.contains('wrists');

    final programId = 'sp_${DateTime.now().millisecondsSinceEpoch}';
    const totalWeeks = 6;
    const deloadWeek = 4;

    final program = MovementStrengthProgram(
      id: programId,
      name: 'برنامهٔ قدرت در خانه (${_getGoalLabel(goal)})',
      goal: goal,
      level: level,
      sensitiveAreas: sensitiveAreas,
      equipment: equipment,
      daysPerWeek: daysPerWeek,
      sessionMinutes: sessionMinutes,
      preferredDays: sanitizedDays,
      preferredTime: preferredTime ?? '08:00',
      totalWeeks: totalWeeks,
      currentWeek: 1,
      deloadWeekIndex: deloadWeek,
      status: MovementStrengthProgramStatus.draft,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );

    // تولید روزها و حرکات برای ۶ هفته
    final days = <MovementStrengthDay>[];

    for (int w = 1; w <= totalWeeks; w++) {
      final isDeloadWeek = (w == deloadWeek);
      final weekSets = isDeloadWeek ? (sets > 2 ? sets - 1 : 2) : sets;

      for (int i = 0; i < sanitizedDays.length; i++) {
        final weekday = sanitizedDays[i];
        final dayId = '${programId}_w${w}_d${i + 1}';
        final dayName = _getDaySplitName(i, sanitizedDays.length);
        final targetMuscles = _getTargetMusclesForSplit(
          i,
          sanitizedDays.length,
        );

        final exercises = _generateDeterministicExercises(
          dayId: dayId,
          splitIndex: i,
          totalDays: sanitizedDays.length,
          sets: weekSets,
          repsMin: repsMin,
          repsMax: repsMax,
          restSec: restSec,
          hasDumbbells: hasDumbbells,
          hasBands: hasBands,
          hasPullup: hasPullup,
          avoidKnees: avoidKnees,
          avoidLowerBack: avoidLowerBack,
          avoidShoulders: avoidShoulders,
          avoidWrists: avoidWrists,
        );

        days.add(
          MovementStrengthDay(
            id: dayId,
            programId: programId,
            weekIndex: w,
            weekday: weekday,
            name: isDeloadWeek ? '$dayName (دِلود)' : dayName,
            targetMuscles: targetMuscles,
            estimatedMinutes: sessionMinutes,
            orderIndex: i,
            exercises: exercises,
          ),
        );
      }
    }

    return {'program': program, 'days': days};
  }

  static String _getGoalLabel(String goal) {
    switch (goal) {
      case 'strength':
        return 'افزایش قدرت';
      case 'muscle':
        return 'عضله‌سازی';
      case 'endurance':
        return 'استقامت عضلانی';
      case 'rehab':
        return 'توانبخشی و سلامت مفاصل';
      case 'health':
      default:
        return 'سلامت عمومی و تندرستی';
    }
  }

  static String _getDaySplitName(int index, int totalDays) {
    if (totalDays == 1) return 'تمرین فول بادی کل بدن';
    if (totalDays == 2) return index == 0 ? 'بالاتنه' : 'پایین‌تنه و میان‌تنه';
    if (totalDays == 3) {
      if (index == 0) return 'فول بادی A (سینه و پا)';
      if (index == 1) return 'فول بادی B (زیربغل و شانه)';
      return 'فول بادی C (دست و میان‌تنه)';
    }
    if (totalDays == 4) {
      if (index == 0) return 'بالاتنه قدرتی';
      if (index == 1) return 'پایین‌تنه قدرتی';
      if (index == 2) return 'بالاتنه هایپرتروفی';
      return 'پایین‌تنه و کور';
    }
    return 'جلسهٔ ${index + 1} قدرت';
  }

  static List<String> _getTargetMusclesForSplit(int index, int totalDays) {
    if (totalDays <= 2) {
      return index == 0
          ? ['سینه', 'زیربغل', 'شانه']
          : ['چهارسر ران', 'همسترینگ', 'شکم'];
    }
    if (totalDays == 3) {
      if (index == 0) return ['سینه', 'چهارسر ران', 'پشت‌بازو'];
      if (index == 1) return ['زیربغل', 'همسترینگ', 'جلوبازو'];
      return ['شانه', 'باسن', 'شکم'];
    }
    return ['سینه', 'پشت', 'پاها', 'میان‌تنه'];
  }

  static List<MovementStrengthExercise> _generateDeterministicExercises({
    required String dayId,
    required int splitIndex,
    required int totalDays,
    required int sets,
    required int repsMin,
    required int repsMax,
    required int restSec,
    required bool hasDumbbells,
    required bool hasBands,
    required bool hasPullup,
    required bool avoidKnees,
    required bool avoidLowerBack,
    required bool avoidShoulders,
    required bool avoidWrists,
  }) {
    final list = <MovementStrengthExercise>[];

    // حرکت ۱: سینه / پرس
    String chestEx = 'شنا سوئدی استاندارد';
    if (hasDumbbells && !avoidShoulders) {
      chestEx = 'پرس سینه دمبل روی زمین';
    } else if (hasBands) {
      chestEx = 'پرس سینه با کش مقاومتی';
    }
    if (avoidWrists && chestEx.contains('شنا')) {
      chestEx = 'شنا روی بند انگشتان یا دسته';
    }

    list.add(
      MovementStrengthExercise(
        id: '${dayId}_ex1',
        dayId: dayId,
        orderIndex: 0,
        nameFa: chestEx,
        muscleGroup: 'سینه و پشت‌بازو',
        sets: sets,
        repsMin: repsMin,
        repsMax: repsMax,
        restSec: restSec,
        formTips: const [
          'ستون فقرات را کاملاً صاف نگه دارید.',
          'آرنج‌ها زاویهٔ ۴۵ درجه با بدن داشته باشند.',
          'در دامنهٔ کامل حرکت را اجرا کنید.',
        ],
        alternatives: const [
          'شنا سوئدی روی زانو',
          'شنا با تکیه به دیوار',
          'پرس سینه با کش ورزشی',
        ],
      ),
    );

    // حرکت ۲: زیربغل / کشش
    String backEx = 'سوپرمن روی زمین';
    if (hasPullup) {
      backEx = 'بارفیکس دست باز';
    } else if (hasDumbbells) {
      backEx = avoidLowerBack
          ? 'زیربغل تک دمبل خم با تکیه‌گاه'
          : 'زیربغل دمبل جفت خم';
    } else if (hasBands) {
      backEx = 'زیربغل قایقی با کش ورزشی';
    }

    list.add(
      MovementStrengthExercise(
        id: '${dayId}_ex2',
        dayId: dayId,
        orderIndex: 1,
        nameFa: backEx,
        muscleGroup: 'زیربغل و پشت',
        sets: sets,
        repsMin: repsMin,
        repsMax: repsMax,
        restSec: restSec,
        formTips: const [
          'تیغه‌های شانه را در انتهای حرکت به هم منقبض کنید.',
          'از تکان دادن ناگهانی بالاتنه خودداری کنید.',
          'تنفس پیوسته را حفظ کنید.',
        ],
        alternatives: const [
          'کشش زیربغل با حوله یا کش',
          'سوپرمن دست باز',
          'حرکت پرنده‌سگ (Bird-Dog)',
        ],
      ),
    );

    // حرکت ۳: پاها / اسکات
    String legEx = avoidKnees
        ? 'پل باسن روی زمین (Glute Bridge)'
        : 'اسکات با وزن بدن';
    if (!avoidKnees && hasDumbbells) {
      legEx = 'گابلت اسکات با دمبل';
    } else if (!avoidKnees && hasBands) {
      legEx = 'اسکات با کش ورزشی دور زانو';
    }

    list.add(
      MovementStrengthExercise(
        id: '${dayId}_ex3',
        dayId: dayId,
        orderIndex: 2,
        nameFa: legEx,
        muscleGroup: avoidKnees ? 'باسن و پشت ران' : 'چهارسر ران و باسن',
        sets: sets,
        repsMin: repsMin,
        repsMax: repsMax,
        restSec: restSec,
        formTips: const [
          'سینه را بالا و وزن را روی پاشنه‌ها نگه دارید.',
          'زانوها در راستای پنجهٔ پا حرکت کنند.',
          'هنگام بالا آمدن باسن را منقبض کنید.',
        ],
        alternatives: const [
          'اسکات با تکیه به دیوار (Wall Sit)',
          'پل باسن تک‌پا',
          'لانجز ثابت معکوس',
        ],
      ),
    );

    // حرکت ۴: میان‌تنه / شکم
    String coreEx = avoidWrists ? 'پلانک روی ساعد' : 'پلانک استاندارد';
    if (avoidLowerBack) {
      coreEx = 'کرانچ ساده روی زمین با زانوی خم';
    }

    list.add(
      MovementStrengthExercise(
        id: '${dayId}_ex4',
        dayId: dayId,
        orderIndex: 3,
        nameFa: coreEx,
        muscleGroup: 'عضلات مرکزی شکم و پهلو',
        sets: sets > 3 ? 3 : sets,
        repsMin: 30, // 30 sec or reps
        repsMax: 45,
        restSec: 45,
        formTips: const [
          'شکم را محکم منقبض نگه دارید و گودی کمر ندهید.',
          'نفس را در سینه حبس نکنید.',
          'نگاه به زمین و گردن در وضعیت خنثی باشد.',
        ],
        alternatives: const [
          'پلانک زانو روی زمین',
          'ددباگ (Deadbug)',
          'کرانچ معکوس',
        ],
      ),
    );

    return list;
  }

  // ---------------------------------------------------------------------------
  // فعال‌سازی برنامه در یک تراکنش واحد (Atomic Activation)
  // ---------------------------------------------------------------------------

  /// فعال‌سازی برنامه: ثبت برنامه + روزها + حرکات + رخدادهای تقویم در یک تراکنش
  Future<void> activateProgram({
    required MovementStrengthProgram program,
    required List<MovementStrengthDay> days,
  }) async {
    final dbExec = await _database;
    final now = DateTime.now().toUtc();

    final activeProgram = program.copyWith(
      status: MovementStrengthProgramStatus.active,
      currentWeek: 1,
      updatedAt: now,
    );

    await dbExec.transaction((txn) async {
      // ۱. برنامه‌های قبلی را پایان‌یافته کن
      await txn.update(
        MovementTables.tableStrengthPrograms,
        {
          'status': MovementStrengthProgramStatus.finished.name,
          'updatedAt': now.toIso8601String(),
        },
        where: 'status = ?',
        whereArgs: [MovementStrengthProgramStatus.active.name],
      );

      // ۲. درج یا به‌روزرسانی برنامهٔ فعال جدید
      await txn.insert(
        MovementTables.tableStrengthPrograms,
        activeProgram.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // ۳. پاک‌سازی روزها و حرکات قبلی این برنامه
      await txn.delete(
        MovementTables.tableStrengthDays,
        where: 'programId = ?',
        whereArgs: [program.id],
      );

      // ۴. درج روزها و حرکات
      for (final day in days) {
        await txn.insert(
          MovementTables.tableStrengthDays,
          day.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        for (final exercise in day.exercises) {
          await txn.insert(
            MovementTables.tableStrengthExercises,
            exercise.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      // ۵. ایجاد Occurrenceهای افق برنامه (۶ هفته) با origin = 'strength'
      final today = DateTime.now();
      // پیدا کردن شنبهٔ این هفته (روز آغازین افق)
      final daysSinceSat = (today.weekday == DateTime.saturday)
          ? 0
          : (today.weekday % 7) + 1;
      final thisSaturday = today.subtract(Duration(days: daysSinceSat));

      for (int w = 0; w < activeProgram.totalWeeks; w++) {
        final weekStart = thisSaturday.add(Duration(days: w * 7));
        final weekDays = days.where((d) => d.weekIndex == (w + 1)).toList();

        for (final day in weekDays) {
          // محاسبه تاریخ دقیق این روز در تقویم (شنبه=1)
          final dayDate = weekStart.add(Duration(days: day.weekday - 1));
          final dateIso = dayDate.toIso8601String().substring(0, 10);

          final occId =
              'occ_str_${activeProgram.id}_w${w + 1}_d${day.weekday}_$dateIso';

          await txn.insert(
            MovementTables.tableOccurrences,
            {
              'id': occId,
              'activityKindId': 'kind_strength',
              'templateId': activeProgram.id,
              'scheduleId': day.id,
              'dateIso': dateIso,
              'startTime': activeProgram.preferredTime ?? '08:00',
              'status': MovementOccurrenceStatus.planned.name,
              'goalType': 'duration',
              'goalValue': activeProgram.sessionMinutes.toDouble(),
              'goalUnit': 'دقیقه',
              'origin': MovementOrigin.strength.name,
              'createdAt': now.toIso8601String(),
              'updatedAt': now.toIso8601String(),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  // ---------------------------------------------------------------------------
  // مدیریت وضعیت برنامه (مکث، ادامه، پایان)
  // ---------------------------------------------------------------------------

  /// مکث برنامه
  Future<void> pauseProgram(String programId) async {
    final dbExec = await _database;
    await dbExec.update(
      MovementTables.tableStrengthPrograms,
      {
        'status': MovementStrengthProgramStatus.paused.name,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [programId],
    );
  }

  /// ادامهٔ برنامهٔ متوقف‌شده
  Future<void> resumeProgram(String programId) async {
    final dbExec = await _database;
    await dbExec.update(
      MovementTables.tableStrengthPrograms,
      {
        'status': MovementStrengthProgramStatus.active.name,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [programId],
    );
  }

  /// پایان دورهٔ برنامه
  Future<void> finishProgram(String programId) async {
    final dbExec = await _database;
    await dbExec.update(
      MovementTables.tableStrengthPrograms,
      {
        'status': MovementStrengthProgramStatus.finished.name,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [programId],
    );
  }

  // ---------------------------------------------------------------------------
  // خواندن روزها و حرکات برنامه
  // ---------------------------------------------------------------------------

  /// دریافت روزهای برنامه همراه با لیست حرکات هر روز
  Future<List<MovementStrengthDay>> getProgramDays(
    String programId, {
    int? weekIndex,
  }) async {
    final dbExec = await _database;

    String where = 'programId = ?';
    final List<dynamic> whereArgs = [programId];

    if (weekIndex != null) {
      where += ' AND weekIndex = ?';
      whereArgs.add(weekIndex);
    }

    final dayRows = await dbExec.query(
      MovementTables.tableStrengthDays,
      where: where,
      whereArgs: whereArgs,
      orderBy: 'weekIndex ASC, orderIndex ASC',
    );

    final result = <MovementStrengthDay>[];

    for (final r in dayRows) {
      final dayId = r['id'] as String;
      final exRows = await dbExec.query(
        MovementTables.tableStrengthExercises,
        where: 'dayId = ?',
        whereArgs: [dayId],
        orderBy: 'orderIndex ASC',
      );

      final exercises = exRows
          .map((e) => MovementStrengthExercise.fromMap(e))
          .toList();
      result.add(MovementStrengthDay.fromMap(r, exercises: exercises));
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // جایگزینی حرکت (Swap Exercise)
  // ---------------------------------------------------------------------------

  /// جایگزینی حرکت با دامنهٔ «فقط امروز» یا «در کل برنامه»
  Future<void> swapExercise({
    required String exerciseId,
    required String newExerciseNameFa,
    required String newMuscleGroup,
    required MovementChangeScope scope,
    String? dayId,
    String? programId,
  }) async {
    final dbExec = await _database;

    if (scope == MovementChangeScope.onlyThis || dayId != null) {
      // فقط همین حرکت در همین روز
      await dbExec.update(
        MovementTables.tableStrengthExercises,
        {'nameFa': newExerciseNameFa, 'muscleGroup': newMuscleGroup},
        where: 'id = ?',
        whereArgs: [exerciseId],
      );
    } else {
      // در تمام روزهای آینده برنامه
      final exRow = await dbExec.query(
        MovementTables.tableStrengthExercises,
        where: 'id = ?',
        whereArgs: [exerciseId],
        limit: 1,
      );
      if (exRow.isNotEmpty) {
        final currentName = exRow.first['nameFa'] as String;
        await dbExec.update(
          MovementTables.tableStrengthExercises,
          {'nameFa': newExerciseNameFa, 'muscleGroup': newMuscleGroup},
          where: 'nameFa = ?',
          whereArgs: [currentName],
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // ثبت و خواندن لاگ ست‌ها (Set Logs)
  // ---------------------------------------------------------------------------

  /// ثبت یا به‌روزرسانی لاگ یک ست
  Future<void> recordSetLog(MovementSetLog log) async {
    final dbExec = await _database;
    await dbExec.insert(
      MovementTables.tableSetLogs,
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// دریافت ست‌های ثبت‌شده برای یک جلسه
  Future<List<MovementSetLog>> getSetLogsForSession(String sessionId) async {
    final dbExec = await _database;
    final rows = await dbExec.query(
      MovementTables.tableSetLogs,
      where: 'sessionId = ?',
      whereArgs: [sessionId],
      orderBy: 'at ASC, setIndex ASC',
    );
    return rows.map((r) => MovementSetLog.fromMap(r)).toList();
  }

  /// دریافت ست‌های جلسهٔ قبل برای یک حرکت جهت نمایش به صورت Hint
  Future<List<MovementSetLog>> getPreviousSessionSetLogs(
    String exerciseNameFa,
  ) async {
    final dbExec = await _database;
    // یافتن آخرین لاگ‌های این حرکت از جلسات پیشین
    final rows = await dbExec.rawQuery(
      '''
      SELECT s.*
      FROM ${MovementTables.tableSetLogs} s
      INNER JOIN ${MovementTables.tableStrengthExercises} e ON s.exerciseId = e.id
      WHERE e.nameFa = ? AND s.completed = 1
      ORDER BY s.at DESC
      LIMIT 10
    ''',
      [exerciseNameFa],
    );

    return rows.map((r) => MovementSetLog.fromMap(r)).toList();
  }
}
