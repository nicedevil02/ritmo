import 'package:ritmo/features/notes/data/notes_repository.dart';
import 'package:ritmo/features/notes/domain/note_models.dart';
import 'package:ritmo/features/notes/logic/note_fts_engine.dart';

class NotesPersonaContextInjector {
  NotesPersonaContextInjector._();
  static final NotesPersonaContextInjector instance =
      NotesPersonaContextInjector._();

  /// Builds context prompt text for AI personas (P-01, P-02).
  ///
  /// EXPLICIT PRODUCT RULE (Decision 7):
  /// Notes sourced from cycle module (`sourceModule == 'cycle'`) are strictly
  /// excluded from AI persona context prompt outside cycle persona itself!
  Future<String> buildContextForPersona({
    required String personaId,
    String? currentTopic,
    int limit = 5,
  }) async {
    final List<Note> candidates;
    if (currentTopic != null && currentTopic.trim().isNotEmpty) {
      candidates = await NoteFtsEngine.instance.search(currentTopic, limit: 10);
    } else {
      candidates = await NotesRepository.instance.listRecent(limit: 10);
    }

    // Exclude private notes & cycle module notes (Decision 7)
    final filtered = candidates
        .where((n) {
          if (n.isPrivate) return false;
          if (n.sourceModule?.toLowerCase() == 'cycle' &&
              personaId.toLowerCase() != 'cycle')
            return false;
          return true;
        })
        .take(limit)
        .toList();

    if (filtered.isEmpty) return '';

    final sb = StringBuffer();
    sb.writeln('--- یادداشت‌ها و تجربه‌های مرتبط کاربر ---');
    for (final note in filtered) {
      final kindLabel = note.kind == NoteKind.experience
          ? '[تجربه زندگی]'
          : '[یادداشت]';
      sb.writeln('• $kindLabel ${note.title ?? ''}: ${note.body}');
    }
    sb.writeln('----------------------------------------');

    return sb.toString();
  }
}
