import 'dart:convert';

import 'package:ritmo/core/ai/agent/agent_tool.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:ritmo/core/domain/commands/ritmo_command_bus.dart';
import 'package:ritmo/core/logging/ritmo_logger.dart';

/// ژورنال ابزارهای ایجنت — فاز ۳ (P3-3)
///
/// هر اجرای ابزار تغییردهنده اینجا ثبت می‌شود تا «دستیار چه کاری کرد؟» پاسخ
/// داشته باشد و بازگردانی با یک لمس ممکن شود. ابزارهای فقط‌خواندنی ثبت
/// نمی‌شوند چون چیزی برای برگرداندن ندارند.
///
/// جدول تنبل و با CREATE TABLE IF NOT EXISTS ساخته می‌شود: هم نصب تازه و هم
/// ارتقا پوشش داده می‌شود و migrations_registry.dart دست نمی‌خورد.
class AgentJournalEntry {
  const AgentJournalEntry({
    required this.id,
    required this.sessionId,
    required this.toolName,
    required this.titleFa,
    required this.policy,
    required this.args,
    required this.summaryFa,
    required this.isSuccess,
    required this.createdAt,
    this.undoKind,
    this.undoRef,
    this.undoneAt,
  });

  final String id;
  final String sessionId;
  final String toolName;
  final String titleFa;
  final String policy;
  final Map<String, dynamic> args;
  final String summaryFa;
  final bool isSuccess;
  final int createdAt;

  /// 'plan' برای undoPlan و 'audit' برای undoAudit؛ null یعنی بازگشت خودکار ندارد
  final String? undoKind;
  final String? undoRef;
  final int? undoneAt;

  bool get isUndone => undoneAt != null;

  bool get canUndo {
    final ref = undoRef;
    return isSuccess &&
        undoneAt == null &&
        undoKind != null &&
        ref != null &&
        ref.isNotEmpty;
  }

  DateTime get createdAtDate => DateTime.fromMillisecondsSinceEpoch(createdAt);

  static Map<String, dynamic> _decodeArgs(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) return const <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {
      // آرگومان ناخوانا نباید نمایش ژورنال را بشکند
    }
    return const <String, dynamic>{};
  }

  factory AgentJournalEntry.fromRow(Map<String, Object?> row) {
    final tool = row['toolName']?.toString() ?? '';
    return AgentJournalEntry(
      id: row['id']?.toString() ?? '',
      sessionId: row['sessionId']?.toString() ?? '',
      toolName: tool,
      titleFa:
          row['titleFa']?.toString() ?? (tool.isEmpty ? 'عملیات دستیار' : tool),
      policy: row['policy']?.toString() ?? 'actionDirect',
      args: _decodeArgs(row['argsJson']),
      summaryFa: row['summaryFa']?.toString() ?? '',
      isSuccess: (row['isSuccess'] as int? ?? 0) == 1,
      createdAt: row['createdAt'] as int? ?? 0,
      undoKind: row['undoKind']?.toString(),
      undoRef: row['undoRef']?.toString(),
      undoneAt: row['undoneAt'] as int?,
    );
  }
}

/// نتیجه تلاش برای بازگردانی یک عملیات
class AgentUndoOutcome {
  const AgentUndoOutcome({required this.success, required this.messageFa});

  final bool success;
  final String messageFa;
}

class AgentJournal {
  AgentJournal._();

  static final AgentJournal instance = AgentJournal._();

  static const String table = 'agent_tool_journal';

  bool _schemaReady = false;

  Future<void> ensureSchema() async {
    if (_schemaReady) return;
    final db = await DatabaseHelper.instance.database;
    await db.execute('CREATE TABLE IF NOT EXISTS $table ('
        'id TEXT PRIMARY KEY, sessionId TEXT NOT NULL, toolName TEXT NOT NULL, '
        'titleFa TEXT, policy TEXT NOT NULL, argsJson TEXT NOT NULL, '
        'resultJson TEXT, summaryFa TEXT, isSuccess INTEGER NOT NULL, '
        'undoKind TEXT, undoRef TEXT, undoneAt INTEGER, createdAt INTEGER NOT NULL)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_agent_journal_created '
        'ON $table (createdAt DESC)');
    _schemaReady = true;
  }

  /// ثبت یک اجرای ابزار تغییردهنده. شکست ثبت هرگز خود عملیات را نمی‌شکند.
  Future<String?> record({
    required String sessionId,
    required AgentTool tool,
    required Map<String, dynamic> args,
    required AgentToolResult result,
  }) async {
    if (tool.policy == ToolPolicy.readOnly) return null;

    try {
      await ensureSchema();
      final db = await DatabaseHelper.instance.database;

      final data = _asMap(result.data);
      final undoable = data?['isUndoable'] == true;
      final planId = data?['planId']?.toString();
      final auditId = data?['auditId']?.toString();

      String? undoKind;
      String? undoRef;
      if (undoable && planId != null && planId.isNotEmpty) {
        undoKind = 'plan';
        undoRef = planId;
      } else if (undoable && auditId != null && auditId.isNotEmpty) {
        undoKind = 'audit';
        undoRef = auditId;
      }

      final id = 'aj_${DateTime.now().microsecondsSinceEpoch}';
      await db.insert(table, <String, Object?>{
        'id': id,
        'sessionId': sessionId,
        'toolName': tool.name,
        'titleFa': tool.titleFa,
        'policy': tool.policy.name,
        'argsJson': _encode(args),
        'resultJson': result.isSuccess ? _encode(result.data) : null,
        'summaryFa': result.isSuccess
            ? result.summaryFa
            : (result.errorMessage ?? result.summaryFa),
        'isSuccess': result.isSuccess ? 1 : 0,
        'undoKind': undoKind,
        'undoRef': undoRef,
        'undoneAt': null,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });

      RitmoLog.info('AgentJournal',
          'ثبت شد: ${tool.name} | undo=${undoKind ?? 'ندارد'}');
      return id;
    } catch (e, st) {
      RitmoLog.error(
          'AgentJournal', 'ثبت ژورنال ${tool.name} شکست خورد', e, st);
      return null;
    }
  }

