import 'package:ritmo/core/ai/agent/intent/ritmo_date_parser.dart';
import 'package:ritmo/core/ai/ai_context_builder.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/commands/ritmo_command.dart';

class RagResult {
  // فقط aggregate
  const RagResult({
    this.blocked = false,
    this.blockReason,
    this.blockMessage,
    this.data = const {},
  });
  final bool blocked;
  final String? blockReason; // 'cycle_no_consent' | 'medical'
  final String? blockMessage; // متن فارسی ثابت برای نمایش بدون LLM
  final Map<String, dynamic> data;
}

/// بازیابی دادهٔ تجمیعی برای گفتگو (فاز ۴ · P4-3)
///
/// سه اصلاح نسبت به نسخهٔ قبلی:
///  ۱. تشخیص نیت در سطح توکن (با پیشوند) انجام می‌شود نه زیررشتهٔ خام؛
///     پس «مدرسه» دیگر نیت «درس» را فعال نمی‌کند ولی «خوابم» هنوز کار می‌کند.
///  ۲. بازهٔ زمانی از متن کاربر با RitmoDateParser حل می‌شود؛ قبلا همیشه ۳۰ روز
///     ثابت بود و پاسخ «این هفته چند بار ورزش کردم؟» عملا عدد ۳۰ روز را می‌داد.
///  ۳. بازهٔ واقعی در خروجی برگردانده می‌شود (کلید `window`) تا مدل نتواند عدد
///     تجمیعی را به بازهٔ دیگری نسبت دهد.
///
/// نگهبان حریم خصوصی عمدا سخت‌گیرانه و زیررشته‌ای مانده است (دو شکل نرمال‌شده
/// بررسی می‌شود) تا هیچ نوشتهٔ حساسی از فیلتر نگذرد.
class ConversationRAG {
  static final RegExp _splitter = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

  static List<String> _tokenize(String input) => RitmoDateParser.normalize(
    input,
  ).split(_splitter).where((t) => t.isNotEmpty).toList();

  /// تطبیق نیت: برابری توکن یا پیشوند بودن (برای پسوندهای فارسی)
  static bool _hasIntent(
    List<String> tokens,
    String joined,
    List<String> keywords,
  ) {
    for (final raw in keywords) {
      final keyword = RitmoDateParser.normalize(raw);
      if (keyword.isEmpty) continue;
      if (keyword.contains(' ')) {
        if (joined.contains(' $keyword ')) return true;
        continue;
      }
      for (final token in tokens) {
        if (token == keyword) return true;
        if (token.length > keyword.length && token.startsWith(keyword)) {
          return true;
        }
      }
    }
    return false;
  }

  /// نگهبان دادهٔ حساس: زیررشته‌ای روی دو شکل نرمال‌شده
  static bool _hasSensitive(
    String normalized,
    String spaced,
    List<String> keywords,
  ) {
    for (final raw in keywords) {
      final keyword = RitmoDateParser.normalize(raw);
      if (keyword.isEmpty) continue;
      if (normalized.contains(keyword) || spaced.contains(keyword)) return true;
    }
    return false;
  }

