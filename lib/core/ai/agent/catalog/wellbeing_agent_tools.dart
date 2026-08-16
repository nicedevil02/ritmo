import 'package:ritmo/core/ai/agent/agent_tool.dart';
import 'package:ritmo/core/database/database_helper.dart';

/// ۱. ابزار دریافت سوابق و تحلیل خواب
class GetSleepDiagnosticsTool extends AgentTool {
  const GetSleepDiagnosticsTool()
      : super(
          name: 'get_sleep_diagnostics',
          categoryFa: 'خواب و بازیابی',
          titleFa: 'سوابق و تحلیل خواب',
          descriptionFa: 'اطلاعات ساعت خواب، زمان بیداری، کیفیت خواب و کسر خواب کاربر را در چند روز اخیر برمی‌گرداند.',
          policy: ToolPolicy.readOnly,
          parameters: const [
            ToolParameter(
              name: 'days',
              descriptionFa: 'تعداد روزهای مورد بررسی (پیش‌فرض ۷ روز)',
              type: 'int',
              defaultValue: 7,
            ),
          ],
        );

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    final days = (args['days'] is int)
        ? args['days'] as int
        : (int.tryParse(args['days']?.toString() ?? '7') ?? 7);

    final db = await DatabaseHelper.instance.database;
    final logs = <Map<String, dynamic>>[];

    try {
      final rows = await db.query('bedtime_diagnostics', orderBy: 'timestamp DESC', limit: days);
      logs.addAll(rows);
    } catch (_) {}

    if (logs.isEmpty) {
      return AgentToolResult.success(
        toolName: name,
        data: {'logs': [], 'count': 0},
        summaryFa: 'هیچ لاگ خوابی در $days روز گذشته ثبت نشده است.',
      );
    }

    final formatted = logs.map((l) => {
      'bedtime': l['bedtime'] ?? l['targetBedtime'],
      'wakeTime': l['wakeTime'] ?? l['targetWakeTime'],
      'quality': l['qualityRating'] ?? l['quality'] ?? 'ثبت‌نشده',
      'sleepDebtMinutes': l['sleepDebtMinutes'] ?? 0,
      'date': l['date'] ?? l['timestamp'],
    }).toList();

    return AgentToolResult.success(
      toolName: name,
      data: {'logs': formatted, 'count': formatted.length},
      summaryFa: '${formatted.length} رکورد سوابق خواب کاربر واکشی شد.',
    );
  }
}

/// ۲. ابزار دریافت روند انرژی و مود
class GetEnergyTrendsTool extends AgentTool {
  const GetEnergyTrendsTool()
      : super(
          name: 'get_energy_trends',
          categoryFa: 'انرژی و ریتم',
          titleFa: 'روند سطح انرژی و خلق‌وخو',
          descriptionFa: 'میانگین و نوسانات سطح انرژی و حال روحی کاربر را در روزهای اخیر بازمی‌گرداند.',
          policy: ToolPolicy.readOnly,
          parameters: const [
            ToolParameter(
              name: 'days',
              descriptionFa: 'تعداد روزهای مورد بررسی (پیش‌فرض ۷ روز)',
              type: 'int',
              defaultValue: 7,
            ),
          ],
        );

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    final days = (args['days'] is int)
        ? args['days'] as int
        : (int.tryParse(args['days']?.toString() ?? '7') ?? 7);

    final db = await DatabaseHelper.instance.database;
    final energyRows = <Map<String, dynamic>>[];

    try {
      final rows = await db.query('energy_logs', orderBy: 'timestamp DESC', limit: days * 3);
      energyRows.addAll(rows);
    } catch (_) {}

    return AgentToolResult.success(
      toolName: name,
      data: {'energyLogs': energyRows, 'count': energyRows.length},
      summaryFa: '${energyRows.length} لاگ سطح انرژی در بازه $days روز اخیر یافت شد.',
    );
  }
}

/// ۳. ابزار ثبت سطح انرژی و مود
class LogEnergyMoodLevelTool extends AgentTool {
  const LogEnergyMoodLevelTool()
      : super(
          name: 'log_energy_mood_level',
          categoryFa: 'انرژی و ریتم',
          titleFa: 'ثبت سطح انرژی و حال روحی',
          descriptionFa: 'سطح انرژی فعلی (۱ تا ۵) و مود کاربر را ثبت می‌کند.',
          policy: ToolPolicy.actionDirect,
          parameters: const [
            ToolParameter(
              name: 'energyLevel',
              descriptionFa: 'سطح انرژی از ۱ (خیلی کم) تا ۵ (عالی)',
              type: 'int',
              isRequired: true,
            ),
            ToolParameter(
              name: 'moodScore',
              descriptionFa: 'امتیاز حال روحی از ۱ تا ۵',
              type: 'int',
            ),
            ToolParameter(
              name: 'note',
              descriptionFa: 'یادداشت کوتاه',
              type: 'string',
            ),
          ],
        );

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    final energy = (args['energyLevel'] is int)
        ? args['energyLevel'] as int
        : (int.tryParse(args['energyLevel']?.toString() ?? '3') ?? 3);
    final mood = args['moodScore'] != null ? int.tryParse(args['moodScore'].toString()) : null;
    final note = args['note']?.toString();

    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      await db.insert('energy_logs', {
        'id': 'energy_${now}',
        'level': energy,
        'note': note,
        'timestamp': now,
      });
      if (mood != null) {
        await db.insert('mood_logs', {
          'id': 'mood_${now}',
          'score': mood,
          'timestamp': now,
        });
      }
    } catch (_) {}

    return AgentToolResult.success(
      toolName: name,
      data: {'energy': energy, 'mood': mood},
      summaryFa: 'سطح انرژی ($energy از ۵) با موفقیت در سیستم ثبت گردید.',
    );
  }
}
