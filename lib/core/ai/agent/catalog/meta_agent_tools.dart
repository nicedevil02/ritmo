import 'package:ritmo/core/ai/agent/agent_policy_gate.dart';
import 'package:ritmo/core/ai/agent/agent_tool.dart';
import 'package:ritmo/core/ai/agent/catalog/kernel_command_tool.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/agenda/day_agenda_service.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';

/// ۱. ابزار خودبازرسی وضعیت (P2-4)
///
/// مهم‌ترین ابزار فاز ۲ از نظر قابل اعتماد بودن. مشکل تکرارشوندهٔ این برنامه
/// این بوده که چیزی در دیتابیس ذخیره می‌شد ولی در تقویم/برنامهٔ روز دیده نمی‌شد
/// (نبودن اکیورنس، گیت ماژول، کش کهنه، ...). پس ایجنت باید بتواند بعد از هر
/// نوشتن، نتیجه را از دید منبعِ UI دوباره بخواند و فقط آن وقت به کاربر بگوید
/// «انجام شد».
///
/// کاملاً خواندنی است و هیچ داده‌ای تغییر نمی‌دهد.
class VerifyStateTool extends AgentTool {
  const VerifyStateTool()
      : super(
          name: 'verify_state',
          categoryFa: 'بازرسی و دقت',
          titleFa: 'بازرسی وضعیت واقعی',
          descriptionFa:
              'بررسی می‌کند که چیزی درواقع ثبت و قابل دیدن شده یا نه. بعد از هر ابزار نوشتنی مهم (مانند ساخت روتین) این را صدا بزن تا به کاربر حقیقت را بگویی.',
          policy: ToolPolicy.readOnly,
          parameters: const [
            ToolParameter(
              name: 'check',
              descriptionFa:
                  'نوع بازرسی: routine_in_day (روتین در برنامهٔ یک روز دیده می‌شود؟) یا routine_exists (روتین و زمان‌بندی‌اش وجود دارد؟) یا setting_value (مقدار فعلی یک تنظیم) یا agenda_count (شمارش موارد یک روز)',
              type: 'string',
              isRequired: true,
              allowedValues: [
                'routine_in_day',
                'routine_exists',
                'setting_value',
                'agenda_count',
              ],
            ),
            ToolParameter(
              name: 'title',
              descriptionFa: 'عنوان روتین یا بخشی از آن (برای دو حالت روتین)',
              type: 'string',
            ),
            ToolParameter(
              name: 'date',
              descriptionFa: 'تاریخ مورد بازرسی (پیش‌فرض امروز)',
              type: 'string',
              defaultValue: 'امروز',
            ),
            ToolParameter(
              name: 'key',
              descriptionFa: 'کلید تنظیمات (فقط برای setting_value)',
              type: 'string',
            ),
          ],
        );

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    final check = KernelCommandTool.optionalString(args['check']) ?? '';
    final title = KernelCommandTool.optionalString(args['title']);
    final date = AgentDateResolver.resolve(args['date']);

