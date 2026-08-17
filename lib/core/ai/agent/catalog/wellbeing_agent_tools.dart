import 'package:ritmo/core/ai/agent/agent_tool.dart';
import 'package:ritmo/core/ai/agent/catalog/kernel_command_tool.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/commands/command_plan.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';

/// ۱. ابزار خواندن سابقهٔ خواب
///
/// ستون‌های واقعی bedtime_diagnostics: date / durationMinutes / quality / createdAt.
/// نسخهٔ قبلی با `orderBy: 'timestamp DESC'` کوئری می‌زد که همیشه خطای
/// «no such column: timestamp» می‌داد، خطا را می‌بلعید و لیست خالی را به عنوان
/// «دادهٔ معتبر» تحویل می‌داد.
class GetSleepDiagnosticsTool extends AgentTool {
  const GetSleepDiagnosticsTool()
      : super(
          name: 'get_sleep_diagnostics',
          categoryFa: 'خواب و انرژی',
          titleFa: 'گزارش وضعیت خواب',
          descriptionFa:
              'شب‌های اخیر ثبت‌شدهٔ خواب (تاریخ، مدت خواب و کیفیت) را به همراه میانگین مدت خواب بازمی‌گرداند.',
          policy: ToolPolicy.readOnly,
          parameters: const [
            ToolParameter(
              name: 'days',
              descriptionFa: 'تعداد شب‌های اخیر (پیش‌فرض ۷، حداکثر ۳۰)',
              type: 'int',
              defaultValue: 7,
            ),
          ],
        );

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    final days = KernelCommandTool.clampedInt(args['days'], 7, 1, 30);
    final db = await DatabaseHelper.instance.database;

    List<Map<String, Object?>> rows;
    try {
      rows = await db.rawQuery('''
        SELECT date, durationMinutes, quality, createdAt
        FROM bedtime_diagnostics
        ORDER BY date DESC
        LIMIT ?
      ''', [days]);
    } catch (e, st) {
      RitmoLog.error('GetSleepDiagnosticsTool', 'bedtime_diagnostics query failed', e, st);
      return AgentToolResult.failure(
        toolName: name,
        errorMessage:
            'خواندن دفتر خواب با خطا متوقف شد، پس هیچ داده‌ای در دست نیست. نتیجه‌گیری نکن که کاربر خوابش را ثبت نکرده: $e',
      );
    }

    if (rows.isEmpty) {
      return AgentToolResult.success(
        toolName: name,
        data: {'nights': <Map<String, dynamic>>[], 'count': 0},
        summaryFa:
            'در $days شب گذشته هیچ رکورد خوابی ثبت نشده است (جدول خوانده شد و خالی بود).',
      );
    }

    final nights = rows
        .map((r) => <String, dynamic>{
              'date': r['date'],
              'durationMinutes': r['durationMinutes'],
              'quality': r['quality'],
            })
        .toList();

    final durations = rows
        .map((r) => (r['durationMinutes'] as num?)?.toInt())
        .whereType<int>()
        .toList();

    int? avgMinutes;
    if (durations.isNotEmpty) {
      final sum = durations.reduce((a, b) => a + b);
      avgMinutes = (sum / durations.length).round();
    }

    final avgLabel = avgMinutes == null
        ? 'نامشخص'
        : '${(avgMinutes / 60).floor()} ساعت و ${avgMinutes % 60} دقیقه';

    return AgentToolResult.success(
      toolName: name,
      data: {
        'count': nights.length,
        'averageDurationMinutes': avgMinutes,
        'averageDurationLabelFa': avgLabel,
        'nights': nights,
      },
      summaryFa:
          '${nights.length} شب ثبت‌شده یافت شد؛ میانگین مدت خواب $avgLabel. آخرین رکورد: ${rows.first['date']}.',
    );
  }
}

/// ۲. ابزار روند انرژی و حال
///
/// ستون‌های واقعی: energy_logs(id, energyLevel, source, note, loggedAt) و
/// mood_logs(id, mood, valence, note, loggedAt).
class GetEnergyTrendsTool extends AgentTool {
  const GetEnergyTrendsTool()
      : super(
          name: 'get_energy_trends',
          categoryFa: 'خواب و انرژی',
          titleFa: 'روند انرژی و حال',
          descriptionFa:
              'ثبت‌های اخیر سطح انرژی (بالا/متوسط/پایین) و حال کاربر را با شمارش هر سطح بازمی‌گرداند.',
          policy: ToolPolicy.readOnly,
          parameters: const [
            ToolParameter(
              name: 'days',
              descriptionFa: 'بازهٔ مورد نظر به روز (پیش‌فرض ۷، حداکثر ۳۰)',
              type: 'int',
              defaultValue: 7,
            ),
          ],
        );

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    final days = KernelCommandTool.clampedInt(args['days'], 7, 1, 30);
    final limit = days * 3;
    final db = await DatabaseHelper.instance.database;

