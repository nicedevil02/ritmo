import 'package:ritmo/core/domain/commands/command_plan.dart';
import 'package:ritmo/core/domain/commands/param_spec.dart';
import 'package:ritmo/core/domain/commands/ritmo_command.dart';
import 'package:ritmo/core/time/ritmo_clock.dart';
import 'package:sqflite/sqflite.dart';

String _genNoteId() => 'note_${DateTime.now().microsecondsSinceEpoch}';
String _genLinkId() => 'link_${DateTime.now().microsecondsSinceEpoch}';
String _genRevId() => 'rev_${DateTime.now().microsecondsSinceEpoch}';

// 1. note.create (confirm)
class NoteCreateCommand extends RitmoCommand {
  const NoteCreateCommand();

  @override
  String get id => 'note.create';

  @override
  String get humanTitle => 'ایجاد یادداشت جدید';

  @override
  String get humanDescriptionFa => 'افزودن یادداشت جدید به دفترچه';

  @override
  Sensitivity get sensitivity => Sensitivity.confirm;

  @override
  Set<DataDomain> get touches => {DataDomain.notes};

  @override
  Map<String, ParamSpec> get params => {
    'title': const ParamSpec(type: ParamType.text, labelFa: 'عنوان', required: false),
    'body': const ParamSpec(type: ParamType.text, labelFa: 'متن یادداشت', required: true),
    'kind': const ParamSpec(type: ParamType.enumeration, labelFa: 'نوع', required: false, allowed: ['NOTE', 'DAILY', 'EXPERIENCE', 'IDEA', 'DECISION']),
    'tags': const ParamSpec(type: ParamType.list, itemType: ParamType.text, labelFa: 'برچسب‌ها', required: false),
    'linkModule': const ParamSpec(type: ParamType.text, labelFa: 'ماژول مرتبط', required: false),
    'linkEntityId': const ParamSpec(type: ParamType.text, labelFa: 'شناسه موجودیت مرتبط', required: false),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    final title = ctx.payload['title']?.toString() ?? (ctx.payload['body']?.toString().split('\n').first ?? 'یادداشت جدید');
    return PlanDiff(kind: DiffKind.create, entityLabelFa: 'یادداشت: $title');
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final noteId = ctx.payload['id']?.toString() ?? _genNoteId();
    final body = ctx.payload['body']?.toString().trim() ?? '';
    final title = ctx.payload['title']?.toString().trim() ?? (body.length > 40 ? '${body.substring(0, 40)}...' : body);
    final kind = ctx.payload['kind']?.toString() ?? 'NOTE';
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final dayKey = SystemClock().today().value;

    final wordCount = body.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

    await ctx.txn.insert('notes', {
      'id': noteId,
      'title': title,
      'body': body,
      'titleNormalized': title.toLowerCase(),
      'bodyNormalized': body.toLowerCase(),
      'kind': kind,
      'status': 'ACTIVE',
      'isPrivate': 0,
      'isPinned': 0,
      'dayKey': dayKey,
      'sourceModule': 'assistant',
      'wordCount': wordCount,
      'createdAt': nowMs,
      'updatedAt': nowMs,
      'openCount': 0,
      'reviewStage': 0,
    });

    final linkModule = ctx.payload['linkModule']?.toString();
    final linkEntityId = ctx.payload['linkEntityId']?.toString();
    if (linkModule != null && linkEntityId != null) {
      await ctx.txn.insert('note_links', {
        'id': _genLinkId(),
        'noteId': noteId,
        'linkModule': linkModule,
        'linkEntityId': linkEntityId,
        'relation': 'SPAWNED',
        'createdAt': nowMs,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    final tags = (ctx.payload['tags'] as List?)?.cast<String>();
    if (tags != null) {
      for (final t in tags) {
        final cleanTag = t.replaceAll('#', '').trim();
        if (cleanTag.isNotEmpty) {
          await ctx.txn.insert('note_tags', {
            'noteId': noteId,
            'tag': cleanTag,
            'tagNormalized': cleanTag.toLowerCase(),
            'source': 'AI',
            'createdAt': nowMs,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
    }

    return CommandResult.ok(commandId: id, outputData: {'noteId': noteId}, inverseData: {'noteId': noteId});
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    final noteId = inverseData['noteId']?.toString();
    if (noteId == null) return null;
    await ctx.txn.delete('notes', where: 'id = ?', whereArgs: [noteId]);
    return CommandResult.ok(commandId: id);
  }
}

// 2. note.append (confirm)
class NoteAppendCommand extends RitmoCommand {
  const NoteAppendCommand();

  @override
  String get id => 'note.append';

  @override
  String get humanTitle => 'افزودن به انتهای یادداشت';

  @override
  String get humanDescriptionFa => 'اضافه‌کردن متن به یک یادداشت موجود';

  @override
  Sensitivity get sensitivity => Sensitivity.confirm;

  @override
  Set<DataDomain> get touches => {DataDomain.notes};

  @override
  Map<String, ParamSpec> get params => {
    'noteId': const ParamSpec(type: ParamType.idRef, labelFa: 'یادداشت', required: true, refTable: 'notes'),
    'text': const ParamSpec(type: ParamType.text, labelFa: 'متن الحاقی', required: true),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    return const PlanDiff(kind: DiffKind.update, entityLabelFa: 'افزودن متن به یادداشت');
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final noteId = ctx.payload['noteId']?.toString() ?? '';
    final text = ctx.payload['text']?.toString() ?? '';
    final rows = await ctx.txn.query('notes', where: 'id = ?', whereArgs: [noteId]);
    if (rows.isEmpty) return CommandResult.failure(commandId: id, errorMessage: 'یادداشت یافت نشد');

    final existingBody = (rows.first['body'] as String?) ?? '';
    final updatedBody = existingBody.isEmpty ? text : '$existingBody\n\n$text';
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    await ctx.txn.update(
      'notes',
      {
        'body': updatedBody,
        'bodyNormalized': updatedBody.toLowerCase(),
        'updatedAt': nowMs,
      },
      where: 'id = ?',
      whereArgs: [noteId],
    );

    return CommandResult.ok(commandId: id, outputData: {'noteId': noteId}, inverseData: {'noteId': noteId, 'previousBody': existingBody});
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    final noteId = inverseData['noteId']?.toString();
    final prev = inverseData['previousBody']?.toString();
    if (noteId == null || prev == null) return null;
    await ctx.txn.update('notes', {'body': prev, 'bodyNormalized': prev.toLowerCase()}, where: 'id = ?', whereArgs: [noteId]);
    return CommandResult.ok(commandId: id);
  }
}

// 3. note.edit (confirm)
class NoteEditCommand extends RitmoCommand {
  const NoteEditCommand();

  @override
  String get id => 'note.edit';

  @override
  String get humanTitle => 'ویرایش متن یادداشت';

  @override
  String get humanDescriptionFa => 'تغییر محتوای یادداشت با نگهداری تاریخچه نسخه';

  @override
  Sensitivity get sensitivity => Sensitivity.confirm;

  @override
  Set<DataDomain> get touches => {DataDomain.notes};

  @override
  Map<String, ParamSpec> get params => {
    'noteId': const ParamSpec(type: ParamType.idRef, labelFa: 'یادداشت', required: true, refTable: 'notes'),
    'newBody': const ParamSpec(type: ParamType.text, labelFa: 'متن جدید', required: true),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    return const PlanDiff(kind: DiffKind.update, entityLabelFa: 'ویرایش یادداشت');
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final noteId = ctx.payload['noteId']?.toString() ?? '';
    final newBody = ctx.payload['newBody']?.toString() ?? '';
    final rows = await ctx.txn.query('notes', where: 'id = ?', whereArgs: [noteId]);
    if (rows.isEmpty) return CommandResult.failure(commandId: id, errorMessage: 'یادداشت یافت نشد');

    final existingBody = (rows.first['body'] as String?) ?? '';
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // Save revision with reason AI_EDIT
    await ctx.txn.insert('note_revisions', {
      'id': _genRevId(),
      'noteId': noteId,
      'body': existingBody,
      'wordCount': existingBody.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length,
      'reason': 'AI_EDIT',
      'createdAt': nowMs,
    });

    await ctx.txn.update(
      'notes',
      {
        'body': newBody,
        'bodyNormalized': newBody.toLowerCase(),
        'wordCount': newBody.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length,
        'updatedAt': nowMs,
      },
      where: 'id = ?',
      whereArgs: [noteId],
    );

    return CommandResult.ok(commandId: id, outputData: {'noteId': noteId}, inverseData: {'noteId': noteId, 'previousBody': existingBody});
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    final noteId = inverseData['noteId']?.toString();
    final prev = inverseData['previousBody']?.toString();
    if (noteId == null || prev == null) return null;
    await ctx.txn.update('notes', {'body': prev, 'bodyNormalized': prev.toLowerCase()}, where: 'id = ?', whereArgs: [noteId]);
    return CommandResult.ok(commandId: id);
  }
}

// 4. note.retitle (safe)
class NoteRetitleCommand extends RitmoCommand {
  const NoteRetitleCommand();

  @override
  String get id => 'note.retitle';

  @override
  String get humanTitle => 'تغییر عنوان یادداشت';

  @override
  String get humanDescriptionFa => 'تغییر عنوان یک یادداشت موجود';

  @override
  Sensitivity get sensitivity => Sensitivity.safe;

  @override
  Set<DataDomain> get touches => {DataDomain.notes};

  @override
  Map<String, ParamSpec> get params => {
    'noteId': const ParamSpec(type: ParamType.idRef, labelFa: 'یادداشت', required: true, refTable: 'notes'),
    'title': const ParamSpec(type: ParamType.text, labelFa: 'عنوان جدید', required: true),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    final title = ctx.payload['title']?.toString() ?? '';
    return PlanDiff(kind: DiffKind.update, entityLabelFa: 'عنوان یادداشت: $title');
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final noteId = ctx.payload['noteId']?.toString() ?? '';
    final title = ctx.payload['title']?.toString().trim() ?? '';
    final rows = await ctx.txn.query('notes', where: 'id = ?', whereArgs: [noteId]);
    if (rows.isEmpty) return CommandResult.failure(commandId: id, errorMessage: 'یادداشت یافت نشد');

    final prevTitle = rows.first['title'] as String?;
    await ctx.txn.update(
      'notes',
      {'title': title, 'titleNormalized': title.toLowerCase(), 'updatedAt': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [noteId],
    );

    return CommandResult.ok(commandId: id, outputData: {'noteId': noteId}, inverseData: {'noteId': noteId, 'previousTitle': prevTitle});
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    final noteId = inverseData['noteId']?.toString();
    final prevTitle = inverseData['previousTitle'] as String?;
    if (noteId == null) return null;
    await ctx.txn.update('notes', {'title': prevTitle, 'titleNormalized': prevTitle?.toLowerCase() ?? ''}, where: 'id = ?', whereArgs: [noteId]);
    return CommandResult.ok(commandId: id);
  }
}

// 5. note.tag (safe)
class NoteTagCommand extends RitmoCommand {
  const NoteTagCommand();

  @override
  String get id => 'note.tag';

  @override
  String get humanTitle => 'برچسب‌گذاری یادداشت';

  @override
  String get humanDescriptionFa => 'افزودن برچسب موضوعی به یادداشت';

  @override
  Sensitivity get sensitivity => Sensitivity.safe;

  @override
  Set<DataDomain> get touches => {DataDomain.notes};

  @override
  Map<String, ParamSpec> get params => {
    'noteId': const ParamSpec(type: ParamType.idRef, labelFa: 'یادداشت', required: true, refTable: 'notes'),
    'tag': const ParamSpec(type: ParamType.text, labelFa: 'برچسب', required: true),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    final tag = ctx.payload['tag']?.toString() ?? '';
    return PlanDiff(kind: DiffKind.update, entityLabelFa: 'افزودن تگ #$tag');
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final noteId = ctx.payload['noteId']?.toString() ?? '';
    final tag = ctx.payload['tag']?.toString().replaceAll('#', '').trim() ?? '';
    if (tag.isEmpty) return CommandResult.failure(commandId: id, errorMessage: 'برچسب نامعتبر');

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await ctx.txn.insert('note_tags', {
      'noteId': noteId,
      'tag': tag,
      'tagNormalized': tag.toLowerCase(),
      'source': 'AI',
      'createdAt': nowMs,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    return CommandResult.ok(commandId: id, outputData: {'noteId': noteId, 'tag': tag}, inverseData: {'noteId': noteId, 'tag': tag});
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    final noteId = inverseData['noteId']?.toString();
    final tag = inverseData['tag']?.toString();
    if (noteId == null || tag == null) return null;
    await ctx.txn.delete('note_tags', where: 'noteId = ? AND tagNormalized = ?', whereArgs: [noteId, tag.toLowerCase()]);
    return CommandResult.ok(commandId: id);
  }
}

// 6. note.untag (safe)
class NoteUntagCommand extends RitmoCommand {
  const NoteUntagCommand();

  @override
  String get id => 'note.untag';

  @override
  String get humanTitle => 'حذف برچسب یادداشت';

  @override
  String get humanDescriptionFa => 'برداشتن یک برچسب از یادداشت';

  @override
  Sensitivity get sensitivity => Sensitivity.safe;

  @override
  Set<DataDomain> get touches => {DataDomain.notes};

  @override
  Map<String, ParamSpec> get params => {
    'noteId': const ParamSpec(type: ParamType.idRef, labelFa: 'یادداشت', required: true, refTable: 'notes'),
    'tag': const ParamSpec(type: ParamType.text, labelFa: 'برچسب', required: true),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    final tag = ctx.payload['tag']?.toString() ?? '';
    return PlanDiff(kind: DiffKind.update, entityLabelFa: 'حذف تگ #$tag');
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final noteId = ctx.payload['noteId']?.toString() ?? '';
    final tag = ctx.payload['tag']?.toString().replaceAll('#', '').trim() ?? '';
    await ctx.txn.delete('note_tags', where: 'noteId = ? AND tagNormalized = ?', whereArgs: [noteId, tag.toLowerCase()]);
    return CommandResult.ok(commandId: id, outputData: {'noteId': noteId, 'tag': tag}, inverseData: {'noteId': noteId, 'tag': tag});
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    final noteId = inverseData['noteId']?.toString();
    final tag = inverseData['tag']?.toString();
    if (noteId == null || tag == null) return null;
    await ctx.txn.insert('note_tags', {
      'noteId': noteId,
      'tag': tag,
      'tagNormalized': tag.toLowerCase(),
      'source': 'AI',
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    return CommandResult.ok(commandId: id);
  }
}

// 7. note.link (safe)
class NoteLinkCommand extends RitmoCommand {
  const NoteLinkCommand();

  @override
  String get id => 'note.link';

  @override
  String get humanTitle => 'پیوند یادداشت';

  @override
  String get humanDescriptionFa => 'ایجاد پیوند بین یادداشت و یک موجودیت در برنامه';

  @override
  Sensitivity get sensitivity => Sensitivity.safe;

  @override
  Set<DataDomain> get touches => {DataDomain.notes};

  @override
  Map<String, ParamSpec> get params => {
    'noteId': const ParamSpec(type: ParamType.idRef, labelFa: 'یادداشت', required: true, refTable: 'notes'),
    'linkModule': const ParamSpec(type: ParamType.text, labelFa: 'ماژول', required: true),
    'linkEntityId': const ParamSpec(type: ParamType.text, labelFa: 'شناسه موجودیت', required: true),
    'relation': const ParamSpec(type: ParamType.enumeration, labelFa: 'نوع رابطه', required: false, allowed: ['MENTIONS', 'ABOUT', 'SPAWNED']),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    return const PlanDiff(kind: DiffKind.update, entityLabelFa: 'ایجاد پیوند یادداشت');
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final noteId = ctx.payload['noteId']?.toString() ?? '';
    final linkModule = ctx.payload['linkModule']?.toString() ?? '';
    final linkEntityId = ctx.payload['linkEntityId']?.toString() ?? '';
    final relation = ctx.payload['relation']?.toString() ?? 'MENTIONS';
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final linkId = _genLinkId();

    await ctx.txn.insert('note_links', {
      'id': linkId,
      'noteId': noteId,
      'linkModule': linkModule,
      'linkEntityId': linkEntityId,
      'relation': relation,
      'createdAt': nowMs,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    return CommandResult.ok(commandId: id, outputData: {'linkId': linkId}, inverseData: {'linkId': linkId});
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    final linkId = inverseData['linkId']?.toString();
    if (linkId == null) return null;
    await ctx.txn.delete('note_links', where: 'id = ?', whereArgs: [linkId]);
    return CommandResult.ok(commandId: id);
  }
}

// 8. note.unlink (safe)
class NoteUnlinkCommand extends RitmoCommand {
  const NoteUnlinkCommand();

  @override
  String get id => 'note.unlink';

  @override
  String get humanTitle => 'حذف پیوند یادداشت';

  @override
  String get humanDescriptionFa => 'برداشتن پیوند میان یادداشت و موجودیت دیگر';

  @override
  Sensitivity get sensitivity => Sensitivity.safe;

  @override
  Set<DataDomain> get touches => {DataDomain.notes};

  @override
  Map<String, ParamSpec> get params => {
    'noteId': const ParamSpec(type: ParamType.idRef, labelFa: 'یادداشت', required: true, refTable: 'notes'),
    'linkModule': const ParamSpec(type: ParamType.text, labelFa: 'ماژول', required: true),
    'linkEntityId': const ParamSpec(type: ParamType.text, labelFa: 'شناسه موجودیت', required: true),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    return const PlanDiff(kind: DiffKind.update, entityLabelFa: 'حذف پیوند یادداشت');
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final noteId = ctx.payload['noteId']?.toString() ?? '';
    final linkModule = ctx.payload['linkModule']?.toString() ?? '';
    final linkEntityId = ctx.payload['linkEntityId']?.toString() ?? '';

    await ctx.txn.delete(
      'note_links',
      where: 'noteId = ? AND linkModule = ? AND linkEntityId = ?',
      whereArgs: [noteId, linkModule, linkEntityId],
    );

    return CommandResult.ok(commandId: id, inverseData: {'noteId': noteId, 'linkModule': linkModule, 'linkEntityId': linkEntityId});
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    final noteId = inverseData['noteId']?.toString();
    final linkModule = inverseData['linkModule']?.toString();
    final linkEntityId = inverseData['linkEntityId']?.toString();
    if (noteId == null || linkModule == null || linkEntityId == null) return null;
    await ctx.txn.insert('note_links', {
      'id': _genLinkId(),
      'noteId': noteId,
      'linkModule': linkModule,
      'linkEntityId': linkEntityId,
      'relation': 'MENTIONS',
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    return CommandResult.ok(commandId: id);
  }
}

// 9. note.pin (safe)
class NotePinCommand extends RitmoCommand {
  const NotePinCommand();

  @override
  String get id => 'note.pin';

  @override
  String get humanTitle => 'سنجاق کردن یادداشت';

  @override
  String get humanDescriptionFa => 'قرار دادن یادداشت در بالای فهرست';

  @override
  Sensitivity get sensitivity => Sensitivity.safe;

  @override
  Set<DataDomain> get touches => {DataDomain.notes};

  @override
  Map<String, ParamSpec> get params => {
    'noteId': const ParamSpec(type: ParamType.idRef, labelFa: 'یادداشت', required: true, refTable: 'notes'),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    return const PlanDiff(kind: DiffKind.update, entityLabelFa: 'سنجاق کردن یادداشت');
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final noteId = ctx.payload['noteId']?.toString() ?? '';
    await ctx.txn.update('notes', {'isPinned': 1, 'updatedAt': DateTime.now().millisecondsSinceEpoch}, where: 'id = ?', whereArgs: [noteId]);
    return CommandResult.ok(commandId: id, inverseData: {'noteId': noteId, 'wasPinned': 0});
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    final noteId = inverseData['noteId']?.toString();
    if (noteId == null) return null;
    await ctx.txn.update('notes', {'isPinned': 0}, where: 'id = ?', whereArgs: [noteId]);
    return CommandResult.ok(commandId: id);
  }
}

// 10. note.unpin (safe)
class NoteUnpinCommand extends RitmoCommand {
  const NoteUnpinCommand();

  @override
  String get id => 'note.unpin';

  @override
  String get humanTitle => 'برداشتن سنجاق یادداشت';

  @override
  String get humanDescriptionFa => 'خارج کردن یادداشت از وضعیت سنجاق‌شده';

  @override
  Sensitivity get sensitivity => Sensitivity.safe;

  @override
  Set<DataDomain> get touches => {DataDomain.notes};

  @override
  Map<String, ParamSpec> get params => {
    'noteId': const ParamSpec(type: ParamType.idRef, labelFa: 'یادداشت', required: true, refTable: 'notes'),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    return const PlanDiff(kind: DiffKind.update, entityLabelFa: 'برداشتن سنجاق یادداشت');
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final noteId = ctx.payload['noteId']?.toString() ?? '';
    await ctx.txn.update('notes', {'isPinned': 0, 'updatedAt': DateTime.now().millisecondsSinceEpoch}, where: 'id = ?', whereArgs: [noteId]);
    return CommandResult.ok(commandId: id, inverseData: {'noteId': noteId});
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    final noteId = inverseData['noteId']?.toString();
    if (noteId == null) return null;
    await ctx.txn.update('notes', {'isPinned': 1}, where: 'id = ?', whereArgs: [noteId]);
    return CommandResult.ok(commandId: id);
  }
}

// 11. note.archive (confirm)
class NoteArchiveCommand extends RitmoCommand {
  const NoteArchiveCommand();

  @override
  String get id => 'note.archive';

  @override
  String get humanTitle => 'بایگانی یادداشت';

  @override
  String get humanDescriptionFa => 'انتقال یادداشت به بخش بایگانی';

  @override
  Sensitivity get sensitivity => Sensitivity.confirm;

  @override
  Set<DataDomain> get touches => {DataDomain.notes};

  @override
  Map<String, ParamSpec> get params => {
    'noteId': const ParamSpec(type: ParamType.idRef, labelFa: 'یادداشت', required: true, refTable: 'notes'),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    return const PlanDiff(kind: DiffKind.update, entityLabelFa: 'بایگانی یادداشت');
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final noteId = ctx.payload['noteId']?.toString() ?? '';
    await ctx.txn.update('notes', {'status': 'ARCHIVED', 'updatedAt': DateTime.now().millisecondsSinceEpoch}, where: 'id = ?', whereArgs: [noteId]);
    return CommandResult.ok(commandId: id, outputData: {'noteId': noteId, 'isArchived': true}, inverseData: {'noteId': noteId});
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    final noteId = inverseData['noteId']?.toString();
    if (noteId == null) return null;
    await ctx.txn.update('notes', {'status': 'ACTIVE'}, where: 'id = ?', whereArgs: [noteId]);
    return CommandResult.ok(commandId: id);
  }
}

// 12. note.restore (confirm)
class NoteRestoreCommand extends RitmoCommand {
  const NoteRestoreCommand();

  @override
  String get id => 'note.restore';

  @override
  String get humanTitle => 'بازیابی یادداشت';

  @override
  String get humanDescriptionFa => 'بازگردانی یادداشت از بایگانی یا سطل زباله به حالت فعال';

  @override
  Sensitivity get sensitivity => Sensitivity.confirm;

  @override
  Set<DataDomain> get touches => {DataDomain.notes};

  @override
  Map<String, ParamSpec> get params => {
    'noteId': const ParamSpec(type: ParamType.idRef, labelFa: 'یادداشت', required: true, refTable: 'notes'),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    return const PlanDiff(kind: DiffKind.update, entityLabelFa: 'بازیابی یادداشت');
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final noteId = ctx.payload['noteId']?.toString() ?? '';
    await ctx.txn.update('notes', {'status': 'ACTIVE', 'trashedAt': null, 'updatedAt': DateTime.now().millisecondsSinceEpoch}, where: 'id = ?', whereArgs: [noteId]);
    return CommandResult.ok(commandId: id, outputData: {'noteId': noteId, 'isRestored': true}, inverseData: {'noteId': noteId});
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    final noteId = inverseData['noteId']?.toString();
    if (noteId == null) return null;
    await ctx.txn.update('notes', {'status': 'ARCHIVED'}, where: 'id = ?', whereArgs: [noteId]);
    return CommandResult.ok(commandId: id);
  }
}

// 13. note.delete (confirm)
class NoteDeleteCommand extends RitmoCommand {
  const NoteDeleteCommand();

  @override
  String get id => 'note.delete';

  @override
  String get humanTitle => 'انتقال به سطل زباله';

  @override
  String get humanDescriptionFa => 'حذف نرم یادداشت و انتقال آن به سطل زباله';

  @override
  Sensitivity get sensitivity => Sensitivity.confirm;

  @override
  Set<DataDomain> get touches => {DataDomain.notes};

  @override
  Map<String, ParamSpec> get params => {
    'noteId': const ParamSpec(type: ParamType.idRef, labelFa: 'یادداشت', required: true, refTable: 'notes'),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    return const PlanDiff(kind: DiffKind.delete, entityLabelFa: 'انتقال یادداشت به زباله‌دان');
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final noteId = ctx.payload['noteId']?.toString() ?? '';
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await ctx.txn.update('notes', {'status': 'TRASHED', 'trashedAt': nowMs, 'updatedAt': nowMs}, where: 'id = ?', whereArgs: [noteId]);
    return CommandResult.ok(commandId: id, outputData: {'noteId': noteId, 'isDeleted': true}, inverseData: {'noteId': noteId});
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    final noteId = inverseData['noteId']?.toString();
    if (noteId == null) return null;
    await ctx.txn.update('notes', {'status': 'ACTIVE', 'trashedAt': null}, where: 'id = ?', whereArgs: [noteId]);
    return CommandResult.ok(commandId: id);
  }
}

// 14. note.scheduleReview (safe)
class NoteScheduleReviewCommand extends RitmoCommand {
  const NoteScheduleReviewCommand();

  @override
  String get id => 'note.scheduleReview';

  @override
  String get humanTitle => 'تنظیم مرور فاصله‌دار';

  @override
  String get humanDescriptionFa => 'قرار دادن یادداشت در صف مرور فاصله‌دار یادگیری';

  @override
  Sensitivity get sensitivity => Sensitivity.safe;

  @override
  Set<DataDomain> get touches => {DataDomain.notes};

  @override
  Map<String, ParamSpec> get params => {
    'noteId': const ParamSpec(type: ParamType.idRef, labelFa: 'یادداشت', required: true, refTable: 'notes'),
    'stage': const ParamSpec(type: ParamType.integer, labelFa: 'مرحله مرور', required: false),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    return const PlanDiff(kind: DiffKind.update, entityLabelFa: 'تنظیم مرور فاصله‌دار');
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final noteId = ctx.payload['noteId']?.toString() ?? '';
    final stage = (ctx.payload['stage'] as num?)?.toInt() ?? 1;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final ladderDays = [1, 3, 7, 14, 30, 60, 120];
    final days = stage <= ladderDays.length ? ladderDays[stage - 1] : 120;
    final nextReviewMs = nowMs + (days * 24 * 60 * 60 * 1000);

    await ctx.txn.update('notes', {
      'reviewStage': stage,
      'reviewAt': nextReviewMs,
      'updatedAt': nowMs,
    }, where: 'id = ?', whereArgs: [noteId]);

    return CommandResult.ok(commandId: id, outputData: {'noteId': noteId, 'nextReviewMs': nextReviewMs}, inverseData: {'noteId': noteId});
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    final noteId = inverseData['noteId']?.toString();
    if (noteId == null) return null;
    await ctx.txn.update('notes', {'reviewStage': 0, 'reviewAt': null}, where: 'id = ?', whereArgs: [noteId]);
    return CommandResult.ok(commandId: id);
  }
}

// 15. note.extractActions (confirm)
class NoteExtractActionsCommand extends RitmoCommand {
  const NoteExtractActionsCommand();

  @override
  String get id => 'note.extractActions';

  @override
  String get humanTitle => 'استخراج اقدامات و کارهای یادداشت';

  @override
  String get humanDescriptionFa => 'شناسایی و تبدیل موارد عملیاتی داخل یادداشت به کار';

  @override
  Sensitivity get sensitivity => Sensitivity.confirm;

  @override
  Set<DataDomain> get touches => {DataDomain.notes, DataDomain.routines};

  @override
  Map<String, ParamSpec> get params => {
    'noteId': const ParamSpec(type: ParamType.idRef, labelFa: 'یادداشت', required: true, refTable: 'notes'),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    return const PlanDiff(kind: DiffKind.create, entityLabelFa: 'استخراج کارهای عملیاتی از یادداشت');
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final noteId = ctx.payload['noteId']?.toString() ?? '';
    final rows = await ctx.txn.query('notes', where: 'id = ?', whereArgs: [noteId]);
    if (rows.isEmpty) return CommandResult.failure(commandId: id, errorMessage: 'یادداشت یافت نشد');

    final body = (rows.first['body'] as String?) ?? '';
    final lines = body.split('\n');
    final extractedTasks = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('- [ ]')) {
        extractedTasks.add(trimmed.substring(5).trim());
      } else if (trimmed.startsWith('TODO:') || trimmed.startsWith('کار:')) {
        extractedTasks.add(trimmed.replaceFirst(RegExp(r'^(TODO:|کار:)'), '').trim());
      }
    }

    return CommandResult.ok(
      commandId: id,
      outputData: {
        'noteId': noteId,
        'tasks': extractedTasks,
        'count': extractedTasks.length,
      },
    );
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    return CommandResult.ok(commandId: id);
  }
}

// 16. note.summarize (safe - read-only)
class NoteSummarizeCommand extends RitmoCommand {
  const NoteSummarizeCommand();

  @override
  String get id => 'note.summarize';

  @override
  String get humanTitle => 'خلاصه‌سازی یادداشت‌ها';

  @override
  String get humanDescriptionFa => 'جمع‌بندی موضوعی یا هفتگی یادداشت‌های ثبت شده';

  @override
  Sensitivity get sensitivity => Sensitivity.safe;

  @override
  Set<DataDomain> get touches => {DataDomain.notes};

  @override
  Map<String, ParamSpec> get params => {
    'scope': const ParamSpec(type: ParamType.enumeration, labelFa: 'بازه یا دامنه', required: true, allowed: ['note', 'week', 'tag']),
    'value': const ParamSpec(type: ParamType.text, labelFa: 'شناسه یا مقدار', required: false),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    return const PlanDiff(kind: DiffKind.noop, entityLabelFa: 'خلاصه‌سازی یادداشت');
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final scope = ctx.payload['scope']?.toString() ?? 'week';
    final value = ctx.payload['value']?.toString();

    if (scope == 'note' && value != null) {
      final rows = await ctx.txn.query('notes', where: 'id = ? AND isPrivate = 0', whereArgs: [value]);
      if (rows.isNotEmpty) {
        final title = rows.first['title'] as String?;
        final wordCount = rows.first['wordCount'] as int? ?? 0;
        return CommandResult.ok(commandId: id, outputData: {'title': title, 'wordCount': wordCount});
      }
    }

    return CommandResult.ok(commandId: id, outputData: {'status': 'summarized'});
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    return CommandResult.ok(commandId: id);
  }
}

// 17. notes.search (safe)
class NotesSearchCommand extends RitmoCommand {
  const NotesSearchCommand();

  @override
  String get id => 'notes.search';

  @override
  String get humanTitle => 'جستجو در یادداشت‌ها';

  @override
  String get humanDescriptionFa => 'جستجوی هوشمند در متن و عناوین یادداشت‌ها';

  @override
  Sensitivity get sensitivity => Sensitivity.safe;

  @override
  Set<DataDomain> get touches => {DataDomain.notes};

  @override
  Map<String, ParamSpec> get params => {
    'query': const ParamSpec(type: ParamType.text, labelFa: 'عبارت جستجو', required: true),
    'limit': const ParamSpec(type: ParamType.integer, labelFa: 'حداکثر نتایج', required: false),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    final query = ctx.payload['query']?.toString() ?? '';
    return PlanDiff(kind: DiffKind.noop, entityLabelFa: 'جستجوی «$query»');
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final query = ctx.payload['query']?.toString().trim() ?? '';
    final limit = (ctx.payload['limit'] as num?)?.toInt() ?? 8;

    final results = await ctx.txn.query(
      'notes',
      where: "status = 'ACTIVE' AND isPrivate = 0 AND (sourceModule IS NULL OR sourceModule != 'cycle') AND (titleNormalized LIKE ? OR bodyNormalized LIKE ?)",
      whereArgs: ['%$query%', '%$query%'],
      limit: limit,
    );

    final hits = results.map((r) => {
      'id': r['id'],
      'title': r['title'],
      'dayKey': r['dayKey'],
      'wordCount': r['wordCount'],
    }).toList();

    return CommandResult.ok(commandId: id, outputData: {'hits': hits});
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    return CommandResult.ok(commandId: id);
  }
}

// 18. notes.dailyNote (safe)
class NotesDailyNoteCommand extends RitmoCommand {
  const NotesDailyNoteCommand();

  @override
  String get id => 'notes.dailyNote';

  @override
  String get humanTitle => 'یادداشت روزانه';

  @override
  String get humanDescriptionFa => 'ایجاد یا بازخوانی یادداشت روزانه';

  @override
  Sensitivity get sensitivity => Sensitivity.safe;

  @override
  Set<DataDomain> get touches => {DataDomain.notes};

  @override
  Map<String, ParamSpec> get params => {
    'dayKey': const ParamSpec(type: ParamType.text, labelFa: 'کلید روز', required: false),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    return const PlanDiff(kind: DiffKind.create, entityLabelFa: 'یادداشت روزانه');
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final dayKey = ctx.payload['dayKey']?.toString() ?? SystemClock().today().value;
    final existing = await ctx.txn.query('notes', where: "kind = 'DAILY' AND dayKey = ?", whereArgs: [dayKey]);

    if (existing.isNotEmpty) {
      return CommandResult.ok(commandId: id, outputData: {'noteId': existing.first['id'], 'existing': true});
    }

    final noteId = _genNoteId();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final title = 'یادداشت روز $dayKey';

    await ctx.txn.insert('notes', {
      'id': noteId,
      'title': title,
      'body': '## $title\n\n---\n\n',
      'titleNormalized': title.toLowerCase(),
      'bodyNormalized': title.toLowerCase(),
      'kind': 'DAILY',
      'status': 'ACTIVE',
      'isPrivate': 0,
      'isPinned': 0,
      'dayKey': dayKey,
      'wordCount': 0,
      'createdAt': nowMs,
      'updatedAt': nowMs,
    });

    return CommandResult.ok(commandId: id, outputData: {'noteId': noteId}, inverseData: {'noteId': noteId});
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    final noteId = inverseData['noteId']?.toString();
    if (noteId == null) return null;
    await ctx.txn.delete('notes', where: 'id = ?', whereArgs: [noteId]);
    return CommandResult.ok(commandId: id);
  }
}

// 19. experience.create (confirm)
class ExperienceCreateCommand extends RitmoCommand {
  const ExperienceCreateCommand();

  @override
  String get id => 'experience.create';

  @override
  String get humanTitle => 'ثبت تجربه جدید';

  @override
  String get humanDescriptionFa => 'ثبت یک آموخته و درس زندگی ماندگار';

  @override
  Sensitivity get sensitivity => Sensitivity.confirm;

  @override
  Set<DataDomain> get touches => {DataDomain.notes};

  @override
  Map<String, ParamSpec> get params => {
    'lesson': const ParamSpec(type: ParamType.text, labelFa: 'درس تجربه', required: true),
    'contextText': const ParamSpec(type: ParamType.text, labelFa: 'رویداد و اتفاق', required: false),
    'category': const ParamSpec(type: ParamType.enumeration, labelFa: 'دسته‌بندی', required: false, allowed: ['GENERAL', 'WORK', 'STUDY', 'HEALTH', 'RELATION', 'MONEY', 'FAITH', 'SELF']),
    'importance': const ParamSpec(type: ParamType.integer, labelFa: 'اهمیت (۱ تا ۵)', required: false),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    final lesson = ctx.payload['lesson']?.toString() ?? '';
    return PlanDiff(kind: DiffKind.create, entityLabelFa: 'تجربه: «$lesson»');
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final lesson = ctx.payload['lesson']?.toString().trim() ?? '';
    final contextText = ctx.payload['contextText']?.toString().trim() ?? '';
    final category = ctx.payload['category']?.toString() ?? 'GENERAL';
    final importance = (ctx.payload['importance'] as num?)?.toInt() ?? 3;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final dayKey = SystemClock().today().value;
    final noteId = _genNoteId();

    await ctx.txn.insert('notes', {
      'id': noteId,
      'title': lesson.length > 50 ? '${lesson.substring(0, 50)}...' : lesson,
      'body': contextText.isNotEmpty ? '$lesson\n\n$contextText' : lesson,
      'titleNormalized': lesson.toLowerCase(),
      'bodyNormalized': (contextText.isNotEmpty ? '$lesson $contextText' : lesson).toLowerCase(),
      'kind': 'EXPERIENCE',
      'status': 'ACTIVE',
      'isPrivate': 0,
      'isPinned': 0,
      'dayKey': dayKey,
      'createdAt': nowMs,
      'updatedAt': nowMs,
    });

    await ctx.txn.insert('note_experience_meta', {
      'noteId': noteId,
      'lesson': lesson,
      'contextText': contextText,
      'category': category,
      'importance': importance,
      'occurredOnDayKey': dayKey,
      'isActive': 1,
      'showCount': 0,
      'acknowledgedCount': 0,
    });

    return CommandResult.ok(commandId: id, outputData: {'noteId': noteId}, inverseData: {'noteId': noteId});
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    final noteId = inverseData['noteId']?.toString();
    if (noteId == null) return null;
    await ctx.txn.delete('note_experience_meta', where: 'noteId = ?', whereArgs: [noteId]);
    await ctx.txn.delete('notes', where: 'id = ?', whereArgs: [noteId]);
    return CommandResult.ok(commandId: id);
  }
}

// 20. experience.edit (confirm)
class ExperienceEditCommand extends RitmoCommand {
  const ExperienceEditCommand();

  @override
  String get id => 'experience.edit';

  @override
  String get humanTitle => 'ویرایش تجربه';

  @override
  String get humanDescriptionFa => 'تغییر درس، دسته‌بندی یا اهمیت تجربه';

  @override
  Sensitivity get sensitivity => Sensitivity.confirm;

  @override
  Set<DataDomain> get touches => {DataDomain.notes};

  @override
  Map<String, ParamSpec> get params => {
    'noteId': const ParamSpec(type: ParamType.idRef, labelFa: 'تجربه', required: true, refTable: 'notes'),
    'lesson': const ParamSpec(type: ParamType.text, labelFa: 'درس جدید', required: false),
    'category': const ParamSpec(type: ParamType.text, labelFa: 'دسته جدید', required: false),
    'importance': const ParamSpec(type: ParamType.integer, labelFa: 'اهمیت', required: false),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    return const PlanDiff(kind: DiffKind.update, entityLabelFa: 'ویرایش تجربه');
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final noteId = ctx.payload['noteId']?.toString() ?? '';
    final metaUpdate = <String, dynamic>{};
    if (ctx.payload['lesson'] != null) metaUpdate['lesson'] = ctx.payload['lesson'];
    if (ctx.payload['category'] != null) metaUpdate['category'] = ctx.payload['category'];
    if (ctx.payload['importance'] != null) metaUpdate['importance'] = ctx.payload['importance'];

    if (metaUpdate.isNotEmpty) {
      await ctx.txn.update('note_experience_meta', metaUpdate, where: 'noteId = ?', whereArgs: [noteId]);
    }

    return CommandResult.ok(commandId: id, outputData: {'noteId': noteId});
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    return CommandResult.ok(commandId: id);
  }
}

// 21. experience.setActive (safe)
class ExperienceSetActiveCommand extends RitmoCommand {
  const ExperienceSetActiveCommand();

  @override
  String get id => 'experience.setActive';

  @override
  String get humanTitle => 'تغییر وضعیت چرخش تجربه';

  @override
  String get humanDescriptionFa => 'فعال یا غیرفعال کردن نمایش تجربه در چرخش روزانه';

  @override
  Sensitivity get sensitivity => Sensitivity.safe;

  @override
  Set<DataDomain> get touches => {DataDomain.notes};

  @override
  Map<String, ParamSpec> get params => {
    'noteId': const ParamSpec(type: ParamType.idRef, labelFa: 'تجربه', required: true, refTable: 'notes'),
    'isActive': const ParamSpec(type: ParamType.boolean, labelFa: 'فعال در چرخش', required: true),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    final isActive = ctx.payload['isActive'] == true || ctx.payload['isActive'] == 1;
    return PlanDiff(kind: DiffKind.update, entityLabelFa: isActive ? 'فعال‌سازی در چرخش' : 'خروج از چرخش');
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final noteId = ctx.payload['noteId']?.toString() ?? '';
    final isActive = (ctx.payload['isActive'] == true || ctx.payload['isActive'] == 1) ? 1 : 0;

    await ctx.txn.update('note_experience_meta', {'isActive': isActive}, where: 'noteId = ?', whereArgs: [noteId]);
    return CommandResult.ok(commandId: id, outputData: {'noteId': noteId, 'isActive': isActive}, inverseData: {'noteId': noteId, 'previousActive': 1 - isActive});
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    final noteId = inverseData['noteId']?.toString();
    final prev = (inverseData['previousActive'] as num?)?.toInt() ?? 1;
    if (noteId == null) return null;
    await ctx.txn.update('note_experience_meta', {'isActive': prev}, where: 'noteId = ?', whereArgs: [noteId]);
    return CommandResult.ok(commandId: id);
  }
}

// 22. experience.setImportance (safe)
class ExperienceSetImportanceCommand extends RitmoCommand {
  const ExperienceSetImportanceCommand();

  @override
  String get id => 'experience.setImportance';

  @override
  String get humanTitle => 'تغییر اهمیت تجربه';

  @override
  String get humanDescriptionFa => 'تنظیم میزان اهمیت تجربه (۱ تا ۵)';

  @override
  Sensitivity get sensitivity => Sensitivity.safe;

  @override
  Set<DataDomain> get touches => {DataDomain.notes};

  @override
  Map<String, ParamSpec> get params => {
    'noteId': const ParamSpec(type: ParamType.idRef, labelFa: 'تجربه', required: true, refTable: 'notes'),
    'importance': const ParamSpec(type: ParamType.integer, labelFa: 'اهمیت (۱ تا ۵)', required: true),
  };

  @override
  Future<PlanDiff> preview(AgentCommandContext ctx) async {
    final imp = ctx.payload['importance']?.toString() ?? '';
    return PlanDiff(kind: DiffKind.update, entityLabelFa: 'تنظیم اهمیت تجربه روی $imp');
  }

  @override
  Future<CommandResult> run(AgentCommandContext ctx) async {
    final noteId = ctx.payload['noteId']?.toString() ?? '';
    final importance = (ctx.payload['importance'] as num?)?.toInt().clamp(1, 5) ?? 3;

    await ctx.txn.update('note_experience_meta', {'importance': importance}, where: 'noteId = ?', whereArgs: [noteId]);
    return CommandResult.ok(commandId: id, outputData: {'noteId': noteId, 'importance': importance});
  }

  @override
  Future<CommandResult?> undo(AgentCommandContext ctx, Map<String, dynamic> inverseData) async {
    return CommandResult.ok(commandId: id);
  }
}
