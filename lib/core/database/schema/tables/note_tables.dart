import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

class NoteTables {
  static Future<void> create(DatabaseExecutor db) async {
    await ensureSchema(db);
  }

  /// Self-healing schema check and initialization for `notes` and related tables.
  /// Ensures all required tables, columns, and indexes exist regardless of database version
  /// or previous migration history.
  static Future<void> ensureSchema(DatabaseExecutor db) async {
    try {
      // 1. notes table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS notes (
          id TEXT PRIMARY KEY,
          title TEXT,
          body TEXT NOT NULL DEFAULT '',
          titleNormalized TEXT NOT NULL DEFAULT '',
          bodyNormalized TEXT NOT NULL DEFAULT '',
          kind TEXT NOT NULL DEFAULT 'NOTE',
          status TEXT NOT NULL DEFAULT 'ACTIVE',
          isPrivate INTEGER NOT NULL DEFAULT 0,
          isPinned INTEGER NOT NULL DEFAULT 0,
          dayKey TEXT,
          sourceModule TEXT,
          sourceEntityId TEXT,
          captureContextJson TEXT,
          wordCount INTEGER NOT NULL DEFAULT 0,
          createdAt INTEGER NOT NULL,
          updatedAt INTEGER NOT NULL,
          openedAt INTEGER,
          openCount INTEGER NOT NULL DEFAULT 0,
          reviewAt INTEGER,
          reviewStage INTEGER NOT NULL DEFAULT 0,
          trashedAt INTEGER
        );
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_status_updated ON notes(status, updatedAt DESC);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_kind_status ON notes(kind, status);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_daykey ON notes(dayKey);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_source ON notes(sourceModule, sourceEntityId);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_review ON notes(reviewAt);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_pinned ON notes(isPinned, updatedAt DESC);');

      // 2. note_links table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS note_links (
          id TEXT PRIMARY KEY,
          noteId TEXT NOT NULL,
          linkModule TEXT NOT NULL,
          linkEntityId TEXT NOT NULL,
          linkAction TEXT,
          relation TEXT NOT NULL DEFAULT 'MENTIONS',
          createdAt INTEGER NOT NULL,
          FOREIGN KEY(noteId) REFERENCES notes(id) ON DELETE CASCADE
        );
      ''');
      await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_note_links_unique ON note_links(noteId, linkModule, linkEntityId, relation);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_note_links_target ON note_links(linkModule, linkEntityId);');

      // 3. note_tags table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS note_tags (
          noteId TEXT NOT NULL,
          tag TEXT NOT NULL,
          tagNormalized TEXT NOT NULL,
          source TEXT NOT NULL DEFAULT 'USER',
          createdAt INTEGER NOT NULL,
          PRIMARY KEY (noteId, tagNormalized),
          FOREIGN KEY(noteId) REFERENCES notes(id) ON DELETE CASCADE
        );
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_note_tags_norm ON note_tags(tagNormalized);');

      // 4. note_attachments table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS note_attachments (
          id TEXT PRIMARY KEY,
          noteId TEXT NOT NULL,
          kind TEXT NOT NULL DEFAULT 'IMAGE',
          fileName TEXT NOT NULL,
          relativePath TEXT NOT NULL,
          fileSizeBytes INTEGER NOT NULL,
          mimeType TEXT,
          caption TEXT,
          createdAt INTEGER NOT NULL,
          FOREIGN KEY(noteId) REFERENCES notes(id) ON DELETE CASCADE
        );
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_note_attachments_note ON note_attachments(noteId);');

      // 5. note_revisions table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS note_revisions (
          id TEXT PRIMARY KEY,
          noteId TEXT NOT NULL,
          body TEXT NOT NULL,
          wordCount INTEGER NOT NULL DEFAULT 0,
          reason TEXT NOT NULL DEFAULT 'AUTOSAVE',
          createdAt INTEGER NOT NULL,
          FOREIGN KEY(noteId) REFERENCES notes(id) ON DELETE CASCADE
        );
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_note_revisions_note ON note_revisions(noteId, createdAt DESC);');

      // 6. note_experience_meta table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS note_experience_meta (
          noteId TEXT PRIMARY KEY,
          lesson TEXT NOT NULL,
          contextText TEXT,
          category TEXT NOT NULL DEFAULT 'GENERAL',
          importance INTEGER NOT NULL DEFAULT 3,
          occurredOnDayKey TEXT,
          isActive INTEGER NOT NULL DEFAULT 1,
          showCount INTEGER NOT NULL DEFAULT 0,
          lastShownAtDayKey TEXT,
          acknowledgedCount INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY(noteId) REFERENCES notes(id) ON DELETE CASCADE
        );
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_experience_active ON note_experience_meta(isActive, importance DESC);');

      // 7. FTS5 table if supported by sqlite runtime
      try {
        bool fts5Available = false;
        try {
          final options = await db.rawQuery('PRAGMA compile_options');
          fts5Available = options.any((o) => o.values.any((v) => v.toString().toUpperCase().contains('ENABLE_FTS5')));
        } catch (_) {}

        if (!fts5Available) {
          try {
            final modules = await db.rawQuery('PRAGMA module_list');
            fts5Available = modules.any((m) => m.values.any((v) => v.toString().toLowerCase() == 'fts5'));
          } catch (_) {}
        }

        if (fts5Available) {
          await db.execute('''
            CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(
              noteId UNINDEXED,
              titleN,
              bodyN,
              tagsN,
              tokenize = "unicode61 remove_diacritics 2",
              prefix = '2 3'
            );
          ''');
        } else {
          debugPrint('[NOTE_TABLES] FTS5 module not present in current SQLite build; skipping virtual table.');
        }
      } catch (e) {
        debugPrint('[NOTE_TABLES] FTS5 not available or failed: $e');
      }
    } catch (e, st) {
      debugPrint('[NOTE_TABLES] Error in ensureSchema for notes: $e\n$st');
    }
  }
}