    List<Map<String, Object?>> energyRows;
    try {
      energyRows = await db.rawQuery('''
        SELECT energyLevel, source, note, loggedAt
        FROM energy_logs
        ORDER BY loggedAt DESC
        LIMIT ?
      ''', [limit]);
    } catch (e, st) {
      RitmoLog.error('GetEnergyTrendsTool', 'energy_logs query failed', e, st);
      return AgentToolResult.failure(
        toolName: name,
        errorMessage:
            'خواندن ثبت‌های انرژی با خطا متوقف شد و هیچ داده‌ای در دست نیست: $e',
      );
    }

    // حال/مود در جدول جداگانه است؛ اگر خواندنش شکست خورد، بخش انرژی را
    // خراب نمی‌کنیم ولی صریحاً اعلام می‌کنیم که ناقص است (نه سکوت).
    List<Map<String, Object?>> moodRows = const [];
    String? moodError;
    try {
      moodRows = await db.rawQuery('''
        SELECT mood, valence, note, loggedAt
        FROM mood_logs
        ORDER BY loggedAt DESC
        LIMIT ?
      ''', [limit]);
    } catch (e, st) {
      RitmoLog.error('GetEnergyTrendsTool', 'mood_logs query failed', e, st);
      moodError = 'خواندن ثبت‌های حال ممکن نشد: $e';
    }

    var high = 0;
    var medium = 0;
    var low = 0;
    for (final r in energyRows) {
      final level = (r['energyLevel'] ?? '').toString().toUpperCase();
      if (level == 'HIGH') {
        high++;
      } else if (level == 'MEDIUM') {
        medium++;
      } else if (level == 'LOW') {
        low++;
      }
    }

    final summary = StringBuffer();
    if (energyRows.isEmpty) {
      summary.write('هیچ ثبت انرژی‌ای پیدا نشد (جدول خوانده شد و خالی بود).');
    } else {
      summary.write(
        '${energyRows.length} ثبت انرژی یافت شد: $high بار بالا، $medium بار متوسط، $low بار پایین.',
      );
    }
    if (moodError != null) {
      summary.write(' هشدار: بخش حال ناقص است.');
    } else if (moodRows.isNotEmpty) {
      summary.write(' همچنین ${moodRows.length} ثبت حال وجود دارد.');
    }

    return AgentToolResult.success(
      toolName: name,
      data: {
        'energyCount': energyRows.length,
        'highCount': high,
        'mediumCount': medium,
        'lowCount': low,
        'energyLogs': energyRows
            .map((r) => <String, dynamic>{
                  'level': r['energyLevel'],
                  'note': r['note'],
                  'loggedAt': r['loggedAt'],
                })
            .toList(),
        'moodLogs': moodRows
            .map((r) => <String, dynamic>{
                  'mood': r['mood'],
                  'valence': r['valence'],
                  'note': r['note'],
                  'loggedAt': r['loggedAt'],
                })
            .toList(),
        'moodError': ?moodError,
      },
      summaryFa: summary.toString(),
    );
  }
}

/// ۳. ابزار ثبت سطح انرژی و حال — فاز ۲: روی فرمان‌های باس
///
/// نسخهٔ قبلی مستقیم در energy_logs و mood_logs با ستون‌های موهوم (level، score،
/// timestamp) می‌نوشت، خطا را می‌بلعید و بعد می‌گفت «ثبت شد». اکنون از فرمان
/// `energy.log` (و در صورت وجود حال، `reflection.log`) در یک تراکنش عبور می‌کند.
///
/// توجه: دامنهٔ energy به ماژول انرژی گیت شده است؛ اگر کاربر آن ماژول را
/// روشن نکرده باشد، PersonaGate نوشتن را می‌بندد و این ابزار همان دلیل را عیناً
/// برمی‌گرداند تا مدل بتواند کاربر را راهنمایی کند — نه اینکه ادعای موفقیت کند.
class LogEnergyMoodLevelTool extends KernelCommandTool {
  const LogEnergyMoodLevelTool()
      : super(
          name: 'log_energy_mood_level',
          categoryFa: 'خواب و انرژی',
          titleFa: 'ثبت سطح انرژی و حال',
          descriptionFa:
              'سطح انرژی کاربر را ثبت می‌کند و اگر حالش را هم گفته باشد، همزمان در دفتر حال ثبت می‌کند. وقتی کاربر می‌گوید انرژی‌اش کم/زیاد است یا حالش را توصیف می‌کند، این را صدا بزن.',
          commandId: 'energy.log',
          policy: ToolPolicy.actionDirect,
          parameters: const [
            ToolParameter(
              name: 'energyLevel',
              descriptionFa:
                  'سطح انرژی: HIGH یا MEDIUM یا LOW (عدد ۱ تا ۵ هم پذیرفته می‌شود)',
              type: 'string',
              isRequired: true,
            ),
            ToolParameter(
              name: 'mood',
              descriptionFa:
                  'حال کاربر (اختیاری): neutral یا happy یا sad یا stressed یا calm',
              type: 'string',
            ),
            ToolParameter(
              name: 'note',
              descriptionFa: 'یادداشت کوتاه اختیاری دربارهٔ علت',
              type: 'string',
            ),
          ],
        );