    switch (check) {
      case 'routine_in_day':
        return _checkRoutineInDay(title, date);
      case 'routine_exists':
        return _checkRoutineExists(title);
      case 'setting_value':
        return _checkSetting(KernelCommandTool.optionalString(args['key']));
      case 'agenda_count':
        return _checkAgendaCount(date);
      default:
        return AgentToolResult.failure(
          toolName: name,
          errorMessage:
              'نوع بازرسی «$check» معتبر نیست. یکی از این‌ها را بفرست: routine_in_day, routine_exists, setting_value, agenda_count.',
        );
    }
  }

  /// آیا روتین در برنامهٔ واقعی آن روز (همان منبع خانه/تقویم) دیده می‌شود؟
  Future<AgentToolResult> _checkRoutineInDay(String? title, DateTime date) async {
    if (title == null) {
      return AgentToolResult.failure(
        toolName: name,
        errorMessage: 'برای این بازرسی، عنوان روتین (title) الزامی است.',
      );
    }

    final label = AgentDateResolver.label(date);
    try {
      final agenda = await DayAgendaService.instance.agendaForDate(date);
      final needle = title.toLowerCase();
      final matches = agenda.items
          .where((i) => i.title.toLowerCase().contains(needle))
          .toList();

      if (matches.isEmpty) {
        final sample = agenda.items
            .take(10)
            .map((i) => i.title)
            .toList();
        return AgentToolResult.success(
          toolName: name,
          data: {
            'check': 'routine_in_day',
            'found': false,
            'date': AgentDateResolver.iso(date),
            'dayItemCount': agenda.items.length,
            'sampleTitles': sample,
          },
          summaryFa:
              '«$title» در برنامهٔ $label دیده نمی‌شود. آن روز ${agenda.items.length} مورد دارد. به کاربر نگو که انجام شده.',
        );
      }

      final first = matches.first;
      return AgentToolResult.success(
        toolName: name,
        data: {
          'check': 'routine_in_day',
          'found': true,
          'date': AgentDateResolver.iso(date),
          'matchCount': matches.length,
          'title': first.title,
          'time': first.timeOfDay ?? 'ساعت مشخص ندارد',
          'status': first.completion.name,
          'domain': first.domain.name,
        },
        summaryFa:
            'تأیید شد: «${first.title}» در برنامهٔ $label دیده می‌شود (ساعت ${first.timeOfDay ?? 'نامشخص'}).',
      );
    } catch (e, st) {
      RitmoLog.error('VerifyStateTool', 'routine_in_day failed', e, st);
      return AgentToolResult.failure(
        toolName: name,
        errorMessage:
            'بازرسی برنامهٔ $label ممکن نشد، پس نمی‌توان تأیید کرد: $e',
      );
    }
  }

  /// آیا روتین، زمان‌بندی و اکیورنس‌های آینده دارد؟
  ///
  /// روتینی که ردیف دارد ولی اکیورنس ندارد، در تقویم نامرئی است — همان
  /// باگی که قبلاً بارها دیده شده. پس این بازرسی عدد اکیورنس را صریح برمی‌گرداند.
  Future<AgentToolResult> _checkRoutineExists(String? title) async {
    if (title == null) {
      return AgentToolResult.failure(
        toolName: name,
        errorMessage: 'برای این بازرسی، عنوان روتین (title) الزامی است.',
      );
    }

    final today = DateTime.now();
    final startIso = AgentDateResolver.iso(today);
    final endIso = AgentDateResolver.iso(today.add(const Duration(days: 7)));

    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.rawQuery('''
        SELECT
          r.id AS id,
          r.title AS title,
          r.isArchived AS isArchived,
          (SELECT s.timeOfDay FROM routine_schedules s
             WHERE s.routineId = r.id ORDER BY s.createdAt ASC LIMIT 1) AS timeOfDay,
          (SELECT s.scheduleType FROM routine_schedules s
             WHERE s.routineId = r.id ORDER BY s.createdAt ASC LIMIT 1) AS scheduleType,
          (SELECT COUNT(*) FROM routine_schedules s WHERE s.routineId = r.id) AS scheduleCount,
          (SELECT COUNT(*) FROM routine_occurrences o
             WHERE o.routine_id = r.id AND o.date >= ? AND o.date <= ?) AS upcomingOccurrences
        FROM routines r
        WHERE r.title LIKE ?
        LIMIT 8
      ''', [startIso, endIso, '%$title%']);

      if (rows.isEmpty) {
        return AgentToolResult.success(
          toolName: name,
          data: {'check': 'routine_exists', 'found': false, 'matches': []},
          summaryFa:
              'هیچ روتینی با عنوان شبیه به «$title» در دیتابیس وجود ندارد. پس ساخته نشده است.',
        );
      }

      final matches = rows
          .map((r) => <String, dynamic>{
                'id': r['id'],
                'title': r['title'],
                'isArchived': (r['isArchived'] as num?)?.toInt() == 1,
                'time': r['timeOfDay'] ?? 'ساعت ثابت ندارد',
                'scheduleType': r['scheduleType'] ?? 'نامشخص',
                'scheduleCount': (r['scheduleCount'] as num?)?.toInt() ?? 0,
                'upcomingOccurrences':
                    (r['upcomingOccurrences'] as num?)?.toInt() ?? 0,
              })
          .toList();

      final first = matches.first;
      final occurrences = first['upcomingOccurrences'] as int;
      final scheduleCount = first['scheduleCount'] as int;

      final problems = <String>[];
      if (scheduleCount == 0) problems.add('زمان‌بندی ثبت نشده');
      if (occurrences == 0) problems.add('هیچ اکیورنسی در ۷ روز آینده ندارد');
      if (first['isArchived'] == true) problems.add('بایگانی شده');

      return AgentToolResult.success(
        toolName: name,
        data: {
          'check': 'routine_exists',
          'found': true,
          'matchCount': matches.length,
          'matches': matches,
          'problems': problems,
        },
        summaryFa: problems.isEmpty
            ? 'تأیید شد: روتین «${first['title']}» وجود دارد، ساعت ${first['time']}، و $occurrences روز آینده برایش برنامه ثبت شده است.'
            : 'روتین «${first['title']}» وجود دارد ولی مشکل دارد: ${problems.join('، ')}. به کاربر صادقانه بگو که ممکن است در تقویم دیده نشود.',
      );
    } catch (e, st) {
      RitmoLog.error('VerifyStateTool', 'routine_exists failed', e, st);
      return AgentToolResult.failure(
        toolName: name,
        errorMessage: 'بازرسی وجود روتین ممکن نشد: $e',
      );
    }
  }

  Future<AgentToolResult> _checkSetting(String? key) async {
    if (key == null) {
      return AgentToolResult.failure(
        toolName: name,
        errorMessage: 'برای این بازرسی، کلید تنظیمات (key) الزامی است.',
      );
    }

    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.rawQuery(
        'SELECT key, value, updatedAt FROM app_settings WHERE key = ? LIMIT 1',
        [key],
      );

      if (rows.isEmpty) {
        return AgentToolResult.success(
          toolName: name,
          data: {'check': 'setting_value', 'key': key, 'exists': false},
          summaryFa:
              'تنظیم «$key» در دیتابیس مقداری ندارد (مقدار پیش‌فرض برنامه استفاده می‌شود).',
        );
      }

      final row = rows.first;
      return AgentToolResult.success(
        toolName: name,
        data: {
          'check': 'setting_value',
          'key': key,
          'exists': true,
          'value': row['value'],
          'updatedAt': row['updatedAt'],
        },
        summaryFa: 'مقدار فعلی تنظیم «$key» برابر «${row['value']}» است.',
      );
    } catch (e, st) {
      RitmoLog.error('VerifyStateTool', 'setting_value failed', e, st);
      return AgentToolResult.failure(
        toolName: name,
        errorMessage: 'خواندن تنظیم «$key» ممکن نشد: $e',
      );
    }
  }

  Future<AgentToolResult> _checkAgendaCount(DateTime date) async {
    final label = AgentDateResolver.label(date);
    try {
      final agenda = await DayAgendaService.instance.agendaForDate(date);
      final done = agenda.items.where((i) => i.isCompleted).length;
      return AgentToolResult.success(
        toolName: name,
        data: {
          'check': 'agenda_count',
          'date': AgentDateResolver.iso(date),
          'itemCount': agenda.items.length,
          'doneCount': done,
          'pendingCount': agenda.items.length - done,
        },
        summaryFa:
            'برنامهٔ $label در این لحظه ${agenda.items.length} مورد دارد ($done انجام‌شده).',
      );
    } catch (e, st) {
      RitmoLog.error('VerifyStateTool', 'agenda_count failed', e, st);
      return AgentToolResult.failure(
        toolName: name,
        errorMessage: 'شمارش موارد برنامهٔ $label ممکن نشد: $e',
      );
    }
  }
}

