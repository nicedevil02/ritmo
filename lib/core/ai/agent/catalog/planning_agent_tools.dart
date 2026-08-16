import 'package:ritmo/core/ai/agent/agent_tool.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:shamsi_date/shamsi_date.dart';

/// ۱. ابزار دریافت برنامه و زمان‌بندی روزانه
///
/// منبع داده جدول routine_occurrences است که بر کلید تاریخ ایندکس شده و همان
/// منبعی است که تقویم برنامه از آن می‌خواند. نسخه قبلی تمام روتین‌ها را
/// بدون توجه به تاریخ می‌خواند و همان لیست را برای «فردا» هم تحویل می‌داد.
///
/// محدودیت فعلی: فقط روتین‌ها و ایونت‌های موجود در routine_occurrences را می‌بیند.
/// پوشش کامل (نماز، ورزش، گیت‌های مادول) در فاز ۲ با عبور از DayAgendaService.
class GetDayAgendaTool extends AgentTool {
  const GetDayAgendaTool()
      : super(
          name: 'get_day_agenda',
          categoryFa: 'برنامه‌ریزی روز',
          titleFa: 'دریافت برنامه روزانه',
          descriptionFa:
              'لیست روتین‌ها و کارهای زمان‌بندی‌شده کاربر برای یک روز مشخص را با وضعیت انجام بازمی‌گرداند.',
          policy: ToolPolicy.readOnly,
          parameters: const [
            ToolParameter(
              name: 'targetDate',
              descriptionFa:
                  'تاریخ مورد نطر: یکی از today یا tomorrow یا yesterday، یا تاریخ جلالی مانند 1403/05/20، یا تاریخ میلادی مانند 2026-08-16',
              type: 'string',
              defaultValue: 'today',
            ),
          ],
        );

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    final rawTarget = args['targetDate']?.toString() ?? 'today';
    final resolved = _resolveDate(rawTarget);
    final isoDate = _iso(resolved);
    final jalaliLabel = _jalaliLabel(resolved);

    final db = await DatabaseHelper.instance.database;

    final rows = await db.rawQuery('''
      SELECT
        o.routine_id AS routineId,
        o.date AS occurrenceDate,
        o.scheduled_time AS scheduledTime,
        o.status AS status,
        o.ownerModule AS ownerModule,
        r.title AS title,
        r.category AS category,
        r.itemType AS itemType,
        COALESCE(r.targetDurationMinutes, r.defaultDurationMinutes) AS durationMinutes
      FROM routine_occurrences o
      JOIN routines r ON r.id = o.routine_id
      WHERE o.date = ? AND (r.isArchived = 0 OR r.isArchived IS NULL)
      ORDER BY (o.scheduled_time IS NULL) ASC, o.scheduled_time ASC
    ''', [isoDate]);

    final items = rows.map((r) {
      final time = (r['scheduledTime'] as String?)?.trim() ?? '';
      return {
        'routineId': r['routineId'],
        'title': r['title'],
        'time': time.isEmpty ? 'ساعت مشخص ندارد' : time,
        'status': r['status'] ?? 'pending',
        'itemType': r['itemType'] ?? 'ROUTINE',
        'category': r['category'],
        'durationMinutes': r['durationMinutes'],
        'ownerModule': r['ownerModule'],
      };
    }).toList();

    final doneCount =
        items.where((i) => (i['status']?.toString() ?? '') != 'pending').length;

    return AgentToolResult.success(
      toolName: name,
      data: {
        'requestedTarget': rawTarget,
        'resolvedDateGregorian': isoDate,
        'resolvedDateJalali': jalaliLabel,
        'itemCount': items.length,
        'doneCount': doneCount,
        'items': items,
        'coverageNote':
            'این لیست فقط روتین‌ها و کارهای ثبت‌شده در جدول اکیورنس را شامل می‌شود و ممکن است نماز یا جلسات ورزشی را دربرنگیرد.',
      },
      summaryFa: items.isEmpty
          ? 'برای تاریخ $jalaliLabel (میلادی $isoDate) هیچ مورد زمان‌بندی‌شده‌ای در برنامه ثبت نشده است.'
          : 'برنامه تاریخ $jalaliLabel (میلادی $isoDate) شامل ${items.length} مورد است که $doneCount مورد انجام شده.',
    );
  }

  /// تبدیل ورودی کاربر/مدل به یک تاریخ میلادی معتبر
  static DateTime _resolveDate(String input) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final v = _toEnglishDigits(input.trim().toLowerCase());

    if (v.isEmpty || v == 'today' || v == 'امروز') return today;
    if (v == 'tomorrow' || v == 'فردا') {
      return today.add(const Duration(days: 1));
    }
    if (v == 'yesterday' || v == 'دیروز') {
      return today.subtract(const Duration(days: 1));
    }

    final parts = v
        .split(RegExp(r'[\/\-\.]'))
        .where((p) => p.trim().isNotEmpty)
        .toList();
    if (parts.length == 3) {
      final a = int.tryParse(parts[0].trim());
      final b = int.tryParse(parts[1].trim());
      final c = int.tryParse(parts[2].trim());
      if (a != null && b != null && c != null && b >= 1 && b <= 12 && c >= 1 && c <= 31) {
        if (a >= 1700) {
          return DateTime(a, b, c);
        }
        if (a >= 1200 && a < 1700) {
          final g = Jalali(a, b, c).toGregorian();
          return DateTime(g.year, g.month, g.day);
        }
      }
    }

    return today;
  }

  static String _toEnglishDigits(String s) {
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    const ar = '٠١٢٣٤٥٦٧٨٩';
    var out = s;
    for (var i = 0; i < fa.length; i++) {
      out = out.replaceAll(fa[i], i.toString());
      out = out.replaceAll(ar[i], i.toString());
    }
    return out;
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _jalaliLabel(DateTime d) {
    final j = Jalali.fromDateTime(d);
    return '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';
  }
}

/// ۲. ابزار چیدمان هوشمند برنامه روز — غیرفعال تا فاز ۲
///
/// نسخه قبلی در جدول assistant_plans می‌نوشت که وجود ندارد، خطا را در catch (_) {}
/// می‌بلعید و بعد بی‌قیدوشرط به کاربر می‌گفت برنامه آماده شد. یعنی ابزار به
/// کاربر دروغ می‌گفت. تا وقتی کارت تایید و ژورنال بازگشت (فاز ۳) وجود ندارد،
/// این ابزار نباید وعده بدهد.
class ApplySmartDayPlanTool extends AgentTool {
  const ApplySmartDayPlanTool()
      : super(
          name: 'apply_smart_day_plan',
          categoryFa: 'برنامه‌ریزی روز',
          titleFa: 'چیدمان هوشمند برنامه روز',
          descriptionFa:
              'فعلاً غیرفعال است. پیشنهاد چیدمان را در متن پاسخ به کاربر بگو و ادعای ذخیره‌سازی نکن.',
          policy: ToolPolicy.actionInteractive,
          parameters: const [
            ToolParameter(
              name: 'planSummary',
              descriptionFa: 'خلاصه چینش برنامه',
              type: 'string',
              isRequired: true,
            ),
          ],
        );

  @override
  Future<AgentToolResult> execute(Map<String, dynamic> args) async {
    return AgentToolResult.failure(
      toolName: name,
      errorMessage:
          'این ابزار فعلاً غیرفعال است و هیچ برنامه‌ای ذخیره نشد. ادعا نکن که برنامه اعمال یا ذخیره شد؛ فقط پیشنهاد را در متن بنویس تا کاربر خودش در برنامه ثبت کند.',
    );
  }
}
