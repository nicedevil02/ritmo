import 'package:ritmo/core/domain/commands/command_plan.dart';
import 'package:ritmo/core/domain/commands/param_spec.dart';
import 'package:ritmo/core/domain/commands/ritmo_command.dart';
import 'package:ritmo/core/domain/engines/engine_invalidation_tag.dart';
import 'package:ritmo/features/notes/data/experience_repository.dart';
import 'package:ritmo/features/notes/data/notes_repository.dart';
import 'package:ritmo/features/notes/domain/note_models.dart';
import 'package:ritmo/features/notes/logic/note_fts_engine.dart';

class CreateNoteCommand extends RitmoCommand {
  @override
  String get name => 'create_note';

  @override
  String get description => 'ایجاد یادداشت جدید در دفترچه';

  @override
  DataDomain get domain => DataDomain.notes;

  @override
  Sensitivity get sensitivity => Sensitivity.safe;

  @override
  Set<EngineInvalidationTag> get invalidates => {EngineInvalidationTag.notes};

  @override
  List<ParamSpec> get parameters => [
    const ParamSpec(name: 'title', type: ParamType.string, isRequired: false),
    const ParamSpec(name: 'body', type: ParamType.string, isRequired: true),
    const ParamSpec(name: 'kind', type: ParamType.string, isRequired: false),
    const ParamSpec(name: 'tags', type: ParamType.array, isRequired: false),
  ];

  @override
  Future<CommandResult> execute(AgentCommandContext context) async {
    final title = context.payload['title'] as String?;
    final body = context.payload['body'] as String? ?? '';
    final kindStr = context.payload['kind'] as String?;
    final tagsList = (context.payload['tags'] as List?)?.cast<String>();

    final note = await NotesRepository.instance.create(
      title: title,
      body: body,
      kind: NoteKind.parse(kindStr),
      tags: tagsList,
    );

    return CommandResult(
      success: true,
      commandId: name,
      outputData: note.toMap(),
    );
  }
}

class UpdateNoteCommand extends RitmoCommand {
  @override
  String get name => 'update_note';

  @override
  String get description => 'ویرایش یادداشت موجود';

  @override
  DataDomain get domain => DataDomain.notes;

  @override
  Sensitivity get sensitivity => Sensitivity.safe;

  @override
  Set<EngineInvalidationTag> get invalidates => {EngineInvalidationTag.notes};

  @override
  List<ParamSpec> get parameters => [
    const ParamSpec(name: 'noteId', type: ParamType.string, isRequired: true),
    const ParamSpec(name: 'title', type: ParamType.string, isRequired: false),
    const ParamSpec(name: 'body', type: ParamType.string, isRequired: false),
  ];

  @override
  Future<CommandResult> execute(AgentCommandContext context) async {
    final noteId = context.payload['noteId'] as String;
    final existing = await NotesRepository.instance.getById(noteId);
    if (existing == null) {
      return CommandResult(success: false, commandId: name, errorMessage: 'یادداشت یافت نشد');
    }

    final newTitle = context.payload['title'] as String? ?? existing.title;
    final newBody = context.payload['body'] as String? ?? existing.body;

    final updated = existing.copyWith(title: newTitle, body: newBody);
    await NotesRepository.instance.update(updated, reason: 'AI_EDIT');

    return CommandResult(success: true, commandId: name, outputData: updated.toMap());
  }
}

class SearchNotesCommand extends RitmoCommand {
  @override
  String get name => 'search_notes';

  @override
  String get description => 'جستجو در یادداشت‌ها و تجربه‌ها';

  @override
  DataDomain get domain => DataDomain.notes;

  @override
  Sensitivity get sensitivity => Sensitivity.safe;

  @override
  Set<EngineInvalidationTag> get invalidates => {};

  @override
  List<ParamSpec> get parameters => [
    const ParamSpec(name: 'query', type: ParamType.string, isRequired: true),
  ];

  @override
  Future<CommandResult> execute(AgentCommandContext context) async {
    final query = context.payload['query'] as String? ?? '';
    final results = await NoteFtsEngine.instance.search(query);
    return CommandResult(
      success: true,
      commandId: name,
      outputData: {'notes': results.map((n) => n.toMap()).toList()},
    );
  }
}

class CreateExperienceCommand extends RitmoCommand {
  @override
  String get name => 'create_experience';

  @override
  String get description => 'ثبت تجربه یا آموخته جدید در زندگی';

  @override
  DataDomain get domain => DataDomain.notes;

  @override
  Sensitivity get sensitivity => Sensitivity.safe;

  @override
  Set<EngineInvalidationTag> get invalidates => {EngineInvalidationTag.notes};

  @override
  List<ParamSpec> get parameters => [
    const ParamSpec(name: 'lesson', type: ParamType.string, isRequired: true),
    const ParamSpec(name: 'contextText', type: ParamType.string, isRequired: false),
    const ParamSpec(name: 'category', type: ParamType.string, isRequired: false),
    const ParamSpec(name: 'importance', type: ParamType.integer, isRequired: false),
  ];

  @override
  Future<CommandResult> execute(AgentCommandContext context) async {
    final lesson = context.payload['lesson'] as String;
    final ctxText = context.payload['contextText'] as String?;
    final catStr = context.payload['category'] as String?;
    final imp = context.payload['importance'] as int? ?? 3;

    final exp = await ExperienceRepository.instance.create(
      lesson: lesson,
      contextText: ctxText,
      category: ExperienceCategory.parse(catStr),
      importance: imp,
    );

    return CommandResult(success: true, commandId: name, outputData: exp.toMap());
  }
}

class ListExperiencesCommand extends RitmoCommand {
  @override
  String get name => 'list_experiences';

  @override
  String get description => 'لیست تجربه‌ها و آموزه‌ها';

  @override
  DataDomain get domain => DataDomain.notes;

  @override
  Sensitivity get sensitivity => Sensitivity.safe;

  @override
  Set<EngineInvalidationTag> get invalidates => {};

  @override
  List<ParamSpec> get parameters => [];

  @override
  Future<CommandResult> execute(AgentCommandContext context) async {
    final exps = await ExperienceRepository.instance.listActive();
    return CommandResult(
      success: true,
      commandId: name,
      outputData: {'experiences': exps.map((e) => e.toMap()).toList()},
    );
  }
}

class GetNoteDetailsCommand extends RitmoCommand {
  @override
  String get name => 'get_note_details';

  @override
  String get description => 'دریافت جزئیات کامل یک یادداشت';

  @override
  DataDomain get domain => DataDomain.notes;

  @override
  Sensitivity get sensitivity => Sensitivity.safe;

  @override
  Set<EngineInvalidationTag> get invalidates => {};

  @override
  List<ParamSpec> get parameters => [
    const ParamSpec(name: 'noteId', type: ParamType.string, isRequired: true),
  ];

  @override
  Future<CommandResult> execute(AgentCommandContext context) async {
    final noteId = context.payload['noteId'] as String;
    final note = await NotesRepository.instance.getById(noteId);
    if (note == null) {
      return CommandResult(success: false, commandId: name, errorMessage: 'یادداشت پیدا نشد');
    }
    return CommandResult(success: true, commandId: name, outputData: note.toMap());
  }
}