/// ۲. ابزار پرسیدن از کاربر (P2-5)
///
/// جایگزین حدس زدن. رفتار خطرناک قبلی این بود که مدل برای ورودی ناقص
/// (مانند روتینی بدون ساعت یا عنوانی مبهم) مقدار اختراع کند و دادهٔ اشتباه
/// بنویسد. این ابزار یک مسیر رسمی برای توقف و پرسیدن می‌دهد.
class AskUserTool extends AgentTool {
  const AskUserTool()
      : super(
          name: 'ask_user',
          categoryFa: 'بازرسی و دقت',
          titleFa: 'پرسیدن از کاربر',
          descriptionFa:
              'وقتی برای انجام کار یک اطلاع لازم را نداری (مانند ساعت، عنوان دقیق، یا اینکه کدام روتین منظور است) این را صدا بزن و منتظر پاسخ بمان. هرگز مقدار را حدس نزن و چیزی را سرخود ننویس.',
          policy: ToolPolicy.readOnly,
          parameters: const [
            ToolParameter(
              name: 'question',
              descriptionFa: 'متن پرسش کوتاه و مشخص به فارسی',
              type: 'string',
              isRequired: true,
            ),
            ToolParameter(
              name: 'options',
              descriptionFa:
                  'گزینه‌های پیشنهادی (اختیاری) به صورت لیست یا متن جداشده با کاما',
              type: 'list',
            ),
          ],
        );

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    final question = KernelCommandTool.optionalString(args['question']);
    if (question == null) {
      return AgentToolResult.failure(
        toolName: name,
        errorMessage: 'متن پرسش (question) الزامی است.',
      );
    }

    final rawOptions = args['options'];
    final options = <String>[];
    if (rawOptions is List) {
      for (final o in rawOptions) {
        final s = KernelCommandTool.optionalString(o);
        if (s != null) options.add(s);
      }
    } else {
      final s = KernelCommandTool.optionalString(rawOptions);
      if (s != null) {
        options.addAll(
          s.split(RegExp(r'[,،]')).map((p) => p.trim()).where((p) => p.isNotEmpty),
        );
      }
    }

    final reqId = 'q_${DateTime.now().microsecondsSinceEpoch}';
    final request = AgentQuestionRequest(
      id: reqId,
      sessionId: 'global',
      question: question,
      options: options,
    );

    final response = await AgentQuestionBroker.instance.ask(request);
    if (!response.answered) {
      return AgentToolResult.failure(
        toolName: name,
        errorMessage: response.reasonFa ?? 'پاسخی از کاربر دریافت نشد.',
        summaryFa:
            'کاربر به پرسش پاسخ نداد یا لغو کرد: ${response.reasonFa ?? 'لغو شد'}',
      );
    }

    return AgentToolResult.success(
      toolName: name,
      data: {
        'question': question,
        'userAnswer': response.answer,
        'options': options,
      },
      summaryFa: 'پاسخ کاربر دریافت شد: «${response.answer}»',
    );
  }
}