  Future<List<AgentJournalEntry>> recent({
    int limit = 30,
    String? sessionId,
    bool onlyUndoable = false,
  }) async {
    try {
      await ensureSchema();
      final db = await DatabaseHelper.instance.database;

      final clauses = <String>[];
      final whereArgs = <Object?>[];
      if (sessionId != null && sessionId.isNotEmpty) {
        clauses.add('sessionId = ?');
        whereArgs.add(sessionId);
      }
      if (onlyUndoable) {
        clauses.add('isSuccess = 1 AND undoneAt IS NULL '
            'AND undoKind IS NOT NULL AND undoRef IS NOT NULL');
      }

      final safeLimit = limit < 1 ? 30 : (limit > 200 ? 200 : limit);
      final rows = await db.query(
        table,
        where: clauses.isEmpty ? null : clauses.join(' AND '),
        whereArgs: whereArgs.isEmpty ? null : whereArgs,
        orderBy: 'createdAt DESC',
        limit: safeLimit,
      );

      return rows.map((row) => AgentJournalEntry.fromRow(row)).toList();
    } catch (e, st) {
      RitmoLog.error('AgentJournal', 'خواندن ژورنال شکست خورد', e, st);
      return const <AgentJournalEntry>[];
    }
  }

  Future<int> undoableCount({String? sessionId}) async {
    final rows =
        await recent(limit: 50, sessionId: sessionId, onlyUndoable: true);
    return rows.length;
  }

  /// بازگردانی واقعی توسط RitmoCommandBus انجام می‌شود (همان معکوسی که خود
  /// فرمان تعریف کرده)، نه با SQL دستی. اینجا فقط مسیر درست انتخاب می‌شود.
  Future<AgentUndoOutcome> undoEntry(String entryId) async {
    try {
      await ensureSchema();
      final db = await DatabaseHelper.instance.database;

      final rows = await db
          .query(table, where: 'id = ?', whereArgs: [entryId], limit: 1);
      if (rows.isEmpty) {
        return const AgentUndoOutcome(
            success: false, messageFa: 'این عملیات در ژورنال پیدا نشد.');
      }

      final entry = AgentJournalEntry.fromRow(rows.first);
      if (entry.isUndone) {
        return const AgentUndoOutcome(
            success: false,
            messageFa: 'این عملیات قبلا بازگردانده شده است.');
      }

      final ref = entry.undoRef;
      if (!entry.canUndo || ref == null) {
        return AgentUndoOutcome(
            success: false,
            messageFa:
                'عملیات «${entry.titleFa}» بازگشت خودکار ندارد و باید دستی اصلاح شود.');
      }

      bool ok;
      String? errorFa;
      if (entry.undoKind == 'plan') {
        final res = await RitmoCommandBus.instance.undoPlan(ref);
        ok = res.success;
        errorFa = res.errorMessage;
      } else {
        final res = await RitmoCommandBus.instance.undoAudit(ref);
        ok = res.success;
        errorFa = res.errorMessage;
      }

      if (!ok) {
        RitmoLog.warning('AgentJournal',
            'بازگردانی ${entry.toolName} ناموفق بود: $errorFa');
        return AgentUndoOutcome(
            success: false,
            messageFa: errorFa ?? 'بازگردانی این عملیات ممکن نشد.');
      }

      await db.update(
        table,
        <String, Object?>{'undoneAt': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [entryId],
      );

      return AgentUndoOutcome(
          success: true, messageFa: 'عملیات «${entry.titleFa}» بازگردانده شد.');
    } catch (e, st) {
      RitmoLog.error('AgentJournal', 'بازگردانی $entryId شکست خورد', e, st);
      return const AgentUndoOutcome(
          success: false,
          messageFa: 'خطای غیرمنتظره در بازگردانی. تغییری اعمال نشد.');
    }
  }

  Future<AgentUndoOutcome> undoLast({String? sessionId}) async {
    final rows =
        await recent(limit: 1, sessionId: sessionId, onlyUndoable: true);
    if (rows.isEmpty) {
      return const AgentUndoOutcome(
          success: false,
          messageFa: 'عملیات قابل بازگشتی از دستیار ثبت نشده است.');
    }
    return undoEntry(rows.first.id);
  }

  Future<void> purgeOlderThan({int days = 45}) async {
    try {
      await ensureSchema();
      final db = await DatabaseHelper.instance.database;
      final cutoff = DateTime.now()
          .subtract(Duration(days: days))
          .millisecondsSinceEpoch;
      await db.delete(table, where: 'createdAt < ?', whereArgs: [cutoff]);
    } catch (e, st) {
      RitmoLog.error('AgentJournal', 'پاکسازی ژورنال شکست خورد', e, st);
    }
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map) {
      try {
        return value.cast<String, dynamic>();
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String _encode(dynamic value) {
    if (value == null) return '{}';
    try {
      return jsonEncode(value);
    } catch (_) {
      return jsonEncode(<String, String>{'raw': value.toString()});
    }
  }
}