  /// مپینگ ورودی آزاد مدل به سه مقدار مجاز فرمان.
  static String _normalizeEnergy(dynamic raw) {
    final s = KernelCommandTool.optionalString(raw);
    if (s == null) {
      throw const ToolArgumentError(
        'سطح انرژی الزامی است: یکی از HIGH یا MEDIUM یا LOW را بفرست.',
      );
    }

    final upper = KernelCommandTool.toEnglishDigits(s).toUpperCase().trim();
    if (upper == 'HIGH' || upper == 'MEDIUM' || upper == 'LOW') return upper;

    if (upper == 'بالا' || upper == 'زیاد' || upper == 'خوب') return 'HIGH';
    if (upper == 'متوسط' || upper == 'معمولی') return 'MEDIUM';
    if (upper == 'پایین' || upper == 'کم' || upper == 'بد') return 'LOW';

    final numeric = int.tryParse(upper);
    if (numeric != null) {
      if (numeric <= 2) return 'LOW';
      if (numeric == 3) return 'MEDIUM';
      if (numeric >= 4) return 'HIGH';
    }

    throw ToolArgumentError(
      'سطح انرژی «$s» قابل تفسیر نیست. فقط HIGH یا MEDIUM یا LOW (یا عدد ۱ تا ۵) مجاز است.',
    );
  }

  /// مقادیر مجاز فرمان reflection.log
  static const List<String> _moods = <String>[
    'neutral',
    'happy',
    'sad',
    'stressed',
    'calm',
  ];

  static String? _normalizeMood(dynamic raw) {
    final s = KernelCommandTool.optionalString(raw);
    if (s == null) return null;
    final lower = s.toLowerCase().trim();
    if (_moods.contains(lower)) return lower;

    if (lower == 'خوب' || lower == 'شاد' || lower == 'عالی') return 'happy';
    if (lower == 'بد' || lower == 'ناراحت' || lower == 'غمگین') return 'sad';
    if (lower == 'مضطرب' || lower == 'استرس' || lower == 'پراسترس') return 'stressed';
    if (lower == 'آرام' || lower == 'ریلکس') return 'calm';
    if (lower == 'معمولی' || lower == 'عادی') return 'neutral';

    throw ToolArgumentError(
      'حال «$s» معتبر نیست. فقط یکی از این‌ها مجاز است: ${_moods.join(', ')}.',
    );
  }

  @override
  Future<List<PlanStep>> buildSteps(Map<String, dynamic> args) async {
    final level = _normalizeEnergy(args['energyLevel'] ?? args['level']);
    final note = KernelCommandTool.optionalString(args['note']);
    final mood = _normalizeMood(args['mood'] ?? args['moodScore']);

    final steps = <PlanStep>[
      PlanStep(
        commandId: commandId,
        payload: <String, dynamic>{
          'energyLevel': level,
          'note': ?note,
        },
        note: 'ثبت‌شده در گفت‌وگو با دستیار',
      ),
    ];

    if (mood != null) {
      // فرمان reflection.log یادداشت را الزامی می‌خواهد؛ متن ساختگی نمی‌سازیم،
      // فقط منبع واقعی ثبت را می‌نویسیم.
      steps.add(
        PlanStep(
          commandId: 'reflection.log',
          payload: <String, dynamic>{
            'note': note ?? 'ثبت حال در گفت‌وگو با دستیار',
            'mood': mood,
          },
          note: 'ثبت‌شده در گفت‌وگو با دستیار',
        ),
      );
    }

    return steps;
  }

  @override
  String buildSummaryFa(Map<String, dynamic> args, Map<String, dynamic> output) {
    final level = _normalizeEnergy(args['energyLevel'] ?? args['level']);
    const labels = <String, String>{
      'HIGH': 'بالا',
      'MEDIUM': 'متوسط',
      'LOW': 'پایین',
    };
    final mood = _normalizeMood(args['mood'] ?? args['moodScore']);
    final moodPart = mood == null ? '' : ' و حال «$mood» هم ثبت شد';
    return 'سطح انرژی «${labels[level] ?? level}» برای امروز ثبت شد$moodPart.';
  }
}