  static DateTime _dayOf(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  Future<RagResult> retrieve({
    required String query,
    required ConsentProfile consent,
    DateTime? now,
  }) async {
    // 1) Privacy Guard
    final normalized = RitmoDateParser.normalize(query);
    final spaced = RitmoDateParser.normalize(query.replaceAll('\u200c', ' '));

    final cycleKeywords = [
      'چرخه قاعدگی',
      'سیکل قاعدگی',
      'قاعدگی',
      'پریود',
      'پریودی',
      'عادت ماهیانه',
      'بارداری',
      'menstrual',
      'period',
      'pregnancy',
      'contraceptive',
    ];
    final medicalKeywords = [
      'دارو',
      'داروها',
      'دوز',
      'قرص',
      'آمپول',
      'نسخه',
      'بیماری',
      'درمان',
      'پزشک',
      'پزشکی',
      'medicine',
      'medication',
      'medical',
      'dose',
      'dosage',
      'prescription',
    ];

    final hasCycleKeyword = _hasSensitive(normalized, spaced, cycleKeywords);
    final hasMedicalKeyword = _hasSensitive(
      normalized,
      spaced,
      medicalKeywords,
    );

    if (hasCycleKeyword &&
        !consent.readableDomains.contains(DataDomain.cycle)) {
      return const RagResult(
        blocked: true,
        blockReason: 'cycle_no_consent',
        blockMessage:
            'برای دسترسی به اطلاعات چرخه قاعدگی، می‌توانید ماژول چرخه را در بخش مدیریت ماژول‌ها یا تنظیمات برنامه فعال کنید.',
      );
    }

    if (hasMedicalKeyword &&
        !consent.readableDomains.contains(DataDomain.medical)) {
      return const RagResult(
        blocked: true,
        blockReason: 'medical',
        blockMessage:
            'برای حفظ ایمنی، اطلاعات پزشکی و یادآورهای دارویی از طریق دستیار مدیریت نمی‌شوند؛ لطفا این موارد را مستقیما در بخش سلامت مدیریت کنید.',
      );
    }

    // 2) تشخیص نیت در سطح توکن
    final tokens = _tokenize(query);
    if (tokens.isEmpty) return const RagResult();
    final joined = ' ${tokens.join(' ')} ';

    // 3) بازهٔ زمانی: از متن کاربر، وگرنه ۳۰ روز اخیر
    final today = _dayOf(now ?? DateTime.now());
    final parsed = RitmoDateParser.parse(query, now: today);
    var windowStart = today.subtract(const Duration(days: 29));
    var windowEnd = today;
    var windowLabel = '۳۰ روز گذشته';
    if (parsed.matched && !parsed.start.isAfter(today)) {
      windowStart = parsed.start;
      windowEnd = parsed.end.isAfter(today) ? today : parsed.end;
      windowLabel = parsed.labelFa;
    }

    final fromIso = RitmoDateParser.iso(windowStart);
    final toIso = RitmoDateParser.iso(windowEnd);
    final fromMs = windowStart.millisecondsSinceEpoch;
    final toMsExclusive = windowEnd
        .add(const Duration(days: 1))
        .millisecondsSinceEpoch;

    final retrievedData = <String, dynamic>{};

    final hasFitness = _hasIntent(tokens, joined, <String>[
      'ورزش',
      'تمرین',
      'دویدن',
      'فیتنس',
      'باشگاه',
      'پیادهروی',
      'کاردیو',
      'بدنسازی',
      'running',
    ]);
    final hasStudy = _hasIntent(tokens, joined, <String>[
      'مطالعه',
      'درس',
      'درسها',
      'کتاب',
      'کنکور',
      'آزمون',
      'تست',
    ]);
    final hasPrayer = _hasIntent(tokens, joined, <String>[
      'نماز',
      'واجب',
      'عبادت',
      'دعا',
      'ذکر',
      'قضا',
      'قرآن',
      'قران',
    ]);
    final hasSleep = _hasIntent(tokens, joined, <String>[
      'خواب',
      'بیدار',
      'بیخوابی',
      'bedtime',
    ]);
    final hasEnergy = _hasIntent(tokens, joined, <String>[
      'انرژی',
      'خلق',
      'روحیه',
      'خستگی',
      'حوصله',
      'mood',
    ]);
    final hasGoals = _hasIntent(tokens, joined, <String>[
      'هدف',
      'اهداف',
      'پیشرفت',
      'گام',
    ]);
    final hasReflection = _hasIntent(tokens, joined, <String>[
      'تأمل',
      'تامل',
      'بازتاب',
      'خودارزیاب',
      'روزنگار',
    ]);

    if (hasFitness && consent.readableDomains.contains(DataDomain.sports)) {
      retrievedData['fitness'] = await _fetchRoutineStats(
        'fitness',
        fromIso,
        toIso,
      );
    }
    if (hasStudy &&
        (consent.readableDomains.contains(DataDomain.courses) ||
            consent.readableDomains.contains(DataDomain.konkur))) {
      retrievedData['study'] = await _fetchStudyStats(fromIso, toIso);
    }
    if (hasPrayer && consent.readableDomains.contains(DataDomain.worship)) {
      retrievedData['worship'] = await _fetchWorshipStats();
    }
    if (hasSleep && consent.readableDomains.contains(DataDomain.sleep)) {
      retrievedData['sleep'] = await _fetchSleepStats(fromMs, toMsExclusive);
    }
    if (hasEnergy && consent.readableDomains.contains(DataDomain.energy)) {
      retrievedData['energy'] = await _fetchEnergyStats(fromMs, toMsExclusive);
    }
    if (hasGoals && consent.readableDomains.contains(DataDomain.goals)) {
      retrievedData['goals'] = await _fetchGoalStats();
    }
    if (hasReflection &&
        consent.readableDomains.contains(DataDomain.reflection)) {
      retrievedData['reflection'] = await _fetchReflectionStats(
        fromMs,
        toMsExclusive,
      );
    }

    if (retrievedData.isEmpty) return const RagResult();

    // بازه را صریح برمی‌گردانیم تا مدل عدد را به بازهٔ اشتباه نچسباند.
    retrievedData['window'] = <String, dynamic>{
      'from': fromIso,
      'to': toIso,
      'days': windowEnd.difference(windowStart).inDays + 1,
      'labelFa': windowLabel,
      'matchedFromUserText': parsed.matched,
    };

    return RagResult(data: retrievedData);
  }

  Future<Map<String, dynamic>> _fetchRoutineStats(
    String category,
    String fromIso,
    String toIso,
  ) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.rawQuery(
        '''
        SELECT 
          SUM(CASE WHEN rc.resultType = 'COMPLETE' THEN 1 ELSE 0 END) as completed,
          SUM(CASE WHEN rc.resultType = 'SNOOZE' THEN 1 ELSE 0 END) as skipped,
          COUNT(*) as total
        FROM routine_completions rc
        JOIN routines r ON rc.routineId = r.id
        WHERE r.category = ? AND rc.completionDate >= ? AND rc.completionDate <= ?
      ''',
        [category, fromIso, toIso],
      );
      if (result.isEmpty) return {'completed': 0, 'skipped': 0, 'total': 0};
      return {
        'completed': result.first['completed'] ?? 0,
        'skipped': result.first['skipped'] ?? 0,
        'total': result.first['total'] ?? 0,
      };
    } catch (_) {
      return {'completed': 0, 'skipped': 0, 'total': 0};
    }
  }

  Future<Map<String, dynamic>> _fetchStudyStats(
    String fromIso,
    String toIso,
  ) async {
    try {
      final db = await DatabaseHelper.instance.database;

      final konkurResult = await db.rawQuery(
        '''
        SELECT SUM(durationMinutes) as minutes, COUNT(*) as count 
        FROM konkur_study_sessions 
        WHERE dateIso >= ? AND dateIso <= ?
      ''',
        [fromIso, toIso],
      );
      final konkurMins = (konkurResult.first['minutes'] as num?)?.toInt() ?? 0;
      final konkurCount = (konkurResult.first['count'] as num?)?.toInt() ?? 0;

      final courseResult = await db.rawQuery(
        '''
        SELECT SUM(actualDurationMinutes) as minutes, COUNT(*) as count 
        FROM course_sessions 
        WHERE plannedDate >= ? AND plannedDate <= ? AND completionStatus = 'COMPLETED'
      ''',
        [fromIso, toIso],
      );
      final courseMins = (courseResult.first['minutes'] as num?)?.toInt() ?? 0;
      final courseCount = (courseResult.first['count'] as num?)?.toInt() ?? 0;

      return {
        'total_minutes': konkurMins + courseMins,
        'sessions': konkurCount + courseCount,
      };
    } catch (_) {
      return {'total_minutes': 0, 'sessions': 0};
    }
  }

  Future<Map<String, dynamic>> _fetchWorshipStats() async {
    try {
      final db = await DatabaseHelper.instance.database;

      final practicesResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM worship_practices WHERE isActive = 1',
      );
      final practicesCount =
          (practicesResult.first['count'] as num?)?.toInt() ?? 0;

      final debtsResult = await db.rawQuery(
        'SELECT SUM(debtCount) as count FROM worship_debts',
      );
      final debtsCount = (debtsResult.first['count'] as num?)?.toInt() ?? 0;

      return {'practices_count': practicesCount, 'debts_count': debtsCount};
    } catch (_) {
      return {'practices_count': 0, 'debts_count': 0};
    }
  }

  Future<Map<String, dynamic>> _fetchSleepStats(
    int fromMs,
    int toMsExclusive,
  ) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.rawQuery(
        '''
        SELECT AVG(quality) as avg_quality, COUNT(*) as count 
        FROM bedtime_diagnostics 
        WHERE createdAt >= ? AND createdAt < ?
      ''',
        [fromMs, toMsExclusive],
      );
      if (result.isEmpty) return {'avg_quality': 0.0, 'entries': 0};
      return {
        'avg_quality': (result.first['avg_quality'] as num?)?.toDouble() ?? 0.0,
        'entries': (result.first['count'] as num?)?.toInt() ?? 0,
      };
    } catch (_) {
      return {'avg_quality': 0.0, 'entries': 0};
    }
  }

  Future<Map<String, dynamic>> _fetchEnergyStats(
    int fromMs,
    int toMsExclusive,
  ) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.rawQuery(
        '''
        SELECT 
          COUNT(*) as entries,
          SUM(CASE WHEN energyLevel = 'LOW' THEN 1 ELSE 0 END) as low_count,
          SUM(CASE WHEN energyLevel = 'HIGH' THEN 1 ELSE 0 END) as high_count
        FROM energy_logs 
        WHERE loggedAt >= ? AND loggedAt < ?
      ''',
        [fromMs, toMsExclusive],
      );
      if (result.isEmpty)
        return {'entries': 0, 'low_count': 0, 'high_count': 0};
      return {
        'entries': (result.first['entries'] as num?)?.toInt() ?? 0,
        'low_count': (result.first['low_count'] as num?)?.toInt() ?? 0,
        'high_count': (result.first['high_count'] as num?)?.toInt() ?? 0,
      };
    } catch (_) {
      return {'entries': 0, 'low_count': 0, 'high_count': 0};
    }
  }

  Future<Map<String, dynamic>> _fetchGoalStats() async {
    try {
      final db = await DatabaseHelper.instance.database;

      final activeGoalsResult = await db.rawQuery(
        "SELECT COUNT(*) as count FROM goals WHERE status = 'ACTIVE'",
      );
      final activeCount =
          (activeGoalsResult.first['count'] as num?)?.toInt() ?? 0;

      final stepsResult = await db.rawQuery('''
        SELECT 
          SUM(CASE WHEN gs.isCompleted = 1 THEN 1 ELSE 0 END) as completed_steps,
          COUNT(*) as total_steps
        FROM goal_steps gs
        JOIN goals g ON gs.goalId = g.id
        WHERE g.status = 'ACTIVE'
      ''');

      return {
        'active': activeCount,
        'completed_steps':
            (stepsResult.first['completed_steps'] as num?)?.toInt() ?? 0,
        'total_steps': (stepsResult.first['total_steps'] as num?)?.toInt() ?? 0,
      };
    } catch (_) {
      return {'active': 0, 'completed_steps': 0, 'total_steps': 0};
    }
  }

  Future<Map<String, dynamic>> _fetchReflectionStats(
    int fromMs,
    int toMsExclusive,
  ) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.rawQuery(
        '''
        SELECT AVG(mood_score) as avg_mood, COUNT(*) as count 
        FROM daily_reflections 
        WHERE createdAt >= ? AND createdAt < ? AND isPrivate = 0
      ''',
        [fromMs, toMsExclusive],
      );
      if (result.isEmpty) return {'count': 0, 'avg_mood': 0.0};
      return {
        'count': (result.first['count'] as num?)?.toInt() ?? 0,
        'avg_mood': (result.first['avg_mood'] as num?)?.toDouble() ?? 0.0,
      };
    } catch (_) {
      return {'count': 0, 'avg_mood': 0.0};
    }
  }
}
